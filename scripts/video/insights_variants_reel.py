"""Two reels of the 144 insight variants of episode 1, with the suite.

The operator (2026-10-03): «расширяй время видео постепенно
эксперементируй всегда через хор».

* insights-variants-ep1.mp4: each insight runs through its twelve hours
  as a time-lapse of the day, from the blue hour before dawn to the
  deep night, every hour with its own line of the narrator.  The first
  insight lasts 6.5 s and each next one 0.8 s longer, so the reel
  slows down as it goes: the eye learns the trick on the first, and
  has time to read on the last.
* insights-variants-best-ep1.mp4: the chorus's pick of each insight
  (data 'picks'), 6.5 s each, as the original reel.

Frames come from build/insight_variants/<id>/vNN.jpg
(scripts/prerender/render_insights.py --all-variants); the layout,
fonts, cross fade and music are those of scripts/video/insights_reel.py.
Nothing is random: the same inputs give the same video.

    python3 scripts/video/insights_variants_reel.py

Constitution: ФОРМА (one memory at twelve hours) → ДЕЙСТВИЕ (watch the
day pass over it while the line keeps its meaning) → ЦЕЛЬ (the law of
the world the insight explains does not depend on the hour).
"""

import argparse
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import insights_reel as reel  # noqa: E402

ROOT = reel.ROOT
DATA = ROOT / 'godot' / 'data' / 'pilot-insight-variants.json'
BASE = ROOT / 'godot' / 'data' / 'pilot-insights.json'
BUILD = ROOT / 'build' / 'insight_variants'
W, H, FPS = reel.W, reel.H, reel.FPS
FIRST_S, GROW_S, BEST_S, DISSOLVE_S = 6.5, 0.8, 6.5, 0.25


def frame_of(iid, v):
    return Image.open(BUILD / iid / ('v%02d.jpg' % v)).convert('RGB')


def panel(n, item, var, src):
    """The still part of a frame: the blurred picture behind, the
    epoch, the hour and the narrator's line on the right."""
    back = src.resize((W, H)).filter(ImageFilter.GaussianBlur(28))
    back = Image.blend(back, Image.new('RGB', (W, H), reel.INK), 0.78)
    d = ImageDraw.Draw(back)
    d.text((740, 60), '%d / 12 · %s' % (n, reel.EPOCHS.get(
        item['epoch'], item['epoch'])), font=reel.font(reel.FONT, 22),
        fill=reel.AMBER)
    d.text((740, 96), 'v%02d · %s · %s, солнце %+.0f°' % (
        var['v'], var['time_of_day'], var['solar_time'], var['sun_elev']),
        font=reel.font(reel.FONT, 18), fill=reel.GREY)
    y = reel.wrap(d, (740, 160), var['narration_ru'],
                  reel.font(reel.FONT_I, 30), reel.PAPER, 34, 10)
    d.text((740, y + 24), 'что объясняет:', font=reel.font(reel.FONT, 17),
           fill=reel.AMBER)
    reel.wrap(d, (740, y + 52), item['explains'],
              reel.font(reel.FONT, 18), reel.GREY, 46, 6)
    return back


def pic(src, k):
    side = int(660 / k)
    off = (660 - side) // 2
    return src.resize((660, 660)).crop((off, off, off + side,
                                        off + side)).resize((600, 600))


def day_frames(n, item, variants, frames):
    """An insight through its twelve hours: each hour holds an equal
    share of the frames and dissolves into the next; the push-in runs
    across the whole day, as in the original reel."""
    iid = item['id']
    srcs = [frame_of(iid, v['v']) for v in variants]
    panels = [panel(n, item, v, s) for v, s in zip(variants, srcs)]
    per = frames / len(variants)
    dis = int(DISSOLVE_S * FPS)
    for i in range(frames):
        j = min(len(variants) - 1, int(i / per))
        k = 1.0 + 0.06 * i / max(1, frames - 1)
        f = panels[j].copy()
        f.paste(pic(srcs[j], k), (60, 60))
        into = i - int(j * per)
        if j > 0 and into < dis:
            g = panels[j - 1].copy()
            g.paste(pic(srcs[j - 1], k), (60, 60))
            f = Image.blend(g, f, (into + 1) / (dis + 1))
        yield np.asarray(f, dtype=np.uint8)


