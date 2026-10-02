"""The cracked jug of sadness: never a cup, measured like every antagonist.

Pass osint-2026-10-02T09:51:32Z shipped by the numbers a sadness kit
whose form sagged into a stemless cup that can read as a chalice; the
eye rejected it (CLAUDE.md TABOO 0.2 item 3, 0.35 rule 6).  The form of
sadness is now a clay jug of daily work fallen on its side, cracked,
its water running out (antagonist.shape_sadness).  These tests keep it
so, and keep the reworked kit inside the rules of TABOO 0.1 and 0.3.
"""

import json
import sys
import unittest
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import antagonist as ant  # noqa: E402
import form  # noqa: E402
import passion_fields  # noqa: E402
import sadness_vessel as sv  # noqa: E402
import transform  # noqa: E402

SHIPPED = (HERE.parents[2] / 'public' / 'ludus' / 'art' / 'derived' /
           'DEF-001')
NAME = 'ant_sadness_4bbd8e3f97'


def blue_icon():
    """A square blue icon like the crawl source: a recolour, so sadness."""
    img = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle([2, 2, 29, 29], fill=(60, 100, 200, 255))
    draw.rectangle([10, 8, 21, 20], fill=(30, 60, 150, 255))
    return img


def square_mask():
    mask = Image.new('L', (form.CANVAS, form.CANVAS), 0)
    ImageDraw.Draw(mask).rectangle([24, 24, 231, 231], fill=255)
    return mask


class JugFormTest(unittest.TestCase):

    def setUp(self):
        self.st = ant.SeedStream('0' * 40, 'passion:sadness')
        self.jug = ant.shape_sadness(square_mask(), self.st, 1)

    def test_it_lies_on_its_side(self):
        # A cup stands taller than or as tall as it is wide at the rim;
        # the fallen jug is wide and low, even with its puddle and the
        # drops under it in the box.
        x0, y0, x1, y1 = self.jug.getbbox()
        self.assertGreater((x1 - x0) / (y1 - y0), 1.1)

    def test_the_handle_is_a_loop(self):
        # The loop of the handle encloses a hole in the alpha.
        filled = form.fill_holes(self.jug)
        self.assertGreater(form.area(filled) - form.area(self.jug), 150)

    def test_far_from_the_old_cup(self):
        st = ant.SeedStream('0' * 40, 'passion:sadness')
        cup = ant.LEGACY_SHAPES['sadness-sag'](square_mask(), st, 1)
        inter = form.area(ImageChops.multiply(cup, self.jug))
        union = form.area(ImageChops.lighter(cup, self.jug))
        self.assertLess(inter / union, 0.6)

    def test_deterministic(self):
        st = ant.SeedStream('0' * 40, 'passion:sadness')
        again = ant.shape_sadness(square_mask(), st, 1)
        self.assertEqual(again.tobytes(), self.jug.tobytes())

    def test_runner_kit_from_a_blue_icon(self):
        item = {'repo': 'https://example.invalid/r', 'path': 'icon.png',
                'commit': '0' * 40, 'license': 'GPL',
                'license_file': 'LICENSE'}
        rec, _ = transform.process_piece(item, 0, blue_icon())
        self.assertEqual(rec['passion'], 'sadness')
        self.assertEqual(rec['status'], 'ok')
        self.assertTrue(all(v['shape_change'] >= 0.35
                            for v in rec['variants']))


class ShippedKitTest(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.meta = json.loads((SHIPPED / f'{NAME}.json').read_text('utf-8'))

    def test_twelve_variants_both_changes_over_threshold(self):
        m = self.meta
        self.assertEqual(m['status'], 'ok')
        self.assertEqual([v['slot'] for v in m['variants']],
                         [f'v{i:02d}' for i in range(1, 13)])
        for v in m['variants']:
            self.assertGreaterEqual(v['shape_change'], 0.35, v['slot'])
            self.assertGreaterEqual(v['colour_change'], 0.35, v['slot'])
        keys = {form.hitbox_key(v['hitbox']) for v in m['variants']}
        self.assertEqual(len(keys), 12)

    def test_same_seed_and_source_as_the_reverted_pass(self):
        m = self.meta
        self.assertEqual(m['seed'], ant.object_seed(
            sv.ITEM['repo'], sv.ITEM['path'], 0))
        self.assertEqual(m['reworks']['pass_id'],
                         'osint-2026-10-02T09:51:32Z')
        self.assertEqual(m['passion_form'], sv.FORM)

    def test_teaching_fields_and_mentor(self):
        m = self.meta
        self.assertEqual(passion_fields.missing(m), [])
        self.assertEqual(m['mentor_node'], 'theodora:cracked_jug')
        self.assertEqual(m['palette']['hue'], ant.PASSION_HUE['sadness'])

    def test_not_a_look_alike_of_a_shipped_passion(self):
        mine = form.alpha_mask(Image.open(SHIPPED / f'{NAME}_v01.png'))
        for f in sorted(SHIPPED.glob('ant_*_v01.png')):
            if f.name.startswith(NAME):
                continue
            other = form.alpha_mask(Image.open(f))
            self.assertLess(sv.mask_iou(mine, other), sv.SIBLING_IOU,
                            f.name)

    def test_files_match_their_meta(self):
        for v in self.meta['variants']:
            img = Image.open(SHIPPED / v['file'])
            self.assertEqual(img.mode, 'RGBA')
            box = form.hitbox(form.alpha_mask(img))
            self.assertEqual(box['area'], v['hitbox']['area'], v['file'])

    @unittest.skipUnless(sv.DEFAULT_SOURCE.exists(),
                         'crawl checkout not on this machine')
    def test_rebuild_matches_the_shipped_kit(self):
        rec, images = sv.build(sv.DEFAULT_SOURCE)
        self.assertEqual(rec['source']['sha1'],
                         self.meta['source']['sha1'])
        for v in rec['variants']:
            shipped = Image.open(SHIPPED / v['file']).convert('RGBA')
            self.assertEqual(images[v['file']].tobytes(), shipped.tobytes(),
                             v['file'])


if __name__ == '__main__':
    unittest.main()
