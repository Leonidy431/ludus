"""Twelve recognisable variants of a raw 3D model for the locations.

The mesh twin of location_kit.py (track B of the 99 locations,
CLAUDE.md TABOO 0.013 p. 3).  A model from the props store may become
a thing of a location only if its licence allows a store release, its
file can be read here, every variant stays within the proxy budget of
TABOO 0.32 p. 4 (5 000 triangles) and the reshaping is measured.

How 35 % is measured for a mesh.  A mesh has no alpha channel, so its
form is read as the alpha of its shadow on three planes: the model is
projected orthographically onto the front (x, y), side (z, y) and top
(x, z) planes, each rasterised to a 256 x 256 mask in one window fixed
by the source (so no change comes from scale).  The shape change of a
variant is the mean over the three views of |A xor B| / |A or B|
(form.shape_delta's formula with interior moves at 0.1), against the
source and against every sibling; both must reach 35 %.

Colour.  The source's texture is not used at all: every variant carries
our own material colour of the thing (clay, leather...) in one of its
states.  There is no source colour on the variant to measure against,
so the meta says "colour_basis": "source texture not shipped" instead
of a number.

The real changes are those of location_kit.py (lean, lie, upend,
chipped, broken, sunk in sand, in grass, pair, stack); pose alone never
makes a variant.  Nothing here is random.
"""

import math
import sys
from pathlib import Path

import numpy as np
import trimesh
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))

from form import area, fill_holes, hitbox_key  # noqa: E402
import location_kit as lk  # noqa: E402
import neutral_procedural as npd  # noqa: E402

VIEW = 256
THRESHOLD = 0.35
KIT_SIZE = 12
MAX_TRIS = 5000
REVISION = 'location-mesh-r1'
# Front (x right, y up), side (z right, y up), top (x right, z down).
AXES = (('front', 0, 1, 1), ('side', 2, 1, 1), ('top', 0, 2, -1))


# --- Reading and placing ------------------------------------------------

def load(path):
    """One triangle mesh from an OBJ or glTF file (parts merged)."""
    mesh = trimesh.load(str(path), force='mesh', process=True)
    return trimesh.Trimesh(vertices=mesh.vertices, faces=mesh.faces,
                           process=True)


def rest(mesh):
    """Stand the mesh on the floor (y = 0), centred on the y axis."""
    lo, hi = mesh.bounds
    mesh = mesh.copy()
    mesh.apply_translation([-(lo[0] + hi[0]) / 2, -lo[1],
                            -(lo[2] + hi[2]) / 2])
    return mesh


def to_real(mesh, size_m):
    """Scale uniformly to the thing's real largest size, on the floor."""
    lo, hi = mesh.bounds
    k = max(size_m) / max(hi - lo)
    mesh = mesh.copy()
    mesh.apply_scale(k)
    return rest(mesh)


def turn(mesh, deg, axis=(0, 0, 1)):
    """Rotate about an axis through the origin, then stand it again."""
    if deg % 360 == 0:
        return mesh.copy()
    mesh = mesh.copy()
    mesh.apply_transform(trimesh.transformations.rotation_matrix(
        math.radians(deg), axis))
    return rest(mesh)


def keep_faces(mesh, keep):
    """The part of the mesh made of the faces where keep is True."""
    part = mesh.copy()
    part.update_faces(np.asarray(keep))
    part.remove_unreferenced_vertices()
    return part


# --- Real changes ---------------------------------------------------------

def chip(mesh, corner, size):
    """A piece missing at a top corner: faces beyond a slanted plane go."""
    lo, hi = mesh.bounds
    span = hi - lo
    n = np.array([corner * 1.0, 1.0, 0.35])
    n /= np.linalg.norm(n)
    top = np.array([hi[0] if corner > 0 else lo[0], hi[1],
                    (lo[2] + hi[2]) / 2])
    d = top.dot(n) - size * float(np.linalg.norm(span))
    centres = mesh.triangles_center
    return keep_faces(mesh, centres.dot(n) < d)


