"""Still frames of the insights (CLAUDE.md TABOO 0.021): one realistic
picture of the other epoch for each memory, built from the render
prompt the chorus of screenwriters wrote (docs/story/chorus-ep1/
INSIGHT_PROMPTS_2026-10-02.md).  Our Silicon Graphics again: Blender
4.5 LTS as a Python module, Cycles on the CPU, Open Image Denoise, seed
1375.  No human figure and no face: people are shown by their traces
(a pen just laid down, a broken loaf, a wet rope), as the prompts ask.

    /home/user/bpy-venv/bin/python scripts/prerender/render_insights.py \\
        [--only ink_first_line] [--samples 160] [--size 768]

The frames go to godot/art/prerender/insight_<id>.jpg; the scene shows
them in the middle of the memory's veil.

Version 3 (2026-10-03) carries the fixes of the frame chorus
(docs/review/REVIEW_INSIGHTS_2026-10-03.md): every human fire burns at
1900-2200 K, because 1800 K is the lampada's class and belongs to the
holy alone (TABOO 0.38); one main spot of contrast per frame, on the
thing the narrator names; irregular stones and ridges instead of
cubes and saw teeth; the camera sees as far as the mountains.

Variants of the hour (2026-10-03; the operator: «другие точки
постановки камеры угол свет наклон и текст сделай. разные по времени
суток по 12 на каждые 12»; «в пеп 8 запиши технологию и опиши ее 144
рендера для веток развития игры»).  The technology of the 144 renders,
in full in docs/TECH_INSIGHT_RENDER_144_2026-10-03.md:

1. scripts/prerender/insight_variants.py writes the recipe,
   godot/data/pilot-insight-variants.json: twelve hours of the day for
   each insight, the sun from the latitude and date of the place and
   the solar hour, the camera as an orbit around the subject, the fire
   in 1900-2200 K and the narrator's line of that hour.
2. This script, with --variant-file and --variant N[,M] or
   --all-variants, builds the insight's scene as for its canonical
   frame and then moves the sun, sky, window light, fire and camera by
   the recipe (apply_variant), lifts the camera over an obstacle or
   pulls it in front of it (place_camera), meters the exposure toward
   the hour's brightness (expose) and renders at 512 px, 56 samples,
   seed 1375 + v, with Open Image Denoise, into
   build/insight_variants/<id>/vNN.jpg with a vNN.json of the camera
   and the seconds it took.  Never into godot/: nothing enters the APK.
3. scripts/video/insight_variant_sheets.py lays the frames on contact
   sheets; the chorus picks and remarks «− / + / +».
4. scripts/story/insight_branches.py makes each variant a branch node
   (godot/data/pilot-insight-branches.json) that converges into the
   insight's next beat; scripts/story/check_branches.py checks them.
5. scripts/video/insights_variants_reel.py builds the two reels.

    /home/user/bpy-venv/bin/python scripts/prerender/render_insights.py \\
        --variant-file godot/data/pilot-insight-variants.json \\
        --all-variants --size 512 --samples 56 [--only id] [--force]

Constitution: ФОРМА (the place of the other epoch, its light and the
things people left) → ДЕЙСТВИЕ (render it once, exactly, offline) →
ЦЕЛЬ (the memory looks true, so the law it explains is believed).
"""

import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Quaternion, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import render_items as ri  # noqa: E402

OUT = Path(ri.arg('--out', str(ri.ROOT / 'godot' / 'art' / 'prerender')))

# Human fire (lamp, candle, torch, brazier, lantern) stays inside this
# band; the lampada's 1800 K is never used for it (TABOO 0.38 p. 1).
FIRE_MIN_K, FIRE_MAX_K = 1900, 2200


def kelvin(k):
    """An approximate linear RGB of a black body, enough to tell a
    candle (1900 K) from the moon (4100 K) and noon (5500 K)."""
    t = k / 100.0
    if t <= 66:
        r = 1.0
        g = max(0.0, min(1.0, (99.47 * math.log(t) - 161.12) / 255.0))
        b = 0.0 if t <= 19 else max(0.0, min(
            1.0, (138.52 * math.log(t - 10) - 305.04) / 255.0))
    else:
        r = max(0.0, min(1.0, 329.70 * ((t - 60) ** -0.1332) / 255.0))
        g = max(0.0, min(1.0, 288.12 * ((t - 60) ** -0.0755) / 255.0))
        b = 1.0
    return (r ** 2.2, g ** 2.2, b ** 2.2)


def fire_k(k):
    """Guard for human fire: a temperature outside 1900-2200 K is a
    mistake in the recipe, not a choice, so the render stops."""
    if not FIRE_MIN_K <= k <= FIRE_MAX_K:
        raise ValueError('human fire at %d K is outside %d-%d K'
                         % (k, FIRE_MIN_K, FIRE_MAX_K))
    return k


def light(kind, loc, energy, k, size=0.2, aim=(0, 0, 0), size_y=None):
    bpy.ops.object.light_add(type=kind, location=loc)
    lt = bpy.context.object
    lt.data.energy = energy
    lt.data.color = kelvin(k)
    # The Kelvin is kept on the light, so a variant of another hour
    # can tell human fire from the sky and the instrument.
    lt['k'] = k
    if kind == 'AREA':
        if size_y is None:
            lt.data.size = size
        else:
            lt.data.shape = 'RECTANGLE'
            lt.data.size = size
            lt.data.size_y = size_y
    elif kind in ('POINT', 'SPOT'):
        lt.data.shadow_soft_size = size
    elif kind == 'SUN':
        lt.data.angle = size
    d = Vector(aim) - lt.location
    lt.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    return lt


def camera(sc, loc, aim, lens=50, fstop=0.0, focus=None):
    cd = bpy.data.cameras.new('cam')
    cd.lens = lens
    # The default far plane (100 m) cut the lake and the mountains out
    # of scribe_lifts_eyes and left a black frame: see to 3 km.
    cd.clip_start = 0.01
    cd.clip_end = 3000.0
    if fstop:
        cd.dof.use_dof = True
        cd.dof.aperture_fstop = fstop
        cd.dof.focus_distance = focus or (Vector(aim) - Vector(loc)).length
    cam = bpy.data.objects.new('cam', cd)
    bpy.context.collection.objects.link(cam)
    cam.location = loc
    d = Vector(aim) - Vector(loc)
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    # The subject the camera looks at: a variant orbits around it.
    cam['aim'] = tuple(aim)
    sc.camera = cam
    return cam


def on_screen(cam, u, v, dist):
    """The world point seen at (u, v) of the square frame (-1..1 from
    the centre to the edge) at a distance along the view: used to put
    a lantern or a candle exactly where the prompt wants it."""
    t = 18.0 / cam.data.lens
    d = cam.rotation_euler.to_matrix() @ Vector((u * t, v * t, -1.0))
    return tuple(cam.location + d.normalized() * dist)


def on_wall(cam, u, v, y):
    """Where the ray through (u, v) of the frame meets the plane y =
    const (a wall behind the subject): the edge of the frame, exactly."""
    t = 18.0 / cam.data.lens
    d = cam.rotation_euler.to_matrix() @ Vector((u * t, v * t, -1.0))
    k = (y - cam.location.y) / d.y
    return tuple(cam.location + d * k)


def box(size, at, m, rot=(0, 0, 0), bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at, rotation=rot)
    ob = bpy.context.object
    ob.scale = size
    ri.link(ob, m)
    if bevel:
        b = ob.modifiers.new('bev', 'BEVEL')
        b.width = bevel
        b.segments = 3
    return ob


def cyl(r, depth, at, m, rot=(0, 0, 0), verts=64):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r,
                                        depth=depth, location=at,
                                        rotation=rot)
    ob = bpy.context.object
    if depth < 0.3 * r:
        # A thin disc (a coin, an astrolabe) stays flat-shaded: smoothing
        # bends the cap's normals and the disc reads as a ball.
        return ri.link(ob, m)
    return ri.link(ri.smooth(ob, 0), m)


def torus(major, minor, at, m, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major,
                                     minor_radius=minor, location=at,
                                     rotation=rot)
    return ri.link(ri.smooth(bpy.context.object, 0), m)


def world(sc, colour, strength=1.0):
    bg = sc.world.node_tree.nodes['Background']
    bg.inputs[0].default_value = colour + (1,)
    bg.inputs[1].default_value = strength


def haze(density, colour=(0.6, 0.6, 0.6), size=12.0, at=(0, 0, 1),
         dims=None):
    """A volume box: dust in lamp light, mist over water, murk under
    it."""
    m = bpy.data.materials.new('haze')
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.remove(nt.nodes['Principled BSDF'])
    v = nt.nodes.new('ShaderNodeVolumePrincipled')
    v.inputs['Density'].default_value = density
    v.inputs['Color'].default_value = colour + (1,)
    nt.links.new(v.outputs[0], nt.nodes['Material Output'].inputs['Volume'])
    ob = box(dims or (size, size, size * 0.5), at, m)
    ob['haze'] = True
    return ob


def water(at, size, colour=(0.05, 0.12, 0.10), rough=0.04, bump=0.15,
          scale=6, stretch=(1.0, 1.0)):
    m = ri.mat('water', colour, rough=rough, bump=bump, scale=scale)
    p = m.node_tree.nodes['Principled BSDF']
    p.inputs['Transmission Weight'].default_value = 0.9
    p.inputs['IOR'].default_value = 1.333
    bpy.ops.mesh.primitive_plane_add(size=size, location=at)
    ob = bpy.context.object
    ob.scale = (stretch[0], stretch[1], 1.0)
    return ri.link(ob, m)


def boulders(n, spread, at, m, seed, scale=(0.18, 0.13, 0.08)):
    """Irregular river stones placed by a fixed seed (no randomness at
    play time; the seed is part of the frame's recipe).  Each is an
    icosphere with its vertices pushed in and out, so no two are the
    same egg.  Returns the centres and sizes, for foam and rime."""
    rnd = random.Random(seed)
    out = []
    for i in range(n):
        x = at[0] + rnd.uniform(-spread, spread)
        y = at[1] + rnd.uniform(-spread, spread)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1,
                                              location=(x, y, at[2]))
        s = bpy.context.object
        for v in s.data.vertices:
            v.co *= rnd.uniform(0.78, 1.12)
        k = rnd.uniform(0.6, 1.3)
        s.scale = (scale[0] * k, scale[1] * k, scale[2] * k)
        s.rotation_euler = (0, 0, rnd.uniform(0, 3.14))
        ri.link(ri.smooth(s, 1), m)
        out.append(((x, y, at[2]), scale[0] * k, scale[2] * k))
    return out


def ashlar(size, at, m, seed, bevel=0.025):
    """A split building stone: a block whose eight corners are moved by
    the seed, so the faces are skewed as a mason's hammer leaves them,
    never the clean cube of a cinder block."""
    rnd = random.Random(seed)
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    ob = bpy.context.object
    for v in ob.data.vertices:
        v.co.x += rnd.uniform(-0.14, 0.14)
        v.co.y += rnd.uniform(-0.08, 0.08)
        v.co.z += rnd.uniform(-0.1, 0.1)
    ob.scale = size
    ob.rotation_euler = (rnd.uniform(-0.03, 0.03), 0,
                         rnd.uniform(-0.05, 0.05))
    b = ob.modifiers.new('bev', 'BEVEL')
    b.width = bevel
    b.segments = 2
    return ri.link(ob, m)


def smooth_noise(seed, n):
    """Value noise on n knots with cosine easing: the same seed gives
    the same mountains, and the slopes have no saw teeth."""
    rnd = random.Random(seed)
    knots = [rnd.random() for _ in range(n + 2)]

    def f(t):
        i = int(t)
        a = t - i
        a = (1 - math.cos(math.pi * a)) / 2
        return knots[i] * (1 - a) + knots[i + 1] * a
    return f


def ridge(name, x0, x1, y0, depth, z0, peak, seed, rock, snow=None,
          snow_at=0.62, nx=180, ny=16):
    """A mountain range as a grid with a front slope, a crest and a
    back slope; two octaves of smooth noise along it, snow caps above a
    height.  Replaces the flat saw-tooth strips of version 2."""
    big = smooth_noise(seed, 40)
    small = smooth_noise(seed + 1, 140)
    verts = []
    for j in range(ny + 1):
        v = j / ny
        prof = math.sin(math.pi * v) ** 0.7
        for i in range(nx + 1):
            u = i / nx
            h = 0.6 * big(u * 30) + 0.28 * small(u * 120 + v * 4) + 0.12
            verts.append((x0 + (x1 - x0) * u, y0 + depth * v,
                          z0 + peak * h * prof))
    faces = []
    for j in range(ny):
        for i in range(nx):
            a = j * (nx + 1) + i
            faces.append((a, a + 1, a + nx + 2, a + nx + 1))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    me.materials.append(rock)
    if snow is not None:
        me.materials.append(snow)
        line = z0 + snow_at * peak
        for p in me.polygons:
            if sum(me.vertices[k].co.z for k in p.vertices) / 4 > line:
                p.material_index = 1
    for p in me.polygons:
        p.use_smooth = True
    return ob


