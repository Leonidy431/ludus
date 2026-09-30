"""Transform raw third-party images into Ludus art and measure the change.

Step two of the raw-material pipeline (CLAUDE.md, TABOO 0.4).  Each
object cut from a sheet is first re-drawn in the project's gold tone on
a transparent background.  Alpha is the only truth of form, so that
redraw keeps the source silhouette exactly: it is a recolour, and a
recolour never passes the 35 % shape rule.  Such an object is replaced
by an Antagonist (one of the eight passions, see antagonist.py), drawn
in twelve variants that each must differ from the source silhouette by
at least the threshold.

The threshold is an internal technology rule.  It is not a legal safe
harbour: the licence of every source is still recorded, and attribution
and share-alike duties still apply (see THIRD_PARTY_NOTICES.md).

Usage:
    python3 scripts/raw_assets/transform.py --raw build/raw \
        --out build/derived --threshold 0.35
"""

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter, ImageOps

sys.path.insert(0, str(Path(__file__).resolve().parent))

import antagonist as ant  # noqa: E402
from form import (CANVAS, alpha_mask, colour_change, fill_holes,  # noqa
                  hitbox, hitbox_key, iou_delta, shape_delta,
                  silhouette_loss)
import neutral_variants  # noqa: E402
import passion_fields  # noqa: E402
import reference  # noqa: E402

# Palette stops copied from public/ludus/art so the plain redraw sits in
# the same visual family as the project's own drawings.
PALETTE = [
    (0.00, (0x1a, 0x0e, 0x04)),
    (0.35, (0x2a, 0x18, 0x08)),
    (0.60, (0x8a, 0x6a, 0x34)),
    (0.80, (0xc8, 0xa5, 0x6a)),
    (1.00, (0xe8, 0xc8, 0x7a)),
]

# A transform that is not a deliberate erosion may lose at most this
# share of the source's opaque pixels; more means the form was damaged
# (the old luminance mask erased dark sprites this way).
SILHOUETTE_LOSS_LIMIT = 0.05
SILHOUETTE_ERROR = 'Alpha_Silhouette_Error'

# How many replacement hybrids one rejected slot may try before the
# shortfall is reported.
REPLACEMENT_TRIES = 6


def gaps(profile):
    """Return (start, end) runs where the alpha profile is non-empty."""
    runs, start = [], None
    for i, value in enumerate(profile + [0]):
        if value and start is None:
            start = i
        elif not value and start is not None:
            runs.append((start, i))
            start = None
    return runs


def solid_alpha(img):
    """Return the image with an alpha that ignores faint and key pixels.

    Sheets often carry near-invisible pixels (alpha 1-16) between cells,
    and some (BrogueCE glyph atlas) use an opaque background colour
    instead of transparency.  That key colour is removed by the largest
    per-channel distance, not by grey level, so a dark-blue pixel on a
    black key is kept as firmly as a white one.
    """
    rgba = img.convert('RGBA')
    orig = rgba.getchannel('A')
    keep = orig.point(lambda v: 255 if v > 16 else 0)
    corner = rgba.getpixel((0, 0))
    if corner[3] > 16:
        key = Image.new('RGBA', rgba.size, corner)
        diff = ImageChops.difference(rgba, key).convert('RGB').split()
        dist = ImageChops.lighter(ImageChops.lighter(diff[0], diff[1]),
                                  diff[2])
        keep = ImageChops.multiply(
            keep, dist.point(lambda v: 255 if v > 12 else 0))
    # Soft edges keep their own alpha; only dust and key pixels go.
    rgba.putalpha(ImageChops.multiply(orig, keep))
    return rgba


def slice_sheet(img, max_pieces, min_side=12, depth=0):
    """Split a sprite sheet into single objects by transparent gaps.

    A recursive XY-cut is enough for the grid-like sheets these games use,
    and it keeps one object per derived file, which the claim sheet needs.
    """
    img = solid_alpha(img) if depth == 0 else img
    box = alpha_mask(img).getbbox()
    if box is None:
        return []
    img = img.crop(box)
    alpha = alpha_mask(img)
    w, h = img.size
    data = alpha.tobytes()
    rows = [any(data[y * w:(y + 1) * w]) for y in range(h)]
    cols = [any(data[y * w + x] for y in range(h)) for x in range(w)]
    row_runs, col_runs = gaps(rows), gaps(cols)
    if depth > 3 or (len(row_runs) == 1 and len(col_runs) == 1):
        return [img] if min(w, h) >= min_side else []
    pieces = []
    for y0, y1 in row_runs:
        for x0, x1 in col_runs:
            part = img.crop((x0, y0, x1, y1))
            pieces += slice_sheet(part, max_pieces, min_side, depth + 1)
            if len(pieces) >= max_pieces:
                return pieces[:max_pieces]
    return pieces


