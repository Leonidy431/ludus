"""Fish, birds and small life of Issyk-Kul, drawn from code.

Each fish is a loft of ellipse sections with the fins, eyes, gill cover
and barbels its species really has (docs/ISSYK_KUL_FISH.md): the carp
and the marinka have two pairs of barbels, the loaches three, the
trouts and the whitefish an adipose fin, the zander two dorsals and
dark bars, the bream a deep narrow body and a long anal fin, the silver
carp its eyes set low.  Proportions are the usual field-guide ones for
the genus, not measurements of the lake's own fish; an ichthyologist
checks them before release (docs/HLD_LAKE_99_DETAILS_2026-09-30.md).
"""

import math

import numpy as np

from lake_kit import (chain, ellipsoid, loft, plate, rot_x, rot_y, rot_z,
                      scale, shade, translate, tube)

# depth, width (of length); where the body is deepest; peduncle share;
# tail; dorsal (start, end, height) as shares of length from the nose;
# anal fin; adipose; barbel pairs and length; eye; marks; mouth drop;
# belly flatness; fin colour.
SPECIES = {
    'chebak': dict(D=.22, W=.12, tm=.38, p=.32, tail='fork',
                   dorsal=(.42, .54, .13), anal=(.62, .72, .09)),
    'chebachok': dict(D=.2, W=.11, tm=.38, p=.32, tail='fork',
                      dorsal=(.43, .55, .12), anal=(.62, .72, .08)),
    'marinka': dict(D=.2, W=.15, tm=.36, p=.3, tail='fork',
                    dorsal=(.40, .52, .15), anal=(.66, .74, .09),
                    barbels=(2, .07), drop=.25, spine=True),
    'osman': dict(D=.19, W=.16, tm=.3, p=.3, tail='emarg',
                  dorsal=(.44, .55, .12), anal=(.66, .74, .08),
                  barbels=(1, .05), drop=.2, eye=.022),
    'osman-scaly': dict(D=.18, W=.15, tm=.32, p=.3, tail='fork',
                        dorsal=(.44, .55, .12), anal=(.66, .74, .08),
                        barbels=(1, .05), drop=.2, marks='spots'),
    'gubach': dict(D=.14, W=.14, tm=.3, p=.45, tail='trunc',
                   dorsal=(.42, .54, .1), anal=(.66, .74, .07),
                   barbels=(3, .08), drop=.3, flat=.8, marks='blotch',
                   lips=True, eye=.02),
    'loach-tibet': dict(D=.13, W=.13, tm=.3, p=.45, tail='trunc',
                        dorsal=(.42, .54, .1), anal=(.66, .74, .07),
                        barbels=(3, .07), drop=.3, flat=.8,
                        marks='blotch', eye=.02),
    'loach-grey': dict(D=.13, W=.12, tm=.3, p=.42, tail='emarg',
                       dorsal=(.43, .55, .1), anal=(.66, .74, .07),
                       barbels=(3, .07), drop=.3, flat=.8,
                       marks='blotch', eye=.02),
    'golyan': dict(D=.19, W=.12, tm=.38, p=.36, tail='emarg',
                   dorsal=(.5, .6, .1), anal=(.62, .71, .08),
                   marks='stripe'),
    'amur-chebachok': dict(D=.2, W=.12, tm=.38, p=.36, tail='emarg',
                           dorsal=(.44, .55, .11), anal=(.62, .7, .08),
                           marks='stripe', drop=-.1),
    'ishkhan': dict(D=.21, W=.12, tm=.4, p=.3, tail='emarg',
                    dorsal=(.38, .5, .12), anal=(.64, .73, .09),
                    adipose=True, marks='spots'),
    'raduzhnaya': dict(D=.22, W=.12, tm=.4, p=.3, tail='emarg',
                       dorsal=(.38, .5, .12), anal=(.64, .73, .09),
                       adipose=True, marks='band+spots'),
    'sig': dict(D=.2, W=.11, tm=.4, p=.26, tail='fork',
                dorsal=(.38, .5, .14), anal=(.64, .74, .08),
                adipose=True, eye=.03),
    'sudak': dict(D=.18, W=.12, tm=.36, p=.28, tail='fork',
                  dorsal=(.28, .46, .12), dorsal2=(.5, .66, .1),
                  anal=(.63, .73, .08), marks='bars', eye=.035),
    'leshch': dict(D=.36, W=.1, tm=.42, p=.22, tail='fork',
                   dorsal=(.46, .56, .15), anal=(.55, .82, .08),
                   eye=.035),
    'sazan': dict(D=.28, W=.15, tm=.38, p=.3, tail='fork',
                  dorsal=(.36, .72, .1), anal=(.7, .78, .09),
                  barbels=(2, .05), lips=True, spine=True),
    'karas': dict(D=.34, W=.13, tm=.4, p=.3, tail='fork',
                  dorsal=(.38, .7, .1), anal=(.7, .78, .09),
                  spine=True),
    'lin': dict(D=.26, W=.15, tm=.4, p=.42, tail='trunc',
                dorsal=(.44, .56, .12), anal=(.64, .74, .09),
                barbels=(1, .025), eye=.025, iris='#c0402a',
                fin='#3a4020'),
    'amur-white': dict(D=.18, W=.14, tm=.36, p=.32, tail='fork',
                       dorsal=(.44, .54, .11), anal=(.66, .74, .08)),
    'tolstolob': dict(D=.27, W=.12, tm=.4, p=.26, tail='fork',
                      dorsal=(.5, .58, .08), anal=(.62, .8, .07),
                      eye_low=True),
}


