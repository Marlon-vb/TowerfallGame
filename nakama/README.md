# ArrowClash Nakama backend (local dev)

Local Nakama + Postgres with the ArrowClash Go runtime module (a pure input
relay plus a matchmaker hook). The deterministic rollback simulation runs on the
clients; the server only relays per-tick input packets and assigns player slots
and a shared seed.

## Run

Requires Docker Desktop.

```
cd nakama
docker compose up --build
```

First run builds the Go plugin (pulls the matching toolchain) and starts the
server. When it is up:

- gRPC API: `127.0.0.1:7349` (the iOS client connects here)
- HTTP API: `127.0.0.1:7350`
- Console: http://127.0.0.1:7351 (default login `admin` / `password`)

Server key is `defaultkey`.

Stop with Ctrl-C. `docker compose down -v` also wipes the Postgres volume.

## What the module does

- `main.go` registers the `arrowclash` match handler and a matchmaker-matched
  hook. When two tickets match, the hook creates an `arrowclash` match and Nakama
  hands its id to both clients, which join it.
- `match_relay.go` is an authoritative match that only relays input. On the
  second join it broadcasts `OpStart` (1) with JSON `{ seed, order: [userId,...] }`
  (the index in `order` is the player slot). Every `OpInput` (2) message is
  relayed verbatim to the other player; the server never parses input bytes.

## Verifying the match is wired up (without the app)

Use the Nakama console (http://127.0.0.1:7351) or `nakama-cli`/curl against the
HTTP API to authenticate two device ids and add matchmaker tickets with
`min_count = 2`, `max_count = 2`, query `*`. Both should receive a matchmaker
matched event carrying the same match id.

## Later phases

Phase 5 adds an RPC here to validate match results, award XP, write progression,
and update a leaderboard. Not present yet.

## Note on verification

This module was compiled and plugin-built (`go build -buildmode=plugin`) against
`nakama-common v1.31.0`, so the runtime API usage is correct. It has not been
run inside a live Nakama server in this environment (no Docker runtime here), so
please report anything that misbehaves on first `docker compose up`.
