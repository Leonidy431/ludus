"""Track B of the 99 locations: things from the 99 cloned repos.

CLAUDE.md TABOO 0.013 p. 3 (a location's things are real and chosen;
from the repos only through the props store and the raw pipeline),
0.012 (the store takes everything but holy things, the stop-list and
repos without a licence), 0.1 (35 %, twelve variants, the eye check;
the D6 lesson: a neutral thing must stay recognisable).  These tests
hold the scripts to those promises with what is committed, so they run
without the index, the props cache or the headset.
"""

import itertools
import json
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import check_delta  # noqa: E402
import form  # noqa: E402
import location_items as li  # noqa: E402
import location_kit as lk  # noqa: E402
import neutral_procedural as npd  # noqa: E402

ROOT = HERE.parents[2]
DERIVED = ROOT / 'public' / 'ludus' / 'art' / 'derived'
GODOT = ROOT / 'godot'


def shipped_metas():
    out = []
    for path in sorted(DERIVED.glob('LOC-*/*.json')):
        meta = json.loads(path.read_text('utf-8'))
        out.append((path, meta))
    return out


class WhichThingsTest(unittest.TestCase):
    """Only neutral matter is looked up in raw material."""

    @classmethod
    def setUpClass(cls):
        cls.data = li.load_locations()
        cls.eligible, cls.refused = li.wished(cls.data)

    def test_every_wished_thing_is_decided(self):
        wished = {k for loc in self.data['locations']
                  for k in loc['wishlist']}
        self.assertEqual(set(self.eligible) | set(self.refused), wished)
        self.assertFalse(set(self.eligible) & set(self.refused))

    def test_holy_things_are_never_looked_up(self):
        for key, thing in self.data['things'].items():
            if thing['holy'] and key in self.refused:
                self.assertEqual(self.refused[key], 'holy-never-raw')
            if thing['holy']:
                self.assertNotIn(key, self.eligible, key)

    def test_documents_and_church_furniture_are_ours(self):
        for key in ('yarlyk', 'ledger', 'lectern', 'hand-candle'):
            self.assertIn(key, self.refused, key)

    def test_every_eligible_thing_has_a_material(self):
        for key, thing in self.eligible.items():
            self.assertIn(thing['material'], lk.MATERIAL_STATES, key)
            self.assertTrue(thing['words'], key)

    def test_flag_is_not_a_word_for_the_banner(self):
        words = [w for alt in self.eligible['banner']['words'] for w in alt]
        self.assertNotIn('flag', words)


class SearchTest(unittest.TestCase):

    def test_only_the_file_and_its_folder_speak(self):
        toks = li.tokens('data/tools/wares/basket/menu.png')
        self.assertIn('basket', toks)
        self.assertNotIn('tools', toks)

    def test_repository_words_are_not_the_thing(self):
        toks = li.tokens('res/forge/anvil.png', own={'forge'})
        self.assertNotIn('forge', toks)
        self.assertIn('anvil', toks)

    def test_plural_forms(self):
        self.assertIn('bench', li.tokens('x/benches.png'))
        self.assertIn('rope', li.tokens('x/ropes.png'))

    def test_never_taken(self):
        self.assertEqual(li.never('a/church_bell.png'), 'sacred-never-raw')
        self.assertEqual(li.never('a/pentagram.png'), 'dogma-stop-list')
        self.assertEqual(li.never('fonts/x.png'), 'font')
        self.assertIsNone(li.never('wares/basket/menu.png'))

    def test_not_a_source(self):
        cases = {
            'forge-gui/res/custom_card_pics/X.fullborder.jpg':
                'no-alpha-format',
            'data/flags/france.svg': 'national-flag',
            'data/core/images/units/dwarves/fighter.png': 'hostile-or-unit',
            'Textures/Objects/bread.rsi/inhand-left.png': 'worn-or-held',
            'crawl-ref/source/rltiles/dngn/wall/brick.png': 'terrain-tile',
            'crawl-ref/source/rltiles/gui/spells/x.png': 'ui-glyph',
        }
        for path, reason in cases.items():
            self.assertEqual(li.not_a_source(path), reason, path)
        self.assertIsNone(li.not_a_source('data/core/images/items/'
                                          'barrel.png'))

    def test_licence_urls(self):
        self.assertEqual(li.spdx_of_url(
            'https://creativecommons.org/licenses/by-nc-sa/3.0'),
            'CC-BY-NC-SA-3.0')
        self.assertEqual(li.spdx_of_url(
            'https://creativecommons.org/publicdomain/zero/1.0'), 'CC0-1.0')
        self.assertEqual(li.spdx_of_url(
            'https://creativecommons.org/licenses/by-sa/3.0'),
            'CC-BY-SA-3.0')


