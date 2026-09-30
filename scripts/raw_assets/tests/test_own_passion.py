"""The lust kit is our own procedural drawing, measured like raw material.

Chorus decision docs/CHORUS_LUST_2026-09-30.md: lust never comes from
the 99 repositories and never shows a body.  The drawing must still
meet every rule of the antagonist protocol (CLAUDE.md TABOO 0.1, 0.3):
twelve variants, each at least 35 % away from the base form by alpha,
pairwise distinct hitboxes, deterministic, with the rule-13 fields.
"""

import json
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import antagonist as ant  # noqa: E402
import form  # noqa: E402
import own_passion  # noqa: E402
import passion_fields  # noqa: E402

SHIPPED = (HERE.parents[2] / 'public' / 'ludus' / 'art' / 'derived' /
           'DEF-001')


class OwnPassionTest(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.record, cls.images = own_passion.build()

    def test_twelve_variants_each_reshaped_from_the_base(self):
        rec = self.record
        self.assertEqual(rec['status'], 'ok')
        self.assertEqual([v['slot'] for v in rec['variants']],
                         [f'v{i:02d}' for i in range(1, 13)])
        base = form.alpha_mask(own_passion.base_flame())
        for v in rec['variants']:
            self.assertGreaterEqual(v['shape_change'], 0.35, v['slot'])
            # Measured again here, from the images, not from the meta.
            mask = form.alpha_mask(self.images[v['file']])
            self.assertGreaterEqual(form.shape_delta(base, mask), 0.35,
                                    v['slot'])

    def test_hitboxes_differ_pairwise(self):
        keys = [form.hitbox_key(v['hitbox'])
                for v in self.record['variants']]
        self.assertEqual(len(set(keys)), 12)

    def test_no_third_party_material(self):
        rec = self.record
        self.assertFalse(rec['raw_material'])
        self.assertEqual(rec['origin'], 'own-procedural-drawing')
        self.assertNotIn('github.com', rec['repo'])
        self.assertEqual(rec['passion'], 'lust')

    def test_cold_palette_complements_the_warm_base(self):
        rec = self.record
        self.assertEqual(rec['palette']['basis'], 'complement')
        self.assertTrue(180 <= rec['palette']['hue'] <= 260,
                        rec['palette']['hue'])

    def test_deterministic(self):
        again, images = own_passion.build()
        self.assertEqual([v['shape_change'] for v in again['variants']],
                         [v['shape_change']
                          for v in self.record['variants']])
        first = self.record['variants'][0]['file']
        self.assertEqual(images[first].tobytes(),
                         self.images[first].tobytes())

    def test_shipped_kit_matches_the_generator(self):
        meta = json.loads((SHIPPED / f'{self.record["name"]}.json')
                          .read_text('utf-8'))
        self.assertEqual(passion_fields.missing(meta), [])
        self.assertEqual([v['shape_change'] for v in meta['variants']],
                         [v['shape_change']
                          for v in self.record['variants']])

    def test_vainglory_wears_no_ring(self):
        # TABOO 0.35 rule 7: a ring round a figure reads as a halo.  The
        # vainglory form is a fan over the upper half.  The old ring
        # (radius 0.85 of the form) passed below the sides of the form,
        # about (68, 170) and (188, 170); nothing new may lie there.
        from PIL import Image, ImageDraw
        mask = Image.new('L', (form.CANVAS, form.CANVAS), 0)
        ImageDraw.Draw(mask).rectangle([48, 48, 208, 208], fill=255)
        for s in (1, 2, 3):
            out = ant.shape_vainglory(mask, ant.SeedStream('x', 'v'), s)
            self.assertIsNone(out.crop((58, 150, 78, 190)).getbbox(), s)
            self.assertIsNone(out.crop((178, 150, 198, 190)).getbbox(), s)


if __name__ == '__main__':
    unittest.main()
