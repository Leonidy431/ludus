"""The licence of one file of a backlog repo, not only of its repo.

The runner used to guess one licence per repository from the first 600
characters of its top-level licence file.  That guess is often only the
code licence: rotp-public's LICENSE starts with GPL-3 for the Java
sources and says further down that every image, sound and text file is
CC BY-NC-ND 4.0 ("These assets cannot be altered"), so 3 870 rotp images
were labelled GPL and could be pushed through the derivative pipeline.
Eleven repos also came out as "UNKNOWN" and were shelved anyway.

This module answers per file, from three sources in this order:

1. REPO_RULES: explicit, reviewed rules for repos whose licence file
   names several licences by path (each rule quotes its source);
2. a machine-readable Debian copyright file (DEP-5, endless-sky and
   godot), where the last matching "Files:" stanza decides;
3. the head of the top-level licence file, as before, with a few more
   marks (Ms-PL, ISC, zlib, Artistic).

Two questions are then asked of the label:

- shelvable: may a copy sit in the private props store?  Yes for open
  licences and for Creative Commons NC/ND ones (they allow verbatim
  copies); no for UNKNOWN and custom licences, which are refused and
  counted, never guessed (TABOO 0.012 p. 2 in spirit: what we cannot
  read is not ours to take).
- derivable: may the TABOO 0.1 pipeline make a derivative of it?  Only
  open licences without NC or ND.  to_slot and the pass check this
  before transform.py runs.

The final word on every licence stays with the lawyer (TABOO 0.1).
"""

import fnmatch
import functools
import json
import re
import subprocess
from pathlib import Path

# Marks in the head of a top-level licence file, the more specific
# first ("LGPL" before "GPL").  The first ten are the runner's original
# list, unchanged, so earlier register lines keep their labels.
HEAD_MARKS = (
    ('AGPL-3.0', 'AFFERO'), ('LGPL', 'LESSER GENERAL'),
    ('GPL', 'GNU GENERAL PUBLIC'),
    ('MIT', 'PERMISSION IS HEREBY GRANTED'),
    ('Apache-2.0', 'APACHE LICENSE'), ('MPL-2.0', 'MOZILLA PUBLIC'),
    ('CC-BY-SA', 'ATTRIBUTION-SHAREALIKE'), ('CC0-1.0', 'CC0'),
    ('BSD', 'REDISTRIBUTION AND USE'), ('Zlib', 'ALTERED SOURCE'),
    # Added 2026-09-30 after the UNKNOWN heads were read one by one.
    ('Ms-PL', 'MICROSOFT PUBLIC LICENSE'), ('ISC', 'ISC LICENSE'),
    ('Zlib', 'ALTER IT AND REDISTRIBUTE IT FREELY'),
    ('Artistic', 'ARTISTIC LICENSE'),
)
DEP5_MARK = 'FORMAT: HTTPS://WWW.DEBIAN.ORG/DOC/PACKAGING-MANUALS/' \
    'COPYRIGHT-FORMAT'
DEP5 = 'DEP5'
UNKNOWN = 'UNKNOWN'

# Rules per repo, first match wins; None keeps the licence of the head.
# Each one was read from the repo's own licence file on 2026-09-30.
REPO_RULES = {
    # LICENSE: *.java GPL-3 (src/rotp/apachemath Apache-2.0); "All
    # image files", "All sound files", the texts and manual.pdf are
    # CC BY-NC-ND 4.0: "These assets cannot be altered."
    'https://github.com/RayFowler/rotp-public': (
        (r'(^|/)apachemath/.*\.java$', 'Apache-2.0'),
        (r'\.java$', None),
        (r'', 'CC-BY-NC-ND-4.0'),
    ),
    # LICENSE.txt: a list of copyright holders, then the MIT text.
    'https://github.com/CorsixTH/CorsixTH': ((r'', 'MIT'),),
    # license.txt: "LOVE ... License: zlib"; src/libraries/ holds the
    # bundled third-party projects, each under its own terms.
    'https://github.com/love2d/love': (
        (r'^src/libraries/', UNKNOWN),
        (r'', 'Zlib'),
    ),
    # LICENSE.md: "The documentation and examples are under the MIT
    # License"; the framework is triple-licensed and third-party assets
    # keep their own licences (REUSE.toml), so the rest is unread.
    'https://github.com/slint-ui/slint': (
        (r'^(docs?|examples)/', 'MIT'),
        (r'', UNKNOWN),
    ),
    # LICENSE.txt: "Defold License, Version 1.0", a licence of its own
    # rather than Apache-2.0; left to the lawyer.
    'https://github.com/defold/defold': ((r'', 'Defold-1.0'),),
}

