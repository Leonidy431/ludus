"""A small geometry kit and a glTF writer for the lake models.

The 99 objects of Issyk-Kul and the knight's five traces are drawn from
code, not from raw material (TABOO 0.35 rule 6 for the khachkar above
all), so this kit has only what they need: boxes, lathes, ellipsoids,
tubes, lofts, flat plates, a pierced slab and a height field.  Nothing
here draws a random number: every "irregular" stone takes its shape
from a generator seeded by the object's id (TABOO 0.35 rule 15), so the
same id gives the same bytes on every machine.

The writer puts one primitive per material into one mesh.  There are no
textures (TABOO 0.32 item 4): colour lives in the material, and a
granite speckle or a zander's bars are faces of another material.
Every material is double sided, so thin parts (fins, leaves, the net)
read from both sides, and normals follow the winding of each face.
"""

import hashlib
import json
import math
import random
import struct

import numpy as np

TRI_BUDGET = 5000


# ----------------------------------------------------------------------
# Transforms.

def translate(x, y, z):
    m = np.eye(4)
    m[:3, 3] = (x, y, z)
    return m


def scale(x, y=None, z=None):
    y = x if y is None else y
    z = x if z is None else z
    return np.diag([x, y, z, 1.0])


def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0, 0], [0, c, -s, 0], [0, s, c, 0],
                     [0, 0, 0, 1.0]])


def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s, 0], [0, 1, 0, 0], [-s, 0, c, 0],
                     [0, 0, 0, 1.0]])


def rot_z(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0, 0], [s, c, 0, 0], [0, 0, 1, 0],
                     [0, 0, 0, 1.0]])


def chain(*ms):
    """Compose transforms; the last one is applied first."""
    out = np.eye(4)
    for m in ms:
        out = out @ m
    return out


def seeded(key):
    """A generator seeded by a text key, the same on every machine."""
    seed = int(hashlib.sha1(key.encode('utf-8')).hexdigest()[:12], 16)
    return random.Random(seed), seed


# ----------------------------------------------------------------------
# Primitives.  Each returns (vertices (n, 3), faces (m, 3)), wound so
# that the outside is counter-clockwise.

def box(sx, sy, sz):
    x, y, z = sx / 2, sy / 2, sz / 2
    v = np.array([[-x, -y, -z], [x, -y, -z], [x, y, -z], [-x, y, -z],
                  [-x, -y, z], [x, -y, z], [x, y, z], [-x, y, z]])
    f = np.array([[0, 2, 1], [0, 3, 2], [4, 5, 6], [4, 6, 7],
                  [0, 1, 5], [0, 5, 4], [3, 7, 6], [3, 6, 2],
                  [0, 4, 7], [0, 7, 3], [1, 2, 6], [1, 6, 5]])
    return v, f


def lathe(profile, n=16, a0=0.0, a1=2 * math.pi, caps=False):
    """Revolve (r, y) points about the y axis.

    A full turn shares its seam.  A partial turn (a broken millstone, a
    sherd) can close its two cut faces with the profile polygon when
    the profile itself is closed.
    """
    full = abs(a1 - a0 - 2 * math.pi) < 1e-9
    steps = n if full else n + 1
    k = len(profile)
    verts = []
    for i in range(steps):
        a = a0 + (a1 - a0) * i / n
        c, s = math.cos(a), math.sin(a)
        for r, y in profile:
            verts.append((r * c, y, -r * s))
    faces = []
    for i in range(n):
        i2 = (i + 1) % steps if full else i + 1
        for j in range(k - 1):
            a, b = i * k + j, i2 * k + j
            faces.append((a, b, b + 1))
            faces.append((a, b + 1, a + 1))
    v = np.array(verts, float)
    f = np.array(faces, int)
    if caps and not full:
        # A closed profile repeats its first point at the end; the cap
        # polygon must not, or the ear clipper sees a zero-length edge.
        keep = list(range(k))
        if np.allclose(profile[0], profile[-1]):
            keep = keep[:-1]
        tri = earclip([profile[j] for j in keep])
        for i, sign in ((0, -1), (n, 1)):
            base = i * k
            for t in tri:
                a, b, c = (keep[j] for j in (t if sign > 0 else t[::-1]))
                f = np.vstack([f, [base + a, base + b, base + c]])
    return v, f


