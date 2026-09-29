"""Collect raw image assets from the open-source games listed in backlog.

The operator's rule (CLAUDE.md, TABOO 0.4) treats third-party art as raw
material: it may enter Ludus only after a measured transformation of at
least 35 % and with its licence recorded.  This script is step one: it
fetches images plus licence files, and nothing else, so a runner never
downloads whole game source trees.

Usage:
    python3 scripts/raw_assets/intake.py --out build/raw --max-repos 5
"""

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

REPO_URL = re.compile(r'https://github\.com/[\w.-]+/[\w.-]+')
IMAGE_SUFFIXES = {'.png', '.svg'}
LICENSE_NAMES = ('LICENSE', 'LICENCE', 'COPYING', 'COPYRIGHT')

# Sparse patterns keep the clone to images and licence texts only.
SPARSE_PATTERNS = ['/*LICEN*', '/*COPYING*', '/*COPYRIGHT*',
                   '*.png', '*.svg']

OBJECT_WORDS = ('sprite', 'item', 'tile', 'character', 'hero', 'monster',
                'npc', 'unit', 'portrait', 'building', 'terrain', 'icon',
                'object', 'prop', 'effect')
EXCLUDE_WORDS = ('metadata', 'screenshot', 'splash', 'store', 'promo',
                 'feature', 'banner', 'logo', 'test', 'font')

# Order matters: the more specific identifiers are checked first, so
# "LGPL" is not reported as "GPL".
LICENSE_MARKERS = [
    ('AGPL-3.0', 'GNU AFFERO GENERAL PUBLIC LICENSE'),
    ('LGPL', 'GNU LESSER GENERAL PUBLIC LICENSE'),
    ('GPL-3.0', 'GNU GENERAL PUBLIC LICENSE\n *Version 3'),
    ('GPL-2.0', 'GNU GENERAL PUBLIC LICENSE\n *Version 2'),
    ('MPL-2.0', 'Mozilla Public License Version 2.0'),
    ('CC-BY-SA', 'Creative Commons Attribution-ShareAlike'),
    ('CC0-1.0', 'CC0 1.0 Universal'),
    ('MIT', 'Permission is hereby granted, free of charge'),
    ('Apache-2.0', 'Apache License'),
]


def repos_from_backlog(backlog_path):
    """Return the unique GitHub repository URLs in backlog order."""
    text = Path(backlog_path).read_text(encoding='utf-8', errors='ignore')
    seen = []
    for url in REPO_URL.findall(text):
        url = url.rstrip('.')
        if url not in seen:
            seen.append(url)
    return seen


def run(cmd, cwd=None):
    """Run a git command and fail loudly, since a silent partial clone
    would be recorded as an empty repository."""
    subprocess.run(cmd, cwd=cwd, check=True, stdout=subprocess.DEVNULL,
                   stderr=subprocess.PIPE, timeout=600)


def sparse_clone(url, dest):
    """Shallow, blob-filtered, sparse clone of images and licences."""
    if (dest / '.git').exists():
        return
    run(['git', 'clone', '--depth', '1', '--filter=blob:none',
         '--no-checkout', '--quiet', url, str(dest)])
    run(['git', 'sparse-checkout', 'set', '--no-cone', *SPARSE_PATTERNS],
        cwd=dest)
    run(['git', 'checkout', '--quiet'], cwd=dest)


def detect_license(repo_dir):
    """Guess the SPDX id from the top-level licence file.

    A guess is still only a guess, so the raw text path is recorded too
    and a human confirms it before anything ships.
    """
    for path in sorted(repo_dir.iterdir()):
        if not path.name.upper().startswith(LICENSE_NAMES):
            continue
        text = path.read_text(encoding='utf-8', errors='ignore')[:20000]
        for spdx, marker in LICENSE_MARKERS:
            if re.search(marker, text, re.IGNORECASE):
                return spdx, path.name
        return 'UNKNOWN', path.name
    return 'NOASSERTION', None


def head_sha(repo_dir):
    """Pin the exact upstream revision for the licence register."""
    out = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=repo_dir,
                         check=True, capture_output=True, text=True)
    return out.stdout.strip()


def is_game_object(path):
    """True for in-game art, false for store pages and screenshots.

    The first trial run picked the largest files, which turned out to be
    store screenshots and splash screens rather than heroes or items.
    """
    low = str(path).lower()
    if any(word in low for word in EXCLUDE_WORDS):
        return False
    return any(word in low for word in OBJECT_WORDS)


def collect_images(repo_dir, per_repo, min_bytes, max_bytes):
    """Pick the largest in-game images first."""
    images = [p for p in repo_dir.rglob('*')
              if p.suffix.lower() in IMAGE_SUFFIXES
              and '.git' not in p.parts
              and is_game_object(p.relative_to(repo_dir))
              and min_bytes <= p.stat().st_size <= max_bytes]
    images.sort(key=lambda p: p.stat().st_size, reverse=True)
    return images[:per_repo]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--backlog', default='backlog')
    parser.add_argument('--out', default='build/raw')
    parser.add_argument('--max-repos', type=int, default=5)
    parser.add_argument('--per-repo', type=int, default=20)
    parser.add_argument('--only', nargs='*', default=None,
                        help='owner/name filters, e.g. tmewett/BrogueCE')
    parser.add_argument('--min-bytes', type=int, default=2048)
    parser.add_argument('--max-bytes', type=int, default=2_000_000)
    args = parser.parse_args()

    out = Path(args.out)
    clones = out / 'clones'
    clones.mkdir(parents=True, exist_ok=True)

    urls = repos_from_backlog(args.backlog)
    if args.only:
        urls = [u for u in urls if any(u.endswith(o) for o in args.only)]
    urls = urls[:args.max_repos]

    manifest = []
    for url in urls:
        name = url.rsplit('/', 2)[-2] + '__' + url.rsplit('/', 1)[-1]
        dest = clones / name
        try:
            sparse_clone(url, dest)
        except (subprocess.SubprocessError, OSError) as exc:
            # One broken upstream must not stop the whole intake run.
            print(f'skip {url}: {exc}', file=sys.stderr)
            continue
        spdx, license_file = detect_license(dest)
        sha = head_sha(dest)
        for img in collect_images(dest, args.per_repo, args.min_bytes,
                                  args.max_bytes):
            manifest.append({
                'repo': url,
                'commit': sha,
                'license': spdx,
                'license_file': license_file,
                'path': str(img.relative_to(dest)),
                'local': str(img),
                'bytes': img.stat().st_size,
            })
        print(f'{url}: licence={spdx} images='
              f'{sum(1 for m in manifest if m["repo"] == url)}')

    (out / 'manifest.json').write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding='utf-8')
    print(f'manifest: {len(manifest)} images -> {out / "manifest.json"}')


if __name__ == '__main__':
    main()
