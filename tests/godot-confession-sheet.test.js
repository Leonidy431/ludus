// The headset sheet (godot/scripts/confession_sheet.gd) asks the same
// questions in the same words as the web module, and keeps the web
// module's headset promise: no field, only the questions, paper or the
// silence of the heart (CLAUDE.md TABOO 0.26 point 9).
// Run: node --test tests/*.test.js
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const C = require('../public/ludus/ludus-confession.js');

const GD = fs.readFileSync(path.join(__dirname,
  '../godot/scripts/confession_sheet.gd'), 'utf8');
const WEB = fs.readFileSync(path.join(__dirname,
  '../public/ludus/ludus-confession.js'), 'utf8');

test('the headset sheet asks the eight questions of the web sheet', () => {
  const start = GD.indexOf('const QUESTIONS');
  const block = GD.slice(start, GD.indexOf(']', start));
  const got = [...block.matchAll(/"([^"]+)"/g)].map((m) => m[1]);
  assert.deepEqual(got, C.QUESTIONS.map((q) => q.q_ru));
});

test('the headset note is the web headset note, word for word', () => {
  const note = GD.match(/const HEADSET_NOTE := "([^"]+)"/)[1];
  const raw = WEB.match(/'В шлеме на этом листке[\s\S]*?\)/)[0];
  const web = raw.replace(/'\s*\+\s*'/g, '').replace(/^'|'\)$/g, '');
  assert.equal(note, web);
});

test('the headset sheet says it is not the sacrament and burns', () => {
  assert.match(GD, /Это не таинство\. Прощает Бог/);
  assert.match(GD, /const BURN := "Сжечь листок"/);
});
