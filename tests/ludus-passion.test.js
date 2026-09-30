// Meeting a passion (HLD F1, DEF-016/017): the ladder of a thought from
// the Ladder, step 15.  Run: node --test tests/*.test.js
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('path');
const P = require('../public/ludus/ludus-passion.js');
const data = require(path.join(__dirname,
  '../public/ludus/data/passions.json'));

const gluttony = data.passions.find((p) => p.id === 'gluttony');
const low = { wisdom: 1 };
const none = { met: {} };

function walk(passion, form, actions, ids) {
  let s = P.start(passion);
  ids.forEach((id) => { s = P.choose(s, id, passion, form, actions); });
  return s;
}

test('eight passions in the order of Evagrius, each fully described', () => {
  assert.deepEqual(data.order, ['gluttony', 'lust', 'avarice', 'sadness',
    'anger', 'acedia', 'vainglory', 'pride']);
  data.passions.forEach((p) => {
    ['virtue', 'ladder', 'source', 'teacher', 'cue', 'cue_ru', 'lure',
      'lure_ru'].forEach((k) => assert.ok(p[k], `${p.id}.${k}`));
  });
});

test('a beginner cannot name the sign but can always turn away', () => {
  const ids = P.options(P.start(gluttony), gluttony, low, none)
    .map((o) => o.id);
  assert.deepEqual(ids, ['look', 'turn']);
});

test('the mentor who teaches the sign lets the player name it', () => {
  const taught = { met: { abba_john: 1 } };
  const ids = P.options(P.start(gluttony), gluttony, low, taught)
    .map((o) => o.id);
  assert.ok(ids.includes('name'));
});

test('naming at the suggestion gives +1 Wisdom once', () => {
  const taught = { met: { abba_john: 1 } };
  const s = walk(gluttony, low, taught, ['name', 'still']);
  assert.equal(s.stage, 'virtue');
  const first = P.finish({}, s);
  assert.deepEqual(first.attributeBonuses, { wisdom: 1 });
  const again = P.finish(first.record, s);
  assert.deepEqual(again.attributeBonuses, {});
});

test('turning away or stillness pays nothing', () => {
  const s = walk(gluttony, low, none, ['turn', 'still']);
  assert.equal(s.stage, 'virtue');
  assert.deepEqual(P.finish({}, s).attributeBonuses, {});
});

test('repentance is open at every stage', () => {
  const s = walk(gluttony, low, none, ['look', 'answer', 'remember',
    'still']);
  assert.equal(s.stage, 'virtue');
});

test('consent leads to captivity without damage; the passion returns',
  () => {
    const s = walk(gluttony, low, none, ['look', 'answer', 'take']);
    assert.equal(s.stage, 'captive');
    const r = P.finish({}, s);
    assert.deepEqual(r.attributeBonuses, {});
    assert.equal(P.nextPassion(data, r.record).id, 'gluttony');
  });

test('once overcome, the road moves to the next passion', () => {
  const s = walk(gluttony, low, none, ['turn', 'still']);
  const r = P.finish({}, s);
  assert.equal(P.nextPassion(data, r.record).id, 'lust');
});

test('the same choices always give the same end', () => {
  const a = walk(gluttony, low, none, ['look', 'stop', 'still']);
  const b = walk(gluttony, low, none, ['look', 'stop', 'still']);
  assert.deepEqual(a, b);
});
