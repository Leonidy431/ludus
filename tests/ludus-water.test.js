'use strict';

// Water physics (TABOO 0.35 rule 19): the numbers a diver would check.

const test = require('node:test');
const assert = require('node:assert/strict');
const W = require('../public/ludus/ludus-water.js');
const synth = require('../public/ludus/ludus-sacred-synth.js');

test('sound is slower below the thermocline', () => {
  assert.equal(W.soundSpeed(10, 25), 1480);
  assert.equal(W.soundSpeed(40, 25), 1435);
  // A target 74 m away above the thermocline answers after 0.1 s.
  assert.ok(Math.abs(W.echoDelay(74, 10, 25) - 0.1) < 1e-9);
});

test('pressure is one atmosphere plus 1 bar per 10.2 m', () => {
  assert.equal(W.pressureBar(0), 1.01325);
  assert.ok(Math.abs(W.pressureBar(10.2) - 2.01325) < 1e-9);
  assert.ok(Math.abs(W.pressureBar(30) - 3.9544) < 1e-3);
});

test('ascent faster than 10 m/min is flagged', () => {
  assert.deepEqual(W.ascent(30, 29, 6), { mPerMin: 10, tooFast: false });
  assert.equal(W.ascent(30, 28, 6).tooFast, true);
  assert.equal(W.ascent(30, 31, 6).tooFast, false); // descending
  assert.equal(W.ascent(30, 29, 0), null);
});

test('red fades first, blue last (Beer-Lambert, clear water)', () => {
  const at10 = W.lightLeft(10);
  assert.ok(at10.red < 0.04 && at10.green > 0.5 && at10.blue > 0.9);
  assert.deepEqual(W.lightLeft(-3), W.lightLeft(0));
});

test('bubbles follow the breath of the prayer, not a free number', () => {
  assert.equal(W.bubblesPerMinute(synth.BREATH.basic), 6);
  assert.equal(W.bubblesPerMinute(synth.BREATH.athonite), 4);
});
