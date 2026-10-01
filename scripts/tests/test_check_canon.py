"""Negative tests for scripts/check_canon.py.

A checker that only ever says OK proves nothing, so each rule is shown
failing on a made-up source that breaks it.
"""

import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import check_canon  # noqa: E402

CANON = check_canon.Canon(json.loads(
    check_canon.CANON.read_text(encoding='utf-8')))


def errors(source):
    return CANON.check(source)[0]


class CanonTest(unittest.TestCase):
    def test_real_sources_pass(self):
        self.assertEqual(errors('Mt 25:35, 40; Heb 13:2'), [])
        self.assertEqual(errors('Psalm 45:11 (LXX; 46:10 in Hebrew '
                                'numbering)'), [])
        self.assertEqual(errors('2 Kings (4 Kingdoms LXX) 6:16'), [])
        self.assertEqual(errors('Ladder, steps 16-17 (avarice)'), [])
        self.assertEqual(errors('Gregory the Great, Pastoral Rule, part 1, '
                                'chapter 1; part 3, prologue'), [])

    def test_unknown_work_fails(self):
        self.assertTrue(any('not in canon' in e for e in errors(
            'Abba Invented, Sayings of the Cloud 3')))

    def test_chapter_out_of_range_fails(self):
        self.assertTrue(errors('Jude 3:1; Mark 17:1'))
        self.assertTrue(any('31' in e for e in errors(
            'The Ladder of Divine Ascent, step 31')))

    def test_wrong_topic_fails(self):
        # Step 22 is on vainglory, not on anger.
        self.assertTrue(errors('The Ladder, step 22 (on anger)'))
        # Praktikos 7 is gluttony, not pride.
        self.assertTrue(errors('Evagrius, Praktikos 7 (pride)'))

    def test_unlisted_date_fails(self):
        self.assertTrue(errors('Synaxarion, 3 March'))
        self.assertEqual(errors('Synaxarion, 28 August'), [])

    def test_witness_alone_fails(self):
        self.assertTrue(any('no authority' in e for e in errors(
            'William of Rubruck, Itinerarium')))
        self.assertEqual(errors('Rom 13:7; William of Rubruck, '
                                'Itinerarium'), [])

    def test_whole_project_passes(self):
        self.assertEqual(check_canon.main(), 0)


if __name__ == '__main__':
    unittest.main()
