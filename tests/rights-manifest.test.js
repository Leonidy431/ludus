'use strict';

// The Manuscript of rights lists every shipped raw object (TABOO 0.1:
// the licence register is always kept), and copyleft entries carry
// the share-alike note.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const rights = JSON.parse(fs.readFileSync(
  path.join(root, 'public/ludus/data/rights.json'), 'utf8'));

test('every derived meta-json is in the register', () => {
  const dir = path.join(root, 'public/ludus/art/derived');
  const metas = fs.readdirSync(dir).flatMap((slot) =>
    fs.readdirSync(path.join(dir, slot))
      .filter((f) => f.endsWith('.json'))
      .map((f) => f.replace(/\.json$/, '')));
  const listed = rights.raw_material.map((r) => r.object).sort();
  assert.deepEqual(listed, metas.sort(),
    'run python3 scripts/build_rights_manifest.py');
});

test('copyleft sources carry the share-alike note', () => {
  rights.raw_material.forEach((r) => {
    if (/^(A?GPL|LGPL|CC-BY-SA|MPL)/i.test(r.licence)) {
      assert.match(r.note || '', /share-alike/, r.object);
    }
    assert.ok(r.repo && r.commit && r.path, r.object);
  });
});
