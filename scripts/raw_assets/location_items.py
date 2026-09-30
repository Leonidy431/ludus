"""Things for the 99 locations from the 99 cloned repos (track B).

Operator, 2026-09-30: "99 локаций добавь по 299 нашим сюжетам. бери
предметы из 99 репо которые склонировали".  CLAUDE.md TABOO 0.013 p. 3
says how: a location's things are real and chosen; things from the
cloned repos go through the props store (TABOO 0.012) and the raw
pipeline (TABOO 0.1: 35 %, twelve variants, the eye check); a thing
that does not look like itself is not placed.

The steps, each a sub-command, each deterministic:

  search      the wished things of godot/data/locations-99.json that
              may come from raw material (neutral matter: wood, stone,
              rope, pots, tools, tents, carts, boats, nets, crates,
              barrels, lamps that are not holy, fabrics, food, plants,
              animals, and the machines of the Kiberslav dream) are
              looked up in the index of the 99 repos, images and 3D
              models alike.  Holy things, documents, devotional things
              and the expedition's own instruments are never looked up.
  props       every hit is taken into the props store: the bytes into a
              cache outside the repository, one line per file into the
              append-only register docs/RAW_LOCATION_PROPS.json.
  candidates  the image hits are cut into single objects and scored by
              five open criteria (TABOO 0.07); the best of each thing go
              on a candidate sheet for the eye.
  kits        each source picked by eye (PICKS below) gets twelve
              variants that keep the thing recognisable: it leans, lies,
              stands upended, is chipped or broken, sinks into sand or
              silt, is overgrown, stands in a pair or a stack.  Pose
              alone never makes a variant.  Every variant differs from
              the source and from each of its siblings by at least 35 %
              of |A xor B| / |A or B| on the alpha masks (form.py), and
              its colour by at least 35 % (TABOO 0.1: both measures).
  ship        kits the eye passed (EYE below) go to
              public/ludus/art/derived/LOC-<location>/ with their meta;
              the variants a location will show are copied to
              godot/art/derived/ and listed in godot/data/
              location-items.json for the location builder (track A).
              Rolled-back kits are journalled with their reason in
              docs/RAW_OSINT_CURSOR.json (append only).

Usage:
    python3 scripts/raw_assets/location_items.py search
    python3 scripts/raw_assets/location_items.py props
    python3 scripts/raw_assets/location_items.py candidates
    python3 scripts/raw_assets/location_items.py kits
    python3 scripts/raw_assets/location_items.py ship
"""

import argparse
import datetime
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))

import licences  # noqa: E402
import osint_cycle  # noqa: E402
import search_index  # noqa: E402

LOCATIONS = ROOT / 'godot' / 'data' / 'locations-99.json'
PROPS_REGISTER = ROOT / 'docs' / 'RAW_LOCATION_PROPS.json'
WORK = ROOT / 'build' / 'location-items'
DEFAULT_INDEX = '/home/user/raw-repos'
DEFAULT_CACHE = '/home/user/raw-props'

SCHEMA = 'ludus.raw-location-props.v1'
RULE = ('CLAUDE.md TABOO 0.012 and 0.013 p. 3: append-only; a line is '
        'never edited or deleted. Bytes live in the props cache outside '
        'the repo at <cache>/<owner__name>/<revision[:12]>/<path>.')

# --- Which wished things may come from raw material ----------------------

# Things the search never looks for, with the reason.  Holy things
# (their "holy" field) and the lake's and the Atlas's own things are
# excluded by rule in excluded(); these are the rest, named one by one
# so a reviewer sees each decision.
EXCLUDED = {
    # Writing and seals: the words and marks on them are the teaching
    # (TABOO 0.39), so a roguelike's magic scroll or a UI map icon is
    # never the khan's yarlyk or the caravan's route.
    'apprentice-deed': 'document', 'birch-bark': 'document',
    'bulla': 'document', 'caravel': 'document', 'chronicle': 'document',
    'credentials': 'document', 'duty-decree': 'document',
    'glossary': 'document', 'languages': 'document',
    'ledger': 'document', 'letter': 'document',
    'levels-chronicle': 'document', 'mission-map': 'document',
    'order-report': 'document', 'paiza': 'document',
    'parchment': 'document', 'portolan': 'document',
    'ransom-charter': 'document', 'receipt': 'document',
    'route-map': 'document', 'rov-log': 'document',
    'scroll-niche': 'document', 'star-card': 'document',
    'tamga': 'document', 'trade-contract': 'document',
    'wax-tablet': 'document', 'world-map': 'document',
    'yarlyk': 'document',
    # The expedition's instruments are the operator's own work or our
    # own proxies (third_party/mangustik, third_party/posoh).
    'depth-gauge': 'expedition-instrument',
    'hydrophone': 'expedition-instrument',
    'rov-tether': 'expedition-instrument',
    # Church furniture and devotional things are our own drawing only
    # (TABOO 0.35 rule 6); the lectern is drawn in phase L5.
    'lectern': 'church-furniture', 'crypt-case': 'church-furniture',
    'hand-candle': 'devotional', 'prostration-mat': 'devotional',
}

# The material family of every thing the search looks for.  It decides
# the palette of the variants and which real changes may happen to the
# thing (a pot breaks, a rope does not; a sack slumps, an anvil does
# not).  Every eligible thing must be listed (the test checks it).
MATERIAL = {
    'wood': ('abacus', 'archive-chest', 'barrel', 'beehive', 'bench',
             'binding-press', 'boat', 'boat-hull', 'brick-mould',
             'bridge-log', 'caravan-staff', 'casket', 'drying-rack',
             'dye-vat', 'firewood', 'float', 'fruit-crate', 'loom',
             'measuring-ell', 'measuring-rod', 'mill-wheel', 'oar',
             'potter-wheel', 'print-block', 'probe-staff',
             'refugee-cart', 'sluice', 'spade', 'spindle', 'spruce-log',
             'stakes', 'tally-stick', 'treasury-chest', 'water-gauge'),
    'iron': ('adze', 'anvil', 'caulker', 'shackles', 'store-key',
             'tongs', 'tools'),
    'copper': ('caravan-bells', 'caravan-lantern', 'cauldron-camp',
               'cauldron-common', 'compass', 'money-scales', 'scales',
               'weights', 'silver-ingot', 'sounding-lead'),
    'clay': ('crucible', 'grain-pit', 'inkwell', 'jeweller-crucible',
             'karas', 'kiln', 'potter-stamp', 'tonir', 'water-jug',
             'water-sampler'),
    'stone': ('anchor-stone', 'hand-mill', 'level-mark', 'mortar',
              'stone-pile', 'touchstone'),
    'fibre': ('awning', 'bandage', 'banner', 'basket', 'cloth', 'felt',
              'fish-basket', 'grain-sack', 'khadak', 'knotted-line',
              'marking-cord', 'net', 'paper-bale', 'rope-coil',
              'salt-sack', 'sample-basket', 'silk-bale', 'spice-sack',
              'marker-buoy'),
    'leather': ('camel-saddle', 'coin-purse', 'girth-strap', 'horn',
                'kumys-skin', 'sealed-case', 'water-skin', 'well-bucket'),
    'food': ('bread-loaf', 'bread-table', 'grapes'),
    'plant': ('herbs', 'vine'),
    'animal': ('dove',),
    'fire': ('campfire', 'forge', 'signal-fire', 'torch'),
    'wax': ('candle-blank', 'wax-bar'),
    'glass': ('hourglass',),
    'machine': ('exoskeleton', 'keyboard', 'phone', 'screen',
                'server-rack'),
}
MATERIAL_OF = {k: m for m, keys in MATERIAL.items() for k in keys}

# Other names of the same real thing, added to the register's keywords
# (scripts/locations/register.py).  Only names of the thing itself: a
# word that also names something else ("wood", "box") stays out.
EXTRA_WORDS = {
    'barrel': ['keg', 'cask'], 'basket': ['wicker'],
    'bench': ['pew_bench'], 'boat': ['canoe', 'raft'],
    'bread-loaf': ['loaf'], 'bread-table': ['loaf'],
    'campfire': ['bonfire', 'fireplace'], 'caravan-lantern': ['lamp'],
    'cauldron-camp': ['pot'], 'cauldron-common': ['pot'],
    'fruit-crate': ['crates'], 'grain-sack': ['bag'],
    'herbs': ['herbal'], 'keyboard': ['keyboards'],
    'phone': ['payphone'], 'rope-coil': ['coil', 'ropes'],
    'screen': ['display'], 'server-rack': ['rack_server'],
    'spade': ['shovels'], 'spruce-log': ['logs'],
    'stone-pile': ['rocks', 'boulders', 'stonepile'],
    'tongs': ['pliers'], 'water-jug': ['jar', 'vase'],
    'well-bucket': ['pail'], 'exoskeleton': ['exosuit', 'hardsuit'],
}

# Register words that name something else in the 99 repos far more
# often than the thing.  "flag" found 2 887 national flags of freeciv
# and 263 of mage for the watch's linen banner; a national flag is not
# that banner, and some carry signs of other faiths.
DROP_WORDS = {'banner': ['flag']}

# Fonts were excluded before TABOO 0.012 and stay excluded.
FONT = re.compile(r'font|\.(ttf|otf|woff2?|fnt|bdf|pcf|pfb)$', re.I)
TOKEN = re.compile(r'[a-z]+')


def load_locations(path=LOCATIONS):
    return json.loads(Path(path).read_text('utf-8'))


def register_words():
    """The en keywords of every thing in the locations' register."""
    sys.path.insert(0, str(ROOT / 'scripts' / 'locations'))
    import register as reg
    return {k: o['en'] for k, o in reg.OBJECTS.items()}


def excluded(key, thing):
    """Why a wished thing is never looked up in raw material, or None."""
    if thing['holy']:
        return 'holy-never-raw'
    src = thing['source'].split(':')[0]
    if src == 'lake':
        return 'lake-own-drawing'
    if src == 'atlas':
        return 'through-story-trace'
    return EXCLUDED.get(key)


def wished(data=None):
    """Every wished thing with its locations and search words.

    Returns (eligible, refused): eligible maps a thing key to its
    record (Russian name, size, material family, words, locations);
    refused maps a key to the reason it is not looked up.
    """
    data = data or load_locations()
    uses = {}
    for loc in data['locations']:
        for key in loc['wishlist']:
            uses.setdefault(key, []).append(loc['id'])
    words = register_words()
    eligible, refused = {}, {}
    for key in sorted(uses):
        thing = data['things'][key]
        reason = excluded(key, thing)
        if reason:
            refused[key] = reason
            continue
        alts = []
        for w in list(words.get(key, [])) + EXTRA_WORDS.get(key, []):
            if w in DROP_WORDS.get(key, []):
                continue
            alt = tuple(w) if isinstance(w, (list, tuple)) else \
                tuple(w.split('_'))
            if alt not in alts:
                alts.append(alt)
        eligible[key] = {
            'ru': thing['ru'], 'size_m': thing['size_m'],
            'material_ru': thing['material'],
            'material': MATERIAL_OF.get(key), 'words': alts,
            'locations': uses[key],
        }
    return eligible, refused


