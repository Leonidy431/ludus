"""Tests of the chunked corpus puller (TABOO 0.033), without a network."""

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "raw_assets"))
import corpus_chunks as cc  # noqa: E402


class CorpusChunksTest(unittest.TestCase):
    """A chunk adds its own key and never replaces another."""

    def test_summary_keeps_every_chunk(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "corpus-summary.json"
            cc.merge_summary(path, "chunk-000", {"bytes": 5, "repos": ["a"]})
            cc.merge_summary(path, "chunk-001", {"bytes": 7, "repos": ["b"]})
            data = json.loads(path.read_text("utf-8"))
            self.assertEqual(sorted(data["chunks"]),
                             ["chunk-000", "chunk-001"])
            self.assertEqual(data["total_bytes"], 12)

    def test_a_chunk_cannot_be_written_twice(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "corpus-summary.json"
            cc.merge_summary(path, "chunk-000", {"bytes": 1, "repos": []})
            with self.assertRaises(SystemExit):
                cc.merge_summary(path, "chunk-000", {"bytes": 2,
                                                     "repos": []})

    def test_wanted_takes_licence_and_types_but_never_the_holy(self):
        self.assertTrue(cc.wanted("LICENSE", cc.TYPES))
        self.assertTrue(cc.wanted("art/lamp.png", cc.TYPES))
        self.assertFalse(cc.wanted("art/church_door.png", cc.TYPES))
        self.assertFalse(cc.wanted("art/cross.svg", cc.TYPES))
        self.assertFalse(cc.wanted("src/main.py", cc.TYPES))
        self.assertTrue(cc.wanted("src/main.py",
                                  cc.TYPES + cc.CODE_TYPES))
        self.assertFalse(cc.wanted("docs/LICENSE", cc.TYPES))

    def test_clean_drops_big_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            (d / "small.png").write_bytes(b"x" * 10)
            (d / "big.png").write_bytes(b"x" * (cc.MAX_FILE_MB * (1 << 20)
                                                + 1))
            kept = cc.clean(d)
            self.assertEqual([p for p, _ in kept], ["small.png"])
            self.assertFalse((d / "big.png").exists())


if __name__ == "__main__":
    unittest.main()
