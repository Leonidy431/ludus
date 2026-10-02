"""The blockbuster intro of every next launch, as a preview video
(docs/story/INTRO_SIERRA_ECOQUEST_2026-10-02.md, godot/data/intro-ep1.json).

Shots are made only of what the game has: proof frames of the pilot's
scenes, the Blender turntables of the close-ups, title cards drawn here.
The narrator's lines are spoken by the DRAFT voice (Piper "irina", Д-22);
the sonar ping is synthesised here (a decaying 1.5 kHz tone), the water
is a low room tone.  Subtitles are wrapped to stay inside the frame.

    python3 scripts/prerender/build_intro.py [--variant virtue]

Constitution: ФОРМА (what the pilot showed and what the player chose)
→ ДЕЙСТВИЕ (recall it in ninety seconds, wonder → mystery → choice →
mark → title) → ЦЕЛЬ (the player enters the courtyard remembering the
choice he made, not a trailer of someone else's).
"""

import json
import math
import struct
import subprocess
import sys
import wave
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts' / 'prerender'))
import build_closeups as B  # noqa: E402

AUDIT = ROOT / 'docs' / 'audit' / '2026-10-02'
TURN = ROOT / 'build' / 'turntable'
WORK = ROOT / 'build' / 'intro'
W, H, FPS = 1280, 720, 24
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
FONT_B = '/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf'

# Each shot id -> a still of the pilot, or a turntable, or a card.
STILL = {
    'room_water': 'pilot-02-water.png',
    'lake_wonder': 'pilot-04-walls.png',
    'walls_whole': 'pilot-04-walls.png',
    'thermocline': 'pilot-03-immersion.png',
    'tether_bookmark': 'pilot-03-immersion.png',
    'khachkar_far': 'pilot-06-khachkar.png',
    'mark_line': 'pilot-16-closeup-diary.png',
    'comet_mark': 'pilot-08-mark.png',
    'prior_last': 'pilot-08-mark.png',
}
TURNS = {'amphora_turn': 'amphora', 'drams_lure': 'drams',
         'diary_scan': 'diary'}
LURE = 'pilot-05-lure.png'


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


def card(path, shot):
    img = Image.new('RGB', (W, H), (8, 7, 6))
    d = ImageDraw.Draw(img)
    if shot['id'] == 'open_black':
        for r, a in ((60, 120), (110, 70), (170, 35)):
            d.ellipse((W / 2 - r, H / 2 - r, W / 2 + r, H / 2 + r),
                      outline=(40, a + 60, a + 90), width=2)
    else:
        # Birch bark and gold, the style's charter (TABOO 0.38).
        d.rectangle((140, 230, W - 140, H - 230), fill=(214, 200, 168))
        f = ImageFont.truetype(FONT_B, 76)
        text = 'АТЛАС ВОДЫ'
        tw = d.textlength(text, font=f)
        d.text(((W - tw) / 2, 290), text, font=f, fill=(150, 108, 30))
    img.save(path)


def frame(shot, src, out):
    """One shot's base picture, with the screen text and the subtitle
    drawn inside the frame."""
    img = Image.open(src).convert('RGB').resize((W, H))
    d = ImageDraw.Draw(img)
    if shot.get('text_ru'):
        f = ImageFont.truetype(FONT, 26)
        lines = wrap(d, shot['text_ru'], f, W - 260)
        y = 40
        for ln in lines[:3]:
            tw = d.textlength(ln, font=f)
            d.text(((W - tw) / 2, y), ln, font=f, fill=(140, 230, 255),
                   stroke_width=2, stroke_fill=(0, 0, 0))
            y += 34
    if shot.get('narration_ru'):
        f = ImageFont.truetype(FONT, 28)
        lines = wrap(d, shot['narration_ru'], f, W - 200)
        y = H - 40 - 36 * len(lines)
        d.rectangle((70, y - 12, W - 70, H - 28), fill=(0, 0, 0))
        for ln in lines:
            tw = d.textlength(ln, font=f)
            d.text(((W - tw) / 2, y), ln, font=f, fill=(255, 226, 168))
            y += 36
    f = ImageFont.truetype(FONT, 14)
    d.text((14, 12), 'черновой голос · превью', font=f,
           fill=(200, 200, 200))
    img.save(out)


