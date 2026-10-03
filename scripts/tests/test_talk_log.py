"""Tests of the talk log collector (scripts/logs/talk_log.py)."""

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "logs"))
import talk_log as tl  # noqa: E402


def write(recs):
    """A transcript file from records; returns its path."""
    f = tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False,
                                    encoding="utf-8")
    for r in recs:
        f.write(json.dumps(r, ensure_ascii=False) + "\n")
    f.close()
    return f.name


class TalkLogTest(unittest.TestCase):
    """Every word of the operator is kept once; the harness's is not."""

    def test_midturn_messages_and_client_comments_are_kept(self):
        path = write([
            {"type": "user", "timestamp": "2026-10-03T10:00:00Z",
             "message": {"content": "первое слово"}},
            {"type": "queue-operation", "operation": "enqueue",
             "timestamp": "2026-10-03T10:01:00Z",
             "content": "сказано на ходу"},
            {"type": "user", "timestamp": "2026-10-03T10:02:00Z",
             "message": {"content": "<!-- attach -->\n> цитата\n\nответ"}},
        ])
        days, _ = tl.messages(path)
        texts = [t for _, t in days["2026-10-03"]]
        self.assertEqual(len(texts), 3)
        self.assertIn("сказано на ходу", texts)
        self.assertTrue(texts[2].startswith("> цитата"))

    def test_harness_text_is_not_a_message(self):
        path = write([
            {"type": "queue-operation", "operation": "enqueue",
             "timestamp": "2026-10-03T10:00:00Z",
             "content": "<task-notification>x</task-notification>"},
            {"type": "user", "timestamp": "2026-10-03T10:01:00Z",
             "message": {"content": "<system-reminder>y</system-reminder>"}},
            {"type": "user", "timestamp": "2026-10-03T10:02:00Z",
             "message": {"content": "Stop hook feedback: commit"}},
            {"type": "queue-operation", "operation": "enqueue",
             "timestamp": "2026-10-03T10:03:00Z",
             "content": "<agent-message from=\"a1\">report</agent-message>"},
        ])
        days, _ = tl.messages(path)
        self.assertEqual(days.get("2026-10-03", []), [])

    def test_the_same_words_are_logged_once_and_masked(self):
        path = write([
            {"type": "queue-operation", "operation": "enqueue",
             "timestamp": "2026-10-03T10:00:00Z",
             "content": "пиши на me@mail.ru"},
            {"type": "user", "timestamp": "2026-10-03T10:00:05Z",
             "message": {"content": "пиши на me@mail.ru"}},
        ])
        days, _ = tl.messages(path)
        got = days["2026-10-03"]
        self.assertEqual(len(got), 1)
        self.assertNotIn("me@mail.ru", got[0][1])


if __name__ == "__main__":
    unittest.main()
