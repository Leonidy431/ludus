"""Three tools that turn our own 2D art into 3D, from the honest pool.

Operator, 2026-10-03: «героев всех через конвертацию сделай в 3d все
декорации и предметы тоже… Выбери три инструмента конвертации из 999 по
32 параметрам проекта».  Only OUR sprites go in (the antagonists and
heroes of the second series, props, decorations); frames of other
people's games are reference for study and never a source (TABOO 0.1,
HLD_RZHEVSKY_SERIES2).

Pool (not padded to 999, TABOO 0.07):
    9 tools x 3 inputs x 2 outputs x 3 checks = 162.
Inputs: hero sprite, prop sprite, decoration plate.  Outputs: a closed
proxy mesh, a relief (a plate with depth).  Checks: at most 5000
triangles, resting gap within 5 mm, silhouette overlap within 8 %.

Hard rules prune first: the licence must allow commercial use [V: read
the licence text again before shipping, the table is from memory], it
must run on a CPU in the sandbox, it must not send our art to a server,
and it must give the same mesh for the same picture (no sampling).  The
rest are scored on 32 parameters, 0-3 each, 2 when not listed.

    python3 scripts/decisions/convert_2d3d_choice.py           # table
    python3 scripts/decisions/convert_2d3d_choice.py --check   # CI

Constitution: ФОРМА (our own sprite and its silhouette) → ДЕЙСТВИЕ
(a deterministic converter lifts it into a mesh that rests on its
support) → ЦЕЛЬ (the player sees the same hero in the headset as in
the script, and every borrowed picture stays out of the build).
"""

import itertools
import sys

PARAMS = (
    'licence_commercial', 'cpu_only', 'offline', 'deterministic',
    'silhouette_kept', 'tri_budget', 'gravity_flat_base', 'no_textures_ext',
    'godot_glb', 'python_only', 'small_install', 'ci_runnable',
    'speed', 'memory_low', 'hero_quality', 'prop_quality',
    'decor_quality', 'stylised_flat', 'edge_clean', 'uv_clean',
    'rig_friendly', 'lod_ready', 'batch_friendly', 'testable',
    'maintained', 'docs_clear', 'no_gpu_driver', 'no_model_download',
    'privacy', 'low_risk', 'operator_effort', 'constitution_fit')
assert len(PARAMS) == 32

INPUTS = ('hero', 'prop', 'decor')
OUTPUTS = ('proxy', 'relief')
CHECKS = ('triangles', 'gravity', 'silhouette')

