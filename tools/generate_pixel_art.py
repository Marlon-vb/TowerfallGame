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
    """Rounded head block, 3-tone: base + top-right highlight + bottom-left shade.
    (Style notes from the strong CC0 packs: one light source, soft interior.)"""
    c.rect(x0, y0, x1, y1, fill)
    # Rounder corners: 2-step cuts.
    for cx, cy in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
        c.put(cx, cy, (0, 0, 0, 0))
    for cx, cy in ((x0 + 1, y0), (x0, y0 + 1), (x1 - 1, y0), (x1, y0 + 1),
                   (x0 + 1, y1), (x0, y1 - 1), (x1 - 1, y1), (x1, y1 - 1)):
        pass  # keep the 1-step cut only; 2-step looked too diamond-like at 13px
    # Shade: bottom row + left column (light from the top-right).
    for x in range(x0 + 1, x1):
        c.put(x, y1, shade)
    for y in range(y0 + 2, y1):
        c.put(x0 + 1, y, shade)


def draw_skin(c, p):
    """Head + face + arms + feet (+ pose extras). Grayscale, tinted by skin."""
    hx0, hy0, hx1, hy1 = head_box(p)
    draw_head_shape(c, hx0, hy0, hx1, hy1, gray(G_BASE), gray(G_SHADE))

    # Top-right highlight arc across the crown (one light source).
    for x in range(hx0 + 4, hx1):
        c.put(x, hy0 + 1, gray(G_LIGHT))
    c.put(hx1 - 1, hy0 + 2, gray(G_LIGHT))

    # Ear nub on the left (back of head, since we face right).
    c.rect(hx0 - 1, hy0 + 5, hx0 - 1, hy0 + 6, gray(G_SHADE))

    # Face: two 2x2 eyes shifted toward facing (right), each with a white
    # sparkle, plus warm blush marks under them (cute-pack staples).
    if "dead_eyes" in p["flags"]:
        for ex in (hx0 + 4, hx1 - 4):
            ey = hy0 + 5
            c.put(ex, ey, EYE); c.put(ex + 1, ey + 1, EYE)
            c.put(ex + 1, ey, EYE); c.put(ex, ey + 1, EYE)
    else:
        for ex in (hx0 + 4, hx1 - 4):
            c.rect(ex, hy0 + 5, ex + 1, hy0 + 6, EYE)
            c.put(ex, hy0 + 5, (236, 234, 244, 255))       # sparkle
            c.put(ex, hy0 + 8, (222, 138, 128, 255))       # blush
            c.put(ex + 1, hy0 + 8, (222, 138, 128, 255))

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
    # The bow itself is a separate cosmetic layer (bow_<style>), drawn only for
    # the shoot frames - see draw_bow.

    c.outline()


# Bow cosmetics: full-color (non-tintable) layers drawn only for shoot frames,
# anchored to the same extended-arm pose the skin layer draws.
def make_bow(limb, string_col, accent=None):
    def draw(c, p):
        bdx, bdy = p["body"]
        bx = 21 + bdx
        cy = 15 + bdy
        for yy in range(cy - 3, cy + 4):
            c.put(bx, yy, limb)                      # bow belly
        c.put(bx - 1, cy - 4, limb); c.put(bx - 1, cy + 4, limb)  # curved tips
        c.put(bx - 2, cy - 5, limb); c.put(bx - 2, cy + 5, limb)
        if accent:
            c.put(bx, cy, accent)                    # grip accent
        if "bow_draw" in p["flags"]:
            # String pulled back to the face + nocked arrow across the arm.
            for yy in range(cy - 4, cy + 5):
                c.put(bx - 4, yy, string_col)
            c.rect(15 + bdx, cy, bx + 1, cy, (110, 84, 58, 255))  # arrow shaft
            c.put(bx + 2, cy, (216, 216, 224, 255))               # arrow head
        else:
            # String snapped straight between the tips.
            for yy in range(cy - 4, cy + 5):
                c.put(bx - 2 if yy in (cy - 4, cy + 4) else bx - 1, yy, string_col)
        c.outline()
    return draw


BOW_LAYERS = {
    "bow_wood":    make_bow((150, 112, 78, 255), (236, 236, 242, 255)),
    "bow_silver":  make_bow((198, 202, 214, 255), (240, 244, 250, 255), accent=(150, 155, 170, 255)),
    "bow_gold":    make_bow((238, 198, 74, 255), (250, 240, 200, 255), accent=(184, 140, 40, 255)),
    "bow_crystal": make_bow((140, 216, 240, 255), (222, 248, 255, 255), accent=(96, 170, 220, 255)),
}


def draw_hair(c, p):
    """Fringe + little top tuft over the head. Grayscale, tinted by hair color."""
    hx0, hy0, hx1, hy1 = head_box(p)
    # Cap of hair over the top of the head, highlight along the crown.
    c.rect(hx0, hy0, hx1, hy0 + 2, gray(G_BASE))
    c.rect(hx0 + 1, hy0 - 1, hx1 - 1, hy0 - 1, gray(G_BASE))
    for x in range(hx0 + 4, hx1 - 1):
        c.put(x, hy0 - 1, gray(G_LIGHT))
    # Fringe dips on the forehead (facing-right side gets the longer bang),
    # with a shade line where hair meets skin so the fringe reads as depth.
    c.rect(hx1 - 2, hy0 + 3, hx1 - 1, hy0 + 3, gray(G_BASE))
    c.rect(hx0 + 2, hy0 + 3, hx0 + 3, hy0 + 3, gray(G_BASE))
    for x in range(hx0, hx1 + 1):
        if c.get(x, hy0 + 2)[3] != 0 and c.get(x, hy0 + 3)[3] == 0:
            c.put(x, hy0 + 2, gray(G_SHADE))
    # Back-of-head mass (left side, since we face right).
    c.rect(hx0, hy0 + 3, hx0 + 1, hy0 + 6, gray(G_SHADE))
    # Tuft.
    c.rect(hx0 + 6, hy0 - 2, hx0 + 7, hy0 - 2, gray(G_BASE))
    c.put(hx0 + 7, hy0 - 3, gray(G_BASE))
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


