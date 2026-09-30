"""Search the 99-repo index for raw material that fills a game deficit.

Step between the index (index_repos.py) and the transform: given the
keywords of a deficit (docs/DEFICITS_99_*.md), list candidate files by
repository, kind and licence.  Nothing is downloaded here.

Two licence facts found while building the index shape this module:
  * the top-level licence is often only the code licence; art and sound
    carry their own terms in per-folder attribution files (for example
    space-station-14 is MIT for code, while its audio lists authors and
    CC licences next to the files), so those files are listed too;
  * a repository without any licence file is "all rights reserved", so
    its files are excluded unless --allow-unlicensed is given.

Usage:
    python3 scripts/raw_assets/search_index.py --index /home/user/raw-repos \
        --kind audio --keywords bell chime church --limit 20
"""

import argparse
import json
import re
from pathlib import Path

ATTRIBUTION = re.compile(
    r'(attribution|credits|copying|licen[cs]e|authors)[^/]*\.'
    r'(ya?ml|txt|md|json)$', re.IGNORECASE)


def load_index(root):
    """Yield (header, records) for every indexed repository."""
    for path in sorted(Path(root, 'index').glob('*.jsonl')):
        lines = path.read_text(encoding='utf-8').splitlines()
        header = json.loads(lines[0])['header']
        yield header, [json.loads(line) for line in lines[1:]]


def attribution_files(records, folder):
    """Attribution files in the folder of a match or any parent folder."""
    parts = Path(folder).parts
    parents = {str(Path(*parts[:i])) for i in range(len(parts) + 1)}
    parents.add('.')
    return [r['path'] for r in records
            if ATTRIBUTION.search(r['path'])
            and str(Path(r['path']).parent) in parents]


def search(root, kinds, keywords, limit, allow_unlicensed):
    """Score every file by how many keywords its path contains."""
    words = [w.lower() for w in keywords]
    # Whole words only: "pike" once matched "pikeman", so a fish slot got
    # soldiers.  A key may carry a plural ending (fish -> fishes).
    patterns = {w: re.compile(r'(^|[^a-z])' + re.escape(w)
                              + r'(e?s)?([^a-z]|$)') for w in words}
    results = []
    for header, records in load_index(root):
        if not header['license_file'] and not allow_unlicensed:
            continue
        for rec in records:
            if kinds and rec['kind'] not in kinds:
                continue
            low = rec['path'].lower()
            hits = [w for w in words if patterns[w].search(low)]
            if not hits:
                continue
            results.append({
                'repo': header['repo'],
                'commit': header['commit'],
                'license_file': header['license_file'],
                'path': rec['path'],
                'kind': rec['kind'],
                'hits': hits,
                'score': len(hits),
            })
    results.sort(key=lambda r: (-r['score'], r['repo'], r['path']))
    results = results[:limit]
    by_repo = {h['repo']: recs for h, recs in load_index(root)}
    for res in results:
        res['attribution'] = attribution_files(
            by_repo[res['repo']], str(Path(res['path']).parent))[:5]
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--index', default='/home/user/raw-repos')
    parser.add_argument('--kind', nargs='*', default=[])
    parser.add_argument('--keywords', nargs='+', required=True)
    parser.add_argument('--limit', type=int, default=30)
    parser.add_argument('--allow-unlicensed', action='store_true')
    parser.add_argument('--json', action='store_true')
    args = parser.parse_args()

    found = search(args.index, set(args.kind), args.keywords, args.limit,
                   args.allow_unlicensed)
    if args.json:
        print(json.dumps(found, ensure_ascii=False, indent=2))
        return
    for res in found:
        repo = res['repo'].split('github.com/')[-1]
        attr = f' attr={res["attribution"]}' if res['attribution'] else ''
        print(f'{res["score"]} {res["kind"]:5} {repo}: {res["path"]}'
              f' [{res["license_file"]}]{attr}')


if __name__ == '__main__':
    main()
