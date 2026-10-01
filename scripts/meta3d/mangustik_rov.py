"""Build the game's ROV from the operator's own OpenSCAD drawings.

The Mangustik repo ships every part of the ROV as an STL rendered from
its OpenSCAD source (third_party/mangustik/rov-platform/cad/stl).  The
assembly file 00_full_assembly.scad places them with translate/rotate;
the same placements are repeated here (PLACEMENTS), so the game's
vehicle is the drawn vehicle, not a guess.

OpenSCAD works in millimetres with +X to the bow and +Z up.  Godot and
glTF work in metres with +Y up and -Z forward, so a point (x, y, z) of
the drawing becomes (-y, z, -x): a proper rotation, not a mirror.

Each part keeps the colour of the author's OpenSCAD render
(rov-platform/drawings/00_full_assembly.jpg) and is simplified for the
Quest 3 budget (MAX_TRIANGLES for the whole vehicle).  The result is a
proxy (lod "proxy", TABOO 0.32): the drawing's own assembly is marked
by its author as not certified.

The far-view proxy mangustik-lod1.glb (blocker Б-2, TABOO 0.32 p.4) is
built from the same drawings and placements, decimated to LOD1_TRIANGLES
for the whole vehicle and baked into one mesh whose vertex colours carry
the parts' colours, so it costs one draw call (the hub is at its limit,
docs/APK_REQUIREMENTS.md Б-1).  The scenes show the full model only
near the camera and the proxy beyond (godot/scripts/rov_lod.gd).

Run:  python3 scripts/meta3d/mangustik_rov.py
"""

import json
import os
import sys

import numpy as np
import trimesh

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
CAD = os.path.join(ROOT, 'third_party', 'mangustik', 'rov-platform', 'cad')
OUT_DIR = os.path.join(ROOT, 'godot', 'models', 'rov')
MAX_TRIANGLES = 20000
# The far-view proxy: under the 5,000-triangle limit of TABOO 0.32 p.4
# with room for the clustering fallback's 10 % overshoot per part.
LOD1_TRIANGLES = 5200

# (stl name, [translate mm], [rotate deg], colour, triangle share).
# The placements are copied from 00_full_assembly.scad lines 73-252;
# 12_fasteners is left out there too (a catalogue, not placed geometry).
PLACEMENTS = [
    ('01_main_chassis_frame', [0, 0, 0], [0, 0, 0], '#9c9ea3', 0.18),
    ('02_main_pressure_hull_port', [-400, -130, 250], [0, 90, 0],
     '#f0cf32', 0.12),
    ('03_main_pressure_hull_starboard', [-400, 130, 250], [0, 90, 0],
     '#f0cf32', 0.10),
    ('04_auxiliary_sensor_tubes_top', [-200, 0, 440], [0, 90, 0],
     '#4a72e0', 0.06),
    ('11_central_control_pdb_module', [0, 0, 560], [0, 0, 0],
     '#2c4a48', 0.03),
    ('05_propulsion_horizontal_module', [-500, -300, 0], [0, 90, 0],
     '#1f2c86', 0.05),
    ('05_propulsion_horizontal_module', [-500, 300, 0], [0, 90, 0],
     '#1f2c86', 0.05),
    ('06_propulsion_vertical_module', [400, 0, 140], [0, 0, 0],
     '#1f2c86', 0.04),
    ('06_propulsion_vertical_module', [-350, 0, 140], [0, 0, 0],
     '#1f2c86', 0.04),
    ('07_buoyancy_and_ballast_system', [0, -250, -280], [0, 90, 0],
     '#f2d20c', 0.06),
    ('07_buoyancy_and_ballast_system', [0, 250, -280], [0, 90, 0],
     '#f2d20c', 0.06),
    ('08_sensor_and_camera_skid_front', [500, 0, 50], [0, 0, 0],
     '#e0780e', 0.03),
    ('09_manipulator_and_tool_interface', [500, 0, -200], [0, 0, 0],
     '#b4c6dc', 0.06),
    ('10_tether_rigging_and_protection_bars', [-50, 0, 150], [0, 0, 0],
     '#a3a5aa', 0.12),
]

