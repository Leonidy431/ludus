"""99 locations for our plots: the honest pool and the K the headset gets.

Operator, 2026-09-30: "99 локаций добавь по 299 нашим сюжетам. бери
предметы из 99 репо которые склонировали. келья вечернего дозора с
предметами обители хорошо получилась" -- and the evening-watch cell
became the location standard (CLAUDE.md TABOO 0.013).  This script is
the foundation: WHICH 99 places, for WHICH plots, each specified on
that standard, so the next phases only build.

First the plots are counted as they are in the repository (the
campaign, the Water Atlas, Kiberslav, the dive, the thresholds, the
passions' road, the path of the witness); the operator's 299 is
checked against that count and never padded.

The pool (scripts/locations/register.py) holds every place where a plot
of ours happens, with its evidence: the location proxies drawn from
our SVG or written in the 1070 prompts, and the plot that names the
place.  Each candidate is scored on five open criteria, 0-10:
  truth      a real place or type of 14th-century Semirechye and
             Issyk-Kul, of Cilicia in 1375, or of the 2026 story;
             lower for a hypothesis, a legend or the dream register;
  teaching   FORM -> ACTION -> GOAL through ONE heart practice;
  readable   computed from the shell: a room reads best in the
             headset, open ground and night outdoors worst; a drawn
             backdrop helps;
  novelty    computed: lower when the headset already has the place
             (hub, dive, witness path);
  safety     holy never loot or key, sacraments only witnessed.
Gates: safety >= 7, readable >= 4, teaching >= 5, truth >= 4, a valid
heart, a plot not wholly on the chorus' rewrite list.  Selection is
deterministic (ties by id): first a minimum per plot family, then one
place for every campaign mission that has none yet, then the rest by
score; at most two places of one kind, one location per place.

Every chosen location is then laid out on the standard: the heart at
a fixed point, a free passage from the entrance, slots on the wall, on
a bench or crate, on the floor (on the seabed under water), a holy
thing only in its one slot, every thing at least 0.75 m from the
heart.  Its budget is measured from the proxy files (TABOO 0.011).

Writes:
  godot/data/locations-99.json               the K (goes into the APK)
  docs/LOCATIONS_99_POOL.json                the whole pool with scores
  docs/LOCATIONS_99_SELECTION_2026-09-30.md  the table for the operator
Reads, when --index is given, the index of the 99 cloned repos and
writes docs/LOCATIONS_99_RAW_HITS.json (what the props store can give
each wished thing); without --index the committed snapshot is used.
Usage: python3 scripts/locations/locations_99.py [--check] [--index DIR]
"""

import json
import math
import re
import struct
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(ROOT / 'scripts' / 'story'))

import register as reg  # noqa: E402
import atlas_nodes  # noqa: E402

GODOT = ROOT / 'godot'
MODELS = ROOT / 'public' / 'vr' / 'models'
OUT_DATA = GODOT / 'data' / 'locations-99.json'
OUT_POOL = ROOT / 'docs' / 'LOCATIONS_99_POOL.json'
OUT_DOC = ROOT / 'docs' / 'LOCATIONS_99_SELECTION_2026-09-30.md'
RAW_HITS = ROOT / 'docs' / 'LOCATIONS_99_RAW_HITS.json'

K = 99
PER_KIND = 2
# The families of plots and how many places each needs at least.  A
# place counts for every family its plots belong to.
FAMILIES = ['prologue', 'trade', 'spiritual', 'hydrology', 'diplomacy',
            'craft', 'narrative', 'atlas', 'kiberslav', 'dive',
            'threshold', 'road', 'witness']
MIN_FAMILY = {'prologue': 2, 'trade': 8, 'spiritual': 6, 'hydrology': 8,
              'diplomacy': 7, 'craft': 10, 'narrative': 5, 'atlas': 12,
              'kiberslav': 8, 'dive': 4, 'threshold': 5, 'road': 6,
              'witness': 0}
FAMILY_RU = {'prologue': 'Пролог', 'trade': 'Акт I', 'spiritual': 'Акт II',
             'hydrology': 'Акт III', 'diplomacy': 'Акт IV',
             'craft': 'Акт V', 'narrative': 'Финал', 'atlas': 'Атлас воды',
             'kiberslav': 'Киберслав', 'dive': 'Погружение',
             'threshold': 'Пороги', 'road': 'Дорога страстей',
             'witness': 'Тропа свидетеля'}

# The standard (TABOO 0.013 item 6) and the Quest budgets of the draft
# gate (commit 55849b7, scripts/godot/apk-budgets.json: draw calls of
# the main view < 100 for the Quest 2 floor, 750K triangles for both
# eyes, a proxy <= 5000 triangles, a file <= 1 MiB).
CLEAR_M = 0.75
PASS_HALF_M = 0.6
ROV_PASS_HALF_M = 1.0
TAG_RANGE_M = 3.2
MAX_TRIS = 5000
MAX_DRAWS = 100
MAX_TRIS_TWO_EYES = 750000
MAX_FILE_BYTES = 1048576
PENDING_TRIS = MAX_TRIS  # Worst case for a thing still to be made.
CARD_M = 0.6

SHELL_READ = {'room': 8, 'cave': 7, 'yard': 7, 'shore': 6, 'open': 5,
              'underwater': 6}
SHELL_PARTS = {'room': 5, 'cave': 5, 'yard': 4, 'shore': 2, 'open': 1,
               'underwater': 1}
EXISTS_PENALTY = {'hub-cell': 4, 'hub-refectory': 4, 'witness': 4,
                  'dive': 3, 'dive-trace': 3}
LIGHT_K = {'lampada': (1800, 1800), 'hearth': (1900, 2500),
           'instrument': (6500, 6500)}
# Church words never label a place, a thing or a hint (TABOO 0.39
# item 3, 0.4 item 7); names of holy things are not labels either.
CHURCH_WORDS = ['свят', 'благодат', 'таинств', 'мученик', 'мучени',
                'спасени', 'литурги', 'причаст', 'причащ', 'исповед',
                'крещен', 'молитв', 'чудо', 'мощи', 'икон', 'храм',
                'церк', 'алтар', 'крест', 'лампад', 'прп.', 'свт.',
                'вмц.', 'столпник', 'двоеслов', 'мироносиц']

PASSION_RU = {'gluttony': 'чревоугодие', 'lust': 'блуд',
              'avarice': 'сребролюбие', 'sadness': 'печаль',
              'anger': 'гнев', 'acedia': 'уныние',
              'vainglory': 'тщеславие', 'pride': 'гордость'}


# --- The plots as they are ------------------------------------------------

def _read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def _json(path):
    return json.loads(_read(path))


def _block(text, start):
    """The literal of a GDScript constant, by matching its brackets."""
    i = text.index(start)
    opening = min(j for j in (text.find('[', i), text.find('{', i))
                  if j >= 0)
    pair = {'[': ']', '{': '}'}[text[opening]]
    depth = 0
    for j in range(opening, len(text)):
        if text[j] == text[opening]:
            depth += 1
        elif text[j] == pair:
            depth -= 1
            if depth == 0:
                return text[opening:j + 1]
    raise ValueError(start)


