"""One way to make the headset engine smaller, chosen in the open.

Operator, 2026-10-02: «godot возможно как то в бинарник без лишних
библиотек сконвертировать потом? поищи единственное решение из 888 по
48 параметрам из имеющихся».  The native libraries are the APK's tight
spot (lib/*.so 83 393 888 of 88 080 384 bytes, 5.3 % left), and 76 177
376 bytes of them are the engine itself, libgodot_android.so, from the
stock debug template.

The pool is the product of explicit dimensions of how the engine can
be built and packed, so its size is what they honestly give, not 888
(TABOO 0.07 item 2).  Hard constraints prune what cannot work here.
Every remaining variant is scored on the 48 parameters of
scripts/decisions/engine-params-48.json, one rule per parameter, 0, 1
or 2 points times its weight.  Ties go to the order the dimensions are
written in, so the run is deterministic.

    python3 scripts/decisions/engine_build_choice.py          # top 10
    python3 scripts/decisions/engine_build_choice.py --check  # CI

--check fails when the winner differs from CHOSEN, the choice recorded
in docs/decisions/ENGINE_BUILD_2026-10-02.md.

The facts the rules rest on were measured on 2026-10-02 and are named
in FACTS; sizes of a custom build are not guessed here: the rules rank
variants by what they remove, and the size is measured once the
template is built (TABOO 0.011 item 6).

Constitution: ФОРМА (what the headset can carry: the engine's own
bytes) → ДЕЙСТВИЕ (every way of building it scored by the same open
rules) → ЦЕЛЬ (room for the teaching's voices without a heavier APK).
"""

import itertools
import json
import sys
from pathlib import Path

PARAMS = Path(__file__).resolve().parent / 'engine-params-48.json'

# Measured 2026-10-02 (unzip -lv of the Godot 4.7.1 export templates and
# of headset-latest; grep over godot/scripts, scenes, tools, tests).
FACTS = {
    'so_debug_stock': 76_177_376,
    'so_release_stock': 71_110_440,
    'so_debug_deflated': 27_833_653,
    'lib_so_limit': 88_080_384,
    'lib_so_now': 83_393_888,
    'android_job_minutes': 45,
    'regex_files': 11,
    'network_classes_in_game': 0,
    'navigation_csg_gridmap_video_gltf_runtime': 0,
    'physics_bodies_and_rays': 0,
    'church_slavonic_marks_in_data': 0,
}

# The dimensions in order of precedence for ties.  Custom-only
# dimensions are None for the stock templates.
DIMS = {
    'build': ('stock', 'custom'),
    'opt': ('speed', 'size', 'size_extra'),
    'lto': ('none', 'thin', 'full'),
    'profile': ('none', 'detected', 'hand'),
    'text': ('adv', 'fb'),
    'modules': ('all', 'drop_unused', 'minimal'),
    'where': ('every_run', 'cached'),
    'libs': ('stored', 'compressed'),
    'vendors': ('keep', 'drop'),
}
CUSTOM_ONLY = ('opt', 'lto', 'profile', 'text', 'modules', 'where')

CHOSEN = {'build': 'custom', 'opt': 'size', 'lto': 'thin',
          'profile': 'detected', 'text': 'adv', 'modules': 'drop_unused',
          'where': 'cached', 'libs': 'stored', 'vendors': 'keep'}


def pool():
    """Every variant the dimensions give, stock ones without the
    custom-only dimensions (they cannot vary there)."""
    out = []
    shared = [DIMS['libs'], DIMS['vendors']]
    for libs, vendors in itertools.product(*shared):
        out.append({'build': 'stock', 'opt': None, 'lto': None,
                    'profile': None, 'text': None, 'modules': None,
                    'where': None, 'libs': libs, 'vendors': vendors})
    custom = [DIMS[k] for k in CUSTOM_ONLY] + shared
    for vals in itertools.product(*custom):
        v = dict(zip(CUSTOM_ONLY + ('libs', 'vendors'), vals))
        v['build'] = 'custom'
        out.append(v)
    return out


def hard_reason(v):
    """Why a variant cannot work here, or '' when it can."""
    if v['vendors'] == 'drop':
        # The CI step greps the manifest for com.oculus entries that
        # the vendors plugin writes; without them Quest does not list
        # the app as VR.
        return 'no Meta vendors plugin: Quest manifest check fails'
    if v['build'] == 'custom' and v['where'] == 'every_run':
        # A full engine build does not fit the android job's 45 min.
        return 'engine built in every android job: over 45 minutes'
    if v['build'] == 'custom' and v['modules'] == 'minimal' \
            and v['profile'] == 'none':
        # "minimal" strips the image loaders; without a class profile
        # Image.load (1 file) is left without its format.
        return 'minimal modules without a class profile'
    return ''


def shrink(v):
    """What a variant removes, 0..9: ranks size, not measures it."""
    if v['build'] == 'stock':
        return 0
    return ({'speed': 0, 'size': 1, 'size_extra': 2}[v['opt']]
            + {'none': 0, 'thin': 1, 'full': 2}[v['lto']]
            + {'none': 0, 'detected': 1, 'hand': 2}[v['profile']]
            + {'adv': 0, 'fb': 1}[v['text']]
            + {'all': 0, 'drop_unused': 1, 'minimal': 2}[v['modules']])


