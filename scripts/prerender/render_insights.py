"""Still frames of the insights (CLAUDE.md TABOO 0.021): one realistic
picture of the other epoch for each memory, built from the render
prompt the chorus of screenwriters wrote (docs/story/chorus-ep1/
INSIGHT_PROMPTS_2026-10-02.md).  Our Silicon Graphics again: Blender
4.5 LTS as a Python module, Cycles on the CPU, Open Image Denoise, seed
1375.  No human figure and no face: people are shown by their traces
(a pen just laid down, a broken loaf, a wet rope), as the prompts ask.

    /home/user/bpy-venv/bin/python scripts/prerender/render_insights.py \\
        [--only ink_first_line] [--samples 160] [--size 768]

The frames go to godot/art/prerender/insight_<id>.png; the scene shows
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

OUT = ri.ROOT / 'godot' / 'art' / 'prerender'


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
    return ri.link(ri.smooth(bpy.context.object, 0), m)


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


SCENES = {}


def scene(fn):
    SCENES[fn.__name__] = fn
    return fn


def render(name, size, samples):
    sc = ri.reset()
    sc.cycles.samples = samples
    sc.render.resolution_x = size
    sc.render.resolution_y = size
    SCENES[name](sc)
    out = OUT / ('insight_%s.png' % name)
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
