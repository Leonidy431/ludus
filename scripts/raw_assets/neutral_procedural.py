"""Our own procedural drawing of the neutral things of the lake (D6).

Why this exists.  Four raw passes over the 99 repositories tried to
fill the neutral slots (stones DEF-057, water plants DEF-058, sunken
wood and pottery DEF-059) and every one was reverted after the eye
check: the antagonist variants made stones into vases, and the gentler
"age and pose" family (neutral_variants.py) reached only 5/12 and 7/12
recognisable variants on wesnoth planks.  The chorus proposed, and the
operator agreed ("все вопросы да"), that the neutral slots move to the
project's own procedural drawing (D6).  Nothing here is fetched from a
third-party repository, so there is nothing to reshape by 35 %: the
drawing is ours, and its register row says so.

Constitution: FORM (a real thing of Issyk-Kul, drawn from its real
proportions and colour in the lake register) -> ACTION (the player
reads the floor: boulder, reed, beam, jar) -> GOAL (learning to read a
place by its real traces, TABOO 0.03 rule 3; the water keeps memory in
things and silt, not in magic).

How a kit is made (TABOO 0.07, "из N лучших K, без выдумки"):
  1. Register.  Each thing is a row of scripts/lake/lake_objects.py:
     granite boulder, quartz pebbles, shore reeds, pondweed, timber
     beam, khum jar.  Its colour and its states come from that row.
  2. Honest pool.  Every combination of the thing's real states and a
     few sizes and proportions is drawn; the pool size is whatever it
     is, and the file says it.
  3. Real-object profile.  A drawing whose alpha silhouette does not
     fit its slot in reference.PROFILES is refused (aspect, fill and,
     for stones, a base that rests on the floor).
  4. Diversity.  Twelve are chosen greedily in a fixed order, and each
     new one must differ from every one chosen before by at least 35 %
     of |A xor B| / |A or B| (form.shape_delta, alpha only), with a
     distinct hitbox.  So no two neighbours in the queue look the same
     (TABOO 0.3 rules 49 and 53).  Fewer than twelve is a shortfall
     and ships nothing (never stop at eleven).
  5. The meta-json records shape_change as the distance to the nearest
     sibling ("shape_basis": "nearest-sibling"), because an own drawing
     has no source to be measured against.

Nothing is random: every jitter is read from sha1/shake of a fixed
label, so the same revision always draws the same pixels.  Colour only
paints; the form is the alpha channel (TABOO 0.3 rule 1).

Usage:
    python3 scripts/raw_assets/neutral_procedural.py --out build/d6 \
        --sheet docs/audit/2026-09-30/neutral-procedural-D6-contact.png \
        [--ship public/ludus/art/derived]
"""

import argparse
import hashlib
import json
import math
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))

from form import (CANVAS, INTERIOR_WEIGHT, alpha_mask,  # noqa: E402
                  area, fill_holes, hitbox, hitbox_key, iou_delta)
import neutral_variants  # noqa: E402
import reference  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts' / 'lake'))
import lake_objects  # noqa: E402

THRESHOLD = 0.35
KIT_SIZE = 12
# Supersampling of the drawing: polygons are drawn four times larger and
# reduced, so the alpha edge is smooth without any blur of the form.
SS = 4
# The floor line of every thing that rests on the bottom.
FLOOR = 238
# Raise whenever a drawing function or a pool changes, so the meta names
# which drawing shipped (an own drawing has no upstream commit).
REVISION = 'neutral-drawing-r1'
HERE = 'scripts/raw_assets/neutral_procedural.py'

# Register colours used for details (lake_objects.ITEMS).
ALGAE = '#6a8a3a'      # nitchatka, filamentous algae on stones
SILT = '#6a655a'       # silt plain
SAND = '#c8b890'       # sand ripples


def _rgb(hexcol):
    return tuple(int(hexcol[i:i + 2], 16) for i in (1, 3, 5))


def register_row(thing):
    """The lake-register row of a thing, as a dict."""
    for row in lake_objects.ITEMS:
        if row[0] == thing:
            return {'id': row[0], 'category': row[1], 'ru': row[2],
                    'en': row[3], 'depth_m': list(row[4]),
                    'shape': row[9], 'size_m': row[10], 'colour': row[11],
                    'states': list(row[12])}
    raise KeyError(thing)


# --- Deterministic numbers ---------------------------------------------

def seed_of(thing):
    return hashlib.sha1(
        f'ludus-own-drawing:neutral:{thing}'.encode()).hexdigest()


def unit(*keys):
    """A number in [0, 1) read from sha1 of the keys; never random."""
    text = ':'.join(str(k) for k in keys)
    return int(hashlib.sha1(text.encode()).hexdigest()[:8], 16) / 2 ** 32


def signed(*keys):
    return 2 * unit(*keys) - 1


def noise(seed, label, grid, size=CANVAS):
    """Smooth value noise: a small grid of shake bytes, scaled up."""
    data = hashlib.shake_256(f'{seed}:{label}'.encode()).digest(grid * grid)
    small = Image.frombytes('L', (grid, grid), data)
    return small.resize((size, size), Image.BICUBIC)


