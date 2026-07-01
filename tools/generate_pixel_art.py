#!/usr/bin/env python3
"""Generate the game's pixel art: layered chibi characters, map tilesets, arrow.

Everything is drawn programmatically so the style is perfectly consistent
(tiny big-head chibi, bold dark outline, flat shading - see docs/ART_DIRECTION)
and every layer of every frame is pixel-registered by construction.

Outputs (all committed):
  App/ArrowClash/Sprites/chibi/<layer>/<state>/east_<i>.png   character layers
      layers: skin, hair, shirt, pants, head_cap, head_helmet, head_horns,
              head_halo, head_crown
      states/frames: idle 2, run 4, jump 1, fall 1, dash 1, shoot 2, die 1
      Tintable layers are GRAYSCALE (the engine tints by equipped item color);
      outlines/eyes are near-black so they stay dark after tinting.
  App/ArrowClash/Sprites/tiles/theme<id>/t<mask>.png          map tilesets
      mask = 4-bit solid-neighbor mask (1=N, 2=E, 4=S, 8=W); exposed edges get
      an outline + top lip, exposed corners are rounded.
  App/ArrowClash/Sprites/fx/arrow.png                          arrow sprite

Run: python3 tools/generate_pixel_art.py
"""

from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SPRITES = ROOT / "App/ArrowClash/Sprites"

# ---------------------------------------------------------------------------
# Shared drawing helpers
# ---------------------------------------------------------------------------

OUTLINE = (40, 36, 58, 255)      # dark navy, survives engine tinting
EYE = (24, 22, 34, 255)

# Grayscale values for tintable layers (engine multiplies toward item color).
G_BASE = 208
G_SHADE = 156
G_LIGHT = 238


def gray(v):
    return (v, v, v, 255)


class Canvas:
    def __init__(self, w, h):
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.px = self.img.load()
        self.w, self.h = w, h

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[x, y]
        return (0, 0, 0, 0)

    def outline(self):
        """Draw OUTLINE on every transparent pixel 4-adjacent to a filled one."""
        edges = []
        for y in range(self.h):
            for x in range(self.w):
                if self.get(x, y)[3] == 0:
                    for nx, ny in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
                        if self.get(nx, ny)[3] != 0 and self.get(nx, ny) != OUTLINE:
                            edges.append((x, y))
                            break
        for x, y in edges:
            self.put(x, y, OUTLINE)

    def save(self, path):
        path.parent.mkdir(parents=True, exist_ok=True)
        self.img.save(path)


# ---------------------------------------------------------------------------
# Chibi character: shared skeleton
# ---------------------------------------------------------------------------
# 24x24 canvas, y down, character faces RIGHT (engine mirrors for left).
# Base geometry (idle frame 0):
#   head  x5..17, y4..14 (13x11, rounded)   eyes shifted right (facing)
#   torso x8..15, y15..18                    (shirt layer draws this)
#   arms  x6..7 / x16..17, y15..18           (skin layer)
#   legs  x9..11 / x13..15, y19..20          (pants layer)
#   feet  same columns, y21                  (skin layer, peeking under pants)

SIZE = 24

