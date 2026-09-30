'use strict';

// The dive scene's rules (public/ludus/dive/dive-core.js): every lake
// object and fish inside its own depth range, a deterministic world, the
// ROV physics and the operator's loot rule (docs/ISSYK_KUL_FISH.md).

const test = require('node:test');
const assert = require('node:assert/strict');
const D = require('../public/ludus/dive/dive-core.js');
const objects = require('../public/ludus/data/lake-objects-99.json').objects;
const fish = require('../public/ludus/data/issyk-kul-fish.json').fish;

test('the floor deepens from the shore to the deep plain', () => {
  let prev = -1;
  for (let x = 0; x <= D.LENGTH_M; x += 10) {
    const d = D.baseDepth(x);
    assert.ok(d >= prev, `x=${x}`);
    prev = d;
  }
  assert.equal(D.baseDepth(0), 0);
  assert.ok(D.baseDepth(D.LENGTH_M) >= 150);
  assert.ok(Math.abs(D.baseDepth(D.xForDepth(77)) - 77) < 1e-6);
});

test('every placed object sits inside its own depth range', () => {
  const placed = D.placeObjects(objects);
  const expected = objects.filter((o) => o.category !== 'fish'
    && o.item !== 'tether').length;
  assert.equal(placed.length, expected);
  placed.forEach((p) => {
    assert.ok(p.depth >= p.depthRange[0] - 0.01
      && p.depth <= p.depthRange[1] + 0.01, `${p.id} at ${p.depth}`);
    if (p.where === 'floor') {
      assert.ok(Math.abs(D.floorDepth(p.x, p.z) - p.depth) < 0.31
        || p.depth === 0.3, `${p.id} floats`);
    } else {
      assert.ok(D.floorDepth(p.x, p.z) > p.depth, `${p.id} buried`);
    }
  });
});

test('the world is the same on every visit', () => {
  assert.deepEqual(D.placeObjects(objects), D.placeObjects(objects));
  const a = D.fishSchools(fish);
  assert.deepEqual(a, D.fishSchools(fish));
  assert.deepEqual(D.fishAt(a[0], 3, 12.5), D.fishAt(a[0], 3, 12.5));
});

test('fish swim only inside their depth range, over deeper floor', () => {
  D.fishSchools(fish).forEach((s) => {
    for (let t = 0; t < 120; t += 7) {
      for (let i = 0; i < s.count; i++) {
        const p = D.fishAt(s, i, t);
        assert.ok(p.depth >= s.depthRange[0] && p.depth <= s.depthRange[1],
          `${s.id}#${i}@${t}`);
      }
    }
    assert.ok(D.baseDepth(s.centre.x) >= s.centre.depth - 0.01, s.id);
  });
  assert.equal(D.fishSchools(fish).length, fish.length);
});

test('temperature falls across the thermocline', () => {
  assert.ok(D.temperature(0) > 17);
  assert.ok(D.temperature(120) < 5);
  assert.ok(D.temperature(40) - D.temperature(60) > 8);
});

test('the ROV keeps off the floor and the surface, and drains', () => {
  let s = D.newRov();
  for (let i = 0; i < 600; i++) {
    s = D.stepRov(s, { forward: 1, vertical: -1 }, 0.1);
  }
  assert.ok(s.depth <= D.floorDepth(s.x, s.z) - D.ROV.minClearance + 1e-9);
  assert.ok(s.battery < 1 && s.battery > 0.9);
  for (let i = 0; i < 2000; i++) {
    s = D.stepRov(s, { vertical: 1 }, 0.1);
  }
  assert.ok(s.depth >= 0.3);
  const speed = Math.hypot(s.vx, s.vz);
  assert.ok(speed <= D.ROV.maxSpeed + 1e-9);
});

test('a fast rise breaks the diver\'s 10 m/min rule', () => {
  let s = { ...D.newRov(), x: 400, depth: 60 };
  for (let i = 0; i < 30; i++) {
    s = D.stepRov(s, { vertical: 1 }, 0.1);
  }
  const t = D.telemetry(s);
  assert.ok(t.ascentMPerMin > 10);
  assert.equal(t.ascentTooFast, true);
  let slow = { ...D.newRov(), x: 400, depth: 60 };
  for (let i = 0; i < 30; i++) {
    slow = D.stepRov(slow, { vertical: 0.1 }, 0.1);
  }
  assert.equal(D.telemetry(slow).ascentTooFast, false);
});

test('the sonar echo uses the real speed of sound', () => {
  const s = { ...D.newRov(), x: 500, depth: 80 };
  const t = D.telemetry(s);
  assert.equal(t.soundSpeed, 1435);
  const range = t.floor - t.depth;
  assert.ok(Math.abs(t.echoDelay - 2 * range / 1435) < 1e-9);
});

test('loot follows one rule per thing', () => {
  const byItem = (id) => D.placeObjects(objects).find((p) => p.item === id);
  let r = D.lootAction(byItem('boulder'), null);
  assert.deepEqual(r.bag.kept, ['boulder']);
  r = D.lootAction(byItem('boulder'), r.bag);
  assert.equal(r.bag.kept.length, 1);
  const bulla = byItem('bulla');
  if (bulla) {
    const b = D.lootAction(bulla, r.bag);
    assert.equal(b.rule, null);
    assert.match(b.text, /крест/);
    assert.deepEqual(b.bag, r.bag);
  }
  const chebak = D.fishSchools(fish).find((s) => s.id === 'chebak');
  const c = D.lootAction(chebak, r.bag);
  assert.equal(c.rule, 'release');
  assert.ok(!c.bag.kept.includes('chebak'));
  assert.deepEqual(c.bag.released, ['chebak']);
  const water = D.placeObjects(objects).find((p) => p.category === 'water');
  assert.equal(D.lootAction(water, null).rule, null);
});

test('only what lies ahead within reach is offered', () => {
  const s = { ...D.newRov(), x: 100, z: 0, depth: 10, yaw: 0 };
  const ahead = { id: 'a', x: 102, z: 0, depth: 10 };
  const behind = { id: 'b', x: 98.5, z: 0, depth: 10 };
  assert.equal(D.nearest(s, [ahead, behind], 4).thing.id, 'a');
  assert.equal(D.nearest(s, [behind], 4), null);
  assert.equal(D.nearest(s, [{ id: 'far', x: 120, z: 0, depth: 10 }], 4),
    null);
});
