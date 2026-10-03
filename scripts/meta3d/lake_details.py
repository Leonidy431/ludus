"""Detailed procedural proxies of the 99 lake objects and the knight's
five traces (CLAUDE.md TABOO 0.32, 0.07; TABOO 0.03 for the traces).

The first proxies were one or two boxes per object.  The operator asked
"детали мелкие доделывай все 99 по Промтам": every object now carries
the small details that make it recognisable -- the millstone's eye and
furrows, the storage jar's rolled rim and rope bands, the net's floats
and sinkers, the carp's barbels, the stonewort's whorls.

What stays true:
- every shape is drawn from code, never from raw material; the khachkar
  is our own drawing, stone only, no glow and no gold, flags noInteract
  and noLoot (TABOO 0.35 rule 6, TABOO 0.4);
- irregular stones take their shape from a generator seeded by the id,
  so the same id always gives the same model (TABOO 0.35 rule 15);
- each model stays within 5,000 triangles and has no textures;
- lod stays "proxy": these are careful procedural drawings, not a
  modeller's final assets, and the meta-json says so in "detail".

Run:  python3 scripts/meta3d/lake_details.py
Writes public/vr/models/lake/*.glb|json, godot/models/lake/*.glb,
public/vr/models/atlas/*.glb|json and godot/models/atlas/*.glb|json.
"""

import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lake_fauna import (BIRDS, SPECIES, amphipod, bird, fish,  # noqa: E402
                        school, snail_shell)
from lake_kit import (TRI_BUDGET, Model, box, chain, disc_field,  # noqa
                      ellipsoid, heightfield, lathe, mix, pierced, plate,
                      rot_x, rot_y, rot_z, scale, seeded, shade, torus,
                      translate, tube)

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
DATA = os.path.join(ROOT, 'godot', 'data', 'lake-objects-99.json')
OUT_WEB = os.path.join(ROOT, 'public', 'vr', 'models')
OUT_GODOT = os.path.join(ROOT, 'godot', 'models')
SAND = '#b8a888'
SILT = '#6a655a'


# ----------------------------------------------------------------------
# Shared pieces.

def rock(rng, rx, ry, rz, nu=10, nv=7, rough=0.18):
    """An irregular stone: an ellipsoid with a few seeded lobes."""
    lobes = [(np.array([rng.uniform(-1, 1) for _ in range(3)]),
              rng.uniform(-rough, rough)) for _ in range(6)]
    for i, (d, a) in enumerate(lobes):
        lobes[i] = (d / (np.linalg.norm(d) + 1e-9), a)

    def bump(d):
        d = np.array(d)
        k = 1.0
        for c, a in lobes:
            k += a * max(0.0, float(d @ c)) ** 2
        return k
    return ellipsoid(rx, ry, rz, nu, nv, bump)


def pebbles(model, key, rng, count, radius, size, keys=None, flat=0.5,
            ring=None, y0=0.0, detail='pebbles'):
    """Scatter of small stones on a disc (or on a ring)."""
    for i in range(count):
        if ring:
            a = 2 * math.pi * i / count + rng.uniform(-.1, .1)
            r = ring + rng.uniform(-size, size) * .5
        else:
            a = rng.uniform(0, 2 * math.pi)
            r = radius * math.sqrt(rng.random())
        s = size * rng.uniform(0.5, 1.3)
        k = keys[i % len(keys)] if keys else key
        model.add(k, rock(rng, s, s * flat, s * rng.uniform(.7, 1.1), 6, 4,
                          .25),
                  chain(translate(r * math.cos(a), y0 + s * flat * .5,
                                  r * math.sin(a)),
                        rot_y(rng.uniform(0, 6.28))), smooth=False,
                  detail=detail)


def ground(model, key, radius, rng, amp=0.02, rings=4, sectors=16,
           detail='bed of sand'):
    bumps = [(rng.uniform(-radius, radius), rng.uniform(-radius, radius),
              rng.uniform(.2, .5) * radius) for _ in range(4)]

    def fn(x, z):
        d = math.hypot(x, z) / radius
        y = amp * (1 - d ** 2)
        for bx, bz, br in bumps:
            y += amp * .5 * math.exp(-((x - bx) ** 2 + (z - bz) ** 2)
                                     / br ** 2)
        return y - amp * .6
    model.add(key, disc_field(radius, rings, sectors, fn), detail=detail)


def granite(model, rng, rx, ry, rz, m=None, colour='#8a8680'):
    """A granite boulder: grey stone with grains of pink feldspar and
    black mica set on its surface (not whole faces recoloured)."""
    v, f = rock(rng, rx, ry, rz, 18, 11, .2)
    m = np.eye(4) if m is None else m
    model.add(model.mat('granite', colour, .9), (v, f), m, smooth=False,
              detail='rounded granite')
    pink = model.mat('feldspar', mix(colour, '#d0a090', .6), .85)
    mica = model.mat('mica', shade(colour, .3), .5, .2)
    r = min(rx, ry, rz)
    for i in range(34):
        p = v[rng.randrange(1, len(v) - 1)]
        d = p / (np.linalg.norm(p) + 1e-9)
        g = r * rng.uniform(.04, .08)
        yaw = math.atan2(-d[2], d[0])
        pitch = math.asin(max(-1.0, min(1.0, d[1])))
        model.add(pink if i % 3 else mica,
                  ellipsoid(g * .35, g, g * 1.2, 5, 3),
                  chain(m, translate(*p), rot_y(yaw), rot_z(pitch)),
                  detail='feldspar and mica grains')


# ----------------------------------------------------------------------
# Finds of the drowned settlements.

def millstone(model, obj, rng):
    s = obj['size_m']
    R, r_eye, th = s / 2, s * .09, s * .16
    stone = model.mat('stone', obj['colour'], .95)
    groove = model.mat('groove', shade(obj['colour'], .45), .95)
    prof = [(r_eye, 0), (R * .98, 0), (R, th * .15), (R, th * .85),
            (R * .96, th), (r_eye * 1.3, th * .92), (r_eye, th * .8),
            (r_eye, 0)]
    broken = 'расколот' in obj['state']
    if broken:
        model.add(stone, lathe(prof, 18, 0, math.pi * 1.08, caps=True),
                  smooth=False, detail='split along the eye')
        model.add(stone, lathe(prof, 8, math.pi * 1.25, math.pi * 1.8,
                               caps=True),
                  chain(translate(s * .1, 0, s * .08)), smooth=False,
                  detail='second fragment')
        arcs = [a for a in np.linspace(0.2, math.pi, 7)]
    else:
        model.add(stone, lathe(prof, 28), smooth=False,
                  detail='central eye (hole)')
        arcs = list(np.linspace(0, 2 * math.pi, 12, endpoint=False))
    for a in arcs:
        # Harp dressing: straight furrows that do not meet the centre.
        x0, z0 = math.cos(a) * r_eye * 1.6, -math.sin(a) * r_eye * 1.6
        b = a + 0.35
        x1, z1 = math.cos(b) * R * .9, -math.sin(b) * R * .9
        L = math.hypot(x1 - x0, z1 - z0)
        model.add(groove, box(L, .006, s * .018),
                  chain(translate((x0 + x1) / 2, th * .93 + .002,
                                  (z0 + z1) / 2),
                        rot_y(math.atan2(-(z1 - z0), x1 - x0))),
                  detail='furrows of the grinding face')
    if not broken:
        for k in (0, math.pi):
            model.add(groove, box(r_eye * .9, th * .3, r_eye * .5),
                      chain(rot_y(k), translate(r_eye * 1.1, th * .8, 0)),
                      detail='rynd slots at the eye')


def khum(model, obj, rng):
    s = obj['size_m']
    clay = model.mat('clay', obj['colour'], .9)
    band = model.mat('clay-band', shade(obj['colour'], .8), .9)
    inner = model.mat('clay-inside', shade(obj['colour'], .45), .95)
    H = s * 1.1
    prof = [(0, 0), (s * .12, 0), (s * .2, H * .12), (s * .38, H * .45),
            (s * .4, H * .6), (s * .34, H * .8), (s * .2, H * .92),
            (s * .19, H * .97)]
    lip = [(s * .19, H * .97), (s * .23, H * .985), (s * .235, H),
           (s * .2, H * 1.01), (s * .17, H * .995), (s * .16, H * .9)]
    half = 'половин' in obj['state']
    m = chain(rot_z(.35), translate(0, -H * .3, 0)) if half else np.eye(4)
    model.add(clay, lathe(prof, 22), m, detail='egg-shaped body')
    model.add(clay, lathe(lip, 22), m, detail='rolled rim')
    model.add(inner, lathe([(s * .16, H * .9), (0.001, H * .88)], 22), m,
              detail='dark mouth')
    for y in (H * .55, H * .68):
        rr = s * .4 if y < H * .6 else s * .37
        model.add(band, torus(rr, s * .012, 28, 4),
                  chain(m, translate(0, y, 0)), detail='applied rope bands')
    for side in (0, math.pi):
        model.add(clay, torus(s * .045, s * .015, 8, 4),
                  chain(m, rot_y(side), translate(s * .37, H * .72, 0),
                        rot_x(math.pi / 2)), detail='small lug handles')
    if half:
        model.add(model.mat('sand', SAND, 1), disc_field(
            s * .9, 4, 18, lambda x, z: max(0.0, .12 * s * (1 - math.hypot(
                x, z) / (s * .9)))), detail='sand drifted around it')