# Families that allow copies and derivatives (with their own duties:
# attribution, share-alike, source).
_OPEN = re.compile(
    r'^(A?GPL|LGPL|MIT|Expat|X11|Apache|MPL|BSD|ISC|Zlib|Ms-PL|'
    r'Artistic|CC0|CC-BY(-SA)?(-\d|$)|public-domain|Unlicense|BSL|'
    r'Boost|FTL|libpng|curl)', re.IGNORECASE)
_CC = re.compile(r'^CC-BY', re.IGNORECASE)
_NC_ND = re.compile(r'(^|-)(NC|ND)(-|$)', re.IGNORECASE)


def head_licence(head):
    """The label read from the head of a top-level licence file."""
    # Whitespace is folded: recastnavigation breaks "redistribute it
    # freely" across two lines.  No earlier label changes by this; only
    # UNKNOWN heads gain one (checked on all 82 indexed repos).
    text = re.sub(r'\s+', ' ', (head or '').lstrip('\ufeff')).upper()
    if text.startswith(DEP5_MARK):
        return DEP5
    for label, mark in HEAD_MARKS:
        if mark in text:
            return label
    return UNKNOWN


def _dep5_stanzas(text):
    """(globs, licence) of every Files stanza of a DEP-5 file."""
    stanzas, fields, last = [], {}, None
    for line in text.lstrip('\ufeff').splitlines() + ['']:
        if not line.strip():
            if 'Files' in fields and 'License' in fields:
                licence = fields['License'].split('\n')[0].strip()
                stanzas.append((fields['Files'].split(), licence))
            fields, last = {}, None
            continue
        if line[0] in ' \t':
            # A continuation line: more globs, or licence text.
            if last:
                fields[last] += '\n' + line.strip()
            continue
        name, _sep, value = line.partition(':')
        last = name.strip()
        fields[last] = value.strip()
    return stanzas


def dep5_licence(text, path):
    """The licence of path in a DEP-5 file: the last matching stanza."""
    found = UNKNOWN
    for globs, licence in _dep5_stanzas(text):
        if any(fnmatch.fnmatchcase(path, g) for g in globs):
            found = licence
    return found


def path_licence(repo, path, base, full_text=''):
    """The licence of one file, given the repo's head label."""
    for pattern, licence in REPO_RULES.get(repo, ()):
        if re.search(pattern, path):
            return licence or base
    if base == DEP5:
        return dep5_licence(full_text, path)
    return base


def _parts(licence):
    # "GPL-3+ or CC-BY-SA-4.0" offers a choice; "Expat and Zlib" binds
    # both.  A choice is open if one alternative is open in full.
    return [re.split(r'\s+and\s+|\s*,\s*', alt.strip())
            for alt in re.split(r'\s+or\s+', licence or '')]


def derivable(licence):
    """May the pipeline make a derivative (no NC, no ND, all open)?"""
    return any(all(_OPEN.match(p) and not _NC_ND.search(p) for p in alt)
               for alt in _parts(licence))


def shelvable(licence):
    """May a verbatim copy sit in the private props store?"""
    return derivable(licence) or any(
        all(_OPEN.match(p) or _CC.match(p) for p in alt)
        for alt in _parts(licence))


@functools.lru_cache(maxsize=None)
def _header(index_root, name):
    path = Path(index_root) / 'index' / f'{name}.jsonl'
    with path.open(encoding='utf-8') as fh:
        return json.loads(fh.readline())['header']


@functools.lru_cache(maxsize=None)
def _full_text(clone, commit, licence_file):
    # The licence blob was read when the index was built, so it is in
    # the blobless clone already; no network is needed here.
    out = subprocess.run(['git', 'show', f'{commit}:{licence_file}'],
                         cwd=clone, capture_output=True, timeout=300)
    return out.stdout.decode('utf-8', 'replace') if not out.returncode \
        else ''


def licence_for(index_root, hit):
    """The licence of the hit's own file, from the index and its clone."""
    name = hit['repo'].split('github.com/')[-1].replace('/', '__')
    header = _header(str(index_root), name)
    if not header.get('license_file'):
        return 'NOASSERTION'
    base = head_licence(header.get('license_head'))
    full = ''
    if base == DEP5:
        full = _full_text(str(Path(index_root) / 'clones' / name),
                          header['commit'], header['license_file'])
    return path_licence(hit['repo'], hit.get('path', ''), base, full)