# Per-frame skeleton offsets: (head, body, armL, armR, legL, legR) as (dx, dy),
# plus a set of flags for pose extras.
POSES = {
    ("idle", 0): dict(head=(0, 0), body=(0, 0), armL=(0, 0), armR=(0, 0),
                      legL=(0, 0), legR=(0, 0), flags=set()),
    ("idle", 1): dict(head=(0, 1), body=(0, 1), armL=(0, 1), armR=(0, 1),
                      legL=(0, 0), legR=(0, 0), flags=set()),
    ("run", 0): dict(head=(1, 0), body=(0, 0), armL=(0, -1), armR=(1, 1),
                     legL=(0, -1), legR=(0, 0), flags=set()),
    ("run", 1): dict(head=(1, -1), body=(0, -1), armL=(0, 0), armR=(1, 0),
                     legL=(0, 0), legR=(0, 0), flags=set()),
    ("run", 2): dict(head=(1, 0), body=(0, 0), armL=(0, 1), armR=(1, -1),
                     legL=(0, 0), legR=(0, -1), flags=set()),
    ("run", 3): dict(head=(1, -1), body=(0, -1), armL=(0, 0), armR=(1, 0),
                     legL=(0, 0), legR=(0, 0), flags=set()),
    ("jump", 0): dict(head=(0, -1), body=(0, -1), armL=(-1, -2), armR=(1, -2),
                      legL=(1, -2), legR=(-1, -2), flags=set()),
    ("fall", 0): dict(head=(0, 0), body=(0, 0), armL=(-1, -1), armR=(1, -1),
                      legL=(-1, 0), legR=(1, 0), flags=set()),
    ("dash", 0): dict(head=(2, 1), body=(1, 1), armL=(-1, 1), armR=(-2, 1),
                      legL=(-1, 0), legR=(-2, 0), flags={"speed"}),
    ("shoot", 0): dict(head=(1, 0), body=(0, 0), armL=(0, 0), armR=(0, 0),
                       legL=(0, 0), legR=(0, 0), flags={"bow_draw"}),
    ("shoot", 1): dict(head=(0, 0), body=(0, 0), armL=(0, 0), armR=(0, 0),
                       legL=(0, 0), legR=(0, 0), flags={"bow_release"}),
    ("die", 0): dict(head=(1, 2), body=(0, 1), armL=(-1, -1), armR=(1, -1),
                     legL=(0, 0), legR=(1, -1), flags={"dead_eyes"}),
}

STATES = [("idle", 2), ("run", 4), ("jump", 1), ("fall", 1),
          ("dash", 1), ("shoot", 2), ("die", 1)]


def head_box(p):
    dx, dy = p["head"]
    return (5 + dx, 4 + dy, 17 + dx, 14 + dy)


def draw_head_shape(c, x0, y0, x1, y1, fill, shade):
    """Rounded head block with bottom/left shading."""
    c.rect(x0, y0, x1, y1, fill)
    # Round the corners (cut 2px steps).
    for cx, cy in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
        c.put(cx, cy, (0, 0, 0, 0))
    for cx, cy in ((x0 + 1, y0), (x0, y0 + 1), (x1 - 1, y0), (x1, y0 + 1),
                   (x0 + 1, y1), (x0, y1 - 1), (x1 - 1, y1), (x1, y1 - 1)):
        c.put(cx, cy, (0, 0, 0, 0)) if False else None
    # Softer round: clear one more pixel next to each corner on top.
    for cx, cy in ((x0 + 1, y0), (x1 - 1, y0)):
        c.put(cx, cy, fill)  # keep top edge full apart from the corner cut
    # Shade: bottom row + left column.
    for x in range(x0 + 1, x1):
        c.put(x, y1, shade)
    for y in range(y0 + 2, y1):
        c.put(x0 + 1, y, shade)


