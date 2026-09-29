"""Fail the build when an SVG or a prompt has no Meta 3D object.

CLAUDE.md TABOO 0.32 item 6: every SVG (SVG/, public/ludus/art/) and
every prompt in docs/PROMPTS_1070_*.json needs a .glb plus meta-json in
public/vr/models/.  The message "Нет объёма для Meta" names what is
missing, so the gap is fixed by running scripts/meta3d/build.js.
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODELS = ROOT / 'public' / 'vr' / 'models'


def main():
    have = {p.stem for p in MODELS.rglob('*.glb')}
    missing = []
    for folder in (ROOT / 'SVG', ROOT / 'public' / 'ludus' / 'art'):
        for svg in folder.rglob('*.svg'):
            if 'derived' not in svg.parts and svg.stem not in have:
                missing.append(str(svg.relative_to(ROOT)))
    for prompts in (ROOT / 'docs').glob('PROMPTS_*.json'):
        count = len(json.loads(prompts.read_text('utf-8')))
        # Prompt ids are p0001-<slug>; checking the numeric prefix keeps
        # this independent of the transliteration in build.js.
        numbered = {h.split('-')[0] for h in have if h.startswith('p')}
        for i in range(1, count + 1):
            if f'p{i:04d}' not in numbered:
                missing.append(f'{prompts.name}#{i - 1}')
    no_meta = [str(p.relative_to(ROOT)) for p in MODELS.rglob('*.glb')
               if not p.with_suffix('.json').exists()]
    if missing or no_meta:
        print('Нет объёма для Meta:', len(missing), 'без .glb,',
              len(no_meta), 'без meta-json')
        for item in (missing + no_meta)[:40]:
            print('  ', item)
        sys.exit(1)
    print(f'meta3d coverage ok: {len(have)} models')


if __name__ == '__main__':
    main()