# --- Search ---------------------------------------------------------------

def tokens(path, own=frozenset()):
    """Words of the file name and its folder, with plural forms.

    Only the last two parts of the path speak about the thing: a word
    in a deep folder ("Objects/Tools/...") names a category of the
    engine, not the object, and the design pass counted 832 "tools"
    hits that way.  Words of the repository's own name say nothing.
    """
    parts = Path(path.lower()).parts[-2:]
    stem = [re.sub(r'\.[a-z0-9]+$', '', p) for p in parts]
    toks = set()
    for part in stem:
        toks |= set(TOKEN.findall(part))
    toks -= set(own)
    return toks | {t[:-1] for t in toks if t.endswith('s')} | \
        {t[:-2] for t in toks if t.endswith('es')}


# Demonic imagery is not neutral matter even on the shelf (TABOO 0.012
# p. 2, 0.35 p. 5): the stop-list's "demon-summon" let crawl's
# demon_head_horn and space-station-14's horns_demonic in under "horn",
# and crawl's staff_skull under the caravan staff (review 2026-09-30).
DEMONIC = re.compile(r'demon|devil|skull', re.I)


def never(path):
    """Paths that never enter even the props store, with the reason."""
    if osint_cycle.DOGMA_STOP.search(path):
        return 'dogma-stop-list'
    if DEMONIC.search(path):
        return 'demonic'
    if osint_cycle.SACRED.search(path):
        return 'sacred-never-raw'
    if FONT.search(path):
        return 'font'
    return None


def search(index_root, eligible):
    """Match every eligible thing's words against the index.

    Returns (hits, refused): hits maps (repo, path) to one record with
    all the things it matched; refused counts what never enters the
    store and why.
    """
    hits, refused = {}, {}

    def refuse(reason):
        refused[reason] = refused.get(reason, 0) + 1

    for header, records in search_index.load_index(index_root):
        repo = header['repo']
        own = frozenset(TOKEN.findall(repo.split('github.com/')[-1]
                                      .lower()))
        for rec in records:
            if rec['kind'] not in ('image', 'model'):
                continue
            toks = tokens(rec['path'], own)
            matched = [(key, ' '.join(alt))
                       for key, thing in eligible.items()
                       for alt in thing['words']
                       if all(w in toks for w in alt)]
            if not matched:
                continue
            if not header['license_file']:
                # All rights reserved: nothing is taken (TABOO 0.012
                # p. 2).
                refuse('no-licence')
                continue
            reason = never(rec['path'])
            if reason:
                refuse(reason)
                continue
            hit = hits.setdefault((repo, rec['path']), {
                'repo': repo, 'commit': header['commit'],
                'license_file': header['license_file'],
                'path': rec['path'], 'kind': rec['kind'],
                'things': [], 'keywords': []})
            for key, word in matched:
                if key not in hit['things']:
                    hit['things'].append(key)
                if word not in hit['keywords']:
                    hit['keywords'].append(word)
    return hits, refused


# --- The props store ------------------------------------------------------

PROP_PLACES = (
    ('screenshot', re.compile(r'screen_?shots?|(^|[^a-z])scrn')),
    ('test', re.compile(r'(^|/)(tests?|testing|specs?|fixtures?)/')),
    ('editor', re.compile(r'editor|(^|/)tools?/')),
    ('doc', re.compile(r'(^|/)(docs?|documentation|manuals?|tutorials?|'
                       r'wiki|help|book)/')),
    ('example', re.compile(r'(^|/)(examples?|samples?|demos?)/')),
    ('promo', re.compile(r'promo|splash|logo|metadata|fastlane')),
)


def prop_place(path):
    """Where a prop lies in its repository: game art or something else.

    TABOO 0.012: a thing outside the game art (a screenshot, an engine
    example, a test picture) is still taken into the store, and its
    place is written so nobody mistakes it for game art.
    """
    low = path.lower()
    for place, pattern in PROP_PLACES:
        if pattern.search(low):
            return place
    return 'game'


def prop_key(repo, revision, path):
    raw = f'{repo}\n{revision}\n{path}'.encode('utf-8')
    return 'p_' + hashlib.sha1(raw).hexdigest()[:12]


def repo_dir(repo):
    return repo.split('github.com/')[-1].replace('/', '__')


def cache_path(cache_root, repo, revision, path):
    return Path(cache_root) / repo_dir(repo) / revision[:12] / path


def check_cache_outside(cache_root):
    """The cache must not be inside the repository (TABOO 0.012 p. 4)."""
    cache = Path(cache_root).resolve()
    if cache == ROOT or ROOT in cache.parents:
        raise ValueError(f'props cache {cache} is inside the repo')
    return cache


def _git(clone, *args, data=None):
    return subprocess.run(['git', *args], cwd=clone, input=data,
                          capture_output=True, timeout=1800)


def read_blobs(clone, revision, paths):
    """Read many files of one revision from a blobless clone.

    The blob ids come from the local trees, the missing blobs arrive in
    one fetch and `git cat-file --batch` reads them all (the technique
    of the props store of the deficit runner).
    """
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
    wanted = sorted(set(oids.values()))
    if not wanted:
        return {}
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


def load_props(path=PROPS_REGISTER):
    path = Path(path)
    if not path.exists():
        return {'schema': SCHEMA, 'rule': RULE, 'repos': {},
                'entries': []}
    return json.loads(path.read_text('utf-8'))


def dump_props(register):
    """One entry per line, so a pass shows in git as appended lines."""
    head = json.dumps({'schema': register['schema'],
                       'rule': register['rule']}, ensure_ascii=False)
    repos = json.dumps(register['repos'], ensure_ascii=False,
                       sort_keys=True, indent=0)
    lines = [json.dumps(e, ensure_ascii=False, sort_keys=True)
             for e in register['entries']]
    text = (head[:-1] + ',\n"repos": ' + repos + ',\n"entries": [\n'
            + ',\n'.join(lines) + ('\n' if lines else '') + ']')
    for extra in ('corrections', 'withdrawn'):
        if extra not in register:
            continue
        rows = [json.dumps(c, ensure_ascii=False, sort_keys=True)
                for c in register[extra]]
        text += (f',\n"{extra}": [\n' + ',\n'.join(rows)
                 + ('\n' if rows else '') + ']')
    return text + '}\n'


def save_props(register, path=PROPS_REGISTER):
    """Write the register; refuse anything but appended entries."""
    before = load_props(path)
    old = before['entries']
    if register['entries'][:len(old)] != old:
        raise RuntimeError(f'{path}: an existing line was changed or '
                           'removed; the props register only grows')
    for extra in ('corrections', 'withdrawn'):
        fixes = before.get(extra, [])
        if register.get(extra, [])[:len(fixes)] != fixes:
            raise RuntimeError(f'{path}: a line of {extra} was changed or '
                               'removed')
    if any(e.get('licence', 'x') in NO_LICENCE
           for e in register['entries'][len(old):]):
        raise RuntimeError(f'{path}: a new line without a licence')
    keys = [e['key'] for e in register['entries']]
    if len(keys) != len(set(keys)):
        raise RuntimeError(f'{path}: duplicate key')
    Path(path).write_text(dump_props(register), 'utf-8')
    return Path(path).stat().st_size


def licence_of(index_root, repo):
    return osint_cycle.licence_of(index_root, {'repo': repo})


# Labels the licence classifier gives, as SPDX ids (licences.py reads
# DEP-5 and heads in their own words).
SPDX_OF = {'Expat': 'MIT', 'Artistic': 'Artistic-1.0',
           'GPL-3+': 'GPL-3.0-or-later', 'GPL-2+': 'GPL-2.0-or-later',
           'Defold-1.0': 'LicenseRef-Defold-1.0'}
# A licence a props line may not be written without (TABOO 0.012 p. 1:
# every line names its licence; p. 2: without one, nothing is taken).
NO_LICENCE = ('', 'UNKNOWN', 'NOASSERTION')


def _reuse_licence(clone, revision, path):
    """The licence REUSE.toml gives a file (the last matching wins)."""
    import fnmatch
    import tomllib
    out = subprocess.run(['git', 'show', f'{revision}:REUSE.toml'],
                         cwd=clone, capture_output=True, timeout=300)
    if out.returncode:
        return ''
    found = ''
    reuse = tomllib.loads(out.stdout.decode('utf-8'))
    for a in reuse.get('annotations', []):
        pats = a['path'] if isinstance(a['path'], list) else [a['path']]
        if any(fnmatch.fnmatchcase(path, p.replace('**', '*'))
               for p in pats):
            found = a.get('SPDX-License-Identifier', found)
    return found


def props_licence(index_root, repo, revision, path):
    """The licence of one file of the props store, as an SPDX id.

    The first pass (2026-09-30) wrote one label per repository, which
    left 105 lines UNKNOWN (defold, endless-sky, godot, raylib,
    simutrans, slint), every GPL without its version and rotp-public's
    art "GPL" where it is CC BY-NC-ND 4.0.  The label is now per file:
    REUSE.toml where the repository keeps one, else licences.py (DEP-5
    stanzas, per-path rules), a bare GPL with the version its licence
    file states ("or later" is in the source headers and is not
    asserted here).
    """
    name = repo_dir(repo)
    clone = Path(index_root) / 'clones' / name
    label = ''
    if (clone / '.git').exists() or clone.exists():
        label = _reuse_licence(clone, revision, path)
    if not label:
        label = licences.licence_for(index_root, {'repo': repo,
                                                  'path': path})
    if label == 'GPL':
        head = licences._header(str(index_root), name).get(
            'license_head') or ''
        ver = re.search(r'VERSION (\d)', head.upper())
        label = f'GPL-{ver.group(1)}.0' if ver else label
    return SPDX_OF.get(label, label)


def licence_corrections(register, index_root, pass_id, when):
    """Append a correction for every props line whose file's licence
    differs from its label.  The lines themselves are never rewritten
    (the register only grows); a correction names the line's key, the
    old label, the licence and why."""
    done = {c['key'] for c in register.get('corrections', [])}
    added = []
    for e in register['entries']:
        if e['key'] in done:
            continue
        now = props_licence(index_root, e['repo'], e['revision'],
                            e['path'])
        if now != e['licence']:
            added.append({'key': e['key'], 'was': e['licence'],
                          'licence': now, 'pass_id': pass_id,
                          'time': when,
                          'why': 'per-file licence (props_licence)'})
    register.setdefault('corrections', []).extend(added)
    return added


def withdraw_never(register, pass_id, when):
    """Append a withdrawal for every line never() now refuses: the line
    stays (append-only), marked withdrawn with why, and no kit, sheet or
    headset file may take it."""
    done = {w['key'] for w in register.get('withdrawn', [])}
    added = [{'key': e['key'], 'why': never(e['path']),
              'pass_id': pass_id, 'time': when}
             for e in register['entries']
             if e['key'] not in done and never(e['path'])]
    register.setdefault('withdrawn', []).extend(added)
    return added


def withdrawn_keys(register):
    return {w['key'] for w in register.get('withdrawn', [])}


