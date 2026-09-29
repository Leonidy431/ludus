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
        if status.strip() != 'открыт':
            continue
        rows.append({'id': def_id, 'priority': prio,
                     'category': category.strip(), 'fill': fill.strip(),
                     'title': title.strip(),
                     'keywords': [k.strip() for k in keys.split(',')
                                  if k.strip()]})
    order = {'P0': 0, 'P1': 1, 'P2': 2, 'P3': 3}
    rows.sort(key=lambda r: (order.get(r['priority'], 9), r['id']))
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


def allowed(path):
    """Apply the stop-lists; return the reason when a path is refused."""
    if NOT_GAME.search(path) or not is_game_object(path):
        return 'not-a-game-object'
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


def run(cmd):
    subprocess.run(cmd, check=True, cwd=ROOT, timeout=3600)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--index', default='/home/user/raw-repos')
    parser.add_argument('--work', default='build/osint')
    parser.add_argument('--deficits', type=int, default=3)
    parser.add_argument('--per-deficit', type=int, default=6)
    args = parser.parse_args()

    work = ROOT / args.work
    shutil.rmtree(work, ignore_errors=True)
    raw_dir, out_dir = work / 'raw', work / 'derived'
    raw_dir.mkdir(parents=True)

    deficits = open_deficits()
    cursor = load_cursor()
    if not deficits:
        print('no open deficits')
        return
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
        hits = search(args.index, kinds, deficit['keywords'], limit=200,
                      allow_unlicensed=False)
        taken, refused = 0, {}
        for hit in hits:
            reason = allowed(hit['path'])
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
            })
            taken += 1
        entry['deficits'].append({'id': deficit['id'], 'hits': len(hits),
                                  'taken': taken, 'refused': refused})
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
        for rec in report['accepted']:
            slot = slots.get(rec['path'], 'unslotted')
            dest = DERIVED / slot
            dest.mkdir(parents=True, exist_ok=True)
            for f in out_dir.glob(f'{rec["name"]}*'):
                if f.suffix in ('.png', '.json'):
                    shutil.copy2(f, dest / f.name)
            accepted += 1
        run([sys.executable, 'scripts/raw_assets/check_delta.py',
             '--root', str(DERIVED), '--threshold', '0.35'])
        # The register only grows: rows are appended, never rewritten.
        rows = [line for line in (work / 'NOTICES.md').read_text('utf-8')
                .splitlines() if line.startswith('| ant_')]
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
