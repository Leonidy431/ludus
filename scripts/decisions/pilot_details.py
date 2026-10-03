"""55 details for the pilot "Taboo", chosen from every variant of 119 seeds.

Operator, 2026-10-02: «придумай еще 55 таких деталей отобрав из 777
сгенерированных на основе лучших книг идей по 12 параметрам смачности
эффекта для игрока»; «создай отдельный HLD и реализуй это недорого».

The pool is generated, not padded (TABOO 0.07): 119 seeds from sixteen
books' craft (pilot_details_seeds.py) times seven ways to deliver each:

    as_is        as written;
    plus_haptic  the hands feel it too (not at the holy);
    plus_duck    the machine's sound dips under it;
    later5       five seconds later in its beat;
    no_text      without words: the thing alone (Hemingway's omission);
    double       stronger light, murk or pulse;
    one_branch   only for the player who fell (choice beats only).

119 x 7 = 833 generated; the operator asked for 777 and the honest
number is written as it is.  Hard rules prune a variant before scoring:
at the holy only quiet primitives (TABOO 0.4 item 2, TABOO 0.015 item
5), no church word on a line (data/church-words.json), no doubled jolt
at the tether jerk (comfort), no empty detail.

Twelve criteria of how strongly a detail lands for the player, 0-10
each, derived from the seed's tags and the variant (rules in score()):
surprise, clarity, body, stakes, mystery, eras (Cloud Atlas), seen
("they see me"), payoff, truth, comfort, canon, cheapness.  These are
design judgements written as code, not player data: the headset test
(Д-17) is what proves them.

Selection is deterministic: at most one variant per seed, at least two
and at most four details per beat, at most six per book, no two lines
on the same screen within 3 s, one pulse of the hands per beat and
eighteen in the episode.

    python3 scripts/decisions/pilot_details.py           # write data
    python3 scripts/decisions/pilot_details.py --check   # CI

Constitution: ФОРМА (the pilot's beats and the player's senses) →
ДЕЙСТВИЕ (a small true thing at the right second) → ЦЕЛЬ (the player
believes the world and so meets its choice in earnest).
"""

import copy
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(ROOT / 'scripts' / 'locations'))

from pilot_details_seeds import SEEDS  # noqa: E402
import church_words  # noqa: E402

OUT = ROOT / 'godot' / 'data' / 'pilot-details.json'
PILOT = ROOT / 'godot' / 'data' / 'pilot-1.json'
WANT = 55
PER_BEAT = (2, 4)
PER_BOOK = 6
# A pulse that comes every ten seconds stops meaning anything, and the
# hands tire: one per beat, a third of the details at most.  The first
# scoring chose "plus_haptic" 40 times out of 55; this is the override.
HAPTIC_PER_BEAT = 1
HAPTIC_MAX = 18
VARIANTS = ('as_is', 'plus_haptic', 'plus_duck', 'later5', 'no_text',
            'double', 'one_branch')
CRITERIA = ('surprise', 'clarity', 'body', 'stakes', 'mystery', 'eras',
            'seen', 'payoff', 'truth', 'comfort', 'canon', 'cheapness')
HOLY_BEATS = ('khachkar',)
QUIET = ('duck', 'lamp', 'fog', 'line')
CHOICE_BEATS = ('lure', 'price_rises', 'choice_echo')
TEXT = ('say', 'line')
# Things a detail may show, hide or move; built cheaply in pilot.gd.
NODES = ('Ring', 'Logbook', 'Doorway', 'WallMark', 'FloorDram', 'Mark',
         'Drams', 'Amphora')


def kind(p):
    for k in ('say', 'line', 'lamp', 'flicker', 'haptic', 'sfx', 'duck',
              'fog', 'move', 'show', 'hide', 'water'):
        if k in p:
            return k
    return ''


