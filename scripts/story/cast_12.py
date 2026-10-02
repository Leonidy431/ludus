"""Where the people of the 12 stories stand in the headset.

The 12 stories (godot/data/story-12.json, scripts/story/select_12.py)
are walked through the hearts of their places, and each story's talk
step is led by one person (MissionCore.ACT_PLAN).  The matrix of the 99
storylines (docs/STORYLINES_99_ASSET_MATRIX.md, "Реплики" and the
scenario) names two to four more people for every story.  This script
is the census of them made data (docs/STORY_12_CHARACTERS_2026-10-02.md,
docs/HLD_STORY_12_CHARACTERS_2026-10-02.md):

- CAST below is hand-curated from the matrix, one row per person a
  story calls for, with where that person stands: the story's own
  place (a place whose plots name the mission, or a place of its
  route), never under water, never on a heart that is the person's
  already; a mentor of the courtyard (the four of the gates and the
  guests, scripts/mentors.gd HUB_AT) stays in the courtyard and the
  board of the story names him there;
- the node a person opens at that place is the one that speaks of the
  story's event (an existing tree's node, or the start of a new tree
  in functions/src/data/npc-dialogues-story12.json);
- the tag over the person carries no church word (the one stop-list,
  godot/data/church-words.json, read the way the headset reads it).

Nothing is padded: a person the matrix names but who has no tree and no
basis would be listed in the census, not invented here.  The script
checks every row against the data and writes
godot/data/story-cast-12.json, which the places read
(godot/scripts/story_cast.gd).

  python3 scripts/story/cast_12.py           write the data;
  python3 scripts/story/cast_12.py --check   fail if it is stale or a
                                             row does not hold.

Constitution: FORM (the people of a story, each with his craft, idiom
and place) -> ACTION (the player walks up to a person where his story
happens and talks with his own FORM) -> GOAL (the story's teaching is
heard from many mouths, each in its own image, with its source).
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STORY = ROOT / 'godot/data/story-12.json'
TREES = ROOT / 'godot/data/dialogue-trees.json'
LOCATIONS = ROOT / 'godot/data/locations-99.json'
CHURCH = ROOT / 'godot/data/church-words.json'
OUT = ROOT / 'godot/data/story-cast-12.json'
DATE = '2026-10-02'

# The mentors of the courtyard (scripts/mentors.gd HUB_AT): they stand
# only there; a story that calls for one names the courtyard.
HUB = ['elder_sergius', 'theodora', 'abba_john', 'sister_catherine',
       'gregory_palamas', 'isaias', 'kassiani', 'ekaterina',
       'gregory_dialogist', 'symeon_stylite', 'mary_magdalene',
       'ikonopisets']
HUB_RU = 'во дворе обители'

# The tag over a person standing in a place: a name and a sign of his
# craft, never a church title (TABOO 0.39 item 3).
TAG = {
    'episkop_ioann': 'Иоанн, что мирит купцов',
    'kupets_ovanes': 'Ованес, торговец тканями',
    'kupets_sauma': 'Саума, торговец пряностями',
    'kupets_kutlug': 'Кутлуг с расщеплённой биркой',
    'vozchik_davit': 'Давит, молодой возчик',
    'mostovshik_toros': 'Торос, плотник-мостовщик',
    'provodnik_buri': 'Бури, проводник каравана',
    'perekupshik_arshak': 'Аршак, перекупщик',
    'starukha_shushan': 'Старая Шушан с веретеном',
    'brat_gevond': 'Слепой брат Гевонд',
    'sargis': 'Саргис, караван-баши',
    'rybak_issyk_kul': 'Рыбак Иссык-Куля',
    'vardan': 'Вардан-переписчик',
    'anahit': 'Анаит, хозяйка караван-сарая',
    'tabib': 'Табиб Мар-Ава',
    'melik': 'Мелик Ашот, хранитель весов',
}

# One row per person a story calls for, beyond the person of its talk
# step: (npc, place or 'hub', node, where the matrix names him).  The
# node is the one that speaks of the story's event.
CAST = {
    3: [
        ('episkop_ioann', 'court-yard', 'b_silk', 'Реплики: 6 узлов'),
        ('kupets_ovanes', 'court-yard', 'o_start', 'Реплики: 3 узла'),
        ('kupets_sauma', 'court-yard', 's_start', 'Реплики: 3 узла'),
    ],
    6: [
        ('sargis', 'winter-hut', 'overload', 'Реплики: 4 узла'),
        ('rybak_issyk_kul', 'winter-hut', 'greeting', 'Реплики: 3 узла'),
        ('elder_sergius', 'hub', 'greeting', 'Реплики: 3 узла'),
    ],
    15: [
        ('vozchik_davit', 'caravaners-yard', 'd_start', 'Реплики: 3 узла'),
        ('theodora', 'hub', 'greeting', 'Реплики: 4 узла'),
    ],
    27: [
        ('anahit', 'feast-yard', 'a_bread', 'Реплики: 2 узла'),
        ('tabib', 'feast-yard', 'theotokos', 'Реплики: 2 узла'),
        ('rybak_issyk_kul', 'feast-yard', 'ichthys', 'Реплики: 2 узла'),
        ('kassiani', 'hub', 'k_greeting', 'Реплики: 6 узлов'),
    ],
    31: [
        ('vardan', 'terrace-regression', 'v_marks', 'Реплики: 3 узла'),
        ('elder_sergius', 'hub', 'greeting', 'Реплики: 2 узла'),
    ],
    34: [
        ('rybak_issyk_kul', 'kairak-valley', 'avarice', 'Реплики: 5 узлов'),
        ('vardan', 'kairak-valley', 'v_legend', 'Реплики: 2 узла'),
    ],
    49: [
        ('episkop_ioann', 'porch-court', 'b_debt', 'Реплики: 3 узла'),
        ('sargis', 'porch-court', 'open_hand', 'Реплики: 3 узла'),
        ('kupets_kutlug', 'porch-court', 'k_start', 'Реплики: 3 узла'),
    ],
    61: [
        ('melik', 'divan-darugi', 'm_gift', 'Реплики: 3 узла'),
        ('elder_sergius', 'hub', 'greeting', 'Реплики: 4 узла'),
    ],
    73: [
        ('mostovshik_toros', 'mountain-bridge', 't_start',
         'Реплики: ≈4 узла'),
        ('sargis', 'mountain-bridge', 'overload', 'Реплики: ≈4 узла'),
        ('sister_catherine', 'hub', 'greeting', 'Реплики: ≈4 узла'),
    ],
    78: [
        ('provodnik_buri', 'star-shore', 'u_start', 'Реплики: ≈5 узлов'),
        ('rybak_issyk_kul', 'star-shore', 'cold_layer', 'Реплики: ≈3 узла'),
        ('elder_sergius', 'hub', 'greeting', 'Реплики: ≈4 узла'),
    ],
    88: [
        ('perekupshik_arshak', 'fishers-camp', 'r_start',
         'Реплики: ≈3 узла'),
        ('starukha_shushan', 'fishers-camp', 'h_start',
         'Сценарий: три версии легенды'),
        ('abba_john', 'hub', 'greeting', 'Реплики: ≈5 узлов'),
    ],
    90: [
        ('episkop_ioann', 'flooded-lower', 'b_flock', 'Реплики: ≈2 узла'),
        ('brat_gevond', 'flooded-lower', 'g_start', 'Реплики: ≈3 узла'),
        ('vardan', 'flooded-lower', 'v_marks', 'Реплики: ≈4 узла'),
        ('elder_sergius', 'hub', 'greeting', 'Реплики: ≈5 узлов'),
    ],
}


def load(path):
    return json.loads(path.read_text(encoding='utf-8'))


def words(text):
    """Runs of a-z and а-я after lower case, ё read as е (LocationsCore)."""
    out, cur = [], ''
    for ch in text.lower().replace('ё', 'е'):
        if 'a' <= ch <= 'z' or 'а' <= ch <= 'я':
            cur += ch
        elif cur:
            out.append(cur)
            cur = ''
    return out + ([cur] if cur else [])


def church_word(text, data):
    """The first church word of a text, as LocationsCore.church_word."""
    for w in words(text):
        if any(w.startswith(t) for t in data['twins']):
            continue
        if w in data['forms'] or any(w.startswith(s)
                                     for s in data['stems']):
            return w
    return ''


def build():
    """The data the places read, and the problems of the rows."""
    stories = {int(s['mission']): s for s in load(STORY)['stories']}
    trees = load(TREES)['trees']
    locs = {p['id']: p for p in load(LOCATIONS)['locations']}
    church = load(CHURCH)
    problems = []
    if set(CAST) != set(stories):
        problems.append('CAST does not cover the 12 stories')
    out_stories, places = [], {}
    # The order of the selection (story-12.json), which is the road's.
    for mid in stories:
        s = stories[mid]
        talk = [r for r in s['route'] if r['kind'] == 'dialogue'][0]
        people = []
        for npc, place, node, basis in CAST.get(mid, []):
            tree = trees.get(npc)
            where = f'M{mid} {npc}'
            if tree is None:
                problems.append(f'{where}: no dialogue tree')
                continue
            if node not in {n['id'] for n in tree['nodes']}:
                problems.append(f'{where}: no node {node}')
            if npc == talk['npc']:
                problems.append(f'{where}: is the talk step already')
            if place == 'hub':
                if npc not in HUB:
                    problems.append(f'{where}: not a mentor of the hub')
                people.append({'npc': npc, 'name_ru': tree['npcName_ru'],
                               'place': 'hub', 'place_ru': HUB_RU,
                               'node': node, 'basis': basis})
                continue
            if npc in HUB:
                problems.append(f'{where}: a hub mentor stands in the hub')
            loc = locs.get(place)
            if loc is None:
                problems.append(f'{where}: no place {place}')
                continue
            if loc['shell']['type'] == 'underwater':
                problems.append(f'{where}: {place} is under water')
            if loc['heart'].get('npc') == npc:
                problems.append(f'{where}: stands at the heart of {place}')
            own = f'M{mid}' in loc['plots'] \
                or any(r['place'] == place for r in s['route'])
            if not own:
                problems.append(f'{where}: {place} is not of the story')
            tag = TAG.get(npc, '')
            if not tag or church_word(tag, church):
                problems.append(f'{where}: tag {tag!r} is not plain')
            people.append({'npc': npc, 'name_ru': tree['npcName_ru'],
                           'place': place, 'place_ru': loc['title_ru'],
                           'node': node, 'basis': basis,
                           'on_route': any(r['place'] == place
                                           for r in s['route'])})
            row = places.setdefault(place, [])
            if any(p['npc'] == npc for p in row):
                # One person stands once in a place; a second story of
                # the same place opens the same figure (its first node).
                for p in row:
                    if p['npc'] == npc:
                        p['missions'].append(mid)
                continue
            row.append({'npc': npc, 'tag': tag, 'node': node,
                        'missions': [mid]})
        out_stories.append({'mission': mid, 'title': s['title'],
                            'talk': {'npc': talk['npc'],
                                     'place': talk['place']},
                            'people': people})
    data = {
        'note': 'Written by scripts/story/cast_12.py; do not edit by '
                'hand. The people of the 12 stories beyond the talk '
                'step, where each stands (docs/STORY_12_CHARACTERS_'
                '2026-10-02.md).',
        'date': DATE,
        'stories': out_stories,
        'places': {k: places[k] for k in sorted(places)},
    }
    return data, problems


def main():
    data, problems = build()
    text = json.dumps(data, ensure_ascii=False, indent=1) + '\n'
    if problems:
        print('\n'.join(problems))
        sys.exit(1)
    if '--check' in sys.argv:
        if not OUT.exists() or OUT.read_text(encoding='utf-8') != text:
            print(f'{OUT.relative_to(ROOT)} is stale: run '
                  'python3 scripts/story/cast_12.py')
            sys.exit(1)
        print(f'cast_12: {len(data["places"])} places, '
              f'{sum(len(v) for v in data["places"].values())} figures, '
              'data current')
        return
    OUT.write_text(text, encoding='utf-8')
    print(f'wrote {OUT.relative_to(ROOT)}: {len(data["places"])} places, '
          f'{sum(len(v) for v in data["places"].values())} figures')


if __name__ == '__main__':
    main()
