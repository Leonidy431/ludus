"""One OSINT pass over the 99 cloned repos, driven by the game's deficits.

CLAUDE.md TABOO 0.15: every 1.5 hours the runner takes the next open
deficits from docs/DEFICITS_99_2026-09-29.md, searches the blobless index
of the 99 backlog repos for material, fetches only the chosen files, and
runs them through the raw-material pipeline (TABOO 0.1).  Only objects
that pass check_delta are copied into public/ludus/art/derived/<DEF-id>/.

Guru rules applied here (CLAUDE.md TABOO 0.35):
  3  the search starts from a deficit, never from browsing a repo;
  4  every fetched file is bound to a named slot (the deficit id);
  5  a dogmatic stop-list is checked BEFORE any measurement;
  6  holy things (icons, crosses, bells, vestments, churches) are never
     taken from raw material; they are our own drawings or synthesis;
  -  repositories without a licence file are skipped (all rights
     reserved), and every pass is appended to a log that is never
     deleted (TABOO 0.25, item 5).

Code deficits are not copied: matching source files are only listed in
docs/RAW_CODE_CANDIDATES.json, because code is rewritten by a person or
agent and measured with code_delta.py.

Usage:
    python3 scripts/raw_assets/osint_cycle.py --index /home/user/raw-repos \
        --deficits 3 --per-deficit 6
"""

import argparse
import datetime
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

from intake import is_game_object
from search_index import search

ROOT = Path(__file__).resolve().parents[2]
DEFICITS = ROOT / 'docs' / 'DEFICITS_99_2026-09-29.md'
CURSOR = ROOT / 'docs' / 'RAW_OSINT_CURSOR.json'
CODE_CANDIDATES = ROOT / 'docs' / 'RAW_CODE_CANDIDATES.json'
DERIVED = ROOT / 'public' / 'ludus' / 'art' / 'derived'
NOTICES = ROOT / 'THIRD_PARTY_NOTICES.md'
LADDER = ROOT / 'docs' / 'RAW_KEYWORD_LADDER.json'

# Operator, 2026-09-30: "каждый проход добавляй 12 ключевых слов".
KEYWORDS_PER_PASS = 12
# Path words that say nothing about the object itself.
PLAIN_WORDS = {'png', 'svg', 'jpg', 'gif', 'img', 'image', 'images', 'res',
               'assets', 'asset', 'data', 'art', 'gfx', 'graphics', 'src',
               'main', 'resources', 'textures', 'texture', 'sprites',
               'sprite', 'tiles', 'tile', 'items', 'item', 'objects',
               'object', 'png', 'core', 'base', 'default', 'small', 'large',
               'big', 'icon', 'icons', 'the', 'and', 'of', 'new', 'old',
               # Folder names of engines and repos, not things (the
               # hourly pass of 2026-09-30 added ref, source, rltiles).
               'ref', 'source', 'sources', 'internal', 'raw', 'rltiles',
               'dngn', 'crawl', 'fast', 'slow', 'common', 'misc', 'gui',
               'forge', 'adventure', 'mods', 'mod', 'build', 'dist',
               'public', 'static', 'lib', 'libs', 'game', 'games'}

# Rule 5: paths that must never enter the pipeline at all.
DOGMA_STOP = re.compile(
    r'pentagram|zodiac|occult|sigil|rune|idol|demon.?summon|necromanc|'
    r'holy.?weapon|cross.?sword|relic.?loot|halo|satan|ritual.?circle',
    re.IGNORECASE)

# Rule 6: holy things are never raw material; they are drawn or
# synthesised by the project itself.
SACRED = re.compile(
    r'church|temple|shrine|altar|priest|icon(?!s?/)|cross|crucifix|'
    r'bible|gospel|chalice|censer|bell|vestment|monk|nun|saint|angel|'
    r'christ|madonna|holy',
    re.IGNORECASE)

ROW = re.compile(r'^\| (DEF-\d{3}) \| (P\d) \| ([^|]+) \| ([^|]+) \| '
                 r'([^|]+) \| ([^|]+) \|.*\| ([^|]*) \| [^|]* \|$')

CODE_KINDS = {'code'}
IMAGE_KINDS = {'image'}

# Which index kinds a deficit may draw on.  The second trial matched the
# sound deficit DEF-002 to Mindustry "synthesizer" block sprites through
# the keyword "synth", so the category now decides the kind first.
# Sound waits for an audio pipeline (35 % spectral change) and theology
# or content deficits are never filled from raw material.
KINDS_BY_CATEGORY = {
    'графика': IMAGE_KINDS | CODE_KINDS,
    'локация': IMAGE_KINDS,
    'сочность': IMAGE_KINDS | CODE_KINDS,
    'код': CODE_KINDS,
    'конвейер': CODE_KINDS,
}


