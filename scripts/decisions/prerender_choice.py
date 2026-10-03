"""Our Silicon Graphics: the one offline renderer for the close-up swap.

Operator, 2026-10-02: «замена sylicon graphics выбери из современных
одну из 999 по 32 параметрам проекта» (docs/HLD_SWAP_RENDERING_
2026-10-02.md).  Pandora's still close-ups were rendered on SGI
workstations with Alias PowerAnimator; ours are rendered once, offline,
and only the picture goes into the APK.

The pool is every renderer x host x quality x denoiser, as found on
2026-10-02 (TABOO 0.07: not padded to 999):

    24 renderers x 4 hosts x 3 qualities x 3 denoisers = 864.

Hard rules prune before scoring: a closed or paid renderer (TABOO 0.25
item 4: no closed engine in new work), a host the project does not
have (a paid GPU cloud, the self-hosted runner not registered, Д-15),
a denoiser that needs a GPU on a CPU host, a renderer that needs a GPU
or Windows, one that cannot run headless.  The rest are scored on 32
parameters, 0-3 each; the order is deterministic.

    python3 scripts/decisions/prerender_choice.py           # table
    python3 scripts/decisions/prerender_choice.py --check   # CI

Constitution: ФОРМА (what the project owns: a 4-core server without a
GPU, open tools, the headset's 768 px of attention) → ДЕЙСТВИЕ (render
the close-ups once, exactly, and ship only pictures) → ЦЕЛЬ (the eye
gets truth where it looks, and the headset carries no renderer).
"""

import itertools
import sys

PARAMS = (
    # Picture
    'global_illumination', 'raytraced_reflections', 'soft_shadows',
    'specular_highlights', 'subsurface_and_glaze', 'colour_management',
    'pbr_matches_gltf', 'procedural_textures', 'hipoly_modelling_same_tool',
    'output_16bit_png',
    # Pipeline
    'python_headless', 'deterministic_seed', 'gltf_import',
    'denoise_quality', 'speed_on_4_cpu', 'memory_fits_15gb',
    'disk_fits_4gb', 'installable_now', 'offline_render',
    'reproducible_by_others', 'time_to_first_image',
    # Rights and life
    'open_licence', 'output_ours', 'no_cost', 'maintained', 'lts',
    'documentation', 'community',
    # Project fit
    'art_direction_continuity', 'skill_reuse', 'low_risk',
    'nothing_in_apk',
)
assert len(PARAMS) == 32

