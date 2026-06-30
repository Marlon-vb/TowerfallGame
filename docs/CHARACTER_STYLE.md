# Character art style (locked)

Direction chosen from reference: small, cute CHIBI mini-sprites (think tiny
overworld/brawler minis - One Piece mini crew, ShouHex critters, small RPG
overworld characters).

## The look

- Tiny chibi proportions: BIG round head (~45-55% of total height), small body,
  stubby limbs. Head is the focal point.
- Small canvas, low resolution on purpose - reads as cute pixel art, not a
  detailed character.
- Bold single-color dark outline around the whole silhouette.
- Flat / minimal shading (1-2 tones max), limited palette.
- Clean, readable silhouette over fine detail.
- Side view, facing right (engine mirrors for left).

NOT the previous output: avoid tall, detailed, realistic proportions and heavy
shading.

## Target specs for PixelLab

- Frame size: 32 x 32 px (small). Character fills most of the frame.
- Proportions: chibi / big head (state this in the description).
- detail: low. shading: flat (or "basic"). outline: single-color dark.
- Limited palette.
- Same animation set + folder structure as before so the loader only needs the
  frame-size constant updated:
  idle, run, jump, fall, dash, shoot, die -> `Sprites/skin/<state>/east_<i>.png`.

## Description seed (for create_character)

"tiny cute chibi character, very big round head, small stubby body, bold black
outline, flat shading, limited palette, simple minimal detail, side view facing
right, retro pixel art mini-sprite"

## Canonical base prompt (reuse VERBATIM for consistency)

Use this exact description for the base, and reuse the same style/proportion
sentences for every pose and every layer so nothing drifts between generations.
After a good base is made, also UPLOAD that image back as a reference for each
subsequent generation.

```
A single 2D pixel-art character sprite, full body, side-view profile facing
RIGHT, standing in a relaxed neutral idle pose.

Cute retro indie-game pixel art style inspired by classic RPG and farming-sim
NPC sprites. Character proportions are approximately 2 heads tall, with a very
large rounded head (about half the total height), tiny torso, short chunky arms,
and stubby legs. Clean readable silhouette designed for a 16x24 to 24x24 pixel
sprite.

Pixel art only. Crisp square pixels. No anti-aliasing. No smoothing. No
painterly effects. Limited palette of roughly 10-16 colours. Flat colours with
only one simple shadow tone. Thick dark navy outline surrounding the entire
silhouette with clean internal outlines.

Character is a blank modular base body intended for later clothing
customization: bald head, plain skin, neutral friendly face, two tiny black
eyes, tiny single-pixel nose, no mouth, no eyebrows, no shirt, light grey
shorts, bare feet, no shoes, no accessories, no tattoos. Arms resting naturally
at the sides, slightly separated from the torso to allow clothing overlays.

Character centered in frame, full body visible head to feet, feet near the
bottom edge, SAME zoom/scale in every image. Background flat solid magenta
(#FF00FF). No shadow. No ground. No text. No extra objects.

Consistent side-view template, perfectly vertical posture, clean pixel
alignment so future hair, helmets, shirts, gloves, pants and shoes layer
directly over the base without changing proportions.
```

Locked canon (keep identical everywhere): ~2 heads tall, head ~50% height;
thick DARK NAVY outline; 10-16 colour flat palette + one shadow tone; two tiny
black eyes, single-pixel nose, no mouth; magenta background; side profile
facing right; same zoom with feet near the bottom edge.

## Honest note on AI consistency

Separate generations won't be pixel-perfect across frames/layers. Expect to:
downscale to ~24px (nearest-neighbor), then align and clean each frame/layer in
a pixel editor (Aseprite/Photoshop) so layers register and animations don't
jitter. Reusing the approved base image as a reference each time minimizes this.

## After regenerating

Update `Sprites/skin/NOTES.md` with the new frame size and per-state frame
counts. The loader (`FileSpriteProvider`) then just needs `nativeFrameSize`
updated to match (and frame counts if they changed). Keep folder/file naming
identical.
