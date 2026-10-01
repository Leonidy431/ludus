"""Measure the offline render of the path of the witness.

Reads the WAV files that tools/render_witness_audio.gd writes and prints
the numbers recorded in docs/HLD_WITNESS_SOUND_2026-09-30.md: peak and
RMS in dBFS, the longest run of digital zero, the ison's fundamental
and formant balance, and the благовестник's partials and doublet beats.
It exits non-zero when a rule is broken, so the numbers are a check and
not only a report.

    python3 godot/tools/witness_wav_check.py <dir>
"""

import struct
import sys

import numpy as np

RATE = 22050


def read_wav(path):
    """Return the float32 stereo samples of a format-3 WAV as (n, 2)."""
    with open(path, 'rb') as f:
        data = f.read()
    # The writer puts a 44-byte header before the data chunk.
    count = struct.unpack('<I', data[40:44])[0] // 4
    samples = np.frombuffer(data[44:44 + count * 4], dtype='<f4')
    return samples.reshape(-1, 2).astype(np.float64)


def db(x):
    return 20.0 * np.log10(max(float(x), 1e-12))


def longest_zero(stereo):
    zero = np.all(stereo == 0.0, axis=1)
    best = run = 0
    for z in zero:
        run = run + 1 if z else 0
        best = max(best, run)
    return best


def level(stereo):
    mono = stereo.mean(axis=1)
    return {
        'peak': db(np.abs(stereo).max()),
        'rms': 10.0 * np.log10(np.mean(stereo ** 2) + 1e-24),
        'zero': longest_zero(stereo),
        'mono': mono,
    }


def spectrum(mono, pad=8):
    """Magnitude spectrum with a Hann window, zero-padded for finer bins."""
    n = len(mono)
    win = np.hanning(n)
    spec = np.abs(np.fft.rfft(mono * win, n * pad))
    freqs = np.fft.rfftfreq(n * pad, 1.0 / RATE)
    return freqs, spec


def peak_near(freqs, spec, f, width):
    band = (freqs > f - width) & (freqs < f + width)
    i = np.argmax(spec[band])
    return float(freqs[band][i]), float(spec[band][i])


def beat_of(mono, f, width):
    """Split of a doublet, fitted to the partial's own envelope.

    Two equal modes f - s/2 and f + s/2 sum to a tone whose envelope is
    A exp(-b t) |cos(pi s t)|.  The partial is isolated by an FFT
    band-pass and its envelope taken by the analytic signal.  For each
    s on a 0.001 Hz grid, log A and b are fitted by least squares to
    the log envelope from 0.1 s until the partial is 30 dB down (later
    the band-pass leakage of the other partials dominates); the s with
    the smallest residual is returned.  The prime's split is so slow
    that its first null (1 / 2s, 3.8 s) comes after it has died away,
    so a null cannot be waited for: the curvature of the envelope is
    what shows the doublet.
    """
    n = len(mono)
    spec = np.fft.fft(mono)
    freqs = np.fft.fftfreq(n, 1.0 / RATE)
    keep = (freqs > f - width) & (freqs < f + width)
    env = np.abs(np.fft.ifft(np.where(keep, 2.0 * spec, 0.0)))
    t = np.arange(n) / RATE
    e0 = env[int(0.1 * RATE)]
    quiet = np.nonzero((env < e0 * 10 ** (-30 / 20)) & (t > 0.1))[0]
    end = quiet[0] if len(quiet) else n
    sel = slice(int(0.1 * RATE), end, 16)
    tt = t[sel]
    y = np.log(env[sel] + 1e-12)
    design = np.stack([np.ones_like(tt), -tt], axis=1)
    best = (np.inf, 0.0)
    for s in np.arange(0.02, 0.8, 0.001):
        c = np.abs(np.cos(np.pi * s * tt))
        ok = c > 0.05
        coef, res, _, _ = np.linalg.lstsq(design[ok], y[ok] - np.log(c[ok]),
                                          rcond=None)
        r = float(np.mean((design[ok] @ coef - (y[ok] - np.log(c[ok])))
                          ** 2))
        if r < best[0]:
            best = (r, float(s))
    return best[1]


