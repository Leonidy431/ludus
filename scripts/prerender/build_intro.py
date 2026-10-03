"""The recap of every next launch, «Ранее в „Атласе воды“», as a
preview video (godot/data/intro-ep1.json, chorus review 2026-10-03).

Shots are made only of what the game has, named by each shot's `src`:
`card` (drawn here), `audit:` (proof frames of the pilot's scenes),
`prerender:` (the insight frames in godot/art/prerender) and `turn:`
(the Blender turntables of the close-ups).  The narrator speaks with
the DRAFT voice (Piper, Д-22); the companion Claud speaks his own draft
lines from build/voice/claud/ru (TABOO 0.026).  The sonar ping is
synthesised here and sounds only where a shot asks for it: never at
the kayrak, where the machine falls silent (TABOO 0.4 p. 2, 0.027).

Every voice must end at least 0.1 s before its shot ends and two voices
never overlap in a shot; otherwise the build stops with the shot id
(`fit_rule` of the JSON).

    python3 scripts/prerender/build_intro.py [--variant virtue]
        [--out DIR]

Constitution: ФОРМА (what the pilot showed, what the player chose, and
the chain of readers of the diary) → ДЕЙСТВИЕ (recall it in ninety
seconds: the readers, the price, the player's choice and its rhyme in
1374, silence at the kayrak, the cut line) → ЦЕЛЬ (the player enters
the courtyard remembering the choice he made, not someone's trailer).
"""

import json
import math
import shutil
import struct
import subprocess
import sys
import wave
from pathlib import Path

from PIL import (Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter,
                 ImageFont)

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts' / 'prerender'))
import build_closeups as B  # noqa: E402

AUDIT = ROOT / 'docs' / 'audit' / '2026-10-02'
PRERENDER = ROOT / 'godot' / 'art' / 'prerender'
TURN = ROOT / 'build' / 'turntable'
CLAUD = ROOT / 'build' / 'voice' / 'claud' / 'ru'
WORK = ROOT / 'build' / 'intro'
W, H, FPS = 1280, 720, 24
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
FONT_B = '/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf'

# Colours: cyan belongs to Claud alone, so the Prior's and the
# console's screen text is light grey (chorus edit 5).
NARRATOR = (255, 226, 168)
CLAUD_C = (140, 230, 255)
SCREEN = (220, 220, 210)
BARK = (214, 200, 168)
GOLD = (150, 108, 30)
CHARCOAL = (90, 85, 80)
DEEP = (2, 8, 10)
NARRATOR_AT = 0.3
CLAUD_AT = 0.2
MARGIN = 0.1


def wrap(draw, text, font, width):
    words, lines, cur = text.split(), [], ''
    for w in words:
        test = (cur + ' ' + w).strip()
        if draw.textlength(test, font=font) > width and cur:
            lines.append(cur)
            cur = w
        else:
            cur = test
    if cur:
        lines.append(cur)
    return lines


