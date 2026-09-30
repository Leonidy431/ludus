"""Twelve variants for neutral lake objects: age and pose, never passion.

The lake pass of 2026-09-30 was reverted because the antagonist variant
family (erosion, swarm, crystal, echo...) turned stones into "vases"
and water plants into blobs.  A neutral thing (fish, stone, plant, wood
or pottery) must stay recognisable, so its twelve variants come only
from what really happens to such a thing on the lake floor:

  age   overgrowth  algae lumps and tufts on the faces turned to light;
        chip        a broken-off piece (rigid things) or bitten edges
                    (fins and leaves);
        silt        the lower part buried, with the drift around it;
        crack       split in two, the halves settled apart;
  pose  bend        curved along the body axis (a fish flexing, a stem
                    in the current), anchored at one end;
        turn        rotated in the picture plane (a fish pitching, a
                    stone rolled over).

Not every operation fits every thing: a living fish does not crack or
grow algae, and a stone does not bend.  CATEGORY_OPS lists what each
slot may use.  The twelve variants are the single operations of the
slot followed by pairs of them, chosen by the seed.

Each variant is measured against the source like any raw object:
shape change = |A xor B| / |A or B| on the alpha masks (form.py), at
least the threshold (35 %), and the result must still pass
reference.fits() for its slot.  The strength of an operation climbs a
fixed ladder and stops at the first rung that satisfies both; if no
rung does, the variant is refused with the measured numbers, never
faked.  Colour comes from the natural palette of the slot (the lake
register), algae and silt from their own register colours.  Alpha is
the only truth of form; luminance is used only to carry the drawing
inside the form into the new palette.  Nothing here is random.

Usage (review only; nothing is shipped):
    python3 scripts/raw_assets/neutral_variants.py \
        --raw build/osint/raw --out build/neutral \
        --sheet docs/audit/2026-09-30/neutral-contact.png
"""

import argparse
import itertools
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

sys.path.insert(0, str(Path(__file__).resolve().parent))

import antagonist as ant  # noqa: E402
from form import (CANVAS, alpha_mask, area, colour_change,  # noqa: E402
                  fill_holes, hitbox, hitbox_key, iou_delta, shape_delta,
                  silhouette_loss)
import reference  # noqa: E402

# What may happen to each kind of thing.  A sign of +1 or -1 picks the
# direction of a pose (up or down, clockwise or not), so two poses of
# the same operation are two different, real positions.
CATEGORY_OPS = {
    # A living fish flexes and pitches, loses bits of fin, and settles
    # into the silt; it neither cracks nor grows algae.
    'fish': (('bend', 1), ('bend', -1), ('turn', 1), ('turn', -1),
             ('chip', 1), ('silt', 1)),
    # A stone is rigid: it rolls, breaks, cracks, grows algae and sinks
    # into silt, but never bends.
    'shelf': (('overgrowth', 1), ('chip', 1), ('silt', 1), ('crack', 1),
              ('turn', 1), ('turn', -1)),
    # A water plant sways, leans, is grazed, fouled and silted; its stem
    # does not crack like stone.
    'plant': (('bend', 1), ('bend', -1), ('turn', 1), ('turn', -1),
              ('overgrowth', 1), ('silt', 1), ('chip', 1)),
    # Wood and pottery are rigid finds: they age like stone.
    'find': (('overgrowth', 1), ('chip', 1), ('silt', 1), ('crack', 1),
             ('turn', 1), ('turn', -1)),
}

# Soft bodies lose small bites along the edge; rigid ones break along a
# fracture plane.
SOFT = {'fish', 'plant'}

# Poses act first, then damage, then growth, then burial: the thing is
# moved, broken, overgrown, and last of all the silt settles on it.
ORDER = ('bend', 'turn', 'crack', 'chip', 'overgrowth', 'silt')

# The strength of each operation climbs this ladder until the variant
# changes enough and is still recognisable.  Fixed, so reproducible.
LADDER = (0.3, 0.45, 0.6, 0.75, 0.9, 1.0)

# Register colours (scripts/lake/lake_objects.py): the silt plain.
SILT = (0x6a, 0x65, 0x5a)

