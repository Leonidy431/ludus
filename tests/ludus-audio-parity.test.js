'use strict';

// The headset's sound (godot/scripts/audio) is a port of the JS sacred
// modules.  The GDScript test (godot/tests/test_audio.gd) checks the
// port against the tables written in it; this test checks the same
// tables, and the constants of the port, against the JS modules.  One
// source of truth: a change in JS that is not ported fails here.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const clock = require('../public/ludus/ludus-liturgical-clock.js');
const G = require('../public/ludus/ludus-glas.js');
const synth = require('../public/ludus/ludus-sacred-synth.js');

const godot = path.join(__dirname, '..', 'godot');
const read = (p) => fs.readFileSync(path.join(godot, p), 'utf8');
const testSrc = read('tests/test_audio.gd');
const synthSrc = read('scripts/audio/dive_synth.gd');
const typikonSrc = read('scripts/audio/typikon.gd');

// The body of a GDScript constant, from "const NAME := " to the line
// that closes it (a line starting with "]" or "}").
function constBody(src, name) {
  const start = src.indexOf(`const ${name} :=`);
  assert.ok(start >= 0, `const ${name} in the port`);
  const rest = src.slice(start);
  const end = rest.search(/\n[\]}]/);
  return rest.slice(rest.indexOf('=') + 1, end + 2);
}

// Local-time parsing as in tests/ludus-glas.test.js ("YYYY-MM-DDTHH:MM"
// without a zone is local time in node, as it is in the GDScript port).
const at = (s) => new Date(s);

test('the glas fixture of the port agrees with ludus-glas.js', () => {
  const rows = [...constBody(testSrc, 'GLAS_FIXTURE').matchAll(
    /\["([^"]+)", (\d), "([^"]+)", "([^"]+)"\]/g)];
  assert.ok(rows.length >= 24, `${rows.length} fixture rows`);
  for (const [, date, glas, period, rank] of rows) {
    const now = at(date);
    assert.equal(G.glasOf(now, clock) || 0, Number(glas), `glas ${date}`);
    const info = clock.describe(now);
    assert.equal(info.period, period, `period ${date}`);
    assert.equal(info.rank, rank, `rank ${date}`);
  }
});

test('the dates of ludus-glas.test.js are in the port fixture', () => {
  const body = constBody(testSrc, 'GLAS_FIXTURE');
  for (const d of ['2026-04-19T10:00', '2026-04-26T10:00',
    '2024-06-30T10:00', '2026-04-25T17:00', '2026-04-25T19:00',
    '2026-04-10T10:00', '2026-03-01T10:00', '2026-09-29T12:00']) {
    assert.ok(body.includes(`"${d}"`), d);
  }
});

test('the bell of the port is the JS благовестник', () => {
  const nums = [...constBody(testSrc, 'BELL_FIXTURE').matchAll(
    /\[([\d.]+), ([\d.]+)\]/g)].map((m) => [Number(m[1]), Number(m[2])]);
  const spec = synth.bellSpec(0);
  assert.equal(spec.name, 'blagovestnik');
  assert.equal(spec.ring, 9);
  assert.equal(nums.length, 5);
  spec.partials.forEach((p, k) => {
    assert.ok(Math.abs(p.freq - nums[k][0]) < 1e-9, `freq ${p.name}`);
    assert.ok(Math.abs(p.split - nums[k][1]) < 1e-9, `split ${p.name}`);
  });
  // Ratios, amplitudes, decay and drift of the five partials.
  const body = constBody(synthSrc, 'BELL_PARTIALS');
  synth.BELL_PARTIALS.forEach((p) => {
    const re = new RegExp(`"name": "${p.name}", "ratio": ([\\d.]+), ` +
      '"amp": ([\\d.]+), "decay": ([\\d.]+),\\s*"drift": ([\\d.]+)');
    const m = body.match(re);
    assert.ok(m, `partial ${p.name} in the port`);
    assert.deepEqual(m.slice(1).map(Number),
      [p.ratio, p.amp, p.decay, p.drift], p.name);
  });
});

test('BREATH timings of the port equal the hesychast table', () => {
  const body = constBody(synthSrc, 'BREATH');
  for (const [name, p] of Object.entries(synth.BREATH)) {
    const re = new RegExp(`"${name}": \\{"inhale": ([\\d.]+), ` +
      '"hold_in": ([\\d.]+), "exhale": ([\\d.]+),\\s*"hold_out": ([\\d.]+)');
    const m = body.match(re);
    assert.ok(m, `pattern ${name} in the port`);
    assert.deepEqual(m.slice(1).map(Number),
      [p.inhale, p.holdIn, p.exhale, p.holdOut], name);
  }
});

test('the tonic of every tone equals GLAS_TONIC', () => {
  const body = constBody(typikonSrc, 'GLAS_TONIC');
  for (let g = 1; g <= 8; g += 1) {
    const m = body.match(new RegExp(`${g}: ([\\d.]+)`));
    assert.ok(m, `tone ${g}`);
    assert.equal(Number(m[1]), synth.GLAS_TONIC[g], `tone ${g}`);
  }
  assert.ok(typikonSrc.includes(`const VESPERS_HOUR := ${
    clock.VESPERS_HOUR}`), 'Vespers hour');
});
