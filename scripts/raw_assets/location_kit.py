"""Twelve recognisable variants of a raw neutral thing for the locations.

The lesson of D6 (docs/RAW_D6_HLD_2026-09-30.md): the antagonist family
of variants (erosion, swarm, crystal...) turned stones into vases, and
the gentler "age and pose" family reached only 5/12 and 7/12 on
wesnoth planks.  A thing a location shows must stay itself, so its
variants here come only from what really happens to such a thing in a
room, a yard, on a shore or on the lake floor:

  pose        lean      leans a little or much, resting on its base;
              lie       lies on its side;
              upend     stands upside down (a pot drying, a basket);
  structure   chip      a piece is missing at a top corner;
              break     broken in two, the smaller piece fallen beside;
              sink      half sunk into sand or silt, with the drift;
              overgrow  grass at the foot, moss on the top;
  group       pair      two of the thing side by side, one behind;
              stack     a second one lying on top of the first.

Pose alone never makes a variant: every variant has a structural change
or is a group, because a turned copy is still the same drawing.  The
scale is the same for the source and every variant (the longest side is
SIDE pixels), so no change comes from scaling (TABOO 0.3 rule 15).

Measures (form.py, alpha only; TABOO 0.3 rules 1 and 22):
  shape_change    |A xor B| / |A or B| against the source standing on
                  the same floor line, interior moves weighted 0.1;
  sibling_min     the same distance to the nearest other variant of
                  the kit; both must reach the threshold (35 %), so no
                  two variants of the queue look alike (rules 49, 53);
  colour_change   share of the shared form whose colour moved beyond
                  the tolerance (form.colour_change); at least 35 % too
                  (TABOO 0.1: both measures);
  visible         share of the thing's own pixels still seen; at least
                  VISIBLE_MIN, so the thing is never mostly hidden.
A variant that misses any of them is refused with its numbers, never
faked.  Fewer than twelve is a shortfall and ships nothing.

Colour comes from the thing's material (oak, iron, clay, flax...) in
one of its real states (fresh, aged, weathered, wet); the luminance of
the source only carries the drawing inside the form.  Nothing here is
random: every number is read from sha1 of the kit's seed and a label.
"""

import hashlib
import math
import sys
from pathlib import Path

from PIL import (Image, ImageChops, ImageDraw, ImageFilter,
                 ImageFont, ImageOps)

sys.path.insert(0, str(Path(__file__).resolve().parent))

from form import (CANVAS, alpha_mask, area, colour_change,  # noqa: E402
                  fill_holes, hitbox, hitbox_key)
import neutral_procedural as npd  # noqa: E402

THRESHOLD = 0.35
KIT_SIZE = 12
# The thing's longest side on the canvas: room for a pair, a stack or a
# thing lying down, at the same scale as the source.
SIDE = 118
FLOOR = 238
VISIBLE_MIN = 0.6
REVISION = 'location-kit-r1'

# Real colours of the materials in their states (fresh, aged,
# weathered, wet or sooted).  Oak from the obitel's own oak proxies,
# clay and stone from the lake register, flax and willow from the
# Kiberslav style bible (§2: oak, birch bark, flax, copper, clay).
MATERIAL_STATES = {
    'wood': (('fresh', '#9a6a3a'), ('aged', '#6e4c2c'),
             ('weathered', '#8c857a'), ('wet', '#4a3322')),
    'iron': (('forged', '#5f6166'), ('rusted', '#8a4a2a'),
             ('sooted', '#35363a'), ('worn', '#7c7f84')),
    'copper': (('bright', '#b8763c'), ('dull', '#7e5634'),
               ('verdigris', '#5d8a74'), ('brass', '#a8904a')),
    'clay': (('fired', '#b0673c'), ('pale', '#c49a6c'),
             ('sooted', '#5a4034'), ('wet', '#7a4a30')),
    'stone': (('granite', '#8a8680'), ('limestone', '#b8ad96'),
              ('dark', '#55524d'), ('mossed', '#6f7358')),
    'fibre': (('flax', '#c2b28c'), ('canvas', '#9a8a68'),
              ('willow', '#a8844e'), ('wet', '#6e6048')),
    'leather': (('tan', '#8a5a34'), ('dark', '#5a3a22'),
                ('dusty', '#9a7e62'), ('wet', '#4a3020')),
    'food': (('crust', '#b4783a'), ('pale', '#d0aa6a'),
             ('dark', '#7a4a26'), ('dry', '#a88c62')),
    'plant': (('green', '#6f8a45'), ('dry', '#a89a5a'),
              ('dark', '#4a5e30'), ('silver', '#8a9a80')),
    'animal': (('grey', '#9a9ca3'), ('white', '#d0d0cc'),
               ('dark', '#5e6068'), ('brown', '#8a7462')),
    'fire': (('flame', '#d8842c'), ('embers', '#a8401c'),
             ('ash', '#8a8278'), ('glow', '#e8b04a')),
    'wax': (('beeswax', '#d8b45a'), ('pale', '#e4d4a4'),
            ('dark', '#a8843a'), ('aged', '#bca070')),
    'glass': (('clear', '#a8c0c4'), ('smoky', '#7a8a8c'),
              ('amber', '#b8944a'), ('dusty', '#b0aca0')),
    'machine': (('steel', '#6a7078'), ('dark', '#3a3e44'),
                ('pale', '#a0a6ac'), ('oxide', '#6e5a4e')),
}