def inventory():
    """Every plot unit of the game, read from its own source."""
    spine = _json('godot/data/campaign-spine.json')
    act_of, missions = {}, {}
    for act in spine['acts']:
        for mid in act['missions']:
            act_of[int(mid)] = act['id']
    for m in spine['missions']:
        missions[int(m['id'])] = m['title']
    flagged = {int(m['id']) for m in spine['needsChorusRewrite']}

    synopsis = _read('docs/kiberslav/KIBERSLAV_SYNOPSIS_AV_5_EDITORS.md')
    section = synopsis.split('## 3.')[1].split('## 4.')[0]
    kiber = {}
    for row in re.findall(r'^\| (\d+) \|(.*)$', section, re.MULTILINE):
        cells = [c.strip() for c in row[1].split('|')]
        kiber[int(row[0])] = re.sub(r'\*\*', '', cells[2])[:90]
    bible = _read('docs/kiberslav/STYLE_BIBLE_LUDUS_KIBERSLAV.md')
    dream = int(re.search(r'Ветка из (\d+) миссий', bible).group(1))
    written = len(re.findall(r'^#+ .*[Мм]иссия \d+', bible
                             + synopsis, re.MULTILINE))

    dive_gd = _read('godot/scripts/dive_core.gd')
    dive = re.findall(r'\{"id": "(\w+)", "band"',
                      _block(dive_gd, 'const TASKS'))
    dive_ru = dict(re.findall(r'"id": "(\w+)", "band": "\w+",\s*'
                              r'"ru": "([^"]+)"', dive_gd))
    witness = re.findall(r'"(\w+)"', _block(
        _read('godot/scripts/witness_core.gd'), 'const ORDER'))
    trials = _json('godot/data/gate-trials.json')['trials']
    passions = _json('godot/data/passions.json')['passions']
    rule_gd = _read('godot/scripts/rule_core.gd')
    practices = dict(re.findall(r'\{"id": "(\w+)", "kind": "\w+",'
                                r'[^}]*?"ru": "([^"]+)"',
                                _block(rule_gd, 'const PRACTICES'),
                                re.DOTALL))
    mission_gd = _read('godot/scripts/mission_core.gd')
    deeds = dict(re.findall(r'"(\w+)": \{"label": "([^"]+)"',
                            _block(mission_gd, 'const PRACTICE_RU')))
    lore = sorted((ROOT / 'lore').glob('*.txt'))
    matrix = _read('docs/STORYLINES_99_ASSET_MATRIX.md')
    prompts = _json('docs/PROMPTS_1070_2026-09-29.json')

    plots = {}
    for mid, title in missions.items():
        plots['M%d' % mid] = {'family': act_of[mid], 'title': title,
                              'rewrite': mid in flagged}
    for node in atlas_nodes.NODES:
        plots['A%d' % node[0]] = {'family': 'atlas',
                                  'title': node[2][:90], 'rewrite': False}
    for n, text in kiber.items():
        plots['K%d' % n] = {'family': 'kiberslav', 'title': text,
                            'rewrite': False}
    plots['KM'] = {'family': 'kiberslav', 'rewrite': False,
                   'title': 'Сон послушника: %d миссий объявлены, не '
                            'расписаны' % dream}
    for t in dive:
        plots['D:' + t] = {'family': 'dive', 'title': dive_ru.get(t, t),
                           'rewrite': False}
    for w in witness:
        plots['W:' + w] = {'family': 'witness', 'title': w,
                           'rewrite': False}
    for t in trials:
        plots['T:' + t['gateId']] = {'family': 'threshold',
                                     'title': t['title_ru'],
                                     'rewrite': False}
    for p in passions:
        plots['P:' + p['id']] = {'family': 'road',
                                 'title': 'Встреча: ' + p['name_ru'],
                                 'rewrite': False}
    counts = {
        'missions': len(missions), 'missions_rewrite': len(flagged),
        'acts': len(spine['acts']), 'atlas_nodes': len(atlas_nodes.NODES),
        'atlas_traces': len(atlas_nodes.TRACES),
        'atlas_chronicle_options': len(atlas_nodes.CHRONICLE['options']),
        'kiberslav_nodes': len(kiber), 'dream_missions_declared': dream,
        'dream_missions_written': written, 'dive_tasks': len(dive),
        'witness_scenes': len(witness), 'thresholds': len(trials),
        'passions': len(passions), 'practices': len(practices),
        'matrix_storylines': len(re.findall(r'\n## \d+\. ', matrix)),
        'prompt_places': sum(1 for x in prompts
                             if x['type'] == 'локация'),
        'loc_proxies': len(list((MODELS / 'loc').glob('*.json'))),
        'lore_files': len(lore),
        'lore_lines': sum(len(f.read_text(encoding='utf-8').splitlines())
                          for f in lore)}
    counts['plot_units'] = (counts['missions'] + counts['atlas_nodes']
                            + counts['kiberslav_nodes']
                            + counts['dream_missions_declared']
                            + counts['dive_tasks']
                            + counts['witness_scenes']
                            + counts['thresholds'] + counts['passions'])
    counts['plot_units_written'] = (counts['plot_units']
                                    - counts['dream_missions_declared']
                                    + counts['dream_missions_written'])
    counts['three_lists'] = (counts['missions'] + counts['atlas_nodes']
                             + counts['kiberslav_nodes'])
    trees = _json('godot/data/dialogue-trees.json')['trees']
    lake = {o['id']: o for o in
            _json('godot/data/lake-objects-99.json')['objects']}
    return {'plots': plots, 'counts': counts, 'dive_ru': dive_ru,
            'witness': witness, 'trials': {t['gateId']: t for t in trials},
            'passions': {p['id']: p for p in passions},
            'practices': practices, 'deeds': deeds, 'trees': trees,
            'lake': lake,
            'traces': {t['id']: t for t in atlas_nodes.TRACES}}


# --- Hearts ----------------------------------------------------------------