def sherds(model, obj, rng):
    s = obj['size_m']
    clay = model.mat('clay', obj['colour'], .9)
    glaze = model.mat('glaze', '#3a7a8a', .25)
    core = model.mat('clay-core', shade(obj['colour'], .7), 1)
    for i in range(7):
        R = s * rng.uniform(.35, .6)
        a0 = rng.uniform(0, 6.28)
        span = rng.uniform(.35, .7)
        y0, y1 = 0, R * rng.uniform(.3, .6)
        t = s * .025
        prof = [(R, y0), (R * .96, y1), (R * .96 - t, y1), (R - t, y0),
                (R, y0)]
        m = chain(translate(rng.uniform(-s * .6, s * .6), t,
                            rng.uniform(-s * .6, s * .6)),
                  rot_x(math.pi / 2 * rng.choice([1, -1]) * .9),
                  translate(-R, 0, 0))
        model.add(core if i % 3 == 2 else clay,
                  lathe(prof, 4, a0, a0 + span, caps=True), m,
                  smooth=False, detail='curved wall sherds')
        if i == 0:
            model.add(glaze, lathe([(R * .96 - t * .9, y1 * .1),
                                    (R * .96 - t * .9, y1 * .95)], 4, a0,
                                   a0 + span), m,
                      detail='glazed inner face')
            model.add(clay, lathe([(R * .96, y1), (R * .99, y1 + t * 1.5),
                                   (R * .93 - t, y1 + t * 1.5),
                                   (R * .96 - t, y1)], 4, a0, a0 + span,
                                  caps=True), m, smooth=False,
                      detail='rim piece with a lip')
    if 'сва' in obj['state']:
        wood = model.mat('wood', '#5a4a38', .95)
        model.add(wood, lathe([(0, 0), (s * .12, 0), (s * .12, s * 1.2),
                               (s * .07, s * 1.35), (0, s * 1.3)], 8),
                  chain(translate(-s * .9, 0, -s * .5)), smooth=False,
                  detail='stub of the pile')


def bones(model, obj, rng):
    s = obj['size_m']
    bone = model.mat('bone', obj['colour'], .8)
    stain = model.mat('bone-stain', shade(obj['colour'], .7), .9)
    for i in range(4):
        L = s * rng.uniform(.35, .55)
        m = chain(translate(rng.uniform(-s * .4, s * .4), s * .03,
                            rng.uniform(-s * .4, s * .4)),
                  rot_y(rng.uniform(0, 6.28)))
        model.add(bone, tube([(-L / 2, 0, 0), (0, 0, 0), (L / 2, 0, 0)],
                             [s * .025, s * .018, s * .025], 6), m,
                  detail='long bones')
        for x in (-L / 2, L / 2):
            model.add(stain, ellipsoid(s * .045, s * .035, s * .05, 6, 4),
                      chain(m, translate(x, 0, 0)), detail='knuckle ends')
    for i in range(3):
        m = chain(translate(rng.uniform(-s * .3, s * .3), s * .02,
                            rng.uniform(-s * .3, s * .3)),
                  rot_x(rng.uniform(-.3, .3)))
        model.add(bone, lathe([(0, 0), (s * .04, 0), (s * .045, s * .03),
                               (s * .04, s * .05), (0, s * .05)], 8), m,
                  detail='vertebrae')
        model.add(bone, plate([(0, 0), (s * .07, s * .015),
                               (s * .07, s * .03), (0, s * .045)], s * .01),
                  chain(m, translate(s * .02, s * .025, 0)),
                  detail='vertebra spines')
    pts = [(s * .3 * math.cos(a), s * .01, s * .3 * math.sin(a))
           for a in np.linspace(.3, 1.8, 7)]
    model.add(bone, tube(pts, s * .012, 5), detail='a rib')


def foundation(model, obj, rng):
    s = obj['size_m']
    stones = [model.mat('stone', obj['colour'], .95),
              model.mat('stone-2', shade(obj['colour'], .82), .95),
              model.mat('stone-3', shade(obj['colour'], 1.15), .95)]
    mortar = model.mat('mortar', '#a89e8a', 1)
    corner = 'угол' in obj['state']
    runs = [(s, 0.0)] if not corner else [(s * .6, 0.0), (s * .5, 1.5708)]
    for L, ang in runs:
        base = rot_y(ang)
        model.add(mortar, box(L, .06, .5), chain(
            base, translate(L / 2 - (s * .05 if corner else s / 2), .03,
                            0)), detail='mortar bed')
        for course in range(3):
            x = -s / 2 if not corner else -s * .05
            x += (.12 if course else 0)
            while x < (L - s / 2 if not corner else L - s * .05) - .1:
                w = rng.uniform(.2, .34)
                sz = (w, rng.uniform(.16, .2), rng.uniform(.2, .26))
                for side in (-1, 1):
                    k = stones[rng.randrange(3)]
                    at = translate(x + w / 2, .06 + sz[1] / 2
                                   + course * .2, side * .13)
                    model.add(k, box(*sz),
                              chain(base, at,
                                    rot_y(rng.uniform(-.06, .06))),
                              smooth=False, detail='two faces of '
                              'squared stones in courses')
                x += w + .015
    if corner:
        model.details.append('corner of two walls')


def brick(model, obj, rng):
    s = obj['size_m']
    glazed = obj['item'] == 'glazur'
    body = model.mat('brick', '#b87050' if glazed else obj['colour'], .95)
    glaze = model.mat('glaze', obj['colour'], .2, .05) if glazed else None
    mortar = model.mat('mortar', '#b0a690', 1)
    finger = model.mat('finger-lines', shade(obj['colour'], .6), 1)
    if glazed:
        dims = (s * .85, s * .2, s * .42)
    else:
        dims = (s * .9, s * .18, s * .9)

    def one(m, rot=0.0, lead=False):
        w, h, d = dims
        # A chipped corner: the block is drawn as a prism with one
        # corner cut off.
        poly = [(-w / 2, -d / 2), (w / 2 - w * .12, -d / 2),
                (w / 2, -d / 2 + d * .18), (w / 2, d / 2), (-w / 2, d / 2)]
        mm = chain(m, rot_y(rot), rot_x(-math.pi / 2))
        model.add(body, plate(poly, h), chain(mm, translate(0, 0, 0)),
                  smooth=False, detail='chipped corner')
        if glazed:
            model.add(glaze, box(w * .98, .004, h * .95),
                      chain(m, rot_y(rot), translate(0, 0, d / 2 + .002),
                            rot_x(math.pi / 2)), detail='turquoise glazed '
                      'face')
        elif lead:
            for k in (-1, 0, 1):
                model.add(finger, box(w * .7, .003, .006),
                          chain(m, rot_y(rot), translate(0, h / 2 + .001,
                                                         k * d * .15),
                                rot_y(.15 * k)),
                          detail='finger-drawn lines on the face')
    if 'кладк' in obj['state']:
        w, h, d = dims
        for row in range(4):
            off = w * .5 if row % 2 else 0
            for i in range(3):
                x = -w * 1.5 + i * (w + .012) + off
                one(translate(x, h / 2 + row * (h + .012), 0))
            model.add(mortar, box(w * 3.6, .012, d * .9),
                      translate(0, (row + 1) * (h + .012) - .006, -.005))
        model.details.append('bond of four courses with mortar')
    else:
        one(translate(0, dims[1] / 2, 0), .3, lead=True)


def slag(model, obj, rng):
    s = obj['size_m']
    k1 = model.mat('slag', obj['colour'], .6, .3)
    k2 = model.mat('rust', '#7a4a2a', .9)
    v, f = rock(rng, s * .5, s * .3, s * .42, 16, 10, .35)
    split = [i for i in range(len(f)) if (i * 7919) % 5 == 0]
    rest = [i for i in range(len(f)) if (i * 7919) % 5 != 0]
    model.add(k1, (v, f[rest]), translate(0, s * .2, 0), smooth=False,
              detail='glassy lumpy flow')
    model.add(k2, (v, f[split]), translate(0, s * .2, 0), smooth=False,
              detail='rust patches')
    pore = model.mat('pores', '#141210', .9)
    for i in range(10):
        d = np.array([rng.uniform(-1, 1), rng.uniform(.1, 1),
                      rng.uniform(-1, 1)])
        d /= np.linalg.norm(d)
        p = d * np.array([s * .48, s * .28, s * .4]) + [0, s * .2, 0]
        r = s * rng.uniform(.03, .06)
        model.add(pore, ellipsoid(r, r, r, 6, 4), translate(*p),
                  detail='gas pores')
    model.add(k1, tube([(s * .4, s * .15, 0), (s * .6, s * .08, s * .05),
                        (s * .7, s * .02, s * .02)],
                       [s * .08, s * .06, s * .03], 6),
              detail='drip lobe')


def tongs(model, obj, rng):
    s = obj['size_m']
    iron = model.mat('iron', obj['colour'], .7, .5)
    rust = model.mat('rust', '#6a3a22', .95)
    L = s
    # Two arms cross at the rivet: the handle on one side becomes the
    # jaw on the other, as forged tongs are made.
    for side in (1, -1):
        handle = [(-L * .62, 0, side * L * .11), (-L * .4, 0, side * L * .09),
                  (-L * .15, 0, side * L * .04), (0, 0, 0)]
        jaw = [(0, 0, 0), (L * .1, 0, -side * L * .07),
               (L * .22, 0, -side * L * .08), (L * .32, 0, -side * L * .04),
               (L * .36, 0, -side * L * .008)]
        model.add(iron, tube(handle, [L * .014, L * .016, L * .02,
                                      L * .024], 6),
                  translate(0, L * .03 + side * L * .012, 0),
                  detail='two forged handles')
        model.add(iron, tube(jaw, [L * .024, L * .026, L * .024, L * .02,
                                   L * .016], 6),
                  translate(0, L * .03 - side * L * .012, 0),
                  detail='bowed gripping jaws')
    model.add(rust, lathe([(0, 0), (L * .04, 0), (L * .04, L * .07),
                           (0, L * .075)], 10),
              translate(0, 0, 0), detail='rivet at the pivot')
    if 'клад' in obj['state']:
        b = model.mat('brick', '#9a5a3a', .95)
        for i in range(3):
            model.add(b, box(.28, .06, .28),
                      translate(-L * .2 + i * .02, .03 + i * .062, -L * .5),
                      smooth=False, detail='bricks of the forge wall')


