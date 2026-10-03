"""Validate the 24 NPC dialogue trees (CLAUDE.md TABOO 0.37 and 0.39).

The chorus of 12 editors wrote functions/src/data/npc-dialogues-24.json;
this check keeps every later edit inside the same contract, and fails
the build with the first problems it finds:
  - every NPC has an idiom: worldview, craft, 6-10 images, 3-5
    metaphors and a way of falling silent (Aesopian language, 0.39);
  - 6-8 teaching nodes, plus one more for each passion the NPC teaches
    beyond the first (see max_nodes), unique ids, a real start node,
    every nextNodeId resolves or is null;
  - every node carries text, text_ru, meaning and source (0.35 rule 18);
  - every node says whose words these are: voice "own" (the NPC in
    his own words) or "paraphrase" (a retold teaching with its source);
  - a saint carries the flag "saint": true, and so does every NPC whose
    Russian name begins with a saint's title (Свт., Прп., Вмц., Пророк,
    Ап. and their full forms); a saint speaks only in paraphrase, never
    in invented quotations (0.37, 0.35 rule 18);
  - the start node has a branch with no condition, so a beginner can
    talk and the meeting is recorded (the gates depend on it);
  - at least two branches are gated by FORM; Cunning never opens a
    teaching: a Cunning-gated branch may lead only to a refusal node,
    one with no FORM gates where each way on pays at most +1 (the way
    back is repentance, as on the ladder of a thought), and Cunning
    never pays more than +1;
  - bonuses are whole numbers 1-5 on the seven attributes only;
  - player choices never use the words the UI must not carry (0.39).

The people of the 12 stories walked in the headset
(functions/src/data/npc-dialogues-story12.json, docs/STORY_12_CHARACTERS_
2026-10-02.md) keep the same contract; with no path both files are
checked, the 24 of the chorus and the people of the stories, and an
npcId may not repeat across them.

Usage: python3 scripts/check_dialogues.py [path]
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT = ROOT / 'functions' / 'src' / 'data' / 'npc-dialogues-24.json'
STORY = ROOT / 'functions' / 'src' / 'data' / 'npc-dialogues-story12.json'

ATTRS = {'wisdom', 'faith', 'dexterity', 'constitution', 'charisma',
         'cunning', 'erudition'}
SAINTS = {'abba_moses', 'ekaterina', 'maximos', 'photius',
          'mary_magdalene', 'gregory_dialogist', 'symeon_stylite',
          'kassiani', 'gregory_palamas', 'macrina', 'isaias'}
VOICES = ('own', 'paraphrase')
# The titles that make a name a saint's.  Patrologist of the chorus,
# 2026-10-03: prejudice «the list of saint ids is enough» / counter: a
# new saint added by name and not to the list would speak in his own
# invented words unchecked / why: the title in the name and the flag in
# the data are checked against each other, and the list stays as a
# third witness.
SAINT_TITLE = re.compile(r'^(?:Свт\.|Святител|Прп\.|Преподобн|Вмц\.|'
                         r'Мц\.|Пророк|Ап\.|Апостол|Св\.|Равноап)')
FORBIDDEN = re.compile(r'\b(martyr\w*|saint\w*|grace|sacrament\w*|'
                       r'salvation)\b|мученик\w*|святой|святая|благодат\w*|'
                       r'таинств\w*|спасени\w*', re.IGNORECASE)


def is_refusal(node):
    """A node that teaches nothing new: no FORM gates, at most +1."""
    for br in node.get('branches') or []:
        if br.get('condition'):
            return False
        if sum((br.get('attributeBonuses') or {}).values()) > 1:
            return False
    return True


def is_discernment(node):
    """A node that teaches the sign of one passion (rule 13)."""
    return str(node.get('meaning') or '').startswith('Discernment cue')


def max_nodes(nodes):
    """Eight nodes, and one more for each passion beyond the first.

    TABOO 0.35 rule 13 asks for a mentor node teaching the sign of each
    passion, and some mentors teach the signs of two or three passions
    (Sister Catherine: vainglory and pride; Elder Sergius, the teacher
    of lust and vainglory in public/ludus/data/passions.json: acedia,
    vainglory and lust).  Folding a sign into another node would delete
    teaching, which is worse than a longer tree, so only discernment
    nodes may go past eight; any other growth still fails.
    """
    cues = sum(1 for node in nodes if is_discernment(node))
    return 8 + max(0, cues - 1)


def check_tree(tree):
    errors = []
    nid = tree.get('npcId', '?')

    def err(msg):
        errors.append(f'{nid}: {msg}')

    idiom = tree.get('idiom') or {}
    for key in ('worldview', 'craft', 'silence'):
        if not idiom.get(key):
            err(f'idiom.{key} missing')
    if not 6 <= len(idiom.get('images') or []) <= 10:
        err('idiom.images must hold 6-10 images')
    if not 3 <= len(idiom.get('metaphors') or []) <= 5:
        err('idiom.metaphors must hold 3-5 metaphors')

    saint = tree.get('saint') is True
    if 'saint' in tree and not isinstance(tree['saint'], bool):
        err('saint must be true or false')
    if SAINT_TITLE.match(tree.get('npcName_ru') or '') and not saint:
        err('the name carries a saint\'s title, but "saint" is not true')
    if nid in SAINTS and not saint:
        err('a saint of the chorus list without "saint": true')

    nodes = tree.get('nodes') or []
    ids = [n.get('id') for n in nodes]
    if not 6 <= len(nodes) <= max_nodes(nodes):
        err(f'{len(nodes)} nodes, expected 6-{max_nodes(nodes)}')
    if len(set(ids)) != len(ids):
        err('duplicate node ids')
    if tree.get('startNode') not in ids:
        err('startNode not found')

    gated = 0
    for node in nodes:
        where = f"node {node.get('id')}"
        for key in ('text', 'text_ru', 'meaning', 'source'):
            if not str(node.get(key) or '').strip():
                err(f'{where}: {key} missing')
        if node.get('voice') not in VOICES:
            err(f'{where}: voice {node.get("voice")!r} is not one of '
                f'{", ".join(VOICES)}')
        if saint and node.get('voice') != 'paraphrase':
            err(f'{where}: a saint speaks in paraphrase')
        for br in node.get('branches') or []:
            nxt = br.get('nextNodeId')
            if nxt is not None and nxt not in ids:
                err(f'{where}: nextNodeId {nxt!r} does not resolve')
            for key in ('text', 'text_ru'):
                if FORBIDDEN.search(br.get(key) or ''):
                    err(f'{where}: choice uses a UI-forbidden word: '
                        f'{br.get(key)!r}')
            cond = br.get('condition') or {}
            if cond:
                gated += 1
            for attr, value in cond.items():
                if attr not in ATTRS:
                    err(f'{where}: condition on unknown {attr!r}')
                if attr == 'cunning':
                    target = next((n for n in nodes
                                   if n.get('id') == nxt), None)
                    if not target or not is_refusal(target):
                        err(f'{where}: Cunning opens a teaching')
                if not (isinstance(value, int) and 1 <= value <= 20):
                    err(f'{where}: threshold {value!r} out of range')
            for attr, value in (br.get('attributeBonuses') or {}).items():
                if attr not in ATTRS:
                    err(f'{where}: bonus on unknown {attr!r}')
                elif not (isinstance(value, int) and 1 <= value <= 5):
                    err(f'{where}: bonus {value!r} not 1-5')
                elif attr == 'cunning' and value > 1:
                    err(f'{where}: Cunning pays more than +1')
    start = next((n for n in nodes if n.get('id') == tree.get('startNode')),
                 None)
    if start and not any(not br.get('condition')
                         for br in start.get('branches') or []):
        err('the start node has no unconditioned branch')
    if gated < 2:
        err(f'only {gated} FORM-gated branches, need 2')
    return errors


def check_file(path, count=None):
    """The problems of one file of trees; count is the expected size."""
    trees = json.loads(path.read_text('utf-8'))
    errors = []
    if count is not None and len(trees) != count:
        errors.append(f'{path.name}: {len(trees)} trees, expected {count}')
    if len({t.get('npcId') for t in trees}) != len(trees):
        errors.append(f'{path.name}: duplicate npcId')
    for tree in trees:
        errors += check_tree(tree)
    return trees, errors


def main():
    if len(sys.argv) > 1:
        files = [(Path(sys.argv[1]), None)]
    else:
        # The 24 of the chorus are exactly 24; the people of the stories
        # are as many as the census found (never padded).
        files = [(DEFAULT, 24), (STORY, None)]
    errors, ids, total = [], [], 0
    for path, count in files:
        trees, errs = check_file(path, count)
        errors += errs
        ids += [t.get('npcId') for t in trees]
        total += len(trees)
    if len(set(ids)) != len(ids):
        errors.append('an npcId repeats across the files')
    if errors:
        print(f'check_dialogues: {len(errors)} problem(s)')
        for line in errors[:60]:
            print('  ', line)
        sys.exit(1)
    print(f'check_dialogues: {total} trees ok')


if __name__ == '__main__':
    main()
