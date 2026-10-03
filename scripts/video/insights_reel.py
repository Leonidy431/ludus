"""The reel of the twelve insights of episode 1, with the suite under it.

The operator (2026-10-02): «Комит видео в отдельную папку и дай тут
скачать».  The reel shows the twelve insight frames of the pilot
(godot/art/prerender/insight_<id>.jpg, rendered by
scripts/prerender/render_insights.py) as they come in the game: the
memory's frame, the narrator's line from the third person, the epoch,
what brings it (place, order, time, depth, find, step of thought,
stillness) and what law of the world it explains.  Under it plays the
start of the suite «Наука. Любовь. Познание.» from
build/music/cosmos/suite-preview.wav (scripts/music/cosmos_preview.py).

Everything is computed: a slow push-in on each frame, a 0.8 s cross
fade, text drawn with DejaVu Sans.  Nothing is random, so the same
inputs give the same video.

    python3 scripts/music/cosmos_preview.py      # the music first
    python3 scripts/video/insights_reel.py       # -> video/insights/

Needs numpy, Pillow and ffmpeg with libx264 and AAC.

Constitution: ФОРМА (the twelve memories and the words about them) →
ДЕЙСТВИЕ (watch them one after another, as the player meets them) →
ЦЕЛЬ (each epoch is the reader of the one before; the reel shows the
laws of the world the insights teach).
"""

import argparse
import json
import subprocess
import sys
import textwrap
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / 'godot' / 'data' / 'pilot-insights.json'
MUSIC = ROOT / 'build' / 'music' / 'cosmos' / 'suite-preview.wav'
OUT = ROOT / 'video' / 'insights' / 'insights-ep1.mp4'
W, H, FPS = 1280, 720, 24
TITLE_S, SHOT_S, END_S, FADE_S = 4.0, 6.5, 4.0, 0.8
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
FONT_I = '/usr/share/fonts/truetype/liberation/LiberationSerif-Italic.ttf'
INK = (14, 10, 8)
PAPER = (232, 214, 182)
AMBER = (255, 190, 110)
GREY = (170, 160, 150)
EPOCHS = {
    'brothers': 'Братья обители, XIV век',
    'copyist': 'Переписчик обители, 1376',
    'knight_1374': 'Рыцарь, 1374',
    'knight_1375': 'Рыцарь, 1375',
    'knight_youth': 'Рыцарь в юности, гавань Аяса',
    'operator_2025': 'Оператор, 2025',
    'operator_2026': 'Оператор, 2026',
    'traitor_1374': 'Предатель, 1374',
}
FACTORS = {
    'depth': 'приходит по глубине',
    'find': 'приходит по находке',
    'place': 'приходит по месту: взгляд держит место',
    'sequence': 'приходит по порядку событий',
    'stage': 'приходит по ступени помысла',
    'still': 'приходит по неподвижности',
    'time': 'приходит по времени серии',
}


def font(path, size):
    # A missing face falls back to DejaVu Sans, never to the bitmap
    # default (it has no Cyrillic: the first reel lost its lines so).
    for p in (path, FONT):
        try:
            return ImageFont.truetype(p, size)
        except OSError:
            continue
    raise SystemExit('no font with Cyrillic: install DejaVu Sans')


def wrap(draw, xy, text, fnt, fill, width, gap=8):
    x, y = xy
    for line in textwrap.wrap(text, width):
        draw.text((x, y), line, font=fnt, fill=fill)
        y += fnt.size + gap
    return y


def card(title, sub):
    img = Image.new('RGB', (W, H), INK)
    d = ImageDraw.Draw(img)
    d.text((80, 260), title, font=font(FONT, 44), fill=PAPER)
    wrap(d, (80, 330), sub, font(FONT, 24), GREY, 80)
    return np.asarray(img, dtype=np.uint8)


def hold(frame, frames):
    for _ in range(frames):
        yield frame


