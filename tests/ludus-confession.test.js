// Static guarantees behind the confession-privacy declaration
// (CLAUDE.md TABOO 0.26, docs/CONFESSION_PRIVACY_DECLARATION.md).
// The module must contain no storage, network or logging API at all,
// so a later edit that adds one fails the build instead of leaking.
// Run: node --test tests/*.test.js
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const SRC = fs.readFileSync(path.join(__dirname,
  '../public/ludus/ludus-confession.js'), 'utf8');
// Comments may name the forbidden APIs to declare them; code may not.
const CODE = SRC.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');

const FORBIDDEN = [
  'localStorage', 'sessionStorage', 'indexedDB', 'document.cookie',
  'caches', 'serviceWorker', 'fetch(', 'XMLHttpRequest', 'sendBeacon',
  'WebSocket', 'EventSource', 'postMessage', 'console.', 'dispatchEvent',
  'CustomEvent', 'firebase', 'firestore', 'gtag', 'analytics',
  'innerHTML', '.value)', 'navigator.clipboard',
];

test('the confession module uses no storage, network or logging API',
  () => {
    FORBIDDEN.forEach((name) => {
      assert.equal(CODE.includes(name), false, `found ${name}`);
    });
  });

test('the typed text is read only to overwrite it', () => {
  // The only reads of .value are inside burnField, as its length.
  const reads = CODE.match(/\.value(?!\s*=)/g) || [];
  assert.equal(reads.length, 1);
  assert.match(CODE, /field\.value = ' '\.repeat\(field\.value\.length\)/);
});

test('spell-check and autocomplete are off on the page', () => {
  assert.match(CODE, /spellcheck: 'false'/);
  assert.match(CODE, /autocomplete: 'off'/);
});

test('the page says plainly that it is not the sacrament', () => {
  assert.match(CODE, /This is not the sacrament/);
  assert.match(CODE, /Это не таинство/);
});

test('the rule panel offers no counter for confession', () => {
  const actions = require('../public/ludus/ludus-actions.js');
  assert.equal(actions.PRACTICES.some((p) => /confess/.test(p.id)), false);
});

test('the Eucharist is only in the story: no practice or button', () => {
  const actions = require('../public/ludus/ludus-actions.js');
  const re = /euchar|communion|liturgy|причащ|евхарист/i;
  assert.equal(actions.PRACTICES.some((p) => re.test(p.id + p.label)),
    false);
  const game = fs.readFileSync(path.join(__dirname,
    '../public/ludus/ludus-game.js'), 'utf8');
  assert.equal(/data-action="[^"]*(euchar|communion)/i.test(game), false);
});

test('a headset gets no field: dictation cannot be switched off', () => {
  assert.match(CODE, /function isHeadset\(\)/);
  assert.match(CODE, /OculusBrowser\|Quest/);
  // The headset branch returns before any textarea is created.
  const branch = CODE.slice(CODE.indexOf('if (isHeadset())'),
    CODE.indexOf("const field = el('textarea'"));
  assert.match(branch, /return;/);
  assert.equal(branch.includes("'textarea'"), false);
});

test('other devices are warned about dictation and keyboards', () => {
  assert.match(CODE, /Do not dictate by voice/);
  assert.match(CODE, /Не диктуйте голосом/);
});
