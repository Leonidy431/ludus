"""CI gate: the headset's copies of shared data and derived art.

The headset (godot/) ships copies of files the web game owns: the JSON
under public/ludus/data/ and the derived sprites under
public/ludus/art/derived/.  A hand-written list of ``cmp`` lines misses
every new file, so this walks the folders instead:

1. every JSON with the same relative path in godot/data/ and
   public/ludus/data/ is byte for byte the same (one source of data for
   both versions, TABOO 0.32 item 7), except the few listed in OWN_PAGE
   with the reason they differ;
2. every derived image under godot/art/derived/ either is a byte copy
   of the web's image of the same path, or is a headset atlas that
   godot/data/fish-drawings.json lists (fish_procedural.py --check
   proves the atlas is drawn from its listed cells);
3. the 35 % gate (check_delta.py, TABOO 0.1) holds for the headset's
   images.  The meta-json live only beside the web's images (the
   export copies the PNG, not the meta), so a copy passes when the
   web's meta lists its original with shape_change >= the threshold,
   and an atlas passes when every cell it is built from does.  Running
   check_delta.py on godot/art/derived alone fails every image with "no
   meta-json lists this image": that is the missing meta beside the
   copy, not a sprite without its proof.

Usage:
    python3 scripts/ci/check_shared_copies.py [--threshold 0.35]
"""

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts' / 'raw_assets'))
import check_delta  # noqa: E402

GODOT_DATA = ROOT / 'godot' / 'data'
WEB_DATA = ROOT / 'public' / 'ludus' / 'data'
GODOT_ART = ROOT / 'godot' / 'art' / 'derived'
WEB_ART = ROOT / 'public' / 'ludus' / 'art' / 'derived'
FISH_INDEX = GODOT_DATA / 'fish-drawings.json'
# Same-named files that differ on purpose, each with its reason and the
# check that keeps it current instead of a byte comparison.
OWN_PAGE = {
    'rights.json': 'scripts/build_rights_manifest.py writes the headset '
                   'its own page (what the APK holds); --check there',
}


def rel(path):
    return path.relative_to(ROOT)


def shared_json():
    """Problems with JSON the two versions share, and how many matched."""
    problems, same = [], 0
    for ours in sorted(GODOT_DATA.rglob('*.json')):
        web = WEB_DATA / ours.relative_to(GODOT_DATA)
        if not web.exists():
            continue
        if str(ours.relative_to(GODOT_DATA)) in OWN_PAGE:
            continue
        if ours.read_bytes() == web.read_bytes():
            same += 1
        else:
            problems.append(f'{rel(ours)} differs from {rel(web)}')
    return problems, same


def atlases():
    """Map each headset atlas to the web images it is built from."""
    if not FISH_INDEX.exists():
        return {}
    index = json.loads(FISH_INDEX.read_text(encoding='utf-8'))
    slot_root = GODOT_ART
    return {slot_root / kit['atlas']: [WEB_ART / f for f in kit['files']]
            for kit in index.get('kits', [])}


def derived_art(threshold):
    """Problems with the headset's derived images, and the counts."""
    if not GODOT_ART.is_dir():
        return [], 0, 0
    listed, problems = check_delta.load_meta(WEB_ART)
    by_atlas = atlases()

    def proven(web_image):
        variant = listed.get(web_image)
        if variant is None:
            return f'{rel(web_image)}: no meta-json lists this image'
        shape = variant.get('shape_change')
        if not isinstance(shape, (int, float)) or shape < threshold:
            return f'{rel(web_image)}: shape_change {shape} < {threshold}'
        return ''

    copies = atlas_count = 0
    for image in sorted(GODOT_ART.rglob('*')):
        if image.suffix.lower() not in check_delta.IMAGE_SUFFIXES:
            continue
        web = WEB_ART / image.relative_to(GODOT_ART)
        if image in by_atlas:
            atlas_count += 1
            for cell in by_atlas[image]:
                if not cell.exists():
                    problems.append(f'{rel(image)}: cell {rel(cell)} '
                                    f'is not shipped')
                elif proven(cell):
                    problems.append(f'{rel(image)}: {proven(cell)}')
            continue
        if not web.exists():
            problems.append(f'{rel(image)}: neither a copy of a web image '
                            f'nor an atlas in {rel(FISH_INDEX)}')
            continue
        if image.read_bytes() != web.read_bytes():
            problems.append(f'{rel(image)} differs from {rel(web)}')
            continue
        copies += 1
        if proven(web):
            problems.append(f'{rel(image)}: {proven(web)}')
    for atlas in by_atlas:
        if not atlas.exists():
            problems.append(f'{rel(atlas)}: listed in {rel(FISH_INDEX)} '
                            f'but not shipped')
    return problems, copies, atlas_count


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--threshold', type=float, default=0.35)
    args = parser.parse_args(argv)
    json_problems, same = shared_json()
    art_problems, copies, atlas_count = derived_art(args.threshold)
    problems = json_problems + art_problems
    print(f'check_shared_copies: {same} shared JSON identical; '
          f'{copies} derived images are byte copies of the web\'s, '
          f'{atlas_count} are atlases; gate shape_change >= '
          f'{args.threshold}')
    if problems:
        print(f'check_shared_copies: {len(problems)} problem(s)')
        for line in problems:
            print(f'  {line}')
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