def licence_now(register, key, label):
    """A line's licence with its corrections applied."""
    for c in register.get('corrections', []):
        if c['key'] == key:
            label = c['licence']
    return label


def take_props(hits, eligible, index_root, cache_root, pass_id,
               register):
    """Fetch every hit into the cache and append it to the register."""
    cache = check_cache_outside(cache_root)
    known = {e['key'] for e in register['entries']}
    by_repo = {}
    stats = {'hits': len(hits), 'duplicates': 0, 'errors': 0,
             'taken': 0, 'bytes': 0, 'by_kind': {}, 'by_place': {}}
    for (repo, path), hit in sorted(hits.items()):
        key = prop_key(repo, hit['commit'], path)
        if key in known:
            stats['duplicates'] += 1
            continue
        by_repo.setdefault((repo, hit['commit']), []).append((key, hit))
    for (repo, revision), items in sorted(by_repo.items()):
        if repo not in register['repos']:
            # Licence facts once per repository, not once per line.
            register['repos'][repo] = {
                'revision': revision,
                'licence': licence_of(index_root, repo),
                'licence_file': items[0][1]['license_file']}
        clone = Path(index_root) / 'clones' / repo_dir(repo)
        paths = [h['path'] for _, h in items]
        blobs = {}
        # ls-tree takes the paths on its command line; a few hundred at
        # a time keep it under the argument limit.
        for i in range(0, len(paths), 400):
            try:
                blobs.update(read_blobs(clone, revision, paths[i:i + 400]))
            except (subprocess.SubprocessError, OSError) as exc:
                print(f'props: cannot read {repo}: {exc}', file=sys.stderr)
        for key, hit in items:
            data = blobs.get(hit['path'])
            if data is None:
                stats['errors'] += 1
                continue
            licence = props_licence(index_root, repo, revision,
                                    hit['path'])
            if licence in NO_LICENCE:
                # TABOO 0.012 p. 1-2: no line without its licence.
                stats['refused_licence'] = \
                    stats.get('refused_licence', 0) + 1
                continue
            dest = cache_path(cache, repo, revision, hit['path'])
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(data)
            locs = sorted({loc for t in hit['things']
                           for loc in eligible[t]['locations']})
            entry = {
                'key': key, 'repo': repo, 'revision': revision,
                'path': hit['path'],
                'licence': licence,
                'kind': hit['kind'], 'place': prop_place(hit['path']),
                'things': hit['things'], 'location_ids': locs,
                'keywords': hit['keywords'], 'pass_id': pass_id,
                'sha1': hashlib.sha1(data).hexdigest(), 'bytes': len(data),
            }
            register['entries'].append(entry)
            known.add(key)
            stats['taken'] += 1
            stats['bytes'] += len(data)
            stats['by_kind'][hit['kind']] = \
                stats['by_kind'].get(hit['kind'], 0) + 1
            stats['by_place'][entry['place']] = \
                stats['by_place'].get(entry['place'], 0) + 1
    return stats


# --- Candidates: which hits could become a thing of a location ----------

# A hit stays in the props store whatever it is (TABOO 0.012), but only
# a picture of the thing itself, seen as an object, may become a kit.
# These are refused as sources with the reason; the words were learned
# from the hits of this pass (docs/HLD_LOCATION_ITEMS_2026-09-30.md).
NOT_A_SOURCE = (
    # Magic: The Gathering card art is the card publisher's, whatever
    # the licence of the program that shows it.
    ('card-art', re.compile(r'card|fullborder|(^|/)cards?/', re.I)),
    ('national-flag', re.compile(r'(^|/)flags?/', re.I)),
    ('hostile-or-unit', osint_cycle.HOSTILE),
    ('hostile-or-unit', re.compile(r'(^|/)(units?|attacks?|mon|'
                                   r'monsters?|mobs?|weapons?|mecha?)'
                                   r'(/|_|\.|$)', re.I)),
    ('worn-or-held', re.compile(r'inhand|in-hand|equipped|(^|/)worn/|'
                                r'hand[12]/|(^|/)player/|clothing|'
                                r'(^|/)(head|body|torso)/', re.I)),
    ('ui-glyph', re.compile(r'(^|/)(ui|gui|interface|icons?|buttons?|'
                            r'cursors?|menus?|hud|actions?|commands?|'
                            r'wui|editor|skin)(/|_)', re.I)),
    ('terrain-tile', re.compile(r'terrain|(^|/)dngn/|(^|/)(walls?|'
                                r'floors?|tiles?|decals?|overlays?|'
                                r'flora|bridge)(/|\.rsi|_)', re.I)),
    ('effect-or-spell', re.compile(r'(^|/)(effects?|spells?|'
                                   r'invocations?|mutations?|'
                                   r'tentacles)/|fill-\d', re.I)),
)

LICENCE_SCORE = {'CC0-1.0': 10, 'MIT': 10, 'BSD': 10, 'Zlib': 10,
                 'Apache-2.0': 10, 'MPL-2.0': 8, 'LGPL': 8, 'GPL': 7,
                 'CC-BY-SA': 7, 'AGPL-3.0': 6}
IMAGE_EXT = ('.png', '.svg', '.webp', '.gif', '.bmp')
PER_FILE = 4
PER_THING = 8


def not_a_source(path):
    """The reason a hit cannot be a kit's source, or None."""
    if not path.lower().endswith(IMAGE_EXT):
        return 'no-alpha-format' if path.lower().endswith(
            ('.jpg', '.jpeg')) else 'model'
    for reason, pattern in NOT_A_SOURCE:
        if pattern.search(path):
            return reason
    return None


def open_image(path):
    """Open a cached file as RGBA; an SVG is rasterised by cairosvg."""
    from PIL import Image
    if path.suffix.lower() == '.svg':
        import io
        try:
            import cairosvg
        except ImportError:
            return None
        try:
            png = cairosvg.svg2png(url=str(path), output_width=256)
        except Exception:  # noqa: BLE001 -- any SVG error refuses it
            return None
        return Image.open(io.BytesIO(png)).convert('RGBA')
    try:
        img = Image.open(path)
        img.load()
    except OSError:
        return None
    return img.convert('RGBA')


def pieces_of(img):
    """Single objects of a picture, animation frame duplicates skipped."""
    import transform
    kept, out = [], []
    for piece in transform.slice_sheet(img, PER_FILE * 2):
        mask = transform.frame_mask(piece)
        if any(transform.mask_iou(mask, seen) > transform.FRAME_DUP_IOU
               for seen in kept):
            continue
        kept.append(mask)
        out.append(piece)
        if len(out) == PER_FILE:
            break
    return out


def score(entry, piece, thing, index):
    """Five open criteria, 0-10 each (TABOO 0.07 p. 3).

    truth     the thing's word is in the file name (10) or only in its
              folder (8); outside the game art (an example, a test) -3;
    teaching  the thing reads as itself in a place: it rests on a base
              (seen from the side) rather than floating as an icon;
    readable  enough pixels for a card at arm's length in the headset,
              and not a hair-thin stroke;
    novelty   the first object of a file 10, later pieces of a sheet 7;
    safety    the licence: permissive 10 ... unknown 4 (copyleft keeps
              its share-alike duty; the lawyer decides).
    """
    import form
    import reference
    mask = form.alpha_mask(piece)
    stats = reference.bbox_stats(mask)
    stem = Path(entry['path'].lower()).stem
    in_name = any(w in set(TOKEN.findall(stem)) or w in stem
                  for alt in thing['words'] for w in alt)
    truth = (10 if in_name else 8) - (3 if entry['place'] != 'game'
                                      else 0)
    teaching = 10 if stats['base'] >= 0.35 else 6
    side = max(piece.size)
    readable = (10 if side >= 96 else 9 if side >= 64 else 8 if side >= 48
                else 6 if side >= 32 else 4 if side >= 24 else 2)
    if stats['fill'] < 0.2:
        readable = max(0, readable - 3)
    novelty = 10 if index == 0 else 7
    safety = LICENCE_SCORE.get(entry['licence'], 4)
    crit = {'truth': truth, 'teaching': teaching, 'readable': readable,
            'novelty': novelty, 'safety': safety}
    return crit, sum(crit.values()), stats


def candidates(register, eligible, cache_root, only=()):
    """Score every image hit of every eligible thing; best first."""
    import form
    out, refused = {}, {}

    def refuse(things, why):
        for t in things:
            refused.setdefault(t, {})
            refused[t][why] = refused[t].get(why, 0) + 1

    for entry in register['entries']:
        if entry['kind'] != 'image':
            continue
        things = [t for t in entry['things'] if t in eligible
                  and (not only or t in only)]
        if not things:
            continue
        reason = not_a_source(entry['path'])
        if reason:
            refuse(things, reason)
            continue
        img = open_image(cache_path(cache_root, entry['repo'],
                                    entry['revision'], entry['path']))
        if img is None:
            refuse(things, 'unreadable')
            continue
        for index, piece in enumerate(pieces_of(img)):
            mask = form.alpha_mask(piece)
            fill = form.area(mask) / max(1, piece.width * piece.height)
            if min(piece.size) < 12 or max(piece.size) < 20:
                refuse(things, 'too-small')
                continue
            if fill > 0.97:
                refuse(things, 'rectangle-tile')
                continue
            for t in things:
                crit, total, stats = score(entry, piece, eligible[t], index)
                out.setdefault(t, []).append({
                    'key': entry['key'], 'repo': entry['repo'],
                    'revision': entry['revision'], 'path': entry['path'],
                    'licence': entry['licence'], 'piece': index,
                    'size': list(piece.size), 'criteria': crit,
                    'total': total, 'stats': stats})
    for t in out:
        out[t].sort(key=lambda c: (-c['total'], c['repo'], c['path'],
                                   c['piece']))
    return out, refused


def piece_image(cand, cache_root):
    """The cut object a candidate names, read again from the cache."""
    img = open_image(cache_path(cache_root, cand['repo'], cand['revision'],
                                cand['path']))
    return pieces_of(img)[cand['piece']]