def variant(seed, v):
    """The seed delivered the v way, or None when that way is barred."""
    sid, beat, at, book, tags, idea, prims = seed
    prims = copy.deepcopy(prims)
    holy = beat in HOLY_BEATS
    if v == 'plus_haptic':
        if holy or any(kind(p) == 'haptic' for p in prims):
            return None
        prims.append({'haptic': 'breath', 'hand': 'both'})
    elif v == 'plus_duck':
        if any(kind(p) == 'duck' for p in prims):
            return None
        prims.append({'duck': -12, 's': 1.5})
    elif v == 'later5':
        at += 5
    elif v == 'no_text':
        prims = [p for p in prims if kind(p) not in TEXT]
        if not prims:
            return None
    elif v == 'double':
        if beat == 'tether_jerk':
            return None
        changed = False
        for p in prims:
            if kind(p) in ('lamp', 'fog', 'flicker', 'haptic'):
                p['strong'] = True
                changed = True
        if not changed:
            return None
    elif v == 'one_branch':
        if beat not in CHOICE_BEATS or any('if' in p for p in prims):
            return None
        for p in prims:
            p['if'] = 'captive'
    return {'id': '%s.%s' % (sid, v), 'seed': sid, 'variant': v,
            'beat': beat, 'at': at, 'book': book, 'tags': tags,
            'idea_ru': idea, 'do': prims}


def barred(d, cw):
    """Why a variant may not be used, or ''."""
    if d['beat'] in HOLY_BEATS:
        for p in d['do']:
            k = kind(p)
            if k not in QUIET:
                return 'holy: %s' % k
            if k == 'lamp' and p.get('strong'):
                return 'holy: strong light'
            if k == 'line' and p['line']:
                return 'holy: words'
    for p in d['do']:
        k = kind(p)
        if k == '':
            return 'unknown primitive'
        if k in TEXT and church_words.church_word(p[k], cw):
            return 'church word: %s' % church_words.church_word(p[k], cw)
        if k in ('move', 'show', 'hide') and p[k] not in NODES:
            return 'unknown node %s' % p[k]
    return ''


def score(d):
    t = d['tags']
    v = d['variant']
    kinds = [kind(p) for p in d['do']]
    strong = any(p.get('strong') for p in d['do'])
    s = {
        'surprise': (8 if 'S' in t else 4) + (1 if strong else 0),
        'clarity': 8 - (2 if 'X' in t else 0) - (3 if v == 'no_text' else 0)
        - (1 if len(kinds) > 2 else 0),
        'body': min(10, (9 if 'B' in t or 'haptic' in kinds else 3)
                    + (3 if v == 'plus_haptic' else 0)),
        'stakes': 8 if 'K' in t else 4,
        'mystery': (8 if 'M' in t else 4) + (1 if v == 'no_text' else 0),
        'eras': 9 if 'E' in t else 3,
        'seen': 9 if 'R' in t else 3,
        'payoff': (8 if 'P' in t else 3) + (1 if v == 'one_branch' else 0),
        'truth': 9 if 'T' in t else 6,
        'comfort': 9 - (2 if strong else 0) - (1 if 'flicker' in kinds
                                               else 0)
        - (1 if v == 'plus_haptic' else 0),
        'canon': 10 if d['beat'] not in HOLY_BEATS or 'Q' in t else 6,
        'cheapness': 10 - (1 if any(k in ('show', 'move') for k in kinds)
                           else 0) - (1 if len(kinds) > 1 else 0),
    }
    # A variant that adds nothing to the seed's point costs attention.
    if v == 'later5':
        s['surprise'] -= 1
    if v == 'plus_duck' and 'Q' not in t:
        s['clarity'] -= 1
    return {k: max(0, min(10, s[k])) for k in CRITERIA}


def generate():
    cw = church_words.load()
    pool, pruned = [], {}
    for seed in SEEDS:
        for v in VARIANTS:
            d = variant(seed, v)
            if d is None:
                pruned['barred variant'] = pruned.get('barred variant',
                                                      0) + 1
                continue
            why = barred(d, cw)
            if why:
                key = why.split(':')[0]
                pruned[key] = pruned.get(key, 0) + 1
                continue
            d['scores'] = score(d)
            d['total'] = sum(d['scores'].values())
            pool.append(d)
    return pool, pruned


