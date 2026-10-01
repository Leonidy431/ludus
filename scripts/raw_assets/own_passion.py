"""Our own procedural drawing of a passion, for a slot raw material
may never fill.

Lust is the one passion the chorus kept out of the raw-material runner
(docs/CHORUS_LUST_2026-09-30.md): a sprite from a third-party game that
shows a body is not admissible in a game with a young audience or in
the Meta Store, and the image of a passion must not itself allure.  St
John Climacus (Ladder, step 15) teaches flight and watchfulness, not
gazing.  So the form is drawn here, by the project, as an abstraction:
a restless flame that will not stand still and keeps coming back.  No
body, no face, no figure; nothing is fetched from the 99 repositories.

The drawing then goes through the same machine as every antagonist
(CLAUDE.md TABOO 0.1 and 0.3):
  - the base is our own calm tongue of flame, painted warm; it is the
    "source" every result is measured against, alpha only;
  - the passion's form (antagonist.SHAPES['lust']) coils it until the
    shape change reaches the threshold (35 %, |A xor B| / |A or B|);
  - transform.VariantBuilder makes the twelve variants (v01-v12), each
    measured against the base, each with its own hitbox, rejected and
    replaced by a seeded hybrid when it falls short;
  - the palette is the cold complement of the warm base flame, so the
    counterfeit flame gives light without warmth (rule 13: a cold
    palette);
  - the meta-json carries the rule-13 fields from passion_fields.
Nothing is random: the seed is sha1 of a fixed label.

Usage:
    python3 scripts/raw_assets/own_passion.py --out build/own \
        [--ship public/ludus/art/derived/DEF-001]
"""

import argparse
import hashlib
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))

import antagonist as ant  # noqa: E402
from form import CANVAS, alpha_mask  # noqa: E402
import transform  # noqa: E402

# The only passion drawn here, and the label its seed is hashed from.
PASSION = 'lust'
LABEL = 'ludus-own-drawing:lust:restless-flame'
THRESHOLD = 0.35

# Revision of the drawing, in place of a source commit: an own drawing
# has no upstream repository.  Raise it whenever base_flame() or the
# kit's parameters change, so the register names which drawing shipped.
REVISION = 'drawing-r1'

# The base flame is a warm ember (a hearth flame, dim).  Its features
# are measured from the drawing by antagonist.source_features, as for
# any source: the complement of its hue is the cold blue of the
# counterfeit, and a dim source becomes a luminous body, so the kit
# reads on the dark water of the deep and night biomes.


def seed():
    return hashlib.sha1(LABEL.encode()).hexdigest()


