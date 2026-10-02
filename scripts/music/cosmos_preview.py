"""Build the listening copy and the pictures of the suite
«Наука. Любовь. Познание.» from the synth the headset runs.

The suite is not a recording: godot/scripts/audio/cosmos_synth.gd
computes it live in the headset (docs/music/cosmos/README.md).  This
script makes what a person needs to hear and see it outside the
headset, the same every time:

1. render: Godot runs godot/tools/render_cosmos.gd headless and writes
   one WAV per node and suite.wav (the nine nodes in the order of the
   pilot, 40 s each, with the 8 s morph between them);
2. room: a preview reverb (a decaying noise impulse response, seeded),
   because the headset's reverb is the engine's AudioEffectReverb on
   the Music bus and cannot be captured headless; it is an
   approximation and is named so;
3. level: the listening copy is brought to -16 LUFS with a true peak
   at or below -1 dBTP (TABOO 0.4 rule 13); in the game the suite is a
   bed near -26 LUFS under the dive;
4. mp3: ffmpeg with libmp3lame, VBR quality 2, 44.1 kHz;
5. pictures: the spectrogram of the suite, one per node, the glide of
   the six voices of each node computed from the data (the picture of
   "love as the gravity that draws voices into accord"), and the
   loudness of every node.

Audio never enters the repository (scripts/raw_assets/tests/
test_audio_pass.py forbids it under docs/); the WAV and MP3 stay in
build/music/cosmos/, the pictures go to docs/music/cosmos/.

    python3 scripts/music/cosmos_preview.py
    python3 scripts/music/cosmos_preview.py --skip-render  # reuse WAVs

Needs numpy, Pillow, ffmpeg with libmp3lame and the Godot 4.7.1 editor
binary (--godot or $GODOT).

Constitution: ФОРМА (the suite as the synth computes it) → ДЕЙСТВИЕ
(render, listen, look at the glides) → ЦЕЛЬ (anyone can hear and check
what the headset plays: science as the method, love as the motive,
knowledge as the process).
"""

import argparse
import json
import math
import os
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts' / 'godot'))
import loudness  # noqa: E402  (the project's BS.1770 meter)

DATA = ROOT / 'godot' / 'data' / 'entelechy-99.json'
WORK = ROOT / 'build' / 'music' / 'cosmos'
IMAGES = ROOT / 'docs' / 'music' / 'cosmos'
GODOT = os.environ.get(
    'GODOT', '/home/user/godot-deps/Godot_v4.7.1-stable_linux.x86_64')
# The order of the pilot (godot/tools/render_cosmos.gd ORDER).
ORDER = ['I', 'V', 'VI', 'III', 'II', 'VIII', 'VII', 'IV', 'IX']
SEED = 1375
TARGET_LUFS = -16.0
CEILING_DBTP = -1.0
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
# Colours of the instrument class (TABOO 0.38: cyan only on devices).
BG = (6, 12, 16)
CYAN = (90, 230, 255)
AMBER = (255, 190, 110)
DIM = (70, 110, 120)


def font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.load_default()


def render(godot, seconds):
    """Run the headset's synth headless and write the WAVs."""
    WORK.mkdir(parents=True, exist_ok=True)
    subprocess.run([godot, '--headless', '--path', str(ROOT / 'godot'),
                    '--import'], check=False, capture_output=True)
    out = subprocess.run(
        [godot, '--headless', '--path', str(ROOT / 'godot'), '--script',
         'res://tools/render_cosmos.gd', '--',
         '--out=%s' % WORK, '--seconds=%g' % seconds],
        check=True, capture_output=True, text=True)
    for line in out.stdout.splitlines():
        if line.startswith('cosmos:'):
            print(line)


def room(x, rate):
    """The preview reverb: two decorrelated noise tails of 3.5 s with a
    0.9 s decay, convolved by FFT, 0.45 wet over 0.7 dry.  Seeded, so
    the preview is the same every time."""
    rng = np.random.default_rng(SEED)
    n_ir = int(3.5 * rate)
    t = np.arange(n_ir) / rate
    n = x.shape[1]
    size = 1 << int(math.ceil(math.log2(n + n_ir)))
    out = np.zeros((2, n + n_ir - 1))
    for c in range(2):
        ir = rng.standard_normal(n_ir) * np.exp(-t / 0.9)
        ir /= np.sqrt((ir ** 2).sum())
        wet = np.fft.irfft(np.fft.rfft(x[c], size) * np.fft.rfft(ir, size),
                           size)[:n + n_ir - 1]
        out[c] = 0.45 * wet
        out[c, :n] += 0.7 * x[c]
    return out