# --- Painting ------------------------------------------------------------

def _scale(img, k):
    return img.point(lambda v: min(255, int(v * k)))


def paint(alpha, colour, seed, grain=None, speckle=0.18):
    """Paint a form in its register colour with light from the surface.

    The light comes from above and a little to the left, as through the
    water: faces turned up and left are lighter, the underside darker.
    The relief is the blurred alpha, so shading follows the silhouette
    without changing it.  grain is an optional 'L' layer (wood grain);
    speckle is the share of stone speckle.
    """
    h = alpha.filter(ImageFilter.GaussianBlur(7))
    up = ImageChops.offset(h, -3, -4)
    bright = ImageChops.subtract(up, h)
    dark = ImageChops.subtract(h, up)
    shade = Image.new('L', alpha.size, 176)
    shade = ImageChops.add(shade, _scale(bright, 3.2))
    shade = ImageChops.subtract(shade, _scale(dark, 3.2))
    # Light falls from the surface: the top of the canvas is brighter.
    ramp = Image.linear_gradient('L').resize(alpha.size)
    shade = ImageChops.subtract(shade, _scale(ramp, 0.22))
    tex = noise(seed, 'speckle', 48)
    shade = ImageChops.add(shade, _scale(tex, speckle), offset=0)
    shade = ImageChops.subtract(shade, _scale(tex.point(lambda v: 255 - v),
                                              speckle))
    if grain is not None:
        shade = ImageChops.subtract(shade, grain)
    # The rim: one pixel darker all round reads as the contact shadow.
    inner = alpha.filter(ImageFilter.MinFilter(3))
    rim = ImageChops.subtract(alpha, inner)
    shade = ImageChops.subtract(shade, _scale(rim, 0.35))
    base = Image.new('RGB', alpha.size, tuple(min(255, int(c * 1.45))
                                              for c in colour))
    rgb = ImageChops.multiply(base, Image.merge('RGB', [shade] * 3))
    out = rgb.convert('RGBA')
    out.putalpha(alpha)
    return out


def layer(img, alpha, colour, seed, label, speckle=0.12):
    """Paint an extra part (algae, silt, sand) over the image."""
    part = paint(alpha, colour, f'{seed}:{label}', speckle=speckle)
    return Image.alpha_composite(img, part)


def reduce(big):
    """Supersampled 'L' drawing -> canvas alpha with a smooth edge."""
    return big.resize((CANVAS, CANVAS), Image.LANCZOS)


def canvas_big():
    return Image.new('L', (CANVAS * SS, CANVAS * SS), 0)


def _pts(points):
    return [(x * SS, y * SS) for x, y in points]


# --- Stones: granite boulder, quartz pebbles (DEF-057) -------------------

def stone_outline(cx, floor, w, h, family, key, flat=0.14):
    """Closed outline of a stone resting on the floor, side view.

    rounded  a superellipse with low harmonics: a water-worn boulder;
    angular  a few broad facets: a granite block that broke off a slope.
    The lowest part is cut flat and set on the floor line, because a
    stone lies on its broad face (the lake pass let a diamond tile in
    here, and its variants read as vases).
    """
    rx, ry = w / 2, h / (2 * (1 - flat))
    cy = floor - (1 - flat) * ry * 2 + ry
    pts = []
    if family == 'angular':
        n = 7 + int(unit(key, 'n') * 3)
        for i in range(n):
            t = 2 * math.pi * (i + 0.35 * signed(key, 'a', i)) / n
            r = 0.9 + 0.1 * unit(key, 'r', i)
            pts.append((cx + rx * r * math.cos(t), cy + ry * r * math.sin(t)))
    else:
        harm = [(k, 0.045 * signed(key, 'h', k), 2 * math.pi *
                 unit(key, 'p', k)) for k in (2, 3, 4, 5)]
        for i in range(96):
            t = 2 * math.pi * i / 96
            r = 1 + sum(a * math.cos(k * t + p) for k, a, p in harm)
            c, s = math.cos(t), math.sin(t)
            x = math.copysign(abs(c) ** 0.8, c)
            y = math.copysign(abs(s) ** 0.8, s)
            pts.append((cx + rx * r * x, cy + ry * r * y))
    cut = floor
    pts = [(x, min(y, cut)) for x, y in pts]
    low = max(y for _, y in pts)
    return [(x, y + floor - low) for x, y in pts]