def best_frames(n, item, var, frames):
    src = frame_of(item['id'], var['v'])
    p = panel(n, item, var, src)
    for i in range(frames):
        f = p.copy()
        f.paste(pic(src, 1.0 + 0.06 * i / max(1, frames - 1)), (60, 60))
        yield np.asarray(f, dtype=np.uint8)


def write(seq, out, music):
    """reel.write, with the music looped so a longer reel never runs
    out of sound."""
    out.parent.mkdir(parents=True, exist_ok=True)
    fade = int(reel.FADE_S * FPS)
    total = sum(n for n, _ in seq) - fade * (len(seq) - 1)
    cmd = ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
           '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', '%dx%d' % (W, H),
           '-r', str(FPS), '-i', '-']
    if music.exists():
        cmd += ['-stream_loop', '-1', '-i', str(music), '-map', '0:v',
                '-map', '1:a', '-c:a', 'aac', '-b:a', '128k', '-af',
                'afade=t=out:st=%.2f:d=3' % (total / FPS - 3.0)]
    cmd += ['-c:v', 'libx264', '-preset', 'medium', '-crf', '24',
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


def cards(title, sub):
    t = int(reel.TITLE_S * FPS)
    e = int(reel.END_S * FPS)
    a = reel.card(title, sub)
    b = reel.card('Смысл один в любой час',
                  'Кадры: Blender Cycles, seed 1375 + номер варианта, '
                  'солнце по широте и дате места. Выбор — хор: оператор, '
                  'гаффер, VR-комфорт, шоураннер, катехизатор, историк, '
                  'Аристотель-скептик.')
    return (t, lambda: reel.hold(a, t)), (e, lambda: reel.hold(b, e))


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--out-dir', default=str(BUILD))
    args = ap.parse_args(argv)
    data = json.loads(DATA.read_text(encoding='utf-8'))
    base = json.loads(BASE.read_text(encoding='utf-8'))
    items = [i for i in base['insights'] if i['id'] in data['variants']]
    title, end = cards('Атлас воды · серия 1 · инсайты в 12 часах дня',
                       'Каждое воспоминание проходит свой день: синий '
                       'час, заря, восход, утро, полдень, золотой час, '
                       'закат, сумерки, луна, глухая ночь. Другая точка '
                       'камеры, другой свет, другая строка — тот же '
                       'закон мира. Каждое следующее длится дольше.')
    seq = [title]
    durations = []
    for n, item in enumerate(items):
        sec = FIRST_S + GROW_S * n
        durations.append(sec)
        fr = int(round(sec * FPS))
        seq.append((fr, lambda n=n, item=item, fr=fr: day_frames(
            n + 1, item, data['variants'][item['id']], fr)))
    seq.append(end)
    out = Path(args.out_dir) / 'insights-variants-ep1.mp4'
    s = write(seq, out, reel.MUSIC)
    print('%s: %.1f s (insights %s s), %d bytes' % (
        out, s, ', '.join('%.1f' % d for d in durations),
        out.stat().st_size))
    title, end = cards('Атлас воды · серия 1 · выбор хора',
                       'Из двенадцати часов каждого инсайта хор выбрал '
                       'один: он и идёт в шлем на приёмку оператору.')
    seq = [title]
    picks = data.get('picks', {})
    for n, item in enumerate(items):
        var = data['variants'][item['id']][picks.get(item['id'], 1) - 1]
        fr = int(BEST_S * FPS)
        seq.append((fr, lambda n=n, item=item, var=var, fr=fr: best_frames(
            n + 1, item, var, fr)))
    seq.append(end)
    out = Path(args.out_dir) / 'insights-variants-best-ep1.mp4'
    s = write(seq, out, reel.MUSIC)
    print('%s: %.1f s, %d bytes' % (out, s, out.stat().st_size))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