def heart_of(spec, inv):
    """Resolve a heart spec against the game's own cores."""
    kind, _, rest = spec.partition(':')
    if kind == 'rule' and rest in inv['practices']:
        return {'core': 'RuleCore', 'id': rest,
                'ru': inv['practices'][rest]}
    if kind == 'deed' and rest in inv['deeds']:
        return {'core': 'MissionCore', 'step': 'practice', 'id': rest,
                'ru': inv['deeds'][rest]}
    if kind == 'talk':
        npc, _, node = rest.partition('/')
        tree = inv['trees'].get(npc)
        if tree and any(n['id'] == node for n in tree['nodes']):
            name = reg.NPC_HINT_RU.get(npc, tree['npcName_ru'])
            return {'core': 'MissionCore', 'step': 'dialogue', 'npc': npc,
                    'node': node, 'ru': 'Поговорить: ' + name}
    if kind == 'find' and rest in inv['lake']:
        return {'core': 'MissionCore', 'step': 'find', 'object': rest,
                'ru': 'Находка: ' + inv['lake'][rest]['ru']}
    if kind == 'dive' and rest in inv['dive_ru']:
        return {'core': 'DiveCore', 'id': rest, 'ru': inv['dive_ru'][rest]}
    if kind == 'trace' and rest in inv['traces']:
        return {'core': 'AtlasTraces', 'id': 'trace', 'trace': rest,
                'ru': 'Отдать писцу: ' + inv['traces'][rest]['ru']}
    if kind == 'atlas' and rest == 'chronicle':
        return {'core': 'AtlasTraces', 'id': 'chronicle',
                'ru': 'Летопись 1375 года: что сделал рыцарь'}
    if kind == 'atlas' and rest == 'scribe':
        return {'core': 'AtlasTraces', 'id': 'scribe',
                'ru': 'Книга находок у писца'}
    if kind == 'trial' and rest in inv['trials']:
        return {'core': 'TrialCore', 'id': rest,
                'ru': inv['trials'][rest]['title_ru']}
    if kind == 'passion' and rest in inv['passions']:
        lure = inv['passions'][rest]['lure_ru'].split('.')[0]
        return {'core': 'PassionCore', 'id': rest,
                'ru': 'Посул на дороге: «%s»' % lure}
    if kind == 'witness' and rest in inv['witness']:
        return {'core': 'WitnessCore', 'id': rest,
                'ru': 'Постоять у черты, склонить голову, уйти'}
    if kind == 'typikon' and rest == 'hear':
        return {'core': 'TypikonCore', 'id': 'hear',
                'ru': 'Слушать звон дня: по уставу и часам'}
    if kind == 'listen' and rest == 'kitezh':
        # Kiberslav node 76: the lake is listened to, never found; the
        # heart counts, pays and writes nothing (not RuleCore, whose
        # stillness is recorded and lifts a fall).
        return {'core': 'listen', 'id': rest,
                'ru': 'Стоять неподвижно и слушать озеро'}
    if kind == 'new' and rest in reg.NEW_ACTIONS:
        ru, line = reg.NEW_ACTIONS[rest]
        return {'core': 'new', 'id': rest, 'ru': ru, 'constitution': line}
    return None


def heart_thing(spec):
    """The thing the heart itself is about, if it stands in the place."""
    kind, _, rest = spec.partition(':')
    if kind == 'find':
        return rest
    if kind == 'trace':
        return 'atlas-' + rest
    return None


# --- Things ------------------------------------------------------------------

def proxy_paths(src):
    kind, _, pid = src.partition(':')
    if kind == 'obj':
        base = MODELS / 'obj' / pid
    elif kind == 'lake':
        base = MODELS / 'lake' / ('lake-' + pid.replace('.', '-'))
    elif kind == 'atlas':
        base = MODELS / 'atlas' / ('atlas-' + pid)
    else:
        return None, None
    return Path(str(base) + '.glb'), Path(str(base) + '.json')


def glb_draws(path):
    """Draw calls of a .glb: one per primitive of every mesh instance."""
    data = path.read_bytes()
    size, kind = struct.unpack_from('<I4s', data, 12)
    assert data[:4] == b'glTF' and kind == b'JSON', path
    doc = json.loads(data[20:20 + size])
    meshes = doc.get('meshes', [])
    return sum(len(meshes[n['mesh']]['primitives'])
               for n in doc.get('nodes', []) if 'mesh' in n)


def in_apk(glb):
    """Whether the same file already ships in godot/models."""
    return any((GODOT / 'models' / d / glb.name).exists()
               for d in ('obitel', 'lake', 'atlas', 'scene'))


_THINGS = {}


def thing(key):
    """A catalogue entry with what its proxy files say about it."""
    if key in _THINGS:
        return _THINGS[key]
    o = dict(reg.OBJECTS[key])
    glb, meta_path = proxy_paths(o['source'])
    o['key'] = key
    if glb is None:
        o.update({'state': 'pending-' + o['source'], 'tris': None,
                  'draws': 1, 'glb_bytes': 0, 'in_apk': False,
                  'proxy': None, 'method': None})
    else:
        assert glb.exists() and meta_path.exists(), (key, glb)
        meta = json.loads(meta_path.read_text(encoding='utf-8'))
        method = meta.get('method') or meta.get('detail')
        state = {'layered-svg-extrusion': 'card',
                 'flat-board': 'board'}.get(method, 'volume')
        if o['source'].startswith(('lake:', 'atlas:')) and not any(
                o['size_m']):
            bx = meta['bbox_m']
            o['size_m'] = [round(v, 3) for v in bx]
        o.update({'state': state, 'tris': meta['tris'],
                  'draws': glb_draws(glb),
                  'glb_bytes': glb.stat().st_size, 'in_apk': in_apk(glb),
                  'proxy': str(glb.relative_to(ROOT)), 'method': method,
                  'depth_m': meta['bbox_m'][2]})
    _THINGS[key] = o
    return o


# --- Scores and gates --------------------------------------------------------

def families(plots, inv):
    return sorted({inv['plots'][p]['family'] for p in plots},
                  key=FAMILIES.index)


def readable(p):
    shell = p['shell']
    score = SHELL_READ[shell]
    if any(r.startswith('loc-') for r in p['records']):
        score += 1
    if max(p['size_m'][:2]) > 16:
        score -= 1
    if p['sky'] == 'night' and shell in ('open', 'shore'):
        score -= 1
    return max(0, min(10, score))


def novelty(p):
    return 9 - EXISTS_PENALTY.get(p['exists'], 0)


def gate_reasons(p, inv, heart):
    out = []
    plots = [inv['plots'].get(x) for x in p['plots']]
    if not plots or None in plots:
        out.append('no-plot')
    elif all(x['rewrite'] for x in plots):
        out.append('plots-on-rewrite')
    if heart is None:
        out.append('heart')
    if p['safety'] < 7:
        out.append('safety')
    if readable(p) < 4:
        out.append('readable')
    if p['teach'] < 5:
        out.append('teaching')
    if p['truth'] < 4:
        out.append('truth')
    holy = [k for k in p['objects'] if reg.OBJECTS[k]['holy']]
    if p['light'][0] == 'lampada' and not holy:
        out.append('lampada-without-holy')
    if any(reg.OBJECTS[k]['source'] == 'raw' for k in holy):
        out.append('holy-from-raw')
    if len(holy) > 1:
        out.append('more-than-one-holy')
    return out


def pool(inv):
    loc_ids = {f.stem for f in (MODELS / 'loc').glob('*.json')}
    out = []
    for p in reg.PLACES:
        for r in p['records']:
            assert r in loc_ids, (p['id'], r)
        heart = heart_of(p['heart'], inv)
        score = {'truth': p['truth'], 'teaching': p['teach'],
                 'readable': readable(p), 'novelty': novelty(p),
                 'safety': p['safety']}
        reasons = gate_reasons(p, inv, heart)
        out.append(dict(p, heart_spec=p['heart'], heart=heart,
                        families=families(
                            [x for x in p['plots'] if x in inv['plots']],
                            inv),
                        score=score, total=sum(score.values()),
                        gate=not reasons, reasons=reasons))
    ids = [c['id'] for c in out]
    assert len(ids) == len(set(ids)), 'duplicate place id'
    return out


def built_plots():
    return {x for _ru, plots in reg.BUILT.values() for x in plots}


