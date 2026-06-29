# ArrowClash - Art Direction

This is the visual plan: what we committed to in-engine now, and how real art
drops in later. All current art is original (procedural shapes, generated
textures, color palettes). No scraped or third-party assets.

## The look we're going for

Neon-tinted dark arenas where light is the hero: glowing arrows streak through
moody, atmospheric backgrounds; characters read as crisp silhouettes with a
soft aura. One signature idea drives it: **arrows and players emit light** in a
darkened space. This is distinct from the flat, brightly-lit look of most mobile
brawlers and ties the visuals to the core fantasy (archery).

### Palette
- Backgrounds: deep desaturated bases (per-map theme), top-lit gradient.
- Accents: electric cyan / blue (UI + default glow), with warm (fire) and cool
  (ice) accents from trails.
- Characters: saturated avatar colors pop against the dark arena.
- Rule of thumb: dark stage, bright actors, one accent hue per screen.

## Shipped in-engine now (no external art)

- Generated textures (`TextureFactory`): soft radial glow, vertical gradients,
  vignette.
- Atmosphere: per-map gradient background + slow drifting motes; full-screen
  vignette for depth.
- Lighting: additive glow auras on players; glowing arrow heads + particle
  trails colored by the equipped trail cosmetic (the signature look).
- Motion: squash-and-stretch on the avatar, landing dust, dash/jump/hit sounds,
  screen shake, hit flash, death particle burst + zoom punch.
- UI: gradient menu with a glowing title; punch-scale countdown.

## Real-art pipeline (next, needs assets)

The renderer is structured so textures swap in without touching gameplay:

- Characters: `AvatarRenderer` builds the avatar from parts. Replace each
  `SKShapeNode` layer with an `SKSpriteNode(texture:)` from a per-slot atlas
  (skin/hair/shirt/pants/head). Animation = swap textures per frame keyed off
  sim velocity/state (run cycle, jump, draw-bow). Keep the same layering + colors
  as tint where art is greyscale-maskable.
- Tiles: give each map theme a tile texture (16x16) instead of a flat color;
  add edge/auto-tiling later.
- Backgrounds: replace the gradient with layered parallax images per theme.

### Choosing a style
Recommended: cohesive **pixel art** (reads great at this scale, cheap to
animate, fits the genre) OR clean **vector/flat with glow** (what we approximate
now). Pick one and stick to it.

### Sourcing (license-safe only)
- CC0 packs: Kenney.nl, OpenGameArt (filter CC0), itch.io CC0 bundles.
- Or commission original sprites to match this palette.
- Do NOT use ripped TowerFall art or scraped "TowerFall-style" assets (IP).

## Possible next signature touches
- True dynamic lighting (arrows cast light on nearby tiles via `SKLightNode`).
- Wrap-edge shimmer when something crosses the screen-wrap seam.
- Slow-mo + desaturated kill-cam replay of the final arrow.
