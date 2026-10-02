"""Antagonist protocol: the eight passions and their twelve variants.

A raw object whose redraw is only a recolour (shape change under the
35 % rule) must not enter Ludus as a disguised copy.  It is replaced by
an Antagonist: one of the eight passions (logismoi) named by Evagrius
Ponticus and John Climacus - gluttony, lust, avarice, anger, sadness
(lype), acedia, vainglory and pride.  The passion is read from the
source itself, so a coin becomes avarice and a fireball becomes anger.

An antagonist inverts its source three ways: its palette is the
complement of the source's dominant hue, its texture flips between
smooth and rough, and its behaviour tag is the functional opposite of
the source's role (a reward becomes a hazard that looks like a reward).
A mirror flip alone is never used, because it changes nothing a player
would notice.

Nothing here is random.  Every choice comes from a byte stream hashed
from the object's seed, so the same source always yields the same
antagonist, byte for byte (Constitution: choice and consequence only).
"""

import colorsys
import hashlib
import math
import re
from functools import lru_cache

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

from form import CANVAS, alpha_mask, area, fill_holes

PASSIONS = ('gluttony', 'lust', 'avarice', 'anger', 'sadness', 'acedia',
            'vainglory', 'pride')

# Words in the source path that name the passion outright.  A token
# matches when it starts with the word, so "fireball" matches "fire".
PASSION_WORDS = [
    # A mimic is a treasure chest that bites: the hoard that devours the
    # one who hoards it, the very image of love of money (Ladder 16).
    ('avarice', ('coin', 'gold', 'treasure', 'money', 'dollar', 'mimic')),
    ('anger', ('fire', 'flame', 'burn', 'lava')),
    ('gluttony', ('food', 'potion', 'meat', 'bread', 'flask')),
    ('pride', ('crown', 'throne')),
    ('vainglory', ('mirror', 'gem', 'trophy', 'jewel')),
    ('acedia', ('wall', 'bars', 'grid')),
    ('sadness', ('dark', 'tear', 'rain')),
]

# Glyphs of roguelike atlases carry their meaning in the shape: "$" is
# the hoard, "#" is the wall of sloth that shuts the monk in his cell.
PASSION_GLYPHS = {'$': 'avarice', '#': 'acedia'}

# Iconographic hue of each passion, used when the source has no hue of
# its own to invert (a white or black glyph).
PASSION_HUE = {
    'gluttony': 30, 'lust': 320, 'avarice': 80, 'anger': 0,
    'sadness': 220, 'acedia': 45, 'vainglory': 50, 'pride': 275,
}

# The role the source played, read from its passion, and the inverted
# role its antagonist plays.
SOURCE_ROLE = {
    'avarice': 'reward', 'gluttony': 'reward', 'vainglory': 'reward',
    'pride': 'reward', 'lust': 'reward', 'anger': 'projectile',
    'acedia': 'obstacle', 'sadness': 'ambient',
}
INVERTED_ROLE = {
    'reward': 'hazard_mimicking_reward',
    'obstacle': 'homing',
    'projectile': 'stationary_lure',
    'ambient': 'homing',
}

# Hue buckets for sources that no word or glyph identifies.
HUE_BUCKETS = [
    (0, 45, 'anger'), (45, 70, 'avarice'), (70, 165, 'gluttony'),
    (165, 255, 'sadness'), (255, 300, 'pride'), (300, 345, 'lust'),
    (345, 361, 'anger'),
]

# Glyph recognition limits, see source_features().
GLYPH_IOU = 0.55
GLYPH_MARGIN = 0.08

# Below this mean edge strength a source reads as smooth.
SMOOTH_EDGE = 18


class SeedStream:
    """Deterministic stream of numbers hashed from a seed and a label."""

    def __init__(self, seed, label):
        self.seed, self.label, self.count = seed, label, 0

    def unit(self):
        """Next number in [0, 1)."""
        digest = hashlib.sha256(
            f'{self.seed}:{self.label}:{self.count}'.encode()).digest()
        self.count += 1
        return int.from_bytes(digest[:6], 'big') / 2 ** 48

    def uniform(self, lo, hi):
        return lo + (hi - lo) * self.unit()

    def pick(self, seq):
        return seq[int(self.unit() * len(seq))]


def hash_bytes(seed, label, n):
    """Return n deterministic bytes, used for noise fields."""
    out = bytearray()
    i = 0
    while len(out) < n:
        out += hashlib.sha256(f'{seed}:{label}:{i}'.encode()).digest()
        i += 1
    return bytes(out[:n])


def object_seed(repo, path, piece):
    """Seed = sha1(repo + path + piece); the id is its first 10 hex."""
    return hashlib.sha1(f'{repo}{path}#{piece}'.encode()).hexdigest()