def split(mesh, frac):
    """Break across the height: (bottom, top) parts, or None."""
    lo, hi = mesh.bounds
    cut = lo[1] + (hi[1] - lo[1]) * (1 - frac)
    y = mesh.triangles_center[:, 1]
    low, high = y < cut, y >= cut
    if low.sum() < 8 or high.sum() < 8:
        return None
    return keep_faces(mesh, low), keep_faces(mesh, high)


def beside(base, other, gap_k=0.1, side=1):
    """Put another part on the floor beside the base, along x."""
    other = rest(other)
    lo, hi = base.bounds
    olo, ohi = other.bounds
    gap = gap_k * (hi[0] - lo[0])
    dx = (hi[0] + gap - olo[0]) if side > 0 else (lo[0] - gap - ohi[0])
    other.apply_translation([dx, 0, 0])
    return other


def mound(width, depth, height, seed, label):
    """A low drift of sand: a flattened, slightly uneven half-sphere."""
    sphere = trimesh.creation.icosphere(subdivisions=2, radius=1.0)
    v = sphere.vertices.copy()
    for i in range(len(v)):
        v[i] *= 0.85 + 0.15 * lk.unit(seed, label, i)
    v[:, 1] = np.maximum(v[:, 1], 0.0)
    v *= [width / 2, height, depth / 2]
    return trimesh.Trimesh(vertices=v, faces=sphere.faces, process=True)


def grass(width, depth, height, seed, label):
    """Blades of grass on the floor around the base (thin triangles)."""
    verts, faces = [], []
    n = 40
    for i in range(n):
        a = 2 * math.pi * lk.unit(seed, label, i, 'a')
        r = 0.5 + 0.2 * lk.unit(seed, label, i, 'r')
        x, z = r * width * math.cos(a), r * depth * math.sin(a)
        h = height * (0.5 + 0.5 * lk.unit(seed, label, i, 'h'))
        lean = 0.3 * height * (2 * lk.unit(seed, label, i, 'l') - 1)
        w = width * 0.02
        k = len(verts)
        verts += [(x - w, 0, z), (x + w, 0, z), (x + lean, h, z)]
        faces += [(k, k + 1, k + 2), (k, k + 2, k + 1)]
    return trimesh.Trimesh(vertices=np.array(verts, float),
                           faces=np.array(faces), process=False)


def make(src, spec, seed):
    """Build one variant: {'thing': [meshes], 'ground': [meshes]}."""
    ops = dict(spec['ops'])
    body = src.copy()
    parts = []
    if 'chip' in ops:
        body = chip(body, *ops['chip'])
    if 'break' in ops:
        frac, fall = ops['break']
        got = split(body, frac)
        if got is None:
            return None
        body, piece = got
        parts.append(('piece', turn(piece, fall)))
    body = turn(body, spec['pose'])
    things = [body]
    for _, piece in parts:
        things.append(beside(body, piece, 0.08,
                             1 if lk.unit(seed, 'side', spec['label']) > 0.5
                             else -1))
    if spec['group'] == 'pair':
        _dx, spacing, pose2 = spec['pair']
        other = turn(src, pose2)
        other = beside(body, other, spacing - 1.0 if spacing < 1 else 0.05)
        other.apply_translation([0, 0, -0.25 * (other.bounds[1][2]
                                                - other.bounds[0][2])])
        things.append(other)
    if spec['group'] == 'stack':
        top = turn(src, spec.get('top', 0))
        top.apply_translation([0, body.bounds[1][1] * 0.97, 0])
        things.append(top)
    merged = trimesh.util.concatenate(things)
    merged = rest(merged)
    ground = []
    lo, hi = merged.bounds
    size = hi - lo
    if 'sink' in ops:
        depth = ops['sink'] * size[1]
        merged.apply_translation([0, -depth, 0])
        keep = merged.vertices[merged.faces].max(axis=1)[:, 1] > 0
        merged = keep_faces(merged, keep)
        ground.append(mound(size[0] * 1.4, size[2] * 1.4,
                            size[1] * 0.12, seed, 'mound' + spec['label']))
    if 'overgrow' in ops:
        ground.append(grass(size[0], size[2], size[1] * 0.15 *
                            ops['overgrow'], seed, 'grass' + spec['label']))
    return {'thing': merged, 'ground': ground}