def candidate_sheet(rows, out_path, cell=88):
    """Rows of candidates (thing, [(tag, image)]) for the eye check."""
    from PIL import Image, ImageDraw
    import location_kit
    font = location_kit._font(11)
    width = 150 + PER_THING * cell
    sheet = Image.new('RGB', (width, len(rows) * (cell + 14) + 4),
                      (38, 38, 38))
    draw = ImageDraw.Draw(sheet)
    for r, (thing, tiles) in enumerate(rows):
        y = r * (cell + 14) + 2
        draw.text((4, y + cell // 2 - 6), thing[:22], fill=(235, 235, 235),
                  font=font)
        for c, (tag, img) in enumerate(tiles):
            tile = Image.new('RGBA', (cell, cell), (120, 116, 108, 255))
            k = (cell - 6) / max(img.size)
            small = img.resize((max(1, round(img.width * k)),
                                max(1, round(img.height * k))),
                               Image.NEAREST)
            tile.alpha_composite(small, ((cell - small.width) // 2,
                                         (cell - small.height) // 2))
            sheet.paste(tile.convert('RGB'), (150 + c * cell, y))
            draw.text((150 + c * cell + 2, y + cell), tag,
                      fill=(200, 200, 200), font=font)
    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out_path, optimize=True)


# --- Kits: the sources picked by eye, and their twelve variants --------

# Picked by eye on the candidate sheets of this pass (copies in docs/
# audit/2026-09-30/location-items/candidates-0N.png; the first number
# of each note is the sheet, the letter the column).  A pick names the
# file and the cut piece; "serves" lists every wished thing the kit
# stands for (one log serves the bridge log and the spruce log).  The
# other candidates of these sheets were refused by eye; the reasons are
# in REFUSED_BY_EYE.
PICKS = {
    'anvil': ('wesnoth/wesnoth', 'data/core/images/items/anvil.png', 0,
              ['anvil'], '00 b: a grey anvil, three-quarter view'),
    'archive-chest': ('wesnoth/wesnoth',
                      'data/core/images/items/chest-plain-open.png', 0,
                      ['archive-chest', 'treasury-chest'],
                      '00 a: a plain wooden chest, lid ajar; the gold '
                      'chests b, c read as treasure loot'),
    'barrel': ('wesnoth/wesnoth', 'data/core/images/items/barrel.png', 0,
               ['barrel'], '00 b: a hooped wooden barrel'),
    'basket': ('widelands/widelands', 'data/tribes/wares/basket/menu.png',
               0, ['basket', 'fish-basket', 'sample-basket'],
               '00 a: a wicker basket'),
    'bench': ('space-wizards/space-station-14',
              'Resources/Textures/Structures/Furniture/chairs.rsi/'
              'wooden-bench.png', 0, ['bench'],
              '00 g: a wooden bench with a back'),
    'bridge-log': ('widelands/widelands',
                   'data/tribes/wares/log/idle_4.png', 0,
                   ['bridge-log', 'spruce-log'], '01 c: one round log'),
    'campfire': ('space-wizards/space-station-14',
                 'Resources/Textures/Structures/Decoration/bonfire.rsi/'
                 'bonfire.png', 0, ['campfire', 'signal-fire'],
                 '01 e: a laid fire of brushwood on stones, unlit; the '
                 'ones with a stake (g, h) refused'),
    'caravan-lantern': ('crawl/crawl',
                        'crawl-ref/source/rltiles/item/misc/misc_lamp.png',
                        0, ['caravan-lantern'],
                        '01 f: a hanging lantern with a flame'),
    'caulker': ('widelands/widelands', 'data/tribes/wares/chisel/idle_4.png',
                0, ['caulker'], '01 a: a chisel, the caulking iron'),
    'cloth': ('space-wizards/space-station-14',
              'Resources/Textures/Objects/Materials/materials.rsi/'
              'cloth_3.png', 0, ['cloth'], '01 a: rolled bolts of cloth'),
    'forge': ('wesnoth/wesnoth',
              'data/campaigns/Sceptre_of_Fire/images/misc/forge-slab.png', 0,
              ['forge'], '02 d: a brick forge hearth'),
    'fruit-crate': ('space-wizards/space-station-14',
                    'Resources/Textures/Objects/Misc/ParcelWrap/'
                    'wrapped_parcel.rsi/crate.png', 0, ['fruit-crate'],
                    '02 b: a wooden crate'),
    'hand-mill': ('Azgaar/Fantasy-Map-Generator',
                  'public/charges/millstone.svg', 0, ['hand-mill'],
                  '03 a: a millstone with its eye'),
    'hourglass': ('Azgaar/Fantasy-Map-Generator',
                  'public/charges/hourglass.svg', 0, ['hourglass'],
                  '03 a: an hourglass in its frame'),
    'khadak': ('crawl/crawl', 'crawl-ref/source/rltiles/item/armour/'
               'scarf1.png', 0, ['khadak'], '03 b: a looped scarf'),
    'knotted-line': ('widelands/widelands',
                     'data/tribes/wares/rope/idle_4.png', 0,
                     ['knotted-line', 'marking-cord'],
                     '03 e: a length of twisted rope'),
    'refugee-cart': ('Azgaar/Fantasy-Map-Generator',
                     'public/images/markers/wagon.svg', 0,
                     ['refugee-cart'], '04 c: a cart with shafts'),
    'silk-bale': ('wesnoth/wesnoth', 'data/core/images/items/'
                  'straw-bale2.png', 0, ['silk-bale'],
                  '05 b: a bound bale'),
    'silver-ingot': ('space-wizards/space-station-14',
                     'Resources/Textures/Objects/Materials/ingots.rsi/'
                     'silver_3.png', 0, ['silver-ingot'],
                     '05 g: a stack of silver ingots'),
    'spade': ('widelands/widelands', 'data/tribes/wares/shovel/menu.png',
              0, ['spade'], '05 a: a shovel with a wooden handle'),
    'store-key': ('wesnoth/wesnoth', 'data/core/images/items/key-dark.png',
                  0, ['store-key'], '06 b: an iron key'),
    'tongs': ('widelands/widelands',
              'data/tribes/wares/fire_tongs/menu.png', 0, ['tongs'],
              '06 a: smith\'s fire tongs'),
    'tools': ('widelands/widelands', 'data/tribes/wares/hammer/menu.png',
              0, ['tools'], '06 e: a hammer'),
}

# What the eye refused on the candidate sheets, by thing: nothing on
# the sheet is the thing itself (or it is holy, loot or a weapon).
REFUSED_BY_EYE = {
    'adze': 'battle axes and a pole-axe, not a carpenter\'s adze',
    'anchor-stone': 'an iron anchor and station anchors; ours is stone',
    'banner': 'logos and interface banners, no linen banner',
    'beehive': 'magic hives of a roguelike',
    'binding-press': 'factory blocks and an icon',
    'boat': 'the heraldic boats are CC-BY-NC-SA (non-commercial); the '
            'rest are boats in painted waves or portraits',
    'boat-hull': 'no bare hull; wrecks in painted waves',
    'bread-loaf': 'bakery buildings and unsliced strips of frames',
    'bread-table': 'bakery buildings and unsliced strips of frames',
    'brick-mould': 'brick walls and kiln buildings',
    'camel-saddle': 'camels, not a saddle',
    'caravan-staff': 'wizards\' staves',
    'cauldron-camp': 'the heraldic pot is CC-BY-NC-SA (non-commercial)',
    'cauldron-common': 'the heraldic pot is CC-BY-NC-SA (non-commercial)',
    'coin-purse': 'heaps of gold coins read as loot, not a purse',
    'compass': 'interface compass roses',
    'crucible': 'factory blocks',
    'dove': 'the heraldic dove is CC-BY-NC-SA (non-commercial)',
    'drying-rack': 'weapon racks',
    'dye-vat': 'barrels, not an open vat',
    'exoskeleton': 'a fabricator machine and a tech icon',
    'felt': 'carpet floor tiles',
    'float': 'a map',
    'grain-pit': 'granary buildings',
    'grain-sack': 'a magic sack of spiders and a sheaf',
    'herbs': 'a herb inside an item marker ring',
    'horn': 'a magic horn',
    'inkwell': 'a magic inkwell talisman',
    'jeweller-crucible': 'factory blocks',
    'keyboard': 'interface glyphs',
    'kiln': 'factory blocks and kiln buildings',
    'level-mark': 'map markers',
    'measuring-rod': 'steel rods and magic rods',
    'mill-wheel': 'a texture of a CC-BY-NC watermill (non-commercial)',
    'money-scales': 'dragon-scale armour',
    'net': 'fishermen figures and icons',
    'oar': 'a baker\'s peel and pong paddles, not an oar',
    'paper-bale': 'paper sheets and icons',
    'potter-wheel': 'an amphora icon',
    'probe-staff': 'wizards\' staves',
    'rope-coil': 'straight rope and cables, no coil',
    'salt-sack': 'salt walls and a magic sack',
    'scales': 'dragon-scale armour',
    'screen': 'loading-screen pictures',
    'sealed-case': 'an open locker',
    'spice-sack': 'a magic sack and an icon',
    'spindle': 'a spaceship',
    'stakes': 'execution stakes of a bonfire',
    'stone-pile': 'natural rock outcrops with cast shadows, not a '
                  'masonry pile',
    'torch': 'thrusters and a light texture',
    'vine': 'a vine monster',
    'water-gauge': 'an interface gauge',
    'water-sampler': 'a magic potion',
    'well-bucket': 'the heraldic bucket is CC-BY-NC-SA (non-commercial)',
}

# Licence of the file itself.  The repository licence is often only the
# code's: space-station-14 textures carry their own in each .rsi/
# meta.json, and the charges of Fantasy-Map-Generator name theirs in
# the SVG's <metadata> (most are CC-BY-NC-SA, which a store release
# cannot use).
CC_URL = (('by-nc-sa/', 'CC-BY-NC-SA-'), ('by-nc/', 'CC-BY-NC-'),
          ('by-sa/', 'CC-BY-SA-'), ('by/', 'CC-BY-'),
          ('publicdomain/zero/1.0', 'CC0-1.0'), ('fdl-1.3', 'GFDL-1.3'))
REPO_NOTES = {
    'crawl/crawl': ('GPL-2.0-or-later', 'crawl LICENSE: most tiles are '
                    'CC0, older pieces may differ (github.com/crawl/tiles);'
                    ' kept under the repository licence until the piece '
                    'is confirmed'),
    'wesnoth/wesnoth': ('GPL-2.0-or-later', 'art is under the program\'s '
                        'licence (COPYING)'),
    'widelands/widelands': ('GPL-2.0-or-later', 'game data under the '
                            'program\'s licence (COPYING)'),
}


def spdx_of_url(url):
    for part, spdx in CC_URL:
        if part in url:
            if spdx.endswith('-'):
                ver = re.search(r'/(\d\.\d)', url)
                return spdx + (ver.group(1) if ver else '')
            return spdx
    return 'UNKNOWN'


def licence_facts(repo, revision, path, index_root, cache_root):
    """The licence that covers this very file, with its evidence."""
    short = repo.split('github.com/')[-1]
    facts = {'repo_licence': licence_of(index_root, repo),
             'evidence': []}
    facts['licence'] = facts['repo_licence']
    if short in REPO_NOTES:
        facts['licence'], note = REPO_NOTES[short]
        facts['evidence'].append(note)
    if short == 'space-wizards/space-station-14' and '.rsi/' in path:
        meta = path.rsplit('/', 1)[0] + '/meta.json'
        clone = Path(index_root) / 'clones' / repo_dir(repo)
        blobs = read_blobs(clone, revision, [meta])
        if meta in blobs:
            dest = cache_path(cache_root, repo, revision, meta)
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(blobs[meta])
            data = json.loads(blobs[meta].decode('utf-8-sig'))
            facts['licence'] = data.get('license', 'UNKNOWN')
            facts['copyright'] = data.get('copyright', '')
            facts['evidence'].append(meta)
    if short == 'Azgaar/Fantasy-Map-Generator' and path.endswith('.svg'):
        text = cache_path(cache_root, repo, revision, path).read_text(
            'utf-8', 'replace')
        found = re.search(r'<metadata[^>]*>', text)
        if found:
            url = re.search(r'license="([^"]+)"', found.group(0))
            src = re.search(r'source="([^"]+)"', found.group(0))
            author = re.search(r'author="([^"]+)"', found.group(0))
            facts['licence'] = spdx_of_url(url.group(1) if url else '')
            facts['copyright'] = ' '.join(
                x.group(1) for x in (author, src) if x)
            facts['evidence'].append(f'{path} <metadata>')
        else:
            facts['evidence'].append('no <metadata> in the SVG; the '
                                     'repository licence is assumed')
    facts['commercial'] = '-NC' not in facts['licence']
    return facts


def kit_name(key, repo, path, piece):
    import location_kit
    seed = location_kit.kit_seed(repo, path, piece)
    return f'obj_{key.replace("-", "_")}_{seed[:10]}', seed


def home_location(serves, data):
    """The first location (in data order) that wishes a served thing."""
    for loc in data['locations']:
        if any(t in loc['wishlist'] for t in serves):
            return loc['id']
    return None


def make_kit(key, index_root, cache_root, data, eligible):
    """Build one kit from its pick; return (meta, images, source)."""
    import location_kit as lk
    short, path, piece_no, serves, why = PICKS[key]
    register = load_props()
    entry = next(e for e in register['entries']
                 if e['repo'].endswith('/' + short) and e['path'] == path)
    repo, revision = entry['repo'], entry['revision']
    facts = licence_facts(repo, revision, path, index_root, cache_root)
    name, seed = kit_name(key, repo, path, piece_no)
    home = home_location(serves, data)
    meta = {
        'name': name, 'id': seed[:10], 'seed': seed, 'thing': key,
        'serves': serves, 'slot': f'LOC-{home}',
        'locations': sorted({loc['id'] for loc in data['locations']
                             if any(t in loc['wishlist'] for t in serves)}),
        'origin': 'raw-neutral-location-kit', 'method': lk.REVISION,
        'raw_material': True,
        'source': {'repo': repo, 'path': path, 'commit': revision,
                   'piece': piece_no, 'prop_key': entry['key'],
                   'sha1': entry['sha1'], 'bytes': entry['bytes']},
        'repo': repo, 'path': path, 'commit': revision,
        'license': facts['licence'], 'license_file':
            register['repos'][repo]['licence_file'],
        'licence_facts': facts, 'picked_by_eye': why,
        'material': eligible[key]['material'],
        'ru': eligible[key]['ru'], 'size_m': eligible[key]['size_m'],
        'threshold': lk.THRESHOLD, 'shape_basis': 'source',
        'sibling_basis': 'nearest-sibling',
    }
    if not facts['commercial']:
        meta.update({'status': 'licence-non-commercial', 'variants': []})
        return meta, {}, None
    source = piece_image({'repo': repo, 'revision': revision, 'path': path,
                          'piece': piece_no}, cache_root)
    built = lk.build_kit(source, key, meta['material'], seed)
    images, variants = {}, []
    tag = key.replace('-', '_')
    for n, m in enumerate(built['chosen'], 1):
        slot = f'v{n:02d}'
        fname = f'{name}_{slot}.png'
        images[fname] = m['pal']
        variants.append({
            'slot': slot, 'file': fname, 'change': lk.describe(m['spec']),
            'setting': m['spec']['setting'], 'state': m['state'],
            'shape_change': round(m['shape'], 4),
            'sibling_min': round(m['sibling_min'], 4),
            'colour_change': round(m['colour'], 4),
            'visible': round(m['visible'], 4), 'hitbox': m['hitbox'],
            'analytics_id': f'ludus.variant.{tag}.{seed[:10]}.{slot}'})
    shapes = [v['shape_change'] for v in variants] or [0.0]
    colours = [v['colour_change'] for v in variants] or [0.0]
    meta.update({
        'pixel_art': built['pixel_art'], 'source_px': built['source_px'],
        'side_px': built['side_px'], 'pool': built['pool'],
        'variants': variants, 'shortfall': lk.KIT_SIZE - len(variants),
        'status': 'ok' if len(variants) == lk.KIT_SIZE else 'shortfall',
        'shape_change': min(shapes), 'colour_change': min(colours),
        'redraw': {'shape_change': 0.0, 'colour_change': min(colours),
                   'is_recolour': False},
        'claim_features': [
            f'нейтральная вещь локаций «{meta["ru"]}»: источник выбран '
            f'глазами как изображение самой вещи ({why})',
            f'двенадцать вариантов из реальных состояний вещи (наклон, '
            f'лежит, сколота, расколота, в песке, в траве, пара, штабель);'
            f' поза без изменения строения варианта не даёт',
            f'палитра материала «{meta["material"]}» в его состояниях; '
            f'масштаб источника и вариантов один ({lk.SIDE} пикс.)',
            f'изменение формы к источнику (|A xor B| / |A or B|): от '
            f'{min(shapes):.1%} до {max(shapes):.1%}; к ближайшему соседу '
            f'не меньше {lk.THRESHOLD:.0%}; цвета от {min(colours):.1%}',
            f'источник: {repo} @ {revision[:10]}, {path} #{piece_no} '
            f'({facts["licence"]})'],
        'constitution': (
            'ФОРМА: настоящая вещь места в её настоящих состояниях → '
            'ДЕЙСТВИЕ: вещь стоит в слоте локации и не заслоняет сердце '
            'места → ЦЕЛЬ: вещи служат учению (ТАБУ №0.013 п. 3, 9)'),
    })
    return meta, images, built['source_canvas']


# --- The eye check of the kits, and shipping -----------------------------

# Verdicts on the kit sheets (build/location-items/kits/*.sheet.png, the
# five backgrounds of the locations), looked at one by one on
# 2026-09-30.  A kit ships only with 12/12 and "ship"; everything else
# is rolled back with its reason into the journal.
EYE = {
    'anvil': ('rollback', 'shortfall: an anvil only sinks, is overgrown '
              'or leans; its real states give fewer than twelve'),
    'archive-chest': ('rollback', 'reads as a cabinet or a crate, not a '
                      'chest; the cast shadow of the source turns with it'),
    'barrel': ('rollback', 'the cast shadow of the source turns and breaks '
               'with the barrel, and a stacked barrel floats on it'),
    'basket': ('rollback', 'shortfall'),
    'bench': ('ship', 'a wooden bench on all five backgrounds: tilted, '
              'upside down, chipped, broken with its piece, two side by '
              'side, one stacked upside down on another'),
    'bridge-log': ('ship', 'a round log throughout: leaning, chipped at '
                   'the end, broken with a chunk, two side by side, two '
                   'stacked, weathered grey'),
    'campfire': ('rollback', 'shortfall'),
    'caravan-lantern': ('rollback', 'shortfall'),
    'caulker': ('rollback', 'all twelve are sunk or overgrown, none for a '
                'room; a chisel does not stand stuck in sand'),
    'cloth': ('rollback', 'shortfall'),
    'forge': ('rollback', 'shortfall'),
    'fruit-crate': ('rollback', 'the grey weathered variants read as metal '
                    'boxes and the crate on its end as a locker'),
    'hand-mill': ('rollback', 'shortfall'),
    'hourglass': ('ship', 'an hourglass throughout: leaning with a chipped '
                  'plate, or with a post broken off and lying beside it'),
    'khadak': ('rollback', 'shortfall; a looped scarf icon reads as a knot'),
    'knotted-line': ('rollback', 'shortfall; a short thick rope, not a '
                     'measuring line'),
    'refugee-cart': ('rollback', 'seen from above: reads as a box with '
                     'shafts, not a cart'),
    'silk-bale': ('rollback', 'shortfall'),
    'silver-ingot': ('rollback', 'shortfall'),
    'spade': ('rollback', 'the blade of the icon reads as a club head'),
    'store-key': ('rollback', 'shortfall'),
    'tongs': ('rollback', 'the icon reads as scissors'),
    'tools': ('ship', 'a hammer throughout: two crossed, half in sand, in '
              'grass; the oak handle takes the iron colour of the head'),
}

DERIVED = ROOT / 'public' / 'ludus' / 'art' / 'derived'
GODOT_DERIVED = ROOT / 'godot' / 'art' / 'derived'
GODOT_ITEMS = ROOT / 'godot' / 'data' / 'location-items.json'
CURSOR = ROOT / 'docs' / 'RAW_OSINT_CURSOR.json'
NOTICES = ROOT / 'THIRD_PARTY_NOTICES.md'
AUDIT = ROOT / 'docs' / 'audit' / '2026-09-30' / 'location-items'
NOTICE_HEAD = '''
## Things of the 99 locations (raw material, TABOO 0.013 p. 3)

Neutral things from the props store of the 99 repos
(`docs/RAW_LOCATION_PROPS.json`), each reshaped into twelve variants by
`scripts/raw_assets/location_items.py` and `location_kit.py` and passed
by eye (`docs/audit/2026-09-30/location-items/`). The licence is that of
the file itself where the file names one (space-station-14 `.rsi/
meta.json`, the SVG's `<metadata>`), else the repository's. Shape is
|A xor B| / |A or B| of the alpha masks against the source; every
variant is also 35 % or more from each of its siblings.

| Object | Serves | Variants | Source | Commit | Path | Licence \
| Min shape | Min colour |
|---|---|---|---|---|---|---|---|---|
'''

# Rooms and caves take only variants that need no ground (sand, grass).
INDOOR = {'room', 'cave'}


# How a variant must look to stand in a place as its thing (TABOO 0.013
# p. 3: a thing that does not look like itself is not placed).  The
# review of 2026-09-30 found by eye a stack of benches read as a rack,
# a bench and an upturned one as a bracket, broken pieces as floating
# clutter, a grey log as a steel pipe and a leaning hourglass that
# could not stand.  The kit keeps all twelve (the data set, TABOO 0.3
# rule 70); a location only shows the ones that pass here.
# Changes a location never shows: a thing in use stands on its feet.
NOT_IN_A_PLACE = ('stack', 'upended')
# A thing standing on its own leans at most this much.
MAX_LEAN_DEG = 12
# Pieces smaller than this share of the drawing are specks, not parts.
SPECK = 0.02
# The drawn width over height, against the thing's longest ground side
# over its height (as godot/scripts/location_core.gd LIKE_MIN/MAX).
LIKE_MIN, LIKE_MAX = 0.4, 3.0
# Wood reads as wood only warm: red over blue by at least this much in
# the mean of the drawn pixels (the grey weathered variants read as
# metal, TABOO 0.38 p. 2).
WOOD_WARM = 40


def _pieces_and_mean(path):
    """Connected pieces (4-neighbour, alpha > 16) and the mean colour."""
    from PIL import Image
    im = Image.open(path).convert('RGBA')
    w, h = im.size
    px = im.load()
    solid = [[px[x, y][3] > 16 for x in range(w)] for y in range(h)]
    total, r, g, b = 0, 0, 0, 0
    for y in range(h):
        for x in range(w):
            if solid[y][x]:
                total += 1
                c = px[x, y]
                r, g, b = r + c[0], g + c[1], b + c[2]
    seen = [[False] * w for _ in range(h)]
    sizes = []
    for y in range(h):
        for x in range(w):
            if not solid[y][x] or seen[y][x]:
                continue
            seen[y][x] = True
            stack, n = [(x, y)], 0
            while stack:
                cx, cy = stack.pop()
                n += 1
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1),
                               (cx, cy - 1)):
                    if 0 <= nx < w and 0 <= ny < h and solid[ny][nx] \
                            and not seen[ny][nx]:
                        seen[ny][nx] = True
                        stack.append((nx, ny))
            sizes.append(n)
    pieces = sum(1 for n in sizes if n >= SPECK * max(total, 1))
    mean = (r / max(total, 1), g / max(total, 1), b / max(total, 1))
    return pieces, mean


