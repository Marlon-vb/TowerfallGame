// progression.go
// Server-authoritative progression: profile storage, XP + coins from match
// results, the leaderboard, store purchases, and avatar changes. The client can
// never write the profile directly (storage write permission is server-only);
// all changes flow through these RPCs, which compute values server-side.
//
// Hardening:
//   - All profile mutations go through updateProfile, a read-modify-write with
//     optimistic concurrency (storage object versions) and retry, so concurrent
//     RPCs cannot silently overwrite each other (e.g. purchase vs match_end).
//   - match_end requires the matchId; it is validated against the match record
//     the relay wrote (caller must be a participant), each user can claim a
//     given match once, and only one player can claim the WIN of a match (a
//     second win claim is downgraded to a loss). This kills reward farming by
//     replaying the RPC and blunts the symmetric "both sides claim the forfeit
//     win" case. Full server-verified results (server-run sim) remain future
//     work - see docs/NETCODE.md.

package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"

	"github.com/heroiclabs/nakama-common/api"
	"github.com/heroiclabs/nakama-common/runtime"
)

const (
	profileCollection = "profile"
	profileKey        = "main"
	leaderboardID     = "arrowclash_xp"

	matchRecordCollection = "matches"
	matchClaimCollection  = "match_claims"
)

var errNoUser = errors.New("no user in context")

// MARK: storage helpers

// loadProfileVersioned returns the profile plus its storage version ("" when
// the profile does not exist yet), for conditional writes.
func loadProfileVersioned(ctx context.Context, nk runtime.NakamaModule, userID string) (Profile, string, error) {
	reads := []*runtime.StorageRead{{
		Collection: profileCollection,
		Key:        profileKey,
		UserID:     userID,
	}}
	objects, err := nk.StorageRead(ctx, reads)
	if err != nil {
		return defaultProfile(), "", err
	}
	if len(objects) == 0 {
		return defaultProfile(), "", nil
	}
	var profile Profile
	if err := json.Unmarshal([]byte(objects[0].Value), &profile); err != nil {
		return defaultProfile(), objects[0].Version, nil
	}
	if profile.Level < 1 {
		profile.Level = 1
	}
	if profile.Owned == nil {
		profile.Owned = []string{}
	}
	if profile.Avatar.Skin == "" {
		profile.Avatar = defaultAvatar()
	}
	return profile, objects[0].Version, nil
}

func loadProfile(ctx context.Context, nk runtime.NakamaModule, userID string) (Profile, error) {
	profile, _, err := loadProfileVersioned(ctx, nk, userID)
	return profile, err
}

// saveProfile writes conditionally: version "" means "must not exist yet" ("*"),
// otherwise the write only succeeds if the object still has that version.
func saveProfile(ctx context.Context, nk runtime.NakamaModule, userID string, profile Profile, version string) error {
	value, err := json.Marshal(profile)
	if err != nil {
		return err
	}
	if version == "" {
		version = "*"
	}
	writes := []*runtime.StorageWrite{{
		Collection:      profileCollection,
		Key:             profileKey,
		UserID:          userID,
		Value:           string(value),
		Version:         version,
		PermissionRead:  1, // owner can read
		PermissionWrite: 0, // only the server runtime can write
	}}
	_, err = nk.StorageWrite(ctx, writes)
	return err
}

// updateProfile applies mutate under optimistic concurrency: on a version
// conflict it reloads and retries, so concurrent RPCs never lose updates.
// mutate returning an error aborts (validation failures).
func updateProfile(ctx context.Context, nk runtime.NakamaModule, userID string, mutate func(*Profile) error) (Profile, error) {
	var lastErr error
	for attempt := 0; attempt < 4; attempt++ {
		profile, version, err := loadProfileVersioned(ctx, nk, userID)
		if err != nil {
			return profile, err
		}
		if err := mutate(&profile); err != nil {
			return profile, err
		}
		if err := saveProfile(ctx, nk, userID, profile, version); err != nil {
			lastErr = err // most likely a version conflict; retry
			continue
		}
		return profile, nil
	}
	return defaultProfile(), lastErr
}

func avatarForUser(ctx context.Context, nk runtime.NakamaModule, userID string) Avatar {
	profile, err := loadProfile(ctx, nk, userID)
	if err != nil {
		return defaultAvatar()
	}
	return profile.Avatar
}

// MARK: match records + claims

type matchRecord struct {
	Order []string `json:"order"`
}

// writeMatchRecord is called by the relay when a match starts.
func writeMatchRecord(ctx context.Context, logger runtime.Logger, nk runtime.NakamaModule, matchID string, order []string) {
	value, err := json.Marshal(matchRecord{Order: order})
	if err != nil {
		logger.Error("marshal match record: %v", err)
		return
	}
	writes := []*runtime.StorageWrite{{
		Collection:      matchRecordCollection,
		Key:             matchID,
		UserID:          "", // system-owned
		Value:           string(value),
		PermissionRead:  0,
		PermissionWrite: 0,
	}}
	if _, err := nk.StorageWrite(ctx, writes); err != nil {
		logger.Error("write match record: %v", err)
	}
}

func readMatchRecord(ctx context.Context, nk runtime.NakamaModule, matchID string) (matchRecord, bool) {
	objects, err := nk.StorageRead(ctx, []*runtime.StorageRead{{
		Collection: matchRecordCollection,
		Key:        matchID,
		UserID:     "",
	}})
	if err != nil || len(objects) == 0 {
		return matchRecord{}, false
	}
	var record matchRecord
	if err := json.Unmarshal([]byte(objects[0].Value), &record); err != nil {
		return matchRecord{}, false
	}
	return record, true
}

