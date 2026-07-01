# Raw pose drop-zone

Put raw character-pose exports here, one subfolder per animation state. The
normalizer (`tools/normalize_sprites.py`) trims, keys white -> transparent,
scales, and bottom-aligns each into uniform 64x64 frames under
`../skin/<state>/east_<i>.png`.

Naming: files are taken in sorted order, so name them `0.png`, `1.png`, ...
The order is the animation frame order.

```
incoming/
  idle/   0.png                 (relaxed neutral standing)
  run/    0.png  1.png          (contact, passing)
  jump/   0.png                 (rising)
  fall/   0.png                 (descending)
  dash/   0.png                 (horizontal burst)
  shoot/  0.png  1.png          (draw, release)
  die/    0.png                 (knocked back)
```

Raw exports can be any size and may have a white OR transparent background.
You do NOT need to crop or align them - the script handles that. Then run:

```
python3 tools/normalize_sprites.py
```

This folder is staging only; the generated frames in `../skin/` are what ship.
