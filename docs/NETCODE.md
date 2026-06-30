# Netcode (ArrowClashNet)

GGPO-style rollback for exactly two players, sitting behind the `NetcodeSession`
protocol so the sim and renderer never know how inputs are synchronized. The
deterministic sim (`ArrowClashSim`) is the source of truth; the session only
saves/restores `GameState` snapshots and replays `Simulation.tick`.

## Core guarantee

Correctness at confirmed frames does not depend on prediction quality. Any
confirmation that contradicts what we simulated triggers a rollback and
re-simulation, so once a frame's whole input history is known its state equals
what the peer (and a full-information replay) computes. Prediction only affects
how often we roll back, never the final timeline.

This is proven offline by `RollbackHarness`: two sessions over a
`SimulatedNetwork` (latency/jitter/loss) are compared against a full-information
reference replay at every confirmed frame, across fuzzed conditions.

## Phase 10.1 hardening

### Bounded memory (sliding window)
Frame storage is offset by `baseFrame` (the frame at storage index 0). Frames
older than the confirmed frontier can never be a rollback target, so they are
evicted (keeping a small `retainBehindConfirmed` margin). Memory stays flat over
a match of any length.
- `oldestRetainedFrame`, `retainedFrameCount` expose the window.
- `stateAt(frame:)` is valid for `frame in [oldestRetainedFrame, currentFrame]`.

### Prediction barrier
The tip will not lead the confirmed frontier by more than `maxPredictionFrames`.
When the peer goes quiet the session stalls (`isStalled == true`) rather than
predicting unboundedly. This bounds both the rollback distance and memory, and
is the hook the renderer uses to "pause on drop".

### Connection health
`framesSinceRemoteInput` drives `connectionState`:
- `.healthy` - fresh remote input recently.
- `.unstable` - quiet past `unstableTimeoutFrames` (show a banner).
- `.disconnected` - quiet past `disconnectTimeoutFrames` (forfeit).

The app maps this to `SceneDriver.linkStatus`; `GameScene` shows a
"RECONNECTING..." banner while waiting and fires a one-time forfeit win if the
peer stays gone. (Server-side reconciliation of double-claimed forfeits is a
future item; `match_end` remains authoritative for XP/coins.)

### Desync detection
`localChecksum()` reports the newest fully-confirmed frame and its `stateHash`.
`ingestPeerChecksum(frame:hash:)` compares the peer's against ours; if the frame
is not confirmed locally yet it is buffered and checked once it confirms, so
detection works regardless of which peer is ahead. A mismatch trips
`desyncDetected` / `desyncFrame`. This is a safety net behind the determinism
guarantee (it should never fire in a correct build).

## Tuning knobs (RollbackSession.init)

| Param | Default | Meaning |
|-------|---------|---------|
| `inputDelay` | 2 | frames of local input delay |
| `redundancy` | 8 | recent local inputs resent per packet (loss recovery) |
| `maxPredictionFrames` | 30 | max tip lead over confirmed before stalling |
| `retainBehindConfirmed` | 8 | frames kept behind the frontier as margin |
| `unstableTimeoutFrames` | 30 | quiet frames -> `.unstable` |
| `disconnectTimeoutFrames` | 600 | quiet frames -> `.disconnected` (10s @ 60Hz) |

## Wire integration note

The harness exchanges checksums directly. On the live transport, checksums
should be piggybacked onto the existing input packets (or sent as an occasional
control message) and fed to `ingestPeerChecksum`. That transport change is the
remaining wiring step to make desync detection live in online play.

## Tests

- `ArrowClashNetTests/RollbackTests.swift` - correctness across latency/jitter/
  loss, bounded memory over a 5000-frame match, no false desync, desync caught on
  diverging sessions, stall/disconnect on a silent peer.
- `ArrowClashSimCheck` mirrors these for toolchains without XCTest
  (`swift run ArrowClashSimCheck`).
