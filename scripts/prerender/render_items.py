"""Close-up stills for the swap on examine (docs/HLD_SWAP_RENDERING_
2026-10-02.md): our Silicon Graphics is Blender 4.5 LTS as a Python
module (bpy), Cycles on the CPU, 256 samples, Open Image Denoise, a fixed
seed (scripts/decisions/prerender_choice.py chose it from 864).

Each thing is built here at full detail (the amphora is turned on a
lathe of 128 segments, the codex has raised bands and a clasp) for the
picture only; the headset keeps its low proxy and gets one 768 px PNG.

    /home/user/bpy-venv/bin/python scripts/prerender/render_items.py \
        [--only amphora] [--samples 256] [--size 768]

Constitution: ФОРМА (the thing as it is, in true light) → ДЕЙСТВИЕ
(render it once, exactly, offline) → ЦЕЛЬ (where the eye looks closely,
it finds truth, and the headset carries no renderer).
"""

import math
import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'godot' / 'art' / 'prerender'
SEED = 1375
ITEMS = ('amphora', 'souvenir', 'drams', 'logbook', 'diary', 'glasses',
         'backup', 'echomug', 'echobook', 'echocoil', 'astrolabe',
         'shield')
# The pack of the examine videos: sources only, never in the APK.
PACK = ROOT / 'godot' / 'packs' / 'closeups-ep1' / 'closeups'


def arg(name, default):
    if name in sys.argv:
        return sys.argv[sys.argv.index(name) + 1]
    return default


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = int(arg('--samples', 256))
    sc.cycles.seed = SEED
    sc.cycles.use_denoising = True
    sc.cycles.denoiser = 'OPENIMAGEDENOISE'
    sc.cycles.max_bounces = 8
    size = int(arg('--size', 768))
    sc.render.resolution_x = size
    sc.render.resolution_y = size
    sc.render.film_transparent = False
    sc.view_settings.view_transform = 'AgX'
    sc.view_settings.look = 'AgX - Medium High Contrast'
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGB'
    sc.render.image_settings.color_depth = '8'
    world = bpy.data.worlds.new('World')
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes['Background']
    bg.inputs[0].default_value = (0.012, 0.010, 0.008, 1)
    bg.inputs[1].default_value = 1.0
    return sc