def draw_skin(c, p):
    """Head + face + arms + feet (+ pose extras). Grayscale, tinted by skin."""
    hx0, hy0, hx1, hy1 = head_box(p)
    draw_head_shape(c, hx0, hy0, hx1, hy1, gray(G_BASE), gray(G_SHADE))

    # Ear nub on the left (back of head, since we face right).
    c.rect(hx0 - 1, hy0 + 5, hx0 - 1, hy0 + 6, gray(G_SHADE))

    # Face: two eyes shifted toward facing (right).
    if "dead_eyes" in p["flags"]:
        for ex in (hx0 + 5, hx1 - 3):
            ey = hy0 + 5
            c.put(ex, ey, EYE); c.put(ex + 1, ey + 1, EYE)
            c.put(ex + 1, ey, EYE); c.put(ex, ey + 1, EYE)
    else:
        for ex in (hx0 + 5, hx1 - 3):
            c.rect(ex, hy0 + 5, ex, hy0 + 6, EYE)
    # Tiny mouth line only on die (shock); none otherwise (ref style).

    bdx, bdy = p["body"]

    # Arms (skip normal right arm when the bow poses replace it).
    ax, ay = p["armL"]
    c.rect(6 + bdx + ax, 15 + bdy + ay, 7 + bdx + ax, 18 + bdy + ay, gray(G_BASE))
    if "bow_draw" in p["flags"] or "bow_release" in p["flags"]:
        # Extended right arm holding the bow.
        c.rect(16 + bdx, 15 + bdy, 20 + bdx, 16 + bdy, gray(G_BASE))
    else:
        ax, ay = p["armR"]
        c.rect(16 + bdx + ax, 15 + bdy + ay, 17 + bdx + ax, 18 + bdy + ay, gray(G_BASE))

    # Feet peeking under the pants.
    lx, ly = p["legL"]
    c.rect(9 + lx, 21 + ly, 11 + lx, 21 + ly, gray(G_BASE))
    lx, ly = p["legR"]
    c.rect(13 + lx, 21 + ly, 15 + lx, 21 + ly, gray(G_BASE))

    # Pose extras drawn in outline color so they read regardless of tint.
    if "speed" in p["flags"]:
        for sx, sy in ((2, 10), (1, 13), (3, 16)):
            c.rect(sx, sy, sx + 2, sy, gray(G_SHADE))
    if "bow_draw" in p["flags"] or "bow_release" in p["flags"]:
        # Bow: a right-facing arc (limbs curve toward the player), drawn in wood
        # brown + dark outline so it reads as equipment, not body.
        wood = (150, 112, 78, 255)
        bx = 21 + bdx
        cy = 15 + bdy
        for yy in range(cy - 3, cy + 4):
            c.put(bx, yy, wood)                     # bow belly
        c.put(bx - 1, cy - 4, wood); c.put(bx - 1, cy + 4, wood)  # curved tips
        c.put(bx - 2, cy - 5, wood); c.put(bx - 2, cy + 5, wood)
        string = (236, 236, 242, 255)
        if "bow_draw" in p["flags"]:
            # String pulled back to the face + nocked arrow across the arm.
            for yy in range(cy - 4, cy + 5):
                c.put(bx - 4, yy, string)
            c.rect(15 + bdx, cy, bx + 1, cy, (110, 84, 58, 255))  # arrow shaft
            c.put(bx + 2, cy, (216, 216, 224, 255))               # arrow head
        else:
            # String snapped straight between the tips.
            for yy in range(cy - 4, cy + 5):
                c.put(bx - 2 if yy in (cy - 4, cy + 4) else bx - 1, yy, string)

    c.outline()


def draw_hair(c, p):
    """Fringe + little top tuft over the head. Grayscale, tinted by hair color."""
    hx0, hy0, hx1, hy1 = head_box(p)
    # Cap of hair over the top of the head.
    c.rect(hx0, hy0, hx1, hy0 + 2, gray(G_BASE))
    c.rect(hx0 + 1, hy0 - 1, hx1 - 1, hy0 - 1, gray(G_BASE))
    # Fringe dips on the forehead (facing-right side gets the longer bang).
    c.rect(hx1 - 2, hy0 + 3, hx1 - 1, hy0 + 3, gray(G_BASE))
    c.rect(hx0 + 2, hy0 + 3, hx0 + 3, hy0 + 3, gray(G_BASE))
    # Back-of-head mass (left side, since we face right).
    c.rect(hx0, hy0 + 3, hx0 + 1, hy0 + 6, gray(G_SHADE))
    # Tuft.
    c.rect(hx0 + 6, hy0 - 2, hx0 + 7, hy0 - 2, gray(G_BASE))
    c.outline()