def _profile(P, t):
    tm, p = P['tm'], P['p']
    if t < tm:
        return math.sqrt(max(0.0, 1 - ((tm - t) / tm) ** 2))
    u = min(1.0, (t - tm) / (0.85 - tm))
    return p + (1 - p) * (1 - u ** 1.6)


def _sub(v, f, mask):
    f = f[mask]
    used = np.unique(f)
    remap = -np.ones(len(v), int)
    remap[used] = np.arange(len(used))
    return v[used], remap[f]


def fish(model, sp, L, m, colour, low=False, tag=''):
    """One fish of length L, nose to +x, standing upright in m."""
    P = SPECIES[sp]
    back = model.mat('fish-back' + tag, shade(colour, 0.62), 0.55)
    belly = model.mat('fish-belly' + tag, shade(colour, 1.35), 0.4, 0.1)
    fin_c = P.get('fin', shade(colour, 0.8))
    fin = model.mat('fish-fin' + tag, fin_c, 0.7, 0.0, 0.85)
    dark = model.mat('fish-mark' + tag, shade(colour, 0.3), 0.7)
    iris = model.mat('fish-iris' + tag, P.get('iris', '#c8b070'), 0.3,
                     0.3)
    pupil = model.mat('fish-pupil', '#0a0a0a', 0.2)
    D, W, drop = P['D'] * L, P['W'] * L, P.get('drop', 0.0)
    flat = P.get('flat', 0.0)
    nose = L / 2
    n, around = (9, 8) if low else (15, 12)

    def body(t):
        f = _profile(P, t)
        h = D * max(f, 0.04)
        w = W * max(min(1.0, f * 1.15), 0.05)
        cy = flat * (h - D) / 2
        cy -= drop * D * 0.25 * max(0.0, 1 - t / 0.2)
        return cy, h, w

    ts = [0.012] + [0.85 * i / n for i in range(1, n + 1)]
    secs = [(nose - t * L,) + body(t) for t in ts]
    v, f = loft(secs, around)
    cen = v[f].mean(axis=1)
    # The loft writes each quad as two triangles in a row; colour the
    # pair together, or a band edge turns into a saw.
    side = (len(secs) - 1) * around * 2
    cen[:side] = cen[:side].reshape(-1, 2, 3).mean(axis=1).repeat(2, 0)
    tc = (nose - cen[:, 0]) / L
    cyc = np.array([body(max(0.012, t))[0] for t in tc])
    rel = (cen[:, 1] - cyc) / D
    hc = np.array([body(max(0.012, t))[1] for t in tc])
    # Height on the flank as a share of the local depth: a stripe or a
    # band then keeps its width from the head to the tail.
    rel_local = (cen[:, 1] - cyc) / hc
    marks = P.get('marks', '')
    is_dark = np.zeros(len(f), bool)
    if 'stripe' in marks:
        is_dark |= (np.abs(rel_local) < 0.16) & (tc > 0.15)
    if 'bars' in marks:
        is_dark |= (rel > 0.02) & (np.floor((tc - 0.18) / 0.09) % 2 == 0) \
            & (tc > 0.18) & (tc < 0.8)
    band_mask = np.zeros(len(f), bool)
    if 'band' in marks:
        band_mask = (np.abs(rel_local) < 0.16) & (tc > 0.12) & ~is_dark
        pink = model.mat('fish-band' + tag, '#c87a8a', 0.5)
        model.add(pink, _sub(v, f, band_mask), m, detail='pink band')
    up = (rel > 0.05) & ~is_dark & ~band_mask
    lo = ~up & ~is_dark & ~band_mask
    model.add(back, _sub(v, f, up), m, detail='dark back')
    model.add(belly, _sub(v, f, lo), m, detail='pale belly')
    if is_dark.any():
        model.add(dark, _sub(v, f, is_dark), m,
                  detail='dark bars' if 'bars' in marks
                  else 'lateral stripe')

    def top(t):
        cy, h, _ = body(t)
        return cy + h / 2

    def bottom(t):
        cy, h, _ = body(t)
        return cy - h / 2

    def fin_poly(t0, t1, hgt, up=True, spine=False):
        x0, x1 = nose - t0 * L, nose - t1 * L
        y0, y1 = (top(t0), top(t1)) if up else (bottom(t0), bottom(t1))
        s = 1 if up else -1
        lead = hgt * L * (1.25 if spine else 1.0)
        return [(x0 + .01 * L, y0 - s * .01 * L),
                (x0 - .02 * L, y0 + s * lead),
                (x1 + .01 * L, y1 + s * hgt * L * .3),
                (x1 - .02 * L, y1 - s * .01 * L)]

    d0, d1, dh = P['dorsal']
    model.add(fin, plate(fin_poly(d0, d1, dh, True, P.get('spine'))), m,
              detail='dorsal fin')
    if 'dorsal2' in P:
        e0, e1, eh = P['dorsal2']
        model.add(fin, plate(fin_poly(e0, e1, eh)), m,
                  detail='second dorsal fin')
    a0, a1, ah = P['anal']
    model.add(fin, plate(fin_poly(a0, a1, ah, False)), m,
              detail='anal fin')
    if P.get('adipose'):
        tx = 0.76
        x, y = nose - tx * L, top(tx)
        model.add(fin, plate([(x + .03 * L, y - .005 * L),
                              (x + .005 * L, y + .035 * L),
                              (x - .025 * L, y + .03 * L),
                              (x - .03 * L, y - .005 * L)]), m,
                  detail='adipose fin')
    # Tail.
    x0 = nose - 0.85 * L
    hp = body(0.85)[1]
    cy0 = body(0.85)[0]
    kind = P['tail']
    if kind == 'fork':
        tail = [(x0 + .02 * L, cy0 + hp * .45), (x0 - .2 * L, cy0 + .17 * L),
                (x0 - .1 * L, cy0), (x0 - .2 * L, cy0 - .17 * L),
                (x0 + .02 * L, cy0 - hp * .45)]
    elif kind == 'emarg':
        tail = [(x0 + .02 * L, cy0 + hp * .45), (x0 - .17 * L, cy0 + .14 * L),
                (x0 - .14 * L, cy0), (x0 - .17 * L, cy0 - .14 * L),
                (x0 + .02 * L, cy0 - hp * .45)]
    else:
        tail = [(x0 + .02 * L, cy0 + hp * .45), (x0 - .13 * L, cy0 + .1 * L),
                (x0 - .16 * L, cy0 + .04 * L), (x0 - .16 * L, cy0 - .04 * L),
                (x0 - .13 * L, cy0 - .1 * L), (x0 + .02 * L, cy0 - hp * .45)]
    model.add(fin, plate(tail), m, detail=f'{kind} tail fin')
    # Paired fins, splayed out from the body.
    for side in (1, -1):
        for tx, yk, size, name in ((.22, -.3, .1, 'pectoral fins'),
                                   (.48, -.45, .07, 'pelvic fins')):
            cy, h, w = body(tx)
            poly = [(0, 0), (-size * L, size * L * .35),
                    (-size * L * 1.1, -size * L * .1),
                    (-size * L * .3, -size * L * .25)]
            mm = chain(m, translate(nose - tx * L, cy + yk * h,
                                    side * w * 0.42),
                       rot_y(side * 0.5), rot_x(side * 1.2))
            model.add(fin, plate(poly), mm, detail=name)
    # Eyes: an iris and a pupil on each side.
    er = P.get('eye', .028) * L
    ex = nose - 0.075 * L
    cy, h, w = body(0.075)
    ey = cy + (-0.12 if P.get('eye_low') else 0.12) * h
    for side in (1, -1):
        z = side * (w / 2 * 0.72)
        model.add(iris, ellipsoid(er, er, er * .5, 8, 5), chain(
            m, translate(ex, ey, z)), detail='eyes')
        model.add(pupil, ellipsoid(er * .55, er * .55, er * .3, 6, 4),
                  chain(m, translate(ex + er * .1, ey, z + side * er * .35)))
    if not low:
        # Gill cover: an arc pressed into the side.
        tx = 0.22
        cy, h, w = body(tx)
        for side in (1, -1):
            pts = [(nose - tx * L + .02 * L * math.cos(a) ** 2,
                    cy + h / 2 * 1.02 * math.sin(a),
                    side * w / 2 * 1.02 * math.cos(a))
                   for a in np.linspace(-1.1, 1.2, 7)]
            model.add(dark, tube(pts, .005 * L, 4, False), m,
                      detail='gill cover')
    pairs, blen = P.get('barbels', (0, 0))
    for k in range(pairs):
        for side in (1, -1):
            cy, h, w = body(0.03)
            x = nose - (0.02 + 0.03 * k) * L
            y = cy - h * 0.3
            pts = [(x, y, side * w * .25),
                   (x - blen * L * .4, y - blen * L * .5,
                    side * (w * .3 + blen * L * .2 * (k + 1))),
                   (x - blen * L * .7, y - blen * L * .8,
                    side * (w * .3 + blen * L * .35 * (k + 1)))]
            model.add(belly, tube(pts, .005 * L, 4, False), m,
                      detail=f'{pairs} pair(s) of barbels')
    if P.get('lips'):
        cy, h, w = body(0.02)
        model.add(belly, ellipsoid(.03 * L, .02 * L, .035 * L, 6, 4),
                  chain(m, translate(nose - .005 * L, cy - h * .2, 0)),
                  detail='fleshy lips')
    if ('spots' in marks or 'blotch' in marks) and not low:
        k = 14 if 'spots' in marks else 8
        big = .012 if 'spots' in marks else .03
        for i in range(k):
            t = 0.15 + 0.6 * ((i * 0.618) % 1)
            a = -0.2 + 1.5 * ((i * 0.382) % 1)
            cy, h, w = body(t)
            side = 1 if i % 2 else -1
            p = (nose - t * L, cy + h / 2 * math.sin(a) * .98,
                 side * w / 2 * math.cos(a) * .98)
            model.add(dark, ellipsoid(big * L, big * L * .8, big * L * .3,
                                      6, 3),
                      chain(m, translate(*p), rot_x(-side * a)),
                      detail='dark spots' if big < .02 else 'blotches')


