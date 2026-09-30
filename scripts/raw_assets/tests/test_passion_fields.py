"""Rule 13 (CLAUDE.md TABOO 0.35): an antagonist ships with its teaching.

The gate must fail an antagonist meta that lacks its virtue, Ladder
step, source or discernment cue, and enrich() must fill them from the
same passions data the game uses on the road.
"""

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import check_delta  # noqa: E402
import passion_fields  # noqa: E402


class PassionFieldsTest(unittest.TestCase):

    def test_enrich_fills_every_required_field(self):
        meta = passion_fields.enrich({'name': 'ant_pride_x', 'passion':
                                      'pride'})
        self.assertEqual(passion_fields.missing(meta), [])
        self.assertEqual(meta['opposing_virtue'], 'Humility')

    def test_gate_fails_an_antagonist_without_its_teaching(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'ant_anger_1_v01.png').write_bytes(b'x')
            meta = {'name': 'ant_anger_1', 'passion': 'anger',
                    'variants': [{'file': 'ant_anger_1_v01.png',
                                  'shape_change': 0.8}]}
            (root / 'ant_anger_1.json').write_text(json.dumps(meta))
            problems = check_delta.check(root, 0.35)
            self.assertTrue(any('rule 13' in p for p in problems))
            passion_fields.enrich(meta)
            (root / 'ant_anger_1.json').write_text(json.dumps(meta))
            self.assertEqual(check_delta.check(root, 0.35), [])


if __name__ == '__main__':
    unittest.main()