def draw_stone(p, seed):
    """One stone (or a boulder with a smaller one) in a given state."""
    colour = _rgb(p['colour'])
    big = canvas_big()
    d = ImageDraw.Draw(big)
    main = stone_outline(128, FLOOR, p['w'], p['h'], p['family'], p['key'])
    d.polygon(_pts(main), fill=255)
    alpha = reduce(big)
    img = paint(alpha, colour, seed, speckle=0.14)
    if p['state'] in ('pair', 'field'):
        # A second, smaller stone in front and to the side: a field of
        # boulders as the ROV meets it on the slope.
        side = 1 if unit(p['key'], 'side') < 0.5 else -1
        w2, h2 = p['w'] * 0.48, p['h'] * 0.5
        cx2 = 128 + side * (p['w'] * 0.5 - w2 * 0.15)
        cx2 = max(w2 / 2 + 2, min(CANVAS - w2 / 2 - 2, cx2))
        big2 = canvas_big()
        ImageDraw.Draw(big2).polygon(_pts(stone_outline(
            cx2, FLOOR, w2, h2, 'rounded', p['key'] + ':2')), fill=255)
        a2 = reduce(big2)
        tint = tuple(max(0, int(c * 0.92)) for c in colour)
        img = Image.alpha_composite(img, paint(a2, tint, seed + ':2',
                                               speckle=0.14))
    if p['state'] == 'algae':
        # Filamentous algae on the faces turned to the light.
        bigA = canvas_big()
        dA = ImageDraw.Draw(bigA)
        top = min(y for _, y in main)
        tops = [(x, y) for x, y in main if y < top + p['h'] * 0.3]
        for i, (x, y) in enumerate(tops[::2]):
            length = 7 + 9 * unit(p['key'], 'alg', i)
            lean = 6 * signed(p['key'], 'lean', i)
            dA.line(_pts([(x, y + 3), (x + lean, y - length)]),
                    fill=255, width=2 * SS)
            dA.ellipse([(x - 3) * SS, (y - 1) * SS, (x + 3) * SS,
                        (y + 5) * SS], fill=255)
        img = layer(img, reduce(bigA), _rgb(ALGAE), seed, 'algae', 0.3)
    if p['state'] == 'silt':
        # Half sunk in silt: a drift covers the foot of the stone.
        bigS = canvas_big()
        mw, mh = p['w'] * 0.62, p['h'] * 0.26
        ImageDraw.Draw(bigS).ellipse(
            [(128 - mw) * SS, (FLOOR - mh) * SS, (128 + mw) * SS,
             (FLOOR + mh) * SS], fill=255)
        s_alpha = reduce(bigS)
        img = layer(img, s_alpha, _rgb(SILT), seed, 'silt', 0.1)
    return img


def stone_pool(thing):
    """Every state x size x proportion of a stone, in a fixed order."""
    row = register_row(thing)
    pool = []
    if thing == 'boulder':
        states = ('single', 'algae', 'field', 'silt')
        families = ('rounded', 'angular')
        aspects = (1.0, 1.35, 1.8, 2.4)
        widths = (224, 184, 150, 122, 98)
    else:
        states = ('single', 'pair', 'sand')
        families = ('rounded',)
        aspects = (1.25, 1.6, 2.1, 2.6)
        widths = (200, 160, 128, 100, 80)
    for w in widths:
        for a in aspects:
            for fam in families:
                for st in states:
                    h = min(200, w / a)
                    key = f'{thing}:{st}:{fam}:{w}:{a}'
                    pool.append({'thing': thing, 'state': st,
                                 'family': fam, 'w': w, 'h': round(h, 1),
                                 'aspect': a, 'key': key,
                                 'colour': row['colour']})
    return pool


def draw_pebble(p, seed):
    """Quartz pebbles: water-rounded, pale, one or two, or in sand."""
    q = dict(p)
    q['state'] = {'pair': 'pair', 'sand': 'silt'}.get(p['state'], 'single')
    img = draw_stone(q, seed)
    if p['state'] == 'sand':
        # The drift is sand here, not silt: repaint it in sand colour.
        bigS = canvas_big()
        mw, mh = p['w'] * 0.62, p['h'] * 0.26
        ImageDraw.Draw(bigS).ellipse(
            [(128 - mw) * SS, (FLOOR - mh) * SS, (128 + mw) * SS,
             (FLOOR + mh) * SS], fill=255)
        img = layer(img, reduce(bigS), _rgb(SAND), seed, 'sand', 0.1)
    return img


# --- Water plants: shore reeds, pondweed (DEF-058) ------------------------

def _bezier(p0, p1, p2, n=24):
    out = []
    for i in range(n + 1):
        t = i / n
        a, b, c = (1 - t) ** 2, 2 * (1 - t) * t, t * t
        out.append((a * p0[0] + b * p1[0] + c * p2[0],
                    a * p0[1] + b * p1[1] + c * p2[1]))
    return out


def _stroke(d, pts, w0, w1):
    """A tapering stroke along a polyline (widths in canvas pixels)."""
    n = len(pts) - 1
    for i in range(n):
        w = w0 + (w1 - w0) * i / n
        d.line(_pts(pts[i:i + 2]), fill=255, width=max(1, int(w * SS)))
        r = w / 2
        x, y = pts[i + 1]
        d.ellipse([(x - r) * SS, (y - r) * SS, (x + r) * SS, (y + r) * SS],
                  fill=255)