def risk(v):
    """How much a variant could cut that the game later needs, 0..6."""
    if v['build'] == 'stock':
        return 0
    return ({'none': 0, 'detected': 1, 'hand': 2}[v['profile']]
            + {'all': 0, 'drop_unused': 1, 'minimal': 2}[v['modules']]
            + {'adv': 0, 'fb': 1}[v['text']]
            + {'none': 0, 'thin': 0, 'full': 1}[v['lto']])


def lvl(x, two, one):
    return 2 if x >= two else 1 if x >= one else 0


def rules(v):
    """Points 0..2 for each of the 48 parameters."""
    custom = v['build'] == 'custom'
    s, r = shrink(v), risk(v)
    stored = v['libs'] == 'stored'
    speed = 2 if not custom else (
        2 if v['opt'] == 'speed' or (v['opt'] == 'size'
                                     and v['lto'] != 'none') else
        1 if v['opt'] == 'size' else 0)
    return {
        'e01': lvl(s, 4, 2),
        'e02': lvl(s, 4, 2),
        'e03': speed,
        'e04': 2,
        'e05': 2,
        'e06': 2,
        'e07': 2,
        'e08': 2,
        'e09': 1 if custom and v['lto'] == 'full' else 2,
        'e10': 2 if r == 0 else 1 if r <= 2 else 0,
        'e11': 2 if not custom else 1,
        'e12': 2,
        'e13': 0 if custom and v['text'] == 'fb' else 2,
        'e14': 2,
        'e15': 2,
        'e16': 2,
        'e17': 2 if not custom else (
            0 if v['profile'] == 'hand' or v['modules'] == 'minimal'
            else 1 if v['profile'] == 'detected' else 2),
        'e18': 2 if stored and s >= 4 else 1 if stored else 0,
        'e19': (0 if not stored else lvl(s, 4, 1)),
        'e20': lvl(s, 4, 2),
        'e21': 2 if stored else 1,
        'e22': 2 if stored else 0,
        'e23': 2 if not custom else 1,
        'e24': 2 if not custom else 1,
        'e25': 2,
        'e26': 2,
        'e27': 2,
        'e28': 2,
        'e29': 2 if custom and v['profile'] != 'none' else 1,
        'e30': 2 if custom else 0,
        'e31': 2 if custom else 0,
        'e32': 2 if custom and v['modules'] != 'all' else 1,
        'e33': 2,
        'e34': 2 if not custom else 1,
        'e35': 2 if not custom else (1 if r <= 2 else 0),
        'e36': 2,
        'e37': 2,
        'e38': 2,
        'e39': 2,
        'e40': 2 if not custom else 1,
        'e41': 2,
        'e42': 2,
        'e43': 2,
        'e44': 2,
        'e45': 2,
        'e46': 2,
        'e47': 2,
        'e48': 2,
    }


def load_params():
    data = json.loads(PARAMS.read_text(encoding='utf-8'))
    params = data['params']
    assert len(params) == 48, 'forty-eight parameters'
    assert len({p['id'] for p in params}) == 48, 'unique ids'
    return params


def run():
    params = load_params()
    weight = {p['id']: p['weight'] for p in params}
    variants = pool()
    alive, pruned = [], {}
    for v in variants:
        why = hard_reason(v)
        if why:
            pruned[why] = pruned.get(why, 0) + 1
            continue
        pts = rules(v)
        assert set(pts) == set(weight), 'a rule per parameter'
        alive.append((sum(weight[k] * pts[k] for k in pts), v))
    order = list(DIMS)

    def key(item):
        score, v = item
        return (-score,) + tuple(
            -1 if v[k] is None else DIMS[k].index(v[k]) for k in order)
    alive.sort(key=key)
    best = 2 * sum(weight.values())
    return {'pool': len(variants), 'pruned': pruned, 'alive': alive,
            'best_possible': best}


def short(v):
    if v['build'] == 'stock':
        return 'stock libs=%s vendors=%s' % (v['libs'], v['vendors'])
    return ' '.join('%s=%s' % (k, v[k]) for k in DIMS)


def main(argv):
    r = run()
    win = r['alive'][0][1]
    if '--check' in argv:
        if win != CHOSEN:
            print('engine choice changed: %s, recorded %s' % (
                short(win), short(CHOSEN)))
            return 1
        print('engine choice: %s (%d of %d)' % (
            short(win), r['alive'][0][0], r['best_possible']))
        return 0
    print('pool %d variants; pruned %d: %s' % (
        r['pool'], sum(r['pruned'].values()),
        json.dumps(r['pruned'], ensure_ascii=False)))
    print('alive %d; best possible %d' % (len(r['alive']),
                                          r['best_possible']))
    for score, v in r['alive'][:10]:
        print('%4d  shrink %d risk %d  %s' % (score, shrink(v), risk(v),
                                              short(v)))
    stock = [x for x in r['alive'] if x[1]['build'] == 'stock']
    print('best stock: %d  %s' % (stock[0][0], short(stock[0][1])))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