# Ground that takes a sunk or overgrown thing: sand of the shore and
# the yard; the lake's silt is the same drift in darker light.
SAND = '#b09c74'
GRASS = '#5f7438'
MOSS = '#6a8a3a'

# What may happen to a thing of each material family.
RIGID = {'wood', 'iron', 'copper', 'clay', 'stone', 'glass', 'machine',
         'wax'}
BREAKS = {'wood', 'clay', 'stone', 'glass', 'wax'}
CHIPS = {'wood', 'clay', 'stone', 'glass', 'wax', 'food',
         'fibre', 'leather'}
SOFT = {'fibre', 'leather', 'food'}
LIVING = {'plant', 'animal'}
# Things that are naturally turned over to dry or stored upside down.
UPENDS = {'barrel', 'basket', 'fish-basket', 'sample-basket',
          'well-bucket', 'water-jug', 'karas', 'water-sampler',
          'crucible', 'jeweller-crucible', 'cauldron-camp',
          'cauldron-common', 'fruit-crate', 'bench', 'boat', 'boat-hull'}
# Things that are kept in groups, so a pair or a stack is a real sight.
GROUPS = {'barrel', 'basket', 'fish-basket', 'sample-basket',
          'fruit-crate', 'grain-sack', 'salt-sack', 'spice-sack',
          'silk-bale', 'paper-bale', 'spruce-log', 'bridge-log',
          'firewood', 'bread-loaf', 'bread-table', 'water-jug', 'karas',
          'water-skin', 'kumys-skin', 'stone-pile', 'bench',
          'archive-chest', 'treasury-chest', 'casket', 'rope-coil',
          'cloth', 'felt', 'stakes', 'spade', 'oar', 'tongs', 'tools',
          'screen', 'server-rack', 'keyboard', 'dove', 'herbs',
          'candle-blank', 'wax-bar', 'silver-ingot', 'weights',
          'crucible', 'jeweller-crucible', 'well-bucket', 'boat',
          'water-sampler', 'coin-purse', 'grapes'}

# Things that are stacked or heaped, so a stack or a trio is a real
# sight; tools and single things are only laid side by side.
STACKS = {'barrel', 'fruit-crate', 'grain-sack', 'salt-sack', 'spice-sack',
          'silk-bale', 'paper-bale', 'spruce-log', 'bridge-log',
          'firewood', 'bread-loaf', 'bread-table', 'stone-pile', 'bench',
          'archive-chest', 'treasury-chest', 'casket', 'cloth', 'felt',
          'silver-ingot', 'wax-bar', 'candle-blank', 'basket',
          'fish-basket', 'sample-basket', 'well-bucket'}

SETTINGS = ('any', 'ground')


# --- Deterministic numbers ---------------------------------------------

def unit(*keys):
    return npd.unit(*keys)


def kit_seed(repo, path, piece):
    return hashlib.sha1(f'ludus-location-kit:{repo}:{path}#{piece}'
                        .encode()).hexdigest()


# --- The thing and its painting -------------------------------------------

def _rgb(hexcol):
    return tuple(int(hexcol[i:i + 2], 16) for i in (1, 3, 5))


