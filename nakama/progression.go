// progression.go
// Server-authoritative progression: profile storage, XP from match results, the
// leaderboard, and loadout changes. The client can never write the profile
// directly (storage write permission is server-only); all changes flow through
// these RPCs, which compute values server-side.

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

func loadoutForUser(ctx context.Context, nk runtime.NakamaModule, userID string) Loadout {
	profile, err := loadProfile(ctx, nk, userID)
	if err != nil {
		return defaultLoadout()
	}
	return profile.Loadout
}

// MARK: RPCs

func userIDFromContext(ctx context.Context) (string, bool) {
	userID, ok := ctx.Value(runtime.RUNTIME_CTX_USER_ID).(string)
	return userID, ok && userID != ""
}

func usernameFromContext(ctx context.Context) string {
	username, _ := ctx.Value(runtime.RUNTIME_CTX_USERNAME).(string)
	return username
}

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
	profile.Level = levelForXP(profile.XP)

	if err := saveProfile(ctx, nk, userID, profile); err != nil {
		return "", err
	}

	username := usernameFromContext(ctx)
	if _, err := nk.LeaderboardRecordWrite(ctx, leaderboardID, userID, username, int64(profile.XP), 0, nil, nil); err != nil {
		logger.Warn("leaderboard write failed: %v", err)
	}

	out, err := json.Marshal(profile)
	if err != nil {
		return "", err
	}
	return string(out), nil
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
	// Persist a default profile on first read so it exists for match handlers.
	if err := saveProfile(ctx, nk, userID, profile); err != nil {
		logger.Warn("could not persist default profile: %v", err)
	}
	out, err := json.Marshal(profile)
	if err != nil {
		return "", err
	}
	return string(out), nil
}

func rpcSetLoadout(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, payload string) (string, error) {
	userID, ok := userIDFromContext(ctx)
	if !ok {
		return "", errNoUser
	}
	var requested Loadout
	if err := json.Unmarshal([]byte(payload), &requested); err != nil {
		return "", err
	}

	profile, err := loadProfile(ctx, nk, userID)
	if err != nil {
		return "", err
	}

	// Validate that each chosen cosmetic exists, is the right kind, and is owned.
	if cosmeticKind(requested.Skin) != "skin" || !isOwned(requested.Skin, profile.Level) {
		return "", errors.New("skin not unlocked")
	}
	if cosmeticKind(requested.Trail) != "trail" || !isOwned(requested.Trail, profile.Level) {
		return "", errors.New("trail not unlocked")
	}

	profile.Loadout = requested
	if err := saveProfile(ctx, nk, userID, profile); err != nil {
		return "", err
	}

	out, err := json.Marshal(profile)
	if err != nil {
		return "", err
	}
	return string(out), nil
}

// Ensure the api package import is retained for storage object typing.
var _ = api.StorageObject{}
