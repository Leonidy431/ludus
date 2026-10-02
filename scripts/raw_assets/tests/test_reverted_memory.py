"""The runner remembers what the eye check reverted (cycle 93 lesson).

The same chalice-like sadness kit was shipped three times because the
runner did not read its own journal; reverted_objects() reads it.
"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import osint_cycle  # noqa: E402


class RevertedMemoryTest(unittest.TestCase):
    def test_both_forms_of_the_journal_are_read(self):
        cursor = {'log': [
            {'reverted': [{'object': 'ant_sadness_5338273a79',
                           'reason': 'reads as a cup'}]},
            {'reverted': True,
             'reverted_reason': 'obj_stone_0123456789 (x): rhombus'},
            {'stage': 'done'},
        ]}
        self.assertEqual(osint_cycle.reverted_objects(cursor),
                         {'ant_sadness_5338273a79',
                          'obj_stone_0123456789'})

    def test_the_real_journal_remembers_the_chalice_kit(self):
        cursor = osint_cycle.load_cursor()
        self.assertIn('ant_sadness_5338273a79',
                      osint_cycle.reverted_objects(cursor))


if __name__ == '__main__':
    unittest.main()
