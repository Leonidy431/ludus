"""Measure how far our code departs from a third-party source module.

Code is raw material too (CLAUDE.md, TABOO 0.1): a mechanic studied in
a game from the backlog list may inspire our implementation only if the
measured change is at least 35 %.  The measure works on normalised
tokens, so renaming whitespace or comments cannot inflate it.

Usage:
    python3 scripts/raw_assets/code_delta.py SOURCE OURS \
        --source-repo URL --license SPDX [--threshold 0.35] [--json]
"""

import argparse
import difflib
import io
import json
import re
import sys
import tokenize
from pathlib import Path

# Identifier-like runs, numbers, strings and single punctuation marks.
# One regex covers C, C++, C#, Java, JS/TS, Lua and Python well enough
# for a similarity measure; exact parsing is not needed here.
TOKEN = re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|'
                   r'[A-Za-z_][A-Za-z0-9_]*|\d+(?:\.\d+)?|\S')

LINE_COMMENT = re.compile(r'(//|#|--).*?$', re.MULTILINE)
BLOCK_COMMENT = re.compile(r'/\*.*?\*/', re.DOTALL)


def strip_comments(text, suffix):
    """Remove comments so documentation never counts as change."""
    if suffix == '.py':
        # The tokenizer knows Python's own comment and string rules, so
        # a "#" inside a string literal is kept intact.
        out = []
        try:
            for tok in tokenize.generate_tokens(io.StringIO(text).readline):
                if tok.type != tokenize.COMMENT:
                    out.append(tok.string)
            return ' '.join(out)
        except (tokenize.TokenError, IndentationError):
            pass
    text = BLOCK_COMMENT.sub(' ', text)
    return LINE_COMMENT.sub(' ', text)


def normalise(path):
    """Return the file's tokens with every identifier replaced by ID.

    A copy with renamed variables is still a copy.  Replacing names with
    one placeholder compares only the structure of the code, so a
    rename scores 0 % and cannot pass the threshold.
    """
    path = Path(path)
    text = path.read_text(encoding='utf-8', errors='ignore')
    tokens = TOKEN.findall(strip_comments(text, path.suffix.lower()))
    return ['ID' if re.match(r'[A-Za-z_]', t) else t for t in tokens]


def code_change(source, ours):
    """1 - similarity of the normalised token sequences."""
    matcher = difflib.SequenceMatcher(a=normalise(source), b=normalise(ours),
                                      autojunk=False)
    return 1 - matcher.ratio()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source')
    parser.add_argument('ours')
    parser.add_argument('--source-repo', required=True)
    parser.add_argument('--license', required=True)
    parser.add_argument('--threshold', type=float, default=0.35)
    parser.add_argument('--json', action='store_true')
    args = parser.parse_args()

    change = code_change(args.source, args.ours)
    passed = change >= args.threshold
    record = {
        'source_repo': args.source_repo,
        'source_file': args.source,
        'ours': args.ours,
        'license': args.license,
        'code_change': round(change, 4),
        'threshold': args.threshold,
        'passed': passed,
    }
    if args.json:
        print(json.dumps(record, ensure_ascii=False))
    else:
        verdict = 'OK' if passed else 'Требуется переработка'
        print(f'{verdict}: code change {change:.1%} '
              f'(threshold {args.threshold:.0%}), {args.license}')
    sys.exit(0 if passed else 1)


if __name__ == '__main__':
    main()
