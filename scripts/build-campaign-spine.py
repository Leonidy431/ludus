"""Build the Issyk-Kul campaign spine from webtypicon2's missions.

HLD F1 (DEF-018): the 99 missions of Bishop John's 14th-century mission
at Issyk-Kul need a spine: a prologue, acts and a finale, with a fixed
order, so the Meta build and the text version walk the same road.  The
missions live in webtypicon2 (functions/src/game/missions.ts); this
script only reads them (the game never writes into that repository) and
writes public/ludus/data/campaign-spine.json.

The knowledge-check answers (correctIndex) are a server secret there and
are never copied.  Missions whose wording turns a holy thing into a
commodity or a multiplier, or treats conversion as a score, are flagged
for the chorus of 12 editors (CLAUDE.md TABOO 0.37) instead of being
silently rewritten: TABOO 0.2 item 3, TABOO 0.35 rules 6 and 16.

Usage:
    python3 scripts/build-campaign-spine.py \
        --missions /home/user/webtypicon2 --ref origin/main
"""

import argparse
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'public' / 'ludus' / 'data' / 'campaign-spine.json'
SRC_PATH = 'functions/src/game/missions.ts'

# The acts follow the six blocks of the source, framed by a prologue and
# a finale from the narrative block.
ACTS = [
    ('prologue', 'Prologue: the road to the lake', 'Пролог: дорога к озеру'),
    ('trade', 'Act I: the caravan road', 'Акт I: караванная дорога'),
    ('spiritual', 'Act II: signs in clay and stone',
     'Акт II: знаки в глине и камне'),
    ('hydrology', 'Act III: the rising water', 'Акт III: вода поднимается'),
    ('diplomacy', 'Act IV: khans and envoys', 'Акт IV: ханы и послы'),
    ('craft', 'Act V: the workshop of the monastery',
     'Акт V: мастерская обители'),
    ('narrative', 'Finale: the stone under the water',
     'Финал: камень под водой'),
]
PROLOGUE = [1, 3]

M_RE = re.compile(r"m\((\d+),\s*'(\w+)',\s*'((?:[^'\\]|\\.)*)',\s*"
                  r"'((?:[^'\\]|\\.)*)'\)")

REVIEW = [
    ('relic-as-commodity', re.compile(r'реликв|мощ|ковчеж', re.I),
     'A relic is never traded, looted or a pilgrimage multiplier '
     '(TABOO 0.2 item 3; 0.35 rule 16).'),
    ('conversion-as-score', re.compile(r'конверси', re.I),
     'Conversion is not a metric; faith is never pressured '
     '(TABOO 0.37, dignity of the other).'),
    ('sacred-as-bonus', re.compile(
        r'(крест|икон|литурги|молитв|таинств|колокол)[^.]*'
        r'(бонус|буст|множител)', re.I),
     'A holy thing never gives a bonus (TABOO 0.35 rule 16).'),
]


def read_missions(repo, ref):
    text = subprocess.run(['git', 'show', f'{ref}:{SRC_PATH}'], cwd=repo,
                          check=True, capture_output=True,
                          text=True).stdout
    return [{'id': int(i), 'block': b, 'title': t.replace("\\'", "'"),
             'description': d.replace("\\'", "'")}
            for i, b, t, d in M_RE.findall(text)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--missions', default='/home/user/webtypicon2')
    parser.add_argument('--ref', default='origin/main')
    args = parser.parse_args()
    missions = read_missions(args.missions, args.ref)
    if len(missions) != 99:
        raise SystemExit(f'expected 99 missions, found {len(missions)}')
    acts = []
    for key, title, title_ru in ACTS:
        if key == 'prologue':
            ids = PROLOGUE
        else:
            ids = [m['id'] for m in missions
                   if m['block'] == key and m['id'] not in PROLOGUE]
        acts.append({'id': key, 'title': title, 'title_ru': title_ru,
                     'missions': ids})
    order = [i for act in acts for i in act['missions']]
    flagged = []
    for m in missions:
        hits = [{'flag': f, 'why': why} for f, rx, why in REVIEW
                if rx.search(m['title'] + ' ' + m['description'])]
        if hits:
            flagged.append({'id': m['id'], 'title': m['title'],
                            'review': hits})
    spine = {
        'source': f'webtypicon2 {SRC_PATH} @ {args.ref} (read-only)',
        'acts': acts,
        'order': order,
        'missions': [{k: m[k] for k in ('id', 'block', 'title')}
                     for m in missions],
        'needsChorusRewrite': flagged,
    }
    OUT.write_text(json.dumps(spine, ensure_ascii=False, indent=1) + '\n',
                   'utf-8')
    print(f'{len(order)} missions in {len(acts)} acts; '
          f'{len(flagged)} flagged for the chorus -> {OUT.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