def rimed(name, base, rough=0.6, bump=0.8, scale=30):
    """A stone whose upward faces carry a thin white rime: the colour
    follows the surface normal, so the frost lies on top only."""
    m = ri.mat(name, base, rough=rough, bump=bump, scale=scale)
    nt = m.node_tree
    p = nt.nodes['Principled BSDF']
    geo = nt.nodes.new('ShaderNodeNewGeometry')
    sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = 0.86
    ramp.color_ramp.elements[0].color = base + (1,)
    ramp.color_ramp.elements[1].position = 0.97
    ramp.color_ramp.elements[1].color = (0.86, 0.89, 0.93, 1)
    nt.links.new(geo.outputs['Normal'], sep.inputs[0])
    nt.links.new(sep.outputs['Z'], ramp.inputs['Fac'])
    nt.links.new(ramp.outputs['Color'], p.inputs['Base Color'])
    return m


def crackle(name, base, rough=0.35, scale=55):
    """A glaze with a fine crackle: a Voronoi edge net drives the bump,
    so the glaze reads as fired clay and not as plastic."""
    m = ri.mat(name, base, rough=rough, coat=0.25)
    nt = m.node_tree
    p = nt.nodes['Principled BSDF']
    vor = nt.nodes.new('ShaderNodeTexVoronoi')
    vor.feature = 'DISTANCE_TO_EDGE'
    vor.inputs['Scale'].default_value = scale
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (0, 0, 0, 1)
    ramp.color_ramp.elements[1].position = 0.04
    ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
    b = nt.nodes.new('ShaderNodeBump')
    b.inputs['Strength'].default_value = 0.35
    b.inputs['Distance'].default_value = 0.0008
    nt.links.new(vor.outputs['Distance'], ramp.inputs['Fac'])
    nt.links.new(ramp.outputs['Color'], b.inputs['Height'])
    nt.links.new(b.outputs['Normal'], p.inputs['Normal'])
    return m


def laid_rope(name, base, scale=90.0):
    """Hemp with its lay: diagonal bands in the bump, so a rope reads
    as twisted strands and not as a garden hose."""
    m = ri.mat(name, base, rough=0.85)
    nt = m.node_tree
    p = nt.nodes['Principled BSDF']
    wave = nt.nodes.new('ShaderNodeTexWave')
    wave.wave_type = 'BANDS'
    wave.bands_direction = 'DIAGONAL'
    wave.inputs['Scale'].default_value = scale
    wave.inputs['Distortion'].default_value = 1.5
    b = nt.nodes.new('ShaderNodeBump')
    b.inputs['Strength'].default_value = 0.8
    b.inputs['Distance'].default_value = 0.004
    nt.links.new(wave.outputs['Fac'], b.inputs['Height'])
    nt.links.new(b.outputs['Normal'], p.inputs['Normal'])
    return m


def leaf(spine, w, h, side, m, lift=0.01, nx=24, ny=4):
    """One leaf of an open codex: it rises out of the gutter and lies
    almost flat to its fore-edge (side +1 right, -1 left).  Returns the
    leaf and its height as a function of x, for the script lines."""
    def zf(x):
        u = min(1.0, max(0.0, abs(x - spine[0]) / w))
        return (spine[2] + lift * math.sin(0.5 * math.pi * min(1.0, u * 2.5))
                - 0.003 * u)
    verts, faces = [], []
    for j in range(ny + 1):
        y = spine[1] - h / 2 + h * j / ny
        for i in range(nx + 1):
            x = spine[0] + side * w * i / nx
            verts.append((x, y, zf(x)))
    for j in range(ny):
        for i in range(nx):
            a = j * (nx + 1) + i
            faces.append((a, a + 1, a + nx + 2, a + nx + 1))
    me = bpy.data.meshes.new('leaf')
    me.from_pydata(verts, [], faces)
    ob = bpy.data.objects.new('leaf', me)
    bpy.context.collection.objects.link(ob)
    for p in me.polygons:
        p.use_smooth = True
    return ri.link(ob, m), zf


def codex(spine, m_leaf, m_cover, w=0.16, h=0.24):
    """An open codex: two leaves, the page blocks under them, the
    leather boards and the round spine in the gutter."""
    _, zl = leaf(spine, w, h, -1, m_leaf)
    _, zr = leaf(spine, w, h, 1, m_leaf)
    for side in (-1, 1):
        box((w, h - 0.004, 0.012),
            (spine[0] + side * w / 2, spine[1], spine[2] - 0.008), m_leaf)
        box((w + 0.012, h + 0.014, 0.004),
            (spine[0] + side * (w / 2 + 0.006), spine[1],
             spine[2] - 0.016), m_cover)
    cyl(0.007, h + 0.012, (spine[0], spine[1], spine[2] - 0.012), m_cover,
        rot=(math.radians(90), 0, 0), verts=24)
    return zl, zr


def page(at, size, m, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_plane_add(size=1, location=at, rotation=rot)
    p = bpy.context.object
    p.scale = (size[0], size[1], 1)
    return ri.link(p, m)


def script_lines(at, width, rows, ink, step=0.012, seed=1375, zf=None,
                 last=None, fine=False):
    """Illegible lines of script on a page: short dark strokes in rows,
    so the page reads as written without any readable word.  zf gives
    the page's height under x (a curved leaf); last cuts the last row
    to that fraction of the width (a line broken off mid-word).  fine
    draws letter-sized marks for a macro frame, where the coarse strokes
    read as a bar code."""
    rnd = random.Random(seed)
    for r in range(rows):
        x = at[0] - width / 2
        y = at[1] + r * step
        end = at[0] + width / 2 - 0.01
        if last is not None and r == rows - 1:
            end = at[0] - width / 2 + width * last
        while x < end:
            if fine:
                w = rnd.uniform(0.0012, 0.0035)
                hgt = rnd.choice((0.0022, 0.0022, 0.0034))
                gap = rnd.choice((0.0009, 0.0009, 0.0009, 0.003))
            else:
                w = rnd.uniform(0.006, 0.02)
                hgt = 0.0016
                gap = rnd.uniform(0.002, 0.005)
            z = (zf(x + w / 2) + 0.0004) if zf else at[2]
            box((w, hgt, 0.0003), (x + w / 2, y, z), ink)
            x += w + gap
    return x


def exposure(sc, ev):
    sc.view_settings.exposure = ev


def halve(ob, keep_x_positive=True, gap=0.0, inner=None):
    """Cut a body along x by a boolean, as a loaf is torn; gap moves
    the cut off the middle, so the two parts are unequal.  The cut
    faces take the inner material (the crumb)."""
    bpy.ops.mesh.primitive_cube_add(size=2, location=(
        ob.location.x + (-1.0 if keep_x_positive else 1.0) + gap,
        ob.location.y, ob.location.z))
    cutter = bpy.context.object
    if inner is not None:
        cutter.data.materials.append(inner)
    mod = ob.modifiers.new('cut', 'BOOLEAN')
    mod.operation = 'DIFFERENCE'
    mod.object = cutter
    mod.material_mode = 'TRANSFER'
    cutter.hide_render = True
    return ob


SCENES = {}


def scene(fn):
    SCENES[fn.__name__] = fn
    return fn


def stars(sc, density=0.004, strength=2.0, base=(0.004, 0.006, 0.02),
          milky=0.0):
    """A night sky: deep indigo with stars from a fine Voronoi field,
    procedural (no photo, as the prompts ask).  milky adds a faint
    band of the Milky Way across the sky."""
    nt = sc.world.node_tree
    bg = nt.nodes['Background']
    tc = nt.nodes.new('ShaderNodeTexCoord')
    vor = nt.nodes.new('ShaderNodeTexVoronoi')
    vor.inputs['Scale'].default_value = 400.0
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (1, 1, 1, 1)
    ramp.color_ramp.elements[1].position = density
    ramp.color_ramp.elements[1].color = (0, 0, 0, 1)
    mix = nt.nodes.new('ShaderNodeMix')
    mix.data_type = 'RGBA'
    mix.inputs['A'].default_value = base + (1,)
    mix.inputs['B'].default_value = (strength, strength, strength * 1.1, 1)
    nt.links.new(tc.outputs['Generated'], vor.inputs['Vector'])
    nt.links.new(vor.outputs['Distance'], ramp.inputs['Fac'])
    nt.links.new(ramp.outputs['Color'], mix.inputs['Factor'])
    if not milky:
        nt.links.new(mix.outputs['Result'], bg.inputs['Color'])
        return
    # The band: a noise cloud kept near one great circle of the sky.
    band = nt.nodes.new('ShaderNodeVectorMath')
    band.operation = 'DOT_PRODUCT'
    band.inputs[1].default_value = (0.5, 0.0, 1.0)
    nt.links.new(tc.outputs['Generated'], band.inputs[0])
    near = nt.nodes.new('ShaderNodeMapRange')
    near.inputs['From Min'].default_value = 0.05
    near.inputs['From Max'].default_value = 0.35
    near.inputs['To Min'].default_value = 0.0
    near.inputs['To Max'].default_value = 1.0
    nt.links.new(band.outputs['Value'], near.inputs['Value'])
    tri = nt.nodes.new('ShaderNodeMath')
    tri.operation = 'PINGPONG'
    tri.inputs[1].default_value = 0.5
    nt.links.new(near.outputs[0], tri.inputs[0])
    cloud = nt.nodes.new('ShaderNodeTexNoise')
    cloud.inputs['Scale'].default_value = 12.0
    cloud.inputs['Detail'].default_value = 8.0
    nt.links.new(tc.outputs['Generated'], cloud.inputs['Vector'])
    amt = nt.nodes.new('ShaderNodeMath')
    amt.operation = 'MULTIPLY'
    nt.links.new(tri.outputs[0], amt.inputs[0])
    nt.links.new(cloud.outputs['Fac'], amt.inputs[1])
    glowm = nt.nodes.new('ShaderNodeMath')
    glowm.operation = 'MULTIPLY'
    glowm.inputs[1].default_value = milky
    nt.links.new(amt.outputs[0], glowm.inputs[0])
    add = nt.nodes.new('ShaderNodeMix')
    add.data_type = 'RGBA'
    add.blend_type = 'ADD'
    add.inputs['Factor'].default_value = 1.0
    nt.links.new(mix.outputs['Result'], add.inputs['A'])
    nt.links.new(glowm.outputs[0], add.inputs['B'])
    nt.links.new(add.outputs['Result'], bg.inputs['Color'])


def emit_mat(colour, strength):
    m = bpy.data.materials.new('emit')
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.remove(nt.nodes['Principled BSDF'])
    e = nt.nodes.new('ShaderNodeEmission')
    e.inputs['Color'].default_value = colour + (1,)
    e.inputs['Strength'].default_value = strength
    nt.links.new(e.outputs[0], nt.nodes['Material Output'].inputs[0])
    return m


def glow(at, r, k, strength, stretch=1.0):
    """A small flame or a far window: an emitting body (k in Kelvin)."""
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=at)
    ob = bpy.context.object
    ob.scale = (1.0, 1.0, stretch)
    m = emit_mat(kelvin(k), strength)
    m['k'] = k
    return ri.link(ri.smooth(ob, 0), m)


def flame(at, h, r, k, strength):
    """A torch or lamp flame: an emitting cone, wide at the root."""
    bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=r, radius2=0.0,
                                    depth=h, location=(at[0], at[1],
                                                       at[2] + h / 2))
    ob = bpy.context.object
    m = emit_mat(kelvin(fire_k(k)), strength)
    m['k'] = k
    return ri.link(ri.smooth(ob, 1), m)


def panel(size, at, rot, k, strength, colour=None):
    bpy.ops.mesh.primitive_plane_add(size=1, location=at, rotation=rot)
    pl = bpy.context.object
    pl.scale = (size[0], size[1], 1)
    m = emit_mat(colour or kelvin(k), strength)
    m['k'] = 0 if colour else k
    return ri.link(pl, m)


def rope(points, r, m):
    cu = bpy.data.curves.new('rope', 'CURVE')
    cu.dimensions = '3D'
    cu.bevel_depth = r
    cu.bevel_resolution = 4
    # A polyline, not a Bezier: automatic handles overshoot and lift a
    # rope that should lie on the stones.
    sp = cu.splines.new('POLY')
    sp.points.add(len(points) - 1)
    for pt, co in zip(sp.points, points):
        pt.co = (co[0], co[1], co[2], 1.0)
    ob = bpy.data.objects.new('rope', cu)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(m)
    return ob


# A horseman facing right in units of the coin's radius: the worn
# relief of the Cilician silver (no letters, nothing readable).
HORSEMAN = [(-0.60, -0.05), (-0.45, 0.12), (-0.22, 0.12), (-0.24, 0.38),
            (-0.16, 0.50), (-0.16, 0.60), (-0.08, 0.66), (-0.02, 0.60),
            (-0.06, 0.50), (0.08, 0.42), (0.06, 0.36), (-0.06, 0.38),
            (-0.04, 0.14), (0.25, 0.14), (0.38, 0.38), (0.50, 0.40),
            (0.60, 0.28), (0.52, 0.24), (0.40, 0.28), (0.32, 0.06),
            (0.30, -0.10), (0.34, -0.45), (0.28, -0.45), (0.22, -0.12),
            (0.10, -0.08), (-0.30, -0.08), (-0.32, -0.45), (-0.38, -0.45),
            (-0.42, -0.10), (-0.50, -0.02)]


