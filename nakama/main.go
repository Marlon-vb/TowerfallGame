// main.go
// Nakama Go runtime module for ArrowClash.
//
// Phase 3 responsibilities:
//   - register the "arrowclash" relay match handler
//   - register a matchmaker-matched hook that creates one of those matches and
//     returns its id so the two matched clients can join it
//
// The match end RPC, XP, progression and leaderboard come in Phase 5 and are
// intentionally not here yet.

package main

import (
	"context"
	"database/sql"
	"math/rand"
	"time"

	"github.com/heroiclabs/nakama-common/runtime"
)

const moduleName = "arrowclash"

// InitModule is the entry point Nakama calls when loading the plugin.
func InitModule(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, initializer runtime.Initializer) error {
	rand.Seed(time.Now().UnixNano())

	if err := initializer.RegisterMatch(moduleName, func(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule) (runtime.Match, error) {
		return &RelayMatch{}, nil
	}); err != nil {
		logger.Error("failed to register match: %v", err)
		return err
	}

	if err := initializer.RegisterMatchmakerMatched(matchmakerMatched); err != nil {
		logger.Error("failed to register matchmaker matched hook: %v", err)
		return err
	}

	// Progression RPCs (server-authoritative).
	if err := initializer.RegisterRpc("match_end", rpcMatchEnd); err != nil {
		return err
	}
	if err := initializer.RegisterRpc("get_profile", rpcGetProfile); err != nil {
		return err
	}
	if err := initializer.RegisterRpc("set_avatar", rpcSetAvatar); err != nil {
		return err
	}
	if err := initializer.RegisterRpc("purchase", rpcPurchase); err != nil {
		return err
	}

	// XP leaderboard (authoritative: only the server runtime writes it).
	if err := nk.LeaderboardCreate(ctx, leaderboardID, true, "desc", "set", "", nil); err != nil {
		logger.Warn("leaderboard create (may already exist): %v", err)
	}

	logger.Info("arrowclash module loaded")
	return nil
}

// matchmakerMatched creates a relay match for the matched players and returns
// its id. Nakama delivers that id to each matched client, which then joins it.
func matchmakerMatched(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, entries []runtime.MatchmakerEntry) (string, error) {
	matchID, err := nk.MatchCreate(ctx, moduleName, map[string]interface{}{})
	if err != nil {
		logger.Error("failed to create match from matchmaker: %v", err)
		return "", err
	}
	logger.Info("created arrowclash match %s for %d players", matchID, len(entries))
	return matchID, nil
}
