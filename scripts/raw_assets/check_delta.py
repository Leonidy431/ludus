"""CI gate: every shipped derived sprite must prove its 35 % reshaping.

A derived asset may ship under public/ludus/art/derived/ only with its
per-sprite meta-json (written by transform.py) listing that file with a
shape change of at least the threshold.  A missing meta, an unlisted
image or a smaller change fails the build with "Требуется Антагонист":
the object is still a recolour and must be replaced by its passion.

Usage:
    python3 scripts/raw_assets/check_delta.py \
        [--root public/ludus/art/derived] [--threshold 0.35]
"""

import argparse
import json
import sys
from pathlib import Path

MESSAGE = 'Требуется Антагонист'
IMAGE_SUFFIXES = {'.png', '.webp', '.jpg', '.jpeg', '.gif', '.svg'}


def load_meta(root):
    """Map each image path listed by a meta-json to its variant entry."""
    listed, problems = {}, []
    for meta_path in sorted(root.rglob('*.json')):
        try:
            meta = json.loads(meta_path.read_text(encoding='utf-8'))
        except (OSError, ValueError) as exc:
            problems.append(f'{meta_path}: unreadable meta ({exc})')
            continue
        if not isinstance(meta, dict) or 'variants' not in meta:
            continue
        for variant in meta['variants']:
            listed[meta_path.parent / variant['file']] = variant
    return listed, problems


def check(root, threshold):
    """Return the list of problems; empty means the gate passes."""
    listed, problems = load_meta(root)
    for image in sorted(root.rglob('*')):
        if image.suffix.lower() not in IMAGE_SUFFIXES:
            continue
        variant = listed.get(image)
        if variant is None:
            problems.append(f'{image}: no meta-json lists this image')
            continue
        shape = variant.get('shape_change')
        if not isinstance(shape, (int, float)) or shape < threshold:
            problems.append(f'{image}: shape_change {shape} < {threshold}')
    for path in listed:
        if not path.exists():
            problems.append(f'{path}: listed in meta but not shipped')
    return problems


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', default='public/ludus/art/derived')
    parser.add_argument('--threshold', type=float, default=0.35)
    args = parser.parse_args(argv)

    root = Path(args.root)
    if not root.is_dir():
        # Nothing derived is shipped yet, so nothing can break the rule.
        print(f'check_delta: {root} absent, no derived assets shipped')
        return 0
    problems = check(root, args.threshold)
    if problems:
        print(f'{MESSAGE}: {len(problems)} problem(s)')
        for line in problems:
            print(f'  {MESSAGE}: {line}')
        return 1
    print(f'check_delta: all derived assets under {root} carry meta with '
          f'shape_change >= {args.threshold}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