# MARK: fun full-color heads (catalog color is white, so tinting is a no-op)

def draw_head_fish(c, p):
    hx0, hy0, hx1, hy1 = head_box(p)
    body = (72, 140, 214, 255)
    belly = (150, 200, 240, 255)
    fin = (52, 104, 170, 255)
    # Fish body swallowing the whole head.
    c.rect(hx0 - 1, hy0 - 2, hx1 + 1, hy0 + 6, body)
    c.rect(hx0, hy0 + 5, hx1, hy0 + 6, belly)
    # Tail sticking out the back (left).
    c.rect(hx0 - 3, hy0, hx0 - 2, hy0 + 4, fin)
    c.put(hx0 - 4, hy0 - 1, fin); c.put(hx0 - 4, hy0 + 5, fin)
    # Top fin.
    c.rect(hx0 + 4, hy0 - 4, hx0 + 8, hy0 - 3, fin)
    # Fish eye + open mouth at the front.
    c.put(hx1 - 2, hy0 + 1, (250, 250, 250, 255))
    c.put(hx1 - 2, hy0 + 2, (20, 20, 30, 255))
    c.rect(hx1, hy0 + 4, hx1 + 1, hy0 + 5, (30, 30, 46, 255))
    c.outline()


def draw_head_crow(c, p):
    hx0, hy0, hx1, hy1 = head_box(p)
    body = (38, 38, 48, 255)
    # A crow perched on the crown, facing right.
    c.rect(hx0 + 4, hy0 - 5, hx0 + 9, hy0 - 1, body)          # body
    c.rect(hx0 + 8, hy0 - 7, hx0 + 11, hy0 - 4, body)         # head
    c.rect(hx0 + 2, hy0 - 4, hx0 + 3, hy0 - 3, body)          # tail
    c.put(hx0 + 11, hy0 - 6, (240, 168, 48, 255))             # beak
    c.put(hx0 + 12, hy0 - 6, (240, 168, 48, 255))
    c.put(hx0 + 9, hy0 - 6, (240, 240, 246, 255))             # eye
    c.put(hx0 + 5, hy0 - 1, (240, 168, 48, 255))              # legs
    c.put(hx0 + 7, hy0 - 1, (240, 168, 48, 255))
    c.outline()


def draw_head_tv(c, p):
    hx0, hy0, hx1, hy1 = head_box(p)
    frame = (110, 84, 58, 255)
    screen = (110, 220, 130, 255)
    scan = (80, 180, 100, 255)
    c.rect(hx0 - 1, hy0 - 2, hx1 + 1, hy0 + 7, frame)
    c.rect(hx0 + 1, hy0, hx1 - 1, hy0 + 5, screen)
    for x in range(hx0 + 1, hx1):                              # scanline
        if (x - hx0) % 2 == 0:
            c.put(x, hy0 + 2, scan)
    c.rect(hx0 + 4, hy0 + 2, hx0 + 4, hy0 + 3, (30, 30, 40, 255))  # screen eyes
    c.rect(hx1 - 4, hy0 + 2, hx1 - 4, hy0 + 3, (30, 30, 40, 255))
    c.put(hx0 + 8, hy0 - 4, (60, 60, 70, 255))                 # antenna
    c.put(hx0 + 7, hy0 - 5, (60, 60, 70, 255))
    c.put(hx0 + 9, hy0 - 3, (60, 60, 70, 255))
    c.outline()


def draw_head_frog(c, p):
    hx0, hy0, hx1, hy1 = head_box(p)
    green = (108, 190, 92, 255)
    dark = (78, 150, 66, 255)
    c.rect(hx0, hy0 - 2, hx1, hy0 + 3, green)                  # dome
    c.rect(hx0, hy0 + 3, hx1, hy0 + 3, dark)
    for bx in (hx0 + 2, hx1 - 3):                              # bulge eyes
        c.rect(bx, hy0 - 4, bx + 1, hy0 - 3, green)
        c.put(bx, hy0 - 4, (250, 250, 250, 255))
        c.put(bx + 1, hy0 - 4, (24, 24, 34, 255))
    c.outline()


def draw_head_cat(c, p):
    hx0, hy0, hx1, hy1 = head_box(p)
    fur = (232, 176, 96, 255)
    inner = (240, 130, 150, 255)
    for bx in (hx0 + 1, hx1 - 3):
        c.rect(bx, hy0 - 2, bx + 2, hy0 - 1, fur)              # ear base
        c.put(bx + 1, hy0 - 3, fur)                            # tip
        c.put(bx + 1, hy0 - 1, inner)                          # inner
    c.outline()