def _leaf(d, base, angle, length, width):
    """A narrow blade leaf from a point, as a polygon."""
    ca, sa = math.cos(angle), math.sin(angle)
    pts = []
    for i in range(13):
        t = i / 12
        half = width * math.sin(math.pi * t) * (1 - 0.4 * t)
        pts.append((t * length, half))
    pts += [(x, -y) for x, y in reversed(pts)]
    d.polygon(_pts([(base[0] + x * ca - y * sa, base[1] + x * sa + y * ca)
                    for x, y in pts]), fill=255)


def draw_reeds(p, seed):
    """Shore reeds (Phragmites): stems, blade leaves, plumes on top."""
    colour = _rgb(p['colour'])
    stems = canvas_big()
    ds = ImageDraw.Draw(stems)
    plumes = canvas_big()
    dp = ImageDraw.Draw(plumes)
    n, height, lean, key = p['n'], p['height'], p['lean'], p['key']
    spread = 8 + 3.2 * n
    for i in range(n):
        x0 = 128 + spread * (i / max(1, n - 1) - 0.5) * 2 \
            + 4 * signed(key, 'x', i)
        hi = height * (0.78 + 0.22 * unit(key, 'h', i))
        tip = (x0 + lean * hi * 0.35 + 8 * signed(key, 't', i),
               FLOOR - hi)
        ctrl = (x0 + lean * hi * 0.05, FLOOR - hi * 0.55)
        line = _bezier((x0, FLOOR), ctrl, tip)
        broken = p['state'] == 'broken' and i % 2 == 0
        if broken:
            # A stem snapped by ice or waves: the top hangs down.
            k = int(len(line) * (0.5 + 0.2 * unit(key, 'b', i)))
            bx, by = line[k]
            side = 1 if lean >= 0 else -1
            hang = _bezier((bx, by), (bx + side * 18, by - 6),
                           (bx + side * 26, by + hi * 0.3))
            line = line[:k + 1]
            _stroke(ds, hang, 2.2, 1.2)
        _stroke(ds, line, 3.2, 1.6)
        for j in range(3):
            k = int(len(line) * (0.25 + 0.2 * j))
            ang = -math.pi / 2 + (0.55 + 0.25 * unit(key, 'l', i, j)) * \
                (1 if (i + j) % 2 else -1) + lean * 0.3
            _leaf(ds, line[k], ang, 34 + 16 * unit(key, 'll', i, j), 3.2)
        if not broken:
            x, y = line[-1]
            # The plume: a drooping panicle of seed, brownish purple.
            pl = _bezier((x, y + 14), (x + 6 * lean + 3, y - 8),
                         (x + 14 * (lean or 0.4), y - 2), 12)
            for m, (px, py) in enumerate(pl):
                r = 3.4 * math.sin(math.pi * (m + 1) / 14) + 1.4
                dp.ellipse([(px - r) * SS, (py - r) * SS, (px + r) * SS,
                            (py + r) * SS], fill=255)
    img = paint(reduce(stems), colour, seed, speckle=0.1)
    return layer(img, reduce(plumes), (106, 84, 70), seed, 'plume', 0.25)


def draw_pondweed(p, seed):
    """Pondweed (Potamogeton): a wavy stem with broad clasping leaves."""
    colour = _rgb(p['colour'])
    big = canvas_big()
    d = ImageDraw.Draw(big)
    n, height, sway, key = p['n'], p['height'], p['sway'], p['key']
    for i in range(n):
        x0 = 128 + (i - (n - 1) / 2) * 26 + 3 * signed(key, 'x', i)
        hi = height * (0.8 + 0.2 * unit(key, 'h', i))
        phase = 2 * math.pi * unit(key, 'ph', i)
        line = []
        for m in range(41):
            t = m / 40
            line.append((x0 + sway * t * math.sin(3.2 * t + phase)
                         + p['lean'] * hi * 0.25 * t * t,
                         FLOOR - hi * t))
        _stroke(d, line, 2.6, 1.4)
        leaves = 5 + int(hi / 40)
        for j in range(leaves):
            t = 0.18 + 0.8 * j / leaves
            k = int(t * 40)
            side = 1 if j % 2 else -1
            ang = -math.pi / 2 + side * (0.95 - 0.3 * t)
            size = 18 + 8 * (1 - abs(t - 0.5)) + 4 * unit(key, 's', i, j)
            _leaf(d, line[k], ang, size, 6.5 + 2 * unit(key, 'w', i, j))
    return paint(reduce(big), colour, seed, speckle=0.12)


