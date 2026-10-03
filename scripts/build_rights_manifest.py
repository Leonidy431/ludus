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

The headset build gets its own page, godot/data/rights.json (HLD
CHORUS24 F7): what is inside the APK only, with SPDX licence ids and
the licence texts shipped beside it in godot/licenses/, because the
copy the player holds must carry the texts (GPL, CC BY-SA, Apache).

Usage: python3 scripts/build_rights_manifest.py [--check]
Writes public/ludus/data/rights.json and godot/data/rights.json;
--check writes nothing and fails if the headset page is stale or names
a licence text that is not in godot/licenses/.
"""

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DERIVED = ROOT / 'public' / 'ludus' / 'art' / 'derived'
OUT = ROOT / 'public' / 'ludus' / 'data' / 'rights.json'

GODOT = ROOT / 'godot'
GODOT_DERIVED = GODOT / 'art' / 'derived'
GODOT_OUT = GODOT / 'data' / 'rights.json'
LICENCES = GODOT / 'licenses'

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


def _previous():
    """licence_file_present of the manifest as last written, by name."""
    if not OUT.exists():
        return {}
    old = json.loads(OUT.read_text(encoding='utf-8'))
    return {lib['name']: lib.get('licence_file_present')
            for lib in [old.get('own', {})] + old.get('libraries', [])
            if 'name' in lib}


def _ignored(rel):
    """Whether git ignores this path (installed, never committed)."""
    out = subprocess.run(['git', 'check-ignore', '-q', rel], cwd=ROOT,
                         stderr=subprocess.DEVNULL)
    return out.returncode == 0


def with_file(item, previous=None):
    """The item with whether its licence text is present.

    A licence file inside an installed, git-ignored folder (three.js in
    scripts/meta3d/node_modules) is absent in a checkout that has not
    run npm install; that says nothing about the library.  Then the last
    written value is kept rather than turned to false (the review of
    2026-09-30 found the Manuscript of rights claiming three.js had no
    licence text after such a run)."""
    item = dict(item)
    rel = item['licence_file']
    present = (ROOT / rel).exists()
    if not present and _ignored(rel):
        kept = (previous or {}).get(item['name'])
        if kept is None:
            raise SystemExit(f'{rel} is not installed and no earlier '
                             'value is recorded: run npm install first')
        present = kept
    item['licence_file_present'] = present
    return item


# The SPDX id of each source repository, read from its own licence
# file in the clone (/home/user/raw-repos/full): Forge ships the GPL 3
# text and its README and pom.xml say "GPL-3.0" with no "or later";
# Crawl's LICENSE and Wesnoth's README say "version 2 ... or (at your
# option) any later version".  The meta-json of older objects says only
# "GPL", and a bare "GPL" names no text, so the id is fixed here.
REPO_SPDX = {
    'https://github.com/Card-Forge/forge': 'GPL-3.0-only',
    'https://github.com/crawl/crawl': 'GPL-2.0-or-later',
    'https://github.com/wesnoth/wesnoth': 'GPL-2.0-or-later',
}

# Who to name, by repository, when the meta-json has no author line.
REPO_AUTHOR = {
    'https://github.com/Card-Forge/forge': 'Forge contributors',
    'https://github.com/crawl/crawl':
        'Dungeon Crawl Stone Soup dev team and contributors '
        '(CREDITS.txt)',
    'https://github.com/wesnoth/wesnoth':
        'The Battle for Wesnoth Project contributors',
    'https://github.com/widelands/widelands':
        'The Widelands Development Team (data/txts/AUTHORS.lua)',
    'https://github.com/space-wizards/space-station-14':
        'Space Station 14 contributors (wooden bench by Ko4erga)',
    'https://github.com/Azgaar/Fantasy-Map-Generator':
        'Syryatsu, "Meuble sablier s\'écoulant", Wikimedia Commons '
        '(via Azgaar/Fantasy-Map-Generator)',
}

# The licence text in godot/licenses/ for each SPDX id; "-only" and
# "-or-later" share one text, since the text is the same.
TEXT = {
    'GPL-2.0': 'licenses/GPL-2.0.txt',
    'GPL-3.0': 'licenses/GPL-3.0.txt',
    'CC-BY-SA-3.0': 'licenses/CC-BY-SA-3.0.txt',
    'Apache-2.0': 'licenses/Apache-2.0.txt',
}

# What runs in the APK besides our own code.  The engine's own
# third-party parts (FreeType, Jolt, mbedTLS and the rest) are listed
# by the engine itself, Engine.get_copyright_info(), and their texts
# are in the engine binary, Engine.get_license_info(); the panel shows
# that list rather than copying it here.
HEADSET_COMPONENTS = [
    {'name': 'Godot Engine', 'version': '4.7.1-stable',
     'spdx': 'MIT', 'in_apk': True,
     'licence_file': 'licenses/MIT-Godot-Engine.txt',
     'note': 'Text as Engine.get_license_text() returns it; the '
             'engine\'s third-party parts are listed by '
             'Engine.get_copyright_info().'},
    {'name': 'godot_openxr_vendors (OpenXR loaders plugin)',
     'version': '5.1.0-stable', 'spdx': 'MIT', 'in_apk': True,
     'licence_file': 'licenses/MIT-godot_openxr_vendors.txt'},
    {'name': 'Khronos OpenXR loader (in the vendors plugin)',
     'version': 'with godot_openxr_vendors 5.1.0-stable',
     'spdx': 'Apache-2.0', 'in_apk': True,
     'licence_file': 'licenses/Apache-2.0.txt'},
    {'name': 'Meta OpenXR SDK (headers the Meta plugin is built with)',
     'version': 'with godot_openxr_vendors 5.1.0-stable',
     'spdx': 'LicenseRef-Oculus-SDK', 'in_apk': True,
     'licence_file': 'licenses/Meta-OpenXR-SDK-NOTICE.txt',
     'note': 'The notice names the Oculus SDK License Agreement by '
             'address; its full text is not in the vendors release.'},
]


def text_for(spdx):
    """The shipped licence text for an SPDX id, or None."""
    for key, rel in TEXT.items():
        if spdx == key or spdx.startswith(key + '-'):
            return rel
    return None


def headset_objects():
    """Raw-material objects whose pictures ship in the APK.

    What ships is godot/art/derived; the facts of each object are in
    its meta-json under public/ludus/art/derived (one source)."""
    names = sorted({p.name[:-len('_v01.png')] for p in
                    GODOT_DERIVED.glob('*/*_v[0-9][0-9].png')})
    out = []
    for name in names:
        metas = sorted(DERIVED.glob(f'*/{name}.json'))
        if not metas:
            raise SystemExit(f'{name}: ships in godot/art/derived but '
                             'has no meta-json')
        meta = json.loads(metas[0].read_text(encoding='utf-8'))
        repo = meta.get('repo') or ''
        if not repo.startswith('https://'):
            continue  # our own drawing, listed under "own"
        facts = meta.get('licence_facts') or {}
        spdx = (facts.get('licence') or REPO_SPDX.get(repo)
                or meta.get('license'))
        rel = text_for(spdx)
        if rel is None:
            raise SystemExit(f'{name}: no licence text for {spdx!r}')
        out.append({
            'object': name,
            'slot': metas[0].parent.name,
            'repo': repo,
            'commit': (meta.get('commit') or '')[:10],
            'path': meta.get('path'),
            'spdx': spdx,
            'author': REPO_AUTHOR.get(repo, 'contributors of ' + repo),
            'licence_file': rel,
            'colour_change': meta.get('colour_change'),
            'shape_change': meta.get('shape_change'),
        })
    return out


def headset_manifest():
    objects = headset_objects()
    used = sorted({o['licence_file'] for o in objects}
                  | {c['licence_file'] for c in HEADSET_COMPONENTS})
    missing = [rel for rel in used if not (GODOT / rel).exists()]
    if missing:
        raise SystemExit('licence texts missing from godot/licenses: '
                         + ', '.join(missing))
    return {
        'title': 'Manuscript of rights',
        'title_ru': 'Манускрипт прав',
        'generated_by': 'scripts/build_rights_manifest.py',
        'own': {'name': OWN['name'],
                'licence': OWN['licence'], 'note': OWN['note'],
                'name_ru': 'Ludus: код, рисунки SVG, диалоги, '
                           'процедурный звук',
                'licence_ru': 'не объявлена (все права у автора)'},
        'components': HEADSET_COMPONENTS,
        'raw_material': objects,
        'licence_texts': used,
        'copyleft_note': 'GPL and CC BY-SA apply to these pictures '
                         'whatever the 35 % rule says: authors are '
                         'named here, the texts ship in licenses/, and '
                         'the sources are at the repository and commit '
                         'given.  The final word is the lawyer\'s.',
        'copyleft_note_ru': 'GPL и CC BY-SA действуют для этих '
                            'картинок независимо от правила 35 %: '
                            'авторы названы здесь, тексты лицензий '
                            'лежат в licenses/, исходники — в '
                            'указанном репозитории и ревизии.  '
                            'Последнее слово за юристом.',
    }


def _dump(data):
    return json.dumps(data, ensure_ascii=False, indent=1) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    headset = _dump(headset_manifest())
    if args.check:
        old = (GODOT_OUT.read_text(encoding='utf-8')
               if GODOT_OUT.exists() else '')
        if old != headset:
            print(f'{GODOT_OUT.relative_to(ROOT)} is stale: run '
                  'python3 scripts/build_rights_manifest.py')
            return 1
        print(f'{GODOT_OUT.relative_to(ROOT)} is up to date')
        return 0
    GODOT_OUT.write_text(headset, encoding='utf-8')
    previous = _previous()
    manifest = {
        'title': 'Manuscript of rights',
        'title_ru': 'Манускрипт прав',
        'generated_by': 'scripts/build_rights_manifest.py',
        'own': with_file(OWN, previous),
        'libraries': [with_file(lib, previous) for lib in LIBRARIES],
        'raw_material': derived_objects(),
    }
    OUT.write_text(json.dumps(manifest, ensure_ascii=False, indent=1)
                   + '\n', encoding='utf-8')
    print(f'{len(manifest["raw_material"])} raw objects, '
          f'{len(manifest["libraries"])} libraries -> '
          f'{OUT.relative_to(ROOT)}; headset page -> '
          f'{GODOT_OUT.relative_to(ROOT)}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
