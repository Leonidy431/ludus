"""Neutral raw-material slots take the thing itself, never antagonists.

Round 1 of 2026-09-30 filled the fish slot with a jellyfish, a fiend and
pikemen (the key "pike" matched "pikeman") and turned them into
passions.  These tests keep the three fixes in place.
"""

import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import osint_cycle  # noqa: E402


def whole_word(key):
    return re.compile(r'(^|[^a-z])' + re.escape(key) + r'(e?s)?([^a-z]|$)')


class NeutralSlotTest(unittest.TestCase):
    def test_keys_match_whole_words_only(self):
        pike = whole_word('pike')
        self.assertTrue(pike.search('fish/pike.png'))
        self.assertTrue(pike.search('ocean/pikes_big.png'))
        self.assertFalse(pike.search('soldier/pikeman.png'))
        self.assertFalse(
            whole_word("fish").search("beast/ocean/jellyfish.png"))

    def test_hostile_sprites_never_fill_a_neutral_slot(self):
        for path in ('sprites/enemy/beast/fish.png',
                     'enemy/fiend/spikedravager.png',
                     'humanoid/human/soldier/pikeman.png'):
            self.assertTrue(osint_cycle.HOSTILE.search(path), path)
        self.assertFalse(osint_cycle.HOSTILE.search('tiles/water/fish.png'))

    def test_only_the_passion_slot_makes_antagonists(self):
        self.assertEqual(osint_cycle.ANTAGONIST_SLOTS, {'DEF-001'})

    def test_rotation_holds_only_useful_fills(self):
        fills = {r['fill'] for r in osint_cycle.rotation()}
        self.assertLessEqual(fills, {'raw-material', 'code'})


if __name__ == '__main__':
    unittest.main()