def select(cands, inv, k=K):
    ranked = sorted((c for c in cands if c['gate']),
                    key=lambda c: (-c['total'], c['id']))
    chosen, ids, per_kind = [], set(), Counter()

    def ok(c):
        return c['id'] not in ids and per_kind[c['kind']] < PER_KIND

    def take(c):
        chosen.append(c)
        ids.add(c['id'])
        per_kind[c['kind']] += 1

    for fam in FAMILIES:
        n = sum(1 for c in chosen if fam in c['families'])
        for c in ranked:
            if n >= MIN_FAMILY[fam]:
                break
            if fam in c['families'] and ok(c):
                take(c)
                n += 1
    have = built_plots()
    for pid in sorted((x for x in inv['plots'] if x.startswith('M')),
                      key=lambda x: int(x[1:])):
        if inv['plots'][pid]['rewrite'] or pid in have or any(
                pid in c['plots'] for c in chosen):
            continue
        for c in ranked:
            if pid in c['plots'] and ok(c):
                take(c)
                break
    assert len(chosen) <= k, 'minimums and coverage exceed K'
    for c in ranked:
        if len(chosen) >= k:
            break
        if ok(c):
            take(c)
    return chosen


# --- Layout on the standard ----------------------------------------------
#
# Coordinates of a location: x across, z from the back (-d/2) to the
# entrance (+d/2), y up, the floor (or the seabed) at y = 0.  The heart
# stands near the back wall of a room, yard or shore and in the middle
# of open ground or water; the passage runs from the entrance to the
# heart.  Every thing is a rectangle on the ground (its footprint,
# turned with the thing) or a thin rectangle on a wall; it must stay in
# the bounds, off the passage, 0.75 m from the heart and off the
# things already placed.  The order of the anchors is fixed, so the
# same data always gives the same place (TABOO 0.013 item 6).

GRID_M = 0.4
WALL_T = 0.1
BENCH_W = 0.6
TABLE_TOP = {'room': 0.8, 'cave': 0.8, 'yard': 0.8, 'shore': 0.45,
             'open': 0.45}


def _frange(a, b, step):
    out, x = [], a
    while x <= b + 1e-9:
        out.append(round(x, 3))
        x += step
    return out


def heart_point(shell, w, d):
    if shell in ('room', 'cave', 'yard', 'shore'):
        return (0.0, round(-d / 2 + min(1.6, d * 0.3), 3))
    return (0.0, 0.0)


def passage_rect(shell, w, d):
    hx, hz = heart_point(shell, w, d)
    half = ROV_PASS_HALF_M if shell == 'underwater' else PASS_HALF_M
    return (-half, hz, half, d / 2)


def _rect(x, z, fw, fd):
    return (x - fw / 2, z - fd / 2, x + fw / 2, z + fd / 2)


def _overlap(a, b):
    return a[0] < b[2] - 1e-9 and b[0] < a[2] - 1e-9 and \
        a[1] < b[3] - 1e-9 and b[1] < a[3] - 1e-9


def _dist_point_rect(px, pz, r):
    dx = max(r[0] - px, 0.0, px - r[2])
    dz = max(r[1] - pz, 0.0, pz - r[3])
    return math.hypot(dx, dz)


def rect_ok(shell, w, d, r, taken=(), ground=True):
    """A thing's rectangle is in bounds, clear of heart and passage."""
    hx, hz = heart_point(shell, w, d)
    if r[0] < -w / 2 - 1e-9 or r[2] > w / 2 + 1e-9 or \
            r[1] < -d / 2 - 1e-9 or r[3] > d / 2 + 1e-9:
        return False
    if _dist_point_rect(hx, hz, r) < CLEAR_M:
        return False
    if ground and _overlap(r, passage_rect(shell, w, d)):
        return False
    return not any(_overlap(r, t) for t in taken)


def footprint(o):
    """The ground a thing takes, (across, along), before turning."""
    w, _h, d = o['size_m']
    if o['state'] in ('card', 'board'):
        return (CARD_M, WALL_T)
    return (w, d)


def mount_of(o, shell):
    if o['holy']:
        return 'holy'
    if shell == 'underwater':
        return 'seabed'
    if o['state'] in ('card', 'board'):
        return 'stand' if shell in ('shore', 'open') else 'wall'
    w, h, d = o['size_m']
    if max(w, d) <= 0.45 and h <= 0.6:
        return 'table'
    return 'floor'


def wall_anchors(shell, w, d):
    """Cards hang on the side walls, back to front, then the back wall;
    on open ground and shores they stand on two posts at the edges."""
    out = []
    if shell in ('room', 'cave', 'yard'):
        y = 1.4 if shell == 'yard' else 1.5
        for z in _frange(-d / 2 + 0.6, d / 2 - 0.6, 0.8):
            out.append((-w / 2 + WALL_T / 2, y, z, 90))
            out.append((w / 2 - WALL_T / 2, y, z, -90))
        for x in _frange(-w / 2 + 0.6, w / 2 - 0.6, 0.8):
            out.append((x, y, -d / 2 + WALL_T / 2, 0))
    elif shell in ('shore', 'open'):
        for z in _frange(-d / 2 + 0.8, d / 2 - 0.8, 1.0):
            out.append((-w / 2 + 0.3, 1.35, z, 90))
            out.append((w / 2 - 0.3, 1.35, z, -90))
    return out


def ground_anchors(shell, w, d):
    """Floor points in a fixed order: nearest the edge first (things
    keep to the walls), under water on a ring 2.5 m round the heart."""
    pts = [(x, z) for x in _frange(-w / 2 + 0.2, w / 2 - 0.2, GRID_M)
           for z in _frange(-d / 2 + 0.2, d / 2 - 0.2, GRID_M)]
    if shell == 'underwater':
        def key(p):
            return (round(abs(math.hypot(*p) - 2.5), 3), p[1], p[0])
    else:
        def key(p):
            edge = min(w / 2 - abs(p[0]), d / 2 + p[1])
            return (round(edge, 3), p[1], p[0])
    return sorted(pts, key=key)


def holy_anchors(shell, w, d, form):
    """The one place of a holy thing: the red corner of a room, a
    standing place at the back of a yard, a shore or open ground, a
    ledge of the seabed; a vessel stands on the master's table."""
    if form == 'vessel':
        return [('table', -w / 2 + BENCH_W / 2, TABLE_TOP.get(shell, 0.0),
                 z, 0) for z in _frange(-d / 2 + 0.6, d / 2 - 1.0, 0.45)]
    if shell in ('room', 'cave'):
        return [('wall', x, 1.4, -d / 2 + WALL_T / 2, 0) for x in
                (w / 2 - 0.5, -w / 2 + 0.5)]
    if shell == 'underwater':
        return [('seabed', -2.5, 0.0, -2.5, 0),
                ('seabed', 2.5, 0.0, -2.5, 0)]
    return [('ground', x, 0.0, -d / 2 + 1.0, 0) for x in
            (w / 2 - 1.0, -w / 2 + 1.0)]


def _bench(shell, w, d):
    """The oak bench along the left wall, or a birch crate on open
    ground and shores: its rectangle on the ground."""
    if shell in ('room', 'cave', 'yard'):
        return (-w / 2, -d / 2 + 0.3, -w / 2 + BENCH_W, d / 2 - 0.8)
    return (-w / 2 + 1.2, -0.9, -w / 2 + 1.2 + BENCH_W, 0.9)


# Clear ground round the holy thing, on every layer.
HOLY_CLEAR_M = 0.3


def _grow(r, m):
    return (r[0] - m, r[1] - m, r[2] + m, r[3] + m)


def _turn(x, z, fw, fd, yaw):
    return _rect(x, z, fd, fw) if yaw in (90, -90) else \
        _rect(x, z, fw, fd)