def plant_pool(thing):
    row = register_row(thing)
    pool = []
    if thing == 'trostnik':
        for st in ('wall', 'sparse', 'broken'):
            counts = {'wall': (8, 7, 6), 'sparse': (3, 4, 2),
                      'broken': (5, 6, 4)}[st]
            for height in (212, 176, 144, 116):
                for lean in (0.0, 0.35, -0.3):
                    for n in counts:
                        pool.append({'thing': thing, 'state': st, 'n': n,
                                     'height': height, 'lean': lean,
                                     'key': f'{thing}:{st}:{n}:{height}:'
                                            f'{lean}',
                                     'colour': row['colour']})
    else:
        for st in ('dense', 'sparse', 'swaying'):
            counts = {'dense': (3, 2), 'sparse': (1, 2),
                      'swaying': (1, 2)}[st]
            sway = {'dense': 8, 'sparse': 10, 'swaying': 24}[st]
            for height in (214, 180, 150, 122):
                for lean in (0.0, 0.4, -0.4):
                    for n in counts:
                        pool.append({'thing': thing, 'state': st, 'n': n,
                                     'height': height, 'lean': lean,
                                     'sway': sway,
                                     'key': f'{thing}:{st}:{n}:{height}:'
                                            f'{lean}',
                                     'colour': row['colour']})
    return pool


# --- Sunken wood and pottery: timber beam, khum jar (DEF-059) --------------

def draw_beam(p, seed):
    """A squared timber beam of a drowned building, lying on the floor."""
    colour = _rgb(p['colour'])
    big = canvas_big()
    d = ImageDraw.Draw(big)
    L, T, key = p['length'], p['thick'], p['key']
    x0, x1 = 128 - L / 2, 128 + L / 2
    top, bot = FLOOR - T, FLOOR
    # A waterlogged timber is never a clean box: the arrises are worn
    # round, the top face undulates where the adze left it, and the
    # log it was hewn from tapers toward one end.
    cham = T * 0.18
    taper = T * 0.12
    left = [(x0 + cham, bot), (x0, bot - cham), (x0, top + taper + cham),
            (x0 + cham, top + taper)]
    right = [(x1 - cham, top), (x1, top + cham), (x1, bot - cham),
             (x1 - cham, bot)]
    if p['end'] == 'broken':
        right = [(x1 - 12 * unit(key, 'e', i) if i % 2 else x1,
                  top + T * i / 6) for i in range(7)]
    elif p['end'] == 'rotted':
        right = [(x1 - T * 0.5 + T * 0.5 * math.sin(math.pi * i / 8)
                  - 3 * unit(key, 'r', i), top + T * i / 8)
                 for i in range(9)]
    bite = 0.22 if p['state'] == 'rotten' else 0.05
    edge = []
    for i in range(1, 12):
        # Rot eats the upper edge in shallow bites; a sound beam only
        # shows the adze marks.
        x = x0 + L * i / 12
        depth = taper * (1 - i / 12) + T * bite * unit(key, 'bite', i)
        edge.append((x, top + depth))
    outline = left + edge + right
    d.polygon(_pts(outline), fill=255)
    if p['state'] == 'joint':
        # A mortise cut into the top face: the beam was part of a house.
        mx = x0 + L * (0.3 + 0.1 * unit(key, 'm'))
        d.rectangle([mx * SS, top * SS, (mx + T * 0.9) * SS,
                     (top + T * 0.42) * SS], fill=0)
    if p['state'] == 'split':
        # Broken in two where the beam lay across a stone: the pieces
        # rest end to end with a ragged gap between them.
        gx = x0 + L * (0.45 + 0.15 * unit(key, 'gap'))
        gap = [(gx + 6 * signed(key, 'gx', i) + (5 if i % 2 else -5),
                top - 2 + (T + 4) * i / 6) for i in range(7)]
        d.polygon(_pts(gap + [(x + 9, y) for x, y in reversed(gap)]),
                  fill=0)
    if p['state'] == 'rotten':
        for i in range(3):
            cx = x0 + L * (0.2 + 0.28 * i) + 6 * signed(key, 'hole', i)
            cy = top + T * (0.45 + 0.15 * signed(key, 'hy', i))
            r = T * (0.08 + 0.05 * unit(key, 'hr', i))
            d.ellipse([(cx - r) * SS, (cy - r) * SS, (cx + r) * SS,
                       (cy + r) * SS], fill=0)
    alpha = reduce(big)
    # Grain along the length of the timber, deterministic.
    grain = Image.new('L', alpha.size, 0)
    dg = ImageDraw.Draw(grain)
    for i in range(int(T / 3)):
        y = top + 3 + i * 3 + 1.2 * signed(key, 'g', i)
        pts = [(x0 + L * k / 16, y + 1.0 * math.sin(k * 0.9 + i))
               for k in range(17)]
        dg.line(pts, fill=58, width=1)
    if p['state'] == 'propped':
        # One end came to rest on a stone of the floor: the beam lies
        # at a slant, the stone under its raised end.
        ang = -(7 + 4 * unit(key, 'tilt'))
        alpha = alpha.rotate(ang, Image.BICUBIC, center=(x1, FLOOR))
        grain = grain.rotate(ang, Image.BICUBIC, center=(x1, FLOOR))
        low = max(y for y in range(CANVAS)
                  if alpha.getpixel((int(x0 + T), y)) > 16) \
            if alpha.getbbox() else FLOOR
        sw = max(18.0, (FLOOR - low) * 1.9)
        bigR = canvas_big()
        ImageDraw.Draw(bigR).polygon(_pts(stone_outline(
            x0 + T, FLOOR, sw, max(10.0, FLOOR - low + 2), 'rounded',
            key + ':prop')), fill=255)
        stone = reduce(bigR)
        img = paint(stone, _rgb(register_row('boulder')['colour']),
                    seed + ':prop', speckle=0.14)
        img = Image.alpha_composite(
            img, paint(alpha, colour, seed, grain=grain, speckle=0.12))
    else:
        img = paint(alpha, colour, seed, grain=grain, speckle=0.12)
    if p['state'] == 'silt':
        bigS = canvas_big()
        ImageDraw.Draw(bigS).polygon(_pts(
            [(x0 - 14, FLOOR + 2), (x0 + L * 0.25, FLOOR - T * 0.55),
             (x0 + L * 0.7, FLOOR - T * 0.45), (x1 + 16, FLOOR + 2)]),
            fill=255)
        img = layer(img, reduce(bigS), _rgb(SILT), seed, 'silt', 0.1)
    return img