def unlike(kit, v, size):
    """Why a variant does not look like its thing in a place, or ''."""
    change = v['change']
    for word in NOT_IN_A_PLACE:
        if word in change:
            return word
    lean = re.search(r'leans ([+-]?\d+)', change)
    if lean and abs(int(lean.group(1))) > MAX_LEAN_DEG:
        return f'leans {lean.group(1)}'
    x0, y0, x1, y1 = v['hitbox']['bbox']
    real = max(size[0], size[2]) / max(size[1], 1e-3)
    like = ((x1 - x0) / max(y1 - y0, 1)) / real
    if not LIKE_MIN <= like <= LIKE_MAX:
        return f'proportions {like:.2f}'
    pieces, mean = _pieces_and_mean(DERIVED / kit['slot'] / v['file'])
    if pieces != 1:
        return f'{pieces} pieces'
    if kit.get('material') == 'wood' and mean[0] - mean[2] < WOOD_WARM:
        return 'grey wood'
    return ''


def variant_queue(kit, loc, thing, shell, size=None):
    """The variants a location shows of a thing, deterministically.

    The queue starts where sha1(location id + thing) points and keeps
    the kit's order, so two places do not show the same variant first
    and one place never shows two alike in a row (TABOO 0.3 rule 53).
    With the thing's size, only variants like the thing are queued
    (unlike()); the queue may then be empty.
    """
    fit = [v for v in kit['variants']
           if shell not in INDOOR or v['setting'] == 'any']
    if size is not None:
        fit = [v for v in fit if not unlike(kit, v, size)]
    if not fit:
        return []
    start = int(hashlib.sha1(f'{loc}:{thing}'.encode()).hexdigest()[:8],
                16) % len(fit)
    return fit[start:] + fit[:start]


