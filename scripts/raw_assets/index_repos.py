"""Index every repository from backlog without downloading its content.

The 99 games in backlog weigh many gigabytes in total, far more than a
sandbox or CI runner can hold.  A blobless, no-checkout clone fetches only
commits and trees, so `git ls-tree` can list every file.
The deficit search then runs over this index, and only the files that
are actually chosen are fetched later (git fetches missing blobs on
demand).  Only licence texts are read now, because every later step must
know the licence of what it touches (CLAUDE.md, TABOO 0.1).

Usage:
    python3 scripts/raw_assets/index_repos.py --out /home/user/raw-repos \
        --jobs 4
"""

import argparse
import json
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from intake import LICENSE_NAMES, repos_from_backlog

KINDS = {
    'image': {'.png', '.svg', '.jpg', '.jpeg', '.webp', '.gif', '.bmp',
              '.tga', '.dds', '.psd', '.xcf', '.ora', '.kra'},
    'audio': {'.ogg', '.wav', '.mp3', '.flac', '.opus', '.mid', '.midi',
              '.it', '.xm', '.mod', '.s3m', '.spc'},
    'model': {'.glb', '.gltf', '.obj', '.fbx', '.blend', '.dae', '.mesh'},
    'code': {'.c', '.cc', '.cpp', '.h', '.hpp', '.cs', '.java', '.kt',
             '.js', '.ts', '.lua', '.py', '.gd', '.rs', '.go'},
    'data': {'.json', '.xml', '.yaml', '.yml', '.cfg', '.ini', '.txt',
             '.csv', '.toml'},
    'shader': {'.glsl', '.frag', '.vert', '.hlsl', '.shader', '.gdshader'},
}


def kind_of(path):
    """Classify a path by extension for the deficit search."""
    suffix = Path(path).suffix.lower()
    for kind, suffixes in KINDS.items():
        if suffix in suffixes:
            return kind
    return 'other'


def git(args, cwd=None, timeout=900):
    return subprocess.run(['git', *args], cwd=cwd, check=True,
                          capture_output=True, text=True, timeout=timeout)


def index_one(url, root):
    """Clone trees only, list files, and read the licence text."""
    name = url.rsplit('/', 2)[-2] + '__' + url.rsplit('/', 1)[-1]
    dest = root / 'clones' / name
    out = root / 'index' / f'{name}.jsonl'
    if out.exists():
        return name, 'cached', None
    try:
        if not (dest / '.git').exists():
            git(['clone', '--depth', '1', '--filter=blob:none',
                 '--no-checkout', '--quiet', url, str(dest)])
        sha = git(['rev-parse', 'HEAD'], cwd=dest).stdout.strip()
        # No -l: object sizes would make git download every blob of the
        # blobless clone one by one, which defeats the whole design.
        listing = git(['ls-tree', '-r', 'HEAD'], cwd=dest).stdout
        licence = None
        records = []
        for line in listing.splitlines():
            meta, path = line.split('\t', 1)
            _mode, otype, _obj = meta.split()
            if otype != 'blob':
                continue
            if '/' not in path and path.upper().startswith(LICENSE_NAMES):
                # One small blob per repo; it decides what may be used.
                licence = licence or path
            records.append({'path': path, 'kind': kind_of(path)})
        licence_text = ''
        if licence:
            licence_text = git(['show', f'HEAD:{licence}'],
                               cwd=dest).stdout[:20000]
        header = {'repo': url, 'commit': sha, 'license_file': licence,
                  'license_head': licence_text[:600],
                  'files': len(records)}
        with out.open('w', encoding='utf-8') as fh:
            fh.write(json.dumps({'header': header}, ensure_ascii=False)
                     + '\n')
            for rec in records:
                fh.write(json.dumps(rec, ensure_ascii=False) + '\n')
        return name, 'ok', len(records)
    except (subprocess.SubprocessError, OSError, ValueError) as exc:
        # A failed repo is recorded, never silently skipped, so the
        # index report shows exactly what is missing.
        detail = getattr(exc, 'stderr', '') or str(exc)
        return name, 'error', str(detail).strip()[:300]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--backlog', default='backlog')
    parser.add_argument('--out', default='build/raw-repos')
    parser.add_argument('--jobs', type=int, default=4)
    args = parser.parse_args()

    root = Path(args.out)
    (root / 'clones').mkdir(parents=True, exist_ok=True)
    (root / 'index').mkdir(parents=True, exist_ok=True)
    urls = repos_from_backlog(args.backlog)

    report = []
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        for name, status, detail in pool.map(
                lambda u: index_one(u, root), urls):
            report.append({'repo': name, 'status': status,
                           'detail': detail})
            print(f'{status:6} {name} {detail if detail else ""}',
                  flush=True)
    (root / 'index-report.json').write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    failed = [r for r in report if r['status'] == 'error']
    print(f'indexed {len(report) - len(failed)}/{len(report)}; '
          f'failed {len(failed)}')
    sys.exit(0)


if __name__ == '__main__':
    main()
