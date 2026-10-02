"""Rework of ant_sadness_4bbd8e3f97: the cracked jug of sadness.

Hourly pass osint-2026-10-02T09:51:32Z took piece 0 of crawl's
summon_drakes.png, found it a recolour and replaced it by the passion
of sadness.  The numbers passed, the eye did not: the old form of
sadness sagged the square icon into a stemless U-shaped cup that can
read as a chalice, and a passion must never resemble a holy thing
(CLAUDE.md TABOO 0.2 item 3, 0.35 rule 6).  The kit was removed and the
pass marked reverted (docs/RAW_OSINT_CURSOR.json); the contact sheet
is docs/audit/2026-10-02/raw-sadness-4bbd8e3f97-contact-rejected.png.

This script runs the same source piece through the pipeline again with
the reworked form of sadness (antagonist.shape_sadness): a clay jug of
daily work fallen on its side, cracked, its water running out.  It is
the pipeline of transform.py, step for step:
  - the piece is cut from the sheet and placed on the common canvas;
  - the plain redraw is measured and must be a recolour (else it is no
    antagonist at all);
  - the passion is the one the runner chose (sadness), the seed is
    sha1(repo + path + "#" + piece) as antagonist.object_seed makes it,
    so the id stays 4bbd8e3f97;
  - the form is alpha only and must move >= 35 % from the source;
  - VariantBuilder makes exactly twelve variants, each measured against
    the source for shape and colour, with pairwise distinct hitboxes;
  - the meta carries the rule-13 teaching fields (passion_fields).
Two things differ from the hourly run, both written into the meta:
  - the palette is the passion's own cold hue (rule 13: a cold palette)
    instead of the complement of the source's blue, which was a warm
    clay orange and made the counterfeit look like fired earthenware;
  - the kit names the record it reworks ("reworks").
Nothing is random.

Usage:
    python3 scripts/raw_assets/sadness_vessel.py --source <summon_drakes.png>
        [--out build/sadness-vessel] [--sheet docs/audit/.../x.png]
        [--ship public/ludus/art/derived/DEF-001]
The source file is read from a checkout of crawl at the commit below
(the hourly runner's full clone keeps it at
/home/user/raw-repos/full/crawl__crawl/<path>); its sha1 is checked.
"""

import argparse
import hashlib
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageChops

sys.path.insert(0, str(Path(__file__).resolve().parent))

import antagonist as ant  # noqa: E402
from form import CANVAS, alpha_mask, area, fill_holes  # noqa: E402
import neutral_variants  # noqa: E402
import transform  # noqa: E402

ITEM = {
    'repo': 'https://github.com/crawl/crawl',
    'path': 'crawl-ref/source/rltiles/gui/spells/monster/'
            'summon_drakes.png',
    'commit': '7c31f6e79758706fc67dede5080d3270381f6fb4',
    'license': 'GPL',
    'license_file': 'LICENSE',
}
PIECE = 0
PASSION = 'sadness'
THRESHOLD = 0.35
# The form's revision, so the register names which drawing shipped.
FORM = 'cracked-jug-r1'
REWORKS = {
    'object': 'ant_sadness_4bbd8e3f97',
    'pass_id': 'osint-2026-10-02T09:51:32Z',
    'reason': 'stemless U-shaped cup, close to a chalice',
    'contact_sheet': 'docs/audit/2026-10-02/'
                     'raw-sadness-4bbd8e3f97-contact-rejected.png',
}
DEFAULT_SOURCE = Path('/home/user/raw-repos/full/crawl__crawl') / \
    ITEM['path']
# A shipped silhouette this close to another passion's is a look-alike
# (osint_cycle's duplicate-frame rule, TABOO 0.15).
SIBLING_IOU = 0.85


def piece_of(path):
    """The cut piece of the sheet the hourly pass used, and its sha1."""
    data = Path(path).read_bytes()
    src = Image.open(path)
    src.load()
    pieces = transform.slice_sheet(src, 8)
    return pieces[PIECE], hashlib.sha1(data).hexdigest()


