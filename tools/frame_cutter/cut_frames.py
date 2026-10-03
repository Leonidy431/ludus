#!/usr/bin/env python3
"""Cut still frames from a local video file.

Two modes:

* ``interval`` -- one frame every N seconds (default 5).
* ``scenes``   -- one frame at every scene cut, detected by the
  difference of HSV colour histograms between neighbouring frames.

The script works only on video files already on disk. It does not
download anything. Use it on material you have the right to process;
frames of third-party games are style references for local study and
must not be committed to the repository (see README.md).

Requires OpenCV: ``pip install opencv-python-headless``.

Docs:
    https://docs.opencv.org/4.x/d8/dfe/classcv_1_1VideoCapture.html
    https://docs.opencv.org/4.x/d8/dc8/tutorial_histogram_comparison.html
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

try:
    import cv2
except ImportError:  # pragma: no cover - checked at runtime
    cv2 = None

FORMATS = ("jpg", "png")


def format_timestamp(seconds: float) -> str:
    """Return ``HHhMMmSS.sss`` suitable for a file name."""
    total_ms = int(round(seconds * 1000))
    hours, rest = divmod(total_ms, 3_600_000)
    minutes, rest = divmod(rest, 60_000)
    secs, ms = divmod(rest, 1000)
    return f"{hours:02d}h{minutes:02d}m{secs:02d}.{ms:03d}s"


def interval_frame_indices(frame_count: int, fps: float,
                           every_seconds: float) -> list[int]:
    """Frame indices taken every ``every_seconds`` seconds."""
    if fps <= 0 or every_seconds <= 0 or frame_count <= 0:
        return []
    step = every_seconds * fps
    indices = []
    position = 0.0
    while int(round(position)) < frame_count:
        indices.append(int(round(position)))
        position += step
    return indices


def histogram_distance(hist_a, hist_b) -> float:
    """Bhattacharyya distance between two histograms (0 = identical)."""
    return float(cv2.compareHist(hist_a, hist_b,
                                 cv2.HISTCMP_BHATTACHARYYA))


def frame_histogram(frame):
    """Normalised H-S histogram of a BGR frame."""
    hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
    hist = cv2.calcHist([hsv], [0, 1], None, [50, 60], [0, 180, 0, 256])
    cv2.normalize(hist, hist, 0, 1, cv2.NORM_MINMAX)
    return hist


def is_scene_cut(distance: float, threshold: float,
                 seconds_since_last: float, min_gap: float) -> bool:
    """Decide whether a histogram jump counts as a new scene."""
    return distance >= threshold and seconds_since_last >= min_gap


def save_frame(frame, out_dir: Path, prefix: str, number: int,
               seconds: float, fmt: str, quality: int) -> Path:
    """Write one frame and return its path."""
    name = f"{prefix}_{number:05d}_{format_timestamp(seconds)}.{fmt}"
    path = out_dir / name
    if fmt == "jpg":
        params = [cv2.IMWRITE_JPEG_QUALITY, quality]
    else:
        params = [cv2.IMWRITE_PNG_COMPRESSION, 3]
    if not cv2.imwrite(str(path), frame, params):
        raise OSError(f"cannot write {path}")
    return path


def cut_interval(capture, out_dir: Path, prefix: str, fmt: str,
                 quality: int, every_seconds: float) -> list[dict]:
    """Save one frame every ``every_seconds`` seconds."""
    fps = capture.get(cv2.CAP_PROP_FPS) or 25.0
    count = int(capture.get(cv2.CAP_PROP_FRAME_COUNT))
    saved = []
    for number, index in enumerate(
            interval_frame_indices(count, fps, every_seconds), start=1):
        capture.set(cv2.CAP_PROP_POS_FRAMES, index)
        ok, frame = capture.read()
        if not ok:
            break
        seconds = index / fps
        path = save_frame(frame, out_dir, prefix, number, seconds, fmt,
                          quality)
        saved.append({"file": path.name, "seconds": round(seconds, 3)})
    return saved


def cut_scenes(capture, out_dir: Path, prefix: str, fmt: str,
               quality: int, threshold: float,
               min_gap: float) -> list[dict]:
    """Save the first frame of the video and of every detected scene."""
    fps = capture.get(cv2.CAP_PROP_FPS) or 25.0
    saved = []
    previous = None
    last_saved_at = -min_gap
    index = 0
    while True:
        ok, frame = capture.read()
        if not ok:
            break
        seconds = index / fps
        hist = frame_histogram(frame)
        distance = 1.0 if previous is None else histogram_distance(
            previous, hist)
        if is_scene_cut(distance, threshold, seconds - last_saved_at,
                        min_gap):
            path = save_frame(frame, out_dir, prefix, len(saved) + 1,
                              seconds, fmt, quality)
            saved.append({"file": path.name, "seconds": round(seconds, 3),
                          "distance": round(distance, 4)})
            last_saved_at = seconds
        previous = hist
        index += 1
    return saved


def build_parser() -> argparse.ArgumentParser:
    """Command-line interface."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("video", type=Path, help="local video file")
    parser.add_argument("-o", "--out", type=Path, default=None,
                        help="output folder (default: frames/<video name>)")
    parser.add_argument("--mode", choices=("interval", "scenes"),
                        default="interval")
    parser.add_argument("--every", type=float, default=5.0,
                        help="seconds between frames in interval mode")
    parser.add_argument("--threshold", type=float, default=0.35,
                        help="histogram distance for a scene cut (0..1)")
    parser.add_argument("--min-gap", type=float, default=1.0,
                        help="minimum seconds between two scene frames")
    parser.add_argument("--format", choices=FORMATS, default="jpg")
    parser.add_argument("--quality", type=int, default=92,
                        help="JPEG quality 1..100")
    return parser


def main(argv: list[str] | None = None) -> int:
    """Entry point."""
    args = build_parser().parse_args(argv)
    if cv2 is None:
        print("OpenCV missing: pip install opencv-python-headless",
              file=sys.stderr)
        return 2
    if not args.video.is_file():
        print(f"no such file: {args.video}", file=sys.stderr)
        return 2
    out_dir = args.out or Path("frames") / args.video.stem
    out_dir.mkdir(parents=True, exist_ok=True)
    capture = cv2.VideoCapture(str(args.video))
    if not capture.isOpened():
        print(f"cannot open video: {args.video}", file=sys.stderr)
        return 2
    try:
        if args.mode == "interval":
            saved = cut_interval(capture, out_dir, args.video.stem,
                                 args.format, args.quality, args.every)
        else:
            saved = cut_scenes(capture, out_dir, args.video.stem,
                               args.format, args.quality, args.threshold,
                               args.min_gap)
    finally:
        capture.release()
    manifest = {"video": args.video.name, "mode": args.mode,
                "every": args.every, "threshold": args.threshold,
                "frames": saved}
    (out_dir / "frames.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"{len(saved)} frames -> {out_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
