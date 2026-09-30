"""The raw runner's journals merge by union, never by text.

Two writers append to the same journals (session passes through main,
the hourly CI pass on raw-osint/auto).  On 2026-09-30 a text merge of
the two left conflict markers in docs/RAW_OSINT_CURSOR.json and
docs/RAW_CODE_CANDIDATES.json and eight scheduled passes died on
json.load.  These tests hold the merge driver to the journal rule: no
entry of either side is lost, none is rewritten, and a real clash is
refused instead of guessed.
"""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HERE))

import journal_merge  # noqa: E402


def cursor(nxt, log, keywords):
    return json.dumps({'next': nxt, 'log': log, 'keywords': keywords},
                      ensure_ascii=False, indent=1)


def git(cwd, *args):
    return subprocess.run(
        ['git', '-c', 'user.name=t', '-c', 'user.email=t@t', *args],
        cwd=cwd, capture_output=True, text=True)


class JournalMergeTest(unittest.TestCase):
    BASE_LOG = [{'time': '2026-09-30T12:51:11+00:00', 'deficits': []}]

    def test_cursor_keeps_every_pass_of_both_sides(self):
        base = cursor(12, self.BASE_LOG, {'DEF-035': ['a']})
        ours = cursor(18, self.BASE_LOG + [
            {'time': '2026-09-30T13:31:00+00:00', 'pass_id': 'p1'},
            {'time': '2026-09-30T13:38:01+00:00', 'pass_id': 'p2'}],
            {'DEF-035': ['a', 'b'], 'DEF-040': ['x', 'y']})
        theirs = cursor(15, self.BASE_LOG + [
            {'time': '2026-09-30T13:51:18+00:00', 'deficits': ['DEF-035']}],
            {'DEF-035': ['a', 'b'], 'DEF-040': ['x']})
        merged = json.loads(journal_merge.merge_cursor(base, ours, theirs))
        # Ours in place, theirs after: the log is never reordered.
        self.assertEqual(merged['log'][:3], json.loads(ours)['log'])
        self.assertEqual(merged['log'][3]['time'],
                         '2026-09-30T13:51:18+00:00')
        self.assertEqual(len(merged['log']), 4)
        # The cursor furthest along the rotation wins.
        self.assertEqual(merged['next'], 18)
        self.assertEqual(merged['keywords'],
                         {'DEF-035': ['a', 'b'], 'DEF-040': ['x', 'y']})

    def test_a_later_note_on_one_side_is_kept(self):
        base = cursor(1, self.BASE_LOG, {})
        noted = [{**self.BASE_LOG[0], 'reverted': 'why'}]
        merged = json.loads(journal_merge.merge_cursor(
            base, cursor(1, self.BASE_LOG, {}), cursor(1, noted, {})))
        self.assertEqual(merged['log'], noted)

    def test_a_real_clash_is_refused(self):
        base = cursor(1, self.BASE_LOG, {})
        one = [{**self.BASE_LOG[0], 'accepted_objects': 1}]
        two = [{**self.BASE_LOG[0], 'accepted_objects': 2}]
        with self.assertRaises(journal_merge.JournalConflict):
            journal_merge.merge_cursor(base, cursor(1, one, {}),
                                       cursor(1, two, {}))

    def test_a_wrapped_cursor_is_ahead(self):
        self.assertEqual(journal_merge.merge_next(18, 21, 2), 2)
        self.assertEqual(journal_merge.merge_next(18, 21, 24), 24)
        self.assertEqual(journal_merge.merge_next(None, 3, 5), 5)

    def test_candidates_union(self):
        row = {'repo': 'r', 'path': 'a.c', 'slot': 'DEF-024'}
        mine = {'repo': 'r', 'path': 'b.c', 'slot': 'DEF-024'}
        yours = {'repo': 'r', 'path': 'c.c', 'slot': 'DEF-028'}
        # The same file seen at another upstream revision is one line.
        again = {**mine, 'commit': 'b' * 40}
        merged = json.loads(journal_merge.merge_candidates(
            json.dumps([row]), json.dumps([row, mine]),
            json.dumps([row, yours, again])))
        self.assertEqual(merged, [row, mine, yours])

    def test_register_lines_stay_in_place(self):
        head = json.dumps({'schema': 's', 'rule': 'r'})
        a, b, c = ({'key': k, 'x': 1} for k in ('p_a', 'p_b', 'p_c'))
        w = {'withdrawn': 'p_a', 'reason': 'holy', 'date': 'd'}
        base = '\n'.join([head, json.dumps(a)]) + '\n'
        ours = '\n'.join([head, json.dumps(a), json.dumps(b)]) + '\n'
        theirs = '\n'.join([head, json.dumps(a), json.dumps(c),
                            json.dumps(w)]) + '\n'
        merged = journal_merge.merge_register(base, ours, theirs)
        self.assertTrue(merged.startswith(ours))
        rows = [json.loads(line) for line in merged.splitlines()]
        self.assertEqual(rows[1:], [a, b, c, w])
        clash = '\n'.join([head, json.dumps({'key': 'p_b', 'x': 2})])
        with self.assertRaises(journal_merge.JournalConflict):
            journal_merge.merge_register(base, ours, clash)

    def test_git_uses_the_driver(self):
        # A real merge of two branches that both appended: without the
        # driver git reports a conflict, with it the union is clean.
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            (repo / 'docs').mkdir()
            (repo / '.gitattributes').write_text(
                'docs/RAW_OSINT_CURSOR.json merge=ludus-journal\n')
            path = repo / 'docs' / 'RAW_OSINT_CURSOR.json'
            path.write_text(cursor(0, self.BASE_LOG, {}))
            git(repo, 'init', '-q', '-b', 'main')
            git(repo, 'add', '-A')
            git(repo, 'commit', '-q', '-m', 'base')
            git(repo, 'checkout', '-q', '-b', 'auto')
            path.write_text(cursor(3, self.BASE_LOG + [
                {'time': '2026-09-30T14:17:00+00:00'}], {}))
            git(repo, 'commit', '-q', '-am', 'auto pass')
            git(repo, 'checkout', '-q', 'main')
            path.write_text(cursor(3, self.BASE_LOG + [
                {'time': '2026-09-30T13:38:00+00:00'}], {}))
            git(repo, 'commit', '-q', '-am', 'session pass')
            git(repo, 'checkout', '-q', 'auto')
            plain = git(repo, 'merge', '--no-edit', 'main')
            self.assertNotEqual(plain.returncode, 0)
            git(repo, 'merge', '--abort')
            driver = (f'{sys.executable} {HERE / "journal_merge.py"} '
                      '%O %A %B %P')
            done = git(repo, '-c', f'merge.ludus-journal.driver={driver}',
                       'merge', '--no-edit', 'main')
            self.assertEqual(done.returncode, 0, done.stdout + done.stderr)
            merged = json.loads(path.read_text())
            self.assertEqual(len(merged['log']), 3)


if __name__ == '__main__':
    unittest.main()
