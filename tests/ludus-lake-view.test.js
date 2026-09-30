'use strict';

// The view from the ROV: deterministic, fish only in their depth range,
// no holy thing among the finds (TABOO 0.35 rules 6 and 15).

const test = require('node:test');
const assert = require('node:assert/strict');
const V = require('../public/ludus/ludus-lake-view.js');
const data = require('../public/ludus/data/issyk-kul-fish.json');

test('the same depth always shows the same scene', () => {
  assert.deepEqual(V.scene(12, data), V.scene(12.4, data));
});

test('every fish in view lives at that depth', () => {
  for (let d = 0; d <= 150; d += 5) {
    V.scene(d, data).fish.forEach((f) => {
      const spec = data.fish.find((x) => x.id === f.id);
      assert.ok(d >= spec.depth[0] && d <= spec.depth[1], `${f.id}@${d}`);
    });
  }
});

test('finds are neutral things with art that ships', () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const holy = /ikon|krest|ikhtis|chasha|kadil|lampad|evangel|bell/;
  data.finds.forEach((f) => {
    assert.doesNotMatch(f.art, holy, f.id);
    assert.ok(fs.existsSync(path.join(__dirname, '../public', f.art)), f.art);
  });
});

test('the 99 lake objects are drawn only in their depth range', () => {
  const objects = require('../public/ludus/data/lake-objects-99.json')
    .objects;
  assert.equal(objects.length, 99);
  const withObjects = { ...data, objects };
  for (let d = 0; d <= 150; d += 5) {
    V.scene(d, withObjects).objects.forEach((o) => {
      const spec = objects.find((x) => x.id === o.id);
      assert.ok(d >= spec.depth[0] && d <= spec.depth[1], `${o.id}@${d}`);
      assert.notEqual(spec.category, 'fish');
    });
  }
});

// Operator, 2026-09-30: "добавь всех рыб все камни и все реальное" and
// "можно брать как добычу".  Every real thing is shown; loot follows one
// rule per item, and nothing with a cross, no water and no bird is loot.
test('every real thing is among the 99, loot by rule', () => {
  const objects = require('../public/ludus/data/lake-objects-99.json')
    .objects;
  const items = new Set(objects.map((o) => o.item));
  data.fish.forEach((f) => assert.ok(items.has(f.id), f.id));
  const rules = new Set(['keep', 'release', 'hand-over', null]);
  objects.forEach((o) => {
    assert.ok(rules.has(o.flags.loot), o.id);
    assert.equal(o.flags.noLoot, o.flags.loot === null, o.id);
    if (['water', 'bird'].includes(o.category) || o.item === 'bulla') {
      assert.equal(o.flags.loot, null, o.id);
    }
    if (o.category === 'find' && o.item !== 'bulla' && o.item !== 'kosti') {
      assert.equal(o.flags.loot, 'hand-over', o.id);
    }
  });
});

test('native and endemic fish are released, never kept', () => {
  data.fish.forEach((f) => {
    const native = /endemic|native/.test(f.status);
    assert.equal(f.loot, native ? 'release' : 'keep', f.id);
    if (f.redBook) {
      assert.equal(f.loot, 'release', f.id);
    }
  });
  const bulla = data.finds.find((f) => f.id === 'bulla');
  assert.equal(bulla.loot, null);
});