def build(source_path, threshold=THRESHOLD):
    """Return (record, images); nothing is written here."""
    piece, sha = piece_of(source_path)
    seed = ant.object_seed(ITEM['repo'], ITEM['path'], PIECE)
    oid = seed[:10]
    canvas = transform.place_on_canvas(piece)
    src_mask = alpha_mask(canvas)
    filled = fill_holes(src_mask)
    plain = transform.redraw(canvas)
    _, redraw = transform.measure(canvas, src_mask, filled, plain)
    redraw.pop('hitbox')
    redraw['is_recolour'] = redraw['shape_change'] < threshold
    feat = ant.source_features(piece, canvas, src_mask, ITEM['path'])
    passion, reason = ant.choose_passion(feat)
    # The passion read from the source must still be sadness; anything
    # else means the source or the reader changed and the rework is void.
    assert passion == PASSION, (passion, reason)
    cold = dict(feat, chromatic=False)
    palette = ant.antagonist_palette(cold, PASSION)
    texture = ant.texture_mode(feat)
    ref_mask, strength, _ = transform.reference_form(
        PASSION, src_mask, seed, threshold, canvas)
    builder = transform.VariantBuilder(seed, palette, texture, canvas,
                                       src_mask, threshold)
    made = builder.run(ref_mask)
    prefix = f'ant_{PASSION}_{oid}'
    record = {
        'id': oid, 'seed': seed, 'piece': PIECE,
        'source': {'repo': ITEM['repo'], 'path': ITEM['path'],
                   'commit': ITEM['commit'], 'piece': PIECE,
                   'sha1': sha},
        'repo': ITEM['repo'], 'path': ITEM['path'],
        'commit': ITEM['commit'], 'license': ITEM['license'],
        'license_file': ITEM['license_file'],
        'threshold': threshold,
        'redraw': redraw,
        'name': prefix, 'passion': PASSION,
        'passion_reason': reason,
        'passion_form': FORM,
        'reworks': REWORKS,
        'features': feat,
        'behaviour': ant.behaviour(PASSION),
        'palette': {'hue': palette['hue'],
                    'basis': 'passion-hue (cold, rule 13)',
                    'stops': ['#%02x%02x%02x' % c
                              for _, c in palette['stops']]},
        'texture': {'source': 'smooth' if texture == 'rough' else 'rough',
                    'antagonist': texture},
        'reference_strength': strength,
    }
    images = {f'review/{oid}.source.png': canvas,
              f'review/{oid}.reference.png': ref_mask.convert('RGBA')}
    variants = []
    for v in builder.accepted:
        v.pop('mask', None)
        v['file'] = f'{prefix}_{v["slot"]}.png'
        v['analytics_id'] = f'ludus.variant.{PASSION}.{oid}.{v["slot"]}'
        images[v['file']] = made[v['slot']]
        variants.append(v)
    record['variants'] = variants
    record['rejected_variants'] = builder.rejected
    record['shortfall'] = 12 - len(variants)
    record['status'] = 'ok' if len(variants) == 12 else 'shortfall'
    record['file'] = variants[0]['file'] if variants else None
    record['shape_change'] = min((v['shape_change'] for v in variants),
                                 default=0.0)
    record['colour_change'] = min((v['colour_change'] for v in variants),
                                  default=0.0)
    record['claim_features'] = transform.claim_features(record) + [
        'форма печали — опрокинутый треснувший глиняный кувшин (горло, '
        'носик, петля ручки, трещина в брюхе, вода вытекает): сосуд '
        'обихода, не чаша; пересделка отклонённого на глаз '
        f'{REWORKS["object"]} ({REWORKS["pass_id"]})',
    ]
    return record, images


def mask_iou(a, b):
    union = area(ImageChops.lighter(a, b))
    return area(ImageChops.multiply(a, b)) / union if union else 0.0


def sibling_iou(record, images, shipped_dir):
    """IoU of the kit's v01 against every other shipped ant_*_v01."""
    mine = alpha_mask(images[record['file']])
    out = {}
    for f in sorted(Path(shipped_dir).glob('ant_*_v01.png')):
        if f.name == record['file']:
            continue
        out[f.name] = round(mask_iou(mine, alpha_mask(Image.open(f))), 4)
    return out


def contact(record, images, sheet):
    """The eye check: source and twelve variants on five biomes."""
    cells = [(v['slot'], images[v['file']],
              f'{v["shape_change"]:.0%}') for v in record['variants']]
    src = images[f'review/{record["id"]}.source.png']
    label = (f'{record["name"]} ({FORM}) shape >= '
             f'{record["shape_change"]:.1%}, colour >= '
             f'{record["colour_change"]:.1%}')
    return neutral_variants.contact_sheet([(label, src, cells)], sheet)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', default=str(DEFAULT_SOURCE))
    parser.add_argument('--out', default='build/sadness-vessel')
    parser.add_argument('--sheet', default='')
    parser.add_argument('--ship', default='',
                        help='copy the kit here when all 12 pass')
    args = parser.parse_args(argv)
    record, images = build(args.source)
    out = Path(args.out)
    shipped = Path(args.ship or 'public/ludus/art/derived/DEF-001')
    record['sibling_iou_v01'] = sibling_iou(record, images, shipped)
    worst = max(record['sibling_iou_v01'].values(), default=0.0)
    record['sibling_iou_max'] = worst
    transform.write_object(out, record, images)
    if args.sheet:
        print('sheet', contact(record, images, args.sheet))
    print(f'{record["name"]}: {record["status"]} '
          f'{len(record["variants"])}/12, shape '
          + ', '.join(f'{v["slot"]} {v["shape_change"]:.1%}'
                      for v in record['variants'])
          + f'; colour >= {record["colour_change"]:.1%}; '
          f'max IoU vs shipped v01 {worst:.3f}')
    ok = record['status'] == 'ok' and worst < SIBLING_IOU
    if args.ship and ok:
        shipped.mkdir(parents=True, exist_ok=True)
        for f in out.glob(f'{record["name"]}*'):
            if f.suffix in ('.png', '.json'):
                shutil.copy2(f, shipped / f.name)
        print(f'shipped to {shipped}')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
