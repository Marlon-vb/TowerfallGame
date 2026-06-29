# Phase 3 — Nakama online 1v1

Goal: stand up local Nakama, authenticate with a device id, matchmake a 1v1, and
carry per-tick inputs over a relayed match into the Phase 2 rollback system so
two clients play a synced match.

## Pieces

Backend (`nakama/`, compiled + plugin-built here against nakama-common v1.31.0):
- Go runtime module: a pure input-relay match handler plus a matchmaker-matched
  hook that creates the match. Assigns player slots and a shared seed via an
  `OpStart` broadcast; relays every `OpInput` message to the other player.
- `docker-compose.yml` + `Dockerfile` + `local.yml` for Nakama + Postgres.

Client wire format (`ArrowClashNet`, unit-tested):
- `PacketCodec` encodes/decodes `InputPacket` as compact bytes. The server never
  parses these; only clients do.

Client networking (`App/ArrowClash/Online/`, NOT compiled here):
- `NakamaTransport` adapts a Nakama socket to `InputTransport`.
- `OnlineMatchController` does device auth -> matchmaking -> join -> receive
  START (slot + seed) -> build a `RollbackSession` fed by the transport.
- `DeviceAuthProvider` is behind an `AuthProvider` seam so Game Center can be
  added later.

App flow:
- `MenuView` (Find Online Match / Local Practice) -> `AppModel` builds a
  `GameScene` with an `OnlineDriver` (real opponent) or `LocalDriver` (practice).
- `GameScene` now renders through a `SceneDriver`, so the same scene serves both.

## Run it

1. Backend:
   ```
   cd nakama
   docker compose up --build
   ```
   Console at http://127.0.0.1:7351 (admin / password), server key `defaultkey`.

2. Regenerate the Xcode project (it now pulls the Nakama Swift SDK):
   ```
   cd App
   ~/XcodeGen/.build/release/xcodegen generate
   open ArrowClash.xcodeproj
   ```
   Let Xcode resolve Swift packages.

3. Run two clients. Easiest is two simulators (each gets its own device id):
   - Xcode > Product > Destination > pick e.g. iPhone 15, Run.
   - Then pick iPhone 15 Pro as a second destination and Run again.
   - Tap "Find Online Match" on both. They should match and play a synced 1v1.

   Simulator reaches Nakama at `127.0.0.1`. For a physical device, set
   `OnlineMatchController.serverHost` to your Mac's LAN IP.

## Verify (headless parts, no Xcode)

```
cd ArrowClashSim
swift test          # includes PacketCodecTests and all rollback tests
```

## Honest flags

- The backend Go module is compiled and plugin-built here, but it has not been
  run in a live Nakama server in this environment (no Docker runtime). Report
  anything odd on first `docker compose up`.
- The client Nakama code (`NakamaTransport`, `OnlineMatchController`) could NOT
  be compiled here (no iOS toolchain or Nakama SDK). The Nakama Swift SDK API
  (client/socket method names, async shape, the matchmaker/match-data types) is
  the most likely thing to need small adjustments to match the SDK version Xcode
  resolves. All such code is confined to those two files plus the `project.yml`
  package entry. Paste any compile errors and I will correct them quickly.
- The Nakama Swift package version in `project.yml` (`from: 2.0.0`) is a guess.
  If resolution fails, tell me the available versions/tag and I will pin it.
- Rollback over a real relay will show its true feel here for the first time.
  Online interpolation currently snaps on large rollback corrections; if it
  looks jumpy we can add display smoothing.

## Not yet (later phases)

Rounds, countdown, scoring, one-hit death and post-match (Phase 4). XP,
progression, cosmetics, leaderboards and the match-end RPC (Phase 5).
