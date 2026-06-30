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

## After regenerating

Update `Sprites/skin/NOTES.md` with the new frame size and per-state frame
counts. The loader (`FileSpriteProvider`) then just needs `nativeFrameSize`
updated to match (and frame counts if they changed). Keep folder/file naming
identical.
