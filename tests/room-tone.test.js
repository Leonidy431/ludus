'use strict';

// Stillness is a mixer state, never digital zero (CLAUDE.md TABOO 0.35
// rule 8, TABOO 0.4 rule 2): room tone and breath around -40...-50
// dBFS, looping without a seam, with no silent 100 ms window.

const test = require('node:test');
const assert = require('node:assert/strict');
const synth = require('../public/ludus/ludus-sacred-synth.js');

const db = (x) => 20 * Math.log10(x);

test('room tone sits in the -40...-50 dBFS band and never drops out',
  () => {
    const out = synth.renderSamples('room_tone', 48000);
    assert.ok(out && out.loop, 'room_tone is a loop');
    const d = out.data;
    let sum = 0;
    for (let i = 0; i < d.length; i++) {
      sum += d[i] * d[i];
    }
    const rms = db(Math.sqrt(sum / d.length));
    assert.ok(rms <= -40 && rms >= -50, `rms ${rms.toFixed(1)} dBFS`);
    const win = out.rate / 10;
    for (let i = 0; i + win <= d.length; i += win) {
      let peak = 0;
      for (let j = i; j < i + win; j++) {
        peak = Math.max(peak, Math.abs(d[j]));
      }
      assert.ok(peak > 0, `digital zero at ${i / out.rate} s`);
    }
    // The loop is three whole breath cycles of the basic pattern.
    const b = synth.BREATH.basic;
    assert.equal(out.seconds,
      3 * (b.inhale + b.holdIn + b.exhale + b.holdOut));
  });