def shipped_kits():
    """Kits in the build that pass 12/12 and the eye."""
    out = []
    for key, (verdict, _) in sorted(EYE.items()):
        if verdict != 'ship':
            continue
        name, _ = kit_name(key, *_pick_repo_path(key))
        meta_path = WORK / 'kits' / name / f'{name}.json'
        meta = json.loads(meta_path.read_text('utf-8'))
        if meta['status'] != 'ok':
            raise RuntimeError(f'{key}: passed by eye but {meta["status"]}')
        out.append((key, meta, meta_path.parent))
    return out


def _pick_repo_path(key):
    short, path, piece, _serves, _why = PICKS[key]
    entry = next(e for e in load_props()['entries']
                 if e['repo'].endswith('/' + short) and e['path'] == path)
    return entry['repo'], path, piece


def px_m(meta, size_m):
    """Metres per canvas pixel of a kit shown as a thing of size_m.

    Every variant of a kit is drawn at the source's scale: the source's
    longest side is side_px pixels (location_kit.SIDE).  That side is
    the thing's longest real side (a card's width for a card), so a pair
    shows two things of the real size, not two halves of one.
    """
    return round(max(float(v) for v in size_m) / float(meta['side_px']), 6)


def location_items(kits, data):
    """location id -> the things a location shows from the kits.

    Each row carries what the headset needs to stand a variant in metres
    without reading the kit's meta (it is not in the APK): px_m, the
    metres of one canvas pixel, and for every file its alpha box
    [x0, y0, x1, y1] on the canvas (the variant's hitbox bbox), so the
    builder shows only the drawn part and stands its lowest pixel on the
    floor or the bench.
    """
    by_thing = {}
    for key, meta, _ in kits:
        for thing in meta['serves']:
            by_thing[thing] = meta
    out = {}
    for loc in data['locations']:
        rows = []
        for thing in loc['wishlist']:
            meta = by_thing.get(thing)
            if meta is None:
                continue
            count = max(1, sum(1 for s in loc['slots']
                               if s['object'] == thing))
            size = data['things'][thing]['size_m']
            queue = variant_queue(meta, loc['id'], thing,
                                  loc['shell']['type'], size)
            if not queue:
                # No variant of the kit looks like this thing here (a
                # 4 m spruce log drawn aslant is not a log lying on the
                # ground): the place shows none, and the thing waits.
                continue
            shown = queue[:count]
            rows.append({'item': thing, 'kit': meta['name'],
                         'kit_dir': f'res://art/derived/{meta["slot"]}',
                         'files': [v['file'] for v in shown],
                         'settings': [v['setting'] for v in shown],
                         'changes': [v['change'] for v in shown],
                         'bboxes': [v['hitbox']['bbox'] for v in shown],
                         'size_m': size, 'px_m': px_m(meta, size),
                         'licence': meta['license']})
        if rows:
            out[loc['id']] = rows
    return out


def not_shown(kits, data):
    """location id -> the kit things no variant of which is like the
    thing there, each variant with why (unlike()), so the file says
    what waits and why rather than leave it out silently."""
    by_thing = {}
    for _key, meta, _ in kits:
        for thing in meta['serves']:
            by_thing[thing] = meta
    out = {}
    for loc in data['locations']:
        for thing in loc['wishlist']:
            meta = by_thing.get(thing)
            if meta is None:
                continue
            size = data['things'][thing]['size_m']
            if variant_queue(meta, loc['id'], thing,
                             loc['shell']['type'], size):
                continue
            why = sorted({unlike(meta, v, size) or 'setting'
                          for v in meta['variants']})
            out.setdefault(loc['id'], []).append(
                {'item': thing, 'kit': meta['name'], 'why': why})
    return out


GODOT_NOTE = ('Things of the 99 locations from the 99 cloned repos '
              '(TABOO 0.013 p. 3, 0.012, 0.1): kits passed by eye, '
              'written by scripts/raw_assets/location_items.py ship (or '
              'items, from the shipped metas). Only the variants a '
              'location shows are in the APK; the full kits of twelve are '
              'in public/ludus/art/derived. The builder stands each as a '
              'sprite in metres (godot/scripts/location_core.gd).')


def godot_items(kits, data):
    """The text of godot/data/location-items.json for these kits."""
    return json.dumps({
        'note': GODOT_NOTE,
        'kits': {m['name']: {'thing': m['thing'], 'serves': m['serves'],
                             'dir': f'res://art/derived/{m["slot"]}',
                             'licence': m['license'],
                             'variants': len(m['variants']),
                             'side_px': m['side_px']}
                 for _, m, _ in kits},
        'locations': location_items(kits, data),
        'not_shown': not_shown(kits, data)},
        ensure_ascii=False, indent=1) + '\n'


def shipped_metas_on_disk():
    """The kits that shipped, read back from their metas in the build.

    The same list shipped_kits() gives, but from public/ludus/art/
    derived, so the headset's file can be rebuilt and checked without
    the work folder or the props cache (CI has neither).
    """
    out = []
    for path in sorted(DERIVED.glob('LOC-*/obj_*.json')):
        meta = json.loads(path.read_text('utf-8'))
        if EYE.get(meta['thing'], ('', ''))[0] == 'ship' \
                and meta.get('eye', {}).get('verdict') == 'ship':
            out.append((meta['thing'], meta, path.parent))
    out.sort(key=lambda k: k[0])
    return out


def cmd_items(args):
    """Rebuild (or with --check, compare) the headset's list of items."""
    text = godot_items(shipped_metas_on_disk(), load_locations())
    if args.check:
        old = GODOT_ITEMS.read_text('utf-8') if GODOT_ITEMS.exists() else ''
        if old != text:
            print(f'{GODOT_ITEMS.relative_to(ROOT)} is stale: run '
                  'python3 scripts/raw_assets/location_items.py items')
            return 1
        print(f'{GODOT_ITEMS.relative_to(ROOT)} up to date')
        return 0
    GODOT_ITEMS.write_text(text, 'utf-8')
    print(f'wrote {GODOT_ITEMS.relative_to(ROOT)}')
    return 0


def append_notices(kits):
    text = NOTICES.read_text('utf-8')
    rows = []
    for key, meta, _ in kits:
        row = (f'| {meta["name"]} | {", ".join(meta["serves"])} | '
               f'{len(meta["variants"])}/12 | {meta["repo"]} | '
               f'{meta["commit"][:10]} | {meta["path"]} '
               f'#{meta["source"]["piece"]} | {meta["license"]} | '
               f'{meta["shape_change"]:.1%} | {meta["colour_change"]:.1%} |')
        if f'| {meta["name"]} |' not in text:
            rows.append(row)
    if not rows:
        return 0
    if NOTICE_HEAD.strip().splitlines()[0] not in text:
        text = text.rstrip('\n') + '\n' + NOTICE_HEAD
    NOTICES.write_text(text.rstrip('\n') + '\n' + '\n'.join(rows) + '\n',
                       'utf-8')
    return len(rows)


def journal(entry):
    """Append one pass to the journal; a pass is written once."""
    cursor = json.loads(CURSOR.read_text('utf-8'))
    if any(e.get('pass') == entry['pass'] for e in cursor['log']):
        print(f'journal: pass {entry["pass"]} already recorded')
        return
    cursor['log'].append(entry)
    CURSOR.write_text(json.dumps(cursor, ensure_ascii=False, indent=1),
                      'utf-8')


def mesh_rollbacks():
    """The mesh kits of the pass that did not ship, with their numbers.

    A model kit ships only with twelve variants; none reached it in the
    first pass, so each is journalled with its pool (the models stay in
    the props store for a later pass).
    """
    import location_kit as lk
    out = []
    for key, (short, path, _parts, _serves, _why) in sorted(
            MESH_PICKS.items()):
        entry = next(e for e in load_props()['entries']
                     if e['repo'].endswith('/' + short)
                     and e['path'] == path)
        seed = lk.kit_seed(entry['repo'], path, 0)
        name = f'obj_{key.replace("-", "_")}_{seed[:10]}'
        meta_path = WORK / 'kits' / name / f'{name}.json'
        if not meta_path.exists():
            out.append({'kit': key, 'reason': 'not built'})
            continue
        meta = json.loads(meta_path.read_text('utf-8'))
        if meta['status'] == 'ok':
            continue
        out.append({'kit': key, 'name': name, 'reason': meta['status'],
                    'variants': len(meta['variants']),
                    'pool': meta.get('pool')})
    return out