class PropsRegisterTest(unittest.TestCase):
    """docs/RAW_LOCATION_PROPS.json: append-only, licensed, never holy."""

    @classmethod
    def setUpClass(cls):
        cls.register = li.load_props()

    def test_fields_of_every_line(self):
        fields = {'key', 'repo', 'revision', 'path', 'licence', 'kind',
                  'place', 'things', 'location_ids', 'keywords', 'pass_id',
                  'sha1', 'bytes'}
        entries = self.register['entries']
        self.assertGreater(len(entries), 1000)
        keys = set()
        for e in entries:
            self.assertEqual(set(e), fields, e['path'])
            self.assertEqual(e['key'], li.prop_key(e['repo'], e['revision'],
                                                   e['path']))
            self.assertNotIn(e['key'], keys)
            keys.add(e['key'])
            self.assertEqual(len(e['sha1']), 40)
            self.assertIn(e['kind'], ('image', 'model'))
            self.assertTrue(e['location_ids'])
            self.assertIsNone(li.never(e['path']), e['path'])
            repo = self.register['repos'][e['repo']]
            self.assertTrue(repo['licence_file'], e['repo'])

    def test_register_only_grows(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'props.json'
            reg = li.load_props(path)
            reg['entries'].append({'key': 'p_1', 'path': 'a'})
            li.save_props(reg, path)
            reg = li.load_props(path)
            reg['entries'][0]['path'] = 'b'
            with self.assertRaises(RuntimeError):
                li.save_props(reg, path)
            reg = li.load_props(path)
            reg['entries'].append({'key': 'p_1', 'path': 'c'})
            with self.assertRaises(RuntimeError):
                li.save_props(reg, path)

    def test_cache_is_outside_the_repo(self):
        with self.assertRaises(ValueError):
            li.check_cache_outside(ROOT / 'build' / 'props')
        li.check_cache_outside(tempfile.gettempdir())


def drawn_jug():
    """A clay jug with a neck and a rim, drawn here (no raw file)."""
    img = Image.new('RGBA', (40, 56), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([2, 16, 38, 55], fill=(170, 100, 60, 255))
    d.rectangle([13, 2, 27, 20], fill=(150, 90, 50, 255))
    d.rectangle([10, 0, 30, 4], fill=(120, 70, 40, 255))
    return img


class KitTest(unittest.TestCase):
    """The variant family keeps a thing itself and measures honestly."""

    @classmethod
    def setUpClass(cls):
        cls.rec = lk.build_kit(drawn_jug(), 'water-jug', 'clay',
                               'test-seed')

    def test_twelve_with_both_measures(self):
        chosen = self.rec['chosen']
        self.assertEqual(len(chosen), lk.KIT_SIZE, self.rec['pool'])
        src = self.rec['source_canvas']
        src_mask = form.alpha_mask(src)
        for m in chosen:
            mask = form.alpha_mask(m['img'])
            # Measured again from the image, not read from the record.
            self.assertGreaterEqual(npd.distance(src_mask, mask), 0.35)
            self.assertGreaterEqual(form.colour_change(src, m['img'],
                                                       src_mask, mask), 0.35)
            self.assertGreaterEqual(m['visible'], lk.VISIBLE_MIN)

    def test_siblings_differ_and_hitboxes_too(self):
        masks = [form.alpha_mask(m['img']) for m in self.rec['chosen']]
        for a, b in itertools.combinations(masks, 2):
            self.assertGreaterEqual(npd.distance(a, b), 0.35)
        keys = {form.hitbox_key(form.hitbox(m)) for m in masks}
        self.assertEqual(len(keys), len(masks))

    def test_pose_alone_is_never_a_variant(self):
        for spec in lk.pool_specs('water-jug', 'clay', None):
            self.assertTrue(spec['ops'] or spec['group'], spec)

    def test_scale_is_one_for_all(self):
        # The source and every variant are drawn from the same thing at
        # the same scale: its longest side is SIDE pixels.
        obj = lk.normalise(drawn_jug())
        self.assertEqual(max(obj.size), lk.SIDE)

    def test_deterministic(self):
        again = lk.build_kit(drawn_jug(), 'water-jug', 'clay',
                             'test-seed')
        self.assertEqual([m['spec']['label'] for m in again['chosen']],
                         [m['spec']['label'] for m in self.rec['chosen']])
        self.assertEqual(again['chosen'][0]['img'].tobytes(),
                         self.rec['chosen'][0]['img'].tobytes())

    def test_iron_does_not_break_and_soft_does_not_lean(self):
        iron = lk.pool_specs('tongs', 'iron', None)
        self.assertFalse([s for s in iron if dict(s['ops']).get('break')])
        soft = lk.pool_specs('cloth', 'fibre', None)
        self.assertFalse([s for s in soft if s['pose'] in (12, -12, 24,
                                                           -24)])


class ShippedTest(unittest.TestCase):
    """What shipped is what the eye passed, measured and licensed."""

    def test_shipped_kits(self):
        metas = shipped_metas()
        self.assertTrue(metas)
        passed = {k for k, (v, _) in li.EYE.items() if v == 'ship'}
        for path, meta in metas:
            self.assertIn(meta['thing'], passed, path)
            self.assertEqual(meta['status'], 'ok')
            self.assertEqual(len(meta['variants']), 12)
            self.assertEqual(meta['eye']['verdict'], 'ship')
            self.assertTrue((ROOT / meta['eye']['sheet']).exists())
            self.assertNotIn('-NC', meta['license'])
            self.assertTrue(meta['raw_material'])
            masks = []
            for v in meta['variants']:
                self.assertGreaterEqual(v['shape_change'], 0.35)
                self.assertGreaterEqual(v['sibling_min'], 0.35)
                self.assertGreaterEqual(v['colour_change'], 0.35)
                masks.append(form.alpha_mask(
                    Image.open(path.parent / v['file'])))
            for a, b in itertools.combinations(masks, 2):
                self.assertGreaterEqual(npd.distance(a, b), 0.35)
            for thing in meta['serves']:
                self.assertNotIn(thing, li.EXCLUDED)

    def test_every_kit_has_a_verdict(self):
        self.assertEqual(set(li.EYE), set(li.PICKS))

    def test_delta_gate_passes(self):
        self.assertEqual(check_delta.check(DERIVED, 0.35), [])

    def test_location_items_for_the_headset(self):
        items = json.loads((GODOT / 'data' / 'location-items.json')
                           .read_text('utf-8'))
        data = li.load_locations()
        by_id = {loc['id']: loc for loc in data['locations']}
        copied = set()
        for loc_id, rows in items['locations'].items():
            loc = by_id[loc_id]
            for row in rows:
                self.assertIn(row['item'], loc['wishlist'])
                self.assertIsNone(data['things'][row['item']]['holy'])
                self.assertIn(row['item'],
                              items['kits'][row['kit']]['serves'])
                for f, setting in zip(row['files'], row['settings']):
                    rel = row['kit_dir'].replace('res://', '') + '/' + f
                    self.assertTrue((GODOT / rel).exists(), rel)
                    copied.add(rel)
                    if loc['shell']['type'] in li.INDOOR:
                        self.assertEqual(setting, 'any', (loc_id, f))
                    self.assertEqual(len(set(row['files'])),
                                     len(row['files']))
        # Nothing else of the kits is in the build.
        on_disk = {str(p.relative_to(GODOT)) for p in
                   GODOT.glob('art/derived/LOC-*/*.png')}
        self.assertEqual(on_disk, copied)

    def test_headset_boxes_and_metres(self):
        # The headset stands each drawing by the box and the metres in
        # its file, not by the kit's meta (not in the APK): the file must
        # be current, and each box must be the drawn part of its canvas.
        text = li.godot_items(li.shipped_metas_on_disk(),
                              li.load_locations())
        self.assertEqual(text, (GODOT / 'data' / 'location-items.json')
                         .read_text('utf-8'))
        items = json.loads(text)
        data = li.load_locations()
        for rows in items['locations'].values():
            for row in rows:
                side = items['kits'][row['kit']]['side_px']
                self.assertAlmostEqual(
                    row['px_m'] * side, max(data['things'][row['item']]
                                            ['size_m']), places=3)
                for f, box in zip(row['files'], row['bboxes']):
                    rel = row['kit_dir'].replace('res://', '') + '/' + f
                    alpha = Image.open(GODOT / rel).convert('RGBA') \
                        .getchannel('A').point(lambda a: 255 if a > 16
                                               else 0)
                    self.assertEqual(list(alpha.getbbox()), box, rel)

    def test_queue_is_deterministic_and_fits_rooms(self):
        meta = shipped_metas()[0][1]
        a = li.variant_queue(meta, 'porch-court', 'bench', 'room')
        b = li.variant_queue(meta, 'porch-court', 'bench', 'room')
        self.assertEqual(a, b)
        self.assertTrue(all(v['setting'] == 'any' for v in a))


@unittest.skipUnless(
    all(__import__('importlib').util.find_spec(m)
        for m in ('numpy', 'trimesh')), 'numpy and trimesh are not here')
class MeshTest(unittest.TestCase):
    """The three-view measure of a mesh change."""

    def test_measure(self):
        import location_mesh as lm
        import trimesh
        box = lm.rest(trimesh.creation.box(extents=(0.4, 0.8, 0.3)))
        win = lm.window(box)
        same = lm.distance(lm.views([box], win), lm.views([box], win))
        self.assertEqual(same, 0.0)
        lying = lm.turn(box, 90)
        moved = lm.distance(lm.views([box], win), lm.views([lying], win))
        self.assertGreater(moved, 0.2)

    def test_mesh_pool_has_no_pose_only_variant(self):
        import location_mesh as lm
        for spec in lm.pool_specs('karas', 'clay'):
            self.assertTrue(spec['ops'] or spec['group'], spec)


if __name__ == '__main__':
    unittest.main()
