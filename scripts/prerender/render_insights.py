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

Constitution: ФОРМА (the place of the other epoch, its light and the
things people left) → ДЕЙСТВИЕ (render it once, exactly, offline) →
ЦЕЛЬ (the memory looks true, so the law it explains is believed).
"""

import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import render_items as ri  # noqa: E402

OUT = Path(ri.arg('--out', str(ri.ROOT / 'godot' / 'art' / 'prerender')))


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


def light(kind, loc, energy, k, size=0.2, aim=(0, 0, 0)):
    bpy.ops.object.light_add(type=kind, location=loc)
    lt = bpy.context.object
    lt.data.energy = energy
    lt.data.color = kelvin(k)
    if kind == 'AREA':
        lt.data.size = size
    elif kind in ('POINT', 'SPOT'):
        lt.data.shadow_soft_size = size
    d = Vector(aim) - lt.location
    lt.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    return lt


def camera(sc, loc, aim, lens=50, fstop=0.0, focus=None):
    cd = bpy.data.cameras.new('cam')
    cd.lens = lens
    if fstop:
        cd.dof.use_dof = True
        cd.dof.aperture_fstop = fstop
        cd.dof.focus_distance = focus or (Vector(aim) - Vector(loc)).length
    cam = bpy.data.objects.new('cam', cd)
    bpy.context.collection.objects.link(cam)
    cam.location = loc
    d = Vector(aim) - Vector(loc)
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    sc.camera = cam
    return cam


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


def world(sc, colour, strength=1.0):
    bg = sc.world.node_tree.nodes['Background']
    bg.inputs[0].default_value = colour + (1,)
    bg.inputs[1].default_value = strength


def haze(density, colour=(0.6, 0.6, 0.6), size=12.0, at=(0, 0, 1)):
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
    return box((size, size, size * 0.5), at, m)


def water(at, size, colour=(0.05, 0.12, 0.10), rough=0.04):
    m = ri.mat('water', colour, rough=rough, bump=0.15, scale=6)
    p = m.node_tree.nodes['Principled BSDF']
    p.inputs['Transmission Weight'].default_value = 0.9
    p.inputs['IOR'].default_value = 1.333
    bpy.ops.mesh.primitive_plane_add(size=size, location=at)
    return ri.link(bpy.context.object, m)


def stones(n, spread, at, m, seed, scale=(0.18, 0.13, 0.08)):
    """Rounded river stones placed by a fixed seed (no randomness at
    play time; the seed is part of the frame's recipe)."""
    import random
    rnd = random.Random(seed)
    for i in range(n):
        x = at[0] + rnd.uniform(-spread, spread)
        y = at[1] + rnd.uniform(-spread, spread)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1,
                                              location=(x, y, at[2]))
        s = bpy.context.object
        k = rnd.uniform(0.6, 1.3)
        s.scale = (scale[0] * k, scale[1] * k, scale[2] * k)
        s.rotation_euler = (0, 0, rnd.uniform(0, 3.14))
        ri.link(ri.smooth(s, 1), m)


def page(at, size, m, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_plane_add(size=1, location=at, rotation=rot)
    p = bpy.context.object
    p.scale = (size[0], size[1], 1)
    return ri.link(p, m)


def script_lines(at, width, rows, ink, step=0.012, seed=1375):
    """Illegible lines of script on a page: short dark strokes in rows,
    so the page reads as written without any readable word."""
    import random
    rnd = random.Random(seed)
    for r in range(rows):
        x = at[0] - width / 2
        y = at[1] + r * step
        while x < at[0] + width / 2 - 0.01:
            w = rnd.uniform(0.006, 0.02)
            box((w, 0.0016, 0.0003), (x + w / 2, y, at[2]), ink)
            x += w + rnd.uniform(0.002, 0.005)


def exposure(sc, ev):
    sc.view_settings.exposure = ev


def halve(ob, keep_x_positive=True, gap=0.0):
    """Cut a body in half along x by a boolean, as a loaf is torn."""
    bpy.ops.mesh.primitive_cube_add(size=2, location=(
        ob.location.x + (-1.0 if keep_x_positive else 1.0) + gap,
        ob.location.y, ob.location.z))
    cutter = bpy.context.object
    mod = ob.modifiers.new('cut', 'BOOLEAN')
    mod.operation = 'DIFFERENCE'
    mod.object = cutter
    cutter.hide_render = True
    return ob


SCENES = {}


def scene(fn):
    SCENES[fn.__name__] = fn
    return fn


def stars(sc, density=0.004, strength=2.0, base=(0.004, 0.006, 0.02)):
    """A night sky: deep indigo with stars from a fine Voronoi field,
    procedural (no photo, as the prompts ask)."""
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
    nt.links.new(mix.outputs['Result'], bg.inputs['Color'])


def glow(at, r, k, strength):
    m = bpy.data.materials.new('glow')
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.remove(nt.nodes['Principled BSDF'])
    e = nt.nodes.new('ShaderNodeEmission')
    e.inputs['Color'].default_value = kelvin(k) + (1,)
    e.inputs['Strength'].default_value = strength
    nt.links.new(e.outputs[0], nt.nodes['Material Output'].inputs[0])
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=at)
    return ri.link(ri.smooth(bpy.context.object, 0), m)