def level(x, rate):
    """Gain to TARGET_LUFS, then down if the true peak passes the
    ceiling.  Returns the signal and its measured numbers."""
    lufs = loudness.integrated_lufs(rate, x)
    y = x * 10 ** ((TARGET_LUFS - lufs) / 20.0)
    peak = loudness.true_peak_dbtp(y)
    if peak > CEILING_DBTP:
        y *= 10 ** ((CEILING_DBTP - peak) / 20.0)
    return y, loudness.integrated_lufs(rate, y), loudness.true_peak_dbtp(y)


def write_wav(path, x, rate):
    pcm = (np.clip(x.T, -1.0, 1.0) * 32767.0).astype('<i2')
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(pcm.tobytes())


def mp3(src, dst):
    subprocess.run(
        ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i',
         str(src), '-ar', '44100', '-c:a', 'libmp3lame', '-q:a', '2',
         '-metadata', 'title=Наука. Любовь. Познание.',
         '-metadata', 'artist=Ludus — CosmosSynth',
         '-metadata', 'comment=9 узлов Энтелехии по 40 с; '
                      'реверберация превью приближённая',
         str(dst)], check=True)


def spectrogram(mono, rate, width, height, fmax=2000.0):
    """dB spectrogram 0..fmax Hz as an RGB image in the cyan of the
    instrument; -40 dB floor, 45 dB range."""
    win, hop = 2048, 512
    frames = max(1, (len(mono) - win) // hop)
    window = np.hanning(win)
    spec = np.array([np.abs(np.fft.rfft(mono[i * hop:i * hop + win]
                                        * window))
                     for i in range(frames)]).T
    freqs = np.fft.rfftfreq(win, 1.0 / rate)
    spec = spec[freqs <= fmax]
    db = np.clip((20 * np.log10(spec + 1e-6) + 40) / 45, 0, 1)
    v = (db[::-1] * 255).astype(np.uint8)
    im = Image.fromarray(v).resize((width, height))
    return Image.merge('RGB', (im.point(lambda p: int(p * 0.25)),
                               im.point(lambda p: int(p * 0.9)), im))


def nodes():
    data = json.loads(DATA.read_text(encoding='utf-8'))
    return {n['id']: n for n in data['nodes']}


def picture_suite(x, rate, seconds, by_id):
    w, h, top = 1800, 620, 54
    img = Image.new('RGB', (w, h + top + 30), BG)
    img.paste(spectrogram(x.mean(0), rate, w, h), (0, top))
    d = ImageDraw.Draw(img)
    d.text((12, 10), 'Сюита «Наука. Любовь. Познание.» — спектрограмма '
           '0–2000 Гц, 9 узлов по %d с' % seconds, fill=CYAN,
           font=font(22))
    step = w / len(ORDER)
    for k, nid in enumerate(ORDER):
        x0 = int(k * step)
        d.line([(x0, top), (x0, top + h)], fill=(160, 100, 50))
        d.text((x0 + 6, top + 6), nid, fill=AMBER, font=font(20))
        d.text((x0 + 6, top + 30), by_id[nid]['title_ru'], fill=AMBER,
               font=font(13))
    for f in (500, 1000, 1500):
        y = top + int(h * (1 - f / 2000.0))
        d.text((w - 70, y - 8), '%d Гц' % f, fill=(200, 200, 200),
               font=font(13))
    d.text((12, top + h + 6), 'Голоса скользят из грозди к чистому '
           'созвучию и обратно (любовь), обертоны раскрываются по '
           'очереди (познание), короткие точки — чистые тона '
           '(наука).', fill=(210, 210, 210), font=font(15))
    img.save(IMAGES / 'suite-spectrogram.jpg', quality=88)


def picture_node(nid, node, rate):
    rate_s, chans = loudness.read_wav(WORK / ('cosmos-%s.wav' % nid))
    w, h, top = 900, 300, 44
    img = Image.new('RGB', (w, h + top), BG)
    img.paste(spectrogram(chans.mean(0), rate_s, w, h), (0, top))
    d = ImageDraw.Draw(img)
    d.text((10, 8), '%s · %s — %s' % (nid, node['title_ru'],
                                      node['sub_ru']),
           fill=AMBER, font=font(20))
    img.save(IMAGES / ('node-%s.jpg' % nid), quality=86)


def voice_hz(center, step, ratio, g):
    """The same glide as CosmosSynth.voice_hz."""
    f_spread = center * 2 ** (step / 72.0)
    return f_spread * (center * ratio / f_spread) ** g


def picture_glides(by_id):
    """Each node: the six voices over one cycle, computed from the data;
    dotted lines are the just ratios they are drawn to."""
    cw, ch, pad = 600, 260, 30
    img = Image.new('RGB', (cw * 3, ch * 3 + 40), BG)
    d = ImageDraw.Draw(img)
    d.text((12, 8), 'Любовь как притяжение: шесть голосов каждого узла '
           'за один цикл (по данным, без звука)', fill=CYAN,
           font=font(20))
    for k, nid in enumerate(ORDER):
        cue = by_id[nid]['cue']
        ox, oy = (k % 3) * cw, 40 + (k // 3) * ch
        d.rectangle([ox + 4, oy + 4, ox + cw - 4, oy + ch - 4],
                    outline=DIM)
        lo, hi = math.log2(40.0), math.log2(1100.0)

        def ypos(f):
            return oy + ch - pad - (math.log2(f) - lo) / (hi - lo) \
                * (ch - 2 * pad)
        for r in cue['target']:
            y = ypos(cue['center_hz'] * r)
            for xx in range(ox + pad, ox + cw - pad, 8):
                d.point((xx, y), fill=DIM)
        for v in range(6):
            pts = []
            for i in range(101):
                ph = i / 100.0
                g = cue['love'] * (0.5 - 0.5 * math.cos(2 * math.pi * ph))
                f = voice_hz(cue['center_hz'], cue['cluster'][v],
                             cue['target'][v], g)
                pts.append((ox + pad + ph * (cw - 2 * pad), ypos(f)))
            d.line(pts, fill=CYAN, width=2)
        d.text((ox + 12, oy + 10), '%s %s · цикл %d с · love %.2f'
               % (nid, by_id[nid]['title_ru'], cue['cycle_s'],
                  cue['love']), fill=AMBER, font=font(14))
    img.save(IMAGES / 'node-glides.png', optimize=True)


def picture_loudness(rows):
    w, h = 900, 360
    img = Image.new('RGB', (w, h), BG)
    d = ImageDraw.Draw(img)
    d.text((12, 8), 'Громкость узлов в игре (до превью): LUFS и '
           'истинный пик', fill=CYAN, font=font(18))
    for k, (nid, lufs, peak) in enumerate(rows):
        y = 50 + k * 32
        bar = int((lufs + 40) / 40.0 * 600)
        d.rectangle([110, y, 110 + bar, y + 20], fill=(40, 140, 160))
        d.text((12, y), nid, fill=AMBER, font=font(16))
        d.text((120 + bar, y), '%.1f LUFS · %.1f dBTP' % (lufs, peak),
               fill=(220, 220, 220), font=font(14))
    img.save(IMAGES / 'node-loudness.png', optimize=True)


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--godot', default=GODOT)
    ap.add_argument('--seconds', type=float, default=40.0)
    ap.add_argument('--skip-render', action='store_true')
    args = ap.parse_args(argv)
    IMAGES.mkdir(parents=True, exist_ok=True)
    if not args.skip_render:
        render(args.godot, args.seconds)
    by_id = nodes()
    rate, x = loudness.read_wav(WORK / 'suite.wav')
    y, lufs, peak = level(room(x, rate), rate)
    write_wav(WORK / 'suite-preview.wav', y, rate)
    mp3(WORK / 'suite-preview.wav', WORK / 'nauka-lyubov-poznanie.mp3')
    print('mp3: %s, %.1f LUFS, %.1f dBTP' % (
        WORK / 'nauka-lyubov-poznanie.mp3', lufs, peak))
    picture_suite(x, rate, args.seconds, by_id)
    rows = []
    for nid in ORDER:
        picture_node(nid, by_id[nid], rate)
        r, c = loudness.read_wav(WORK / ('cosmos-%s.wav' % nid))
        rows.append((nid, loudness.integrated_lufs(r, c),
                     loudness.true_peak_dbtp(c)))
    picture_glides(by_id)
    picture_loudness(rows)
    print('pictures:', ', '.join(sorted(p.name for p in IMAGES.glob('*')
                                        if p.suffix != '.md')))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
