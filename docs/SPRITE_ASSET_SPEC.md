# Sprite Asset Spec - what to draw

This is the exact art you need for full character customization, and how to lay
it out so it drops into the existing layered pipeline (docs/SPRITE_PIPELINE.md).

Key idea: parts are layered and tinted, so COLOR variants are free (one sheet,
many tints). You only make a new sheet for a new SHAPE (a new hairstyle, a new
accessory), not for a new color. That's why the whole catalog below is ~9 sheets.

---

## 1. Canonical specs (every sheet follows these)

- Format: PNG, 32-bit RGBA, transparent background.
- Frame size: 48 x 64 px (width x height). Portrait, fits a humanoid.
- Grid sheet: one ROW per animation state, columns are frames left-to-right.
  Unused columns in a row are left fully transparent.
- Sheet size: 8 columns x 7 rows = 384 x 448 px (8 = the longest animation).
- Registration: draw the character in the SAME position in every frame
  (centered horizontally, consistent ground line). All parts must register to
  the same skeleton so layers stack and facing-flip stays aligned. Easiest way:
  draw the skin/base body first, then draw hair/shirt/pants/heads on top of those
  exact frames and export each as its own layer.
- Pixel art: keep it crisp; we render with nearest-neighbor filtering.
- Facing: draw the character facing RIGHT. The engine mirrors for left.

## 2. Animation table (IDENTICAL across ALL sheets)

Every part sheet must use this exact row order and frame counts, so frame k of
"run" lines up across skin/shirt/pants/hair/head.

| Row | State | Frames | FPS | Loop? | Notes                                  |
|-----|-------|--------|-----|-------|----------------------------------------|
| 0   | idle  | 4      | 6   | yes   | gentle breathing/bob                   |
| 1   | run   | 8      | 14  | yes   | full run cycle (contact/passing poses) |
| 2   | jump  | 2      | 10  | hold  | rising; legs tucked                    |
| 3   | fall  | 2      | 10  | hold  | descending; legs reaching              |
| 4   | dash  | 2      | 16  | hold  | horizontal burst / lean                |
| 5   | shoot | 4      | 18  | once  | draw, hold, release, recover           |
| 6   | die   | 4      | 10  | hold  | knockback then down                    |

(If you want to start smaller, fewer frames per row is fine - just keep the
SAME counts across every part sheet. We can update the manifest to match.)

## 3. Layers (back to front) and what each sheet contains

1. pants  - lower body clothing only (legs), transparent elsewhere
2. shirt  - torso clothing only
3. skin   - the base body + head + arms (the "naked" character); this is the
            anchor everyone else draws over
4. hair   - hair only, on the head
5. head   - head accessory only (hat/helmet/etc.), on top of hair

Trail is NOT a body sheet - it's the arrow's color/effect (see section 6).

## 4. The sheets you actually need (full customization = ~9 sheets)

| Sheet            | Count | Covers (via tinting)                      |
|------------------|-------|-------------------------------------------|
| skin (base body) | 1     | all 5 skin tones (tint)                   |
| hair (style 1)   | 1     | all hair colors (tint): black/brown/...   |
| shirt (style 1)  | 1     | all shirt colors (tint)                   |
| pants (style 1)  | 1     | all pants colors (tint)                   |
| head: cap        | 1     | (tint or full-color)                      |
| head: helmet     | 1     |                                           |
| head: horns      | 1     |                                           |
| head: halo       | 1     |                                           |
| head: crown      | 1     |                                           |

That's 9 sheets and it already covers every avatar combination in the current
catalog. "head: none" needs no art.

Adding content later:
- New COLOR of an existing part -> 0 new art (just a catalog tint entry).
- New hairSTYLE / shirt design / pants design -> +1 sheet each.
- New accessory (mask, cape-as-head, etc.) -> +1 sheet each.

## 5. Tintable vs full-color

- Tintable parts (skin, hair, shirt, pants, simple accessories): draw in
  GRAYSCALE with real shading - mid-gray = base tone, lighter = highlights,
  darker = shadow. The engine multiplies your chosen color over it, so one
  grayscale sheet yields every color and keeps the shading. Aim for a value
  range roughly 40%-90% gray (avoid pure white/black so tints read well).
- Full-color items (a metallic helmet, a rainbow hat): draw in full color and
  mark the catalog entry non-tintable; the engine shows it as-is.

## 6. Arrows, FX, world (not character sheets)

- Arrow: a small sprite (~16 x 4) facing right, plus a "stuck" variant. The
  trail cosmetic is rendered as the arrow's color/particles, not a sheet.
- FX: small particle textures (dust, impact spark, death burst) ~8 x 8.
- Tiles: 16 x 16 tile per map theme (+ optional edge tiles for auto-tiling).
- Backgrounds: 1-3 parallax layers per theme (wide images).
(Sections 1-5 are the priority for character customization; these come with
the world-art pass.)

## 7. File + manifest convention

```
App/ArrowClash/Sprites/
  skin/skin.png          + skin/manifest.json
  hair/style1.png        + hair/manifest.json
  shirt/style1.png       + shirt/manifest.json
  pants/style1.png       + pants/manifest.json
  head/cap.png head/helmet.png head/horns.png head/halo.png head/crown.png
       + head/manifest.json
  arrow/arrow.png arrow/stuck.png
```

manifest.json per part (matches docs/SPRITE_PIPELINE.md):
```
{
  "frameWidth": 48, "frameHeight": 64, "tintable": true,
  "states": {
    "idle":  { "row": 0, "frames": 4, "fps": 6 },
    "run":   { "row": 1, "frames": 8, "fps": 14 },
    "jump":  { "row": 2, "frames": 2, "fps": 10 },
    "fall":  { "row": 3, "frames": 2, "fps": 10 },
    "dash":  { "row": 4, "frames": 2, "fps": 16 },
    "shoot": { "row": 5, "frames": 4, "fps": 18 },
    "die":   { "row": 6, "frames": 4, "fps": 10 }
  }
}
```
Catalog mapping: each item id in nakama/catalog.go + Cosmetics.swift names which
sheet (and tint) it uses. Colors stay in the catalog; art stays in the sheets.

## 8. Deliverables checklist

- [ ] skin.png (base body, grayscale, 384x448, animation table above)
- [ ] hair style sheet(s) (grayscale)
- [ ] shirt style sheet(s) (grayscale)
- [ ] pants style sheet(s) (grayscale)
- [ ] head accessory sheets: cap, helmet, horns, halo, crown
- [ ] arrow.png (+ stuck), FX particles (later), tiles/backgrounds (later)
- [ ] manifest.json per part

## 9. What I do once art lands

Build `AtlasSpriteProvider` that loads these sheets + manifests, slices frames,
and tints per catalog color. Then flip one line in GameScene from
`PlaceholderSpriteProvider` to the atlas provider - no other changes. The
placeholder art keeps the game playable until then.