def ellipsoid(rx, ry, rz, nu=10, nv=6, bump=None):
    """A lat-long ellipsoid; bump(direction) scales each radius."""
    verts = [(0, -ry, 0)]
    for j in range(1, nv):
        phi = -math.pi / 2 + math.pi * j / nv
        for i in range(nu):
            th = 2 * math.pi * i / nu
            d = (math.cos(phi) * math.cos(th), math.sin(phi),
                 -math.cos(phi) * math.sin(th))
            k = bump(d) if bump else 1.0
            verts.append((d[0] * rx * k, d[1] * ry * k, d[2] * rz * k))
    verts.append((0, ry * (bump((0, 1, 0)) if bump else 1), 0))
    if bump:
        verts[0] = (0, -ry * bump((0, -1, 0)), 0)
    faces = []
    for i in range(nu):
        faces.append((0, 1 + (i + 1) % nu, 1 + i))
    for j in range(nv - 2):
        r0, r1 = 1 + j * nu, 1 + (j + 1) * nu
        for i in range(nu):
            a, b = r0 + i, r0 + (i + 1) % nu
            c, d = r1 + (i + 1) % nu, r1 + i
            faces.append((a, b, c))
            faces.append((a, c, d))
    top = len(verts) - 1
    r0 = 1 + (nv - 2) * nu
    for i in range(nu):
        faces.append((top, r0 + i, r0 + (i + 1) % nu))
    return np.array(verts, float), np.array(faces, int)


def _frames(points):
    """Parallel-transport frames along a polyline."""
    pts = np.asarray(points, float)
    tang = np.gradient(pts, axis=0)
    tang /= np.linalg.norm(tang, axis=1)[:, None] + 1e-12
    up = np.array([0, 1.0, 0])
    if abs(tang[0] @ up) > 0.9:
        up = np.array([1.0, 0, 0])
    nrm = np.cross(tang[0], up)
    nrm /= np.linalg.norm(nrm)
    out = []
    for t in tang:
        nrm = nrm - t * (nrm @ t)
        nrm /= np.linalg.norm(nrm) + 1e-12
        out.append((nrm, np.cross(t, nrm)))
    return pts, out


def tube(points, radius, sides=6, caps=True):
    """A tube along a polyline; radius may vary along it."""
    pts, frames = _frames(points)
    rad = np.broadcast_to(np.asarray(radius, float), (len(pts),))
    verts, faces = [], []
    for p, (n, b), r in zip(pts, frames, rad):
        for i in range(sides):
            a = 2 * math.pi * i / sides
            verts.append(p + r * (math.cos(a) * n + math.sin(a) * b))
    for j in range(len(pts) - 1):
        for i in range(sides):
            a, b = j * sides + i, j * sides + (i + 1) % sides
            c, d = b + sides, a + sides
            faces.append((a, b, c))
            faces.append((a, c, d))
    if caps:
        s = len(verts)
        verts += [pts[0], pts[-1]]
        last = (len(pts) - 1) * sides
        for i in range(sides):
            faces.append((s, (i + 1) % sides, i))
            faces.append((s + 1, last + i, last + (i + 1) % sides))
    return np.array(verts, float), np.array(faces, int)


def torus(big, small, nu=12, nv=6):
    verts, faces = [], []
    for i in range(nu):
        a = 2 * math.pi * i / nu
        for j in range(nv):
            b = 2 * math.pi * j / nv
            r = big + small * math.cos(b)
            verts.append((r * math.cos(a), small * math.sin(b),
                          -r * math.sin(a)))
    for i in range(nu):
        for j in range(nv):
            a = i * nv + j
            b = ((i + 1) % nu) * nv + j
            c = ((i + 1) % nu) * nv + (j + 1) % nv
            d = i * nv + (j + 1) % nv
            faces.append((a, b, c))
            faces.append((a, c, d))
    return np.array(verts, float), np.array(faces, int)


