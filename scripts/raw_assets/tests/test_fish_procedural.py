"""DEF-056: the fish of Issyk-Kul are the project's own drawing.

The raw passes over the 99 repositories never gave a recognisable fish,
so the slot follows D6 and is drawn by the project.  These tests hold
the drawing to its promises: real species of the lake register only,
every variant fits the fish profile, every pair at least 35 % apart
measured on silhouettes normalised for place and scale (a fish moved or
resized is the same form: review of 2026-09-30), distinct hitboxes,
nothing third-party, nothing random, and no kit short of twelve ships.
"""

import contextlib
import io
import itertools
import json
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import check_delta  # noqa: E402
import fish_procedural as fp  # noqa: E402
import form  # noqa: E402
import neutral_procedural as npd  # noqa: E402
import reference  # noqa: E402

ROOT = HERE.parents[2]
DERIVED = ROOT / 'public' / 'ludus' / 'art' / 'derived' / 'DEF-056'
GODOT = ROOT / 'godot' / 'art' / 'derived' / 'DEF-056'
FISH = json.loads((ROOT / 'public' / 'ludus' / 'data' /
                   'issyk-kul-fish.json').read_text('utf-8'))


class KitTest(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        # A carp with barbels and a long dorsal fin, and a stone loach
        # that lies on the bottom: the two ends of the genus shapes.
        cls.kits = {s: fp.build(s) for s in ('sazan', 'gubach')}

    def test_variants_fit_a_fish_and_the_count_is_honest(self):
        for sp, (rec, images) in self.kits.items():
            n = len(rec['variants'])
            self.assertEqual([v['slot'] for v in rec['variants']],
                             [f'v{i:02d}' for i in range(1, n + 1)])
            # The count is what the forms give; never padded to 12.
            self.assertEqual(rec['status'],
                             'ok' if n == 12 else 'shortfall')
            self.assertEqual(rec['shortfall'], 12 - n)
            self.assertLessEqual(n, 12)
            for v in rec['variants']:
                mask = form.alpha_mask(images[v['file']])
                ok, stats = reference.fits('DEF-056', mask)
                self.assertTrue(ok, (sp, v['slot'], stats))

    def test_every_pair_differs_in_form_not_place(self):
        for sp, (rec, images) in self.kits.items():
            masks = [form.alpha_mask(images[v['file']])
                     for v in rec['variants']]
            for a, b in itertools.combinations(masks, 2):
                # Measured again from the images, normalised for place
                # and scale, not read from meta.
                self.assertGreaterEqual(fp.form_distance(a, b), 0.35, sp)
            for v in rec['variants']:
                self.assertGreaterEqual(v['shape_change'], 0.35)
                self.assertEqual(v['shape_basis'],
                                 'nearest-sibling-normalised')

    def test_place_and_size_are_not_form(self):
        # The first kits counted a fish moved down the canvas, or made
        # 0.8x smaller, as a new variant about 100 % apart.
        img = fp.draw_one('sudak', 236, 128, 128)
        low = img.transform(img.size, Image.AFFINE, (1, 0, 0, 0, 1, -40))
        small = fp.draw_one('sudak', 188, 128, 128)
        a, b, c = (form.alpha_mask(x) for x in (img, low, small))
        self.assertGreater(npd.distance(a, b), 0.35)
        self.assertLess(fp.form_distance(a, b), 0.02)
        self.assertLess(fp.form_distance(a, c), 0.1)
        # A real bend of the body does count.
        bent = form.alpha_mask(fp.draw_one(
            'sudak', 236, 128, 128, {'bend': 'bow', 'amp': 0.2}))
        self.assertGreater(fp.form_distance(a, bent), 0.35)

    def test_size_and_place_are_engine_parameters(self):
        for rec, _ in self.kits.values():
            self.assertIn('age_lengths_px', rec['engine'])
            for v in rec['variants']:
                self.assertNotIn('length', v['params'])
                self.assertNotIn('tilt', v['params'])

    def test_hitboxes_differ_pairwise(self):
        for rec, _ in self.kits.values():
            keys = {form.hitbox_key(v['hitbox']) for v in rec['variants']}
            self.assertEqual(len(keys), len(rec['variants']))

    def test_real_species_and_own_drawing(self):
        ids = {f['id'] for f in FISH['fish']}
        for sp, (rec, _) in self.kits.items():
            self.assertIn(sp, ids)
            self.assertEqual(rec['register']['category'], 'fish')
            self.assertEqual(rec['species']['latin'],
                             fp.fish_row(sp)['latin'])
            self.assertFalse(rec['raw_material'])
            self.assertEqual(rec['origin'], 'own-procedural-drawing')
            self.assertNotIn('github.com', json.dumps(rec))
            self.assertIn('ichthyologist', rec['morphology']['note'])

    def test_poses_come_from_register_states(self):
        for sp, (rec, _) in self.kits.items():
            poses, states = fp.poses_of(sp)
            for st in states:
                self.assertIn(fp.POSE.get(st, 'single'), poses)
            for v in rec['variants']:
                self.assertIn(v['state'], poses)
                self.assertIn(v['params']['form']['bend'], fp.BENDS)

    def test_every_species_is_drawn_to_its_genus(self):
        for sp in fp.SPECIES:
            self.assertIn(sp, fp.MORPHOLOGY)
            npd.register_row(sp)
            fp.fish_row(sp)
        # Barbels where the genus has them: carp, marinka, loach.
        self.assertEqual(fp.MORPHOLOGY['sazan']['barbels'], 2)
        self.assertEqual(fp.MORPHOLOGY['gubach']['barbels'], 3)
        self.assertEqual(fp.MORPHOLOGY['chebachok']['barbels'], 0)
        # Trout and whitefish carry the adipose fin.
        self.assertTrue(fp.MORPHOLOGY['ishkhan']['adipose'])
        self.assertTrue(fp.MORPHOLOGY['sig']['adipose'])

    def test_deterministic(self):
        rec, images = fp.build('gubach')
        first, first_images = self.kits['gubach']
        self.assertEqual([v['params'] for v in rec['variants']],
                         [v['params'] for v in first['variants']])
        f = rec['variants'][0]['file']
        self.assertEqual(images[f].tobytes(), first_images[f].tobytes())


class ShippedTest(unittest.TestCase):

    def test_no_short_kit_ships(self):
        # TABOO 0.1: never fewer than 12 variants.  A kit ships only at
        # 12/12; until then DEF-056 stays open and nothing is in public.
        if not DERIVED.is_dir():
            return
        self.assertEqual(check_delta.check(DERIVED, 0.35), [])
        for meta in DERIVED.glob('own_*.json'):
            rec = json.loads(meta.read_text('utf-8'))
            self.assertIn(rec['thing'], fp.SPECIES)
            self.assertEqual(rec['status'], 'ok')
            self.assertEqual(len(rec['variants']), 12)
            self.assertEqual(rec['shape_basis'],
                             'nearest-sibling-normalised')

    def test_main_ships_nothing_short(self):
        with tempfile.TemporaryDirectory() as tmp:
            out, ship = Path(tmp) / 'out', Path(tmp) / 'ship'
            with contextlib.redirect_stdout(io.StringIO()):
                fp.main(['--out', str(out), '--ship', str(ship),
                         '--only', 'gubach'])
            rec, _ = fp.build('gubach')
            shipped = list((ship / 'DEF-056').glob('*')) \
                if (ship / 'DEF-056').exists() else []
            if rec['status'] == 'ok':
                self.assertTrue(shipped)
            else:
                self.assertEqual(shipped, [])

    def test_headset_copy_is_one_atlas_per_shipped_kit(self):
        # TABOO 0.011: the headset carries one atlas per 12/12 kit (one
        # MultiMesh, one draw call per school) and the index the dive
        # reads; never a short kit, never the 12 loose files.
        index = json.loads((ROOT / 'godot' / 'data' /
                            'fish-drawings.json').read_text('utf-8'))
        web = json.loads((ROOT / 'public' / 'ludus' / 'data' /
                          'fish-drawings.json').read_text('utf-8'))
        self.assertEqual(index, web)
        shipped = {k['kit'] for k in index['kits']}
        metas = {m.stem for m in DERIVED.glob('own_*.json')}
        self.assertEqual(shipped, metas)
        pngs = sorted(p.name for p in GODOT.glob('*.png'))
        self.assertEqual(pngs, sorted(f'{k}_atlas.png' for k in shipped))
        for kit in index['kits']:
            self.assertEqual(len(kit['files']), 12)
            self.assertEqual(len(kit['fish_px']), 12)
            atlas = Image.open(GODOT / f'{kit["kit"]}_atlas.png')
            self.assertEqual(atlas.size, (fp.COLS * fp.CELL,
                                          fp.ROWS * fp.CELL))
            rec = json.loads((DERIVED / f'{kit["kit"]}.json')
                             .read_text('utf-8'))
            self.assertEqual(kit['fish_px'],
                             [v['params']['fish_px']
                              for v in rec['variants']])
        for short in index['short']:
            self.assertLess(short['variants'], 12)
            self.assertNotIn(short['id'], {k['id'] for k in
                                           index['kits']})

    def test_new_views_are_real_and_capped(self):
        # r3: the turn in perspective, the view from below or above and
        # schools of 2-5 are real views; a kit keeps at most three of
        # each, so the side view where a species is told apart leads.
        rec, _ = fp.build('gubach')
        states = [v['state'] for v in rec['variants']]
        self.assertLessEqual(sum(s in ('below', 'above')
                                 for s in states), 3)
        self.assertLessEqual(states.count('turning'), 3)
        self.assertNotIn('school', fp.poses_of('gubach')[0])
        self.assertIn('school', fp.poses_of('chebachok')[0])
        # A bottom fish is seen from above; open water also from below.
        self.assertIn('above', fp.poses_of('gubach')[0])
        self.assertNotIn('below', fp.poses_of('gubach')[0])
        # A turn is a taper, not a resize: it counts after normalising.
        img = fp.draw_one('sazan', fp.LENGTH, 128, 128)
        turned = fp.turn(img, 50, 128 - fp.LENGTH / 2, fp.LENGTH, 128)
        self.assertGreater(fp.form_distance(form.alpha_mask(img),
                                            form.alpha_mask(turned)),
                           0.1)


if __name__ == '__main__':
    unittest.main()