def beam_pool(thing):
    row = register_row(thing)
    pool = []
    for st in ('whole', 'joint', 'rotten', 'silt', 'split', 'propped'):
        for L in (236, 204, 172, 140, 112, 88, 68):
            for T in (56, 44, 34, 26, 19, 14):
                if not 3.0 <= L / T <= 8.0:
                    continue
                for end in ('sawn', 'broken', 'rotted'):
                    pool.append({'thing': thing, 'state': st, 'length': L,
                                 'thick': T, 'end': end,
                                 'key': f'{thing}:{st}:{L}:{T}:{end}',
                                 'colour': row['colour']})
    return pool


def jar_profile(h, belly, neck, rim):
    """Half-profile of a khum from the foot up: (y from floor, radius)."""
    foot = belly * 0.42
    pts = []
    for i in range(33):
        t = i / 32
        if t < 0.62:
            s = t / 0.62
            r = foot + (belly - foot) * math.sin(s * math.pi / 2) ** 0.7
        elif t < 0.86:
            s = (t - 0.62) / 0.24
            r = belly + (neck - belly) * (1 - math.cos(s * math.pi)) / 2
        else:
            r = neck + (rim - neck) * ((t - 0.86) / 0.14) ** 2
        pts.append((t * h, r))
    return pts


def draw_jar(p, seed):
    """A khum, the big storage jar of the drowned settlements."""
    colour = _rgb(p['colour'])
    big = canvas_big()
    d = ImageDraw.Draw(big)
    h, key = p['height'], p['key']
    prof = jar_profile(h, p['belly'], p['neck'], p['neck'] * 1.25)
    if p['state'] == 'broken':
        # The neck and a shoulder are gone along a jagged break line.
        keep = int(len(prof) * (0.66 + 0.08 * unit(key, 'k')))
        prof = prof[:keep]
    right = [(128 + r, FLOOR - y) for y, r in prof]
    left = [(128 - r, FLOOR - y) for y, r in reversed(prof)]
    if p['state'] == 'broken':
        top_y = FLOOR - prof[-1][0]
        r = prof[-1][1]
        jag = [(128 + r - 2 * r * i / 8,
                top_y + (8 if i % 2 else 0) + 6 * unit(key, 'j', i))
               for i in range(9)]
        outline = right + jag + left
    else:
        outline = right + left
    if p['state'] == 'tilted':
        # Leaning in the sand where the floor gave way under it.  Laid
        # fully on its side it read as a fish on the contact sheet (the
        # neck and rim looked like a tail), so it only leans.
        ang = 0.3 if unit(key, 'roll') < 0.5 else -0.3
        c, s = math.cos(ang), math.sin(ang)
        pivot = (128, FLOOR - h / 2)
        rot = [(pivot[0] + (x - pivot[0]) * c - (y - pivot[1]) * s,
                pivot[1] + (x - pivot[0]) * s + (y - pivot[1]) * c)
               for x, y in outline]
        low = max(y for _, y in rot)
        outline = [(x, y + FLOOR - low) for x, y in rot]
    d.polygon(_pts(outline), fill=255)
    alpha = reduce(big)
    # Throwing rings of the potter's wheel, faint, across the body.
    grain = Image.new('L', alpha.size, 0)
    if p['state'] != 'tilted':
        dg = ImageDraw.Draw(grain)
        for i in range(int(h / 9)):
            y = FLOOR - 6 - i * 9
            dg.line([(0, y), (CANVAS, y)], fill=16, width=1)
    img = paint(alpha, colour, seed, grain=grain, speckle=0.12)
    if p['state'] == 'broken':
        # The dark inside shows through the open mouth or the break.
        bigM = canvas_big()
        if p['state'] == 'broken':
            top_y = FLOOR - prof[-1][0]
            r = prof[-1][1] * 0.8
            ImageDraw.Draw(bigM).ellipse(
                [(128 - r) * SS, (top_y - 2) * SS, (128 + r) * SS,
                 (top_y + 12) * SS], fill=255)
        mouth = ImageChops.multiply(reduce(bigM), alpha)
        img = layer(img, mouth, (40, 30, 24), seed, 'mouth', 0.05)
    if p['state'] in ('buried', 'tilted'):
        bigS = canvas_big()
        mw = p['belly'] * 1.9
        mh = h * (0.2 if p['state'] == 'buried' else 0.1)
        ImageDraw.Draw(bigS).ellipse(
            [(128 - mw) * SS, (FLOOR - mh) * SS, (128 + mw) * SS,
             (FLOOR + mh) * SS], fill=255)
        img = layer(img, reduce(bigS), _rgb(SAND), seed, 'sand', 0.12)
    return img


