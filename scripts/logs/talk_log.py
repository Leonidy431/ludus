"""Daily talk log of the work with the operator: docs/logs/talk_log_<date>.md.

The operator (2026-10-02): «Мы ведем же talk log на каждый день да? Если
нет веди».  The log had stopped on 2026-09-23/24 (docs/logs/talklog.md,
talk_log_2026-09-23.md).  This script writes one file per day from two
primary sources, so nothing in it is retold from memory:

* the operator's messages, word for word, with their UTC time, taken
  from the Claude Code session transcript (JSONL);
* the commits of that day on the working branch (git log), with their
  short hash and subject.

Left out: the context summaries the session writes for itself, the
hourly routine's stored prompt (counted, not copied), hook feedback and
tool output.  IPv4 addresses and e-mail addresses are masked in any
case (CLAUDE.md: no addresses or personal data in the repository).
Logs are never deleted (TABOO 0.25 point 5): a day's file is rewritten
only to add to it.

    python3 scripts/logs/talk_log.py --transcript <session.jsonl>
    python3 scripts/logs/talk_log.py --transcript <...> --day 2026-10-02

The transcript lives in the session container (~/.claude/projects/),
so the log is written at the end of each working day in the session.

Constitution: ФОРМА (what the operator said and what was done, from the
sources) → ДЕЙСТВИЕ (one file a day, word for word, with commits) →
ЦЕЛЬ (the memory of the work is a testimony, not a retelling).
"""

import argparse
import collections
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs' / 'logs'
SKIP_PREFIXES = ('This session is being continued',
                 'Stop hook feedback', '[Request interrupted')
ROUTINE = 'Ежечасный цикл Ludus'
IPV4 = re.compile(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b')
EMAIL = re.compile(r'[\w.+-]+@[\w-]+\.[\w.]+')


def mask(text):
    text = IPV4.sub('[адрес скрыт]', text)
    return EMAIL.sub('[почта скрыта]', text)


def text_of(content):
    """The text the operator typed; images and tool results are left
    out, a system wrapper (starting with '<') is not a message."""
    if isinstance(content, str):
        return content
    parts = []
    for c in content or []:
        if isinstance(c, dict) and c.get('type') == 'text':
            parts.append(c.get('text', ''))
    return '\n'.join(parts)


def messages(transcript):
    """{day: [(time, text)]} and {day: routine count}."""
    days = collections.defaultdict(list)
    routine = collections.Counter()
    for line in open(transcript, encoding='utf-8'):
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        if rec.get('type') != 'user' or rec.get('isMeta'):
            continue
        text = text_of(rec.get('message', {}).get('content')).strip()
        stamp = rec.get('timestamp', '')
        if not text or not stamp or text.startswith('<'):
            continue
        if text.startswith(SKIP_PREFIXES):
            continue
        day = stamp[:10]
        if text.startswith(ROUTINE):
            routine[day] += 1
            continue
        days[day].append((stamp[11:16], mask(text)))
    return days, routine


def commits(day):
    out = subprocess.run(
        ['git', 'log', '--since=%sT00:00:00Z' % day,
         '--until=%sT23:59:59Z' % day, '--date=iso-strict',
         '--format=%h\t%ad\t%s'],
        cwd=ROOT, capture_output=True, text=True, check=True).stdout
    rows = []
    for line in out.splitlines():
        h, when, subject = line.split('\t', 2)
        rows.append((h, when[11:16], subject))
    return list(reversed(rows))


def quote(text):
    return '\n'.join('> ' + ln if ln else '>' for ln in text.splitlines())


def write_day(day, said, routine_n):
    rows = commits(day)
    lines = ['# Talk log — %s' % day, '',
             'Собрано `scripts/logs/talk_log.py` из журнала сессии Claude '
             'Code (слова оператора дословно, время UTC) и `git log` '
             'ветки. Адреса и почта скрыты. Журнал не удаляется '
             '(ТАБУ №0.25 п. 5).', '',
             '## Оператор (%d сообщений)' % len(said), '']
    for when, text in said:
        lines += ['**%s UTC**' % when, '', quote(text), '']
    if routine_n:
        lines += ['Ежечасный цикл по расписанию срабатывал %d раз '
                  '(его запись — `docs/LOOP_PROGRESS_2026-09-29.md`).'
                  % routine_n, '']
    lines += ['## Сделано: коммиты дня (%d)' % len(rows), '']
    if rows:
        lines += ['| время UTC | коммит | что |', '|---|---|---|']
        lines += ['| %s | `%s` | %s |' % (w, h, s.replace('|', '\\|'))
                  for h, w, s in rows]
    else:
        lines.append('Коммитов в этот день нет.')
    path = OUT / ('talk_log_%s.md' % day)
    path.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    return path, len(said), len(rows)


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--transcript', required=True)
    ap.add_argument('--day', help='only this day (YYYY-MM-DD)')
    args = ap.parse_args(argv)
    days, routine = messages(args.transcript)
    OUT.mkdir(parents=True, exist_ok=True)
    for day in sorted(set(days) | set(routine)):
        if args.day and day != args.day:
            continue
        path, n_said, n_commits = write_day(day, days.get(day, []),
                                            routine.get(day, 0))
        print('%s: %d messages, %d commits' % (path.relative_to(ROOT),
                                               n_said, n_commits))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
