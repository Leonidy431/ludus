"""Pull the 99 repositories' raw material in chunks of at most 100 MB,
clean it, and (only with --push) put each chunk on its own branch,
deleting the clone and the chunk after every step (TABOO 0.033).

Why chunks: the sandbox disk is a fixed allowance and a scheduled run on
the CI runner would hold the queue for hours.  A step is: sparse-fetch one
repository (licence file plus the wanted types, no history), clean it,
write it into the current chunk with a manifest, and remove the clone.  A
chunk closes when the next repository would pass the limit; closing it
writes `chunk-NNN.manifest.json`, merges the chunk into the one summary
under a lock (a chunk only ever adds its own key, so nothing is
overwritten), and with --push commits and pushes it.

Cleaning: no repository without a licence file (TABOO 0.15); no holy or
dogma-listed path (TABOO 0.35 items 5-6); only the wanted file types;
no file above MAX_FILE_MB; no `.git`.  Every file is listed with its
SHA-256 and its repository's licence head, so the licence register
(TABOO 0.1) can be filled from the manifest.  Nothing here reaches the
game or the APK: raw material enters the game only through the runner's
pipeline (TABOO 0.1, 0.012).

Usage (a dry run is the default: nothing is pushed):
    python3 scripts/raw_assets/corpus_chunks.py --only NAME [--only ...]
    python3 scripts/raw_assets/corpus_chunks.py --push --branch \\
        corpus/new-el-korpus-raw
"""

import argparse
import fcntl
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
INDEX = Path("/home/user/raw-repos/index")
WORK = ROOT / "build" / "corpus"
CHUNK_MB = 100
MAX_FILE_MB = 5
TYPES = (".png", ".svg")
CODE_TYPES = (".py", ".gd", ".cs", ".lua", ".js", ".ts", ".java", ".rs",
              ".cpp", ".h", ".hpp")
LICENCE_GLOBS = ("LICEN", "COPYING", "COPYRIGHT")
STOP = re.compile(r"pentagram|zodiac|occult|sigil|rune|idol|demon|"
                  r"necromanc|halo|church|temple|shrine|altar|priest|"
                  r"satan|cross|icon|saint|bell|relic|holy", re.I)


