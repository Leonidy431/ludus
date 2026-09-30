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

import intake  # noqa: E402
import licences  # noqa: E402
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
    # A weapon and a selection outline are props too; to_slot keeps
    # them out of neutral slots and out of the pipeline.
    'examples/weapons/sword.png': b'sword',
    'examples/unit-outline.png': b'outline',
}
HOLY_OR_STOP = ('examples/church_bell.png', 'docs/icon/cross_gold.png',
                'screenshots/altar.png', 'examples/pentagram.png',
                'docs/rune_stone.png')
FONTS = ('docs/fonts/dejavu.png', 'examples/ui/font.ttf')
PROPS = ('examples/water/wave.png', 'docs/screenshots/lake.png',
         'tests/fixtures/rope.c', 'tools/editor/grid.png',
         'examples/weapons/sword.png', 'examples/unit-outline.png')

# Holy, occult and other-faith paths the first lists let through
# (review of 2026-09-30); the last ones are real paths of the index.
PROBE_HOLY_OR_STOP = (
    'examples/cathedral.png', 'docs/chapel.png', 'examples/monastery.png',
    'docs/jesus.png', 'docs/virgin_mary.png', 'docs/theotokos.png',
    'examples/prayer.png', 'docs/rosary.png', 'examples/bishop.png',
    'docs/икона.png', 'docs/церковь.png', 'docs/крест.png',
    'docs/kreuz.png', 'docs/iglesia.png', 'docs/thurible.png',
    'docs/semantron.png', 'docs/mitre.png', 'docs/cassock.png',
    'docs/eucharist.png', 'docs/baptism.png', 'docs/paten.png',
    'docs/diskos.png', 'docs/pentacle.png', 'docs/tarot.png',
    'docs/horoscope.png', 'docs/astrology.png', 'docs/ouija.png',
    'docs/baphomet.png', 'docs/lucifer.png', 'docs/mosque.png',
    'docs/buddha.png', 'docs/divination.png',
    'core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/actors/'
    'buffs/Bless.java',
    'data/graphics/wonders/js_bachs_cathedral.png',
    'data/flags/templar-shield.png',
    'Resources/Textures/chapel_carpet.rsi/chapel.png',
    'core/src/main/assets/splashes/cleric.jpg',
    'public/charges/mitre.svg',
    'Mage.Sets/src/mage/cards/n/NovaPentacle.java',
    'Mage.Sets/src/mage/cards/a/AstrologiansPlanisphere.java',
    'Mage.Sets/src/mage/cards/v/VoodooDoll.java',
    'Mage.Sets/src/mage/cards/m/MonasteryFlock.java')
