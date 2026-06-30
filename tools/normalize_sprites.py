#!/usr/bin/env python3
"""Normalize raw character pose exports into uniform, aligned sprite frames.

Workflow:
  1. Drop raw exports (any size, white OR transparent background) into
       App/ArrowClash/Sprites/incoming/<state>/*.png
     where <state> is one of: idle run jump fall dash shoot die
     Files within a state are taken in sorted filename order and become
     east_0.png, east_1.png, ... so name them 0.png, 1.png (or a.png, b.png).
  2. Run:  python3 tools/normalize_sprites.py
  3. Output uniform frames land in App/ArrowClash/Sprites/skin/<state>/east_<i>.png

What it does per image:
  - keys a white background to transparent (flood fill from the corners so
    interior whites are kept), if the image is not already transparent;
  - trims to the visible bounding box;
  - scales (nearest-neighbor) to fit the target frame, preserving aspect;
  - centers horizontally and bottom-aligns the feet to a shared baseline,
    so every pose stands on the same ground line and animations don't jitter.

No external editor needed. Pure Pillow.
"""

import sys
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
INCOMING = ROOT / "App/ArrowClash/Sprites/incoming"
SKIN = ROOT / "App/ArrowClash/Sprites/skin"

STATES = ["idle", "run", "jump", "fall", "dash", "shoot", "die"]

# Target output frame. Square keeps the engine's facing-flip math simple.
FRAME = 64
# Fraction of frame height the character body should fill (head-to-feet).
FILL = 0.92
# Pixels of empty space below the feet inside the frame.
FOOT_MARGIN = 1
# How close to white counts as background when keying (0-255 per channel).
WHITE_TOL = 60
# Alpha at/above this is treated as solid; below is dropped. Binarizing gives
# crisp pixel edges and removes the faint anti-alias haze some exports carry
# all the way out to the canvas edges (which would otherwise inflate the bbox).
ALPHA_THR = 96
# If fewer than this fraction of pixels are already transparent, treat the image
# as having a solid (white) background that needs keying.
TRANSPARENT_FRACTION = 0.20


def key_white_background(img: Image.Image) -> Image.Image:
    """Make a white background transparent via flood fill from the corners.

    Flood fill (not a global white->alpha) so interior white pixels that are
    enclosed by the outline are preserved. Pixels reachable from a corner while
    staying within WHITE_TOL of white are cleared to alpha 0.
    """
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()

    def is_whiteish(p):
        return p[0] >= 255 - WHITE_TOL and p[1] >= 255 - WHITE_TOL and p[2] >= 255 - WHITE_TOL

    # If the corners are already transparent, assume the art has real alpha.
    corners = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    if all(px[c][3] == 0 for c in corners):
        return img

    seen = bytearray(w * h)
    q = deque()
    for cx, cy in corners:
        if is_whiteish(px[cx, cy]) and not seen[cy * w + cx]:
            seen[cy * w + cx] = 1
            q.append((cx, cy))
    while q:
        x, y = q.popleft()
        px[x, y] = (0, 0, 0, 0)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx]:
                if is_whiteish(px[nx, ny]):
                    seen[ny * w + nx] = 1
                    q.append((nx, ny))
    return img


def clean_alpha(img: Image.Image) -> Image.Image:
    """Return an RGBA image with a crisp, haze-free alpha channel.

    Keys a white background only when the image is mostly opaque (so images that
    already ship real transparency are trusted as-is), then binarizes alpha at
    ALPHA_THR to drop faint anti-alias haze and give clean pixel edges.
    """
    img = img.convert("RGBA")
    w, h = img.size
    transparent = img.getchannel("A").histogram()[0]
    if transparent < w * h * TRANSPARENT_FRACTION:
        img = key_white_background(img)
    mask = img.getchannel("A").point(lambda v: 255 if v >= ALPHA_THR else 0)
    img.putalpha(mask)
    return img


def normalize(img: Image.Image) -> Image.Image:
    img = clean_alpha(img)
    bbox = img.getbbox()
    if bbox is None:
        raise ValueError("image is empty after background removal")
    cropped = img.crop(bbox)
    cw, ch = cropped.size

    target_h = int(FRAME * FILL)
    scale = target_h / ch
    # Do not let width overflow the frame either.
    if cw * scale > FRAME:
        scale = FRAME / cw
    nw = max(1, round(cw * scale))
    nh = max(1, round(ch * scale))
    resized = cropped.resize((nw, nh), Image.NEAREST)

    frame = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    x = (FRAME - nw) // 2
    y = FRAME - FOOT_MARGIN - nh
    frame.paste(resized, (x, y), resized)
    return frame


def main() -> int:
    if not INCOMING.exists():
        print(f"no staging folder: {INCOMING}")
        print("create it and drop raw pose PNGs into incoming/<state>/")
        return 1

    total = 0
    for state in STATES:
        src = INCOMING / state
        if not src.is_dir():
            continue
        files = sorted(p for p in src.iterdir()
                       if p.suffix.lower() == ".png" and not p.name.startswith("."))
        if not files:
            continue
        out = SKIN / state
        out.mkdir(parents=True, exist_ok=True)
        # Clear stale frames so old art never bleeds through.
        for old in out.glob("east_*.png"):
            old.unlink()
        for i, f in enumerate(files):
            frame = normalize(Image.open(f))
            dst = out / f"east_{i}.png"
            frame.save(dst)
            print(f"{state}/{f.name} -> skin/{state}/east_{i}.png")
            total += 1
        print(f"  [{state}] {len(files)} frame(s)")

    if total == 0:
        print("no input PNGs found under incoming/<state>/")
        return 1
    print(f"\ndone: {total} frame(s) at {FRAME}x{FRAME}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