def coin(at, r, silver, rot=(0, 0, 0), relief=True):
    """A thin silver coin; face up it carries the horseman in low
    relief (0.2 mm), as the prompt asks, so it catches the light."""
    c = cyl(r, 0.0012, at, silver, rot=rot, verts=48)
    if not relief:
        return c
    pts = [(x * r * 0.8, y * r * 0.8, 0.0) for x, y in HORSEMAN]
    me = bpy.data.meshes.new('horseman')
    me.from_pydata(pts, [], [list(range(len(pts)))])
    hm = bpy.data.objects.new('horseman', me)
    bpy.context.collection.objects.link(hm)
    sol = hm.modifiers.new('sol', 'SOLIDIFY')
    sol.thickness = 0.0002
    hm.parent = c
    hm.location = (0, 0, 0.0006)
    return ri.link(hm, silver)


def scatter_coins(at, n, silver, seed, spread=0.06, edge=True):
    """Coins spilt from a purse, placed by the seed: never the neat
    grid of an inventory; one may stand on its edge."""
    rnd = random.Random(seed)
    for i in range(n):
        x = at[0] + rnd.gauss(0, spread * 0.5)
        y = at[1] + rnd.gauss(0, spread * 0.35)
        z = at[2] + 0.0006 + 0.0012 * (i % 3 == 2)
        coin((x, y, z), 0.011, silver,
             rot=(math.radians(rnd.uniform(0, 6)), 0,
                  rnd.uniform(0, 6.28)))
    if edge:
        coin((at[0] + spread * 0.9, at[1] - spread * 0.2, at[2] + 0.011),
             0.011, silver, rot=(math.radians(84), 0, math.radians(20)),
             relief=False)


def pouch(at, r, h, m, folds=9, rot=(0, 0, 0)):
    """A soft leather purse drawn in at the neck by a cord: a body of
    revolution whose radius ripples into folds toward the mouth, never
    the mushroom of version 2."""
    prof = [(0.0, 0.0), (0.6, 0.02), (0.95, 0.18), (1.0, 0.38),
            (0.86, 0.58), (0.45, 0.74), (0.28, 0.80), (0.40, 0.88),
            (0.55, 0.98), (0.47, 1.0)]
    seg = 64
    verts, faces = [], []
    for s in range(seg):
        a = 2 * math.pi * s / seg
        for pr, pz in prof:
            fold = 0.03 + 0.2 * max(0.0, pz - 0.45) / 0.55
            rr = r * pr * (1 + fold * math.sin(folds * a + 3 * pz))
            verts.append((rr * math.cos(a), rr * math.sin(a), h * pz))
    n = len(prof)
    for s in range(seg):
        t = (s + 1) % seg
        for i in range(n - 1):
            faces.append((s * n + i, t * n + i, t * n + i + 1,
                          s * n + i + 1))
    me = bpy.data.meshes.new('pouch')
    me.from_pydata(verts, [], faces)
    ob = bpy.data.objects.new('pouch', me)
    bpy.context.collection.objects.link(ob)
    ob.location = at
    ob.rotation_euler = rot
    ri.link(ri.smooth(ob, 1), m)
    tie = torus(r * 0.3, 0.0018, (0, 0, h * 0.8),
                ri.mat('cord', (0.30, 0.20, 0.10), rough=0.8))
    tie.parent = ob
    return ob


def resample(profile, n):
    """More points on a lathe profile, evenly by length, so a dent can
    be pressed into the clay between them."""
    seglen = [math.dist(profile[i], profile[i + 1])
              for i in range(len(profile) - 1)]
    total = sum(seglen)
    out = []
    for k in range(n):
        d = total * k / (n - 1)
        i = 0
        while i < len(seglen) - 1 and d > seglen[i]:
            d -= seglen[i]
            i += 1
        t = d / seglen[i] if seglen[i] else 0.0
        a, b = profile[i], profile[i + 1]
        out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    return out


# A Semirechye jug: low foot ring, round belly, narrow neck, two small
# lug handles at the shoulder (version 2 used a Greek amphora, a
# Mediterranean form this bazaar never knew).
JUG = [(0.0, 0.0), (0.055, 0.0), (0.058, 0.012), (0.05, 0.02),
       (0.075, 0.05), (0.11, 0.11), (0.125, 0.17), (0.118, 0.22),
       (0.095, 0.26), (0.05, 0.295), (0.03, 0.31), (0.026, 0.37),
       (0.033, 0.395), (0.03, 0.4), (0.022, 0.39), (0.0, 0.33)]


def jug(name, m, k=0.7, dent=None):
    """The local jug at scale k (0.7 gives the prompt's 0.28 m).  dent
    is (angle, height): a thumb's dent 3 mm deep and 2 cm wide pressed
    into the wall there."""
    prof = [(r * k, z * k) for r, z in resample(JUG, 70)]
    ob = ri.lathe(name, prof, 128)
    if dent:
        a0, z0 = dent
        for v in ob.data.vertices:
            rr = math.hypot(v.co.x, v.co.y)
            if rr < 1e-6:
                continue
            da = math.atan2(v.co.y, v.co.x) - a0
            da = (da + math.pi) % (2 * math.pi) - math.pi
            d = math.hypot(rr * da, v.co.z - z0)
            if d < 0.02:
                push = 0.003 * (1 - (d / 0.02) ** 2)
                v.co.x -= push * v.co.x / rr
                v.co.y -= push * v.co.y / rr
    for side in (1, -1):
        a = (dent[0] if dent else 0.0) + side * math.pi / 2
        rr = 0.118 * k
        lug = torus(0.022 * k, 0.007 * k,
                    (rr * math.cos(a), rr * math.sin(a), 0.21 * k), m,
                    rot=(math.radians(90), 0, a))
        lug.parent = ob
    return ri.link(ob, m)


def astrolabe(at, rot, brass, line):
    """A brass astrolabe as the prompt draws it: the mater with its
    raised rim, the tympan engraved with almucantars, the pierced rete
    with its pointers, the rule across, the throne and the ring.  Built
    flat around the origin, then turned and moved as one."""
    root = bpy.data.objects.new('astrolabe', None)
    bpy.context.collection.objects.link(root)
    parts = []
    parts.append(cyl(0.08, 0.005, (0, 0, 0), brass, verts=96))
    parts.append(torus(0.08, 0.004, (0, 0, 0.002), brass))
    # The tympan's almucantars: circles of altitude, off-centre and
    # shrinking toward the zenith, engraved as fine dark lines.
    for i in range(7):
        parts.append(torus(0.064 - 0.008 * i, 0.0005,
                           (0, 0.006 + 0.004 * i, 0.0027), line))
    for i in range(6):
        a = math.radians(30 * i)
        parts.append(box((0.13, 0.0008, 0.0004), (0, -0.01, 0.0028), line,
                         rot=(0, 0, a)))
    # The rete: the ecliptic ring off the centre and the star pointers.
    parts.append(torus(0.045, 0.0022, (0, 0.016, 0.0045), brass))
    parts.append(torus(0.066, 0.0018, (0, 0, 0.0045), brass))
    for i in range(5):
        a = math.radians(40 + 63 * i)
        x, y = 0.055 * math.cos(a), 0.055 * math.sin(a)
        parts.append(box((0.03, 0.0025, 0.0015),
                         (x * 0.8, y * 0.8, 0.0045), brass, rot=(0, 0, a)))
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.003,
                                        radius2=0.0, depth=0.008,
                                        location=(x, y, 0.0045),
                                        rotation=(0, math.radians(90),
                                                  a))
        parts.append(ri.link(bpy.context.object, brass))
    # The rule across the face and the pin through the centre.
    parts.append(box((0.15, 0.006, 0.0015), (0, 0, 0.0065), brass,
                     rot=(0, 0, math.radians(28))))
    parts.append(cyl(0.004, 0.012, (0, 0, 0.004), brass, verts=16))
    # The throne and the hanging ring at the top.
    parts.append(box((0.03, 0.02, 0.005), (0, 0.088, 0), brass))
    parts.append(torus(0.011, 0.0018, (0, 0.108, 0), brass,
                       rot=(math.radians(90), 0, 0)))
    for p in parts:
        p.parent = root
    root.location = at
    root.rotation_euler = rot
    return root


def rock_mount_mats(snow=True):
    rock = ri.mat('mount', (0.10, 0.10, 0.11), rough=0.95, bump=1.0,
                  scale=0.4)
    cap = ri.mat('snow', (0.78, 0.80, 0.84), rough=0.8) if snow else None
    return rock, cap


@scene
def ink_first_line(sc):
    lime = ri.mat('lime', (0.42, 0.39, 0.33), rough=0.95, bump=1.2,
                  scale=25, spots=(0.30, 0.28, 0.24))
    walnut = ri.mat('walnut', (0.09, 0.05, 0.03), rough=0.55, bump=0.3,
                    scale=60)
    vellum = ri.mat('vellum', (0.72, 0.64, 0.48), rough=0.9, bump=0.4,
                    scale=180, spots=(0.58, 0.50, 0.36))
    cover = ri.mat('board', (0.16, 0.08, 0.04), rough=0.6, bump=0.5,
                   scale=90)
    ink = ri.mat('ink', (0.05, 0.03, 0.02), rough=0.6)
    wet = ri.mat('wet', (0.04, 0.025, 0.015), rough=0.05, coat=1.0)
    clay = ri.mat('clay', (0.32, 0.15, 0.07), rough=0.85, bump=0.6,
                  scale=60)
    wool = ri.mat('wool', (0.18, 0.11, 0.07), rough=1.0, bump=0.8,
                  scale=300)
    box((4, 0.3, 3), (0, 1.0, 1.5), lime)
    box((4, 4, 0.1), (0, 0, -0.05), lime)
    # The left wall with a real opening 0.4 x 0.6 m (y 0.35-0.75,
    # z 0.85-1.45), so the reveal catches the light.
    box((0.3, 2.35, 3), (-1.0, -0.825, 1.5), lime)
    box((0.3, 1.25, 3), (-1.0, 1.375, 1.5), lime)
    box((0.3, 0.4, 0.85), (-1.0, 0.55, 0.425), lime)
    box((0.3, 0.4, 1.55), (-1.0, 0.55, 2.225), lime)
    # What the window shows, from top to bottom: the overcast sky, the
    # far white mountains, a dark shore, the grey strip of the lake; on
    # the inner face, because the camera sees the deep reveal edgewise.
    # Kept about 1.5 EV under version 2, so it is a view and not a
    # white hole.
    up = (0, math.radians(90), 0)
    panel((0.3, 0.4), (-0.87, 0.55, 1.30), up, 7000, 1.6)
    me = bpy.data.meshes.new('peaks')
    rnd = random.Random(1375)
    tops = [1.10 + 0.05 * rnd.random() for _ in range(17)]
    vs = [(-0.866, 0.35 + 0.025 * i, 1.02) for i in range(17)]
    vs += [(-0.866, 0.35 + 0.025 * i, tops[i]) for i in range(17)]
    me.from_pydata(vs, [], [(i, i + 1, 18 + i, 17 + i) for i in range(16)])
    pk = bpy.data.objects.new('peaks', me)
    bpy.context.collection.objects.link(pk)
    ri.link(pk, emit_mat((0.62, 0.64, 0.68), 1.3))
    panel((0.03, 0.4), (-0.865, 0.55, 1.005), up, 0, 0.25,
          colour=(0.12, 0.13, 0.14))
    panel((0.17, 0.4), (-0.864, 0.55, 0.905), up, 0, 0.8,
          colour=(0.32, 0.38, 0.43))
    light('AREA', (-0.9, 0.55, 1.15), 9, 7000, size=0.5,
          aim=(0.0, 0.1, 0.75))
    exposure(sc, -0.6)
    box((1.0, 0.6, 0.05), (0, 0.15, 0.725), walnut, bevel=0.01)
    for x in (-0.45, 0.45):
        box((0.05, 0.5, 0.7), (x, 0.15, 0.35), walnut)
    zl, zr = codex((0.0, 0.1, 0.77), vellum, cover)
    script_lines((-0.085, -0.01, 0), 0.13, 17, ink, step=0.013, zf=zl)
    script_lines((0.085, -0.01, 0), 0.12, 2, wet, step=0.013, seed=7,
                 zf=zr)
    # The reed pen lies along the right leaf, never across the gutter:
    # a pen over the fold reads as a cross.  Its cut nib is wet.
    rot = (math.radians(90), 0, math.radians(12))
    axis = Vector((math.sin(math.radians(12)), -math.cos(math.radians(12)),
                   0.0))
    c = Vector((0.11, 0.08, zr(0.11) + 0.004))
    cyl(0.0035, 0.19, tuple(c), ri.mat('reed', (0.45, 0.36, 0.2),
        rough=0.6, bump=0.3, scale=200), rot=rot, verts=12)
    bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.0035,
                                    radius2=0.0004, depth=0.022,
                                    location=tuple(c + axis * 0.106),
                                    rotation=rot)
    nib = bpy.context.object
    ri.link(nib, wet)
    pot = ri.lathe('inkpot', [(0.0, 0.0), (0.03, 0.0), (0.033, 0.03),
                              (0.025, 0.055), (0.018, 0.06),
                              (0.0, 0.058)], 64)
    pot.location = (0.25, 0.25, 0.75)
    ri.link(pot, clay)
    # The clay oil lamp of the prompt (version 2 had a modern tea
    # light): a closed bowl with a filling hole, a spout with the wick
    # and a ring handle at the back.
    lamp = ri.lathe('lamp', [(0.0, 0.0), (0.035, 0.0), (0.05, 0.014),
                             (0.052, 0.024), (0.04, 0.034),
                             (0.013, 0.038), (0.011, 0.044),
                             (0.0, 0.042)], 64)
    lamp.location = (-0.3, 0.3, 0.75)
    ri.link(lamp, clay)
    cyl(0.011, 0.05, (-0.255, 0.3, 0.775), clay,
        rot=(0, math.radians(80), 0), verts=24)
    torus(0.016, 0.005, (-0.352, 0.3, 0.785), clay,
          rot=(math.radians(90), 0, 0))
    flame((-0.23, 0.3, 0.781), 0.022, 0.0045, 1900, 60.0)
    light('POINT', (-0.23, 0.3, 0.80), 3, 1900, size=0.01)
    box((0.35, 0.3, 0.06), (0.75, 0.6, 0.45), wool, bevel=0.03)
    haze(0.02, (0.7, 0.7, 0.75), size=3, at=(0, 0, 1))
    camera(sc, (0.32, -0.42, 1.08), (-0.05, 0.25, 0.8), lens=40,
           fstop=2.8, focus=0.62)


