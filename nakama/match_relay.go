// match_relay.go
// A minimal authoritative match that does nothing but relay each client's input
// messages to the other client, plus assign player slots and a shared seed at
// start. Keeping the server as a pure relay means the deterministic rollback
// simulation lives entirely on the clients (lowest server cost, easiest to later
// replace the relay with P2P).
//
// Opcodes on the wire:
//   OpStart (1): server -> clients, JSON { seed, order: [userId,...] }
//   OpInput (2): client -> server -> other client, opaque input-packet bytes
//                (the server never parses these; only the clients do)
//
// Hardening:
//   - Only the two matchmade users may join (ids passed by the matchmaker hook).
//   - Only OpInput is relayed; clients cannot forge server opcodes like OpStart.
//   - A rejoining user keeps their slot and gets the START payload re-sent, so
//     a reconnect does not strand them (client resume is future work).
//   - Matches that never fill up time out instead of running forever.
//   - On start, a match record {matchId: order} is written to storage; the
//     match_end RPC uses it to verify claims (see progression.go).

package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"math/rand"

	"github.com/heroiclabs/nakama-common/runtime"
)

const (
	OpStart int64 = 1
	OpInput int64 = 2

	maxPlayers = 2

	// Ticks (at 30 Hz) an unfilled match waits before shutting down.
	unstartedTimeoutTicks = 30 * 60 // 60 seconds
)

type startPayload struct {
	Seed    int64    `json:"seed"`
	Order   []string `json:"order"`   // user ids; index is the player slot
	Avatars []Avatar `json:"avatars"` // aligned with order, for rendering the players
	MapID   int      `json:"mapId"`   // index into the client's Maps catalog
}

type matchState struct {
	presences map[string]runtime.Presence // keyed by session id
	order     []string                    // user ids in join order, defines slots
	allowed   map[string]bool             // matchmade user ids permitted to join
	started   bool
	seed      int64
	startData []byte // marshaled START payload, kept for rejoin re-send
}

type RelayMatch struct{}

func (m *RelayMatch) MatchInit(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, params map[string]interface{}) (interface{}, int, string) {
	state := &matchState{
		presences: make(map[string]runtime.Presence),
		order:     make([]string, 0, maxPlayers),
		allowed:   make(map[string]bool),
	}
	// The matchmaker hook passes the matched user ids; only they may join.
	if users, ok := params["users"].([]interface{}); ok {
		for _, u := range users {
			if id, ok := u.(string); ok {
				state.allowed[id] = true
			}
		}
	}
	tickRate := 30 // Hz; relay forwards buffered inputs each loop
	label := "arrowclash1v1"
	return state, tickRate, label
}

func (m *RelayMatch) MatchJoinAttempt(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, dispatcher runtime.MatchDispatcher, tick int64, state interface{}, presence runtime.Presence, metadata map[string]string) (interface{}, bool, string) {
	s := state.(*matchState)
	if len(s.allowed) > 0 && !s.allowed[presence.GetUserId()] {
		return s, false, "not a participant of this match"
	}
	// Count distinct users, not sessions, so a matched player can rejoin.
	if len(s.presences) >= maxPlayers && !s.hasUser(presence.GetUserId()) {
		return s, false, "match is full"
	}
	return s, true, ""
}

func (s *matchState) hasUser(userID string) bool {
	for _, uid := range s.order {
		if uid == userID {
			return true
		}
	}
	return false
}

func (m *RelayMatch) MatchJoin(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, dispatcher runtime.MatchDispatcher, tick int64, state interface{}, presences []runtime.Presence) interface{} {
	s := state.(*matchState)
	for _, p := range presences {
		s.presences[p.GetSessionId()] = p
		// A rejoining user keeps their original slot; only new users append.
		if !s.hasUser(p.GetUserId()) {
			s.order = append(s.order, p.GetUserId())
		}
		// Re-send START to a rejoiner so a reconnect is not stranded.
		if s.started && s.startData != nil {
			if err := dispatcher.BroadcastMessage(OpStart, s.startData, []runtime.Presence{p}, nil, true); err != nil {
				logger.Error("failed to re-send start: %v", err)
			}
		}
	}

	if !s.started && len(s.presences) == maxPlayers {
		s.started = true
		s.seed = rand.Int63()

		avatars := make([]Avatar, 0, len(s.order))
		for _, uid := range s.order {
			avatars = append(avatars, avatarForUser(ctx, nk, uid))
		}

		mapID := rand.Intn(mapCount)
		payload, err := json.Marshal(startPayload{Seed: s.seed, Order: s.order, Avatars: avatars, MapID: mapID})
		if err != nil {
			logger.Error("failed to marshal start payload: %v", err)
			return s
		}
		s.startData = payload

		// Record the participants so match_end claims can be verified.
		if matchID, ok := ctx.Value(runtime.RUNTIME_CTX_MATCH_ID).(string); ok {
			writeMatchRecord(ctx, logger, nk, matchID, s.order)
		}

		// Broadcast to everyone (nil recipients == all presences).
		if err := dispatcher.BroadcastMessage(OpStart, payload, nil, nil, true); err != nil {
			logger.Error("failed to broadcast start: %v", err)
		}
	}
	return s
}

func (m *RelayMatch) MatchLeave(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, dispatcher runtime.MatchDispatcher, tick int64, state interface{}, presences []runtime.Presence) interface{} {
	s := state.(*matchState)
	for _, p := range presences {
		delete(s.presences, p.GetSessionId())
	}
	// End the match once everyone has left.
	if len(s.presences) == 0 {
		return nil
	}
	return s
}

func (m *RelayMatch) MatchLoop(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, dispatcher runtime.MatchDispatcher, tick int64, state interface{}, messages []runtime.MatchData) interface{} {
	s := state.(*matchState)

	// A match that never filled shuts down instead of running forever.
	if !s.started && tick > unstartedTimeoutTicks {
		logger.Info("match never filled; shutting down")
		return nil
	}

	for _, msg := range messages {
		// Only relay input packets; clients must not be able to forge
		// server-originated opcodes (e.g. a fake START).
		if msg.GetOpCode() != OpInput {
			continue
		}
		recipients := make([]runtime.Presence, 0, maxPlayers-1)
		for sessionID, p := range s.presences {
			if sessionID != msg.GetSessionId() {
				recipients = append(recipients, p)
			}
		}
		if len(recipients) > 0 {
			if err := dispatcher.BroadcastMessage(msg.GetOpCode(), msg.GetData(), recipients, nil, true); err != nil {
				logger.Error("failed to relay message: %v", err)
			}
		}
	}
	return s
}

func (m *RelayMatch) MatchTerminate(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, dispatcher runtime.MatchDispatcher, tick int64, state interface{}, graceSeconds int) interface{} {
	return state
}

func (m *RelayMatch) MatchSignal(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, dispatcher runtime.MatchDispatcher, tick int64, state interface{}, data string) (interface{}, string) {
	return state, ""
}