def jar_pool(thing):
    row = register_row(thing)
    pool = []
    for st in ('whole', 'buried', 'broken', 'tilted'):
        for h in (212, 188, 160, 136, 112, 92):
            for belly_k in (0.36, 0.28, 0.44):
                for neck_k in (0.42, 0.55):
                    # A squat khum tilted on the sheet read as a jug
                    # with a spout; only slender ones are drawn leaning.
                    if st == 'tilted' and belly_k > 0.4:
                        continue
                    belly = h * belly_k
                    pool.append({'thing': thing, 'state': st, 'height': h,
                                 'belly': round(belly, 1),
                                 'neck': round(belly * neck_k, 1),
                                 'key': f'{thing}:{st}:{h}:{belly_k}:'
                                        f'{neck_k}',
                                 'colour': row['colour']})
    return pool


# --- The kits ------------------------------------------------------------

# slot -> things; each thing -> (pool, drawer).  The things are rows of
# the lake register; the slot's real-object profile checks each drawing.
KITS = {
    'DEF-057': ('boulder', 'quartz'),
    'DEF-058': ('trostnik', 'rdest'),
    'DEF-059': ('balka', 'khum'),
}
DRAW = {
    'boulder': (stone_pool, draw_stone),
    'quartz': (stone_pool, draw_pebble),
    'trostnik': (plant_pool, draw_reeds),
    'rdest': (plant_pool, draw_pondweed),
    'balka': (beam_pool, draw_beam),
    'khum': (jar_pool, draw_jar),
}


def distance(a, b, fa=None, fb=None):
    """Shape distance of two alpha masks, form.shape_delta's formula.

    |A xor B| / |A or B|, with XOR pixels inside both filled outlines
    weighted INTERIOR_WEIGHT (TABOO 0.3 rule 16).  Both filled outlines
    are given, so the distance is symmetric and each fill is made once.
    """
    union = area(ImageChops.lighter(a, b))
    if not union:
        return 0.0
    xor = ImageChops.difference(a, b)
    fa = fa or fill_holes(a)
    fb = fb or fill_holes(b)
    interior = area(ImageChops.multiply(xor, ImageChops.multiply(fa, fb)))
    return (area(xor) - interior + INTERIOR_WEIGHT * interior) / union


def near_enough(a, b, threshold):
    """True when two masks are surely closer than the threshold.

    Plain 1 - IoU is an upper bound of the weighted distance and needs
    no flood fill, so most close pairs are settled cheaply.
    """
    return iou_delta(a, b) < threshold


def _round_robin(pool):
    """Interleave the pool by state so every real state gets a turn."""
    by_state = {}
    for p in pool:
        by_state.setdefault(p['state'], []).append(p)
    lists = list(by_state.values())
    out = []
    for i in range(max(len(x) for x in lists)):
        out += [x[i] for x in lists if i < len(x)]
    return out


