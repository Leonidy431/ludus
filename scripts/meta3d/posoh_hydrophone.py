"""Build the game's hydrophone from the operator's own OpenSCAD drawing.

The posoh repo draws its "model 1" hydrophone in
third_party/posoh/hardware/cad/hydrophone_v1.scad: a printed tube with
a piezo disc potted at the sensor end, a preamp and an ESP32 in the dry
bay, and an O-ring end cap.  Every part here is rendered by OpenSCAD
itself from that file, so the game's instrument is the drawn one and
not a guess:

  - the three printed parts through the drawing's own export switch
    (-D print_part="tube_body" | "end_cap" | "standoff");
  - the piezo disc and the two board slabs through a small wrapper that
    `use`s the drawing and calls its modules;
  - the numbers the placements need (tube length, board lengths ...)
    are echoed by OpenSCAD from the drawing, not typed here.

The placements repeat assembly() of the drawing (lines "Board mounting
Z positions" onwards), as mangustik_rov.py repeats its assembly.

OpenSCAD works in millimetres with the tube axis along +Z and the
sensor face at z = 0.  The game wants metres, the sensor looking
forward (-Z in Godot and glTF) and the origin on the end-cap flange,
where the tube is mounted; so a point (x, y, z) becomes
(x, y, z - L) / 1000 with L the tube length: a translation and a
scale, no mirror.

The result is a proxy (lod "proxy", TABOO 0.32): the drawing is a
bench "model 1", its author marks the piezo size, the boards and the
O-ring groove as [UNVERIFIED], and the part has no depth rating.

Run:  python3 scripts/meta3d/posoh_hydrophone.py
Needs: openscad (apt-get install openscad), trimesh, numpy.
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

import numpy as np
import trimesh

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
SCAD = os.path.join(ROOT, 'third_party', 'posoh', 'hardware', 'cad',
                    'hydrophone_v1.scad')
OUT_DIR = os.path.join(ROOT, 'godot', 'models', 'posoh')
MAX_TRIANGLES = 5000
SOURCE_REV = 'Leonidy431/posoh @ 55f44d0'

# The drawing's own global parameters the placements need; OpenSCAD
# echoes them, so a change in the drawing reaches the model.
ECHOED = ['tube_total_length', 'tube_od', 'tube_id', 'end_cap_length',
          'sensor_wall_thickness', 'potting_cavity_depth',
          'preamp_length', 'standoff_od', 'eps', 'piezo_diameter',
          'dry_bay_length']

# (name, how OpenSCAD makes it, colour, alpha).  The colours are the
# drawing's own color() calls in assembly().  The tube is drawn at
# alpha 0.3 there; in dark lake water that reads as nothing, so it is
# raised to 0.5 here: still see-through, so the piezo and the boards
# inside show, as the author meant.
PARTS = [
    ('tube_body', 'print_part', '#c0c0c0', 0.5),
    ('end_cap', 'print_part', '#ffa500', 0.6),
    ('standoff', 'print_part', '#9ea3a8', 1.0),
    ('piezo_disc', 'module', '#8b0000', 1.0),
    ('preamp_board', 'module', '#008000', 1.0),
    ('esp32_board', 'module', '#0000ff', 1.0),
]


def openscad(args, cwd):
    """Run OpenSCAD and fail loudly: a silent empty mesh would be a
    false model."""
    exe = shutil.which('openscad')
    if exe is None:
        sys.exit('openscad not found: apt-get install -y openscad')
    run = subprocess.run([exe] + args, cwd=cwd, capture_output=True,
                         text=True, timeout=300)
    if run.returncode != 0:
        sys.exit('openscad failed: %s\n%s' % (args, run.stderr))
    return run.stderr


def echo_parameters(work):
    """Ask OpenSCAD for the drawing's parameters.  The drawing is
    included with its smallest export (one standoff) so the echo pass
    is quick; its geometry is thrown away."""
    wrapper = os.path.join(work, 'echo.scad')
    with open(wrapper, 'w', encoding='utf-8') as f:
        f.write('include <%s>\n' % SCAD)
        for name in ECHOED:
            f.write('echo("P", "%s", %s);\n' % (name, name))
    log = openscad(['-D', 'print_part="standoff"', '-o',
                    os.path.join(work, 'echo.echo'), wrapper], work)
    with open(os.path.join(work, 'echo.echo'), encoding='utf-8') as f:
        log += f.read()
    params = {}
    for name, value in re.findall(
            r'ECHO: "P", "(\w+)", ([-0-9.e]+)', log):
        params[name] = float(value)
    missing = [n for n in ECHOED if n not in params]
    if missing:
        sys.exit('OpenSCAD did not echo %s' % missing)
    return params


def render_part(name, how, work):
    out = os.path.join(work, name + '.stl')
    if how == 'print_part':
        openscad(['-D', 'print_part="%s"' % name, '-o', out, SCAD], work)
    else:
        wrapper = os.path.join(work, name + '.scad')
        with open(wrapper, 'w', encoding='utf-8') as f:
            f.write('use <%s>\n%s();\n' % (SCAD, name))
        openscad(['-o', out, wrapper], work)
    mesh = trimesh.load(out)
    mesh.merge_vertices()
    return mesh


def placements(p):
    """Where each part sits, in drawing millimetres, as assembly() of
    hydrophone_v1.scad places it."""
    preamp_z = p['sensor_wall_thickness'] + p['potting_cavity_depth'] + 5
    esp32_z = preamp_z + p['preamp_length'] + 5
    standoff_y = -p['tube_id'] / 2 + p['standoff_od'] / 2 + 1
    return {
        'tube_body': [[0, 0, 0]],
        # translate([0, 0, tube_total_length - end_cap_length + eps])
        'end_cap': [[0, 0, p['tube_total_length'] - p['end_cap_length']
                     + p['eps']]],
        # for (z = [preamp_z, esp32_z]) for (x = [-8, 8])
        'standoff': [[x, standoff_y, z] for z in (preamp_z, esp32_z)
                     for x in (-8, 8)],
        'piezo_disc': [[0, 0, 0]],
        'preamp_board': [[0, 0, preamp_z]],
        'esp32_board': [[0, 0, esp32_z]],
    }


def hex_rgba(colour, alpha):
    c = colour.lstrip('#')
    return [int(c[i:i + 2], 16) for i in (0, 2, 4)] + [round(alpha * 255)]


def to_game(length):
    """Drawing (mm, sensor face at z = 0, axis +Z) -> glTF (m, sensor
    forward along -Z, origin on the end-cap flange at z = L)."""
    m = np.eye(4)
    m[2, 3] = -length
    m[:3, :] *= 0.001
    return m


def build(work):
    params = echo_parameters(work)
    where = placements(params)
    scene = trimesh.Scene()
    total = 0
    parts = []
    base = to_game(params['tube_total_length'])
    for name, how, colour, alpha in PARTS:
        mesh = render_part(name, how, work)
        material = trimesh.visual.material.PBRMaterial(
            name=name, baseColorFactor=hex_rgba(colour, alpha),
            alphaMode='BLEND' if alpha < 1.0 else 'OPAQUE',
            # Printed PETG and bare boards: matte, not metal.
            metallicFactor=0.0, roughnessFactor=0.6,
            doubleSided=alpha < 1.0)
        for i, at in enumerate(where[name]):
            copy = mesh.copy()
            copy.apply_transform(base @ trimesh.transformations.
                                 translation_matrix(at))
            copy.visual = trimesh.visual.TextureVisuals(material=material)
            node = name if len(where[name]) == 1 else '%s_%d' % (name, i)
            scene.add_geometry(copy, node_name=node)
            total += len(copy.faces)
            parts.append({'part': name, 'translate_mm': at,
                          'colour': colour, 'alpha': alpha,
                          'triangles': len(copy.faces)})
    return scene, total, parts, params


def main():
    with tempfile.TemporaryDirectory() as work:
        scene, total, parts, params = build(work)
    lo, hi = scene.bounds
    size = (hi - lo).round(4).tolist()
    os.makedirs(OUT_DIR, exist_ok=True)
    scene.export(os.path.join(OUT_DIR, 'hydrophone.glb'))
    meta = {
        'id': 'posoh_hydrophone',
        'lod': 'proxy',
        'source': 'third_party/posoh/hardware/cad/hydrophone_v1.scad '
                  '(%s), rendered part by part by OpenSCAD' % SOURCE_REV,
        'why_proxy': 'bench "model 1": piezo size, boards and O-ring '
                     'groove are [UNVERIFIED] in the drawing; epoxy '
                     'potting and wiring are not drawn',
        'size_m': size,
        'box': size,
        'axis': 'tube along -Z, sensor face forward at z = -L, '
                'end-cap flange (mount face) at z = 0',
        'drawing_mm': {k: params[k] for k in (
            'tube_total_length', 'tube_od', 'tube_id', 'piezo_diameter',
            'end_cap_length', 'dry_bay_length')},
        'depth_rating_m': None,
        'depth_rating_note': 'none in the source: printed PETG/ABS tube, '
                             'slip-fit O-ring cap, "revisit before a real '
                             'dive-rated build" (HYDROPHONE_V1.md)',
        'triangles': total,
        'noInteract': False,
        'noLoot': True,
        'parts': parts,
    }
    with open(os.path.join(OUT_DIR, 'hydrophone.json'), 'w',
              encoding='utf-8') as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)
        f.write('\n')
    print('hydrophone.glb: %d triangles, size %s m, tube %.1f x %.1f mm'
          % (total, size, params['tube_od'], params['tube_total_length']))
    if total > MAX_TRIANGLES:
        sys.exit('over the Quest budget of %d triangles' % MAX_TRIANGLES)


if __name__ == '__main__':
    main()
