"""Tests for the alpha-form rules and the Antagonist protocol.

Run with:
    python3 -m unittest discover scripts/raw_assets/tests
"""

import io
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import check_delta  # noqa: E402
import form  # noqa: E402
import transform  # noqa: E402

ITEM = {
    'repo': 'https://github.com/tmewett/BrogueCE',
    'commit': '0' * 40,
    'license': 'AGPL-3.0',
    'license_file': 'LICENSE.txt',
    'path': 'bin/assets/tiles.png',
}


def dollar_glyph(colour=(255, 255, 255, 255)):
    """A "$" drawn like an atlas glyph: one colour on transparency."""
    img = Image.new('RGBA', (96, 128), (0, 0, 0, 0))
    font = ImageFont.load_default(size=110)
    ImageDraw.Draw(img).text((14, 4), '$', fill=colour, font=font)
    return img.crop(img.getbbox())


def dark_sprite():
    """A pure black sword silhouette, 16x16, like SPD's unknown items."""
    img = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.polygon([(13, 1), (15, 3), (6, 12), (4, 10)], fill=(0, 0, 0, 255))
    draw.rectangle([2, 10, 5, 13], fill=(0, 0, 0, 255))
    draw.line([(1, 14), (3, 12)], fill=(0, 0, 0, 255), width=2)
    return img


def png_bytes(img):
    buf = io.BytesIO()
    img.save(buf, format='PNG', optimize=True)
    return buf.getvalue()


class DollarCase(unittest.TestCase):
    """One "$" run is shared, because a full run takes a few seconds."""

    @classmethod
    def setUpClass(cls):
        cls.record, cls.images = transform.process_piece(
            ITEM, 5, dollar_glyph())

    def test_recolour_is_below_threshold(self):
        white = transform.place_on_canvas(dollar_glyph())
        gold = transform.place_on_canvas(dollar_glyph((232, 200, 122, 255)))
        a, b = form.alpha_mask(white), form.alpha_mask(gold)
        self.assertLess(form.shape_delta(a, b), 0.35)
        self.assertGreater(form.colour_change(white, gold, a, b), 0.35)
        self.assertTrue(self.record['redraw']['is_recolour'])
        self.assertLess(self.record['redraw']['shape_change'], 0.35)

    def test_recolour_replaced_by_avarice(self):
        self.assertEqual(self.record['passion'], 'avarice')
        self.assertEqual(self.record['features']['glyph'], '$')
        self.assertEqual(self.record['behaviour']['antagonist'],
                         'hazard_mimicking_reward')
        for v in self.record['variants']:
            self.assertTrue(v['file'].startswith(
                f'ant_avarice_{self.record["id"]}_v'))
            self.assertGreaterEqual(v['shape_change'], 0.35)

    def test_twelve_variants_distinct_hitboxes(self):
        variants = self.record['variants']
        self.assertEqual([v['slot'] for v in variants],
                         [f'v{n:02d}' for n in range(1, 13)])
        keys = {form.hitbox_key(v['hitbox']) for v in variants}
        self.assertEqual(len(keys), 12)
        for v in variants:
            self.assertGreaterEqual(len(v['hitbox']['hull']), 3)
            self.assertEqual(
                v['analytics_id'],
                f'ludus.variant.avarice.{self.record["id"]}.{v["slot"]}')
        self.assertEqual(self.record['status'], 'ok')

    def test_output_is_rgba_with_transparent_background(self):
        img = self.images[self.record['variants'][0]['file']]
        self.assertEqual(img.mode, 'RGBA')
        self.assertEqual(img.getpixel((0, 0))[3], 0)

    def test_amorphous_notes_pulse_frames(self):
        amorph = [v for v in self.record['variants']
                  if v['kind'] == 'amorphous']
        self.assertTrue(amorph)
        for v in amorph:
            self.assertIn('alpha_pulse_frames', v)

    def test_determinism(self):
        again, images = transform.process_piece(ITEM, 5, dollar_glyph())
        self.assertEqual(sorted(images), sorted(self.images))
        for name, img in images.items():
            self.assertEqual(png_bytes(img), png_bytes(self.images[name]),
                             name)
        self.assertEqual(json.dumps(again, sort_keys=True),
                         json.dumps(self.record, sort_keys=True))