def open_deficits():
    """Parse the deficit table; keep rows whose status is still open."""
    rows = []
    for line in DEFICITS.read_text(encoding='utf-8').splitlines():
        found = ROW.match(line)
        if not found:
            continue
        def_id, prio, category, fill, status, title, keys = found.groups()
        # A deficit that a merged PR closed in part stays in rotation;
        # only a fully closed one leaves it.
        if not status.strip().startswith(('открыт', 'частично')):
            continue
        rows.append({'id': def_id, 'priority': prio,
                     'category': category.strip(), 'fill': fill.strip(),
                     'title': title.strip(),
                     'keywords': [k.strip() for k in keys.split(',')
                                  if k.strip()]})
    order = {'P0': 0, 'P1': 1, 'P2': 2, 'P3': 3}
    rows.sort(key=lambda r: (order.get(r['priority'], 9), r['id']))
    return rows


# Raw material helps only two kinds of deficit: images for raw-material
# ones and code candidates for code ones.  Procedural, own-drawing and
# content deficits are always skipped, so they no longer take a slot in
# a round (the rounds of 2026-09-29 spent most slots on skips).
USEFUL_FILLS = ('raw-material', 'code')


def rotation():
    """Deficits the runner works on, raw-material first, then code."""
    rows = [r for r in open_deficits() if r['fill'] in USEFUL_FILLS]
    rows.sort(key=lambda r: r['fill'] != 'raw-material')
    return rows


def load_cursor():
    if CURSOR.exists():
        return json.loads(CURSOR.read_text(encoding='utf-8'))
    return {'next': 0, 'log': []}


# The first trial pass took engine example screenshots
# (examples/audio/*.png) because their paths contain "audio" and "sound";
# such files are documentation, not game objects.
NOT_GAME = re.compile(r'(^|/)(examples?|docs?|tests?|screenshots?|'
                      r'tutorials?|demo|editor|tools?)/', re.IGNORECASE)


# Only the passion slot turns raw sprites into antagonists; every other
# raw-material slot is neutral matter (fish, stones, wood) and takes the
# thing itself.  Hostile sprites never fill a neutral slot.
ANTAGONIST_SLOTS = {'DEF-001'}
HOSTILE = re.compile(r'(^|/)(enemy|enemies|monsters?|mobs?|fiends?|'
                     r'demons?|undead|bosses|boss|humanoids?|soldiers?|'
                     r'orcs?|goblins?|skull\w*|abyss\w*|vaults?|mon|'
                     r'turrets?|weapons?)'
                     r'(/|_|\.|$)', re.IGNORECASE)


# Round 4 of 2026-09-30 took wesnoth "*-outline.png" files: one-pixel
# selection outlines drawn by the engine around a unit, not the unit.
# Their antagonist variants were near-empty strokes, so they were
# reverted; such helper frames are refused before any fetch.
OUTLINE = re.compile(r'[-_+]outline\.[a-z]+$', re.IGNORECASE)


def allowed(path):
    """Apply the stop-lists; return the reason when a path is refused."""
    if NOT_GAME.search(path) or not is_game_object(path):
        return 'not-a-game-object'
    if OUTLINE.search(path):
        return 'outline-helper'
    if DOGMA_STOP.search(path):
        return 'dogma-stop-list'
    if SACRED.search(path):
        return 'sacred-never-raw'
    return None


def fetch(index_root, hit, dest_root):
    """Materialise one blob from the blobless clone (git fetches it)."""
    repo = hit['repo'].split('github.com/')[-1].replace('/', '__')
    clone = Path(index_root) / 'clones' / repo
    dest = Path(dest_root) / repo / hit['path']
    dest.parent.mkdir(parents=True, exist_ok=True)
    blob = subprocess.run(['git', 'show', f'HEAD:{hit["path"]}'],
                          cwd=clone, check=True, capture_output=True,
                          timeout=300).stdout
    dest.write_bytes(blob)
    return dest