def base_flame():
    """Our own calm tongue of flame on the common canvas (RGBA).

    A round foot and a tip, drawn as a polygon of a teardrop curve and
    softened once, so the alpha edge is clean.  It is warm and still:
    what the passion distorts.
    """
    mask = Image.new('L', (CANVAS, CANVAS), 0)
    draw = ImageDraw.Draw(mask)
    cx, foot, top, half = CANVAS / 2, 214, 40, 52
    pts = []
    steps = 64
    for i in range(steps + 1):
        t = i / steps
        # A teardrop: width grows as sqrt near the tip, round at the foot.
        y = top + (foot - top) * t
        w = half * (t ** 0.6) * (1 - t ** 6) ** 0.5
        pts.append((cx + w, y))
    for i in range(steps, -1, -1):
        t = i / steps
        y = top + (foot - top) * t
        w = half * (t ** 0.6) * (1 - t ** 6) ** 0.5
        pts.append((cx - w, y))
    draw.polygon(pts, fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(1.5)).point(
        lambda v: 255 if v > 127 else 0)
    ramp = Image.linear_gradient('L').resize((CANVAS, CANVAS))
    warm = Image.merge('RGB', [
        ramp.point(lambda v: 60 + v * 90 // 255),
        ramp.point(lambda v: 36 + v * 54 // 255),
        ramp.point(lambda v: 6 + v * 14 // 255)])
    img = warm.convert('RGBA')
    img.putalpha(mask)
    return img


def build(threshold=THRESHOLD):
    """Return (record, images) for the lust kit; nothing is written."""
    s = seed()
    oid = s[:10]
    canvas = base_flame()
    src_mask = alpha_mask(canvas)
    feat = ant.source_features(canvas, canvas, src_mask,
                               'own/lust/restless_flame')
    palette = ant.antagonist_palette(feat, PASSION)
    texture = ant.texture_mode(feat)
    ref_mask, strength, _ = transform.reference_form(
        PASSION, src_mask, s, threshold, canvas)
    builder = transform.VariantBuilder(s, palette, texture, canvas,
                                       src_mask, threshold)
    made = builder.run(ref_mask)
    prefix = f'ant_{PASSION}_{oid}'
    here = 'scripts/raw_assets/own_passion.py'
    record = {
        'id': oid, 'seed': s, 'piece': 0,
        'origin': 'own-procedural-drawing',
        'raw_material': False,
        'source': {'repo': 'ludus (own drawing)', 'path': here,
                   'commit': REVISION, 'piece': 0},
        'repo': 'ludus (own drawing)', 'path': here, 'commit': REVISION,
        'license': 'project (own drawing, no third-party material)',
        'license_file': None,
        'threshold': threshold,
        'name': prefix, 'passion': PASSION,
        'passion_reason': 'own drawing for the lust slot; chorus '
                          'decision docs/CHORUS_LUST_2026-09-30.md',
        'features': feat,
        'behaviour': ant.behaviour(PASSION),
        'palette': {'hue': palette['hue'], 'basis': palette['basis'],
                    'stops': ['#%02x%02x%02x' % c
                              for _, c in palette['stops']]},
        'texture': {'source': 'smooth' if texture == 'rough' else 'rough',
                    'antagonist': texture},
        'reference_strength': strength,
    }
    images = {f'review/{oid}.source.png': canvas}
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
    record['colour_change'] = variants[0]['colour_change'] if variants \
        else 0.0
    shapes = [v['shape_change'] for v in variants] or [0.0]
    record['claim_features'] = [
        'форма-антагонист страсти «lust» — собственный процедурный '
        'рисунок проекта (беспокойное пламя), без стороннего сырья, '
        'без тела и фигуры',
        f'палитра {palette["basis"]} (тон {palette["hue"]}°) к тёплому '
        f'базовому пламени и инверсия фактуры '
        f'{record["texture"]["source"]} -> {texture}',
        f'поведение {record["behaviour"]["source_role"]} -> '
        f'{record["behaviour"]["antagonist"]}; {len(variants)} вариантов '
        f'с попарно различными хитбоксами',
        f'изменение формы по альфа-маскам (|A xor B| / |A or B|) '
        f'относительно базового пламени: от {min(shapes):.1%} до '
        f'{max(shapes):.1%}',
    ]
    return record, images


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', default='build/own')
    parser.add_argument('--ship', default='',
                        help='copy the kit here when all 12 pass')
    parser.add_argument('--threshold', type=float, default=THRESHOLD)
    args = parser.parse_args(argv)
    out = Path(args.out)
    record, images = build(args.threshold)
    transform.write_object(out, record, images)
    print(f'{record["name"]}: {record["status"]} '
          f'{len(record["variants"])}/12, shape '
          + ', '.join(f'{v["slot"]} {v["shape_change"]:.1%}'
                      for v in record['variants']))
    if args.ship and record['status'] == 'ok':
        dest = Path(args.ship)
        dest.mkdir(parents=True, exist_ok=True)
        for f in out.glob(f'{record["name"]}*'):
            if f.suffix in ('.png', '.json'):
                shutil.copy2(f, dest / f.name)
        print(f'shipped to {dest}')
    return 0 if record['status'] == 'ok' else 1


if __name__ == '__main__':
    sys.exit(main())
