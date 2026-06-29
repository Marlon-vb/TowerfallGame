# ArrowClash

A TowerFall-style 1v1 online archery duel for iOS (Swift, SpriteKit). Fast,
one-hit-kill 2D matches built on a custom deterministic simulation with
rollback netcode.

This repository is being built in phases. See `docs/` for the per-phase notes.

## Current status: Phase 2 (rollback netcode, offline)

`ArrowClashNet` adds GGPO-style rollback (behind swappable `NetcodeSession` and
`InputTransport` protocols) on top of the deterministic sim. Two sim instances
stay in sync under simulated latency, jitter and packet loss, proven headlessly
against a full-information reference replay. See `docs/PHASE2.md`.

Earlier: Phase 0 (deterministic sim), Phase 1 (arrows + SpriteKit local play
harness). See `docs/`.

## Layout

```
ArrowClashSim/                 Swift package: sim + netcode
  Sources/ArrowClashSim/       Fixed-point math, state, tick, collision, hash
  Sources/ArrowClashNet/       Rollback netcode (sim-dependent, no UIKit/SpriteKit)
  Tests/ArrowClashSimTests/    Determinism + movement + combat tests
  Tests/ArrowClashNetTests/    Rollback correctness + fuzz tests
App/                           iOS app target (SwiftUI shell for now)
  project.yml                  XcodeGen spec -> generates ArrowClash.xcodeproj
  ArrowClash/                  App sources
docs/                          Phase notes and design decisions
```

## Confirmed v1 design decisions

- Arena wraps on BOTH axes (horizontal and vertical), TowerFall style.
- Movement/feel values are proposed defaults, all in `GameConfig`, easy to tune.
- Match length: best of 5 (first to 3 round wins). Used from Phase 4 onward.
- Nakama server runtime: Go (decided for Phase 5; not built yet).

## Running the sim tests

The deterministic sim is plain Swift and can be tested without Xcode wherever a
Swift toolchain is installed:

```
cd ArrowClashSim
swift test
```

On macOS you can also open the package in Xcode and run the test target.

### Note on this environment

These tests were authored in a Linux container that has no Swift toolchain
(the toolchain download host is blocked by the environment network policy), so
they could not be executed here. Run `swift test` on your machine to confirm
the Phase 0 acceptance gate. If anything fails to compile or assert, tell me
and I will fix it.

## Building the app

```
brew install xcodegen      # once
cd App && xcodegen generate
open ArrowClash.xcodeproj
```

Or create the project in Xcode by hand and add `ArrowClashSim` as a local
Swift package dependency.