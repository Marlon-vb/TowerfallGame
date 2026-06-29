# Layered Sprite Pipeline - Plan

Goal: animate characters from layered, tintable part-sprites composited at
runtime, so we never pre-bake every avatar combination, and real art drops in
behind a provider protocol without touching gameplay.

Render-only: nothing here affects the deterministic sim or netcode. Both clients
pick animation state from the same synced sim state, so they look consistent.

## Core idea

An avatar is a stack of layers drawn back-to-front. Each layer is one body part
with its own sprite sheet. All parts share the SAME animation timeline (frame k
of "run" lines up across every layer), so a single frame index drives the whole
character. Color variants come from tinting grayscale art, not extra sheets.

Combinatorics solved: 8 hair colors = 1 grayscale hair sheet + 8 tints, not 8
sheets. New item = one more layer/texture.

## Layers (back to front) and avatar-slot mapping

1. pants   (slot: pants, tintable)
2. shirt   (slot: shirt, tintable)
3. skin    (slot: skin,  tintable)   -- head/body base
4. hair    (slot: hair,  tintable)
5. head    (slot: head accessory; tintable OR full-color per item)

(trail is arrow FX, not a body layer. A bow/arms layer can be added later.)

## Animation states (shared frame timeline)

idle, run, jump (rising), fall, dash, shoot (one-shot), hurt/die (one-shot).
Each state has a fixed frame count; every part sheet must match those counts.
State is chosen each render frame from sim state:
- onGround + |vx|~0            -> idle
- onGround + |vx| > threshold  -> run (frame advances with speed/time)
- !onGround + vy < 0           -> jump
- !onGround + vy > 0           -> fall
- dashActiveTimer > 0          -> dash
- shoot fired this tick        -> shoot (one-shot, then back)
- not alive                    -> die (one-shot, then hidden)
Facing flips the whole node on X (from sim player.facing). Squash/stretch stays.

## Architecture

- `AnimState` enum.
- `SpriteProvider` protocol:
  - `frameCount(part, state) -> Int`
  - `texture(part, itemId, state, frame) -> SKTexture`  (grayscale/art)
  - `tint(part, itemId) -> SKColor?`  (nil = use texture as-is)
- `PlaceholderSpriteProvider` (now): generates simple animated blocky frames
  procedurally (run cycle, head bob, jump/fall poses, dash lean, shoot recoil,
  death). Grayscale textures cached + tinted per node by item color.
- `AtlasSpriteProvider` (later): loads real PNG atlases + a JSON manifest.
- `AnimatedAvatarNode` (SKNode): builds one SKSpriteNode per layer for an
  Avatar; `update(state:dt:facing:)` advances frame, sets textures + tints,
  flips for facing. Replaces the static AvatarRenderer in-match.
- `AvatarAnimator`: maps (PlayerState, events) -> AnimState + frame timing.

## Real-art manifest (for AtlasSpriteProvider, when art exists)

Per part, a PNG sheet + JSON:
```
{
  "frameWidth": 32, "frameHeight": 32,
  "tintable": true,
  "states": {
    "idle": { "row": 0, "frames": 2, "fps": 4 },
    "run":  { "row": 1, "frames": 6, "fps": 12 },
    "jump": { "row": 2, "frames": 1 },
    "fall": { "row": 3, "frames": 1 },
    "dash": { "row": 4, "frames": 2, "fps": 16 },
    "shoot":{ "row": 5, "frames": 3, "fps": 18 },
    "die":  { "row": 6, "frames": 4, "fps": 12 }
  }
}
```
Folder: `App/ArrowClash/Sprites/<part>/<itemId>.png` (+ shared manifest per
part). Tintable parts ship grayscale; full-color items set `tintable:false`.

## Build steps

1. Model + protocol: `AnimState`, `SpriteProvider`, layer/slot mapping. [me]
2. `PlaceholderSpriteProvider`: procedural animated part frames (cached, tinted). [me]
3. `AnimatedAvatarNode`: layer compositor + frame animator + facing/squash. [me]
4. `AvatarAnimator`: sim-state -> AnimState + timing; wire shoot/die one-shots
   into the existing event detection. [me]
5. GameScene integration: swap static avatar for AnimatedAvatarNode; update each
   render frame. [me]
6. (later) `AtlasSpriteProvider` + manifest + Sprites/ folder; flip provider. [me + art]
7. (later) Use a rendered frame for the Customize/Store preview. [me]

Steps 1-5 ship animated characters NOW with placeholders; 6-7 land when real
art is sourced. No sim/netcode changes at any step.

## Acceptance (steps 1-5)

In a match, characters visibly idle-bob, run-cycle, show jump/fall/dash poses,
recoil on shoot, and play a death animation, with correct facing - all from
placeholder art, with real art swappable via the provider.
```