# Five biome backgrounds for the readability check (TABOO 0.3 rule 59).
# The water colours are LudusLakeView.waterColour() with ludus-water.js
# at 3 m (shallows), 75 m (thermocline) and 200 m (deep); night is the
# 3 m colour under moonlight (x0.12); bottom sediment is the silt plain
# of the lake register.
BIOMES = (
    ('shallows', (18, 128, 190)),
    ('thermocline', (4, 9, 57)),
    ('deep', (4, 8, 21)),
    ('night', (2, 15, 23)),
    ('sediment', SILT),
)


# --- Geometry helpers ----------------------------------------------------

def _binary(mask, level=127):
    return mask.point(lambda v: 255 if v > level else 0)


def _centroid(mask):
    """Centre of mass of the opaque pixels; the box centre if empty."""
    data = mask.tobytes()
    sx = sy = n = 0
    for i, flag in enumerate(data):
        if flag:
            sx += i % CANVAS
            sy += i // CANVAS
            n += 1
    if not n:
        return CANVAS / 2, CANVAS / 2
    return sx / n, sy / n


def horizontal(mask):
    """True when the body axis runs left to right (wider than tall)."""
    box = mask.getbbox() or (0, 0, 1, 1)
    return (box[2] - box[0]) >= (box[3] - box[1])


def _with_alpha(img, mask):
    out = img.copy()
    out.putalpha(ImageChops.multiply(img.getchannel('A'), mask))
    return out


# --- The six operations --------------------------------------------------
# Each takes an RGBA image, the slot category, a seed stream, a strength
# in (0, 1] and a sign, and returns a new RGBA image.

def op_bend(img, cat, st, s, sign):
    """Curve the body along its axis, anchored at one end.

    Plants are anchored at the base and lean sideways; a horizontal body
    is anchored at one end and arches up or down.  The image is cut into
    strips across the axis and each strip is moved by d(t) = A t^2,
    which is the shape of a beam fixed at one end.
    """
    mask = alpha_mask(img)
    box = mask.getbbox()
    if box is None:
        return img
    x0, y0, x1, y1 = box
    flat = horizontal(mask) and cat != 'plant'
    length = (x1 - x0) if flat else (y1 - y0)
    amp = sign * 0.42 * length * s
    strips = 32
    mesh = []
    for k in range(strips):
        a, b = k * CANVAS // strips, (k + 1) * CANVAS // strips
        if flat:
            # The anchor sits at the left end for +1, the right for -1,
            # so the two signs are two different real poses.
            ta = min(1.0, max(0.0, (a - x0) / max(1, length)))
            tb = min(1.0, max(0.0, (b - x0) / max(1, length)))
            if sign < 0:
                ta, tb = 1 - ta, 1 - tb
            da, db = abs(amp) * ta * ta, abs(amp) * tb * tb
            da, db = (-da, -db) if sign > 0 else (da, db)
            quad = (a, -da, a, CANVAS - da, b, CANVAS - db, b, -db)
            mesh.append(((a, 0, b, CANVAS), quad))
        else:
            # Plants: t runs from the base (bottom) to the top.
            ta = min(1.0, max(0.0, (y1 - a) / max(1, length)))
            tb = min(1.0, max(0.0, (y1 - b) / max(1, length)))
            da, db = amp * ta * ta, amp * tb * tb
            quad = (-da, a, -db, b, CANVAS - db, b, CANVAS - da, a)
            mesh.append(((0, a, CANVAS, b), quad))
    return img.transform((CANVAS, CANVAS), Image.MESH, mesh,
                         Image.BICUBIC)


def op_turn(img, cat, st, s, sign):
    """Rotate the thing about its centre of mass (never a mirror)."""
    cx, cy = _centroid(alpha_mask(img))
    angle = sign * (6 + 34 * s)
    return img.rotate(angle, Image.BICUBIC, center=(cx, cy))


def _split_line(mask, st, s):
    """A jagged fracture through the centroid, across the long axis."""
    cx, cy = _centroid(mask)
    tilt = math.radians(st.uniform(-20, 20))
    across = horizontal(mask)
    pts = []
    for k in range(-8, 9):
        t = k * CANVAS / 16
        jag = st.uniform(-5, 5) * (0.5 + s)
        if across:
            pts.append((cx + t * math.sin(tilt) + jag, cy + t))
        else:
            pts.append((cx + t, cy + t * math.sin(tilt) + jag))
    return pts, across