def layout(c):
    """Place every wished thing; the heart's own thing stands at it.

    Three layers do not collide with each other: thin things on the
    walls (or on two posts outdoors), things on the bench top, and
    things on the ground (the bench itself is on the ground)."""
    w, d = c['size_m'][0], c['size_m'][1]
    shell = c['shell']
    hx, hz = heart_point(shell, w, d)
    own = heart_thing(c['heart_spec'])
    things = [(k, thing(k)) for k in c['objects']]
    layers = {'wall': [], 'top': [], 'ground': []}
    bench = None
    if shell != 'underwater' and any(
            mount_of(o, shell) == 'table' or o['holy'] == 'vessel'
            for _k, o in things):
        bench = _bench(shell, w, d)
        layers['ground'].append(bench)

    # The holy thing keeps a clear margin to every other thing, whatever
    # its layer (TABOO 0.013 p. 5: only on its own place): the review of
    # 2026-09-30 found the silversmith's chalice card overlapping the
    # silver-ingot card on the wall behind it.
    holy_clear = []

    def clear_of_holy(r):
        return not any(_overlap(r, h) for h in holy_clear)

    def on_wall(fw, fd):
        for x, y, z, yaw in wall_anchors(shell, w, d):
            r = _turn(x, z, fw, fd, yaw)
            if rect_ok(shell, w, d, r, layers['wall'], ground=False) \
                    and clear_of_holy(r):
                mount = 'wall' if shell in ('room', 'cave', 'yard') \
                    else 'stand'
                return ('wall', mount, x, y, z, yaw, r)
        return None

    def on_top(fw, fd):
        if bench is None:
            return None
        x = (bench[0] + bench[2]) / 2
        for z in _frange(bench[1] + 0.25, bench[3] - 0.25, 0.45):
            r = _rect(x, z, fw, fd)
            if r[0] >= bench[0] - 1e-9 and r[2] <= bench[2] + 1e-9 and \
                    rect_ok(shell, w, d, r, layers['top'], ground=False) \
                    and clear_of_holy(r):
                return ('top', 'table', x, TABLE_TOP[shell], z, 0, r)
        return None

    def on_ground(fw, fd):
        mount = 'seabed' if shell == 'underwater' else 'floor'
        for x, z in ground_anchors(shell, w, d):
            for yaw in (0, 90):
                r = _turn(x, z, fw, fd, yaw)
                if rect_ok(shell, w, d, r, layers['ground']) and \
                        clear_of_holy(r):
                    return ('ground', mount, x, 0.0, z, yaw, r)
        return None

    def on_holy(o, fw, fd):
        for where, x, y, z, yaw in holy_anchors(shell, w, d, o['holy']):
            layer = {'wall': 'wall', 'table': 'top'}.get(where, 'ground')
            if where == 'table' and bench is None:
                continue
            r = _turn(x, z, fw, fd, yaw)
            near = _grow(r, HOLY_CLEAR_M)
            if rect_ok(shell, w, d, r, layers[layer],
                       ground=layer == 'ground') and not any(
                    _overlap(near, t) for lay in layers.values()
                    for t in lay if t is not bench):
                return (layer, 'holy', x, y, z, yaw, r)
        return None

    placed, unplaced = [], []
    for key, o in things:
        fw, fd = footprint(o)
        mount = mount_of(o, shell)
        if key == own:
            got = ('heart', 'heart', hx, 0.0, hz, 0,
                   _rect(hx, hz, fw, fd))
        elif o['holy']:
            got = on_holy(o, fw, fd)
        elif mount in ('wall', 'stand'):
            got = on_wall(fw, fd) or on_ground(fw, fd)
        elif mount == 'table':
            got = on_top(fw, fd) or on_ground(fw, fd)
        else:
            got = on_ground(fw, fd)
        if got is None:
            unplaced.append(key)
            continue
        layer, mount, x, y, z, yaw, r = got
        if layer in layers:
            layers[layer].append(r)
        if mount == 'holy':
            holy_clear.append(_grow(r, HOLY_CLEAR_M))
        placed.append({'object': key, 'mount': mount,
                       'pos': [round(x, 3), round(y, 3), round(z, 3)],
                       'yaw': yaw, 'rect': [round(v, 3) for v in r]})
    return {'heart_at': [hx, 0.0, hz], 'entrance': [0.0, 0.0, d / 2],
            'passage': [round(v, 3) for v in passage_rect(shell, w, d)],
            'bench': [round(v, 3) for v in bench] if bench else None,
            'placed': placed, 'unplaced': unplaced}


# --- Budget (TABOO 0.011) --------------------------------------------------

def budget(c, plan):
    """Draw calls and triangles of the location, from the proxy files.

    A drawn card (layered SVG extrusion) keeps one surface per SVG
    layer: the ledger alone is 85 draw calls.  as_is counts them so;
    merged counts a card as one surface (its layers joined with vertex
    colours, HLD phase L2), which is what a built location must carry.
    The shell, the bench or crate, the light and the heart's figure are
    counted too, and a name tag per ordinary thing.
    """
    parts = SHELL_PARTS[c['shell']]
    table = plan['bench'] is not None
    base = parts + (3 if table else 0) + 1 + 1
    as_is = merged = base
    tris_known = parts * 12 + (36 if table else 0)
    pending = 0
    glb_new = 0
    for p in plan['placed']:
        o = thing(p['object'])
        tag = 0 if o['holy'] else 1
        as_is += o['draws'] + tag
        merged += (1 if o['state'] == 'card' else o['draws']) + tag
        if o['tris'] is None:
            pending += 1
        else:
            tris_known += o['tris']
            if not o['in_apk']:
                glb_new += o['glb_bytes']
    worst = tris_known + pending * PENDING_TRIS
    return {'draw_calls_as_is': as_is, 'draw_calls_merged': merged,
            'tris_known': tris_known, 'tris_worst': worst,
            'pending_things': pending, 'new_glb_bytes': glb_new,
            'ok_as_is': as_is <= MAX_DRAWS,
            'ok': merged <= MAX_DRAWS and 2 * worst <= MAX_TRIS_TWO_EYES}


# --- The props store: what the 99 repos can give --------------------------

def raw_hits(index_dir):
    """Search the index once for every wished thing's keywords."""
    sys.path.insert(0, str(ROOT / 'scripts' / 'raw_assets'))
    import osint_cycle
    import search_index
    words = {}
    for key, o in sorted(reg.OBJECTS.items()):
        if o['holy'] or not o['en']:
            continue
        words[key] = [tuple(w) if isinstance(w, (list, tuple)) else (w,)
                      for w in o['en']]
    found = {key: {'images': 0, 'models': 0, 'repos': set(),
                   'examples': []} for key in words}
    token = re.compile(r'[a-z]+')
    for header, records in search_index.load_index(index_dir):
        if not header['license_file']:
            continue
        repo = header['repo'].split('github.com/')[-1]
        # A word that names the repository says nothing about the
        # thing: every path of Card-Forge/forge holds "forge".
        own = set(token.findall(repo.lower()))
        for rec in records:
            if rec['kind'] not in ('image', 'model'):
                continue
            path = rec['path']
            if osint_cycle.DOGMA_STOP.search(path) or \
                    osint_cycle.SACRED.search(path):
                continue
            toks = set(token.findall(path.lower())) - own
            plural = toks | {t[:-1] for t in toks if t.endswith('s')} | \
                {t[:-2] for t in toks if t.endswith('es')}
            for key, alts in words.items():
                if any(all(w in plural for w in alt) for alt in alts):
                    f = found[key]
                    f['images' if rec['kind'] == 'image' else 'models'] += 1
                    f['repos'].add(repo)
                    if len(f['examples']) < 3:
                        f['examples'].append('%s:%s (%s)' % (
                            repo, path, header['license_file']))
    out = {}
    for key, f in found.items():
        out[key] = {'images': f['images'], 'models': f['models'],
                    'repos': len(f['repos']), 'examples': f['examples']}
    return {'note': 'Hits of each wished thing in the index of the 99 '
                    'cloned repos (images and 3D models; licensed repos '
                    'only; dogma stop-list and holy words refused). A hit '
                    'is a candidate for the props store (TABOO 0.012), '
                    'not a thing in a scene: that needs the pipeline of '
                    'TABOO 0.1 and an eye check.',
            'index': str(index_dir), 'things': out}


