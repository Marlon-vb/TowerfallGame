# Phase 2 — Rollback netcode (offline)

Goal: GGPO-style rollback driving two sim instances in one process under
simulated input delay, latency, jitter and packet loss. Save/restore state,
predict remote input, roll back and re-simulate on mismatch. Prove both sides
stay in sync.

This is the make-or-break system, so it is built to be proven headlessly with
strong tests, no Xcode required.

## New module: ArrowClashNet

A second library target in the package, depending on `ArrowClashSim`, also free
of UIKit/SpriteKit. Everything sits behind protocols.

- `NetcodeSession.swift` — the protocol the game loop talks to (`step`,
  `currentFrame`, `confirmedFrame`, `stateAt`, `latestState`). RollbackSession is
  the v1 implementation; an authoritative-tick + client-prediction session could
  conform to the same protocol later without touching the sim or renderer.
- `InputTransport.swift` — the wire protocol (`send`/`poll`) plus `InputPacket`.
  Phase 3 swaps in a Nakama relayed-match transport that implements this. A P2P
  (UDP/WebRTC) transport could replace the relay later to cut latency.
- `RollbackSession.swift` — the rollback implementation (details below).
- `SimulatedNetwork.swift` — deterministic in-process link with latency, jitter
  and packet loss, all driven by a seeded PRNG. Used for tests and a future
  local rollback demo.
- `RollbackHarness.swift` — drives two sessions across a SimulatedNetwork and
  compares their confirmed-frame states against a full-information reference
  replay.

## How the rollback works

Frame F is simulated from the start-of-F state using both players' inputs for F.
Each `step(localInput:)`:

1. Assign the local input to frame `current + inputDelay` and send a redundant
   window (last `redundancy` frames) of local inputs to the peer.
2. Apply received remote inputs. If a newly confirmed input for an
   already-simulated frame differs from the value predicted there, mark that
   frame for rollback.
3. If needed, restore the saved start-of-frame state at the earliest such frame
   and re-simulate forward to the tip with the now better-known inputs.
4. Simulate one new tip frame, predicting the remote input (repeat last
   received) if it has not arrived.

Defaults: `inputDelay = 2`, `redundancy = 8`.

### Why confirmed frames are always correct

`confirmedFrame` is the largest frame whose entire input history is known for
certain (a contiguous frontier). The key property: any confirmation that
contradicts what we simulated triggers a rollback and re-simulation, and a
confirmation that matches needs no change. So once a frame's whole history is
confirmed, its state equals what the peer computes and what a full-information
replay computes. Prediction quality only changes how often we roll back, never
the confirmed result. The tests assert exactly this.

## What the tests prove

`swift run ArrowClashSimCheck` (Rollback section) and
`ArrowClashNetTests` both check, against a reference replay that knows all inputs
up front:

- No latency: sessions match the reference at every confirmed frame.
- Latency above input delay: rollbacks actually occur, yet every confirmed frame
  still matches the reference.
- Latency + jitter + 20% packet loss: the redundant input window recovers drops
  and confirmed frames still match.
- Fuzz: dozens of randomized seeds/latency/jitter/loss combinations, all match
  the reference, and both peers agree at every confirmed frame.

## Verify

```
cd ArrowClashSim
swift test                 # includes ArrowClashNetTests
swift run ArrowClashSimCheck
```

## Honest flags / uncertainty

- Correctness is proven by equivalence to a full-information replay across many
  randomized scenarios. That is strong evidence, not a formal proof. If any fuzz
  seed ever fails, the failing seed/latency/loss is printed so it can be
  reproduced and fixed.
- Frame-indexed arrays grow without bound here for clarity. Production needs a
  ring buffer sized to a maximum rollback distance (a frame older than
  `confirmedFrame` can never need rollback). Not done yet because it does not
  affect correctness, only memory over a long match.
- "Plays smoothly" is validated when this is wired into the SpriteKit loop
  (Phase 3 online, or an optional local demo). Here I prove the harder half:
  that the two timelines are identical. If you want, I can add a local
  two-stick rollback demo to the app so you can feel it before Phase 3.
- Tail frames under heavy loss may not confirm (no later packet resends the very
  last inputs). Expected; it only affects the final handful of frames.
