"""Build the "Manuscript of rights": the licence register shown in-game.

HLD F5, improvement 95; CLAUDE.md TABOO 0.1 (the licence register is
always kept) and TABOO 0.25 item 4 (the lawyer gets the register).

The page lists what the player is actually shown, from the files that
ship, not from a hand-kept list:
  - every derived raw-material object under public/ludus/art/derived
    (source repository, commit, path, licence, shape and colour
    change, passion), read from its meta-json;
  - the engines and libraries in the build, with their licence file
    (or the absence of one, stated plainly);
  - the project's own work.
Copyleft entries carry a note that attribution and share-alike apply
whatever the 35 % rule says; the final word is the lawyer's.

Usage: python3 scripts/build_rights_manifest.py
Writes public/ludus/data/rights.json.
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DERIVED = ROOT / 'public' / 'ludus' / 'art' / 'derived'
OUT = ROOT / 'public' / 'ludus' / 'data' / 'rights.json'

COPYLEFT = ('GPL', 'AGPL', 'LGPL', 'CC-BY-SA', 'MPL')

# Engines and libraries.  "licence_file" is checked on disk, so a
# missing file shows up as a missing file, not as a guess.
LIBRARIES = [
    {'name': 'three.js 0.169 (Meta 3D proxies, scripts/meta3d)',
     'licence': 'MIT',
     'licence_file': 'scripts/meta3d/node_modules/three/LICENSE'},
    {'name': 'Needle Engine 5.1.12 (VR scene)',
     'licence': 'Proprietary: all rights reserved; free only for '
                'non-commercial or evaluation use',
     'licence_file': 'public/vr/vendor/needle/LICENSE.md',
     'note': 'A commercial licence or a move to three.js is needed '
             'before a Meta Store release (TABOO 0.25 item 4).'},
    {'name': 'kolokol (bell model, submodule vendor/kolokol)',
     'licence': 'not declared',
     'licence_file': 'vendor/kolokol/LICENSE',
     'note': 'The operator\'s own repository; a licence file is still '
             'to be added.'},
]

OWN = {
    'name': 'Ludus: code, SVG art, dialogues, procedural sound',
    'licence': 'not declared (all rights with the author)',
    'licence_file': 'LICENSE',
    'note': 'No LICENSE file in the repository yet; the operator '
            'decides.',
}


def derived_objects():
    out = []
    for meta_path in sorted(DERIVED.glob('*/*.json')):
        meta = json.loads(meta_path.read_text(encoding='utf-8'))
        redraw = meta.get('redraw') or {}
        variants = meta.get('variants') or []
        shapes = [v.get('shape_change') for v in variants
                  if isinstance(v.get('shape_change'), (int, float))]
        licence = meta.get('license', 'unknown')
        entry = {
            'object': meta.get('name', meta_path.stem),
            'slot': meta_path.parent.name,
            'passion': meta.get('passion'),
            'repo': meta.get('repo'),
            'commit': (meta.get('commit') or '')[:10],
            'path': meta.get('path'),
            'licence': licence,
            'colour_change': redraw.get('colour_change'),
            'min_shape_change': min(shapes) if shapes else
            redraw.get('shape_change'),
            'variants': len(variants),
        }
        if licence.upper().startswith(COPYLEFT):
            entry['note'] = ('Copyleft: attribution and share-alike '
                             'apply regardless of the 35 % rule; the '
                             'lawyer decides.')
        out.append(entry)
    return out


def with_file(item):
    item = dict(item)
    item['licence_file_present'] = (ROOT / item['licence_file']).exists()
    return item


def main():
    manifest = {
        'title': 'Manuscript of rights',
        'title_ru': 'Манускрипт прав',
        'generated_by': 'scripts/build_rights_manifest.py',
        'own': with_file(OWN),
        'libraries': [with_file(lib) for lib in LIBRARIES],
        'raw_material': derived_objects(),
    }
    OUT.write_text(json.dumps(manifest, ensure_ascii=False, indent=1)
                   + '\n', encoding='utf-8')
    print(f'{len(manifest["raw_material"])} raw objects, '
          f'{len(manifest["libraries"])} libraries -> '
          f'{OUT.relative_to(ROOT)}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