def cauldron(model, obj, rng):
    s = obj['size_m']
    bronze = model.mat('bronze', '#7a6040', .55, .6)
    patina = model.mat('patina', '#5aa08a', .8, .1)
    R = s * .9
    t = s * .03
    prof = [(R * .85, 0), (R * .98, R * .25), (R, R * .45),
            (R + t * 1.5, R * .47), (R + t * 1.5, R * .5), (R - t, R * .5),
            (R - t, R * .45), (R * .98 - t, R * .25), (R * .85 - t, 0),
            (R * .85, 0)]
    a0, a1 = -0.4, 0.4
    # The shard lies on the sand with its outer face up.
    m = chain(translate(0, R * .05, 0), rot_z(math.pi / 2),
              translate(-R * .99, 0, 0))
    model.add(bronze, lathe(prof, 8, a0, a1, caps=True), m, smooth=False,
              detail='curved wall with thick rim')
    for i in range(5):
        a = rng.uniform(a0 + .1, a1 - .1)
        y = rng.uniform(R * .08, R * .4)
        g = s * rng.uniform(.03, .06)
        model.add(patina, ellipsoid(g * .3, g, g * 1.3, 6, 3),
                  chain(m, translate(R * math.cos(a) + t * .3, y,
                                     -R * math.sin(a)), rot_y(a)),
                  detail='green patina blooms')
    model.add(bronze, torus(s * .09, s * .02, 12, 5),
              chain(m, translate(R, R * .5 + s * .08, 0),
                    rot_y(math.pi / 2), rot_x(math.pi / 2)),
              detail='vertical loop handle on the rim')


def hearth(model, obj, rng):
    s = obj['size_m']
    R = s / 2
    keys = [model.mat('stone', obj['colour'], .95),
            model.mat('stone-sooty', shade(obj['colour'], .55), .95)]
    pebbles(model, None, rng, 11, 0, s * .1, keys=keys, flat=.7, ring=R,
            detail='ring of hearth stones')
    ash = model.mat('ash', '#8a8580', 1)
    coal = model.mat('charcoal', '#1a1816', .9)
    model.add(ash, disc_field(R * .85, 3, 16, lambda x, z: .01),
              detail='ash floor')
    for i in range(9):
        a = rng.uniform(0, 6.28)
        r = R * .6 * math.sqrt(rng.random())
        c = s * .03
        model.add(coal, box(c * 2, c, c * 1.2),
                  chain(translate(r * math.cos(a), .02, r * math.sin(a)),
                        rot_y(a)), smooth=False, detail='charcoal')


def piles(model, obj, rng):
    s = obj['size_m']
    wood = model.mat('wood', obj['colour'], .95)
    rot = model.mat('wood-rot', shade(obj['colour'], .6), 1)
    algae = model.mat('algae', '#5a7a3a', .9)
    n = 5 if 'ряд' in obj['state'] else 1
    for i in range(n):
        h = s * rng.uniform(.55, 1.0)
        r = s * .06
        x = (i - (n - 1) / 2) * s * .35
        m = chain(translate(x, 0, rng.uniform(-.05, .05)),
                  rot_z(rng.uniform(-.06, .06)), rot_x(rng.uniform(-.05,
                                                                   .05)))
        # Axe-hewn: eight faces, drawn flat.
        model.add(wood, lathe([(0, -.2), (r, -.2), (r, h * .92),
                               (r * .7, h)], 8), m, smooth=False,
                  detail='eight axe-hewn faces')
        for k in range(4):
            a = k * 1.57 + rng.uniform(0, .6)
            model.add(rot, box(r * .7, h * .12, r * .5),
                      chain(m, translate(r * .55 * math.cos(a), h * .95,
                                         r * .55 * math.sin(a)),
                            rot_y(-a), rot_z(.3)), smooth=False,
                      detail='rotten splintered tops')
        model.add(algae, lathe([(r * 1.02, h * .3), (r * 1.08, h * .5),
                                (r * 1.02, h * .7)], 8), m,
                  detail='algae fringe')
    if n > 1:
        beam_pts = [(-s * .75, s * .35, 0), (s * .75, s * .38, 0)]
        model.add(wood, tube(beam_pts, s * .03, 6),
                  detail='cross-beam lashed to the row')


def anchor(model, obj, rng):
    s = obj['size_m']
    stone = model.mat('stone', obj['colour'], .95)
    groove = model.mat('rope-wear', shade(obj['colour'], .6), .95)
    outer = [(-s * .38, 0), (s * .38, 0), (s * .25, s * .8),
             (s * .12, s * .9), (-s * .12, s * .9), (-s * .25, s * .8)]
    model.add(stone, pierced(outer, (0, s * .7), s * .07, s * .16, 20),
              chain(translate(0, s * .08, 0), rot_x(-math.pi / 2),
                    translate(0, -s * .45, 0)), smooth=False,
              detail='drilled rope hole')
    model.add(groove, torus(s * .075, s * .012, 16, 4),
              chain(translate(0, s * .16, -s * .25)),
              detail='rope wear around the hole')
    if 'верёв' in obj['state']:
        rope = model.mat('rope', '#8a7a58', .95)
        model.add(rope, tube([(0, s * .16, -s * .25),
                              (0, s * .5, -s * .5), (s * .1, s, -s * .6)],
                             s * .02, 5), detail='rope')


def sinker(model, obj, rng):
    s = obj['size_m']
    stone = model.mat('stone', obj['colour'], .95)
    groove = model.mat('groove', shade(obj['colour'], .5), .95)
    v, f = rock(rng, s * .5, s * .22, s * .36, 12, 7, .08)
    # Pinch a waist where the net cord was tied.
    x = v[:, 0] / (s * .5)
    k = 1 - 0.18 * np.exp(-(x / .15) ** 2)
    v = v * np.c_[np.ones(len(v)), k, k]
    model.add(stone, (v, f), translate(0, s * .2, 0), smooth=False,
              detail='flat river pebble')
    model.add(groove, torus(1, .05, 16, 3),
              chain(translate(0, s * .2, 0), rot_z(math.pi / 2),
                    scale(s * .19, s * .19, s * .3)),
              detail='pecked groove for the cord')
    for side in (1, -1):
        model.add(groove, box(s * .04, s * .1, s * .06),
                  translate(side * s * .49, s * .2, 0),
                  detail='notches at both ends')


def quern(model, obj, rng):
    s = obj['size_m']
    stone = model.mat('stone', obj['colour'], .95)
    worn = model.mat('worn', shade(obj['colour'], 1.2), .7)

    def fn(x, z):
        u, w = x / (s / 2), z / (s * .3)
        top = s * .16 - s * .06 * max(0.0, 1 - u * u) * max(0.0, 1 - w * w)
        return top
    v, f = heightfield(s * .9, s * .5, 12, 6, fn)
    model.add(worn, (v, f), detail='saddle-worn grinding face')
    model.add(stone, box(s * .92, s * .14, s * .52),
              translate(0, s * .07, 0), smooth=False,
              detail='thick stone slab')
    for side in (1, -1):
        model.add(stone, box(s * .92, s * .03, s * .03),
                  translate(0, s * .15, side * s * .26), smooth=False,
                  detail='raised rims')


def beam(model, obj, rng):
    s = obj['size_m']
    wood = model.mat('wood', obj['colour'], .95)
    dark = model.mat('wood-dark', shade(obj['colour'], .5), 1)
    h, d = .22, .2
    model.add(wood, box(s, h, d), translate(0, h / 2, 0), smooth=False,
              detail='squared timber')
    for i in range(6):
        x = -s / 2 + s * (i + .5) / 6
        model.add(wood, box(s / 6 * .8, .012, d * .9),
                  chain(translate(x, h + .002, 0), rot_z(.03 * (-1) ** i)),
                  smooth=False, detail='adze facets')
    model.add(dark, box(.14, .05, .1), translate(s * .38, h - .02, 0),
              detail='mortise')
    for x in (-s * .3, 0, s * .2):
        model.add(dark, lathe([(.015, 0), (.015, .01)], 8),
                  translate(x, h - .004, rng.uniform(-.04, .04)),
                  detail='peg holes')
    for k in range(5):
        model.add(dark, box(.05, .03, .04),
                  chain(translate(-s / 2 + .02, h * (.2 + .15 * k),
                                  rng.uniform(-.06, .06)),
                        rot_y(rng.uniform(0, 1))), smooth=False,
                  detail='split, rotted end')


def bulla(model, obj, rng):
    """A lead seal with a cross: own drawing, same lead, no light."""
    s = obj['size_m']
    lead = model.mat('lead', obj['colour'], .6, .4)
    model.add(lead, lathe([(0, 0), (s * .45, 0), (s * .5, s * .06),
                           (s * .45, s * .12), (0, s * .13)], 20),
              detail='lead disc')
    model.add(lead, tube([(-s * .5, s * .06, 0), (s * .5, s * .06, 0)],
                         s * .04, 6, False), detail='cord channel')
    for w, h in ((s * .08, s * .5), (s * .5, s * .08)):
        model.add(lead, box(w, s * .02, h), translate(0, s * .135, 0),
                  detail='cross in low relief (same lead, no glow)')
    model.add(lead, torus(s * .4, s * .012, 20, 3),
              translate(0, s * .125, 0), detail='beaded border')
    sand = model.mat('sand', SAND, 1)
    model.add(sand, disc_field(s * 1.2, 2, 12, lambda x, z: .002),
              detail='sand bed')


# ----------------------------------------------------------------------
# Stones and the shelf.

def boulder(model, obj, rng):
    s = obj['size_m']
    if obj['item'] == 'sandstone':
        keys = [model.mat('sandstone', obj['colour'], .95),
                model.mat('sandstone-bed', shade(obj['colour'], .75), .95),
                model.mat('sandstone-pale', shade(obj['colour'], 1.2), .95)]
        y = 0.0
        for i in range(5):
            h = s * rng.uniform(.08, .12)
            w = s * (.5 - .03 * abs(i - 1.5))
            model.add(keys[i % 3], rock(rng, w, h / 2, s * .36, 9, 4, .06),
                      chain(translate(rng.uniform(-.02, .02), y + h / 2, 0),
                            rot_y(rng.uniform(-.08, .08))), smooth=False,
                      detail='block split along red bedding layers')
            y += h * .92
        return
    granite(model, rng, s * .5, s * .38, s * .42,
            translate(0, s * .33, 0), obj['colour'])
    if 'водоросл' in obj['state']:
        alg = model.mat('algae', '#5a7a3a', .9)
        for i in range(40):
            a = rng.uniform(0, 6.28)
            b = rng.uniform(.3, 1.3)
            p = np.array([math.cos(a) * math.cos(b) * s * .48,
                          math.sin(b) * s * .38 + s * .33,
                          math.sin(a) * math.cos(b) * s * .4])
            L = s * rng.uniform(.1, .2)
            model.add(alg, tube([p, p + [L * .6, L * .3, L * .1],
                                 p + [L, L * .2, L * .3]],
                                [s * .008, s * .006, s * .002], 3, False),
                      detail='filamentous algae tufts')


