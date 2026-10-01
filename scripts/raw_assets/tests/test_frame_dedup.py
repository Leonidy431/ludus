"""Frames of one animation must not ship as separate antagonists.

2026-09-30: defend1.png and defend2.png of one wesnoth unit passed as
two objects (aligned silhouette IoU 0.92), because the list of seen
silhouettes was reset for every file.
"""

import json
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import transform  # noqa: E402


def frame(offset, lean):
    """A figure on a transparent canvas, shifted by `offset` pixels."""
    img = Image.new('RGBA', (96, 96), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    x, y = 20 + offset, 10 + offset
    draw.polygon([(x, y + 60), (x + 20 + lean, y), (x + 40, y + 60)],
                 fill=(90, 60, 40, 255))
    draw.rectangle((x + 10, y + 60, x + 30, y + 70), fill=(60, 40, 30, 255))
    return img


class FrameDedupTest(unittest.TestCase):
    def test_shifted_frame_matches_after_crop(self):
        a = transform.frame_mask(frame(0, 0))
        b = transform.frame_mask(frame(12, 1))
        self.assertGreater(transform.mask_iou(a, b), transform.FRAME_DUP_IOU)

    def test_two_files_of_one_slot_ship_once(self):
        with tempfile.TemporaryDirectory() as root:
            raw = Path(root, 'raw')
            raw.mkdir()
            manifest = []
            for i, (off, lean) in enumerate([(0, 0), (12, 1)]):
                path = raw / f'defend{i + 1}.png'
                frame(off, lean).save(path)
                manifest.append({
                    'repo': 'https://github.com/x/y', 'commit': 'c',
                    'license': 'GPL', 'license_file': 'COPYING',
                    'attribution': [], 'path': f'units/defend{i + 1}.png',
                    'local': str(path), 'bytes': path.stat().st_size,
                    'slot': 'DEF-001', 'neutral': False})
            (raw / 'manifest.json').write_text(json.dumps(manifest))
            out = Path(root, 'out')
            argv = sys.argv
            sys.argv = ['transform.py', '--raw', str(raw), '--out', str(out)]
            try:
                transform.main()
            finally:
                sys.argv = argv
            report = json.loads((out / 'report.json').read_text())
            reasons = [r.get('reason') for r in report['rejected']]
            self.assertIn('duplicate-animation-frame', reasons)


if __name__ == '__main__':
    unittest.main()
