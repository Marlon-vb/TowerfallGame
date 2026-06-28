# Phase 0 — Project + deterministic sim core

Goal: a deterministic, snapshottable simulation core, proven by a unit test
that replays the same inputs and gets an identical state hash. No rendering.

## What is here

`ArrowClashSim` Swift package (no UIKit/SpriteKit imports):

- `Fixed.swift` — Q16.16 fixed-point number. All gameplay math uses this. The
  only float conversion (`toFloat`) is marked render-only.
- `FixedVec.swift` — 2D fixed-point vector.
- `DeterministicRandom.swift` — seeded xorshift64 PRNG, carried in the state.
- `InputCommand.swift` — per-tick input: a 5-bit button field (left, right,
  jump, dash, shoot) plus an 8-bit aim direction. `shoot`/`aim` are reserved for
  later phases.
- `GameConfig.swift` — every tunable constant in one place (movement feel,
  collision sizes, dash/jump timings, spawns).
- `TileMap.swift` — static solid-tile grid and the single v1 arena. Not part of
  the snapshot because it never changes during a match.
- `PlayerState.swift` / `GameState.swift` — plain value-type state. A copy is a
  snapshot; an assignment is a restore.
- `Simulation.swift` — the 60 Hz `tick`. Run, jump (coyote time + jump buffer +
  jump cut), dash (with cooldown), gravity, swept-AABB tile collision, both-axis
  wrapping.
- `StateHash.swift` — FNV-1a 64-bit hash over the raw integer fields, in fixed
  order. Used to prove determinism and (later) to detect rollback desyncs.

Tests:

- `DeterminismTests` — identical replay produces identical per-tick hashes;
  snapshot-by-copy stays in sync; different inputs diverge (proves the hash is
  actually sensitive).
- `MovementTests` — gravity + landing, run-speed clamp, dash cooldown, jump.

## Determinism rules followed

- No floats in gameplay logic (Q16.16 everywhere; `toFloat` is render-only).
- No `Date`/time, no unseeded randomness (PRNG is seeded and part of state).
- No `Set`/`Dictionary` iteration in gameplay; players iterate by index order.
- No SpriteKit physics or `SKAction` movement.
- Multiplication uses a 64-bit intermediate with `truncatingIfNeeded` so debug
  and release builds behave identically.

## Design decisions made in Phase 0 (please confirm)

These were chosen to keep Phase 0 minimal and are easy to change:

1. Coordinate system is y-down (row 0 is the top), gravity positive. The
   renderer can flip this; it does not affect the sim.
2. Player position is stored as the AABB minimum corner (left, top).
3. Collision is per-axis (X then Y) with single-leading-tile snapping. This is
   exact only while per-tick displacement stays below `tileSize`, which the
   config guarantees (dash 7 px, max fall 8 px, tile 16 px). If a speed is ever
   raised above `tileSize`, the resolver needs sub-stepping. This is flagged in
   the code.
4. Wrapping is decided by the AABB center crossing an edge; a body straddling
   the seam does not collide with tiles on the opposite side. Fine for v1 since
   the wrap edges are open corridors, but worth revisiting if a map ever puts
   solid tiles right at the seam.
5. Dash is horizontal only (uses held left/right, else facing) and floats
   (gravity suppressed) for its duration. 8-direction dash is a later option.

## Proposed feel defaults (in GameConfig, all tunable)

| Constant            | Value        | Notes                          |
|---------------------|--------------|--------------------------------|
| tick rate           | 60 Hz        |                                |
| tile size           | 16 px        |                                |
| player AABB         | 10 x 14 px   |                                |
| run accel (ground)  | 0.6 px/t^2   |                                |
| air accel           | 0.4 px/t^2   |                                |
| run max speed       | 3.0 px/t     |                                |
| ground friction     | 0.8 px/t^2   |                                |
| air friction        | 0.2 px/t^2   |                                |
| gravity             | 0.5 px/t^2   |                                |
| max fall speed      | 8.0 px/t     |                                |
| jump speed          | 7.0 px/t     | apex about 3 tiles             |
| jump cut multiplier | 0.5          | release-to-shorten jump        |
| coyote time         | 6 ticks      | ~0.1 s                         |
| jump buffer         | 6 ticks      | ~0.1 s                         |
| dash speed          | 7.0 px/t     |                                |
| dash duration       | 8 ticks      | ~0.13 s                        |
| dash cooldown       | 30 ticks     | ~0.5 s                         |
| starting arrows     | 3            | used from Phase 1              |

## How to verify the acceptance gate

```
cd ArrowClashSim
swift test
```

Expect all tests to pass, in particular
`DeterminismTests.testIdenticalReplayProducesIdenticalState`.

Note: this could not be run in the build container (no Swift toolchain; the
download host is blocked by the network policy). Please run it locally.