// claim writes a one-time marker; it fails if the marker already exists.
func claim(ctx context.Context, nk runtime.NakamaModule, key string) bool {
	_, err := nk.StorageWrite(ctx, []*runtime.StorageWrite{{
		Collection:      matchClaimCollection,
		Key:             key,
		UserID:          "",
		Value:           "{}",
		Version:         "*", // only succeeds if the object does not exist yet
		PermissionRead:  0,
		PermissionWrite: 0,
	}})
	return err == nil
}

// MARK: context helpers

func userIDFromContext(ctx context.Context) (string, bool) {
	userID, ok := ctx.Value(runtime.RUNTIME_CTX_USER_ID).(string)
	return userID, ok && userID != ""
}

func usernameFromContext(ctx context.Context) string {
	username, _ := ctx.Value(runtime.RUNTIME_CTX_USERNAME).(string)
	return username
}

// MARK: RPCs

type matchEndRequest struct {
	MatchID string `json:"matchId"`
	Won     bool   `json:"won"`
	Kills   int    `json:"kills"`
	Rounds  int    `json:"rounds"`
}

func rpcMatchEnd(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, payload string) (string, error) {
	userID, ok := userIDFromContext(ctx)
	if !ok {
		return "", errNoUser
	}
	var req matchEndRequest
	if err := json.Unmarshal([]byte(payload), &req); err != nil {
		return "", err
	}
	if req.MatchID == "" {
		return "", errors.New("missing matchId")
	}

	// The caller must have been a participant of a real match.
	record, found := readMatchRecord(ctx, nk, req.MatchID)
	if !found {
		return "", errors.New("unknown match")
	}
	participant := false
	for _, uid := range record.Order {
		if uid == userID {
			participant = true
			break
		}
	}
	if !participant {
		return "", errors.New("not a participant of this match")
	}

	// One claim per user per match: replaying the RPC earns nothing.
	if !claim(ctx, nk, req.MatchID+":"+userID) {
		return "", errors.New("match already claimed")
	}
	// Only one player can claim the win. A second win claim (e.g. both sides
	// believing they won a forfeit) is downgraded to a loss, not rejected, so
	// the honest client still gets loss rewards.
	won := req.Won
	if won && !claim(ctx, nk, req.MatchID+":win") {
		logger.Warn("duplicate win claim for match %s by %s; downgraded to loss", req.MatchID, userID)
		won = false
	}

	profile, err := updateProfile(ctx, nk, userID, func(p *Profile) error {
		p.XP += xpForMatch(won, req.Kills)
		p.Coins += coinsForMatch(won, req.Kills)
		p.Level = levelForXP(p.XP)
		return nil
	})
	if err != nil {
		return "", err
	}

	username := usernameFromContext(ctx)
	if _, err := nk.LeaderboardRecordWrite(ctx, leaderboardID, userID, username, int64(profile.XP), 0, nil, nil); err != nil {
		logger.Warn("leaderboard write failed: %v", err)
	}

	return marshalProfile(profile)
}

func rpcGetProfile(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, payload string) (string, error) {
	userID, ok := userIDFromContext(ctx)
	if !ok {
		return "", errNoUser
	}
	profile, version, err := loadProfileVersioned(ctx, nk, userID)
	if err != nil {
		return "", err
	}
	// Persist only a brand-new profile; never rewrite an existing one on read
	// (an unconditional write here could race and undo a concurrent purchase).
	if version == "" {
		if err := saveProfile(ctx, nk, userID, profile, ""); err != nil {
			logger.Warn("could not persist default profile: %v", err)
		}
	}
	return marshalProfile(profile)
}

func rpcSetAvatar(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, payload string) (string, error) {
	userID, ok := userIDFromContext(ctx)
	if !ok {
		return "", errNoUser
	}
	var requested Avatar
	if err := json.Unmarshal([]byte(payload), &requested); err != nil {
		return "", err
	}

	profile, err := updateProfile(ctx, nk, userID, func(p *Profile) error {
		// Every equipped item must exist, match its slot, and be owned.
		parts := []struct{ id, slot string }{
			{requested.Skin, "skin"},
			{requested.Hair, "hair"},
			{requested.Shirt, "shirt"},
			{requested.Pants, "pants"},
			{requested.Head, "head"},
			{requested.Trail, "trail"},
		}
		for _, part := range parts {
			if !itemInSlot(part.id, part.slot) {
				return errors.New("invalid item for slot " + part.slot)
			}
			if !ownsItem(*p, part.id) {
				return errors.New("item not owned: " + part.id)
			}
		}
		p.Avatar = requested
		return nil
	})
	if err != nil {
		return "", err
	}
	return marshalProfile(profile)
}

type purchaseRequest struct {
	ItemID string `json:"itemId"`
}

func rpcPurchase(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, payload string) (string, error) {
	userID, ok := userIDFromContext(ctx)
	if !ok {
		return "", errNoUser
	}
	var req purchaseRequest
	if err := json.Unmarshal([]byte(payload), &req); err != nil {
		return "", err
	}

	item, exists := itemByID(req.ItemID)
	if !exists || item.Cost <= 0 {
		return "", errors.New("item not purchasable")
	}

	profile, err := updateProfile(ctx, nk, userID, func(p *Profile) error {
		if ownsItem(*p, req.ItemID) {
			return errors.New("already owned")
		}
		if p.Coins < item.Cost {
			return errors.New("not enough coins")
		}
		p.Coins -= item.Cost
		p.Owned = append(p.Owned, req.ItemID)
		return nil
	})
	if err != nil {
		return "", err
	}
	return marshalProfile(profile)
}

func marshalProfile(profile Profile) (string, error) {
	out, err := json.Marshal(profile)
	if err != nil {
		return "", err
	}
	return string(out), nil
}

// Keep the api import (storage object typing).
var _ = api.StorageObject{}
