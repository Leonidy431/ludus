'use strict';

// The church-word stop-list: one file, one verdict.  The web copy is the
// headset's file byte for byte, and the shared corpus gives the same
// answers here as in godot/tests/test_church_words.gd (blind spot 16;
// docs/decisions/STOPLIST_SINGLE_SOURCE_2026-10-02.md).

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const C = require('../public/ludus/ludus-church-words.js');

const ROOT = path.join(__dirname, '..');
const read = (p) => fs.readFileSync(path.join(ROOT, p));
const LIST = JSON.parse(read('public/ludus/data/church-words.json'));
const CORPUS = JSON.parse(read('tests/fixtures/church-words-corpus.json'));

test('the web copy is the headset file byte for byte', () => {
  assert.ok(read('public/ludus/data/church-words.json')
    .equals(read('godot/data/church-words.json')));
  assert.ok(LIST.stems.includes('богородиц'));
  assert.ok(LIST.stems.includes('евангел'));
});

test('the corpus: every must-flag line is caught by its word', () => {
  assert.ok(CORPUS.must_flag.length >= 30);
  CORPUS.must_flag.forEach(([text, word]) => {
    assert.equal(C.churchWord(LIST, text), word, text);
  });
});

test('the corpus: every look-alike twin passes', () => {
  assert.ok(CORPUS.must_pass.length >= 10);
  CORPUS.must_pass.forEach(([text]) => {
    assert.equal(C.churchWord(LIST, text), '', text);
  });
});

test('the code holds no copy of the list', () => {
  // The old lists were literals in three languages; none may come back.
  const core = read('godot/scripts/locations_core.gd').toString();
  const gen = read('scripts/locations/locations_99.py').toString();
  assert.ok(!/CHURCH_WORDS\s*:?=\s*\[/.test(core), 'locations_core.gd');
  assert.ok(!/CHURCH_WORDS\s*=\s*\[/.test(gen), 'locations_99.py');
});