def op_crack(img, cat, st, s, sign):
    """Split along a jagged line; the halves settle apart and tilt."""
    mask = alpha_mask(img)
    pts, across = _split_line(mask, st, s)
    side = Image.new('L', mask.size, 0)
    if across:
        poly = [(-CANVAS, -CANVAS)] + pts + [(-CANVAS, 2 * CANVAS)]
    else:
        poly = [(-CANVAS, -CANVAS)] + pts + [(2 * CANVAS, -CANVAS)]
    ImageDraw.Draw(side).polygon(poly, fill=255)
    other = ImageOps.invert(side)
    gap = 6 + 26 * s
    tilt = 3 + 12 * s
    out = Image.new('RGBA', img.size, (0, 0, 0, 0))
    for part, direction in ((side, -1), (other, 1)):
        piece = _with_alpha(img, part)
        pm = alpha_mask(piece)
        if pm.getbbox() is None:
            continue
        pcx, pcy = _centroid(pm)
        # The heavier half stays down; the other settles lower and tilts
        # away from the crack, as a split stone falls apart.
        piece = piece.rotate(direction * tilt, Image.BICUBIC,
                             center=(pcx, pcy))
        dx = direction * gap / 2 if across else 0
        dy = (direction * gap / 2 if not across
              else (gap / 3 if direction > 0 else 0))
        out.alpha_composite(ImageChops.offset(piece, round(dx), round(dy)))
    return out