def loft(sections, around=12):
    """Ellipse sections [(x, cy, h, w)] along x, ends closed."""
    verts, faces = [], []
    for x, cy, h, w in sections:
        for i in range(around):
            a = 2 * math.pi * i / around
            verts.append((x, cy + h / 2 * math.sin(a), w / 2 * math.cos(a)))
    k = len(sections)
    for j in range(k - 1):
        for i in range(around):
            a, b = j * around + i, j * around + (i + 1) % around
            c, d = b + around, a + around
            faces.append((a, c, b))
            faces.append((a, d, c))
    s = len(verts)
    verts.append((sections[0][0], sections[0][1], 0))
    verts.append((sections[-1][0], sections[-1][1], 0))
    last = (k - 1) * around
    for i in range(around):
        faces.append((s, i, (i + 1) % around))
        faces.append((s + 1, last + (i + 1) % around, last + i))
    return np.array(verts, float), np.array(faces, int)


def earclip(poly):
    """Triangulate a simple 2D polygon (no holes) by ear clipping."""
    pts = [tuple(p) for p in poly]
    area = sum(pts[i][0] * pts[(i + 1) % len(pts)][1]
               - pts[(i + 1) % len(pts)][0] * pts[i][1]
               for i in range(len(pts)))
    idx = list(range(len(pts)))
    if area < 0:
        idx.reverse()

    def inside(p, a, b, c):
        def cross(o, u, v):
            return (u[0] - o[0]) * (v[1] - o[1]) - (u[1] - o[1]) * (
                v[0] - o[0])
        return (cross(a, b, p) >= 0 and cross(b, c, p) >= 0
                and cross(c, a, p) >= 0)

    tris = []
    guard = 0
    while len(idx) > 3 and guard < 10000:
        guard += 1
        for k in range(len(idx)):
            i0, i1, i2 = idx[k - 1], idx[k], idx[(k + 1) % len(idx)]
            a, b, c = pts[i0], pts[i1], pts[i2]
            if (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (
                    c[0] - a[0]) <= 1e-12:
                continue
            if any(inside(pts[j], a, b, c) for j in idx
                   if j not in (i0, i1, i2)):
                continue
            tris.append((i0, i1, i2))
            idx.pop(k)
            break
        else:
            break
    if len(idx) == 3:
        tris.append(tuple(idx))
    if area < 0:
        tris = [(a, c, b) for a, b, c in tris]
    return tris


def plate(poly, thickness=0.0):
    """A flat polygon in the XY plane; with thickness, a prism in z."""
    tri = earclip(poly)
    n = len(poly)
    if thickness <= 0:
        v = np.array([(x, y, 0.0) for x, y in poly])
        return v, np.array(tri, int)
    h = thickness / 2
    v = np.array([(x, y, h) for x, y in poly]
                 + [(x, y, -h) for x, y in poly])
    f = list(tri) + [(a + n, c + n, b + n) for a, b, c in tri]
    area = sum(poly[i][0] * poly[(i + 1) % n][1]
               - poly[(i + 1) % n][0] * poly[i][1] for i in range(n))
    for i in range(n):
        j = (i + 1) % n
        if area > 0:
            f += [(i, i + n, j + n), (i, j + n, j)]
        else:
            f += [(i, j, j + n), (i, j + n, i + n)]
    return v, np.array(f, int)


def pierced(outer, hole, radius, thickness, n=16):
    """A slab with a round hole through it (anchor stone, sinker).

    outer is a polygon star-shaped about the hole centre; for each of n
    angles the ray from the hole meets the outline, and the ring
    between the hole and the outline becomes the two faces.
    """
    cx, cy = hole
    poly = [np.array(p, float) for p in outer]
    rim = []
    for i in range(n):
        a = 2 * math.pi * i / n
        d = np.array([math.cos(a), math.sin(a)])
        best = None
        for j in range(len(poly)):
            p, q = poly[j], poly[(j + 1) % len(poly)]
            e = q - p
            m = np.array([[d[0], -e[0]], [d[1], -e[1]]])
            if abs(np.linalg.det(m)) < 1e-12:
                continue
            t, u = np.linalg.solve(m, p - np.array([cx, cy]))
            if t > 0 and -1e-9 <= u <= 1 + 1e-9:
                best = t if best is None else min(best, t)
        rim.append((cx + d[0] * best, cy + d[1] * best))
    inner = [(cx + radius * math.cos(2 * math.pi * i / n),
              cy + radius * math.sin(2 * math.pi * i / n)) for i in range(n)]
    h = thickness / 2
    verts = ([(x, y, h) for x, y in rim] + [(x, y, h) for x, y in inner]
             + [(x, y, -h) for x, y in rim] + [(x, y, -h) for x, y in inner])
    ro, io, rb, ib = 0, n, 2 * n, 3 * n
    faces = []
    for i in range(n):
        j = (i + 1) % n
        faces += [(io + i, ro + i, ro + j), (io + i, ro + j, io + j)]
        faces += [(ib + i, rb + j, rb + i), (ib + i, ib + j, rb + j)]
        faces += [(ro + i, rb + i, rb + j), (ro + i, rb + j, ro + j)]
        faces += [(io + i, io + j, ib + j), (io + i, ib + j, ib + i)]
    return np.array(verts, float), np.array(faces, int)


def heightfield(w, d, nx, nz, fn):
    """A w x d sheet in XZ, centred, with y = fn(x, z)."""
    verts = []
    for j in range(nz + 1):
        for i in range(nx + 1):
            x = -w / 2 + w * i / nx
            z = -d / 2 + d * j / nz
            verts.append((x, fn(x, z), z))
    faces = []
    for j in range(nz):
        for i in range(nx):
            a = j * (nx + 1) + i
            b, c, e = a + 1, a + nx + 2, a + nx + 1
            faces.append((a, e, c))
            faces.append((a, c, b))
    return np.array(verts, float), np.array(faces, int)


def disc_field(radius, rings, sectors, fn):
    """A round patch (silt, sand, a hearth floor) with y = fn(x, z)."""
    verts = [(0.0, fn(0.0, 0.0), 0.0)]
    for j in range(1, rings + 1):
        r = radius * j / rings
        for i in range(sectors):
            a = 2 * math.pi * i / sectors
            x, z = r * math.cos(a), -r * math.sin(a)
            verts.append((x, fn(x, z), z))
    faces = []
    for i in range(sectors):
        faces.append((0, 1 + i, 1 + (i + 1) % sectors))
    for j in range(rings - 1):
        r0, r1 = 1 + j * sectors, 1 + (j + 1) * sectors
        for i in range(sectors):
            a, b = r0 + i, r0 + (i + 1) % sectors
            faces.append((a, r1 + i, r1 + (i + 1) % sectors))
            faces.append((a, r1 + (i + 1) % sectors, b))
    return np.array(verts, float), np.array(faces, int)


# ----------------------------------------------------------------------
# The model and its writer.

def srgb_to_linear(hex_colour):
    h = hex_colour.lstrip('#')
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055)
                   ** 2.4)
    return out