# --- Measuring --------------------------------------------------------------

def window(src):
    """The fixed view window of a kit: 1.7 times the source's size."""
    lo, hi = src.bounds
    half = 1.7 * float(max(hi - lo))
    centre = np.array([0.0, half * 0.55, 0.0])
    return centre, half


def views(meshes, win):
    """Three orthographic shadow masks of a set of meshes."""
    centre, half = win
    k = (VIEW / 2 - 2) / half
    out = []
    for _, a, b, sign in AXES:
        img = Image.new('L', (VIEW, VIEW), 0)
        draw = ImageDraw.Draw(img)
        for mesh in meshes:
            tri = mesh.vertices[mesh.faces]
            xs = (tri[:, :, a] - centre[a]) * k + VIEW / 2
            ys = VIEW / 2 - sign * (tri[:, :, b] - centre[b]) * k
            for t in range(len(tri)):
                draw.polygon(list(zip(xs[t], ys[t])), fill=255)
        out.append(img)
    return out


def distance(va, vb, fa=None, fb=None):
    """Mean shape distance over the three views."""
    fa = fa or [fill_holes(m) for m in va]
    fb = fb or [fill_holes(m) for m in vb]
    return sum(npd.distance(a, b, x, y) for a, b, x, y in
               zip(va, vb, fa, fb)) / len(va)


def pool_specs(key, material):
    """Real states of a 3D thing, as location_kit.pool_specs."""
    poses = [0, 12, -12, 24, -24, 90, -90]
    if key in lk.UPENDS:
        poses.append(180)
    structs = [{'sink': d} for d in (0.15, 0.25, 0.35)]
    structs += [{'overgrow': t} for t in (1, 2)]
    if material in lk.CHIPS:
        structs += [{'chip': (c, s)} for c in (-1, 1) for s in (0.15, 0.25)]
    if material in lk.BREAKS:
        structs += [{'break': (f, fall)} for f in (0.3, 0.45)
                    for fall in (35, 90)]
    specs = [{'pose': p, 'ops': sorted(st.items()), 'group': None}
             for p in poses for st in structs]
    if key in lk.GROUPS:
        for spacing in (0.55, 1.05):
            for pose2 in (0, 90) + ((180,) if key in lk.UPENDS else ()):
                specs.append({'pose': 0, 'ops': [], 'group': 'pair',
                              'pair': (1, spacing, pose2)})
        if key in lk.STACKS:
            specs.append({'pose': 0, 'ops': [], 'group': 'stack',
                          'top': lk.STACK_TOP.get(key, 0)})
    for i, spec in enumerate(specs):
        spec['label'] = f'm{i:03d}'
        spec['soft'] = material in lk.SOFT
        spec['setting'] = ('ground' if any(k in ('sink', 'overgrow')
                                           for k, _ in spec['ops'])
                           else 'any')
    return specs


def triangles(variant):
    return len(variant['thing'].faces) + sum(len(g.faces)
                                             for g in variant['ground'])


