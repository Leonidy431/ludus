"""Our own procedural drawing of the fish of Issyk-Kul (DEF-056).

Why this exists.  The raw passes over the 99 repositories never filled
the fish slot: the first took a jellyfish, a fiend and pikemen for
"pike", and the fish-like sprites that came later failed the
real-object check (reference.PROFILES['DEF-056']).  As with the
neutral things of the floor (D6, neutral_procedural.py), the slot moves
to the project's own drawing: nothing here comes from a third-party
repository, so there is nothing to reshape by 35 %, and the register
row says so.

Constitution: FORM (a real species of the lake: its genus shape, its
length, its colour, its barbels and fins, from the lake register and
docs/ISSYK_KUL_FISH.md) -> ACTION (the operator of the ROV tells the
species apart through the camera, logs it and, for the endemics,
releases it) -> GOAL (to know the living lake by its real creatures;
the water keeps its memory in real things, TABOO 0.03 rule 6).

How a kit is made (TABOO 0.07, the same steps as D6):
  1. Register.  Each species is a row of scripts/lake/lake_objects.py
     and of public/ludus/data/issyk-kul-fish.json; its colour and its
     real states (single, school, pair, feeding, at the bottom ...)
     come from there.  The genus shape (depth of the body, place and
     length of the dorsal fin, barbels, adipose fin, tail) is written
     in MORPHOLOGY below from general ichthyology; the proportions are
     approximate and are to be checked by an ichthyologist together
     with the species list (docs/ISSYK_KUL_FISH.md, section 0).
  2. Honest pool.  Every real state of the species gives the forms a
     fish takes in it (FORMS): body flexion of several strengths,
     fins raised or folded, the tail fanned, the mouth open, young
     proportions, the layout of a pair.  Size (age), height in the
     water and tilt are where the game puts a fish, so they are
     engine parameters (ENGINE), never variants.
  3. Real-object profile.  A drawing whose alpha silhouette does not
     fit reference.PROFILES['DEF-056'] (aspect 1.8..6.5, fill) is
     refused.
  4. Diversity.  Every pair of chosen variants differs by at least
     35 % of |A xor B| / |A or B|, measured on silhouettes cropped to
     their box and fitted to NORM_BOX, so a moved or resized fish
     counts 0 (the first kits of 2026-09-30 scored a fish moved down
     the canvas about 100 % against itself).  Hitboxes differ.
  5. The meta-json records shape_change as the distance to the nearest
     sibling ("shape_basis": "nearest-sibling-normalised").  A kit
     short of twelve is reported with its real count and not shipped
     (TABOO 0.1; TABOO 0.07 item 2: the count is not padded).

Every fish faces left.  A variant is never a mirror image (TABOO 0.3
rule 35); the game turns the sprite, the kit does not.  Nothing is
random: jitter is read from sha1 of fixed labels.

Usage:
    python3 scripts/raw_assets/fish_procedural.py --out build/fish \
        --sheet docs/audit/2026-09-30/fish-own-DEF-056-contact.png \
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

from form import (CANVAS, alpha_mask, area,  # noqa: E402
                  fill_holes, hitbox, hitbox_key)
import neutral_procedural as npd  # noqa: E402
import reference  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
FISH_DATA = ROOT / 'public' / 'ludus' / 'data' / 'issyk-kul-fish.json'
SLOT = 'DEF-056'
THRESHOLD = npd.THRESHOLD
KIT_SIZE = npd.KIT_SIZE
SS = npd.SS
# Raise whenever a drawing function or a pool changes.
REVISION = 'fish-drawing-r2'
# Nearest sibling, measured on silhouettes normalised for place and
# scale (normalised below).
SHAPE_BASIS = 'nearest-sibling-normalised'
HERE = 'scripts/raw_assets/fish_procedural.py'

# Genus shapes, side view, as shares of the body length (snout to the
# base of the tail).  depth: deepest body; top: share of the depth above
# the midline (a humped back is > 0.5); peak: where the body is
# deepest; head: bluntness of the head (smaller is blunter); stalk:
# depth of the tail stalk as a share of the deepest body; tail: tail
# length as a share of the whole length; fork: depth of the fork (1 is
# a deep swallow tail, 0 a straight edge); dorsal: (start, end,
# height, kind); anal: (start, end, height); adipose: place or None;
# barbels: pairs seen from the side; marks: the pattern of the skin.
# Sources for the genus shapes: docs/ISSYK_KUL_FISH.md; approximate,
# to be checked by an ichthyologist before release.
MORPHOLOGY = {
    'chebachok': {  # Leuciscus: deep-ish, compressed, dark back.
        'depth': 0.3, 'top': 0.56, 'peak': 0.36, 'head': 0.55,
        'stalk': 0.3, 'tail': 0.2, 'fork': 0.62,
        'dorsal': (0.44, 0.56, 0.17, 'short'), 'anal': (0.66, 0.79, 0.09),
        'adipose': None, 'barbels': 0, 'marks': 'silver', 'back': 0.3,
        'eye': 0.08, 'mouth': 'terminal', 'fins': (150, 150, 140)},
    'marinka': {  # Schizothorax: long pointed head, 2 long barbels.
        'depth': 0.21, 'top': 0.52, 'peak': 0.44, 'head': 0.9,
        'stalk': 0.38, 'tail': 0.18, 'fork': 0.55,
        'dorsal': (0.4, 0.52, 0.15, 'short'), 'anal': (0.74, 0.84, 0.07),
        'adipose': None, 'barbels': 2, 'barbel_len': 1.7,
        'marks': 'plain', 'gill': 0.24,
        'eye': 0.05, 'mouth': 'under', 'fins': (110, 104, 80)},
    'osman': {  # Gymnodiptychus: naked, spotted, blunt broad head,
        # one short pair of barbels.
        'depth': 0.2, 'top': 0.5, 'peak': 0.3, 'head': 0.4,
        'stalk': 0.4, 'tail': 0.17, 'fork': 0.4,
        'dorsal': (0.42, 0.53, 0.13, 'short'), 'anal': (0.74, 0.84, 0.07),
        'adipose': None, 'barbels': 1, 'barbel_len': 0.7,
        'marks': 'spots', 'gill': 0.18,
        'eye': 0.05, 'mouth': 'under', 'fins': (96, 92, 74)},
    'gubach': {  # Triplophysa: a stone loach, flat belly, 3 barbels.
        'depth': 0.16, 'top': 0.62, 'peak': 0.4, 'head': 0.55,
        'stalk': 0.55, 'tail': 0.15, 'fork': 0.12,
        'dorsal': (0.45, 0.56, 0.12, 'short'), 'anal': (0.74, 0.83, 0.06),
        'adipose': None, 'barbels': 3, 'marks': 'blotches',
        'eye': 0.045, 'mouth': 'under', 'fins': (120, 110, 88)},
    'ishkhan': {  # Salmo: a trout, spotted back, adipose fin.
        'depth': 0.23, 'top': 0.5, 'peak': 0.4, 'head': 0.72,
        'stalk': 0.38, 'tail': 0.17, 'fork': 0.22,
        'dorsal': (0.4, 0.52, 0.14, 'short'), 'anal': (0.72, 0.82, 0.07),
        'adipose': 0.82, 'barbels': 0, 'marks': 'trout',
        'eye': 0.05, 'mouth': 'terminal', 'fins': (120, 116, 106)},
    'sudak': {  # Sander: long, barred, two dorsal fins, first spiny.
        'depth': 0.2, 'top': 0.5, 'peak': 0.38, 'head': 0.85,
        'stalk': 0.34, 'tail': 0.16, 'fork': 0.35,
        'dorsal': (0.3, 0.76, 0.15, 'double'), 'anal': (0.7, 0.82, 0.07),
        'adipose': None, 'barbels': 0, 'marks': 'bars',
        'eye': 0.06, 'mouth': 'terminal', 'fins': (110, 112, 96)},
    'leshch': {  # Abramis: deep, flat, high dorsal, long anal fin.
        'depth': 0.36, 'top': 0.6, 'peak': 0.42, 'head': 0.5,
        'stalk': 0.24, 'tail': 0.2, 'fork': 0.7,
        'dorsal': (0.5, 0.6, 0.2, 'short'), 'anal': (0.56, 0.9, 0.08),
        'adipose': None, 'barbels': 0, 'marks': 'bronze',
        'eye': 0.06, 'mouth': 'under', 'fins': (96, 90, 76)},
    'sazan': {  # Cyprinus: golden, big scales, long dorsal, 2 barbels.
        'depth': 0.3, 'top': 0.56, 'peak': 0.4, 'head': 0.6,
        'stalk': 0.36, 'tail': 0.19, 'fork': 0.5,
        'dorsal': (0.4, 0.8, 0.15, 'long'), 'anal': (0.72, 0.82, 0.08),
        'adipose': None, 'barbels': 2, 'marks': 'scales',
        'eye': 0.05, 'mouth': 'terminal', 'fins': (150, 104, 70)},
    'sig': {  # Coregonus: slim, small pointed head, big adipose fin,
        # subterminal mouth, pale back.
        'depth': 0.22, 'top': 0.54, 'peak': 0.48, 'head': 0.95,
        'stalk': 0.3, 'tail': 0.2, 'fork': 0.7,
        'dorsal': (0.4, 0.52, 0.15, 'short'), 'anal': (0.7, 0.8, 0.07),
        'adipose': 0.8, 'adipose_h': 0.085, 'barbels': 0,
        'marks': 'silver', 'back': 0.62, 'gill': 0.15,
        'eye': 0.045, 'mouth': 'under', 'fins': (140, 146, 146)},
}

# Register state (lake_objects.ITEMS, Russian) -> pose of the drawing.
POSE = {
    'одиночка': 'single', 'стайка': 'school', 'молодь': 'young',
    'пара': 'pair', 'кормится': 'feeding', 'у дна': 'bottom',
    'на песке': 'bottom', 'в гальке': 'bottom', 'замер': 'bottom',
    'под камнем': 'bottom', 'в засаде': 'bottom',
    'у поверхности': 'rising', 'охотится': 'hunting',
    'на границе слоя': 'single', 'в глубине': 'single',
}


def fish_row(species):
    for f in json.loads(FISH_DATA.read_text('utf-8'))['fish']:
        if f['id'] == species:
            return f
    raise KeyError(species)


def _mix(a, b, k):
    return tuple(int(x + (y - x) * k) for x, y in zip(a, b))


# --- The outline -----------------------------------------------------------

def body_profile(m, s):
    """Depth of the body at s (0 snout .. 1 base of the tail), 0..1."""
    peak, head, stalk = m['peak'], m['head'], m['stalk']
    if s <= peak:
        return 0.04 + 0.96 * math.sin(math.pi / 2 * s / peak) ** head
    k = (s - peak) / (1 - peak)
    return stalk + (1 - stalk) * (1 + math.cos(math.pi * k)) / 2


class Fish:
    """One fish, horizontal, snout to the left, centred on (cx, cy).

    form (see FORMS) changes the fish itself, not where it stands: fins
    raised or folded, the tail fanned or closed, the mouth open, young
    proportions.  The bend of the body is applied after drawing (bend).
    """

    def __init__(self, m, length, cx, cy, form=None):
        form = form or {}
        self.fins_k = form.get('fins', 1.0)
        self.tail_k = form.get('tail', 1.0)
        self.mouth_open = form.get('mouth', False)
        if form.get('young'):
            # Young fish: a bigger head and eye, a shallower body.
            m = dict(m, depth=m['depth'] * 0.82, eye=m['eye'] * 1.6,
                     peak=max(0.3, m['peak'] - 0.06),
                     head=m['head'] * 0.8)
        self.m = m
        self.L = length
        self.tail_len = length * m['tail']
        self.Lb = length - self.tail_len
        self.x0 = cx - length / 2
        self.cy = cy
        self.D = m['depth'] * self.Lb

    def x(self, s):
        return self.x0 + s * self.Lb

    def upper(self, s):
        return self.cy - self.D * body_profile(self.m, s) * self.m['top']

    def lower(self, s):
        m = self.m
        f = body_profile(m, s)
        if m['marks'] == 'blotches':
            # A loach lies on a flat belly: the lower line is fuller.
            f = f ** 0.6
        return self.cy + self.D * f * (1 - m['top'])

    def body(self, n=48):
        ss = [i / n for i in range(n + 1)]
        top = [(self.x(s), self.upper(s)) for s in ss]
        bot = [(self.x(s), self.lower(s)) for s in reversed(ss)]
        return top + bot

    def tail(self):
        m = self.m
        xb = self.x(1.0)
        yt, yb = self.upper(1.0), self.lower(1.0)
        mid = (yt + yb) / 2
        span = self.D * (1.05 if m['fork'] > 0.3 else 0.85) * self.tail_k
        xe = xb + self.tail_len
        notch = xb + self.tail_len * (1 - 0.8 * m['fork'])
        lower_k = 1.12 if m['marks'] == 'bronze' else 1.0
        up = (xe, mid - span / 2)
        lo = (xe - 2 * (1 - m['fork']), mid + span / 2 * lower_k)
        pts = [(xb - 2, yt), (xb + self.tail_len * 0.45,
                              mid - span * 0.3), up]
        if m['fork'] > 0.15:
            pts += [(notch + (xe - notch) * 0.35, mid - span * 0.16),
                    (notch, mid),
                    (notch + (xe - notch) * 0.35, mid + span * 0.16)]
        else:
            # A loach tail: a straight, slightly rounded edge.
            pts += [(xe + 1.5, mid - span * 0.2), (xe + 2, mid),
                    (xe + 1.5, mid + span * 0.2)]
        pts += [lo, (xb + self.tail_len * 0.45, mid + span * 0.3),
                (xb - 2, yb)]
        return pts

    def fin_up(self, s0, s1, h, kind='short'):
        """A dorsal fin standing on the back from s0 to s1."""
        H = h * self.Lb * self.fins_k
        base = [(self.x(s), self.upper(s) + 1)
                for s in (s0 + (s1 - s0) * i / 8 for i in range(9))]
        if kind == 'long':
            # A carp: a tall leading ray, then a long low fin.
            top = [(self.x(s0 + (s1 - s0) * 0.08), self.upper(s0) - H),
                   (self.x(s0 + (s1 - s0) * 0.3),
                    self.upper(s0 + (s1 - s0) * 0.3) - H * 0.42),
                   (self.x(s1), self.upper(s1) - H * 0.25)]
        else:
            top = [(self.x(s0 + (s1 - s0) * 0.12), self.upper(s0) - H),
                   (self.x(s0 + (s1 - s0) * 0.55),
                    self.upper(s1) - H * 0.45),
                   (self.x(s1 + (s1 - s0) * 0.12), self.upper(s1) - 1)]
        return [base[0]] + top + list(reversed(base))[:-1]

    def spiny(self, s0, s1, h):
        """The spiny first dorsal fin of a zander: a saw of rays."""
        H = h * self.Lb * self.fins_k
        pts = [(self.x(s0), self.upper(s0) + 1)]
        n = 12
        for i in range(n + 1):
            s = s0 + (s1 - s0) * i / n
            k = 1 - 0.35 * i / n
            hi = H * k if i % 2 == 0 else H * k * 0.72
            pts.append((self.x(s), self.upper(s) - hi))
        pts.append((self.x(s1), self.upper(s1) + 1))
        return pts

    def fin_down(self, s0, s1, h):
        """An anal or pelvic fin hanging under the belly."""
        H = h * self.Lb * self.fins_k
        # Fins lie swept back along the body, not hanging straight.
        return [(self.x(s0), self.lower(s0) - 1),
                (self.x(s0 + (s1 - s0) * 0.5),
                 self.lower(s0 + (s1 - s0) * 0.5) + H),
                (self.x(s1 + (s1 - s0) * 0.35), self.lower(s1) + H * 0.6),
                (self.x(s1), self.lower(s1) - 1)]

    def adipose(self, s):
        # A whitefish carries a bigger adipose fin than the trout; it is
        # the cue that tells it from the dace at sprite size.
        H = self.m.get('adipose_h', 0.045) * self.Lb
        w = 0.05 if H > 0.05 * self.Lb else 0.04
        return [(self.x(s - 0.03), self.upper(s - 0.03) + 1),
                (self.x(s), self.upper(s) - H),
                (self.x(s + w), self.upper(s + w) - H * 0.6),
                (self.x(s + w + 0.01), self.upper(s + w + 0.01) + 1)]

    def mouth(self):
        """The open jaw: a wedge cut into the snout, or a protruded
        lower lip for a mouth that opens downwards."""
        y = (self.upper(0.02) + self.lower(0.02)) / 2
        g = self.D * 0.22
        if self.m['mouth'] == 'under':
            y = self.lower(0.03) - g * 0.3
        return [(self.x(0.0) - 2, y - g * 0.55), (self.x(0.085), y),
                (self.x(0.0) - 2, y + g * 0.55)]

    def pectoral(self):
        s0 = 0.2
        H = 0.1 * self.Lb * self.fins_k
        y = self.cy + self.D * 0.18
        return [(self.x(s0), y), (self.x(s0 + 0.13), y + H * 0.45),
                (self.x(s0 + 0.1), y + H * 0.7), (self.x(s0 + 0.02),
                                                  y + H * 0.2)]

    def barbels(self):
        """Lines from the mouth: (from, to) in canvas pixels."""
        out = []
        n = self.m['barbels']
        base_y = self.lower(0.04) - 1
        k = self.m.get('barbel_len', 1.0)
        for i in range(n):
            length = self.D * (0.28 + 0.12 * i) * k
            sx = self.x(0.02 + 0.035 * i)
            out.append(((sx, base_y), (sx + length * 0.45,
                                       base_y + length)))
        return out

    def eye(self):
        s = 0.07 + 0.02 * (self.m['head'] < 0.6)
        # 'eye' is roughly the eye diameter as a share of the body
        # length; at full radius the eye read as a cartoon on the sheet.
        r = max(1.4, self.m['eye'] * self.Lb * 0.6)
        y = self.cy - self.D * body_profile(self.m, s) * \
            self.m['top'] * 0.35
        return self.x(s) + r * 0.6, y, r


# --- Drawing one fish ------------------------------------------------------

def _poly(d, pts):
    d.polygon(npd._pts(pts), fill=255)


def masks(fish):
    """Supersampled body and fin masks of one fish."""
    m = fish.m
    body = npd.canvas_big()
    db = ImageDraw.Draw(body)
    _poly(db, fish.body())
    if fish.mouth_open:
        db.polygon(npd._pts(fish.mouth()), fill=0)
    fins = npd.canvas_big()
    df = ImageDraw.Draw(fins)
    _poly(df, fish.tail())
    s0, s1, h, kind = m['dorsal']
    if kind == 'double':
        split = s0 + (s1 - s0) * 0.48
        _poly(df, fish.spiny(s0, split, h))
        _poly(df, fish.fin_up(split + 0.04, s1, h * 0.85))
    else:
        _poly(df, fish.fin_up(s0, s1, h, kind))
    a0, a1, ah = m['anal']
    _poly(df, fish.fin_down(a0, a1, ah))
    _poly(df, fish.fin_down(0.47, 0.56, ah * 0.8))
    _poly(df, fish.pectoral())
    if m['adipose']:
        _poly(df, fish.adipose(m['adipose']))
    for a, b in fish.barbels():
        df.line(npd._pts([a, b]), fill=255, width=int(1.4 * SS))
    return body, fins


def skin(fish, colour, species):
    """The colour of the body: back, flank, belly and the pattern."""
    m = fish.m
    back = tuple(int(c * m.get('back', 0.5)) for c in colour)
    belly = _mix(colour, (236, 236, 228), 0.6)
    if m['marks'] == 'bronze':
        back = _mix(back, (90, 70, 30), 0.4)
    top = fish.cy - fish.D * m['top']
    bot = fish.cy + fish.D * (1 - m['top'])
    column = Image.new('RGB', (1, CANVAS))
    for y in range(CANVAS):
        k = min(1.0, max(0.0, (y - top) / max(1.0, bot - top)))
        if k < 0.5:
            c = _mix(back, colour, (k / 0.5) ** 0.8)
        else:
            c = _mix(colour, belly, ((k - 0.5) / 0.5) ** 0.9)
        column.putpixel((0, y), c)
    img = column.resize((CANVAS, CANVAS), Image.NEAREST)
    d = ImageDraw.Draw(img)
    key = f'{species}:{fish.L}:{fish.cy}'
    dark = tuple(int(c * 0.42) for c in colour)
    marks = m['marks']
    if marks == 'bars':
        # A zander carries dark bars from the back down the flank.
        for i in range(8):
            s = 0.22 + 0.095 * i
            w = fish.Lb * 0.028
            x = fish.x(s)
            d.polygon([(x - w, fish.upper(s)), (x + w, fish.upper(s)),
                       (x + w * 0.5, fish.cy + fish.D * 0.1),
                       (x - w * 0.7, fish.cy + fish.D * 0.1)], fill=dark)
    if marks in ('spots', 'trout'):
        n = 22 if marks == 'trout' else 16
        for i in range(n):
            s = 0.2 + 0.75 * npd.unit(key, 'sx', i)
            y0, y1 = fish.upper(s), fish.cy + fish.D * 0.12
            y = y0 + (y1 - y0) * (0.15 + 0.85 * npd.unit(key, 'sy', i))
            # The naked osman is known by its big spots at sprite size.
            base = 0.013 if marks == 'spots' else 0.008
            r = max(0.8, fish.Lb * (base + 0.006 * npd.unit(key, 'r', i)))
            x = fish.x(s)
            d.ellipse([x - r, y - r, x + r, y + r], fill=dark)
    if marks == 'blotches':
        for i in range(9):
            s = 0.15 + 0.09 * i
            x = fish.x(s)
            w = fish.Lb * (0.025 + 0.015 * npd.unit(key, 'bw', i))
            y0 = fish.upper(s)
            y1 = fish.cy + fish.D * (0.05 + 0.2 * npd.unit(key, 'bh', i))
            d.ellipse([x - w, y0, x + w, y1], fill=dark)
    if marks in ('scales', 'bronze', 'silver', 'plain', 'trout'):
        # Scales: a faint net of arcs over the flank.
        step = max(3.0, fish.D * (0.16 if marks == 'scales' else 0.1))
        net = tuple(int(c * 0.78) for c in colour)
        row = 0
        y = fish.cy - fish.D * 0.35
        while y < fish.cy + fish.D * 0.4:
            off = step / 2 if row % 2 else 0
            x = fish.x(0.24) + off
            while x < fish.x(0.97):
                d.arc([x - step / 2, y - step / 2, x + step / 2,
                       y + step / 2], 300, 60, fill=net)
                x += step
            y += step * 0.75
            row += 1
    # The lateral line and the gill cover.
    ll = [(fish.x(s), fish.cy - fish.D * 0.12 + fish.D * 0.1 *
           math.sin(math.pi * s)) for s in (0.24 + i * 0.038
                                            for i in range(21))]
    d.line(ll, fill=tuple(int(c * 0.6) for c in colour), width=1)
    sg = m.get('gill', 0.2)
    gx = fish.x(sg)
    d.arc([gx - fish.D * 0.5, fish.upper(sg) + 1, gx,
           fish.lower(sg) - 1], 300, 60,
          fill=tuple(int(c * 0.45) for c in colour), width=1)
    ex, ey, r = fish.eye()
    d.ellipse([ex - r, ey - r, ex + r, ey + r], fill=(214, 206, 170))
    d.ellipse([ex - r * 0.62, ey - r * 0.62, ex + r * 0.62,
               ey + r * 0.62], fill=(16, 14, 12))
    return img


def relief(alpha):
    """Light from the surface over the form, as in npd.paint."""
    h = alpha.filter(ImageFilter.GaussianBlur(4))
    up = ImageChops.offset(h, 0, -3)
    bright = ImageChops.subtract(up, h)
    dark = ImageChops.subtract(h, up)
    shade = Image.new('L', alpha.size, 200)
    shade = ImageChops.add(shade, npd._scale(bright, 2.0))
    shade = ImageChops.subtract(shade, npd._scale(dark, 2.4))
    inner = alpha.filter(ImageFilter.MinFilter(3))
    rim = ImageChops.subtract(alpha, inner)
    return ImageChops.subtract(shade, npd._scale(rim, 0.3))


def bend(img, profile, amp, x0, length):
    """Flex the body: shift each column up or down along the fish.

    A real change of form (TABOO 0.3 rule 15), not a placement: the
    snout, the middle and the tail move against one another, so the
    outline itself changes.  profile(u) gives the shift at u (0 snout,
    1 tip of the tail) as a share of amp * length; positive is down.
    Columns are mapped with an image mesh, so the drawing stays smooth.
    """
    if not amp:
        return img
    step = 2
    mesh = []
    for x in range(0, CANVAS, step):
        def off(xx):
            u = min(1.0, max(0.0, (xx - x0) / length))
            return amp * length * profile(u)
        a, b = off(x), off(x + step)
        mesh.append(((x, 0, x + step, CANVAS),
                     (x, -a, x, CANVAS - a, x + step, CANVAS - b,
                      x + step, -b)))
    return img.transform(img.size, Image.MESH, mesh, Image.BICUBIC)


# Bends of the body seen from the side.  Only curvature: a profile with
# no bend in it would be a tilt or a shift, which the game does itself.
BENDS = {
    'straight': lambda u: 0.0,
    'arch': lambda u: -4 * u * (1 - u),          # back humped, diving
    'bow': lambda u: 4 * u * (1 - u),            # belly bowed, rising
    'wave': lambda u: 0.5 * math.sin(2 * math.pi * u),
    'wave-back': lambda u: -0.5 * math.sin(2 * math.pi * u),
    'head-down': lambda u: (max(0.0, 0.45 - u) / 0.45) ** 2,
    'head-up': lambda u: -(max(0.0, 0.45 - u) / 0.45) ** 2,
    'tail-up': lambda u: -(max(0.0, u - 0.55) / 0.45) ** 2,
    'tail-down': lambda u: (max(0.0, u - 0.55) / 0.45) ** 2,
}


def draw_one(species, length, cx, cy, form=None, fins_colour=None):
    """One fish as an RGBA canvas, flexed by its form."""
    form = form or {}
    m = MORPHOLOGY[species]
    colour = npd._rgb(fish_row(species)['colour'])
    fish = Fish(m, length, cx, cy, form)
    body_big, fins_big = masks(fish)
    body_a = npd.reduce(body_big)
    fins_a = npd.reduce(fins_big)
    fin_rgb = fins_colour or m['fins']
    fin_layer = Image.new('RGB', (CANVAS, CANVAS), fin_rgb)
    rays = ImageDraw.Draw(fin_layer)
    for i in range(0, CANVAS, 3):
        rays.line([(i, 0), (i + 40, CANVAS)],
                  fill=tuple(int(c * 0.82) for c in fin_rgb))
    fins_img = fin_layer.convert('RGBA')
    # Fins are thinner than the body: a little of the water shows.
    fins_img.putalpha(fins_a.point(lambda v: int(v * 0.86)))
    body_rgb = ImageChops.multiply(
        skin(fish, colour, species),
        Image.merge('RGB', [relief(body_a)] * 3))
    body_img = body_rgb.convert('RGBA')
    body_img.putalpha(body_a)
    img = Image.alpha_composite(fins_img, body_img)
    return bend(img, BENDS[form.get('bend', 'straight')],
                form.get('amp', 0.0), fish.x0, fish.L)


# --- Forms and the pool ----------------------------------------------------

# One drawing length for every variant.  Size (age) and height in the
# water are where the game puts a fish, not a new form: they are engine
# parameters (ENGINE) and never a variant of their own.  The first kits
# of 2026-09-30 counted them as variants, and a fish moved down the
# canvas scored about 100 % against itself; a review caught it.
LENGTH = 236
ENGINE = {
    'age_lengths_px': [236, 188, 150, 120, 96],
    'scale_note': 'the game scales a variant to the age class; a size '
                  'is never a variant',
    'rest_on_floor': 'a variant of the state "bottom" is placed by the '
                     'game with its lowest pixel on the floor line',
    'tilt_deg': [-13, 13],
    'facing': 'left; the game turns the sprite, never a mirrored '
              'variant (TABOO 0.3 rule 35)',
}

# Register state -> the forms a fish takes in it.  Each form is a real
# posture: a cruising fish undulates, a rising one bows its belly, a
# feeding one dips its head and opens its mouth, a hunting one throws
# an S and raises its fins, a fish at the bottom spreads its pectoral
# fins on the ground and lifts its tail.  Bends come in several
# strengths (share of the body length the snout or tail is flexed).


def _forms(bends, amps, **extra):
    return [dict(extra, bend=b, amp=a) for b in bends for a in amps]


FORMS = {
    'single': ([{'bend': 'straight', 'amp': 0.0, 'fins': 0.8}]
               + _forms(('wave', 'wave-back'), (0.06, 0.1, 0.15))
               + _forms(('tail-up', 'tail-down'), (0.1, 0.2),
                        tail=1.2)),
    'rising': (_forms(('bow',), (0.07, 0.13, 0.2), fins=1.25)
               + _forms(('head-up',), (0.1, 0.15, 0.2))),
    'feeding': (_forms(('head-down',), (0.1, 0.15, 0.2), mouth=True)
                + _forms(('arch',), (0.07, 0.13, 0.2), mouth=True,
                         fins=1.2)),
    'hunting': _forms(('wave', 'wave-back'), (0.12, 0.2), mouth=True,
                      fins=1.3),
    'bottom': ([{'bend': 'straight', 'amp': 0.0, 'fins': 1.35,
                 'tail': 0.8}]
               + _forms(('tail-up',), (0.06, 0.12), fins=1.35)
               + _forms(('head-up',), (0.06,), fins=1.35)),
    'young': [{'bend': 'straight', 'amp': 0.0, 'young': True},
              {'bend': 'wave', 'amp': 0.08, 'young': True}],
    'pair': [dict(f, layout=lay) for lay in ('above', 'beside', 'cross')
             for f in ({'bend': 'straight', 'amp': 0.0},
                       {'bend': 'wave', 'amp': 0.1})],
    'school': [{'bend': 'straight', 'amp': 0.0}],
}


def draw_pose(p):
    """A variant: one fish in a form, a pair or a small school."""
    sp, pose, form = p['species'], p['pose'], p['form']
    key = p['key']
    if pose not in ('pair', 'school'):
        return draw_one(sp, LENGTH, 128, 128, form)
    img = Image.new('RGBA', (CANVAS, CANVAS), (0, 0, 0, 0))
    if pose == 'pair':
        # Two of a kind; how they overlap is the form of the pair.
        s = LENGTH * 0.62
        lay = form.get('layout', 'above')
        if lay == 'above':
            spots = [(0.9, 128 + s * 0.3, 128 - s * 0.16, form),
                     (1.0, 128 - s * 0.22, 128 + s * 0.1, form)]
        elif lay == 'beside':
            spots = [(0.95, 128 + s * 0.05, 128 - s * 0.12, form),
                     (1.0, 128 - s * 0.05, 128 + s * 0.12,
                      dict(form, bend='wave-back'))]
        else:
            spots = [(0.9, 128 + s * 0.35, 128 - s * 0.05,
                      dict(form, bend='head-down', amp=0.2)),
                     (1.0, 128 - s * 0.3, 128 + s * 0.05,
                      dict(form, bend='head-up', amp=0.2))]
        for k, x, y, f in spots:
            img = Image.alpha_composite(img, draw_one(sp, s * k, x, y, f))
        return img
    n, s = 3, LENGTH * 0.42
    for i in range(n):
        dx = (i - (n - 1) / 2) * s * 0.62 + 5 * npd.signed(key, 'dx', i)
        dy = s * 0.26 * (1 if i % 2 else -1) + 4 * npd.signed(key, 'dy', i)
        img = Image.alpha_composite(img, draw_one(
            sp, s * (0.9 + 0.1 * npd.unit(key, 'l', i)), 128 + dx,
            128 + dy, form))
    return img


def poses_of(species):
    """The poses of a species, from its real states in the register."""
    row = npd.register_row(species)
    out = []
    for state in row['states']:
        pose = POSE.get(state, 'single')
        if pose not in out:
            out.append(pose)
    # Every fish also swims past on its own and changes depth.
    for pose in ('single', 'rising', 'feeding'):
        if pose not in out:
            out.append(pose)
    return out, row['states']


def fish_pool(species):
    pool = []
    poses, _ = poses_of(species)
    for pose in poses:
        for i, form in enumerate(FORMS[pose]):
            label = '-'.join(f'{k}={v}' for k, v in sorted(form.items()))
            pool.append({'species': species, 'pose': pose,
                         'state': pose, 'form': dict(form),
                         'key': f'{species}:{pose}:{i}:{label}'})
    return pool


# Every silhouette is cropped to its box and fitted to this common box
# before two are compared, so neither placement nor size nor stretch
# counts as a change of form; only the outline does.
NORM_BOX = (200, 80)


def normalised(mask):
    """The silhouette cropped to its bbox and fitted to NORM_BOX."""
    box = mask.getbbox()
    if not box:
        return Image.new('L', NORM_BOX, 0)
    small = mask.crop(box).resize(NORM_BOX, Image.BILINEAR)
    return small.point(lambda v: 255 if v >= 128 else 0)


def _dist(a, b):
    return npd.distance(a['norm'], b['norm'], a['fill'], b['fill'])


def choose(drawn, threshold, size=KIT_SIZE):
    """The largest set, up to size, whose every pair is threshold apart.

    Greedy in pool order (the round robin keeps every real state in
    turn), tried from every starting drawing; the largest set wins and
    the earliest start breaks ties, so the choice is deterministic.
    Pairs also need distinct hitboxes (TABOO 0.3 rule 49).
    """
    n = len(drawn)
    far = [[i != j and _dist(drawn[i], drawn[j]) >= threshold
            for j in range(n)] for i in range(n)]
    keys = [hitbox_key(d['hitbox']) for d in drawn]
    best = []
    for start in range(n):
        pick = [start]
        for k in range(n):
            if len(pick) == size:
                break
            if k != start and all(far[k][c] for c in pick) and \
                    keys[k] not in {keys[c] for c in pick}:
                pick.append(k)
        if len(pick) > len(best):
            best = pick
        if len(best) == size:
            break
    return [drawn[i] for i in sorted(best)]


def form_distance(a, b):
    """Shape distance of two silhouettes, free of place and scale.

    The formula of form.shape_delta (|A xor B| / |A or B|, interior XOR
    weighted, TABOO 0.3 rules 16 and 22) on the normalised masks.
    """
    return npd.distance(normalised(a), normalised(b))


# --- The kits --------------------------------------------------------------

SPECIES = ('chebachok', 'marinka', 'osman', 'gubach', 'ishkhan', 'sudak',
           'leshch', 'sazan', 'sig')


def build(species, threshold=THRESHOLD):
    """Draw the pool of a species and choose twelve; nothing is written."""
    seed = hashlib.sha1(
        f'ludus-own-drawing:fish:{species}'.encode()).hexdigest()
    oid = seed[:10]
    row = npd.register_row(species)
    data = fish_row(species)
    pool = fish_pool(species)
    refused, drawn = {}, []
    for p in npd._round_robin(pool):
        img = draw_pose(p)
        mask = alpha_mask(img)
        ok, stats = reference.fits(SLOT, mask)
        if not ok:
            refused['unlike-real-object'] = \
                refused.get('unlike-real-object', 0) + 1
            continue
        norm = normalised(mask)
        drawn.append({'params': p, 'img': img, 'mask': mask,
                      'norm': norm, 'fill': fill_holes(norm),
                      'hitbox': hitbox(mask), 'stats': stats})
    fitting = len(drawn)
    chosen = choose(drawn, threshold)
    refused['too-close-to-a-sibling'] = fitting - len(chosen)
    prefix = f'own_{species}_{oid}'
    images, variants = {}, []
    for i, c in enumerate(chosen, 1):
        near = min((_dist(c, o) for o in chosen if o is not c),
                   default=0.0)
        slot_v = f'v{i:02d}'
        name = f'{prefix}_{slot_v}.png'
        images[name] = c['img']
        params = {k: v for k, v in c['params'].items() if k != 'species'}
        variants.append({
            'slot': slot_v, 'file': name, 'state': params['state'],
            'params': params, 'shape_change': round(near, 4),
            'shape_basis': SHAPE_BASIS, 'fits_reference': True,
            'reference_stats': c['stats'], 'area': area(c['mask']),
            'hitbox': c['hitbox'],
            'analytics_id': f'ludus.variant.fish.{species}.{oid}.{slot_v}',
        })
    record = {
        'name': prefix, 'id': oid, 'seed': seed, 'slot': SLOT,
        'thing': species, 'register': row,
        'species': {k: data[k] for k in
                    ('ru', 'en', 'latin', 'status', 'loot', 'length',
                     'depth', 'colour')},
        'morphology': dict(MORPHOLOGY[species],
                           note='genus shape from general ichthyology, '
                                'approximate; to be checked by an '
                                'ichthyologist (docs/ISSYK_KUL_FISH.md)'),
        'origin': 'own-procedural-drawing', 'method': 'own-procedural',
        'raw_material': False,
        'source': {'repo': 'ludus (own drawing)', 'path': HERE,
                   'commit': REVISION},
        'repo': 'ludus (own drawing)', 'path': HERE, 'commit': REVISION,
        'license': 'project (own drawing, no third-party material)',
        'license_file': None,
        'threshold': threshold, 'shape_basis': SHAPE_BASIS,
        'shape_norm': {'box': list(NORM_BOX),
                       'method': 'crop to the bbox, fit to the box; '
                                 'placement, size and stretch do not '
                                 'count'},
        'engine': ENGINE,
        'reference_profile': dict(reference.PROFILES[SLOT]),
        'pool': {'size': len(pool), 'fitting': fitting,
                 'refused': refused, 'chosen': len(chosen)},
        'constitution': 'FORM: a real species of Issyk-Kul in its real '
                        'states -> ACTION: the ROV operator tells it '
                        'apart, logs it and releases the endemics -> '
                        'GOAL: knowing the living lake by its real '
                        'creatures (TABOO 0.03 rule 6)',
        'variants': variants,
        'status': 'ok' if len(variants) == KIT_SIZE else 'shortfall',
        'shortfall': KIT_SIZE - len(variants),
        'shape_change': min((v['shape_change'] for v in variants),
                            default=0.0),
    }
    return record, images


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', default='build/fish')
    parser.add_argument('--sheet', default='')
    parser.add_argument('--ship', default='',
                        help='derived root; kits with 12/12 go to '
                             '<ship>/DEF-056/')
    parser.add_argument('--only', default='', help='comma-separated ids')
    parser.add_argument('--skip', default='',
                        help='ids refused at the eye check')
    args = parser.parse_args(argv)
    out = Path(args.out)
    shutil.rmtree(out, ignore_errors=True)
    wanted = set(filter(None, args.only.split(',')))
    skip = set(filter(None, args.skip.split(',')))
    kits = []
    for species in SPECIES:
        if wanted and species not in wanted:
            continue
        record, images = build(species)
        npd.write_kit(out / SLOT, record, images)
        kits.append((record, images))
        shapes = [v['shape_change'] for v in record['variants']]
        print(f'{SLOT} {record["name"]}: {record["status"]} '
              f'{len(shapes)}/12, pool {record["pool"]}, nearest '
              f'sibling {min(shapes, default=0):.1%}..'
              f'{max(shapes, default=0):.1%}')
    if args.sheet:
        print('sheet', npd.contact_sheet(kits, args.sheet))
    if args.ship:
        dest = Path(args.ship) / SLOT
        for record, _ in kits:
            if record['status'] != 'ok' or record['thing'] in skip:
                continue
            dest.mkdir(parents=True, exist_ok=True)
            for f in (out / SLOT).glob(f'{record["name"]}*'):
                shutil.copy2(f, dest / f.name)
            print(f'shipped {record["name"]} to {dest}')
    return 0 if all(r['status'] == 'ok' for r, _ in kits) else 1


if __name__ == '__main__':
    sys.exit(main())