def sha256(path):
    """The SHA-256 of a file, read in blocks."""
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for block in iter(lambda: fh.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def run(cmd, cwd=None):
    """Run a command quietly; return its output or raise."""
    return subprocess.run(cmd, cwd=cwd, check=True, capture_output=True,
                          text=True).stdout


def list_repos(only):
    """Licensed repositories from the path index: (name, url, commit)."""
    out = []
    for f in sorted(INDEX.glob("*.jsonl")):
        if only and f.stem not in only:
            continue
        with open(f, encoding="utf-8") as fh:
            header = json.loads(fh.readline())["header"]
        if header.get("license_file"):
            out.append((f.stem, header["repo"], header["commit"]))
    return out


def wanted(path, types):
    """Is this path a file the corpus takes?"""
    low = path.lower()
    base = os.path.basename(path).upper()
    if any(base.startswith(g) for g in LICENCE_GLOBS) and "/" not in path:
        return True
    return low.endswith(types) and not STOP.search(path)


def fetch(name, url, commit, dest, types):
    """Sparse-fetch one repository into `dest` (no history, no .git)."""
    if dest.exists():
        shutil.rmtree(dest)
    run(["git", "clone", "--depth", "1", "--filter=blob:none",
         "--no-checkout", url, str(dest)])
    files = run(["git", "ls-tree", "-r", "--name-only", "HEAD"],
                cwd=dest).splitlines()
    take = [p for p in files if wanted(p, types)]
    if take:
        run(["git", "sparse-checkout", "init", "--no-cone"], cwd=dest)
        (dest / ".git" / "info" / "sparse-checkout").write_text(
            "\n".join("/" + p for p in take) + "\n", encoding="utf-8")
        run(["git", "checkout", "HEAD"], cwd=dest)
    head = run(["git", "rev-parse", "HEAD"], cwd=dest).strip()
    shutil.rmtree(dest / ".git")
    return head


def clean(dest):
    """Drop files above the limit; return [(relative path, bytes)]."""
    kept = []
    for p in sorted(dest.rglob("*")):
        if p.is_file():
            size = p.stat().st_size
            if size > MAX_FILE_MB * (1 << 20):
                p.unlink()
            else:
                kept.append((str(p.relative_to(dest)), size))
    return kept


def merge_summary(summary_path, chunk_id, entry):
    """Add one chunk to the summary under a lock; never replace others."""
    summary_path.parent.mkdir(parents=True, exist_ok=True)
    with open(summary_path.with_suffix(".lock"), "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        data = {"chunks": {}}
        if summary_path.exists():
            data = json.loads(summary_path.read_text(encoding="utf-8"))
        if chunk_id in data["chunks"]:
            raise SystemExit("chunk %s is already in the summary" % chunk_id)
        data["chunks"][chunk_id] = entry
        data["total_bytes"] = sum(c["bytes"] for c in
                                  data["chunks"].values())
        tmp = summary_path.with_suffix(".tmp")
        tmp.write_text(json.dumps(data, ensure_ascii=False, indent=1),
                       encoding="utf-8")
        os.replace(tmp, summary_path)


def write_manifest(chunk_dir, chunk_id, repos):
    """Write the chunk's manifest atomically and return its totals."""
    files = 0
    total = 0
    for r in repos:
        files += len(r["files"])
        total += sum(f["bytes"] for f in r["files"])
    manifest = {"chunk": chunk_id, "repos": repos, "files": files,
                "bytes": total}
    path = chunk_dir.parent / ("%s.manifest.json" % chunk_id)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(manifest, ensure_ascii=False, indent=1),
                   encoding="utf-8")
    os.replace(tmp, path)
    names = [r["repo"] for r in repos]
    return {"files": files, "bytes": total, "repos": names}


def push_chunk(chunk_id, chunk_dir, branch):
    """Commit a chunk on its own branch and push it (only with --push)."""
    wt = WORK / "wt"
    if wt.exists():
        shutil.rmtree(wt)
    run(["git", "worktree", "prune"], cwd=ROOT)
    try:
        run(["git", "fetch", "origin", branch], cwd=ROOT)
        run(["git", "worktree", "add", "-B", branch, str(wt),
             "origin/" + branch], cwd=ROOT)
    except subprocess.CalledProcessError:
        run(["git", "worktree", "add", "--detach", str(wt), "HEAD"],
            cwd=ROOT)
        run(["git", "checkout", "--orphan", branch], cwd=wt)
        run(["git", "rm", "-rf", "--quiet", "."], cwd=wt)
    shutil.copytree(chunk_dir, wt / "corpus" / chunk_id)
    shutil.copy(chunk_dir.parent / ("%s.manifest.json" % chunk_id),
                wt / "corpus" / ("%s.manifest.json" % chunk_id))
    run(["git", "add", "corpus"], cwd=wt)
    run(["git", "commit", "-q", "-m", "corpus: raw chunk %s" % chunk_id],
        cwd=wt)
    run(["git", "push", "-u", "origin", branch], cwd=wt)
    run(["git", "worktree", "remove", "--force", str(wt)], cwd=ROOT)


def main(argv):
    """Plan, fetch, clean and close chunks."""
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--only", action="append", default=[])
    ap.add_argument("--code", action="store_true",
                    help="also take source code files")
    ap.add_argument("--chunk-mb", type=int, default=CHUNK_MB)
    ap.add_argument("--push", action="store_true")
    ap.add_argument("--branch", default="corpus/new-el-korpus-raw")
    ap.add_argument("--work", default=str(WORK))
    args = ap.parse_args(argv)
    work = Path(args.work)
    types = TYPES + (CODE_TYPES if args.code else ())
    summary = work / "corpus-summary.json"
    done = set()
    if summary.exists():
        for c in json.loads(summary.read_text("utf-8"))["chunks"].values():
            done.update(c["repos"])
    limit = args.chunk_mb * (1 << 20)
    chunk_no = len(json.loads(summary.read_text("utf-8"))["chunks"]) \
        if summary.exists() else 0
    open_repos, open_bytes = [], 0

    def close():
        nonlocal chunk_no, open_repos, open_bytes
        if not open_repos:
            return
        cid = "chunk-%03d" % chunk_no
        cdir = work / cid
        entry = write_manifest(cdir, cid, open_repos)
        merge_summary(summary, cid, entry)
        print("%s: %d repos, %d files, %.1f MB"
              % (cid, len(entry["repos"]), entry["files"],
                 entry["bytes"] / 1e6))
        if args.push:
            push_chunk(cid, cdir, args.branch)
            shutil.rmtree(cdir)
        chunk_no += 1
        open_repos, open_bytes = [], 0

    for name, url, _ in list_repos(set(args.only)):
        if name in done:
            continue
        cid = "chunk-%03d" % chunk_no
        tmp = work / "clone" / name
        tmp.parent.mkdir(parents=True, exist_ok=True)
        head = fetch(name, url, "", tmp, types)
        kept = clean(tmp)
        size = sum(b for _, b in kept)
        if open_repos and open_bytes + size > limit:
            close()
            cid = "chunk-%03d" % chunk_no
        dst = work / cid / name
        dst.parent.mkdir(parents=True, exist_ok=True)
        if dst.exists():
            shutil.rmtree(dst)
        shutil.move(str(tmp), str(dst))
        lic = next((p for p, _ in kept if "/" not in p
                    and p.upper().startswith(LICENCE_GLOBS)), "")
        open_repos.append({
            "repo": name, "url": url, "commit": head, "licence_file": lic,
            "files": [{"path": p, "bytes": b, "sha256": sha256(dst / p)}
                      for p, b in kept]})
        open_bytes += size
        print("%s: %d files, %.1f MB" % (name, len(kept), size / 1e6))
    close()
    shutil.rmtree(work / "clone", ignore_errors=True)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