def _edge_points(mask):
    edge = ImageChops.subtract(mask, mask.filter(ImageFilter.MinFilter(3)))
    data = edge.tobytes()
    return [(i % CANVAS, i // CANVAS) for i, f in enumerate(data) if f]


def op_chip(img, cat, st, s, sign):
    """Break off a piece, or bite the edge of a fin or leaf."""
    mask = alpha_mask(img)
    keep = mask.copy()
    if cat in SOFT:
        # Fins and leaves lose ragged bites along the edge, never a
        # clean half: the body stays whole and readable.
        points = _edge_points(mask)
        draw = ImageDraw.Draw(keep)
        for _ in range(4 + int(10 * s)):
            if not points:
                break
            x, y = st.pick(points)
            r = st.uniform(5, 9 + 10 * s)
            draw.ellipse([x - r, y - r, x + r, y + r], fill=0)
    else:
        # A rigid thing breaks along a fracture plane.  The plane is set
        # so that a share 0.12..0.45 of the body falls away, with a
        # slightly wavy (conchoidal) edge.
        share = 0.12 + 0.33 * s
        phi = st.pick([math.pi * k / 4 for k in range(8)])
        ux, uy = math.cos(phi), math.sin(phi)
        data = mask.tobytes()
        proj = sorted(ux * (i % CANVAS) + uy * (i // CANVAS)
                      for i, f in enumerate(data) if f)
        if not proj:
            return img
        cut = proj[int((1 - share) * (len(proj) - 1))]
        wave = st.uniform(0, 2 * math.pi)
        out = bytearray(data)
        for i, f in enumerate(data):
            if not f:
                continue
            x, y = i % CANVAS, i // CANVAS
            along = -uy * x + ux * y
            if ux * x + uy * y > cut + 4 * math.sin(along / 9 + wave):
                out[i] = 0
        keep = Image.frombytes('L', mask.size, bytes(out))
    return _with_alpha(img, keep)


def _algae_colour():
    """Light-to-dark colours of the lake's plants (register palette)."""
    pal = reference.natural_palette('DEF-058')
    return [c for _, c in pal['stops']]


def op_overgrowth(img, cat, st, s, sign):
    """Grow algae on the faces turned to the light (the upper edges)."""
    mask = alpha_mask(img)
    data = mask.tobytes()
    box = mask.getbbox()
    if box is None:
        return img
    tall = not horizontal(mask)
    points = []
    for x, y in _edge_points(mask):
        above = y - 3
        if above < 0 or not data[above * CANVAS + x]:
            points.append((x, y))
        elif tall:
            # A tall thing is fouled on its sides as well as its top.
            for dx in (-3, 3):
                nx = x + dx
                if 0 <= nx < CANVAS and not data[y * CANVAS + nx]:
                    points.append((x, y))
                    break
    growth = Image.new('L', mask.size, 0)
    draw = ImageDraw.Draw(growth)
    # On a leaf or a fin the fouling is a fine film of epiphytes; big
    # lumps turned the first plants into bunches of green balls on the
    # contact sheet, so soft bodies get small lumps and more tufts.
    lump = 3 + 3 * s if cat in SOFT else 6 + 12 * s
    for _ in range(12 + int(40 * s)):
        if not points:
            break
        x, y = st.pick(points)
        r = st.uniform(2 if cat in SOFT else 3, lump)
        oy = -r * 0.6 if not tall else 0
        draw.ellipse([x - r, y + oy - r, x + r, y + oy + r], fill=255)
    for _ in range((16 if cat in SOFT else 6) + int(10 * s)):
        if not points:
            break
        x, y = st.pick(points)
        # Tufts of filament algae stand up into the water.
        h = st.uniform(6, 10 + 22 * s)
        lean = st.uniform(-5, 5)
        draw.line([(x, y), (x + lean, y - h)], fill=255, width=3)
    growth = _binary(growth)
    cols = _algae_colour()
    shade = Image.linear_gradient('L').resize(mask.size)
    lut = ant._lut([(0.0, cols[1]), (0.6, cols[2]), (1.0, cols[0])])
    algae = Image.merge('RGB', [shade.point(ch) for ch in lut])
    algae = algae.convert('RGBA')
    algae.putalpha(growth)
    out = img.copy()
    out.alpha_composite(algae)
    return out


def op_silt(img, cat, st, s, sign):
    """Bury the lower part and heap the drift around it."""
    mask = alpha_mask(img)
    box = mask.getbbox()
    if box is None:
        return img
    x0, y0, x1, y1 = box
    # At most half the thing goes under: a stone buried deeper than
    # that reads as a mound of silt, not as a stone.
    share = 0.12 + 0.38 * s
    line = y1 - share * (y1 - y0)
    keep = Image.new('L', mask.size, 0)
    ImageDraw.Draw(keep).rectangle([0, 0, CANVAS, line], fill=255)
    out = _with_alpha(img, keep)
    # The drift: a low mound a little wider than the thing, its crest
    # just above the burial line, flat below.
    half = (x1 - x0) * (0.55 + 0.15 * s)
    cx = (x0 + x1) / 2
    crest = 4 + 8 * s
    drift = Image.new('L', mask.size, 0)
    draw = ImageDraw.Draw(drift)
    draw.ellipse([cx - half, line - crest, cx + half, line + crest * 2],
                 fill=255)
    draw.rectangle([cx - half * 0.8, line, cx + half * 0.8,
                    min(CANVAS - 1, line + crest * 2)], fill=255)
    grain = ant._noise(f'silt:{st.seed}').point(lambda v: 90 + v // 4)
    silt = Image.merge('RGB', [grain.point(
        lambda v, c=c: min(255, c * v // 128)) for c in SILT])
    silt = silt.convert('RGBA')
    silt.putalpha(drift)
    out.alpha_composite(silt)
    return out


OPS = {'bend': op_bend, 'turn': op_turn, 'crack': op_crack,
       'chip': op_chip, 'overgrowth': op_overgrowth, 'silt': op_silt}


# --- Building the twelve -------------------------------------------------

def recipes(category, seed):
    """The twelve recipes of a slot: singles first, then seeded pairs.

    A pair joins two different operations; the pairs are ordered by a
    hash of the seed, so each object gets its own mix, reproducibly.
    """
    singles = [[op] for op in CATEGORY_OPS[category]]
    pairs = [list(p) for p in itertools.combinations(CATEGORY_OPS[category],
                                                     2)
             if p[0][0] != p[1][0]]
    st = ant.SeedStream(seed, 'neutral-pairs')
    pairs.sort(key=lambda p: (st.unit(), str(p)))
    chosen = (singles + pairs)[:12]
    return [sorted(r, key=lambda o: ORDER.index(o[0])) for r in chosen]


def recipe_name(recipe):
    return '+'.join(op if sign > 0 else f'{op}-' for op, sign in recipe)


def natural_redraw(canvas, palette):
    """The source drawing carried into the natural palette of its slot.

    Grey level only chooses the colour; the alpha is copied unchanged,
    so the form of the base is exactly the source form.
    """
    gray = ImageOps.grayscale(canvas.convert('RGB'))
    lut = ant._lut(palette['stops'])
    toned = Image.merge('RGB', [gray.point(ch) for ch in lut])
    out = toned.convert('RGBA')
    out.putalpha(canvas.getchannel('A'))
    return out


def apply(base, category, recipe, seed, label, strength):
    img = base
    for op, sign in recipe:
        st = ant.SeedStream(seed, f'{label}:{op}:{sign}')
        img = OPS[op](img, category, st, strength, sign)
    return img


def build(canvas, slot, seed, threshold=0.35):
    """Make and judge the twelve neutral variants of one source piece.

    Returns (variants, rejected, images).  A variant enters `variants`
    only when its shape change reaches the threshold and its silhouette
    still fits the real-object profile of the slot; otherwise its best
    measurement goes to `rejected` with the reason.
    """
    prof = reference.PROFILES[slot]
    category = prof['category']
    palette = reference.natural_palette(slot)
    src_mask = alpha_mask(canvas)
    filled = fill_holes(src_mask)
    base = natural_redraw(canvas, palette)
    variants, rejected, images, keys = [], [], {}, set()
    for n, recipe in enumerate(recipes(category, seed), 1):
        slot_name = f'v{n:02d}'
        best = None
        for strength in LADDER:
            img = apply(base, category, recipe, seed, slot_name, strength)
            mask = alpha_mask(img)
            like, stats = reference.fits(slot, mask)
            record = {
                'slot': slot_name, 'kind': recipe_name(recipe),
                'ops': [{'op': op, 'sign': sign} for op, sign in recipe],
                'strength': strength,
                'shape_change': round(shape_delta(src_mask, mask, filled),
                                      4),
                'iou_change': round(iou_delta(src_mask, mask), 4),
                'colour_change': round(colour_change(canvas, img, src_mask,
                                                     mask), 4),
                'silhouette_loss': round(silhouette_loss(src_mask, mask),
                                         4),
                'fits_reference': like, 'reference_stats': stats,
                'hitbox': hitbox(mask),
            }
            if like and (best is None
                         or record['shape_change'] > best['shape_change']):
                best = record
            if (like and record['shape_change'] >= threshold
                    and hitbox_key(record['hitbox']) not in keys):
                keys.add(hitbox_key(record['hitbox']))
                variants.append(record)
                images[slot_name] = img
                break
        else:
            if best is None:
                rejected.append({'slot': slot_name,
                                 'kind': recipe_name(recipe),
                                 'reason': 'unlike-real-object-at-every-'
                                           'strength'})
            else:
                rejected.append({**best,
                                 'reason': 'below-threshold-while-'
                                           'recognisable'})
    return variants, rejected, images


def test_fish():
    """Our own side-view dace, for tests and the review sheet only.

    The raw pool of 2026-09-30 holds no fish larger than 7 px (bevy
    props) outside editor test folders, so the fish poses could not be
    shown on raw material.  This drawing follows the proportions of the
    Issyk-Kul dace in the lake register (aspect about 4) and is never
    shipped: it is labelled as our own on the sheet.
    """
    img = Image.new('RGBA', (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    body = (0xb9, 0xc4, 0xc9, 255)
    draw.ellipse([40, 104, 196, 150], fill=body)
    draw.polygon([(188, 127), (228, 100), (220, 127), (228, 154)],
                 fill=body)
    draw.polygon([(100, 108), (124, 88), (136, 108)], fill=body)
    draw.polygon([(110, 146), (124, 162), (132, 146)], fill=body)
    draw.ellipse([56, 118, 66, 128], fill=(20, 20, 24, 255))
    draw.line([(80, 128), (180, 128)], fill=(120, 130, 136, 255), width=2)
    return img


# --- Contact sheet -------------------------------------------------------

def contact_sheet(rows, out_path, cell=96):
    """Every object on the five biome backgrounds, with its numbers.

    rows: list of (label, source RGBA, [(slot, RGBA or None, text)]).
    Each object takes five lines, one per biome; the first column is the
    source, then the variants with their measured shape change, so the
    eye check and the measurement sit side by side.
    """
    cols = 1 + max((len(r[2]) for r in rows), default=12)
    head = 18
    width = 120 + cols * cell
    height = sum(head + len(BIOMES) * cell for _ in rows) or cell
    sheet = Image.new('RGB', (width, height), (24, 24, 24))
    draw = ImageDraw.Draw(sheet)
    y = 0
    for label, source, cells in rows:
        draw.text((4, y + 3), label, fill=(230, 230, 230))
        y += head
        for biome, colour in BIOMES:
            draw.rectangle([0, y, width, y + cell - 1], fill=colour)
            draw.text((4, y + cell // 2 - 6), biome, fill=(240, 240, 240))
            items = [('src', source, 'source')] + list(cells)
            for k, (slot, img, text) in enumerate(items):
                x = 120 + k * cell
                if img is not None:
                    thumb = img.resize((cell - 8, cell - 8), Image.LANCZOS)
                    sheet.paste(thumb, (x + 4, y + 2), thumb)
                draw.text((x + 3, y + cell - 12), f'{slot} {text}',
                          fill=(255, 255, 255))
            y += cell
    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out_path, optimize=True)
    return out_path


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--raw', default='build/osint/raw')
    parser.add_argument('--out', default='build/neutral')
    parser.add_argument('--sheet',
                        default='docs/audit/2026-09-30/neutral-contact.png')
    parser.add_argument('--threshold', type=float, default=0.35)
    parser.add_argument('--per-sheet', type=int, default=8)
    parser.add_argument('--test-fish', action='store_true',
                        help='add our own test fish (review only)')
    args = parser.parse_args(argv)

    # Imported here because transform.py imports this module.
    import transform

    manifest = json.loads(
        (Path(args.raw) / 'manifest.json').read_text(encoding='utf-8'))
    if args.test_fish:
        manifest.append({'slot': 'DEF-056', 'repo': 'own-drawing',
                         'path': 'neutral_variants.test_fish()',
                         'local': None, 'license': 'own (test only)'})
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    report, rows = [], []
    for item in manifest:
        if item['local'] is None:
            pieces = [test_fish()]
            item['local'] = 'own.png'
        else:
            pieces = None
        slot = item.get('slot')
        if slot not in reference.PROFILES or not item['local'].endswith(
                '.png'):
            continue
        if pieces is None:
            src = Image.open(item['local'])
            src.load()
            pieces = transform.slice_sheet(src, args.per_sheet)
            if not pieces:
                print(f'{slot} {item["path"]}: no piece of at least 12 px')
        for index, piece in enumerate(pieces):
            canvas = transform.place_on_canvas(piece)
            like, stats = reference.fits(slot, alpha_mask(canvas))
            if not like:
                print(f'{slot} {item["path"]} #{index}: source unlike the '
                      f'real object {stats}')
                continue
            seed = ant.object_seed(item['repo'], item['path'], index)
            variants, rejected, images = build(canvas, slot, seed,
                                               args.threshold)
            oid = f'obj_{seed[:10]}'
            for name, img in images.items():
                img.save(out / f'{oid}_{name}.png', optimize=True)
            canvas.save(out / f'{oid}.source.png', optimize=True)
            report.append({'id': oid, 'slot': slot, 'path': item['path'],
                           'repo': item['repo'], 'piece': index,
                           'license': item.get('license'),
                           'reference': stats, 'variants': variants,
                           'rejected': rejected,
                           'status': ('ok' if len(variants) == 12
                                      else 'shortfall')})
            cells = []
            for n in range(1, 13):
                slot_name = f'v{n:02d}'
                rec = next((v for v in variants if v['slot'] == slot_name),
                           None)
                bad = next((v for v in rejected if v['slot'] == slot_name),
                           None)
                if rec:
                    text = f'{rec["shape_change"]:.0%}'
                elif bad and 'shape_change' in bad:
                    text = f'NO {bad["shape_change"]:.0%}'
                else:
                    text = 'NO'
                cells.append((slot_name, images.get(slot_name), text))
            rows.append((f'{slot} {reference.PROFILES[slot]["name"]} '
                         f'{oid} {item["path"]} #{index} '
                         f'({len(variants)}/12)', canvas, cells))
            print(f'{slot} {item["path"]} #{index}: {len(variants)}/12 '
                  f'variants, shapes '
                  f'{[v["shape_change"] for v in variants]}')
    (out / 'report.json').write_text(
        json.dumps(report, ensure_ascii=False, indent=1), 'utf-8')
    if rows:
        contact_sheet(rows, args.sheet)
        print(f'contact sheet -> {args.sheet}')
    return report


if __name__ == '__main__':
    main()