def cmd_ship(args):
    import shutil
    from PIL import Image
    data = load_locations()
    kits = shipped_kits()
    shipped = []
    for key, meta, folder in kits:
        dest = DERIVED / meta['slot']
        dest.mkdir(parents=True, exist_ok=True)
        sheet = f'docs/audit/2026-09-30/location-items/{meta["name"]}.png'
        meta['eye'] = {'verdict': 'ship', 'why': EYE[key][1],
                       'sheet': sheet, 'date': '2026-09-30'}
        for v in meta['variants']:
            shutil.copy2(folder / v['file'], dest / v['file'])
        (dest / f'{meta["name"]}.json').write_text(
            json.dumps(meta, ensure_ascii=False, indent=1) + '\n', 'utf-8')
        AUDIT.mkdir(parents=True, exist_ok=True)
        img = Image.open(WORK / 'kits' / f'{meta["name"]}.sheet.png')
        img.convert('RGB').quantize(colors=128).save(ROOT / sheet,
                                                     optimize=True)
        shipped.append(meta)
    items = location_items(kits, data)
    used = {}
    for rows in items.values():
        for row in rows:
            used.setdefault(row['kit_dir'], set()).update(row['files'])
    godot_bytes = 0
    for kit_dir, files in sorted(used.items()):
        slot = kit_dir.rsplit('/', 1)[-1]
        dest = GODOT_DERIVED / slot
        dest.mkdir(parents=True, exist_ok=True)
        for f in sorted(files):
            shutil.copy2(DERIVED / slot / f, dest / f)
            godot_bytes += (dest / f).stat().st_size
    GODOT_ITEMS.write_text(godot_items(kits, data), 'utf-8')
    rows = append_notices(kits)
    rolled = [{'kit': k, 'reason': why} for k, (v, why) in
              sorted(EYE.items()) if v != 'ship']
    props = json.loads((WORK / 'props-pass.json').read_text('utf-8'))
    found = json.loads((WORK / 'hits.json').read_text('utf-8'))
    journal({
        'time': now(), 'pass': props['pass_id'],
        'kind': 'location-items (TABOO 0.013 p. 3, track B)',
        'things_looked_up': len(found['eligible']),
        'things_not_looked_up': _count(found['refused_things'].values()),
        'never_taken': found['never_taken'],
        'props_taken': props['taken'], 'props_by_kind': props['by_kind'],
        'props_by_place': props['by_place'],
        'props_bytes_outside_repo': props['bytes'],
        'register_growth_bytes': props['register_growth'],
        'kits_built': len(EYE), 'kits_shipped': [m['name'] for m in shipped],
        'kits_rolled_back': rolled,
        'refused_by_eye_on_candidates': REFUSED_BY_EYE,
        'godot_files': sum(len(f) for f in used.values()),
        'godot_bytes': godot_bytes, 'notices_rows': rows,
        'models': model_verdicts(found),
        'mesh_kits_rolled_back': mesh_rollbacks(),
    })
    print(f'shipped {len(shipped)} kits, {len(items)} locations, godot '
          f'{sum(len(f) for f in used.values())} files {godot_bytes} B, '
          f'notices +{rows}')
    return 0


# --- 3D models from the props store -------------------------------------

# Every model hit of this pass, and what became of it.  A model becomes
# a kit only with a licence that allows a store release, a format read
# here (OBJ, glTF), at most 5 000 triangles per variant and a measured
# change (location_mesh.py).
MESH_PICKS = {
    'karas': ('drwhut/tabletop-club', 'assets/TabletopClub/containers/'
              'Pot.obj', [], ['karas'],
              'a round clay pot with a rim; found under "pot" for the '
              'cauldron, but it is a clay vessel, so it serves the '
              'Armenian karas (a copper cauldron does not break)'),
    'coin-purse': ('drwhut/tabletop-club', 'assets/TabletopClub/'
                   'containers/Purse.gltf',
                   ['assets/TabletopClub/containers/Purse.bin'],
                   ['coin-purse'], 'a drawstring purse of coins, tied'),
}
MODEL_REFUSED = {
    'models/Anvil.mesh': 'Ogre binary mesh: no reader here',
    'models/Forge.mesh': 'Ogre binary mesh: no reader here',
    'models/Lamp.mesh': 'Ogre binary mesh: no reader here',
    'models/Staff.mesh': 'Ogre binary mesh: no reader here; a wizard\'s '
                         'staff',
    'data/graphics/cimpletoon/XYZ_art/pt-boat.blend':
        'a Blender file (no Blender here) of a torpedo boat',
    'data/models/pottery.blend': 'a Blender file (no Blender here)',
    'examples/shaders/resources/models/watermill.obj':
        'CC-BY-NC 4.0 (raylib examples/shaders/resources/LICENSE.md): '
        'non-commercial',
    'assets/TabletopClub/tables/Picnic Bench.obj':
        'a picnic table with fixed seats, not a bench',
}
MODEL_REFUSED_PATTERNS = (
    ('treasure_chest', 'a treasure chest in the engine\'s editor tests; '
     'the Defold licence of test data is unclear, and treasure reads as '
     'loot'),
    ('morph_weights_anim', 'a morph-target test mesh, not weights'),
)


def tabletop_licence(repo, revision, path, index_root, cache_root):
    """Author and licence of a Tabletop Club asset from its config.cfg."""
    folder, name = path.rsplit('/', 1)
    cfg = folder + '/config.cfg'
    clone = Path(index_root) / 'clones' / repo_dir(repo)
    blobs = read_blobs(clone, revision, [cfg])
    if cfg not in blobs:
        return None
    dest = cache_path(cache_root, repo, revision, cfg)
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(blobs[cfg])
    text = blobs[cfg].decode('utf-8', 'replace')
    section = re.search(r'\[' + re.escape(name) + r'\](.*?)(\n\[|$)', text,
                        re.S)
    if not section:
        return None
    body = section.group(1)
    field = {k: v for k, v in re.findall(r'(\w+) = "([^"]*)"', body)}
    return {'licence': {'CC0': 'CC0-1.0'}.get(field.get('license'),
                                              field.get('license', '')),
            'copyright': '; '.join(f'{k}: {field[k]}' for k in
                                   ('author', 'modified_by', 'url')
                                   if k in field),
            'evidence': [f'{cfg} [{name}]']}


def make_mesh_kit(key, index_root, cache_root, data, eligible):
    """Build one mesh kit; return (meta, {file: glb bytes}, previews)."""
    import location_mesh as lm
    short, path, parts, serves, why = MESH_PICKS[key]
    register = load_props()
    entry = next(e for e in register['entries']
                 if e['repo'].endswith('/' + short) and e['path'] == path)
    repo, revision = entry['repo'], entry['revision']
    facts = {'repo_licence': licence_of(index_root, repo), 'evidence': []}
    facts['licence'] = facts['repo_licence']
    found = tabletop_licence(repo, revision, path, index_root, cache_root)
    if found:
        facts.update(found)
    facts['commercial'] = '-NC' not in facts['licence']
    clone = Path(index_root) / 'clones' / repo_dir(repo)
    if parts:
        # The model's own buffers: fetched next to it, named in the meta.
        for p, blob in read_blobs(clone, revision, parts).items():
            dest = cache_path(cache_root, repo, revision, p)
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(blob)
    import location_kit as lk
    seed = lk.kit_seed(repo, path, 0)
    name = f'obj_{key.replace("-", "_")}_{seed[:10]}'
    home = home_location(serves, data)
    material = eligible[key]['material']
    meta = {
        'name': name, 'id': seed[:10], 'seed': seed, 'thing': key,
        'serves': serves, 'slot': f'LOC-{home}',
        'locations': sorted({loc['id'] for loc in data['locations']
                             if any(t in loc['wishlist'] for t in serves)}),
        'origin': 'raw-neutral-location-mesh', 'method': lm.REVISION,
        'raw_material': True,
        'source': {'repo': repo, 'path': path, 'commit': revision,
                   'piece': 0, 'parts': parts, 'prop_key': entry['key'],
                   'sha1': entry['sha1'], 'bytes': entry['bytes']},
        'repo': repo, 'path': path, 'commit': revision,
        'license': facts['licence'],
        'license_file': register['repos'][repo]['licence_file'],
        'licence_facts': facts, 'picked_by_eye': why,
        'material': material, 'ru': eligible[key]['ru'],
        'size_m': eligible[key]['size_m'], 'threshold': lm.THRESHOLD,
        'shape_basis': 'source; mean of three orthographic silhouettes',
        'sibling_basis': 'nearest-sibling, same measure',
        'colour_basis': 'source texture not shipped: our material colour',
    }
    if not facts['commercial']:
        meta.update({'status': 'licence-non-commercial', 'variants': []})
        return meta, {}, []
    src = lm.to_real(lm.load(cache_path(cache_root, repo, revision, path)),
                     meta['size_m'])
    built = lm.build_kit(src, key, material, seed)
    files, variants, previews = {}, [], []
    win = built['window']
    tag = key.replace('-', '_')
    previews.append(('src', lm.render([(src, lk.MATERIAL_STATES[material]
                                        [0][1])], size=256, win=win)))
    for n, m in enumerate(built['chosen'], 1):
        slot = f'v{n:02d}'
        fname = f'{name}_{slot}.glb'
        files[fname] = lm.to_glb(m['mesh'], m['state'][1])
        variants.append({
            'slot': slot, 'file': fname,
            'change': lk.describe(m['spec']),
            'setting': m['spec']['setting'], 'state': m['state'][0],
            'shape_change': round(m['shape'], 4),
            'sibling_min': round(m['sibling_min'], 4),
            'visible': round(m['visible'], 4), 'triangles': m['tris'],
            'analytics_id': f'ludus.variant.{tag}.{seed[:10]}.{slot}'})
        shown = [(m['mesh']['thing'], m['state'][1])] + [
            (g, lk.SAND if len(g.faces) > 100 else lk.GRASS)
            for g in m['mesh']['ground']]
        previews.append((f'{slot} {variants[-1]["change"][:12]}',
                         lm.render(shown, size=256, win=win)))
    shapes = [v['shape_change'] for v in variants] or [0.0]
    meta.update({
        'pool': built['pool'], 'variants': variants,
        'shortfall': lm.KIT_SIZE - len(variants),
        'status': 'ok' if len(variants) == lm.KIT_SIZE else 'shortfall',
        'shape_change': min(shapes), 'source_triangles': len(src.faces),
        'claim_features': [
            f'нейтральная вещь локаций «{meta["ru"]}»: объёмная модель '
            f'из склада реквизита ({why})',
            'двенадцать вариантов из реальных состояний вещи; поза без '
            'изменения строения варианта не даёт',
            f'цвет — наш материал «{material}», текстура источника не '
            f'используется; масштаб — настоящий размер вещи',
            f'изменение формы: среднее по трём ортогональным силуэтам '
            f'|A xor B| / |A or B| от {min(shapes):.1%} до '
            f'{max(shapes):.1%}; к ближайшему соседу не меньше 35 %',
            f'источник: {repo} @ {revision[:10]}, {path} '
            f'({facts["licence"]}; {facts.get("copyright", "")})'],
        'constitution': (
            'ФОРМА: настоящая вещь места в её настоящих состояниях → '
            'ДЕЙСТВИЕ: вещь стоит в слоте локации и не заслоняет сердце '
            'места → ЦЕЛЬ: вещи служат учению (ТАБУ №0.013 п. 3, 9)'),
    })
    return meta, files, previews