# Drawing (mm, +X bow, +Z up) -> glTF (m, +Y up, -Z forward).
TO_GLTF = np.array([
    [0.0, -1.0, 0.0, 0.0],
    [0.0, 0.0, 1.0, 0.0],
    [-1.0, 0.0, 0.0, 0.0],
    [0.0, 0.0, 0.0, 1.0],
])
TO_GLTF[:3, :3] *= 0.001


def scad_transform(translate, rotate):
    """The matrix of OpenSCAD's translate(t) rotate([a, b, c]).

    OpenSCAD rotates about X, then Y, then Z (extrinsic), so the
    combined rotation is Rz @ Ry @ Rx.
    """
    rx, ry, rz = (np.radians(a) for a in rotate)
    m = trimesh.transformations.rotation_matrix(rz, [0, 0, 1]) @ \
        trimesh.transformations.rotation_matrix(ry, [0, 1, 0]) @ \
        trimesh.transformations.rotation_matrix(rx, [1, 0, 0])
    m[:3, 3] = translate
    return m


def hex_rgba(colour):
    c = colour.lstrip('#')
    return [int(c[i:i + 2], 16) for i in (0, 2, 4)] + [255]


def vertex_rgba(colour):
    """The vertex colour that renders as the full model's material does.

    The full model writes hex / 255 as baseColorFactor, which glTF reads
    as linear, so Godot shows it lighter than the hex (its albedo is
    the sRGB encoding of that value).  Godot takes COLOR_0 as stored, so
    the proxy stores the same sRGB encoding and both read alike.
    """
    out = []
    for v in hex_rgba(colour)[:3]:
        c = v / 255.0
        s = 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055
        out.append(int(round(min(1.0, s) * 255)))
    return out + [255]


def cluster(mesh, cell):
    """Vertex clustering: snap vertices to a cell (mm) and drop the
    triangles that collapse.  Deterministic, no randomness."""
    keys = np.round(mesh.vertices / cell).astype(np.int64)
    _, first, inverse = np.unique(keys, axis=0, return_index=True,
                                  return_inverse=True)
    faces = inverse.reshape(-1)[mesh.faces]
    alive = (faces[:, 0] != faces[:, 1]) & (faces[:, 1] != faces[:, 2]) \
        & (faces[:, 0] != faces[:, 2])
    return trimesh.Trimesh(mesh.vertices[first], faces[alive],
                           process=False)


def build(max_triangles=MAX_TRIANGLES, single=False):
    """The assembled vehicle: one node per part with its own material,
    or (single) one mesh with the parts' colours as vertex colours."""
    scene = trimesh.Scene()
    total = 0
    parts = []
    baked = []
    for i, (name, t, r, colour, share) in enumerate(PLACEMENTS):
        mesh = trimesh.load(os.path.join(CAD, 'stl', name + '.stl'))
        target = int(max_triangles * share)
        mesh.merge_vertices()
        if len(mesh.faces) > target:
            # Quadric decimation keeps the silhouette; the frame tubes
            # and bars carry most triangles and lose the least shape.
            mesh = mesh.simplify_quadric_decimation(
                face_count=target, aggression=7)
        cell = 2.0
        while len(mesh.faces) > target * 1.1:
            # Plates full of bolt holes stop the quadric decimator (it
            # keeps every hole's boundary); a coarser vertex grid is the
            # fallback, and a proxy may lose a 6 mm hole.
            mesh = cluster(mesh, cell)
            cell *= 1.5
        mesh.apply_transform(TO_GLTF @ scad_transform(t, r))
        total += len(mesh.faces)
        parts.append({'part': name, 'translate_mm': t, 'rotate_deg': r,
                      'colour': colour, 'triangles': len(mesh.faces)})
        if single:
            mesh.visual = trimesh.visual.ColorVisuals(
                mesh, vertex_colors=np.tile(vertex_rgba(colour),
                                            (len(mesh.vertices), 1)))
            baked.append(mesh)
            continue
        # One PBR material per part: painted metal and plastic, not
        # mirrors, so the lamp reads the shape and not a glare.
        mesh.visual = trimesh.visual.TextureVisuals(
            material=trimesh.visual.material.PBRMaterial(
                name=name, baseColorFactor=hex_rgba(colour),
                metallicFactor=0.2, roughnessFactor=0.55))
        scene.add_geometry(mesh, node_name='%02d_%s' % (i, name))
    if single:
        # The colours stay per vertex; the one material carries the
        # same paint (metallic 0.2, roughness 0.55) as the full model.
        whole = trimesh.util.concatenate(baked)
        colours = whole.visual.vertex_colors
        whole.visual = trimesh.visual.ColorVisuals(
            whole, vertex_colors=colours)
        scene.add_geometry(whole, node_name='mangustik_lod1')
    return scene, total, parts