@scene
def tape_at_night(sc):
    world(sc, (0.002, 0.003, 0.006))
    birch = ri.mat('birch', (0.36, 0.27, 0.17), rough=0.8, bump=0.3,
                   scale=120)
    floor = ri.mat('laminate', (0.25, 0.18, 0.12), rough=0.4, bump=0.1,
                   scale=40)
    wall = ri.mat('wall', (0.14, 0.14, 0.15), rough=0.9, bump=0.2,
                  scale=30)
    tape = ri.mat('tape', (0.80, 0.72, 0.55), rough=0.7, bump=0.2,
                  scale=300)
    black = ri.mat('usb', (0.02, 0.02, 0.02), rough=0.3, coat=0.4)
    card = ri.mat('card', (0.35, 0.26, 0.16), rough=0.9, bump=0.3,
                  scale=60)
    box((1.2, 0.6, 0.025), (0, 0, 0.74), birch, bevel=0.002)
    for x in (-0.57, 0.57):
        box((0.03, 0.55, 0.73), (x, 0, 0.365), birch)
    box((4, 4, 0.02), (0, 0, -0.01), floor)
    # The room's wall behind the desk: the view under the desk ends on
    # it and not in a black hole.
    box((4, 0.05, 2.4), (0, 0.42, 1.2), wall)
    box((0.05, 0.016, 0.008), (0.05, 0.05, 0.723), black, bevel=0.002)
    # The drive's metal plug, so it reads as a drive at a glance.
    box((0.012, 0.012, 0.0045), (0.081, 0.05, 0.7235),
        ri.mat('plug', (0.7, 0.7, 0.72), rough=0.25, metal=1.0))
    # Two parallel strips along the drive, each over one long edge, the
    # black body showing between them.  Crossed strips would read as a
    # saltire; strips across the body read as a letter H in the second
    # v3 render; strips centred on it hid the drive in the first.
    # Each strip runs over the drive and bends up onto the board at
    # both ends, so no tape hangs in the air.
    for y in (0.0405, 0.0595):
        box((0.052, 0.008, 0.0006), (0.05, y, 0.7185), tape)
        box((0.02, 0.008, 0.0006), (0.013, y, 0.7272), tape)
        for x in (0.0245, 0.0755):
            box((0.0006, 0.008, 0.009), (x, y, 0.7228), tape)
    box((0.012, 0.008, 0.0006), (0.082, 0.0405, 0.7272), tape)
    # The end of one strip hangs loose, curling down, not yet pressed.
    box((0.03, 0.008, 0.0006), (0.088, 0.0595, 0.714), tape,
        rot=(0, math.radians(35), 0))
    wetp = ri.mat('wetpatch', (0.2, 0.14, 0.1), rough=0.02, coat=1.0)
    bpy.ops.mesh.primitive_circle_add(vertices=24, radius=0.25,
                                      fill_type='NGON',
                                      location=(-0.1, 0.1, 0.0005))
    ri.link(bpy.context.object, wetp)
    # The laptop above the edge, its cold light falling over the front.
    panel((0.33, 0.21), (0, 0.15, 0.87), (math.radians(-75), 0, 0),
          6500, 8.0)
    light('AREA', (0, -0.15, 0.95), 25, 6500, size=0.35,
          aim=(0, -0.4, 0.0))
    light('AREA', (2.0, 0.5, 1.2), 6, 4000, size=1.0, aim=(0, 0, 0.3))
    # The screen's light comes back from the floor under the desk, cold
    # and three times stronger than in version 2, and gathered on the
    # drive, so the drive and the tape read at a metre in the headset
    # while the rest of the board falls into shadow.
    fill = light('SPOT', (0.0, -0.3, 0.02), 9, 6500, size=0.05,
                 aim=(0.05, 0.05, 0.72))
    fill.data.spot_size = math.radians(30)
    fill.data.spot_blend = 0.6
    cam = (-0.05, -0.22, 0.42)
    drive = (0.05, 0.05, 0.723)
    # The drive on the upper-right third: aim a little below and left.
    co = camera(sc, cam, (-0.01, 0.0, 0.66), lens=35, fstop=2.0,
                focus=(Vector(drive) - Vector(cam)).length)
    # The orange ROV tether hangs coiled on a hook on the wall, its
    # edge in the lower right of the frame.
    tether = ri.mat('tether', (0.75, 0.22, 0.03), rough=0.5)
    tx, ty, tz = on_wall(co, 0.95, -0.75, 0.37)
    for i in range(5):
        torus(0.17 - 0.006 * i, 0.007, (tx + 0.1, 0.37 - 0.012 * i,
                                        tz - 0.08),
              tether, rot=(math.radians(90), 0, math.radians(4 * i)))
    # The alarm clock stands on a crate of kit under the back of the
    # desk, turned away; its red-orange light lies on the wall at the
    # lower left (no digits).
    ax, ay, az = on_wall(co, -0.8, -0.85, 0.3)
    box((0.3, 0.24, az - 0.04), (ax - 0.05, 0.25, (az - 0.04) / 2), card,
        bevel=0.004)
    box((0.1, 0.05, 0.06), (ax, 0.27, az), black, bevel=0.006)
    panel((0.08, 0.04), (ax, 0.297, az), (math.radians(-90), 0, 0),
          0, 6.0, colour=(1.0, 0.18, 0.02))
    glowl = light('AREA', (ax, 0.33, az), 0.8, 2000, size=0.08,
                  aim=(ax, 0.5, az + 0.15))
    glowl.data.color = (1.0, 0.18, 0.02)


@scene
def harbor_of_ayas(sc):
    world(sc, kelvin(9000), 0.25)
    stone = ri.mat('limestone', (0.45, 0.42, 0.36), rough=0.85, bump=0.9,
                   scale=20, spots=(0.15, 0.22, 0.12))
    wetstone = ri.mat('wetlime', (0.20, 0.20, 0.17), rough=0.25,
                      bump=0.9, scale=20, spots=(0.06, 0.12, 0.07))
    oak = ri.mat('oak', (0.18, 0.12, 0.07), rough=0.7, bump=0.5,
                 scale=50)
    iron = ri.mat('iron', (0.08, 0.07, 0.06), rough=0.6, metal=0.8)
    hemp = laid_rope('hemp', (0.40, 0.32, 0.19))
    # The quay: dressed blocks of unequal length in four courses; the
    # course at the water is wet and dark (version 2 laid identical
    # slabs like a modern pavement).
    rnd = random.Random(1375)
    for j in range(4):
        x = -3.2 + rnd.uniform(0, 0.4)
        while x < 3.6:
            w = rnd.uniform(0.55, 1.15)
            dz = rnd.uniform(-0.012, 0.012)
            box((w - 0.015, 0.385, 0.4), (x + w / 2, -1.6 + 0.4 * j,
                                          -0.2 + dz),
                wetstone if j == 3 else stone, bevel=0.025)
            x += w
    water((0, 40, -0.35), 160, colour=(0.02, 0.05, 0.06))
    cyl(0.12, 0.5, (0.6, -1.0, 0.25), oak)
    for z in (0.1, 0.38):
        torus(0.122, 0.01, (0.6, -1.0, z), iron)
    # From the bollard across the stones to the edge (y = -0.2), over it
    # and into the water: laid in front of the bollard, in view.  A
    # rope of 5 cm, as the prompt says, not a hose of 9 cm.
    rope([(0.62, -1.13, 0.1), (0.5, -1.13, 0.025), (0.3, -1.05, 0.025),
          (0.05, -0.8, 0.025), (-0.15, -0.45, 0.025), (-0.22, -0.24, 0.025),
          (-0.25, -0.18, -0.05), (-0.27, -0.12, -0.3), (-0.4, 0.4, -0.37)],
         0.025, hemp)
    box((0.3, 1.6, 0.04), (-0.9, -0.2, 0.03), oak,
        rot=(0, math.radians(8), math.radians(20)))
    sack = pouch((-1.4, -0.95, 0.0), 0.2, 0.32,
                 ri.mat('canvas', (0.5, 0.45, 0.35), rough=0.9, bump=0.5,
                        scale=200), folds=7)
    sack.scale = (1.0, 0.85, 0.8)
    # The cog going away: a dark hull with castles fore and aft, one
    # mast and the sail furled down along it.  It sits on the horizon in
    # the upper third, a hundred metres off.
    dark = ri.mat('hull', (0.02, 0.02, 0.02), rough=0.8)
    cx, cy = -40.0, 90.0
    # The hull: long at the deck, short at the keel, with the raked
    # stem and stern of a cog, not a box.
    hv = []
    for z, half in ((-0.65, 4.0), (1.85, 7.0)):
        for y in (-2.0, 2.0):
            hv += [(cx - half, cy + y, z), (cx + half, cy + y, z)]
    me = bpy.data.meshes.new('hull')
    me.from_pydata(hv, [], [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1),
                            (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)])
    hull = bpy.data.objects.new('hull', me)
    bpy.context.collection.objects.link(hull)
    ri.link(hull, dark)
    box((3, 4, 1.6), (cx - 4.6, cy, 2.6), dark)
    box((2.2, 3.6, 1.2), (cx + 5.0, cy, 2.4), dark)
    cyl(0.25, 14, (cx, cy, 8), dark)
    # The sail is furled down along the mast, not on a yard across it:
    # a mast with a yard reads as a cross at this distance.
    cyl(0.9, 6, (cx + 0.4, cy, 6), dark)
    light('SUN', (0, 0, 10), 2.5, 2600, size=0.05,
          aim=(1.5, -9, 9.3))
    cam = camera(sc, (1.2, -1.9, 0.75), (-2.0, 5.0, -0.4), lens=35,
                 fstop=5.6, focus=1.6)
    # The small oil lantern on its post at the right of the frame,
    # 1900 K, not bright yet.
    lx, ly, lz = on_screen(cam, 0.55, 0.2, 5.0)
    lz = 1.18
    cyl(0.07, 1.6, (lx, ly, lz - 0.88), oak)
    horn = ri.mat('horn', (0.5, 0.4, 0.25), rough=0.4)
    horn.node_tree.nodes['Principled BSDF'].inputs[
        'Transmission Weight'].default_value = 0.7
    box((0.12, 0.12, 0.16), (lx, ly, lz), horn, bevel=0.01)
    glow((lx, ly, lz), 0.02, 1900, 25, stretch=1.6)
    light('POINT', (lx, ly, lz), 6, 1900, size=0.03)
    haze(0.004, (0.8, 0.7, 0.65), size=60, at=(0, 30, 5))
    exposure(sc, 0.4)