def main(folder):
    bad = []
    lv = {}
    for name in ['room', 'ison-font', 'ison-alone', 'vespers-call',
                 'blagovest-alone', 'trezvon-pascha', 'trezvon-alone',
                 'stroke-blagovestnik']:
        lv[name] = level(read_wav('%s/%s.wav' % (folder, name)))
        v = lv[name]
        print('%-20s peak %6.1f dBFS  RMS %6.1f dBFS  zero run %d'
              % (name, v['peak'], v['rms'], v['zero']))
        if v['peak'] > -1.0:
            bad.append('%s: peak above -1 dBFS' % name)
    room = lv['room']
    if not -50.0 <= room['rms'] <= -40.0 or room['zero'] > 3:
        bad.append('room tone outside -50..-40 dBFS or digital zero')
    for name in ['room', 'ison-font', 'vespers-call', 'trezvon-pascha']:
        if lv[name]['zero'] > 3:
            bad.append('%s: digital zero' % name)

    # The ison: the week's tone 8 on Ni (130.81 Hz), the октавист an
    # octave below, vowel "a" (F1 730 Hz, F2 1090 Hz).
    mono = lv['ison-alone']['mono'][10 * RATE:]
    freqs, spec = spectrum(mono, pad=2)
    f0, a0 = peak_near(freqs, spec, 130.81, 3.0)
    f_okt, a_okt = peak_near(freqs, spec, 65.4, 2.0)
    print('ison: fundamental %.2f Hz, октавист %.2f Hz (%.1f dB)'
          % (f0, f_okt, db(a_okt / a0)))
    harm = []
    for h in range(1, 30):
        f, a = peak_near(freqs, spec, 130.81 * h, 2.0)
        harm.append((h, f, db(a / a0)))
    top = sorted(harm, key=lambda x: -x[2])[:4]
    print('ison: strongest harmonics', ', '.join(
        '%d (%.0f Hz, %.1f dB)' % t for t in top))
    if abs(f0 - 130.81) > 0.5 or abs(f_okt - 65.4) > 0.5:
        bad.append('ison off its declared tonic')
    # Formant check: harmonics near F1 of "a" are stronger than those
    # at 400 Hz, where "a" has no formant.
    near_f1 = max(h[2] for h in harm if 650 < h[1] < 820)
    low = max(h[2] for h in harm if 350 < h[1] < 450)
    print('ison: F1 region %.1f dB vs 400 Hz region %.1f dB'
          % (near_f1, low))
    if near_f1 <= low:
        bad.append('ison: no "a" formant')
    # Antiphony: left and right lean in turn.
    st = read_wav('%s/ison-alone.wav' % folder)
    cyc = int(15.0 * RATE)
    lr = []
    for k in range(0, len(st) - cyc, cyc):
        part = st[k:k + cyc]
        lr.append(db(np.sqrt(np.mean(part[:, 0] ** 2)))
                  - db(np.sqrt(np.mean(part[:, 1] ** 2))))
    print('ison: left minus right per breath cycle',
          ', '.join('%.1f dB' % x for x in lr))

    # The благовестник: five partials, hum and prime as doublets.
    names = {}
    with open('%s/stroke-blagovestnik.txt' % folder) as f:
        for line in f:
            n, fr, sp = line.split()
            names[n] = (float(fr), float(sp))
    mono = lv['stroke-blagovestnik']['mono']
    freqs, spec = spectrum(mono, pad=8)
    for n, (fr, sp) in names.items():
        got, _ = peak_near(freqs, spec, fr, 3.0)
        line = '%-8s model %8.3f Hz  measured %8.3f Hz' % (n, fr, got)
        if abs(got - fr) > 0.3:
            bad.append('partial %s missing' % n)
        if n in ('hum', 'prime'):
            beat = beat_of(mono, fr, 2.0)
            line += '  doublet %.3f Hz, fitted %.3f Hz' % (sp, beat)
            if abs(beat - sp) > 0.03:
                bad.append('doublet of %s not heard' % n)
        elif n == 'tierce':
            # Control: a single mode fits as no doublet at all.
            single = beat_of(mono, fr, 2.0)
            line += '  single mode, fitted %.3f Hz (control)' % single
            if single > 0.06:
                bad.append('the doublet fit sees doublets everywhere')
        print(line)
    for b in bad:
        print('FAIL:', b)
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1]))