def shade(hex_colour, k):
    """Darken (k < 1) or lighten (k > 1) a colour, staying in range."""
    h = hex_colour.lstrip('#')
    rgb = [int(h[i:i + 2], 16) for i in (0, 2, 4)]
    if k <= 1:
        rgb = [c * k for c in rgb]
    else:
        rgb = [c + (255 - c) * (k - 1) for c in rgb]
    return '#' + ''.join(f'{max(0, min(255, round(c))):02x}' for c in rgb)


def mix(a, b, t):
    ha, hb = a.lstrip('#'), b.lstrip('#')
    ra = [int(ha[i:i + 2], 16) for i in (0, 2, 4)]
    rb = [int(hb[i:i + 2], 16) for i in (0, 2, 4)]
    return '#' + ''.join(f'{round(x + (y - x) * t):02x}'
                         for x, y in zip(ra, rb))


class Model:
    """Named materials, each gathering the triangles drawn in it."""

    def __init__(self, name):
        self.name = name
        self.mats = {}
        self.order = []
        self.details = []

    def mat(self, key, colour, rough=0.9, metal=0.0, alpha=1.0):
        if key not in self.mats:
            self.mats[key] = {'colour': colour, 'rough': rough,
                              'metal': metal, 'alpha': alpha,
                              'v': [], 'n': [], 'f': [], 'count': 0}
            self.order.append(key)
        return key

    def add(self, key, geo, m=None, smooth=True, detail=None):
        v, f = geo
        v = np.asarray(v, float)
        f = np.asarray(f, int)
        if len(f) == 0:
            return
        if m is not None:
            hv = np.c_[v, np.ones(len(v))] @ m.T
            v = hv[:, :3]
            if np.linalg.det(m[:3, :3]) < 0:
                f = f[:, ::-1]
        if not smooth:
            v = v[f].reshape(-1, 3)
            f = np.arange(len(v)).reshape(-1, 3)
        fn = np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]])
        n = np.zeros_like(v)
        for c in range(3):
            np.add.at(n, f[:, c], fn)
        n /= np.linalg.norm(n, axis=1)[:, None] + 1e-12
        slot = self.mats[key]
        slot['f'].append(f + slot['count'])
        slot['v'].append(v)
        slot['n'].append(n)
        slot['count'] += len(v)
        if detail and detail not in self.details:
            self.details.append(detail)

    def tris(self):
        return sum(sum(len(f) for f in s['f']) for s in self.mats.values())

    def bounds(self):
        allv = np.vstack([np.vstack(s['v']) for s in self.mats.values()
                          if s['v']])
        return allv.min(axis=0), allv.max(axis=0)

    def glb(self, extras):
        """Binary glTF 2.0: one node, one mesh, a primitive a material."""
        bin_parts, views, accessors, prims, materials = [], [], [], [], []
        offset = 0

        def push(data, target, comp, count, kind, lo=None, hi=None):
            nonlocal offset
            raw = data.tobytes()
            pad = (-len(raw)) % 4
            bin_parts.append(raw + b'\0' * pad)
            views.append({'buffer': 0, 'byteOffset': offset,
                          'byteLength': len(raw), 'target': target})
            acc = {'bufferView': len(views) - 1, 'componentType': comp,
                   'count': count, 'type': kind}
            if lo is not None:
                acc['min'], acc['max'] = lo, hi
            accessors.append(acc)
            offset += len(raw) + pad
            return len(accessors) - 1

        for key in self.order:
            s = self.mats[key]
            if not s['v']:
                continue
            v = np.vstack(s['v']).astype(np.float32)
            n = np.vstack(s['n']).astype(np.float32)
            f = np.vstack(s['f'])
            idx_type = np.uint16 if len(v) < 65536 else np.uint32
            pa = push(v, 34962, 5126, len(v), 'VEC3',
                      [float(x) for x in v.min(axis=0)],
                      [float(x) for x in v.max(axis=0)])
            na = push(n, 34962, 5126, len(n), 'VEC3')
            ia = push(f.astype(idx_type).ravel(), 34963,
                      5123 if idx_type is np.uint16 else 5125,
                      f.size, 'SCALAR')
            mat = {'name': key, 'doubleSided': True,
                   'pbrMetallicRoughness': {
                       'baseColorFactor': srgb_to_linear(s['colour'])
                       + [s['alpha']],
                       'metallicFactor': s['metal'],
                       'roughnessFactor': s['rough']}}
            if s['alpha'] < 1:
                mat['alphaMode'] = 'BLEND'
            materials.append(mat)
            prims.append({'attributes': {'POSITION': pa, 'NORMAL': na},
                          'indices': ia, 'material': len(materials) - 1})
        blob = b''.join(bin_parts)
        doc = {'asset': {'version': '2.0',
                         'generator': 'ludus scripts/meta3d/lake_kit.py'},
               'scene': 0, 'scenes': [{'nodes': [0]}],
               'nodes': [{'name': self.name, 'mesh': 0, 'extras': extras}],
               'meshes': [{'name': self.name, 'primitives': prims}],
               'materials': materials, 'accessors': accessors,
               'bufferViews': views,
               'buffers': [{'byteLength': len(blob)}]}
        js = json.dumps(doc, separators=(',', ':'), ensure_ascii=False,
                        sort_keys=True).encode('utf-8')
        js += b' ' * ((-len(js)) % 4)
        total = 12 + 8 + len(js) + 8 + len(blob)
        return (struct.pack('<III', 0x46546C67, 2, total)
                + struct.pack('<II', len(js), 0x4E4F534A) + js
                + struct.pack('<II', len(blob), 0x004E4942) + blob)