def bark():
    """Birch bark: the base colour, a grain of noise stretched along the
    bark and a few dark lenticels at fixed places (no randomness)."""
    w, h = W - 280, H - 460
    noise = Image.effect_noise((w // 8, h), 40).resize((w, h))
    base = Image.new('RGB', (w, h), BARK)
    grain = Image.merge('RGB', (noise, noise, noise))
    img = Image.blend(base, ImageChops.multiply(base, grain), 0.35)
    d = ImageDraw.Draw(img)
    # Lenticels only along the edges: inside the text band a dark dash
    # reads as a stray hyphen next to the title and the teaser.
    for k in range(16):
        x = (k * 337) % (w - 60) + 20
        y = (6 + (k * 5) % 14) if k % 2 else (h - 22 + (k * 3) % 14)
        d.line((x, y, x + 14 + (k * 7) % 24, y), fill=(70, 60, 50),
               width=3)
    return img


def card(shot):
    img = Image.new('RGB', (W, H), (8, 7, 6))
    d = ImageDraw.Draw(img)
    if shot['id'] == 'open_black':
        for r, a in ((60, 120), (110, 70), (170, 35)):
            d.ellipse((W / 2 - r, H / 2 - r, W / 2 + r, H / 2 + r),
                      outline=(40, a + 60, a + 90), width=2)
        return img
    # The title: gold scratched into birch bark, the style's charter of
    # the interface (TABOO 0.38 p. 3); the teaser is written in charcoal.
    img.paste(bark(), (140, 230))
    f = ImageFont.truetype(FONT_B, 76)
    text = 'АТЛАС ВОДЫ'
    tw = d.textlength(text, font=f)
    x, y = (W - tw) / 2, 262
    d.text((x + 2, y + 2), text, font=f, fill=(90, 70, 40))
    d.text((x, y), text, font=f, fill=GOLD)
    if shot.get('teaser_ru'):
        f = ImageFont.truetype(FONT, 30)
        tw = d.textlength(shot['teaser_ru'], font=f)
        d.text(((W - tw) / 2, 380), shot['teaser_ru'], font=f,
               fill=CHARCOAL)
    return img


def fit(img):
    """A source of another shape (the square insight frames) is shown
    whole on a blurred, darkened copy of itself, never stretched."""
    if abs(img.width / img.height - W / H) < 0.01:
        return img.resize((W, H))
    k = max(W / img.width, H / img.height)
    back = img.resize((int(img.width * k) + 1, int(img.height * k) + 1))
    back = back.crop(((back.width - W) // 2, (back.height - H) // 2,
                      (back.width - W) // 2 + W, (back.height - H) // 2 + H))
    back = ImageEnhance.Brightness(
        back.filter(ImageFilter.GaussianBlur(24))).enhance(0.45)
    k = min(W / img.width, H / img.height)
    fg = img.resize((int(img.width * k), int(img.height * k)))
    back.paste(fg, ((W - fg.width) // 2, (H - fg.height) // 2))
    return back


def source(s, i):
    """The picture of a shot by its `src` (chorus edit 1)."""
    src = s['src']
    if src == 'card':
        return card(s)
    kind, name = src.split(':', 1)
    if kind == 'audit':
        return Image.open(AUDIT / name).convert('RGB')
    if kind == 'prerender':
        return Image.open(PRERENDER / name).convert('RGB')
    if kind == 'turn':
        return TURN / name
    raise SystemExit('shot %s: unknown src %r' % (s['id'], src))


def apply_fx(img, s, variant, grades):
    """Crop, place, lift, dim and the branch grade (chorus edit 2)."""
    fx = s.get('fx', {})
    if 'crop' in fx:
        img = img.crop(tuple(fx['crop']))
    img = fit(img)
    if 'place' in fx:
        # Small and to the side, on the edge of the beam: the kayrak is
        # not a target in the centre of the frame (TABOO 0.4, 0.027).
        p = fx['place']
        small = img.resize((int(W * p['scale']), int(H * p['scale'])))
        mask = Image.new('L', small.size, 0)
        ImageDraw.Draw(mask).ellipse(
            (small.width * 0.08, small.height * 0.08,
             small.width * 0.92, small.height * 0.92), fill=255)
        mask = mask.filter(ImageFilter.GaussianBlur(small.width / 14))
        x = int(p['cx'] * W - small.width / 2)
        y = int(p['cy'] * H - small.height / 2)
        x = max(0, min(W - small.width, x))
        y = max(0, min(H - small.height, y))
        canvas = Image.new('RGB', (W, H), DEEP)
        canvas.paste(small, (x, y), mask)
        img = canvas
    if 'lift' in fx:
        img = ImageEnhance.Brightness(img).enhance(fx['lift'])
    if 'dim' in fx:
        img = ImageEnhance.Brightness(img).enhance(fx['dim'])
    colour = grades.get(variant)
    if s.get('grade') and colour:
        img = Image.blend(img, Image.new('RGB', (W, H), tuple(colour)),
                          0.12)
    return img


def draw_text(img, s, say):
    """Screen text, and the one voice heard now: the narrator's plate or
    Claud's cyan line (never two subtitles at once)."""
    img = img.copy()
    d = ImageDraw.Draw(img)
    fx = s.get('fx', {})
    top = fx.get('sub_top', False)
    if s.get('text_ru') and s['world'] != 'title':
        f = ImageFont.truetype(FONT, 26)
        lines = wrap(d, s['text_ru'], f, W - 260)[:3]
        y = H - 60 - 34 * len(lines) if top else 40
        for ln in lines:
            tw = d.textlength(ln, font=f)
            d.text(((W - tw) / 2, y), ln, font=f, fill=SCREEN,
                   stroke_width=2, stroke_fill=(0, 0, 0))
            y += 34
    if say == 'narrator' and s.get('narration_ru'):
        f = ImageFont.truetype(FONT, 28)
        lines = wrap(d, s['narration_ru'], f, W - 200)
        y = 52 if top else H - 60 - 36 * len(lines)
        d.rectangle((70, y - 12, W - 70, y + 36 * len(lines) + 12),
                    fill=(0, 0, 0))
        for ln in lines:
            tw = d.textlength(ln, font=f)
            d.text(((W - tw) / 2, y), ln, font=f, fill=NARRATOR)
            y += 36
    if say == 'claud' and s.get('claud_ru'):
        f = ImageFont.truetype(FONT, 26)
        lines = wrap(d, 'КЛАУД · ' + s['claud_ru'], f, W - 260)
        y = H - 60 - 34 * len(lines) - 70
        width = max(d.textlength(ln, font=f) for ln in lines)
        d.rectangle((80, y - 10, 110 + width, y + 34 * len(lines) + 6),
                    fill=(0, 10, 14))
        for ln in lines:
            d.text((96, y), ln, font=f, fill=CLAUD_C)
            y += 34
    if not fx.get('no_label'):
        f = ImageFont.truetype(FONT, 14)
        d.text((14, 12), 'черновой голос · превью', font=f,
               fill=(200, 200, 200))
    return img


def duration(path):
    out = subprocess.run(['ffprobe', '-v', 'error', '-show_entries',
                          'format=duration', '-of', 'csv=p=0', str(path)],
                         capture_output=True, text=True, check=True)
    return float(out.stdout.strip())


def ping_track(seconds, out, ping_ranges, quiet=()):
    rate = 22050
    n = int(seconds * rate)
    buf = [0.0] * n
    for i in range(n):
        buf[i] = 0.004 * math.sin(i * 0.013) * math.sin(i * 0.0007)
    for a, b in ping_ranges:
        t = a + 1.0
        while t < b:
            s0 = int(t * rate)
            for k in range(int(1.2 * rate)):
                if s0 + k < n:
                    env = math.exp(-k / (0.18 * rate))
                    buf[s0 + k] += 0.18 * env * math.sin(
                        2 * math.pi * 1500 * k / rate)
            t += 4.0
    # While a thing's examine video is on screen, its world is silent:
    # only the voice speaks (operator, 2026-10-02: «звук когда
    # вставляешь видео предметов, звук с предметов отключай»).
    for a, b in quiet:
        for i in range(int(a * rate), min(n, int(b * rate))):
            buf[i] = 0.0
    with wave.open(str(out), 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, v))
                                                     * 32000))
                               for v in buf))


def voices_of(s, i, end):
    """The voices of one shot with their start and length, checked
    against the shot's end and against each other (chorus edit 6)."""
    got = []
    if s.get('claud_voice'):
        ogg = CLAUD / (s['claud_voice'] + '.ogg')
        if not ogg.exists():
            raise SystemExit('shot %s: no Claud voice %s'
                             % (s['id'], ogg))
        at = s['t'] + CLAUD_AT
        got.append(('claud', at, duration(ogg), ogg))
    if s.get('narration_ru'):
        wav = WORK / ('v%02d.wav' % i)
        length = B.speak(s['narration_ru'], wav)
        at = s['t'] + s.get('voice_at', NARRATOR_AT)
        got.append(('narrator', at, length, wav))
    got.sort(key=lambda v: v[1])
    for k, (who, at, length, _) in enumerate(got):
        if at + length > end - MARGIN:
            raise SystemExit('fit: shot %s, %s voice ends at %.2f s, '
                             'shot ends at %.2f s'
                             % (s['id'], who, at + length, end))
        if k and got[k - 1][1] + got[k - 1][2] > at:
            raise SystemExit('fit: shot %s, voices overlap at %.2f s'
                             % (s['id'], at))
    return got


def encode(s, still, start, end, first, last, seg):
    """One part of a shot from a still: a slow push-in on a screen
    preview, but never at the kayrak (`no_push`), and a fade-out where
    the shot asks for one (chorus edit 4)."""
    fx = s.get('fx', {})
    frames = round(end * FPS) - round(start * FPS)
    vf = []
    if fx.get('no_push'):
        vf.append('fps=%d' % FPS)
    else:
        z0 = 1.0 + 0.0006 * round((start - s['t']) * FPS)
        vf.append("zoompan=z='min(%.4f+0.0006*on,1.06)':d=%d:s=%dx%d:"
                  "fps=%d" % (z0, frames, W, H, FPS))
    if first:
        vf.append('fade=in:0:12')
    if last and fx.get('fade_out_s'):
        n = round(fx['fade_out_s'] * FPS)
        vf.append('fade=out:%d:%d' % (frames - n, n))
    if last and s['world'] == 'title':
        vf.append('fade=out:%d:%d' % (frames - FPS, FPS))
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-loop', '1',
                    '-framerate', str(FPS), '-i', str(still), '-vf',
                    ','.join(vf), '-frames:v', str(frames), '-pix_fmt',
                    'yuv420p', str(seg)], check=True)


