// The Issyk-Kul campaign spine (HLD F1, DEF-018), built read-only from
// webtypicon2 by scripts/build-campaign-spine.py.
// Run: node --test tests/*.test.js
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const spine = require('../public/ludus/data/campaign-spine.json');

test('99 missions, each once, in a prologue, five acts and a finale', () => {
  assert.equal(spine.order.length, 99);
  assert.equal(new Set(spine.order).size, 99);
  assert.deepEqual(spine.acts.map((a) => a.id), ['prologue', 'trade',
    'spiritual', 'hydrology', 'diplomacy', 'craft', 'narrative']);
  assert.deepEqual(spine.order, spine.acts.flatMap((a) => a.missions));
});

test('no knowledge-check answer leaks out of webtypicon2', () => {
  const text = JSON.stringify(spine);
  assert.equal(/correctIndex|options/.test(text), false);
});

test('missions that trade relics are flagged for the chorus', () => {
  const ids = spine.needsChorusRewrite.map((m) => m.id);
  assert.ok(ids.includes(14), 'Рынок реликвий must be reviewed');
  spine.needsChorusRewrite.forEach((m) => assert.ok(m.review.length > 0));
});
