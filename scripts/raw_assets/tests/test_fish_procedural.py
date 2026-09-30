"""DEF-056: the fish of Issyk-Kul are the project's own drawing.

The raw passes over the 99 repositories never gave a recognisable fish
(a jellyfish, a fiend and pikemen came for "pike"; later fish-like
pieces failed the real-object profile), so the slot follows D6 and is
drawn by the project.  These tests hold the drawing to its promises:
real species of the lake register only, twelve variants that each fit
the fish profile, every pair at least 35 % apart by alpha (measured
again from the pixels), distinct hitboxes, nothing third-party,
nothing random, and the shipped kits pass the delta gate.
"""

import itertools
import json
import sys
import unittest
from pathlib import Path

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

    def test_twelve_variants_that_fit_a_fish(self):
        for sp, (rec, images) in self.kits.items():
            self.assertEqual(rec['status'], 'ok', sp)
            self.assertEqual([v['slot'] for v in rec['variants']],
                             [f'v{i:02d}' for i in range(1, 13)])
            for v in rec['variants']:
                mask = form.alpha_mask(images[v['file']])
                ok, stats = reference.fits('DEF-056', mask)
                self.assertTrue(ok, (sp, v['slot'], stats))

    def test_every_pair_differs_by_the_threshold(self):
        for sp, (rec, images) in self.kits.items():
            masks = [form.alpha_mask(images[v['file']])
                     for v in rec['variants']]
            for a, b in itertools.combinations(masks, 2):
                # Measured again from the images, not read from meta.
                self.assertGreaterEqual(npd.distance(a, b), 0.35, sp)
            for v in rec['variants']:
                self.assertGreaterEqual(v['shape_change'], 0.35)
                self.assertEqual(v['shape_basis'], 'nearest-sibling')

    def test_hitboxes_differ_pairwise(self):
        for rec, _ in self.kits.values():
            keys = {form.hitbox_key(v['hitbox']) for v in rec['variants']}
            self.assertEqual(len(keys), 12)

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
                # Small tilts only, and never a mirror image: every fish
                # faces left (TABOO 0.3 rule 35).
                self.assertLessEqual(abs(v['params']['tilt']), 13)

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

    def test_shipped_kits_pass_the_gate(self):
        if not DERIVED.is_dir():
            self.skipTest('DEF-056 not shipped')
        self.assertEqual(check_delta.check(DERIVED, 0.35), [])
        metas = list(DERIVED.glob('own_*.json'))
        self.assertTrue(metas)
        for meta in metas:
            rec = json.loads(meta.read_text('utf-8'))
            self.assertIn(rec['thing'], fp.SPECIES)
            self.assertEqual(rec['status'], 'ok')
            self.assertEqual(len(rec['variants']), 12)

    def test_no_headset_copy_without_a_scene(self):
        # TABOO 0.011: the dive shows 3D fish; no Godot scene loads the
        # fish sprites yet, so they must not ride in the APK.
        self.assertFalse(GODOT.exists())


if __name__ == '__main__':
    unittest.main()
