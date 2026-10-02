"""Clone the 99 repositories of backlog with their working files.

The operator asked for every repository to be cloned for quick access to
its content (2026-10-02), not only indexed.  The sandbox disk is small
(a few gigabytes free), and one game alone (0 A.D.) weighs more than
that, so the clone is bounded and says so instead of pretending:

* only the last revision (--depth 1), no history;
* files larger than --max-blob are left out of the checkout
  (--filter=blob:limit), so sprites, sounds, maps and code come, and
  movie and archive blobs stay on GitHub;
* the run stops before the free space falls under --keep-free, and the
  report names every repository it did not reach.

Repositories go to <dest>/<owner>__<name>.  A repository already cloned
is kept as it is.  The report is <dest>/clone-report.json; nothing here
is copied into the game: raw material still passes the runner (CLAUDE.md
TABOO 0.1, 0.012, 0.15).

Constitution: ФОРМА (the material of 99 games as it is, with its rights)
→ ДЕЙСТВИЕ (keep it at hand, bounded by the disk) → ЦЕЛЬ (find what a
scene lacks before drawing or synthesising it anew).
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from intake import repos_from_backlog  # noqa: E402


def free_bytes(path):
    """Free bytes on the disk that holds path."""
    return shutil.disk_usage(path).free


def dir_bytes(path):
    """Bytes of files under path, without following links."""
    total = 0
    for root, _dirs, files in os.walk(path):
        for f in files:
            p = os.path.join(root, f)
            if not os.path.islink(p):
                total += os.path.getsize(p)
    return total


def clone(url, dest, max_blob, timeout):
    """Clone one repository; return (status, seconds)."""
    t0 = time.time()
    cmd = ['git', 'clone', '--quiet', '--depth', '1',
           '--filter=blob:limit=%s' % max_blob, url, dest]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True,
                           timeout=timeout)
    except subprocess.TimeoutExpired:
        shutil.rmtree(dest, ignore_errors=True)
        return 'timeout', time.time() - t0
    if r.returncode != 0:
        shutil.rmtree(dest, ignore_errors=True)
        return 'error: ' + r.stderr.strip().splitlines()[-1][:200] \
            if r.stderr.strip() else 'error', time.time() - t0
    return 'ok', time.time() - t0


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--backlog', default='backlog')
    parser.add_argument('--dest', default='/home/user/raw-repos/full')
    parser.add_argument('--max-blob', default='2m')
    parser.add_argument('--keep-free', type=float, default=1.5,
                        help='stop below this many GiB free')
    parser.add_argument('--timeout', type=int, default=900)
    args = parser.parse_args()

    os.makedirs(args.dest, exist_ok=True)
    keep = int(args.keep_free * 1024 ** 3)
    rows = []
    for url in repos_from_backlog(args.backlog):
        owner, name = url.rstrip('/').split('/')[-2:]
        dest = os.path.join(args.dest, '%s__%s' % (owner, name))
        row = {'url': url, 'path': dest}
        if os.path.isdir(os.path.join(dest, '.git')):
            row.update(status='kept', bytes=dir_bytes(dest))
        elif free_bytes(args.dest) < keep:
            row.update(status='not reached: disk under %.1f GiB free'
                       % args.keep_free)
        else:
            status, secs = clone(url, dest, args.max_blob, args.timeout)
            row.update(status=status, seconds=round(secs, 1))
            if status == 'ok':
                row['bytes'] = dir_bytes(dest)
            # A clone that crossed the line is kept, but the next one
            # is not started (checked at the top of the loop).
        rows.append(row)
        print('%-60s %s' % (url, row['status']), flush=True)

    done = [r for r in rows if r['status'] in ('ok', 'kept')]
    report = {
        'max_blob': args.max_blob,
        'keep_free_gib': args.keep_free,
        'repos': len(rows),
        'cloned': len(done),
        'bytes': sum(r.get('bytes', 0) for r in done),
        'free_after': free_bytes(args.dest),
        'rows': rows,
    }
    with open(os.path.join(args.dest, 'clone-report.json'), 'w') as f:
        json.dump(report, f, indent=1, ensure_ascii=False)
    print('cloned %d of %d, %.2f GiB; free %.2f GiB' % (
        report['cloned'], report['repos'], report['bytes'] / 1024 ** 3,
        report['free_after'] / 1024 ** 3))


if __name__ == '__main__':
    main()
