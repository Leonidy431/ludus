"""Archive the last 24 hours: the dialogue and the glove renders.

Run every six hours (operator, 2026-10-03: "all glove renders and the
whole dialogue of 24 hours, documented with files, in PEP 8, committed,
every 6 hours so that nothing is lost").  It writes two documents into
docs/logs/archive/ and does not touch anything else:

    dialogue_<stamp>.md  operator and assistant text of the window
    renders_<stamp>.md   every glove / volumetric render and its code,
                         with size, SHA-256 and the last commit

    python3 scripts/logs/archive_6h.py --transcript <session .jsonl>
        [--hours 24] [--now 2026-10-03T12:00] [--commit]

Mail addresses are masked as in talk_log.py; nothing is deleted
(TABOO 0.25 item 5).  The files are named by the UTC hour, so a rerun in
the same hour replaces its own pair and nothing else.
"""
import argparse
import datetime
import hashlib
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import talk_log  # noqa: E402

ROOT = talk_log.ROOT
OUT = ROOT / 'docs' / 'logs' / 'archive'
# Where glove renders and their code live (git-tracked paths).
RENDER_PATTERNS = ('docs/audit/*/volumetric/*', 'docs/audit/*/glove*',
                   'video/glove*/*', 'video/volumetric*/*')
# Audio never lives in the repository (a test enforces it); built audio
# is only listed, from the untracked build folder.
AUDIO_FILES = ('build/music/cosmos/nauka-lyubov-poznanie.mp3',)
CODE_PATTERNS = ('godot/scripts/glove_computer.gd',
                 'godot/scripts/volumetric_*.gd',
                 'godot/tools/volumetric_shots.gd',
                 'godot/tests/test_glove_computer.gd',
                 'godot/tests/test_volumetric*.gd',
                 'godot/data/volumetric-display.json',
                 'docs/HLD_VOLUMETRIC_LASER_SCREEN_*.md')
ASSISTANT_CAP = 4000


def parse_stamp(text):
    return datetime.datetime.strptime(text[:16], '%Y-%m-%dT%H:%M')


def assistant_text(rec):
    """The text blocks of an assistant turn, tool calls left out."""
    content = rec.get('message', {}).get('content')
    if isinstance(content, str):
        return content
    return '\n'.join(c.get('text', '') for c in content or []
                     if isinstance(c, dict) and c.get('type') == 'text')


def dialogue(transcript, since):
    """[(stamp, who, text)] of the window, in the order they happened.

    The operator side is the same as talk_log.messages (it also catches
    messages sent while the agent worked); the assistant side is its own
    text, each turn cut at ASSISTANT_CAP characters.
    """
    rows = []
    said, _ = talk_log.messages(transcript)
    for day, items in said.items():
        for hhmm, text in items:
            stamp = parse_stamp('%sT%s' % (day, hhmm))
            if stamp >= since:
                rows.append((stamp, 'operator', text))
    for line in open(transcript, encoding='utf-8'):
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        if rec.get('type') != 'assistant' or not rec.get('timestamp'):
            continue
        stamp = parse_stamp(rec['timestamp'])
        text = talk_log.mask(assistant_text(rec).strip())
        if stamp >= since and text:
            if len(text) > ASSISTANT_CAP:
                text = text[:ASSISTANT_CAP] + ' [cut]'
            rows.append((stamp, 'claude', text))
    rows.sort(key=lambda r: (r[0], r[1] != 'operator'))
    return rows


def tracked(patterns):
    out = subprocess.run(['git', 'ls-files'] + list(patterns), cwd=ROOT,
                         capture_output=True, text=True, check=True).stdout
    return sorted(set(out.split('\n')) - {''})


def last_commit(path):
    out = subprocess.run(['git', 'log', '-1', '--format=%h %ad',
                          '--date=short', '--', path], cwd=ROOT,
                         capture_output=True, text=True, check=True).stdout
    return out.strip() or 'not committed'


def sha256(path):
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


def write_dialogue(rows, since, until, name):
    fmt = '%Y-%m-%d %H:%M'
    head = '# Dialogue, %s - %s UTC' % (since.strftime(fmt),
                                        until.strftime(fmt))
    lines = [head,
             '',
             'Operator and assistant text of the window; mail addresses '
             'masked; tool calls and results left out.  %d turns.'
             % len(rows), '']
    for stamp, who, text in rows:
        lines.append('### %s %s' % (stamp.strftime('%m-%d %H:%M'), who))
        lines.append('')
        lines.append(talk_log.quote(text) if who == 'operator' else text)
        lines.append('')
    path = OUT / ('dialogue_%s.md' % name)
    path.write_text('\n'.join(lines), encoding='utf-8')
    return path


def write_renders(name, until):
    lines = ['# Glove and volumetric-screen renders, up to %s UTC'
             % until.strftime('%Y-%m-%d %H:%M'), '',
             'Everything git-tracked that shows or builds the diver\'s '
             'glove screen.  Re-render: see the HLD and '
             '`godot/tools/volumetric_shots.gd` (headless, deterministic).',
             '']
    for title, patterns in (('Renders', RENDER_PATTERNS),
                            ('Code, data and documents', CODE_PATTERNS)):
        lines += ['## %s' % title, '',
                  '| file | bytes | last commit | sha256 |',
                  '|---|---|---|---|']
        for path in tracked(patterns):
            lines.append('| `%s` | %d | %s | `%s` |' % (
                path, (ROOT / path).stat().st_size, last_commit(path),
                sha256(path)[:16]))
        lines.append('')
    lines += ['## Built audio (not in git)', '',
              '| file | bytes | sha256 |', '|---|---|---|']
    for rel in AUDIO_FILES:
        if (ROOT / rel).exists():
            lines.append('| `%s` | %d | `%s` |' % (
                rel, (ROOT / rel).stat().st_size, sha256(rel)[:16]))
    lines.append('')
    path = OUT / ('renders_%s.md' % name)
    path.write_text('\n'.join(lines), encoding='utf-8')
    return path


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--transcript', required=True)
    ap.add_argument('--hours', type=int, default=24)
    ap.add_argument('--now', help='UTC time, YYYY-MM-DDTHH:MM')
    ap.add_argument('--commit', action='store_true')
    args = ap.parse_args(argv)
    now = datetime.datetime.utcnow().replace(second=0, microsecond=0)
    until = parse_stamp(args.now) if args.now else now
    since = until - datetime.timedelta(hours=args.hours)
    OUT.mkdir(parents=True, exist_ok=True)
    name = until.strftime('%Y-%m-%d_%Hh')
    rows = dialogue(args.transcript, since)
    made = [write_dialogue(rows, since, until, name),
            write_renders(name, until)]
    for path in made:
        print('wrote', path.relative_to(ROOT))
    if args.commit:
        rel = [str(p.relative_to(ROOT)) for p in made]
        subprocess.run(['git', 'add'] + rel, cwd=ROOT, check=True)
        subprocess.run(['git', 'commit', '-m',
                        'Archive of the last %d h: dialogue and glove '
                        'renders (%s)\n\nCo-Authored-By: Claude Sonnet 5.5 '
                        '<noreply@anthropic.com>\nClaude-Session: https://'
                        'claude.ai/code/session_015SgoYe2WsjLk8L6xDTU2JU'
                        % (args.hours, name)], cwd=ROOT, check=True)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
