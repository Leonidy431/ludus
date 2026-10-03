"""Choose the 12 stories the headset walks on foot (TABOO 0.07).

A story is one mission of the campaign (MissionCore, the port of
public/ludus/ludus-missions.js) walked through the hearts of the 99
places instead of read on the board of the courtyard
(docs/HLD_12_STORIES_HEADSET_2026-10-02.md, phase S4, track D).

The method is the object selection technology of the project
(docs/OBJECT_SELECTION_TECHNOLOGY.md):

1. Register of the real: the 99 missions as the JS reference builds them
   (godot/tests/fixtures/missions.json, the shape MissionCore is tested
   against), the 99 places (godot/data/locations-99.json) and the real
   objects of the lake (godot/data/lake-objects-99.json).
2. Honest pool: a mission enters the pool only if each of its four
   steps has a place that is built and hosts it:
     find      - a place whose heart is that find, or a place where the
                 object stands as one of its things, or else the dive
                 (the object lies on the floor of the dive scene);
     practice  - a place whose heart is that deed of the rule;
     dialogue  - a place whose heart is that person (the mentor stands
                 at the heart, scripts/mentors.gd);
     dive      - an object the dive scene places (not a fish shoal, not
                 the tether), reached from a place whose heart is the
                 dive.
   A holy object is never a step's key (TABOO 0.2, 0.4 item 1): such a
   mission stays out of the pool.  A place of the dream of Kiberslav is
   not a station of the caravan road (TABOO 0.03, 0.38): it is not used.
   The pool is counted, never padded.
3. Five open criteria, 0-10, scored here in code: truth, teaching,
   readability in the headset, novelty, safety.
4. Selection with diversity: the prologue first, at least one story of
   every act, at most two of one act, no two stories with the same four
   steps.  Ties are broken by the order of the campaign; nothing random.
5. Output: godot/data/story-12.json (the routes the headset walks) and
   docs/STORY_12_SELECTION_2026-10-02.md (the table for the operator).

  python3 scripts/story/select_12.py           write both files;
  python3 scripts/story/select_12.py --check   fail if either is stale.

Constitution: FORM (the mission's places, people, things and water) ->
ACTION (the player walks from the board to each place and does the step
at its heart) -> GOAL (the act's teaching is lived in the headset, not
read on a board).
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / 'godot/tests/fixtures/missions.json'
SPINE = ROOT / 'godot/data/campaign-spine.json'
LOCATIONS = ROOT / 'godot/data/locations-99.json'
LAKE = ROOT / 'godot/data/lake-objects-99.json'
TREES = ROOT / 'godot/data/dialogue-trees.json'
OUT = ROOT / 'godot/data/story-12.json'
DOC = ROOT / 'docs/STORY_12_SELECTION_2026-10-02.md'
DATE = '2026-10-02'
K = 12
PER_ACT_MAX = 2

# The deed of the rule that answers the passion of an act (Ladder:
# fasting against gluttony, alms against avarice, the hidden deed against
# vainglory, forgiveness against anger, obedience against pride).
OPPOSES = {'gluttony': 'fast', 'avarice': 'alms', 'vainglory': 'secret_deed',
           'anger': 'forgive', 'pride': 'obedience'}
# The labels of MissionCore.PRACTICE_RU; tests/test_story_12.gd checks
# that every story's Constitution line carries the label the game shows.
PRACTICE_RU = {
    'alms': 'Подать милостыню',
    'forgive': 'Простить обиду',
    'obedience': 'Исполнить послушание наставника',
    'fast': 'Сохранить сегодняшний пост',
    'secret_deed': 'Сделать доброе тайно',
}
# The GOAL of a story's Constitution line is the teaching against its
# passion, from the step of the Ladder that treats that passion (the
# same step public/ludus/data/passions.json names in `ladder`).
# Patrologist of the chorus, 2026-10-03: prejudice «the act's teaching
# is the story's goal» / counter: missions 73 and 78 fight pride but
# cited a saying on acedia, and mission 3 fights gluttony but cited
# step 3 (exile) / why: the goal answers the passion the player meets,
# so the source and the passion are one; scripts/check_canon.py reads
# these lines in story-12.json and checks the step against the canon.
PASSION_GOAL_RU = {
    'gluttony': 'чрево держат постом, чтобы ум был трезв: пост — мера, '
                'а не голод (Лествица, слово 14)',
    'lust': 'чистоту хранят, отворачивая взгляд от посула прежде, чем '
            'он стал мыслью (Лествица, слово 15)',
    'avarice': 'кто держится за серебро, тот служит ему; нестяжатель '
               'свободен, и мера его честна (Лествица, слова 16–17)',
    'sadness': 'печаль мира губит, а плач о своём деле приносит радость '
               'и утешение (Лествица, слово 7)',
    'anger': 'кротость не двигается ни от обиды, ни от похвалы; гнев '
             'гасят молчанием и прощением (Лествица, слово 8)',
    'acedia': 'уныние гонит из кельи; терпение остаётся и делает дело '
              'рук, день за днём (Лествица, слово 13)',
    'vainglory': 'тщеславие крадёт доброе дело похвалой; доброе делают '
                 'тайно (Лествица, слово 22)',
    'pride': 'гордость не принимает совета; смирение слушает наставника '
             'и не считает своих дел (Лествица, слово 23)',
}
# Where the dive of a band is begun when no place shows the object
# itself: the dive place whose task lies in that band.
DIVE_BY_BAND = {'shallows': 'sunken-chapel', 'shelf': 'drowned-posad',
                'slope': 'canyon', 'thermocline': 'canyon',
                'deep': 'canyon'}
HOW_RU = {'heart': 'сердце места', 'thing': 'вещь места, у сердца',
          'dive': 'спуск аппарата от сердца места'}
KIND_RU = {'find': 'находка', 'practice': 'дело', 'dialogue': 'разговор',
           'dive': 'погружение'}
# A mission whose title is about another confession, a cult or a holy
# rite is walked in the headset only after the chorus of 12 has read it
# (TABOO 0.37, 0.2): its safety falls by 5, so it is not taken while a
# plainer mission of its act is there.
CHORUS_STEMS = ['шаман', 'униат', 'унитор', 'несториан', 'папе',
                'синкрет', 'освящен', 'фантом', 'реликв', 'мощ', 'обряд']
CRITERIA = ['truth', 'teaching', 'readable', 'novelty', 'safety']


def load(path):
    return json.loads(path.read_text(encoding='utf-8'))


def lake_id(source):
    """The lake object a place's thing shows, or ''."""
    return source[5:] if source.startswith('lake:') else ''


