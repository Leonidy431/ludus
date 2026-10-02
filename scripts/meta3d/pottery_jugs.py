"""Two clay water jugs of the potters' yard, drawn from code.

The story beat of the cracked jug (docs/HLD_SADNESS_VESSEL_2026-10-02.md)
needs the real things it speaks of at the potters' yard, beside the
whole water jug already there (obj-kuvshin-vody):
  - obj-kuvshin-tresnuvshiy: a jug knocked over on its side, a crack
    down its belly and the spilt water in a shallow puddle at its mouth;
  - obj-kuvshin-podmazannyy: the same jug standing, its crack daubed
    with fresh raw clay, the way a household mends a jug ("подмазать
    глиной"), not gilded (kintsugi is not our tradition).
Both are a lathe of one water-jug profile (lip, spout, narrow neck,
loop handle, belly wider than the foot), so neither is a cup or a
bowl, with or without a stem, and neither is a holy vessel (TABOO 0.2,
0.35 rule 6).  They are LOD0 proxies (TABOO 0.32): no textures, colour
in the materials, under 5000 triangles each.  Nothing is random.

Writes public/vr/models/obj/<id>.glb and <id>.json; the locations ship
them into godot/models/locations (scripts/locations/ship_models.py).
Run: python3 scripts/meta3d/pottery_jugs.py [--check]
"""

import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from lake_kit import (TRI_BUDGET, Model, chain, ellipsoid, lathe,  # noqa
                      rot_z, translate, tube)

ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, 'public', 'vr', 'models', 'obj')

FIRED = '#a0603a'
INSIDE = '#5a321e'
CRACK = '#24160e'
RAW_CLAY = '#c79e70'
WATER = '#7d9fb2'

# The jug standing, foot at y = 0: (radius, height) in metres, from the
# foot up to the lip and over it into the neck, so the rim has a
# thickness.  A household water jug of about 30 cm.
PROFILE = [(0.0, 0.0), (0.052, 0.0), (0.058, 0.008), (0.08, 0.045),
           (0.1, 0.09), (0.108, 0.125), (0.1, 0.165), (0.078, 0.205),
           (0.046, 0.236), (0.036, 0.262), (0.04, 0.284), (0.047, 0.296),
           (0.042, 0.302), (0.034, 0.29), (0.03, 0.262)]
SIDES = 18


def radius_at(y):
    """The jug's outer radius at height y (linear in the profile)."""
    for (r0, y0), (r1, y1) in zip(PROFILE, PROFILE[1:]):
        if y0 <= y <= y1 and y1 > y0:
            return r0 + (r1 - r0) * (y - y0) / (y1 - y0)
    return 0.0


def jug(model, m):
    """The standing jug: body, handle on +x, spout on -x."""
    model.add(model.mat('clay', FIRED, rough=0.85),
              lathe(PROFILE[:12], SIDES), m)
    model.add(model.mat('inside', INSIDE, rough=0.95),
              lathe(PROFILE[11:], SIDES), m)
    handle = [(0.038, 0.262, 0.0), (0.085, 0.27, 0.0),
              (0.118, 0.232, 0.0), (0.112, 0.18, 0.0),
              (0.094, 0.15, 0.0)]
    model.add('clay', tube(handle, 0.011, sides=6), m)
    spout = [(-0.042, 0.292, 0.0), (-0.058, 0.3, 0.0),
             (-0.072, 0.31, 0.0)]
    model.add('clay', tube(spout, [0.013, 0.01, 0.006], sides=6), m)


def crack_points(a0, y0, y1, steps=7, swing=0.18):
    """A zig-zag line on the belly's surface, at angle a0 round y."""
    pts = []
    for i in range(steps + 1):
        y = y0 + (y1 - y0) * i / steps
        a = a0 + (swing if i % 2 else -swing) * 0.5
        r = radius_at(y) + 0.0015
        pts.append((r * math.cos(a), y, -r * math.sin(a)))
    return pts


