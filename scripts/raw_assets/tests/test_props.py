"""The props store takes every non-game hit, and nothing holy.

CLAUDE.md TABOO 0.012 (operator, 2026-09-30): "бери все даже не
игровое нам в реквизит".  The last pass refused 71 hits of DEF-024 and
123 of DEF-028 as "not a game object"; they now go to the shelf.  These
tests hold the edges of that rule: holy things, the stop-list, fonts
and unlicensed repos never reach the register, the register only grows,
one thing is registered once, and two runs write the same lines.
"""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import osint_cycle  # noqa: E402
import props  # noqa: E402
from search_index import search  # noqa: E402

LICENSED = 'https://github.com/test/licensed'
UNLICENSED = 'https://github.com/test/unlicensed'

# Every path here is non-game by folder; some are also holy, stop-listed
# or a font, and those must stay off the shelf.
FILES = {
    'examples/water/wave.png': b'wave',
    'docs/screenshots/lake.png': b'screen',
    'tests/fixtures/rope.c': b'int rope;',
    'tools/editor/grid.png': b'grid',
    'examples/church_bell.png': b'holy',
    'docs/icon/cross_gold.png': b'holy2',
    'screenshots/altar.png': b'holy3',
    'examples/pentagram.png': b'stop',
    'docs/rune_stone.png': b'stop2',
    'docs/fonts/dejavu.png': b'font',
    'examples/ui/font.ttf': b'font2',
    'sprites/items/fish.png': b'game',
}
HOLY_OR_STOP = ('examples/church_bell.png', 'docs/icon/cross_gold.png',
                'screenshots/altar.png', 'examples/pentagram.png',
                'docs/rune_stone.png')
FONTS = ('docs/fonts/dejavu.png', 'examples/ui/font.ttf')
PROPS = ('examples/water/wave.png', 'docs/screenshots/lake.png',
         'tests/fixtures/rope.c', 'tools/editor/grid.png')


def cached(entry):
    return props.cache_rel(entry['repo'], entry['revision'], entry['path'])


def git(cwd, *args):
    return subprocess.run(
        ['git', '-c', 'user.name=t', '-c', 'user.email=t@t', *args],
        cwd=cwd, check=True, capture_output=True, text=True).stdout.strip()


def make_repo(index_root, url, files, licence):
    """A tiny repo laid out like the blobless index of the 99 repos."""
    name = props.repo_dir(url)
    clone = index_root / 'clones' / name
    clone.mkdir(parents=True)
    git(clone, 'init', '-q')
    if licence:
        files = {**files, 'LICENSE': b'Permission is hereby granted'}
    for path, data in files.items():
        (clone / path).parent.mkdir(parents=True, exist_ok=True)
        (clone / path).write_bytes(data)
    git(clone, 'add', '-A')
    git(clone, 'commit', '-q', '-m', 'fixture')
    sha = git(clone, 'rev-parse', 'HEAD')
    header = {'repo': url, 'commit': sha,
              'license_file': 'LICENSE' if licence else None,
              'license_head': 'PERMISSION IS HEREBY GRANTED' if licence
              else '', 'files': len(files)}
    kinds = {'.png': 'image', '.c': 'code', '.ttf': 'other'}
    (index_root / 'index').mkdir(exist_ok=True)
    with (index_root / 'index' / f'{name}.jsonl').open('w') as fh:
        fh.write(json.dumps({'header': header}) + '\n')
        for path in sorted(files):
            kind = kinds.get(Path(path).suffix, 'data')
            fh.write(json.dumps({'path': path, 'kind': kind}) + '\n')
    return sha


class PropsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        # Resolved, because to_slot resolves its work folder too.
        self.root = Path(self.tmp.name).resolve()
        self.index = self.root / 'raw-repos'
        self.cache = self.root / 'raw-props'
        make_repo(self.index, LICENSED, FILES, licence=True)
        make_repo(self.index, UNLICENSED, {'examples/water/lake.png':
                                           b'nolicence'}, licence=False)

    def tearDown(self):
        self.tmp.cleanup()

    def hits(self, allow_unlicensed=False):
        # Every path of the fixtures, the way the runner searches.
        return search(self.index, {'image', 'code', 'other'},
                      ['wave', 'lake', 'rope', 'grid', 'church', 'bell',
                       'cross', 'altar', 'pentagram', 'rune', 'dejavu',
                       'font', 'fish'], limit=200,
                      allow_unlicensed=allow_unlicensed)

    def shelve(self, hits, register, pass_id='osint-test', cache=None):
        _usable, shelf, _refused = osint_cycle.sort_hits(hits, True)
        return props.take([(h, 'DEF-024') for h in shelf], register,
                          self.index, cache or self.cache, pass_id,
                          lambda hit: 'MIT', osint_cycle.is_prop)

    def test_non_game_hits_go_to_the_shelf_with_their_bytes(self):
        register = props.empty_register()
        stats = self.shelve(self.hits(), register)
        paths = sorted(e['path'] for e in register['entries'])
        self.assertEqual(paths, sorted(PROPS))
        self.assertEqual(stats['taken'], {'editor': 1, 'example': 1,
                                          'screenshot': 1, 'test': 1})
        for e in register['entries']:
            data = (self.cache / cached(e)).read_bytes()
            self.assertEqual(data, FILES[e['path']])
            self.assertEqual(e['bytes'], len(data))
            self.assertEqual(e['licence_file'], 'LICENSE')
            self.assertEqual(e['deficit_id'], 'DEF-024')

    def test_a_game_object_still_goes_to_the_pipeline(self):
        usable, shelf, _ = osint_cycle.sort_hits(self.hits(), True)
        self.assertEqual([h['path'] for h in usable],
                         ['sprites/items/fish.png'])
        self.assertNotIn('sprites/items/fish.png',
                         [h['path'] for h in shelf])

    def test_holy_and_stop_listed_never_reach_the_register(self):
        for path in HOLY_OR_STOP:
            self.assertIn('not-a-game-object', osint_cycle.reasons(path),
                          path)
            self.assertFalse(osint_cycle.is_prop(path), path)
            self.assertIn(osint_cycle.allowed(path),
                          ('sacred-never-raw', 'dogma-stop-list'), path)
        register = props.empty_register()
        self.shelve(self.hits(), register)
        # Even handed to the store directly, the guard refuses them.
        forced = [({'repo': LICENSED, 'commit': 'x' * 40, 'path': p,
                    'kind': 'image', 'license_file': 'LICENSE'}, 'DEF-024')
                  for p in HOLY_OR_STOP]
        stats = props.take(forced, register, self.index, self.cache,
                           'osint-test', lambda hit: 'MIT',
                           osint_cycle.is_prop)
        self.assertEqual(stats['refused'], {'not-a-prop': len(HOLY_OR_STOP)})
        shelved = {e['path'] for e in register['entries']}
        self.assertFalse(shelved & set(HOLY_OR_STOP))
        for path in HOLY_OR_STOP:
            self.assertFalse(list(self.cache.rglob(Path(path).name)), path)

    def test_fonts_stay_refused(self):
        for path in FONTS:
            self.assertEqual(osint_cycle.allowed(path), 'font', path)
            self.assertFalse(osint_cycle.is_prop(path), path)
        register = props.empty_register()
        self.shelve(self.hits(), register)
        self.assertFalse({e['path'] for e in register['entries']}
                         & set(FONTS))

    def test_nothing_from_a_repo_without_a_licence(self):
        hits = [h for h in self.hits(allow_unlicensed=True)
                if h['repo'] == UNLICENSED]
        self.assertEqual(len(hits), 1)
        _usable, shelf, refused = osint_cycle.sort_hits(hits, True)
        self.assertEqual((shelf, refused), ([], {'no-licence': 1}))
        register = props.empty_register()
        stats = props.take([(hits[0], 'DEF-024')], register, self.index,
                           self.cache, 'osint-test', lambda hit: 'MIT',
                           osint_cycle.is_prop)
        self.assertEqual(stats['refused'], {'no-licence': 1})
        self.assertEqual(register['entries'], [])
        # The runner's own search never even lists it.
        self.assertNotIn(UNLICENSED, {h['repo'] for h in self.hits()})

    def test_one_thing_is_registered_once(self):
        register = props.empty_register()
        self.shelve(self.hits(), register)
        first = list(register['entries'])
        stats = self.shelve(self.hits(), register, pass_id='osint-later')
        self.assertEqual(register['entries'], first)
        self.assertEqual(stats['duplicates'], len(PROPS))
        self.assertEqual(stats['taken'], {})

    def test_the_register_only_grows(self):
        path = self.root / 'register.json'
        register = props.empty_register()
        self.shelve(self.hits(), register)
        props.save_register(register, path)
        loaded = props.load_register(path)
        self.assertEqual(loaded, register)
        dropped = {**loaded, 'entries': loaded['entries'][1:]}
        with self.assertRaises(props.AppendOnlyError):
            props.save_register(dropped, path)
        edited = props.load_register(path)
        edited['entries'][0]['kind'] = 'other'
        with self.assertRaises(props.AppendOnlyError):
            props.save_register(edited, path)
        grown = props.load_register(path)
        grown['entries'].append({**grown['entries'][0], 'key': 'p_new'})
        props.save_register(grown, path)
        self.assertEqual(len(props.load_register(path)['entries']),
                         len(PROPS) + 1)
        # A withdrawal is appended too, and cannot be taken back.
        key = grown['entries'][0]['key']
        props.withdraw(grown, key, 'stop-list grew', '2026-09-30')
        props.save_register(grown, path)
        loaded = props.load_register(path)
        self.assertEqual(loaded['withdrawn'][0]['key'], key)
        self.assertEqual(len(loaded['entries']), len(PROPS) + 1)
        with self.assertRaises(ValueError):
            props.to_slot(key, 'DEF-056', self.index, self.cache,
                          work=self.root / 'build', register_path=path)
        loaded['withdrawn'] = []
        with self.assertRaises(props.AppendOnlyError):
            props.save_register(loaded, path)

    def test_two_runs_write_the_same_register(self):
        one, two = props.empty_register(), props.empty_register()
        self.shelve(self.hits(), one, cache=self.root / 'a')
        self.shelve(self.hits(), two, cache=self.root / 'b')
        self.assertEqual(props.dump_register(one), props.dump_register(two))
        # One entry per line, so a pass is appended lines in git.
        text = props.dump_register(one)
        self.assertEqual(len(text.splitlines()), 2 + len(PROPS) + 1)
        json.loads(text)

    def test_register_schema(self):
        register = props.empty_register()
        self.shelve(self.hits(), register)
        for e in register['entries']:
            self.assertEqual(props.validate_entry(e), [], e)
            self.assertEqual(set(e), set(props.FIELDS))
        bad = {**register['entries'][0], 'kind': 'loot'}
        self.assertTrue(props.validate_entry(bad))

    def test_the_committed_register_keeps_its_schema(self):
        register = props.load_register(props.REGISTER)
        self.assertEqual(register['schema'], props.SCHEMA)
        keys = [e['key'] for e in register['entries']]
        self.assertEqual(len(keys), len(set(keys)))
        # A thing a grown stop-list now covers must be named withdrawn,
        # never deleted (the register only grows).
        gone = {w['key'] for w in register.get('withdrawn', [])}
        self.assertLessEqual(gone, set(keys))
        for e in register['entries']:
            self.assertEqual(props.validate_entry(e), [], e['key'])
            if e['key'] not in gone:
                self.assertTrue(osint_cycle.is_prop(e['path']), e['path'])
        self.assertLessEqual(props.REGISTER.stat().st_size
                             if props.REGISTER.exists() else 0,
                             props.REGISTER_BUDGET_BYTES)

    def test_the_cache_may_not_live_in_the_repo(self):
        for inside in (props.ROOT, props.ROOT / 'build' / 'props-cache',
                       props.ROOT / 'godot' / 'props'):
            with self.assertRaises(ValueError):
                props.check_cache_outside(inside)
        props.check_cache_outside(self.cache)

    def test_prop_kinds(self):
        cases = {'examples/audio/a.png': 'example',
                 'docs/screenshots/a.png': 'screenshot',
                 'tests/rope.c': 'test', 'tools/editor/x.png': 'editor',
                 'docs/manual/page.png': 'doc',
                 'fastlane/metadata/icon.png': 'promo',
                 'src/restore.c': 'other', 'lib/compress.c': 'other',
                 # The first real pass filed these UI classes as
                 # screenshots; a screen class is code, not a picture.
                 'core/src/com/unciv/ui/screens/worldscreen/Minimap.kt':
                 'other'}
        for path, kind in cases.items():
            self.assertEqual(props.prop_kind(path), kind, path)

    def test_the_register_keeps_to_its_budget(self):
        register = props.empty_register()
        empty = len(props.dump_register(register).encode('utf-8'))
        _usable, shelf, _ = osint_cycle.sort_hits(self.hits(), True)
        stats = props.take([(h, 'DEF-024') for h in shelf], register,
                           self.index, self.cache, 'osint-test',
                           lambda hit: 'MIT', osint_cycle.is_prop,
                           budget=empty + 700)
        self.assertEqual(len(register['entries']), 1)
        self.assertEqual(stats['refused'], {'props-budget': len(PROPS) - 1})
        self.assertLessEqual(len(props.dump_register(register)),
                             empty + 700)
        # What the register does not name is not in the cache either.
        files = [p for p in self.cache.rglob('*') if p.is_file()]
        self.assertEqual(len(files), 1)
        self.assertLessEqual(props.REGISTER.stat().st_size
                             if props.REGISTER.exists() else 0,
                             props.REGISTER_BUDGET_BYTES)

    def test_to_slot_prepares_in_build_and_ships_nothing(self):
        path = self.root / 'register.json'
        register = props.empty_register()
        self.shelve(self.hits(), register)
        props.save_register(register, path)
        key = next(e['key'] for e in register['entries']
                   if e['path'] == 'examples/water/wave.png')
        work = self.root / 'build' / 'props'
        derived = sorted(props.DERIVED.rglob('*'))
        commands = []
        plan = props.to_slot(key, 'DEF-056', self.index, self.cache,
                             work=work, register_path=path,
                             runner=commands.append)
        self.assertFalse(plan['shipped'])
        self.assertEqual(plan['route'], 'image-pipeline')
        self.assertEqual(len(commands), 2)
        for cmd in commands:
            for arg in cmd[2:]:
                if arg.startswith('/'):
                    self.assertTrue(arg.startswith(str(work)), arg)
        self.assertEqual(sorted(props.DERIVED.rglob('*')), derived)
        # Images go only to raw-material slots; code only to a rewrite.
        with self.assertRaises(ValueError):
            props.to_slot(key, 'DEF-024', self.index, self.cache,
                          work=work, register_path=path,
                          runner=commands.append)
        code = next(e['key'] for e in register['entries']
                    if e['path'] == 'tests/fixtures/rope.c')
        plan = props.to_slot(code, 'DEF-024', self.index, self.cache,
                             work=work, register_path=path)
        self.assertEqual(plan['route'], 'code-rewrite')
        self.assertIn('code_delta.py', plan['next'])
        # A location deficit filled by code takes neither images nor
        # code from raw material, so no prop may go there.
        self.assertEqual(osint_cycle.slot_kinds(
            {'category': 'локация', 'fill': 'code'}), set())
        with self.assertRaises(ValueError):
            props.to_slot(code, 'DEF-031', self.index, self.cache,
                          work=work, register_path=path)
        with self.assertRaises(ValueError):
            props.to_slot(key, 'DEF-056', self.index, self.cache,
                          work=props.DERIVED / 'x', register_path=path)

    def test_to_slot_restores_the_exact_bytes(self):
        path = self.root / 'register.json'
        register = props.empty_register()
        self.shelve(self.hits(), register)
        props.save_register(register, path)
        entry = register['entries'][0]
        (self.cache / cached(entry)).unlink()
        local = props.restore(entry, self.index, self.cache)
        self.assertEqual(local.read_bytes(), FILES[entry['path']])
        (self.cache / cached(entry)).write_bytes(b'tampered')
        self.assertEqual(props.restore(entry, self.index,
                                       self.cache).read_bytes(),
                         FILES[entry['path']])


if __name__ == '__main__':
    unittest.main()