def build(slot, thing, threshold=THRESHOLD):
    """Draw the pool of a thing and choose twelve; nothing is written."""
    pool_fn, draw = DRAW[thing]
    seed = seed_of(thing)
    oid = seed[:10]
    row = register_row(thing)
    pool = pool_fn(thing)
    fitting, refused = [], {}
    chosen = []
    for p in _round_robin(pool):
        if len(chosen) == KIT_SIZE:
            break
        img = draw(p, seed)
        mask = alpha_mask(img)
        ok, stats = reference.fits(slot, mask)
        if not ok:
            refused['unlike-real-object'] = \
                refused.get('unlike-real-object', 0) + 1
            continue
        fitting.append(p['key'])
        if any(near_enough(mask, c['mask'], threshold) for c in chosen):
            refused['too-close-to-a-sibling'] = \
                refused.get('too-close-to-a-sibling', 0) + 1
            continue
        filled = fill_holes(mask)
        near = min((distance(mask, c['mask'], filled, c['filled'])
                    for c in chosen), default=1.0)
        box = hitbox(mask)
        if near < threshold:
            refused['too-close-to-a-sibling'] = \
                refused.get('too-close-to-a-sibling', 0) + 1
            continue
        if hitbox_key(box) in {hitbox_key(c['hitbox']) for c in chosen}:
            refused['same-hitbox'] = refused.get('same-hitbox', 0) + 1
            continue
        chosen.append({'params': p, 'img': img, 'mask': mask,
                       'filled': filled, 'hitbox': box, 'stats': stats})
    prefix = f'own_{thing}_{oid}'
    images, variants = {}, []
    for i, c in enumerate(chosen, 1):
        near = min((distance(c['mask'], o['mask'], c['filled'],
                             o['filled'])
                    for o in chosen if o is not c), default=0.0)
        slot_v = f'v{i:02d}'
        name = f'{prefix}_{slot_v}.png'
        images[name] = c['img']
        params = {k: v for k, v in c['params'].items()
                  if k not in ('thing', 'colour')}
        variants.append({
            'slot': slot_v, 'file': name, 'state': params['state'],
            'params': params,
            'shape_change': round(near, 4),
            'shape_basis': 'nearest-sibling',
            'fits_reference': True, 'reference_stats': c['stats'],
            'area': area(c['mask']), 'hitbox': c['hitbox'],
            'analytics_id': f'ludus.variant.neutral.{thing}.{oid}.{slot_v}',
        })
    record = {
        'name': prefix, 'id': oid, 'seed': seed, 'slot': slot,
        'thing': thing, 'register': row,
        'origin': 'own-procedural-drawing', 'method': 'own-procedural',
        'raw_material': False,
        'source': {'repo': 'ludus (own drawing)', 'path': HERE,
                   'commit': REVISION},
        'repo': 'ludus (own drawing)', 'path': HERE, 'commit': REVISION,
        'license': 'project (own drawing, no third-party material)',
        'license_file': None,
        'threshold': threshold, 'shape_basis': 'nearest-sibling',
        'reference_profile': {k: v for k, v in
                              reference.PROFILES[slot].items()},
        'pool': {'size': len(pool), 'fitting_seen': len(fitting),
                 'refused': refused, 'chosen': len(chosen)},
        'constitution': 'FORM: a real thing of the lake register in its '
                        'real states -> ACTION: the player reads the '
                        'floor by it -> GOAL: reading a place by its real '
                        'traces (TABOO 0.03 rule 3)',
        'variants': variants,
        'status': 'ok' if len(variants) == KIT_SIZE else 'shortfall',
        'shortfall': KIT_SIZE - len(variants),
        'shape_change': min((v['shape_change'] for v in variants),
                            default=0.0),
    }
    return record, images


def write_kit(out, record, images):
    out.mkdir(parents=True, exist_ok=True)
    for name, img in images.items():
        img.save(out / name, optimize=True)
    (out / f'{record["name"]}.json').write_text(
        json.dumps(record, ensure_ascii=False, indent=2) + '\n', 'utf-8')


def contact_sheet(kits, out_path, cell=96):
    """All kits on the five biome backgrounds (TABOO 0.3 rule 59)."""
    rows = []
    for record, images in kits:
        cells = [(v['slot'], images[v['file']],
                  f'{v["state"][:6]} {v["shape_change"]:.0%}')
                 for v in record['variants']]
        label = (f'{record["slot"]} {record["name"]} '
                 f'{record["register"]["en"]} '
                 f'{record["status"]} {len(cells)}/12, pool '
                 f'{record["pool"]["size"]}')
        first = cells[0][1] if cells else None
        rows.append((label, first, cells))
    return neutral_variants.contact_sheet(rows, out_path, cell)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', default='build/d6')
    parser.add_argument('--sheet', default='')
    parser.add_argument('--ship', default='',
                        help='derived root; kits with 12/12 are copied '
                             'to <ship>/<slot>/')
    parser.add_argument('--godot', default='',
                        help='second derived root for the headset copy')
    parser.add_argument('--only', default='', help='comma-separated things')
    args = parser.parse_args(argv)
    out = Path(args.out)
    shutil.rmtree(out, ignore_errors=True)
    kits = []
    wanted = set(filter(None, args.only.split(',')))
    for slot, things in KITS.items():
        for thing in things:
            if wanted and thing not in wanted:
                continue
            record, images = build(slot, thing)
            write_kit(out / slot, record, images)
            kits.append((record, images))
            shapes = [v['shape_change'] for v in record['variants']]
            print(f'{slot} {record["name"]}: {record["status"]} '
                  f'{len(shapes)}/12, pool {record["pool"]}, nearest '
                  f'sibling {min(shapes, default=0):.1%}..'
                  f'{max(shapes, default=0):.1%}')
    if args.sheet:
        print('sheet', contact_sheet(kits, args.sheet))
    for root in filter(None, (args.ship, args.godot)):
        for record, _ in kits:
            if record['status'] != 'ok':
                continue
            dest = Path(root) / record['slot']
            dest.mkdir(parents=True, exist_ok=True)
            for f in (out / record['slot']).glob(f'{record["name"]}*'):
                shutil.copy2(f, dest / f.name)
            print(f'shipped {record["name"]} to {dest}')
    return 0 if all(r['status'] == 'ok' for r, _ in kits) else 1


if __name__ == '__main__':
    sys.exit(main())
