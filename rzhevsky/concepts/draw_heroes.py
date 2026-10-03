#!/usr/bin/env python3
"""Procedural concept sheets for "Поручик Ржевский против Ордена".

Draws six ORIGINAL character sheets with Pillow only (no neural nets, no
network).  Style rules follow docs/RZHEVSKY_RESEARCH_2026-10-03.md, 6.6:
flat colours, one uniform dark-brown outline (#2B1B12), coloured shadows,
expressive eyebrows, caricature proportions, plain light-grey background.

Everything is drawn at 2x resolution and downsampled with LANCZOS.
Output is deterministic (fixed seed for the few random details).

Usage:  python3 draw_heroes.py [--sil]   (--sil also writes black silhouettes)
"""
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "out")
SEED = 20261003


def hx(code):
    """Convert '#RRGGBB' to an RGB tuple."""
    code = code.lstrip("#")
    return tuple(int(code[i:i + 2], 16) for i in (0, 2, 4))


BG = hx("#E6E6E6")
OUTLINE = hx("#2B1B12")
WHITE = hx("#FFFFFF")
EGG = hx("#F6F1E4")
BLACK = (0, 0, 0)
FONT_PATH = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


# --------------------------------------------------------------------------
# geometry helpers
# --------------------------------------------------------------------------
def catmull(pts, closed=True, steps=10):
    """Catmull-Rom spline through pts; returns a dense point list."""
    n = len(pts)
    if n < 3:
        return list(pts)
    out = []
    rng = range(n) if closed else range(n - 1)
    for i in rng:
        if closed:
            p0, p1, p2, p3 = (pts[(i - 1) % n], pts[i],
                              pts[(i + 1) % n], pts[(i + 2) % n])
        else:
            p0 = pts[max(i - 1, 0)]
            p1 = pts[i]
            p2 = pts[i + 1]
            p3 = pts[min(i + 2, n - 1)]
        for s in range(steps):
            t = s / steps
            t2, t3 = t * t, t * t * t
            out.append(tuple(
                0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t
                       + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2
                       + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3)
                for j in (0, 1)))
    if not closed:
        out.append(pts[-1])
    return out


def rotate(pts, deg, pivot=(0, 0)):
    """Rotate points counter-clockwise (y-up local coordinates)."""
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    px, py = pivot
    return [(px + (x - px) * c - (y - py) * s,
             py + (x - px) * s + (y - py) * c) for x, y in pts]


def ellipse_pts(x, y, rx, ry, rot=0, n=48):
    """Points of an ellipse (optionally rotated)."""
    pts = [(x + rx * math.cos(2 * math.pi * i / n),
            y + ry * math.sin(2 * math.pi * i / n)) for i in range(n)]
    return rotate(pts, rot, (x, y)) if rot else pts


def mix(c1, c2, t):
    """Linear colour blend."""
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


def darker(c, amt=0.22, tint=(40, 30, 90)):
    """A coloured (not black) shadow tone for colour c."""
    return mix(c, tint, amt)