def normalise(piece):
    """Scale a cut object so its longest side is SIDE pixels.

    Pixel art (a small sprite) is enlarged with nearest-neighbour so its
    pixels stay crisp; a large drawing is resampled smoothly.  The same
    thing, at the same scale, is used for the source and all variants.
    """
    piece = piece.convert('RGBA')
    box = alpha_mask(piece).getbbox()
    piece = piece.crop(box)
    k = SIDE / max(piece.size)
    method = Image.NEAREST if max(piece.size) <= 64 else Image.LANCZOS
    size = (max(1, round(piece.width * k)), max(1, round(piece.height * k)))
    return piece.resize(size, method)


def ramp(base):
    """Four stops from shadow to light around a material colour."""
    r, g, b = _rgb(base)

    def mix(k, white=0.0):
        return tuple(min(255, round(c * k + 255 * white)) for c in (r, g, b))
    return [(0.0, mix(0.32)), (0.45, mix(0.78)), (0.8, mix(1.0)),
            (1.0, mix(0.82, 0.3))]


def relief(alpha):
    """Light from above-left over the form, read from its alpha only.

    A flat heraldic silhouette has no drawing inside; the blurred alpha
    gives it the roundness of a real thing without changing its form.
    """
    radius = max(2, round(min(alpha.size) * 0.06))
    h = alpha.filter(ImageFilter.GaussianBlur(radius))
    up = ImageChops.offset(h, -2, -3)
    shade = Image.new('L', alpha.size, 150)
    shade = ImageChops.add(shade, ImageChops.subtract(up, h), scale=0.35)
    return ImageChops.subtract(shade, ImageChops.subtract(h, up),
                               scale=0.35)


def paint(obj, base):
    """Repaint a thing in a material colour, keeping its drawing.

    The luminance of the source is stretched over the thing's own
    pixels (2nd to 98th percentile), blended with the relief of the
    form (much for a flat source, a little for a drawn one) and mapped
    through the material ramp; the alpha channel is copied unchanged,
    so the form is the source's form.
    """
    alpha = obj.getchannel('A')
    mask = alpha.point(lambda v: 255 if v > 16 else 0)
    grey = ImageOps.grayscale(obj.convert('RGB'))
    hist = grey.histogram(mask)
    total = sum(hist)
    lo, hi = 0, 255
    if total:
        acc, lo_at, hi_at = 0, total * 0.02, total * 0.98
        for level, n in enumerate(hist):
            if acc <= lo_at < acc + n:
                lo = level
            if acc <= hi_at < acc + n:
                hi = level
            acc += n
    span = max(1, hi - lo)
    stretched = grey.point(lambda v: max(0, min(255, round(
        (v - lo) * 255 / span))))
    flat = span < 48
    shade = Image.blend(stretched, relief(mask), 0.75 if flat else 0.3)
    stops = ramp(base)
    table = []
    for level in range(256):
        t = level / 255
        for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
            if t0 <= t <= t1:
                k = (t - t0) / (t1 - t0)
                table.append(tuple(round(a + (b - a) * k)
                                   for a, b in zip(c0, c1)))
                break
    rgb = Image.merge('RGB', [shade.point([c[i] for c in table])
                              for i in range(3)])
    out = rgb.convert('RGBA')
    out.putalpha(alpha)
    return out


# --- Placing on the canvas ---------------------------------------------

def blank():
    return Image.new('RGBA', (CANVAS, CANVAS), (0, 0, 0, 0))


def rotate(obj, angle, pixel_art):
    """Turn a thing in the picture plane; the canvas grows to hold it."""
    if angle % 360 == 0:
        return obj
    method = Image.NEAREST if pixel_art else Image.BICUBIC
    out = obj.rotate(angle, resample=method, expand=True)
    box = alpha_mask(out).getbbox()
    return out.crop(box) if box else out


def put(canvas, obj, cx, bottom):
    """Paste a thing with its bottom-centre at (cx, bottom)."""
    x = round(cx - obj.width / 2)
    y = round(bottom - obj.height)
    layer = blank()
    layer.paste(obj, (x, y), obj)
    return Image.alpha_composite(canvas, layer)


