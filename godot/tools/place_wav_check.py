"""Measure the offline render of the places' sound.

Reads the WAV files that tools/render_place_audio.gd writes (--out) and
prints, for each, the peak and RMS in dBFS, the longest run of digital
zero and the spectral centroid.  It exits non-zero when a rule is
broken (TABOO 0.4 rules 2 and 13: never digital zero, peak at or below
-1 dBFS; the mix of a place between -50 and -20 dBFS RMS), so the
numbers are a check and not only a report.

    python3 godot/tools/place_wav_check.py <dir> [--png=<file>]

With --png a spectrogram of every file is drawn one under another
(time to the right, 0-8 kHz upwards, log magnitude), for the eye.
"""

import os
import struct
import sys

import numpy as np

RATE = 44100
RMS_RANGE = (-50.0, -20.0)
PEAK_MAX = -1.0


def read_wav(path):
    """Return the float32 mono samples of a format-3 WAV."""
    with open(path, 'rb') as f:
        data = f.read()
    # The writer puts a 44-byte header before the data chunk.
    count = struct.unpack('<I', data[40:44])[0] // 4
    return np.frombuffer(data[44:44 + count * 4],
                         dtype='<f4').astype(np.float64)


def db(x):
    return 20.0 * np.log10(max(float(x), 1e-12))


def longest_zero(a):
    best = run = 0
    for z in (a == 0.0):
        run = run + 1 if z else 0
        best = max(best, run)
    return best


def centroid(a):
    spec = np.abs(np.fft.rfft(a * np.hanning(len(a)))) ** 2
    freqs = np.fft.rfftfreq(len(a), 1.0 / RATE)
    return float((spec * freqs).sum() / max(spec.sum(), 1e-30))


def spectrogram(a, rows=160, cols=600):
    """Log-magnitude spectrogram, 0-8 kHz, as an array of 0..255."""
    win = 2048
    hop = max(1, (len(a) - win) // cols)
    top = int(8000 / (RATE / win))
    out = np.zeros((rows, cols))
    for c in range(cols):
        seg = a[c * hop:c * hop + win]
        if len(seg) < win:
            break
        mag = np.abs(np.fft.rfft(seg * np.hanning(win)))[:top]
        idx = np.linspace(0, top - 1, rows).astype(int)
        out[:, c] = 20.0 * np.log10(mag[idx] + 1e-9)
    out = np.clip((out + 60.0) / 60.0, 0.0, 1.0)
    return (255 * out[::-1]).astype(np.uint8)


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    folder = argv[0]
    png = ''
    for a in argv[1:]:
        if a.startswith('--png='):
            png = a[len('--png='):]
    names = sorted(n for n in os.listdir(folder) if n.endswith('.wav'))
    bad = 0
    pictures = []
    for name in names:
        a = read_wav(os.path.join(folder, name))
        rms = db(np.sqrt(np.mean(a * a)))
        peak = db(np.max(np.abs(a)))
        zero = longest_zero(a)
        ok = RMS_RANGE[0] <= rms <= RMS_RANGE[1] and peak <= PEAK_MAX \
            and zero < 2
        bad += 0 if ok else 1
        print('%-34s rms %7.2f dBFS  peak %7.2f dBFS  zero %d  '
              'centroid %6.0f Hz  %s' % (name, rms, peak, zero,
                                         centroid(a), 'ok' if ok
                                         else 'BREACH'))
        pictures.append((name, spectrogram(a)))
    if png and pictures:
        from PIL import Image, ImageDraw
        h = sum(p.shape[0] + 18 for _, p in pictures)
        img = Image.new('L', (pictures[0][1].shape[1], h), 0)
        draw = ImageDraw.Draw(img)
        y = 0
        for name, p in pictures:
            draw.text((4, y + 2), name, fill=255)
            img.paste(Image.fromarray(p), (0, y + 18))
            y += p.shape[0] + 18
        img.save(png)
        print('spectrograms:', png)
    print('PLACE_WAV_CHECK', 'ok' if bad == 0 else '%d breaches' % bad)
    return 0 if bad == 0 else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