# --------------------------------------------------------------------------
# canvas
# --------------------------------------------------------------------------
class Canvas:
    """Supersampled drawing surface in final-pixel coordinates."""

    def __init__(self, w, h, scale=2, sil=False, lw=4.5):
        self.w, self.h, self.S, self.sil, self.lw = w, h, scale, sil, lw
        self.img = Image.new("RGB", (w * scale, h * scale), BG)
        self.d = ImageDraw.Draw(self.img)

    # -- low level ---------------------------------------------------------
    def _s(self, pts):
        return [(x * self.S, y * self.S) for x, y in pts]

    def _col(self, c):
        return BLACK if self.sil else c

    def _crescent(self, draw_fn, bbox, color, amt):
        """Paint a coloured shade along the lower-right edge of a shape."""
        x0, y0, x1, y1 = [int(v) for v in bbox]
        m = 6
        x0, y0 = max(x0 - m, 0), max(y0 - m, 0)
        x1 = min(x1 + m, self.img.width)
        y1 = min(y1 + m, self.img.height)
        if x1 <= x0 or y1 <= y0:
            return
        mask = Image.new("L", (x1 - x0, y1 - y0), 0)
        draw_fn(ImageDraw.Draw(mask), -x0, -y0, 255)
        sh = ImageChops.offset(mask, -int(amt * 0.8), -int(amt))
        cres = ImageChops.subtract(mask, sh)
        self.img.paste(color, (x0, y0), cres)

    # -- shapes --------------------------------------------------------------
    def poly(self, pts, fill, shade=True, outline=True, lw=None):
        """Filled polygon (final-pixel points) with outline + colour shade."""
        if len(pts) < 3:
            return
        lw = (self.lw if lw is None else lw) * self.S
        sp = self._s(pts)
        if fill is not None:
            self.d.polygon(sp, fill=self._col(fill))
        if shade and fill is not None and not self.sil:
            xs = [p[0] for p in sp]
            ys = [p[1] for p in sp]
            size = min(max(xs) - min(xs), max(ys) - min(ys))
            amt = max(4, min(0.16 * size, 22 * self.S / 2))
            sc = shade if isinstance(shade, tuple) else darker(fill)

            def fn(dr, ox, oy, v):
                dr.polygon([(x + ox, y + oy) for x, y in sp], fill=v)
            self._crescent(fn, (min(xs), min(ys), max(xs), max(ys)), sc, amt)
        if outline:
            oc = self._col(OUTLINE)
            self.d.line(sp + [sp[0]], fill=oc, width=int(lw), joint="curve")
            r = lw / 2
            for x, y in sp[::max(1, len(sp) // 60)]:
                self.d.ellipse((x - r, y - r, x + r, y + r), fill=oc)

    def stroke(self, pts, w, color, round_caps=True):
        """Open polyline with round joins (final-pixel units)."""
        sp = self._s(pts)
        wd = max(1, int(w * self.S))
        c = self._col(color)
        self.d.line(sp, fill=c, width=wd, joint="curve")
        if round_caps:
            r = wd / 2
            for x, y in (sp[0], sp[-1]):
                self.d.ellipse((x - r, y - r, x + r, y + r), fill=c)

    def limb(self, pts, w, fill, shade=True, lw=None):
        """Thick polyline with outline (arms, legs, tails)."""
        lw = self.lw if lw is None else lw
        self.stroke(pts, w + 2 * lw, OUTLINE)
        self.stroke(pts, w, fill)
        if shade and not self.sil:
            sp = self._s(pts)
            wd = int(w * self.S)

            def fn(dr, ox, oy, v):
                q = [(x + ox, y + oy) for x, y in sp]
                dr.line(q, fill=v, width=wd, joint="curve")
                for x, y in (q[0], q[-1]):
                    dr.ellipse((x - wd / 2, y - wd / 2, x + wd / 2, y + wd / 2),
                               fill=v)
            xs = [p[0] for p in sp]
            ys = [p[1] for p in sp]
            self._crescent(fn, (min(xs) - wd, min(ys) - wd, max(xs) + wd,
                                max(ys) + wd), darker(fill), max(3, wd * 0.2))

    def text(self, xy, s, size, color, anchor="lm"):
        """Caption text (final-pixel units)."""
        font = ImageFont.truetype(FONT_PATH, int(size * self.S))
        self.d.text((xy[0] * self.S, xy[1] * self.S), s, font=font,
                    fill=self._col(color), anchor=anchor)

    def caption(self, text, right=""):
        """Small caption strip at the bottom of the sheet."""
        y0 = self.h - 46
        self.d.rectangle((0, y0 * self.S, self.w * self.S, self.h * self.S),
                         fill=self._col(hx("#2B1B12")))
        self.text((24, self.h - 23), text, 24, hx("#F0C9A5"))
        if right:
            self.text((self.w - 24, self.h - 23), right, 18, hx("#C9B28B"),
                      anchor="rm")

    def save(self, path):
        """Downsample with LANCZOS and write an optimised PNG."""
        out = self.img.resize((self.w, self.h), Image.LANCZOS)
        out.save(path, optimize=True)
        return out


class Frame:
    """Local y-up coordinate system: origin on the ground, unit = k px."""

    def __init__(self, cv, cx, gy, k, flip=1):
        self.cv, self.cx, self.gy, self.k, self.flip = cv, cx, gy, k, flip

    def p(self, x, y):
        """Local -> canvas coordinates."""
        return (self.cx + self.flip * x * self.k, self.gy - y * self.k)

    def scaled(self, s, y0):
        """Frame that magnifies everything above height y0 by s (big heads)."""
        return Frame(self.cv, self.cx, self.gy + (s - 1) * y0 * self.k,
                     self.k * s, self.flip)

    def pts(self, pts):
        return [self.p(*q) for q in pts]

    def poly(self, pts, fill, **kw):
        self.cv.poly(self.pts(pts), fill, **kw)

    def blob(self, pts, fill, steps=8, **kw):
        """Smooth closed shape through control points."""
        self.cv.poly(self.pts(catmull(pts, True, steps)), fill, **kw)

    def ell(self, x, y, rx, ry, fill, rot=0, **kw):
        self.poly(ellipse_pts(x, y, rx, ry, rot), fill, **kw)

    def limb(self, pts, w, fill, smooth=False, **kw):
        if smooth:
            pts = catmull(pts, False, 8)
        self.cv.limb(self.pts(pts), w * self.k, fill, **kw)

    def line(self, pts, w, color=OUTLINE, smooth=False):
        if smooth:
            pts = catmull(pts, False, 8)
        self.cv.stroke(self.pts(pts), w * self.k, color)

    def dot(self, x, y, r, fill, outline=False):
        if outline:
            self.ell(x, y, r, r, fill, shade=False, lw=self.cv.lw * 0.5)
        else:
            self.ell(x, y, r, r, fill, shade=False, outline=False)

    def shadow(self, x, rx, ry=1.6):
        """Soft coloured ground shadow (no outline)."""
        self.ell(x, 0, rx, ry, hx("#C9C9CF"), shade=False, outline=False)


def eye(f, x, y, rx, ry, look=(0.3, 0), pr=0.45, lid=0.0):
    """A cartoon eye: egg-white, pupil with highlight, optional lid."""
    f.ell(x, y, rx, ry, EGG, shade=False, lw=f.cv.lw * 0.6)
    f.ell(x + look[0] * rx, y + look[1] * ry, rx * pr * 1.7, ry * pr * 1.7,
          OUTLINE, shade=False, outline=False)
    f.dot(x + look[0] * rx + rx * 0.2, y + look[1] * ry + ry * 0.25,
          rx * 0.16, WHITE)
    if lid:
        f.poly([(x - rx * 1.1, y + ry * 1.1), (x + rx * 1.1, y + ry * 1.1),
                (x + rx * 1.1, y + ry * (1 - 2 * lid)),
                (x - rx * 1.1, y + ry * (1 - 2 * lid))], None,
               outline=False)


def brow(f, pts, w, color):
    """Expressive eyebrow = thick smooth stroke."""
    f.line(pts, w, color, smooth=len(pts) > 2)


# ==========================================================================
# 1. Ржевский
# ==========================================================================
R_BLUE, R_GOLD, R_RED = hx("#2F4B7C"), hx("#D9A441"), hx("#C8571B")
R_SKIN, R_GREY = hx("#F0C9A5"), hx("#8C8C8C")
R_CREAM = hx("#E9E0C6")
R_BOOT1, R_BOOT2 = hx("#5A3A28"), hx("#B98B5B")
R_SKIN_D = hx("#D79B76")


def spur(f, x, y, big=1.0, back=False):
    """Spur: spike plus a star-shaped rowel."""
    r = 1.5 * big
    if not back:
        f.poly([(x - 1.2 * big, y - 0.5), (x - 4 * big, y - 0.2),
                (x - 1.2 * big, y + 0.8)], R_GREY, shade=False)
    pts = []
    for i in range(12):
        rr = r * (1.55 if i % 2 == 0 else 0.8)
        a = math.pi * 2 * i / 12
        pts.append((x - (3.6 * big if not back else 0) + rr * math.cos(a),
                    y + rr * math.sin(a)))
    f.poly(pts, R_GREY, shade=False, lw=f.cv.lw * 0.6)


def rz_head_front(f):
    """Ржевский: front face, hair, shako."""
    # hair behind head
    hair = hx("#C8571B")
    f.poly([(-6.0, 93), (-9.4, 90.5), (-7.8, 88.8), (-10.2, 86), (-7.2, 85.4),
            (-8.4, 82.4), (-5.6, 83.6), (5.6, 83.6), (8.4, 82.4), (7.2, 85.4),
            (10.2, 86), (7.8, 88.8), (9.4, 90.5), (6.0, 93)], hair)
    # neck + head
    f.poly([(-1.9, 75), (1.9, 75), (2.1, 81), (-2.1, 81)], R_SKIN)
    f.blob([(-6.0, 90), (-6.5, 86), (-5.2, 81.8), (-2.2, 79.0), (0, 78.4),
            (2.2, 79.0), (5.2, 81.8), (6.5, 86), (6.0, 90), (3, 93), (-3, 93)],
           R_SKIN)
    for sx in (-1, 1):
        f.ell(sx * 6.6, 86.6, 1.3, 2.0, R_SKIN, rot=sx * -10, lw=3)
    # fringe tufts under the shako
    for x0, h in ((-5.0, 3.4), (-2.2, 2.2), (1.2, 3.0), (3.8, 2.4)):
        f.poly([(x0 - 1.7, 91.8), (x0 + 1.7, 91.8), (x0 + 0.2, 91.8 - h)],
               hair, lw=3.5)
    # freckles
    rnd = random.Random(SEED)
    for sx in (-1, 1):
        for _ in range(6):
            f.dot(sx * (2.6 + rnd.random() * 2.2), 84.6 + rnd.random() * 2.4,
                  0.28, hx("#B0592A"))
    # eyes, brows
    eye(f, -2.6, 88.0, 1.65, 1.95, look=(0.5, -0.1))
    eye(f, 2.6, 88.0, 1.65, 1.95, look=(0.5, -0.1))
    brow(f, [(-4.6, 90.8), (-3.0, 92.6), (-0.9, 91.9)], 0.8, hair)
    brow(f, [(0.9, 90.7), (2.8, 91.0), (4.5, 92.3)], 0.8, hair)
    # nose, mouth, moustache
    f.ell(0.5, 84.7, 1.9, 1.7, R_SKIN_D, lw=3.2)
    f.dot(-0.2, 84.3, 0.35, OUTLINE)
    f.dot(1.4, 84.3, 0.35, OUTLINE)
    f.ell(-1.7, 82.3, 1.6, 0.7, hair, rot=8, lw=2.6)
    f.ell(2.4, 82.5, 1.9, 0.7, hair, rot=20, lw=2.6)
    f.line([(-2.4, 81.0), (0.5, 80.5), (3.0, 81.5), (3.9, 82.6)], 0.45,
           OUTLINE, smooth=True)
    # shako
    f.cv.poly([], None)
    shako(f, 0, "front")


def shako(f, tilt, view):
    """Tall flared shako with a gold band and a brush plume."""
    pv = (0, 91)

    def T(pts):
        return rotate(pts, tilt, pv)
    for i in range(11):                       # plume strands (behind cap)
        a = -52 + i * 10.4
        col = R_RED if i % 2 == 0 else R_GOLD
        base = (0, 102)
        ln = 9.5 - abs(a) * 0.04
        tip = (math.sin(math.radians(a)) * ln,
               102 + math.cos(math.radians(a)) * ln)
        w = 1.25
        nx, ny = math.cos(math.radians(a)) * w, -math.sin(math.radians(a)) * w
        f.poly(T([(base[0] - nx, base[1] - ny), tip,
                  (base[0] + nx, base[1] + ny)]), col, lw=3.2)
    f.poly(T([(-6.4, 91), (-7.6, 102.4), (7.6, 102.4), (6.4, 91)]), R_BLUE)
    f.poly(T([(-6.5, 91), (-6.7, 93.6), (6.7, 93.6), (6.5, 91)]), R_GOLD)
    f.poly(T([(-7.8, 101.2), (-7.8, 102.7), (7.8, 102.7), (7.8, 101.2)]),
           R_GOLD, lw=3.5)
    if view == "front":
        f.poly(T(ellipse_pts(0, 96.5, 2.3, 2.7)), R_GOLD, lw=3.5)
        f.poly(T(ellipse_pts(0, 96.5, 1.0, 1.2)), hx("#A97A24"), shade=False,
               lw=2)
        # gold cord swag
        f.line(T([(-6.8, 100), (-8.4, 95), (-7.4, 92), (-8.2, 87)]), 0.7,
               R_GOLD, smooth=True)
        f.ell(-8.2, 85.6, 0.9, 1.6, R_GOLD, lw=3)
    else:
        f.line(T([(-5.5, 100), (0, 97), (5.5, 100)]), 0.7, R_GOLD, smooth=True)


def rz_front(f):
    """Ржевский, front view."""
    f.shadow(0, 17)
    cream = R_CREAM
    # --- legs
    f.blob([(-8.0, 48), (-1.5, 48), (-1.7, 30), (-2.3, 25), (-7.6, 25),
            (-8.0, 36)], cream)                        # left trouser
    f.poly([(-4.8, 47), (-4.4, 27), (-3.6, 27), (-3.9, 47)], R_BLUE,
           shade=False, outline=False)
    f.blob([(1.5, 48), (8.0, 48), (8.1, 36), (7.6, 15), (2.3, 15),
            (1.7, 30)], cream)                         # right trouser
    f.poly([(4.8, 47), (4.6, 17), (3.8, 17), (4.0, 47)], R_BLUE,
           shade=False, outline=False)
    # tall boot (left)
    f.blob([(-8.0, 27), (-2.2, 27), (-2.6, 12), (-3.0, 7), (-8.4, 7),
            (-8.0, 15)], R_BOOT1)
    f.ell(-6.7, 2.8, 5.8, 3.2, R_BOOT1, rot=12)
    f.poly([(-8.2, 27.4), (-2.0, 27.4), (-5.1, 23.4)], R_GOLD, lw=3.5)
    spur(f, -11.4, 4.6, 1.0)
    # short boot (right)
    f.blob([(1.9, 14), (8.3, 14), (8.7, 8), (7.9, 4), (2.6, 4), (2.2, 9)],
           R_BOOT2)
    f.ell(5.5, 2.8, 5.8, 3.2, R_BOOT2, rot=-12)
    f.poly([(1.6, 15.6), (8.8, 15.6), (8.8, 13), (1.6, 13)], hx("#8B6338"),
           lw=3.5)
    spur(f, 13.6, 5.2, 1.5)
    # --- pelisse-side arm (hanging, viewer right)
    f.limb([(9.2, 74), (13.2, 60), (12.6, 47)], 4.3, R_BLUE)
    f.ell(12.5, 44.6, 2.3, 2.5, R_SKIN, lw=3.5)
    f.poly([(10.3, 48.8), (14.9, 48.8), (14.9, 46.8), (10.3, 46.8)], R_GOLD,
           lw=3, shade=False)
    # --- torso (dolman)
    f.blob([(-3.8, 79.5), (-8.6, 77), (-9.6, 70), (-7.8, 58), (-9.4, 46),
            (-4, 43.2), (4, 43.2), (9.4, 46), (7.8, 58), (9.6, 70), (8.6, 77),
            (3.8, 79.5)], R_BLUE, steps=6)
    f.line([(-9.0, 46.6), (-4, 44.5), (4, 44.5), (9.0, 46.6)], 0.8, R_GOLD)
    for y in (73, 69, 65, 61):                       # braid frogs
        f.line([(-5.6, y), (5.6, y)], 0.75, R_GOLD)
        for sx in (-1, 1):
            f.ell(sx * 5.8, y, 0.8, 0.8, R_GOLD, shade=False, lw=2.4)
        f.dot(0, y, 0.5, R_GOLD, True)
    f.poly([(-8.1, 52), (8.1, 52), (8.4, 56), (-8.4, 56)], R_RED, lw=3.5)
    f.poly([(-1.3, 51.6), (1.3, 51.6), (1.3, 56.4), (-1.3, 56.4)], R_GOLD,
           lw=3)
    f.poly([(4.4, 52), (6.4, 52), (6.8, 44.5), (4.0, 44.5)], R_RED, lw=3)
    # collar
    f.poly([(-3.4, 77), (3.4, 77), (3.0, 81.2), (-3.0, 81.2)], R_BLUE, lw=3.5)
    f.line([(-3.2, 80.8), (3.2, 80.8)], 0.6, R_GOLD)
    # --- akimbo arm (viewer left): epaulette side
    f.limb([(-9.3, 75), (-17.8, 62.5), (-9.3, 53)], 4.5, R_BLUE)
    f.poly([(-11.4, 54.6), (-7.4, 51.6), (-6.4, 53.6), (-10.4, 56.4)], R_GOLD,
           lw=3, shade=False)
    f.ell(-7.6, 51.4, 2.5, 2.4, R_SKIN, lw=3.5)
    # --- pelisse draped over viewer-right shoulder, grey fur trim
    f.blob([(3.0, 80.2), (9.6, 80.2), (14.5, 74), (16.2, 62), (13, 55),
            (9.6, 59), (6.8, 66), (4.5, 72)], R_BLUE, steps=6)
    fur = [(16.2, 62), (15.4, 57), (13.4, 54.2), (11.4, 56.5), (9.8, 58.4)]
    f.poly([(16.6, 63)] + fur + [(11.2, 59.6), (13.6, 60.8), (15.2, 60.2)],
           R_GREY, lw=3.2)
    f.line([(5.0, 78), (3.4, 72), (1.8, 66), (0.4, 62)], 0.6, R_GOLD,
           smooth=True)
    f.ell(0.3, 60.6, 0.9, 1.7, R_GOLD, lw=3)
    # --- big epaulette on viewer-left shoulder + bullion fringe
    for i in range(9):
        x = -17.0 + i * 1.65
        f.line([(x, 76.4 - abs(i - 4) * 0.2), (x, 70.3)], 0.5, R_GOLD)
    f.ell(-12.2, 77.2, 7.6, 3.5, R_GOLD, rot=10, lw=4)
    f.ell(-12.2, 77.4, 5.0, 2.0, hx("#E8BE62"), rot=10, shade=False, lw=2.6)
    f.dot(-12.2, 77.4, 0.9, hx("#A97A24"), True)
    # --- head
    rz_head_front(f.scaled(1.3, 76))


def rz_side(f):
    """Ржевский, profile facing right (epaulette side is near)."""
    f.shadow(0, 18)
    cream = R_CREAM
    # far leg (short boot), stepping back
    f.limb([(-1.0, 48), (-5.0, 33), (-5.6, 15)], 6.0, cream)
    f.blob([(-8.6, 15.6), (-2.6, 15.6), (-2.6, 5), (-3, 4), (-8.6, 4)],
           R_BOOT2)
    f.ell(-4.3, 2.8, 6.0, 3.1, R_BOOT2, rot=-4)
    spur(f, -9.8, 5.4, 1.5, back=True)
    # far arm (pelisse side)
    f.limb([(1, 74), (-1.5, 62), (1.0, 49)], 4.0, R_BLUE)
    f.ell(1.4, 46.6, 2.2, 2.4, R_SKIN, lw=3.5)
    # torso
    f.blob([(-3.5, 79.5), (-6.0, 70), (-5.0, 58), (-6.2, 46), (-4, 43.2),
            (5, 43.2), (6.0, 50), (5.4, 60), (6.2, 70), (4, 79.5)], R_BLUE,
           steps=6)
    f.line([(-6, 46.6), (0, 44.6), (5.9, 47)], 0.8, R_GOLD)
    for y in (73, 69, 65, 61):
        f.line([(1.8, y), (5.6, y)], 0.75, R_GOLD)
    f.poly([(-5.6, 52), (5.8, 52), (6.1, 56), (-5.8, 56)], R_RED, lw=3.5)
    f.poly([(1.0, 51.6), (3.4, 51.6), (3.4, 56.4), (1.0, 56.4)], R_GOLD, lw=3)
    # pelisse trailing behind (far shoulder)
    f.blob([(-3.5, 80), (-8.5, 78), (-13, 70), (-14.5, 58), (-11, 56),
            (-8.2, 62), (-6, 70)], R_BLUE, steps=6)
    f.poly([(-14.8, 60), (-14.2, 55.6), (-12, 53.8), (-10.4, 56.2),
            (-11.8, 58.2), (-13.2, 59.4)], R_GREY, lw=3.2)
    # near leg (tall boot), forward
    f.limb([(0.8, 48), (3.6, 34), (3.3, 26)], 6.4, cream)
    f.blob([(0.2, 27.5), (6.2, 27.5), (5.8, 12), (5.0, 7), (0.8, 7),
            (0.2, 14)], R_BOOT1)
    f.poly([(0.0, 27.7), (6.4, 27.7), (6.4, 25.6), (0, 25.6)], R_GOLD, lw=3.2)
    f.ell(3.6, 2.9, 6.2, 3.2, R_BOOT1, rot=-4)
    spur(f, -2.9, 5.0, 1.0, back=True)
    # near akimbo arm, elbow back
    f.limb([(0.2, 75), (-8.8, 64), (0.8, 53.6)], 4.4, R_BLUE)
    f.poly([(-1.2, 55), (2.6, 52.4), (3.4, 54.6), (-0.4, 57)], R_GOLD, lw=3,
           shade=False)
    f.ell(3.4, 52.6, 2.4, 2.3, R_SKIN, lw=3.5)
    # epaulette near shoulder (big, seen from the side)
    for i in range(7):
        x = -4.5 + i * 1.5
        f.line([(x, 76.0), (x, 70.0)], 0.5, R_GOLD)
    f.ell(-0.2, 77.6, 6.6, 2.9, R_GOLD, rot=-4, lw=4)
    f.ell(-0.2, 77.7, 4.2, 1.6, hx("#E8BE62"), rot=-4, shade=False, lw=2.6)
    f.dot(-0.2, 77.7, 0.8, hx("#A97A24"), True)
    f = f.scaled(1.3, 76)
    # head profile
    hair = R_RED
    f.poly([(-6.4, 93), (-9.8, 90), (-8.2, 88.3), (-10.4, 85.6), (-7.4, 84.8),
            (-8.0, 81.4), (-4.6, 82.8), (0, 84), (0, 93)], hair)
    f.poly([(-1.4, 75), (2.2, 75), (2.6, 81), (-2.0, 81)], R_SKIN)
    f.blob([(-5.6, 90), (-6.2, 85), (-4.4, 81), (-1.4, 79.0), (2.4, 78.6),
            (4.2, 79.6), (4.5, 81.4), (3.9, 82.8), (4.9, 83.2), (5.6, 84.4),
            (8.7, 85.4), (5.6, 87), (5.5, 90.2), (3.4, 92.6), (-2, 93.2)],
           R_SKIN, steps=7)
    f.ell(-2.4, 86.2, 1.2, 1.9, R_SKIN, lw=3)
    f.ell(-1.8, 86.2, 0.4, 0.9, R_SKIN_D, shade=False, outline=False)
    eye(f, 3.7, 88.2, 1.4, 1.95, look=(0.6, -0.1))
    brow(f, [(1.8, 90.8), (3.6, 91.6), (5.4, 92.2)], 0.8, hair)
    f.ell(5.4, 83.6, 1.7, 1.0, hair, rot=10, lw=2.6)
    f.line([(2.8, 81.8), (4.4, 82.0), (5.2, 83.0)], 0.45, OUTLINE, True)
    for x0, h in ((-4.4, 3.2), (-1.2, 2.6), (2.4, 3.0)):
        f.poly([(x0 - 1.7, 91.8), (x0 + 1.7, 91.8), (x0 + 0.2, 91.8 - h)],
               hair, lw=3.5)
    rnd = random.Random(SEED + 1)
    for _ in range(5):
        f.dot(2.4 + rnd.random() * 2.4, 84.6 + rnd.random() * 2.4, 0.28,
              hx("#B0592A"))
    # visor then shako
    f.poly([(5.6, 91.6), (10.2, 91.0), (10.8, 92.2), (6.0, 93.4)], hx("#1F2F4F"),
           lw=3.5)
    shako(f, -4, "side")


def rz_back(f):
    """Ржевский, back view (epaulette now on viewer-right)."""
    f.shadow(0, 17)
    cream = R_CREAM
    f.blob([(-8.0, 48), (-1.5, 48), (-1.7, 30), (-2.3, 15), (-7.6, 15),
            (-8.0, 36)], cream)
    f.blob([(1.5, 48), (8.0, 48), (8.1, 36), (7.6, 25), (2.3, 25),
            (1.7, 30)], cream)
    # viewer-left: short boot ; viewer-right: tall boot (mirror of front)
    f.blob([(-8.3, 14), (-1.9, 14), (-2.2, 9), (-2.9, 4), (-7.7, 4),
            (-8.7, 8)], R_BOOT2)
    f.ell(-5.5, 2.8, 5.8, 3.2, R_BOOT2, rot=12)
    f.poly([(-8.8, 15.6), (-1.6, 15.6), (-1.6, 13), (-8.8, 13)], hx("#8B6338"),
           lw=3.5)
    spur(f, -5.2, 5.2, 1.5, back=True)
    f.blob([(2.2, 27), (8.0, 27), (8.4, 15), (7.6, 7), (2.8, 7), (2.4, 15)],
           R_BOOT1)
    f.ell(6.7, 2.8, 5.8, 3.2, R_BOOT1, rot=-12)
    spur(f, 5.2, 4.6, 1.0, back=True)
    # pelisse-side arm (viewer left)
    f.limb([(-9.2, 74), (-13.2, 60), (-12.6, 47)], 4.3, R_BLUE)
    f.ell(-12.5, 44.6, 2.3, 2.5, R_SKIN, lw=3.5)
    f.blob([(-3.8, 79.5), (-8.6, 77), (-9.6, 70), (-7.8, 58), (-9.4, 46),
            (-4, 43.2), (4, 43.2), (9.4, 46), (7.8, 58), (9.6, 70), (8.6, 77),
            (3.8, 79.5)], R_BLUE, steps=6)
    f.line([(0, 77), (0, 46)], 0.7, R_GOLD)
    for i, y in enumerate((72, 66, 60)):
        f.line([(-5.5, y + 3), (0, y), (5.5, y + 3)], 0.7, R_GOLD)
    f.line([(-9.0, 46.6), (-4, 44.5), (4, 44.5), (9.0, 46.6)], 0.8, R_GOLD)
    f.poly([(-8.1, 52), (8.1, 52), (8.4, 56), (-8.4, 56)], R_RED, lw=3.5)
    # akimbo arm (viewer right)
    f.limb([(9.3, 75), (17.8, 62.5), (9.3, 53)], 4.5, R_BLUE)
    f.ell(7.6, 51.4, 2.5, 2.4, R_SKIN, lw=3.5)
    # pelisse (viewer left): big cape on the back
    f.blob([(-3.0, 80.2), (-9.6, 80.2), (-14.5, 74), (-16.2, 60), (-14, 50),
            (-9, 47), (-4, 56), (-2.6, 68)], R_BLUE, steps=6)
    f.poly([(-16.6, 61), (-16.0, 55), (-14.2, 49.4), (-11, 46.2), (-9, 48.4),
            (-12, 52.6), (-13.6, 57.2)], R_GREY, lw=3.2)
    f.line([(-6, 76), (-9.5, 66), (-12, 56)], 0.6, R_GOLD, smooth=True)
    # epaulette (viewer right)
    for i in range(9):
        x = 7.4 + i * 1.65
        f.line([(x, 76.4), (x, 70.3)], 0.5, R_GOLD)
    f.ell(12.2, 77.2, 7.6, 3.5, R_GOLD, rot=-10, lw=4)
    f.ell(12.2, 77.4, 5.0, 2.0, hx("#E8BE62"), rot=-10, shade=False, lw=2.6)
    f.dot(12.2, 77.4, 0.9, hx("#A97A24"), True)
    f = f.scaled(1.3, 76)
    # head from behind: full tousled hair
    hair = R_RED
    f.poly([(-1.9, 75), (1.9, 75), (2.1, 81), (-2.1, 81)], R_SKIN)
    f.blob([(-6.4, 90), (-6.8, 86), (-5.4, 81.0), (0, 79.4), (5.4, 81.0),
            (6.8, 86), (6.4, 90), (3, 93), (-3, 93)], hair)
    for sx in (-1, 1):
        f.ell(sx * 6.7, 86.6, 1.2, 1.9, R_SKIN, lw=3)
    pts = [(-6.6, 88), (-9.8, 87), (-7.4, 84.4), (-9.4, 81.4), (-5.8, 82.4),
           (-4.0, 79.0), (-1.6, 81.6), (0.6, 78.2), (2.4, 81.4), (4.8, 78.6),
           (5.6, 82.2), (8.6, 80.8), (7.0, 84.6), (10.0, 85.6), (6.7, 88.2)]
    f.poly(pts, hair, lw=3.8)
    f.poly([(1.0, 92), (4.6, 94.5), (3.0, 91.4)], hair, lw=3)
    shako(f, 0, "back")


# ==========================================================================
# 2. Бублик
# ==========================================================================
B_GREEN, B_CAP, B_SACK, B_SKIN = (hx("#6B8E4E"), hx("#7A5C3A"), hx("#C9B28B"),
                                  hx("#E8B98F"))
B_BEARD, B_PANTS, B_ROPE = hx("#5B3F28"), hx("#4F4538"), hx("#A98A55")
B_SKIN_D = hx("#CF9368")


def sack(f, cx, cy, s=1.0, front=True):
    """Huge lumpy sack with a tied neck and a patch."""
    pts = [(cx - 15 * s, cy - 22 * s), (cx - 21 * s, cy - 4 * s),
           (cx - 17 * s, cy + 14 * s), (cx - 7 * s, cy + 24 * s),
           (cx - 4 * s, cy + 30 * s), (cx + 6 * s, cy + 30 * s),
           (cx + 8 * s, cy + 24 * s), (cx + 17 * s, cy + 14 * s),
           (cx + 21 * s, cy - 4 * s), (cx + 15 * s, cy - 22 * s),
           (cx, cy - 25 * s)]
    f.blob(pts, B_SACK, steps=8)
    f.poly([(cx - 5 * s, cy + 27 * s), (cx + 5 * s, cy + 27 * s),
            (cx + 9 * s, cy + 34 * s), (cx + 2 * s, cy + 32 * s),
            (cx - 3 * s, cy + 35 * s), (cx - 9 * s, cy + 33 * s)], B_SACK,
           lw=3.6)
    f.line([(cx - 5.5 * s, cy + 24.5 * s), (cx + 5.5 * s, cy + 24.5 * s)],
           1.3, B_ROPE)
    f.poly([(cx - 12 * s, cy + 2 * s), (cx - 3 * s, cy + 3 * s),
            (cx - 4 * s, cy - 7 * s), (cx - 13 * s, cy - 6 * s)],
           hx("#A8B67C"), lw=3.2, shade=False)
    f.line([(cx - 12.4 * s, cy - 2 * s), (cx - 3.6 * s, cy - 2 * s)], 0.3,
           OUTLINE)
    f.line([(cx + 6 * s, cy + 10 * s), (cx + 11 * s, cy + 1 * s),
            (cx + 9 * s, cy - 10 * s)], 0.35, hx("#9A8460"), smooth=True)


def bublik_head(f, view):
    """Round head, cap, spade beard (front / side / back)."""
    hy = 60
    cap_col = B_CAP
    if view == "back":
        f.ell(0, hy, 11.2, 10.5, B_SKIN)
        for sx in (-1, 1):
            f.ell(sx * 11.2, hy - 1, 2.2, 3.0, B_SKIN, lw=3.5)
        f.blob([(-10.6, hy + 2), (-10.2, hy - 8), (-5, hy - 12), (5, hy - 12),
                (10.2, hy - 8), (10.6, hy + 2), (0, hy + 4)], B_BEARD)
    elif view == "front":
        # spade beard behind the chin, broad flat bottom
        f.blob([(-10.4, hy - 2), (-12.4, hy - 11), (-9.4, hy - 19),
                (-4, hy - 21), (4, hy - 21), (9.4, hy - 19), (12.4, hy - 11),
                (10.4, hy - 2), (0, hy - 6)], B_BEARD, steps=7)
        f.ell(0, hy, 11.0, 10.4, B_SKIN)
        for sx in (-1, 1):
            f.ell(sx * 11.2, hy, 2.0, 3.0, B_SKIN, lw=3.5)
        f.blob([(-10.0, hy - 3), (-6, hy - 9), (0, hy - 7.5), (6, hy - 9),
                (10.0, hy - 3), (9.4, hy - 14), (4, hy - 19), (-4, hy - 19),
                (-9.4, hy - 14)], B_BEARD, steps=7)
        f.ell(0, hy - 1.5, 3.1, 2.8, B_SKIN_D, lw=3.5)       # nose
        f.ell(0, hy - 1.5, 11.6, 0.1, B_SKIN, outline=False, shade=False)
        f.blob([(-7, hy - 5.4), (-3.5, hy - 6.8), (0, hy - 5.4), (3.5, hy - 6.8),
                (7, hy - 5.4), (4, hy - 9), (-4, hy - 9)], B_BEARD, lw=3)
        f.line([(-2.8, hy - 10.4), (0, hy - 11.4), (2.8, hy - 10.4)], 0.55,
               hx("#E8B98F"), smooth=True)
        for sx in (-1, 1):
            f.ell(sx * 4.4, hy + 2.6, 1.0, 1.35, OUTLINE, shade=False,
                  outline=False)
            f.dot(sx * 4.4 + 0.3, hy + 3.0, 0.3, WHITE)
            brow(f, [(sx * 7.4, hy + 4.4), (sx * 4.8, hy + 6.2),
                     (sx * 2.2, hy + 5.0)], 1.0, B_BEARD)
        f.ell(-6.4, hy - 3, 1.7, 1.1, hx("#E58A7B"), shade=False,
              outline=False)
        f.ell(6.4, hy - 3, 1.7, 1.1, hx("#E58A7B"), shade=False,
              outline=False)
    else:                                                  # side
        f.ell(0, hy, 10.6, 10.4, B_SKIN)
        f.ell(-3.4, hy - 0.6, 1.7, 2.6, B_SKIN, lw=3.5)
        f.blob([(-1, hy - 5), (5, hy - 7), (11, hy - 10), (12.4, hy - 16),
                (7, hy - 21.5), (0, hy - 19), (-4, hy - 11)], B_BEARD, steps=7)
        f.ell(11.2, hy - 1.4, 3.2, 3.0, B_SKIN_D, lw=3.5)       # nose
        f.blob([(5.4, hy - 4.6), (11.6, hy - 5.8), (11.2, hy - 8.4),
                (5, hy - 7.4)], B_BEARD, lw=3)
        f.ell(6.4, hy + 2.6, 1.0, 1.35, OUTLINE, shade=False, outline=False)
        brow(f, [(3.6, hy + 4.8), (6.4, hy + 6.4), (9.0, hy + 5.0)], 1.0,
             B_BEARD)
        f.ell(5.0, hy - 3, 1.6, 1.0, hx("#E58A7B"), shade=False,
              outline=False)
    # flat cap (kartuz)
    px = 0
    f.blob([(-11.8, hy + 6), (-11.4, hy + 10.6), (-5, hy + 13.4), (3, hy + 14.2),
            (10, hy + 12), (12, hy + 7), (11, hy + 4), (-11, hy + 4)],
           cap_col, steps=7)
    f.poly([(-11.6, hy + 4), (11.6, hy + 4), (11.6, hy + 7), (-11.6, hy + 7)],
           hx("#5E4529"), lw=3.5)
    if view == "front":
        f.blob([(-8, hy + 5), (0, hy + 3.5), (8, hy + 5), (7, hy + 8.4),
                (-7, hy + 8.4)], hx("#5E4529"), lw=3)
    if view == "side":
        f.blob([(8, hy + 5), (17.5, hy + 4.6), (18.2, hy + 6.6), (9, hy + 8)],
               hx("#5E4529"), lw=3.2)
    f.dot(px + (4 if view == "side" else 0), hy + 13.6, 0.7, hx("#5E4529"),
          True)


def bublik(f, view):
    """Бублик: short, stocky, flat cap, spade beard, huge sack."""
    f.shadow(0, 22 if view != "side" else 19, 2.2)
    pants, boot = B_PANTS, hx("#6B4A2E")
    sx0 = 1 if view != "side" else 0
    if view == "front":
        sack(f, 15, 50, 1.0)
    if view == "side":
        sack(f, -17, 38, 1.0)
    # legs
    if view == "side":
        f.limb([(-1.5, 24), (-2, 8)], 7.5, pants)
        f.ell(2.6, 3.4, 7.2, 3.8, boot, rot=-3)
        f.limb([(2.5, 24), (3, 8)], 8, pants)
        f.ell(6.6, 3.4, 7.2, 3.8, boot, rot=3)
    else:
        for sx in (-1, 1):
            f.limb([(sx * 6.2, 25), (sx * 6.8, 8)], 8.4, pants)
            f.ell(sx * 8.4, 3.6, 7.0, 3.9, boot, rot=-sx * 8)
            if view == "front":
                f.line([(sx * 4.4, 6.2), (sx * 10.4, 6.5)], 0.45,
                       hx("#C9B28B"))
    f = Frame(f.cv, f.cx, f.gy + 4 * f.k, f.k, f.flip)
    # arms (behind torso when side)
    if view == "front":
        f.limb([(-13, 46), (-18.5, 36), (-17.5, 26)], 6.2, B_GREEN)
        f.ell(-17.4, 22.6, 3.4, 3.6, B_SKIN, lw=3.5)
    # torso
    if view == "side":
        f.blob([(-3, 53), (-10.5, 46), (-12.5, 34), (-9.5, 24), (0, 21),
                (9, 24), (12.5, 34), (11, 46), (4, 53)], B_GREEN, steps=7)
        f.line([(-10, 33), (11, 33)], 1.6, B_ROPE)
        f.line([(6, 40), (6, 26)], 0.4, hx("#4E6A38"))
    else:
        f.blob([(0, 53.2), (-9.5, 51), (-15, 42), (-16.6, 33), (-13.5, 24),
                (0, 21), (13.5, 24), (16.6, 33), (15, 42), (9.5, 51)],
               B_GREEN, steps=7)
        f.line([(-15.8, 31), (0, 29.5), (15.8, 31)], 1.6, B_ROPE, True)
        if view == "front":
            f.line([(0, 52.5), (0, 30)], 0.45, hx("#4E6A38"))
            for y in (46, 40, 35):
                f.dot(0, y, 0.7, hx("#C9B28B"), True)
            f.poly([(-4.5, 28.5), (4.5, 28.5), (4.5, 22), (-4.5, 22)],
                   hx("#7E9F5E"), lw=3, shade=False)   # patch
        else:
            f.line([(-8, 48), (-2, 36), (-9, 26)], 0.5, hx("#4E6A38"), True)
    # neck + head
    bublik_head(f.scaled(1.22, 50), view)
    # arms in front
    if view == "front":
        f.limb([(13, 46), (19.5, 52), (19, 62)], 6.2, B_GREEN)   # holds sack
        f.ell(19.2, 65, 3.4, 3.3, B_SKIN, lw=3.5)
    elif view == "side":
        f.limb([(0, 46), (6, 34), (9, 31)], 6.4, B_GREEN)
        f.ell(10, 29.6, 3.2, 3.2, B_SKIN, lw=3.5)
        f.limb([(-9, 50), (-14, 42), (-13, 34)], 5.6, B_GREEN)
    else:
        f.limb([(-13, 47), (-21, 52), (-18, 63)], 6.2, B_GREEN)
        f.ell(-17.6, 65.4, 3.3, 3.3, B_SKIN, lw=3.5)
        f.limb([(13, 47), (21, 52), (18, 63)], 6.2, B_GREEN)
        f.ell(17.6, 65.4, 3.3, 3.3, B_SKIN, lw=3.5)


def bublik_back_sack(f):
    """Back view: the sack hides most of the back."""
    sack(f, 0, 41, 1.0)


def sheet_bublik(sil=False):
    """Sheet 2: Бублик 3-view turnaround, 2048x1024."""
    cv = Canvas(2048, 1024, sil=sil)
    k = 9.3
    for cx, view, lab in ((400, "front", "СПЕРЕДИ"), (1024, "side", "СБОКУ"),
                          (1650, "back", "СЗАДИ")):
        f = Frame(cv, cx, 905, k)
        if view == "back":
            # draw body first, sack over it
            bublik_back(f)
        else:
            bublik(f, view)
        if not sil:
            cv.text((cx, 940), lab, 18, hx("#8C6A4A"), anchor="mm")
    if not sil:
        cv.caption("БУБЛИК, денщик — лист поворотов", "Ludus · концепт 02")
    return cv


def bublik_back(f):
    """Бублик from behind: head and legs, sack over the back."""
    f.shadow(0, 22, 2.2)
    pants, boot = B_PANTS, hx("#6B4A2E")
    for sx in (-1, 1):
        f.limb([(sx * 6.2, 25), (sx * 6.8, 8)], 8.4, pants)
        f.ell(sx * 8.4, 3.6, 7.0, 3.9, boot, rot=-sx * 8)
    f = Frame(f.cv, f.cx, f.gy + 4 * f.k, f.k, f.flip)
    f.blob([(0, 53.2), (-9.5, 51), (-15, 42), (-16.6, 33), (-13.5, 24),
            (0, 21), (13.5, 24), (16.6, 33), (15, 42), (9.5, 51)],
           B_GREEN, steps=7)
    f.line([(-15.8, 31), (0, 29.5), (15.8, 31)], 1.6, B_ROPE, True)
    bublik_head(f.scaled(1.22, 50), "back")
    sack(f, 0, 36, 1.0)
    f.limb([(-13, 47), (-21, 52), (-18, 63)], 6.2, B_GREEN)
    f.ell(-17.6, 65.4, 3.3, 3.3, B_SKIN, lw=3.5)
    f.limb([(13, 47), (21, 52), (18, 63)], 6.2, B_GREEN)
    f.ell(17.6, 65.4, 3.3, 3.3, B_SKIN, lw=3.5)


# ==========================================================================
# 3-5. Приор Мглин
# ==========================================================================
P_COAT, P_SILVER, P_WAX = hx("#1F2430"), hx("#B9C2CC"), hx("#A12B2B")
P_SKIN, P_SKIN_D, P_BLUSH = hx("#B8B7B0"), hx("#7C7F86"), hx("#E58A7B")
P_LAMP, P_BLUE = hx("#F3D58A"), hx("#3C4A63")
P_COAT_L = hx("#2D3446")
P_HAIR = hx("#3A3F4B")
P_LINING = hx("#6B2230")


def seal(f, x, y, r, col=P_WAX, lobes=9):
    """Scalloped wax seal with an impressed ring."""
    pts = []
    for i in range(lobes * 6):
        a = 2 * math.pi * i / (lobes * 6)
        rr = r * (1 + 0.1 * math.cos(lobes * a))
        pts.append((x + rr * math.cos(a), y + rr * math.sin(a)))
    f.poly(pts, col, lw=f.cv.lw * 0.65)
    f.ell(x, y, r * 0.58, r * 0.58, darker(col, 0.18, (30, 5, 5)),
          shade=False, lw=f.cv.lw * 0.35)
    f.ell(x - r * 0.1, y + r * 0.1, r * 0.22, r * 0.22, mix(col, WHITE, 0.25),
          shade=False, outline=False)


def collar_fan(f, R=15.5):
    """Big fan collar: a charcoal half-disc rimmed with wax seals.

    Local origin = neck base; the fan opens upward behind the head.
    """
    arc = [(R * math.cos(math.radians(a)), R * math.sin(math.radians(a)) * 1.0)
           for a in range(-8, 189, 8)]
    f.poly([(-R, -3)] + arc + [(R, -3)], P_COAT_L, shade=P_BLUE)
    for a in range(20, 170, 25):                       # pleat lines
        r = math.radians(a)
        f.line([(2 * math.cos(r), 2 * math.sin(r)),
                (R * 0.88 * math.cos(r), R * 0.88 * math.sin(r))], 0.35,
               P_SILVER)
    for ring, (rad, n, rs) in enumerate(((R, 11, 3.1), (R * 0.64, 7, 2.6))):
        for i in range(n):
            a = math.radians(8 + 164 * i / (n - 1))
            seal(f, rad * math.cos(a), rad * math.sin(a), rs,
                 P_WAX if (i + ring) % 2 == 0 else hx("#8F2323"))


def claw_hand(f, x, y, ang=0, s=1.0):
    """Glove with long feather-quill claws."""
    f.ell(x, y, 2.0 * s, 2.4 * s, P_COAT_L, rot=ang, lw=3.5)
    for i, da in enumerate((-30, -10, 10, 30)):
        a = math.radians(-90 + da + ang)
        L = 4.6 * s
        base = (x + math.cos(a) * 1.6 * s, y + math.sin(a) * 1.6 * s)
        tip = (x + math.cos(a) * (1.6 * s + L), y + math.sin(a) * (1.6 * s + L))
        n = (-math.sin(a) * 0.55 * s, math.cos(a) * 0.55 * s)
        f.poly([(base[0] + n[0], base[1] + n[1]), tip,
                (base[0] - n[0], base[1] - n[1])], P_SILVER, lw=3.0,
               shade=False)


def gull_brow(f, s, raise_=0.0, tilt=0.0, w=1.35, dip=1.0):
    """Seagull-shaped eyebrow (two arcs with a dip) for side s = -1/+1."""
    pts = [(s * 9.0, 5.6), (s * 7.0, 8.0), (s * 5.2, 6.6 + (1 - dip) * 0.6),
           (s * 3.6, 7.2 + 0.7 * dip), (s * 1.8, 6.4)]
    pts = [(x, y + raise_) for x, y in pts]
    c = (s * 5.4, 7.0 + raise_)
    pts = rotate(pts, tilt * s, c)
    f.line(pts, w, P_HAIR, smooth=True)


def prior_face(f, emo="grim", hat=False):
    """Prior Mglin's head, local origin = face centre, ~20 units wide."""
    f.poly([(-8.6, 7), (-12.4, 11), (-8.8, 12.4)], P_HAIR, lw=3.4)   # hair
    f.poly([(8.6, 7), (12.4, 11), (8.8, 12.4)], P_HAIR, lw=3.4)
    for sx in (-1, 1):
        f.poly([(sx * 9.0, 3), (sx * 13.4, 7.4), (sx * 9.4, -1.5)], P_SKIN,
               shade=P_SKIN_D, lw=3.6)
    if not hat:
        f.poly([(-8, 11), (-3, 15), (0, 24), (3, 15), (8, 11), (0, 12.5)],
               P_HAIR, lw=3.6)
    face = [(-9.2, 6), (-10, 0), (-7, -7), (-3, -11.8), (0, -13.4),
            (3, -11.8), (7, -7), (10, 0), (9.2, 6), (5.5, 11), (0, 12),
            (-5.5, 11)]
    if emo == "shout":
        face = [(-9.8, 6), (-10.4, -1), (-8, -9), (-4, -14.6), (0, -16),
                (4, -14.6), (8, -9), (10.4, -1), (9.8, 6), (5.5, 11), (0, 12),
                (-5.5, 11)]
    f.blob(face, P_SKIN, shade=P_SKIN_D, steps=8)
    f.poly([(-9.2, 6.4), (-5, 10.2), (-1.6, 8.0), (0, 11.8), (1.6, 8.0),
            (5, 10.2), (9.2, 6.4), (5.5, 11.4), (-5.5, 11.4)], P_HAIR, lw=3.4)
    # brows / eyes per emotion
    cfg = {
        "grim": dict(tilt=14, raise_=-0.6, open=0.55, look=(0, -0.2)),
        "shout": dict(tilt=22, raise_=1.0, open=1.0, look=(0, 0)),
        "shy": dict(tilt=-14, raise_=0.4, open=0.9, look=(-0.5, -0.5)),
        "giggle": dict(tilt=-6, raise_=1.0, open=0.0, look=(0, 0)),
        "think": dict(tilt=0, raise_=0.0, open=0.8, look=(0.6, 0.6)),
    }[emo]
    for sx in (-1, 1):
        rr = cfg["raise_"]
        tl = cfg["tilt"]
        if emo == "think":
            rr += 1.6 if sx == 1 else -0.4
            tl = -10 if sx == 1 else 10
        gull_brow(f, sx, rr, tl)
        ex, ey = sx * 4.4, 2.0
        f.ell(ex, ey, 3.5, 3.0, hx("#9C5560"), shade=False, outline=False)
        if cfg["open"] == 0:                       # closed, laughing
            f.line([(ex - 2.3, ey - 0.6), (ex, ey + 1.6), (ex + 2.3, ey - 0.6)],
                   0.55, OUTLINE, smooth=True)
        else:
            oh = 2.1 * cfg["open"]
            f.ell(ex, ey, 2.4, oh + 0.1, EGG, shade=False, lw=3)
            px, py = cfg["look"]
            pr = 0.55 if emo == "shout" else 1.0
            f.ell(ex + px, ey + py * 0.8, pr, pr * 1.1, OUTLINE, shade=False,
                  outline=False)
            if emo == "grim":                        # heavy lids
                f.poly([(ex - 2.9, ey + 2.4), (ex + 2.9, ey + 2.4 + sx * 0.0),
                        (ex + 2.9, ey + 0.4 - sx * 0.3),
                        (ex - 2.9, ey + 0.4)], P_SKIN_D, lw=3, shade=False)
    # nose: long sharp triangle
    f.poly([(-1.1, 3.0), (1.1, 3.0), (2.0, -3.6), (0.2, -5.0), (-0.9, -3.8)],
           P_SKIN, shade=P_SKIN_D, lw=3.6)
    # mouth
    mc = hx("#3A1A22")
    if emo == "grim":
        f.line([(-3.2, -9.4), (-1.2, -8.0), (1.6, -8.0), (3.6, -9.6)], 0.8,
               OUTLINE, smooth=True)
    elif emo == "shout":
        f.blob([(-5.4, -7.2), (-3, -6.6), (3, -6.6), (5.4, -7.2), (4.6, -12.0),
                (0, -15.0), (-4.6, -12.0)], mc, steps=8, shade=False)
        f.poly([(-3.4, -6.7), (3.4, -6.7), (3, -8.7), (-3, -8.7)], EGG,
               shade=False, lw=2.6)
        f.ell(0, -13.0, 2.8, 1.5, hx("#C25A5A"), shade=False, outline=False)
        for dx, dy in ((7.5, -8), (8.4, -10.6), (6.6, -11.2)):  # spit
            f.dot(dx, dy, 0.4, hx("#DDE6EE"))
            f.dot(-dx, dy, 0.4, hx("#DDE6EE"))
    elif emo == "shy":
        f.line([(-2.8, -8.4), (-1.4, -7.4), (0, -8.6), (1.4, -7.4), (2.8, -8.4)],
               0.7, OUTLINE, smooth=True)
        for sx in (-1, 1):
            f.ell(sx * 6.2, -2.0, 3.2, 2.0, P_BLUSH, shade=False,
                  outline=False)
        f.poly([(9.6, 11.0), (8.4, 8.0), (10.8, 8.0)], hx("#A9C7E3"), lw=3,
               shade=False)
    elif emo == "giggle":
        f.blob([(-5.0, -6.8), (0, -7.6), (5.0, -6.8), (3.6, -11.2), (0, -12.6),
                (-3.6, -11.2)], mc, steps=8, shade=False)
        f.poly([(-4.2, -7.0), (4.2, -7.0), (3.4, -9.0), (2.0, -7.6), (0.6, -9.0),
                (-0.8, -7.6), (-2.2, -9.0), (-3.4, -8.4)], EGG, shade=False,
               lw=2.6)
        for sx in (-1, 1):
            f.ell(sx * 6.2, -2.0, 3.0, 1.8, P_BLUSH, shade=False, outline=False)
            f.poly([(sx * 6.4, 0.6), (sx * 7.6, -2.6), (sx * 5.4, -2.6)],
                   hx("#8FB4D9"), lw=3, shade=False)
    else:                                              # think
        f.ell(2.6, -8.4, 1.8, 0.9, mc, rot=8, shade=False, lw=2.6)


def prior_body(f, pose="stand"):
    """Prior full body, local units: ground = 0, ~118 tall."""
    legc = hx("#2A3040")
    # lantern halo (behind everything)
    if pose == "stand":
        f.ell(-27.5, 36, 12, 12, mix(P_LAMP, BG, 0.55), shade=False,
              outline=False)
        f.ell(-27.5, 36, 7.5, 7.5, mix(P_LAMP, BG, 0.3), shade=False,
              outline=False)
        # cane / seal-stamp on the right
        f.limb([(27.5, 0), (27.5, 60)], 1.5, hx("#5A4636"))
        seal(f, 27.5, 63.5, 4.4)
        f.ell(27.5, 63.5, 1.6, 1.6, P_SILVER, shade=False, lw=3)
    # thin legs, long pointed shoes
    for sx in (-1, 1):
        f.limb([(sx * 4.2, 34), (sx * 5.0, 5)], 2.7, legc)
        f.poly([(sx * 5.0 - 2.4, 6.4), (sx * 5.0 + 2.4, 6.4),
                (sx * 5.0 + sx * 10.5, 1.0), (sx * 5.0 + sx * 7.5, -0.2),
                (sx * 5.0 - 2.4, -0.2)], hx("#12151D"), lw=4)
        f.ell(sx * 5.0, 6.2, 1.5, 1.2, P_SILVER, lw=3, shade=False)
    f.shadow(0, 26, 2.4)
    # arms (long, thin)
    f.limb([(-13, 72), (-20, 56), (-26.5, 41)], 3.0, P_COAT_L)
    f.limb([(13, 72), (20, 56), (26.6, 66)], 3.0, P_COAT_L)
    # bell coat with a spiky hem
    hem = [(-31 + i * 6.2, 24.5 if i % 2 == 0 else 19.5) for i in range(11)]
    f.poly([(-5, 82), (-14, 76), (-16, 66), (-19, 52), (-25, 40)] + hem[:]
           + [(25, 40), (19, 52), (16, 66), (14, 76), (5, 82)], P_COAT,
           shade=P_BLUE)
    f.poly([(-4, 78), (4, 78), (13, 24), (-13, 24)], P_LINING, lw=3.2)
    f.poly([(-3.6, 78), (-1.4, 78), (-5.4, 24), (-13, 24)], P_COAT_L, lw=3,
           shade=False)
    f.poly([(3.6, 78), (1.4, 78), (5.4, 24), (13, 24)], P_COAT_L, lw=3,
           shade=False)
    f.line([(0, 78), (0, 25)], 0.6, P_SILVER)
    # medals = rows of seals
    for row, y in enumerate((70, 64.5, 59)):
        for c in range(3 - (row > 1)):
            seal(f, -10.5 + c * 3.5 - row * 0.3, y, 1.5)
    # chain + big pendant
    f.line([(-11, 74), (-6, 57), (0, 52), (6, 57), (11, 74)], 0.8, P_SILVER,
           smooth=True)
    f.dot(-6, 57, 0.8, P_SILVER, True)
    f.dot(6, 57, 0.8, P_SILVER, True)
    f.poly([(0, 52.6), (-1.0, 50.8), (1.0, 50.8)], P_SILVER, lw=2.4,
           shade=False)
    seal(f, 0, 47.5, 3.3)
    # belt of silver
    f.poly([(-9, 44), (9, 44), (9.4, 41.6), (-9.4, 41.6)], P_SILVER, lw=3)
    # hands
    claw_hand(f, -26.5, 40, 0)
    claw_hand(f, 26.6, 67.5, 180, 0.8)
    if pose == "stand":
        f.line([(-26.5, 38), (-27.5, 43)], 0.4, OUTLINE)
        # lantern
        f.line([(-27.5, 43), (-27.5, 47)], 0.4, OUTLINE)
        f.poly([(-30.5, 31), (-24.5, 31), (-25.5, 43), (-29.5, 43)], P_SILVER,
               lw=3.5, shade=False)
        f.poly([(-29.2, 33), (-25.8, 33), (-26.4, 41.4), (-28.6, 41.4)],
               P_LAMP, lw=2.4, shade=False)
        f.poly([(-31.5, 43), (-23.5, 43), (-27.5, 47)], P_SILVER, lw=3.2,
               shade=False)
    # collar fan + head + tower hat
    fc = Frame(f.cv, f.cx, f.gy - 76 * f.k, f.k * 1.0, f.flip)
    collar_fan(fc, 20.0)
    f.poly([(-1.8, 74), (1.8, 74), (1.6, 87), (-1.6, 87)], P_SKIN,
           shade=P_SKIN_D, lw=3.5)
    fh = Frame(f.cv, f.cx, f.gy - 92 * f.k, f.k * 0.68, f.flip)
    prior_face(fh, "grim", hat=True)
    d = 4.0                                            # tower hat (spire)
    f.poly([(-8.2, 98.4 + d - 4), (8.2, 98.4 + d - 4), (7.4, 100 + d - 4),
            (-7.4, 100 + d - 4)], P_COAT, lw=3.5)
    f.poly([(-6.2, 99.6), (6.2, 99.6), (4.0, 116), (0, 128), (-4.0, 116)],
           P_COAT, shade=P_BLUE)
    f.poly([(-6.1, 99.8), (6.1, 99.8), (5.7, 103.6), (-5.7, 103.6)], P_SILVER,
           lw=3.2)
    seal(f, 0, 101.7, 1.5)


def sheet_prior1(sil=False):
    """Sheet 3: Приор Мглин P1, 1024x1024 front view."""
    cv = Canvas(1024, 1024, sil=sil)
    f = Frame(cv, 512, 945, 6.9)
    prior_body(f)
    if not sil:
        cv.caption("ПРИОР МГЛИН — Р1, вид спереди", "Ludus · концепт 03")
    return cv


def sheet_rzhevsky(sil=False):
    """Sheet 1: Ржевский 3-view turnaround, 2048x1024."""
    cv = Canvas(2048, 1024, sil=sil)
    k = 6.9
    for cx, fn, lab in ((380, rz_front, "СПЕРЕДИ"), (1024, rz_side, "СБОКУ"),
                        (1668, rz_back, "СЗАДИ")):
        fn(Frame(cv, cx, 905, k))
        if not sil:
            cv.text((cx, 940), lab, 18, hx("#8C6A4A"), anchor="mm")
    if not sil:
        cv.caption("ПОРУЧИК РЖЕВСКИЙ — лист поворотов", "Ludus · концепт 01")
    return cv


def main():
    """Render all sheets deterministically into ./out."""
    os.makedirs(OUT_DIR, exist_ok=True)
    sheets = [("01_rzhevsky_turnaround.png", sheet_rzhevsky),
              ("02_bublik_turnaround.png", sheet_bublik),
              ("03_prior_p1.png", sheet_prior1)]
    sil = "--sil" in sys.argv
    for name, fn in sheets:
        fn().save(os.path.join(OUT_DIR, name))
        if sil:
            fn(True).save(os.path.join(OUT_DIR, "sil_" + name))
        print("wrote", name)


if __name__ == "__main__":
    main()
