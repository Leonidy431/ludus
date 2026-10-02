'use strict';

// A word to rest: deterministic, gentle, and stored nowhere (TABOO 0.35
// rules 15 and 21; TABOO 0.39: no church words in the interface).

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const R = require('../public/ludus/ludus-rest.js');
const C = require('../public/ludus/ludus-church-words.js');
// The one stop-list of the game, its Russian and English stems alike.
const CHURCH = JSON.parse(fs.readFileSync(path.join(__dirname,
  '../public/ludus/data/church-words.json'), 'utf8'));

test('first word after 45 min by day, sooner at night, then every 30', () => {
  assert.equal(R.next(0, new Date('2026-09-29T14:00')), 45);
  assert.equal(R.next(0, new Date('2026-09-29T23:30')), 25);
  assert.equal(R.next(0, new Date('2026-09-30T03:00')), 25);
  assert.equal(R.next(1, new Date('2026-09-29T14:00')), 30);
});

test('lines rotate in a fixed order and use no church words', () => {
  assert.equal(R.pick(0), R.pick(R.LINES.length));
  R.LINES.forEach((l) => {
    assert.equal(C.churchWord(CHURCH, l.en + ' ' + l.ru), '', l.en);
  });
});

test('the module stores and sends nothing', () => {
  const src = fs.readFileSync(path.join(__dirname,
    '../public/ludus/ludus-rest.js'), 'utf8');
  for (const api of ['localStorage', 'sessionStorage', 'indexedDB',
    'fetch(', 'XMLHttpRequest', 'sendBeacon', 'document.cookie']) {
    assert.ok(!src.includes(api), api);
  }
});