def school(model, sp, L, colour, count, spread, rng, lead_full=True):
    """A school: one fish in full detail, the rest lighter, all heading
    the same way with small deterministic turns."""
    for i in range(count):
        if i == 0:
            m = np.eye(4)
        else:
            m = chain(translate(-spread * (0.2 + rng.random()),
                                spread * (rng.random() - 0.5) * 0.7,
                                spread * (rng.random() - 0.5) * 1.4),
                      rot_y((rng.random() - 0.5) * 0.5),
                      scale(0.85 + 0.25 * rng.random()))
        fish(model, sp, L, m, colour, low=not (lead_full and i == 0))


# ----------------------------------------------------------------------
# Birds that dive in the shallows (the ROV meets them underwater).

BIRDS = {
    'cormorant': dict(body='#1c1c1c', belly='#262626', head='#1c1c1c',
                      bill='#3a3a30', throat='#d8a840', feet='web',
                      bill_len=.13, hook=True, neck=.26),
    'grebe': dict(body='#5a4a3a', belly='#e8e2d8', head='#3a2a20',
                  bill='#c87a70', feet='lobe', bill_len=.1, crest=True,
                  neck=.3),
    'krokhal': dict(body='#f0eee4', belly='#f4f0e0', head='#1e3a2c',
                    bill='#c03020', feet='web', bill_len=.1, hook=True,
                    neck=.2, back='#20241f'),
    'lysukha': dict(body='#1e1e20', belly='#2a2a2c', head='#161618',
                    bill='#eeeae0', feet='lobe', bill_len=.07,
                    shield=True, neck=.16),
    'nyrok': dict(body='#b8aa92', belly='#e0d8c8', head='#b8582a',
                  bill='#d02a20', feet='web', bill_len=.09, neck=.16,
                  breast='#1a1a1a'),
}


