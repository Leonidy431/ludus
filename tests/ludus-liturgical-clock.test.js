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
  // The Typikon rings звон в двои to the Royal Hours of Great Friday;
  // no source names a перебор that day (open question q-shroud-vespers
  // in bell-rules.json), so it is not allowed.
  assert.equal(C.mayRing('двои', noon('2026-04-10')), true);
  assert.equal(C.mayRing('перебор', noon('2026-04-10')), false);
  assert.equal(C.mayRing('трезвон', noon('2026-04-11')), false);
  assert.equal(C.mayRing('двои', noon('2026-04-11')), false);
});

test('the orders of each period are the periodOrders of bell-rules.json',
  () => {
    const fs = require('fs');
    const path = require('path');
    const web = path.join(__dirname, '../public/ludus/data/bell-rules.json');
    const headset = path.join(__dirname, '../godot/data/bell-rules.json');
    const text = fs.readFileSync(web, 'utf8');
    // The headset reads the same file byte for byte.
    assert.equal(fs.readFileSync(headset, 'utf8'), text);
    const table = JSON.parse(text);
    const fromTable = {};
    for (const [k, v] of Object.entries(table.periodOrders)) {
      fromTable[k] = v.orders;
      // Every list carries a source with a short quote.
      assert.ok(v.sources.length > 0, k);
      for (const s of v.sources) {
        assert.ok(table.books[s.book], `${k}: book ${s.book}`);
        const words = s.quote.split(' ').filter((w) => /[\wа-яё]/i
          .test(w));
        assert.ok(words.length > 0 && words.length <= 25, `${k}: quote`);
      }
    }
    assert.deepEqual(C.PERIOD_ORDERS, fromTable);
    // Rule 9 of the chorus: the table itself names no трезвон on grief
    // days or Lenten weekdays, and names it in Bright Week.
    for (const k of ['great-friday', 'great-saturday', 'great-lent/daily',
      'holy-week']) {
      assert.ok(!fromTable[k].includes('трезвон'), k);
    }
    for (const k of ['pascha', 'bright-week']) {
      assert.ok(fromTable[k].includes('трезвон'), k);
    }
  });

test('Holy Week (Monday to Thursday): благовест and двои, no трезвон',
  () => {
    const wed = noon('2026-04-08');
    assert.equal(C.describe(wed).period, 'holy-week');
    assert.equal(C.mayRing('двои', wed), true);
    assert.equal(C.mayRing('трезвон', wed), false);
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
  assert.equal(audio.bellAllowed('perebor', friday), false);
  assert.equal(audio.bellAllowed('zvon_v_dvoi', friday), true);
  assert.equal(audio.bellAllowed('trezvon', sunday), true);
  assert.equal(audio.bellAllowed('choice', friday), true);
  assert.equal(await audio.playCue('trezvon', { now: friday }), null);
});
