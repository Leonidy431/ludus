/**
 * Ludus Sacred Synth: zero-asset, deterministic procedural sound.
 *
 * No recorded audio exists yet, so every catalogued cue of the audio
 * manager is rendered here from first principles instead of falling
 * silent.  The rules it follows are in docs/SOUND_THEOLOGY_RULES.md:
 *
 *   - Bells are Russian bells: five principal partials (hum, prime,
 *     tierce, quint, nominal) as described in the kolokol research,
 *     chapter 12 ("Пять частичных тонов"): hum an octave below the
 *     prime, tierce a minor third above it, quint a perfect fifth
 *     above it, nominal an octave above it.  Ratios to the prime are
 *     therefore 0.5, 1, 1.2 (just 6:5), 1.5 and 2.  Each bell gets a
 *     small fixed detuning derived from its name, because the same
 *     chapter notes that old, untuned Russian bells stray from exact
 *     intervals, and RESEARCH_NOTES.md records that Russian ringing
 *     keeps the full, untrimmed overtone spectrum (unlike a carillon).
 *   - Bells ring only in liturgical orders (благовест, трезвон,
 *     перезвон, перебор, звон в двои) and never as a reward ding.
 *   - Chant is represented only by a wordless, voice-like drone
 *     (ison), breathing with the Jesus Prayer timings of the
 *     hesychasm-meditation-module (breathing_patterns.py).
 *   - Passions get dissonant clusters that never resolve.
 *   - Nothing is random: every noise and every variation comes from a
 *     PRNG seeded by a hash of the cue (or bell) name.
 *
 * Public global: window.LudusSacredSynth.
 *   render(cueName, ctx[, options]) -> AudioBuffer (mono)
 *   renderSamples(cueName, sampleRate) -> { rate, data, loop, ... }
 */

'use strict';