def bird(model, item, L, pitch, rng):
    """A diving bird, body pitched head-down (ныряет) or up."""
    B = BIRDS[item]
    root = chain(translate(0, L * .3, 0), rot_z(pitch))
    body_m = model.mat('bird-body', B.get('back', B['body']), 0.8)
    belly = model.mat('bird-belly', B['belly'], 0.8)
    head = model.mat('bird-head', B['head'], 0.7)
    bill = model.mat('bird-bill', B['bill'], 0.5)
    feet = model.mat('bird-feet', '#3a3a34', 0.7)
    red_eye = item in ('grebe', 'lysukha', 'nyrok')
    eye = model.mat('bird-eye', '#b02020' if red_eye else '#1a3a2a', 0.2)
    air = model.mat('air', '#e8f4f8', 0.1, 0.0, 0.45)
    bl, bh = L * .55, L * .22
    v, f = ellipsoid(bl / 2, bh / 2, bh * .6, 12, 7)
    cen = v[f].mean(axis=1)
    upper = cen[:, 1] > -bh * .05
    model.add(body_m, _sub(v, f, upper), root, detail='back plumage')
    model.add(belly, _sub(v, f, ~upper), root, detail='belly plumage')
    if 'breast' in B:
        model.add(model.mat('bird-breast', B['breast'], .8),
                  ellipsoid(bh * .45, bh * .5, bh * .55, 8, 5),
                  chain(root, translate(bl * .38, -bh * .05, 0)),
                  detail='black breast')
    # Folded wings along the flanks.
    for side in (1, -1):
        model.add(model.mat('bird-wing', shade(B.get('back', B['body']),
                                               .8), .8),
                  ellipsoid(bl * .38, bh * .2, bh * .12, 8, 4),
                  chain(root, translate(-bl * .05, bh * .12,
                                        side * bh * .5), rot_y(side * .1)),
                  detail='folded wings')
    # Neck stretched forward, head and bill.
    nl = B['neck'] * L
    neck = [(bl * .42, bh * .1, 0), (bl * .42 + nl * .5, bh * .25, 0),
            (bl * .42 + nl, bh * .3, 0)]
    model.add(head if item in ('krokhal', 'nyrok') else body_m,
              tube(neck, [bh * .22, bh * .18, bh * .15], 8, False), root,
              detail='neck')
    hx = bl * .42 + nl + bh * .12
    model.add(head, ellipsoid(bh * .26, bh * .22, bh * .2, 10, 6),
              chain(root, translate(hx, bh * .32, 0)), detail='head')
    blen = B['bill_len'] * L
    droop = blen * .15 if B.get('hook') else 0
    tip = (hx + bh * .2 + blen, bh * .28 - droop, 0)
    model.add(bill, tube([(hx + bh * .18, bh * .3, 0),
                          (hx + bh * .2 + blen * .6, bh * .3, 0), tip],
                         [bh * .07, bh * .045, bh * .015], 6), root,
              detail='hooked bill' if B.get('hook') else 'bill')
    if B.get('throat'):
        model.add(model.mat('bird-throat', B['throat'], .6),
                  ellipsoid(bh * .1, bh * .08, bh * .14, 6, 4),
                  chain(root, translate(hx + bh * .15, bh * .18, 0)),
                  detail='yellow throat patch')
    if B.get('shield'):
        model.add(bill, ellipsoid(bh * .06, bh * .1, bh * .05, 6, 4),
                  chain(root, translate(hx + bh * .16, bh * .42, 0)),
                  detail='white frontal shield')
    if B.get('crest'):
        for side in (1, -1):
            model.add(head, plate([(0, 0), (-bh * .35, bh * .22),
                                   (-bh * .2, 0)]),
                      chain(root, translate(hx - bh * .05, bh * .45,
                                            side * bh * .08)),
                      detail='crest tufts')
    for side in (1, -1):
        model.add(eye, ellipsoid(bh * .04, bh * .04, bh * .03, 6, 4),
                  chain(root, translate(hx + bh * .1, bh * .38,
                                        side * bh * .17)), detail='eyes')
    # Short tail and legs set far back, feet spread for the stroke.
    model.add(body_m, plate([(0, 0), (-bh * .6, bh * .12),
                             (-bh * .6, -bh * .05)]),
              chain(root, translate(-bl * .48, bh * .05, 0), rot_x(1.57)),
              detail='tail')
    for side in (1, -1):
        hip = (-bl * .3, -bh * .3, side * bh * .35)
        ankle = (-bl * .55, -bh * .35, side * bh * .6)
        model.add(feet, tube([hip, ankle], bh * .04, 5), root,
                  detail='legs set far back')
        ax, ay, az = ankle
        if B['feet'] == 'web':
            model.add(feet, plate([(0, 0), (-bh * .5, bh * .25),
                                   (-bh * .55, 0), (-bh * .5, -bh * .25)]),
                      chain(root, translate(ax, ay, az), rot_x(1.2)),
                      detail='webbed feet')
        else:
            for k in (-1, 0, 1):
                model.add(feet, ellipsoid(bh * .22, bh * .03, bh * .08,
                                          6, 3),
                          chain(root, translate(ax - bh * .2, ay,
                                                az + k * bh * .12),
                                rot_y(k * .35)),
                          detail='lobed toes')
    # Silver air shed from the plumage as the bird goes down.
    for i in range(5):
        r = bh * (.05 + .03 * rng.random())
        model.add(air, ellipsoid(r, r * .8, r, 6, 4),
                  chain(root, translate(-bl * (.2 + .2 * i),
                                        bh * (.6 + .5 * i), 0)),
                  detail='air bubbles off the plumage')


