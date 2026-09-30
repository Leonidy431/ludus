"""D6: the neutral things of the lake are the project's own drawing.

Operator, 2026-09-30 ("все вопросы да"): after the raw passes turned
stones into vases, the neutral slots DEF-057..059 are drawn by the
project.  These tests hold the drawing to its promises: things of the
lake register only, twelve variants that each still fit the real-object
profile of the slot, every pair at least 35 % apart by alpha, distinct
hitboxes, nothing third-party, nothing random, and the shipped kits
pass the delta gate.
"""

import itertools
import json
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import check_delta  # noqa: E402
import form  # noqa: E402
import neutral_procedural as npd  # noqa: E402
import reference  # noqa: E402

ROOT = HERE.parents[2]
DERIVED = ROOT / 'public' / 'ludus' / 'art' / 'derived'
GODOT = ROOT / 'godot' / 'art' / 'derived'


class KitTest(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        # One rigid thing and one plant: the two drawing families.
        cls.kits = {t: npd.build(slot, t) for slot, t in
                    (('DEF-057', 'boulder'), ('DEF-058', 'trostnik'))}

    def test_twelve_variants_that_fit_the_real_object(self):
        for thing, (rec, images) in self.kits.items():
            self.assertEqual(rec['status'], 'ok', thing)
            self.assertEqual([v['slot'] for v in rec['variants']],
                             [f'v{i:02d}' for i in range(1, 13)])
            for v in rec['variants']:
                mask = form.alpha_mask(images[v['file']])
                ok, _ = reference.fits(rec['slot'], mask)
                self.assertTrue(ok, (thing, v['slot']))

    def test_every_pair_differs_by_the_threshold(self):
        for thing, (rec, images) in self.kits.items():
            masks = [form.alpha_mask(images[v['file']])
                     for v in rec['variants']]
            for a, b in itertools.combinations(masks, 2):
                # Measured again from the images, not read from meta.
                self.assertGreaterEqual(npd.distance(a, b), 0.35, thing)
            for v in rec['variants']:
                self.assertGreaterEqual(v['shape_change'], 0.35)
                self.assertEqual(v['shape_basis'], 'nearest-sibling')

    def test_hitboxes_differ_pairwise(self):
        for rec, _ in self.kits.values():
            keys = {form.hitbox_key(v['hitbox']) for v in rec['variants']}
            self.assertEqual(len(keys), 12)

    def test_own_drawing_from_the_register(self):
        for thing, (rec, _) in self.kits.items():
            self.assertFalse(rec['raw_material'])
            self.assertEqual(rec['origin'], 'own-procedural-drawing')
            self.assertNotIn('github.com', json.dumps(rec))
            self.assertEqual(rec['register']['id'], thing)
            self.assertIn(rec['register']['category'],
                          ('shelf', 'plant', 'find'))

    def test_deterministic(self):
        rec, images = npd.build('DEF-058', 'trostnik')
        first, _ = self.kits['trostnik']
        self.assertEqual([v['params'] for v in rec['variants']],
                         [v['params'] for v in first['variants']])
        f = rec['variants'][0]['file']
        self.assertEqual(images[f].tobytes(),
                         self.kits['trostnik'][1][f].tobytes())

    def test_distance_is_symmetric_and_zero_on_itself(self):
        rec, images = self.kits['boulder']
        a = form.alpha_mask(images[rec['variants'][0]['file']])
        b = form.alpha_mask(images[rec['variants'][1]['file']])
        self.assertEqual(npd.distance(a, a), 0.0)
        self.assertAlmostEqual(npd.distance(a, b), npd.distance(b, a))


class ShippedTest(unittest.TestCase):

    def test_shipped_kits_pass_the_gate(self):
        for slot, things in npd.KITS.items():
            dest = DERIVED / slot
            if not dest.is_dir():
                continue
            self.assertEqual(check_delta.check(dest, 0.35), [], slot)
            for meta in dest.glob('own_*.json'):
                rec = json.loads(meta.read_text('utf-8'))
                self.assertIn(rec['thing'], things)
                self.assertEqual(len(rec['variants']), 12)
                for v in rec['variants']:
                    # The headset copy is the same picture.
                    twin = GODOT / slot / v['file']
                    if twin.exists():
                        self.assertEqual(twin.read_bytes(),
                                         (dest / v['file']).read_bytes())

    def test_gate_refuses_an_own_drawing_with_a_source(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'own_x.json').write_text(json.dumps({
                'name': 'own_x', 'origin': 'own-procedural-drawing',
                'raw_material': False, 'repo': 'https://github.com/a/b',
                'variants': []}), 'utf-8')
            problems = check_delta.check(root, 0.35)
            self.assertTrue(any('third-party' in p for p in problems))
            self.assertTrue(any('shape_basis' in p for p in problems))


if __name__ == '__main__':
    unittest.main()
