"""Merge the raw runner's append-only journals without losing a line.

Two writers append to the same journals: session passes reach main
through feature branches, and the hourly CI pass commits to the branch
raw-osint/auto.  Both append at the end of the same files, so a plain
text merge always conflicts there.  The workflow used to swallow that
with `git merge ... || true`; the JSON files then held conflict markers,
the next pass died on json.load, and the journal stayed split across two
branches (eight scheduled runs failed that way on 2026-09-30).

This module is a git merge driver.  It is declared in .gitattributes for
the three journals and wired by the workflow (and by anyone merging by
hand) with:

    git config merge.ludus-journal.driver \
        "python3 scripts/raw_assets/journal_merge.py %O %A %B %P"

Git passes the common ancestor, our version, their version and the
path; the union is written over our version.  Nothing is dropped: every
log entry, keyword, code candidate and register line of both sides
stays.  When one entry was changed differently on the two sides, the
driver refuses (exit 1) and git reports a conflict, because choosing one
silently would rewrite the journal (TABOO 0.25 p. 5).
"""

import json
import sys
from pathlib import Path


class JournalConflict(ValueError):
    """The same journal entry was changed differently on both sides."""


def _read(path):
    path = Path(path)
    return path.read_text('utf-8') if path.exists() else ''


def _json(text, default):
    return json.loads(text) if text.strip() else default


def _covers(big, small):
    # An entry that only gained fields (a later "reverted" note on a
    # pass, say) still carries every field of the older copy unchanged.
    return all(k in big and big[k] == v for k, v in small.items())


def _union_dicts(ours, theirs, ident):
    """Union two lists of dicts by identity, ours first.

    Entries of the same identity must be equal, or one must only add
    fields to the other; anything else is a real conflict.
    """
    out, where = [], {}
    for item in ours:
        where[ident(item)] = len(out)
        out.append(item)
    for item in theirs:
        key = ident(item)
        if key not in where:
            where[key] = len(out)
            out.append(item)
            continue
        mine = out[where[key]]
        if mine == item or _covers(mine, item):
            continue
        if _covers(item, mine):
            out[where[key]] = item
            continue
        raise JournalConflict(f'entry {key!r} differs on the two sides')
    return out


def _merge_words(ours, theirs):
    if ours[:len(theirs)] == theirs:
        return ours
    if theirs[:len(ours)] == ours:
        return theirs
    return ours + [w for w in theirs if w not in ours]


def merge_next(base, ours, theirs):
    """The rotation cursor furthest along, counting a wrap as ahead.

    The cursor counts deficits from where the last pass started; after
    a full circle it restarts near zero.  A side whose value fell below
    the ancestor's has wrapped and is therefore further along.
    """
    if base is None:
        return max(ours, theirs)

    def lap(value):
        return (value < base, value)
    return max(ours, theirs, key=lap)


def merge_cursor(base_text, ours_text, theirs_text):
    base = _json(base_text, {})
    ours = _json(ours_text, {})
    theirs = _json(theirs_text, {})
    out = dict(ours)
    for key, value in theirs.items():
        if key not in out:
            out[key] = value
        elif out[key] != value and base.get(key) == out[key]:
            # Only their side changed this field.
            out[key] = value
    out['log'] = _union_dicts(
        ours.get('log', []), theirs.get('log', []),
        lambda e: e.get('time') or json.dumps(e, sort_keys=True))
    # Not re-sorted by time: the log already holds entries whose time
    # stamps are out of order (the 04:00-05:00 cursor notes of
    # 2026-09-30 were written after later passes), and moving them would
    # rewrite the journal.  Our entries keep their places; theirs follow.
    words = {}
    for side in (ours.get('keywords', {}), theirs.get('keywords', {})):
        for def_id, added in side.items():
            words[def_id] = _merge_words(words.get(def_id, []), added)
    if words:
        out['keywords'] = words
    if 'next' in ours and 'next' in theirs:
        out['next'] = merge_next(base.get('next'), ours['next'],
                                 theirs['next'])
    return json.dumps(out, ensure_ascii=False, indent=1)


def merge_candidates(_base_text, ours_text, theirs_text):
    merged = _union_dicts(
        _json(ours_text, []), _json(theirs_text, []),
        lambda c: (c['repo'], c['path'], c.get('slot')))
    return json.dumps(merged, ensure_ascii=False, indent=1)


def _register_lines(text):
    head, rows = None, []
    for line in text.splitlines():
        if not line.strip():
            continue
        row = json.loads(line)
        if 'schema' in row and head is None:
            head = line
            continue
        rows.append((line, row))
    return head, rows


def _register_ident(row):
    if 'withdrawn' in row:
        return ('withdrawn', row['withdrawn'], row.get('reason'),
                row.get('date'))
    return ('entry', row['key'])


def merge_register(_base_text, ours_text, theirs_text):
    """JSON Lines register: our lines in place, their new lines after."""
    head_o, ours = _register_lines(ours_text)
    head_t, theirs = _register_lines(theirs_text)
    seen = {}
    out = [head_o or head_t]
    for line, row in ours + theirs:
        key = _register_ident(row)
        if key in seen:
            if seen[key] != row:
                raise JournalConflict(f'register line {key!r} differs on '
                                      'the two sides')
            continue
        seen[key] = row
        out.append(line)
    return '\n'.join(line for line in out if line) + '\n'


MERGERS = {
    'RAW_OSINT_CURSOR.json': merge_cursor,
    'RAW_CODE_CANDIDATES.json': merge_candidates,
    'RAW_PROPS_REGISTER.jsonl': merge_register,
}


def merge(base, ours, theirs, name):
    """Merge three versions of the journal called name; return text."""
    merger = MERGERS.get(Path(name).name)
    if merger is None:
        raise JournalConflict(f'{name} is not a raw runner journal')
    return merger(base, ours, theirs)


def main(argv):
    if len(argv) != 5:
        print('usage: journal_merge.py BASE OURS THEIRS PATH',
              file=sys.stderr)
        return 2
    base, ours, theirs, name = argv[1:]
    try:
        text = merge(_read(base), _read(ours), _read(theirs), name)
    except (JournalConflict, ValueError, KeyError) as exc:
        print(f'journal_merge: {name}: {exc}', file=sys.stderr)
        return 1
    # Written exactly as the runner writes each file, so a merge adds no
    # stray change of its own.
    Path(ours).write_text(text, 'utf-8')
    print(f'journal_merge: {name}: union written', file=sys.stderr)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