def source_canvas(obj):
    """The source: the thing standing on the floor in the middle."""
    return put(blank(), obj, CANVAS / 2, FLOOR)


# --- Structural changes (on the thing before it is placed) ---------------

def _jagged(points, seed, label, amp):
    """Roughen a polyline: a broken edge is never a ruler line."""
    out = []
    for i, (x, y) in enumerate(points):
        out.append((x + amp * (2 * unit(seed, label, i, 'x') - 1),
                    y + amp * (2 * unit(seed, label, i, 'y') - 1)))
    return out


def chip(obj, seed, corner, size):
    """Cut a piece away at a top corner (corner -1 left, +1 right)."""
    w, h = obj.size
    d = size * min(w, h)
    x0 = 0 if corner < 0 else w
    sx = 1 if corner < 0 else -1
    steps = 7
    edge = [(x0 + sx * d * (1 - i / steps) * (0.9 + 0.2 * unit(
        seed, 'chip', corner, i)), d * i / steps) for i in range(steps + 1)]
    edge = _jagged(edge, seed, f'chip{corner}', max(1.0, d * 0.05))
    poly = [(x0 - sx * 2, -2)] + edge + [(x0 - sx * 2, d + 2)]
    cut = Image.new('L', obj.size, 0)
    ImageDraw.Draw(cut).polygon(poly, fill=255)
    out = obj.copy()
    out.putalpha(ImageChops.subtract(obj.getchannel('A'), cut))
    return out


def split(obj, seed, frac, vertical):
    """Split a thing in two along a slanted, rough line.

    Returns (main, piece): the larger and the smaller part, each cropped
    to its own box.  vertical=True cuts across the width.
    """
    w, h = obj.size
    steps = 9
    tilt = 0.18 * (2 * unit(seed, 'tilt', frac) - 1)
    if vertical:
        line = [(w * frac + tilt * (i / steps - 0.5) * h, h * i / steps)
                for i in range(steps + 1)]
        line = _jagged(line, seed, 'splitv', max(1.0, w * 0.03))
        # The left side: from the top-left corner down the cut line.
        poly = [(-2, -2)] + line + [(-2, h + 2)]
    else:
        line = [(w * i / steps, h * frac + tilt * (i / steps - 0.5) * w)
                for i in range(steps + 1)]
        line = _jagged(line, seed, 'splith', max(1.0, h * 0.03))
        # The top side: from the top-left corner along the cut line.
        poly = [(-2, -2)] + line + [(w + 2, -2)]
    side = Image.new('L', obj.size, 0)
    ImageDraw.Draw(side).polygon(poly, fill=255)
    a = obj.getchannel('A')
    one, two = obj.copy(), obj.copy()
    one.putalpha(ImageChops.multiply(a, side))
    two.putalpha(ImageChops.subtract(a, side))
    parts = []
    for part in (one, two):
        box = alpha_mask(part).getbbox()
        if box:
            parts.append(part.crop(box))
    if len(parts) < 2:
        return None
    parts.sort(key=lambda p: -area(alpha_mask(p)))
    return parts[0], parts[1]


# --- Ground: sand drift, grass, moss ----------------------------------------

def mound(canvas, cx, width, height, seed, label, colour=SAND):
    """A drift of sand on the floor line, rough on top.

    Like grass() and moss(), returns (canvas, mask of what was added),
    so the share of the thing still seen can be measured.
    """
    pts = []
    steps = 16
    for i in range(steps + 1):
        t = i / steps
        x = cx - width / 2 + width * t
        bump = 0.75 + 0.25 * unit(seed, label, i)
        y = FLOOR - height * math.sin(math.pi * t) ** 0.7 * bump
        pts.append((x, y))
    pts += [(cx + width / 2, FLOOR + 1), (cx - width / 2, FLOOR + 1)]
    lay = Image.new('L', (CANVAS, CANVAS), 0)
    ImageDraw.Draw(lay).polygon(pts, fill=255)
    return _paint_mask(canvas, lay, colour, seed, label), lay


