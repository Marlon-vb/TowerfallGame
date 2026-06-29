# skin/ — base body sprites (PixelLab output)

Source: PixelLab `create_character` + `animate_character` (template `breathing-idle`).
Character ID: `060a7f8f-8a77-4324-9c3b-32cbc6b3e423`
Generated: 2026-06-29.

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
- **Directions returned:** south, east, north, west (4 dirs).
  `east` is the facing-right side view used for in-game rendering;
  the engine mirrors `east` for left-facing.
- **View:** "side" (eye-level).

## Animations present

| Animation | Template            | Frames | Dir generated | Notes                |
|-----------|---------------------|--------|---------------|----------------------|
| idle      | `breathing-idle`    | 4      | east          | gentle bob/breath    |

## Files

```
skin/
  NOTES.md                  (this file)
  rotations/
    south.png  east.png  north.png  west.png   (single static reference per dir)
  idle/
    east_0.png  east_1.png  east_2.png  east_3.png   (4 idle frames, east)
```

## Issues flagged for review (before generating more animations)

1. **Hair baked in.** The body sprite has short dark hair, even though the
   prompt asked for "no hair" (hair is supposed to be a separate layer).
   PixelLab's character template seems to always include hair on humanoids.
   Options: (a) accept it — treat the skin sheet as "skin + default hair"
   and skip the hair layer entirely; (b) regenerate with `create_character_state`
   asking to remove hair / bald; (c) drop layered hair and ship presets only.
2. **Full color, not grayscale.** Per pipeline, skin is tintable. Either
   convert to grayscale post-hoc or mark non-tintable.
3. **Per-frame PNGs, not row-strip.** AtlasSpriteProvider in
   docs/SPRITE_PIPELINE.md expects a single sheet per part with rows = states.
   Loader needs either (a) a stitcher step to combine per-frame PNGs into a
   sheet at build time, or (b) extend the provider to accept per-frame files.
4. **48 x 64 spec vs 68 x 68 actual.** Either update SPRITE_ASSET_SPEC.md to
   match PixelLab's output, or post-crop frames to 48 x 64. The character
   itself fits in ~48 px so cropping is feasible but loses the animation
   padding PixelLab adds.

## Cost so far

2 generations used (1 for create_character standard mode, 1 for one-direction
template idle animation). Of 5000/mo on subscription.