def dive_ok(obj):
    """Whether the dive scene places this object (DiveCore.place_objects
    leaves out fish shoals and the tether)."""
    return obj is not None and obj['category'] != 'fish' \
        and obj['item'] != 'tether'


def is_holy(obj):
    return obj is not None and bool(obj['flags'].get('holy'))


class World:
    """The register of the real, read once."""

    def __init__(self):
        self.build = {b['id']: b['out'] for b in load(BUILD)['build']}
        spine = load(SPINE)
        self.order = [int(i) for i in spine['order']]
        self.chorus = {int(m['id']) for m in spine['needsChorusRewrite']}
        self.act_ru = {a['id']: a['title_ru'] for a in spine['acts']}
        locs = load(LOCATIONS)
        self.things = locs['things']
        self.places = [p for p in locs['locations']
                       if 'kiberslav' not in p['families']]
        self.by_id = {p['id']: p for p in locs['locations']}
        self.lake = {o['id']: o for o in load(LAKE)['objects']}
        self.trees = load(TREES)['trees']
        dive_places = {p['id'] for p in self.places
                       if p['heart'].get('core') == 'DiveCore'}
        assert set(DIVE_BY_BAND.values()) <= dive_places, dive_places
        self.dive_places = sorted(dive_places)

    def shows(self, place, obj_id):
        return any(lake_id(self.things[s['object']]['source']) == obj_id
                   for s in place['slots'])

    def place_score(self, place, mission, act):
        """How well a place belongs to this mission: its plots name the
        mission, its families hold the mission's act (or the dive)."""
        score = 0
        if 'M%d' % mission in place['plots']:
            score += 3
        if act in place['families']:
            score += 2
        return score

    def best(self, cands, mission, act):
        """The best (place, how, plot hit, family hit) of candidates
        [(place, how, bonus)]; ties go to the place id (deterministic)."""
        if not cands:
            return None
        ranked = sorted(cands, key=lambda c: (
            -(self.place_score(c[0], mission, act) + c[2]), c[0]['id']))
        p, how, _ = ranked[0]
        return {'place': p['id'], 'how': how,
                'plot': 'M%d' % mission in p['plots'],
                'family': act in p['families']
                or (how == 'dive' and 'dive' in p['families'])}

    def dive_place(self, obj_id):
        """The dive place for an object: one that shows it, else by band."""
        shown = [p for p in self.places
                 if p['id'] in self.dive_places and self.shows(p, obj_id)]
        if shown:
            return shown
        return [self.by_id[DIVE_BY_BAND[self.lake[obj_id]['band']]]]

    def route(self, mid):
        """Each step's place, or the reason the mission is not in the
        pool."""
        m = self.build[mid]
        act = m['actId']
        f, pr, d, dv = m['steps']
        out = []
        # Find.
        obj = self.lake.get(f['object'])
        if is_holy(obj):
            return None, 'holy find: ' + f['object']
        cands = []
        for p in self.places:
            h = p['heart']
            if h.get('core') == 'MissionCore' and h.get('step') == 'find' \
                    and h.get('object') == f['object']:
                cands.append((p, 'heart', 2))
            elif self.shows(p, f['object']):
                cands.append((p, 'thing', 1))
        if not cands and dive_ok(obj):
            cands = [(p, 'dive', 0) for p in self.dive_place(f['object'])]
        step = self.best(cands, mid, act)
        if step is None:
            return None, 'no place for find ' + f['object']
        out.append(dict(step, kind='find', object=f['object']))
        # Practice.
        cands = [(p, 'heart', 0) for p in self.places
                 if p['heart'].get('core') in ('MissionCore', 'RuleCore')
                 and p['heart'].get('id') == pr['practice']]
        step = self.best(cands, mid, act)
        if step is None:
            return None, 'no place for deed ' + pr['practice']
        out.append(dict(step, kind='practice', practice=pr['practice']))
        # Dialogue.
        cands = [(p, 'heart', 0) for p in self.places
                 if p['heart'].get('step') == 'dialogue'
                 and p['heart'].get('npc') == d['npc']]
        step = self.best(cands, mid, act)
        if step is None:
            return None, 'no place for talk with ' + d['npc']
        out.append(dict(step, kind='dialogue', npc=d['npc']))
        # Dive.
        obj = self.lake.get(dv['object'])
        if is_holy(obj):
            return None, 'holy dive object: ' + dv['object']
        if not dive_ok(obj):
            return None, 'not in the dive scene: ' + dv['object']
        step = self.best([(p, 'dive', 0) for p in
                          self.dive_place(dv['object'])], mid, act)
        out.append(dict(step, kind='dive', object=dv['object']))
        return out, ''

    def score(self, mid, route, seen):
        m = self.build[mid]
        plot_hits = sum(1 for s in route if s['plot'])
        fam_hits = sum(1 for s in route if s['family'])
        find_dive = route[0]['how'] == 'dive'
        places = len({s['place'] for s in route})
        truth = min(10, 4 + plot_hits + fam_hits) - (1 if find_dive else 0)
        node = None
        for n in self.trees[route[2]['npc']]['nodes']:
            if n['id'] == m['steps'][2]['node']:
                node = n
        teaching = 5
        if OPPOSES.get(m['passion']) == route[1]['practice']:
            teaching += 3
        if node and node.get('meaning') and node.get('source'):
            teaching += 2
        readable = 10 - max(0, places - 2) - (2 if find_dive else 0)
        key = tuple((s['kind'], s.get('object', ''), s.get('practice', ''),
                     s.get('npc', '')) for s in route)
        novelty = 10 - (4 - places) - (4 if key in seen else 0)
        safety = 10
        title = m['title'].lower()
        if any(stem in title for stem in CHORUS_STEMS):
            safety -= 5
        for s in route:
            if is_holy(self.lake.get(s.get('object', ''))):
                safety = 0
        return {'truth': truth, 'teaching': min(10, teaching),
                'readable': readable, 'novelty': novelty,
                'safety': safety}, key