def load_raw_hits():
    if RAW_HITS.exists():
        return json.loads(RAW_HITS.read_text(encoding='utf-8'))['things']
    return {}


# --- Build -----------------------------------------------------------------

def constitution(c):
    n = len([k for k in c['objects'] if not reg.OBJECTS[k]['holy']])
    light = c['light']
    return ('ФОРМА: %s — %s, %d К, %d настоящих вещей → ДЕЙСТВИЕ: %s → '
            'ЦЕЛЬ: %s' % (c['title_ru'], light[2], light[1], n,
                          c['heart']['ru'], c['lesson']))


def thing_record(key, hits):
    """One wished thing as the data file keeps it (once for all)."""
    o = thing(key)
    h = hits.get(key)
    return {'ru': o['ru'], 'size_m': o['size_m'],
            'material': o['material'], 'source': o['source'],
            'state': o['state'], 'tris': o['tris'], 'draws': o['draws'],
            'in_apk': o['in_apk'],
            # Images and 3D models the index of the 99 repos holds under
            # the thing's words: candidates for the props store only.
            'raw_store': None if h is None else [h['images'], h['models'],
                                                 h['repos']],
            'holy': o['holy']}


def location(c, inv):
    plan = layout(c)
    holy = [k for k in c['objects'] if reg.OBJECTS[k]['holy']]
    holy_place = None
    if holy:
        o = thing(holy[0])
        holy_place = {'thing': holy[0], 'ru': o['ru'],
                      'form': o['holy'], 'state': o['state'],
                      'lampada': c['light'][0] == 'lampada',
                      'noInteract': True, 'noLoot': True, 'tag': False}
    return {
        'id': c['id'], 'title_ru': c['title_ru'], 'kind': c['kind'],
        'families': c['families'], 'plots': c['plots'],
        'heart': c['heart'],
        'light': {'class': c['light'][0], 'kelvin': c['light'][1],
                  'source_ru': c['light'][2], 'sky': c['sky']},
        'shell': {'type': c['shell'], 'size_m': c['size_m'],
                  'heart_at': plan['heart_at'],
                  'entrance': plan['entrance'],
                  'passage': plan['passage'], 'bench': plan['bench']},
        # The rectangle each thing takes is not stored: the headset's
        # test recomputes it from the position, the turn and the size,
        # so the check does not trust this script.
        'slots': [{k: v for k, v in p.items() if k != 'rect'}
                  for p in plan['placed']],
        'unplaced': plan['unplaced'], 'wishlist': list(c['objects']),
        'holy_place': holy_place, 'budget': budget(c, plan),
        'score': c['score'], 'total': c['total'],
        'constitution': constitution(c), 'lesson': c['lesson'],
        'sources': c['records'], 'note': c['note'],
        'exists': c['exists']}


def coverage(chosen, inv):
    new = {p for c in chosen for p in c['plots']}
    have = built_plots()
    pooled = {p for c in reg.PLACES for p in c['plots']}
    out = {}
    for pid in inv['plots']:
        out[pid] = ('new' if pid in new else 'built' if pid in have
                    else 'pool' if pid in pooled else 'none')
    return out


def build(inv=None):
    inv = inv or inventory()
    cands = pool(inv)
    chosen = select(cands, inv)
    locs = [location(c, inv) for c in
            sorted(chosen, key=lambda c: (FAMILIES.index(c['families'][0]),
                                          c['id']))]
    return inv, cands, chosen, locs


def data_text(inv, cands, locs):
    """The data file, one location or thing per line: small in the APK,
    and a change to one location is one line of the diff."""
    cov = coverage([c for c in cands if c['id'] in
                    {x['id'] for x in locs}], inv)
    hits = load_raw_hits()
    keys = sorted({k for x in locs for k in x['wishlist']})
    head = json.dumps({
        'note': 'The 99 locations of our plots on the standard of the '
                'evening-watch cell (CLAUDE.md TABOO 0.013); generated by '
                'scripts/locations/locations_99.py (TABOO 0.07). The next '
                'phases build them; this file is the specification.',
        'plot_units': inv['counts']['plot_units'],
        'pool_size': len(cands),
        'gated': sum(1 for c in cands if c['gate']),
        'k': len(locs),
        'coverage': dict(sorted(Counter(cov.values()).items()))},
        ensure_ascii=False)
    rows = ',\n'.join(json.dumps(x, ensure_ascii=False,
                                 separators=(',', ':')) for x in locs)
    things = ',\n'.join('%s:%s' % (
        json.dumps(k), json.dumps(thing_record(k, hits), ensure_ascii=False,
                                  separators=(',', ':'))) for k in keys)
    return (head[:-1] + ',\n"things":{\n' + things + '\n},\n"locations":[\n'
            + rows + '\n]}\n')


def pool_text(cands):
    rows = []
    for c in sorted(cands, key=lambda c: (-c['total'], c['id'])):
        rows.append({'id': c['id'], 'title_ru': c['title_ru'],
                     'kind': c['kind'], 'families': c['families'],
                     'plots': c['plots'], 'heart': c['heart_spec'],
                     'records': c['records'], 'score': c['score'],
                     'total': c['total'], 'gate': c['gate'],
                     'reasons': c['reasons'], 'note': c['note']})
    return json.dumps({'note': 'Every candidate place of our plots, '
                               'scored (TABOO 0.07).',
                       'size': len(cands), 'candidates': rows},
                      ensure_ascii=False, indent=1) + '\n'


def _cell(text):
    return str(text).replace('|', '/').replace('\n', ' ')