def ping_track(seconds, out, lake_ranges, quiet=()):
    rate = 22050
    n = int(seconds * rate)
    buf = [0.0] * n
    for i in range(n):
        buf[i] = 0.004 * math.sin(i * 0.013) * math.sin(i * 0.0007)
    for a, b in lake_ranges:
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
    # only the narrator speaks (operator, 2026-10-02: «звук когда
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


def main():
    variant = (sys.argv[sys.argv.index('--variant') + 1]
               if '--variant' in sys.argv else 'virtue')
    intro = json.loads((ROOT / 'godot' / 'data' / 'intro-ep1.json')
                       .read_text(encoding='utf-8'))
    shots = [s for s in intro['shots']
             if s.get('variant', 'all') in ('all', variant)]
    shots.sort(key=lambda s: s['t'])
    WORK.mkdir(parents=True, exist_ok=True)
    total = float(intro['length_s'])
    segs, voices, lake, quiet = [], [], [], []
    for i, s in enumerate(shots):
        end = shots[i + 1]['t'] if i + 1 < len(shots) else total
        dur = end - s['t']
        if s['world'] == 'lake':
            lake.append((s['t'], end))
        seg = WORK / ('seg%02d.mp4' % i)
        if s['id'] in TURNS:
            quiet.append((s['t'], end))
            fr = WORK / ('turn%02d' % i)
            fr.mkdir(exist_ok=True)
            for k in range(24):
                frame(s, TURN / TURNS[s['id']] / ('f%02d.png' % k),
                      fr / ('f%02d.png' % k))
            subprocess.run(['ffmpeg', '-y', '-loglevel', 'error',
                            '-stream_loop', '-1', '-framerate', '8', '-i',
                            str(fr / 'f%02d.png'), '-t', str(dur), '-vf',
                            'fps=%d,fade=in:0:12' % FPS, '-pix_fmt',
                            'yuv420p', str(seg)], check=True)
        else:
            src = WORK / ('card%02d.png' % i)
            if s['world'] in ('void', 'title'):
                card(src, s)
            elif s['id'].startswith('echo_'):
                src = AUDIT / LURE
            else:
                src = AUDIT / STILL.get(s['id'], 'pilot-04-walls.png')
            still = WORK / ('still%02d.png' % i)
            frame(s, src, still)
            # A slow push-in: no camera motion in the headset, but a
            # preview on a screen may breathe.
            subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-loop',
                            '1', '-i', str(still), '-t', str(dur), '-vf',
                            "zoompan=z='min(zoom+0.0006,1.06)':d=%d:s=%dx%d:"
                            "fps=%d,fade=in:0:12" % (int(dur * FPS), W, H,
                                                     FPS),
                            '-pix_fmt', 'yuv420p', str(seg)], check=True)
        segs.append(seg)
        if s.get('narration_ru'):
            wav = WORK / ('v%02d.wav' % i)
            B.speak(s['narration_ru'], wav)
            voices.append((s['t'] + 0.6, wav))
    lst = WORK / 'list.txt'
    lst.write_text(''.join("file '%s'\n" % p for p in segs),
                   encoding='utf-8')
    video = WORK / 'video.mp4'
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'concat',
                    '-safe', '0', '-i', str(lst), '-c', 'copy', str(video)],
                   check=True)
    ping = WORK / 'ping.wav'
    ping_track(total, ping, lake, quiet)
    cmd = ['ffmpeg', '-y', '-loglevel', 'error', '-i', str(video), '-i',
           str(ping)]
    filt = []
    for k, (at, wav) in enumerate(voices):
        cmd += ['-i', str(wav)]
        filt.append('[%d:a]adelay=%d|%d[v%d]' % (k + 2, int(at * 1000),
                                                 int(at * 1000), k))
    mix = '[1:a]' + ''.join('[v%d]' % k for k in range(len(voices)))
    filt.append('%samix=inputs=%d:normalize=0[a]'
                % (mix, len(voices) + 1))
    out = AUDIT / ('intro-%s.mp4' % variant)
    cmd += ['-filter_complex', ';'.join(filt), '-map', '0:v', '-map',
            '[a]', '-c:v', 'libx264', '-crf', '23', '-pix_fmt', 'yuv420p',
            '-c:a', 'aac', '-b:a', '96k', '-t', str(total), str(out)]
    subprocess.run(cmd, check=True)
    print('intro', out, out.stat().st_size, 'B,', len(shots), 'shots,',
          len(voices), 'lines')


if __name__ == '__main__':
    main()
