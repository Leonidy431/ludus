"""The props store: what the runner finds but the game may not use yet.

CLAUDE.md TABOO 0.012 (operator, 2026-09-30): "бери все даже не игровое
нам в реквизит".  A deficit search hit that the runner refuses only
because it is not a game object (an engine example, a screenshot, an
editor image, a test fixture, a promo page, a tool) is no longer
dropped.  Its bytes are read from the blobless clone into a props cache
outside the repository, and the thing is written into the append-only
register docs/RAW_PROPS_REGISTER.json with its repo, revision, path,
licence, kind, deficit, keywords, sha1 and size.

Three things never become props, exactly as before (TABOO 0.2 and
0.35 rules 5-6): holy things, the dogmatic stop-list and fonts.
Nothing at all is taken from a repository without a licence file.
The routing that decides this lives in osint_cycle.py; this module
checks it again through a guard, so a caller cannot slip past it.

Nothing from the store enters public/ludus/art/derived, godot/ or the
APK by itself.  A slot that wants a prop asks for it by key:

    python3 scripts/raw_assets/osint_cycle.py \
        --props-to-slot p_1a2b3c4d5e6f DEF-056

That restores the exact bytes (sha1 checked), runs the TABOO 0.1
pipeline (transform.py, register.py) into build/props/, draws a
contact sheet on the five biomes and stops.  Shipping stays a human
step after the eye check, as for every raw pass.
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REGISTER = ROOT / 'docs' / 'RAW_PROPS_REGISTER.json'
DERIVED = ROOT / 'public' / 'ludus' / 'art' / 'derived'
GODOT = ROOT / 'godot'
WORK = ROOT / 'build' / 'props'
DEFAULT_CACHE = os.environ.get('LUDUS_PROPS_CACHE', '/home/user/raw-props')

SCHEMA = 'ludus.raw-props.v1'
RULE = ('CLAUDE.md TABOO 0.012: append-only; entries are never edited or '
        'deleted. Bytes live in the props cache outside the repo.')

# The kinds a prop may have, in the order they are tested: the more
# specific place wins, so docs/screenshots/x.png is a screenshot.
PROP_KINDS = ('screenshot', 'promo', 'test', 'editor', 'doc', 'example',
              'other')


def _words(*words):
    # Whole words of a path only: "store" must not match "restore",
    # nor "press" match "compress" (the search learned this with
    # "pike" and "pikeman").
    return re.compile(r'(^|[^a-z])(' + '|'.join(words) + r')([^a-z]|$)')


_KIND_PATTERNS = (
    # Not "screens/": the first real pass (2026-09-30T13:31Z) filed 171
    # UI classes of Unciv and Forge (ui/screens/*.kt) as screenshots.
    ('screenshot', re.compile(r'screen_?shots?|(^|[^a-z])scrn')),
    ('promo', _words('promo\\w*', 'store', 'banners?', 'logos?',
                     'feature_?graphic', 'marketing', 'press', 'metadata',
                     'splash\\w*', 'fastlane', 'social')),
    ('test', _words('tests?', 'testing', 'specs?', 'testdata',
                    'test_?data', 'fixtures?', 'unittests?')),
    ('editor', re.compile(r'editor|(^|[^a-z])tools?([^a-z]|$)')),
    ('doc', _words('docs?', 'documentation', 'manuals?', 'tutorials?',
                   'guides?', 'wiki', 'help')),
    ('example', _words('examples?', 'samples?', 'demos?')),
)

# The cache path is not stored: it follows from repo, revision and path
# (cache_rel), and on the first pass it was the largest field, 116 of
# 641 bytes a line.
FIELDS = ('key', 'repo', 'revision', 'path', 'licence', 'licence_file',
          'attribution', 'kind', 'index_kind', 'deficit_id', 'keywords',
          'pass_id', 'sha1', 'bytes')

# TABOO 0.011 and 0.012 p. 4: the store must not swell the repo.  The
# bytes live outside it; only this text register travels with the code.
# Measured on the pass of 2026-09-30T13:38Z: 127 new lines, 579 bytes a
# line on average (73 668 bytes), so a pass of three deficits adds at
# most 3 x 200 lines, about 0.35 MB.  8 MB holds about 13 800 things;
# past it the runner stops shelving and says so in the journal, and the
# operator decides where a larger register lives
# (docs/HLD_PROPS_STORE_2026-09-30.md).
REGISTER_BUDGET_BYTES = 8_000_000


class AppendOnlyError(RuntimeError):
    """Raised when a save would change or drop a register entry."""


def prop_kind(path):
    """Classify a prop by where it lies in its repository."""
    low = str(path).lower()
    for kind, pattern in _KIND_PATTERNS:
        if pattern.search(low):
            return kind
    return 'other'


def is_font(path):
    """Fonts were excluded before TABOO 0.012 and stay excluded.

    The substring test is the same one intake.is_game_object uses
    ("font" in EXCLUDE_WORDS), so the exclusion is exactly as it was;
    font files are also named by their own extensions.
    """
    low = str(path).lower()
    return 'font' in low or low.endswith(
        ('.ttf', '.otf', '.woff', '.woff2', '.fnt', '.bdf', '.pcf', '.pfb'))


def prop_key(repo, revision, path):
    """Stable key of one thing: the same repo, revision and path."""
    raw = f'{repo}\n{revision}\n{path}'.encode('utf-8')
    return 'p_' + hashlib.sha1(raw).hexdigest()[:12]


def repo_dir(repo):
    """owner__name, the folder name the index and clones use."""
    return repo.split('github.com/')[-1].replace('/', '__')


def cache_rel(repo, revision, path):
    """Where a prop lies inside the cache.

    The revision is part of the path: when upstream moves, the same
    path may hold other bytes, and an earlier entry must keep its file.
    """
    return f'{repo_dir(repo)}/{revision[:12]}/{path}'


def check_cache_outside(cache_root):
    """The cache must not be inside the repository (TABOO 0.012 p. 4).

    Inside the repo it would be one `git add` away from the tree and the
    APK; outside it, only the text register travels with the code.
    """
    cache = Path(cache_root).resolve()
    if cache == ROOT or ROOT in cache.parents:
        raise ValueError(f'props cache {cache} is inside the repo {ROOT}; '
                         'use a folder outside it (--props-cache)')
    return cache


# --- Register ------------------------------------------------------------

def empty_register():
    return {'schema': SCHEMA, 'rule': RULE, 'entries': []}


def load_register(path=REGISTER):
    path = Path(path)
    if not path.exists():
        return empty_register()
    return json.loads(path.read_text('utf-8'))


def _lines(key, rows):
    if not rows:
        return ''
    body = ',\n'.join(json.dumps(r, ensure_ascii=False, sort_keys=True)
                      for r in rows)
    return f',\n"{key}": [\n{body}\n]'


def dump_register(register):
    """One entry per line: a pass shows in git as appended lines only."""
    head = json.dumps({'schema': register['schema'],
                       'rule': register['rule']}, ensure_ascii=False)
    lines = [json.dumps(e, ensure_ascii=False, sort_keys=True)
             for e in register['entries']]
    body = ',\n'.join(lines)
    return (head[:-1] + ',\n"entries": [\n' + body
            + ('\n' if lines else '') + ']'
            + _lines('withdrawn', register.get('withdrawn')) + '}\n')


def withdraw(register, key, reason, date):
    """Name a shelved thing that may no longer be used, without deleting.

    If the holy list or the stop-list later grows over something already
    on the shelf, its line stays (the register only grows) and a
    withdrawal line says why; to_slot refuses a withdrawn key.
    """
    if key not in {e['key'] for e in register['entries']}:
        raise KeyError(key)
    register.setdefault('withdrawn', []).append(
        {'key': key, 'reason': reason, 'date': date})


def save_register(register, path=REGISTER):
    """Write the register; refuse anything but appended entries.

    The journal rule (TABOO 0.25 p. 5, 0.012 p. 5) says what was taken
    stays written, so every earlier entry and withdrawal must come back
    unchanged and in its place.
    """
    path = Path(path)
    loaded = load_register(path)
    for part in ('entries', 'withdrawn'):
        old, new = loaded.get(part, []), register.get(part, [])
        if new[:len(old)] != old:
            raise AppendOnlyError(f'{path}: an existing {part} line was '
                                  'changed or removed; the props register '
                                  'only grows')
    new = register['entries']
    keys = [e['key'] for e in new]
    if len(keys) != len(set(keys)):
        raise AppendOnlyError(f'{path}: duplicate key')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(dump_register(register), 'utf-8')
    return path.stat().st_size


def validate_entry(entry):
    """Return a list of schema problems of one entry (empty when fine)."""
    problems = [f'missing {f}' for f in FIELDS if f not in entry]
    if problems:
        return problems
    if set(entry) - set(FIELDS):
        problems.append(f'unknown fields {sorted(set(entry) - set(FIELDS))}')
    if entry['kind'] not in PROP_KINDS:
        problems.append(f'kind {entry["kind"]!r}')
    if not entry['licence_file']:
        problems.append('no licence file')
    if entry['key'] != prop_key(entry['repo'], entry['revision'],
                                entry['path']):
        problems.append('key does not match repo, revision and path')
    if len(entry['sha1']) != 40 or not isinstance(entry['bytes'], int):
        problems.append('sha1 or bytes malformed')
    if not str(entry['deficit_id']).startswith('DEF-'):
        problems.append('deficit id')
    return problems


def store_totals(register):
    """Files and bytes of the store by the register, and by kind."""
    by_kind = {}
    for e in register['entries']:
        by_kind[e['kind']] = by_kind.get(e['kind'], 0) + 1
    return {'files': len(register['entries']),
            'bytes': sum(e['bytes'] for e in register['entries']),
            'by_kind': dict(sorted(by_kind.items()))}


# --- Reading the bytes ---------------------------------------------------

def _git(clone, *args, data=None):
    return subprocess.run(['git', *args], cwd=clone, input=data,
                          capture_output=True, timeout=900)


def read_blobs(clone, revision, paths):
    """Read many files of one revision; return {path: bytes}.

    One `git show` per file makes the blobless clone fetch every blob
    on its own (about 0.6 s each through the proxy).  Here the blob ids
    come from the local trees, the missing blobs arrive in one fetch,
    and `git cat-file --batch` reads them all; a probe on BrogueCE read
    four files in 0.5 s instead of 1.7 s for three.
    """
    listing = _git(clone, '--literal-pathspecs', 'ls-tree', '-z',
                   revision, '--', *paths)
    if listing.returncode:
        # A depth-1 clone made after upstream moved does not hold the
        # pinned revision; fetch just that commit's trees and retry, so
        # a register line can always be taken again (restore()).
        _git(clone, 'fetch', '--depth', '1', '--filter=blob:none',
             '--no-tags', 'origin', revision)
        listing = _git(clone, '--literal-pathspecs', 'ls-tree', '-z',
                       revision, '--', *paths)
    if listing.returncode:
        raise OSError(listing.stderr.decode('utf-8', 'replace')[:300])
    oids = {}
    for rec in listing.stdout.split(b'\0'):
        if not rec:
            continue
        meta, name = rec.split(b'\t', 1)
        _mode, otype, oid = meta.split()
        if otype == b'blob':
            oids[name.decode('utf-8', 'surrogateescape')] = oid.decode()
    wanted = [oids[p] for p in paths if p in oids]
    if not wanted:
        return {}
    promisor = _git(clone, 'config', '--get', 'remote.origin.promisor')
    if promisor.stdout.strip() == b'true':
        # The same command git runs for a lazy fetch, with all ids at
        # once.  A failure here is not fatal: cat-file still fetches
        # each missing blob on demand.
        _git(clone, '-c', 'fetch.negotiationAlgorithm=noop', 'fetch',
             'origin', '--no-tags', '--no-write-fetch-head',
             '--recurse-submodules=no', '--filter=blob:none', '--stdin',
             data=('\n'.join(wanted) + '\n').encode())
    batch = _git(clone, 'cat-file', '--batch',
                 data=('\n'.join(wanted) + '\n').encode())
    if batch.returncode:
        raise OSError(batch.stderr.decode('utf-8', 'replace')[:300])
    blobs, out, pos = {}, batch.stdout, 0
    for oid in wanted:
        end = out.index(b'\n', pos)
        head = out[pos:end].split()
        pos = end + 1
        if len(head) < 3 or head[1] == b'missing':
            continue
        size = int(head[2])
        blobs[oid] = out[pos:pos + size]
        pos += size + 1
    return {p: blobs[o] for p, o in oids.items() if o in blobs}


# --- Taking props --------------------------------------------------------

def _entry(key, hit, deficit_id, licence, pass_id, data):
    return {
        'key': key, 'repo': hit['repo'], 'revision': hit['commit'],
        'path': hit['path'], 'licence': licence,
        'licence_file': hit['license_file'],
        'attribution': list(hit.get('attribution') or []),
        'kind': prop_kind(hit['path']), 'index_kind': hit['kind'],
        'deficit_id': deficit_id,
        'keywords': list(hit.get('hits') or []),
        'pass_id': pass_id,
        'sha1': hashlib.sha1(data).hexdigest(), 'bytes': len(data),
    }


def _line_bytes(entry):
    # One register line plus its ",\n" separator.
    return len(json.dumps(entry, ensure_ascii=False, sort_keys=True)
               .encode('utf-8')) + 2


def take(candidates, register, index_root, cache_root, pass_id,
         licence_of, guard, budget=REGISTER_BUDGET_BYTES):
    """Fetch every candidate prop into the cache and register it.

    candidates: list of (hit, deficit_id) in the runner's own order,
    which is deterministic (score, repo, path).  guard(path) must say
    True for a path that is a prop and nothing else; it is checked
    again here so a caller cannot put a holy or stop-listed thing on
    the shelf.  A thing that would push the register past its budget
    is not fetched at all, so the cache never holds what the register
    does not name.  Returns the counts for the journal.
    """
    cache = check_cache_outside(cache_root)
    known = {e['key'] for e in register['entries']}
    stats = {'taken': {}, 'duplicates': 0, 'errors': 0, 'refused': {},
             'new_bytes': 0, 'by_deficit': {}}
    licences = {}
    room = budget - len(dump_register(register).encode('utf-8'))
    todo = {}

    def refuse(reason):
        stats['refused'][reason] = stats['refused'].get(reason, 0) + 1

    for hit, deficit_id in candidates:
        if not hit.get('license_file'):
            refuse('no-licence')
            continue
        if not guard(hit['path']):
            refuse('not-a-prop')
            continue
        key = prop_key(hit['repo'], hit['commit'], hit['path'])
        if key in known:
            stats['duplicates'] += 1
            continue
        if hit['repo'] not in licences:
            # One read of the index header per repo, not per file.
            licences[hit['repo']] = licence_of(hit)
        # The size of the line is known before the fetch: sha1 and a
        # ten-digit size stand in for the real ones.
        guess = _line_bytes(_entry(key, hit, deficit_id,
                                   licences[hit['repo']], pass_id,
                                   b'')) + 10
        if guess > room:
            refuse('props-budget')
            continue
        room -= guess
        known.add(key)
        todo.setdefault((hit['repo'], hit['commit']), []).append(
            (key, hit, deficit_id))
    # Repos in sorted order, entries in the runner's order within each,
    # so two runs over the same index write the same register.
    new_entries = {}
    for (repo, revision), items in sorted(todo.items()):
        clone = Path(index_root) / 'clones' / repo_dir(repo)
        try:
            blobs = read_blobs(clone, revision, [h['path'] for _, h, _ in
                                                 items])
        except (subprocess.SubprocessError, OSError, ValueError) as exc:
            print(f'props: cannot read {repo}: {exc}', file=sys.stderr)
            blobs = {}
        for key, hit, deficit_id in items:
            data = blobs.get(hit['path'])
            if data is None:
                stats['errors'] += 1
                continue
            dest = cache / cache_rel(repo, revision, hit['path'])
            try:
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(data)
            except OSError as exc:
                # An unwritable cache must not stop the hourly pass; the
                # thing is not taken, so it is not registered either.
                print(f'props: cannot write {dest}: {exc}', file=sys.stderr)
                stats['errors'] += 1
                continue
            new_entries[key] = _entry(key, hit, deficit_id,
                                      licences[repo], pass_id, data)
            kind = new_entries[key]['kind']
            stats['taken'][kind] = stats['taken'].get(kind, 0) + 1
            per = stats['by_deficit'].setdefault(deficit_id, {})
            per[kind] = per.get(kind, 0) + 1
            stats['new_bytes'] += len(data)
    # Append in the candidates' order, not the per-repo fetch order.
    for hit, _deficit_id in candidates:
        key = prop_key(hit['repo'], hit['commit'], hit['path'])
        if key in new_entries:
            register['entries'].append(new_entries.pop(key))
    stats['taken'] = dict(sorted(stats['taken'].items()))
    return stats


def cache_bytes_on_disk(cache_root):
    """What the store really weighs on disk (the register may be ahead
    of a fresh cache on a CI runner, see restore())."""
    root = Path(cache_root)
    if not root.exists():
        return 0
    return sum(p.stat().st_size for p in root.rglob('*') if p.is_file())


def restore(entry, index_root, cache_root):
    """Return the cached file of an entry, re-reading it if needed.

    The free CI runner starts with an empty cache, so a prop taken
    there lives on as its register line; the pinned revision and sha1
    let any later run take exactly the same bytes again.
    """
    cache = check_cache_outside(cache_root)
    dest = cache / cache_rel(entry['repo'], entry['revision'], entry['path'])
    if dest.exists() and hashlib.sha1(
            dest.read_bytes()).hexdigest() == entry['sha1']:
        return dest
    clone = Path(index_root) / 'clones' / repo_dir(entry['repo'])
    data = read_blobs(clone, entry['revision'], [entry['path']]).get(
        entry['path'])
    if data is None or hashlib.sha1(data).hexdigest() != entry['sha1']:
        raise OSError(f'{entry["key"]}: bytes at {entry["revision"][:12]} '
                      'do not match the register sha1')
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(data)
    return dest


# --- From the shelf to a slot --------------------------------------------

def to_slot(key, deficit_id, index_root, cache_root, work=WORK,
            register_path=REGISTER, runner=None):
    """Prepare one prop for a slot through the TABOO 0.1 pipeline.

    Writes only under build/props/ (ignored by git, outside godot/) and
    never copies anything into public/ludus/art/derived: after the eye
    check on the contact sheet a person ships it as for any raw pass.
    Returns the plan and the outputs as a dict.
    """
    # Imported here: osint_cycle imports this module.
    import osint_cycle

    work = Path(work).resolve()
    for forbidden in (DERIVED, GODOT):
        if work == forbidden or forbidden in work.parents:
            raise ValueError(f'{work} lies in {forbidden}; props are '
                             'prepared in build/props only')
    register = load_register(register_path)
    entry = next((e for e in register['entries'] if e['key'] == key),
                 None)
    if entry is None:
        raise KeyError(f'{key} is not in {register_path}')
    gone = [w for w in register.get('withdrawn', []) if w['key'] == key]
    if gone:
        raise ValueError(f'{key} was withdrawn: {gone[-1]["reason"]}')
    # The shelf is checked again: a stop-list may have grown since.
    if not osint_cycle.is_prop(entry['path']) or not entry['licence_file']:
        raise ValueError(f'{key} ({entry["path"]}) is no longer a prop: '
                         f'{osint_cycle.reasons(entry["path"])}')
    deficit = next((d for d in osint_cycle.open_deficits()
                    if d['id'] == deficit_id), None)
    if deficit is None:
        raise ValueError(f'{deficit_id} is not an open deficit')

    kinds = osint_cycle.slot_kinds(deficit)
    if entry['index_kind'] not in kinds:
        # The same rule as the pass: round 4 of 2026-09-30 gave doors to
        # a gate and a watermelon to bubbles when images went to
        # procedural slots.
        raise ValueError(f'{deficit_id} ({deficit["category"]}, '
                         f'{deficit["fill"]}) takes {sorted(kinds)}; this '
                         f'prop is {entry["index_kind"]}')
    plan = {'key': key, 'deficit_id': deficit_id, 'path': entry['path'],
            'licence': entry['licence'], 'index_kind': entry['index_kind'],
            'shipped': False}
    if entry['index_kind'] in osint_cycle.CODE_KINDS:
        # Code is never copied into the game (TABOO 0.15 p. 7): it is
        # read, rewritten in the project's language and measured.
        local = restore(entry, index_root, cache_root)
        plan['route'] = 'code-rewrite'
        plan['next'] = (f'rewrite as our own module, then: python3 '
                        f'scripts/raw_assets/code_delta.py {local} <ours> '
                        f'--source-repo {entry["repo"]} --license '
                        f'{entry["licence"]} (>= 35 % or it is not ours)')
        return plan
    if not entry['path'].lower().endswith('.png'):
        raise ValueError(f'{entry["path"]}: the pipeline reads PNG only')

    local = restore(entry, index_root, cache_root)
    job = work / f'{key}-{deficit_id}'
    shutil.rmtree(job, ignore_errors=True)
    raw_dir, out_dir = job / 'raw', job / 'derived'
    raw_dir.mkdir(parents=True)
    copy = raw_dir / Path(entry['path']).name
    shutil.copy2(local, copy)
    manifest = [{
        'repo': entry['repo'], 'commit': entry['revision'],
        'license': entry['licence'], 'license_file': entry['licence_file'],
        'attribution': entry['attribution'], 'path': entry['path'],
        'local': str(copy), 'bytes': entry['bytes'], 'slot': deficit_id,
        'neutral': deficit_id not in osint_cycle.ANTAGONIST_SLOTS,
        'prop_key': key,
    }]
    (raw_dir / 'manifest.json').write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), 'utf-8')
    run = runner or (lambda cmd: subprocess.run(cmd, check=True, cwd=ROOT,
                                                timeout=3600))
    here = Path(__file__).resolve().parent
    run([sys.executable, str(here / 'transform.py'), '--raw', str(raw_dir),
         '--out', str(out_dir)])
    run([sys.executable, str(here / 'register.py'), '--derived',
         str(out_dir), '--notices', str(job / 'NOTICES.md')])
    plan.update({'route': 'image-pipeline', 'work': str(job),
                 'sheet': str(job / 'contact.png')})
    report_path = out_dir / 'report.json'
    if report_path.exists():
        report = json.loads(report_path.read_text('utf-8'))
        plan['status'] = [r.get('status') for r in report['accepted']]
        _contact_sheet(report, out_dir, job / 'contact.png')
    plan['next'] = ('eye check on contact.png; only a set with status '
                    'ok (12/12) may be copied by a person into '
                    f'public/ludus/art/derived/{deficit_id}/ with its '
                    'meta-json and NOTICES rows, through a PR')
    return plan


def _contact_sheet(report, out_dir, sheet):
    """Source and variants on the five biomes, for the eye check."""
    from PIL import Image

    import neutral_variants

    rows = []
    for rec in report['accepted']:
        src = out_dir / 'review' / f'{rec["id"]}.source.png'
        if not src.exists():
            continue
        cells = [(v['slot'], Image.open(out_dir / v['file']).convert('RGBA'),
                  f'{v["shape_change"]:.0%}') for v in rec['variants']]
        rows.append((f'{rec["name"]} {rec.get("status")}',
                     Image.open(src).convert('RGBA'), cells))
    if rows:
        neutral_variants.contact_sheet(rows, sheet)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--index', default='/home/user/raw-repos')
    parser.add_argument('--props-cache', default=DEFAULT_CACHE)
    parser.add_argument('--to-slot', nargs=2, metavar=('KEY', 'DEF_ID'),
                        help='prepare one prop for a slot (nothing ships)')
    args = parser.parse_args()
    if args.to_slot:
        plan = to_slot(args.to_slot[0], args.to_slot[1], args.index,
                       args.props_cache)
        print(json.dumps(plan, ensure_ascii=False, indent=2))
        return
    register = load_register()
    totals = store_totals(register)
    totals['register_bytes'] = (REGISTER.stat().st_size
                                if REGISTER.exists() else 0)
    totals['cache_bytes_on_disk'] = cache_bytes_on_disk(args.props_cache)
    print(json.dumps(totals, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