def doc_text(inv, cands, chosen, locs):
    cnt = inv['counts']
    cov = coverage(chosen, inv)
    fam_n = Counter(f for x in locs for f in x['families'])
    gated = [c for c in cands if c['gate']]
    reasons = Counter(r for c in cands for r in c['reasons'])
    hearts = Counter(x['heart']['core'] for x in locs)
    new_actions = sorted({x['heart']['id'] for x in locs
                          if x['heart']['core'] == 'new'})
    records = {r for c in cands for r in c['records']}
    draws = [x['budget']['draw_calls_merged'] for x in locs]
    as_is = [x['budget']['draw_calls_as_is'] for x in locs]
    over = sorted(x['id'] for x in locs if not x['budget']['ok_as_is'])
    worst = [x['budget']['tris_worst'] for x in locs]
    known = [x['budget']['tris_known'] for x in locs]
    glb_new = {}
    for x in locs:
        for s in x['slots']:
            o = thing(s['object'])
            if o['proxy'] and not o['in_apk']:
                glb_new[o['proxy']] = o['glb_bytes']
    raw = load_raw_hits()
    wished = sorted({k for x in locs for k in x['wishlist']})
    raw_src = [k for k in wished if reg.OBJECTS[k]['source'] == 'raw']
    with_hits = [k for k in wished if raw.get(k) and (
        raw[k]['images'] + raw[k]['models'])]
    lines = [
        '# 99 локаций по нашим сюжетам: из N — K (ТАБУ №0.013, №0.07)', '',
        'Генератор: `scripts/locations/locations_99.py` (реестр — '
        '`scripts/locations/register.py`). Данные: '
        '`godot/data/locations-99.json`. Пул: '
        '`docs/LOCATIONS_99_POOL.json`. HLD: '
        '`docs/HLD_LOCATIONS_99_2026-09-30.md`. Эталон места — келья '
        'вечернего дозора (`godot/scripts/rule_cell.gd`, '
        '`godot/scripts/obitel_layout.gd`, `godot/tests/test_obitel.gd`).',
        '', '## Сколько у нас сюжетов на самом деле', '',
        'Оператор сказал «299». Счёт по источникам репозитория:', '',
        '| Источник | Единиц | Откуда |', '|---|---|---|',
        '| Кампания: миссии (7 актов) | %d (из них %d на переписке хора) '
        '| `godot/data/campaign-spine.json` |' % (
            cnt['missions'], cnt['missions_rewrite']),
        '| «Атлас воды»: узлы | %d (внутри: выбор летописи из %d '
        'вариантов, %d следов) | `scripts/story/atlas_nodes.py` |' % (
            cnt['atlas_nodes'], cnt['atlas_chronicle_options'],
            cnt['atlas_traces']),
        '| «Киберслав»: узлы | %d | `docs/kiberslav/KIBERSLAV_SYNOPSIS_'
        'AV_5_EDITORS.md` |' % cnt['kiberslav_nodes'],
        '| «Сон послушника»: миссии | %d объявлены, %d расписаны | '
        '`docs/kiberslav/STYLE_BIBLE_LUDUS_KIBERSLAV.md` §6 |' % (
            cnt['dream_missions_declared'], cnt['dream_missions_written']),
        '| Задачи погружения | %d | `godot/scripts/dive_core.gd` TASKS |'
        % cnt['dive_tasks'],
        '| Сцены тропы свидетеля | %d | `godot/scripts/witness_core.gd` |'
        % cnt['witness_scenes'],
        '| Пороги врат (сцены) | %d | `godot/data/gate-trials.json` |'
        % cnt['thresholds'],
        '| Встречи страстей на дороге | %d | `godot/data/passions.json` |'
        % cnt['passions'],
        '| **Итого сюжетных единиц** | **%d** (%d, если не считать '
        'нерасписанные миссии сна) | |' % (
            cnt['plot_units'], cnt['plot_units_written']), '',
        'Не сюжеты, а их материал или механика: %d практик правила '
        '(`rule_core.gd`, это сердца мест), %d линий матрицы '
        '`STORYLINES_99_ASSET_MATRIX.md` (те же %d миссий), %d записей '
        '«локация» в промтах, %d прокси локаций, %d файлов лора '
        '(`lore/`, %d строк — сырой текст, из которого сделаны миссии).'
        % (cnt['practices'], cnt['matrix_storylines'], cnt['missions'],
           cnt['prompt_places'], cnt['loc_proxies'], cnt['lore_files'],
           cnt['lore_lines']), '',
        '**Честный ответ на «299».** Трёх списков по 99 (кампания, Атлас, '
        'Киберслав) — %d, а не 299; всех сюжетных единиц — %d. Число не '
        'подгонялось ни вверх, ни вниз.' % (
            cnt['three_lists'], cnt['plot_units']), '',
        '## Пул мест и его настоящий размер', '',
        '- Место — точка, где можно стоять: келья, угол скриптория, кузня, '
        'пристань, берег, караван-сарай, брод, стоянка, пещера, шельф, '
        'затопленный посад, ворота Сиса, берег Светлояра.',
        '- Честный пул N = **%d** мест, в которых происходит хотя бы один '
        'наш сюжет. Доказательства места — %d записей прокси локаций '
        '(рисунки SVG и промты) и тексты сюжетов.' % (
            len(cands), len(records)),
        '- Уже есть в шлеме и в пул не входят (их сюжеты считаются '
        'покрытыми): %s.' % ', '.join(ru for ru, _p in reg.BUILT.values()),
        '- Проходят ворота: **%d**. Отсеяны: %s.' % (
            len(gated), ', '.join('%s — %d' % kv for kv in
                                  sorted(reasons.items()))),
        '- Выбрано K = **%d** (не больше %d мест одного вида, одно место '
        '— одна локация; минимум по семьям сюжетов).' % (len(locs),
                                                         PER_KIND), '',
        'Критерии 0–10: правда (реальное место или тип Семиречья и '
        'Иссык-Куля XIV в., Киликии 1375 г., экспедиции 2026 г.; гипотеза, '
        'предание и сон — ниже), учительная связь (одно сердце: ФОРМА → '
        'ДЕЙСТВИЕ → ЦЕЛЬ), читаемость в шлеме (считается по оболочке: '
        'комната 8, пещера и двор 7, берег и подводное место 6, открытое '
        'место 5; +1 за нарисованный задник, −1 за размер больше 16 м и '
        'за ночь под открытым небом), новизна (9; −4, если в хабе или на '
        'тропе уже есть такое место, −3, если оно есть в погружении), '
        'безопасность (святое не лут и не ключ; таинства — только '
        'свидетелем). Порядок детерминирован.', '',
        '## K: 99 локаций', '',
        '| # | Локация | Вид | Семьи | Сюжеты | Сердце | Свет | Святыня | '
        'П | У | Ч | Н | Б | Итог |',
        '|---|---|---|---|---|---|---|---|---|---|---|---|---|---|']
    for i, x in enumerate(locs, 1):
        s = x['score']
        h = x['heart']
        hid = h.get('npc', '') + '/' + h.get('node', '') if \
            h.get('step') == 'dialogue' else h.get('trace') or \
            h.get('object') or h['id']
        lines.append('| %d | %s | %s | %s | %s | %s `%s` | %s %d K | %s | '
                     '%d | %d | %d | %d | %d | %d |' % (
                         i, _cell(x['title_ru']), x['kind'],
                         ', '.join(FAMILY_RU[f] for f in x['families']),
                         ', '.join(x['plots']), h['core'], hid,
                         x['light']['class'], x['light']['kelvin'],
                         _cell(x['holy_place']['ru']) if x['holy_place']
                         else '—', s['truth'], s['teaching'],
                         s['readable'], s['novelty'], s['safety'],
                         x['total']))
    lines += [
        '', '## Семьи сюжетов и покрытие', '',
        '| Семья | Локаций в K | Минимум |', '|---|---|---|']
    for f in FAMILIES:
        lines.append('| %s | %d | %d |' % (
            FAMILY_RU[f], fam_n[f], MIN_FAMILY[f]))
    cv = Counter(cov.values())
    miss = sorted((p for p, v in cov.items() if v in ('pool', 'none')
                   and p.startswith('M')
                   and not inv['plots'][p]['rewrite']),
                  key=lambda p: int(p[1:]))
    rewrite = sorted((p for p in inv['plots'] if p.startswith('M')
                      and inv['plots'][p]['rewrite']),
                     key=lambda p: int(p[1:]))
    lines += [
        '', 'Сюжетные единицы: в новых локациях — %d, в уже построенных '
        'местах — %d, только в пуле (не вошли в K) — %d, без места — %d '
        '(монтаж, звук, правила, рамка: им место не нужно или оно — весь '
        'мир).' % (cv['new'], cv['built'], cv['pool'], cv['none']),
        '- Миссии кампании без места в K и в хабе: %s.' % (
            ', '.join(miss) if miss else 'нет'),
        '- Миссии на переписке хора (не запускаются, место не '
        'обязательно): %s.' % ', '.join(rewrite), '',
        '## Сердца', '',
        '- По ядрам: %s.' % ', '.join(
            '%s — %d' % kv for kv in sorted(hearts.items())),
        '- Новых малых действий (логику писать и покрывать тестом): %d — '
        '%s.' % (len(new_actions), ', '.join(new_actions)), '',
        '## Бюджет каждой локации (ТАБУ №0.011, план по файлам прокси)',
        '',
        '- Вызовы отрисовки на локацию, если поставить прокси как есть: '
        'от %d до %d (предел %d, пол Quest 2 из черновика ворот 55849b7). '
        'Карточка-рисунок SVG несёт по поверхности на каждый слой '
        '(приходная книга — 85), поэтому как есть предел превышают %d '
        'локаций: %s.' % (min(as_is), max(as_is), MAX_DRAWS, len(over),
                          ', '.join(over)),
        '- После слияния слоёв каждой карточки в одну поверхность '
        '(цвета вершин; фаза L2 HLD) — от %d до %d вызовов на локацию: все '
        'в пределе. Строить локацию до слияния нельзя (ТАБУ №0.011 п. 4).'
        % (min(draws), max(draws)),
        '- Треугольники известных прокси: от %d до %d; худший случай с '
        'вещами, которые ещё предстоит сделать (по %d на вещь): до %d '
        '(предел на два глаза %d).' % (
            min(known), max(known), PENDING_TRIS, max(worst),
            MAX_TRIS_TWO_EYES),
        '- Новые файлы моделей в APK, если поставить все прокси: %d шт., '
        '%.2f МБ.' % (len(glb_new), sum(glb_new.values()) / 1e6),
        '- Этот коммит кладёт в APK только `godot/data/locations-99.json`'
        ' (размер — в HLD, фаза L1). Частота кадров и память — только в '
        'самом Quest 3 (ТАБУ №0.02 п. 4).', '',
        '## Предметы и 99 репо (ТАБУ №0.012)', '',
        '- Вещей в списках желаний: %d; из них прокси уже есть у %d, свои '
        'рисунки нужны %d, из склада реквизита (99 репо) ждут %d.' % (
            len(wished),
            sum(1 for k in wished if thing(k)['proxy']),
            sum(1 for k in wished if reg.OBJECTS[k]['source'] == 'own'),
            len(raw_src)),
        '- Поиск по индексу 99 репо нашёл кандидатов для %d вещей из %d '
        '(%s). Кандидат — это склад, а не сцена: в сцену вещь идёт только '
        'через конвейер ТАБУ №0.1 (35 %%, 12 вариаций, проверка глазами).'
        ' Урок D6: нейтральные вещи теряли узнаваемость в вариациях '
        'антагонистов, поэтому для узнаваемой вещи первым идёт свой '
        'рисунок или прокси.' % (
            len(with_hits), len(wished) - sum(
                1 for k in wished if reg.OBJECTS[k]['holy']),
            'снимок `docs/LOCATIONS_99_RAW_HITS.json`' if raw
            else 'индекс не читался'),
        '- Попадание — это совпадение слова в пути файла, а не проверенная '
        'вещь: среди них много шума (ствол турели вместо бочки, пики '
        'игральных карт вместо лопаты, жгут теста вместо верёвки), а '
        'настоящие тоже есть (клещи и корзина widelands). Отбор глазами '
        'на контактном листе — фаза L5 HLD.',
        '- Святыни из сырья не берутся: только свои рисунки или прокси '
        'из `SVG/`, плоско, `noInteract`/`noLoot`, без бирки.', '',
        '## Что проверить специалисту до релиза', '']
    for x in locs:
        if x['note']:
            lines.append('- **%s** (`%s`): %s' % (x['title_ru'], x['id'],
                                                  x['note']))
    lines += [
        '- Богослову и хору 12: каждое место со святыней (столбец '
        '«Святыня») — её ли это место; сердце-практика не превращает '
        'святыню в ключ; «Посул на дороге» у страстей имеет признак '
        'распознавания у наставника.',
        '- Историку-этнографу Семиречья: виды мест «рабат», «фактория», '
        '«ставка», «диван» для 1375 г.; армянские братья на Иссык-Куле — '
        'по Каталанскому атласу, место обители — гипотеза.',
        '- Гидроакустику: подводные места стоят на поясах погружения '
        '(шельф, свал, термоклин на 50 м, глубина до 668 м).', '',
        '## Отсеянные кандидаты', '']
    for c in sorted(cands, key=lambda c: c['id']):
        if not c['gate']:
            lines.append('- `%s` %s — %s%s' % (
                c['id'], c['title_ru'], ', '.join(c['reasons']),
                ('; ' + c['note']) if c['note'] else ''))
    lines.append('')
    return '\n'.join(lines)