def build_kit(src, key, material, seed, threshold=THRESHOLD):
    """Twelve mesh variants; the record mirrors location_kit.build_kit."""
    win = window(src)
    src_views = views([src], win)
    src_fill = [fill_holes(m) for m in src_views]
    own = sum(area(m) for m in src_views)
    made, refused = [], {}

    def refuse(reason):
        refused[reason] = refused.get(reason, 0) + 1

    specs = pool_specs(key, material)
    for i, spec in enumerate(specs):
        var = make(src, spec, seed)
        if var is None:
            refuse('cannot-break')
            continue
        tris = triangles(var)
        if tris > MAX_TRIS:
            refuse('over-triangle-budget')
            continue
        vs = views([var['thing']] + var['ground'], win)
        if any(m.getbbox() is None or m.getbbox()[0] <= 0 or
               m.getbbox()[2] >= VIEW or m.getbbox()[1] <= 0 for m in vs):
            refuse('does-not-fit-window')
            continue
        seen = views([var['thing']], win)
        copies = 2 if spec['group'] else 1
        visible = sum(area(m) for m in seen) / max(1, own * copies)
        if visible < lk.VISIBLE_MIN:
            refuse('thing-mostly-hidden')
            continue
        fill = [fill_holes(m) for m in vs]
        shape = distance(src_views, vs, src_fill, fill)
        if shape < threshold:
            refuse('shape-below-threshold')
            continue
        states = lk.MATERIAL_STATES[material]
        made.append({'spec': spec, 'state': states[i % len(states)],
                     'mesh': var, 'views': vs, 'fill': fill,
                     'shape': shape, 'visible': visible, 'tris': tris,
                     'key': tuple(m.getbbox() for m in vs)})
    made.sort(key=lambda m: (m['spec']['setting'] != 'any',
                             round(m['shape'], 4), m['spec']['label']))
    chosen, keys = [], set()
    for m in made:
        if len(chosen) == KIT_SIZE:
            break
        if m['key'] in keys:
            refuse('duplicate-hitbox')
            continue
        if any(distance(m['views'], c['views'], m['fill'], c['fill'])
               < threshold for c in chosen):
            refuse('too-close-to-a-sibling')
            continue
        chosen.append(m)
        keys.add(m['key'])
    for m in chosen:
        others = [distance(m['views'], c['views'], m['fill'], c['fill'])
                  for c in chosen if c is not m]
        m['sibling_min'] = min(others) if others else 1.0
    return {'pool': {'size': len(specs), 'measured': len(made),
                     'refused': dict(sorted(refused.items())),
                     'chosen': len(chosen)},
            'chosen': chosen, 'window': win, 'source_views': src_views}


# --- Writing ----------------------------------------------------------------

def to_glb(variant, state_colour):
    """One .glb: the thing in its material colour, the ground in sand."""
    scene = trimesh.Scene()

    def material(hexcol):
        r, g, b = lk._rgb(hexcol)
        return trimesh.visual.material.PBRMaterial(
            baseColorFactor=[r, g, b, 255], metallicFactor=0.0,
            roughnessFactor=0.9)
    thing = variant['thing'].copy()
    thing.visual = trimesh.visual.TextureVisuals(
        material=material(state_colour))
    scene.add_geometry(thing, node_name='thing', geom_name='thing')
    for i, g in enumerate(variant['ground']):
        g = g.copy()
        colour = lk.SAND if i == 0 and len(g.faces) > 100 else lk.GRASS
        g.visual = trimesh.visual.TextureVisuals(material=material(colour))
        scene.add_geometry(g, node_name=f'ground{i}', geom_name=f'ground{i}')
    return scene.export(file_type='glb')


def render(meshes_colours, size=160, yaw=35, pitch=22, win=None):
    """A shaded three-quarter view for the eye check (painter's order)."""
    rot = trimesh.transformations.euler_matrix(math.radians(pitch),
                                               math.radians(yaw), 0)[:3, :3]
    light = np.array([-0.4, 0.8, 0.45])
    light /= np.linalg.norm(light)
    polys = []
    centre, half = win
    k = (size / 2 - 2) / half
    for mesh, colour in meshes_colours:
        v = (mesh.vertices - centre).dot(rot.T)
        tri = v[mesh.faces]
        normals = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
        lens = np.linalg.norm(normals, axis=1)
        lens[lens == 0] = 1
        normals /= lens[:, None]
        rgb = np.array(lk._rgb(colour), float)
        for t in range(len(tri)):
            shade = 0.35 + 0.65 * abs(float(normals[t].dot(light)))
            pts = [(x * k + size / 2, size / 2 - y * k)
                   for x, y, _ in tri[t]]
            polys.append((float(tri[t][:, 2].mean()), pts,
                          tuple(int(c * shade) for c in rgb)))
    polys.sort(key=lambda p: p[0])
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    for _, pts, col in polys:
        draw.polygon(pts, fill=col + (255,))
    return img
