'use strict';

// The tone of the week (Octoechos) and its ison (TABOO 0.35 rule 10).

const test = require('node:test');
const assert = require('node:assert/strict');
const clock = require('../public/ludus/ludus-liturgical-clock.js');
const G = require('../public/ludus/ludus-glas.js');
const synth = require('../public/ludus/ludus-sacred-synth.js');

const at = (s) => new Date(s);

test('the cycle starts with tone 1 on Thomas Sunday', () => {
  // Pascha 2026 is 12 April (civil), Thomas Sunday 19 April.
  assert.equal(G.glasOf(at('2026-04-19T10:00'), clock), 1);
  assert.equal(G.glasOf(at('2026-04-26T10:00'), clock), 2);
});

test('All Saints 2024 falls in tone 8', () => {
  assert.equal(G.glasOf(at('2024-06-30T10:00'), clock), 8);
});

test('the Sunday tone begins at Saturday Vespers', () => {
  assert.equal(G.glasOf(at('2026-04-25T17:00'), clock), 1);
  assert.equal(G.glasOf(at('2026-04-25T19:00'), clock), 2);
});

test('Holy Week has no tone; Bright Week skips the grave tone', () => {
  assert.equal(G.glasOf(at('2026-04-10T10:00'), clock), null);
  const bright = [12, 13, 14, 15, 16, 17, 18].map((d) =>
    G.glasOf(at(`2026-04-${d}T10:00`), clock));
  assert.deepEqual(bright, [1, 2, 3, 4, 5, 6, 8]);
});

test('before Pascha the cycle continues from last year', () => {
  const g = G.glasOf(at('2026-03-01T10:00'), clock);
  assert.ok(g >= 1 && g <= 8);
});

test('every tone has an ison cue on its tonic', () => {
  const bases = { Pa: 146.83, Di: 196.0, Ga: 174.61, Zo: 116.54,
    Ni: 130.81 };
  for (let g = 1; g <= 8; g++) {
    assert.ok(synth.has(`ison_glas_${g}`), `cue for tone ${g}`);
    assert.equal(synth.GLAS_TONIC[g], bases[G.GLASY[g].base], `tone ${g}`);
  }
  const d = G.describe(at('2026-09-29T12:00'), clock);
  assert.equal(d.glas, 8);
  assert.equal(d.cue, 'ison_glas_8');
});
