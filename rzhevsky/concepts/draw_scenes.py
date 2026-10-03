#!/usr/bin/env python3
"""Procedural concept art for "Поручик Ржевский против Ордена" (scenes + props).

Renders four original, secular, character-free images with Pillow only:

* ``07_usadba_courtyard.png`` - manor courtyard of Vyuzhina (prompt 7);
* ``08_archive_night.png``    - night seal archive, stealth light cones (prompt 8);
* ``09_fair_square.png``      - fair square with tents and carousel (prompt 9);
* ``10_item_sheet.png``       - 4x3 sheet of inventory props (prompt 10).

Everything is drawn at 2x and downsampled with LANCZOS.  All randomness is
seeded, so repeated runs give identical PNGs.  Usage::

    python3 draw_scenes.py            # writes into ./out/
"""

from __future__ import annotations

import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

OUT_DIR = Path(__file__).resolve().parent / "out"
OUTLINE = "#2B1B12"
OW = 3              # outline width in logical pixels (uniform everywhere)
SS = 2              # supersampling factor
FONT_REG = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


# --------------------------------------------------------------------------
# generic helpers
# --------------------------------------------------------------------------
def hex_rgb(value: str) -> tuple[int, int, int]:
    """Convert ``#RRGGBB`` to an RGB tuple."""
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))  # type: ignore


def mix(a: str, b: str, t: float) -> str:
    """Linear blend of two hex colours (t=0 -> a, t=1 -> b)."""
    ca, cb = hex_rgb(a), hex_rgb(b)
    return "#%02X%02X%02X" % tuple(round(x + (y - x) * t) for x, y in zip(ca, cb))


