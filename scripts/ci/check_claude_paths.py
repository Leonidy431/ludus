"""Check that every repository path named in CLAUDE.md exists.

CLAUDE.md names the files each rule lives in.  A rule that points to a
file nobody can open is a rule nobody can check (TABOO 0.6, "do not
simulate"), so this lists every backticked path that is missing.

What is not a path of this repository and is skipped:
  - globs (``*``) and templates (``<date>``, ``<N>``);
  - build outputs under ``build/`` and the runtime ``user://``,
    ``res://`` and URLs;
  - branch names (``claude/...``, ``raw-osint/auto``) and absolute
    paths of the sandbox (``/home/...``);
  - commands (a token with a space that does not start with a path)
    and words without a slash or a file suffix.
A path written with a command around it (``python3 scripts/x.py
--check``) is checked by its path.

Usage:
    python3 scripts/ci/check_claude_paths.py [--file CLAUDE.md] [--strict]

Without --strict the missing paths are printed and the exit code is 0
(the step only warns for now); with --strict a missing path exits 1.
"""

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TICKED = re.compile(r'`([^`\n]+)`')
SUFFIX = re.compile(r'\.(md|py|js|ts|gd|json|yml|yaml|cfg|glb|gltf|png|svg|'
                    r'css|html|tscn|txt|jsonl|sh|pck|apk)$')
BRANCH_PREFIXES = ('claude/', 'raw-osint/')
SKIP_PREFIXES = ('build/', 'user://', 'res://', 'http://', 'https://', '/',
                 '~')
# Paths that CLAUDE.md names in another repository (webtypicon2), so
# they cannot exist here: TABOO 0.05 lists the game code there.
OTHER_REPO = ('public/game/', 'public/index.html', 'functions/src/game/',
              'style.css', 'i18n.js', 'app.js', 'vr.js', 'docs/ru/')


def candidates(text):
    """Yield (line number, path) for each backticked path-like token."""
    for number, line in enumerate(text.splitlines(), 1):
        for token in TICKED.findall(line):
            for word in token.split():
                # A leading dot is part of a path (.github/, .claude/).
                path = word.strip(',;:()"\'«»').rstrip('.')
                if path.startswith('--') or not path:
                    continue
                if '/' not in path and not SUFFIX.search(path):
                    continue
                yield number, path


def skipped(path):
    """True for what is not a file of this repository (see the doc)."""
    if any(ch in path for ch in '*<>{}$|='):
        return True
    if path.startswith(SKIP_PREFIXES + BRANCH_PREFIXES):
        return True
    if path.startswith(OTHER_REPO) or path in OTHER_REPO:
        return True
    # A bare file name (no slash) is named by a rule, not located, and
    # "a.js/.css" is shorthand for two files.
    if '/' not in path or '/.' in path:
        return True
    # A one-segment folder ("examples/") names a kind of folder in the
    # 99 cloned repos, not a folder here.
    if path.endswith('/') and path.count('/') == 1:
        return True
    # "owner/name" of a GitHub repository or a "a/b" pair of words.
    if not SUFFIX.search(path) and not path.endswith('/') and \
            path.count('/') == 1 and not (ROOT / path.split('/')[0]).exists():
        return True
    return False


def missing_paths(claude_md):
    text = claude_md.read_text(encoding='utf-8')
    seen, missing = set(), []
    for number, path in candidates(text):
        if path in seen or skipped(path):
            continue
        seen.add(path)
        # "ludus/public/vr/" names this repository by its name.
        local = path[len('ludus/'):] if path.startswith('ludus/') else path
        if not (ROOT / local.rstrip('/')).exists():
            missing.append((number, path))
    return seen, missing


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--file', default=str(ROOT / 'CLAUDE.md'))
    parser.add_argument('--strict', action='store_true')
    args = parser.parse_args(argv)
    seen, missing = missing_paths(Path(args.file))
    print(f'check_claude_paths: {len(seen)} paths named, '
          f'{len(missing)} missing')
    for number, path in missing:
        print(f'  CLAUDE.md:{number}: {path}')
    if missing and args.strict:
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
