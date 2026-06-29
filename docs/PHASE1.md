# Phase 1 — Local render harness

Goal: render the sim with SpriteKit and drive it with local touch input. You can
play one character in the arena (run, jump, dash, shoot, reclaim arrows). The
sim stays deterministic and the Phase 0 checks still pass.

## Sim additions (still no UIKit/SpriteKit in the sim)

Arrows are now part of the deterministic simulation:

- `ArrowState.swift` — plain-data arrow (pos, vel, active, stuck, owner, dir).
- `AimTable.swift` — GENERATED baked Q16.16 unit vectors for the 256 aim
  directions. Generated offline so the sim has zero floating-point trig; the
  integers are identical on every device.
- `GameState.arrows` — fixed-capacity pool (`startingArrows * 2` slots, stable
  indices). `PlayerState.arrows` — the quiver count.
- `Simulation.updateArrows` — shoot on the press edge (consume one quiver
  arrow, spawn a projectile aimed by `InputCommand.aim`), move flying arrows
  with a light gravity arc, stick on tile contact (point-vs-tile), and reclaim a
  settled arrow when a player with a non-full quiver walks over it. Both axes
  wrap, like players.
- `StateHash` now folds in the quiver and every arrow slot.

New tunables in `GameConfig`: `arrowSpeed` (7), `arrowGravity` (0.2),
`arrowMaxFallSpeed` (8), `arrowSpawnOffset` (8).

### Determinism notes

- Aiming uses the baked integer table, not runtime `sin`/`cos`.
- Arrow tile collision is point-vs-tile, exact while arrow speed stays below
  `tileSize` (arrow speed 7 < tile 16). Same invariant as player movement.
- Arrow slots use stable indices; `freeArrowSlot` and reclaim iterate in index
  order. The quiver+world arrow count per player is invariant (3), so a free
  slot always exists when a player has an arrow to fire.

## App (SpriteKit, untested in this environment)

- `GameScene.swift` — fixed 60 Hz timestep accumulated from frame time; the sim
  advances in `tick` steps and the render interpolates between the previous and
  current state. SpriteKit only draws; it never moves anything (no SKPhysics, no
  SKAction movement). Tiles are drawn once; player and arrow nodes follow sim
  state each frame. Interpolation snaps across the wrap seam instead of sliding.
- `InputBus.swift` — collects touch input into one `InputCommand` per tick.
- `ControlsOverlay.swift` — left move joystick, Jump/Dash buttons, and an aim
  joystick that fires on release. Screen and sim are both y-down so the drag
  angle maps straight to the 8-bit aim direction.
- `GameView.swift` / `ContentView.swift` — host the scene plus controls.

Player 1 is an idle dummy in Phase 1; the second player becomes real in Phase 2
(rollback) and Phase 3 (online).

## How to verify

Sim (works with Command Line Tools only):

```
cd ArrowClashSim
swift run ArrowClashSimCheck
```

Expect `ALL CHECKS PASSED`, now including the two Combat checks.

App (needs full Xcode):

```
brew install xcodegen        # once
cd App && xcodegen generate
open ArrowClash.xcodeproj     # run on a device or simulator
```

Acceptance is subjective: it should feel controllable. The feel constants live
in `GameConfig`; tell me what to adjust (accel, jump height, dash distance,
arrow speed/arc) and I will tune them.

### Not yet (later phases, intentionally absent)

- Second human/remote player, rollback (Phase 2), online (Phase 3).
- One-hit death resolution, rounds, scoring (Phase 4).
- Progression, cosmetics (Phase 5). Polish, audio, particles (Phase 6).
