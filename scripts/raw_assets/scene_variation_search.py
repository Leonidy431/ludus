"""Search the 99 cloned repositories for code and objects that serve the
twelve-sets technology (TABOO 0.032, docs/tech/MULTI_ENV_SETS_2026-10-03.
md).

Only the path index is read (index_repos.py made it: trees without
blobs), so the pass costs seconds.  Code is searched by technique:
time of day, scatter and placement, layout generators, seeds and presets,
rejection of bad layouts.  Objects are searched by the names of the
things in our scenes.  A repository without a licence file is never a
source (TABOO 0.15); a holy or dogma-listed path is never taken
(TABOO 0.35 items 5-6).  Nothing is copied: code found here is read and
rewritten in our own words, then measured by code_delta.py (TABOO 0.1),
and an image goes through the runner's pipeline like any raw material.

Usage:
    python3 scripts/raw_assets/scene_variation_search.py \\
        --index /home/user/raw-repos/index \\
        --out docs/RAW_SCENE_VARIATION_SEARCH_2026-10-03.json
"""

import argparse
import json
import re
import sys
from pathlib import Path

CODE_EXT = (".py", ".gd", ".cs", ".lua", ".js", ".ts", ".cpp", ".java",
            ".rs", ".h", ".hpp")
IMAGE_EXT = (".png", ".svg")
# Technique -> pattern over the path (case-insensitive).
TECHNIQUES = {
    "time_of_day": r"time[-_]?of[-_]?day|day[-_]?night|daynight|sun[-_]?"
                   r"(?:path|position)|skybox|ambient[-_]?light",
    "scatter_placement": r"scatter|poisson|jitter|prop[-_]?(?:placement|"
                         r"spawn)|decor(?:ation)?[-_]?(?:place|spawn)|"
                         r"spawner|spawn[-_]?(?:grid|point|area)",
    "layout_generator": r"(?:room|vault|dungeon|level|map|layout)[-_]?"
                        r"(?:gen|generator|builder|maker)|procgen|"
                        r"proced",
    "seed_presets": r"preset|seeded?[-_]?random|random[-_]?seed|"
                    r"variation|variant",
    "validation": r"validat|sanity|constraint|collision[-_]?check|"
                  r"overlap|aabb|bounding[-_]?box",
}
# Objects of our scenes (the cell and the pier): lamp, book, jug, ...
OBJECTS = r"lamp|lantern|candle|book|codex|scroll|jug|amphora|pot|vase|" \
          r"basket|stool|bench|table|rug|mat|inkwell|cup|bowl|barrel|" \
          r"crate|chest|shelf|bucket|rope|net|oar|boat"
# Never taken: the holy and the dogma stop-list (TABOO 0.35 items 5-6).
STOP = r"pentagram|zodiac|occult|sigil|rune|idol|demon|necromanc|halo|" \
       r"church|temple|shrine|altar|priest|satan|cross|icon|saint|" \
       r"bell|relic|holy"


def licence_of(header):
    """The first named line of a repository's licence head, or ''."""
    for line in str(header.get("license_head", "")).splitlines():
        if line.strip():
            return line.strip()[:60]
    return ""


def scan(index_dir, per_group=8):
    """Read every index file once and sort the hits into groups."""
    code = {k: [] for k in TECHNIQUES}
    objects = []
    stop = re.compile(STOP, re.I)
    techs = {k: re.compile(v, re.I) for k, v in TECHNIQUES.items()}
    obj = re.compile(OBJECTS, re.I)
    repos = 0
    for f in sorted(Path(index_dir).glob("*.jsonl")):
        with open(f, encoding="utf-8") as fh:
            header = json.loads(fh.readline())["header"]
            if not header.get("license_file"):
                continue
            repos += 1
            name = f.stem
            lic = licence_of(header)
            for line in fh:
                try:
                    rec = json.loads(line)
                except ValueError:
                    continue
                path = rec.get("path", "")
                if stop.search(path):
                    continue
                low = path.lower()
                if low.endswith(CODE_EXT):
                    for key, pat in techs.items():
                        if pat.search(path):
                            code[key].append((name, path, lic))
                elif low.endswith(IMAGE_EXT) and obj.search(
                        Path(path).stem):
                    objects.append((name, path, lic))
    return repos, code, objects


def summarise(repos, code, objects, per_group):
    """Counts of everything, and a short head of each group."""
    def head(rows):
        seen, out = set(), []
        for name, path, lic in sorted(rows):
            if name in seen:
                continue
            seen.add(name)
            out.append({"repo": name, "path": path, "licence": lic})
            if len(out) >= per_group:
                break
        return out
    return {
        "licensed_repos_read": repos,
        "code": {k: {"hits": len(v), "repos": len({r[0] for r in v}),
                     "one_per_repo": head(v)} for k, v in code.items()},
        "objects": {"hits": len(objects),
                    "repos": len({r[0] for r in objects}),
                    "one_per_repo": head(objects)},
        "rule": "Read and rewrite code; measure with code_delta.py "
                "(>= 35 %). Images only through the runner pipeline. "
                "Nothing here was copied.",
    }


def main(argv):
    """Run the search and write the report."""
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--index", default="/home/user/raw-repos/index")
    ap.add_argument("--out", required=True)
    ap.add_argument("--per-group", type=int, default=8)
    args = ap.parse_args(argv)
    repos, code, objects = scan(args.index, args.per_group)
    report = summarise(repos, code, objects, args.per_group)
    Path(args.out).write_text(json.dumps(report, ensure_ascii=False,
                                         indent=1), encoding="utf-8")
    for key, val in report["code"].items():
        print("%-18s %6d hits in %2d repos" % (key, val["hits"],
                                               val["repos"]))
    print("%-18s %6d hits in %2d repos" % (
        "objects", report["objects"]["hits"], report["objects"]["repos"]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
