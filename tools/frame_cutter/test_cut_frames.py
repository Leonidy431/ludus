"""Tests for cut_frames.py. Run: python -m pytest tools/frame_cutter"""

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent))
import cut_frames  # noqa: E402

cv2 = pytest.importorskip("cv2")
np = pytest.importorskip("numpy")


def test_format_timestamp():
    assert cut_frames.format_timestamp(0) == "00h00m00.000s"
    assert cut_frames.format_timestamp(3725.5) == "01h02m05.500s"


def test_interval_indices_every_5s_at_25fps():
    assert cut_frames.interval_frame_indices(300, 25.0, 5.0) == [0, 125, 250]


def test_interval_indices_degenerate_inputs():
    assert cut_frames.interval_frame_indices(0, 25.0, 5.0) == []
    assert cut_frames.interval_frame_indices(100, 0.0, 5.0) == []
    assert cut_frames.interval_frame_indices(100, 25.0, 0.0) == []


def test_scene_cut_needs_threshold_and_gap():
    assert cut_frames.is_scene_cut(0.5, 0.35, 2.0, 1.0)
    assert not cut_frames.is_scene_cut(0.2, 0.35, 2.0, 1.0)
    assert not cut_frames.is_scene_cut(0.5, 0.35, 0.5, 1.0)


def _make_video(path: Path, colours, seconds_each: int, fps: int = 10):
    writer = cv2.VideoWriter(str(path), cv2.VideoWriter_fourcc(*"MJPG"),
                             fps, (64, 48))
    for colour in colours:
        frame = np.zeros((48, 64, 3), dtype=np.uint8)
        frame[:] = colour
        for _ in range(seconds_each * fps):
            writer.write(frame)
    writer.release()


@pytest.fixture()
def video(tmp_path):
    path = tmp_path / "clip.avi"
    # Three 4-second "scenes": blue, green, red (BGR).
    _make_video(path, [(255, 0, 0), (0, 255, 0), (0, 0, 255)], 4)
    return path


def test_interval_mode_writes_frames_and_manifest(video, tmp_path):
    out = tmp_path / "out"
    assert cut_frames.main([str(video), "-o", str(out), "--every", "5"]) == 0
    manifest = json.loads((out / "frames.json").read_text(encoding="utf-8"))
    seconds = [f["seconds"] for f in manifest["frames"]]
    assert seconds == [0.0, 5.0, 10.0]
    assert len(list(out.glob("*.jpg"))) == 3


def test_scene_mode_finds_three_scenes_png(video, tmp_path):
    out = tmp_path / "scenes"
    assert cut_frames.main([str(video), "-o", str(out), "--mode", "scenes",
                            "--format", "png"]) == 0
    manifest = json.loads((out / "frames.json").read_text(encoding="utf-8"))
    assert [round(f["seconds"]) for f in manifest["frames"]] == [0, 4, 8]
    assert len(list(out.glob("*.png"))) == 3


def test_missing_file_returns_2(tmp_path):
    assert cut_frames.main([str(tmp_path / "nope.mp4")]) == 2
