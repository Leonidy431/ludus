// Tests for the ACTION layer and the three-part gate check
// (CLAUDE.md constitution section 4, TABOO 0.35 rule 14).
// Run: node --test tests/
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const A = require('../public/ludus/ludus-actions.js');

const wise = (w) => ({ wisdom: w, faith: 1, dexterity: 1, constitution: 1,
  charisma: 1, cunning: 20, erudition: 1 });

function pray(actions, n) {
  let a = actions;
  for (let i = 0; i < n; i += 1) a = A.prayKnot(a);
  return a;
}

test('Wisdom alone does not open the first gate', () => {
  const check = A.evaluate(A.GATES[0], wise(20), A.EMPTY);
  assert.equal(check.open, false);
  assert.deepEqual(check.missing.map((m) => m.kind), ['dialogue', 'rite']);
});

test('the first gate opens with Wisdom, the mentor and the rite', () => {
  let a = A.recordMeeting(A.EMPTY, 'theodora');
  a = pray(a, 10);
  assert.equal(A.evaluate(A.GATES[0], wise(4), a).open, true);
  assert.equal(A.evaluate(A.GATES[0], wise(3), a).open, false);
});

test('Cunning opens no gate', () => {
  const form = { ...wise(1), cunning: 20 };
  assert.equal(A.currentGate(form, pray(A.EMPTY, 999)), null);
});

test('a fast counts once per calendar day', () => {
  let a = A.keepFast(A.EMPTY, '2026-09-29');
  a = A.keepFast(a, '2026-09-29');
  assert.equal(a.fastDays, 1);
  a = A.keepFast(a, '2026-09-30');
  assert.equal(a.fastDays, 2);
  assert.equal(A.keepFast(a, 'not-a-date').fastDays, 2);
});

test('gates 4-6 wait for the gift even when all else holds', () => {
  let a = A.recordMeeting(A.EMPTY, 'elder_sergius');
  a = A.addStillness(a, 10);
  const gate = A.GATES[3];
  const before = A.evaluate(gate, wise(10), a);
  assert.equal(before.open, false);
  assert.equal(before.readyForGift, true);
  assert.deepEqual(before.missing.map((m) => m.kind), ['gift']);
  a = A.acceptGift(a, wise(10), gate.id);
  assert.equal(A.evaluate(gate, wise(10), a).open, true);
});

test('the bow cannot skip an unmet condition', () => {
  const a = A.acceptGift(A.EMPTY, wise(20), 'contemplative');
  assert.equal(a.gifts.contemplative, undefined);
});

test('a higher gate never opens before a lower one', () => {
  let a = A.recordMeeting(A.EMPTY, 'abba_john');
  a = A.keepFast(a, '2026-09-29');
  const ladder = A.evaluateLadder(wise(8), a);
  assert.equal(A.evaluate(A.GATES[2], wise(8), a).open, true);
  assert.equal(ladder[2].open, false);
  assert.ok(ladder[2].missing.some((m) => m.kind === 'ladder'));
});

test('only whole minutes of stillness count', () => {
  assert.equal(A.addStillness(A.EMPTY, 0.9).meditationHours, 0);
  assert.equal(A.addStillness(A.EMPTY, 30).meditationHours, 0.5);
});

test('normalize drops tampered keys and bad values', () => {
  const a = A.normalize({ prayerCount: -5, fastDays: 'x', xp: 999,
    met: { theodora: 2, '<img>': 1 }, gifts: { apophatic: 'yes' } });
  assert.deepEqual(a, { prayerCount: 0, fastDays: 0, meditationHours: 0,
    lastFastDay: null, met: { theodora: 2 }, gifts: {} });
});