def lod1_paint(tree):
    """Give the proxy's one primitive the full model's paint.

    trimesh writes vertex colours without a material; a white base
    colour with metallic 0.2 and roughness 0.55 keeps COLOR_0 as the
    colour and carries the same paint as the full model's parts.
    """
    tree['materials'] = [{
        'name': 'mangustik_lod1_paint',
        'pbrMetallicRoughness': {
            'baseColorFactor': [1.0, 1.0, 1.0, 1.0],
            'metallicFactor': 0.2,
            'roughnessFactor': 0.55,
        },
    }]
    for mesh in tree['meshes']:
        for prim in mesh['primitives']:
            prim['material'] = 0


def main_lod1():
    scene, total, parts = build(LOD1_TRIANGLES, single=True)
    lo, hi = scene.bounds
    size = (hi - lo).round(3).tolist()
    # Normals are written, so the shading does not depend on how an
    # importer makes them up; the paint goes in as a material, so the
    # file stands alone outside RovLod.build().
    glb = trimesh.exchange.gltf.export_glb(
        scene, include_normals=True, tree_postprocessor=lod1_paint)
    with open(os.path.join(OUT_DIR, 'mangustik-lod1.glb'), 'wb') as f:
        f.write(glb)
    meta = {
        'id': 'mangustik-lod1',
        'lod': 'proxy',
        'lod_level': 1,
        'lod_of': 'mangustik',
        'source': 'third_party/mangustik/rov-platform/cad '
                  '(Leonidy431/Mangustik @ e0dc577), 00_full_assembly.scad',
        'size_m': size,
        'box': size,
        'triangles': total,
        'noInteract': False,
        'noLoot': True,
        'vertex_colours': 'COLOR_0 holds the sRGB encoding of the hex '
                          'colour / 255, not linear as glTF defines it; '
                          'RovLod.proxy_paint() reads it as stored '
                          '(vertex_color_is_srgb = false) so it matches '
                          'the full model, and other viewers show it '
                          'lighter',
        'parts': parts,
    }
    with open(os.path.join(OUT_DIR, 'mangustik-lod1.json'), 'w',
              encoding='utf-8') as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)
        f.write('\n')
    print('mangustik-lod1.glb: %d triangles, size %s m' % (total, size))
    if total > 5000:
        sys.exit('the far-view proxy is over 5,000 triangles')


def main():
    scene, total, parts = build()
    lo, hi = scene.bounds
    size = (hi - lo).round(3).tolist()
    os.makedirs(OUT_DIR, exist_ok=True)
    glb = os.path.join(OUT_DIR, 'mangustik.glb')
    scene.export(glb)
    meta = {
        'id': 'mangustik',
        'lod': 'proxy',
        'source': 'third_party/mangustik/rov-platform/cad '
                  '(Leonidy431/Mangustik @ e0dc577), 00_full_assembly.scad',
        'size_m': size,
        'box': size,
        'triangles': total,
        'noInteract': False,
        'noLoot': True,
        'parts': parts,
    }
    with open(os.path.join(OUT_DIR, 'mangustik.json'), 'w',
              encoding='utf-8') as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)
        f.write('\n')
    print('mangustik.glb: %d triangles, size %s m' % (total, size))
    if total > MAX_TRIANGLES:
        sys.exit('over the Quest budget of %d triangles' % MAX_TRIANGLES)
    main_lod1()


if __name__ == '__main__':
    main()