def _fits(d, chosen, by_beat, by_book, seeds):
    if d['seed'] in seeds or by_book.get(d['book'], 0) >= PER_BOOK:
        return False
    if by_beat.get(d['beat'], 0) >= PER_BEAT[1]:
        return False
    if _buzz(d):
        if sum(1 for c in chosen if _buzz(c)) >= HAPTIC_MAX:
            return False
        if any(_buzz(c) and c['beat'] == d['beat'] for c in chosen):
            return False
    texts = [kind(p) for p in d['do'] if kind(p) in TEXT]
    for c in chosen:
        if c['beat'] != d['beat'] or abs(c['at'] - d['at']) >= 3:
            continue
        if set(texts) & {kind(p) for p in c['do']}:
            return False
    return True


def _buzz(d):
    return any(kind(p) == 'haptic' for p in d['do'])


def select(pool):
    order = sorted(pool, key=lambda d: (-d['total'], d['id']))
    chosen, by_beat, by_book, seeds = [], {}, {}, set()

    def take(d):
        chosen.append(d)
        by_beat[d['beat']] = by_beat.get(d['beat'], 0) + 1
        by_book[d['book']] = by_book.get(d['book'], 0) + 1
        seeds.add(d['seed'])

    beats = sorted({d['beat'] for d in pool})
    for b in beats:
        for d in order:
            if by_beat.get(b, 0) >= PER_BEAT[0]:
                break
            if d['beat'] == b and _fits(d, chosen, by_beat, by_book,
                                        seeds):
                take(d)
    for d in order:
        if len(chosen) >= WANT:
            break
        if _fits(d, chosen, by_beat, by_book, seeds):
            take(d)
    beat_t = {b['id']: b['t'] for b in json.loads(
        PILOT.read_text(encoding='utf-8'))['beats']}
    chosen.sort(key=lambda d: (beat_t[d['beat']] + d['at'], d['id']))
    return chosen


def build():
    pool, pruned = generate()
    chosen = select(pool)
    generated = len(SEEDS) * len(VARIANTS)
    return {
        'doc': 'docs/HLD_PILOT_DETAILS_55_2026-10-02.md',
        'about': 'Details of the pilot, chosen by '
                 'scripts/decisions/pilot_details.py; do not edit.',
        'generated': generated,
        'seeds': len(SEEDS),
        'variants': list(VARIANTS),
        'pruned': dict(sorted(pruned.items())),
        'scored': len(pool),
        'criteria': list(CRITERIA),
        'chosen': [{k: d[k] for k in ('id', 'beat', 'at', 'book',
                                      'idea_ru', 'do', 'scores', 'total')}
                   for d in chosen],
    }


def text(data):
    return json.dumps(data, ensure_ascii=False, indent=1) + '\n'


def main(argv):
    data = build()
    if '--check' in argv:
        bad = []
        if len(data['chosen']) != WANT:
            bad.append('%d chosen, not %d' % (len(data['chosen']), WANT))
        if not OUT.exists() or OUT.read_text(encoding='utf-8') != \
                text(data):
            bad.append('godot/data/pilot-details.json is stale')
        for b in bad:
            print('FAIL:', b)
        print('pilot details: %d generated, %d scored, %d chosen' % (
            data['generated'], data['scored'], len(data['chosen'])))
        return 1 if bad else 0
    if '--table' in argv:
        print('| # | бит | +с | книга | деталь | вариант | балл |')
        print('|---|---|---|---|---|---|---|')
        for i, d in enumerate(data['chosen'], 1):
            print('| %d | %s | %d | %s | %s | %s | %d |' % (
                i, d['beat'], d['at'], d['book'], d['idea_ru'],
                d['id'].split('.')[1], d['total']))
        return 0
    OUT.write_text(text(data), encoding='utf-8')
    print('wrote %s: %d generated, %d pruned, %d scored, %d chosen' % (
        OUT.relative_to(ROOT), data['generated'],
        sum(data['pruned'].values()), data['scored'], len(data['chosen'])))
    print('pruned:', data['pruned'])
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
