"""Transform raw third-party images into Ludus art and measure the change.

Step two of the raw-material pipeline (CLAUDE.md, TABOO 0.4).  Each image
is re-drawn in the project's gold-on-dark language and kept only if the
measured change is at least the operator's threshold (35 % by default).

The threshold is an internal technology rule.  It is not a legal safe
harbour: the licence of every source is still recorded, and attribution
and share-alike duties still apply (see THIRD_PARTY_NOTICES.md).

Usage:
    python3 scripts/raw_assets/transform.py --raw build/raw \
        --out build/derived --threshold 0.35
"""

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

CANVAS = 256

# Palette stops copied from public/ludus/art so derived objects sit in the
# same visual family as the project's own drawings.
PALETTE = [
    (0.00, (0x1a, 0x0e, 0x04)),
    (0.35, (0x2a, 0x18, 0x08)),
    (0.60, (0x8a, 0x6a, 0x34)),
    (0.80, (0xc8, 0xa5, 0x6a)),
    (1.00, (0xe8, 0xc8, 0x7a)),
]
OUTLINE = (0xe8, 0xc8, 0x7a)
FRAME = (0x8a, 0x6a, 0x34)

# A pixel counts as changed when its RGB distance exceeds 15 % of the
# maximum possible distance; smaller shifts are invisible on a headset.
PIXEL_TOLERANCE = 0.15 * (3 * 255 ** 2) ** 0.5


def palette_lut():
    """Build a 256-entry lookup from luminance to the gold gradient."""
    lut = []
    for level in range(256):
        t = level / 255
        for (t0, c0), (t1, c1) in zip(PALETTE, PALETTE[1:]):
            if t0 <= t <= t1:
                k = (t - t0) / (t1 - t0) if t1 > t0 else 0
                lut.append(tuple(round(a + (b - a) * k)
                                 for a, b in zip(c0, c1)))
                break
    return lut


LUT = palette_lut()


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
    """Return an alpha mask that ignores faint and background pixels.

    Sheets often carry near-invisible pixels (alpha 1-16) between cells,
    and some use an opaque background colour instead of transparency.
    Both would glue neighbouring objects together in the XY-cut, which is
    why the first trial accepted whole sheets as single objects.
    """
    rgba = img.convert('RGBA')
    alpha = rgba.getchannel('A').point(lambda v: 255 if v > 16 else 0)
    corner = rgba.getpixel((0, 0))
    if corner[3] > 16:
        # The corner pixel is opaque, so its colour is the background.
        key = Image.new('RGBA', rgba.size, corner)
        dist = ImageOps.grayscale(ImageChops.difference(rgba, key))
        alpha = ImageChops.multiply(
            alpha, dist.point(lambda v: 255 if v > 12 else 0))
    rgba.putalpha(alpha)
    return rgba