def gravel(model, obj, rng):
    s = obj['size_m']
    quartz = obj['item'] == 'quartz'
    base = model.mat('sand', SAND, 1)
    ground(model, base, s / 2, rng, .02)
    if quartz:
        keys = [model.mat('quartz', obj['colour'], .35),
                model.mat('quartz-milky', '#f4f0e8', .3),
                model.mat('quartz-iron', '#d8b898', .4)]
    else:
        keys = [model.mat('pebble', obj['colour'], .9),
                model.mat('pebble-dark', shade(obj['colour'], .6), .9),
                model.mat('pebble-red', '#a0604a', .9),
                model.mat('pebble-pale', shade(obj['colour'], 1.3), .9)]
    pebbles(model, None, rng, 110 if not quartz else 90, s * .45,
            .035 if 'мелк' in obj['state'] else .06, keys=keys, flat=.55,
            detail='rounded pebbles of mixed rock')


def ripples(model, obj, rng):
    s = obj['size_m']
    sand = model.mat('sand', obj['colour'], 1)
    lam = .08 if 'мелк' in obj['state'] else .2

    def fn(x, z):
        ph = (x + .05 * math.sin(z * 3)) / lam
        u = ph - math.floor(ph)
        crest = u / .7 if u < .7 else (1 - u) / .3
        return .012 * crest * (1 - (2 * z / s) ** 8)
    v, f = heightfield(s, s * .6, 60, 12, fn)
    crest = v[f][:, :, 1].mean(axis=1) > .006
    model.add(sand, (v, f[~crest]), detail='troughs')
    model.add(model.mat('sand-crest', shade(obj['colour'], 1.25), 1),
              (v, f[crest]), detail='asymmetric ripple crests')
    shells = model.mat('shell', '#e0d8c4', .6)
    for i in range(8):
        model.add(shells, ellipsoid(.008, .004, .006, 6, 3),
                  translate(rng.uniform(-s / 2, s / 2), .006,
                            rng.uniform(-s * .25, s * .25)),
                  detail='shell bits in the troughs')


def silt(model, obj, rng):
    s = obj['size_m']
    black = obj['item'] == 'blacksilt'
    key = model.mat('silt', obj['colour'], 1)
    bumps = [(rng.uniform(-s / 2, s / 2), rng.uniform(-s / 2, s / 2))
             for _ in range(12)]

    def fn(x, z):
        y = 0.0
        for bx, bz in bumps:
            y += .01 * math.exp(-((x - bx) ** 2 + (z - bz) ** 2) / .01)
        return y
    model.add(key, disc_field(s / 2, 8, 24, fn), detail='soft silt surface')
    hole = model.mat('burrow', shade(obj['colour'], .4), 1)
    for bx, bz in bumps:
        model.add(hole, lathe([(.012, .012), (.02, .006), (.012, 0)], 8),
                  translate(bx, 0, bz), detail='burrow mounds with holes')
    if black:
        rust = model.mat('iron-stain', '#7a4a28', 1)
        for i in range(6):
            a = rng.uniform(0, 6.28)
            L = s * rng.uniform(.15, .3)
            model.add(rust, box(L, .004, .03),
                      chain(translate(rng.uniform(-s / 3, s / 3), .003,
                                      rng.uniform(-s / 3, s / 3)),
                            rot_y(a)), detail='rusty iron streaks')
    else:
        trail = model.mat('trail', shade(obj['colour'], .8), 1)
        pts = [(x, .004, .15 * math.sin(x * 4)) for x in
               np.linspace(-s * .4, s * .4, 12)]
        model.add(trail, tube(pts, .01, 3, False),
                  detail='a snail trail')


def outcrop(model, obj, rng):
    s = obj['size_m']
    cols = ['#9a7a5a', '#b08a64', '#80664c', '#a88868']
    for i in range(5):
        k = model.mat(f'clay-{i % 4}', cols[i % 4], .95)
        h = s * .08
        w = s * (1 - i * .12)
        model.add(k, rock(rng, w / 2, h / 2, s * .3, 10, 4, .05),
                  translate(-i * s * .04, h * (i + .5), -i * s * .02),
                  smooth=False, detail='stacked bedding layers')
    ov = model.mat('clay-overhang', '#6a5038', 1)
    model.add(ov, box(s * .5, s * .03, s * .1),
              translate(0, s * .08, s * .3), smooth=False,
              detail='undercut eroded front')


def schist(model, obj, rng):
    s = obj['size_m']
    k1 = model.mat('schist', obj['colour'], .6, .1)
    k2 = model.mat('schist-sheen', shade(obj['colour'], 1.25), .4, .15)
    for i in range(6):
        w = s * rng.uniform(.4, .7)
        d = s * rng.uniform(.25, .45)
        poly = [(-w / 2, -d / 2), (w / 2, -d * .4), (w * .4, d / 2),
                (-w * .3, d * .45)]
        m = chain(translate(rng.uniform(-s * .2, s * .2), s * .015 +
                            i * s * .022, rng.uniform(-s * .15, s * .15)),
                  rot_y(rng.uniform(-.4, .4)), rot_x(-math.pi / 2),
                  rot_z(rng.uniform(-.05, .05)))
        model.add(k1 if i % 2 else k2, plate(poly, s * .02), m,
                  smooth=False, detail='thin split flags (foliation)')


def edge(model, obj, rng):
    s = obj['size_m']
    k = model.mat('slope', obj['colour'], .95)
    deep = model.mat('slope-dark', shade(obj['colour'], .35), 1)

    def fn(x, z):
        return 0.0 if x < 0 else -min(s * .6, (x / (s * .3)) ** 1.5 * s * .3)
    v, f = heightfield(s, s * .6, 20, 6, fn)
    cen = v[f].mean(axis=1)
    dark = cen[:, 1] < (-s * .25 if 'темнот' in obj['state'] else -s)
    model.add(k, (v, f[~dark]), smooth=False, detail='lip of the drop')
    if dark.any():
        model.add(deep, (v, f[dark]), smooth=False,
                  detail='darkness below the edge')
    rs = model.mat('talus', shade(obj['colour'], 1.2), .95)
    for i in range(14):
        x = rng.uniform(s * .05, s * .4)
        z = rng.uniform(-s * .28, s * .28)
        r = rng.uniform(.06, .16)
        model.add(rs, rock(rng, r, r * .7, r, 6, 4, .2),
                  translate(x, fn(x, z) + r * .4, z), smooth=False,
                  detail='talus stones on the slope')


def terrace(model, obj, rng):
    s = obj['size_m']
    k = model.mat('terrace', obj['colour'], .95)
    beach = model.mat('beach-pebble', shade(obj['colour'], 1.25), .9)
    notch = model.mat('notch', shade(obj['colour'], .6), 1)

    def fn(x, z):
        if x < -s * .1:
            return s * .25
        if x < s * .05:
            return s * .25 - (x + s * .1) / (s * .15) * s * .2
        return s * .05 - (x - s * .05) * .05
    model.add(k, heightfield(s, s * .5, 24, 6, fn), smooth=False,
              detail='step of the drowned shore')
    model.add(notch, box(s * .03, s * .05, s * .5),
              translate(-s * .1, s * .22, 0), detail='wave-cut notch')
    for i in range(26):
        x = rng.uniform(-s * .1, s * .15)
        z = rng.uniform(-s * .24, s * .24)
        r = rng.uniform(.03, .07)
        model.add(beach, ellipsoid(r, r * .5, r * .8, 6, 4),
                  translate(x, fn(x, z) + r * .25, z),
                  detail='rounded beach pebbles of the old shoreline')


def seep(model, obj, rng):
    s = obj['size_m']
    sand = model.mat('sand', SAND, 1)
    shimmer = model.mat('shimmer', obj['colour'], .1, 0, .35)

    def fn(x, z):
        r = math.hypot(x, z) / (s / 2)
        return .04 * math.exp(-((r - .35) / .15) ** 2) - .03 * max(
            0.0, 1 - r / .25)
    model.add(sand, disc_field(s / 2, 8, 20, fn),
              detail='sand crater with a raised rim')
    pts = [(.02 * math.sin(i), .02 + i * .05, .02 * math.cos(i * 1.3))
           for i in range(10)]
    model.add(shimmer, tube(pts, [.01 + .006 * i for i in range(10)], 6),
              detail='shimmering upwelling thread')
    grain = model.mat('grain', '#d8ccb0', 1)
    for i in range(12):
        model.add(grain, ellipsoid(.004, .004, .004, 4, 3),
                  translate(rng.uniform(-.03, .03), .02 + i * .03,
                            rng.uniform(-.03, .03)),
                  detail='lifted sand grains')


# ----------------------------------------------------------------------
# Plants.

def stonewort(model, obj, rng):
    s = obj['size_m']
    stem = model.mat('chara', obj['colour'], .8)
    tip = model.mat('chara-tip', shade(obj['colour'], 1.3), .7)
    count = 22 if 'густ' in obj['state'] else 9
    for i in range(count):
        a = rng.uniform(0, 6.28)
        r = s * .45 * math.sqrt(rng.random())
        base = np.array([r * math.cos(a), 0, r * math.sin(a)])
        h = s * rng.uniform(.18, .35)
        lean = np.array([rng.uniform(-.1, .1), 1, rng.uniform(-.1, .1)])
        pts = [base + lean * h * k / 4 for k in range(5)]
        model.add(stem, tube(pts, .003, 3, False), detail='jointed stems')
        for k in (1, 2, 3, 4):
            c = pts[k]
            for j in range(6):
                b = j * math.pi / 3 + k * .5
                model.add(tip if k == 4 else stem,
                          plate([(0, -.002), (.03, 0), (0, .002)]),
                          chain(translate(*c), rot_y(-b), rot_z(.6)),
                          detail='whorls of branchlets at each node')
    model.add(model.mat('silt', SILT, 1), disc_field(
        s / 2, 2, 14, lambda x, z: 0.0), detail='silt floor')


