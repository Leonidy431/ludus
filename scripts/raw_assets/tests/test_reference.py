"""The runner selects by the real object and grows its keys by twelve.

Operator, 2026-09-30: "смени подход к выбору, изучи на реальных
объектах ... каждый проход добавляй 12 ключевых слов".
"""

import sys
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import osint_cycle  # noqa: E402
import reference  # noqa: E402


def mask(draw):
    img = Image.new('L', (256, 256), 0)
    draw(ImageDraw.Draw(img))
    return img


class ReferenceTest(unittest.TestCase):
    def test_a_fish_fits_and_a_diamond_does_not(self):
        fish = mask(lambda d: d.ellipse((40, 110, 220, 150), fill=255))
        diamond = mask(lambda d: d.polygon(
            [(128, 40), (200, 128), (128, 216), (56, 128)], fill=255))
        self.assertTrue(reference.fits('DEF-056', fish)[0])
        self.assertFalse(reference.fits('DEF-056', diamond)[0])

    def test_a_pebble_fits_the_stone_slot_and_a_ladder_does_not(self):
        pebble = mask(lambda d: d.ellipse((60, 90, 200, 170), fill=255))

        def ladder(d):
            d.rectangle((100, 20, 106, 236), fill=255)
            d.rectangle((150, 20, 156, 236), fill=255)
            for y in range(30, 230, 30):
                d.rectangle((100, y, 156, y + 4), fill=255)
        diamond = mask(lambda d: d.polygon(
            [(128, 60), (210, 128), (128, 196), (46, 128)], fill=255))
        self.assertTrue(reference.fits('DEF-057', pebble)[0])
        self.assertFalse(reference.fits('DEF-057', diamond)[0])
        self.assertFalse(reference.fits('DEF-057', mask(ladder))[0])

    def test_natural_palette_is_not_a_passion_palette(self):
        pal = reference.natural_palette('DEF-057')
        self.assertTrue(pal['basis'].startswith('natural:'))
        # Natural things are muted: no stop is a saturated colour.
        for _, (r, g, b) in pal['stops']:
            self.assertLess(max(r, g, b) - min(r, g, b), 140)


class KeywordLadderTest(unittest.TestCase):
    def test_each_pass_adds_twelve_new_words(self):
        deficit = {'id': 'DEF-056', 'keywords': ['fish', 'carp']}
        cursor = {}
        first = osint_cycle.grow_keywords(deficit, cursor, '/nonexistent',
                                          {'image'})
        second = osint_cycle.grow_keywords(deficit, cursor, '/nonexistent',
                                           {'image'})
        self.assertEqual(len(first), 12)
        self.assertEqual(len(second), 12)
        self.assertFalse(set(first) & set(second))
        self.assertEqual(first[:3], ['dace', 'loach', 'minnow'])

    def test_neighbour_words_skip_sacred_and_hostile(self):
        hits = [{'path': 'art/water/lake/perch_church.png'},
                {'path': 'art/water/lake/enemy/perch.png'}]
        words = osint_cycle.neighbour_words(hits, set())
        self.assertIn('lake', words)
        self.assertNotIn('church', words)
        self.assertNotIn('enemy', words)


if __name__ == '__main__':
    unittest.main()


class OutlineTest(unittest.TestCase):
    def test_engine_outline_frames_are_refused(self):
        # Round 4 of 2026-09-30 turned wesnoth selection outlines into
        # near-empty antagonist strokes; they never enter the pipeline.
        path = ('data/internal/Rogue_Mage/images/units/rogue-mage/'
                'shadow-lord+female-defend2-outline.png')
        self.assertEqual(osint_cycle.allowed(path), 'outline-helper')
        self.assertIsNone(osint_cycle.allowed(
            'data/core/images/units/x/shadow-lord-defend2.png'))


class NoProfileTest(unittest.TestCase):
    def test_neutral_slot_without_profile_is_refused(self):
        import transform
        img = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
        ImageDraw.Draw(img).ellipse((4, 8, 28, 24), fill=(40, 120, 40, 255))
        item = {'repo': 'r', 'path': 'grass.png', 'commit': 'c',
                'license': 'MIT', 'neutral': True, 'slot': 'DEF-049'}
        record, _ = transform.process_piece(item, 0, img)
        self.assertEqual(record['status'], 'unlike-real-object')
        self.assertEqual(record['reference']['reason'],
                         'no-real-object-profile')
