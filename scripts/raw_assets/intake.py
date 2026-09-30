"""Collect raw image assets from the open-source games listed in backlog.

The operator's rule (CLAUDE.md, TABOO 0.4) treats third-party art as raw
material: it may enter Ludus only after a measured transformation of at
least 35 % and with its licence recorded.  This script is step one: it
fetches images plus licence files, and nothing else, so a runner never
downloads whole game source trees.

Non-game images (screenshots, splash screens, promo, docs, examples)
are no longer dropped in silence (CLAUDE.md TABOO 0.012).  Holy things,
the stop-list and fonts stay refused.  The rest goes to the props store
through props.take, the same guard and register as the hourly pass,
when a deficit slot is named with --props-slot: TABOO 0.35 p. 4 takes
nothing without a named slot, so without one they are counted and
listed in props-pending.json, not fetched into the store.

Usage:
    python3 scripts/raw_assets/intake.py --out build/raw --max-repos 5 \
        [--props-slot DEF-056 --props-cache /home/user/raw-props]
"""

import argparse
import datetime
import json
import re
import subprocess
import sys
from pathlib import Path

import licences

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


def collect_props(repo_dir):
    """Non-game images of a clone that may go to the props store.

    No size filter and no per-repo cap: the store takes everything the
    guard allows, and the register budget is its only stop-line.
    """
    # Imported here: osint_cycle imports this module.
    import osint_cycle

    found = []
    for p in sorted(repo_dir.rglob('*')):
        rel = str(p.relative_to(repo_dir))
        if (p.suffix.lower() in IMAGE_SUFFIXES and '.git' not in p.parts
                and p.is_file() and osint_cycle.is_prop(rel)):
            found.append(rel)
    return found


def file_licence(url, repo_dir, spdx, license_file, path):
    """The licence of one file: the repo's guess, refined per path.

    The reviewed per-path rules and a Debian copyright file (licences.py)
    say more than the top-level guess: rotp-public's art is CC BY-NC-ND
    under a GPL code licence.
    """
    if not license_file:
        return spdx
    text = (repo_dir / license_file).read_text(encoding='utf-8',
                                               errors='ignore')
    base = spdx
    if licences.head_licence(text[:600]) == licences.DEP5:
        base = licences.DEP5
    return licences.path_licence(url, path, base, text)


def shelve(pending, out, slot, cache, register_path):
    """Put the pending non-game images of this run on the shelf."""
    import props

    if not re.fullmatch(r'DEF-\d{3}', slot):
        raise SystemExit(f'--props-slot {slot!r}: a deficit id, DEF-nnn')
    stamp = datetime.datetime.now(datetime.timezone.utc)
    register = props.load_register(register_path)
    lic = {(h['repo'], h['path']): h.pop('licence') for h in pending}
    stats = props.take([(h, slot) for h in pending], register, out, cache,
                       'intake-' + stamp.strftime('%Y-%m-%dT%H:%M:%SZ'),
                       lambda h: lic[(h['repo'], h['path'])],
                       lambda path: True)
    size = props.save_register(register, register_path)
    print(f'props: taken {stats["taken"]} duplicates '
          f'{stats["duplicates"]} refused {stats["refused"]} errors '
          f'{stats["errors"]}; register {size} B')
    return stats


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
    parser.add_argument('--props-slot', default='',
                        help='deficit id the non-game images are taken '
                             'for (TABOO 0.012; without it they are only '
                             'listed)')
    parser.add_argument('--props-cache', default='/home/user/raw-props')
    parser.add_argument('--props-register', default=None,
                        help='register file (default: the repo one)')
    args = parser.parse_args()

    out = Path(args.out)
    clones = out / 'clones'
    clones.mkdir(parents=True, exist_ok=True)

    urls = repos_from_backlog(args.backlog)
    if args.only:
        urls = [u for u in urls if any(u.endswith(o) for o in args.only)]
    urls = urls[:args.max_repos]

    manifest, pending = [], []
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
            rel = str(img.relative_to(dest))
            own = file_licence(url, dest, spdx, license_file, rel)
            if not licences.derivable(own):
                # No derivative of NC/ND art, of an unread licence or of
                # a repo without one: the pipeline makes derivatives.
                print(f'skip {rel}: {own} allows no derivative')
                continue
            manifest.append({
                'repo': url,
                'commit': sha,
                'license': own,
                'license_file': license_file,
                'path': rel,
                'local': str(img),
                'bytes': img.stat().st_size,
            })
        if license_file:
            for rel in collect_props(dest):
                pending.append({
                    'repo': url, 'commit': sha,
                    'license_file': license_file, 'path': rel,
                    'kind': 'image', 'hits': [], 'attribution': [],
                    'licence': file_licence(url, dest, spdx, license_file,
                                            rel)})
        print(f'{url}: licence={spdx} images='
              f'{sum(1 for m in manifest if m["repo"] == url)} props='
              f'{sum(1 for h in pending if h["repo"] == url)}')

    (out / 'manifest.json').write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding='utf-8')
    print(f'manifest: {len(manifest)} images -> {out / "manifest.json"}')
    if args.props_slot:
        import props
        shelve(pending, out, args.props_slot, args.props_cache,
               args.props_register or props.REGISTER)
    else:
        (out / 'props-pending.json').write_text(
            json.dumps(pending, ensure_ascii=False, indent=1),
            encoding='utf-8')
        print(f'props: {len(pending)} non-game images listed in '
              f'{out / "props-pending.json"}, not taken: no --props-slot '
              '(TABOO 0.35 p. 4)')


if __name__ == '__main__':
    main()
