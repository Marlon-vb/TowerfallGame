// progression.go
// Server-authoritative progression: profile storage, XP + coins from match
// results, the leaderboard, store purchases, and avatar changes. The client can
// never write the profile directly (storage write permission is server-only);
// all changes flow through these RPCs, which compute values server-side.

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
)

var errNoUser = errors.New("no user in context")

// MARK: storage helpers

func loadProfile(ctx context.Context, nk runtime.NakamaModule, userID string) (Profile, error) {
	reads := []*runtime.StorageRead{{
		Collection: profileCollection,
		Key:        profileKey,
		UserID:     userID,
	}}
	objects, err := nk.StorageRead(ctx, reads)
	if err != nil {
		return defaultProfile(), err
	}
	if len(objects) == 0 {
		return defaultProfile(), nil
	}
	var profile Profile
	if err := json.Unmarshal([]byte(objects[0].Value), &profile); err != nil {
		return defaultProfile(), nil
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
	return profile, nil
}

func saveProfile(ctx context.Context, nk runtime.NakamaModule, userID string, profile Profile) error {
	value, err := json.Marshal(profile)
	if err != nil {
		return err
	}
	writes := []*runtime.StorageWrite{{
		Collection:      profileCollection,
		Key:             profileKey,
		UserID:          userID,
		Value:           string(value),
		PermissionRead:  1, // owner can read
		PermissionWrite: 0, // only the server runtime can write
	}}
	_, err = nk.StorageWrite(ctx, writes)
	return err
}

func avatarForUser(ctx context.Context, nk runtime.NakamaModule, userID string) Avatar {
	profile, err := loadProfile(ctx, nk, userID)
	if err != nil {
		return defaultAvatar()
	}
	return profile.Avatar
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
	Won    bool `json:"won"`
	Kills  int  `json:"kills"`
	Rounds int  `json:"rounds"`
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

	profile, err := loadProfile(ctx, nk, userID)
	if err != nil {
		return "", err
	}
	profile.XP += xpForMatch(req.Won, req.Kills)
	profile.Coins += coinsForMatch(req.Won, req.Kills)
	profile.Level = levelForXP(profile.XP)

	if err := saveProfile(ctx, nk, userID, profile); err != nil {
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
	profile, err := loadProfile(ctx, nk, userID)
	if err != nil {
		return "", err
	}
	if err := saveProfile(ctx, nk, userID, profile); err != nil {
		logger.Warn("could not persist default profile: %v", err)
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

	profile, err := loadProfile(ctx, nk, userID)
	if err != nil {
		return "", err
	}

	// Every equipped item must exist, match its slot, and be owned.
	parts := []struct{ id, slot string }{
		{requested.Skin, "skin"},
		{requested.Hair, "hair"},
		{requested.Shirt, "shirt"},
		{requested.Pants, "pants"},
		{requested.Head, "head"},
		{requested.Trail, "trail"},
	}
	for _, p := range parts {
		if !itemInSlot(p.id, p.slot) {
			return "", errors.New("invalid item for slot " + p.slot)
		}
		if !ownsItem(profile, p.id) {
			return "", errors.New("item not owned: " + p.id)
		}
	}

	profile.Avatar = requested
	if err := saveProfile(ctx, nk, userID, profile); err != nil {
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

	profile, err := loadProfile(ctx, nk, userID)
	if err != nil {
		return "", err
	}
	if ownsItem(profile, req.ItemID) {
		return "", errors.New("already owned")
	}
	if profile.Coins < item.Cost {
		return "", errors.New("not enough coins")
	}

	profile.Coins -= item.Cost
	profile.Owned = append(profile.Owned, req.ItemID)
	if err := saveProfile(ctx, nk, userID, profile); err != nil {
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