def panel(size, at, rot, k, strength):
    m = bpy.data.materials.new('panel')
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.remove(nt.nodes['Principled BSDF'])
    e = nt.nodes.new('ShaderNodeEmission')
    e.inputs['Color'].default_value = kelvin(k) + (1,)
    e.inputs['Strength'].default_value = strength
    nt.links.new(e.outputs[0], nt.nodes['Material Output'].inputs[0])
    bpy.ops.mesh.primitive_plane_add(size=1, location=at, rotation=rot)
    pl = bpy.context.object
    pl.scale = (size[0], size[1], 1)
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


def coins(at, n, silver, standing=True):
    for i in range(n):
        x = at[0] + 0.03 * (i % 4) - 0.04
        y = at[1] + 0.028 * (i // 4)
        cyl(0.011, 0.0012, (x, y, at[2] + 0.0006 + 0.0012 * (i % 2)),
            silver, rot=(math.radians(5 * (i % 3)), 0,
                         math.radians(41 * i)), verts=48)
    if standing:
        cyl(0.011, 0.0012, (at[0] + 0.07, at[1] - 0.02, at[2] + 0.011),
            silver, rot=(math.radians(84), 0, math.radians(20)), verts=48)


@scene
def ink_first_line(sc):
    lime = ri.mat('lime', (0.42, 0.39, 0.33), rough=0.95, bump=1.2,
                  scale=25, spots=(0.30, 0.28, 0.24))
    walnut = ri.mat('walnut', (0.09, 0.05, 0.03), rough=0.55, bump=0.3,
                    scale=60)
    vellum = ri.mat('vellum', (0.72, 0.64, 0.48), rough=0.9, bump=0.4,
                    scale=180, spots=(0.58, 0.50, 0.36))
    ink = ri.mat('ink', (0.05, 0.03, 0.02), rough=0.6)
    wet = ri.mat('wet', (0.04, 0.025, 0.015), rough=0.05, coat=1.0)
    clay = ri.mat('clay', (0.32, 0.15, 0.07), rough=0.85, bump=0.6,
                  scale=60)
    wool = ri.mat('wool', (0.18, 0.11, 0.07), rough=1.0, bump=0.8,
                  scale=300)
    box((4, 0.3, 3), (0, 1.0, 1.5), lime)
    box((0.3, 4, 3), (-1.0, 0, 1.5), lime)
    box((4, 4, 0.1), (0, 0, -0.05), lime)
    # The window in the left wall, its cold light and the lake far off.
    panel((0.4, 0.6), (-0.84, 0.25, 1.15), (0, math.radians(90), 0),
          7000, 3.0)
    light('AREA', (-0.7, 0.25, 1.15), 9, 7000, size=0.5,
          aim=(0.0, 0.1, 0.75))
    exposure(sc, -0.6)
    box((1.0, 0.6, 0.05), (0, 0.15, 0.725), walnut, bevel=0.01)
    for x in (-0.45, 0.45):
        box((0.05, 0.5, 0.7), (x, 0.15, 0.35), walnut)
    page((-0.085, 0.1, 0.756), (0.16, 0.24), vellum,
         rot=(0, math.radians(4), 0))
    page((0.085, 0.1, 0.756), (0.16, 0.24), vellum,
         rot=(0, math.radians(-4), 0))
    script_lines((-0.085, -0.01, 0.7575), 0.13, 17, ink, step=0.013)
    script_lines((0.085, -0.01, 0.7575), 0.12, 2, wet, step=0.013,
                 seed=7)
    # The pen lies along the right page, never across the gutter: a pen
    # over the fold reads as a cross.
    cyl(0.003, 0.2, (0.11, 0.08, 0.762), ri.mat('reed', (0.45, 0.36, 0.2),
        rough=0.6), rot=(math.radians(90), 0, math.radians(12)), verts=12)
    pot = ri.lathe('inkpot', [(0.0, 0.0), (0.03, 0.0), (0.033, 0.03),
                              (0.025, 0.055), (0.018, 0.06),
                              (0.0, 0.058)], 64)
    pot.location = (0.25, 0.25, 0.75)
    ri.link(pot, clay)
    lamp = ri.lathe('lamp', [(0.0, 0.0), (0.04, 0.0), (0.055, 0.02),
                             (0.03, 0.04), (0.0, 0.04)], 64)
    lamp.location = (-0.3, 0.3, 0.75)
    ri.link(lamp, clay)
    glow((-0.27, 0.3, 0.805), 0.008, 1900, 40.0)
    light('POINT', (-0.27, 0.3, 0.83), 3, 1900, size=0.01)
    box((0.35, 0.3, 0.06), (0.75, 0.6, 0.45), wool, bevel=0.03)
    haze(0.02, (0.7, 0.7, 0.75), size=3, at=(0, 0, 1))
    camera(sc, (0.32, -0.42, 1.08), (-0.05, 0.25, 0.8), lens=40,
           fstop=2.8, focus=0.62)


@scene
def tape_at_night(sc):
    world(sc, (0.002, 0.003, 0.006))
    birch = ri.mat('birch', (0.55, 0.42, 0.28), rough=0.7, bump=0.2,
                   scale=120)
    floor = ri.mat('laminate', (0.25, 0.18, 0.12), rough=0.4, bump=0.1,
                   scale=40)
    tape = ri.mat('tape', (0.80, 0.72, 0.55), rough=0.7, bump=0.2,
                  scale=300)
    black = ri.mat('usb', (0.02, 0.02, 0.02), rough=0.3, coat=0.4)
    box((1.2, 0.6, 0.025), (0, 0, 0.74), birch, bevel=0.002)
    for x in (-0.57, 0.57):
        box((0.03, 0.55, 0.73), (x, 0, 0.365), birch)
    box((4, 4, 0.02), (0, 0, -0.01), floor)
    box((0.05, 0.016, 0.008), (0.05, 0.05, 0.723), black, bevel=0.002)
    # Two parallel strips (crossed strips would read as a saltire).
    for y in (0.042, 0.058):
        box((0.12, 0.012, 0.0006), (0.05, y, 0.7185), tape)
    # The end of one strip curls down, not yet pressed.
    box((0.03, 0.012, 0.0006), (0.124, 0.058, 0.712), tape,
        rot=(0, math.radians(35), 0))
    bpy.ops.mesh.primitive_torus_add(major_radius=0.045,
                                     minor_radius=0.012,
                                     location=(0.1, -0.2, 0.012))
    ri.link(ri.smooth(bpy.context.object, 0), tape)
    box((0.3, 0.022, 0.0006), (-0.05, -0.2, 0.0005), tape,
        rot=(0, 0, math.radians(10)))
    mug = ri.lathe('mug', [(0.0, 0.0), (0.04, 0.0), (0.042, 0.1),
                           (0.038, 0.1), (0.036, 0.01), (0.0, 0.01)], 64)
    mug.location = (-0.3, -0.1, 0.0)
    ri.link(mug, ri.mat('mugp', (0.6, 0.6, 0.62), rough=0.3))
    for i in range(4):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.2 - 0.01 * i, minor_radius=0.008,
            location=(0.9, 0.5, 0.008 + 0.016 * i))
        ri.link(ri.smooth(bpy.context.object, 0),
                ri.mat('tether', (0.8, 0.25, 0.03), rough=0.5))
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
    glow((-0.5, 0.33, 0.78), 0.012, 1600, 30.0)
    # The screen's light falls on the floor in front and comes back up
    # under the desk, cold and weak: the only light on the tape.
    light('AREA', (0.0, -0.35, 0.02), 6, 6500, size=0.6,
          aim=(0.05, 0.05, 0.72))
    camera(sc, (-0.05, -0.3, 0.5), (0.06, 0.05, 0.72), lens=24,
           fstop=2.0, focus=0.42)