def place_on_canvas(img):
    """Fit the source onto the common square canvas, keeping its alpha.

    Small sprites are enlarged with nearest-neighbour scaling so the
    object, not the empty background, fills the frame.  The background
    stays transparent: an opaque fill would make the canvas itself part
    of the form.
    """
    img = img.convert('RGBA')
    side = CANVAS - 48
    scale = side / max(img.size)
    img = img.resize((max(1, round(img.width * scale)),
                      max(1, round(img.height * scale))), Image.NEAREST)
    canvas = Image.new('RGBA', (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.paste(img, ((CANVAS - img.width) // 2,
                       (CANVAS - img.height) // 2))
    return canvas


def palette_lut():
    """Build per-channel lookups from grey level to the gold gradient."""
    table = []
    for level in range(256):
        t = level / 255
        for (t0, c0), (t1, c1) in zip(PALETTE, PALETTE[1:]):
            if t0 <= t <= t1:
                k = (t - t0) / (t1 - t0) if t1 > t0 else 0
                table.append(tuple(round(a + (b - a) * k)
                                   for a, b in zip(c0, c1)))
                break
    return [[c[i] for c in table] for i in range(3)]


LUT = palette_lut()


def redraw(canvas):
    """Re-draw the object in the Ludus gold tone on transparency.

    Grey level chooses only the colour.  The alpha channel is copied
    unchanged, so the form is exactly the source form and a dark pixel
    stays as opaque as a white one.
    """
    gray = ImageOps.grayscale(canvas.convert('RGB'))
    toned = Image.merge('RGB', [gray.point(ch) for ch in LUT])
    mask = alpha_mask(canvas)
    rim = ImageChops.subtract(mask, mask.filter(ImageFilter.MinFilter(3)))
    toned.paste(PALETTE[-1][1], (0, 0), rim)
    out = toned.convert('RGBA')
    out.putalpha(canvas.getchannel('A'))
    return out


def measure(src_img, src_mask, filled_src, img):
    """Shape, colour and hitbox of one result against the source."""
    mask = alpha_mask(img)
    return mask, {
        'shape_change': round(shape_delta(src_mask, mask, filled_src), 4),
        'iou_change': round(iou_delta(src_mask, mask), 4),
        'colour_change': round(colour_change(src_img, img, src_mask, mask),
                               4),
        'silhouette_loss': round(silhouette_loss(src_mask, mask), 4),
        'hitbox': hitbox(mask),
    }


def check_silhouette(stats, deliberate):
    """Return the named error when a non-erosion transform lost form."""
    if deliberate:
        return None
    if stats['silhouette_loss'] > SILHOUETTE_LOSS_LIMIT:
        return (f'{SILHOUETTE_ERROR}: {stats["silhouette_loss"]:.1%} of '
                f'the source silhouette vanished (limit '
                f'{SILHOUETTE_LOSS_LIMIT:.0%})')
    return None


class VariantBuilder:
    """Make, measure, amplify and accept the twelve variants."""

    def __init__(self, seed, palette, texture, src_img, src_mask,
                 threshold):
        self.seed, self.palette, self.texture = seed, palette, texture
        self.src_img, self.src_mask = src_img, src_mask
        self.filled_src = fill_holes(src_mask)
        self.threshold = threshold
        self.accepted, self.rejected, self.keys = [], [], set()

    def render(self, mask, style, alpha=None):
        img = ant.paint(mask, self.palette, self.texture, self.seed, style)
        if alpha is not None:
            img.putalpha(alpha)
        return img

    def make(self, kind, strength, base, label):
        """Build one candidate; returns (img, meta) or None."""
        st = ant.SeedStream(self.seed, f'{label}:{strength}')
        if kind == 'reference':
            return self.render(base['mask'], 'body'), {}
        if kind == 'hybrid':
            pool = [v for v in self.accepted if v['slot'] != 'v01']
            made = ant.hybrid(pool, st)
            if made is None:
                return None
            mask, style, extra = made
            return self.render(mask, style), extra
        mask, style, alpha, extra = ant.VARIANT_OPS[kind](
            base['mask'], st, strength)
        return self.render(mask, style, alpha), extra

    def attempt(self, slot, kind, base, label):
        """Try a kind at strength 1, then once amplified; judge it."""
        record = None
        for strength in (1, 2):
            made = self.make(kind, strength, base, label)
            if made is None:
                return None, {'slot': slot, 'kind': kind,
                              'reason': 'hybrid-pool-too-small'}
            img, extra = made
            mask, stats = measure(self.src_img, self.src_mask,
                                  self.filled_src, img)
            record = {'slot': slot, 'kind': kind, 'amplified': strength > 1,
                      **extra, **stats}
            if stats['shape_change'] >= self.threshold:
                break
        if not stats['hitbox']['area']:
            record['reason'] = 'empty-form'
        elif stats['shape_change'] < self.threshold:
            record['reason'] = 'shape-below-threshold-after-amplify'
        elif ant_key(stats) in self.keys:
            record['reason'] = 'duplicate-hitbox'
        else:
            return (img, mask), record
        return None, record

    def run(self, reference_mask):
        """Fill all twelve slots; a rejected slot gets hybrid retries."""
        base = {'mask': reference_mask}
        images = {}
        deferred = []
        for slot, kind in ant.VARIANTS:
            if kind == 'reference':
                # The reference form already carries the amplification
                # decided by the caller, so it is judged once.
                img = self.render(reference_mask, 'body')
                mask, stats = measure(self.src_img, self.src_mask,
                                      self.filled_src, img)
                made, record = (img, mask), {'slot': slot, 'kind': kind,
                                             'amplified': False, **stats}
                if stats['shape_change'] < self.threshold:
                    record['reason'] = 'shape-below-threshold-after-amplify'
                    made = None
            else:
                made, record = self.attempt(slot, kind, base, slot)
            if made:
                self.accept(slot, made, record, images)
            else:
                self.rejected.append(record)
                deferred.append(slot)
        for slot in deferred:
            for n in range(1, REPLACEMENT_TRIES + 1):
                made, record = self.attempt(slot, 'hybrid', base,
                                            f'{slot}-replacement-{n}')
                record['replaces'] = slot
                if made:
                    self.accept(slot, made, record, images)
                    break
                self.rejected.append(record)
        self.accepted.sort(key=lambda v: v['slot'])
        return images

    def accept(self, slot, made, record, images):
        img, mask = made
        self.keys.add(ant_key(record))
        images[slot] = img
        self.accepted.append({**record, 'mask': mask})


def ant_key(stats):
    return hitbox_key(stats['hitbox'])


def reference_form(passion, src_mask, seed, threshold, src_img):
    """Deform the source into the passion's form, amplifying if needed."""
    filled = fill_holes(src_mask)
    best = None
    for strength in (1, 2, 3):
        st = ant.SeedStream(seed, f'passion:{passion}')
        mask = ant.SHAPES[passion](src_mask, st, strength)
        delta = shape_delta(src_mask, mask, filled)
        best = (mask, strength, delta)
        if delta >= threshold:
            break
    return best


def process_piece(item, index, piece, threshold=0.35):
    """Run one cut object through redraw, antagonist and variants.

    Returns (record, images) where images maps file names to RGBA
    images; nothing is written here, so tests can run in memory.
    """
    seed = ant.object_seed(item['repo'], item['path'], index)
    oid = seed[:10]
    canvas = place_on_canvas(piece)
    src_mask = alpha_mask(canvas)
    record = {
        'id': oid, 'seed': seed, 'piece': index,
        'source': {'repo': item['repo'], 'path': item['path'],
                   'commit': item['commit'], 'piece': index},
        'repo': item['repo'], 'path': item['path'],
        'commit': item['commit'], 'license': item['license'],
        'license_file': item.get('license_file'),
        'threshold': threshold,
    }
    images = {f'review/{oid}.source.png': canvas}

    # Step 1: the plain redraw.  It must keep the form; if it does not,
    # the object stops here with the named error.
    plain = redraw(canvas)
    _, stats = measure(canvas, src_mask, fill_holes(src_mask), plain)
    stats.pop('hitbox')
    record['redraw'] = stats
    error = check_silhouette(stats, deliberate=False)
    if error:
        record['status'] = 'error'
        record['error'] = SILHOUETTE_ERROR
        record['error_detail'] = error
        return record, images
    recolour = stats['shape_change'] < threshold
    record['redraw']['is_recolour'] = recolour

    # Step 2: a recolour is replaced by the passion it serves -- but only
    # in a passion slot.  A neutral slot (fish, stones, wood of the lake)
    # needs the thing itself, so there it is not turned into an
    # antagonist (round 1 of 2026-09-30 made
    # passions out of a jellyfish and pikemen for the fish slot).
    feat = ant.source_features(piece, canvas, src_mask, item['path'])
    natural = item.get('neutral') and item.get('slot') in reference.PROFILES
    if item.get('neutral') and not natural:
        # A neutral slot without a real-object profile has no natural
        # palette and no way to check the thing stays recognisable; the
        # hourly pass of 2026-09-30 turned grass into magenta shapes that
        # way.  Such a slot waits for its profile.
        record['status'] = 'unlike-real-object'
        record['reference'] = {'slot': item.get('slot'),
                               'reason': 'no-real-object-profile'}
        return record, images
    if natural:
        # Operator, 2026-09-30: "изучи на реальных объектах".  A neutral
        # piece must first look like the real thing of its slot; a
        # diamond or a letter in the fish slot stops here.
        like, shape = reference.fits(item['slot'], src_mask)
        record['reference'] = {'slot': item['slot'], **shape,
                               'profile': reference.PROFILES[item['slot']]}
        if not like:
            record['status'] = 'unlike-real-object'
            return record, images
    if recolour and item.get('neutral'):
        # The thing stays itself: no passion, and the twelve variants
        # below must each reshape it by at least the threshold, measured
        # against the source like every other object.
        passion, reason = None, 'neutral slot: reshaped by the variants'
        prefix = f'obj_{oid}'
    elif recolour:
        passion, reason = ant.choose_passion(feat)
        prefix = f'ant_{passion}_{oid}'
    else:
        passion, reason = None, 'redraw already reshaped'
        prefix = f'obj_{oid}'
    if natural:
        # The thing keeps its own nature: the natural palette of its slot
        # and its own texture, never a passion's inverted ones.
        palette = reference.natural_palette(item['slot'])
        texture = 'smooth' if ant.texture_mode(feat) == 'rough' else 'rough'
    else:
        palette = ant.antagonist_palette(feat, passion or 'vainglory')
        texture = ant.texture_mode(feat)
    record.update({
        'name': prefix, 'passion': passion, 'passion_reason': reason,
        'features': feat,
        'behaviour': ant.behaviour(passion) if passion else None,
        'palette': {'hue': palette['hue'], 'basis': palette['basis'],
                    'stops': ['#%02x%02x%02x' % c
                              for _, c in palette['stops']]},
        'texture': ({'source': texture, 'result': texture} if natural
                    else {'source': ('smooth' if texture == 'rough'
                                     else 'rough'),
                          'antagonist': texture}),
    })
    if passion:
        ref_mask, strength, _ = reference_form(
            passion, src_mask, seed, threshold, canvas)
        record['reference_strength'] = strength
    else:
        ref_mask = alpha_mask(plain)

    # Step 3: twelve variants, each measured against the source.  A
    # neutral thing of the lake gets the age-and-pose family of
    # neutral_variants.py: the antagonist family (erosion, swarm, echo)
    # turned its stones into vases on 2026-09-30.
    tag = passion or 'none'
    variants = []
    if natural and not passion:
        accepted, rejected, made = neutral_variants.build(
            canvas, item['slot'], seed, threshold)
        record['variant_family'] = 'neutral-age-pose'
    else:
        builder = VariantBuilder(seed, palette, texture, canvas, src_mask,
                                 threshold)
        made = builder.run(ref_mask)
        accepted, rejected = builder.accepted, builder.rejected
    for v in accepted:
        v.pop('mask', None)
        v['file'] = f'{prefix}_{v["slot"]}.png'
        v['analytics_id'] = f'ludus.variant.{tag}.{oid}.{v["slot"]}'
        images[v['file']] = made[v['slot']]
        variants.append(v)
    record['variants'] = variants
    record['rejected_variants'] = rejected
    record['shortfall'] = 12 - len(variants)
    record['status'] = 'ok' if len(variants) == 12 else 'shortfall'
    first = variants[0] if variants else {}
    record['file'] = first.get('file')
    record['shape_change'] = min((v['shape_change'] for v in variants),
                                 default=0.0)
    record['colour_change'] = first.get('colour_change', 0.0)
    record['claim_features'] = claim_features(record)
    return record, images


def claim_features(rec):
    """List the essential features used in the object's claim text."""
    shapes = [v['shape_change'] for v in rec['variants']] or [0.0]
    passion = rec['passion'] or 'none'
    beh = rec['behaviour'] or {}
    if 'reference' in rec:
        ref = rec['reference']
        return [
            f'нейтральный объект слота {ref["slot"]} '
            f'({ref["profile"]["name"]}): силуэт источника сверен с '
            f'профилем реального объекта (соотношение сторон '
            f'{ref["aspect"]}, заполнение {ref["fill"]})',
            f'природная палитра {rec["palette"]["basis"]} (тон '
            f'{rec["palette"]["hue"]}°), фактура источника сохранена',
            f'{len(rec["variants"])} вариантов с попарно различными '
            f'хитбоксами',
            f'изменение формы по альфа-маскам (|A xor B| / |A or B|): '
            f'от {min(shapes):.1%} до {max(shapes):.1%}',
            f'источник: {rec["repo"]} @ {rec["commit"][:10]}, '
            f'{rec["path"]} #{rec["piece"]} ({rec["license"]})',
        ]
    return [
        f'форма-антагонист страсти «{passion}» (по Евагрию и Иоанну '
        f'Лествичнику), выведенная из альфа-силуэта источника',
        f'палитра {rec["palette"]["basis"]} (тон '
        f'{rec["palette"]["hue"]}°) и инверсия фактуры '
        f'{rec["texture"]["source"]} -> {rec["texture"]["antagonist"]}',
        f'инвертированное поведение {beh.get("source_role")} -> '
        f'{beh.get("antagonist")}; {len(rec["variants"])} вариантов с '
        f'попарно различными хитбоксами',
        f'изменение формы по альфа-маскам (|A xor B| / |A or B|): '
        f'от {min(shapes):.1%} до {max(shapes):.1%}',
        f'источник: {rec["repo"]} @ {rec["commit"][:10]}, '
        f'{rec["path"]} #{rec["piece"]} ({rec["license"]})',
    ]


def write_object(out, record, images):
    """Save images and the per-sprite meta next to them."""
    for name, img in images.items():
        path = out / name
        path.parent.mkdir(parents=True, exist_ok=True)
        img.save(path, optimize=True)
    if record.get('name'):
        meta = {k: v for k, v in record.items() if k != 'local'}
        # Rule 13: an antagonist ships with its teaching fields.
        passion_fields.enrich(meta)
        (out / f'{record["name"]}.json').write_text(
            json.dumps(meta, ensure_ascii=False, indent=2), encoding='utf-8')


FRAME_DUP_IOU = 0.85


def frame_mask(piece):
    """Alpha silhouette of a piece on a small fixed grid for comparison."""
    alpha = piece.convert('RGBA').getchannel('A').resize((32, 32))
    return [v > 16 for v in alpha.tobytes()]


def mask_iou(a, b):
    inter = sum(x and y for x, y in zip(a, b))
    union = sum(x or y for x, y in zip(a, b)) or 1
    return inter / union


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--raw', default='build/raw')
    parser.add_argument('--out', default='build/derived')
    parser.add_argument('--threshold', type=float, default=0.35)
    parser.add_argument('--per-sheet', type=int, default=8,
                        help='max objects cut from one sprite sheet')
    args = parser.parse_args()

    manifest = json.loads(
        (Path(args.raw) / 'manifest.json').read_text(encoding='utf-8'))
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    accepted, rejected, errors = [], [], []
    for item in manifest:
        if not item['local'].lower().endswith('.png'):
            # SVG needs a rasteriser the runner does not have yet.
            rejected.append({**item, 'reason': 'svg-not-supported'})
            continue
        try:
            src = Image.open(item['local'])
            src.load()
        except OSError as exc:
            rejected.append({**item, 'reason': f'unreadable: {exc}'})
            continue
        kept_masks = []
        for index, piece in enumerate(slice_sheet(src, args.per_sheet)):
            # Frames of one animation differ by a few pixels; turning each
            # into its own antagonist produced near-identical sets (11
            # "anger" objects from one mushroom walk cycle), so a piece
            # whose silhouette matches an earlier one is skipped.
            mask = frame_mask(piece)
            if any(mask_iou(mask, seen) > FRAME_DUP_IOU
                   for seen in kept_masks):
                rejected.append({**item, 'piece': index,
                                 'reason': 'duplicate-animation-frame'})
                continue
            kept_masks.append(mask)
            record, images = process_piece(item, index, piece,
                                           args.threshold)
            write_object(out, record, images)
            if record['status'] == 'error':
                errors.append(record)
            elif record['status'] == 'unlike-real-object':
                rejected.append({**item, 'piece': index,
                                 'reason': 'unlike-real-object',
                                 'reference': record['reference']})
            else:
                accepted.append(record)
            print(f'{item["path"]} #{index}: {record["status"]} '
                  f'{record.get("name", "")} '
                  f'min shape {record.get("shape_change", 0):.1%}')

    report = {'threshold': args.threshold, 'accepted': accepted,
              'errors': errors, 'rejected': rejected}
    (out / 'report.json').write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f'objects {len(accepted)}, errors {len(errors)}, skipped '
          f'{len(rejected)} (threshold {args.threshold:.0%}) '
          f'-> {out / "report.json"}')


if __name__ == '__main__':
    main()