def pondweed(model, obj, rng, milfoil=False):
    s = obj['size_m']
    stem = model.mat('stem', shade(obj['colour'], .8), .8)
    leaf = model.mat('leaf', obj['colour'], .6)
    count = 7 if 'густ' in obj['state'] else 4
    for i in range(count):
        a = 2 * math.pi * i / count + rng.uniform(-.3, .3)
        base = np.array([s * .2 * math.cos(a), 0, s * .2 * math.sin(a)])
        h = s * rng.uniform(.75, 1.0)
        sway = rng.uniform(-.1, .1)
        pts = [base + [sway * h * (k / 6) ** 2, h * k / 6, 0]
               for k in range(7)]
        model.add(stem, tube(pts, .004, 4, False), detail='stems')
        nodes = 9 if milfoil else 7
        for k in range(1, nodes):
            p = np.array(pts[0]) + (np.array(pts[-1]) - pts[0]) * k / nodes
            if milfoil:
                for j in range(4):
                    b = j * math.pi / 2 + k * .4
                    m = chain(translate(*p), rot_y(b), rot_z(-.2))
                    model.add(stem, plate([(0, -.001), (.05, 0),
                                           (0, .001)]),
                              chain(m, rot_x(math.pi / 2)),
                              detail='whorls of four feathery leaves')
                    for q in range(3):
                        x = .01 + q * .014
                        model.add(leaf, plate([(x, 0), (x + .004, .018),
                                               (x + .006, 0),
                                               (x + .004, -.018)]),
                                  chain(m, rot_x(math.pi / 2)))
            else:
                b = k * 2.4
                L = .09 * (1 - k / nodes * .4)
                m = chain(translate(*p), rot_y(b), rot_z(.5))
                model.add(leaf, plate([(0, 0), (L * .3, L * .12),
                                       (L, 0), (L * .3, -L * .12)]),
                          chain(m, rot_x(math.pi / 2)),
                          detail='alternate lance leaves')
        if not milfoil and i % 2 == 0:
            model.add(model.mat('spike', '#6a5a3a', .8),
                      tube([pts[-1], pts[-1] + np.array([0, .05, 0])],
                           .006, 5), detail='flower spikes')


def reeds(model, obj, rng):
    s = obj['size_m']
    culm = model.mat('culm', obj['colour'], .6)
    node = model.mat('culm-node', shade(obj['colour'], .6), .7)
    leaf = model.mat('reed-leaf', mix(obj['colour'], '#5a7a3a', .5), .6)
    plume = model.mat('panicle', '#6a4a40', .9)
    count = 14
    for i in range(count):
        x = rng.uniform(-s * .35, s * .35)
        z = rng.uniform(-s * .12, s * .12)
        h = s * rng.uniform(.8, 1.0)
        lean = rng.uniform(-.06, .06)
        pts = [(x + lean * h * k / 6, h * k / 6, z) for k in range(7)]
        model.add(culm, tube(pts, [.01 - .001 * k for k in range(7)], 5,
                             False), detail='hollow culms')
        for k in (1, 2, 3, 4, 5):
            p = pts[k]
            model.add(node, torus(.01 - .001 * k, .002, 6, 3),
                      translate(*p), detail='nodes')
            b = k * 2.1 + i
            L = s * .22
            m = chain(translate(*p), rot_y(b), rot_z(.9))
            model.add(leaf, plate([(0, -.008), (L * .5, -.006),
                                   (L, 0), (L * .5, .006), (0, .008)]),
                      chain(m, rot_x(math.pi / 2), rot_z(-.4)),
                      detail='long arching ribbon leaves')
        if i % 3 != 2:
            top = np.array(pts[-1])
            for j in range(5):
                b = j * 1.26
                model.add(plume, tube([top, top + [.04 * math.cos(b), .1,
                                                   .04 * math.sin(b)],
                                       top + [.07 * math.cos(b), .14,
                                              .07 * math.sin(b)]],
                                      [.006, .008, .002], 4, False),
                          detail='purple-brown panicles')


def algae_on_stone(model, obj, rng):
    s = obj['size_m']
    stone = model.mat('stone', '#7a7670', .95)
    thread = model.mat('algae', obj['colour'], .8)
    model.add(stone, rock(rng, s * .5, s * .3, s * .4, 10, 6, .15),
              translate(0, s * .25, 0), smooth=False, detail='host stone')
    for i in range(110):
        a = rng.uniform(0, 6.28)
        b = rng.uniform(.1, 1.4)
        p = np.array([math.cos(a) * math.cos(b) * s * .5,
                      math.sin(b) * s * .3 + s * .25,
                      math.sin(a) * math.cos(b) * s * .4])
        L = s * rng.uniform(.25, .5)
        pts = [p, p + [L * .5, L * .12, L * .05],
               p + [L, L * .08, L * .12]]
        model.add(thread, tube(pts, [.002, .0015, .0005], 3, False),
                  detail='hair-like filaments streaming with the current')


# ----------------------------------------------------------------------
# Small life.

def snail_on_stone(model, obj, rng):
    s = obj['size_m']
    stone = model.mat('stone', '#8a8680', .95)
    shell = model.mat('shell', obj['colour'], .5)
    body = model.mat('snail-body', '#5a5040', .8)
    model.add(stone, rock(rng, .1, .05, .08, 10, 6, .12),
              translate(0, .05, 0), smooth=False, detail='host stone')
    m = chain(translate(0, .1, 0), rot_z(-1.2))
    snail_shell(model, shell, s, m, lip=body)
    model.add(body, ellipsoid(s * .35, s * .08, s * .18, 8, 4),
              translate(s * .1, .098, 0), detail='creeping foot')
    for side in (1, -1):
        model.add(body, tube([(s * .4, .1, side * s * .05),
                              (s * .6, .105, side * s * .12)], s * .02, 4),
                  detail='flat tentacles')


def shells(model, obj, rng):
    s = obj['size_m']
    sand = model.mat('sand', SAND, 1)
    shell = model.mat('shell', obj['colour'], .5)
    worn = model.mat('shell-worn', shade(obj['colour'], .8), .7)
    ground(model, sand, s / 2, rng, .005)
    for i in range(11):
        h = rng.uniform(.012, .03)
        m = chain(translate(rng.uniform(-s * .4, s * .4), h * .3,
                            rng.uniform(-s * .4, s * .4)),
                  rot_y(rng.uniform(0, 6.28)), rot_z(1.4))
        snail_shell(model, shell if i % 3 else worn, h, m, 3.5, k=26,
                    sides=6)
    model.details.append('empty pond-snail shells, some worn')


def tubes(model, obj, rng):
    s = obj['size_m']
    silt = model.mat('silt', SILT, 1)
    tube_k = model.mat('tube', obj['colour'], 1)
    larva = model.mat('larva', '#a02020', .6)
    model.add(silt, disc_field(.08, 3, 16, lambda x, z: 0.0),
              detail='silt patch')
    for i in range(14):
        a = rng.uniform(0, 6.28)
        r = .07 * math.sqrt(rng.random())
        x, z = r * math.cos(a), r * math.sin(a)
        h = s * rng.uniform(.4, 1.0)
        model.add(tube_k, lathe([(.002, h), (.0025, 0), (.0015, 0),
                                 (.0015, h)], 6), translate(x, 0, z),
                  detail='silk-and-silt tubes')
        if i % 4 == 0:
            model.add(larva, tube([(x, h, z), (x + .003, h + .006, z)],
                                  .0012, 4), detail='red larva peeking out')


def swarm(model, obj, rng):
    s = obj['size_m']
    key = model.mat('amphipod', obj['colour'], .5)
    for i in range(12):
        lift = .02 + rng.uniform(0, .06)
        m = chain(translate(rng.uniform(-.08, .08), lift,
                            rng.uniform(-.08, .08)),
                  rot_y(rng.uniform(0, 6.28)), rot_z(rng.uniform(-.4, .4)))
        amphipod(model, key, s, m)
    model.add(model.mat('stone', '#8a8680', .95),
              rock(rng, .1, .03, .08, 8, 5, .1), translate(0, 0, 0),
              smooth=False, detail='stone on the bottom')


def plankton(model, obj, rng):
    s = obj['size_m']
    key = model.mat('copepod', obj['colour'], .4, 0, .8)
    eye = model.mat('copepod-eye', '#c03020', .5)
    for i in range(170):
        u, v = rng.random(), rng.random()
        th, ph = 2 * math.pi * u, math.acos(2 * v - 1)
        r = s / 2 * rng.random() ** .5
        p = (r * math.sin(ph) * math.cos(th), s / 2 + r * math.cos(ph) * .5,
             r * math.sin(ph) * math.sin(th))
        c = .0025
        m = chain(translate(*p), rot_y(rng.uniform(0, 6.28)))
        model.add(key, plate([(c, 0), (-c * .2, c * .4), (-c, 0),
                              (-c * .2, -c * .4)]), m,
                  detail='copepod bodies (drawn 2.5 mm)')
        model.add(key, plate([(c * .6, 0), (c * .3, c * 1.8),
                              (c * .2, 0)]), m, detail='antennae')
        if i % 3 == 0:
            model.add(eye, plate([(c * .7, 0), (c * .5, c * .2),
                                  (c * .5, -c * .2)]), m,
                      detail='red eye spot')


# ----------------------------------------------------------------------
# People and the lake today.

def bottle(model, obj, rng):
    s = obj['size_m']
    glass = model.mat('glass', obj['colour'], .1, 0, .6)
    lip = model.mat('glass-lip', shade(obj['colour'], .8), .1, 0, .75)
    prof = [(0, s * .03), (s * .05, 0), (s * .12, 0), (s * .125, s * .05),
            (s * .125, s * .55), (s * .1, s * .65), (s * .045, s * .75),
            (s * .042, s * .93), (s * .038, s * .93)]
    m = chain(translate(0, s * .125, 0), rot_z(math.pi / 2))
    model.add(glass, lathe(prof, 16), m, detail='shoulder and neck')
    model.add(lip, torus(s * .045, s * .01, 12, 4),
              chain(m, translate(0, s * .92, 0)), detail='lip ring')
    model.add(lip, lathe([(0, s * .05), (s * .06, s * .01)], 12), m,
              detail='kicked-in punt')
    model.add(model.mat('fouling', '#5a6a3a', .9),
              ellipsoid(s * .08, s * .02, s * .06, 6, 3),
              translate(-s * .2, s * .24, 0), detail='a patch of fouling')
    model.add(model.mat('sand', SAND, 1), disc_field(
        s * .8, 3, 14, lambda x, z: .02 * max(0.0, 1 - abs(z) / (s * .3))),
        detail='sand ridge along it')


