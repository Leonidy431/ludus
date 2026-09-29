"""Check every teaching source against the closed patristic canon.

CLAUDE.md TABOO 0.35 rule 18 and TABOO 0.37: a teaching line names its
source, and the source must come from the hand-curated canon in
data/patristic-canon.json.  This script reads:
  - the 24 chorus trees (functions/src/data/npc-dialogues-24.json),
  - the eight passions (public/ludus/data/passions.json),
  - the confession questions (public/ludus/ludus-confession.js; read as
    text, because that module must stay free of imports),
and fails the build when a cited segment
  - matches no Scripture book and no canon work,
  - cites a chapter, step or book outside the work's bounds,
  - cites a Synaxarion or Menologion date the canon does not list,
  - names a topic ("on vainglory") that the cited step or chapter does
    not treat, or a passion whose Praktikos chapter is another thought,
  - leaves a node with only witnesses (a travel account, a painter's
    manual) and no authority behind it.
Verses are not checked, only chapters; the report says so, so nobody
reads a green run as more than it proves.

Usage: python3 scripts/check_canon.py
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CANON = ROOT / 'data' / 'patristic-canon.json'
TREES = ROOT / 'functions' / 'src' / 'data' / 'npc-dialogues-24.json'
PASSIONS = ROOT / 'public' / 'ludus' / 'data' / 'passions.json'
CONFESSION = ROOT / 'public' / 'ludus' / 'ludus-confession.js'

AUTHORITY = {'scripture', 'father', 'council', 'canon-law', 'catechism',
             'hagiography', 'synaxarion'}
MONTHS = {m: i + 1 for i, m in enumerate(
    ['january', 'february', 'march', 'april', 'may', 'june', 'july',
     'august', 'september', 'october', 'november', 'december'])}
ROMAN = {'I': 1, 'V': 5, 'X': 10}


def to_int(token):
    """Read an Arabic or a small Roman numeral (book IV, XVIII)."""
    if token.isdigit():
        return int(token)
    total = 0
    for i, ch in enumerate(token):
        value = ROMAN[ch]
        nxt = ROMAN.get(token[i + 1]) if i + 1 < len(token) else 0
        total += -value if nxt and nxt > value else value
    return total


def split_segments(source):
    """Split on ';' outside parentheses: '(LXX; 46:10)' stays whole."""
    parts, depth, cur = [], 0, ''
    for ch in source:
        depth += (ch == '(') - (ch == ')')
        if ch == ';' and depth == 0:
            parts.append(cur)
            cur = ''
        else:
            cur += ch
    parts.append(cur)
    return [p.strip().rstrip('.').strip() for p in parts if p.strip()]


class Canon:
    def __init__(self, data):
        self.works = data['works']
        for work in self.works:
            work['_re'] = re.compile(work['match'])
        self.dates = set(data['synaxarion'])
        books = []
        for book in data['scripture']:
            for alias in book['aliases']:
                books.append((alias, book))
        # Longest alias first, so '1 John' wins over 'John'.
        books.sort(key=lambda b: -len(b[0]))
        alt = '|'.join(re.escape(a) for a, _ in books)
        self.book_re = re.compile(
            r'^(?:cf\.\s*)?(?:St\s+)?(' + alt + r')\.?\s+(\d+)(?=[:\s,.]|$)')
        self.books = dict(books)

    def scripture(self, segment):
        """Match 'Mt 25:35, 40' or '2 Kings (4 Kingdoms LXX) 6:16'."""
        bare = re.sub(r'\s*\([^)]*\)', '', segment).strip()
        m = self.book_re.match(bare)
        if not m:
            return None
        book = self.books[m.group(1)]
        errors = []
        chapters = [int(m.group(2))]
        # Later chapter refs in the same segment: 'Exodus 3:2 and 20:21'.
        chapters += [int(c) for c in re.findall(
            r'(?:,|and)\s*(\d+):\d+', bare[m.end():])]
        for ch in chapters:
            if not 1 <= ch <= book['chapters']:
                errors.append(f'{book["name"]} has {book["chapters"]} '
                              f'chapters, cited {ch}')
        return {'kind': 'scripture', 'errors': errors}

    def date_ok(self, segment):
        m = re.search(r'(\d{1,2})\s+([A-Z][a-z]+)|([A-Z][a-z]+)\s+(\d{1,2})',
                      segment)
        if not m:
            return 'no date'
        day = m.group(1) or m.group(4)
        month = MONTHS.get((m.group(2) or m.group(3)).lower())
        if not month:
            return 'no date'
        key = f'{month:02d}-{int(day):02d}'
        return None if key in self.dates else f'date {key} not in canon'

    def work(self, segment):
        for work in self.works:
            if not work['_re'].search(segment):
                continue
            errors = []
            loc = work.get('locator')
            cited = []
            if loc:
                for m in re.finditer(loc['re'], segment):
                    lo = to_int(m.group(1))
                    hi = to_int(m.group(2)) if m.lastindex > 1 \
                        and m.group(2) else lo
                    cited += list(range(lo, hi + 1)) if hi >= lo else [lo]
                for n in cited:
                    if not loc['min'] <= n <= loc['max']:
                        errors.append(f'{work["title"]}: {n} outside '
                                      f'{loc["min"]}-{loc["max"]}')
            if work.get('date'):
                problem = self.date_ok(segment)
                if problem:
                    errors.append(f'{work["title"]}: {problem}')
            topics = work.get('topics')
            if topics and cited:
                errors += topic_errors(work, topics, cited, segment)
            return {'kind': work['kind'], 'id': work['id'],
                    'cited': cited, 'errors': errors}
        return None

    def _work_head(self, segment):
        """The segment up to the end of the canon title it names."""
        for work in self.works:
            m = work['_re'].search(segment)
            if m:
                return segment[:m.end()]
        return ''

    def check(self, source):
        """Return (errors, kinds) for one source string."""
        errors, kinds = [], set()
        prev = ''
        for seg in split_segments(source):
            hit = self.scripture(seg) or self.work(seg)
            if not hit and prev:
                # 'Pastoral Rule, part 1; part 3' and 'Maximos, Ad
                # Thalassium 22; Ambigua' continue the previous work or
                # author, so retry with that prefix.
                author = prev.split(',')[0]
                for prefix in (self._work_head(prev), author):
                    if prefix:
                        hit = self.work(f'{prefix}, {seg}')
                        if hit:
                            break
            if not hit:
                errors.append(f'not in canon: "{seg}"')
                continue
            kinds.add(hit['kind'])
            errors += hit['errors']
            prev = seg
        if kinds and not kinds & AUTHORITY:
            errors.append('only witnesses, no authority behind the line')
        return errors, kinds


def topic_errors(work, topics, cited, segment):
    """A named topic must be treated by one of the cited steps."""
    every = {t for words in topics.values() for t in words}
    named = [t for t in every if re.search(r'\b' + re.escape(t) + r'\b',
                                           segment, re.IGNORECASE)]
    # 'love' inside 'love of money' is not a second topic.
    named = [t for t in named
             if not any(t != o and t in o for o in named)]
    have = {t for n in cited for t in topics.get(str(n), [])}
    return [f'{work["title"]} {cited} does not treat "{t}"'
            for t in named if t not in have]


def iter_sources():
    trees = json.loads(TREES.read_text(encoding='utf-8'))
    for tree in trees:
        for node in tree['nodes']:
            yield f'{tree["npcId"]}/{node["id"]}', node.get('source', ''), \
                None
    passions = json.loads(PASSIONS.read_text(encoding='utf-8'))
    for p in passions['passions']:
        yield f'passion/{p["id"]}', p['source'], p['id']
        yield f'passion/{p["id"]}/ladder', p['ladder'], p['id']
    text = CONFESSION.read_text(encoding='utf-8')
    for m in re.finditer(r"passion:\s*'(\w+)'.*?source:\s*'([^']+)'", text,
                         re.DOTALL):
        yield f'confession/{m.group(1)}', m.group(2), m.group(1)


def main():
    canon = Canon(json.loads(CANON.read_text(encoding='utf-8')))
    problems, count = [], 0
    for where, source, passion in iter_sources():
        count += 1
        if not source.strip():
            problems.append(f'{where}: empty source')
            continue
        errors, _ = canon.check(source)
        if passion:
            # The passion itself must be the topic of what it cites.
            probe = f'{source} ({passion})'
            errors += [e for e in canon.check(probe)[0] if e not in errors]
        problems += [f'{where}: {e}' for e in errors]
    if problems:
        print('\n'.join(problems))
        print(f'FAIL: {len(problems)} problem(s) in {count} sources '
              f'(canon: {CANON.relative_to(ROOT)})')
        return 1
    print(f'OK: {count} sources match the canon '
          f'({len(canon.works)} works, chapters checked, verses not)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
