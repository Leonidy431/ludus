"""Write the round plan of the deficit runner (CLAUDE.md TABOO 0.15).

Each hourly pass takes the next three deficits of the rotation
(osint_cycle.rotation(): raw-material first, then code, P0 before P3)
from the cursor in docs/RAW_OSINT_CURSOR.json.  This script lists the
rounds of one full turn from the cursor on, with the hour each round
runs (minute 17 UTC, the GitHub schedule) and what it can yield, so the
operator sees the plan instead of a bare cursor.

Usage: python3 scripts/raw_assets/rounds.py [--per-round 3]
Writes docs/RAW_RUNNER_ROUNDS.md.
"""

import argparse
import datetime
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import osint_cycle  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs' / 'RAW_RUNNER_ROUNDS.md'
YIELD = {'raw-material': 'images through the 35 % runner + code',
         'code': 'code candidates (rewritten, measured by code_delta)'}


def next_slot(now):
    slot = now.replace(minute=17, second=0, microsecond=0)
    return slot if slot > now else slot + datetime.timedelta(hours=1)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--per-round', type=int, default=3)
    args = parser.parse_args()
    rows = osint_cycle.rotation()
    cursor = osint_cycle.load_cursor()
    start = cursor['next'] % len(rows) if rows else 0
    ordered = rows[start:] + rows[:start]
    now = datetime.datetime.now(datetime.timezone.utc)
    slot = next_slot(now)
    lines = [
        '# Deficit runner: rounds of one full turn',
        '',
        f'Generated {now:%Y-%m-%d %H:%M} UTC by '
        '`scripts/raw_assets/rounds.py`. '
        f'{len(rows)} deficits in rotation '
        f'({sum(r["fill"] == "raw-material" for r in rows)} raw-material, '
        f'{sum(r["fill"] == "code" for r in rows)} code); '
        f'{args.per_round} per hourly round; cursor at {start}.',
        '',
        'Procedural, own-drawing and content deficits are not in the '
        'rotation: raw material never fills them (TABOO 0.15 item 3).',
        '',
        '| Round | UTC | Deficit | P | Fill | Yields | Keys |',
        '|---|---|---|---|---|---|---|',
    ]
    for i in range(0, len(ordered), args.per_round):
        chunk = ordered[i:i + args.per_round]
        when = (slot + datetime.timedelta(hours=i // args.per_round))
        for j, row in enumerate(chunk):
            lines.append(
                f'| {i // args.per_round + 1 if j == 0 else ""} '
                f'| {when:%m-%d %H:%M}' if j == 0 else '| | ')
            lines[-1] += (f' | {row["id"]} | {row["priority"]} '
                          f'| {row["fill"]} | {YIELD[row["fill"]]} '
                          f'| {", ".join(row["keywords"][:6])} |')
    OUT.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(f'{-(-len(ordered) // args.per_round)} rounds, '
          f'{len(ordered)} deficits -> {OUT.relative_to(ROOT)}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