def chain_line(model, obj, rng):
    s = obj['size_m']
    steel = model.mat('chain', obj['colour'], .6, .6)
    rust = model.mat('rust', '#7a4a2a', .9)
    link = .1
    n = int(s / (link * .8))
    for i in range(n):
        y = .25 + i * link * .8
        m = chain(translate(0, y, 0), rot_y(i % 2 * math.pi / 2),
                  scale(1, 1.6, 1))
        model.add(rust if i % 7 == 3 else steel,
                  torus(link * .3, link * .07, 10, 4),
                  chain(m, rot_x(math.pi / 2)),
                  detail='interlocking links at right angles')
    conc = model.mat('concrete', '#8a8a82', 1)
    model.add(conc, box(.5, .25, .5), translate(0, .125, 0), smooth=False,
              detail='concrete sinker block')
    model.add(steel, torus(.05, .015, 10, 4),
              chain(translate(0, .28, 0), rot_x(math.pi / 2)),
              detail='shackle')


def ghost_net(model, obj, rng):
    s = obj['size_m']
    mesh = model.mat('net', obj['colour'], .8)
    fl = model.mat('float', '#c8a060', .8)
    lead = model.mat('net-lead', '#5a5a58', .6, .4)
    W, H, nx, ny = s, s * .45, 14, 7

    def surf(u, v):
        x = -W / 2 + W * u
        y = .05 + H * v * (0.55 + .45 * math.sin(u * 3.1))
        z = .12 * math.sin(u * 6.3 + v * 2) * v
        return (x, y, z)
    for j in range(ny + 1):
        pts = [surf(i / 16, j / ny) for i in range(17)]
        model.add(lead if j == 0 else mesh,
                  tube(pts, .006 if j in (0, ny) else .0025, 3, False),
                  detail='knotted mesh')
    for i in range(nx + 1):
        pts = [surf(i / nx, j / 8) for j in range(9)]
        model.add(mesh, tube(pts, .0025, 3, False))
    for i in range(7):
        p = surf((i + .5) / 7, 1)
        model.add(fl, ellipsoid(.035, .02, .02, 8, 5), translate(*p),
                  detail='bark floats on the head-rope')
    for i in range(6):
        p = surf((i + .5) / 6, 0)
        model.add(lead, ellipsoid(.03, .018, .022, 6, 4), translate(*p),
                  detail='sinkers on the foot-rope')
    if 'рыб' in obj['state']:
        fish(model, 'chebak', .28, chain(translate(*surf(.45, .5)),
                                         rot_z(-.4)), '#b9c4c9')
        model.details.append('a dace caught in the mesh')


def tether(model, obj, rng):
    s = obj['size_m']
    cable = model.mat('tether', obj['colour'], .6)
    stripe = model.mat('tether-mark', '#1a1a1a', .6)
    fl = model.mat('tether-float', '#e0d040', .6)
    pts = [(-s / 2 + s * k / 20, .3 + .2 * (1 - (2 * k / 20 - 1) ** 2),
            .05 * math.sin(k)) for k in range(21)]
    model.add(cable, tube(pts, .007, 8, True), detail='orange cable')
    for k in (4, 8, 12, 16):
        model.add(stripe, torus(.0075, .002, 8, 3),
                  chain(translate(*pts[k]), rot_z(math.pi / 2)),
                  detail='metre marks')
    for k in (6, 14):
        model.add(fl, lathe([(.008, -.05), (.03, -.04), (.03, .04),
                             (.008, .05)], 12),
                  chain(translate(*pts[k]), rot_z(math.pi / 2)),
                  detail='clip-on float collars')


# ----------------------------------------------------------------------
# The water's own phenomena: drawn as the eye sees them, thin and pale.

def water(model, obj, rng):
    s = obj['size_m']
    shape = obj['shape']
    col = obj['colour']
    k = model.mat('water', col, .1, 0, .4)
    k2 = model.mat('water-bright', shade(col, 1.3), .1, 0, .55)
    if shape == 'light' and obj['item'] == 'caustics':
        sand = model.mat('sand', SAND, 1)
        model.add(sand, heightfield(s, s, 8, 8, lambda x, z: 0.0))
        seeds = [(rng.uniform(-s / 2, s / 2), rng.uniform(-s / 2, s / 2))
                 for _ in range(26)]
        for i, (x, z) in enumerate(seeds):
            near = sorted(seeds, key=lambda p: (p[0] - x) ** 2
                          + (p[1] - z) ** 2)[1:4]
            for nx_, nz in near:
                model.add(k2, tube([(x, .005, z), ((x + nx_) / 2, .006,
                                                   (z + nz) / 2 + .03),
                                    (nx_, .005, nz)], .008, 3, False),
                          detail='bright net of focused sunlight')
    elif shape == 'light':
        n = 7 if 'кос' in obj['state'] else 3
        for i in range(n):
            x = rng.uniform(-s / 3, s / 3)
            z = rng.uniform(-s / 3, s / 3)
            w = rng.uniform(.15, .4)
            model.add(k, box(w, s, .02),
                      chain(translate(x, s / 2, z), rot_z(.35),
                            rot_y(rng.uniform(-.2, .2))),
                      detail='slanting shafts of light')
    elif shape == 'bubbles':
        # Groups of breaths: each exhale a cluster, then a pause.
        y = .1
        for breath in range(5):
            for j in range(6):
                r = .01 + .004 * breath + .004 * rng.random()
                model.add(k2, ellipsoid(r, r * .6, r, 8, 4),
                          translate(rng.uniform(-.04, .04), y,
                                    rng.uniform(-.04, .04)),
                          detail='mushroom-capped bubbles in breath groups')
                y += r * 2.2
            y += .15
    elif shape in ('layer', 'intwave'):
        amp = .35 if shape == 'intwave' else .05
        lam = s / 1.5 if shape == 'intwave' else s / 6

        def fn(x, z):
            return 1 + amp * math.sin(2 * math.pi * x / lam + .3 * z)
        model.add(k, heightfield(s, s * .5, 36, 6, fn),
                  detail='undulating boundary sheet')
        for z in (-s * .15, 0, s * .15):
            xs = np.linspace(-s / 2, s / 2, 30)
            pts = [(x, fn(x, z) + .02, z) for x in xs]
            model.add(k2, tube(pts, .01, 3, False),
                      detail='shimmer lines along the crests')
    elif shape == 'eddy':
        stub = model.mat('obstacle', '#8a8680' if 'валун' in obj['state']
                         else '#5a4a38', .95)
        if 'валун' in obj['state']:
            model.add(stub, rock(rng, .3, .25, .3, 8, 5), translate(
                -s / 2, .25, 0), smooth=False, detail='the boulder')
        else:
            model.add(stub, lathe([(0, 0), (.1, 0), (.1, .9), (0, .9)], 8),
                      translate(-s / 2, 0, 0), smooth=False,
                      detail='the pile')
        for i in range(5):
            side = 1 if i % 2 else -1
            cx = -s / 2 + .4 + i * .45
            pts = [(cx + .12 * (1 + a / 6) * math.cos(a), .3,
                    side * .15 + .12 * (1 + a / 6) * math.sin(a) * side)
                   for a in np.linspace(0, 10, 24)]
            model.add(k2, tube(pts, .008, 3, False),
                      detail='alternating vortices')
    elif shape in ('current', 'langmuir', 'plume', 'upwelling'):
        rows = {'current': 6, 'langmuir': 5, 'plume': 7,
                'upwelling': 6}[shape]
        for r in range(rows):
            z = -s / 2 + s * (r + .5) / rows
            if shape == 'upwelling':
                pts = [(x, .2 + max(0.0, x + s / 4) ** 1.5 * .6, z)
                       for x in np.linspace(-s / 2, s / 2, 14)]
            elif shape == 'plume':
                pts = [(x, .5 + .1 * math.sin(x * 2 + r), z * (.3 + .7 * (
                    x + s / 2) / s)) for x in np.linspace(-s / 2, s / 2, 14)]
            elif shape == 'langmuir':
                pts = [(x, 1.5, z) for x in np.linspace(-s / 2, s / 2, 6)]
            else:
                pts = [(x, .4 + .05 * math.sin(x * 2 + r), z + .1 *
                        math.sin(x)) for x in np.linspace(-s / 2, s / 2,
                                                          14)]
            model.add(k2, tube(pts, .012 if shape != 'langmuir' else .03,
                               3, False), detail='flow lines')
            end = np.array(pts[-1])
            d = end - pts[-2]
            ang = math.atan2(d[1], d[0])
            model.add(k2, plate([(0, .06), (.12, 0), (0, -.06)]),
                      chain(translate(*end), rot_z(ang)),
                      detail='arrow of the flow')
        if shape == 'plume':
            model.add(model.mat('silt-cloud', '#a09a78', .9, 0, .3),
                      rock(rng, s * .3, .3, s * .25, 10, 6, .3),
                      translate(-s * .3, .5, 0), detail='silt-laden lobe')
        if shape == 'langmuir':
            foam = model.mat('foam', '#f4f8f8', .6)
            for r in range(rows):
                z = -s / 2 + s * (r + .5) / rows
                for i in range(8):
                    model.add(foam, ellipsoid(.05, .01, .03, 6, 3),
                              translate(rng.uniform(-s / 2, s / 2), 1.53,
                                        z + rng.uniform(-.05, .05)),
                              detail='foam lines at the convergences')
    elif shape == 'particles':
        flake = model.mat('snow', col, .7, 0, .8)
        for i in range(220):
            p = (rng.uniform(-s / 2, s / 2), rng.uniform(0, s),
                 rng.uniform(-s / 2, s / 2))
            c = rng.uniform(.004, .012)
            model.add(flake, plate([(c, 0), (0, c * .7), (-c, 0),
                                    (0, -c * .9)]),
                      chain(translate(*p), rot_y(rng.uniform(0, 6)),
                            rot_x(rng.uniform(0, 6))),
                      detail='fluffy aggregates of marine snow')
    elif shape == 'cloud':
        for i in range(9):
            r = rng.uniform(.2, .45) * s / 2
            model.add(k, rock(rng, r, r * .7, r, 10, 6, .3),
                      translate(rng.uniform(-s / 3, s / 3),
                                s * .3 + rng.uniform(-.2, .2),
                                rng.uniform(-s / 4, s / 4)),
                      detail='billowing lobes of suspended silt')
    else:
        raise ValueError(f'no water drawing for {shape}')