def draw_shirt(c, p):
    """Torso block + short sleeves. Grayscale, tinted by shirt color."""
    bdx, bdy = p["body"]
    c.rect(8 + bdx, 15 + bdy, 15 + bdx, 18 + bdy, gray(G_BASE))
    # Bottom hem shade.
    c.rect(8 + bdx, 18 + bdy, 15 + bdx, 18 + bdy, gray(G_SHADE))
    c.outline()


def draw_pants(c, p):
    """Hip band + two stubby legs. Grayscale, tinted by pants color."""
    lLx, lLy = p["legL"]
    lRx, lRy = p["legR"]
    bdx, bdy = p["body"]
    c.rect(9 + bdx, 19 + bdy, 15 + bdx, 19 + bdy, gray(G_BASE))  # hips
    c.rect(9 + lLx, 19 + lLy, 11 + lLx, 20 + lLy, gray(G_BASE))
    c.rect(13 + lRx, 19 + lRy, 15 + lRx, 20 + lRy, gray(G_BASE))
    c.outline()


def draw_head_cap(c, p):
    hx0, hy0, hx1, hy1 = head_box(p)
    c.rect(hx0, hy0 - 1, hx1, hy0 + 2, gray(G_BASE))
    c.rect(hx0 + 1, hy0 - 2, hx1 - 1, hy0 - 2, gray(G_BASE))
    # Brim forward (facing right).
    c.rect(hx1 + 1, hy0 + 1, hx1 + 3, hy0 + 2, gray(G_SHADE))
    c.outline()


def draw_head_helmet(c, p):
    hx0, hy0, hx1, hy1 = head_box(p)
    c.rect(hx0 - 1, hy0 - 1, hx1 + 1, hy0 + 4, gray(G_BASE))
    c.rect(hx0, hy0 - 2, hx1, hy0 - 2, gray(G_BASE))
    # Eye slit stays open: carve the band above the eyes.
    c.rect(hx0 + 4, hy0 + 3, hx1 - 1, hy0 + 4, (0, 0, 0, 0))
    # Crest.
    c.rect(hx0 + 5, hy0 - 4, hx0 + 7, hy0 - 2, gray(G_LIGHT))
    c.outline()


def draw_head_horns(c, p):
    hx0, hy0, hx1, hy1 = head_box(p)
    for bx in (hx0 + 1, hx1 - 2):
        c.rect(bx, hy0 - 2, bx + 1, hy0 - 1, gray(G_BASE))
        c.put(bx, hy0 - 3, gray(G_LIGHT))
    c.outline()


def draw_head_halo(c, p):
    hx0, hy0, hx1, hy1 = head_box(p)
    c.rect(hx0 + 3, hy0 - 4, hx1 - 3, hy0 - 3, gray(G_LIGHT))
    c.rect(hx0 + 4, hy0 - 4, hx1 - 4, hy0 - 4, gray(G_BASE))
    c.outline()


def draw_head_crown(c, p):
    hx0, hy0, hx1, hy1 = head_box(p)
    c.rect(hx0 + 3, hy0 - 2, hx1 - 3, hy0 - 1, gray(G_BASE))
    for px_ in (hx0 + 3, hx0 + 6, hx1 - 4):
        c.put(px_, hy0 - 3, gray(G_LIGHT))
    c.outline()


CHAR_LAYERS = {
    "skin": draw_skin,
    "hair": draw_hair,
    "shirt": draw_shirt,
    "pants": draw_pants,
    "head_cap": draw_head_cap,
    "head_helmet": draw_head_helmet,
    "head_horns": draw_head_horns,
    "head_halo": draw_head_halo,
    "head_crown": draw_head_crown,
}


def generate_characters():
    n = 0
    for layer, draw in CHAR_LAYERS.items():
        for state, frames in STATES:
            for f in range(frames):
                c = Canvas(SIZE, SIZE)
                draw(c, POSES[(state, f)])
                c.save(SPRITES / "chibi" / layer / state / f"east_{f}.png")
                n += 1
    print(f"characters: {n} frames across {len(CHAR_LAYERS)} layers")