def shot_frames(n, item, frames):
    """The frames of one insight: the picture pushing in slowly on the
    left, the words on the right, an ink vignette as in the game."""
    src = Image.open(ROOT / 'godot' / item['image'].replace('res://', ''))
    src = src.convert('RGB').resize((660, 660))
    back = src.resize((W, H)).filter(ImageFilter.GaussianBlur(28))
    back = Image.blend(back, Image.new('RGB', (W, H), INK), 0.78)
    panel = Image.new('RGB', (W, H))
    panel.paste(back)
    d = ImageDraw.Draw(panel)
    d.text((740, 60), '%d / 12 · %s' % (n, EPOCHS.get(item['epoch'],
                                                      item['epoch'])),
           font=font(FONT, 22), fill=AMBER)
    d.text((740, 96), FACTORS.get(item['factor'], item['factor']),
           font=font(FONT, 18), fill=GREY)
    y = wrap(d, (740, 160), item['line_ru'], font(FONT_I, 30), PAPER, 34,
             10)
    d.text((740, y + 24), 'что объясняет:', font=font(FONT, 17),
           fill=AMBER)
    wrap(d, (740, y + 52), item['explains'], font(FONT, 18), GREY, 46, 6)
    for i in range(frames):
        k = 1.0 + 0.06 * i / max(1, frames - 1)
        side = int(660 / k)
        off = (660 - side) // 2
        pic = src.crop((off, off, off + side, off + side)).resize((600,
                                                                  600))
        f = panel.copy()
        f.paste(pic, (60, 60))
        yield np.asarray(f, dtype=np.uint8)


def scenes(data):
    """The segments as (frame count, frame generator), made lazily so a
    shot's frames never sit in memory all at once."""
    items = [i for i in data['insights'] if i.get('image')]
    title = card('Атлас воды · серия 1 · инсайты',
                 'Двенадцать воспоминаний других эпох. Каждое приходит '
                 'само — по месту, порядку, времени, глубине, находке, '
                 'ступени помысла или неподвижности — и объясняет '
                 'закон мира. Музыка: сюита «Наука. Любовь. '
                 'Познание.»')
    end = card('Каждая эпоха — читатель предыдущей',
               'Кадры: Blender Cycles, seed 1375, по промтам хора '
               'сценаристов. Видео собрано scripts/video/insights_reel.py; '
               'в игре кадр приходит в шлеме, пропуск — стиком, '
               'рукоятями или взглядом на значок.')
    seq = [(int(TITLE_S * FPS), lambda: hold(title, int(TITLE_S * FPS)))]
    for n, item in enumerate(items, 1):
        seq.append((int(SHOT_S * FPS),
                    lambda n=n, item=item: shot_frames(
                        n, item, int(SHOT_S * FPS))))
    seq.append((int(END_S * FPS), lambda: hold(end, int(END_S * FPS))))
    return seq


def write(seq, out, music):
    """Pipe the frames to ffmpeg; each cut is a FADE_S cross fade, so
    the last frames of a segment are held back and mixed into the
    first of the next."""
    out.parent.mkdir(parents=True, exist_ok=True)
    fade = int(FADE_S * FPS)
    total = sum(n for n, _ in seq) - fade * (len(seq) - 1)
    cmd = ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
           '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', '%dx%d' % (W, H),
           '-r', str(FPS), '-i', '-']
    if music.exists():
        cmd += ['-i', str(music), '-map', '0:v', '-map', '1:a',
                '-c:a', 'aac', '-b:a', '128k', '-af',
                'afade=t=out:st=%.2f:d=3' % (total / FPS - 3.0)]
    cmd += ['-c:v', 'libx264', '-preset', 'slow', '-crf', '24',
            '-pix_fmt', 'yuv420p', '-movflags', '+faststart', '-t',
            '%.3f' % (total / FPS), str(out)]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    tail = []
    for k, (_, make) in enumerate(seq):
        last = k == len(seq) - 1
        held = []
        for i, f in enumerate(make()):
            if i < len(tail):
                a = (i + 1) / (fade + 1)
                f = (tail[i].astype(np.float32) * (1 - a)
                     + f.astype(np.float32) * a).astype(np.uint8)
                p.stdin.write(f.tobytes())
                continue
            held.append(f)
            if not last and len(held) > fade:
                p.stdin.write(held.pop(0).tobytes())
        if last:
            for f in held:
                p.stdin.write(f.tobytes())
        tail = held
    p.stdin.close()
    if p.wait() != 0:
        raise SystemExit('ffmpeg failed')
    return total / FPS


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--out', default=str(OUT))
    args = ap.parse_args(argv)
    data = json.loads(DATA.read_text(encoding='utf-8'))
    seconds = write(scenes(data), Path(args.out), MUSIC)
    size = Path(args.out).stat().st_size
    print('%s: %.1f s, %d bytes, music %s' % (
        args.out, seconds, size, 'on' if MUSIC.exists() else 'absent'))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