def slice_sheet(img, max_pieces, min_side=12, depth=0):
    """Split a sprite sheet into single objects by transparent gaps.

    A recursive XY-cut is enough for the grid-like sheets these games use,
    and it keeps one object per derived file, which the claim sheet needs.
    """
    img = solid_alpha(img) if depth == 0 else img
    box = img.getchannel('A').getbbox()
    if box is None:
        return []
    img = img.crop(box)
    alpha = img.getchannel('A')
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
    """Fit the source onto the common square canvas over black.

    Small sprites are enlarged with nearest-neighbour scaling so the
    object, not the empty background, fills the frame.  Both the source
    and the result are compared on this same canvas, so resizing alone
    can never count as change.
    """
    img = img.convert('RGBA')
    side = CANVAS - 48
    scale = side / max(img.size)
    img = img.resize((max(1, round(img.width * scale)),
                      max(1, round(img.height * scale))), Image.NEAREST)
    canvas = Image.new('RGBA', (CANVAS, CANVAS), (0, 0, 0, 255))
    offset = ((CANVAS - img.width) // 2, (CANVAS - img.height) // 2)
    canvas.alpha_composite(img, offset)
    return canvas.convert('RGB'), img.getchannel('A'), offset


def redraw(base, alpha, offset):
    """Re-draw the object in the Ludus style.

    The steps are deterministic, so the same source always yields the
    same result and the change measurement can be reproduced for review.
    """
    gray = ImageOps.grayscale(base)
    # tobytes() works on every Pillow version, unlike getdata(), which is
    # deprecated in current releases.
    flat = bytes(c for v in gray.tobytes() for c in LUT[v])
    toned = Image.frombytes('RGB', base.size, flat)

    # A gold contour carries the silhouette, as in the project's own
    # line-art icons.
    mask = Image.new('L', base.size, 0)
    mask.paste(alpha, offset)
    edges = mask.filter(ImageFilter.FIND_EDGES).point(
        lambda v: 255 if v > 40 else 0)
    edges = edges.filter(ImageFilter.MaxFilter(3))
    toned.paste(Image.new('RGB', base.size, OUTLINE), (0, 0), edges)

    # The double frame is the signature of every Ludus object badge.
    draw = ImageDraw.Draw(toned)
    draw.rounded_rectangle([6, 6, CANVAS - 7, CANVAS - 7], radius=18,
                           outline=FRAME, width=3)
    draw.rounded_rectangle([14, 14, CANVAS - 15, CANVAS - 15], radius=12,
                           outline=OUTLINE, width=1)
    return toned, edges


def silhouette(mask_bytes):
    """Binary mask restricted to the area inside the badge frame."""
    inner = range(22, CANVAS - 22)
    return [mask_bytes[y * CANVAS + x] > 0 for y in inner for x in inner]


def change_metrics(before, after, area, source_mask):
    """Return the colour-change share and the shape-change share.

    Colour change is measured over the object's own area, because
    pixel-art items leave most of the canvas empty.

    Shape change is 1 - IoU of the visible silhouettes.  It exists
    because the first trial showed that a pure recolour (a white "$"
    turned gold) scored 100 % on colour while the design was unchanged;
    the 35 % rule must hold for shape as well, or it measures nothing.
    """
    diff = ImageChops.difference(before, after).tobytes()
    inside = area.tobytes()
    limit = PIXEL_TOLERANCE ** 2
    changed = total = 0
    for i, flag in enumerate(inside):
        if not flag:
            continue
        total += 1
        r, g, b = diff[3 * i], diff[3 * i + 1], diff[3 * i + 2]
        if r * r + g * g + b * b > limit:
            changed += 1
    colour_share = changed / (total or 1)

    # The source silhouette comes from its alpha channel: dark sprites
    # are invisible by luminance, and the first version wrongly scored
    # them as 100 % reshaped.  In the result, anything brighter than the
    # dark badge fill is drawn content.
    m0 = silhouette(source_mask.tobytes())
    m1 = silhouette(ImageOps.grayscale(after).point(
        lambda v: 255 if v > 48 else 0).tobytes())
    union = sum(a or b for a, b in zip(m0, m1)) or 1
    inter = sum(a and b for a, b in zip(m0, m1))
    return colour_share, 1 - inter / union


def features(item, colour_share, shape_share):
    """List the essential features used in the object's claim text."""
    return [
        'монохромная тонировка по яркости в пятиступенчатую золотую '
        'шкалу #1a0e04–#e8c87a',
        'золотой контур силуэта, выделенный по альфа-каналу',
        'двойная скруглённая рамка значка Ludus',
        f'измеренное изменение цвета объекта {colour_share:.1%}',
        f'измеренное изменение формы (1 - IoU силуэтов) {shape_share:.1%}',
        f'источник: {item["repo"]} @ {item["commit"][:10]}, '
        f'{item["path"]} ({item["license"]})',
    ]


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
    # Rejected pairs are kept for review, so a human can see why the
    # rule said no instead of trusting a number.
    review = out / 'rejected'
    review.mkdir(exist_ok=True)

    accepted, rejected = [], []
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
        for index, piece in enumerate(slice_sheet(src, args.per_sheet)):
            before, alpha, offset = place_on_canvas(piece)
            after, edges = redraw(before, alpha, offset)
            source_mask = Image.new('L', before.size, 0)
            source_mask.paste(alpha, offset)
            source_mask = source_mask.point(lambda v: 255 if v else 0)
            area = ImageChops.lighter(source_mask, edges)
            colour_share, shape_share = change_metrics(
                before, after, area, source_mask)
            digest = hashlib.sha1(
                f'{item["repo"]}{item["path"]}#{index}'.encode()
            ).hexdigest()[:10]
            record = {
                **item,
                'piece': index,
                'id': f'derived-{digest}',
                'colour_change': round(colour_share, 4),
                'shape_change': round(shape_share, 4),
            }
            # Both parts of the rule must hold: see change_metrics().
            if min(colour_share, shape_share) < args.threshold:
                record['reason'] = ('shape-below-threshold'
                                    if shape_share < args.threshold
                                    else 'colour-below-threshold')
                after.save(review / f'{record["id"]}.png')
                before.save(review / f'{record["id"]}.source.png')
                rejected.append(record)
                continue
            name = f'{record["id"]}.png'
            after.save(out / name, optimize=True)
            before.save(out / f'{record["id"]}.source.png', optimize=True)
            record['file'] = name
            record['features'] = features(item, colour_share,
                                          shape_share)
            accepted.append(record)

    report = {'threshold': args.threshold, 'accepted': accepted,
              'rejected': rejected}
    (out / 'report.json').write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f'accepted {len(accepted)}, rejected {len(rejected)} '
          f'(threshold {args.threshold:.0%}) -> {out / "report.json"}')


if __name__ == '__main__':
    main()