@scene
def purse_at_the_gate(sc):
    world(sc, (0.002, 0.002, 0.004))
    stone = ri.mat('stone', (0.30, 0.24, 0.18), rough=0.9, bump=1.0,
                   scale=18, spots=(0.08, 0.07, 0.06))
    leather = ri.mat('leather', (0.20, 0.12, 0.06), rough=0.6, bump=0.6,
                     scale=80)
    silver = ri.mat('silver', (0.85, 0.84, 0.8), rough=0.25, metal=1.0,
                    bump=0.25, scale=90)
    iron = ri.mat('iron', (0.05, 0.045, 0.04), rough=0.55, metal=0.9,
                  bump=0.4, scale=60)
    box((0.6, 0.4, 0.1), (0, 0, -0.05), stone, bevel=0.01)
    box((0.15, 0.6, 0.8), (-0.38, 0.1, 0.35), stone)
    box((0.9, 0.15, 0.8), (0, 0.28, 0.35), stone)
    # The right wall is pierced by an arrow slit 3 cm wide (y 0.005 to
    # 0.035): the moon comes through it as a thin stripe across the
    # sill, never the round theatre spot of version 2.
    box((0.15, 0.295, 0.8), (0.38, -0.1325, 0.35), stone)
    box((0.15, 0.365, 0.8), (0.38, 0.2175, 0.35), stone)
    light('AREA', (0.75, 0.02, 0.5), 30, 8000, size=0.04, size_y=0.5,
          aim=(0.0, 0.02, 0.0))
    pouch((-0.11, 0.08, 0.045), 0.05, 0.12, leather, folds=9,
          rot=(0, math.radians(84), math.radians(-15)))
    scatter_coins((0.06, 0.03, 0.0), 7, silver, seed=1375, spread=0.06)
    # The gate key lies on the edge of the stripe, untouched.
    kx, ky = 0.2, 0.045
    cyl(0.009, 0.11, (kx, ky, 0.009), iron,
        rot=(0, math.radians(90), math.radians(8)), verts=24)
    torus(0.022, 0.005, (kx - 0.075, ky - 0.01, 0.005), iron)
    box((0.02, 0.012, 0.03), (kx + 0.055, ky + 0.012, 0.012), iron)
    # The tallow stub at the left of the frame, 1900 K.
    cyl(0.012, 0.03, (-0.09, -0.03, 0.015), ri.mat('tallow',
        (0.8, 0.75, 0.6), rough=0.6), verts=24)
    flame((-0.09, -0.03, 0.031), 0.012, 0.003, 1900, 50)
    light('POINT', (-0.09, -0.03, 0.05), 1.2, 1900, size=0.005)
    exposure(sc, -0.3)
    haze(0.03, (0.6, 0.6, 0.6), size=1.5, at=(0, 0, 0.3))
    camera(sc, (0.12, -0.42, 0.36), (0.07, 0.03, 0.0), lens=45,
           fstop=4.0, focus=0.55)


@scene
def bread_in_siege(sc):
    world(sc, kelvin(6500), 0.3)
    exposure(sc, 0.4)
    stone = ri.mat('stone', (0.36, 0.34, 0.30), rough=0.9, bump=1.2,
                   scale=12, spots=(0.25, 0.24, 0.21))
    wool = ri.mat('greywool', (0.10, 0.095, 0.085), rough=1.0, bump=0.8,
                  scale=300)
    crust = ri.mat('crust', (0.22, 0.12, 0.05), rough=0.8, bump=1.4,
                   scale=40, spots=(0.12, 0.06, 0.025))
    crumb = ri.mat('crumb', (0.45, 0.33, 0.2), rough=0.95, bump=2.0,
                   scale=180, spots=(0.33, 0.23, 0.13))
    clay = ri.mat('clay', (0.36, 0.17, 0.08), rough=0.85, bump=0.4,
                  scale=60)
    box((3, 3, 0.1), (0, 0, -0.05), stone)
    # The parapet: a low wall to 0.3 m with merlons to 1.3 m; the
    # crenel between them (x 0.25 to 0.85) opens in the upper right.
    box((3, 0.4, 0.3), (0, 0.8, 0.15), stone, bevel=0.02)
    box((1.75, 0.42, 1.0), (-0.625, 0.8, 0.8), stone, bevel=0.02)
    box((0.65, 0.42, 1.0), (1.175, 0.8, 0.8), stone, bevel=0.02)
    # Mortar joints on the inner faces: courses of 0.3 m, the head
    # joints staggered, so the wall reads as laid stone, not plaster.
    joint = ri.mat('joint', (0.12, 0.11, 0.10), rough=1.0)
    for c, z in enumerate((0.3, 0.6, 0.9, 1.2)):
        # Above the low wall the bed joint stops at the crenel (x 0.25
        # to 0.85): a joint across the gap hung in the air as a black
        # line over the sky in the variants of the hour (TABOO 0.016).
        if z > 0.3:
            box((1.75, 0.01, 0.012), (-0.625, 0.585, z), joint)
            box((0.65, 0.01, 0.012), (1.175, 0.585, z), joint)
        else:
            box((3.0, 0.01, 0.012), (0, 0.585, z), joint)
        x = -1.5 + 0.22 * (c % 2)
        while x < 1.5:
            if z > 0.3 and 0.25 < x < 0.85:
                x += 0.45
                continue
            box((0.012, 0.01, 0.3), (x, 0.585, z - 0.15), joint)
            x += 0.45
    # Far below through the crenel: the gate yard, the gate tower and
    # the faint glint of silver by a torch at the gate.
    yard = ri.mat('yard', (0.30, 0.28, 0.25), rough=1.0, bump=0.5,
                  scale=2)
    box((120, 100, 0.2), (10, 70, -8.1), yard)
    box((8, 6, 10), (7, 58, -3), stone)
    box((3, 6.2, 4), (7, 58, -6), ri.mat('gateway', (0.02, 0.02, 0.02)))
    box((60, 3, 9), (0, 110, -3.5), stone)
    silver = ri.mat('silver', (0.9, 0.9, 0.86), rough=0.1, metal=1.0)
    for k, (dx, dy) in enumerate(((0, 0), (0.5, 0.2), (-0.4, 0.3))):
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.3 - 0.05 * k, location=(5.6 + dx, 53.0 + dy, -7.8))
        ri.link(ri.smooth(bpy.context.object, 0), silver)
    flame((6.2, 54.8, -6.0), 0.5, 0.12, 2000, 40)
    light('POINT', (5.8, 54.5, -6.2), 400, 2000, size=0.1)
    box((0.9, 0.6, 0.03), (0, 0.1, 0.015), wool, bevel=0.01)
    # One round flat loaf torn 60/40: the larger part is pushed 0.15 m
    # toward the empty place on the right, the smaller stays.
    for at, keep in (((-0.06, 0.08, 0.05), False),
                     ((0.17, 0.10, 0.05), True)):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.11, location=at)
        h = bpy.context.object
        h.scale = (1.0, 1.0, 0.38)
        ri.link(ri.smooth(h, 1), crust)
        halve(h, keep_x_positive=keep, gap=-0.022, inner=crumb)
    boulders(9, 0.06, (0.05, 0.08, 0.035), crumb, 5,
             scale=(0.006, 0.005, 0.004))
    cup = ri.lathe('cup', [(0.0, 0.0), (0.035, 0.0), (0.05, 0.09),
                           (0.046, 0.09), (0.032, 0.006), (0.0, 0.006)],
                   48)
    cup.location = (-0.35, 0.25, 0.03)
    ri.link(cup, clay)
    cup2 = ri.lathe('cup2', [(0.0, 0.0), (0.035, 0.0), (0.05, 0.09),
                             (0.046, 0.09), (0.032, 0.006), (0.0, 0.006)],
                    48)
    cup2.location = (0.42, 0.28, 0.05)
    cup2.rotation_euler = (math.radians(90), 0, math.radians(30))
    ri.link(cup2, clay)
    box((0.16, 0.035, 0.008), (-0.2, -0.08, 0.034),
        ri.mat('spoon', (0.4, 0.28, 0.15), rough=0.6),
        rot=(0, 0, math.radians(-20)), bevel=0.003)
    cyl(0.12, 0.15, (-1.0, 0.3, 0.075), ri.mat('brazier', (0.06, 0.05,
        0.04), rough=0.6, metal=0.7))
    glow((-1.0, 0.3, 0.16), 0.08, 2100, 4)
    light('POINT', (-1.0, 0.3, 0.3), 25, 2100, size=0.1)
    light('AREA', (1.5, -1.0, 3.0), 40, 6500, size=3, aim=(0, 0.2, 0))
    haze(0.01, (0.8, 0.8, 0.8), size=6, at=(0, 0, 1))
    cam = (0.3, -0.8, 0.6)
    camera(sc, cam, (0.08, 0.5, 0.42), lens=30, fstop=2.8,
           focus=(Vector((0.02, 0.09, 0.07)) - Vector(cam)).length)


@scene
def error_of_a_finger(sc):
    stars(sc, strength=6.0, milky=0.035)
    tar = ri.mat('tar', (0.04, 0.03, 0.02), rough=0.6, bump=0.5,
                 scale=30)
    brass = ri.mat('brass', (0.50, 0.40, 0.22), rough=0.35, metal=1.0,
                   bump=0.4, scale=80, spots=(0.3, 0.27, 0.18))
    engraved = ri.mat('engraved', (0.08, 0.06, 0.03), rough=0.6)
    hemp = ri.mat('hemp', (0.18, 0.13, 0.08), rough=0.85, bump=0.8,
                  scale=300)
    for x in (-0.55, 0.55):
        box((0.04, 2.4, 0.4), (x, 0, 0.2), tar,
            rot=(0, math.radians(-12 if x > 0 else 12), 0))
    box((1.0, 2.4, 0.03), (0, 0, 0.0), tar)
    for y in (-0.8, -0.3, 0.2, 0.7):
        box((1.1, 0.05, 0.05), (0, y, 0.03), tar)
    box((1.1, 0.25, 0.04), (0, 0.15, 0.35), tar)
    water((0, 0, -0.05), 1200, colour=(0.005, 0.01, 0.015), rough=0.08)
    water((0, 0, 0.02), 0.9, colour=(0.02, 0.02, 0.02), rough=0.02)
    # The astrolabe hangs by its ring from the thole, tipped by the
    # swell: mater, engraved tympan, rete with pointers, rule.
    astrolabe((0.05, 0.15, 0.48), (math.radians(70), math.radians(9), 0),
              brass, engraved)
    rope([(0.05, 0.19, 0.58), (0.3, 0.2, 0.75), (0.55, 0.2, 0.42)],
         0.003, ri.mat('thong', (0.15, 0.08, 0.04), rough=0.6))
    for i in range(3):
        torus(0.13 - 0.01 * i, 0.01, (-0.3, -0.4, 0.04 + 0.02 * i), hemp)
    cyl(0.02, 2.2, (0.48, 0, 0.42), tar, rot=(math.radians(90), 0, 0))
    cyl(0.04, 0.12, (-0.2, -0.75, 0.08), brass, verts=24)
    glow((-0.2, -0.75, 0.15), 0.015, 1900, 30)
    light('POINT', (-0.2, -0.75, 0.18), 8, 1900, size=0.02)
    light('SUN', (0, 0, 10), 0.35, 8000, size=0.3, aim=(-3, -5, 0))
    exposure(sc, 0.8)
    # The brothers' window: one small warm point at the foot of the far
    # range, 2000 K, and no streak on the water (it read as a candle
    # standing out of the lake).
    win = glow((-20, 405, 4.0), 0.15, 2000, 120)
    win.visible_glossy = False
    rock, _ = rock_mount_mats(snow=False)
    rock.node_tree.nodes['Principled BSDF'].inputs[
        'Base Color'].default_value = (0.0, 0.0, 0.0, 1)
    ridge('ridge', -900, 900, 410, 260, -0.05, 70, 1375, rock)
    haze(0.003, (0.6, 0.65, 0.8), size=40, at=(0, 15, 0.5))
    # f/8, not the prompt's f/2.8: at f/2.8 the stars and the far window
    # blur into discs and the sky goes empty.
    camera(sc, (0.16, -0.6, 0.66), (0.02, 0.6, 0.42), lens=30, fstop=8.0,
           focus=0.76)


def cell(sc, morning=False):
    """The copyist's cell of ink_first_line, shared with
    scribe_lifts_eyes (the same room in spring, window open)."""
    lime = ri.mat('lime', (0.42, 0.39, 0.33), rough=0.95, bump=1.2,
                  scale=25, spots=(0.30, 0.28, 0.24))
    walnut = ri.mat('walnut', (0.09, 0.05, 0.03), rough=0.55, bump=0.3,
                    scale=60)
    box((4, 4, 0.1), (0, 0, -0.05), lime)
    box((0.3, 4, 3), (-1.0, 0, 1.5), lime)
    box((0.3, 4, 3), (1.6, 0, 1.5), lime)
    box((4, 4, 0.1), (0, 0, 3.0), lime)
    box((1.0, 0.6, 0.05), (0, 0.15, 0.725), walnut, bevel=0.01)
    for x in (-0.45, 0.45):
        box((0.05, 0.5, 0.7), (x, 0.15, 0.35), walnut)
    return lime, walnut