def constitution(w, mid, route):
    m = w.build[mid]
    names = []
    for s in route:
        t = w.by_id[s['place']]['title_ru']
        if t not in names:
            names.append(t)
    lake = w.lake
    npc = w.trees[route[2]['npc']].get('npcName_ru', route[2]['npc'])
    act = ('найти «%s», %s, поговорить: %s, спуститься к «%s»' % (
        lake[route[0]['object']]['ru'],
        PRACTICE_RU[route[1]['practice']].lower(), npc,
        lake[route[3]['object']]['ru']))
    return 'ФОРМА: %s → ДЕЙСТВИЕ: %s → ЦЕЛЬ: %s.' % (
        '; '.join(names), act, PASSION_GOAL_RU[m['passion']])


def select():
    w = World()
    pool = []
    out_of_pool = []
    seen = set()
    for mid in w.order:
        if mid in w.chorus:
            out_of_pool.append((mid, 'on rewrite at the chorus'))
            continue
        route, why = w.route(mid)
        if route is None:
            out_of_pool.append((mid, why))
            continue
        sc, key = w.score(mid, route, seen)
        seen.add(key)
        pool.append({'mission': mid, 'route': route, 'score': sc,
                     'total': sum(sc.values()),
                     'act': w.build[mid]['actId']})
    strict = sum(1 for c in pool if c['route'][0]['how'] != 'dive')
    rank = {mid: i for i, mid in enumerate(w.order)}
    ordered = sorted(pool, key=lambda c: (-c['total'], rank[c['mission']]))
    picked = []
    keys = set()

    def take(c):
        key = tuple((s['kind'], s.get('object', ''), s.get('practice', ''),
                     s.get('npc', '')) for s in c['route'])
        if key in keys or c in picked:
            return False
        if sum(1 for p in picked if p['act'] == c['act']) >= PER_ACT_MAX:
            return False
        picked.append(c)
        keys.add(key)
        return True

    # The prologue first, then the best of every act, then the rest by
    # total under the cap of an act.
    acts = list(dict.fromkeys(w.build[m]['actId'] for m in w.order))
    for act in acts:
        for c in ordered:
            if c['act'] == act and take(c):
                break
    for c in ordered:
        if len(picked) >= K:
            break
        take(c)
    picked.sort(key=lambda c: rank[c['mission']])
    stories = []
    for c in picked:
        mid = c['mission']
        m = w.build[mid]
        route = []
        for i, s in enumerate(c['route']):
            p = w.by_id[s['place']]
            r = {'step': i, 'kind': s['kind'], 'place': s['place'],
                 'place_ru': p['title_ru'], 'how': s['how']}
            for k in ('object', 'practice', 'npc'):
                if k in s:
                    r[k] = s[k]
            route.append(r)
        stories.append({'mission': mid, 'title': m['title'],
                        'act': m['actId'], 'act_ru': m['actTitle'],
                        'passion': m['passion'], 'score': c['score'],
                        'total': c['total'], 'route': route,
                        'constitution': constitution(w, mid, c['route'])})
    return w, pool, strict, out_of_pool, stories