def licence_of(index_root, hit):
    """Read the SPDX guess from the index header of the hit's repo."""
    repo = hit['repo'].split('github.com/')[-1].replace('/', '__')
    header = json.loads((Path(index_root) / 'index' / f'{repo}.jsonl')
                        .read_text(encoding='utf-8').splitlines()[0])
    head = header['header']['license_head'].upper()
    for spdx, mark in (('AGPL-3.0', 'AFFERO'), ('LGPL', 'LESSER GENERAL'),
                       ('GPL', 'GNU GENERAL PUBLIC'),
                       ('MIT', 'PERMISSION IS HEREBY GRANTED'),
                       ('Apache-2.0', 'APACHE LICENSE'),
                       ('MPL-2.0', 'MOZILLA PUBLIC'),
                       ('CC-BY-SA', 'ATTRIBUTION-SHAREALIKE'),
                       ('CC0-1.0', 'CC0'), ('BSD', 'REDISTRIBUTION AND USE'),
                       ('Zlib', 'ALTERED SOURCE')):
        if mark in head:
            return spdx
    return 'UNKNOWN'


def ladder_words(def_id):
    """The real-object keyword ladder of a deficit, if it has one."""
    if not LADDER.exists():
        return []
    return json.loads(LADDER.read_text('utf-8'))['ladders'].get(def_id, [])


def neighbour_words(hits, known):
    """Most frequent path words next to earlier hits, not yet keys.

    When the real-object ladder runs out, the next words come from the
    material itself: the folder and file words that stand beside what
    was already found.  Stop-listed, sacred and hostile words never
    become keys.
    """
    counts = {}
    for hit in hits:
        for word in re.split(r'[^a-z]+', hit['path'].lower()):
            if (len(word) < 3 or word in PLAIN_WORDS or word in known
                    or DOGMA_STOP.search(word) or SACRED.search(word)
                    or HOSTILE.search(word) or word.isdigit()):
                continue
            counts[word] = counts.get(word, 0) + 1
    return [w for w, _ in sorted(counts.items(), key=lambda x: (-x[1], x[0]))]


def grow_keywords(deficit, cursor, index, kinds):
    """Add the next twelve keywords of a deficit; return the added ones.

    Deterministic: the real-object ladder first, in its written order,
    then neighbour words ranked by frequency and name.
    """
    added = cursor.setdefault('keywords', {}).setdefault(deficit['id'], [])
    known = set(deficit['keywords']) | set(added)
    fresh = [w for w in ladder_words(deficit['id']) if w not in known]
    new = fresh[:KEYWORDS_PER_PASS]
    if len(new) < KEYWORDS_PER_PASS:
        hits = search(index, kinds, deficit['keywords'] + added, limit=400,
                      allow_unlicensed=False)
        hits = [h for h in hits if not allowed(h['path'])]
        more = neighbour_words(hits, known | set(new))
        new += more[:KEYWORDS_PER_PASS - len(new)]
    added.extend(new)
    return new