# tool: (hard-rule flags, params above 2 / below 2, input bonus)
TOOLS = {
    'alpha-extrude-shapely': (
        dict(commercial=True, cpu=True, offline=True, deterministic=True),
        dict(licence_commercial=3, cpu_only=3, offline=3,
             deterministic=3, silhouette_kept=3, tri_budget=3,
             gravity_flat_base=3, godot_glb=3, python_only=3,
             small_install=3, ci_runnable=3, speed=3, memory_low=3,
             stylised_flat=3, edge_clean=3, lod_ready=3, batch_friendly=3,
             testable=3, no_gpu_driver=3, no_model_download=3, privacy=3,
             low_risk=3, operator_effort=3, constitution_fit=3,
             hero_quality=1, decor_quality=1, rig_friendly=1),
        dict(hero=0, prop=2, decor=-1)),
    'depth-relief-small-model': (
        dict(commercial=True, cpu=True, offline=True, deterministic=True),
        dict(licence_commercial=3, cpu_only=2, offline=3,
             deterministic=3, godot_glb=3, python_only=3, decor_quality=3,
             hero_quality=2, ci_runnable=2, batch_friendly=3, testable=3,
             privacy=3, small_install=1, no_model_download=0, speed=1,
             memory_low=1, silhouette_kept=2, gravity_flat_base=2,
             rig_friendly=0, constitution_fit=3),
        dict(hero=-1, prop=0, decor=3)),
    'layered-cutout-parallax': (
        dict(commercial=True, cpu=True, offline=True, deterministic=True),
        dict(licence_commercial=3, cpu_only=3, offline=3,
             deterministic=3, silhouette_kept=3, tri_budget=3,
             godot_glb=3, python_only=3, small_install=3, ci_runnable=3,
             speed=3, memory_low=3, stylised_flat=3, batch_friendly=3,
             testable=3, no_gpu_driver=3, no_model_download=3, privacy=3,
             low_risk=3, operator_effort=3, hero_quality=2, prop_quality=1,
             decor_quality=2, rig_friendly=3, edge_clean=2,
             constitution_fit=2),
        dict(hero=2, prop=-1, decor=1)),
    'image-to-3d-feedforward-mit': (
        dict(commercial=True, cpu=False, offline=True, deterministic=False),
        dict(hero_quality=3, prop_quality=3, cpu_only=0, speed=0,
             deterministic=1, no_model_download=0, small_install=0,
             tri_budget=1, uv_clean=1, memory_low=0, ci_runnable=0),
        dict(hero=2, prop=2, decor=0)),
    'image-to-3d-community-licence': (
        dict(commercial=False, cpu=False, offline=True,
             deterministic=False),
        dict(hero_quality=3, licence_commercial=1, cpu_only=0,
             deterministic=1, no_model_download=0),
        dict(hero=2, prop=1, decor=0)),
    'multiview-diffusion': (
        dict(commercial=True, cpu=False, offline=True, deterministic=False),
        dict(hero_quality=2, cpu_only=0, speed=0, deterministic=0,
             memory_low=0, small_install=0),
        dict(hero=1, prop=1, decor=0)),
    'cloud-api-converter': (
        dict(commercial=True, cpu=True, offline=False, deterministic=False),
        dict(offline=0, privacy=0, cpu_only=3, hero_quality=3,
             deterministic=0, licence_commercial=1),
        dict(hero=2, prop=2, decor=1)),
    'blender-shrinkwrap-sculpt': (
        dict(commercial=True, cpu=True, offline=True, deterministic=True),
        dict(licence_commercial=3, cpu_only=3, offline=3,
             deterministic=3, silhouette_kept=2, godot_glb=3, speed=1,
             batch_friendly=1, operator_effort=0, ci_runnable=1,
             hero_quality=2, prop_quality=2),
        dict(hero=1, prop=1, decor=0)),
    'voxel-from-silhouettes': (
        dict(commercial=True, cpu=True, offline=True, deterministic=True),
        dict(licence_commercial=3, cpu_only=3, offline=3,
             deterministic=3, python_only=3, testable=3, tri_budget=1,
             edge_clean=0, stylised_flat=1, hero_quality=1,
             prop_quality=1),
        dict(hero=0, prop=1, decor=-1)),
}


def pool():
    return list(itertools.product(TOOLS, INPUTS, OUTPUTS, CHECKS))


def survives(tool):
    flags = TOOLS[tool][0]
    return (flags['commercial'] and flags['cpu'] and flags['offline']
            and flags['deterministic'])


def score(tool, kind):
    _, attrs, bonus = TOOLS[tool]
    base = sum(attrs.get(p, 2) for p in PARAMS)
    return base + 4 * bonus[kind]


def choose():
    """The best tool for each input, then fill up to three distinct."""
    alive = sorted(t for t in TOOLS if survives(t))
    picks = []
    for kind in INPUTS:
        ranked = sorted(alive, key=lambda t: (-score(t, kind), t))
        pick = next((t for t in ranked if t not in picks), None)
        if pick:
            picks.append(pick)
    return picks, alive


def main(argv):
    picks, alive = choose()
    if '--check' in argv:
        assert len(pool()) == 162, len(pool())
        assert len(picks) == 3 and len(set(picks)) == 3, picks
        assert picks == choose()[0], 'not deterministic'
        assert 'image-to-3d-community-licence' not in alive
        print('convert_2d3d_choice: ok', picks)
        return 0
    print('pool %d, alive tools %d of %d' % (len(pool()), len(alive),
                                             len(TOOLS)))
    for kind in INPUTS:
        for tool in sorted(alive, key=lambda t: (-score(t, kind), t)):
            print('%-6s %-30s %3d' % (kind, tool, score(tool, kind)))
    print('picked:', ', '.join(picks))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