def draw_head_wizard(c, p):
    hx0, hy0, hx1, hy1 = head_box(p)
    hat = (110, 70, 180, 255)
    band = (238, 198, 74, 255)
    c.rect(hx0 - 1, hy0, hx1 + 1, hy0 + 1, hat)                # brim
    c.rect(hx0 + 2, hy0 - 3, hx1 - 2, hy0 - 1, hat)            # cone base
    c.rect(hx0 + 4, hy0 - 5, hx1 - 4, hy0 - 4, hat)
    c.rect(hx0 + 6, hy0 - 7, hx0 + 7, hy0 - 6, hat)            # tip (bent)
    c.put(hx0 + 8, hy0 - 8, hat)
    c.put(hx0 + 5, hy0 - 2, band)                              # star
    c.outline()


def draw_head_pirate(c, p):
    hx0, hy0, hx1, hy1 = head_box(p)
    hat = (40, 40, 52, 255)
    trim = (238, 198, 74, 255)
    c.rect(hx0 - 1, hy0 - 1, hx1 + 1, hy0 + 1, hat)            # wide tricorn
    c.rect(hx0 + 1, hy0 - 3, hx1 - 1, hy0 - 2, hat)
    c.rect(hx0 - 1, hy0 + 1, hx1 + 1, hy0 + 1, trim)           # gold trim
    c.put(hx0 + 6, hy0 - 2, (245, 245, 245, 255))              # skull mark
    c.put(hx0 + 8, hy0 - 2, (245, 245, 245, 255))
    c.put(hx0 + 7, hy0 - 1, (245, 245, 245, 255))
    c.outline()


def draw_head_viking(c, p):
    hx0, hy0, hx1, hy1 = head_box(p)
    helm = (150, 154, 166, 255)
    horn = (238, 232, 214, 255)
    c.rect(hx0, hy0 - 2, hx1, hy0 + 3, helm)
    c.rect(hx0 + 3, hy0 - 3, hx1 - 3, hy0 - 3, helm)
    c.put(hx0 + 8, hy0 - 1, (110, 114, 126, 255))              # rivet
    for bx, dx in ((hx0 - 1, -1), (hx1 + 1, 1)):               # horns
        c.rect(bx, hy0 - 2, bx, hy0, horn)
        c.put(bx + dx, hy0 - 4, horn)
        c.put(bx, hy0 - 3, horn)
    c.outline()


def draw_head_ninja(c, p):
    hx0, hy0, hx1, hy1 = head_box(p)
    band = (52, 56, 78, 255)
    c.rect(hx0 - 1, hy0 + 2, hx1 + 1, hy0 + 3, band)           # forehead band
    c.rect(hx0 - 3, hy0 + 3, hx0 - 2, hy0 + 6, band)           # trailing knot
    c.put(hx0 - 4, hy0 + 7, band)
    c.put(hx1 - 4, hy0 + 2, (196, 60, 60, 255))                # metal plate mark
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
    "head_fish": draw_head_fish,
    "head_crow": draw_head_crow,
    "head_tv": draw_head_tv,
    "head_frog": draw_head_frog,
    "head_cat": draw_head_cat,
    "head_wizard": draw_head_wizard,
    "head_pirate": draw_head_pirate,
    "head_viking": draw_head_viking,
    "head_ninja": draw_head_ninja,
}


# ---------------------------------------------------------------------------
# World themes: tilesets + 16-bit backgrounds
# ---------------------------------------------------------------------------
# Five worlds; Maps.themes maps each map id to one of these by name.

TILE = 16
N, E, S, W = 1, 2, 4, 8
BG_W, BG_H = 320, 192  # world size at 20x12 tiles

WORLDS = {
    "alien": dict(
        base=(96, 68, 138), shade=(76, 52, 112), lip=(122, 224, 168),
        lip2=(86, 178, 128), outline=(28, 20, 48),
        sky=[(20, 18, 46), (32, 26, 66), (46, 36, 88)],
    ),
    "castle": dict(
        base=(132, 130, 144), shade=(104, 102, 118), lip=(172, 170, 186),
        lip2=(148, 146, 162), outline=(42, 40, 56),
        sky=[(52, 38, 78), (96, 60, 100), (176, 106, 100)],
    ),
    "lava": dict(
        base=(70, 58, 66), shade=(52, 42, 50), lip=(104, 88, 98),
        lip2=(86, 72, 82), outline=(22, 16, 22),
        sky=[(30, 10, 16), (56, 18, 22), (92, 30, 26)],
    ),
    "sludge": dict(
        base=(112, 120, 112), shade=(88, 96, 90), lip=(134, 202, 78),
        lip2=(104, 164, 62), outline=(32, 40, 34),
        sky=[(30, 40, 32), (44, 58, 44), (62, 78, 58)],
    ),
    "aquatic": dict(
        base=(198, 174, 126), shade=(166, 142, 98), lip=(228, 208, 162),
        lip2=(206, 184, 138), outline=(72, 58, 40),
        sky=[(14, 34, 72), (20, 52, 100), (30, 74, 130)],
    ),
}


def hash2(x, y):
    h = (x * 374761393 + y * 668265263) & 0xFFFFFFFF
    h = (h ^ (h >> 13)) * 1274126177 & 0xFFFFFFFF
    return (h >> 16) & 0xFFFF


def speckle(x, y, mod=23):
    return hash2(x, y) % mod == 0


