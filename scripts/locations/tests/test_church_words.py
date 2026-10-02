"""The generator's stop-list gives the shared corpus's verdict.

The same corpus is checked by godot/tests/test_church_words.gd and
tests/church-words.test.js, so the three matchers cannot part
(docs/decisions/STOPLIST_SINGLE_SOURCE_2026-10-02.md).
"""

import json
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HERE))

import church_words as C  # noqa: E402

CORPUS = HERE.parents[1] / 'tests' / 'fixtures' / 'church-words-corpus.json'


class ChurchWordsTest(unittest.TestCase):

    def setUp(self):
        with open(CORPUS, encoding='utf-8') as f:
            self.corpus = json.load(f)

    def test_web_copy_is_the_same_bytes(self):
        web = HERE.parents[1] / 'public' / 'ludus' / 'data'
        self.assertEqual((web / 'church-words.json').read_bytes(),
                         C.DATA.read_bytes())

    def test_must_flag(self):
        for text, word in self.corpus['must_flag']:
            self.assertEqual(C.find_church_word(text), word, text)

    def test_must_pass(self):
        for text, _why in self.corpus['must_pass']:
            self.assertEqual(C.find_church_word(text), '', text)


if __name__ == '__main__':
    unittest.main()