@scene
def harbor_of_ayas(sc):
    world(sc, kelvin(9000), 0.25)
    stone = ri.mat('limestone', (0.45, 0.42, 0.36), rough=0.85, bump=0.9,
                   scale=20, spots=(0.15, 0.22, 0.12))
    oak = ri.mat('oak', (0.18, 0.12, 0.07), rough=0.7, bump=0.5,
                 scale=50)
    iron = ri.mat('iron', (0.08, 0.07, 0.06), rough=0.6, metal=0.8)
    hemp = ri.mat('hemp', (0.40, 0.31, 0.18), rough=0.8, bump=0.8,
                  scale=400)
    for i in range(7):
        for j in range(4):
            box((0.79, 0.39, 0.4), (-2.4 + 0.8 * i + 0.4 * (j % 2),
                -1.6 + 0.4 * j, -0.2), stone, bevel=0.02)
    water((0, 40, -0.35), 80, colour=(0.02, 0.05, 0.06))
    cyl(0.12, 0.5, (0.3, -0.5, 0.25), oak)
    for z in (0.1, 0.38):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.122,
                                         minor_radius=0.01,
                                         location=(0.3, -0.5, z))
        ri.link(ri.smooth(bpy.context.object, 0), iron)
    # Off the bollard, along the stones to the edge (y = -0.2), over it
    # and into the water.
    rope([(0.3, -0.5, 0.36), (0.24, -0.46, 0.06), (0.12, -0.36, 0.03),
          (0.02, -0.26, 0.03), (-0.03, -0.19, -0.02), (-0.06, -0.15, -0.2),
          (-0.1, -0.08, -0.35), (-0.3, 0.5, -0.37)], 0.03, hemp)
    box((0.3, 1.6, 0.04), (-0.9, -0.2, 0.03), oak,
        rot=(0, math.radians(8), math.radians(20)))
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=0.2,
                                          location=(-1.4, -0.9, 0.15))
    sack = bpy.context.object
    sack.scale = (1.0, 0.8, 0.7)
    canvas = ri.mat('canvas', (0.5, 0.45, 0.35), rough=0.9, bump=0.5,
                    scale=200)
    ri.link(ri.smooth(sack, 1), canvas)
    # The cog far off: a dark hull, a mast and a furled sail.
    dark = ri.mat('hull', (0.02, 0.02, 0.02), rough=0.8)
    box((12, 4, 2.5), (-8, 300, 0.6), dark)
    cyl(0.25, 14, (-8, 300, 8), dark)
    # The sail is furled down along the mast, not on a yard across it:
    # a mast with a yard reads as a cross at this distance.
    cyl(0.9, 6, (-7.6, 300, 6), dark)
    light('SUN', (0, 0, 10), 2.5, 2600, size=0.05, aim=(0.2, -10, 9.3))
    glow((1.6, -0.9, 1.6), 0.03, 1900, 15)
    cyl(0.04, 1.6, (1.6, -0.9, 0.8), oak)
    haze(0.004, (0.8, 0.7, 0.65), size=60, at=(0, 30, 5))
    exposure(sc, 0.4)
    camera(sc, (1.3, -1.4, 0.8), (-0.2, 1.2, 0.0), lens=40, fstop=5.6,
           focus=1.6)


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
    box((0.15, 0.6, 0.8), (0.38, 0.1, 0.35), stone)
    box((0.9, 0.15, 0.8), (0, 0.28, 0.35), stone)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4, radius=0.06,
                                          location=(-0.02, 0.05, 0.03))
    purse = bpy.context.object
    purse.scale = (1.15, 0.9, 0.35)
    ri.link(ri.smooth(purse, 1), leather)
    rope([(-0.04, 0.08, 0.075), (-0.08, 0.0, 0.004), (-0.12, -0.06, 0.003)],
         0.002, ri.mat('cord', (0.3, 0.2, 0.1), rough=0.8))
    coins((0.04, -0.04, 0.0), 7, silver)
    cyl(0.012, 0.11, (0.22, 0.06, 0.012), iron,
        rot=(0, math.radians(90), math.radians(15)), verts=24)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.025,
                                     minor_radius=0.006,
                                     location=(0.15, 0.04, 0.006))
    ri.link(ri.smooth(bpy.context.object, 0), iron)
    box((0.02, 0.012, 0.03), (0.28, 0.08, 0.015), iron)
    cyl(0.012, 0.03, (-0.22, -0.05, 0.015), ri.mat('tallow',
        (0.8, 0.75, 0.6), rough=0.6), verts=24)
    glow((-0.22, -0.05, 0.045), 0.005, 1850, 60)
    light('POINT', (-0.22, -0.05, 0.06), 2.5, 1850, size=0.005)
    light('SPOT', (0.9, 0.06, 0.2), 120, 8000, size=0.01,
          aim=(0.2, 0.06, 0.0)).data.spot_size = math.radians(5)
    exposure(sc, -0.3)
    haze(0.03, (0.6, 0.6, 0.6), size=1.5, at=(0, 0, 0.3))
    camera(sc, (0.12, -0.42, 0.36), (0.1, 0.03, 0.0), lens=45,
           fstop=4.0, focus=0.55)