# ----------------------------------------------------------------------
# Small life.

def amphipod(model, key, L, m):
    """A scud: a curled row of segments, antennae forward, legs below."""
    segs = 7
    for i in range(segs):
        a = -0.9 + 1.8 * i / (segs - 1)
        r = L * 0.45
        x, y = r * math.sin(a), r * math.cos(a) - r * .7
        s = L * (0.09 if 1 <= i <= 4 else 0.07)
        model.add(key, ellipsoid(s * .7, s, s * .8, 6, 3),
                  chain(m, translate(x, y, 0), rot_z(-a)),
                  detail='curled segmented body')
    head = (L * .45 * math.sin(0.9), L * .45 * math.cos(0.9) - L * .31, 0)
    for k in (1, -1):
        model.add(key, tube([head, (head[0] + L * .35, head[1] + L * .2,
                                    k * L * .05)], L * .012, 3, False), m,
                  detail='antennae')
    for i in range(4):
        x = -L * .2 + L * .13 * i
        model.add(key, tube([(x, -L * .15, 0), (x + L * .05, -L * .32, 0)],
                            L * .01, 3, False), m, detail='legs')


def snail_shell(model, key, h, m, whorls=4.5, lip=None, k=40, sides=8):
    """A pond snail's shell: a tube wound on a cone, tip up."""
    pts, rad = [], []
    for i in range(k):
        u = i / (k - 1)
        a = whorls * 2 * math.pi * u
        grow = 0.08 + 0.92 * u ** 2.2
        r = h * 0.28 * grow
        y = h * (1 - u ** 0.8) * 0.72
        pts.append((r * math.cos(a), y, r * math.sin(a)))
        rad.append(h * 0.22 * grow + h * .01)
    model.add(key, tube(pts, rad, sides, True), m, detail='spiral whorls')
    if lip:
        x, y, z = pts[-1]
        model.add(lip, ellipsoid(rad[-1] * .9, rad[-1] * 1.1, rad[-1] * .3,
                                 8, 4), chain(m, translate(x, y, z),
                                              rot_y(-math.atan2(z, x))),
                  detail='aperture')
    return pts[-1]
