"""Draw the launcher icons of the headset build (HLD_CHORUS24 phase F2).

The emblem is our own: the comet mark of the series (ТАБУ №0.03 node
1) over the water of the lake.  No halo and no cross: the launcher is
an interface, and the holy is never an interface mark (ТАБУ №0.4).
The palette is the instrument's: cyan, ultramarine and graphite
(ТАБУ №0.38, ТАБУ №0.024 п. 8).

The drawing is geometry only, so the same run gives the same bytes
and nothing random enters (Constitution).  Every shape is drawn four
times larger and scaled down, which smooths the edges without a font
or an outside picture.

Run from the repository root:

    python3 scripts/godot/make_icons.py

It writes godot/icons/icon_192.png, icon_fg_432.png, icon_bg_432.png
and icon_mono_432.png.

Constitution: ФОРМА (the comet over the water, the mark of the
series) → ДЕЙСТВИЕ (the player finds the game by it in the headset's
library) → ЦЕЛЬ (the first thing he sees already says where the story
goes: down into the water, after the comet).
"""

import math
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "godot", "icons")
SS = 4  # Supersampling factor: draw large, then scale down smoothly.

GRAPHITE = (30, 34, 40, 255)
ULTRAMARINE = (24, 44, 120, 255)
DEEP = (14, 24, 66, 255)
CYAN = (64, 214, 232, 255)
FOAM = (196, 244, 250, 255)


def _comet(draw, cx, cy, r, colour, tail_colour):
    """Draw a comet: a round head and a tail that thins to the left.

    The tail is a run of shrinking discs along a shallow arc, so it
    reads as motion downwards, towards the water, not as a ray of
    light around a head.
    """
    steps = 40
    for i in range(steps, 0, -1):
        k = i / steps
        x = cx - k * r * 5.2
        y = cy - k * r * 2.4 - math.sin(k * math.pi) * r * 0.5
        rr = r * (1.0 - k) ** 1.4 * 0.95
        if rr < 1:
            continue
        draw.ellipse((x - rr, y - rr, x + rr, y + rr), fill=tail_colour)
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=colour)


def _waves(draw, size, top, colour, rows=3, amp=None, width=None):
    """Draw the lake as three calm wave lines under the comet."""
    amp = amp or size * 0.018
    width = width or max(1, int(size * 0.022))
    gap = size * 0.07
    for row in range(rows):
        y0 = top + row * gap
        pts = []
        for i in range(0, 121):
            x = size * 0.23 + size * 0.54 * i / 120
            y = y0 + amp * math.sin(i / 120 * math.pi * 4 + row)
            pts.append((x, y))
        draw.line(pts, fill=colour, width=width, joint="curve")


def foreground(size, mono=False):
    """The comet and the water on a clear field.

    Everything stays inside the adaptive icon's safe circle (66 % of
    the side), because the launcher may crop the rest.
    """
    big = size * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    head = CYAN if not mono else (255, 255, 255, 255)
    tail = FOAM if not mono else (255, 255, 255, 255)
    wave = CYAN if not mono else (255, 255, 255, 255)
    _comet(d, big * 0.60, big * 0.44, big * 0.055, head, tail)
    _waves(d, big, big * 0.58, wave)
    return img.resize((size, size), Image.LANCZOS)


def background(size):
    """Ultramarine deepening to graphite, like water seen from above."""
    img = Image.new("RGBA", (size, size), GRAPHITE)
    d = ImageDraw.Draw(img)
    for y in range(size):
        k = y / (size - 1)
        c = tuple(int(ULTRAMARINE[i] * (1 - k) + DEEP[i] * k)
                  for i in range(3)) + (255,)
        d.line((0, y, size, y), fill=c)
    return img


def legacy(size):
    """The plain icon: a rounded square of water with the emblem."""
    bg = background(size)
    big = size * SS
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, big - 1, big - 1), radius=big * 0.2, fill=255)
    mask = mask.resize((size, size), Image.LANCZOS)
    # The emblem is drawn a little larger here: there is no crop.
    fg = foreground(int(size * 1.3))
    off = (int(size * 1.3) - size) // 2
    fg = fg.crop((off, off, off + size, off + size))
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(Image.alpha_composite(bg, fg), (0, 0), mask)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    files = {
        "icon_192.png": legacy(192),
        "icon_fg_432.png": foreground(432),
        "icon_bg_432.png": background(432),
        "icon_mono_432.png": foreground(432, mono=True),
    }
    for name, img in files.items():
        path = os.path.join(OUT, name)
        img.save(path, optimize=True)
        print(name, img.size, os.path.getsize(path), "bytes")


if __name__ == "__main__":
    main()