# name: (open, needs_gpu_or_windows, headless, attrs 0-3 by PARAMS[:30])
# attrs not given default to 1.
R = {
    'bpy-cycles-4.5lts': (True, False, True, dict(
        global_illumination=3, raytraced_reflections=3, soft_shadows=3,
        specular_highlights=3, subsurface_and_glaze=3, colour_management=3,
        pbr_matches_gltf=3, procedural_textures=3,
        hipoly_modelling_same_tool=3, output_16bit_png=3,
        python_headless=3, deterministic_seed=3, gltf_import=3,
        speed_on_4_cpu=2, memory_fits_15gb=3, disk_fits_4gb=2,
        installable_now=3, offline_render=3, reproducible_by_others=3,
        time_to_first_image=3, open_licence=3, output_ours=3, no_cost=3,
        maintained=3, lts=3, documentation=3, community=3,
        art_direction_continuity=2, skill_reuse=3, low_risk=3)),
    'bpy-cycles-5.0': (True, False, True, dict(
        global_illumination=3, raytraced_reflections=3, soft_shadows=3,
        specular_highlights=3, subsurface_and_glaze=3, colour_management=3,
        pbr_matches_gltf=3, procedural_textures=3,
        hipoly_modelling_same_tool=3, output_16bit_png=3,
        python_headless=3, deterministic_seed=3, gltf_import=3,
        speed_on_4_cpu=2, memory_fits_15gb=3, disk_fits_4gb=2,
        installable_now=1, offline_render=3, reproducible_by_others=2,
        time_to_first_image=2, open_licence=3, output_ours=3, no_cost=3,
        maintained=3, lts=1, documentation=2, community=3,
        art_direction_continuity=2, skill_reuse=3, low_risk=2)),
    'apt-blender-4.0-cycles': (True, False, True, dict(
        global_illumination=3, raytraced_reflections=3, soft_shadows=3,
        specular_highlights=3, subsurface_and_glaze=3, colour_management=2,
        pbr_matches_gltf=3, procedural_textures=3,
        hipoly_modelling_same_tool=3, output_16bit_png=3,
        python_headless=3, deterministic_seed=3, gltf_import=3,
        speed_on_4_cpu=1, memory_fits_15gb=3, disk_fits_4gb=3,
        installable_now=3, offline_render=3, reproducible_by_others=2,
        time_to_first_image=3, open_licence=3, output_ours=3, no_cost=3,
        maintained=1, lts=1, documentation=3, community=3,
        art_direction_continuity=2, skill_reuse=3, low_risk=2)),
    'bpy-eevee-4.5lts': (True, True, True, {}),
    'mitsuba-3': (True, False, True, dict(
        global_illumination=3, raytraced_reflections=3, soft_shadows=3,
        specular_highlights=3, subsurface_and_glaze=2, colour_management=2,
        pbr_matches_gltf=2, procedural_textures=1,
        hipoly_modelling_same_tool=0, output_16bit_png=3,
        python_headless=3, deterministic_seed=3, gltf_import=1,
        speed_on_4_cpu=2, memory_fits_15gb=3, disk_fits_4gb=3,
        installable_now=3, offline_render=3, reproducible_by_others=3,
        time_to_first_image=1, open_licence=3, output_ours=3, no_cost=3,
        maintained=3, lts=1, documentation=2, community=1,
        art_direction_continuity=1, skill_reuse=1, low_risk=2)),
    'luxcorerender': (True, False, True, dict(
        global_illumination=3, raytraced_reflections=3, soft_shadows=3,
        specular_highlights=3, subsurface_and_glaze=3, gltf_import=1,
        installable_now=2, maintained=1, community=1,
        hipoly_modelling_same_tool=0, time_to_first_image=1)),
    'pbrt-v4': (True, False, True, dict(
        global_illumination=3, raytraced_reflections=3, soft_shadows=3,
        specular_highlights=3, installable_now=0, gltf_import=0,
        hipoly_modelling_same_tool=0, time_to_first_image=0)),
    'appleseed': (True, False, True, dict(
        global_illumination=3, raytraced_reflections=3, maintained=0,
        installable_now=0, hipoly_modelling_same_tool=0)),
    'pov-ray': (True, False, True, dict(
        global_illumination=2, raytraced_reflections=3, soft_shadows=2,
        pbr_matches_gltf=0, gltf_import=0, installable_now=3,
        hipoly_modelling_same_tool=1, maintained=1)),
    'godot-forward-plus-lavapipe': (True, False, True, dict(
        global_illumination=1, raytraced_reflections=0, soft_shadows=2,
        specular_highlights=2, subsurface_and_glaze=1, colour_management=2,
        pbr_matches_gltf=3, procedural_textures=2,
        hipoly_modelling_same_tool=2, output_16bit_png=1,
        python_headless=2, deterministic_seed=3, gltf_import=3,
        speed_on_4_cpu=3, memory_fits_15gb=3, disk_fits_4gb=3,
        installable_now=3, offline_render=3, reproducible_by_others=3,
        time_to_first_image=3, open_licence=3, output_ours=3, no_cost=3,
        maintained=3, lts=2, documentation=3, community=3,
        art_direction_continuity=3, skill_reuse=3, low_risk=3)),
    'godot-compatibility': (True, False, True, dict(
        global_illumination=0, raytraced_reflections=0, soft_shadows=1,
        specular_highlights=1, pbr_matches_gltf=3, installable_now=3,
        art_direction_continuity=3, low_risk=3)),
    'three-gpu-pathtracer-chromium': (True, False, True, dict(
        global_illumination=3, raytraced_reflections=3, soft_shadows=3,
        speed_on_4_cpu=0, gltf_import=3, installable_now=2,
        hipoly_modelling_same_tool=1, deterministic_seed=1)),
    'filament': (True, False, True, dict(
        global_illumination=1, pbr_matches_gltf=3, gltf_import=3,
        installable_now=1, hipoly_modelling_same_tool=0)),
    'embree-custom-tracer': (True, False, True, dict(
        installable_now=0, time_to_first_image=0, low_risk=0,
        hipoly_modelling_same_tool=0)),
    'falcor': (True, True, False, {}),
    'unreal-path-tracer': (False, True, False, {}),
    'unity-hdrp': (False, True, False, {}),
    'renderman-ncr': (False, False, True, {}),
    'arnold': (False, False, True, {}),
    'v-ray': (False, False, True, {}),
    'octane': (False, True, False, {}),
    'redshift': (False, True, False, {}),
    'keyshot': (False, False, False, {}),
    'marmoset-toolbag': (False, True, False, {}),
}
assert len(R) == 24

