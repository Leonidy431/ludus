"""The 144 insight branches pass the chorus's checks without Godot
(scripts/story/check_branches.py; CLAUDE.md TABOO 0.021, 0.025, 0.027).

    python3 -m unittest scripts/tests/test_insight_branches.py
"""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'story'))
import check_branches as cb  # noqa: E402


class InsightBranches(unittest.TestCase):

    def setUp(self):
        self.args = [cb.load(cb.BRANCHES), cb.load(cb.VARIANTS),
                     cb.load(cb.INSIGHTS), cb.load(cb.BEATS)]

    def test_the_data_passes(self):
        self.assertEqual(cb.check(*self.args), [])

    def test_a_branch_that_does_not_converge_fails(self):
        b = copy.deepcopy(self.args[0])
        b['nodes'][5]['converges_to'] = 'title'
        self.assertTrue(cb.check(b, *self.args[1:]))

    def test_the_holy_place_is_never_a_branch(self):
        b = copy.deepcopy(self.args[0])
        b['nodes'][0]['branch_ru'] += ' у кайрака'
        self.assertTrue(cb.check(b, *self.args[1:]))

    def test_no_bonus_for_faith(self):
        b = copy.deepcopy(self.args[0])
        b['nodes'][0]['world']['dialogue_bonus']['attribute'] = 'faith'
        self.assertTrue(cb.check(b, *self.args[1:]))

    def test_long_subtitle_fails(self):
        b = copy.deepcopy(self.args[0])
        n = b['nodes'][0]
        n['subtitles_ru'] = ['а' * 141]
        n['voiceover_ru'] = n['subtitles_ru'][0]
        self.assertTrue(cb.check(b, *self.args[1:]))


if __name__ == '__main__':
    unittest.main()
