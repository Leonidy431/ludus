"""The chorus's checks of the 144 insight branches of episode 1
(CLAUDE.md TABOO 0.021, 0.020, 0.025, 0.027, 0.37).

Technology in short (in full: docs/TECH_INSIGHT_RENDER_144_2026-10-03.md):
scripts/prerender/insight_variants.py writes the recipe of twelve
hours for each of the twelve insights (godot/data/pilot-insight-
variants.json); scripts/prerender/render_insights.py renders each
variant with Blender Cycles on the CPU, seed 1375 + v, 512 px, 56
samples, Open Image Denoise, into build/insight_variants/<id>/vNN.jpg
(never into godot/, so nothing enters the APK);
scripts/video/insight_variant_sheets.py lays them on contact sheets for
the chorus; scripts/story/insight_branches.py turns each variant into a
branch node (godot/data/pilot-insight-branches.json and the .md);
scripts/video/insights_variants_reel.py builds the two reels.  This
module checks the branch nodes, without Godot, so a plain Python test
(scripts/tests/test_insight_branches.py) and CI can run it.

What is checked, each a rule of the chorus:
* 12 insights x 12 variants = 144 nodes, ids unique and well formed;
* every branch converges into its insight's bridge_to, which is a real
  beat of godot/data/pilot-1.json, and all twelve of an insight into
  the same one (the bottleneck: no combinatorial explosion);
* no node of the holy place: no insight comes at the kayrak (id
  khachkar), so no branch may name it or converge into it;
* the voice-over has at most 40 words and every subtitle line at most
  140 characters; the voice speaks in the third person (no «я», «ты»);
* the bonus is +1, given by a dialogue answer, to one of the seven
  attributes and never to Faith or Cunning; no money, no inventory of
  price, nothing random;
* the video prompt excludes faces, halo and blood, and never uses the
  lampada's 1800 K for human fire;
* the human fire of the recipe stays inside 1900-2200 K.

    python3 scripts/story/check_branches.py      # exit 1 on any fault

Constitution: ФОРМА (the branch nodes as data) → ДЕЙСТВИЕ (check each
against the rules before it enters the game) → ЦЕЛЬ (the branches part
for a moment and meet again; the holy is never a branch).
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BRANCHES = ROOT / 'godot' / 'data' / 'pilot-insight-branches.json'
VARIANTS = ROOT / 'godot' / 'data' / 'pilot-insight-variants.json'
INSIGHTS = ROOT / 'godot' / 'data' / 'pilot-insights.json'
BEATS = ROOT / 'godot' / 'data' / 'pilot-1.json'
ATTRIBUTES = {'wisdom', 'faith', 'dexterity', 'constitution', 'charisma',
              'cunning', 'erudition'}
NO_BONUS = {'faith', 'cunning'}
HOLY = re.compile(r'khachkar|хачкар|кайрак', re.I)
FIRST_PERSON = re.compile(r'(^|[\s«(])(я|мне|меня|ты|тебя|тебе)'
                          r'([\s,.!?»)]|$)', re.I)
ID = re.compile(r'^v_[a-z_]+_(0[1-9]|1[0-2])$')
WORDS_MAX, LINE_MAX = 40, 140


def load(p):
    return json.loads(Path(p).read_text(encoding='utf-8'))


def check(branches, variants, insights, beats):
    """Return the list of faults; empty means the chorus accepts."""
    bad = []
    beat_ids = {b['id'] for b in beats['beats']}
    holy_beats = {b['id'] for b in beats['beats'] if b.get('holy')}
    bridge = {i['id']: i['bridge_to'] for i in insights['insights']}
    nodes = branches.get('nodes', [])
    if len(nodes) != 144:
        bad.append('%d nodes, not 144' % len(nodes))
    seen, conv = set(), {}
    for n in nodes:
        nid = n.get('node_id', '')
        if not ID.match(nid) or nid in seen:
            bad.append('bad or repeated id %r' % nid)
        seen.add(nid)
        iid = n.get('insight')
        if iid not in bridge:
            bad.append('%s: unknown insight %r' % (nid, iid))
            continue
        c = n.get('converges_to')
        conv.setdefault(iid, set()).add(c)
        if c != bridge[iid] or c not in beat_ids:
            bad.append('%s: converges to %r, not %r'
                       % (nid, c, bridge[iid]))
        if c in holy_beats:
            bad.append('%s: converges into the holy beat %s' % (nid, c))
        text = json.dumps(n, ensure_ascii=False)
        if HOLY.search(text):
            bad.append('%s: names the holy place' % nid)
        voice = n.get('voiceover_ru', '')
        if len(voice.split()) > WORDS_MAX:
            bad.append('%s: voice-over %d words' % (nid,
                                                    len(voice.split())))
        if FIRST_PERSON.search(voice):
            bad.append('%s: voice-over not in the third person' % nid)
        for line in n.get('subtitles_ru', []):
            if len(line) > LINE_MAX:
                bad.append('%s: subtitle of %d chars' % (nid, len(line)))
        if ' '.join(n.get('subtitles_ru', [])) != voice:
            bad.append('%s: subtitles differ from the voice-over' % nid)
        bonus = n.get('world', {}).get('dialogue_bonus', {})
        a = bonus.get('attribute')
        if a not in ATTRIBUTES or a in NO_BONUS:
            bad.append('%s: bonus to %r' % (nid, a))
        if bonus.get('amount') != 1 or bonus.get('by') != \
                'dialogue_answer' or bonus.get('beat') != c:
            bad.append('%s: bonus not +1 by a dialogue answer in %s'
                       % (nid, c))
        if n.get('world', {}).get('inventory'):
            bad.append('%s: branch puts things in the inventory' % nid)
        p = n.get('video_prompt', '')
        for must in ('face', 'halo', 'blood'):
            if must not in p:
                bad.append('%s: prompt does not exclude %s' % (nid, must))
        if re.search(r'(?<!never )\b1800 K', p):
            bad.append('%s: prompt uses 1800 K' % nid)
        for k in ('branch_ru', 'logic_ru', 'chorus', 'git_commit_msg'):
            if not n.get(k):
                bad.append('%s: no %s' % (nid, k))
        ch = n.get('chorus', '')
        if not (ch.startswith('−') and ch.count('/ +') == 2):
            bad.append('%s: chorus remark is not «− / + / +»' % nid)
    for iid, cs in conv.items():
        if len(cs) != 1:
            bad.append('%s: branches converge into %s' % (iid, sorted(cs)))
    for iid, vs in variants['variants'].items():
        if HOLY.search(iid):
            bad.append('variant of the holy place: %s' % iid)
        for v in vs:
            k = v['light'].get('fire_k')
            if k is not None and not 1900 <= k <= 2200:
                bad.append('%s v%02d: human fire at %s K' % (iid, v['v'],
                                                             k))
    return bad


def main():
    bad = check(load(BRANCHES), load(VARIANTS), load(INSIGHTS),
                load(BEATS))
    for b in bad:
        print('BAD', b)
    print('branches: %s' % ('ok' if not bad else '%d faults' % len(bad)))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