@scene
def scribe_lifts_eyes(sc):
    world(sc, kelvin(9000), 0.8)
    lime, walnut = cell(sc, morning=True)
    vellum = ri.mat('vellum', (0.72, 0.64, 0.48), rough=0.9, bump=0.4,
                    scale=180, spots=(0.58, 0.50, 0.36))
    cover = ri.mat('board', (0.16, 0.08, 0.04), rough=0.6, bump=0.5,
                   scale=90)
    ink = ri.mat('ink', (0.05, 0.03, 0.02), rough=0.6)
    clay = ri.mat('clay', (0.32, 0.15, 0.07), rough=0.85, bump=0.6,
                  scale=60)
    # The back wall with an open window onto the lake (x -0.4..0.4,
    # z 0.9..1.8).
    box((1.6, 0.3, 3), (-1.2, 1.0, 1.5), lime)
    box((1.6, 0.3, 3), (1.2, 1.0, 1.5), lime)
    box((0.8, 0.3, 0.9), (0, 1.0, 0.45), lime)
    box((0.8, 0.3, 1.2), (0, 1.0, 2.4), lime)
    # Outside: the cell stands on a bluff 10 m over the water; a spring
    # meadow runs down to the shore, the lake lies from 40 m and the
    # range rises across it at 290-490 m, mirrored in still water.
    meadow = ri.mat('meadow', (0.16, 0.20, 0.08), rough=1.0, bump=0.6,
                    scale=3, spots=(0.22, 0.22, 0.10))
    box((600, 40, 0.2), (0, 21.2, -10.05), meadow)
    water((0, 170, -10.0), 260, colour=(0.03, 0.09, 0.12), rough=0.02,
          bump=0.02, stretch=(6.0, 1.0))
    rock, cap = rock_mount_mats()
    ridge('ridge', -900, 900, 290, 200, -10.0, 130, 7, rock, cap,
          snow_at=0.5)
    light('SUN', (0, 0, 10), 3.0, 5600, size=0.05, aim=(0.4, 1.0, 9.4))
    # The morning comes in through the opening as a soft area of 5600 K
    # onto the desk: the room is lit, not a black box.
    light('AREA', (0.0, 0.88, 1.35), 60, 5600, size=0.8,
          aim=(0.0, -0.3, 0.75))
    zl, zr = codex((0.0, 0.1, 0.77), vellum, cover)
    script_lines((-0.085, -0.01, 0), 0.13, 17, ink, step=0.013, zf=zl)
    # On the right leaf one line breaks off in the middle of a word
    # with a tiny blot where the pen stopped.
    end = script_lines((0.085, -0.01, 0), 0.12, 1, ink, step=0.013,
                       seed=9, zf=zr, last=0.45)
    cyl(0.0022, 0.0004, (end + 0.002, -0.01, zr(end) + 0.0005), ink,
        verts=16)
    pot = ri.lathe('inkpot', [(0.0, 0.0), (0.03, 0.0), (0.033, 0.03),
                              (0.025, 0.055), (0.018, 0.06),
                              (0.0, 0.058)], 64)
    pot.location = (0.25, 0.25, 0.75)
    ri.link(pot, clay)
    # The pen across the inkpot's lip, its tip dry and grey.
    cyl(0.0035, 0.2, (0.25, 0.18, 0.81), ri.mat('reed', (0.45, 0.36, 0.2),
        rough=0.6), rot=(math.radians(70), 0, math.radians(15)), verts=12)
    haze(0.0002, (0.8, 0.85, 0.9), dims=(1600, 500, 120), at=(0, 250, 40))
    exposure(sc, 0.5)
    # Behind the empty stool, past the leaf to the window: the leaf is
    # a soft foreground, the frame and the lake are sharp.
    camera(sc, (0.1, -0.35, 1.05), (0.0, 1.0, 0.98), lens=28, fstop=4.0,
           focus=3.0)


@scene
def same_comet(sc):
    vellum = ri.mat('vellum', (0.74, 0.66, 0.50), rough=0.9, bump=0.8,
                    scale=260, spots=(0.60, 0.52, 0.38))
    ink = ri.mat('ink', (0.04, 0.025, 0.015), rough=0.55)
    page((0, 0, 0), (0.3, 0.3), vellum)
    script_lines((-0.03, -0.11, 0.0003), 0.16, 30, ink, step=0.007,
                 fine=True)
    # The margin notes everywhere but beside the comet.
    script_lines((0.11, -0.11, 0.0003), 0.04, 12, ink, step=0.005, seed=3,
                 fine=True)
    script_lines((0.11, 0.035, 0.0003), 0.04, 10, ink, step=0.005, seed=4,
                 fine=True)
    # The comet: a round head ringed by eight short ticks and three
    # strands of tail spreading to the right, each strand a lock of fine
    # hair lines.  Never a star of rays (a star of five points reads as
    # a pentagram, on the dogmatic stop-list); version 3's first render
    # of three thick strands read as a beetle, so the strands are thin.
    hx, hy, z = 0.085, -0.01, 0.0004
    cyl(0.0035, 0.0004, (hx, hy, z), ink, verts=32)
    for k in range(8):
        a = math.radians(55 + 250 * k / 7)
        box((0.0012, 0.0005, 0.0003), (hx + 0.0058 * math.cos(a),
                                       hy + 0.0058 * math.sin(a), z), ink,
            rot=(0, 0, a))
    for s in (-1, 0, 1):
        for h in (-1, 0, 1):
            a = math.radians(-4 + 9 * s + 1.2 * h)
            n = 10 - abs(h) * 2
            for k in range(n):
                t = 0.0045 + 0.003 * k
                w = 0.0005 * (1.0 - k / (n + 1.0))
                box((0.0031, max(w, 0.0002), 0.0003),
                    (hx + t * math.cos(a), hy + t * math.sin(a), z), ink,
                    rot=(0, 0, a))
    light('POINT', (0.4, 0.0, 0.07), 3, 1900, size=0.02)
    world(sc, (0.003, 0.002, 0.001))
    exposure(sc, -0.2)
    camera(sc, (0.08, -0.10, 0.40), (0.085, -0.005, 0.0), lens=100,
           fstop=4.0, focus=0.41)


@scene
def bazaar_jug(sc):
    world(sc, kelvin(9000), 0.35)
    earth = ri.mat('earth', (0.35, 0.27, 0.18), rough=1.0, bump=0.8,
                   scale=20)
    poplar = ri.mat('poplar', (0.55, 0.45, 0.32), rough=0.8, bump=0.4,
                    scale=50)
    glaze = crackle('glaze', (0.06, 0.32, 0.30))
    terra = ri.mat('terracotta', (0.45, 0.20, 0.10), rough=0.85, bump=0.4,
                   scale=60)
    box((14, 14, 0.1), (0, 2, -0.05), earth)
    box((1.8, 0.7, 0.04), (0, 0.2, 0.78), poplar, bevel=0.005)
    for x in (-0.8, 0.8):
        box((0.05, 0.6, 0.76), (x, 0.2, 0.38), poplar)
    # The hero jug, 0.28 m, a thumb's dent pressed into the glaze low
    # on the side that faces the camera.
    face = math.atan2(-1.1, 0.45)
    j = jug('hero', glaze, 0.7, dent=(face, 0.06))
    j.location = (0.0, 0.0, 0.8)
    for i in range(8):
        k = 0.66 - 0.04 * i
        jj = jug('copy%d' % i, glaze if i % 2 else terra, k)
        jj.location = (-0.75 + 0.2 * i, 0.4, 0.8)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=0.05,
                                          location=(0.5, -0.05, 0.82))
    ri.link(ri.smooth(bpy.context.object, 1),
            ri.mat('wetclay', (0.25, 0.25, 0.24), rough=0.3, bump=0.5))
    box((0.12, 0.025, 0.006), (0.35, -0.08, 0.805), poplar,
        rot=(0, 0, math.radians(25)))
    # The awning: a roof of faded cotton and a valance of strips on the
    # sun's side, so the low 3500 K sun lays stripes over the table.
    cotton = ri.mat('cotton', (0.85, 0.82, 0.74), rough=0.9)
    for i in range(4):
        box((2.4, 0.18, 0.005), (0, -0.4 + 0.36 * i, 2.2), cotton)
    for x, y in ((-1.15, -0.45), (1.15, -0.45), (-1.15, 0.75),
                 (1.15, 0.75)):
        cyl(0.03, 2.2, (x, y, 1.1), poplar, verts=12)
    for i in range(7):
        box((0.005, 0.16, 1.3), (1.3, -0.6 + 0.3 * i, 1.6), cotton)
    light('SUN', (0, 0, 10), 4.0, 3500, size=0.03, aim=(-1.0, 0.2, 9.82))
    # Neighbouring stalls behind, in warm dust: tables, sacks, pots and
    # their own awnings.
    rnd = random.Random(1375)
    stripe = ri.mat('stripe', (0.55, 0.22, 0.12), rough=0.9)
    for s in range(4):
        sx, sy = -2.4 + 1.7 * s, 3.0 + 0.6 * (s % 2)
        box((1.4, 0.6, 0.04), (sx, sy, 0.78), poplar)
        for x in (-0.6, 0.6):
            box((0.05, 0.5, 0.76), (sx + x, sy, 0.38), poplar)
        for n in range(4):
            bpy.ops.mesh.primitive_ico_sphere_add(
                subdivisions=2, radius=0.12,
                location=(sx - 0.45 + 0.3 * n, sy, 0.92))
            ri.link(ri.smooth(bpy.context.object, 1),
                    terra if rnd.random() < 0.5 else ri.mat(
                        'sack', (0.5, 0.42, 0.3), rough=0.95, bump=0.5))
        box((1.6, 0.9, 0.005), (sx, sy, 2.1),
            stripe if s % 2 else cotton)
        for x in (-0.75, 0.75):
            cyl(0.03, 2.1, (sx + x, sy - 0.4, 1.05), poplar, verts=12)
    # Adobe walls of the market lane close the view: no flat sky.
    box((16, 0.5, 4.5), (0, 6.8, 2.25),
        ri.mat('adobe', (0.52, 0.40, 0.27), rough=1.0, bump=1.0,
               scale=6, spots=(0.45, 0.34, 0.22)))
    haze(0.025, (0.9, 0.8, 0.6), dims=(14, 10, 3), at=(0, 4, 1.5))
    camera(sc, (0.45, -1.1, 1.2), (0.0, 0.1, 0.9), lens=35, fstop=4.0,
           focus=(Vector((0.04, -0.11, 0.86))
                  - Vector((0.45, -1.1, 1.2))).length)


@scene
def ford_of_cold(sc):
    world(sc, kelvin(10000), 0.45)
    granite = rimed('granite', (0.35, 0.36, 0.38), bump=0.8)
    stone = ri.mat('granite_wet', (0.20, 0.21, 0.22), rough=0.35,
                   bump=0.8, scale=30)
    gravel = ri.mat('gravel', (0.30, 0.29, 0.27), rough=0.7, bump=1.5,
                    scale=90)
    foam = ri.mat('foam', (0.85, 0.88, 0.9), rough=0.9, bump=0.6,
                  scale=200)
    box((8, 12, 0.2), (0, 2, -0.7), gravel)
    # Stones in the stream: wet and dark below, foam on their downstream
    # side (the river runs toward +x).
    rocks = boulders(40, 2.2, (0, 1.6, -0.36), stone, 11,
                     scale=(0.25, 0.2, 0.13))
    rnd = random.Random(1375)
    for (x, y, z), w, h in rocks:
        if rnd.random() < 0.7:
            # Torn foam behind the stone: a few small flattened blobs
            # shrinking downstream (version 3's first render laid
            # straight white planks).
            for k in range(4):
                bpy.ops.mesh.primitive_ico_sphere_add(
                    subdivisions=2, radius=1,
                    location=(x + w * (1.1 + 0.55 * k),
                              y + rnd.uniform(-0.06, 0.06), -0.298))
                f = bpy.context.object
                f.scale = (w * (0.5 - 0.09 * k), w * (0.22 - 0.03 * k),
                           0.006)
                ri.link(ri.smooth(f, 1), foam)
    # The near bank: dry stones with rime on their tops.
    boulders(14, 0.6, (0, -0.45, -0.25), granite, 12,
             scale=(0.12, 0.1, 0.07))
    water((0, 2, -0.3), 12, colour=(0.10, 0.28, 0.30), rough=0.15,
          bump=0.6, scale=3)
    box((8, 3, 0.4), (0, 5.2, -0.4), gravel,
        rot=(math.radians(-4), 0, 0))
    # Fresh hoof prints full of water on the far bank, and a dropped
    # leather glove.
    mud = ri.mat('mud', (0.12, 0.10, 0.08), rough=0.8)
    print_m = ri.mat('print', (0.05, 0.08, 0.09), rough=0.02)

    def bank(y):
        # The top of the far bank, tilted 4 degrees toward the river.
        return -0.2 + (5.2 - y) * math.tan(math.radians(4))
    for i in range(4):
        px, py = -0.3 + 0.25 * i, 4.2 + 0.1 * (i % 2)
        cyl(0.075, 0.012, (px, py, bank(py) + 0.002), mud, verts=24)
        cyl(0.06, 0.012, (px, py, bank(py) + 0.006), print_m, verts=24)
    glove = ri.mat('glove', (0.30, 0.18, 0.09), rough=0.6, bump=0.5,
                   scale=60)
    gx, gy = 0.55, 4.05
    gz = bank(gy) + 0.009
    box((0.09, 0.1, 0.018), (gx, gy, gz), glove, bevel=0.008,
        rot=(0, 0, math.radians(20)))
    for k in range(4):
        a = math.radians(20)
        fx = gx + 0.07 * math.cos(a) - (k - 1.5) * 0.022 * math.sin(a)
        fy = gy + 0.07 * math.sin(a) + (k - 1.5) * 0.022 * math.cos(a)
        cyl(0.009, 0.06, (fx, fy, gz), glove,
            rot=(0, math.radians(90), a), verts=12)
    rope([(-2.0, 1.0, -0.28), (-1.2, 1.4, -0.29), (-0.6, 1.9, -0.28)],
         0.012, laid_rope('halter', (0.30, 0.22, 0.12), scale=40))
    water((0, 200, -0.6), 600, colour=(0.02, 0.06, 0.12), rough=0.05)
    rock, cap = rock_mount_mats()
    ridge('ridge', -700, 700, 420, 300, -0.6, 140, 21, rock, cap,
          snow_at=0.5)
    # First sun of 2800 K rises behind the range, 8 degrees up: the
    # slopes facing the ford stay in shadow and only the crests catch a
    # thin gold line; the range shades the whole valley.
    light('SUN', (0, 0, 10), 4.0, 2800, size=0.01,
          aim=(0.2, -1.0, 9.86))
    haze(0.012, (0.85, 0.9, 0.95), dims=(10, 10, 0.35), at=(0, 2, -0.12))
    exposure(sc, -0.3)
    camera(sc, (0.2, -1.2, 0.25), (0.0, 4.2, -0.25), lens=28, fstop=5.6,
           focus=5.4)