# ----------------------------------------------------------------------
# Dispatch.

def fish_object(model, obj, rng):
    L = obj['size_m']
    sp = obj['item']
    state = obj['state']
    if 'стай' in state:
        count = 7 if L < .2 else (5 if L < .5 else 3)
        school(model, sp, L, obj['colour'], count, L * 1.4, rng)
        model.details.append(f'school of {count}')
    else:
        fish(model, sp, L, np.eye(4), obj['colour'])
    if 'камн' in state:
        under = 'под' in state
        granite(model, rng, L * .6, L * .3, L * .5,
                translate(-L * .05, L * .45 if under else -L * .05,
                          0 if under else -L * .75))
        model.details.append('the stone it shelters by')
    if 'трав' in state:
        g = model.mat('weed', '#4a6a3a', .8)
        for i in range(6):
            x = rng.uniform(-L, L)
            model.add(g, tube([(x, -L * .5, -L * .4), (x + .02, L * .4,
                                                       -L * .45),
                               (x + .05, L, -L * .3)], .004, 3, False),
                      detail='water weed around it')
    if 'песк' in state:
        model.add(model.mat('sand', SAND, 1), disc_field(
            L * 1.2, 2, 14, lambda x, z: -L * .08), detail='sand under it')
    if 'устья' in state:
        pebbles(model, model.mat('pebble', '#8a8070', .9), rng, 14, L,
                L * .08, y0=-L * .15, detail='river-mouth pebbles')


BUILDERS = {
    'disc': lambda m, o, r: (bulla if o['item'] == 'bulla'
                             else millstone)(m, o, r),
    'jar': khum, 'wall': foundation, 'brick': brick, 'ring': hearth,
    'pile': piles, 'anchor': anchor, 'sinker': sinker, 'beam': beam,
    'boulder': boulder, 'gravel': gravel, 'ripples': ripples,
    'silt': silt, 'outcrop': outcrop, 'edge': edge, 'terrace': terrace,
    'seep': seep, 'meadow': stonewort, 'reeds': reeds,
    'fuzz': algae_on_stone, 'shell': snail_on_stone, 'shells': shells,
    'tubes': tubes, 'swarm': swarm, 'bottle': bottle, 'chain': chain_line,
    'net': ghost_net, 'rope': tether, 'fish': fish_object,
}


def build_lake(obj):
    rng, seed = seeded(obj['id'])
    mid = 'lake-' + obj['id'].replace('.', '-')
    model = Model(mid)
    shape = obj['shape']
    if obj['category'] == 'water':
        water(model, obj, rng)
    elif shape == 'bird':
        pitch = .5 if 'всплыв' in obj['state'] else -.45
        bird(model, obj['item'], obj['size_m'], pitch, rng)
    elif shape == 'stems':
        pondweed(model, obj, rng, milfoil=obj['item'] == 'urut')
    elif shape == 'sherds':
        (bones if obj['item'] == 'kosti' else sherds)(model, obj, rng)
    elif shape == 'slab':
        (quern if obj['item'] == 'kayrak' else schist)(model, obj, rng)
    elif shape == 'shard':
        {'kleshchi': tongs, 'kotel': cauldron, 'shlak': slag}[
            obj['item']](model, obj, rng)
    elif shape == 'cloud' and obj['category'] == 'life':
        plankton(model, obj, rng)
    else:
        BUILDERS[shape](model, obj, rng)
    return mid, model, seed


# ----------------------------------------------------------------------
# The knight's five traces (scripts/story/atlas_nodes.py TRACES).

TRACES = [
    {'id': 'diary', 'ru': 'Дневник рыцаря в кожаном переплёте',
     'shape': 'book', 'colour': '#5a3a22', 'size': 0.3,
     'loot': 'hand-over', 'holy': False, 'nodes': [4, 96]},
    {'id': 'amphora', 'ru': 'Амфора со свитком о литье колоколов',
     'shape': 'amphora', 'colour': '#a8643c', 'size': 0.6,
     'loot': 'hand-over', 'holy': False, 'nodes': [14]},
    {'id': 'astrolabe', 'ru': 'Астролябия рыцаря', 'shape': 'astrolabe',
     'colour': '#b08d57', 'size': 0.25, 'loot': 'hand-over',
     'holy': False, 'nodes': [28, 40, 82]},
    {'id': 'khachkar', 'ru': 'Кайрак — крест-камень братьев',
     'shape': 'khachkar', 'colour': '#8c8578', 'size': 1.6, 'loot': None,
     'holy': True, 'nodes': [15]},
    {'id': 'shield', 'ru': 'Щит рыцаря', 'shape': 'shield',
     'colour': '#4a4640', 'size': 0.9, 'loot': 'hand-over', 'holy': False,
     'nodes': [92, 41]},
]


def diary(model, t, rng):
    s = t['size']
    leather = model.mat('leather', t['colour'], .8)
    band = model.mat('leather-band', shade(t['colour'], .7), .8)
    page = model.mat('parchment', '#c8b89a', .9)
    iron = model.mat('clasp', '#4a4a48', .6, .5)
    W, D, H = s, s * .72, s * .22
    for y in (H * .07, H * .93):
        model.add(leather, box(W, H * .14, D), translate(0, y, 0),
                  smooth=False, detail='leather-covered boards')
    model.add(page, box(W * .96, H * .72, D * .94),
              translate(W * .01, H / 2, 0), smooth=False,
              detail='swollen block of pages')
    model.add(leather, lathe([(H * .5, -D / 2), (H * .5, D / 2)], 8,
                             math.pi / 2, math.pi * 1.5),
              chain(translate(-W / 2, H / 2, 0), rot_x(math.pi / 2)),
              detail='rounded spine')
    for k in (-1, 0, 1):
        model.add(band, torus(H * .5, H * .06, 10, 4),
                  chain(translate(-W / 2, H / 2, k * D * .25),
                        rot_x(0)), detail='raised bands on the spine')
    model.add(iron, box(W * .25, H * .1, D * .1),
              translate(W / 2, H / 2, 0), detail='iron clasp')

    def drift(x, z):
        return .02 * max(0.0, 1 - math.hypot(x, z) / (s * .9))
    model.add(model.mat('silt', SILT, 1), disc_field(s * .9, 3, 16, drift),
              detail='silt it lay in')


def amphora(model, t, rng):
    s = t['size']
    clay = model.mat('clay', t['colour'], .9)
    dark = model.mat('clay-mouth', shade(t['colour'], .4), .95)
    scroll = model.mat('scroll', '#c8b89a', .9)
    H = s
    prof = [(0, 0), (s * .03, H * .02), (s * .06, H * .1),
            (s * .17, H * .35), (s * .2, H * .55), (s * .15, H * .72),
            (s * .07, H * .8), (s * .065, H * .95), (s * .08, H * .97),
            (s * .08, H), (s * .055, H)]
    m = chain(translate(0, s * .16, 0), rot_z(-1.45),
              translate(0, -H * .5, 0))
    model.add(clay, lathe(prof, 18), m, detail='pointed toe and body')
    model.add(dark, lathe([(s * .055, H), (s * .001, H * .96)], 18), m,
              detail='open mouth')
    for side in (1, -1):
        pts = [(side * s * .065, H * .9, 0), (side * s * .16, H * .88, 0),
               (side * s * .17, H * .78, 0), (side * s * .14, H * .7, 0)]
        model.add(clay, tube(pts, s * .018, 6), m, detail='two handles')
    model.add(scroll, lathe([(s * .035, 0), (s * .035, s * .12)], 10),
              chain(m, translate(0, H * .94, 0)),
              detail='rolled scroll at the mouth')
    model.add(model.mat('silt', SILT, 1), disc_field(
        s * .8, 4, 18, lambda x, z: max(0.0, .12 * s * (1 - math.hypot(
            x, z) / (s * .8)))), detail='half buried in silt')


def astrolabe(model, t, rng):
    s = t['size']
    brass = model.mat('brass', t['colour'], .45, .8)
    dark = model.mat('brass-dark', shade(t['colour'], .6), .6, .7)
    R = s / 2
    model.add(dark, lathe([(0, 0), (R * .9, 0), (R * .9, R * .03),
                           (0, R * .03)], 32), detail='mater (plate)')
    model.add(brass, lathe([(R * .82, 0), (R, 0), (R, R * .1),
                            (R * .82, R * .1)], 32), smooth=False,
              detail='raised limb')
    for i in range(24):
        a = 2 * math.pi * i / 24
        model.add(brass, box(R * .08, R * .012, R * .008),
                  chain(rot_y(a), translate(R * .86, R * .1, 0)),
                  detail='degree ticks on the limb')
    model.add(brass, box(R * .35, R * .06, R * .25),
              translate(R * 1.1, R * .05, 0), detail='throne (kursi)')
    model.add(brass, torus(R * .12, R * .025, 12, 4),
              chain(translate(R * 1.32, R * .05, 0), rot_x(math.pi / 2)),
              detail='suspension ring')
    # Rete: an ecliptic ring off-centre and star pointers.
    model.add(brass, torus(R * .45, R * .025, 24, 4),
              translate(R * .12, R * .06, 0), detail='rete: ecliptic ring')
    model.add(brass, torus(R * .8, R * .02, 32, 3),
              translate(0, R * .06, 0))
    for i in range(7):
        a = 2 * math.pi * i / 7 + .3
        r0, r1 = R * .35, R * rng.uniform(.55, .78)
        model.add(brass, plate([(r0, -R * .02), (r1, 0), (r0, R * .02)]),
                  chain(translate(0, R * .07, 0), rot_y(a),
                        rot_x(-math.pi / 2)), detail='rete: star pointers')
    model.add(brass, box(s * .95, R * .03, R * .07),
              chain(translate(0, R * .1, 0), rot_y(.6)),
              detail='rule across the face')
    model.add(dark, lathe([(0, 0), (R * .04, 0), (R * .04, R * .18),
                           (0, R * .2)], 8), detail='central pin')


