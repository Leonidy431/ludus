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

    def test_mentor_nodes_teach_the_sign_in_the_teachers_tree(self):
        root = Path(__file__).resolve().parents[3]
        trees = json.loads((root / 'functions' / 'src' / 'data' /
                            'npc-dialogues-24.json').read_text('utf-8'))
        by_id = {t['npcId']: {n['id']: n for n in t['nodes']}
                 for t in trees}
        table = passion_fields.load()
        # Synonyms the meanings use for the passion's name.
        names = {'avarice': ('avarice', 'love of money'),
                 'lust': ('lust', 'fornication')}
        for passion, node_id in passion_fields.MENTOR_NODES.items():
            teacher = table[passion]['teacher']
            node = by_id[teacher].get(node_id)
            self.assertIsNotNone(node, f'{teacher}:{node_id}')
            self.assertTrue(node['meaning'].startswith('Discernment cue'),
                            node_id)
            self.assertTrue(any(w in node['meaning'].lower()
                                for w in names.get(passion, (passion,))),
                            f'{node_id} does not name {passion}')

    def test_shipped_kits_name_their_mentor_node(self):
        root = Path(__file__).resolve().parents[3]
        kits = root / 'public' / 'ludus' / 'art' / 'derived' / 'DEF-001'
        for name in ('ant_avarice_f14d9c7468', 'ant_vainglory_12f32bbb0f',
                     'ant_lust_fc98bcfdb9'):
            meta = json.loads((kits / f'{name}.json').read_text('utf-8'))
            self.assertEqual(passion_fields.missing(meta), [], name)
            teacher, node = meta['mentor_node'].split(':')
            self.assertEqual(teacher, meta['teacher_npc'])
            self.assertEqual(node,
                             passion_fields.MENTOR_NODES[meta['passion']])
            self.assertEqual(meta['status'], 'ok')
            self.assertEqual(len(meta['variants']), 12)


if __name__ == '__main__':
    unittest.main()
