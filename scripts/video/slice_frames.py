"""Cut a LOCAL video into pictures, one every N seconds (or per scene).

Operator, 2026-10-03: «нарежь себе все сцены или через каждые пять
секунд в jpg или png».  The frames are style REFERENCE for study: they
stay under build/ (git-ignored) and never go into the game, the repo or
a published episode.  The script does not download anything; give it a
file you are allowed to keep (a demo, your own capture).

    python3 scripts/video/slice_frames.py clip.mp4 --every 5
    python3 scripts/video/slice_frames.py clip.mp4 --scenes 0.3 --png

Needs ffmpeg on PATH (Pillow for --dedupe).  The output folder is
build/reference/<name>/ and holds frame-0001.jpg ..., index.json (each
frame's time in the clip, so a frame can be found again) and a
contact.jpg sheet of the first 48.  --dedupe drops a frame that looks
like the one before it (a still shot held for many seconds).

Constitution: ФОРМА (a clip of someone else's style) → ДЕЙСТВИЕ (cut
into stills for the chorus to look at) → ЦЕЛЬ (learn the manner, then
draw our own; nothing borrowed ships).
"""

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build' / 'reference'


def filters(every, scenes, width):
    """A select filter whose showinfo line gives each kept frame's time.

    The first frame is always kept; then a frame every `every` seconds,
    or (with `scenes`) each frame whose change from the last is above the
    threshold.
    """
    if scenes:
        pick = "select='eq(n,0)+gt(scene,%s)'" % scenes
    else:
        pick = ("select='isnan(prev_selected_t)"
                "+gte(t-prev_selected_t,%s)'" % every)
    return '%s,showinfo,scale=%d:-2' % (pick, width)


PTS = re.compile(r'pts_time:([0-9.]+)')


def dhash(path, size=8):
    """A difference hash: neighbouring shots of one scene come close."""
    from PIL import Image
    img = Image.open(path).convert('L').resize((size + 1, size))
    px = list(img.tobytes())
    bits = 0
    for row in range(size):
        for col in range(size):
            left = px[row * (size + 1) + col]
            bits = (bits << 1) | (left > px[row * (size + 1) + col + 1])
    return bits


def dedupe(files, times, max_bits=5):
    """Drop a frame within max_bits of the last kept one."""
    kept, last = [], None
    for path, t in zip(files, times):
        h = dhash(path)
        if last is not None and bin(h ^ last).count('1') <= max_bits:
            path.unlink()
            continue
        kept.append((path, t))
        last = h
    return kept


def slice_video(src, every=5.0, scenes=None, width=640, png=False,
                same=False):
    """Write the frames and index.json; return [(file, seconds)]."""
    if not shutil.which('ffmpeg'):
        raise SystemExit('ffmpeg is not installed')
    src = Path(src)
    out = OUT / src.stem
    out.mkdir(parents=True, exist_ok=True)
    ext = 'png' if png else 'jpg'
    for old in out.glob('frame-*'):
        old.unlink()
    cmd = ['ffmpeg', '-hide_banner', '-y', '-i', str(src), '-vf',
           filters(every, scenes, width), '-fps_mode', 'vfr']
    if not png:
        cmd += ['-q:v', '3']
    cmd.append(str(out / ('frame-%04d.' + ext)))
    run = subprocess.run(cmd, check=True, capture_output=True, text=True)
    times = [float(t) for t in PTS.findall(run.stderr)]
    files = sorted(out.glob('frame-*.' + ext))
    pairs = list(zip(files, times))
    if same:
        pairs = dedupe(files, times)
    index = [{'file': f.name, 'seconds': round(t, 2)} for f, t in pairs]
    (out / 'index.json').write_text(json.dumps(
        {'source': src.name, 'every': None if scenes else every,
         'scenes': scenes, 'frames': index}, indent=1), encoding='utf-8')
    return pairs


def contact(files, columns=6, rows=8):
    """A sheet of the first columns x rows frames, next to them."""
    if not files:
        return None
    sheet = files[0].parent / 'contact.jpg'
    cmd = ['ffmpeg', '-v', 'error', '-y', '-pattern_type', 'glob', '-i',
           str(files[0].parent / ('frame-*' + files[0].suffix)),
           '-frames:v', '1', '-vf',
           'scale=240:-2,tile=%dx%d' % (columns, rows), str(sheet)]
    subprocess.run(cmd, check=True)
    return sheet


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('video')
    ap.add_argument('--every', type=float, default=5.0)
    ap.add_argument('--scenes', type=float, default=None,
                    help='scene-change threshold 0..1 instead of --every')
    ap.add_argument('--width', type=int, default=640)
    ap.add_argument('--png', action='store_true')
    ap.add_argument('--dedupe', action='store_true',
                    help='drop a frame that looks like the previous one')
    args = ap.parse_args(argv)
    pairs = slice_video(args.video, args.every, args.scenes, args.width,
                        args.png, args.dedupe)
    files = [f for f, _ in pairs]
    sheet = contact(files)
    print('%d frames in %s%s' % (len(files), files[0].parent if files
                                 else OUT, ', sheet ' + sheet.name
                                 if sheet else ''))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