# Words that only look like holy ones stay free.
PROBE_FREE = ('examples/spray.png', 'docs/summary.png', 'docs/patent.png',
              'examples/diving/rov.png', 'examples/god_rays.png',
              'examples/GodRays.java', 'docs/astrolabe.png',
              'examples/template.png', 'docs/miter_join.png')


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

    def shelve(self, hits, register, pass_id='osint-test', cache=None):
        _usable, shelf, _refused = osint_cycle.sort_hits(hits, True)
        return props.take([(h, 'DEF-024') for h in shelf], register,
                          self.index, cache or self.cache, pass_id,
                          lambda hit: 'MIT', osint_cycle.is_prop)

    def hits(self, allow_unlicensed=False):
        # Every path of the fixtures, the way the runner searches.
        return search(self.index, {'image', 'code', 'other'},
                      ['wave', 'lake', 'rope', 'grid', 'church', 'bell',
                       'cross', 'altar', 'pentagram', 'rune', 'dejavu',
                       'font', 'fish', 'sword', 'outline'], limit=200,
                      allow_unlicensed=allow_unlicensed)

    def test_non_game_hits_go_to_the_shelf_with_their_bytes(self):
        register = props.empty_register()
        stats = self.shelve(self.hits(), register)
        paths = sorted(e['path'] for e in register['entries'])
        self.assertEqual(paths, sorted(PROPS))
        self.assertEqual(stats['taken'], {'editor': 1, 'example': 3,
                                          'screenshot': 1, 'test': 1})
        self.assertEqual(stats['taken_by_index_kind'],
                         {'code': 1, 'image': 5})
        for e in register['entries']:
            data = (self.cache / cached(e)).read_bytes()
            self.assertEqual(data, FILES[e['path']])
            self.assertEqual(e['bytes'], len(data))
            self.assertEqual(e['licence_file'], 'LICENSE')
            self.assertEqual(e['deficit_id'], 'DEF-024')
            self.assertEqual(len(e['blob']), 40)

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

    def test_the_grown_lists_catch_what_the_first_ones_missed(self):
        for path in PROBE_HOLY_OR_STOP:
            self.assertFalse(osint_cycle.is_prop(path), path)
            self.assertIn(osint_cycle.allowed(path),
                          ('sacred-never-raw', 'dogma-stop-list'), path)
        for path in PROBE_FREE:
            self.assertEqual(osint_cycle.reasons(path),
                             ['not-a-game-object'], path)
        # A holy word never becomes a search key.
        for word in ('cleric', 'bless', 'prayer', 'tarot'):
            self.assertTrue(osint_cycle.is_sacred(word)
                            or osint_cycle.is_stop_listed(word), word)

    def test_a_permissive_guard_cannot_shelve_a_holy_thing(self):
        # take() asks the holy list and the stop-list itself; a guard
        # passed by a caller can only narrow the shelf.
        forced = [({'repo': LICENSED, 'commit': 'x' * 40, 'path': p,
                    'kind': 'image', 'license_file': 'LICENSE'}, 'DEF-040')
                  for p in HOLY_OR_STOP + PROBE_HOLY_OR_STOP]
        register = props.empty_register()
        stats = props.take(forced, register, self.index, self.cache,
                           'osint-test', lambda hit: 'MIT',
                           lambda path: True)
        self.assertEqual(stats['refused'], {'not-a-prop': len(forced)})
        self.assertEqual(register['entries'], [])
        self.assertFalse(self.cache.exists()
                         and any(self.cache.rglob('*')))

    def test_a_file_s_own_licence_decides(self):
        rotp = 'https://github.com/RayFowler/rotp-public'
        art = licences.path_licence(rotp, 'src/rotp/images/Ship.jpg', 'GPL')
        self.assertEqual(art, 'CC-BY-NC-ND-4.0')
        self.assertTrue(licences.shelvable(art))
        self.assertFalse(licences.derivable(art))
        self.assertEqual(licences.path_licence(
            rotp, 'src/rotp/model/Ship.java', 'GPL'), 'GPL')
        self.assertEqual(licences.head_licence(
            'Microsoft Public License (Ms-PL)'), 'Ms-PL')
        dep5 = ('Format: https://www.debian.org/doc/packaging-manuals/'
                'copyright-format/1.0/\n\nFiles: *\nLicense: GPL-3+\n\n'
                'Files: images/*\nLicense: CC-BY-SA-4.0\n\n'
                'Files: images/land/*\nLicense: public-domain\n')
        self.assertEqual(licences.head_licence(dep5), licences.DEP5)
        for path, want in (('src/a.cpp', 'GPL-3+'),
                           ('images/ship.png', 'CC-BY-SA-4.0'),
                           ('images/land/a.jpg', 'public-domain')):
            self.assertEqual(licences.path_licence('r', path,
                                                   licences.DEP5, dep5),
                             want)
        for unread in ('UNKNOWN', 'Defold-1.0', 'NOASSERTION'):
            self.assertFalse(licences.shelvable(unread), unread)
        # An unread licence is refused, never shelved under a guess.
        register = props.empty_register()
        _usable, shelf, _ = osint_cycle.sort_hits(self.hits(), True)
        stats = props.take([(h, 'DEF-024') for h in shelf], register,
                           self.index, self.cache, 'osint-test',
                           lambda hit: 'UNKNOWN', osint_cycle.is_prop)
        self.assertEqual(stats['refused'], {'licence-UNKNOWN': len(PROPS)})
        self.assertEqual(register['entries'], [])

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
        self.assertEqual(stats['seen_by_deficit'], {'DEF-024': len(PROPS)})
        self.assertEqual(stats['taken'], {})

    def reindex(self):
        # An upstream commit that touches none of the props, then the
        # index rebuilt from the new HEAD, as the free CI runner does
        # every hour.
        clone = self.index / 'clones' / props.repo_dir(LICENSED)
        readme = clone / 'README'
        readme.write_text((readme.read_text() if readme.exists() else '')
                          + 'moved\n')
        git(clone, 'add', 'README')
        git(clone, 'commit', '-q', '-m', 'upstream moves')
        name = props.repo_dir(LICENSED)
        index = self.index / 'index' / f'{name}.jsonl'
        lines = index.read_text().splitlines()
        head = json.loads(lines[0])
        head['header']['commit'] = git(clone, 'rev-parse', 'HEAD')
        index.write_text('\n'.join([json.dumps(head)] + lines[1:]) + '\n')

    def test_upstream_moving_does_not_shelve_the_same_bytes_again(self):
        register = props.empty_register()
        self.shelve(self.hits(), register)
        self.reindex()
        stats = self.shelve(self.hits(), register, pass_id='osint-later')
        self.assertEqual(len(register['entries']), len(PROPS))
        self.assertEqual(stats['duplicates'], len(PROPS))
        self.assertEqual(len([p for p in self.cache.rglob('*')
                              if p.is_file()]), len(PROPS))
        # Lines written before blob ids were recorded are matched by
        # their sha1 once the bytes are read.
        old = props.empty_register()
        self.shelve(self.hits(), old)
        for e in old['entries']:
            e.pop('blob')
        self.reindex()
        stats = self.shelve(self.hits(), old, pass_id='osint-later')
        self.assertEqual(len(old['entries']), len(PROPS))
        self.assertEqual(stats['duplicates'], len(PROPS))

    def test_the_register_only_grows(self):
        path = self.root / 'register.jsonl'
        register = props.empty_register()
        self.shelve(self.hits(), register)
        props.save_register(register, path)
        first_text = path.read_text()
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
        # On disk a save only appends lines: the old text stays a prefix.
        self.assertTrue(path.read_text().startswith(first_text))
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

    def test_two_runs_write_the_same_entries_apart_from_pass_id(self):
        one, two = props.empty_register(), props.empty_register()
        self.shelve(self.hits(), one, pass_id='osint-a',
                    cache=self.root / 'a')
        self.shelve(self.hits(), two, pass_id='osint-b',
                    cache=self.root / 'b')
        # pass_id names the run, so it differs; nothing else may.
        self.assertNotEqual(props.dump_register(one),
                            props.dump_register(two))
        for register in (one, two):
            for e in register['entries']:
                e.pop('pass_id')
        self.assertEqual(props.dump_register(one), props.dump_register(two))
        # A header line and one line per entry: JSON Lines.
        text = props.dump_register(one)
        self.assertEqual(len(text.splitlines()), 1 + len(PROPS))
        for line in text.splitlines():
            json.loads(line)

    def test_register_schema(self):
        register = props.empty_register()
        self.shelve(self.hits(), register)
        for e in register['entries']:
            self.assertEqual(props.validate_entry(e), [], e)
            self.assertEqual(set(e),
                             set(props.FIELDS) | set(props.OPTIONAL_FIELDS))
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
        # The file is JSON Lines, header first.
        first = props.REGISTER.read_text('utf-8').splitlines()[0]
        self.assertEqual(json.loads(first)['schema'], props.SCHEMA)

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
        path = self.root / 'register.jsonl'
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

    def test_to_slot_keeps_the_pass_rules(self):
        path = self.root / 'register.jsonl'
        register = props.empty_register()
        self.shelve(self.hits(), register)
        props.save_register(register, path)
        keys = {e['path']: e['key'] for e in register['entries']}
        commands = []
        # A weapon never goes into a neutral slot (TABOO 0.15 p. 4).
        with self.assertRaisesRegex(ValueError, 'hostile-for-neutral'):
            props.to_slot(keys['examples/weapons/sword.png'], 'DEF-056',
                          self.index, self.cache, work=self.root / 'b',
                          register_path=path, runner=commands.append)
        # A selection outline is on the shelf but not for the pipeline.
        with self.assertRaisesRegex(ValueError, 'outline-helper'):
            props.to_slot(keys['examples/unit-outline.png'], 'DEF-056',
                          self.index, self.cache, work=self.root / 'b',
                          register_path=path, runner=commands.append)
        self.assertEqual(commands, [])
        # No derivative of art whose licence forbids one.
        nd = props.empty_register()
        entry = dict(register['entries'][0], licence='CC-BY-NC-ND-4.0')
        nd['entries'].append(entry)
        nd_path = self.root / 'nd.jsonl'
        props.save_register(nd, nd_path)
        with self.assertRaisesRegex(ValueError, 'no derivative'):
            props.to_slot(entry['key'], 'DEF-056', self.index, self.cache,
                          work=self.root / 'b', register_path=nd_path,
                          runner=commands.append)
        self.assertEqual(commands, [])

    def test_intake_shelves_non_game_images_under_a_slot(self):
        out = self.root / 'intake'
        url = 'https://github.com/test/intake'
        make_repo(out, url, {'docs/screenshots/shore.png': b'shore',
                             'examples/altar.png': b'holy',
                             'sprites/items/fish.png': b'game'},
                  licence=True)
        clone = out / 'clones' / props.repo_dir(url)
        self.assertEqual(intake.collect_props(clone),
                         ['docs/screenshots/shore.png'])
        pending = [{'repo': url, 'commit': git(clone, 'rev-parse', 'HEAD'),
                    'license_file': 'LICENSE', 'path': rel,
                    'kind': 'image', 'hits': [], 'attribution': [],
                    'licence': 'MIT'}
                   for rel in intake.collect_props(clone)]
        path = self.root / 'register.jsonl'
        stats = intake.shelve(pending, out, 'DEF-056', self.cache, path)
        self.assertEqual(stats['taken'], {'screenshot': 1})
        entry = props.load_register(path)['entries'][0]
        self.assertEqual((entry['path'], entry['deficit_id']),
                         ('docs/screenshots/shore.png', 'DEF-056'))
        self.assertEqual((self.cache / cached(entry)).read_bytes(),
                         b'shore')

    def test_to_slot_restores_the_exact_bytes(self):
        path = self.root / 'register.jsonl'
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