# ---------------------------------------------------------------------------
# Tilesets
# ---------------------------------------------------------------------------
# Pastel palettes per map theme (bg is used by the scene, not baked into PNGs).
# Order matches Maps.swift ids: Arena, Pillars, Stairs, Towers, Cross, Ledges,
# Bridges, Diamond, Layers, Scatter.

THEMES = [
    dict(bg=(167, 155, 212), base=(124, 111, 176), shade=(104, 92, 152), lip=(201, 191, 232), outline=(58, 49, 83)),
    dict(bg=(212, 160, 185), base=(168, 114, 144), shade=(146, 95, 124), lip=(235, 201, 219), outline=(78, 46, 65)),
    dict(bg=(155, 196, 180), base=(110, 156, 138), shade=(92, 134, 118), lip=(198, 230, 217), outline=(47, 74, 64)),
    dict(bg=(216, 199, 154), base=(176, 155, 106), shade=(152, 132, 88), lip=(239, 227, 190), outline=(85, 72, 43)),
    dict(bg=(159, 180, 216), base=(113, 137, 180), shade=(95, 117, 156), lip=(197, 212, 238), outline=(47, 61, 89)),
    dict(bg=(216, 168, 152), base=(176, 120, 98), shade=(152, 101, 82), lip=(239, 207, 194), outline=(84, 50, 40)),
    dict(bg=(151, 195, 206), base=(106, 152, 166), shade=(88, 130, 143), lip=(194, 228, 235), outline=(44, 70, 77)),
    dict(bg=(182, 155, 212), base=(138, 111, 176), shade=(118, 92, 152), lip=(217, 201, 238), outline=(64, 49, 92)),
    dict(bg=(180, 199, 155), base=(138, 156, 110), shade=(118, 134, 92), lip=(220, 233, 198), outline=(65, 74, 47)),
    dict(bg=(196, 164, 201), base=(152, 124, 158), shade=(131, 105, 136), lip=(229, 205, 232), outline=(70, 48, 73)),
]

TILE = 16
N, E, S, W = 1, 2, 4, 8


def speckle(x, y):
    """Fixed pseudo-random speckle pattern (deterministic, seed-free)."""
    h = (x * 374761393 + y * 668265263) & 0xFFFFFFFF
    h = (h ^ (h >> 13)) * 1274126177 & 0xFFFFFFFF
    return (h >> 16) % 23 == 0


def generate_tileset(theme_id, t):
    base, shade, lip, outline = [t[k] + (255,) for k in ("base", "shade", "lip", "outline")]
    for mask in range(16):
        c = Canvas(TILE, TILE)
        # Fill with base + sparse darker speckles.
        for y in range(TILE):
            for x in range(TILE):
                c.put(x, y, shade if speckle(x + mask * TILE, y + theme_id * TILE) else base)

        exp_n = not (mask & N)
        exp_e = not (mask & E)
        exp_s = not (mask & S)
        exp_w = not (mask & W)

        # Exposed-edge treatments.
        if exp_n:
            for x in range(TILE):
                c.put(x, 0, outline)
                c.put(x, 1, lip)
                c.put(x, 2, lip)
        if exp_s:
            for x in range(TILE):
                c.put(x, TILE - 1, outline)
                c.put(x, TILE - 2, shade)
        if exp_w:
            for y in range(TILE):
                c.put(0, y, outline)
                c.put(1, y, shade if not (exp_n and y <= 2) else lip)
        if exp_e:
            for y in range(TILE):
                c.put(TILE - 1, y, outline)
                c.put(TILE - 2, y, shade if not (exp_n and y <= 2) else lip)

        # Rounded exposed corners: cut the corner pixel, patch with outline.
        for (cx, cy, ex, ey) in ((0, 0, exp_w, exp_n), (TILE - 1, 0, exp_e, exp_n),
                                 (0, TILE - 1, exp_w, exp_s), (TILE - 1, TILE - 1, exp_e, exp_s)):
            if ex and ey:
                c.put(cx, cy, (0, 0, 0, 0))
                nx = cx + (1 if cx == 0 else -1)
                ny = cy + (1 if cy == 0 else -1)
                c.put(nx, cy, outline)
                c.put(cx, ny, outline)

        c.save(SPRITES / "tiles" / f"theme{theme_id}" / f"t{mask}.png")


