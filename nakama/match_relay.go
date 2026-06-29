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
)

type startPayload struct {
	Seed     int64     `json:"seed"`
	Order    []string  `json:"order"`    // user ids; index is the player slot
	Loadouts []Loadout `json:"loadouts"` // aligned with order, for rendering cosmetics
}

type matchState struct {
	presences map[string]runtime.Presence // keyed by session id
	order     []string                    // user ids in join order, defines slots
	started   bool
	seed      int64
}

type RelayMatch struct{}

func (m *RelayMatch) MatchInit(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, params map[string]interface{}) (interface{}, int, string) {
	state := &matchState{
		presences: make(map[string]runtime.Presence),
		order:     make([]string, 0, maxPlayers),
	}
	tickRate := 30 // Hz; relay forwards buffered inputs each loop
	label := "arrowclash1v1"
	return state, tickRate, label
}

func (m *RelayMatch) MatchJoinAttempt(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, dispatcher runtime.MatchDispatcher, tick int64, state interface{}, presence runtime.Presence, metadata map[string]string) (interface{}, bool, string) {
	s := state.(*matchState)
	if len(s.presences) >= maxPlayers {
		return s, false, "match is full"
	}
	return s, true, ""
}

func (m *RelayMatch) MatchJoin(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, dispatcher runtime.MatchDispatcher, tick int64, state interface{}, presences []runtime.Presence) interface{} {
	s := state.(*matchState)
	for _, p := range presences {
		s.presences[p.GetSessionId()] = p
		s.order = append(s.order, p.GetUserId())
	}

	if !s.started && len(s.presences) == maxPlayers {
		s.started = true
		s.seed = rand.Int63()

		loadouts := make([]Loadout, 0, len(s.order))
		for _, uid := range s.order {
			loadouts = append(loadouts, loadoutForUser(ctx, nk, uid))
		}

		payload, err := json.Marshal(startPayload{Seed: s.seed, Order: s.order, Loadouts: loadouts})
		if err != nil {
			logger.Error("failed to marshal start payload: %v", err)
			return s
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
	for _, msg := range messages {
		// Relay each input message to everyone except the sender.
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
