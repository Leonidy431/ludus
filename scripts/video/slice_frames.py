"""Cut a LOCAL video into pictures, one every N seconds (or per scene).

Operator, 2026-10-03: «нарежь себе все сцены или через каждые пять
секунд в jpg или png».  The frames are style REFERENCE for study: they
stay under build/ (git-ignored) and never go into the game, the repo or
a published episode.  The script does not download anything; give it a
file you are allowed to keep (a demo, your own capture).

    python3 scripts/video/slice_frames.py clip.mp4 --every 5
    python3 scripts/video/slice_frames.py clip.mp4 --scenes 0.3 --png

Needs ffmpeg on PATH.  The output folder is build/reference/<name>/ and
holds frame-0001.jpg ... and a contact.jpg sheet of the first 48.

Constitution: ФОРМА (a clip of someone else's style) → ДЕЙСТВИЕ (cut
into stills for the chorus to look at) → ЦЕЛЬ (learn the manner, then
draw our own; nothing borrowed ships).
"""

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build' / 'reference'


def filters(every, scenes, width):
    if scenes:
        pick = "select='gt(scene,%s)'" % scenes
    else:
        pick = "fps=1/%s" % every
    return '%s,scale=%d:-2' % (pick, width)


def slice_video(src, every=5.0, scenes=None, width=640, png=False):
    """Write the frames; return the list of files, in order."""
    if not shutil.which('ffmpeg'):
        raise SystemExit('ffmpeg is not installed')
    src = Path(src)
    out = OUT / src.stem
    out.mkdir(parents=True, exist_ok=True)
    ext = 'png' if png else 'jpg'
    cmd = ['ffmpeg', '-v', 'error', '-y', '-i', str(src), '-vf',
           filters(every, scenes, width), '-vsync', 'vfr']
    if not png:
        cmd += ['-q:v', '3']
    cmd.append(str(out / ('frame-%04d.' + ext)))
    subprocess.run(cmd, check=True)
    return sorted(out.glob('frame-*.' + ext))


def contact(files, columns=6, rows=8):
    """A sheet of the first columns x rows frames, next to them."""
    if not files:
        return None
    sheet = files[0].parent / 'contact.jpg'
    first = files[:columns * rows]
    cmd = ['ffmpeg', '-v', 'error', '-y', '-pattern_type', 'glob', '-i',
           str(files[0].parent / ('frame-*' + files[0].suffix)),
           '-frames:v', '1', '-vf',
           'scale=240:-2,tile=%dx%d' % (columns, rows), str(sheet)]
    subprocess.run(cmd, check=True)
    return sheet if first else None


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('video')
    ap.add_argument('--every', type=float, default=5.0)
    ap.add_argument('--scenes', type=float, default=None,
                    help='scene-change threshold 0..1 instead of --every')
    ap.add_argument('--width', type=int, default=640)
    ap.add_argument('--png', action='store_true')
    args = ap.parse_args(argv)
    files = slice_video(args.video, args.every, args.scenes, args.width,
                        args.png)
    sheet = contact(files)
    print('%d frames in %s%s' % (len(files), files[0].parent if files
                                 else OUT, ', sheet ' + sheet.name
                                 if sheet else ''))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
