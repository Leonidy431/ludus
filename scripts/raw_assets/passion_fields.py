"""The teaching fields every passion antagonist must carry.

CLAUDE.md TABOO 0.35 rule 13: an antagonist is shipped as a set, and its
meta-json names the passion, the opposing virtue, the Ladder step, a
patristic source and the sign by which the player discerns it.  Without
them an antagonist is a deception, not a teaching (TABOO 0.2 item 8).

The fields come from public/ludus/data/passions.json, the same data the
game uses when the player meets a passion on the road, so the art, the
encounter and the mentors' lessons name the passion the same way.
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / 'public' / 'ludus' / 'data' / 'passions.json'
REQUIRED = ('passion', 'opposing_virtue', 'ladder_step',
            'patristic_source', 'discernment_cue')

# The mentor node that teaches each passion's sign in the teacher's own
# idiom (rule 13: "at least one mentor node that teaches the sign").
# Node ids are in functions/src/data/npc-dialogues-24.json; the tests
# check that each one exists in the teacher's tree and is a
# discernment node.  A passion whose teacher has no such node yet is
# left out rather than pointed at a node that teaches something else.
MENTOR_NODES = {
    'avarice': 'avarice_cue',
    'vainglory': 'seen_knot',
    'lust': 'returning_knock',
    'pride': 'own_light',
    'acedia': 'noonday_thief',
}


def load(path=DATA):
    doc = json.loads(Path(path).read_text(encoding='utf-8'))
    return {p['raw']: p for p in doc['passions']}


def enrich(meta, passions=None):
    """Add the rule-13 fields to one antagonist meta; return it."""
    table = passions if passions is not None else load()
    entry = table.get(meta.get('passion'))
    if not entry:
        return meta
    meta.update({
        'opposing_virtue': entry['virtue'],
        'ladder_step': entry['ladder'],
        'patristic_source': entry['source'],
        'discernment_cue': entry['cue'],
        'discernment_cue_ru': entry['cue_ru'],
        'teacher_npc': entry['teacher'],
    })
    node = MENTOR_NODES.get(meta['passion'])
    if node:
        meta['mentor_node'] = f"{entry['teacher']}:{node}"
    return meta


def missing(meta):
    """Names of rule-13 fields an antagonist meta lacks."""
    return [key for key in REQUIRED if not meta.get(key)]