def shield(model, t, rng):
    s = t['size']
    wood = model.mat('wood', shade(t['colour'], 1.1), .95)
    wood2 = model.mat('wood-2', shade(t['colour'], .85), .95)
    iron = model.mat('iron', shade(t['colour'], .7), .6, .5)
    rust = model.mat('rust', '#6a3a22', .95)
    R = s / 2
    th = s * .03
    planks = 6
    for i in range(planks):
        x0 = -R + 2 * R * i / planks
        x1 = x0 + 2 * R / planks
        a0 = math.acos(max(-1, min(1, x0 / R)))
        a1 = math.acos(max(-1, min(1, x1 / R)))
        poly = [(x0, -R * math.sin(a0)), (x1, -R * math.sin(a1)),
                (x1, R * math.sin(a1)), (x0, R * math.sin(a0))]
        poly = [(x * .995 + (.002 if k in (1, 2) else -.002), y)
                for k, (x, y) in enumerate(poly)]
        model.add(wood if i % 2 else wood2, plate(poly, th),
                  chain(translate(0, th, 0), rot_x(-math.pi / 2)),
                  smooth=False, detail='planks of the board')
    model.add(iron, torus(R, th * .8, 40, 4), translate(0, th, 0),
              detail='iron rim')
    model.add(iron, lathe([(0, 0), (R * .2, 0), (R * .19, th * 1.5),
                           (R * .12, th * 4), (0, th * 4.6)], 16),
              translate(0, th * 1.4, 0), detail='iron boss (umbo)')
    for i in range(8):
        a = 2 * math.pi * i / 8
        model.add(rust, ellipsoid(th * .5, th * .4, th * .5, 6, 3),
                  translate(R * .24 * math.cos(a), th * 1.6,
                            R * .24 * math.sin(a)), detail='rivets')
    for i in range(5):
        model.add(rust, rock(rng, R * .12, th * .4, R * .09, 6, 3, .3),
                  translate(rng.uniform(-R * .7, R * .7), th * 1.5,
                            rng.uniform(-R * .7, R * .7)),
                  smooth=False, detail='rust blooms')
    model.add(model.mat('silt', SILT, 1), disc_field(
        s * .7, 3, 18, lambda x, z: max(0.0, .04 * (x / (s * .7)))),
        detail='silt drifted over one side')


def khachkar(model, t, rng):
    """Own drawing, stone only; seen by its shadows (TABOO 0.4 r. 2)."""
    stone = model.mat('stone', t['colour'], .95)
    W, H, D = 0.9, 1.6, 0.22
    z = D / 2
    model.add(stone, box(1.2, .3, .5), translate(0, .15, 0), smooth=False,
              detail='pedestal stone')
    model.add(stone, box(W, H, D), translate(0, .3 + H / 2, 0),
              smooth=False, detail='upright slab')
    model.add(stone, box(W + .08, .1, D + .06),
              translate(0, .3 + H + .05, 0), smooth=False,
              detail='cornice')
    y0 = .3
    for w, h, x, y in ((.06, H - .1, -W / 2 + .06, H / 2),
                       (.06, H - .1, W / 2 - .06, H / 2),
                       (W - .1, .06, 0, .08), (W - .1, .06, 0, H - .08)):
        model.add(stone, box(w, h, .04), translate(x, y0 + y, z + .02),
                  smooth=False, detail='carved frame')
    cy = y0 + 1.05
    d = .05
    model.add(stone, box(.13, .8, d), translate(0, cy, z + d / 2),
              smooth=False, detail='cross in relief')
    model.add(stone, box(.56, .13, d), translate(0, cy + .15, z + d / 2),
              smooth=False)
    # Each arm ends in two rounded lobes (the split tips of a khachkar
    # cross), drawn as short discs of the same stone.
    for ax, ay, ang in ((0, cy + .4, 0), (0, cy - .4, math.pi),
                        (-.28, cy + .15, math.pi / 2),
                        (.28, cy + .15, -math.pi / 2)):
        for side in (-1, 1):
            off = np.array([math.cos(ang), math.sin(ang)]) * .045 * side
            tip = np.array([-math.sin(ang), math.cos(ang)]) * .03
            model.add(stone, lathe([(0, 0), (.045, 0), (.045, d),
                                    (0, d)], 10),
                      chain(translate(ax + off[0] + tip[0],
                                      ay + off[1] + tip[1], z),
                            rot_x(math.pi / 2)),
                      detail='split trefoil tips of the arms')
    model.add(stone, lathe([(0, 0), (.13, 0), (.13, d * .8), (0, d)], 20),
              chain(translate(0, y0 + .32, z), rot_x(math.pi / 2)),
              detail='rosette under the cross')
    for i in range(8):
        a = 2 * math.pi * i / 8
        model.add(stone, box(.025, .09, .02),
                  chain(translate(.07 * math.cos(a), y0 + .32 +
                                  .07 * math.sin(a), z + d),
                        rot_z(a - math.pi / 2)),
                  detail='rosette spokes')
    for side in (-1, 1):
        model.add(stone, tube([(side * .09, y0 + .5, z + .02),
                               (side * .2, y0 + .62, z + .02),
                               (side * .22, y0 + .78, z + .02),
                               (side * .14, y0 + .86, z + .02)], .018, 5),
                  detail='leaf scrolls rising from the rosette')


TRACE_BUILDERS = {'book': diary, 'amphora': amphora,
                  'astrolabe': astrolabe, 'shield': shield,
                  'khachkar': khachkar}


# ----------------------------------------------------------------------
# Writing.

def meta_for(model, mid, kind, seed, extra):
    lo, hi = model.bounds()
    size = hi - lo
    centre = (hi + lo) / 2
    mats = [{'name': k, 'colour': model.mats[k]['colour'],
             'roughness': model.mats[k]['rough'],
             'metallic': model.mats[k]['metal'],
             'alpha': model.mats[k]['alpha']} for k in model.order
            if model.mats[k]['v']]
    return {'id': mid, 'kind': kind, 'lod': 'proxy',
            'detail': 'procedural-detailed',
            'details': model.details,
            'tris': model.tris(),
            'bbox_m': [round(float(x), 3) for x in size],
            'collider': {'shape': 'box',
                         'size_m': [round(float(x), 3) for x in size],
                         'centre_m': [round(float(x), 3) for x in centre]},
            'materials': mats, 'textures': 0,
            'generator': 'scripts/meta3d/lake_details.py',
            'seed': seed, **extra}


def write(kind, mid, model, meta, godot=True, godot_json=False):
    extras = {k: meta[k] for k in ('noInteract', 'noLoot') if k in meta}
    blob = model.glb(extras)
    dirs = [os.path.join(OUT_WEB, kind)]
    if godot:
        dirs.append(os.path.join(OUT_GODOT, kind))
    for d in dirs:
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, mid + '.glb'), 'wb') as fh:
            fh.write(blob)
    text = json.dumps(meta, ensure_ascii=False, indent=1) + '\n'
    with open(os.path.join(OUT_WEB, kind, mid + '.json'), 'w',
              encoding='utf-8') as fh:
        fh.write(text)
    if godot and godot_json:
        with open(os.path.join(OUT_GODOT, kind, mid + '.json'), 'w',
                  encoding='utf-8') as fh:
            fh.write(text)


def main():
    with open(DATA, encoding='utf-8') as fh:
        objects = json.load(fh)['objects']
    report = {'lake': 0, 'atlas': 0, 'max_tris': 0, 'over': []}
    for obj in objects:
        mid, model, seed = build_lake(obj)
        flags = obj['flags']
        holy = obj['item'] == 'bulla'
        meta = meta_for(model, mid, 'lake', seed, {
            'name': obj['ru'], 'category': obj['category'],
            'band': obj['band'], 'depth_m': obj['depth'], 'flags': flags,
            'noLoot': bool(flags.get('noLoot')),
            'noInteract': holy,
            'size_m': obj['size_m'],
            'source': 'godot/data/lake-objects-99.json (scripts/lake/'
                      'lake_objects.py) + docs/ISSYK_KUL_FISH.md',
            'method': 'lake-detail-kit (numpy, own glTF writer)'})
        if holy:
            meta['holy_note'] = ('a cross on the seal: never loot, no '
                                 'interaction, same lead, no glow')
        write('lake', mid, model, meta)
        report['lake'] += 1
        report['max_tris'] = max(report['max_tris'], model.tris())
        if model.tris() > TRI_BUDGET:
            report['over'].append((mid, model.tris()))
    for t in TRACES:
        rng, seed = seeded('atlas:' + t['id'])
        mid = 'atlas-' + t['id']
        model = Model(mid)
        TRACE_BUILDERS[t['shape']](model, t, rng)
        extra = {'name': t['ru'], 'category': 'atlas-trace',
                 'shape': t['shape'], 'size_m': t['size'],
                 'atlas_nodes': t['nodes'], 'loot': t['loot'],
                 'noLoot': t['loot'] is None or t['holy'],
                 'noInteract': t['holy'],
                 'source': 'scripts/story/atlas_nodes.py TRACES; own '
                           'procedural drawing, no raw material',
                 'method': 'lake-detail-kit (numpy, own glTF writer)'}
        if t['holy']:
            extra['holy_note'] = ('own drawing (TABOO 0.35 rule 6): stone '
                                  'only, no glow, no gold; relief faces '
                                  '+Z; the console fades near it')
        meta = meta_for(model, mid, 'atlas', seed, extra)
        write('atlas', mid, model, meta, godot_json=True)
        report['atlas'] += 1
        report['max_tris'] = max(report['max_tris'], model.tris())
        if model.tris() > TRI_BUDGET:
            report['over'].append((mid, model.tris()))
    print(json.dumps(report))
    return 1 if report['over'] else 0


if __name__ == '__main__':
    sys.exit(main())
