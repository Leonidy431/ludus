"""The neutral family: age and pose, measured, recognisable, repeatable.

The lake pass of 2026-09-30 was reverted because antagonist variants
made stones look like vases.  These tests hold the replacement to its
promises: only real operations per kind of thing, twelve recipes, every
accepted variant at least 35 % XOR/union and still fitting the real
object profile, refusals carry their numbers, and nothing is random.
"""

import sys
import unittest
from pathlib import Path

from PIL import Image, ImageOps

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import antagonist as ant  # noqa: E402
import neutral_variants as nv  # noqa: E402
import reference  # noqa: E402
import transform  # noqa: E402
from form import alpha_mask, hitbox_key, shape_delta  # noqa: E402

SEED = ant.object_seed('own-drawing', 'test_fish', 0)


def recolour(img, rgb):
    """Same alpha, another colour: form must not change with it."""
    out = Image.new('RGBA', img.size, rgb + (255,))
    out.putalpha(img.getchannel('A'))
    return out


class RecipeTest(unittest.TestCase):
    def test_twelve_recipes_per_kind_of_thing(self):
        for cat in nv.CATEGORY_OPS:
            recipes = nv.recipes(cat, SEED)
            self.assertEqual(len(recipes), 12, cat)
            names = [nv.recipe_name(r) for r in recipes]
            self.assertEqual(len(set(names)), 12, cat)

    def test_only_real_operations_for_each_thing(self):
        ops = {cat: {op for op, _ in pairs}
               for cat, pairs in nv.CATEGORY_OPS.items()}
        self.assertNotIn('bend', ops['shelf'])
        self.assertNotIn('bend', ops['find'])
        self.assertNotIn('crack', ops['fish'])
        self.assertNotIn('overgrowth', ops['fish'])
        self.assertNotIn('crack', ops['plant'])
        every = set().union(*ops.values())
        self.assertEqual(every, {'overgrowth', 'chip', 'silt', 'crack',
                                 'bend', 'turn'})

    def test_recipes_are_deterministic_and_seeded(self):
        self.assertEqual(nv.recipes('shelf', SEED), nv.recipes('shelf',
                                                               SEED))
        other = ant.object_seed('own-drawing', 'test_fish', 1)
        self.assertNotEqual(nv.recipes('shelf', SEED)[6:],
                            nv.recipes('shelf', other)[6:])

    def test_pairs_join_two_different_operations(self):
        for cat in nv.CATEGORY_OPS:
            for recipe in nv.recipes(cat, SEED):
                self.assertEqual(len({op for op, _ in recipe}), len(recipe))


class OperationTest(unittest.TestCase):
    def setUp(self):
        self.fish = nv.test_fish()
        self.src = alpha_mask(self.fish)

    def test_poses_reach_the_threshold_on_a_fish(self):
        # A steep turn stops looking like a fish (aspect under 1.8), so
        # the claim is that some rung of the ladder satisfies both.
        for op in ('bend', 'turn'):
            good = []
            for s in nv.LADDER:
                st = ant.SeedStream(SEED, op)
                mask = alpha_mask(nv.OPS[op](self.fish, 'fish', st, s, 1))
                good.append(shape_delta(self.src, mask) >= 0.35
                            and reference.fits('DEF-056', mask)[0])
            self.assertTrue(any(good), op)

    def test_turn_is_never_a_mirror(self):
        st = ant.SeedStream(SEED, 'turn')
        out = alpha_mask(nv.op_turn(self.fish, 'fish', st, 0.6, 1))
        mirror = ImageOps.mirror(self.src)
        self.assertGreater(shape_delta(mirror, out), 0.1)

    def test_form_ignores_colour(self):
        dark = recolour(self.fish, (5, 5, 5))
        light = recolour(self.fish, (250, 250, 250))
        for op in nv.OPS:
            a = nv.OPS[op](dark, 'shelf', ant.SeedStream(SEED, op), 0.6, 1)
            b = nv.OPS[op](light, 'shelf', ant.SeedStream(SEED, op), 0.6,
                           1)
            self.assertEqual(alpha_mask(a).tobytes(),
                             alpha_mask(b).tobytes(), op)


class BuildTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.canvas = transform.place_on_canvas(nv.test_fish())
        cls.result = nv.build(cls.canvas, 'DEF-056', SEED)

    def test_accepted_variants_pass_both_rules(self):
        variants, _, images = self.result
        self.assertGreaterEqual(len(variants), 6)
        src = alpha_mask(self.canvas)
        for v in variants:
            self.assertGreaterEqual(v['shape_change'], 0.35, v['slot'])
            self.assertTrue(v['fits_reference'], v['slot'])
            # The stored number is the measurement of the stored image.
            mask = alpha_mask(images[v['slot']])
            self.assertAlmostEqual(shape_delta(src, mask),
                                   v['shape_change'], places=3)

    def test_hitboxes_are_pairwise_distinct(self):
        variants, _, _ = self.result
        keys = [hitbox_key(v['hitbox']) for v in variants]
        self.assertEqual(len(keys), len(set(keys)))

    def test_refusals_are_reported_with_numbers(self):
        variants, rejected, _ = self.result
        self.assertEqual(len(variants) + len(rejected), 12)
        for r in rejected:
            self.assertIn(r['reason'], (
                'below-threshold-while-recognisable',
                'unlike-real-object-at-every-strength'))
            if r['reason'].startswith('below'):
                self.assertLess(r['shape_change'], 0.35)

    def test_build_is_repeatable(self):
        again = nv.build(self.canvas, 'DEF-056', SEED)
        self.assertEqual([v['shape_change'] for v in again[0]],
                         [v['shape_change'] for v in self.result[0]])

    def test_transform_uses_the_neutral_family_for_lake_slots(self):
        item = {'repo': 'own-drawing', 'path': 'test_fish.png',
                'commit': '0' * 40, 'license': 'own', 'slot': 'DEF-056',
                'neutral': True}
        record, _ = transform.process_piece(item, 0, nv.test_fish())
        self.assertEqual(record['variant_family'], 'neutral-age-pose')
        self.assertIsNone(record['passion'])
        for v in record['variants']:
            self.assertGreaterEqual(v['shape_change'], 0.35)
            self.assertTrue(v['analytics_id'].startswith(
                'ludus.variant.none.'))


if __name__ == '__main__':
    unittest.main()