@scene
def hands_of_masons(sc):
    world(sc, kelvin(8000), 0.7)
    granite = ri.mat('granite', (0.28, 0.28, 0.27), rough=0.8, bump=1.5,
                     scale=25, spots=(0.18, 0.18, 0.18))
    sand = ri.mat('sandstone', (0.46, 0.36, 0.24), rough=0.9, bump=1.5,
                  scale=25, spots=(0.36, 0.28, 0.18))
    mortar = ri.mat('mortar', (0.66, 0.63, 0.56), rough=1.0, bump=1.5,
                    scale=60)
    dust = ri.mat('dust', (0.55, 0.48, 0.38), rough=1.0, bump=0.5,
                  scale=40)
    ash = ri.mat('ash', (0.55, 0.45, 0.32), rough=0.7)
    linen = ri.mat('linen', (0.9, 0.9, 0.86), rough=0.8)
    lead = ri.mat('lead', (0.25, 0.25, 0.27), rough=0.4, metal=0.8)
    wicker = ri.mat('wicker', (0.42, 0.32, 0.18), rough=0.9, bump=1.5,
                    scale=120)
    box((10, 10, 0.1), (0, 0, -0.05), dust)
    # A mortar core shows in the joints between the split stones.
    box((2.7, 0.3, 0.8), (0, 0, 0.4), mortar)
    rnd = random.Random(1375)
    top = 0.0
    for c in range(3):
        x = -1.5
        while x < 1.5:
            w = rnd.uniform(0.3, 0.5)
            hgt = rnd.uniform(0.24, 0.3)
            st = ashlar((w - 0.03, 0.44, hgt),
                        (x + w / 2, 0, 0.15 + 0.29 * c),
                        granite if rnd.random() < 0.6 else sand,
                        seed=rnd.randrange(1 << 30))
            if c == 2:
                bpy.context.view_layer.update()
                top = max(top, max((st.matrix_world @ v.co).z
                                   for v in st.data.vertices))
            x += w
    # The string runs 5 mm over the top course along the wall's face,
    # tied to two ash stakes driven into the ground.
    sy, sz = -0.22, top + 0.005
    for x in (-1.7, 1.7):
        cyl(0.018, sz + 0.25, (x, sy, (sz + 0.25) / 2 - 0.05), ash,
            verts=12)
    rope([(-1.7, sy, sz), (1.7, sy, sz)], 0.0015, linen)
    # A tripod of poles with the lead plumb bob hanging still.
    ax, ay, az = 0.9, 0.85, 1.35
    for k in range(3):
        a = math.radians(90 + 120 * k)
        fx, fy = ax + 0.45 * math.cos(a), ay + 0.45 * math.sin(a)
        mid = ((ax + fx) / 2, (ay + fy) / 2, az / 2)
        d = Vector((ax - fx, ay - fy, az))
        bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.015,
                                            depth=d.length, location=mid)
        leg = bpy.context.object
        leg.rotation_euler = d.to_track_quat('Z', 'Y').to_euler()
        ri.link(leg, ash)
    rope([(ax, ay, az), (ax, ay, 0.32)], 0.0008, linen)
    bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=0.022,
                                    radius2=0.004, depth=0.06,
                                    location=(ax, ay, 0.29),
                                    rotation=(math.radians(180), 0, 0))
    ri.link(bpy.context.object, lead)
    # The mallet and trowel on a flat stone, the basket of mortar.
    box((0.4, 0.3, 0.08), (0.4, -0.75, 0.04), granite, bevel=0.02)
    cyl(0.045, 0.14, (0.35, -0.75, 0.125), ash,
        rot=(0, math.radians(90), 0), verts=16)
    cyl(0.012, 0.28, (0.35, -0.6, 0.11), ash,
        rot=(math.radians(90), 0, 0), verts=10)
    box((0.12, 0.07, 0.003), (0.5, -0.8, 0.083),
        ri.mat('trowel', (0.15, 0.14, 0.13), rough=0.4, metal=0.9),
        rot=(0, 0, math.radians(30)))
    basket = ri.lathe('basket', [(0.0, 0.0), (0.14, 0.0), (0.2, 0.18),
                                 (0.19, 0.18), (0.13, 0.01), (0.0, 0.01)],
                      48)
    basket.location = (1.0, -0.8, 0.0)
    ri.link(basket, wicker)
    cyl(0.18, 0.02, (1.0, -0.8, 0.15), mortar, verts=32)
    # Bare footprints in the dust along the wall.
    foot = ri.mat('foot', (0.42, 0.36, 0.28), rough=1.0)
    for k in range(6):
        bpy.ops.mesh.primitive_circle_add(
            vertices=16, radius=0.06, fill_type='NGON',
            location=(-1.2 + 0.32 * k, -0.55 + 0.12 * (k % 2), 0.001))
        f = bpy.context.object
        f.scale = (1.0, 0.42, 1.0)
        ri.link(f, foot)
    water((0, 60, -0.5), 200, colour=(0.08, 0.20, 0.30), rough=0.02)
    light('SUN', (0, 0, 10), 3.0, 5500, size=0.02, aim=(0.5, 0.3, 9.1))
    exposure(sc, -1.0)
    # 85 mm along the string, so it runs away into the distance.
    cam = (-4.4, -1.6, 1.05)
    camera(sc, cam, (0.6, -0.1, 0.72), lens=85, fstop=4.0,
           focus=(Vector((-1.7, sy, sz)) - Vector(cam)).length)


@scene
def gate_opened_inside(sc):
    world(sc, (0.001, 0.001, 0.002))
    oak = ri.mat('oak', (0.14, 0.09, 0.05), rough=0.7, bump=0.6, scale=40)
    iron = ri.mat('iron', (0.05, 0.045, 0.04), rough=0.55, metal=0.9,
                  bump=0.4, scale=60)
    stone = ri.mat('stone', (0.28, 0.25, 0.21), rough=0.9, bump=1.0,
                   scale=12)
    silver = ri.mat('silver', (0.85, 0.84, 0.8), rough=0.25, metal=1.0)
    rag = ri.mat('rag', (0.06, 0.05, 0.04), rough=1.0, bump=1.0,
                 scale=200)
    box((6, 8, 0.1), (0, -2, -0.05), stone)
    box((0.4, 8, 4), (-1.6, -2, 2), stone)
    box((0.4, 8, 4), (1.6, -2, 2), stone)
    box((1.4, 0.15, 3.5), (-0.7, 0.6, 1.75), oak)
    box((1.4, 0.15, 3.5), (0.85, 0.75, 1.75), oak,
        rot=(0, 0, math.radians(-12)))
    for z in (0.6, 1.8, 3.0):
        box((1.4, 0.02, 0.08), (-0.7, 0.52, z), iron)
    # The empty staples where the bar lay.
    for x in (-1.2, -0.2):
        box((0.06, 0.08, 0.22), (x, 0.48, 1.2), iron)
    panel((0.25, 3.4), (0.13, 1.3, 1.75), (math.radians(90), 0, 0),
          11000, 1.2)
    light('AREA', (0.13, 1.5, 1.6), 600, 11000, size=0.06, size_y=1.6,
          aim=(0.05, -1.5, 0.0))
    # The oak bar, taken out of its staples and leaned on the wall.
    box((0.25, 0.25, 2.6), (-1.2, -0.2, 1.25), oak,
        rot=(math.radians(-10), 0, 0))
    # Silver spilt along the blue wedge on the flags, the empty purse.
    rnd = random.Random(1375)
    for i in range(9):
        coin((0.08 + rnd.uniform(-0.08, 0.1), -0.3 - 0.2 * i
              + rnd.uniform(-0.05, 0.05), 0.0006), 0.012, silver,
             rot=(0, 0, rnd.uniform(0, 6.28)))
    pouch((0.35, -0.75, 0.0), 0.05, 0.09,
          ri.mat('leather', (0.2, 0.12, 0.06), rough=0.6, bump=0.5,
                 scale=80), rot=(math.radians(-85), 0, math.radians(40)))
    # The torch in its iron bracket on the left wall: a wrapped shaft
    # and a flame at 2000 K (version 2 had a ball on a stick that read
    # as an electric sconce, and burned at the lampada's 1800 K).
    tx, ty, tz = -1.36, -0.2, 1.6
    torus(0.04, 0.008, (tx + 0.02, ty, tz), iron)
    box((0.1, 0.02, 0.02), (tx - 0.02, ty, tz), iron)
    cyl(0.032, 0.8, (tx + 0.03, ty, tz + 0.02), ri.mat(
        'shaft', (0.30, 0.20, 0.11), rough=0.7, bump=0.6, scale=40),
        rot=(0, math.radians(25), 0), verts=16)
    for k in range(4):
        torus(0.036, 0.012, (tx + 0.13 + 0.011 * k, ty,
                             tz + 0.30 + 0.024 * k), rag,
              rot=(0, math.radians(25), 0))
    # A ragged flame of three tongues, not the neat bulb of a sconce.
    for k, (dx, dy, hh) in enumerate(((0.0, 0.0, 0.24), (0.03, 0.02, 0.15),
                                      (-0.025, -0.015, 0.12))):
        flame((tx + 0.19 + dx, ty + dy, tz + 0.38), hh, 0.045 - 0.01 * k,
              2000, 25)
    light('POINT', (tx + 0.28, ty - 0.1, tz + 0.45), 70, 2000, size=0.08)
    haze(0.02, (0.6, 0.55, 0.5), size=6, at=(0, -2, 2))
    camera(sc, (-0.3, -3.2, 0.9), (0.0, 0.6, 0.85), lens=35, fstop=8.0)


def render(name, size, samples):
    sc = ri.reset()
    sc.cycles.samples = samples
    sc.render.resolution_x = size
    sc.render.resolution_y = size
    SCENES[name](sc)
    # JPEG, not PNG: six PNGs of 0.5 MB each broke the APK revisor's
    # budget for the exported sources (TABOO 0.011); a JPEG of 768 px at
    # quality 88 is about a fifth of that and reads the same in the veil.
    sc.render.image_settings.file_format = 'JPEG'
    sc.render.image_settings.quality = 88
    out = OUT / ('insight_%s.jpg' % name)
    sc.render.filepath = str(out)
    bpy.ops.render.render(write_still=True)
    print('rendered', out)


# Variants of the hour (docs/story/chorus-ep1/
# INSIGHT_VARIANTS_144_2026-10-03.md): the scene of the insight is built
# as above, then the recipe of the variant (scripts/prerender/
# insight_variants.py -> godot/data/pilot-insight-variants.json) moves
# its sun, sky, window light, fire and camera.  Frames go to
# build/insight_variants/, outside godot/, so none enters the APK.

VARIANT_OUT = ri.ROOT / 'build' / 'insight_variants'


def sky_light_colour(var):
    """The colour of the daylight coming through a window or a slit at
    the variant's hour."""
    el, slot = var['sun_elev'], var['slot']
    if slot == 'moon_night':
        return kelvin(7500)
    if slot == 'deep_night':
        return kelvin(9000)
    if el > 10:
        return kelvin(6500)
    if el > 0:
        return kelvin(var['light']['sun_k'] + 600)
    return kelvin(11000)


def towards(az, el, east):
    """The unit vector toward a body at compass bearing az and height
    el, in the world of a place whose east lies at angle east."""
    w = math.radians(east + 90.0 - az)
    e = math.radians(el)
    return Vector((math.cos(e) * math.cos(w), math.cos(e) * math.sin(w),
                   math.sin(e)))


def aim_light(lt, direction):
    lt.rotation_euler = (-direction).to_track_quat('-Z', 'Y').to_euler()


