"""Contact sheets of the 144 insight variants: one sheet per insight,
twelve frames in the order of the hours, each labelled with its hour,
solar time and the height of the sun, so the chorus judges them with
its eyes side by side (CLAUDE.md TABOO 0.021 p. 5, 0.37).

    python3 scripts/video/insight_variant_sheets.py [--only id,id]

Reads godot/data/pilot-insight-variants.json and
build/insight_variants/<id>/vNN.jpg; writes
build/insight_variants/<id>/sheet.jpg.  A missing frame is drawn as a
red cross, never skipped, so a hole in the batch is seen.

Constitution: ФОРМА (twelve frames of one memory) → ДЕЙСТВИЕ (lay them
side by side and look) → ЦЕЛЬ (the chorus picks with its eyes, not
from a number).
"""

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / 'godot' / 'data' / 'pilot-insight-variants.json'
BUILD = ROOT / 'build' / 'insight_variants'
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
THUMB, COLS, ROWS, LABEL, HEAD = 320, 4, 3, 44, 56


def sheet(iid, variants, picks):
    f = ImageFont.truetype(FONT, 15)
    fh = ImageFont.truetype(FONT, 22)
    w = COLS * THUMB
    img = Image.new('RGB', (w, HEAD + ROWS * (THUMB + LABEL)), (14, 10, 8))
    d = ImageDraw.Draw(img)
    d.text((12, 14), '%s — 12 часов дня' % iid, font=fh,
           fill=(255, 190, 110))
    for i, v in enumerate(variants):
        x = (i % COLS) * THUMB
        y = HEAD + (i // COLS) * (THUMB + LABEL)
        p = BUILD / iid / ('v%02d.jpg' % v['v'])
        if p.exists():
            img.paste(Image.open(p).convert('RGB').resize((THUMB, THUMB)),
                      (x, y))
        else:
            d.line((x, y, x + THUMB, y + THUMB), fill=(200, 0, 0), width=4)
            d.line((x + THUMB, y, x, y + THUMB), fill=(200, 0, 0), width=4)
        mark = ' ★' if picks.get(iid) == v['v'] else ''
        d.text((x + 6, y + THUMB + 4), 'v%02d %s%s' % (
            v['v'], v['time_of_day'], mark), font=f, fill=(232, 214, 182))
        d.text((x + 6, y + THUMB + 23), '%s, солнце %+.0f°, %g мм' % (
            v['solar_time'], v['sun_elev'], v['cam']['lens_mm']), font=f,
            fill=(170, 160, 150))
    out = BUILD / iid / 'sheet.jpg'
    img.save(out, quality=85)
    return out


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--only', default='')
    args = ap.parse_args(argv)
    data = json.loads(DATA.read_text(encoding='utf-8'))
    picks = data.get('picks', {})
    for iid, vs in data['variants'].items():
        if args.only and iid not in args.only.split(','):
            continue
        print(sheet(iid, vs, picks))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