# --- Reading the source -------------------------------------------------

def _normalised(mask, side=32):
    """Crop a mask to its box and scale it to a side x side square."""
    box = mask.getbbox()
    if box is None:
        return None
    small = mask.crop(box).resize((side, side), Image.BILINEAR)
    return small.point(lambda v: 255 if v > 127 else 0)


@lru_cache(maxsize=1)
def _glyph_templates():
    """Render the printable ASCII glyphs once, as normalised masks.

    Pillow ships its own scalable font, so the templates are the same
    on every runner and the recognition stays deterministic.
    """
    font = ImageFont.load_default(size=96)
    templates = {}
    for code in range(33, 127):
        ch = chr(code)
        img = Image.new('L', (160, 160), 0)
        ImageDraw.Draw(img).text((20, 10), ch, fill=255, font=font)
        norm = _normalised(img.point(lambda v: 255 if v > 127 else 0))
        if norm is not None:
            templates[ch] = norm
    return templates


def recognise_glyph(mask):
    """Return (glyph, IoU, margin) of the best-matching ASCII glyph.

    The margin over the runner-up guards against shapes that are close
    to several glyphs at once (a bar is "|", "l" and "I" alike).
    """
    norm = _normalised(mask)
    if norm is None:
        return None, 0.0, 0.0
    scores = []
    for ch, tpl in _glyph_templates().items():
        union = area(ImageChops.lighter(norm, tpl)) or 1
        scores.append((area(ImageChops.multiply(norm, tpl)) / union, ch))
    scores.sort(reverse=True)
    return scores[0][1], scores[0][0], scores[0][0] - scores[1][0]