class AlphaFormCase(unittest.TestCase):

    def test_dark_sprite_keeps_silhouette(self):
        record, _ = transform.process_piece(
            {**ITEM, 'path': 'core/src/main/assets/sprites/items.png'},
            0, dark_sprite())
        self.assertNotEqual(record['status'], 'error')
        self.assertNotIn('error', record)
        self.assertEqual(record['redraw']['silhouette_loss'], 0.0)
        self.assertEqual(record['redraw']['shape_change'], 0.0)

    def test_dark_and_white_have_same_form(self):
        dark = transform.place_on_canvas(dark_sprite())
        white = Image.new('RGBA', dark.size, (255, 255, 255, 255))
        white.putalpha(dark.getchannel('A'))
        self.assertEqual(form.alpha_mask(dark).tobytes(),
                         form.alpha_mask(white).tobytes())

    def test_luminance_transform_raises_silhouette_error(self):
        # A transform that keys form by brightness erases a black sprite;
        # the named error must stop it.
        canvas = transform.place_on_canvas(dark_sprite())
        bad = canvas.copy()
        bad.putalpha(ImageOps.grayscale(canvas.convert('RGB')).point(
            lambda v: 255 if v > 48 else 0))
        src = form.alpha_mask(canvas)
        _, stats = transform.measure(canvas, src, form.fill_holes(src), bad)
        error = transform.check_silhouette(stats, deliberate=False)
        self.assertIsNotNone(error)
        self.assertTrue(error.startswith('Alpha_Silhouette_Error'))
        self.assertIsNone(transform.check_silhouette(stats, deliberate=True))

    def test_interior_moves_weigh_one_tenth(self):
        disc = Image.new('L', (256, 256), 0)
        ImageDraw.Draw(disc).ellipse([28, 28, 228, 228], fill=255)
        ring = disc.copy()
        ImageDraw.Draw(ring).ellipse([98, 98, 158, 158], fill=0)
        hole = form.area(disc) - form.area(ring)
        expected = 0.1 * hole / form.area(disc)
        self.assertAlmostEqual(form.shape_delta(disc, ring), expected,
                               places=6)
        self.assertAlmostEqual(form.iou_delta(disc, ring),
                               hole / form.area(disc), places=6)


class CheckDeltaCase(unittest.TestCase):

    def write(self, root, shape):
        Image.new('RGBA', (4, 4)).save(root / 'ant_anger_x_v01.png')
        meta = {'variants': [{'file': 'ant_anger_x_v01.png',
                              'shape_change': shape}]}
        (root / 'ant_anger_x.json').write_text(json.dumps(meta))

    def run_gate(self, root):
        return subprocess.run(
            [sys.executable, str(HERE.parent / 'check_delta.py'),
             '--root', str(root)], capture_output=True, text=True)

    def test_passes_with_meta(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.write(Path(tmp), 0.5)
            self.assertEqual(check_delta.check(Path(tmp), 0.35), [])
            self.assertEqual(self.run_gate(tmp).returncode, 0)

    def test_fails_below_threshold(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.write(Path(tmp), 0.2)
            result = self.run_gate(tmp)
            self.assertEqual(result.returncode, 1)
            self.assertIn('Требуется Антагонист', result.stdout)

    def test_fails_without_meta(self):
        with tempfile.TemporaryDirectory() as tmp:
            Image.new('RGBA', (4, 4)).save(Path(tmp) / 'copy.png')
            result = self.run_gate(tmp)
            self.assertEqual(result.returncode, 1)
            self.assertIn('Требуется Антагонист', result.stdout)


if __name__ == '__main__':
    unittest.main()