def main():
    variant = (sys.argv[sys.argv.index('--variant') + 1]
               if '--variant' in sys.argv else 'virtue')
    outdir = (Path(sys.argv[sys.argv.index('--out') + 1])
              if '--out' in sys.argv else AUDIT)
    intro = json.loads((ROOT / 'godot' / 'data' / 'intro-ep1.json')
                       .read_text(encoding='utf-8'))
    grades = intro.get('branch_grade', {})
    shots = [s for s in intro['shots']
             if s.get('variant', 'all') in ('all', variant)]
    shots.sort(key=lambda s: s['t'])
    shutil.rmtree(WORK, ignore_errors=True)
    WORK.mkdir(parents=True)
    total = float(intro['length_s'])
    segs, voices, pings, quiet = [], [], [], []
    for i, s in enumerate(shots):
        end = shots[i + 1]['t'] if i + 1 < len(shots) else total
        got = voices_of(s, i, end)
        voices += [(at, path) for _, at, _, path in got]
        if s.get('ping'):
            pings.append((s['t'], end))
        pic = source(s, i)
        if isinstance(pic, Path):
            # A turntable of a thing: its world falls silent.
            quiet.append((s['t'], end))
            fr = WORK / ('turn%02d' % i)
            fr.mkdir()
            for k in range(24):
                img = Image.open(pic / ('f%02d.png' % k)).convert('RGB')
                img = apply_fx(img, s, variant, grades)
                draw_text(img, s, 'claud').save(fr / ('f%02d.png' % k))
            seg = WORK / ('seg%02d.mp4' % i)
            frames = round(end * FPS) - round(s['t'] * FPS)
            subprocess.run(['ffmpeg', '-y', '-loglevel', 'error',
                            '-stream_loop', '-1', '-framerate', '8', '-i',
                            str(fr / 'f%02d.png'), '-vf',
                            'fps=%d,fade=in:0:12' % FPS, '-frames:v',
                            str(frames), '-pix_fmt', 'yuv420p', str(seg)],
                           check=True)
            shutil.rmtree(fr)
            segs.append(seg)
            continue
        base = apply_fx(pic, s, variant, grades)
        # One part per voice, so a subtitle is on screen only while its
        # voice may speak; the switch is where the second voice begins.
        cuts = [s['t']] + [at for _, at, _, _ in got[1:]] + [end]
        whos = [v[0] for v in got] or ['narrator']
        for k in range(len(cuts) - 1):
            still = WORK / ('still%02d_%d.png' % (i, k))
            draw_text(base, s, whos[min(k, len(whos) - 1)]).save(still)
            seg = WORK / ('seg%02d_%d.mp4' % (i, k))
            encode(s, still, cuts[k], cuts[k + 1], k == 0,
                   k == len(cuts) - 2, seg)
            segs.append(seg)
    lst = WORK / 'list.txt'
    lst.write_text(''.join("file '%s'\n" % p for p in segs),
                   encoding='utf-8')
    video = WORK / 'video.mp4'
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'concat',
                    '-safe', '0', '-i', str(lst), '-c', 'copy', str(video)],
                   check=True)
    for p in segs:
        p.unlink()
    ping = WORK / 'ping.wav'
    ping_track(total, ping, pings, quiet)
    cmd = ['ffmpeg', '-y', '-loglevel', 'error', '-i', str(video), '-i',
           str(ping)]
    filt = []
    for k, (at, path) in enumerate(voices):
        cmd += ['-i', str(path)]
        filt.append('[%d:a]aresample=22050,aformat=channel_layouts=mono,'
                    'adelay=%d:all=1[v%d]' % (k + 2, int(at * 1000), k))
    mix = '[1:a]' + ''.join('[v%d]' % k for k in range(len(voices)))
    filt.append('%samix=inputs=%d:normalize=0[a]'
                % (mix, len(voices) + 1))
    outdir.mkdir(parents=True, exist_ok=True)
    out = outdir / ('intro-%s.mp4' % variant)
    cmd += ['-filter_complex', ';'.join(filt), '-map', '0:v', '-map',
            '[a]', '-c:v', 'libx264', '-crf', '23', '-pix_fmt', 'yuv420p',
            '-c:a', 'aac', '-b:a', '96k', '-t', str(total), str(out)]
    subprocess.run(cmd, check=True)
    video.unlink()
    print('intro', out, out.stat().st_size, 'B,', len(shots), 'shots,',
          len(voices), 'voices')


if __name__ == '__main__':
    main()