(function (root) {
  const TAU = 2 * Math.PI;

  // Long looping beds are rendered at a reduced rate: the ensemble's
  // highest principal partial is below 1.4 kHz, and halving the rate
  // halves the work done on the Quest 3 main thread.
  const LONG_RATE = 24000;
  const LONG_SECONDS = 12;

  // ── Determinism ────────────────────────────────────────────────────
  // FNV-1a gives every source name its own stable 32-bit seed.
  function hashString(text) {
    let h = 0x811c9dc5;
    for (let i = 0; i < text.length; i += 1) {
      h ^= text.charCodeAt(i);
      h = Math.imul(h, 0x01000193) >>> 0;
    }
    return h >>> 0;
  }

  // Mulberry32: small, fast, and identical in every JS engine, so the
  // same cue renders bit-for-bit the same on the headset and in tests.
  function makeRng(seed) {
    let state = seed >>> 0;
    return function () {
      state = (state + 0x6d2b79f5) >>> 0;
      let t = state;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function rngFor(name) {
    return makeRng(hashString(name));
  }

  // ── Sources ────────────────────────────────────────────────────────
  // Five principal partials of a bell (kolokol, chapter 12).  "decay"
  // scales the bell's ring time: the hum carries the long after-sound
  // and the nominal is the short bright flash at the strike, exactly
  // as the chapter describes them.
  const BELL_PARTIALS = [
    { name: 'hum', ratio: 0.5, amp: 0.55, decay: 1.0, drift: 0.015 },
    { name: 'prime', ratio: 1.0, amp: 0.6, decay: 0.75, drift: 0 },
    { name: 'tierce', ratio: 1.2, amp: 0.45, decay: 0.55, drift: 0.006 },
    { name: 'quint', ratio: 1.5, amp: 0.25, decay: 0.4, drift: 0.006 },
    { name: 'nominal', ratio: 2.0, amp: 0.5, decay: 0.22, drift: 0.01 },
  ];

  // The ensemble.  The three largest bells form a C major triad, the
  // design that RESEARCH_NOTES.md records for the Rostov zvonnitsa
  // (Сысой, Полиелейный, Лебедь).  Index 0 is the благовестник, 1-2
  // are подзвонные, 3-7 are зазвонные (smallest last).
  const ENSEMBLE = [
    { name: 'blagovestnik', prime: 130.81 },
    { name: 'polieleiny', prime: 164.81 },
    { name: 'lebed', prime: 196.0 },
    { name: 'podzvon-c4', prime: 261.63 },
    { name: 'zazvon-e4', prime: 329.63 },
    { name: 'zazvon-g4', prime: 392.0 },
    { name: 'zazvon-c5', prime: 523.25 },
    { name: 'zazvon-e5', prime: 659.26 },
  ];

  // Jesus Prayer breathing patterns, copied from
  // hesychasm-meditation-module/src/hesychasm/breathing_patterns.py
  // (seconds: inhale, hold after inhale, exhale, hold after exhale).
  const BREATH = {
    basic: { inhale: 4.0, holdIn: 0.0, exhale: 6.0, holdOut: 0.0 },
    athonite: { inhale: 5.0, holdIn: 1.0, exhale: 8.0, holdOut: 1.0 },
    optina: { inhale: 4.5, holdIn: 0.0, exhale: 5.5, holdOut: 0.0 },
    sinaite: { inhale: 6.0, holdIn: 2.0, exhale: 8.0, holdOut: 0.0 },
    ignatius: { inhale: 5.0, holdIn: 0.5, exhale: 6.0, holdOut: 0.5 },
  };

  function breathCycle(pattern) {
    return pattern.inhale + pattern.holdIn + pattern.exhale +
      pattern.holdOut;
  }

  // Vowel formants (Hz, bandwidth Hz, gain).  A dark "o" for the male
  // ison and an open "a" for brighter phrases; female "a" for the
  // sisters' choir.  Standard phonetic averages (Peterson and Barney).
  const VOWELS = {
    o: [[570, 140, 1.0], [840, 160, 0.55], [2410, 220, 0.18]],
    a: [[730, 150, 1.0], [1090, 170, 0.6], [2440, 230, 0.2]],
    fa: [[850, 160, 1.0], [1220, 180, 0.6], [2810, 250, 0.2]],
  };

  // ── Bell specification ─────────────────────────────────────────────
  // A bell's detuning is seeded by the bell's own name, not by the cue,
  // so one bell has one voice in every cue it rings in.
  const bellSpecCache = new Map();

  function bellSpec(index) {
    if (bellSpecCache.has(index)) {
      return bellSpecCache.get(index);
    }
    const bell = ENSEMBLE[index];
    const rng = rngFor('bell:' + bell.name);
    const partials = BELL_PARTIALS.map(function (p) {
      const ratio = p.ratio * (1 + (rng() * 2 - 1) * p.drift);
      // Real bell partials are doublets (the bell is not perfectly
      // round), which gives the slow warble of a living bell.
      const split = 0.12 + rng() * 0.4;
      return {
        name: p.name,
        ratio: ratio,
        freq: bell.prime * ratio,
        amp: p.amp,
        decay: p.decay,
        split: split,
      };
    });
    // Bigger bells ring longer; the power law keeps the smallest
    // зазвонный bell short and bright and the благовестник long.
    const ring = Math.min(12, Math.max(1.6,
      9 * Math.pow(130.81 / bell.prime, 0.8)));
    const spec = {
      name: bell.name, prime: bell.prime, ring: ring,
      partials: partials,
    };
    bellSpecCache.set(index, spec);
    return spec;
  }

  // ── Track: a mono float buffer with loop-aware writing ─────────────
  // Loop tracks write circularly, so a bell tail near the end wraps to
  // the start and the loop seam is inaudible.
  function createTrack(seconds, rate, loop) {
    const n = Math.max(1, Math.round(seconds * rate));
    return { rate: rate, n: n, loop: loop, seconds: n / rate,
      data: new Float32Array(n) };
  }

  // A bank of decaying sinusoids by complex rotation: four multiplies
  // per mode and sample instead of a Math.sin call, and one write to
  // the track per sample for the whole bank.  Modes: [{freq, amp,
  // t60}].  Each mode stops at -60 dB (its own t60); later strokes
  // mask anything quieter.
  function addModes(tr, t0, modes, attack) {
    const rate = tr.rate;
    const list = modes.filter(function (m) {
      return m.freq > 0 && m.freq < rate * 0.45 && m.amp > 0;
    }).map(function (m) {
      return { m: m, limit: Math.min(tr.n, Math.ceil(m.t60 * rate)) };
    }).sort(function (x, y) {
      return y.limit - x.limit;
    });
    const count = list.length;
    if (!count) {
      return;
    }
    const re = new Float64Array(count);
    const im = new Float64Array(count);
    const c = new Float64Array(count);
    const s = new Float64Array(count);
    const env = new Float64Array(count);
    const d = new Float64Array(count);
    const lim = new Int32Array(count);
    list.forEach(function (e, j) {
      const w = TAU * e.m.freq / rate;
      re[j] = 1;
      c[j] = Math.cos(w);
      s[j] = Math.sin(w);
      env[j] = e.m.amp;
      d[j] = Math.pow(10, -3 / (e.m.t60 * rate));
      lim[j] = e.limit;
    });
    const a = Math.max(1, Math.round((attack || 0.002) * rate));
    const start = Math.round(t0 * rate);
    const data = tr.data;
    const n = tr.n;
    let active = count;
    const total = lim[0];
    for (let k = 0; k < total; k += 1) {
      while (active > 0 && lim[active - 1] <= k) {
        active -= 1;
      }
      let idx = start + k;
      if (idx >= n) {
        if (!tr.loop) {
          break;
        }
        idx %= n;
      }
      let sum = 0;
      for (let j = 0; j < active; j += 1) {
        sum += im[j] * env[j];
        const nre = re[j] * c[j] - im[j] * s[j];
        im[j] = re[j] * s[j] + im[j] * c[j];
        re[j] = nre;
        env[j] *= d[j];
      }
      data[idx] += k < a ? sum * k / a : sum;
      // Renormalise the rotators so rounding never lets them grow.
      if ((k & 4095) === 4095) {
        for (let j = 0; j < active; j += 1) {
          const m = 1 / Math.sqrt(re[j] * re[j] + im[j] * im[j]);
          re[j] *= m;
          im[j] *= m;
        }
      }
    }
  }

  function addPartial(tr, t0, freq, amp, t60, attack) {
    addModes(tr, t0, [{ freq: freq, amp: amp, t60: t60 }], attack);
  }

  // One strike of the tongue on the sound bow.  A harder strike
  // excites the upper partials more than the hum, as in a real bell.
  // Hum and prime are doublets (the slow warble of a real, slightly
  // out-of-round bell); the upper partials die too fast for a warble
  // to be heard, so they are single modes.
  //
  // A stroke of one bell at one strength always sounds the same, so
  // strokes are rendered once per render call and then mixed: a
  // трезвон strikes the same eight bells a hundred times.
  const strokeCache = new Map();

  // Timbre is cached per 0.1 of strike strength; the exact strength
  // is then applied as a gain in strike().
  function strokeClip(index, velocity, damp, rate) {
    const v = Math.max(0.1, Math.round(velocity * 10) / 10);
    const key = index + '|' + v + '|' + damp + '|' + rate;
    if (strokeCache.has(key)) {
      return strokeCache.get(key);
    }
    const spec = bellSpec(index);
    const modes = [];
    let longest = 0;
    spec.partials.forEach(function (p, k) {
      const level = p.amp * Math.pow(v, 1 + 0.35 * k);
      const t60 = spec.ring * p.decay * damp;
      longest = Math.max(longest, t60);
      if (k < 2) {
        modes.push({ freq: p.freq - p.split / 2, amp: level / 2,
          t60: t60 });
        modes.push({ freq: p.freq + p.split / 2, amp: level / 2,
          t60: t60 });
      } else {
        modes.push({ freq: p.freq, amp: level, t60: t60 });
      }
    });
    const clip = createTrack(longest, rate, false);
    addModes(clip, 0, modes, 0.002);
    // The metal click of iron on bronze: a few milliseconds of noise
    // around the upper partials, seeded by the bell, not the cue.
    const click = noiseBurst(rate, 0.012, rngFor('click:' + spec.name),
      spec.prime * 4, 1.2);
    mixInto(clip, click, 0, 0.18 * v);
    strokeCache.set(key, clip.data);
    return clip.data;
  }

  function strike(tr, t0, index, velocity, rng, damp) {
    const v = velocity === undefined ? 1 : velocity;
    const q = Math.max(0.1, Math.round(v * 10) / 10);
    mixInto(tr, strokeClip(index, v, damp || 1, tr.rate), t0, v / q);
  }

  // ── Noise and filtering ────────────────────────────────────────────
  function biquadBandpass(rate, freq, q) {
    const w = TAU * Math.min(freq, rate * 0.45) / rate;
    const alpha = Math.sin(w) / (2 * q);
    const a0 = 1 + alpha;
    return {
      b0: alpha / a0, b1: 0, b2: -alpha / a0,
      a1: -2 * Math.cos(w) / a0, a2: (1 - alpha) / a0,
    };
  }

  function biquadLowpass(rate, freq, q) {
    const w = TAU * Math.min(freq, rate * 0.45) / rate;
    const alpha = Math.sin(w) / (2 * q);
    const cw = Math.cos(w);
    const a0 = 1 + alpha;
    return {
      b0: (1 - cw) / 2 / a0, b1: (1 - cw) / a0, b2: (1 - cw) / 2 / a0,
      a1: -2 * cw / a0, a2: (1 - alpha) / a0,
    };
  }

  // Filters white noise through a time-varying biquad.  "shape(t)"
  // returns { freq, gain } for time t; coefficients are refreshed
  // every 64 samples, far below the rate at which the ear could hear
  // steps in a slowly moving band.
  function filteredNoise(rate, seconds, rng, kind, q, shape) {
    const n = Math.max(1, Math.round(seconds * rate));
    const out = new Float32Array(n);
    let x1 = 0;
    let x2 = 0;
    let y1 = 0;
    let y2 = 0;
    let co = null;
    let gain = 0;
    const make = kind === 'lowpass' ? biquadLowpass : biquadBandpass;
    for (let i = 0; i < n; i += 1) {
      if ((i & 63) === 0) {
        const st = shape(i / rate);
        co = make(rate, st.freq, q);
        gain = st.gain;
      }
      const x = rng() * 2 - 1;
      const y = co.b0 * x + co.b1 * x1 + co.b2 * x2 - co.a1 * y1 -
        co.a2 * y2;
      x2 = x1;
      x1 = x;
      y2 = y1;
      y1 = y;
      out[i] = y * gain;
    }
    return out;
  }

  function noiseBurst(rate, seconds, rng, freq, q) {
    return filteredNoise(rate, seconds, rng, 'bandpass', q, function (t) {
      return { freq: freq, gain: Math.pow(1 - t / seconds, 3) };
    });
  }

  // Adds a rendered clip at time t0.  Loop tracks wrap.
  function mixInto(tr, clip, t0, gain) {
    const start = Math.round(t0 * tr.rate);
    for (let i = 0; i < clip.length; i += 1) {
      let idx = start + i;
      if (idx >= tr.n) {
        if (!tr.loop) {
          break;
        }
        idx %= tr.n;
      }
      tr.data[idx] += clip[i] * gain;
    }
  }

  // A noise bed for a loop track.  Filtered noise is not periodic, so
  // it is rendered a little longer than the loop and the overhang is
  // cross-faded (equal power) into the head: sample n-1 then flows
  // straight into sample 0.
  function noiseBed(tr, rng, kind, q, shape, gain) {
    const fold = tr.loop ? Math.round(tr.rate * 0.5) : 0;
    const raw = filteredNoise(tr.rate, (tr.n + fold) / tr.rate, rng,
      kind, q, shape);
    for (let i = 0; i < tr.n; i += 1) {
      let v = raw[i];
      if (i < fold) {
        const x = i / fold;
        v = raw[i] * Math.sin(x * Math.PI / 2) +
          raw[tr.n + i] * Math.cos(x * Math.PI / 2);
      }
      tr.data[i] += v * gain;
    }
  }

  // ── Voice (ison) ───────────────────────────────────────────────────
  const TABLE = 4096;

  function formantGain(freq, vowel) {
    let g = 0.015;
    for (const f of VOWELS[vowel]) {
      const x = (freq - f[0]) / (f[1] / 2);
      g += f[2] / (1 + x * x);
    }
    return g;
  }

  // One period of a band-limited sawtooth whose harmonics are weighted
  // by vowel formants: a formant-filtered saw computed in the
  // frequency domain, so it cannot alias and costs nothing per sample.
  function voiceTable(f0, rate, vowel, rng) {
    const table = new Float32Array(TABLE + 1);
    const top = Math.min(rate * 0.42, 5200);
    for (let h = 1; h * f0 < top; h += 1) {
      const amp = formantGain(h * f0, vowel) / h;
      const phase = rng() * TAU;
      for (let i = 0; i < TABLE; i += 1) {
        table[i] += amp * Math.sin(TAU * h * i / TABLE + phase);
      }
    }
    let peak = 0;
    for (let i = 0; i < TABLE; i += 1) {
      peak = Math.max(peak, Math.abs(table[i]));
    }
    for (let i = 0; i < TABLE; i += 1) {
      table[i] /= peak || 1;
    }
    table[TABLE] = table[0];
    return table;
  }

  // Loop tracks need a whole number of cycles per loop or the seam
  // clicks, so pitches are snapped to multiples of 1/length.  At a
  // 30 s loop the snap is under half a cent at chant pitch.
  function loopFreq(tr, freq) {
    if (!tr.loop) {
      return freq;
    }
    return Math.max(1, Math.round(freq * tr.seconds)) / tr.seconds;
  }

  function addVoice(tr, t0, seconds, freq, amp, vowel, rng, envelope) {
    const f = loopFreq(tr, freq);
    const table = voiceTable(f, tr.rate, vowel, rng);
    const step = f * TABLE / tr.rate;
    const start = Math.round(t0 * tr.rate);
    const count = Math.min(tr.loop ? tr.n : Infinity,
      Math.round(seconds * tr.rate));
    let phase = rng() * TABLE;
    // Breath envelopes move over seconds, so evaluating them every 64
    // samples and interpolating is inaudible and several times faster.
    let e0 = envelope(0);
    let e1 = envelope(64 / tr.rate);
    for (let k = 0; k < count; k += 1) {
      if ((k & 63) === 0 && k > 0) {
        e0 = e1;
        e1 = envelope((k + 64) / tr.rate);
      }
      let idx = start + k;
      if (idx >= tr.n) {
        if (!tr.loop) {
          break;
        }
        idx %= tr.n;
      }
      const i = phase | 0;
      const frac = phase - i;
      const v = table[i] + (table[i + 1] - table[i]) * frac;
      const e = e0 + (e1 - e0) * (k & 63) / 64;
      tr.data[idx] += v * amp * e;
      phase += step;
      if (phase >= TABLE) {
        phase -= TABLE;
      }
    }
  }

  function smooth(x) {
    const c = Math.min(1, Math.max(0, x));
    return c * c * (3 - 2 * c);
  }

  // The choir sings on the exhalation.  During the inhalation the
  // drone thins to a floor (other singers carry it, "chain
  // breathing"), swells through the hold, and relaxes over the long
  // exhale.  The curve is periodic, so a loop of whole cycles is
  // seamless.
  function breathEnvelope(pattern, floor) {
    const cycle = breathCycle(pattern);
    const low = floor === undefined ? 0.35 : floor;
    // Without a hold after the exhale the exhale itself must end on
    // the floor, or the envelope would jump at the cycle boundary.
    const end = pattern.holdOut > 0 ? 0.55 : low;
    return function (t) {
      let p = t % cycle;
      if (p < pattern.inhale) {
        return low + (1 - low) * smooth(p / pattern.inhale);
      }
      p -= pattern.inhale;
      if (p < pattern.holdIn) {
        return 1;
      }
      p -= pattern.holdIn;
      if (p < pattern.exhale) {
        return 1 - (1 - end) * smooth(p / pattern.exhale);
      }
      p -= pattern.exhale;
      return end - (end - low) * smooth(p / pattern.holdOut);
    };
  }

  function swellEnvelope(seconds, attack, release) {
    return function (t) {
      if (t < attack) {
        return smooth(t / attack);
      }
      if (t > seconds - release) {
        return smooth((seconds - t) / release);
      }
      return 1;
    };
  }

  // Ison of several singers: unison voices a few cents apart plus an
  // октавист an octave below, the Russian choral bass.
  function ison(tr, rng, opts) {
    const env = opts.envelope;
    const cents = opts.cents || [-3, 0, 4];
    cents.forEach(function (c) {
      const f = opts.freq * Math.pow(2, c / 1200);
      addVoice(tr, opts.t0 || 0, opts.seconds, f, opts.amp,
        opts.vowel || 'o', rng, env);
    });
    if (opts.oktavist) {
      addVoice(tr, opts.t0 || 0, opts.seconds, opts.freq / 2,
        opts.amp * opts.oktavist, 'o', rng, env);
    }
  }

  // ── Semantron / било ───────────────────────────────────────────────
  // A semantron is a wooden beam, so its modes follow the free-free
  // Euler-Bernoulli beam ratios 1 : 2.756 : 5.404 : 8.933 (textbook
  // beam theory).  Wood damps fast, hence the short ring.
  const BEAM = [[1, 1.0, 0.22], [2.756, 0.5, 0.12], [5.404, 0.22, 0.07],
    [8.933, 0.1, 0.045]];

  function knock(tr, t0, freq, level, rng, muted) {
    const modes = BEAM.filter(function (m, k) {
      return !muted || k < 2;
    }).map(function (m) {
      return { freq: freq * m[0], amp: level * m[1],
        t60: m[2] * (muted ? 0.45 : 1) };
    });
    addModes(tr, t0, modes, 0.0008);
    const click = noiseBurst(tr.rate, muted ? 0.01 : 0.018, rng,
      muted ? 700 : 1600, 0.9);
    mixInto(tr, click, t0, level * (muted ? 0.35 : 0.6));
  }

  // ── Ringing orders (kolokol, chapter 25; RESEARCH_NOTES "Устав") ────
  // Благовест: measured single strokes on the largest bell.  The book
  // gives no tempo in seconds; five seconds is a design choice for a
  // "мерный, редкий" pulse that lets each stroke's hum be heard out.
  function blagovest(tr, rng, t0, count, interval, bell) {
    for (let i = 0; i < count; i += 1) {
      const v = 0.9 + rng() * 0.08;
      strike(tr, t0 + i * interval, bell || 0, v, rng);
    }
  }

  // Удар во вся: all bells at once, the sign that a ringing is over
  // (kolokol, chapter 22, "затравка ... удар во вся").
  function allBells(tr, rng, t0, velocity) {
    for (let b = 0; b < ENSEMBLE.length; b += 1) {
      strike(tr, t0 + b * 0.004, b, velocity * (b === 0 ? 0.8 : 0.7),
        rng);
    }
  }

  // Трезвон: three приёма, each a затравка on the small bells, a body
  // in three layers (благовестник on the downbeat, подзвонные as an
  // even middle pulse, зазвонные as the quick upper figure), and the
  // удар во вся (chapter 22).  The figure is fixed; only the strike
  // strength varies, seeded, as a ringer's hand does.
  const ZAZVON_FIGURE = [7, 6, 5, 6, 7, 6, 4, 6];

  function trezvon(tr, rng, t0, priemy, bars, beat) {
    let t = t0;
    for (let p = 0; p < priemy; p += 1) {
      [7, 6, 7, 5].forEach(function (b, i) {
        strike(tr, t + i * beat, b, 0.75 + rng() * 0.1, rng);
      });
      t += 4 * beat;
      for (let bar = 0; bar < bars; bar += 1) {
        for (let s = 0; s < 8; s += 1) {
          const at = t + s * beat;
          if (s === 0) {
            strike(tr, at, 0, 0.85, rng);
          }
          if (s % 2 === 0) {
            strike(tr, at, s % 4 === 0 ? 1 : 2, 0.7 + rng() * 0.1, rng);
          }
          if (s === 4) {
            strike(tr, at, 3, 0.65, rng);
          }
          strike(tr, at, ZAZVON_FIGURE[s], 0.6 + rng() * 0.15, rng);
        }
        t += 8 * beat;
      }
      allBells(tr, rng, t, 0.95);
      t += 8 * beat;
    }
    return t;
  }

  // Перебор (funeral): single rare strokes from the smallest bell to
  // the largest, then all together (RESEARCH_NOTES "Устав звона";
  // chapter 25).  Pitch therefore descends.
  function perebor(tr, rng, t0, interval) {
    let t = t0;
    for (let b = ENSEMBLE.length - 1; b >= 0; b -= 1) {
      strike(tr, t, b, 0.7, rng, 0.8);
      t += interval;
    }
    allBells(tr, rng, t, 0.6);
    return t;
  }

  // Перезвон: strokes from the largest bell to the smallest, without a
  // final удар во вся (RESEARCH_NOTES "Устав звона").
  function perezvon(tr, rng, t0, interval, each) {
    let t = t0;
    for (let b = 0; b < ENSEMBLE.length; b += 1) {
      for (let k = 0; k < each; k += 1) {
        strike(tr, t, b, 0.75, rng);
        t += interval;
      }
    }
    return t;
  }

  // Звон в двои: the Lenten ringing in two bells, the постовой and the
  // next one in size (chapter 25).  Restraint is the meaning.
  function zvonVDvoi(tr, rng, t0, count, interval) {
    for (let i = 0; i < count; i += 1) {
      strike(tr, t0 + i * interval, 1 + (i % 2), 0.7, rng);
    }
  }

  // ── Passions ───────────────────────────────────────────────────────
  // The eight logismoi of Evagrius.  Each passion is a cluster built
  // from a tritone and a minor second over a root, with a buzzy
  // odd-harmonic timbre (no vowel formants, no bell partials: nothing
  // sacred), slow beating, and a pitch that sags and never lands.
  // The cue ends by fading while still dissonant: a passion is not
  // resolved by music, only stilled by hesychia.
  const PASSIONS = {
    passion: { root: 92.5, cluster: [0, 1, 6] },
    passion_gluttony: { root: 87.31, cluster: [0, 6, 7] },
    passion_lust: { root: 110.0, cluster: [0, 1, 6] },
    passion_avarice: { root: 77.78, cluster: [0, 6, 11] },
    passion_sorrow: { root: 98.0, cluster: [0, 1, 6] },
    passion_anger: { root: 123.47, cluster: [0, 1, 6, 7] },
    passion_acedia: { root: 69.3, cluster: [0, 6] },
    passion_vainglory: { root: 138.59, cluster: [0, 6, 11, 13] },
    passion_pride: { root: 146.83, cluster: [0, 1, 6, 12] },
  };

  function passionCluster(tr, rng, def) {
    const seconds = tr.seconds;
    const sag = 0.97 + rng() * 0.01;
    def.cluster.forEach(function (semi, v) {
      const base = def.root * Math.pow(2, semi / 12);
      const beat = 0.7 + rng() * 2.2;
      let phase = rng();
      const rate = tr.rate;
      for (let i = 0; i < tr.n; i += 1) {
        const t = i / rate;
        const f = base * (1 + (sag - 1) * smooth(t / seconds));
        phase += f / rate;
        phase -= Math.floor(phase);
        // Odd harmonics 1, 3, 5, 7 with 1/h weights: square-like buzz.
        const x = TAU * phase;
        const tone = Math.sin(x) + Math.sin(3 * x) / 3 +
          Math.sin(5 * x) / 5 + Math.sin(7 * x) / 7;
        const trem = 0.65 + 0.35 * Math.sin(TAU * beat * t + v);
        const env = smooth(t / 0.4) * smooth((seconds - t) / 1.2);
        tr.data[i] += tone * trem * env * (0.5 / (v + 1));
      }
    });
  }

  // ── Environment ────────────────────────────────────────────────────
  // Wind: a band of noise that rises and falls, meaning the world is
  // changing around the player.  The sweep is a fixed curve.
  function wind(tr, rng, centre, gain) {
    const s = tr.seconds;
    const p1 = rng() * TAU;
    noiseBed(tr, rng, 'bandpass', 1.1, function (t) {
      const x = t / s;
      const sweep = 0.55 + 0.9 * Math.sin(Math.PI * x) +
        0.15 * Math.sin(TAU * 3 * x + p1);
      const g = tr.loop ? 0.8 + 0.2 * Math.sin(TAU * x + p1) :
        Math.sin(Math.PI * x);
      return { freq: centre * sweep, gain: g };
    }, gain);
  }

  // Room tone: the audible stillness of a stone church.  Real silence
  // is never digital zero; this bed sits around -60 dBFS.
  function roomTone(tr, rng) {
    noiseBed(tr, rng, 'lowpass', 0.7, function () {
      return { freq: 380, gain: 1 };
    }, 1);
  }

  function water(tr, rng) {
    const s = tr.seconds;
    const p = [rng() * TAU, rng() * TAU, rng() * TAU];
    const k = tr.loop ? 1 : 0;
    noiseBed(tr, rng, 'lowpass', 0.8, function (t) {
      return { freq: 520, gain: k ? 1 : Math.min(1, t * 4) };
    }, 0.8);
    // Gurgles: a resonant band whose centre wanders on a sum of three
    // fixed sines (whole cycles per loop, so loops stay seamless).
    noiseBed(tr, rng, 'bandpass', 6, function (t) {
      const x = TAU * t / s;
      const f = 650 + 260 * Math.sin(7 * x + p[0]) +
        140 * Math.sin(13 * x + p[1]) + 90 * Math.sin(29 * x + p[2]);
      const g = k ? 1 : Math.min(1, t * 2, (s - t) * 2);
      return { freq: f, gain: g };
    }, 1.4);
  }

  // Sonar: the ROV sends a ping and the lake answers.  The echoes are
  // the bottom and the far shore; depth is known by listening.
  function sonar(tr, rng) {
    const echoes = [[0, 1], [0.36, 0.35], [0.74, 0.14], [1.13, 0.06]];
    echoes.forEach(function (e, k) {
      const f = 1480 * (1 - 0.004 * k);
      addPartial(tr, 0.02 + e[0], f, 0.6 * e[1], 0.9, 0.004);
      addPartial(tr, 0.02 + e[0], f * 2.01, 0.12 * e[1], 0.3, 0.004);
    });
    water(tr, rng);
  }

  function steps(tr, rng, interval, freq) {
    for (let t = 0.05; t < tr.seconds - 0.2; t += interval) {
      const burst = filteredNoise(tr.rate, 0.14, rng, 'lowpass', 0.8,
        function (x) {
          return { freq: freq, gain: Math.pow(1 - x / 0.14, 2) };
        });
      mixInto(tr, burst, t, 0.8 + rng() * 0.3);
    }
  }

  // A plucked gut or wire string (gusli) by the Karplus-Strong method:
  // a delay line one period long is filled with noise and averaged on
  // every pass, which is how a real string loses its high harmonics
  // first.  The noise comes from the seeded rng, so the pluck is the
  // same on every run.  This is folk, human work, not a sacred sound,
  // which is why it may answer an ordinary game event.
  function pluck(tr, t0, freq, level, rng, t60) {
    const period = Math.max(2, Math.round(tr.rate / freq));
    const line = new Float32Array(period);
    for (let i = 0; i < period; i += 1) {
      line[i] = rng() * 2 - 1;
    }
    // The loss per period that makes the tone fall by 60 dB in t60
    // seconds; the averaging filter adds its own, frequency-dependent
    // loss on top of it.
    const loss = Math.pow(10, -3 / (t60 * freq));
    const n = Math.round(t60 * tr.rate);
    const clip = new Float32Array(n);
    let idx = 0;
    let prev = 0;
    for (let i = 0; i < n; i += 1) {
      const cur = line[idx];
      clip[i] = cur;
      line[idx] = loss * 0.5 * (cur + prev);
      prev = cur;
      idx = (idx + 1) % period;
    }
    mixInto(tr, clip, t0, level);
  }

  function breathing(tr, rng, pattern) {
    const cycle = breathCycle(pattern);
    const env = breathEnvelope(pattern, 0);
    noiseBed(tr, rng, 'bandpass', 1.4, function (t) {
      const p = t % cycle;
      const inhaling = p < pattern.inhale;
      return {
        freq: inhaling ? 1400 : 780,
        gain: env(t) * smooth(Math.min(t, tr.seconds - t) / 0.3),
      };
    }, 1);
  }

  // ── Recipes ────────────────────────────────────────────────────────
  // Each recipe: seconds, loop, peak (normalisation target), meaning,
  // build(track, rng).  The peak targets fix the relative loudness so
  // that bells sit above voices and the room tone stays near silence.
  function isonBed(freq, pattern, vowel, oktavist) {
    const cycle = breathCycle(BREATH[pattern]);
    const loops = Math.max(1, Math.round(30 / cycle));
    return {
      seconds: cycle * loops, loop: true, peak: 0.5,
      build: function (tr, rng) {
        ison(tr, rng, {
          freq: freq, seconds: tr.seconds, amp: 0.3, vowel: vowel,
          oktavist: oktavist, envelope: breathEnvelope(BREATH[pattern]),
        });
      },
    };
  }

  function shortVoice(freqs, seconds, vowel, oktavist) {
    return {
      seconds: seconds, loop: false, peak: 0.45,
      build: function (tr, rng) {
        const part = seconds / freqs.length;
        freqs.forEach(function (f, i) {
          const chord = Array.isArray(f) ? f : [f];
          chord.forEach(function (fc) {
            ison(tr, rng, {
              freq: fc, t0: i * part, seconds: part + 0.25, amp: 0.3,
              vowel: vowel, oktavist: oktavist,
              envelope: swellEnvelope(part + 0.25, Math.min(0.25,
                part / 3), Math.min(0.4, part / 2)),
            });
          });
        });
      },
    };
  }

  const RECIPES = {
    // Ringing orders.
    blagovest: {
      meaning: 'Благовест: measured strokes call to prayer.',
      seconds: 12, loop: false, peak: 0.85,
      build: function (tr, rng) {
        blagovest(tr, rng, 0.02, 3, 4.0, 0);
      },
    },
    blagovest_stroke: {
      meaning: 'One благовест stroke: the prayer has been delivered.',
      seconds: 6, loop: false, peak: 0.8,
      build: function (tr, rng) {
        strike(tr, 0.02, 0, 0.9, rng);
      },
    },
    small_bell_stroke: {
      meaning: 'One light stroke of a small bell: the prayer is heard.',
      seconds: 3.5, loop: false, peak: 0.6,
      build: function (tr, rng) {
        strike(tr, 0.02, 5, 0.6, rng);
      },
    },
    trezvon: {
      meaning: 'Трезвон in three приёма: the joy of the feast.',
      seconds: 18, loop: false, peak: 0.85,
      build: function (tr, rng) {
        trezvon(tr, rng, 0.02, 3, 2, 0.17);
      },
    },
    trezvon_motif: {
      meaning: 'Short трезвон motif: a teaching has been received.',
      seconds: 3.2, loop: false, peak: 0.75,
      build: function (tr, rng) {
        [7, 6, 7, 5, 6, 4].forEach(function (b, i) {
          strike(tr, 0.02 + i * 0.13, b, 0.7 + rng() * 0.1, rng, 0.6);
        });
        allBells(tr, rng, 0.02 + 6 * 0.13, 0.75);
      },
    },
    perezvon: {
      meaning: 'Перезвон, large to small: solemn procession.',
      seconds: 14, loop: false, peak: 0.8,
      build: function (tr, rng) {
        perezvon(tr, rng, 0.02, 1.2, 1);
      },
    },
    perebor: {
      meaning: 'Перебор, small to large then all: mourning.',
      seconds: 22, loop: false, peak: 0.75,
      build: function (tr, rng) {
        perebor(tr, rng, 0.02, 2.2);
      },
    },
    zvon_v_dvoi: {
      meaning: 'Звон в двои: Lenten restraint in two bells.',
      seconds: 12, loop: false, peak: 0.75,
      build: function (tr, rng) {
        zvonVDvoi(tr, rng, 0.02, 4, 2.5);
      },
    },

    // Voice.
    ison: Object.assign(isonBed(146.83, 'athonite', 'o', 0.5), {
      meaning: 'Ison on D3 breathing the Athonite Jesus Prayer cycle.',
    }),

    // Wood.
    semantron: {
      meaning: 'Semantron: the voice of the prophets before the Gospel.',
      seconds: 6, loop: false, peak: 0.7,
      build: function (tr, rng) {
        // Three rounds, as the Athonite monk walks three times around
        // the church (kolokol, chapter 6).
        for (let r = 0; r < 3; r += 1) {
          for (let k = 0; k < 4; k += 1) {
            knock(tr, 0.02 + r * 1.9 + k * 0.32 * (1 - k * 0.08),
              380, 0.8, rng, false);
          }
        }
      },
    },
    choice: {
      meaning: 'One light tap on a wooden desk: a word was chosen.',
      seconds: 0.45, loop: false, peak: 0.45,
      build: function (tr, rng) {
        knock(tr, 0.005, 520, 0.8, rng, false);
      },
    },
    gate_locked: {
      meaning: 'Muted double knock on a wooden door: FORM is not ready yet.',
      seconds: 0.7, loop: false, peak: 0.5,
      build: function (tr, rng) {
        knock(tr, 0.005, 210, 0.9, rng, true);
        knock(tr, 0.24, 196, 0.7, rng, true);
      },
    },

    // Environment.
    world_change: {
      meaning: 'Wind: the world is changing around the player.',
      seconds: 3.0, loop: false, peak: 0.45,
      build: function (tr, rng) {
        wind(tr, rng, 650, 1);
      },
    },
    water: {
      meaning: 'Lake water: the depth that the ROV observes.',
      seconds: 6, loop: false, peak: 0.35,
      build: function (tr, rng) {
        water(tr, rng);
      },
    },
    sonar_ping: {
      meaning: 'Sonar ping and echo: depth is known by listening.',
      seconds: 2.4, loop: false, peak: 0.5,
      build: function (tr, rng) {
        sonar(tr, rng);
      },
    },
    footsteps: {
      meaning: 'Steady steps: the pilgrim is on the way.',
      seconds: 3, loop: false, peak: 0.35,
      build: function (tr, rng) {
        steps(tr, rng, 0.55, 420);
      },
    },
    sand_steps: {
      meaning: 'Steps in desert sand: the way of the desert fathers.',
      seconds: 3, loop: false, peak: 0.3,
      build: function (tr, rng) {
        steps(tr, rng, 0.6, 1200);
      },
    },
    robe_rustle: {
      meaning: 'A monastic robe moving: the body turns to prayer.',
      seconds: 1.6, loop: false, peak: 0.25,
      build: function (tr, rng) {
        noiseBed(tr, rng, 'bandpass', 0.9, function (t) {
          return { freq: 3200, gain: Math.sin(Math.PI * t / 1.6) };
        }, 1);
      },
    },
    kneeling: {
      meaning: 'Kneeling on stone: Constitution, rootedness.',
      seconds: 1.4, loop: false, peak: 0.55,
      build: function (tr, rng) {
        addPartial(tr, 0.01, 72, 0.9, 0.35, 0.003);
        knock(tr, 0.05, 150, 0.5, rng, true);
      },
    },
    breathing: {
      meaning: 'Breath at the basic 4:6 Jesus Prayer rhythm.',
      seconds: breathCycle(BREATH.basic), loop: false, peak: 0.2,
      build: function (tr, rng) {
        breathing(tr, rng, BREATH.basic);
      },
    },
    prayer_voice: {
      meaning: 'Wordless ison: prayer accompanies, it never powers up.',
      seconds: 4, loop: false, peak: 0.45,
      build: function (tr, rng) {
        ison(tr, rng, {
          freq: 146.83, seconds: 4, amp: 0.3, oktavist: 0.5,
          envelope: swellEnvelope(4, 0.8, 1.2),
        });
      },
    },

    // Attributes: wordless voices, never bells (bells keep their
    // liturgical meaning).  High notes for ascent, low for roots.
    wisdom: Object.assign(shortVoice([293.66, 329.63], 1.4, 'a'), {
      meaning: 'Voice rising a step: Wisdom, ascent of the nous.',
    }),
    faith: Object.assign(shortVoice([[146.83, 220.0]], 1.6, 'o', 0.4), {
      meaning: 'Open fifth in voices: Faith, a firm foundation.',
    }),
    erudition: {
      meaning: 'Parchment and a clear upper voice: Erudition.',
      seconds: 1.1, loop: false, peak: 0.4,
      build: function (tr, rng) {
        mixInto(tr, noiseBurst(tr.rate, 0.12, rng, 2400, 0.8), 0, 0.6);
        ison(tr, rng, {
          freq: 329.63, t0: 0.1, seconds: 1.0, amp: 0.3, vowel: 'a',
          envelope: swellEnvelope(1.0, 0.2, 0.45),
        });
      },
    },
    charisma: Object.assign(shortVoice([[130.81, 261.63]], 1.5, 'o'), {
      meaning: 'Many voices in unison and octave: Charisma, community.',
    }),
    dexterity: {
      meaning: 'Two quick taps of a carpenter\'s mallet: Dexterity, practice.',
      seconds: 0.55, loop: false, peak: 0.45,
      build: function (tr, rng) {
        knock(tr, 0.005, 600, 0.8, rng, false);
        knock(tr, 0.14, 600, 0.7, rng, false);
      },
    },
    cunning: {
      meaning: 'A muted low knock: Cunning, a hidden path.',
      seconds: 0.6, loop: false, peak: 0.35,
      build: function (tr, rng) {
        knock(tr, 0.005, 160, 0.8, rng, true);
      },
    },
    constitution: Object.assign(shortVoice([98.0], 1.8, 'o', 0.6), {
      meaning: 'Low steady ison with октавист: Constitution.',
    }),
    // Generic FORM growth after a dialogue choice.  It used to borrow
    // the Wisdom voice, which made a chant-like voice answer every
    // bonus like a reward ding (SOUND_THEOLOGY_RULES, TABOO 0.2 item
    // 5, rule 16).  Two soft plucks of a gusli string, a whole step
    // apart and rising, say "something grew" with the warm, hand-made
    // timbre of the hearth, and stay clear of bell, board and voice.
    form_growth: {
      meaning: 'Two gusli plucks rising a step: FORM has grown.',
      seconds: 1.3, loop: false, peak: 0.35,
      build: function (tr, rng) {
        pluck(tr, 0.005, 196.0, 0.8, rng, 1.1);
        pluck(tr, 0.16, 220.0, 0.9, rng, 1.1);
      },
    },

    // Silence.
    hesychia: {
      meaning: 'Hesychia: stillness (room tone near -60 dBFS).',
      seconds: 4, loop: false, peak: 0.001,
      build: function (tr, rng) {
        roomTone(tr, rng);
      },
    },

    // Stillness as a mixer state (TABOO 0.35 rule 8, TABOO 0.4 rule 2):
    // never digital zero, but room tone with a slow breath under it,
    // the basic 4-6 s Jesus Prayer cycle of the hesychasm module.  The
    // loop is three whole cycles, so it repeats without a seam.  The
    // peak of 0.02 (-34 dBFS) puts the average near -48 dBFS, inside
    // the -40...-50 band of TABOO 0.4 rule 2.
    room_tone: {
      meaning: 'Stillness: room tone and breath, about -48 dBFS.',
      seconds: 3 * breathCycle(BREATH.basic), loop: true, peak: 0.02,
      build: function (tr, rng) {
        roomTone(tr, rng);
        const env = breathEnvelope(BREATH.basic, 0.15);
        noiseBed(tr, rng, 'bandpass', 0.9, function (t) {
          return { freq: 900, gain: env(t) };
        }, 0.6);
      },
    },

    // Looping beds (music layer).
    desert_silence: {
      meaning: 'Desert stillness: faint wind over room tone.',
      seconds: 30, loop: true, peak: 0.06,
      build: function (tr, rng) {
        wind(tr, rng, 420, 1);
      },
    },
    monastery_bells: {
      meaning: 'Distant благовест: the monastery calls to prayer.',
      seconds: 30, loop: true, peak: 0.55,
      build: function (tr, rng) {
        blagovest(tr, rng, 0, 6, 5.0, 0);
      },
    },
    hesychasm_flow: Object.assign(isonBed(146.83, 'athonite', 'o', 0.5),
      { meaning: 'Ison breathing the Athonite 5-1-8-1 s cycle.' }),
    theoria_ascending: {
      meaning: 'Ison on D3 with a fifth that enters: illumination.',
      seconds: 30, loop: true, peak: 0.5,
      build: function (tr, rng) {
        const env = breathEnvelope(BREATH.athonite);
        ison(tr, rng, { freq: 146.83, seconds: 30, amp: 0.3,
          oktavist: 0.4, envelope: env });
        // The upper voice sings only through the exhale of each cycle:
        // light that is given, not seized.
        ison(tr, rng, { freq: 220.0, seconds: 30, amp: 0.2, vowel: 'a',
          envelope: function (t) {
            const p = t % 15;
            return p < 6 ? 0 : Math.sin(Math.PI * (p - 6) / 9);
          } });
      },
    },
    apophatic_void: {
      meaning: 'Apophatic gate: near silence and one far hum.',
      seconds: 30, loop: true, peak: 0.02,
      build: function (tr, rng) {
        roomTone(tr, rng);
        // Only the hum of the great bell, the partial that outlives
        // all others: what remains when every word has fallen away.
        addPartial(tr, 3, bellSpec(0).partials[0].freq, 0.02, 20, 2.5);
      },
    },
    elder_sergius_theme: Object.assign(isonBed(110.0, 'sinaite', 'o',
      0.6), { meaning: 'Elder Sergius: low ison, Sinaite breath.' }),
    theodora_theme: Object.assign(isonBed(146.83, 'optina', 'a', 0.3),
      { meaning: 'Theodora: open-vowel ison, Optina breath.' }),
    isaias_theme: Object.assign(isonBed(164.81, 'ignatius', 'o', 0.4),
      { meaning: 'Isaias: ison on E3, St Ignatius breath.' }),
    abbot_moses_theme: Object.assign(isonBed(130.81, 'basic', 'o', 0.6),
      { meaning: 'Abba Moses: dark ison of repentance, 4:6 breath.' }),
    sister_catherine_theme: Object.assign(isonBed(220.0, 'athonite',
      'fa', 0), { meaning: 'Sister Catherine: sisters\' ison on A3.' }),
    foundational_gate: {
      meaning: 'Foundational gate: благовест, the good news begins.',
      seconds: 30, loop: true, peak: 0.6,
      build: function (tr, rng) {
        blagovest(tr, rng, 0, 5, 6.0, 0);
      },
    },
    liturgical_gate: {
      meaning: 'Liturgical gate: трезвон before the Liturgy.',
      seconds: 30, loop: true, peak: 0.7,
      build: function (tr, rng) {
        trezvon(tr, rng, 0, 3, 2, 0.19);
      },
    },
    ascetic_gate: {
      meaning: 'Ascetic gate: Lenten звон в двои.',
      seconds: 30, loop: true, peak: 0.55,
      build: function (tr, rng) {
        zvonVDvoi(tr, rng, 0, 10, 3.0);
      },
    },
    encounter_theme: {
      meaning: 'First encounter: semantron, then the bell (ch. 6).',
      seconds: 30, loop: true, peak: 0.6,
      build: function (tr, rng) {
        for (let r = 0; r < 3; r += 1) {
          for (let k = 0; k < 4; k += 1) {
            knock(tr, r * 2.4 + k * 0.34, 380, 0.7, rng, false);
          }
        }
        blagovest(tr, rng, 8.5, 4, 5.0, 0);
      },
    },
    victory_theme: {
      meaning: 'Illumination: full трезвон, the joy of the feast.',
      seconds: 30, loop: true, peak: 0.75,
      build: function (tr, rng) {
        trezvon(tr, rng, 0, 3, 2, 0.19);
      },
    },
  };

  Object.keys(PASSIONS).forEach(function (key) {
    RECIPES[key] = {
      meaning: 'Passion (' + key.replace('passion_', '') +
        '): unresolved dissonance; stilled only by hesychia.',
      seconds: 3.2, loop: false, peak: 0.4,
      build: function (tr, rng) {
        passionCluster(tr, rng, PASSIONS[key]);
      },
    };
  });

  // Catalogue keys of ludus-audio-manager.js that share a recipe.
  // Every MUSIC_CATALOG, SFX_CATALOG and SEMANTIC_CUES key resolves.
  const ALIASES = {
    desert_wind: 'world_change',
    transformation_effect: 'world_change',
    sand_footsteps: 'sand_steps',
    character_footsteps: 'footsteps',
    monastery_bell_toll: 'blagovest_stroke',
    prayer_delivered: 'blagovest_stroke',
    meditation_bell: 'small_bell_stroke',
    water_flow: 'water',
    character_breathing: 'breathing',
    kneeling_sound: 'kneeling',
    prayer_vocalization: 'prayer_voice',
    // A teaching ends in stillness, not in a festal peal: a bell tied to
    // a UI event is what CLAUDE.md TABOO 0.35 rule 9 forbids, and the
    // трезвон belongs to feasts by the typikon, not to a closed dialog.
    blessing_sound: 'hesychia',
    teaching_complete: 'hesychia',
    ui_positive: 'form_growth',
    ui_negative: 'gate_locked',
    ui_neutral: 'choice',
    ui_confirm: 'choice',
    silence: 'hesychia',
  };

  function resolve(name) {
    const key = ALIASES[name] || name;
    return RECIPES[key] ? key : null;
  }

  // ── Rendering ──────────────────────────────────────────────────────
  function normalise(tr, peak) {
    let max = 0;
    let bad = false;
    for (let i = 0; i < tr.n; i += 1) {
      const v = tr.data[i];
      if (v !== v) {
        bad = true;
        tr.data[i] = 0;
      } else if (Math.abs(v) > max) {
        max = Math.abs(v);
      }
    }
    if (bad) {
      console.warn('[Ludus Synth] NaN samples were zeroed');
    }
    const g = max > 0 ? peak / max : 0;
    for (let i = 0; i < tr.n; i += 1) {
      tr.data[i] *= g;
    }
  }

  // One-shots are cut at their nominal length; a short fade keeps the
  // cut from clicking while the bell's hum is still sounding.
  function fadeTail(tr) {
    const f = Math.min(Math.round(tr.n * 0.2),
      Math.round(tr.rate * 0.35));
    for (let i = 0; i < f; i += 1) {
      tr.data[tr.n - 1 - i] *= smooth(i / f);
    }
  }

  const sampleCache = new Map();

  /**
   * Renders a cue to raw samples.  Deterministic: the seed is the hash
   * of the recipe name, so aliases of one recipe sound identical.
   * Returns { name, recipe, rate, seconds, loop, meaning, data } or
   * null for an unknown cue.
   */
  function renderSamples(name, sampleRate) {
    const key = resolve(name);
    if (!key) {
      return null;
    }
    const recipe = RECIPES[key];
    const want = Number(sampleRate) || 48000;
    const rate = recipe.seconds > LONG_SECONDS ?
      Math.min(want, LONG_RATE) : want;
    const cacheKey = key + '@' + rate;
    if (sampleCache.has(cacheKey)) {
      return sampleCache.get(cacheKey);
    }
    const tr = createTrack(recipe.seconds, rate, recipe.loop);
    recipe.build(tr, rngFor(key));
    // Stroke clips are large (seconds of float samples); keep them
    // only for the duration of one render.
    strokeCache.clear();
    if (!recipe.loop) {
      fadeTail(tr);
    }
    normalise(tr, recipe.peak);
    const result = {
      name: name, recipe: key, rate: rate, seconds: tr.seconds,
      loop: recipe.loop, meaning: recipe.meaning || '', data: tr.data,
    };
    sampleCache.set(cacheKey, result);
    return result;
  }

  /**
   * Renders a cue into an AudioBuffer of the given context.  The
   * buffer may carry a lower sample rate than the context (long
   * beds); Web Audio resamples it on playback.
   */
  function render(name, ctx) {
    const out = renderSamples(name, ctx && ctx.sampleRate);
    if (!out || !ctx) {
      return null;
    }
    const buffer = ctx.createBuffer(1, out.data.length, out.rate);
    buffer.copyToChannel(out.data, 0);
    return buffer;
  }

  const api = {
    render: render,
    renderSamples: renderSamples,
    has: function (name) {
      return resolve(name) !== null;
    },
    resolve: resolve,
    list: function () {
      return Object.keys(RECIPES).concat(Object.keys(ALIASES));
    },
    describe: function (name) {
      const key = resolve(name);
      return key ? RECIPES[key].meaning || '' : null;
    },
    bellSpec: bellSpec,
    hashString: hashString,
    ENSEMBLE: ENSEMBLE,
    BELL_PARTIALS: BELL_PARTIALS,
    BREATH: BREATH,
  };

  root.LudusSacredSynth = api;
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = api;
  }
})(typeof window !== 'undefined' ? window : globalThis);