# host: (exists for the project now, has GPU, reproducible by others)
HOSTS = {
    'dev-server-cpu': (True, False, 1),
    'github-actions-cpu': (True, False, 3),
    'self-hosted-vm-batch': (False, False, 2),
    'cloud-gpu-paid': (False, True, 2),
}
QUALITY = {'preview-32spp': 1, 'production-256spp': 3,
           'pathtraced-1024spp': 2}
DENOISE = {'none': 0, 'oidn': 3, 'optix': 3}


def candidates():
    for r, h, q, d in itertools.product(R, HOSTS, QUALITY, DENOISE):
        yield r, h, q, d


def pruned(r, h, q, d):
    is_open, needs_gpu, headless, _ = R[r]
    exists, gpu, _ = HOSTS[h]
    if not is_open:
        return 'closed or paid renderer'
    if not exists:
        return 'host the project does not have'
    if needs_gpu and not gpu:
        return 'needs a GPU or Windows'
    if not headless:
        return 'not headless'
    if d == 'optix' and not gpu:
        return 'OptiX needs an NVIDIA GPU'
    if d == 'oidn' and not r.startswith(('bpy-cycles', 'apt-blender',
                                         'luxcore')):
        return 'no OIDN in this renderer'
    if d == 'oidn' and r.startswith('apt-blender'):
        return 'the distro build has no OIDN'
    return ''


def score(r, h, q, d):
    attrs = R[r][3]
    s = {p: attrs.get(p, 1) for p in PARAMS}
    s['denoise_quality'] = DENOISE[d]
    s['reproducible_by_others'] = min(s['reproducible_by_others'],
                                      HOSTS[h][2])
    if h == 'github-actions-cpu':
        # A runner downloads the renderer every run unless cached, and
        # its job limit bounds a long render.
        s['time_to_first_image'] = max(0, s['time_to_first_image'] - 1)
    q_s = QUALITY[q]
    for p in ('global_illumination', 'soft_shadows'):
        s[p] = min(s[p], q_s + (1 if d != 'none' else 0))
    if q == 'pathtraced-1024spp':
        s['speed_on_4_cpu'] = max(0, s['speed_on_4_cpu'] - 2)
    s['nothing_in_apk'] = 3
    return s


def ranked():
    alive, dead = [], {}
    for c in candidates():
        why = pruned(*c)
        if why:
            dead[why] = dead.get(why, 0) + 1
            continue
        s = score(*c)
        alive.append((sum(s.values()), c, s))
    alive.sort(key=lambda x: (-x[0], x[1]))
    return alive, dead


def main(argv):
    alive, dead = ranked()
    total = len(R) * len(HOSTS) * len(QUALITY) * len(DENOISE)
    best = alive[0]
    if '--check' in argv:
        ok = best[1] == ('bpy-cycles-4.5lts', 'github-actions-cpu',
                         'production-256spp', 'oidn')
        print('prerender: %d in pool, %d pruned, %d scored; chosen %s'
              % (total, sum(dead.values()), len(alive), ' x '.join(
                  best[1])))
        if not ok:
            print('FAIL: the choice changed; update the HLD')
        return 0 if ok else 1
    print('pool %d, pruned %d %s, scored %d' % (
        total, sum(dead.values()), dead, len(alive)))
    print('| # | renderer | host | quality | denoiser | score of 96 |')
    print('|---|---|---|---|---|---|')
    for i, (tot, c, _) in enumerate(alive[:10], 1):
        print('| %d | %s | %s | %s | %s | %d |' % ((i,) + c + (tot,)))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