def grass(canvas, x0, x1, seed, label, height):
    """Tufts of grass along the floor line."""
    lay = Image.new('L', (CANVAS, CANVAS), 0)
    draw = ImageDraw.Draw(lay)
    n = max(6, int((x1 - x0) / 5))
    for i in range(n):
        x = x0 + (x1 - x0) * (i + unit(seed, label, i, 'x')) / n
        hh = height * (0.5 + 0.5 * unit(seed, label, i, 'h'))
        lean = 6 * (2 * unit(seed, label, i, 'l') - 1)
        draw.polygon([(x - 2, FLOOR), (x + lean, FLOOR - hh), (x + 2, FLOOR)],
                     fill=255)
    return _paint_mask(canvas, lay, GRASS, seed, label), lay


def moss(canvas, seed, label, size):
    """A thin skin of moss along the top edge of what stands.

    The first pass drew round lumps on the top, which read as green
    beads on a rope and a chisel; moss lies flat along the surface, so
    it is a band a few pixels deep that follows the silhouette.
    """
    a = alpha_mask(canvas)
    box = a.getbbox()
    lay = Image.new('L', (CANVAS, CANVAS), 0)
    if not box:
        return canvas, lay
    data = a.tobytes()
    pixels = lay.load()
    for x in range(box[0], box[2]):
        top = next((y for y in range(box[1], box[3])
                    if data[y * CANVAS + x]), None)
        if top is None:
            continue
        # Moss grows in patches: the depth rises and falls smoothly.
        depth = size * (0.25 + 0.75 * unit(seed, label, x // 6))
        for y in range(top, min(box[3], top + round(depth))):
            if data[y * CANVAS + x]:
                pixels[x, y] = 255
    return _paint_mask(canvas, lay, MOSS, seed, label), lay


def _paint_mask(canvas, lay, colour, seed, label):
    part = npd.paint(lay, _rgb(colour), f'{seed}:{label}', speckle=0.12)
    return Image.alpha_composite(canvas, part)


# --- One variant -------------------------------------------------------------

def rest_on(below, top):
    """Lay a thing on top of what stands, touching it, not floating.

    The thing is lowered from above until its silhouette overlaps the
    one below by a few rows of pixels, the way it would settle.
    """
    under = alpha_mask(below)
    box = under.getbbox()
    if box is None:
        return None
    cx = (box[0] + box[2]) / 2
    top_mask = alpha_mask(top)
    need = max(4, area(top_mask) // 40)
    for bottom in range(box[1] + 1, FLOOR + 1):
        if bottom - top.height < 2:
            continue
        probe = Image.new('L', (CANVAS, CANVAS), 0)
        probe.paste(top_mask, (round(cx - top.width / 2),
                               round(bottom - top.height)))
        if area(ImageChops.multiply(probe, under)) >= need:
            return put(below, top, cx, bottom)
    return None


def make(obj, spec, seed, pixel_art):
    """Draw one variant; return (image, own_mask, copies) or None.

    spec: {'pose': angle, 'ops': [...], 'group': None|'pair'|'stack'|
    'trio', ...}; obj is already painted in the variant's state.
    own_mask is the part of the canvas that is the thing itself, so the
    share of it still seen can be measured; copies says how many of the
    thing the variant shows.
    """
    ops = dict(spec['ops'])
    body = obj
    piece = None
    if 'chip' in ops:
        corner, size = ops['chip']
        body = chip(body, seed, corner, size)
    if 'break' in ops:
        frac, across, fall = ops['break']
        # A thing breaks across its length: a tall jug loses its top, a
        # long log breaks into two shorter logs.
        tall = body.height >= body.width
        parts = split(body, seed, frac, vertical=(not tall) == across)
        if parts is None:
            return None
        body, piece = parts
        piece = rotate(piece, fall, pixel_art)
    body = rotate(body, spec['pose'], pixel_art)
    cx = CANVAS / 2
    sink = ops.get('sink', 0.0) * body.height
    group = spec.get('group')
    back = blank()
    copies = 1
    if group in ('pair', 'trio'):
        # The second one stands behind, a spacing of its width away.
        dx, spacing, pose2 = spec['pair']
        other = rotate(obj, pose2, pixel_art)
        shift = dx * spacing * max(body.width, other.width)
        back = put(back, other, cx + shift / 2, FLOOR + sink)
        cx -= shift / 2
        copies = 2
    whole = put(blank(), body, cx, FLOOR + sink)
    if piece is not None:
        side = 1 if unit(seed, 'fall-side', spec['label']) > 0.5 else -1
        px = cx + side * (body.width / 2 + piece.width / 2 + 4)
        whole = put(whole, piece, px, FLOOR + sink)
    whole = Image.alpha_composite(back, whole)
    if group in ('stack', 'trio'):
        # One more lies on top of what stands, resting on it.
        top = rotate(obj, spec.get('top', 0), pixel_art)
        placed = rest_on(whole, top)
        if placed is None:
            return None
        whole = placed
        copies += 1
    canvas = whole
    if sink:
        # Below the floor line the thing is under the sand.
        cut = Image.new('L', (CANVAS, CANVAS), 0)
        ImageDraw.Draw(cut).rectangle([0, 0, CANVAS, FLOOR], fill=255)
        canvas.putalpha(ImageChops.multiply(canvas.getchannel('A'), cut))
    own = alpha_mask(canvas)
    cover = Image.new('L', (CANVAS, CANVAS), 0)
    box = own.getbbox()
    if sink and box:
        width = (box[2] - box[0]) * (1.25 + 0.3 * unit(seed, 'mw',
                                                       spec['label']))
        height = SIDE * (0.07 + 0.04 * unit(seed, 'mh', spec['label']))
        canvas, lay = mound(canvas, (box[0] + box[2]) / 2, width, height,
                            seed, 'mound' + spec['label'])
        cover = ImageChops.lighter(cover, lay)
    if ops.get('overgrow') and box:
        tall = ops['overgrow']
        canvas, lay = grass(canvas, box[0] - 10, box[2] + 10, seed,
                            'grass' + spec['label'], SIDE * 0.1 * tall)
        cover = ImageChops.lighter(cover, lay)
        canvas, lay = moss(canvas, seed, 'moss' + spec['label'],
                           3 + 3 * tall)
        cover = ImageChops.lighter(cover, lay)
    # The thing seen: its own pixels not covered by sand, grass or moss.
    return canvas, ImageChops.subtract(own, cover), copies


# Iron and copper things do not break in two in a room or a yard: the
# first pass broke keys, tongs and chisels into shards that no eye
# could name (docs/HLD_LOCATION_ITEMS_2026-09-30.md), so only wood,
# clay, stone, glass and wax break.
TOOLS_BREAK = set()
# How the one on top of a stack lies: a barrel on its side, a bench
# upside down, a crate or a log as it is.
STACK_TOP = {'barrel': 90, 'bench': 180, 'water-jug': 90, 'karas': 90,
             'basket': 180, 'fish-basket': 180, 'sample-basket': 180,
             'well-bucket': 180}


def pool_specs(key, material, obj):
    """The honest pool of real states of one thing (all combinations).

    Poses by material; structural changes by material; groups only for
    things that are kept in groups.  Every spec has at least one
    structural change or is a group: a pose alone is never a variant.
    The pool is whatever these real states give; it is not padded.
    """
    rigid = material in RIGID
    living = material in LIVING
    poses = [0, 10, -10] if living else [0, 12, -12, 24, -24]
    if material in SOFT:
        poses = [0, 90, -90]
    elif rigid:
        poses += [90, -90]
    if key in UPENDS:
        poses.append(180)
    structs = []
    chips = material in CHIPS
    breaks = material in BREAKS or key in TOOLS_BREAK
    if chips:
        structs += [{'chip': (c, s)} for c in (-1, 1) for s in (0.3, 0.42)]
    if breaks:
        structs += [{'break': (f, True, fall)} for f in (0.3, 0.42)
                    for fall in (35, -70, 90)]
    if material != 'animal':
        structs += [{'sink': d} for d in (0.15, 0.25, 0.35)]
        structs += [{'overgrow': t} for t in (1, 2)]
    if chips:
        structs += [{'chip': (1, 0.36), 'overgrow': 1},
                    {'chip': (-1, 0.36), 'sink': 0.2}]
    if breaks:
        structs += [{'break': (0.38, True, 90), 'sink': 0.15},
                    {'break': (0.38, True, -35), 'overgrow': 1}]
    specs = []
    for pose in poses:
        for st in structs:
            specs.append({'pose': pose, 'ops': sorted(st.items()),
                          'group': None})
    if key in GROUPS:
        second = [0, 12, 90] + ([180] if key in UPENDS else [])
        for dx in (1, -1):
            for spacing in (0.55, 0.95):
                for pose2 in second:
                    specs.append({'pose': 0, 'ops': [], 'group': 'pair',
                                  'pair': (dx, spacing, pose2)})
            specs.append({'pose': 0, 'ops': [('sink', 0.2)],
                          'group': 'pair', 'pair': (dx, 0.75, 90)})
            if key in STACKS:
                specs.append({'pose': 0, 'ops': [], 'group': 'trio',
                              'pair': (dx, 0.95, 0),
                              'top': STACK_TOP.get(key, 0)})
        if key in STACKS:
            for pose in (0, 90):
                specs.append({'pose': pose, 'ops': [], 'group': 'stack',
                              'top': STACK_TOP.get(key, 0)})
            specs.append({'pose': 0, 'ops': [('overgrow', 1)],
                          'group': 'stack', 'top': STACK_TOP.get(key, 0)})
    for i, spec in enumerate(specs):
        spec['label'] = f's{i:03d}'
        spec['soft'] = material in SOFT
        spec['setting'] = ('ground' if any(k in ('sink', 'overgrow')
                                           for k, _ in spec['ops'])
                           else 'any')
    return specs


def describe(spec):
    """Short words for the contact sheet and the meta."""
    words = []
    if spec['pose']:
        words.append({90: 'lies', -90: 'lies', 180: 'upended'}.get(
            spec['pose'], f'leans {spec["pose"]:+d}'))
    for k, v in spec['ops']:
        if k == 'chip':
            words.append('torn' if spec.get('soft') else 'chipped')
        elif k == 'break':
            words.append('broken')
        elif k == 'sink':
            words.append(f'sunk {round(v * 100)}%')
        elif k == 'overgrow':
            words.append('overgrown' if v == 1 else 'in tall grass')
    if spec['group']:
        words.append(spec['group'])
    return ', '.join(words)


def as_saved(img):
    """The variant exactly as its palette PNG will hold it.

    The variants are painted from a few material colours, so 256
    palette entries keep them; the palette file is about a quarter of
    the RGBA one, which the APK budget needs (TABOO 0.011).  Every
    measure is taken on this image, so the numbers are those of the
    file that ships.
    """
    pal = img.quantize(colors=256, method=Image.Quantize.FASTOCTREE,
                       dither=Image.Dither.NONE)
    return pal, pal.convert('RGBA')


def build_kit(piece, key, material, seed, threshold=THRESHOLD):
    """Twelve variants of one source piece.

    Returns a record with the source stats, the pool, the chosen
    variants with their measures and images, and the refused ones by
    reason (nothing is written here).
    """
    pixel_art = max(piece.size) <= 64
    obj = normalise(piece)
    src = source_canvas(obj)
    src_mask = alpha_mask(src)
    src_fill = fill_holes(src_mask)
    own_area = area(alpha_mask(obj))
    states = MATERIAL_STATES[material]
    painted = {name: paint(obj, colour) for name, colour in states}
    specs = pool_specs(key, material, obj)
    made, refused = [], {}

    def refuse(reason):
        refused[reason] = refused.get(reason, 0) + 1

    for i, spec in enumerate(specs):
        # The material state starts where the spec's number points and
        # moves on only if the colour did not change enough, so the kit
        # shows the thing fresh, aged, weathered and wet in turn.
        result, why = None, 'does-not-fit-canvas'
        for k in range(len(states)):
            name = states[(i + k) % len(states)][0]
            out = make(painted[name], spec, seed, pixel_art)
            if out is None:
                why = 'does-not-fit-canvas'
                break
            raw, seen, copies = out
            pal, img = as_saved(raw)
            mask = alpha_mask(img)
            box = mask.getbbox()
            if not box or box[0] <= 0 or box[2] >= CANVAS or box[1] <= 0:
                why = 'does-not-fit-canvas'
                break
            visible = area(seen) / max(1, own_area * copies)
            if visible < VISIBLE_MIN:
                why = 'thing-mostly-hidden'
                break
            fill = fill_holes(mask)
            shape = npd.distance(src_mask, mask, src_fill, fill)
            if shape < threshold:
                why = 'shape-below-threshold'
                break
            colour = colour_change(src, img, src_mask, mask)
            if colour < threshold:
                why = 'colour-below-threshold'
                continue
            result = {'spec': spec, 'state': name, 'img': img, 'pal': pal,
                      'mask': mask, 'fill': fill, 'shape': shape,
                      'colour': colour, 'visible': visible,
                      'hitbox': hitbox(mask)}
            break
        if result is None:
            refuse(why)
            continue
        made.append(result)
    # Greedy choice in a fixed order: variants that fit any room first,
    # then the least changed (the most recognisable), then the label.
    made.sort(key=lambda m: (m['spec']['setting'] != 'any',
                             round(m['shape'], 4), m['spec']['label']))
    chosen, keys = [], set()
    for m in made:
        if len(chosen) == KIT_SIZE:
            break
        key_hb = hitbox_key(m['hitbox'])
        if key_hb in keys:
            refuse('duplicate-hitbox')
            continue
        # Plain 1 - IoU bounds the weighted distance from above, so a
        # pair it already puts under the threshold needs no flood fill.
        close = any(npd.near_enough(m['mask'], c['mask'], threshold) or
                    npd.distance(m['mask'], c['mask'], m['fill'],
                                 c['fill']) < threshold for c in chosen)
        if close:
            refuse('too-close-to-a-sibling')
            continue
        chosen.append(m)
        keys.add(key_hb)
    for m in chosen:
        others = [npd.distance(m['mask'], c['mask'], m['fill'], c['fill'])
                  for c in chosen if c is not m]
        m['sibling_min'] = min(others) if others else 1.0
    return {
        'pixel_art': pixel_art, 'side_px': SIDE,
        'source_px': list(piece.size),
        'pool': {'size': len(specs), 'measured': len(made),
                 'refused': dict(sorted(refused.items())),
                 'chosen': len(chosen)},
        'chosen': chosen, 'source_canvas': src,
    }


# --- Contact sheets ----------------------------------------------------------

# Five backgrounds where the locations stand (TABOO 0.3 rule 59 in the
# terms of the locations): a hearth-lit room (clay wall at about
# 2200 K), a daylit yard, a sandy shore at dusk, an instrument room at
# 6500 K and the lake shallows (LudusLakeView water at 3 m).
BACKGROUNDS = (
    ('room', (74, 52, 36)),
    ('yard', (150, 136, 108)),
    ('shore', (196, 176, 136)),
    ('instrument', (28, 36, 46)),
    ('shallows', (18, 128, 190)),
)


def _font(size):
    for name in ('DejaVuSans.ttf',
                 '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def kit_sheet(title, source, variants, out_path, cell=112):
    """One kit: the source and its variants on the five backgrounds.

    Every tile shows the same square cut of the canvas around the union
    of all the kit's forms, so the things are seen large and at one
    scale, as the eye check needs.
    """
    items = [('src', source)] + variants
    box = None
    for _, img in items:
        b = alpha_mask(img).getbbox()
        if b:
            box = b if box is None else (min(box[0], b[0]),
                                         min(box[1], b[1]),
                                         max(box[2], b[2]),
                                         max(box[3], b[3]))
    box = box or (0, 0, CANVAS, CANVAS)
    side = max(box[2] - box[0], box[3] - box[1]) + 8
    cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
    crop = (round(cx - side / 2), round(cy - side / 2),
            round(cx + side / 2), round(cy + side / 2))
    cols = len(items)
    head = 18
    sheet = Image.new('RGB', (cols * cell, head + len(BACKGROUNDS) * cell
                              + 14), (20, 20, 20))
    draw = ImageDraw.Draw(sheet)
    draw.text((4, 3), title, fill=(230, 230, 230), font=_font(12))
    for r, (name, colour) in enumerate(BACKGROUNDS):
        for c, (label, img) in enumerate(items):
            tile = Image.new('RGBA', (CANVAS, CANVAS), colour + (255,))
            tile = Image.alpha_composite(tile, img.convert('RGBA'))
            sheet.paste(tile.crop(crop).convert('RGB').resize(
                (cell, cell), Image.LANCZOS), (c * cell, head + r * cell))
    for c, (label, _) in enumerate(items):
        draw.text((c * cell + 3, head + len(BACKGROUNDS) * cell),
                  label, fill=(200, 200, 200), font=_font(10))
    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out_path, optimize=True)
    return out_path
