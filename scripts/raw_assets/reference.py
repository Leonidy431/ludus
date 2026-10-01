"""Real-object profiles for the neutral raw-material slots.

Operator, 2026-09-30: "смени подход к выбору, изучи на реальных
объектах".  Round 1 and its three repeats shipped nothing: after every
fix the contact sheet still showed stones and ladders as abstract
diamonds in the cold palette of the passions.  The selection therefore
starts from the real thing now, not from the sprite:

1. Each neutral slot has a profile measured on the real objects of the
   lake register (scripts/lake/lake_objects.py, docs/ISSYK_KUL_FISH.md):
   the proportions of the silhouette and the natural colours.
2. A raw piece whose alpha silhouette does not fit the profile is
   refused before any variant is made ("unlike-real-object").
3. A piece that fits is painted in the natural palette of its slot,
   never in a passion's palette, so a stone stays a stone.

Only the alpha channel decides the form (TABOO 0.3 rule 1); colour is
used only for the palette.  Everything is deterministic.
"""

import colorsys
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FISH = ROOT / 'public' / 'ludus' / 'data' / 'issyk-kul-fish.json'

# Silhouette proportions of the real things, side view as the ROV sees
# them.  aspect = width / height of the alpha bounding box; fill = share
# of the box covered by the silhouette.  Ranges are wide on purpose:
# they refuse diamonds, letters and people, not a fat bream.
#   fish     dace and trout 4-5, bream and carp 2.5-3, fins lower fill;
#   stones   pebbles and boulders 0.8-2.5, solid;
#   plants   stems and reeds, tall and sparse;
#   wood     logs are long, jugs and pots upright and full.
PROFILES = {
    'DEF-056': {'name': 'fish', 'aspect': (1.8, 6.5), 'fill': (0.35, 0.85),
                'category': 'fish'},
    'DEF-057': {'name': 'stones', 'aspect': (0.7, 2.8),
                'fill': (0.55, 0.98), 'category': 'shelf', 'base': 0.35},
    'DEF-058': {'name': 'plants', 'aspect': (0.1, 0.9), 'fill': (0.1, 0.7),
                'category': 'plant'},
    'DEF-059': {'name': 'wood and pottery', 'aspect': (0.45, 8.0),
                'fill': (0.45, 0.98), 'category': 'find'},
}


def bbox_stats(mask):
    """Aspect, fill and base of an alpha mask ('L' image, 0 or 255).

    base = widest row among the lowest tenth of the silhouette, divided
    by the widest row overall.  A stone seen from the side rests on the
    floor and is broad low down; a top-down diamond tile narrows to a
    point (the lake pass of 2026-09-30 let such a tile into the stone
    slot, and its variants read as vases).
    """
    box = mask.getbbox()
    if not box:
        return {'aspect': 0.0, 'fill': 0.0, 'base': 0.0}
    w, h = box[2] - box[0], box[3] - box[1]
    crop = mask.crop(box)
    data = crop.tobytes()
    rows = [sum(1 for v in data[y * w:(y + 1) * w] if v) for y in range(h)]
    low = rows[h - max(1, h // 10):]
    return {'aspect': round(w / max(1, h), 3),
            'fill': round(sum(rows) / max(1, w * h), 3),
            'base': round(max(low) / max(1, max(rows)), 3)}


def fits(slot, mask):
    """Return (True, stats) when the silhouette looks like the thing."""
    prof = PROFILES.get(slot)
    stats = bbox_stats(mask)
    if not prof:
        return True, stats
    ok = (prof['aspect'][0] <= stats['aspect'] <= prof['aspect'][1]
          and prof['fill'][0] <= stats['fill'] <= prof['fill'][1]
          and stats['base'] >= prof.get('base', 0.0))
    return ok, stats


def _register_colours(category):
    """Colours of the real things of one category of the lake."""
    import sys
    sys.path.insert(0, str(ROOT / 'scripts' / 'lake'))
    import lake_objects
    cols = [row[11] for row in lake_objects.ITEMS if row[1] == category]
    if category == 'fish' and FISH.exists():
        cols += [f['colour'] for f in
                 json.loads(FISH.read_text('utf-8'))['fish']]
    return cols


def natural_palette(slot):
    """Four-stop palette from the median real colour of the slot.

    The hue and saturation are the median of the register's colours,
    so a fish slot is silver-olive and a stone slot grey-ochre.  Value
    runs from shadow to light like the passion palettes, so painting and
    the rim work unchanged.
    """
    prof = PROFILES[slot]
    hsv = []
    for c in _register_colours(prof['category']):
        r, g, b = (int(c[i:i + 2], 16) / 255 for i in (1, 3, 5))
        hsv.append(colorsys.rgb_to_hsv(r, g, b))
    hsv.sort()
    h, s, _ = hsv[len(hsv) // 2]
    s = min(s, 0.45)

    def rgb(v, ds=0.0):
        r, g, b = colorsys.hsv_to_rgb(h, max(0.0, s + ds), v)
        return (round(r * 255), round(g * 255), round(b * 255))
    stops = [(0.0, rgb(0.18, 0.05)), (0.45, rgb(0.42)), (0.8, rgb(0.66)),
             (1.0, rgb(0.9, -0.15))]
    return {'hue': round(h * 360), 'basis': f'natural:{prof["name"]}',
            'stops': stops}
