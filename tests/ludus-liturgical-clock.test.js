// The liturgical clock (HLD F1, DEF-010/019): Paschalion, the day
// beginning at Vespers, and the bell orders the Typikon allows.
// Run: node --test tests/*.test.js
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const C = require('../public/ludus/ludus-liturgical-clock.js');

const iso = (d) => d.toISOString().slice(0, 10);
// Local noon, so the Vespers rule does not move the day.
const noon = (s) => new Date(`${s}T12:00:00`);

test('Orthodox Pascha dates (civil calendar)', () => {
  assert.equal(iso(C.paschaCivil(2024)), '2024-05-05');
  assert.equal(iso(C.paschaCivil(2025)), '2025-04-20');
  assert.equal(iso(C.paschaCivil(2026)), '2026-04-12');
  assert.equal(iso(C.paschaCivil(2027)), '2027-05-02');
});

test('the liturgical day begins at Vespers', () => {
  assert.equal(C.describe(new Date('2026-04-09T17:59:00')).date,
    '2026-04-09');
  assert.equal(C.describe(new Date('2026-04-09T18:00:00')).date,
    '2026-04-10');
});

test('no трезвон on Great Friday or Great Saturday', () => {
  assert.equal(C.describe(noon('2026-04-10')).period, 'great-friday');
  assert.equal(C.mayRing('трезвон', noon('2026-04-10')), false);
  assert.equal(C.mayRing('перебор', noon('2026-04-10')), true);
  assert.equal(C.mayRing('трезвон', noon('2026-04-11')), false);
});

test('Lenten weekdays: благовест only; a Lenten Sunday keeps трезвон',
  () => {
    const wed = noon('2026-03-04');
    assert.equal(C.describe(wed).period, 'great-lent');
    assert.equal(C.mayRing('трезвон', wed), false);
    assert.equal(C.mayRing('благовест', wed), true);
    assert.equal(C.mayRing('трезвон', noon('2026-03-08')), true);
  });

test('Bright Week rings трезвон every day', () => {
  for (let d = 13; d <= 18; d += 1) {
    const day = noon(`2026-04-${d}`);
    assert.equal(C.describe(day).period, 'bright-week');
    assert.equal(C.mayRing('трезвон', day), true);
  }
});

test('great feasts are ranked great', () => {
  assert.equal(C.describe(noon('2026-01-07')).feast, 'Nativity of Christ');
  assert.equal(C.describe(noon('2026-01-07')).rank, 'great');
  assert.equal(C.describe(noon('2026-05-21')).feast, 'Ascension');
  assert.equal(C.describe(noon('2026-05-31')).feast, 'Pentecost');
});

test('the audio manager refuses трезвон on Great Friday', async () => {
  // Load the real audio manager with a minimal window: the guard runs
  // before any audio context is touched.
  const fs = require('fs');
  const path = require('path');
  const vm = require('vm');
  const sandbox = { console, setTimeout, clearTimeout, Promise };
  sandbox.window = sandbox;
  sandbox.document = { addEventListener() {}, createElement() {
    return { style: {} }; }, visibilityState: 'visible' };
  sandbox.navigator = { userAgent: 'test' };
  sandbox.LudusLiturgicalClock = C;
  vm.createContext(sandbox);
  vm.runInContext(fs.readFileSync(path.join(__dirname,
    '../public/ludus/ludus-audio-manager.js'), 'utf8'), sandbox);
  const audio = sandbox.LudusAudioManager;
  const friday = noon('2026-04-10');
  const sunday = noon('2026-04-19');
  assert.equal(audio.bellAllowed('trezvon', friday), false);
  assert.equal(audio.bellAllowed('trezvon_motif', friday), false);
  assert.equal(audio.bellAllowed('perebor', friday), true);
  assert.equal(audio.bellAllowed('trezvon', sunday), true);
  assert.equal(audio.bellAllowed('choice', friday), true);
  assert.equal(await audio.playCue('trezvon', { now: friday }), null);
});