@scene
def bread_in_siege(sc):
    world(sc, kelvin(6500), 0.05)
    exposure(sc, -0.3)
    stone = ri.mat('stone', (0.36, 0.34, 0.30), rough=0.9, bump=1.2,
                   scale=12, spots=(0.25, 0.24, 0.21))
    wool = ri.mat('greywool', (0.10, 0.095, 0.085), rough=1.0, bump=0.8,
                  scale=300)
    crust = ri.mat('crust', (0.22, 0.12, 0.05), rough=0.8, bump=1.2,
                   scale=40)
    crumb = ri.mat('crumb', (0.45, 0.33, 0.2), rough=0.95, bump=1.5,
                   scale=120)
    clay = ri.mat('clay', (0.36, 0.17, 0.08), rough=0.85, bump=0.4,
                  scale=60)
    box((3, 3, 0.1), (0, 0, -0.05), stone)
    box((3, 0.4, 1.0), (0, 0.8, 0.5), stone, bevel=0.02)
    box((0.5, 0.42, 0.4), (0.6, 0.8, 1.2), stone)
    box((0.5, 0.42, 0.4), (-0.6, 0.8, 1.2), stone)
    box((0.9, 0.6, 0.03), (0, 0.1, 0.015), wool, bevel=0.01)
    # One round loaf torn into two unequal halves; the larger is pushed
    # toward the empty place.
    for at, keep, gap in (((-0.06, 0.05, 0.05), False, -0.02),
                          ((0.13, 0.12, 0.05), True, 0.03)):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.11, location=at)
        h = bpy.context.object
        h.scale = (1.0, 1.0, 0.38)
        ri.link(ri.smooth(h, 1), crust)
        h.data.materials.append(crumb)
        halve(h, keep_x_positive=keep, gap=gap)
    stones(9, 0.08, (0.02, 0.07, 0.035), crumb, 5,
           scale=(0.006, 0.005, 0.004))
    cup = ri.lathe('cup', [(0.0, 0.0), (0.035, 0.0), (0.05, 0.09),
                           (0.046, 0.09), (0.032, 0.006), (0.0, 0.006)],
                   48)
    cup.location = (-0.35, 0.25, 0.03)
    ri.link(cup, clay)
    cup2 = ri.lathe('cup2', [(0.0, 0.0), (0.035, 0.0), (0.05, 0.09),
                             (0.046, 0.09), (0.032, 0.006), (0.0, 0.006)],
                    48)
    cup2.location = (0.4, 0.25, 0.05)
    cup2.rotation_euler = (math.radians(90), 0, math.radians(30))
    ri.link(cup2, clay)
    cyl(0.12, 0.15, (-1.0, 0.3, 0.075), ri.mat('brazier', (0.06, 0.05,
        0.04), rough=0.6, metal=0.7))
    glow((-1.0, 0.3, 0.16), 0.08, 1700, 4)
    light('AREA', (1.5, -1.0, 3.0), 40, 6500, size=3, aim=(0, 0.2, 0))
    haze(0.01, (0.8, 0.8, 0.8), size=6, at=(0, 0, 1))
    camera(sc, (0.3, -0.7, 0.55), (0.0, 0.45, 0.4), lens=32,
           fstop=2.8, focus=0.75)