def run(cmd):
    subprocess.run(cmd, check=True, cwd=ROOT, timeout=3600)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--index', default='/home/user/raw-repos')
    parser.add_argument('--work', default='build/osint')
    parser.add_argument('--deficits', type=int, default=3)
    parser.add_argument('--per-deficit', type=int, default=6)
    parser.add_argument('--only', default='',
                        help='comma-separated deficit ids; the rotation '
                             'cursor is left where it is')
    args = parser.parse_args()

    work = ROOT / args.work
    shutil.rmtree(work, ignore_errors=True)
    raw_dir, out_dir = work / 'raw', work / 'derived'
    raw_dir.mkdir(parents=True)

    deficits = rotation()
    cursor = load_cursor()
    if not deficits:
        print('no open deficits')
        return
    if args.only:
        wanted = args.only.split(',')
        chosen = [d for d in deficits if d['id'] in wanted]
    else:
        start = cursor['next'] % len(deficits)
        chosen = (deficits[start:] + deficits[:start])[:args.deficits]
        cursor['next'] = start + len(chosen)

    stamp = datetime.datetime.now(datetime.timezone.utc).isoformat()
    manifest, code_hits, entry = [], [], {'time': stamp, 'deficits': []}
    for deficit in chosen:
        kinds = KINDS_BY_CATEGORY.get(deficit['category'])
        # The fourth pass filled DEF-004 (the gate-opening moment) with
        # dungeon doors and DEF-006 (bubble columns) with a watermelon:
        # both deficits are meant to be procedural.  Images are taken only
        # where the deficit asks for raw material; code deficits still
        # list code candidates, which are rewritten, never copied.
        if deficit['fill'] != 'raw-material':
            kinds = (kinds or set()) & CODE_KINDS
        if not kinds:
            reason = ('audio-pipeline-pending' if deficit['category'] == 'звук'
                      else 'not-raw-material')
            entry['deficits'].append({'id': deficit['id'], 'skipped': reason})
            print(f'{deficit["id"]}: skipped ({reason})')
            continue
        grown = grow_keywords(deficit, cursor, args.index, kinds)
        keys = deficit['keywords'] + cursor['keywords'][deficit['id']]
        print(f'{deficit["id"]}: +{len(grown)} keywords {grown}')
        hits = search(args.index, kinds, keys, limit=200,
                      allow_unlicensed=False)
        taken, refused = 0, {}
        neutral = deficit['id'] not in ANTAGONIST_SLOTS
        for hit in hits:
            reason = allowed(hit['path'])
            if not reason and neutral and hit['kind'] not in CODE_KINDS \
                    and HOSTILE.search(hit['path']):
                reason = 'hostile-for-neutral-slot'
            if reason:
                refused[reason] = refused.get(reason, 0) + 1
                continue
            if hit['kind'] in CODE_KINDS:
                code_hits.append({**hit, 'slot': deficit['id']})
                continue
            if taken >= args.per_deficit or not hit['path'].lower() \
                    .endswith('.png'):
                continue
            try:
                local = fetch(args.index, hit, raw_dir)
            except (subprocess.SubprocessError, OSError) as exc:
                refused['fetch-error'] = refused.get('fetch-error', 0) + 1
                print(f'fetch failed {hit["path"]}: {exc}', file=sys.stderr)
                continue
            manifest.append({
                'repo': hit['repo'], 'commit': hit['commit'],
                'license': licence_of(args.index, hit),
                'license_file': hit['license_file'],
                'attribution': hit['attribution'],
                'path': hit['path'], 'local': str(local),
                'bytes': local.stat().st_size, 'slot': deficit['id'],
                'neutral': neutral,
            })
            taken += 1
        entry['deficits'].append({'id': deficit['id'], 'hits': len(hits),
                                  'taken': taken, 'refused': refused,
                                  'added_keywords': grown,
                                  'keywords_total': len(keys)})
        print(f'{deficit["id"]}: hits={len(hits)} taken={taken} '
              f'refused={refused}')

    (raw_dir / 'manifest.json').write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), 'utf-8')
    accepted = 0
    if manifest:
        run([sys.executable, 'scripts/raw_assets/transform.py',
             '--raw', str(raw_dir), '--out', str(out_dir)])
        run([sys.executable, 'scripts/raw_assets/register.py',
             '--derived', str(out_dir),
             '--notices', str(work / 'NOTICES.md')])
        slots = {m['path']: m['slot'] for m in manifest}
        report = json.loads((out_dir / 'report.json').read_text('utf-8'))
        shipped = set()
        for rec in report['accepted']:
            # Fewer than twelve variants never ships (TABOO 0.1: never
            # stop at eleven); such objects stay in the build for review.
            if rec.get('status') != 'ok':
                continue
            slot = slots.get(rec['path'], 'unslotted')
            dest = DERIVED / slot
            dest.mkdir(parents=True, exist_ok=True)
            for f in out_dir.glob(f'{rec["name"]}*'):
                if f.suffix in ('.png', '.json'):
                    shutil.copy2(f, dest / f.name)
            shipped.add(rec['name'])
            accepted += 1
        run([sys.executable, 'scripts/raw_assets/check_delta.py',
             '--root', str(DERIVED), '--threshold', '0.35'])
        # The register only grows: rows are appended, never rewritten.
        # Only what shipped is registered; a shortfall stays out.
        rows = [line for line in (work / 'NOTICES.md').read_text('utf-8')
                .splitlines()
                if line.startswith(('| ant_', '| obj_'))
                and line.split('|')[1].strip() in shipped]
        existing = NOTICES.read_text('utf-8') if NOTICES.exists() else (
            '# Third-party raw material register\n\n| Object | Source | '
            'Commit | Path | Licence | Colour | Shape |\n'
            '|---|---|---|---|---|---|---|\n')
        new = [r for r in rows if r not in existing]
        NOTICES.write_text(existing.rstrip('\n') + '\n'
                           + '\n'.join(new) + ('\n' if new else ''),
                           'utf-8')

    if code_hits:
        known = (json.loads(CODE_CANDIDATES.read_text('utf-8'))
                 if CODE_CANDIDATES.exists() else [])
        seen = {(c['repo'], c['path']) for c in known}
        known += [c for c in code_hits if (c['repo'], c['path']) not in seen]
        CODE_CANDIDATES.write_text(
            json.dumps(known, ensure_ascii=False, indent=1), 'utf-8')

    entry['accepted_objects'] = accepted
    entry['code_candidates'] = len(code_hits)
    cursor['log'].append(entry)
    CURSOR.write_text(json.dumps(cursor, ensure_ascii=False, indent=1),
                      'utf-8')
    print(f'pass done: {accepted} objects accepted, '
          f'{len(code_hits)} code candidates listed')


if __name__ == '__main__':
    main()
