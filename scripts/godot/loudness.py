"""Integrated loudness and true peak of WAV files (ITU-R BS.1770-4).

Usage:
    python3 scripts/godot/loudness.py FILE.wav [...]
    python3 scripts/godot/loudness.py --selftest

The dive mix must sit at -16 LUFS (+-2) with a true peak at or below
-1 dBTP (CLAUDE.md TABOO 0.4 rule 13).  The renders come from
godot/scripts/audio/render_mix.gd.

Method:
- K-weighting: the two BS.1770 filters (high shelf and RLB high pass),
  designed for any sample rate from their analogue prototypes, as in
  libebur128, because the renders run at 22 050 Hz, not 48 kHz.
- Gating: 400 ms blocks with 75 % overlap, absolute gate -70 LUFS and a
  relative gate 10 LU below the ungated level of the blocks above it.
- True peak: 8x band-limited oversampling by FFT zero padding (exact
  sinc interpolation of the whole file).  BS.1770 Annex 2 asks for at
  least 4x with a FIR; the FFT interpolation is at least as strict.

Needs numpy.  Supports 16-bit PCM and 32-bit float WAV.
"""

import math
import struct
import sys

import numpy as np


def read_wav(path):
    """Return (rate, samples[channels][n]) as float64 in [-1, 1]."""
    with open(path, 'rb') as f:
        data = f.read()
    if data[:4] != b'RIFF' or data[8:12] != b'WAVE':
        raise ValueError(path + ': not a RIFF WAVE file')
    pos = 12
    fmt = None
    body = None
    while pos + 8 <= len(data):
        tag = data[pos:pos + 4]
        size = struct.unpack('<I', data[pos + 4:pos + 8])[0]
        chunk = data[pos + 8:pos + 8 + size]
        if tag == b'fmt ':
            fmt = struct.unpack('<HHIIHH', chunk[:16])
        elif tag == b'data':
            body = chunk
        pos += 8 + size + (size & 1)
    if fmt is None or body is None:
        raise ValueError(path + ': no fmt or data chunk')
    code, channels, rate, _, _, bits = fmt
    if code == 3 and bits == 32:
        x = np.frombuffer(body, dtype='<f4').astype(np.float64)
    elif code == 1 and bits == 16:
        x = np.frombuffer(body, dtype='<i2').astype(np.float64) / 32768.0
    else:
        raise ValueError('%s: format %d/%d bits not supported'
                         % (path, code, bits))
    return rate, x.reshape(-1, channels).T


def biquad(x, b, a):
    """Direct form I biquad; a[0] is 1."""
    y = np.empty_like(x)
    x1 = x2 = y1 = y2 = 0.0
    b0, b1, b2 = b
    _, a1, a2 = a
    for i, v in enumerate(x.tolist()):
        out = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1 = x1, v
        y2, y1 = y1, out
        y[i] = out
    return y


def k_filters(rate):
    """Coefficients of the two K-weighting stages at this rate."""
    gain_db = 3.999843853973347
    fc = 1681.974450955533
    q = 0.7071752369554196
    k = math.tan(math.pi * fc / rate)
    vh = 10 ** (gain_db / 20)
    vb = vh ** 0.4996667741545416
    a0 = 1 + k / q + k * k
    shelf = ((vh + vb * k / q + k * k) / a0, 2 * (k * k - vh) / a0,
             (vh - vb * k / q + k * k) / a0), \
        (1.0, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0)
    fc = 38.13547087602444
    q = 0.5003270373238773
    k = math.tan(math.pi * fc / rate)
    a0 = 1 + k / q + k * k
    high = (1.0, -2.0, 1.0), \
        (1.0, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0)
    return shelf, high


def integrated_lufs(rate, chans):
    """BS.1770-4 gated integrated loudness of all channels (gain 1)."""
    shelf, high = k_filters(rate)
    weighted = []
    done = {}
    for c in chans:
        key = c.tobytes()
        if key not in done:
            done[key] = biquad(biquad(c, *shelf), *high)
        weighted.append(done[key])
    block = int(round(0.4 * rate))
    step = int(round(0.1 * rate))
    n = len(chans[0])
    powers = []
    for start in range(0, n - block + 1, step):
        z = sum(float(np.mean(w[start:start + block] ** 2))
                for w in weighted)
        powers.append(z)
    powers = np.array(powers)
    with np.errstate(divide='ignore'):
        loud = -0.691 + 10 * np.log10(powers)
    above = powers[loud > -70.0]
    if above.size == 0:
        return float('-inf')
    rel = -0.691 + 10 * math.log10(float(np.mean(above))) - 10.0
    gated = powers[(loud > -70.0) & (loud > rel)]
    return -0.691 + 10 * math.log10(float(np.mean(gated)))


def true_peak_dbtp(chans, factor=8):
    """Peak of the band-limited signal, oversampled by FFT."""
    peak = 0.0
    for c in chans:
        n = len(c)
        spec = np.fft.rfft(c)
        up = np.fft.irfft(spec, n * factor) * factor
        peak = max(peak, float(np.max(np.abs(up))),
                   float(np.max(np.abs(c))))
    return 20 * math.log10(peak) if peak > 0 else float('-inf')


def sample_peak_dbfs(chans):
    peak = max(float(np.max(np.abs(c))) for c in chans)
    return 20 * math.log10(peak) if peak > 0 else float('-inf')


def selftest():
    """Reference signals with known results (BS.1770 and BS.2217)."""
    ok = True
    for rate in (48000, 22050):
        t = np.arange(int(10 * rate)) / rate
        tone = 0.1 * np.sin(2 * math.pi * 997.0 * t)
        lufs = integrated_lufs(rate, [tone, tone])
        good = abs(lufs + 20.0) < 0.1
        ok = ok and good
        print('997 Hz, -20 dBFS, stereo at %d Hz: %.2f LUFS (expect -20.0)'
              ' %s' % (rate, lufs, 'ok' if good else 'FAIL'))
    rate = 48000
    t = np.arange(rate) / rate
    wave = 0.5 * np.sin(2 * math.pi * rate / 4 * t + math.pi / 4)
    tp = true_peak_dbtp([wave])
    sp = sample_peak_dbfs([wave])
    good = abs(tp + 6.02) < 0.05 and sp < -8.9
    ok = ok and good
    print('fs/4 sine at 45 deg: sample peak %.2f dBFS, true peak %.2f dBTP'
          ' (expect -6.02) %s' % (sp, tp, 'ok' if good else 'FAIL'))
    return ok


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    if argv[0] == '--selftest':
        return 0 if selftest() else 1
    print('%-28s %9s %9s %10s' % ('file', 'LUFS', 'dBTP', 'dBFS peak'))
    for path in argv:
        rate, chans = read_wav(path)
        lufs = integrated_lufs(rate, list(chans))
        tp = true_peak_dbtp(chans)
        sp = sample_peak_dbfs(chans)
        name = path.rsplit('/', 1)[-1]
        print('%-28s %9.2f %9.2f %10.2f' % (name, lufs, tp, sp))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