def mat(name, base, rough=0.5, metal=0.0, coat=0.0, bump=0.0,
        scale=40.0, spots=None):
    """A principled material; bump and spots are procedural noise, so
    the clay has pores and the silver its tarnish."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes['Principled BSDF']
    p.inputs['Base Color'].default_value = base + (1,)
    p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metal
    p.inputs['Coat Weight'].default_value = coat
    if bump or spots:
        tex = nt.nodes.new('ShaderNodeTexNoise')
        tex.inputs['Scale'].default_value = scale
        tex.inputs['Detail'].default_value = 12.0
        tex.inputs['Roughness'].default_value = 0.65
        if bump:
            b = nt.nodes.new('ShaderNodeBump')
            b.inputs['Strength'].default_value = bump
            b.inputs['Distance'].default_value = 0.002
            nt.links.new(tex.outputs['Fac'], b.inputs['Height'])
            nt.links.new(b.outputs['Normal'], p.inputs['Normal'])
        if spots:
            ramp = nt.nodes.new('ShaderNodeValToRGB')
            ramp.color_ramp.elements[0].position = 0.45
            ramp.color_ramp.elements[0].color = base + (1,)
            ramp.color_ramp.elements[1].position = 0.75
            ramp.color_ramp.elements[1].color = spots + (1,)
            nt.links.new(tex.outputs['Fac'], ramp.inputs['Fac'])
            nt.links.new(ramp.outputs['Color'], p.inputs['Base Color'])
    return m


def link(ob, m):
    ob.data.materials.append(m)
    return ob


def smooth(ob, subdiv=2):
    for p in ob.data.polygons:
        p.use_smooth = True
    if subdiv:
        mod = ob.modifiers.new('sub', 'SUBSURF')
        mod.levels = subdiv
        mod.render_levels = subdiv
    return ob


def lathe(name, profile, segments=128):
    """A body of revolution from (radius, height) points, metres."""
    verts, faces = [], []
    n = len(profile)
    for s in range(segments):
        a = 2 * math.pi * s / segments
        for r, z in profile:
            verts.append((r * math.cos(a), r * math.sin(a), z))
    for s in range(segments):
        t = (s + 1) % segments
        for i in range(n - 1):
            faces.append((s * n + i, t * n + i, t * n + i + 1,
                          s * n + i + 1))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return smooth(ob, 1)


def handle(name, side, r0, z0, r1, z1, out, thick=0.014):
    """A strap handle from the neck (r0, z0) to the shoulder (r1, z1):
    a bent tube whose ends sink a little into the clay, so it is fixed
    to the body and not hanging beside it."""
    curve = bpy.data.curves.new(name, 'CURVE')
    curve.dimensions = '3D'
    curve.bevel_depth = thick
    curve.bevel_resolution = 6
    curve.use_fill_caps = True
    sp = curve.splines.new('BEZIER')
    sp.bezier_points.add(3)
    pts = [(side * (r0 - 2.2 * thick), 0, z0 - 0.02),
           (side * (r0 + 0.012), 0, z0 - 0.015),
           (side * (r1 + out), 0, z0 + 0.02),
           (side * (r1 - thick), 0, z1)]
    for bp, co in zip(sp.bezier_points, pts):
        bp.co = co
        bp.handle_left_type = bp.handle_right_type = 'AUTO'
    ob = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(ob)
    return ob


AMPHORA = [(0.0, 0.0), (0.035, 0.0), (0.05, 0.03), (0.09, 0.09),
           (0.14, 0.2), (0.165, 0.32), (0.16, 0.42), (0.12, 0.5),
           (0.065, 0.55), (0.05, 0.6), (0.048, 0.68), (0.06, 0.7),
           (0.062, 0.72), (0.045, 0.72)]


def amphora(glaze):
    body = lathe('amphora', AMPHORA)
    for side in (1, -1):
        h = handle('handle', side, 0.05, 0.66, 0.15, 0.44, 0.05)
        h.data.materials.append(glaze)
        # The handles belong to the body: scaled and turned with it.
        h.parent = body
    return link(body, glaze)


def studio(sc, target_h, dist, look_z, yaw=0.6, pitch=0.25):
    # A sweep of dark linen behind and under the thing.
    bpy.ops.mesh.primitive_plane_add(size=6, location=(0, 0, 0))
    floor = bpy.context.object
    link(floor, mat('linen', (0.035, 0.03, 0.025), rough=0.9, bump=0.3,
                    scale=200))
    bpy.ops.mesh.primitive_plane_add(size=6, location=(0, 1.6, 1.5),
                                     rotation=(math.radians(90), 0, 0))
    link(bpy.context.object, mat('wall', (0.03, 0.025, 0.02), rough=1.0))
    # Key: a soft warm area light, the working light of a lamp (2500 K
    # class); rim: a cool narrow light behind, the instrument's.
    for name, loc, energy, size, col in (
            ('key', (-1.2, -1.2, 1.6), 90, 0.9, (1.0, 0.82, 0.62)),
            ('fill', (1.4, -0.8, 0.6), 14, 1.5, (0.9, 0.9, 1.0)),
            ('rim', (0.6, 1.1, 1.3), 70, 0.4, (0.75, 0.85, 1.0))):
        bpy.ops.object.light_add(type='AREA', location=loc)
        lt = bpy.context.object
        lt.data.energy = energy * target_h
        lt.data.size = size
        lt.data.color = col
        d = -lt.location
        lt.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    cam_d = bpy.data.cameras.new('cam')
    cam_d.lens = 85
    cam = bpy.data.objects.new('cam', cam_d)
    bpy.context.collection.objects.link(cam)
    cam.location = (math.sin(yaw) * dist * math.cos(pitch),
                    -math.cos(yaw) * dist * math.cos(pitch),
                    look_z + math.sin(pitch) * dist)
    from mathutils import Vector
    d = Vector((0, 0, look_z)) - cam.location
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    sc.camera = cam


def build(item, sc):
    if item == 'amphora':
        clay = mat('clay', (0.30, 0.12, 0.05), rough=0.85, bump=0.6,
                   scale=60, spots=(0.20, 0.18, 0.14))
        a = amphora(clay)
        a.rotation_euler = (0, math.radians(8), 0)
        studio(sc, 0.72, 2.2, 0.36)
    elif item == 'souvenir':
        glaze = mat('glaze', (0.06, 0.26, 0.22), rough=0.12, coat=0.8,
                    bump=0.05, scale=30)
        a = amphora(glaze)
        a.scale = (0.4, 0.4, 0.4)
        studio(sc, 0.29, 0.95, 0.15, yaw=-0.5)
    elif item == 'drams':
        silver = mat('silver', (0.85, 0.84, 0.80), rough=0.28, metal=1.0,
                     bump=0.25, scale=90, spots=(0.40, 0.38, 0.33))
        for i in range(7):
            x = 0.05 * (i % 4) - 0.075
            y = 0.05 * (i // 4) - 0.02
            bpy.ops.mesh.primitive_cylinder_add(
                vertices=96, radius=0.019, depth=0.0018,
                location=(x, y, 0.0009 + 0.0016 * (i % 3)),
                rotation=(math.radians(4 * (i % 3)), 0,
                          math.radians(37 * i)))
            coin = link(smooth(bpy.context.object, 0), silver)
            bev = coin.modifiers.new('bev', 'BEVEL')
            bev.width = 0.0005
            bev.segments = 3
            bpy.ops.mesh.primitive_torus_add(
                major_radius=0.016, minor_radius=0.0006,
                location=(x, y, 0.0019 + 0.0016 * (i % 3)))
            link(smooth(bpy.context.object, 0), silver)
        studio(sc, 0.08, 0.42, 0.0, yaw=0.3, pitch=0.75)
    elif item == 'logbook':
        leather = mat('cover', (0.10, 0.06, 0.04), rough=0.6, bump=0.4,
                      scale=120)
        paper = mat('paper', (0.82, 0.78, 0.68), rough=0.9, bump=0.2,
                    scale=400)
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.0125))
        cover = bpy.context.object
        cover.scale = (0.17, 0.24, 0.025)
        link(cover, leather)
        bev = cover.modifiers.new('bev', 'BEVEL')
        bev.width = 0.004
        bev.segments = 4
        bpy.ops.mesh.primitive_cube_add(size=1,
                                        location=(0.004, 0, 0.0125))
        pages = bpy.context.object
        pages.scale = (0.165, 0.232, 0.021)
        link(pages, paper)
        bpy.ops.mesh.primitive_cube_add(size=1,
                                        location=(0.06, 0, 0.0125))
        band = bpy.context.object
        band.scale = (0.008, 0.245, 0.027)
        link(band, mat('band', (0.05, 0.05, 0.06), rough=0.4))
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=6, radius=0.004, depth=0.18,
            location=(-0.11, 0.0, 0.004), rotation=(math.radians(90), 0,
                                                    math.radians(8)))
        link(bpy.context.object, mat('pencil', (0.75, 0.55, 0.12),
                                     rough=0.5))
        studio(sc, 0.25, 0.85, 0.01, yaw=0.4, pitch=0.85)
    elif item == 'diary':
        hide = mat('hide', (0.16, 0.09, 0.05), rough=0.75, bump=1.0,
                   scale=35, spots=(0.07, 0.05, 0.035))
        vellum = mat('vellum', (0.62, 0.55, 0.40), rough=0.95, bump=0.6,
                     scale=250, spots=(0.45, 0.38, 0.26))
        brass = mat('brass', (0.55, 0.40, 0.18), rough=0.35, metal=1.0,
                    bump=0.3, scale=80, spots=(0.20, 0.30, 0.22))
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.035))
        board = bpy.context.object
        board.scale = (0.2, 0.27, 0.07)
        link(board, hide)
        bev = board.modifiers.new('bev', 'BEVEL')
        bev.width = 0.008
        bev.segments = 5
        bpy.ops.mesh.primitive_cube_add(size=1,
                                        location=(0.006, 0, 0.035))
        block = bpy.context.object
        block.scale = (0.196, 0.262, 0.058)
        link(block, vellum)
        for i in range(4):
            bpy.ops.mesh.primitive_cylinder_add(
                vertices=48, radius=0.006, depth=0.075,
                location=(-0.1, -0.09 + 0.06 * i, 0.035))
            link(smooth(bpy.context.object, 0), hide)
        bpy.ops.mesh.primitive_cube_add(size=1,
                                        location=(0.095, 0, 0.035))
        clasp = bpy.context.object
        clasp.scale = (0.03, 0.03, 0.074)
        link(clasp, brass)
        studio(sc, 0.3, 1.0, 0.03, yaw=0.5, pitch=0.6)
    elif item == 'glasses':
        frame = mat('frame', (0.03, 0.025, 0.02), rough=0.3, coat=0.5)
        lens = mat('lens', (0.9, 0.95, 1.0), rough=0.02)
        lens.node_tree.nodes['Principled BSDF'].inputs[
            'Transmission Weight'].default_value = 1.0
        for x in (-0.032, 0.032):
            bpy.ops.mesh.primitive_torus_add(
                major_radius=0.024, minor_radius=0.0022,
                location=(x, 0, 0.026), rotation=(math.radians(90), 0, 0))
            link(smooth(bpy.context.object, 0), frame)
            bpy.ops.mesh.primitive_cylinder_add(
                vertices=64, radius=0.023, depth=0.002,
                location=(x, 0, 0.026), rotation=(math.radians(90), 0, 0))
            link(bpy.context.object, lens)
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.03))
        bridge = bpy.context.object
        bridge.scale = (0.018, 0.003, 0.003)
        link(bridge, frame)
        for x in (-0.058, 0.058):
            bpy.ops.mesh.primitive_cube_add(size=1,
                                            location=(x, 0.06, 0.026))
            arm = bpy.context.object
            arm.scale = (0.003, 0.12, 0.003)
            link(arm, frame)
        studio(sc, 0.1, 0.5, 0.025, yaw=0.6, pitch=0.35)
    elif item == 'backup':
        plastic = mat('drive', (0.10, 0.18, 0.40), rough=0.35, coat=0.3)
        metal = mat('plug', (0.75, 0.75, 0.72), rough=0.2, metal=1.0)
        tape = mat('tape', (0.92, 0.90, 0.82), rough=0.7, bump=0.2,
                   scale=300)
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.006))
        body = bpy.context.object
        body.scale = (0.05, 0.018, 0.009)
        link(body, plastic)
        bev = body.modifiers.new('bev', 'BEVEL')
        bev.width = 0.002
        bev.segments = 3
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0.032, 0, 0.006))
        plug = bpy.context.object
        plug.scale = (0.014, 0.012, 0.0045)
        link(plug, metal)
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.0108))
        strip = bpy.context.object
        strip.scale = (0.08, 0.03, 0.0004)
        strip.rotation_euler = (0, 0, math.radians(6))
        link(strip, tape)
        studio(sc, 0.05, 0.3, 0.005, yaw=0.5, pitch=0.6)
    elif item in ('echomug', 'echobook', 'echocoil'):
        rust = mat('rust', (0.22, 0.10, 0.04), rough=0.95, bump=1.2,
                   scale=70, spots=(0.10, 0.08, 0.06))
        silt = mat('silt', (0.08, 0.075, 0.06), rough=1.0, bump=0.6,
                   scale=150)
        bpy.ops.mesh.primitive_plane_add(size=0.6, location=(0, 0, 0.001))
        link(bpy.context.object, silt)
        if item == 'echomug':
            bpy.ops.mesh.primitive_cylinder_add(
                vertices=64, radius=0.024, depth=0.057,
                location=(0, 0, 0.022),
                rotation=(math.radians(72), 0, math.radians(30)))
            link(smooth(bpy.context.object, 0), rust)
        elif item == 'echobook':
            bpy.ops.mesh.primitive_cube_add(size=1,
                                            location=(0, 0, 0.012))
            b = bpy.context.object
            b.scale = (0.094, 0.132, 0.014)
            b.rotation_euler = (math.radians(14), math.radians(-9), 0.4)
            link(b, rust)
        else:
            for i in range(3):
                bpy.ops.mesh.primitive_torus_add(
                    major_radius=0.09 - 0.005 * i, minor_radius=0.006,
                    location=(0, 0, 0.007 + 0.011 * i),
                    rotation=(math.radians(8 * i), math.radians(5), 0))
                link(smooth(bpy.context.object, 0), rust)
        studio(sc, 0.12, 0.6, 0.02, yaw=0.5, pitch=0.55)
    elif item in ('astrolabe', 'shield'):
        bronze = mat('bronze', (0.45, 0.30, 0.14), rough=0.4, metal=1.0,
                     bump=0.5, scale=90, spots=(0.14, 0.22, 0.16))
        if item == 'astrolabe':
            bpy.ops.mesh.primitive_cylinder_add(
                vertices=128, radius=0.09, depth=0.006,
                location=(0, 0, 0.1), rotation=(math.radians(90), 0, 0))
            link(smooth(bpy.context.object, 0), bronze)
            bpy.ops.mesh.primitive_torus_add(
                major_radius=0.09, minor_radius=0.005,
                location=(0, 0, 0.1), rotation=(math.radians(90), 0, 0))
            link(smooth(bpy.context.object, 0), bronze)
            bpy.ops.mesh.primitive_torus_add(
                major_radius=0.012, minor_radius=0.003,
                location=(0, 0, 0.198), rotation=(math.radians(90), 0, 0))
            link(smooth(bpy.context.object, 0), bronze)
            bpy.ops.mesh.primitive_cube_add(size=1,
                                            location=(0, -0.006, 0.1))
            rule = bpy.context.object
            rule.scale = (0.17, 0.003, 0.012)
            rule.rotation_euler = (0, math.radians(32), 0)
            link(rule, bronze)
            studio(sc, 0.22, 0.75, 0.1, yaw=0.35, pitch=0.15)
        else:
            iron = mat('iron', (0.16, 0.14, 0.12), rough=0.7, metal=0.8,
                       bump=1.0, scale=40, spots=(0.25, 0.12, 0.05))
            bpy.ops.mesh.primitive_uv_sphere_add(
                segments=96, ring_count=48, radius=0.5,
                location=(0, 0, 0.02))
            sh = bpy.context.object
            sh.scale = (0.7, 0.85, 0.12)
            link(smooth(sh, 0), iron)
            bpy.ops.mesh.primitive_uv_sphere_add(
                segments=48, ring_count=24, radius=0.06,
                location=(0, 0, 0.075))
            link(smooth(bpy.context.object, 0), bronze)
            studio(sc, 0.9, 2.4, 0.03, yaw=0.4, pitch=0.7)


def turntable_root():
    """Everything of the thing (not the sweep, lights or camera) under
    one empty, so the thing turns on its stand under a still light."""
    root = bpy.data.objects.new('turn', None)
    bpy.context.collection.objects.link(root)
    for ob in list(bpy.data.objects):
        if ob is root or ob.parent is not None:
            continue
        if ob.type in ('MESH', 'CURVE') and not ob.name.startswith(
                'Plane'):
            ob.parent = root
    return root


def turntable(item, frames, size, samples):
    """The examine video (TABOO 0.019): the thing turned once round in
    `frames` steps, saved as frames and as one JPEG atlas for the pack
    godot/packs/closeups-ep1 (a flipbook: the engine has no video)."""
    from PIL import Image
    tmp = ROOT / 'build' / 'turntable' / item
    tmp.mkdir(parents=True, exist_ok=True)
    sc = reset()
    sc.cycles.samples = samples
    sc.render.resolution_x = size
    sc.render.resolution_y = size
    build(item, sc)
    root = turntable_root()
    paths = []
    for f in range(frames):
        root.rotation_euler = (0, 0, 2 * math.pi * f / frames)
        sc.render.filepath = str(tmp / ('f%02d.png' % f))
        bpy.ops.render.render(write_still=True)
        paths.append(sc.render.filepath)
    cols = 6
    rows = (frames + cols - 1) // cols
    atlas = Image.new('RGB', (cols * size, rows * size))
    for f, pth in enumerate(paths):
        atlas.paste(Image.open(pth).convert('RGB'),
                    ((f % cols) * size, (f // cols) * size))
    out = PACK / item
    out.mkdir(parents=True, exist_ok=True)
    atlas.save(out / 'atlas.jpg', quality=88, optimize=True)
    (out / 'clip.json').write_text(
        '{"cols": %d, "rows": %d, "frames": %d, "fps": 8}\n'
        % (cols, rows, frames), encoding='utf-8')
    print('turntable', out / 'atlas.jpg')


def main():
    only = arg('--only', '')
    if '--turntable' in sys.argv:
        for item in ITEMS:
            if only and item != only:
                continue
            turntable(item, int(arg('--frames', 24)),
                      int(arg('--size', 320)),
                      int(arg('--samples', 96)))
        return
    OUT.mkdir(parents=True, exist_ok=True)
    for item in ITEMS:
        if only and item != only:
            continue
        sc = reset()
        build(item, sc)
        sc.render.filepath = str(OUT / ('%s.png' % item))
        bpy.ops.render.render(write_still=True)
        print('rendered', sc.render.filepath)


if __name__ == '__main__':
    main()