def cracked():
    """Knocked over: lying along -x, handle up, water at the mouth."""
    model = Model('obj-kuvshin-tresnuvshiy')
    # Turn the standing jug onto its side: its axis (y) to -x, the belly
    # resting on the ground (its widest radius is 0.108 m).
    lay = chain(translate(0.0, 0.108, 0.0), rot_z(math.pi / 2))
    jug(model, lay)
    model.mat('crack', CRACK, rough=1.0)
    # The crack runs along the side the jug lies toward the viewer (+z).
    model.add('crack', tube(crack_points(-math.pi / 2, 0.05, 0.19),
                            0.0035, sides=4), lay)
    model.mat('water', WATER, rough=0.15, alpha=0.6)
    model.add('water', ellipsoid(0.13, 0.004, 0.09, nu=14, nv=4),
              translate(-0.36, 0.004, 0.02))
    model.add('water', ellipsoid(0.05, 0.003, 0.035, nu=10, nv=3),
              translate(-0.07, 0.003, 0.11))
    return model


def patched():
    """Standing again, the crack daubed with raw clay."""
    model = Model('obj-kuvshin-podmazannyy')
    jug(model, np.eye(4))
    model.mat('crack', CRACK, rough=1.0)
    model.add('crack', tube(crack_points(-math.pi / 2, 0.04, 0.2),
                            0.0035, sides=4), np.eye(4))
    model.mat('patch', RAW_CLAY, rough=1.0)
    r = radius_at(0.12)
    # The daub lies over the crack, on the side it faces (+z).
    model.add('patch', ellipsoid(0.032, 0.06, 0.012, nu=10, nv=5),
              translate(0.0, 0.12, r - 0.002))
    return model


THINGS = {
    'obj-kuvshin-tresnuvshiy': (cracked, 'Треснувший кувшин на боку',
                                'a water jug knocked over, cracked, its '
                                'water spilt'),
    'obj-kuvshin-podmazannyy': (patched, 'Кувшин, подмазанный глиной',
                                'the same jug standing, its crack daubed '
                                'with raw clay'),
}


def build(mid):
    make, ru, en = THINGS[mid]
    model = make()
    lo, hi = model.bounds()
    size = hi - lo
    meta = {
        'id': mid, 'kind': 'obj', 'lod': 'proxy',
        'tris': model.tris(),
        'bbox_m': [round(float(x), 3) for x in size],
        'source': 'scripts/meta3d/pottery_jugs.py (own procedural '
                  'drawing, no raw material)',
        'name': ru, 'what': en,
        'method': 'pottery-jug-kit (numpy, own glTF writer)',
        'collider': {'shape': 'box',
                     'size_m': [round(float(x), 3) for x in size],
                     'centre_m': [round(float(x), 3)
                                  for x in (hi + lo) / 2]},
        'materials': [{'name': k, 'colour': model.mats[k]['colour'],
                       'alpha': model.mats[k]['alpha']}
                      for k in model.order if model.mats[k]['v']],
        'textures': 0,
        'noInteract': False, 'noLoot': False,
    }
    blob = model.glb({'noInteract': False, 'noLoot': False})
    return model, meta, blob


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    check = '--check' in argv
    bad = []
    for mid in THINGS:
        model, meta, blob = build(mid)
        text = json.dumps(meta, ensure_ascii=False, indent=1) + '\n'
        glb = os.path.join(OUT, mid + '.glb')
        js = os.path.join(OUT, mid + '.json')
        if model.tris() > TRI_BUDGET:
            bad.append(f'{mid}: {model.tris()} triangles')
        if check:
            same = os.path.exists(glb) and open(glb, 'rb').read() == blob \
                and os.path.exists(js) and \
                open(js, encoding='utf-8').read() == text
            if not same:
                bad.append(f'{mid}: files differ from the generator')
        else:
            os.makedirs(OUT, exist_ok=True)
            with open(glb, 'wb') as fh:
                fh.write(blob)
            with open(js, 'w', encoding='utf-8') as fh:
                fh.write(text)
        print(mid, meta['tris'], 'tris', meta['bbox_m'], len(blob), 'B')
    for line in bad:
        print('pottery_jugs:', line)
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