def main(argv):
    if '--index' in argv:
        index_dir = argv[argv.index('--index') + 1]
        RAW_HITS.write_text(json.dumps(raw_hits(index_dir),
                                       ensure_ascii=False, indent=1)
                            + '\n', encoding='utf-8')
    inv, cands, chosen, locs = build()
    data = data_text(inv, cands, locs)
    pool_json = pool_text(cands)
    doc = doc_text(inv, cands, chosen, locs)
    assert len(data.encode('utf-8')) <= MAX_FILE_BYTES, 'data > 1 MiB'
    if '--check' in argv:
        stale = [p.name for p, t in ((OUT_DATA, data), (OUT_POOL, pool_json),
                                     (OUT_DOC, doc))
                 if not p.exists() or p.read_text(encoding='utf-8') != t]
        print('locations-99:', 'STALE ' + ', '.join(stale) if stale
              else 'up to date')
        return 1 if stale else 0
    OUT_DATA.write_text(data, encoding='utf-8')
    OUT_POOL.write_text(pool_json, encoding='utf-8')
    OUT_DOC.write_text(doc, encoding='utf-8')
    cnt = inv['counts']
    print('plot units %d (three lists %d), pool %d, gated %d, chosen %d'
          % (cnt['plot_units'], cnt['three_lists'], len(cands),
             sum(1 for c in cands if c['gate']), len(locs)))
    print('families', dict(Counter(f for x in locs
                                   for f in x['families'])))
    print('data bytes', len(data.encode('utf-8')))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