class Canvas:
    """Supersampled drawing surface with outline-aware primitives.

    All coordinates are *logical* pixels; they are multiplied by ``SS``
    internally.  Every filled shape gets the uniform dark-brown outline.
    """

    def __init__(self, w: int, h: int, bg: str = "#FFFFFF") -> None:
        self.w, self.h = w, h
        self.im = Image.new("RGB", (w * SS, h * SS), bg)
        self.d = ImageDraw.Draw(self.im)

    # -- coordinate helpers -------------------------------------------------
    @staticmethod
    def _p(pts):
        return [(x * SS, y * SS) for x, y in pts]

    # -- primitives ---------------------------------------------------------
    def poly(self, pts, fill, ow: float = OW, outline: str | None = OUTLINE):
        """Filled polygon with a closed rounded outline."""
        p = self._p(pts)
        if fill is not None:
            self.d.polygon(p, fill=fill)
        if outline and ow:
            self.d.line(p + [p[0], p[1]], fill=outline, width=int(ow * SS), joint="curve")

    def rect(self, x0, y0, x1, y1, fill, ow: float = OW, outline: str | None = OUTLINE):
        """Axis-aligned rectangle."""
        self.poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], fill, ow, outline)

    def rrect(self, x0, y0, x1, y1, r, fill, ow: float = OW, outline: str | None = OUTLINE):
        """Rounded rectangle."""
        self.d.rounded_rectangle([x0 * SS, y0 * SS, x1 * SS, y1 * SS], r * SS, fill=fill,
                                 outline=outline if ow else None, width=int(ow * SS))

    def ellipse(self, cx, cy, rx, ry, fill, ow: float = OW, outline: str | None = OUTLINE):
        """Ellipse given by centre and radii."""
        self.d.ellipse([(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS],
                       fill=fill, outline=outline if ow else None, width=int(ow * SS))

    def circle(self, cx, cy, r, fill, ow: float = OW, outline: str | None = OUTLINE):
        """Circle."""
        self.ellipse(cx, cy, r, r, fill, ow, outline)

    def line(self, pts, color=OUTLINE, w: float = OW, joint: bool = True):
        """Poly-line with round-ish joints."""
        self.d.line(self._p(pts), fill=color, width=max(1, int(w * SS)),
                    joint="curve" if joint else None)

    def arc(self, cx, cy, rx, ry, a0, a1, color=OUTLINE, w: float = OW):
        """Elliptical arc (degrees)."""
        self.d.arc([(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS],
                   a0, a1, fill=color, width=max(1, int(w * SS)))

    def blob(self, circles, fill, ow: float = OW, shade=None):
        """Union of ellipses (cx, cy, rx, ry) with ONE merged silhouette outline."""
        for cx, cy, rx, ry in circles:
            self.ellipse(cx, cy, rx + ow, ry + ow, OUTLINE, 0)
        for cx, cy, rx, ry in circles:
            self.ellipse(cx, cy, rx, ry, fill, 0)
        if shade:
            for cx, cy, rx, ry in circles:
                self.ellipse(cx + rx * 0.18, cy + ry * 0.28, rx * 0.72, ry * 0.62, shade, 0)
            for cx, cy, rx, ry in circles:
                self.ellipse(cx - rx * 0.1, cy - ry * 0.12, rx * 0.78, ry * 0.7, fill, 0)

    def text(self, x, y, s, size, fill=OUTLINE, bold=True, anchor="mm"):
        """Text with a DejaVu font (Cyrillic capable)."""
        font = ImageFont.truetype(FONT_BOLD if bold else FONT_REG, int(size * SS))
        self.d.text((x * SS, y * SS), s, font=font, fill=fill, anchor=anchor)

    def clip_lines(self, box, pts_list, color, w=2):
        """Draw lines clipped to a rectangle (for wood grain, shingles...)."""
        x0, y0, x1, y1 = [int(v * SS) for v in box]
        layer = Image.new("L", self.im.size, 0)
        ld = ImageDraw.Draw(layer)
        for pts in pts_list:
            ld.line(self._p(pts), fill=255, width=max(1, int(w * SS)))
        mask = Image.new("L", self.im.size, 0)
        ImageDraw.Draw(mask).rectangle([x0, y0, x1, y1], fill=255)
        layer = ImageChops.multiply(layer, mask)
        self.im.paste(Image.new("RGB", self.im.size, color), (0, 0), layer)

    def poly_clip_lines(self, poly, pts_list, color, w=2):
        """Draw lines clipped to an arbitrary polygon."""
        layer = Image.new("L", self.im.size, 0)
        ld = ImageDraw.Draw(layer)
        for pts in pts_list:
            ld.line(self._p(pts), fill=255, width=max(1, int(w * SS)))
        mask = Image.new("L", self.im.size, 0)
        ImageDraw.Draw(mask).polygon(self._p(poly), fill=255)
        layer = ImageChops.multiply(layer, mask)
        self.im.paste(Image.new("RGB", self.im.size, color), (0, 0), layer)

    def glow(self, cx, cy, r, color, alpha=0.6, squash=1.0):
        """Soft additive-ish radial glow (blurred translucent ellipse)."""
        pad = int(r * SS * 1.6)
        x, y = int(cx * SS), int(cy * SS)
        box = (max(0, x - pad), max(0, y - pad), min(self.im.width, x + pad),
               min(self.im.height, y + pad))
        if box[2] <= box[0] or box[3] <= box[1]:
            return
        lay = Image.new("L", (box[2] - box[0], box[3] - box[1]), 0)
        ImageDraw.Draw(lay).ellipse(
            [x - box[0] - r * SS, y - box[1] - r * SS * squash,
             x - box[0] + r * SS, y - box[1] + r * SS * squash], fill=int(255 * alpha))
        lay = lay.filter(ImageFilter.GaussianBlur(r * SS * 0.35))
        self.im.paste(Image.new("RGB", lay.size, color), box[:2], lay)

    def alpha_poly(self, pts, color, alpha, edge=None, edge_w=2):
        """Translucent polygon composited over the canvas (optional edge)."""
        lay = Image.new("L", self.im.size, 0)
        ImageDraw.Draw(lay).polygon(self._p(pts), fill=int(255 * alpha))
        self.im.paste(Image.new("RGB", self.im.size, color), (0, 0), lay)
        if edge:
            p = self._p(pts)
            self.d.line(p + [p[0]], fill=edge, width=int(edge_w * SS), joint="curve")

    # -- output -------------------------------------------------------------
    def finish(self, path: Path, seed: int = 7, grain: float = 3.0) -> None:
        """Downsample (LANCZOS), add seeded paper grain / brush mottling, save."""
        img = self.im.resize((self.w, self.h), Image.LANCZOS)
        rng = np.random.default_rng(seed)
        arr = np.asarray(img).astype(np.float32)
        low = rng.normal(0, 1, (self.h // 16 + 2, self.w // 16 + 2)).astype(np.float32)
        low_img = Image.fromarray(((low * 40) + 128).clip(0, 255).astype(np.uint8))
        low_img = low_img.resize((self.w, self.h), Image.BICUBIC)
        low_arr = (np.asarray(low_img).astype(np.float32) - 128) / 40.0
        # brush streaks: noise stretched horizontally
        st = rng.normal(0, 1, (self.h, self.w // 24 + 2)).astype(np.float32)
        st_img = Image.fromarray(((st * 40) + 128).clip(0, 255).astype(np.uint8))
        st_arr = (np.asarray(st_img.resize((self.w, self.h), Image.BICUBIC)).astype(np.float32)
                  - 128) / 40.0
        fine = rng.normal(0, 1, (self.h, self.w)).astype(np.float32)
        noise = low_arr * grain * 0.9 + st_arr * grain * 0.5 + np.round(fine) * grain * 0.25
        arr += noise[..., None]
        out = Image.fromarray(arr.clip(0, 255).astype(np.uint8))
        path.parent.mkdir(parents=True, exist_ok=True)
        out.save(path, optimize=True)


def vgrad(c: Canvas, y0, y1, top, bottom, steps=28, x0=0, x1=None):
    """Vertical stepped gradient (flat bands, lubok-like)."""
    x1 = c.w if x1 is None else x1
    for i in range(steps):
        ya = y0 + (y1 - y0) * i / steps
        yb = y0 + (y1 - y0) * (i + 1) / steps + 1
        c.rect(x0, ya, x1, yb, mix(top, bottom, i / (steps - 1)), 0, None)


def cloud(c: Canvas, x, y, s=1.0, fill="#F6EDD6", shade="#D8DCE0"):
    """Puffy cloud with one merged outline."""
    parts = [(x, y, 70 * s, 30 * s), (x - 60 * s, y + 10 * s, 45 * s, 24 * s),
             (x + 62 * s, y + 8 * s, 48 * s, 26 * s), (x + 10 * s, y - 24 * s, 42 * s, 28 * s)]
    c.blob(parts, fill, shade=shade)


def tuft(c: Canvas, x, y, s=1.0, col="#5A7D3F", col2="#86A85A"):
    """Grass tuft of pointed blades."""
    for i, dx in enumerate((-9, -4, 0, 5, 10)):
        h = (22 + (i * 7) % 11) * s
        lean = (i - 2) * 3 * s
        c.poly([(x + dx * s - 3 * s, y), (x + dx * s + lean, y - h), (x + dx * s + 3 * s, y)],
               col if i % 2 else col2, 2)


def flower(c: Canvas, x, y, s=1.0, petal="#E8E3D2", heart="#D9A441"):
    """Small five-petal meadow flower on a stalk."""
    c.line([(x, y), (x, y + 18 * s)], "#4C6B34", 3)
    for k in range(5):
        a = k * 2 * math.pi / 5
        c.circle(x + math.cos(a) * 5 * s, y + math.sin(a) * 5 * s, 3.6 * s, petal, 2)
    c.circle(x, y, 3.4 * s, heart, 2)


# --------------------------------------------------------------------------
# shared props
# --------------------------------------------------------------------------
CREAM = "#F3E5C0"
WOOD = "#7A5C3A"
WOOD_D = "#573E25"
WOOD_L = "#A07C4C"
OCHRE = "#D9A441"
OCHRE_D = "#B07F2C"
MOSS = "#6B8E4E"
MOSS_D = "#4C6B34"
MOSS_L = "#8FB066"
SKY = "#9CC3D5"
BRICK = "#B0492F"
BRASS = "#E2B64A"
BRASS_D = "#A8782A"


def beam(c: Canvas, p0, p1, th, fill, ow=OW):
    """Thick straight beam between two points."""
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    n = math.hypot(dx, dy) or 1
    nx, ny = -dy / n * th / 2, dx / n * th / 2
    c.poly([(p0[0] + nx, p0[1] + ny), (p1[0] + nx, p1[1] + ny),
            (p1[0] - nx, p1[1] - ny), (p0[0] - nx, p0[1] - ny)], fill, ow)


def cuckoo_clock(c: Canvas, cx, top, s=1.0, shade="#5A4128"):
    """Cuckoo clock: gabled case, face, bird in a door, pendulum, cone weights.

    ``(cx, top)`` is the roof apex; base size is ~130 x 235 logical pixels.
    """
    def T(x, y):
        return (cx + x * s, top + y * s)

    ow = max(2, OW * min(1, s + 0.35))
    # chains + pinecone weights (behind the case)
    for sx in (-34, 34):
        c.line([T(sx, 140), T(sx, 196)], OUTLINE, ow)
        c.poly([T(sx - 10, 196), T(sx + 10, 196), T(sx + 12, 222), T(sx, 240), T(sx - 12, 222)],
               "#8A6A3E", ow)
        c.poly_clip_lines([T(sx - 10, 196), T(sx + 10, 196), T(sx + 12, 222), T(sx, 240),
                           T(sx - 12, 222)],
                          [[T(sx - 14, 206 + k * 9), T(sx + 14, 206 + k * 9 + 7)]
                           for k in range(4)], "#5A4128", max(1, 2 * s))
    # pendulum
    c.line([T(0, 140), T(0, 190)], OUTLINE, ow)
    c.circle(*T(0, 200), 15 * s, BRASS, ow)
    c.circle(*T(0, 200), 6 * s, BRASS_D, 0)
    # case
    c.rect(*T(-50, 44), *T(50, 150), WOOD_L, ow)
    c.rect(*T(-50, 44), *T(-34, 150), mix(WOOD_L, "#5A4128", .35), 0)
    c.rect(*T(-50, 44), *T(50, 150), None, ow)
    # roof
    c.poly([T(0, 0), T(72, 46), T(-72, 46)], WOOD, ow)
    c.poly_clip_lines([T(0, 0), T(72, 46), T(-72, 46)],
                      [[T(-80, 12 + k * 9), T(80, 12 + k * 9)] for k in range(5)],
                      WOOD_D, max(1, 2 * s))
    c.circle(*T(0, 0), 5 * s, BRASS, ow)
    # little door with the bird
    c.rect(*T(-12, 52), *T(12, 76), "#2F2018", ow)
    c.ellipse(*T(0, 68), 9 * s, 7 * s, "#F1C84B", ow)
    c.poly([T(8, 66), T(19, 69), T(8, 71)], BRICK, max(1, ow - 1))
    c.circle(*T(-1, 65), 1.6 * s, OUTLINE, 0)
    # face
    c.circle(*T(0, 108), 29 * s, CREAM, ow)
    for k in range(12):
        a = k * math.pi / 6
        c.line([T(math.sin(a) * 22, 108 - math.cos(a) * 22),
                T(math.sin(a) * 26, 108 - math.cos(a) * 26)], OUTLINE, max(1.5, 2 * s))
    c.line([T(0, 108), T(0, 90)], OUTLINE, max(1.5, 2.5 * s))
    c.line([T(0, 108), T(13, 114)], OUTLINE, max(1.5, 2.5 * s))
    c.circle(*T(0, 108), 2.5 * s, BRICK, 0)
    # carved leaves on the sides
    for sx in (-1, 1):
        c.ellipse(*T(sx * 58, 96), 8 * s, 18 * s, MOSS, ow)


# --------------------------------------------------------------------------
# prompt 7: manor courtyard
# --------------------------------------------------------------------------
def carved_window(c: Canvas, x0, y0, x1, y1, interior="glass", shutter=BRICK):
    """Window with carved casing, pediment, scalloped apron and open shutters."""
    w = x1 - x0
    sw = w * 0.30
    # shutters (open, drawn behind casing)
    for side in (-1, 1):
        sx0 = x0 - 14 - sw if side < 0 else x1 + 14
        c.rect(sx0, y0 - 6, sx0 + sw, y1 + 6, shutter, OW)
        c.rect(sx0 + 6, y0 + 6, sx0 + sw - 6, y1 - 6, mix(shutter, "#F3E5C0", .15), 2)
        cx, cy = sx0 + sw / 2, (y0 + y1) / 2
        c.poly([(cx, cy - 16), (cx + 11, cy), (cx, cy + 16), (cx - 11, cy)], "#2F2018", 2)
    # casing
    c.rect(x0 - 14, y0 - 14, x1 + 14, y1 + 14, WOOD_L, OW)
    c.rect(x0 - 14, y0 - 14, x0 - 6, y1 + 14, mix(WOOD_L, WOOD_D, .35), 0)
    # glass / interior
    if interior == "glass":
        c.rect(x0, y0, x1, y1, "#BFD9DA", OW)
        c.poly([(x0 + 8, y1 - 8), (x0 + 40, y0 + 8), (x0 + 58, y0 + 8), (x0 + 26, y1 - 8)],
               "#E6F0E2", 0)
        c.line([((x0 + x1) / 2, y0), ((x0 + x1) / 2, y1)], OUTLINE, 3)
        c.line([(x0, (y0 + y1) / 2), (x1, (y0 + y1) / 2)], OUTLINE, 3)
        c.poly([(x0, y0), (x0 + w * .5, y0), (x0, y0 + 36)], BRICK, 2)   # curtain corner
    else:
        c.rect(x0, y0, x1, y1, "#3A2A22", OW)
    # pediment with discs
    c.poly([(x0 - 28, y0 - 14), (x1 + 28, y0 - 14), (x1 + 6, y0 - 48), (x0 - 6, y0 - 48)],
           WOOD, OW)
    for k in range(4):
        c.circle(x0 + w * (k + .5) / 4, y0 - 31, 6, OCHRE if k % 2 == 0 else CREAM, 2)
    # apron with scallops
    c.rect(x0 - 22, y1 + 14, x1 + 22, y1 + 26, WOOD, OW)
    n = int((w + 44) / 20)
    for k in range(n):
        c.circle(x0 - 22 + (k + .5) * (w + 44) / n, y1 + 28, 10, WOOD_L, 2)
    return x0, y0, x1, y1


def draw_house(c: Canvas) -> None:
    """Log manor house: roof, courses, windows, porch (mid plane)."""
    gx0, gx1, gy0, gy1 = 480, 1560, 330, 645
    # ground shadow of the house (coloured, falls right)
    c.poly([(gx0 - 10, gy1 - 6), (gx1 + 10, gy1 - 6), (gx1 + 210, gy1 + 36), (gx0 + 140, gy1 + 56)],
           "#4F6E5A", 0, None)
    # walls
    c.rect(gx0, gy0, gx1, gy1, OCHRE, OW)
    courses = [[(gx0, y), (gx1, y)] for y in range(gy0 + 26, gy1, 26)]
    c.clip_lines((gx0, gy0, gx1, gy1), courses, OCHRE_D, 3)
    c.clip_lines((gx0, gy0, gx1, gy1), [[(gx0, y + 9), (gx1, y + 9)] for y in range(gy0 + 26, gy1, 26)],
                 "#E8BB5E", 2)
    for y in range(gy0 + 4, gy1 - 20, 26):       # protruding corner log ends
        for x in (gx0 - 12, gx1 - 14):
            c.rrect(x, y, x + 26, y + 22, 8, OCHRE, 2)
            c.circle(x + 13, y + 11, 5, OCHRE_D, 0)
    # plinth
    c.rect(gx0 - 12, gy1 - 18, gx1 + 12, gy1 + 8, "#8E8068", OW)
    c.clip_lines((gx0, gy1 - 18, gx1, gy1 + 8),
                 [[(x, gy1 - 18), (x - 8, gy1 + 8)] for x in range(gx0, gx1, 34)], "#6C604C", 2)
    # roof
    roof = [(gx0 - 56, gy0 + 10), (gx1 + 56, gy0 + 10), (gx1 - 30, 190), (gx0 + 30, 190)]
    c.poly(roof, WOOD, OW)
    rows = []
    for k in range(7):
        y = 190 + k * 20
        rows.append([(gx0 - 60, y), (gx1 + 60, y)])
    c.poly_clip_lines(roof, rows, WOOD_D, 3)
    scal = []
    for k in range(7):
        y = 190 + k * 20
        for x in range(gx0 - 50, gx1 + 60, 26):
            off = 13 if k % 2 else 0
            scal.append([(x + off, y), (x + off + 13, y + 10), (x + off + 26, y)])
    c.poly_clip_lines(roof, scal, WOOD_L, 2)
    c.poly([(gx0 - 56, gy0 + 10), (gx1 + 56, gy0 + 10), (gx1 + 56, gy0 + 22), (gx0 - 56, gy0 + 22)],
           WOOD_D, OW)
    # ridge board with carved ornaments
    c.rect(gx0 + 10, 176, gx1 - 10, 194, WOOD_D, OW)
    for x in range(gx0 + 40, gx1 - 30, 44):
        c.circle(x, 168, 8, OCHRE, 2)
        c.circle(x, 168, 3, BRICK, 0)
    # chimney
    c.rect(1290, 100, 1360, 200, "#B5694C", OW)
    c.clip_lines((1290, 100, 1360, 200), [[(1290, y), (1360, y)] for y in range(116, 200, 16)],
                 "#8A4A34", 2)
    c.rect(1280, 88, 1370, 108, "#8A4A34", OW)
    for (sx, sy, sr) in ((1330, 62, 20), (1352, 30, 26), (1386, 4, 28)):
        c.circle(sx, sy, sr, "#EFE7D6", OW)
    # eave shadow on the wall
    c.rect(gx0 + 2, gy0 + 12, gx1 - 2, gy0 + 40, OCHRE_D, 0, None)
    # windows
    carved_window(c, 560, 420, 760, 585, interior="dark")
    carved_window(c, 1180, 430, 1300, 570)
    carved_window(c, 1400, 430, 1520, 570)
    # cuckoo clock sitting in the dark window
    c.rect(556, 578, 764, 592, WOOD_L, 2)
    cuckoo_clock(c, 660, 424, 0.66)
    c.glow(660, 510, 80, "#F3D58A", .22)


def draw_porch(c: Canvas) -> None:
    """Carved porch with turned posts, valance, door and steps."""
    px0, px1 = 850, 1130
    # door
    c.rect(930, 455, 1050, 620, WOOD, OW)
    c.clip_lines((930, 455, 1050, 620), [[(x, 455), (x, 620)] for x in range(950, 1050, 20)],
                 WOOD_D, 3)
    c.rect(946, 470, 1034, 535, WOOD_L, 3)
    c.rect(946, 548, 1034, 604, WOOD_L, 3)
    c.circle(1030, 590, 5, BRASS, 2)
    # deck
    c.rect(px0 - 20, 612, px1 + 20, 650, WOOD_L, OW)
    c.clip_lines((px0, 612, px1, 650), [[(x, 612), (x, 650)] for x in range(px0 - 20, px1 + 20, 28)],
                 WOOD_D, 2)
    # steps
    for k in range(3):
        c.rect(px0 + 30 - k * 14, 650 + k * 18, px1 - 30 + k * 14, 668 + k * 18,
               WOOD_L if k % 2 == 0 else WOOD, OW)
    # balusters + rail
    for x in range(px0 + 18, px1, 26):
        c.poly([(x - 4, 566), (x + 4, 566), (x + 7, 590), (x + 4, 612), (x - 4, 612),
                (x - 7, 590)], CREAM, 2)
    c.rect(px0 - 6, 556, px1 + 6, 570, WOOD, OW)
    # posts with bulb capitals
    for x in (px0, px1):
        c.rect(x - 12, 452, x + 12, 612, WOOD, OW)
        c.rect(x - 12, 452, x - 4, 612, WOOD_D, 0)
        c.ellipse(x, 474, 20, 12, OCHRE, OW)
        c.ellipse(x, 540, 17, 9, OCHRE, OW)
        c.rect(x - 20, 440, x + 20, 456, WOOD_L, OW)
    # roof of the porch
    c.poly([(px0 - 60, 446), (px1 + 60, 446), (px1 + 20, 376), (px0 - 20, 376)], WOOD, OW)
    rows = [[(px0 - 70, y), (px1 + 70, y)] for y in range(386, 446, 16)]
    c.poly_clip_lines([(px0 - 60, 446), (px1 + 60, 446), (px1 + 20, 376), (px0 - 20, 376)],
                      rows, WOOD_D, 3)
    # hanging carved valance (подзор)
    n = 14
    wv = (px1 - px0 + 80) / n
    c.rect(px0 - 40, 446, px1 + 40, 458, OCHRE, OW)
    for k in range(n):
        x = px0 - 40 + (k + .5) * wv
        c.poly([(x - wv / 2, 458), (x + wv / 2, 458), (x + wv / 2 - 3, 478), (x, 496),
                (x - wv / 2 + 3, 478)], CREAM if k % 2 == 0 else OCHRE, 2)
        c.circle(x, 474, 3.5, BRICK, 0)
    # lantern hanging by the door
    c.line([(1085, 458), (1085, 490)], OUTLINE, 2)
    c.rect(1075, 490, 1095, 520, "#F3D58A", 2)
    c.poly([(1072, 490), (1098, 490), (1085, 480)], BRICK, 2)
    # welcome mat
    c.poly([(940, 620), (1040, 620), (1050, 632), (930, 632)], BRICK, 2)


def draw_well(c: Canvas) -> None:
    """Crane well (колодец-журавль): log frame, sweep pole, rod, bucket."""
    # shadow
    c.poly([(1460, 676), (1660, 676), (1890, 712), (1570, 726)], "#4F6E5A", 0, None)
    # log frame
    c.rect(1470, 592, 1650, 676, WOOD, OW)
    c.clip_lines((1470, 592, 1650, 676), [[(1470, y), (1650, y)] for y in (620, 648)],
                 WOOD_D, 3)
    for y in (592, 620, 648):
        c.rrect(1458, y, 1488, y + 28, 8, WOOD_L, 2)
        c.rrect(1632, y, 1662, y + 28, 8, WOOD_L, 2)
    c.ellipse(1560, 592, 90, 18, "#2F2018", OW)           # well mouth
    c.ellipse(1560, 596, 70, 11, "#1D3340", 0)
    # post with fork
    beam(c, (1741, 676), (1741, 336), 24, WOOD)
    c.line([(1731, 560), (1700, 676)], OUTLINE, 6)        # brace
    c.line([(1751, 560), (1782, 676)], OUTLINE, 6)
    c.poly([(1722, 350), (1708, 300), (1722, 296), (1730, 340)], WOOD, 3)
    c.poly([(1760, 350), (1774, 300), (1760, 296), (1752, 340)], WOOD, 3)
    # sweep
    beam(c, (1538, 244), (1880, 392), 16, WOOD_L)
    c.circle(1741, 328, 8, BRASS, 3)
    # counterweight stone
    c.ellipse(1884, 420, 32, 26, "#9A958C", OW)
    c.ellipse(1876, 412, 14, 9, "#C3BFB4", 0)
    c.line([(1880, 392), (1884, 400)], OUTLINE, 3)
    # rod + bucket
    c.line([(1548, 250), (1548, 470)], OUTLINE, 3)
    c.poly([(1520, 470), (1576, 470), (1568, 520), (1528, 520)], WOOD_L, OW)
    for y in (482, 502):
        c.line([(1522, y), (1574, y)], BRASS_D, 3)
    c.ellipse(1548, 470, 28, 6, "#1D3340", 2)


def draw_far_plane(c: Canvas, hy: int) -> None:
    """Distant plane: hills, tree line, tiny village (muted tones)."""
    far = "#8DB4A6"
    pts = [(0, hy)]
    for x in range(0, 2049, 32):
        pts.append((x, hy - 70 - 26 * math.sin(x / 210.0) - 14 * math.sin(x / 83.0 + 1)))
    pts.append((2048, hy))
    c.poly(pts, far, OW)
    pts2 = [(0, hy + 20)]
    for x in range(0, 2049, 32):
        pts2.append((x, hy - 28 - 20 * math.sin(x / 150.0 + 2)))
    pts2.append((2048, hy + 20))
    c.poly(pts2, "#7AA38A", OW)
    # tree line
    rnd = random.Random(11)
    x = -20
    while x < 2080:
        r = rnd.randint(22, 38)
        y = hy - 20 - rnd.randint(0, 22)
        tone = rnd.choice(["#5F8C5A", "#55814F", "#6A9863"])
        c.blob([(x, y, r, r * 1.15), (x + r * .6, y + 8, r * .8, r * .9)], tone, shade="#4A7347")
        x += rnd.randint(34, 58)
    # tiny village
    for hx, hw, col in ((300, 70, "#C9A06A"), (420, 52, "#B8895A"), (1790, 64, "#C9A06A"),
                        (1900, 74, "#B8895A")):
        c.rect(hx, hy - 38, hx + hw, hy - 6, col, 2)
        c.poly([(hx - 8, hy - 38), (hx + hw + 8, hy - 38), (hx + hw / 2, hy - 68)],
               "#6E5238", 2)
        c.rect(hx + hw / 2 - 6, hy - 30, hx + hw / 2 + 6, hy - 18, "#F3D58A", 2)


def draw_birch(c: Canvas, x: int, lean: int, width: int, seed: int) -> None:
    """Foreground birch trunk with dark bark marks and leaf masses."""
    rnd = random.Random(seed)
    top = -20
    trunk = [(x - width / 2, 1040), (x - width / 2 * .7 + lean, top), (x + width / 2 * .7 + lean, top),
             (x + width / 2, 1040)]
    c.poly(trunk, "#F1ECDD", OW)
    c.poly([(x + width * .1, 1040), (x + width * .1 + lean * .1, top),
            (x + width / 2 * .7 + lean, top), (x + width / 2, 1040)], "#D3CFE0", 0)
    c.poly(trunk, None, OW)
    for y in range(40, 1000, 54):
        wv = width * rnd.uniform(.25, .55)
        xx = x + lean * (1 - y / 1040) + rnd.uniform(-width * .15, width * .15)
        c.poly([(xx - wv / 2, y), (xx + wv / 2, y - 3), (xx + wv / 2 - 4, y + 11),
                (xx - wv / 2 + 3, y + 9)], OUTLINE, 0, None)
    # leaf masses
    for _ in range(7):
        bx = x + lean + rnd.randint(-150, 150)
        by = rnd.randint(10, 260)
        c.blob([(bx, by, 62, 40), (bx + 38, by + 22, 46, 32), (bx - 40, by + 18, 44, 30)],
               rnd.choice([MOSS_L, "#7FA55A", "#9AB96A"]), shade=MOSS)
        for k in range(3):                              # hanging catkin-like strands
            sx = bx - 30 + k * 30
            c.line([(sx, by + 34), (sx + 4, by + 70 + k * 6)], MOSS_D, 4)


def draw_wattle_fence(c: Canvas, x0: int, x1: int, y: int) -> None:
    """Foreground wattle fence (плетень) with clay pots on stakes."""
    h = 120
    c.rect(x0, y, x1, y + h, "#9A7448", OW)
    for xx in range(x0 + 20, x1, 30):
        c.rect(xx - 6, y - 24, xx + 6, y + h + 20, WOOD, OW)
        c.poly([(xx - 6, y - 24), (xx + 6, y - 24), (xx, y - 40)], WOOD, 2)
    for k, yy in enumerate(range(y + 10, y + h, 24)):
        pts = []
        for xx in range(x0, x1 + 1, 10):
            pts.append((xx, yy + 8 * math.sin(xx / 14.0 + k * 1.7)))
        c.line(pts, WOOD_D if k % 2 else "#C9A06A", 9)
        c.line(pts, OUTLINE, 3) if False else None
    c.rect(x0, y, x1, y + h, None, OW)
    for xx, col in ((x0 + 80, BRICK), (x0 + 380, OCHRE), (x0 + 560, "#C0693C")):
        c.poly([(xx - 22, y - 44), (xx + 22, y - 44), (xx + 30, y - 76), (xx + 20, y - 100),
                (xx - 20, y - 100), (xx - 30, y - 76)], col, OW)
        c.rect(xx - 26, y - 106, xx + 26, y - 96, col, OW)
        c.poly([(xx - 14, y - 70), (xx - 4, y - 90), (xx + 14, y - 70)], mix(col, CREAM, .5), 2)


def sunflower(c: Canvas, x, y, r=34, seed=3):
    """Sunflower on a tall stalk."""
    c.line([(x, y), (x + 6, 1030)], MOSS_D, 8)
    c.ellipse(x + 38, y + 150, 36, 12, "#3F6A30", OW)
    c.ellipse(x - 36, y + 230, 36, 12, "#3F6A30", OW)
    for k in range(14):
        a = k * 2 * math.pi / 14
        px, py = x + math.cos(a) * r * 1.1, y + math.sin(a) * r * 1.1
        c.ellipse(px, py, r * .42, r * .26, "#F1C84B", 2)
    c.circle(x, y, r * .72, "#5A3B20", OW)
    c.circle(x, y, r * .35, "#7A5C3A", 0)


def scene_courtyard() -> Canvas:
    """Prompt 7: 2048x1024 manor courtyard, three depth planes."""
    c = Canvas(2048, 1024, SKY)
    hy = 560
    vgrad(c, 0, hy, "#7FAEC6", "#D6E4D4")
    # sun and clouds
    for k in range(12):
        a = k * math.pi / 6
        c.poly([(860 + math.cos(a - .12) * 52, 90 + math.sin(a - .12) * 52),
                (860 + math.cos(a) * 72, 90 + math.sin(a) * 72),
                (860 + math.cos(a + .12) * 52, 90 + math.sin(a + .12) * 52)], "#F3D58A", 2)
    c.circle(860, 90, 42, "#F7E3A4", OW)
    for (x, y, s) in ((300, 150, 1.2), (780, 260, .8), (1640, 190, 1.1), (1950, 330, .7)):
        cloud(c, x, y, s)
    draw_far_plane(c, hy)
    # ground
    c.rect(0, hy - 2, 2048, 1024, MOSS, 0, None)
    vgrad(c, hy, 1024, "#789A57", "#5E8043", 20)
    c.line([(0, hy), (2048, hy)], OUTLINE, OW)
    # grass tone patches
    rnd = random.Random(5)
    for _ in range(46):
        gx, gy = rnd.randint(0, 2048), rnd.randint(hy + 20, 1000)
        c.ellipse(gx, gy, rnd.randint(40, 110), rnd.randint(6, 14), mix(MOSS, MOSS_D, .5), 0)
    # path
    c.poly([(930, 668), (1090, 668), (1420, 1024), (560, 1024)], "#D2A862", OW)
    c.poly([(930, 668), (960, 668), (900, 1024), (560, 1024)], "#B88A48", 0, None)
    for _ in range(40):
        t = rnd.random()
        py = 700 + t * 310
        spread = 70 + t * 330
        c.ellipse(1010 + rnd.uniform(-spread, spread) * .85, py, 7 + t * 8, 3 + t * 3, "#A87C3E", 2)
    # mid plane
    draw_house(c)
    draw_porch(c)
    draw_well(c)
    # bushes beside the house
    for bx in (470, 1570):
        c.blob([(bx, 640, 50, 34), (bx + 46, 648, 40, 28), (bx - 44, 650, 36, 26)], MOSS_L,
               shade=MOSS_D)
        for k in range(5):
            c.circle(bx - 40 + k * 20, 640 + (k % 2) * 8, 5, BRICK, 2)
    # foreground plane
    draw_birch(c, 70, 40, 78, 1)
    draw_birch(c, 340, -20, 40, 2)
    draw_wattle_fence(c, 0, 760, 850)
    # firewood stack + barrel at lower right
    for row in range(4):
        for k in range(6 - row // 2):
            x = 1500 + k * 44 + (row % 2) * 22
            c.circle(x, 940 - row * 38, 22, "#B98F58", OW)
            c.circle(x, 940 - row * 38, 10, "#8E6A3C", 2)
    c.poly([(1470, 985), (1830, 985), (1860, 1010), (1450, 1010)], "#4F6E5A", 0, None)
    sunflower(c, 1930, 640, 40)
    sunflower(c, 1990, 720, 32)
    sunflower(c, 1860, 760, 30)
    # grass and flowers in the foreground
    for _ in range(30):
        tuft(c, rnd.randint(780, 1500), rnd.randint(900, 1020), rnd.uniform(1.0, 1.7))
    for _ in range(26):
        flower(c, rnd.randint(760, 1900), rnd.randint(860, 990), rnd.uniform(.9, 1.4),
               petal=rnd.choice(["#F3E5C0", "#F1C84B", "#D8826F"]))
    for x in range(0, 2048, 70):
        tuft(c, x + 20, 1030, 1.5, "#4A6A33", "#6B8E4E")
    return c


# --------------------------------------------------------------------------
# prompt 8: night archive of seals (stealth)
# --------------------------------------------------------------------------
NIGHT = "#1F2430"
NIGHT_L = "#2D3446"
LAMP = "#F3D58A"
CAB = "#4B3A2A"


class Persp:
    """One-point perspective projection for the archive corridor."""

    def __init__(self, vx=512, vy=430, f=420):
        self.vx, self.vy, self.f = vx, vy, f

    def __call__(self, x, y, z):
        """x right, y down (camera at y=0), z forward."""
        return (self.vx + x * self.f / z, self.vy + y * self.f / z)


def convex_hull(pts):
    """Andrew monotone-chain convex hull of 2-D points."""
    pts = sorted(set((round(x, 2), round(y, 2)) for x, y in pts))

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lo, up = [], []
    for p in pts:
        while len(lo) >= 2 and cross(lo[-2], lo[-1], p) <= 0:
            lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(up) >= 2 and cross(up[-2], up[-1], p) <= 0:
            up.pop()
        up.append(p)
    return lo[:-1] + up[:-1]


def samovar_lamp(c: Canvas, cx, top, s, chain_to=None):
    """Hanging lamp shaped like a samovar (urn, lid, tap, handles, chimney)."""
    ow = max(2, OW * min(1.0, s + .4))

    def T(x, y):
        return (cx + x * s, top + y * s)
    c.line([(cx, chain_to if chain_to is not None else top - 400 * s), T(0, 0)], OUTLINE, ow)
    c.poly([T(-5, 0), T(5, 0), T(5, 24), T(-5, 24)], BRASS_D, ow)       # chimney
    c.poly([T(-22, 24), T(22, 24), T(30, 38), T(-30, 38)], BRASS, ow)  # lid
    body = [T(-28, 38), T(28, 38), T(46, 62), T(48, 92), T(36, 118), T(-36, 118),
            T(-48, 92), T(-46, 62)]
    c.poly(body, LAMP, ow)
    c.poly([T(-28, 38), T(-6, 38), T(-18, 62), T(-22, 118), T(-36, 118), T(-48, 92), T(-46, 62)],
           "#FFF0C4", 0)
    c.poly(body, None, ow)
    for sx in (-1, 1):
        c.ellipse(*T(sx * 54, 68), 8 * s, 10 * s, BRASS_D, ow)          # handles
    c.poly([T(48, 90), T(66, 86), T(66, 96), T(48, 100)], BRASS, ow)    # tap
    c.rect(*T(-40, 118), *T(40, 132), BRASS_D, ow)                        # base
    c.line([T(-30, 76), T(30, 76)], BRASS_D, max(1.5, 3 * s))


def draw_cabinet_wall(c: Canvas, P: Persp, side: int, zs, xw=2.5, y_top=-2.5, y_bot=1.55):
    """Cabinets along a wall, from far to near. ``side`` -1 left, +1 right."""
    x = side * xw
    for z0, z1 in zip(zs[:-1], zs[1:]):
        quad = [P(x, y_top, z0), P(x, y_top, z1), P(x, y_bot, z1), P(x, y_bot, z0)]
        k = (z0 - 1) / 14.0
        base = mix(CAB, NIGHT, min(.7, .3 + k * .7))
        c.poly(quad, base, 2.5)
        # drawers grid: 3 columns along z, 8 rows
        cols, rows = 3, 8
        for i in range(cols):
            for j in range(rows):
                za = z0 + (z1 - z0) * (i + .1) / cols
                zb = z0 + (z1 - z0) * (i + .9) / cols
                ya = y_top + (y_bot - y_top) * (j + .12) / rows
                yb = y_top + (y_bot - y_top) * (j + .88) / rows
                dq = [P(x, ya, za), P(x, ya, zb), P(x, yb, zb), P(x, yb, za)]
                c.poly(dq, mix("#6A5236", NIGHT, min(.8, .3 + k)), 1.5)
                kn = P(x, (ya + yb) / 2, (za + zb) / 2)
                c.circle(kn[0], kn[1], max(1.2, 140 / (z0 + 1) / 10), BRASS_D, 0)
                lab = [P(x, ya + .08, za + .1 * (zb - za)), P(x, ya + .08, zb - .1 * (zb - za)),
                       P(x, ya + .22, zb - .1 * (zb - za)), P(x, ya + .22, za + .1 * (zb - za))]
                c.poly(lab, mix(CREAM, NIGHT, min(.85, .5 + k * .5)), 0, None)
    # top cornice
    c.line([P(x, y_top, zs[0]), P(x, y_top, zs[-1])], OUTLINE, 4)


def scene_archive() -> Canvas:
    """Prompt 8: 1024x1024 night archive with lamp cones (stealth zones)."""
    W = H = 1024
    c = Canvas(W, H, NIGHT)
    P = Persp(512, 440, 430)
    zfar = 15.0
    xw, yt, yb = 2.5, -2.5, 1.55
    # ceiling and floor, back wall
    c.poly([P(-xw, yt, 1.2), P(xw, yt, 1.2), P(xw, yt, zfar), P(-xw, yt, zfar)], "#161A25", 0, None)
    c.poly([P(-xw, yb, 1.2), P(xw, yb, 1.2), P(xw, yb, zfar), P(-xw, yb, zfar)], NIGHT_L, 0, None)
    c.rect(*P(-xw, yt, zfar), *P(xw, yb, zfar), "#262C3C", 0)
    # checkered floor
    n_x = 5
    zlist = [1.2]
    z = 1.2
    while z < zfar:
        z += 0.9
        zlist.append(min(z, zfar))
    for i in range(len(zlist) - 1):
        for j in range(n_x):
            xa = -xw + j * (2 * xw / n_x)
            xb = xa + 2 * xw / n_x
            col = "#3A4258" if (i + j) % 2 == 0 else "#171B26"
            c.poly([P(xa, yb, zlist[i]), P(xb, yb, zlist[i]), P(xb, yb, zlist[i + 1]),
                    P(xa, yb, zlist[i + 1])], col, 1.2, "#10131B")
    # ceiling beams
    zb = 2.0
    while zb < zfar:
        c.poly([P(-xw, yt, zb), P(xw, yt, zb), P(xw, yt + .25, zb), P(-xw, yt + .25, zb)],
               "#2A2118", 2)
        zb += 2.4
    # back wall: tall window with moon and a big cabinet door
    bw = [P(-.9, -1.9, zfar), P(.9, -1.9, zfar), P(.9, yb, zfar), P(-.9, yb, zfar)]
    c.poly(bw, "#3B2F22", 3)
    c.rect(*P(-.6, -1.5, zfar), *P(.6, -0.2, zfar), "#2B4668", 3)
    c.circle(*P(.15, -1.1, zfar), 9, "#EDE7C8", 2)
    # cabinet walls
    zs = [zfar - 0.0]
    z = zfar
    while z > 1.3:
        z = max(1.3, z - 1.35)
        zs.append(z)
    zs_far_to_near = zs                # descending z = far -> near
    for side in (-1, 1):
        # painter's order: far first (descending list order)
        for z0, z1 in zip(zs_far_to_near[:-1], zs_far_to_near[1:]):
            draw_cabinet_wall(c, P, side, [z1, z0], xw, yt, yb)
    # open drawers and a library ladder for readability
    for z0, j in ((5.2, 3), (9.4, 5)):
        a, b = P(-xw, -1.0 + j * .1, z0), P(-xw + .5, -1.0 + j * .1, z0 - .1)
        c.poly([a, (b[0], b[1]), (b[0], b[1] + 20), (a[0], a[1] + 20)], "#6A5236", 2)
    la = [P(xw - .05, -2.2, 6.4), P(xw - .05, 1.55, 6.4), P(xw - .55, 1.55, 6.8),
          P(xw - .55, -2.2, 6.8)]
    c.poly(la, "#7A5C3A", 2)
    for k in range(9):
        yy = -2.0 + k * .4
        c.line([P(xw - .05, yy, 6.4), P(xw - .55, yy, 6.8)], OUTLINE, 3)
    # lamps hang at staggered lateral positions so dark gaps remain (hiding spots)
    lamps = [(-0.9, 2.9), (0.9, 5.3), (-0.8, 8.3), (0.8, 11.8)]
    ly = -1.55                                     # lamp base height (camera at 0)
    for lx, lz in lamps:
        for sx in (-1, 1):
            gx, gy = P(sx * xw, ly + .2, lz)
            c.glow(gx, gy, 480 / lz, "#6E5428", .5)
    for lx, lz in sorted(lamps, key=lambda a: -a[1]):
        r = 1.15
        apex = P(lx, ly + .02, lz)
        ring = [P(lx + r * math.cos(math.radians(t)), yb, lz + r * math.sin(math.radians(t)))
                for t in range(0, 360, 8)]
        hull = convex_hull([apex] + ring)
        c.alpha_poly(hull, LAMP, .24, edge="#F3D58A", edge_w=2)
        core = [(apex[0] + (p[0] - apex[0]) * .55, apex[1] + (p[1] - apex[1]) * .55) for p in hull]
        c.alpha_poly(core, "#FFF3C8", .14)
        c.alpha_poly(ring, LAMP, .34, edge="#F3D58A", edge_w=3)
        c.glow(apex[0], apex[1] - 30 * 1.6 / lz, 260 / lz, LAMP, .5)
        s = 2.7 / lz
        ceil_y = P(lx, yt, lz)[1]
        samovar_lamp(c, apex[0], apex[1] - 132 * s, s, chain_to=ceil_y)
    return c


# --------------------------------------------------------------------------
# prompt 9: fair square
# --------------------------------------------------------------------------
FR, FY, FB, FG = "#C94A3B", "#F1C84B", "#3C6FB2", "#5FA05A"
FSH = "#6B3F73"          # coloured (violet) shadow tone
FCREAM = "#F8EBCB"


def striped_rect(c: Canvas, x0, y0, x1, y1, n, cols, ow=OW):
    """Vertical striped rectangle."""
    for i in range(n):
        c.rect(x0 + (x1 - x0) * i / n, y0, x0 + (x1 - x0) * (i + 1) / n + .5, y1,
               cols[i % len(cols)], 0, None)
    c.rect(x0, y0, x1, y1, None, ow)


def striped_roof(c: Canvas, apex, x0, x1, yb, n, cols, scallop=True, ow=OW):
    """Cone/tent roof with colour wedges and a scalloped skirt."""
    seg = (x1 - x0) / n
    if scallop:
        for i in range(n):
            c.circle(x0 + seg * (i + .5), yb, seg / 2, cols[i % len(cols)], 2.5)
    for i in range(n):
        c.poly([apex, (x0 + seg * i, yb), (x0 + seg * (i + 1), yb)], cols[i % len(cols)], 0, None)
    c.poly([apex, (x0, yb), (x1, yb)], None, ow)
    for i in range(1, n):
        c.line([apex, (x0 + seg * i, yb)], OUTLINE, 1.5)


def pennant(c: Canvas, x, y, col, length=46, up=True):
    """Small swallow-tail pennant on a pole top."""
    c.line([(x, y), (x, y - 24)], OUTLINE, 3)
    c.poly([(x, y - 24), (x + length, y - 18), (x + length - 12, y - 12), (x + length, y - 6),
            (x, y - 4)], col, 2)


def bunting(c: Canvas, p0, p1, sag, n, cols=(FR, FY, FB, FG)):
    """String of triangular flags hanging along a sagging curve."""
    pts = []
    for i in range(41):
        t = i / 40
        pts.append((p0[0] + (p1[0] - p0[0]) * t,
                    p0[1] + (p1[1] - p0[1]) * t + sag * 4 * t * (1 - t)))
    c.line(pts, OUTLINE, 3)
    for k in range(n):
        t = (k + .5) / n
        x = p0[0] + (p1[0] - p0[0]) * t
        y = p0[1] + (p1[1] - p0[1]) * t + sag * 4 * t * (1 - t)
        w = (p1[0] - p0[0]) / n * .42
        c.poly([(x - w, y), (x + w, y + 2), (x, y + w * 1.7)], cols[k % len(cols)], 2)


def horse(c: Canvas, x, y, s, col, mane):
    """Carousel horse, facing right; (x, y) is the middle of the body."""
    def T(a, b):
        return (x + a * s, y + b * s)
    ow = 2.5
    for lx, dy in ((-22, 0), (-12, 4), (14, 4), (24, 0)):
        c.poly([T(lx - 5, 10), T(lx + 5, 10), T(lx + 6 + dy / 2, 42), T(lx - 4 + dy / 2, 42)],
               mix(col, FSH, .25), ow)
    c.poly([T(-36, 6), T(-52, 30), T(-42, 34), T(-30, 14)], mane, ow)               # tail
    c.ellipse(*T(0, 0), 38 * s, 21 * s, col, ow)
    c.poly([T(14, -10), T(38, -46), T(58, -38), T(34, 0)], col, ow)                  # neck
    c.poly([T(40, -56), T(72, -42), T(68, -28), T(44, -30)], col, ow)                # head
    c.poly([T(42, -58), T(48, -72), T(54, -56)], col, 2)                              # ear
    c.circle(*T(56, -45), 2.6 * s, OUTLINE, 0)
    for k in range(4):                                                                # mane
        c.circle(*T(24 + k * 5, -42 + k * 10 - 4 * (k > 1)), 7 * s, mane, 2)
    c.poly([T(-8, -18), T(14, -18), T(12, 4), T(-10, 4)], FY if col != FY else FR, 2)  # saddle


def tent(c: Canvas, cx, base, w, h, roof_h, cols, flag):
    """Big striped fair tent with scalloped valance and a pennant."""
    x0, x1 = cx - w / 2, cx + w / 2
    c.poly([(x0 + 10, base), (x1 + 120, base + 18), (x1 + 20, base + 40), (x0 - 20, base + 30)],
           mix("#E3C48A", FSH, .45), 0, None)
    striped_rect(c, x0, base - h, x1, base, 8, cols)
    # open doorway
    c.poly([(cx - 36, base), (cx - 28, base - 100), (cx + 28, base - 100), (cx + 36, base)],
           "#3A2438", OW)
    c.poly([(cx - 36, base), (cx - 50, base), (cx - 28, base - 100)], cols[0], 2)
    c.poly([(cx + 36, base), (cx + 50, base), (cx + 28, base - 100)], cols[0], 2)
    y_roof = base - h
    striped_roof(c, (cx, y_roof - roof_h), x0 - 24, x1 + 24, y_roof, 8, [cols[1], cols[0]])
    pennant(c, cx, y_roof - roof_h, flag, 60)


def stall(c: Canvas, x0, x1, base, awning_cols, wares):
    """Market stall with striped awning, counter and wares."""
    top = base - 190
    c.poly([(x0 + 8, base + 2), (x1 + 100, base + 14), (x1 + 20, base + 32), (x0 - 10, base + 22)],
           mix("#E3C48A", FSH, .45), 0, None)
    c.rect(x0, top, x1, base, "#E8D6A8", OW)
    c.rect(x0 - 10, base - 74, x1 + 10, base, WOOD, OW)
    c.clip_lines((x0 - 10, base - 74, x1 + 10, base), [[(x, base - 74), (x, base)]
                                                       for x in range(int(x0), int(x1), 22)],
                 WOOD_D, 2)
    c.rect(x0 - 16, base - 82, x1 + 16, base - 70, WOOD_L, OW)
    c.rect(x0 - 4, top, x0 + 8, base - 70, WOOD, OW)
    c.rect(x1 - 8, top, x1 + 4, base - 70, WOOD, OW)
    # awning
    n = max(4, int((x1 - x0) / 34))
    seg = (x1 - x0 + 40) / n
    for i in range(n):
        xa = x0 - 20 + seg * i
        c.poly([(xa, top - 28), (xa + seg, top - 28), (xa + seg, top + 14), (xa + seg / 2, top + 28),
                (xa, top + 14)], awning_cols[i % 2], 2.5)
    c.poly([(x0 - 20, top - 28), (x1 + 20, top - 28), (x1 + 4, top - 52), (x0 - 4, top - 52)],
           awning_cols[0], OW)
    wares(c, x0, x1, base - 82)


def wares_loaves(c: Canvas, x0, x1, y):
    """Round loaves, pretzel rings and a gingerbread row."""
    x = x0 + 18
    k = 0
    while x < x1 - 14:
        if k % 3 == 0:
            c.ellipse(x, y - 12, 20, 14, "#D8923F", 2.5)
            c.line([(x - 10, y - 14), (x + 10, y - 14)], "#A8651F", 2)
        elif k % 3 == 1:
            c.circle(x, y - 14, 13, None, 2.5)
            c.circle(x, y - 14, 12, "#C98B3A", 0)
            c.circle(x, y - 14, 5, "#E8D6A8", 2)
        else:
            c.poly([(x - 14, y), (x - 14, y - 22), (x + 14, y - 22), (x + 14, y)], "#9A5A2E", 2.5)
            c.circle(x, y - 12, 3, FCREAM, 0)
        x += 42
        k += 1
    for i in range(4):                                   # hanging pretzel garland
        c.circle(x0 + 20 + i * ((x1 - x0 - 40) / 3), y - 110, 11, FY, 2.5)
        c.circle(x0 + 20 + i * ((x1 - x0 - 40) / 3), y - 110, 4, "#E8D6A8", 2)


def wares_samovars(c: Canvas, x0, x1, y):
    """Row of brass samovars and cups on a counter."""
    n = max(1, int((x1 - x0) / 80))
    for i in range(n):
        cx = x0 + (i + .5) * (x1 - x0) / n
        c.rect(cx - 6, y - 76, cx + 6, y - 66, BRASS_D, 2)
        c.poly([(cx - 24, y - 66), (cx + 24, y - 66), (cx + 36, y - 40), (cx + 34, y - 14),
                (cx + 22, y), (cx - 22, y), (cx - 34, y - 14), (cx - 36, y - 40)], BRASS, 2.5)
        c.poly([(cx - 24, y - 66), (cx - 8, y - 66), (cx - 18, y - 30), (cx - 22, y)], "#F6DE8A", 0)
        c.rect(cx - 8, y - 44, cx + 8, y - 36, FR, 2)
        c.rect(cx + 34, y - 36, cx + 46, y - 28, BRASS_D, 2)
    c.ellipse(x1 - 14, y - 6, 10, 6, FB, 2)


def barrel(c: Canvas, x, y, w=54, h=62, col="#9A6A3A"):
    """Barrel with iron-coloured hoops (y = bottom)."""
    c.poly([(x - w * .42, y - h), (x + w * .42, y - h), (x + w * .5, y - h * .5), (x + w * .42, y),
            (x - w * .42, y), (x - w * .5, y - h * .5)], col, OW)
    c.ellipse(x, y - h, w * .42, w * .12, mix(col, FCREAM, .35), 2.5)
    for f in (.22, .78):
        c.line([(x - w * (.5 - abs(f - .5) * .16), y - h * f),
                (x + w * (.5 - abs(f - .5) * .16), y - h * f)], FB, 4)


def crate(c: Canvas, x, y, w=60, h=46, col="#C9A06A"):
    """Wooden crate (y = bottom)."""
    c.rect(x - w / 2, y - h, x + w / 2, y, col, OW)
    c.line([(x - w / 2, y - h), (x + w / 2, y)], WOOD_D, 3)
    c.line([(x + w / 2, y - h), (x - w / 2, y)], WOOD_D, 3)


def basket_apples(c: Canvas, x, y, s=1.0):
    """Basket of red apples."""
    for dx in (-14, 0, 14):
        c.circle(x + dx * s, y - 30 * s, 11 * s, FR, 2.5)
        c.line([(x + dx * s, y - 41 * s), (x + dx * s + 3, y - 46 * s)], MOSS_D, 2)
    c.poly([(x - 30 * s, y - 28 * s), (x + 30 * s, y - 28 * s), (x + 24 * s, y), (x - 24 * s, y)],
           "#C9A06A", 2.5)
    c.clip_lines((x - 30 * s, y - 28 * s, x + 30 * s, y), [[(x - 30 * s, y - 20 * s + k * 9 * s),
                                                            (x + 30 * s, y - 20 * s + k * 9 * s)]
                                                           for k in range(3)], WOOD_D, 2)


def balloons(c: Canvas, x, y, cols, seed=1):
    """Bunch of balloons on strings tied at (x, y)."""
    rnd = random.Random(seed)
    for i, col in enumerate(cols):
        bx = x + (i - len(cols) / 2) * 26 + rnd.randint(-6, 6)
        by = y - 120 - rnd.randint(0, 36)
        c.line([(x, y), (bx, by + 28)], OUTLINE, 1.5)
        c.ellipse(bx, by, 20, 26, col, 2.5)
        c.ellipse(bx - 7, by - 9, 5, 8, mix(col, "#FFFFFF", .55), 0)
        c.poly([(bx - 4, by + 26), (bx + 4, by + 26), (bx, by + 32)], col, 2)


def kite(c: Canvas, x, y, col, col2):
    """Diamond kite with bow-tail."""
    c.line([(x, y + 40), (x - 30, y + 120), (x + 10, y + 190)], OUTLINE, 2)
    c.poly([(x, y - 44), (x + 30, y), (x, y + 44), (x - 30, y)], col, 2.5)
    c.poly([(x, y - 44), (x + 30, y), (x, y)], col2, 0)
    c.line([(x, y - 44), (x, y + 44)], OUTLINE, 2)
    c.line([(x - 30, y), (x + 30, y)], OUTLINE, 2)
    for k, (dx, dy) in enumerate(((-30, 120), (-14, 150), (4, 176))):
        c.poly([(x + dx - 8, y + dy), (x + dx + 8, y + dy), (x + dx, y + dy + 12)],
               (FR, FY, FG)[k], 2)


def carousel(c: Canvas, cx, base):
    """Central carousel: platform, poles, horses, striped canopy, lanterns."""
    w = 250
    # shadow
    c.ellipse(cx + 40, base + 24, w + 90, 30, mix("#E3C48A", FSH, .5), 0)
    # platform (drum)
    c.rect(cx - w, base - 36, cx + w, base, FB, OW)
    for i in range(14):
        xm = cx - w + (i + .5) * (2 * w / 14)
        c.circle(xm, base - 18, 6, FY, 2)
    c.rect(cx - w - 14, base - 48, cx + w + 14, base - 34, WOOD_L, OW)
    # central column
    c.rect(cx - 30, base - 330, cx + 30, base - 48, FY, OW)
    for k in range(6):
        c.line([(cx - 30, base - 330 + k * 47), (cx + 30, base - 300 + k * 47)], FR, 4)
    c.rect(cx - 30, base - 330, cx + 30, base - 48, None, OW)
    # poles + horses
    spots = [(-205, FR, FY), (-110, FG, FCREAM), (105, FB, FY), (205, FY, FR)]
    for px, hc, mc in spots:
        c.rect(cx + px - 4, base - 330, cx + px + 4, base - 48, BRASS, 2)
    # canopy
    c.rect(cx - w - 20, base - 340, cx + w + 20, base - 322, FR, OW)
    striped_roof(c, (cx, base - 470), cx - w - 30, cx + w + 30, base - 340, 10, [FR, FY, FB, FCREAM])
    c.circle(cx, base - 474, 10, FY, OW)
    pennant(c, cx, base - 484, FR, 70)
    # back horses first (smaller, higher), front horses bigger
    for px, hc, mc in spots[1:3]:
        horse(c, cx + px, base - 150 - (20 if px < 0 else 0), 1.1, hc, mc)
    horse(c, cx - 205, base - 130, 1.25, FR, FY)
    horse(c, cx + 205, base - 170, 1.25, FY, FR)
    # lanterns on canopy rim
    for i in range(9):
        xm = cx - w - 10 + i * (2 * w + 20) / 8
        c.line([(xm, base - 322), (xm, base - 308)], OUTLINE, 2)
        c.circle(xm, base - 298, 9, FY if i % 2 else FCREAM, 2.5)
    c.glow(cx, base - 200, 220, "#FFE9A0", .1)


def mast(c: Canvas, x, base):
    """Greasy climbing pole with a prize wheel of boots and a loaf."""
    beam(c, (x, base), (x, base - 340), 16, WOOD_L)
    for y in range(int(base - 300), int(base), 36):
        c.line([(x - 8, y), (x + 8, y + 10)], WOOD_D, 3)
    c.circle(x, base - 350, 40, None, 4)
    c.circle(x, base - 350, 40, None, 0)
    c.line([(x - 40, base - 350), (x + 40, base - 350)], OUTLINE, 5)
    c.line([(x, base - 390), (x, base - 310)], OUTLINE, 5)
    c.circle(x, base - 350, 40, None, 4)
    # boots
    for dx, col in ((-34, FR), (34, FB)):
        c.line([(x + dx, base - 350), (x + dx, base - 330)], OUTLINE, 2)
        c.poly([(x + dx - 9, base - 330), (x + dx + 9, base - 330), (x + dx + 9, base - 298),
                (x + dx + 24, base - 290), (x + dx + 24, base - 278), (x + dx - 9, base - 278)],
               col, 2.5)
    c.circle(x, base - 396, 12, FY, 2.5)
    pennant(c, x, base - 400, FG, 50)


def fair_cobbles(c: Canvas, y0, rnd):
    """Cobblestone ground with perspective-scaled stones."""
    vgrad(c, y0, c.h, "#EBCD92", "#D9B070", 24)
    y = y0 + 14
    while y < c.h:
        t = (y - y0) / (c.h - y0)
        sz = 12 + t * 34
        x = rnd.uniform(-sz, sz)
        while x < c.w + sz:
            tone = mix(rnd.choice(["#D9B070", "#C79F5F", "#E3C48A", "#B98F58"]), "#E3C48A", .45)
            c.ellipse(x, y + rnd.uniform(-3, 3), sz * .62, sz * .26, tone, 2)
            x += sz * 1.55
        y += sz * .6


def puppet_booth(c: Canvas, cx, base):
    """Folding-screen puppet theatre: striped frame, curtain, little stage, bell."""
    w, h = 190, 300
    c.ellipse(cx + 40, base + 8, w * .7, 16, mix("#D9B070", FSH, .5), 0)
    c.rect(cx - w / 2, base - h, cx + w / 2, base, FB, OW)
    striped_rect(c, cx - w / 2, base - h, cx + w / 2, base - 120, 6, [FB, FCREAM])
    c.rect(cx - 62, base - 250, cx + 62, base - 150, "#2F2038", OW)
    c.poly([(cx - 62, base - 250), (cx - 20, base - 250), (cx - 62, base - 190)], FR, 2.5)
    c.poly([(cx + 62, base - 250), (cx + 20, base - 250), (cx + 62, base - 190)], FR, 2.5)
    c.rect(cx - 76, base - 270, cx + 76, base - 250, FY, OW)
    for k in range(7):
        c.circle(cx - 66 + k * 22, base - 270, 6, FR if k % 2 else FB, 2)
    c.circle(cx, base - 170, 15, "#F0C9A5", 2.5)                  # puppet head
    c.poly([(cx - 14, base - 182), (cx + 14, base - 182), (cx, base - 214)], FR, 2.5)  # cap
    c.rect(cx - 18, base - 156, cx + 18, base - 150, FY, 2)
    c.rect(cx - 62, base - 150, cx + 62, base - 130, WOOD, OW)
    c.line([(cx + w / 2 + 14, base - h + 40), (cx + w / 2 + 14, base - 40)], OUTLINE, 5)
    c.poly([(cx + w / 2, base - h + 40), (cx + w / 2 + 28, base - h + 40), (cx + w / 2 + 22, base - h + 70),
            (cx + w / 2 + 6, base - h + 70)], BRASS, 2.5)
    pennant(c, cx, base - h, FY, 64)


def fruit_cart(c: Canvas, cx, base):
    """Hand cart loaded with watermelons and cabbages."""
    c.ellipse(cx + 20, base + 6, 190, 18, mix("#D9B070", FSH, .5), 0)
    c.line([(cx - 160, base - 110), (cx - 90, base - 70)], OUTLINE, 8)             # shafts
    c.line([(cx - 160, base - 110), (cx - 90, base - 70)], WOOD_L, 4)
    for k in range(5):
        c.circle(cx - 90 + k * 40, base - 118, 24, FG, 2.5)
        c.arc(cx - 90 + k * 40, base - 118, 16, 22, 200, 340, "#2E6A38", 3)
    c.circle(cx + 80, base - 130, 18, "#9ACB6A", 2.5)
    c.circle(cx + 40, base - 150, 18, "#9ACB6A", 2.5)
    c.poly([(cx - 110, base - 100), (cx + 110, base - 100), (cx + 96, base - 40), (cx - 96, base - 40)],
           WOOD, OW)
    c.clip_lines((cx - 110, base - 100, cx + 110, base - 40), [[(x, base - 100), (x, base - 40)]
                                                               for x in range(int(cx - 100), int(cx + 100), 24)],
                 WOOD_D, 2)
    c.circle(cx - 40, base - 20, 42, WOOD_L, OW)
    c.circle(cx - 40, base - 20, 10, BRASS, 2.5)
    for k in range(8):
        a = k * math.pi / 4
        c.line([(cx - 40, base - 20), (cx - 40 + math.cos(a) * 40, base - 20 + math.sin(a) * 40)],
               OUTLINE, 3)


def clay_pots(c: Canvas, cx, base):
    """Stack of coloured clay pots and jugs."""
    c.ellipse(cx + 10, base + 4, 120, 14, mix("#D9B070", FSH, .5), 0)
    for i, (dx, col, sc) in enumerate(((-70, FR, 1.0), (0, FB, 1.2), (74, FY, 1.0))):
        x = cx + dx
        h = 80 * sc
        c.poly([(x - 30 * sc, base - h), (x + 30 * sc, base - h), (x + 40 * sc, base - h * .5),
                (x + 28 * sc, base), (x - 28 * sc, base), (x - 40 * sc, base - h * .5)], col, OW)
        c.rect(x - 34 * sc, base - h - 10, x + 34 * sc, base - h + 4, col, 2.5)
        c.line([(x - 32 * sc, base - h * .55), (x + 32 * sc, base - h * .55)], FCREAM, 4)
        c.circle(x, base - h * .3, 6 * sc, FCREAM, 0)
    for dx, col in ((-34, FG), (36, FR)):
        c.poly([(cx + dx - 22, base - 134), (cx + dx + 22, base - 134), (cx + dx + 28, base - 100),
                (cx + dx - 28, base - 100)], col, OW)


def scene_fair() -> Canvas:
    """Prompt 9: 2048x1024 saturated fair square, no characters."""
    c = Canvas(2048, 1024, "#7FB7E6")
    rnd = random.Random(9)
    hy = 520
    vgrad(c, 0, hy, "#4C8FD6", "#B6DDF0")
    for (x, y, s) in ((260, 120, 1.2), (900, 70, .9), (1500, 130, 1.3), (1900, 60, .8)):
        cloud(c, x, y, s, "#FFFFFF", "#CFE0F0")
    # distant townscape
    for i, x in enumerate(range(-20, 2100, 118)):
        hgt = 60 + (i * 37) % 50
        wall = [FCREAM, "#F3D58A", "#E8A5A0", "#B9D7B0"][i % 4]
        roof = [FR, FB, FG, "#A0522D"][(i * 3) % 4]
        c.rect(x, hy - hgt, x + 96, hy + 10, wall, 2.5)
        c.poly([(x - 8, hy - hgt), (x + 104, hy - hgt), (x + 80, hy - hgt - 38), (x + 16, hy - hgt - 38)],
               roof, 2.5)
        for wx in (x + 20, x + 60):
            c.rect(wx, hy - hgt + 16, wx + 16, hy - hgt + 38, "#6A8FB8", 2)
    for x in range(40, 2048, 190):
        c.blob([(x, hy - 14, 34, 30), (x + 24, hy - 4, 26, 22)], FG, shade="#3E7A44")
    # ground
    c.rect(0, hy, 2048, 1024, "#E3C48A", 0, None)
    fair_cobbles(c, hy + 6, rnd)
    c.line([(0, hy + 6), (2048, hy + 6)], OUTLINE, OW)
    # back row: tents, pole, stalls, carousel
    tent(c, 245, 650, 270, 150, 140, [FR, FCREAM], FY)
    tent(c, 1810, 660, 300, 160, 150, [FB, FY], FR)
    mast(c, 470, 690)
    stall(c, 580, 780, 700, (FG, FCREAM), wares_loaves)
    stall(c, 1300, 1520, 700, (FR, FY), wares_samovars)
    carousel(c, 1040, 700)
    # small far props
    for x, col in ((900, FR), (1190, FB)):
        pennant(c, x, 520, col, 36)
    # midground props
    barrel(c, 800, 760)
    barrel(c, 1560, 770, 58, 66, "#8A5A2E")
    crate(c, 1600, 772, 58, 44)
    basket_apples(c, 520, 790, 1.1)
    balloons(c, 1660, 760, [FR, FY, FB, FG, FR], 3)
    balloons(c, 350, 768, [FY, FB, FR, FG], 4)
    kite(c, 700, 190, FR, FY)
    kite(c, 1560, 160, FB, FY)
    # poles + bunting across the square
    for x in (690, 1400):
        beam(c, (x, 640), (x, 250), 14, WOOD_L)
        c.circle(x, 242, 11, FY, OW)
    bunting(c, (0, 40), (690, 250), 70, 14)
    bunting(c, (690, 250), (1400, 250), 80, 18)
    bunting(c, (1400, 250), (2048, 60), 70, 14)
    bunting(c, (690, 250), (1040, 236), 40, 8, (FY, FR, FB, FG))
    bunting(c, (1040, 236), (1400, 250), 40, 8, (FB, FG, FY, FR))
    bunting(c, (0, 120), (245, 330), 40, 6, (FY, FB, FR, FG))
    # foreground
    puppet_booth(c, 1010, 1012)
    fruit_cart(c, 1500, 960)
    clay_pots(c, 640, 960)
    barrel(c, 130, 990, 110, 130)
    crate(c, 250, 1000, 100, 80)
    crate(c, 210, 920, 80, 62)
    basket_apples(c, 330, 1010, 1.8)
    for k in range(3):
        hx, hy2 = 1790 + (k % 2) * 14, 1010 - k * 56
        c.rect(hx, hy2 - 52, hx + 190, hy2, "#E5C15C", OW)
        c.clip_lines((hx, hy2 - 52, hx + 190, hy2),
                     [[(hx + 6 + j * 17, hy2 - 52 + (j * 7) % 13), (hx + 14 + j * 17, hy2 - 8)]
                      for j in range(11)], "#B8903A", 2)
        for bx in (hx + 50, hx + 140):
            c.line([(bx, hy2 - 52), (bx, hy2)], BRICK, 5)
    c.rect(1700, 760, 1712, 1030, WOOD, OW)
    c.rect(1980, 700, 1992, 1030, WOOD, OW)
    for x, col in ((1706, FR), (1986, FB)):
        pennant(c, x, 760 if x < 1800 else 700, col, 60)
    balloons(c, 1780, 1000, [FY, FR, FG, FB], 7)
    for _ in range(30):
        x, y = rnd.randint(0, 2048), rnd.randint(860, 1015)
        c.circle(x, y, rnd.randint(2, 4), rnd.choice([FR, FY, FB, FG]), 0)   # confetti
    return c