def generate_tiles():
    for i, t in enumerate(THEMES):
        generate_tileset(i, t)
    print(f"tiles: {len(THEMES)} themes x 16 masks")


# ---------------------------------------------------------------------------
# Arrow sprite (points right; the scene rotates it)
# ---------------------------------------------------------------------------

def generate_arrow():
    c = Canvas(14, 5)
    # Fletching (left).
    for x, ys in ((0, (0, 2, 4)), (1, (0, 1, 2, 3, 4)), (2, (1, 2, 3))):
        for y in ys:
            c.put(x, y, (196, 84, 84, 255))
    # Shaft.
    c.rect(3, 2, 9, 2, (150, 112, 78, 255))
    # Head.
    c.put(10, 1, (208, 208, 216, 255)); c.put(10, 2, (208, 208, 216, 255)); c.put(10, 3, (208, 208, 216, 255))
    c.put(11, 2, (208, 208, 216, 255)); c.put(12, 2, (232, 232, 238, 255))
    c.outline()
    c.save(SPRITES / "fx" / "arrow.png")
    print("arrow: 1 sprite")


# ---------------------------------------------------------------------------
# Contact sheet (scratch preview only, not committed)
# ---------------------------------------------------------------------------

def contact_sheet(out_path):
    scale = 6
    frames = [(s, f) for s, n in STATES for f in range(n)]
    cols = len(frames)
    rows = 3  # composited character, tiles sample, arrow
    sheet = Image.new("RGBA", (cols * (SIZE + 2) * scale // 1, (SIZE + 2) * scale * 2 + 20 * scale), THEMES[0]["bg"] + (255,))

    # Row 1: full composite (pants+shirt+skin+hair) and Row 2: with cap accessory.
    for row, layers in enumerate((["pants", "shirt", "skin", "hair"],
                                  ["pants", "shirt", "skin", "hair", "head_cap"])):
        for i, (state, f) in enumerate(frames):
            comp = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
            for layer in layers:
                img = Image.open(SPRITES / "chibi" / layer / state / f"east_{f}.png")
                comp.alpha_composite(img)
            comp = comp.resize((SIZE * scale, SIZE * scale), Image.NEAREST)
            sheet.alpha_composite(comp, (i * (SIZE + 2) * scale, row * (SIZE + 2) * scale))

    # Row 3: tile sample (theme 0): a small platform = masks W=8|E, etc.
    y3 = 2 * (SIZE + 2) * scale
    for i, mask in enumerate([0, N | S, W, W | E, E, 15]):
        img = Image.open(SPRITES / "tiles/theme0" / f"t{mask}.png").resize((TILE * scale, TILE * scale), Image.NEAREST)
        sheet.alpha_composite(img, (i * (TILE + 1) * scale, y3))
    arrow = Image.open(SPRITES / "fx/arrow.png")
    arrow = arrow.resize((arrow.width * scale, arrow.height * scale), Image.NEAREST)
    sheet.alpha_composite(arrow, (7 * (TILE + 1) * scale, y3 + 4 * scale))

    sheet.save(out_path)
    print(f"contact sheet: {out_path}")


if __name__ == "__main__":
    generate_characters()
    generate_tiles()
    generate_arrow()
    import sys
    if len(sys.argv) > 1:
        contact_sheet(Path(sys.argv[1]))