def render():
    w, pool, strict, out_of_pool, stories = select()
    data = {
        'note': 'Written by scripts/story/select_12.py; do not edit by hand.'
                ' The 12 missions the headset walks through the hearts of '
                'the places (TABOO 0.07, HLD_12_STORIES_HEADSET S4).',
        'date': DATE,
        'pool_size': len(pool),
        'pool_find_on_land': strict,
        'missions_total': len(w.order),
        'k': len(stories),
        'criteria': CRITERIA,
        'stories': stories,
    }
    js = json.dumps(data, ensure_ascii=False, indent=1) + '\n'
    return js, doc(w, pool, strict, out_of_pool, stories)


def doc(w, pool, strict, out_of_pool, stories):
    lines = [
        '# Отбор 12 сюжетов для шлема (%s)' % DATE,
        '',
        'Технология отбора — ТАБУ №0.07 (`docs/OBJECT_SELECTION_TECHNOLOGY'
        '.md`); HLD — `docs/HLD_12_STORIES_HEADSET_2026-10-02.md`, фаза S4,'
        ' трек D. Файл пишет `python3 scripts/story/select_12.py`; '
        '`--check` валит сборку, если он устарел.',
        '',
        '**Конституция:** ФОРМА — места миссии, её люди, вещи и вода → '
        'ДЕЙСТВИЕ — игрок идёт от доски дороги к каждому месту и делает '
        'шаг у его сердца → ЦЕЛЬ — урок акта прожит в шлеме, а не прочитан '
        'на доске.',
        '',
        '## Пул N — реальный размер',
        '',
        '- Миссий в кампании: %d; на переписке у хора: %d.' % (
            len(w.order), len(w.chorus)),
        '- **Пул N = %d**: у каждого из четырёх шагов есть построенное '
        'место. Из них %d — с находкой на суше (у сердца или среди вещей '
        'места); у остальных находка лежит на дне и берётся спуском.' % (
            len(pool), strict),
        '- Вне пула: %d. Причины ниже; число не подгонялось.' % (
            len(out_of_pool)),
        '',
        'Правила пула:',
        '',
        '- находка — место, где эта вещь — сердце или стоит среди вещей; '
        'иначе спуск (вещь лежит на дне сцены погружения);',
        '- дело — место, чьё сердце — это дело правила;',
        '- разговор — место, чьё сердце — этот человек (наставник стоит '
        'у сердца, `scripts/mentors.gd`);',
        '- погружение — вещь, которую ставит сцена погружения (не стайка '
        'рыбы, не трос), спуск от сердца места погружения;',
        '- святая вещь не бывает ключом шага: миссия со святой находкой '
        '(свинцовая булла) не входит в пул;',
        '- места сна «Киберслав» не станции караванной дороги и не '
        'берутся.',
        '',
        '## Пять критериев (0–10, в коде)',
        '',
        '- **правда** — 4 + шаги, чьё место называет эту миссию в своих '
        'сюжетах, + шаги в месте своего акта; −1, если находка только '
        'спуском;',
        '- **учительная связь** — 5, +3 если дело отвечает страсти акта '
        '(пост — чревоугодию, милостыня — сребролюбию, тайное добро — '
        'тщеславию, прощение — гневу, послушание — гордости), +2 если у '
        'узла беседы есть смысл и источник;',
        '- **читаемость в шлеме** — 10 − (мест сверх двух) − 2 за находку '
        'только под водой;',
        '- **новизна** — 10 − (4 − разных мест) − 4, если та же четвёрка '
        'шагов уже была у миссии раньше по дороге;',
        '- **безопасность** — 10; −5, если название миссии говорит об '
        'иной вере, культе или святом обряде (сначала хор 12, ТАБУ '
        '№0.37); 0, если хоть один шаг держится за святыню.',
        '',
        'Разнообразие: пролог первым, хотя бы один сюжет каждого акта, '
        'не больше %d на акт, две одинаковые четвёрки шагов не берутся; '
        'при равенстве — порядок кампании. Случайности нет.' % PER_ACT_MAX,
        '',
        '## Таблица K = %d' % len(stories),
        '',
        '| № | Миссия | Акт | Находка | Дело | Разговор | Погружение | '
        'Пр | Уч | Чт | Нв | Бз | Σ |',
        '|' + '---|' * 13,
    ]
    for i, s in enumerate(stories):
        r = s['route']
        cells = []
        for st in r:
            cells.append('%s (%s)' % (st['place_ru'], HOW_RU[st['how']]))
        sc = s['score']
        row = ['%d' % (i + 1), '%d. %s' % (s['mission'], s['title']),
               s['act_ru'].split(':')[0]] + cells \
            + [str(sc[c]) for c in CRITERIA] + ['%d' % s['total']]
        lines.append('| ' + ' | '.join(row) + ' |')
    lines += ['', '## Строка Конституции каждого сюжета', '']
    for s in stories:
        lines.append('- **%d. %s** — %s' % (
            s['mission'], s['title'], s['constitution']))
    lines += ['', '## Пул целиком', '',
              '| Миссия | Акт | Σ | Пр | Уч | Чт | Нв | Бз | Находка |',
              '|---|---|---|---|---|---|---|---|---|']
    for c in sorted(pool, key=lambda c: w.order.index(c['mission'])):
        sc = c['score']
        lines.append('| %d | %s | %d | %s | %s |' % (
            c['mission'], c['act'], c['total'],
            ' | '.join(str(sc[k]) for k in CRITERIA),
            HOW_RU[c['route'][0]['how']]))
    lines += ['', '## Вне пула и почему', '',
              '| Миссия | Причина |', '|---|---|']
    for mid, why in out_of_pool:
        lines.append('| %d | %s |' % (mid, why))
    lines += [
        '',
        '## Что проверить специалисту до релиза',
        '',
        '- **Историк-этнограф (хор 12, голос 9):** дела миссий стоят в '
        'местах других актов (послушание — в кирпичной мастерской, пост — '
        'в полевой кухне); уместно ли идти туда с караванной дороги.',
        '- **Гидроакустик-водолаз:** находка на дне берётся спуском '
        'от сердца места погружения; глубина и полоса — по реестру озера.',
        '- **Богослов (катехизатор, патролог, догматист):** булла '
        'помечена святой и исключена; проверить, нет ли других святых '
        'вещей среди находок без флага.',
        '- **Гейм-дизайнер Конституции:** поздние сюжеты открываются '
        'только порогами врат (MissionCore.act_lock) — для проверки в '
        'шлеме их нужно пройти по порядку кампании.',
        '- **Оператор в шлеме:** что доска называет «Куда идти», что шаг '
        'делается только у сердца своего места, что после спуска шаг '
        'закрывается во дворе. Проверено в шлеме будет только после '
        'слова оператора.',
        '',
    ]
    return '\n'.join(lines)


def main():
    js, md = render()
    if '--check' in sys.argv:
        stale = [str(p.relative_to(ROOT)) for p, text in ((OUT, js),
                                                          (DOC, md))
                 if not p.exists() or p.read_text(encoding='utf-8') != text]
        if stale:
            print('stale: ' + ', '.join(stale) +
                  '; run python3 scripts/story/select_12.py')
            sys.exit(1)
        print('story-12: up to date')
        return
    OUT.write_text(js, encoding='utf-8')
    DOC.write_text(md, encoding='utf-8')
    data = json.loads(js)
    print('pool %d (find on land %d), k %d' % (
        data['pool_size'], data['pool_find_on_land'], data['k']))
    for s in data['stories']:
        print(s['mission'], s['act'], s['total'], s['title'],
              [(r['kind'], r['place'], r['how']) for r in s['route']])


if __name__ == '__main__':
    main()