def model_verdicts(found):
    """What became of every model hit of the pass."""
    out = {}
    for hit in found['hits']:
        if hit['kind'] != 'model':
            continue
        picked = [k for k, v in MESH_PICKS.items() if v[1] == hit['path']]
        if picked:
            out[hit['path']] = f'kit for {picked[0]}'
            continue
        why = MODEL_REFUSED.get(hit['path'])
        for pattern, reason in MODEL_REFUSED_PATTERNS:
            if why is None and pattern in hit['path']:
                why = reason
        out[hit['path']] = why or 'not looked at'
    return out


def cmd_meshes(args):
    import location_kit as lk
    found = json.loads((WORK / 'hits.json').read_text('utf-8'))
    data = load_locations()
    out = WORK / 'kits'
    for key in (args.only.split(',') if args.only else sorted(MESH_PICKS)):
        meta, files, previews = make_mesh_kit(key, args.index, args.cache,
                                              data, found['eligible'])
        folder = out / meta['name']
        folder.mkdir(parents=True, exist_ok=True)
        for old in folder.glob('*'):
            old.unlink()
        for fname, blob in files.items():
            (folder / fname).write_bytes(blob)
        (folder / f'{meta["name"]}.json').write_text(
            json.dumps(meta, ensure_ascii=False, indent=1), 'utf-8')
        if previews:
            lk.kit_sheet(f'{key}: {meta["name"]} {meta["status"]} '
                         f'{len(meta["variants"])}/12 pool '
                         f'{meta["pool"]["size"]} ({meta["license"]})',
                         previews[0][1], previews[1:],
                         out / f'{meta["name"]}.sheet.png')
        size = sum(len(b) for b in files.values())
        print(f'{key}: {meta["name"]} {meta["status"]} '
              f'{len(meta["variants"])}/12 {size} B pool '
              f'{meta.get("pool")}')
    for path, why in sorted(model_verdicts(found).items()):
        print(f'  model {path}: {why}')
    return 0


# --- Command line ---------------------------------------------------------

def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat(
        timespec='seconds')


def cmd_search(args):
    eligible, refused = wished()
    hits, never_taken = search(args.index, eligible)
    WORK.mkdir(parents=True, exist_ok=True)
    per_thing = {k: {'images': 0, 'models': 0} for k in eligible}
    for hit in hits.values():
        for key in hit['things']:
            per_thing[key]['images' if hit['kind'] == 'image'
                           else 'models'] += 1
    out = {'eligible': eligible, 'refused_things': refused,
           'never_taken': never_taken, 'per_thing': per_thing,
           'hits': [hits[k] for k in sorted(hits)]}
    (WORK / 'hits.json').write_text(json.dumps(out, ensure_ascii=False,
                                               indent=1), 'utf-8')
    with_hits = sum(1 for v in per_thing.values()
                    if v['images'] + v['models'])
    print(f'wished things {len(eligible) + len(refused)}: eligible '
          f'{len(eligible)}, not looked up {len(refused)} '
          f'{_count(refused.values())}')
    print(f'hits {len(hits)} files (images '
          f'{sum(1 for h in hits.values() if h["kind"] == "image")}, '
          f'models {sum(1 for h in hits.values() if h["kind"] == "model")})'
          f' for {with_hits} things; never taken {never_taken}')
    return 0


def _count(values):
    out = {}
    for v in values:
        out[v] = out.get(v, 0) + 1
    return dict(sorted(out.items()))


def cmd_props(args):
    found = json.loads((WORK / 'hits.json').read_text('utf-8'))
    hits = {(h['repo'], h['path']): h for h in found['hits']}
    register = load_props()
    before = len(dump_props(register).encode('utf-8'))
    pass_id = args.pass_id or 'loc-items-' + now()
    stats = take_props(hits, found['eligible'], args.index, args.cache,
                       pass_id, register)
    size = save_props(register)
    stats.update({'pass_id': pass_id, 'register_bytes': size,
                  'register_growth': size - before})
    (WORK / 'props-pass.json').write_text(json.dumps(stats, indent=1),
                                          'utf-8')
    print(json.dumps(stats, ensure_ascii=False))
    return 0


def cmd_candidates(args):
    found = json.loads((WORK / 'hits.json').read_text('utf-8'))
    eligible = found['eligible']
    only = tuple(args.only.split(',')) if args.only else ()
    cands, refused = candidates(load_props(), eligible, args.cache, only)
    best = {t: c[:PER_THING] for t, c in cands.items()}
    (WORK / 'candidates.json').write_text(json.dumps(
        {'best': best, 'counts': {t: len(c) for t, c in cands.items()},
         'refused': refused}, ensure_ascii=False, indent=1), 'utf-8')
    things = sorted(best)
    for n in range(0, len(things), 12):
        rows = []
        for t in things[n:n + 12]:
            tiles = []
            for i, c in enumerate(best[t]):
                tag = f'{chr(97 + i)} {c["repo"].split("/")[-1][:9]}'
                tiles.append((tag, piece_image(c, args.cache)))
            rows.append((t, tiles))
        candidate_sheet(rows, WORK / f'candidates-{n // 12:02d}.png')
    none = sorted(set(eligible) - set(cands))
    print(f'things with candidates {len(cands)}, without {len(none)}: '
          f'{none}')
    return 0


def save_png(pal, path):
    """Save a variant's palette image (location_kit.as_saved) as is."""
    pal.save(path, optimize=True)


def remeasure(meta, folder, source_canvas):
    """Measure the saved files again; the meta keeps these numbers."""
    import form
    import location_kit as lk
    import neutral_procedural as npd
    from PIL import Image
    src_mask = form.alpha_mask(source_canvas)
    src_fill = form.fill_holes(src_mask)
    masks = []
    for v in meta['variants']:
        img = Image.open(folder / v['file'])
        img.load()
        img = img.convert('RGBA')
        mask = form.alpha_mask(img)
        fill = form.fill_holes(mask)
        v['shape_change'] = round(npd.distance(src_mask, mask, src_fill,
                                               fill), 4)
        v['colour_change'] = round(form.colour_change(
            source_canvas, img, src_mask, mask), 4)
        v['hitbox'] = form.hitbox(mask)
        masks.append((mask, fill))
    for i, v in enumerate(meta['variants']):
        others = [npd.distance(masks[i][0], m, masks[i][1], f)
                  for j, (m, f) in enumerate(masks) if j != i]
        v['sibling_min'] = round(min(others), 4) if others else 1.0
    if meta['variants']:
        meta['shape_change'] = min(v['shape_change']
                                   for v in meta['variants'])
        meta['colour_change'] = min(v['colour_change']
                                    for v in meta['variants'])
        meta['redraw']['colour_change'] = meta['colour_change']
        low = [v['slot'] for v in meta['variants']
               if min(v['shape_change'], v['sibling_min'],
                      v['colour_change']) < lk.THRESHOLD]
        if low:
            meta['status'] = 'below-threshold-after-save'
            meta['below_threshold'] = low


def cmd_kits(args):
    import location_kit as lk
    found = json.loads((WORK / 'hits.json').read_text('utf-8'))
    data = load_locations()
    keys = args.only.split(',') if args.only else sorted(PICKS)
    out = WORK / 'kits'
    summary = []
    for key in keys:
        meta, images, source = make_kit(key, args.index, args.cache, data,
                                        found['eligible'])
        folder = out / meta['name']
        folder.mkdir(parents=True, exist_ok=True)
        for old in folder.glob('*'):
            old.unlink()
        for fname, img in images.items():
            save_png(img, folder / fname)
        if source is not None:
            remeasure(meta, folder, source)
            source.save(folder / 'source.png')
            from PIL import Image
            shown = []
            for v in meta['variants']:
                img = Image.open(folder / v['file'])
                img.load()
                shown.append((f'{v["slot"]} {v["change"][:12]}',
                              img.convert('RGBA')))
            lk.kit_sheet(f'{key}: {meta["name"]} {meta["status"]} '
                         f'{len(meta["variants"])}/12 pool '
                         f'{meta["pool"]["size"]} ({meta["license"]})',
                         source, shown, out / f'{meta["name"]}.sheet.png')
        (folder / f'{meta["name"]}.json').write_text(
            json.dumps(meta, ensure_ascii=False, indent=1), 'utf-8')
        size = sum(f.stat().st_size for f in folder.glob('*_v*.png'))
        summary.append((key, meta['name'], meta['status'],
                        len(meta['variants']), meta.get('pool', {}), size))
        print(f'{key}: {meta["name"]} {meta["status"]} '
              f'{len(meta["variants"])}/12 {size} B pool '
              f'{meta.get("pool", {})}')
    return 0


def cmd_licences(args):
    """Append the per-file licence corrections and the withdrawals of
    lines never() now refuses to the props register (append-only), and
    journal the pass."""
    register = load_props()
    pass_id = args.pass_id or 'loc-props-licences-2026-09-30'
    when = now()
    fixes = licence_corrections(register, args.index, pass_id, when)
    gone = withdraw_never(register, pass_id, when)
    left = [e['key'] for e in register['entries']
            if licence_now(register, e['key'], e['licence']) in NO_LICENCE
            and e['key'] not in withdrawn_keys(register)]
    save_props(register)
    by = {}
    for c in fixes:
        pair = f'{c["was"]} -> {c["licence"]}'
        by[pair] = by.get(pair, 0) + 1
    print(f'licence corrections +{len(fixes)}, withdrawn +{len(gone)}, '
          f'lines still without a licence: {len(left)}')
    for pair, n in sorted(by.items()):
        print(f'  {n:5d}  {pair}')
    journal({'time': when, 'pass': pass_id,
             'kind': 'props register licences and withdrawals '
                     '(TABOO 0.012 p. 1-2; review 2026-09-30)',
             'licence_corrections': len(fixes), 'by_change': by,
             'withdrawn': len(gone),
             'withdrawn_why': sorted({w['why'] for w in gone}),
             'without_licence_after': len(left)})
    return 1 if left else 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['search', 'props',
                                            'candidates', 'kits',
                                            'meshes', 'ship', 'items',
                                            'licences'])
    parser.add_argument('--index', default=DEFAULT_INDEX)
    parser.add_argument('--cache', default=DEFAULT_CACHE)
    parser.add_argument('--pass-id', default='')
    parser.add_argument('--only', default='')
    parser.add_argument('--check', action='store_true',
                        help='items: fail if the headset file is stale')
    args = parser.parse_args(argv)
    return {'search': cmd_search, 'props': cmd_props,
            'candidates': cmd_candidates,
            'kits': cmd_kits, 'meshes': cmd_meshes,
            'ship': cmd_ship, 'items': cmd_items,
            'licences': cmd_licences}[args.command](args)


if __name__ == '__main__':
    sys.exit(main())