def source_features(piece, canvas, mask, path):
    """Measure what the passion, palette and texture are read from.

    Colour and luminance are measured here only to choose a palette and
    a texture; the form itself is always the alpha mask.
    """
    hsv = canvas.convert('RGB').convert('HSV')
    hues = [0] * 36
    sat_count = total = 0
    value_sum = 0
    h_b, s_b, v_b = (c.tobytes() for c in hsv.split())
    m_b = mask.tobytes()
    for i, flag in enumerate(m_b):
        if not flag:
            continue
        total += 1
        value_sum += v_b[i]
        if s_b[i] > 60 and v_b[i] > 40:
            sat_count += 1
            hues[h_b[i] * 36 // 256] += 1
    chromatic = total > 0 and sat_count >= 0.2 * total
    hue = (hues.index(max(hues)) * 10 + 5) if chromatic else None
    mean_value = value_sum / (255 * total) if total else 0.0

    # Texture is judged at native resolution, where the upscale has not
    # yet flattened the drawing into large uniform blocks.
    native = piece.convert('RGBA')
    # The 5x5 erosion keeps the 3x3 edge kernel and one antialias pixel
    # off the outline, so only drawing inside the form is measured.
    inner = alpha_mask(native).filter(ImageFilter.MinFilter(5))
    edges = native.convert('L').filter(ImageFilter.FIND_EDGES).tobytes()
    inside = [edges[i] for i, f in enumerate(inner.tobytes()) if f]
    roughness = sum(inside) / len(inside) if inside else 0.0

    glyph, glyph_iou, margin = None, 0.0, 0.0
    if not chromatic:
        # Only monochrome pieces can be atlas glyphs; a coloured sprite
        # that happens to look like "S" is not a letter.
        glyph, glyph_iou, margin = recognise_glyph(mask)
    # The atlas font differs from Pillow's, so the match is loose (IoU
    # 0.55) but must clearly beat the next glyph.
    known = glyph_iou >= GLYPH_IOU and margin >= GLYPH_MARGIN
    words = [w for w in re.split(r'[^a-z]+', path.lower()) if w]
    return {
        'hue': hue, 'chromatic': chromatic,
        'mean_value': round(mean_value, 4),
        'roughness': round(roughness, 2),
        'glyph': glyph if known else None,
        'glyph_iou': round(glyph_iou, 3),
        'glyph_margin': round(margin, 3),
        'words': words,
    }


def choose_passion(feat):
    """Map source features to a passion; return (passion, reason)."""
    if feat['glyph'] in PASSION_GLYPHS:
        return PASSION_GLYPHS[feat['glyph']], f'glyph "{feat["glyph"]}"'
    for passion, keys in PASSION_WORDS:
        for word in feat['words']:
            if word.startswith(keys):
                return passion, f'word "{word}"'
    hue = feat['hue']
    if hue is not None:
        for lo, hi, passion in HUE_BUCKETS:
            if lo <= hue < hi:
                return passion, f'dominant hue {hue} deg'
    if feat['mean_value'] < 0.35:
        return 'sadness', 'dark achromatic source'
    if feat['mean_value'] > 0.75:
        return 'vainglory', 'bright achromatic source'
    return 'acedia', 'grey achromatic source'


def behaviour(passion):
    """Return the source role and the antagonist's inverted role."""
    role = SOURCE_ROLE[passion]
    return {'source_role': role, 'antagonist': INVERTED_ROLE[role]}


def _hsv(h, s, v):
    r, g, b = colorsys.hsv_to_rgb((h % 360) / 360, s, v)
    return (round(r * 255), round(g * 255), round(b * 255))


def antagonist_palette(feat, passion):
    """Complementary palette with inverted value.

    A chromatic source gives its complementary hue.  An achromatic one
    has no hue to invert, so the passion's own iconographic hue is used.
    A bright source becomes a dark body with a bright rim, and a dark
    source becomes a luminous body: the counterfeit light of the
    passion.
    """
    if feat['chromatic']:
        hue, basis = (feat['hue'] + 180) % 360, 'complement'
    else:
        hue, basis = PASSION_HUE[passion], 'passion-hue'
    if feat['mean_value'] > 0.5:
        values = (0.06, 0.22, 0.5, 0.92)
    else:
        values = (0.3, 0.6, 0.85, 1.0)
    stops = [(0.0, _hsv(hue, 0.7, values[0])),
             (0.45, _hsv(hue, 0.75, values[1])),
             (0.8, _hsv(hue, 0.6, values[2])),
             (1.0, _hsv(hue + 20, 0.3, values[3]))]
    return {'hue': hue, 'basis': basis, 'stops': stops}


def texture_mode(feat):
    """Smooth sources get rough antagonists and rough ones smooth."""
    return 'rough' if feat['roughness'] < SMOOTH_EDGE else 'smooth'


# --- Painting ------------------------------------------------------------

def _lut(stops):
    """Build per-channel 256-entry lookups from gradient stops."""
    table = []
    for level in range(256):
        t = level / 255
        for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
            if t0 <= t <= t1:
                k = (t - t0) / (t1 - t0) if t1 > t0 else 0
                table.append(tuple(round(a + (b - a) * k)
                                   for a, b in zip(c0, c1)))
                break
    return [[c[i] for c in table] for i in range(3)]


@lru_cache(maxsize=32)
def _noise(seed):
    """Two-octave hashed noise: coarse chips plus fine grain."""
    coarse = Image.frombytes('L', (16, 16), hash_bytes(seed, 'chip', 256))
    fine = Image.frombytes('L', (64, 64), hash_bytes(seed, 'grain', 4096))
    coarse = coarse.resize((CANVAS, CANVAS), Image.NEAREST)
    fine = fine.resize((CANVAS, CANVAS), Image.BILINEAR)
    return Image.blend(coarse, fine, 0.5)


def _gradient():
    """Vertical light-from-above ramp shared by every painted body."""
    return Image.linear_gradient('L').rotate(180)


def paint(mask, palette, texture, seed, style='body'):
    """Fill a form mask with the antagonist's palette and texture."""
    lut = _lut(palette['stops'])
    light = palette['stops'][-1][1]
    if style == 'dark':
        # Dark matter: an almost black body and a thin light rim.
        rgb = Image.new('RGB', mask.size, (8, 6, 12))
        rim = ImageChops.subtract(mask, mask.filter(ImageFilter.MinFilter(3)))
        rgb.paste(light, (0, 0), rim)
    else:
        if texture == 'rough':
            field = Image.blend(_gradient(), _noise(seed), 0.6)
            grit = field.filter(ImageFilter.FIND_EDGES)
            field = ImageChops.add(field, grit)
        else:
            dome = mask.filter(ImageFilter.GaussianBlur(12))
            field = Image.blend(_gradient(), dome, 0.6)
        rgb = Image.merge('RGB', [field.point(ch) for ch in lut])
        width = 3 if style == 'hollow' else 5
        rim = ImageChops.subtract(
            mask, mask.filter(ImageFilter.MinFilter(width)))
        rgb.paste(light, (0, 0), rim)
    img = rgb.convert('RGBA')
    img.putalpha(mask)
    return img


# --- Shape tools -----------------------------------------------------------

def _binary(img, level=127):
    return img.point(lambda v: 255 if v > level else 0)


def _dilate(mask, size):
    return mask.filter(ImageFilter.MaxFilter(size))


def _erode(mask, size):
    return mask.filter(ImageFilter.MinFilter(size))


def warp_rows(mask, scale, shift=lambda t: 0.0):
    """Rescale and shift each row about the box centre.

    scale(t) and shift(t) take t in [0, 1] from the top row to the
    bottom row of the object's box.
    """
    box = mask.getbbox()
    out = Image.new('L', mask.size, 0)
    if box is None:
        return out
    x0, y0, x1, y1 = box
    cx = (x0 + x1) / 2
    span = max(1, y1 - y0 - 1)
    for y in range(y0, y1):
        t = (y - y0) / span
        row = mask.crop((x0, y, x1, y + 1))
        w = max(1, round((x1 - x0) * scale(t)))
        row = row.resize((w, 1), Image.NEAREST)
        out.paste(row, (round(cx - w / 2 + shift(t)), y))
    return out


def warp_cols(mask, scale, shift=lambda t: 0.0):
    """Column version of warp_rows, via a transpose."""
    tr = Image.Transpose.TRANSPOSE
    return warp_rows(mask.transpose(tr), scale, shift).transpose(tr)


def _centre(mask):
    box = mask.getbbox() or (0, 0, CANVAS, CANVAS)
    cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
    return cx, cy, max(box[2] - box[0], box[3] - box[1]) / 2, box


def _scale(mask, k):
    """Scale the form about the centre of its box."""
    box = mask.getbbox()
    if box is None:
        return mask
    part = mask.crop(box)
    w = max(1, round(part.width * k))
    h = max(1, round(part.height * k))
    out = Image.new('L', mask.size, 0)
    out.paste(part.resize((w, h), Image.NEAREST),
              (round((box[0] + box[2] - w) / 2),
               round((box[1] + box[3] - h) / 2)))
    return out


def _rays(mask, st, count, r0, r1, half, strength, core=1.0):
    """Shrink the form to a core and draw rays from its centre.

    The source fills the canvas up to a 24 px margin, so growth outward
    alone would be clipped; the passion first contracts, then reaches.
    """
    cx, cy, radius, _ = _centre(mask)
    out = _scale(mask, core)
    draw = ImageDraw.Draw(out)
    for k in range(count):
        a = 2 * math.pi * (k + 0.35 * st.unit()) / count
        tip = radius * r1 * (1 + 0.1 * (strength - 1))
        tip *= st.uniform(0.9, 1.05)
        base = radius * r0

        def at(r, angle):
            return (cx + r * math.cos(angle), cy + r * math.sin(angle))

        pts = [at(base, a - half), at(tip, a), at(base, a + half)]
        draw.polygon(pts, fill=255)
    return out


# --- The eight passions as shape deformations ---------------------------
# Each takes the source mask, a seed stream and a strength (1 normal,
# 2 amplified) and returns the antagonist's form.

def shape_anger(mask, st, s):
    """Wrath clenches its heart small and lashes out in tongues."""
    core = max(0.3, 0.6 - 0.15 * (s - 1))
    return _rays(mask, st, 7 + int(3 * st.unit()), 0.3 * core + 0.1, 1.1,
                 0.2, s, core)


def shape_avarice(mask, st, s):
    """Avarice narrows at the top and hangs heavy, with hooked claws."""
    top = max(0.1, 0.4 - 0.15 * (s - 1))
    out = warp_rows(mask, lambda t: top + (1.05 - top) * t ** 1.4)
    _, _, _, box = _centre(out)
    draw = ImageDraw.Draw(out)
    x0, _, x1, y1 = box
    for i in range(3):
        x = x0 + (i + 0.5) * (x1 - x0) / 3
        hook = st.uniform(-10, 10)
        draw.polygon([(x - 9, y1 - 14), (x + 9, y1 - 14),
                      (x + hook, y1 + 20 * s)], fill=255)
    return out


def shape_gluttony(mask, st, s):
    """Gluttony swells: widened, bloated and rounded."""
    widen = 1.3 + 0.2 * (s - 1) + st.uniform(0, 0.05)
    out = warp_rows(mask, lambda t: widen * (1 + 0.15 * math.sin(math.pi * t)))
    out = _dilate(_dilate(out, 9), 9 if s == 1 else 15)
    return _binary(out.filter(ImageFilter.GaussianBlur(5)), 110)


def shape_lust(mask, st, s):
    """Lust coils: rows and columns are drawn into a sinuous wave."""
    _, _, radius, box = _centre(mask)
    phase = st.uniform(0, 2 * math.pi)
    amp = 0.17 * (box[2] - box[0]) * s
    out = warp_rows(mask, lambda t: 1.0,
                    lambda t: amp * math.sin(3 * math.pi * t + phase))
    amp2 = 0.1 * (box[3] - box[1]) * s
    return warp_cols(out, lambda t: 1.0,
                     lambda t: amp2 * math.sin(2 * math.pi * t + phase))


def shape_sadness_sag(mask, st, s):
    """The first form of sadness: it sagged and wept drops below itself.

    Kept so the sadness kits shipped before 2026-10-02 can still be
    rebuilt byte for byte (rule 48).  It is no longer the passion's
    form: on a square source it sagged into a stemless U-shaped cup that
    can read as a chalice (pass osint-2026-10-02T09:51:32Z, rejected by
    eye), and a passion must never resemble a holy thing (TABOO 0.2
    item 3, 0.35 rule 6).
    """
    _, _, _, box = _centre(mask)
    depth = 0.22 * (box[3] - box[1]) * s
    out = warp_cols(mask, lambda t: 0.85,
                    lambda t: depth * (1 - (2 * t - 1) ** 2))
    draw = ImageDraw.Draw(out)
    data = out.tobytes()
    x0, _, x1, _ = out.getbbox() or box
    for _ in range(4):
        x = int(st.uniform(x0 + 6, x1 - 6))
        col = [y for y in range(CANVAS) if data[y * CANVAS + x]]
        if not col:
            continue
        y = col[-1]
        length = st.uniform(14, 26) * s
        draw.line([(x, y), (x, y + length)], fill=255, width=4)
        draw.ellipse([x - 7, y + length - 4, x + 7, y + length + 14],
                     fill=255)
    return out


# The cracked jug of sadness, in fractions of the source's box.  A jug
# of daily craft, never a cup: a lip with a spout, a narrow neck, a
# loop handle, a belly wider than its foot, and it lies on its side.
JUG_WIDTH = 0.66
JUG_LIP = 0.36
JUG_NECK = 0.24
JUG_FOOT = 0.6
# Tipped over: the mouth turned to the left and a little down, so the
# water runs out of it (degrees counter-clockwise, as PIL turns).
JUG_TILT = 100
JUG_GROUND = 200


def _jug_width(t):
    """Width of the standing jug at height t (0 rim, 1 foot), 0..1.

    A lip, a narrow neck to t = 0.2, then a shoulder that swells to the
    widest belly at t = 0.6 and draws in to a foot narrower than the
    belly: the profile of a water jug, not of a bowl.
    """
    if t < 0.06:
        return JUG_LIP
    if t < 0.1:
        return JUG_LIP + (JUG_NECK - JUG_LIP) * (t - 0.06) / 0.04
    if t < 0.2:
        return JUG_NECK
    u = (t - 0.2) / 0.8
    if u < 0.5:
        return JUG_NECK + (1 - JUG_NECK) * math.sin(math.pi * u) ** 1.3
    return 1 - (1 - JUG_FOOT) * ((u - 0.5) / 0.5) ** 2


def _jug_upright(mask):
    """The source's rows drawn into a standing jug with spout and handle.

    The form is still the source's: its holes filled and its notches
    closed, every row is rescaled to the jug's profile (warp_rows keeps
    what the row holds), then the spout and the loop of the handle are
    drawn on.  Returns the jug mask and its box.
    """
    closed = _erode(_dilate(fill_holes(mask), 15), 15)
    out = warp_rows(closed, lambda t: JUG_WIDTH * _jug_width(t))
    box = out.getbbox()
    if box is None:
        return out, box
    x0, y0, x1, y1 = box
    cx, h = (x0 + x1) / 2, y1 - y0
    half = (x1 - x0) / 2

    def y_at(t):
        return y0 + h * t

    def half_at(t):
        return half * _jug_width(t)

    draw = ImageDraw.Draw(out)
    # The spout: the lip pinched out on one side.
    lip = half_at(0.0)
    draw.polygon([(cx - lip + 2, y_at(0.0)),
                  (cx - lip - 0.16 * h, y_at(0.0) - 0.05 * h),
                  (cx - lip + 2, y_at(0.09))], fill=255)
    # The handle: a loop from the neck to the shoulder on the other
    # side, thick enough to stay a loop after erosion and facets.
    neck = half_at(0.16)
    draw.arc([cx + neck - 0.2 * h, y_at(0.08), cx + neck + 0.2 * h,
              y_at(0.5)], -90, 90, fill=255,
             width=max(9, round(0.07 * h)))
    return out, box


def shape_sadness(mask, st, s):
    """Sadness is a cracked clay jug fallen on its side.

    Evagrius (Praktikos 10) says sadness comes when a desire is not
    fulfilled and the thoughts bring back home and the former life; the
    Apostle sets the sorrow of the world, which works death, against the
    sorrow according to God (2 Cor 7:10).  So the form is a vessel of
    everyday work that no longer holds what it was made for: a jug
    knocked over, a crack in its belly, the water running out of the
    mouth into a puddle and dripping from the crack.  It is never a cup
    and never stands upright on a foot, with or without a stem (the
    first form sagged into a stemless cup; see shape_sadness_sag).
    """
    jug, box = _jug_upright(mask)
    if box is None:
        return jug
    # Lay it down: turn it about its own centre, then rest the belly on
    # the ground line with the mouth to the left.
    turned = jug.rotate(JUG_TILT, resample=Image.NEAREST, expand=True)
    part = turned.crop(turned.getbbox())
    k = min(1.0, (CANVAS - 40) / part.width, 0.62 * CANVAS / part.height)
    part = part.resize((max(1, round(part.width * k)),
                        max(1, round(part.height * k))), Image.NEAREST)
    out = Image.new('L', mask.size, 0)
    out.paste(part, ((CANVAS - part.width) // 2 + 8,
                     JUG_GROUND - part.height))
    x0, y0, x1, y1 = out.getbbox()
    w, h = x1 - x0, y1 - y0
    draw = ImageDraw.Draw(out)
    # The crack: a zig-zag cut up from the underside of the belly into
    # its middle, cut out of the alpha, so it shows on every variant
    # that keeps the edge.
    cx = x0 + w * st.uniform(0.56, 0.64)
    pts = [(cx + st.uniform(-3, 3), y1 + 2)]
    for i in range(1, 5):
        dx = (7 if i % 2 else -7) * (1 + 0.3 * (s - 1))
        pts.append((cx + dx + st.uniform(-2, 2), y1 - h * 0.58 * i / 4))
    draw.line(pts, fill=0, width=3 + s, joint='curve')
    # Water: drops from the crack and a puddle spread from the mouth.
    for i in range(2 + s):
        dx = st.uniform(-5, 5)
        dy = 10 + 11 * i
        r = 3.5 + 0.8 * i
        draw.ellipse([cx + dx - r, y1 + dy - r * 1.6, cx + dx + r,
                      y1 + dy + r], fill=255)
    pud_y = min(CANVAS - 14, y1 + 22 + 6 * s)
    draw.ellipse([x0 - 6, pud_y - 6, x0 + w * 0.5, pud_y + 6], fill=255)
    # The stream from the mouth down to the puddle.
    mouth_x = x0 + 4
    draw.line([(mouth_x, y0 + h * 0.62), (mouth_x - 6, y0 + h * 0.85),
               (mouth_x - 2, pud_y)], fill=255, width=5, joint='curve')
    return out


def shape_acedia(mask, st, s):
    """Acedia slumps: squashed to the floor, spread wide, edges melted."""
    box = mask.getbbox()
    if box is None:
        return mask
    x0, y0, x1, y1 = box
    squash = max(0.25, 0.55 - 0.15 * (s - 1))
    part = mask.crop(box)
    w = round((x1 - x0) * (1.25 + 0.05 * st.unit()))
    h = max(1, round((y1 - y0) * squash))
    part = part.resize((w, h), Image.NEAREST)
    out = Image.new('L', mask.size, 0)
    out.paste(part, (round((x0 + x1 - w) / 2), y1 - h))
    return _binary(_dilate(out, 5).filter(ImageFilter.GaussianBlur(3)))


def shape_vainglory(mask, st, s):
    """Vainglory spreads a fan upward, each quill tipped with an eye.

    It does its work so that it is seen (Ladder 22): the form shrinks
    and displays a fan of quills over itself, and the round tips are
    the eyes of the onlookers it lives for.  The earlier form wore a
    ring round the whole body; a ring round a figure reads as a halo in
    any technique (CLAUDE.md TABOO 0.35 rule 7), so it was removed.
    """
    core = max(0.3, 0.55 - 0.12 * (s - 1))
    cx, cy, radius, box = _centre(mask)
    out = _scale(mask, core)
    # The shrunk core sits low in the old box, so the fan has room above.
    low = (box[3] - cy) * (1 - core) * 0.8
    out = ImageChops.offset(out, 0, round(low))
    base_y = cy + low
    draw = ImageDraw.Draw(out)
    count = 7
    for k in range(count):
        # Quills spread over the upper half only, from -160 to -20 deg.
        a = math.radians(-160 + 140 * (k + 0.5) / count
                         + st.uniform(-4, 4))
        tip = min(radius * (0.95 + 0.1 * (s - 1)) * st.uniform(0.9, 1.0),
                  base_y - 12)
        half = 0.07 * s

        def at(r, angle):
            return (cx + r * math.cos(angle), base_y + r * math.sin(angle))

        draw.polygon([at(radius * core * 0.4, a - half), at(tip, a),
                      at(radius * core * 0.4, a + half)], fill=255)
        ex, ey = at(tip, a)
        e = 6 + 2 * (s - 1)
        draw.ellipse([ex - e, ey - e, ex + e, ey + e], fill=255)
    return out


def shape_pride(mask, st, s):
    """Pride towers: a spire that narrows upward and wears a crown."""
    top = max(0.08, 0.25 - 0.12 * (s - 1))
    out = warp_rows(mask, lambda t: top + (1 - top) * t)
    x0, y0, x1, _ = out.getbbox() or (0, 0, CANVAS, CANVAS)
    cx = (x0 + x1) / 2
    draw = ImageDraw.Draw(out)
    for dx in (-14, 0, 14):
        h = st.uniform(14, 22) * s
        draw.polygon([(cx + dx - 6, y0 + 2), (cx + dx + 6, y0 + 2),
                      (cx + dx, y0 - h)], fill=255)
    return out


SHAPES = {
    'anger': shape_anger, 'avarice': shape_avarice,
    'gluttony': shape_gluttony, 'lust': shape_lust,
    'sadness': shape_sadness, 'acedia': shape_acedia,
    'vainglory': shape_vainglory, 'pride': shape_pride,
}

# Forms a passion once had, kept only to rebuild the kits shipped with
# them (rule 48); the runner never chooses them.
LEGACY_SHAPES = {'sadness-sag': shape_sadness_sag}


# --- The twelve variants ------------------------------------------------
# Each takes the reference form, a seed stream and a strength and
# returns (mask, paint style, alpha scale, extra meta).

def v_erosion(m, st, s):
    """Erosion: MinFilter wear plus round bites out of the edge."""
    out = _erode(m, 5 + 4 * (s - 1))
    edge = ImageChops.subtract(m, _erode(m, 3)).tobytes()
    points = [i for i, f in enumerate(edge) if f]
    draw = ImageDraw.Draw(out)
    for _ in range(9 * s):
        if not points:
            break
        i = points[int(st.unit() * len(points))]
        x, y = i % CANVAS, i // CANVAS
        r = st.uniform(9, 17) * (1 + 0.3 * (s - 1))
        draw.ellipse([x - r, y - r, x + r, y + r], fill=0)
    return out, 'body', None, {}


def v_crystal(m, st, s):
    """Crystallisation: the form snapped to a coarse grid of facets."""
    cell = 16 + 8 * (s - 1)
    n = CANVAS // cell
    small = m.resize((n, n), Image.BOX)
    grid = _binary(small, 100).resize((CANVAS, CANVAS), Image.NEAREST)
    # Each facet loses a corner, so the grid reads as cut crystal and
    # not as a pixelated copy.
    draw = ImageDraw.Draw(grid)
    cut = cell // 2
    data = small.tobytes()
    for j in range(n):
        for i in range(n):
            if data[j * n + i] > 100 and st.unit() < 0.5:
                x, y = i * cell, j * cell
                draw.polygon([(x, y), (x + cut, y), (x, y + cut)], fill=0)
    return grid, 'body', None, {'cell': cell}


def v_amorphous(m, st, s):
    """Amorphous: blurred into a blob that pulses in alpha."""
    radius = 12 + 8 * (s - 1) + int(st.uniform(0, 4))
    blob = _binary(m.filter(ImageFilter.GaussianBlur(radius)), 70)
    return blob, 'body', None, {
        'blur_radius': radius,
        'alpha_pulse_frames': [1.0, 0.85, 0.7, 0.85],
    }


def v_symbiote(m, st, s):
    """Symbiote: organic lobes grown outward from the silhouette."""
    out = m.copy()
    edge = ImageChops.subtract(m, _erode(m, 3)).tobytes()
    points = [i for i, f in enumerate(edge) if f]
    cx, cy, _, _ = _centre(m)
    draw = ImageDraw.Draw(out)
    for _ in range(10 * s):
        if not points:
            break
        i = points[int(st.unit() * len(points))]
        x, y = i % CANVAS, i // CANVAS
        d = math.hypot(x - cx, y - cy) or 1
        r = st.uniform(10, 20)
        ox, oy = x + (x - cx) / d * r * 0.8, y + (y - cy) / d * r * 0.8
        draw.ellipse([ox - r, oy - r, ox + r, oy + r], fill=255)
    return out, 'body', None, {}


def v_techno(m, st, s):
    """Techno: outline only, hollow inside."""
    width = 4 if s == 1 else 2
    ring = ImageChops.subtract(m, _erode(m, 2 * width + 1))
    return ring, 'hollow', None, {'outline_px': width}


def v_dark(m, st, s):
    """Dark matter: holes filled, body near-black, one thin light rim."""
    grow = 7 + 6 * (s - 1)
    return _dilate(fill_holes(m), grow), 'dark', None, {}


def v_swarm(m, st, s):
    """Swarm: the silhouette resampled as a cloud of particles."""
    step = 11 + 4 * (s - 1)
    out = Image.new('L', m.size, 0)
    draw = ImageDraw.Draw(out)
    data = m.tobytes()
    for gy in range(0, CANVAS, step):
        for gx in range(0, CANVAS, step):
            x = int(gx + st.uniform(0, step))
            y = int(gy + st.uniform(0, step))
            if x < CANVAS and y < CANVAS and data[y * CANVAS + x]:
                r = st.uniform(2.5, 4.5)
                draw.ellipse([x - r, y - r, x + r, y + r], fill=255)
    return out, 'body', None, {'particle_step': step}


def v_echo(m, st, s):
    """Echo: half-transparent body and a fainter lagged copy."""
    dx = int(st.uniform(14, 24) * s)
    dy = int(st.uniform(-10, 10) * s)
    lag = ImageChops.offset(m, dx, dy)
    # ImageChops.offset wraps around; the wrapped strip is cleared.
    clear = Image.new('L', m.size, 255)
    ImageDraw.Draw(clear).rectangle(
        [0, 0, dx - 1 if dx > 0 else -1, CANVAS], fill=0)
    if dy > 0:
        ImageDraw.Draw(clear).rectangle([0, 0, CANVAS, dy - 1], fill=0)
    elif dy < 0:
        ImageDraw.Draw(clear).rectangle([0, CANVAS + dy, CANVAS, CANVAS],
                                        fill=0)
    lag = ImageChops.multiply(lag, clear)
    alpha = ImageChops.lighter(m.point(lambda v: v // 2),
                               lag.point(lambda v: v // 4))
    return ImageChops.lighter(m, lag), 'body', alpha, {
        'alpha': 0.5, 'echo_alpha': 0.25, 'echo_offset': [dx, dy]}


def v_gravity(m, st, s):
    """Inverted gravity: stretched upward, tapered, dripping skyward."""
    box = m.getbbox()
    if box is None:
        return m, 'body', None, {}
    x0, y0, x1, y1 = box
    h = y1 - y0
    new_h = round(h * (1.3 + 0.2 * (s - 1)))
    part = m.crop(box).resize((x1 - x0, new_h), Image.NEAREST)
    out = Image.new('L', m.size, 0)
    out.paste(part, (x0, y1 - new_h))
    out = warp_rows(out, lambda t: 0.45 + 0.55 * t)
    draw = ImageDraw.Draw(out)
    nx0, ny0, nx1, _ = out.getbbox() or box
    data = out.tobytes()
    for _ in range(4):
        x = int(st.uniform(nx0 + 4, nx1 - 4))
        col = [y for y in range(CANVAS) if data[y * CANVAS + x]]
        if not col:
            continue
        top = col[0]
        length = st.uniform(12, 30) * s
        draw.line([(x, top), (x, top - length)], fill=255, width=4)
        draw.ellipse([x - 6, top - length - 12, x + 6, top - length + 2],
                     fill=255)
    return out, 'body', None, {'stretch': new_h / max(1, h)}


VARIANTS = [
    ('v01', 'reference'), ('v02', 'erosion'), ('v03', 'crystallisation'),
    ('v04', 'amorphous'), ('v05', 'symbiote'), ('v06', 'techno'),
    ('v07', 'dark_matter'), ('v08', 'swarm'), ('v09', 'echo'),
    ('v10', 'inverted_gravity'), ('v11', 'hybrid'), ('v12', 'hybrid'),
]

VARIANT_OPS = {
    'erosion': v_erosion, 'crystallisation': v_crystal,
    'amorphous': v_amorphous, 'symbiote': v_symbiote,
    'techno': v_techno, 'dark_matter': v_dark, 'swarm': v_swarm,
    'echo': v_echo, 'inverted_gravity': v_gravity,
}

HYBRID_OPS = ('union', 'xor', 'grown_intersection')


def hybrid(pool, st):
    """Combine two earlier variants chosen by the seed.

    Returns (mask, style, meta) or None when the pool is too small.
    """
    if len(pool) < 2:
        return None
    a = st.pick(pool)
    b = st.pick([p for p in pool if p['slot'] != a['slot']])
    op = st.pick(HYBRID_OPS)
    ma, mb = a['mask'], b['mask']
    if op == 'union':
        mask = ImageChops.lighter(ma, mb)
    elif op == 'xor':
        mask = ImageChops.difference(ma, mb)
    else:
        mask = _dilate(ImageChops.multiply(ma, mb), 9)
    style = st.pick(('body', 'dark'))
    return mask, style, {'parents': [a['slot'], b['slot']], 'op': op}
