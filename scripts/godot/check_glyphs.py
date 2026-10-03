"""Glyph coverage of the headset's text: no tofu in Quest or WebXR.

Every string the game shows comes from godot/data/*.json or from string
literals in godot/scripts/**/*.gd.  Godot draws them with its built-in
OpenSans SemiBold; a character missing from it is a box ("tofu") in the
Web export, which has no system fallback, and maybe in Quest too.  The
game ships one small fallback font (godot/fonts/ludus-fallback.ttf, a
subset of DejaVu Sans) for the symbols OpenSans lacks.  This check:

  --check   exit 1 if a character is covered by neither font;
  --build   (re)make the fallback subset from DejaVu Sans for exactly the
            characters OpenSans lacks (needs fontTools).

Church Slavonic and polytonic Greek must never become tofu (TABOO 0.2
item 7): when such text is added, its font is added here first.

Constitution: FORM (each letter the player reads) -> ACTION (the build
proves every letter has a glyph) -> GOAL (no word of the game, and no
holy text above all, is broken into empty boxes).
"""

import argparse
import glob
import json
import os
import re
import sys

from fontTools.subset import Options, Subsetter
from fontTools.ttLib import TTFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
BASE = os.environ.get(
    'GODOT_BASE_FONT',
    '/home/user/godot-src/godot/thirdparty/fonts/OpenSans_SemiBold.woff2')
DEJAVU = os.environ.get(
    'DEJAVU_FONT', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf')
FALLBACK = os.path.join(ROOT, 'godot', 'fonts', 'ludus-fallback.ttf')
# Characters that never reach the screen: controls and the like.
SKIP = set(range(0, 32)) | {0x7f, 0xfeff, 0x200b, 0x200d}
GD_STRING = re.compile(r'"((?:[^"\\]|\\.)*)"')


def _strings(node):
    """Yield every string inside a parsed JSON value."""
    if isinstance(node, str):
        yield node
    elif isinstance(node, dict):
        for k, v in node.items():
            yield k
            yield from _strings(v)
    elif isinstance(node, list):
        for v in node:
            yield from _strings(v)


def used_chars():
    """The set of code points the game may show, with where each is."""
    seen = {}
    for path in sorted(glob.glob(os.path.join(ROOT, 'godot/data/*.json'))):
        with open(path, encoding='utf-8') as f:
            data = json.load(f)
        for s in _strings(data):
            for ch in s:
                seen.setdefault(ord(ch), os.path.relpath(path, ROOT))
    for path in sorted(glob.glob(os.path.join(ROOT, 'godot/scripts/**/*.gd'),
                                 recursive=True)):
        with open(path, encoding='utf-8') as f:
            for line in f:
                code = line.split('#', 1)[0] if '"' not in line \
                    else line
                if code.lstrip().startswith('#'):
                    continue
                for m in GD_STRING.finditer(code):
                    for ch in m.group(1):
                        seen.setdefault(ord(ch), os.path.relpath(path, ROOT))
    return {c: w for c, w in seen.items() if c not in SKIP}


def cmap(path):
    """The code points a font file covers."""
    font = TTFont(path)
    return set(font.getBestCmap().keys())


def build(missing):
    """Subset DejaVu Sans to the characters the base font lacks."""
    have = cmap(DEJAVU)
    want = sorted(c for c in missing if c in have)
    opts = Options()
    opts.layout_features = []
    opts.name_IDs = ['*']
    opts.notdef_outline = True
    font = TTFont(DEJAVU)
    sub = Subsetter(opts)
    sub.populate(unicodes=want)
    sub.subset(font)
    os.makedirs(os.path.dirname(FALLBACK), exist_ok=True)
    font.save(FALLBACK)
    return want


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--build', action='store_true')
    args = ap.parse_args()
    used = used_chars()
    base = cmap(BASE)
    missing = {c: w for c, w in used.items() if c not in base}
    if args.build:
        got = build(missing)
        print('fallback: %d glyphs -> %s (%d bytes)' % (
            len(got), os.path.relpath(FALLBACK, ROOT),
            os.path.getsize(FALLBACK)))
    extra = cmap(FALLBACK) if os.path.exists(FALLBACK) else set()
    tofu = {c: w for c, w in missing.items() if c not in extra}
    print('characters used: %d; not in OpenSans: %d; tofu: %d' % (
        len(used), len(missing), len(tofu)))
    for c, w in sorted(tofu.items()):
        print('  U+%04X %r  first in %s' % (c, chr(c), w))
    if args.check and tofu:
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