@scene
def error_of_a_finger(sc):
    stars(sc)
    tar = ri.mat('tar', (0.04, 0.03, 0.02), rough=0.6, bump=0.5,
                 scale=30)
    brass = ri.mat('brass', (0.55, 0.40, 0.18), rough=0.55, metal=1.0,
                   bump=0.6, scale=80, spots=(0.2, 0.3, 0.22))
    hemp = ri.mat('hemp', (0.30, 0.24, 0.15), rough=0.85, bump=0.8,
                  scale=300)
    for x in (-0.55, 0.55):
        box((0.04, 2.4, 0.4), (x, 0, 0.2), tar,
            rot=(0, math.radians(-12 if x > 0 else 12), 0))
    box((1.0, 2.4, 0.03), (0, 0, 0.0), tar)
    for y in (-0.8, -0.3, 0.2, 0.7):
        box((1.1, 0.05, 0.05), (0, y, 0.03), tar)
    box((1.1, 0.25, 0.04), (0, 0.15, 0.35), tar)
    water((0, 0, -0.05), 400, colour=(0.005, 0.01, 0.015), rough=0.08)
    water((0, 0, 0.02), 0.9, colour=(0.02, 0.02, 0.02), rough=0.02)
    cyl(0.09, 0.005, (0.05, 0.15, 0.48), brass,
        rot=(math.radians(70), math.radians(9), 0), verts=96)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.09,
                                     minor_radius=0.005,
                                     location=(0.05, 0.15, 0.48),
                                     rotation=(math.radians(70),
                                               math.radians(9), 0))
    ri.link(ri.smooth(bpy.context.object, 0), brass)
    box((0.15, 0.003, 0.01), (0.05, 0.146, 0.48), brass,
        rot=(math.radians(80), math.radians(30), 0))
    rope([(0.05, 0.15, 0.57), (0.3, 0.2, 0.75), (0.55, 0.2, 0.42)],
         0.003, ri.mat('thong', (0.15, 0.08, 0.04), rough=0.6))
    for i in range(3):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.13 - 0.01 * i,
                                         minor_radius=0.01,
                                         location=(-0.3, -0.4,
                                                   0.04 + 0.02 * i))
        ri.link(ri.smooth(bpy.context.object, 0), hemp)
    cyl(0.02, 2.2, (0.48, 0, 0.42), tar, rot=(math.radians(90), 0, 0))
    cyl(0.04, 0.12, (-0.2, -0.75, 0.08), brass, verts=24)
    glow((-0.2, -0.75, 0.15), 0.015, 1900, 30)
    light('POINT', (-0.2, -0.75, 0.18), 8, 1900, size=0.02)
    light('SUN', (0, 0, 10), 0.35, 8000, size=0.3, aim=(-3, -5, 0))
    exposure(sc, 0.8)
    glow((-20, 400, 0.5), 0.6, 1800, 60)
    import random
    rnd = random.Random(1375)
    ridge = [(-600 + 40 * i, 500, rnd.uniform(15, 60)) for i in range(31)]
    verts = [(x, y, 0.0) for x, y, _ in ridge]
    verts += [(x, y, z) for x, y, z in ridge]
    n = len(ridge)
    faces = [(i, i + 1, n + i + 1, n + i) for i in range(n - 1)]
    me = bpy.data.meshes.new('ridge')
    me.from_pydata(verts, [], faces)
    ob = bpy.data.objects.new('ridge', me)
    bpy.context.collection.objects.link(ob)
    ri.link(ob, ri.mat('mount', (0.0, 0.0, 0.0), rough=1.0))
    haze(0.003, (0.6, 0.65, 0.8), size=40, at=(0, 15, 0.5))
    camera(sc, (0.2, -1.15, 0.7), (0.0, 0.6, 0.4), lens=30, fstop=2.8,
           focus=1.3)


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


def main():
    only = ri.arg('--only', '')
    names = [n for n in SCENES if not only or n in only.split(',')]
    for n in names:
        render(n, int(ri.arg('--size', 768)), int(ri.arg('--samples', 160)))


if __name__ == '__main__':
    main()
