# ArrowClash - Character Art Commission Brief

Hand this single file to a pixel artist. It defines a SIDE-VIEW, MODULAR,
chibi character set for a 2D platformer. Everything is drawn to layer and
animate together.

## Style (must match)

- Tiny CUTE CHIBI: big round head (~45-55% of height), small stubby body.
- Bold single-color dark outline; flat / minimal shading (1-2 tones); limited
  palette. Clean readable silhouette over detail.
- SIDE VIEW, profile, facing RIGHT (we mirror for left in-engine).
- Reference vibe: small overworld/brawler minis (cute, simple, high contrast).

## Modular layers (each drawn as its OWN transparent sheet, same skeleton)

Back-to-front draw order:
1. pants (legs clothing only)
2. shirt (torso clothing only)
3. skin (base body + head + arms - the anchor everyone else registers to)
4. hair (on the head)
5. head accessory (hat/helmet/etc., on top)

All layers MUST share the exact same frames/poses so they stack perfectly.
Easiest workflow: draw the skin base first, then paint each other layer on
top of those exact frames and export per layer.

## Frame + sheet format

- Frame size: 48 x 48 px, transparent PNG. Character centered, consistent
  ground line every frame.
- Deliver as a row-strip sheet per layer (one row per animation) OR per-frame
  PNGs in folders - either is fine; just document the layout.
- Pixel art, crisp (no anti-aliasing/blur).

## Animations (same set + counts across every layer)

| State | Frames | Notes                          |
|-------|--------|--------------------------------|
| idle  | 4      | gentle breathing/bob, loop     |
| run   | 8      | full run cycle, loop           |
| jump  | 2      | rising, legs tucked            |
| fall  | 2      | descending, legs reaching      |
| dash  | 2      | horizontal burst / lean        |
| shoot | 4      | draw bow, hold, release, recover (arms/hands; bow is a separate overlay later) |
| die   | 4      | knockback then down            |

(If the artist prefers different counts, that's OK - just keep them IDENTICAL
across all layers and tell us the counts.)

## Tinting (saves you tons of variants)

Draw the tintable layers (skin, hair, shirt, pants, simple accessories) in
GRAYSCALE with shading (mid-gray base, lighter highlights, darker shadows,
roughly 40-90% value). The engine recolors them, so ONE grayscale sheet covers
every color. Multi-color items (e.g. metal helmet) can be full color - flag
those as "non-tintable."

## What to deliver (covers ALL combinations - ~9 sheets)

- skin base body (grayscale) x1
- hair style(s) (grayscale) - 1 sheet per style
- shirt design(s) (grayscale) - 1 per design
- pants design(s) (grayscale) - 1 per design
- head accessories: cap, helmet, horns, halo, crown (1 sheet each)
- (optional now) a bow overlay for the shoot pose; arrow sprite

Color variants are NOT separate art - they're engine tints. New color = free.

## Delivery

PNGs + a short note of: frame size, frames per animation, layer order, and
which layers are tintable vs full-color. Drop into
`App/ArrowClash/Sprites/<part>/...` (or send a zip). We wire it in.

## For posting a commission request (paste this)

> Looking for a pixel artist to make a SIDE-VIEW, MODULAR chibi character set
> for a 2D platformer: a base body + separate layered hair/shirt/pants + a few
> head accessories, all 48x48, facing right, in cute chibi style (big head,
> bold outline, flat shading). Animations: idle, run, jump, fall, dash, shoot
> (bow draw), die - same frame counts across all layers so they stack.
> Tintable layers in grayscale for in-engine recoloring. Full spec provided.
