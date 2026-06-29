# skin/ — base body sprites (PixelLab output)

Source: PixelLab `create_character` + `animate_character`.
Character ID: `060a7f8f-8a77-4324-9c3b-32cbc6b3e423`
Generated: 2026-06-29.

User decision (2026-06-29): accept the baked-in hair on the base body and
SKIP the hair layer entirely. The "skin" sheet is treated as
"skin + default short dark hair." No separate hair sheets will be generated.

## Actual output (what the loader has to expect)

- **Frame size:** 68 x 68 px (NOT 48 x 64 like docs/SPRITE_ASSET_SPEC.md).
  PixelLab pads the canvas ~40% beyond the requested 48px so animation
  poses fit without re-cropping. Character itself reads at ~48 px tall
  centered in the 68 x 68 frame.
- **Layout:** one PNG per frame (NOT a row-strip sheet). Naming:
  `<animation>/<direction>_<frameIndex>.png`, frame index 0-based.
- **Color:** full color RGBA — PixelLab ignored the "GRAYSCALE" hint in
  the prompt. Mark the skin catalog entry **non-tintable** when this art
  ships, OR post-process to grayscale offline before catalog flips on tinting.
- **Background:** transparent (alpha).
- **Directions returned:** south, east, north, west (4 dirs) for the
  static rotations. Animations were only generated for `east` (facing-right
  side view); the engine mirrors `east` for left-facing.
- **View:** "side" (eye-level).

## Animations present (all east direction)

Frame counts diverge from docs/SPRITE_ASSET_SPEC.md — PixelLab picks its
own counts per template and v3 customs add a reference frame. The loader
should read from this table, not the spec table.

| Animation | Source                            | Frames | Folder    | Notes                                       |
|-----------|-----------------------------------|--------|-----------|---------------------------------------------|
| idle      | template `breathing-idle`         | 4      | `idle/`   | gentle bob/breath; loops                    |
| run       | template `running-8-frames`       | 8      | `run/`    | full run cycle; loops                       |
| jump      | template `jumping-1`              | 9      | `jump/`   | full takeoff→apex sequence; play once/hold  |
| fall      | v3 custom                         | 5      | `fall/`   | frame 0 = reference pose, 1–4 = animated    |
| dash      | v3 custom                         | 5      | `dash/`   | frame 0 = reference pose, 1–4 = animated    |
| shoot     | v3 custom (bow draw + release)    | 5      | `shoot/`  | NO bow drawn — base body has no bow; layer  |
|           |                                   |        |           | a bow accessory on top for the actual look  |
| die       | template `falling-back-death`     | 7      | `die/`    | knockback → on ground; play once/hold       |

## Files

```
skin/
  NOTES.md
  rotations/                  (static reference, NOT animated)
    south.png  east.png  north.png  west.png
  idle/   east_0.png … east_3.png   (4 frames)
  run/    east_0.png … east_7.png   (8 frames)
  jump/   east_0.png … east_8.png   (9 frames)
  fall/   east_0.png … east_4.png   (5 frames)
  dash/   east_0.png … east_4.png   (5 frames)
  shoot/  east_0.png … east_4.png   (5 frames)
  die/    east_0.png … east_6.png   (7 frames)
```

## Implications for the atlas loader

`AtlasSpriteProvider` (per docs/SPRITE_PIPELINE.md) assumes a single
row-strip sheet per part with a JSON manifest naming row/frames/fps. With
per-frame PNGs, the simplest paths:

1. **Build-time stitcher (recommended):** small script (e.g. `scripts/`)
   reads `skin/<state>/east_*.png`, packs them into one row per state, writes
   `skin/skin.png` + `skin/manifest.json`. Loader stays as-spec.
2. **Loader-side per-frame loading:** extend the provider to accept
   `{folder, fileGlob}` per state and load `SKTexture` per file.

Either way, the **manifest** for skin should be (matching the table above):
```
{
  "frameWidth": 68, "frameHeight": 68, "tintable": false,
  "states": {
    "idle":  { "frames": 4, "fps": 6 },
    "run":   { "frames": 8, "fps": 14 },
    "jump":  { "frames": 9, "fps": 12, "loop": false },
    "fall":  { "frames": 5, "fps": 10, "loop": false },
    "dash":  { "frames": 5, "fps": 16, "loop": false },
    "shoot": { "frames": 5, "fps": 18, "loop": false },
    "die":   { "frames": 7, "fps": 10, "loop": false }
  }
}
```

## Open differences from docs/SPRITE_ASSET_SPEC.md (need a spec update)

- frame size 68×68 vs 48×64
- per-frame PNGs vs row-strip sheet with `row:` indices
- skin is non-tintable (full color) vs grayscale tintable
- frame counts: jump 9 vs 2, fall 5 vs 2, dash 5 vs 2, shoot 5 vs 4, die 7 vs 4
- no hair/shirt/pants/accessory sheets — layered customization deferred,
  ship-as-preset for now

Recommend updating SPRITE_ASSET_SPEC.md to reflect PixelLab's actual output
before building the loader, so the spec and reality match.

## Cost so far

9 generations used (1 create_character + 7 animations + 1 retry on dash).
Of 5000/mo on subscription.