def generate_tileset(name, t):
    base = t["base"] + (255,)
    shade = t["shade"] + (255,)
    lip = t["lip"] + (255,)
    lip2 = t["lip2"] + (255,)
    outline = t["outline"] + (255,)

    for mask in range(16):
        c = Canvas(TILE, TILE)
        # Themed fill.
        for y in range(TILE):
            for x in range(TILE):
                col = base
                if name == "castle":
                    # Staggered brick mortar lines.
                    if y % 8 == 7 or (x + (8 if (y // 8) % 2 else 0)) % 16 == 15:
                        col = shade
                elif name == "sludge":
                    # Metal plates with rivets.
                    if (x % 8 == 0) or (y % 8 == 0):
                        col = shade
                    elif (x % 8 in (2, 5)) and (y % 8 in (2, 5)) and speckle(x, y, 3):
                        col = shade
                elif name == "lava":
                    if speckle(x + mask, y, 31):
                        col = (232, 120, 40, 255)  # embers
                    elif speckle(x + mask * 3, y + 7, 17):
                        col = shade
                elif name == "aquatic":
                    if speckle(x + mask, y, 29):
                        col = (240, 236, 224, 255)  # shell flecks
                    elif speckle(x + mask * 5, y + 3, 13):
                        col = shade
                else:  # alien
                    if speckle(x + mask, y, 19):
                        col = shade
                c.put(x, y, col)

        exp_n = not (mask & N)
        exp_e = not (mask & E)
        exp_s = not (mask & S)
        exp_w = not (mask & W)

        if exp_n:
            for x in range(TILE):
                c.put(x, 0, outline)
                c.put(x, 1, lip)
                c.put(x, 2, lip if name in ("alien", "sludge") and x % 3 != 2 else lip2)
            if name in ("alien", "sludge"):
                # Grass / slime drips hanging off the lip.
                for x in range(TILE):
                    if hash2(x, mask) % 5 == 0:
                        c.put(x, 3, lip2)
        if exp_s:
            for x in range(TILE):
                c.put(x, TILE - 1, outline)
                c.put(x, TILE - 2, shade)
        if exp_w:
            for y in range(TILE):
                c.put(0, y, outline)
                c.put(1, y, lip2 if (exp_n and y <= 2) else shade)
        if exp_e:
            for y in range(TILE):
                c.put(TILE - 1, y, outline)
                c.put(TILE - 2, y, lip2 if (exp_n and y <= 2) else shade)

        # Rounded exposed corners.
        for (cx, cy, ex, ey) in ((0, 0, exp_w, exp_n), (TILE - 1, 0, exp_e, exp_n),
                                 (0, TILE - 1, exp_w, exp_s), (TILE - 1, TILE - 1, exp_e, exp_s)):
            if ex and ey:
                c.put(cx, cy, (0, 0, 0, 0))
                c.put(cx + (1 if cx == 0 else -1), cy, outline)
                c.put(cx, cy + (1 if cy == 0 else -1), outline)

        c.save(SPRITES / "tiles" / name / f"t{mask}.png")


# MARK: backgrounds

def vgrad(c, bands, dither=True):
    """Fill the canvas with horizontal bands + 1px dither rows between them."""
    n = len(bands)
    for y in range(c.h):
        idx = min(n - 1, y * n // c.h)
        col = bands[idx] + (255,)
        if dither and idx + 1 < n:
            edge = (idx + 1) * c.h // n
            if edge - y <= 2 and (x_dither := True):
                pass
        for x in range(c.w):
            c.put(x, y, col)
    # Dither rows at band boundaries.
    if dither:
        for i in range(1, n):
            edge = i * c.h // n
            for x in range(c.w):
                if (x + edge) % 2 == 0 and edge - 1 >= 0:
                    c.put(x, edge - 1, bands[i] + (255,))
                if (x + edge) % 2 == 1 and edge < c.h:
                    c.put(x, edge, bands[i - 1] + (255,))


def bg_alien(c, t):
    vgrad(c, t["sky"])
    # Stars.
    for i in range(90):
        x, y = hash2(i, 1) % BG_W, hash2(i, 2) % (BG_H * 2 // 3)
        c.put(x, y, (230, 230, 245, 255) if i % 3 else (150, 150, 190, 255))
    # Ringed planet.
    px, py, pr = 250, 44, 17
    for y in range(-pr, pr + 1):
        for x in range(-pr, pr + 1):
            if x * x + y * y <= pr * pr:
                col = (206, 140, 190, 255) if (x + y) % 7 else (176, 112, 166, 255)
                c.put(px + x, py + y, col)
    for x in range(-27, 28):
        y = x // 4
        if abs(x) > pr - 3:
            c.put(px + x, py + y + 4, (232, 208, 150, 255))
    # Little UFO.
    ux, uy = 60, 70
    for dx in range(-6, 7):
        c.put(ux + dx, uy, (160, 170, 190, 255))
    for dx in range(-3, 4):
        c.put(ux + dx, uy - 1, (120, 230, 170, 255))
        c.put(ux + dx, uy + 1, (110, 120, 140, 255))
    # Rolling alien hills silhouette.
    for x in range(BG_W):
        h = 22 + (hash2(x // 24, 9) % 14) + (6 if (x // 12) % 2 else 0)
        for y in range(BG_H - h, BG_H):
            c.put(x, y, (38, 30, 74, 255))


def bg_castle(c, t):
    vgrad(c, t["sky"])
    # Moon.
    mx, my, mr = 262, 36, 11
    for y in range(-mr, mr + 1):
        for x in range(-mr, mr + 1):
            if x * x + y * y <= mr * mr and (x + 4) * (x + 4) + y * y > (mr - 2) * (mr - 2):
                c.put(mx + x, my + y, (238, 232, 208, 255))
    # Distant castle silhouette with towers + battlements.
    sil = (36, 28, 52, 255)
    def tower(x0, w, top):
        for x in range(x0, x0 + w):
            for y in range(top, BG_H):
                c.put(x, y, sil)
        for x in range(x0 - 1, x0 + w + 1, 2):  # battlements
            c.put(x, top - 1, sil)
            c.put(x, top - 2, sil)
    tower(30, 16, 96)
    tower(70, 12, 116)
    tower(130, 22, 84)
    tower(190, 12, 118)
    tower(238, 16, 100)
    # Wall connecting them.
    for x in range(20, 300):
        for y in range(140, BG_H):
            c.put(x, y, sil)
    # Lit windows.
    for i, (wx, wy) in enumerate(((36, 108), (136, 96), (140, 120), (244, 112), (76, 126))):
        c.put(wx, wy, (240, 200, 90, 255))
        c.put(wx, wy + 1, (240, 200, 90, 255))


def bg_lava(c, t):
    vgrad(c, t["sky"])
    # Cavern ceiling stalactites.
    rock = (24, 8, 14, 255)
    for x in range(BG_W):
        h = 10 + hash2(x // 10, 3) % 12
        for y in range(0, h):
            c.put(x, y, rock)
    # Lava lake at the bottom with glow bands.
    for y in range(BG_H - 34, BG_H):
        for x in range(BG_W):
            depth = y - (BG_H - 34)
            col = (255, 190, 60, 255) if depth < 3 else (244, 120, 30, 255) if depth < 12 else (200, 70, 24, 255)
            if speckle(x, y, 41):
                col = (255, 222, 120, 255)
            c.put(x, y, col)
    # Rock islands poking out of the lava.
    for x0 in (40, 150, 250):
        w = 26
        for x in range(x0, x0 + w):
            h = 8 - abs(x - x0 - w // 2) // 2
            for y in range(BG_H - 30 - h, BG_H - 24):
                c.put(x, y, rock)
    # Rising ember dots.
    for i in range(24):
        x, y = hash2(i, 5) % BG_W, BG_H - 40 - hash2(i, 6) % 90
        c.put(x, y, (255, 170, 70, 255))


def bg_sludge(c, t):
    vgrad(c, t["sky"])
    dark = (24, 32, 26, 255)
    # Industrial pipes across the top.
    for y in range(12, 17):
        for x in range(BG_W):
            c.put(x, y, (70, 82, 72, 255) if y != 14 else (96, 110, 98, 255))
    for px in (50, 140, 240):
        for y in range(17, 40):
            for x in range(px, px + 6):
                c.put(x, y, (70, 82, 72, 255))
        # Drip.
        c.put(px + 3, 42, (134, 202, 78, 255))
        c.put(px + 3, 43, (134, 202, 78, 255))
    # Vats/tanks silhouette.
    for x0, w, top in ((20, 34, 120), (90, 26, 136), (200, 40, 116), (270, 26, 132)):
        for x in range(x0, x0 + w):
            for y in range(top, BG_H):
                c.put(x, y, dark)
        for x in range(x0 + 2, x0 + w - 2):
            c.put(x, top, (134, 202, 78, 255))  # glowing rim
    # Sludge pool bottom.
    for y in range(BG_H - 16, BG_H):
        for x in range(BG_W):
            col = (110, 180, 60, 255) if y > BG_H - 14 else (134, 202, 78, 255)
            if speckle(x, y, 37):
                col = (160, 224, 96, 255)
            c.put(x, y, col)


def bg_aquatic(c, t):
    vgrad(c, t["sky"])
    # Light rays from the surface.
    for i, rx in enumerate((40, 90, 170, 240)):
        for y in range(0, 120):
            x = rx + y // 3
            for w in range(3 + i % 2):
                cur = c.get(x + w, y)
                if cur[3]:
                    c.put(x + w, y, (min(255, cur[0] + 22), min(255, cur[1] + 26), min(255, cur[2] + 30), 255))
    # Bubbles.
    for i in range(30):
        x, y = hash2(i, 7) % BG_W, hash2(i, 8) % (BG_H - 30)
        c.put(x, y, (190, 220, 240, 255))
        if i % 4 == 0:
            c.put(x + 1, y, (150, 190, 220, 255))
    # Fish silhouettes.
    fish = (10, 22, 48, 255)
    for fx, fy in ((60, 60), (200, 40), (140, 90), (260, 76)):
        for dx in range(6):
            c.put(fx + dx, fy, fish)
        c.put(fx + 1, fy - 1, fish); c.put(fx + 2, fy - 1, fish)
        c.put(fx + 1, fy + 1, fish); c.put(fx + 2, fy + 1, fish)
        c.put(fx - 1, fy - 1, fish); c.put(fx - 1, fy + 1, fish)  # tail
    # Sea floor with kelp.
    floor = (16, 34, 66, 255)
    for x in range(BG_W):
        h = 12 + hash2(x // 16, 11) % 8
        for y in range(BG_H - h, BG_H):
            c.put(x, y, floor)
    for kx in (30, 110, 180, 280):
        for y in range(BG_H - 44, BG_H - 12):
            x = kx + (1 if (y // 4) % 2 else 0)
            c.put(x, y, (28, 92, 62, 255))


BG_DRAWERS = {
    "alien": bg_alien,
    "castle": bg_castle,
    "lava": bg_lava,
    "sludge": bg_sludge,
    "aquatic": bg_aquatic,
}


def generate_worlds():
    for name, t in WORLDS.items():
        generate_tileset(name, t)
        c = Canvas(BG_W, BG_H)
        BG_DRAWERS[name](c, t)
        BG_DECORATORS[name](c)
        c.save(SPRITES / "backgrounds" / f"{name}.png")
    print(f"worlds: {len(WORLDS)} tilesets + backgrounds")


# ---------------------------------------------------------------------------
# FX sprites: arrows per kind + treasure chest
# ---------------------------------------------------------------------------

def arrow_canvas(shaft, head, fletch):
    c = Canvas(14, 5)
    for x, ys in ((0, (0, 2, 4)), (1, (0, 1, 2, 3, 4)), (2, (1, 2, 3))):
        for y in ys:
            c.put(x, y, fletch)
    c.rect(3, 2, 9, 2, shaft)
    for x in (10,):
        c.put(x, 1, head); c.put(x, 2, head); c.put(x, 3, head)
    c.put(11, 2, head)
    c.put(12, 2, tuple(min(255, v + 24) for v in head[:3]) + (255,))
    return c


def generate_fx():
    wood = (150, 112, 78, 255)
    steel = (208, 208, 216, 255)
    arrow_canvas(wood, steel, (196, 84, 84, 255)).save(SPRITES / "fx/arrow.png")
    # Bomb: dark shaft, round black bomb head with a lit fuse pixel.
    bomb = arrow_canvas((92, 76, 64, 255), (52, 52, 62, 255), (120, 120, 130, 255))
    bomb.put(11, 1, (52, 52, 62, 255)); bomb.put(11, 3, (52, 52, 62, 255))
    bomb.put(13, 0, (255, 200, 80, 255))  # fuse spark
    bomb.save(SPRITES / "fx/arrow_bomb.png")
    # Laser: cyan energy bolt.
    arrow_canvas((90, 220, 240, 255), (200, 250, 255, 255), (60, 160, 200, 255)).save(SPRITES / "fx/arrow_laser.png")
    # Drill: grey cone head, stubby.
    drill = arrow_canvas((140, 140, 150, 255), (190, 190, 200, 255), (100, 100, 110, 255))
    drill.put(9, 1, (190, 190, 200, 255)); drill.put(9, 3, (190, 190, 200, 255))
    drill.save(SPRITES / "fx/arrow_drill.png")
    # Feather: green with a leafy fletch.
    arrow_canvas((118, 184, 96, 255), (196, 232, 150, 255), (86, 150, 74, 255)).save(SPRITES / "fx/arrow_feather.png")

    # Treasure chest (16x14): wooden with gold trim + keyhole.
    c = Canvas(16, 14)
    wood_l = (168, 122, 74, 255)
    wood_d = (136, 96, 56, 255)
    gold = (238, 198, 74, 255)
    c.rect(1, 1, 14, 5, wood_l)              # lid
    c.rect(1, 6, 14, 12, wood_d)             # body
    c.rect(1, 5, 14, 6, gold)                # trim band
    c.rect(7, 5, 8, 8, gold)                 # clasp
    c.put(7, 7, (90, 62, 30, 255)); c.put(8, 7, (90, 62, 30, 255))  # keyhole
    for y in (2, 9):
        c.put(1, y, wood_d); c.put(14, y, wood_d)  # planks
    c.outline()
    c.save(SPRITES / "fx/chest.png")
    print("fx: 5 arrows + chest")


# ---------------------------------------------------------------------------
# Contact sheet (scratch preview only, not committed)
# ---------------------------------------------------------------------------

def contact_sheet(out_path):
    scale = 5
    frames = [(s, f) for s, n in STATES for f in range(n)]
    cols = max(len(frames), 10)
    cell = (SIZE + 2) * scale
    sheet = Image.new("RGBA", (cols * cell, cell * 3 + 40 * scale), (44, 40, 70, 255))

    def tint_img(img, rgb):
        out = img.copy(); px = out.load()
        for y in range(out.height):
            for x in range(out.width):
                p = px[x, y]
                if p[3]:
                    px[x, y] = (p[0] * rgb[0] // 255, p[1] * rgb[1] // 255, p[2] * rgb[2] // 255, p[3])
        return out

    colors = dict(skin=(242, 199, 158), hair=(89, 56, 31), shirt=(64, 115, 204), pants=(38, 51, 102))
    # Row 1: base composite. Row 2: with a rotating pick of the new heads.
    heads = ["head_fish", "head_crow", "head_tv", "head_frog", "head_cat",
             "head_wizard", "head_pirate", "head_viking", "head_ninja", "head_crown",
             "head_cap", "head_helmet"]
    for i, (state, f) in enumerate(frames):
        comp = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        for layer in ("pants", "shirt", "skin", "hair"):
            comp.alpha_composite(tint_img(Image.open(SPRITES / f"chibi/{layer}/{state}/east_{f}.png"), colors[layer]))
        if state == "shoot":
            comp.alpha_composite(Image.open(SPRITES / f"chibi/bow_gold/{state}/east_{f}.png"))
        sheet.alpha_composite(comp.resize((SIZE * scale,) * 2, Image.NEAREST), (i * cell, 0))
    for i, head in enumerate(heads):
        comp = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        for layer in ("pants", "shirt", "skin", "hair"):
            comp.alpha_composite(tint_img(Image.open(SPRITES / f"chibi/{layer}/idle/east_0.png"), colors[layer]))
        comp.alpha_composite(Image.open(SPRITES / f"chibi/{head}/idle/east_0.png"))
        sheet.alpha_composite(comp.resize((SIZE * scale,) * 2, Image.NEAREST), (i * cell, cell))
    # Row 3: fx sprites + a tile sample of each world.
    x = 0
    for fx in ("arrow", "arrow_bomb", "arrow_laser", "arrow_drill", "arrow_feather", "chest"):
        img = Image.open(SPRITES / f"fx/{fx}.png")
        img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
        sheet.alpha_composite(img, (x, cell * 2 + 10))
        x += img.width + 6 * scale
    for name in WORLDS:
        img = Image.open(SPRITES / f"tiles/{name}/t0.png").resize((TILE * scale,) * 2, Image.NEAREST)
        sheet.alpha_composite(img, (x, cell * 2))
        x += (TILE + 2) * scale
    sheet.save(out_path)
    print(f"contact sheet: {out_path}")


def generate_characters_and_bows():
    n = 0
    for layer, draw in CHAR_LAYERS.items():
        for state, frames in STATES:
            for f in range(frames):
                c = Canvas(SIZE, SIZE)
                draw(c, POSES[(state, f)])
                c.save(SPRITES / "chibi" / layer / state / f"east_{f}.png")
                n += 1
    # Bows exist only for the shoot frames; the provider hides them elsewhere.
    for layer, draw in BOW_LAYERS.items():
        for f in range(2):
            c = Canvas(SIZE, SIZE)
            draw(c, POSES[("shoot", f)])
            c.save(SPRITES / "chibi" / layer / "shoot" / f"east_{f}.png")
            n += 2
    print(f"characters: {n} frames across {len(CHAR_LAYERS) + len(BOW_LAYERS)} layers")




# ---------------------------------------------------------------------------
# Menu background: a wide hero scene for the main menu (16-bit, no text)
# ---------------------------------------------------------------------------

def generate_menu_bg():
    c = Canvas(480, 270)
    vgrad(c, [(24, 20, 52), (44, 32, 78), (90, 54, 96), (168, 100, 96)])
    # Stars in the upper half.
    for i in range(120):
        x, y = hash2(i, 21) % c.w, hash2(i, 22) % (c.h // 2)
        c.put(x, y, (232, 230, 244, 255) if i % 3 else (160, 158, 196, 255))
    # Big moon.
    mx, my, mr = 396, 52, 22
    for y in range(-mr, mr + 1):
        for x in range(-mr, mr + 1):
            d = x * x + y * y
            if d <= mr * mr:
                col = (240, 234, 210, 255) if d < (mr - 3) * (mr - 3) else (214, 206, 180, 255)
                c.put(mx + x, my + y, col)
    for cx, cy in ((388, 46), (404, 60), (396, 40)):
        c.put(cx, cy, (214, 206, 180, 255))
    # Distant castle skyline.
    sil = (30, 24, 48, 255)
    def tower(x0, w, top):
        for x in range(x0, x0 + w):
            for y in range(top, c.h):
                c.put(x, y, sil)
        for x in range(x0 - 1, x0 + w + 1, 2):
            c.put(x, top - 1, sil); c.put(x, top - 2, sil)
    tower(40, 22, 150); tower(110, 16, 176); tower(200, 30, 140)
    tower(300, 16, 172); tower(420, 22, 156)
    for x in range(20, 460):
        for y in range(200, c.h):
            c.put(x, y, sil)
    for wx, wy in ((48, 168), (208, 152), (214, 178), (306, 184), (428, 170), (120, 188)):
        c.put(wx, wy, (240, 200, 90, 255)); c.put(wx, wy + 1, (240, 200, 90, 255))
    # Foreground battlement ledge along the bottom.
    ledge = (58, 50, 84, 255)
    ledge_hi = (86, 76, 118, 255)
    for x in range(c.w):
        for y in range(c.h - 26, c.h):
            c.put(x, y, ledge)
        c.put(x, c.h - 26, ledge_hi)
    for x in range(0, c.w, 12):
        for xx in range(x, min(x + 6, c.w)):
            c.put(xx, c.h - 28, ledge)
            c.put(xx, c.h - 27, ledge_hi)
    c.save(SPRITES / "backgrounds" / "menu.png")
    print("menu background")



# ---------------------------------------------------------------------------
# Pixel logotype: "ARROWCLASH" drawn in a chunky 5x7 pixel font with a hard
# 3D drop - a custom pixel logo always beats a system font on a title screen.
# ---------------------------------------------------------------------------

FONT_5X7 = {
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "W": ["10001", "10001", "10001", "10101", "10101", "11011", "10001"],
    "C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
}


def generate_title():
    text = "ARROWCLASH"
    gold = (250, 208, 66, 255)
    gold_hi = (255, 236, 150, 255)
    gold_dk = (206, 148, 38, 255)
    edge = (46, 34, 20, 255)
    drop = (24, 18, 40, 255)

    w = len(text) * 6 + 3
    h = 7 + 4
    c = Canvas(w, h)
    x = 1
    for ch in text:
        glyph = FONT_5X7[ch]
        for gy, row in enumerate(glyph):
            for gx, bit in enumerate(row):
                if bit == "1":
                    # Hard 3D drop, then the face with a top highlight band
                    # and a bottom shade band.
                    c.put(x + gx + 1, 1 + gy + 2, drop)
                    face = gold_hi if gy == 0 else gold_dk if gy >= 5 else gold
                    c.put(x + gx, 1 + gy, face)
        x += 6
    # Outline the gold face (not the drop) for a sticker-crisp edge.
    edges = []
    for y in range(h):
        for x2 in range(w):
            if c.get(x2, y)[3] == 0:
                for nx, ny in ((x2+1,y),(x2-1,y),(x2,y+1),(x2,y-1)):
                    p2 = c.get(nx, ny)
                    if p2[3] != 0 and p2 != drop and p2 != edge:
                        edges.append((x2, y))
                        break
    for ex, ey in edges:
        c.put(ex, ey, edge)
    c.save(SPRITES / "ui" / "title.png")
    print("title logo")


# ---------------------------------------------------------------------------
# Background detail pass v2: a nearer decoration layer per world
# ---------------------------------------------------------------------------

def decorate_alien(c):
    # Crystals sprouting from the hills + a second, nearer hill ridge.
    ridge = (52, 42, 96, 255)
    for x in range(BG_W):
        h = 10 + (hash2(x // 18, 31) % 9)
        for y in range(BG_H - h, BG_H):
            c.put(x, y, ridge)
    for cx in (30, 90, 170, 230, 290):
        ch = 6 + hash2(cx, 33) % 5
        col = (120, 230, 170, 255) if cx % 2 else (150, 210, 240, 255)
        for i in range(ch):
            c.put(cx, BG_H - 8 - i, col)
            if i < ch - 2:
                c.put(cx + 1, BG_H - 8 - i, tuple(v * 3 // 4 for v in col[:3]) + (255,))
    c.put(31, BG_H - 8 - 7, (240, 255, 250, 255))


def decorate_castle(c):
    # Banner flags on the towers + drifting cloud wisps.
    for fx, fy in ((36, 92), (136, 80), (244, 96)):
        for i in range(4):
            c.put(fx, fy - 4 + i, (60, 50, 80, 255))       # pole
        for i in range(3):
            c.put(fx + 1 + i, fy - 4, (196, 60, 70, 255))  # flag
            if i < 2:
                c.put(fx + 1 + i, fy - 3, (196, 60, 70, 255))
    for wx, wy, wl in ((60, 40, 22), (180, 26, 30), (280, 54, 18)):
        for i in range(wl):
            c.put(wx + i, wy, (150, 110, 140, 255))
            if i % 3 == 0:
                c.put(wx + i, wy - 1, (150, 110, 140, 255))


def decorate_lava(c):
    # Stalagmites rising from the rock islands + dithered heat shimmer band.
    rock = (24, 8, 14, 255)
    for x0 in (52, 162, 262):
        for i in range(9):
            wdt = max(1, 4 - i // 2)
            for dx in range(-wdt, wdt + 1):
                c.put(x0 + dx, BG_H - 30 - i, rock)
    for x in range(BG_W):
        if (x + 1) % 2 == 0:
            c.put(x, BG_H - 35, (140, 52, 30, 255))
        if x % 3 == 0:
            c.put(x, BG_H - 37, (100, 36, 26, 255))


def decorate_sludge(c):
    # Hazard stripes on the big pipe + leaky barrels by the vats.
    for x in range(0, BG_W, 8):
        for i in range(4):
            if x + i < BG_W:
                c.put(x + i, 13, (206, 172, 60, 255))
    for bx in (70, 150, 246):
        for y in range(BG_H - 26, BG_H - 17):
            for x in range(bx, bx + 8):
                c.put(x, y, (88, 74, 58, 255))
        for x in range(bx, bx + 8):
            c.put(x, BG_H - 24, (110, 94, 74, 255))
            c.put(x, BG_H - 20, (110, 94, 74, 255))
        c.put(bx + 3, BG_H - 17, (134, 202, 78, 255))  # drip
    

def decorate_aquatic(c):
    # Coral fans + tall seaweed + a sunken mast silhouette.
    for cx, col in ((50, (214, 108, 118, 255)), (150, (238, 148, 92, 255)), (240, (188, 96, 178, 255))):
        base = BG_H - 18
        for i in range(6):
            c.put(cx - i, base - i, col)
            c.put(cx - i + 1, base - i, col)
            c.put(cx + i, base - i, col)
            c.put(cx + i - 1, base - i, col)
        c.put(cx, base - 6, col)
    mastx = 200
    for y in range(BG_H - 44, BG_H - 10):
        c.put(mastx, y, (8, 18, 40, 255))
    for i in range(10):
        c.put(mastx - 9 + i, BG_H - 38 + i // 2, (8, 18, 40, 255))


BG_DECORATORS = {
    "alien": decorate_alien,
    "castle": decorate_castle,
    "lava": decorate_lava,
    "sludge": decorate_sludge,
    "aquatic": decorate_aquatic,
}


if __name__ == "__main__":
    generate_characters_and_bows()
    generate_worlds()
    generate_fx()
    generate_menu_bg()
    generate_title()
    import sys
    if len(sys.argv) > 1:
        contact_sheet(Path(sys.argv[1]))