def set_world(sc, var):
    nt = sc.world.node_tree
    for n in list(nt.nodes):
        if n.type not in ('BACKGROUND', 'OUTPUT_WORLD'):
            nt.nodes.remove(n)
    bg = nt.nodes['Background']
    for ln in list(bg.inputs['Color'].links):
        nt.links.remove(ln)
    lt = var['light']
    bg.inputs['Color'].default_value = tuple(lt['sky_rgb']) + (1,)
    bg.inputs['Strength'].default_value = lt['sky_strength']
    if lt['stars']:
        stars(sc, strength=6.0 if var['slot'] == 'deep_night' else 3.0,
              base=tuple(lt['sky_rgb']),
              milky=0.03 if var['slot'] == 'deep_night' else 0.0)


def classify(place):
    """Split the scene's lights and emitters into sun, sky (window,
    moon through a slit, overcast fill), human fire and the rest
    (instrument screens, the alarm clock), by the Kelvin each carries."""
    out = {'sun': [], 'sky': [], 'fire': [], 'keep': []}
    for ob in bpy.data.objects:
        if ob.type != 'LIGHT':
            continue
        k = ob.get('k', 0)
        if ob.data.type == 'SUN':
            out['sun'].append(ob)
        elif FIRE_MIN_K <= k <= FIRE_MAX_K:
            out['fire' if place['fire'] else 'keep'].append(ob)
        elif k == 6500 and not place['fire']:
            out['keep'].append(ob)
        else:
            out['sky'].append(ob)
    mats = {'sky': [], 'fire': [], 'view': []}
    for m in bpy.data.materials:
        if not m.node_tree or 'Emission' not in m.node_tree.nodes:
            continue
        k = m.get('k', 0)
        if FIRE_MIN_K <= k <= FIRE_MAX_K:
            if place['fire']:
                mats['fire'].append(m)
        elif k == 0:
            if place['views']:
                mats['view'].append(m)
        elif not (k == 6500 and not place['fire']):
            mats['sky'].append(m)
    return out, mats


def scale_emit(m, gain, tint=None):
    e = m.node_tree.nodes['Emission']
    e.inputs['Strength'].default_value *= gain
    if tint is not None:
        c = e.inputs['Color'].default_value
        top = max(tint)
        e.inputs['Color'].default_value = (c[0] * tint[0] / top,
                                           c[1] * tint[1] / top,
                                           c[2] * tint[2] / top, 1)


def hits(sc, origin, direction, limit, skip_first):
    """The distance to the first solid surface from origin along
    direction, passing through haze and through the subject's own body
    near the aim point (the aim often sits on or in the subject)."""
    dg = bpy.context.evaluated_depsgraph_get()
    o = Vector(origin)
    travelled = 0.0
    while travelled < limit:
        ok, loc, nrm, _, ob, _ = sc.ray_cast(dg, o, direction,
                                             distance=limit - travelled)
        if not ok:
            return None
        step = (loc - o).length
        travelled += step
        # A face whose normal looks along the ray is the way out of a
        # body the aim sits in (the hands_of_masons aim is inside the
        # wall, and the ray ran 1 m along it to its end face): not an
        # obstacle between the subject and the camera.
        leaving = nrm.dot(direction) > 0.0
        if ob.get('haze') or leaving or travelled < skip_first:
            o = loc + direction * 1e-3
            travelled += 1e-3
            continue
        return travelled
    return None


def place_camera(sc, var, place):
    """Orbit the original camera around its subject by the variant's
    yaw and pitch, change the lens and the distance, roll it, and pull
    it in front of any wall the orbit would put it behind."""
    cam = sc.camera
    c = var['cam']
    aim = Vector(cam['aim'])
    loc0 = Vector(cam.location)
    fwd0 = cam.rotation_euler.to_matrix() @ Vector((0, 0, -1))
    focus_pt = aim
    if cam.data.dof.use_dof:
        focus_pt = loc0 + fwd0 * cam.data.dof.focus_distance
    v = loc0 - aim
    d0 = v.length
    az = math.atan2(v.y, v.x) + math.radians(c['orbit_yaw'])
    el = math.asin(max(-1.0, min(1.0, v.z / d0)))
    el = max(math.radians(-60), min(math.radians(80),
                                    el + math.radians(c['orbit_pitch'])))
    lens0 = cam.data.lens
    d = d0 * c['dist_k'] * (c['lens_mm'] / lens0) ** 0.6
    # If a stone or a wall stands between the subject and the camera,
    # first lift the camera by 3, 6 and 9 degrees to look over it (a
    # pulled-in camera ends up nose to the stone: ford_of_cold v08);
    # only if none is clear, pull it in front of the obstacle.
    # Last before pulling in, the reference view's own height and then
    # its own bearing, which are clear by construction (in
    # error_of_a_finger a low camera was pulled onto the astrolabe).
    pulled = False
    el0 = math.asin(max(-1.0, min(1.0, v.z / d0)))
    az0 = math.atan2(v.y, v.x)
    tries = [(az, min(math.radians(80), el + math.radians(lift)))
             for lift in (0.0, 3.0, 6.0, 9.0)] + [(az, el0), (az0, el0)]
    for a, e in tries:
        u = Vector((math.cos(e) * math.cos(a), math.cos(e) * math.sin(a),
                    math.sin(e)))
        h = hits(sc, aim, u, d, 0.2 * d0)
        if h is None or h >= d:
            break
    else:
        a, e = az, el
        u = Vector((math.cos(e) * math.cos(a), math.cos(e) * math.sin(a),
                    math.sin(e)))
        h = hits(sc, aim, u, d, 0.2 * d0)
        d = max(0.05, h - max(0.03, 0.04 * d))
        pulled = True
    loc = aim + u * d
    cam.location = loc
    cam.data.lens = c['lens_mm']
    q = (aim - loc).to_track_quat('-Z', 'Y')
    q = q @ Quaternion((0, 0, 1), math.radians(c['roll']))
    cam.rotation_euler = q.to_euler()
    if cam.data.dof.use_dof:
        cam.data.dof.focus_distance = max(0.05, (focus_pt - loc).length)
    f = (aim - loc).normalized()
    return {'pos': [round(x, 3) for x in loc],
            'yaw': round(math.degrees(math.atan2(f.y, f.x)), 1),
            'pitch': round(math.degrees(math.asin(f.z)), 1),
            'roll': c['roll'], 'lens_mm': c['lens_mm'],
            'lifted_deg': round(math.degrees(e - el), 1),
            'reference_bearing': a != az,
            'pulled_in': pulled}


def apply_variant(sc, var, place):
    lt = var['light']
    lights, mats = classify(place)
    set_world(sc, var)
    east = place['east']
    if place['kind'] == 'exterior':
        if not lights['sun']:
            lights['sun'].append(light('SUN', (0, 0, 10), 1.0, 5000,
                                       size=0.03))
        for s in lights['sun']:
            if lt['sun_w'] > 0:
                s.data.energy = lt['sun_w']
                s.data.color = kelvin(lt['sun_k'])
                s.data.angle = math.radians(0.6)
                aim_light(s, towards(var['sun_azim'], var['sun_elev'],
                                     east))
            elif var['moon']:
                mo = var['moon']
                s.data.energy = mo['w']
                s.data.color = kelvin(mo['k'])
                s.data.angle = math.radians(0.6)
                aim_light(s, towards(mo['azim'], mo['elev'], east))
            else:
                s.data.energy = 0.0
    gain = lt['sky_gain']
    tint = sky_light_colour(var)
    for ob in lights['sky']:
        ob.data.energy *= gain
        ob.data.color = tint
    for m in mats['sky'] + mats['view']:
        scale_emit(m, gain, tint if m in mats['sky'] else None)
    if lt['fire_k'] is not None:
        k = fire_k(lt['fire_k'])
        for ob in lights['fire']:
            ob.data.color = kelvin(k)
        for m in mats['fire']:
            m.node_tree.nodes['Emission'].inputs['Color'].default_value = \
                kelvin(k) + (1,)
    if lt.get('window'):
        w = lt['window']
        win = light('AREA', tuple(w['at']), w['energy'] * gain, 6500,
                    size=w['size'], aim=tuple(w['aim']))
        win.data.color = tint
    if lt.get('night_fire'):
        k = fire_k(lt['fire_k'])
        at = tuple(lt['night_fire_at'])
        h = lt['night_fire_h']
        flame(at, h, h * 0.35, k, 40.0)
        light('POINT', (at[0], at[1], at[2] + h * 0.6),
              lt['night_fire_w'], k, size=h * 0.3)
    return place_camera(sc, var, place)


def meter(sc, ev, target, tmp):
    """The gaffer's light meter: a 64 px, 8-sample frame at the given
    exposure; returns the mean display brightness 0..1."""
    keep = (sc.render.resolution_x, sc.cycles.samples,
            sc.cycles.use_denoising, sc.render.image_settings.file_format)
    sc.render.resolution_x = sc.render.resolution_y = 64
    sc.cycles.samples = 8
    sc.cycles.use_denoising = False
    sc.render.image_settings.file_format = 'PNG'
    sc.view_settings.exposure = ev
    sc.render.filepath = str(tmp)
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(str(tmp), check_existing=False)
    px = list(img.pixels)
    bpy.data.images.remove(img)
    n = len(px) // 4
    mean = sum(0.2126 * px[4 * i] + 0.7152 * px[4 * i + 1]
               + 0.0722 * px[4 * i + 2] for i in range(n)) / n
    (sc.render.resolution_x, sc.cycles.samples, sc.cycles.use_denoising,
     sc.render.image_settings.file_format) = keep
    sc.render.resolution_y = keep[0]
    return mean


def expose(sc, target, tmp):
    """Three steps of the meter toward the hour's target brightness;
    AgX bends the curve, so each step corrects about half the
    remaining distance in display terms times two in stops."""
    base = sc.view_settings.exposure
    ev = base
    for _ in range(3):
        m = max(1e-4, meter(sc, ev, target, tmp))
        step = 2.0 * math.log2(target / m)
        ev = max(base - 6.0, min(base + 9.0,
                                 ev + max(-4.0, min(4.0, step))))
        if abs(step) < 0.15:
            break
    sc.view_settings.exposure = ev
    return round(ev, 2), round(m, 3)


def render_variant(name, var, place, size, samples, force=False):
    import json
    import time
    out_dir = VARIANT_OUT / name
    out_dir.mkdir(parents=True, exist_ok=True)
    jpg = out_dir / ('v%02d.jpg' % var['v'])
    if jpg.exists() and not force:
        print('skip', jpg)
        return
    t0 = time.time()
    sc = ri.reset()
    SCENES[name](sc)
    cam = apply_variant(sc, var, place)
    sc.cycles.seed = var['seed']
    ev, mean = expose(sc, var['light']['exposure_target'],
                      out_dir / '_meter.png')
    sc.cycles.samples = samples
    sc.render.resolution_x = sc.render.resolution_y = size
    sc.cycles.use_denoising = True
    sc.render.image_settings.file_format = 'JPEG'
    sc.render.image_settings.quality = 85
    sc.render.filepath = str(jpg)
    bpy.ops.render.render(write_still=True)
    info = {'id': name, 'v': var['v'], 'slot': var['slot'], 'cam': cam,
            'exposure_ev': ev, 'meter_mean': mean,
            'seconds': round(time.time() - t0, 1), 'size': size,
            'samples': samples}
    (out_dir / ('v%02d.json' % var['v'])).write_text(
        json.dumps(info, ensure_ascii=False, indent=1), encoding='utf-8')
    print('rendered', jpg, info['seconds'], 's')


def main():
    only = ri.arg('--only', '')
    names = [n for n in SCENES if not only or n in only.split(',')]
    vfile = ri.arg('--variant-file', '')
    if vfile:
        import json
        data = json.loads(Path(vfile).read_text(encoding='utf-8'))
        pick = ri.arg('--variant', '')
        every = '--all-variants' in sys.argv
        if not pick and not every:
            raise SystemExit('give --variant N[,M] or --all-variants')
        want = {int(x) for x in pick.split(',')} if pick else None
        size = int(ri.arg('--size', 512))
        samples = int(ri.arg('--samples', 56))
        force = '--force' in sys.argv
        for n in names:
            place = dict(data['places'][n])
            place.update(PLACE_FLAGS[n])
            for var in data['variants'][n]:
                if want is None or var['v'] in want:
                    render_variant(n, var, place, size, samples, force)
        return
    for n in names:
        render(n, int(ri.arg('--size', 768)), int(ri.arg('--samples', 160)))


# What the recipe's places do not carry: whether the scene's 1900-2200
# K lights are human fire, and whether its flat emitters are views
# through a window (scripts/prerender/insight_variants.py, PLACES).
PLACE_FLAGS = {
    'ink_first_line': {'fire': True, 'views': True},
    'bazaar_jug': {'fire': True, 'views': False},
    'tape_at_night': {'fire': False, 'views': False},
    'ford_of_cold': {'fire': True, 'views': False},
    'hands_of_masons': {'fire': True, 'views': False},
    'harbor_of_ayas': {'fire': True, 'views': False},
    'purse_at_the_gate': {'fire': True, 'views': False},
    'gate_opened_inside': {'fire': True, 'views': False},
    'bread_in_siege': {'fire': True, 'views': False},
    'scribe_lifts_eyes': {'fire': True, 'views': False},
    'same_comet': {'fire': True, 'views': False},
    'error_of_a_finger': {'fire': True, 'views': False},
}


if __name__ == '__main__':
    main()
