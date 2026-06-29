# Sprite generation prompt sheet

Copy-paste prompts to generate ArrowClash art. Read the reality check first so
the output is usable.

## Reality check (read this)

- Generic generators (Midjourney/DALL-E/SD) are good at SINGLE images, not
  frame-accurate sprite SHEETS. Use them for one clean pose per item (reference
  or static placeholder), then animate/clean up later.
- For real animated sheets + layered characters, use a game-sprite tool:
  - PixelLab.ai (sprite sheets, animations, character rotations, skeletons)
  - Retro Diffusion (pixel-art model, sheets/animations)
- Tinting: our engine recolors grayscale art. If you generate COLORED parts,
  that's fine too - we just mark those items non-tintable and use the art as-is
  (so e.g. 6 hair colors = 6 generated images instead of 1 + tints).
- After generating: every asset still needs to be cropped, background removed,
  and resized to the spec (48x64 frames) before it drops in. See
  docs/SPRITE_ASSET_SPEC.md.

## Shared style (keep all prompts consistent)

Use this style phrasing in every prompt so items match:

`16-bit SNES pixel-art game sprite, 2D side-view platformer, chibi archer
proportions, bold dark outline, flat cel shading, limited palette, facing
right, full body, centered, isolated on flat #FF00FF magenta background, no
drop shadow, crisp pixels`

Tips:
- "isolated on flat magenta background" makes background removal easy.
- For Midjourney add `--style raw --ar 1:1`. For pixel models, request small
  sizes (e.g. 64x64) and nearest-neighbor upscaling.
- Keep the SAME character base across items (paste a reference image when the
  tool supports it) so layers line up.

---

## Character base (skin layer)

```
16-bit SNES pixel-art game sprite, 2D side-view platformer, chibi archer
proportions, bold dark outline, flat cel shading, facing right, full body,
centered, isolated on flat #FF00FF magenta background, no drop shadow:
a bare base body character - plain skin, simple underwear/shorts, no shirt,
no hair, neutral standing A-pose, arms slightly out. Rendered in GRAYSCALE
(white to dark gray) so it can be recolored in engine.
```

## Hair (one style, recolorable)

```
[shared style], GRAYSCALE: just a HAIR piece for a chibi character head,
short tousled hairstyle, sized to sit on top of a small round head, nothing
else visible, transparent/magenta everywhere except the hair.
```
For multiple hairstyles, swap "short tousled" with: "spiky", "long ponytail",
"buzz cut", "curly afro", "mohawk".

## Shirt (torso clothing only)

```
[shared style], GRAYSCALE: just a simple short-sleeve SHIRT garment for a
chibi character torso, front-ish side view, no body, no head, no arms beyond
sleeves, isolated, magenta background.
```
Design variants: "tank top", "hoodie", "tunic", "armor chestplate".

## Pants (legs clothing only)

```
[shared style], GRAYSCALE: just a pair of simple PANTS for a chibi character
legs, side view, no body, isolated, magenta background.
```
Variants: "shorts", "baggy trousers", "armored greaves".

## Head accessories (full color is fine)

Cap:
```
[shared style]: a small baseball CAP accessory sized for a chibi character
head, side view, isolated on magenta, nothing else.
```
Helmet:
```
[shared style]: a metal knight HELMET accessory sized for a chibi character
head, side view, shiny steel, isolated on magenta, nothing else.
```
Horns:
```
[shared style]: a pair of small curved devil HORNS sized to sit on a chibi
character head, side view, isolated on magenta, nothing else.
```
Halo:
```
[shared style]: a glowing golden HALO ring floating above a chibi character
head, side view, isolated on magenta, nothing else.
```
Crown:
```
[shared style]: a small golden CROWN with jewels sized for a chibi character
head, side view, isolated on magenta, nothing else.
```

## Arrow

```
16-bit pixel-art game sprite, a single ARROW projectile pointing right,
wooden shaft, metal tip, fletching at the back, side view, ~16x4 proportions,
isolated on magenta background, crisp pixels.
```

## World art (later)

Tile (per map theme):
```
16-bit pixel-art seamless TILE, 16x16, stone platform block, top-lit, tileable
edges, [theme] palette (e.g. mossy green / volcanic / icy / temple), isolated.
```
Background:
```
16-bit pixel-art parallax BACKGROUND layer for a 2D arena, [theme] (e.g. dusk
sky, distant mountains, ruins), wide, soft depth, no characters, seamless
horizontally.
```

---

## If you'd rather animate (PixelLab / Retro Diffusion)

These tools can take a character and generate animation frames. Prompt the base
character (above), then ask for the animation set from the spec:
`idle, run, jump, fall, dash, shoot bow, death` as a sprite sheet, 48x64 frames,
facing right, transparent background. Export per-part if the tool supports
layers; otherwise export the full character per preset and we treat presets as
whole-character skins.

## Hand it back to me

Drop exported PNGs into `App/ArrowClash/Sprites/<part>/...` per
docs/SPRITE_ASSET_SPEC.md (or just send them and I'll place + slice them and
build the AtlasSpriteProvider). Tell me whether each part is grayscale
(tintable) or full-color so I set the catalog flags.
