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

// --- The dive as a game (HLD P2) --------------------------------------

function run(rov, game, input, seconds, events) {
  let r = rov;
  let g = game;
  const said = [];
  for (let i = 0; i < seconds * 10; i++) {
    r = D.stepRov(r, input, 0.1);
    const out = D.stepGame(g, r, 0.1, events);
    g = out.game;
    said.push(...out.say);
  }
  return { rov: r, game: g, said };
}

test('hovering still in the shallows completes the buoyancy drill', () => {
  const res = run({ ...D.newRov(), depth: 2 }, D.newGame(), {}, 11);
  assert.ok(res.game.done.includes('hover'));
});

test('a fast rise is a fall, lifted by a safety stop, not a death', () => {
  let r = { ...D.newRov(), x: 400, depth: 70 };
  let res = run(r, D.newGame(), { vertical: 1 }, 5);
  assert.equal(res.game.fallen, true);
  assert.ok(res.said.some((s) => /остановка безопасности/.test(s)));
  // While fallen, nothing counts: a still hover earns no drill.
  const before = res.game.done.length;
  // Drag needs about two seconds to still the ROV, then 15 s of stop.
  res = run(res.rov, res.game, {}, 20);
  assert.equal(res.game.fallen, false);
  assert.ok(res.said.some((s) => /Свет вернулся/.test(s)));
  assert.equal(res.game.done.length, before);
  assert.equal(res.rov.battery > 0, true);
});

test('crossing the thermocline tells the change of sound', () => {
  let r = { ...D.newRov(), x: 450, depth: 40 };
  const res = run(r, D.newGame(), { vertical: -1 }, 60);
  assert.ok(res.game.done.includes('thermocline'));
  assert.ok(res.said.some((s) => /1480 → 1435/.test(s)));
});

test('deep silence needs the lamp off and stillness', () => {
  const deep = { ...D.newRov(), x: 600, depth: 120 };
  let res = run(deep, D.newGame(), {}, 25);
  assert.ok(!res.game.done.includes('silence'));
  res = run({ ...deep, lamp: false }, D.newGame(), {}, 25);
  assert.ok(res.game.done.includes('silence'));
});

test('three finds bring the scribe\'s line once, with its source', () => {
  const r = { ...D.newRov(), depth: 10, x: 120 };
  const res = run(r, D.newGame(), {}, 2, { handedOver: 3 });
  assert.ok(res.game.done.includes('finds'));
  assert.equal(res.said.filter((s) => s === D.SCRIBE.ru).length, 1);
  assert.ok(D.SCRIBE.meaning && D.SCRIBE.source);
});

test('the game is deterministic and has no randomness', () => {
  const a = run({ ...D.newRov() }, D.newGame(), { forward: 1 }, 12);
  const b = run({ ...D.newRov() }, D.newGame(), { forward: 1 }, 12);
  assert.deepEqual(a.game, b.game);
  const src = require('fs').readFileSync(
    require('path').join(__dirname, '../public/ludus/dive/dive-core.js'),
    'utf8');
  assert.doesNotMatch(src, /Math\.random\s*\(/);
});

test('the current drifts the ROV only on the slope', () => {
  assert.equal(D.current(100, 30), 0);
  assert.notEqual(D.current(330, 30), 0);
  const r = D.stepRov({ ...D.newRov(), x: 330, depth: 60 },
    { drift: 0.2 }, 1);
  assert.ok(r.z > 0.19);
});

test('a whole dive 0 -> 60 -> 0 m: crossing, slow rise, no fall', () => {
  // Down the slope to 60 m, then up at 0.15 m/s (9 m/min), inside the
  // diver's limit, all the way to the surface.
  let r = { ...D.newRov(), x: 340, depth: 0.5 };
  let g = D.newGame();
  const said = [];
  let maxDepth = 0;
  const step = (inp) => {
    r = D.stepRov(r, { ...inp, drift: D.current(r.x, 0) }, 0.1);
    const out = D.stepGame(g, r, 0.1, { handedOver: 0 });
    g = out.game;
    said.push(...out.say);
    maxDepth = Math.max(maxDepth, r.depth);
  };
  for (let i = 0; i < 3000 && r.depth < 60; i++) {
    step({ vertical: -1 });
  }
  // Hold vertical thrust so the rise settles at about 9 m/min.
  const up = 0.15 * 1.2 / 0.8;
  for (let i = 0; i < 6000 && r.depth > 0.5; i++) {
    step({ vertical: up });
  }
  assert.ok(maxDepth >= 60);
  assert.ok(r.depth <= 0.5);
  assert.ok(g.done.includes('thermocline'));
  assert.ok(g.done.includes('slope'));
  assert.ok(g.done.includes('slowrise'));
  assert.equal(g.fallen, false);
  assert.ok(!said.some((s) => /Слишком быстро/.test(s)));
});

// --- The tether (HLD_TETHER_TRIALS_PASSIONS T1) ------------------------

test('a full turn winds the tether, the same way back unwinds it', () => {
  let res = run({ ...D.newRov(), depth: 4 }, D.newGame(), { turn: 1 }, 8.4);
  assert.ok(res.game.turns > 1.0, `wound ${res.game.turns}`);
  assert.ok(res.game.wound);
  // The arm alone does not help while the cable is still twisted.
  let out = D.stepGame(res.game, res.rov, 0.1, { arm: true });
  assert.ok(!out.game.done.includes('tether'));
  res = run(res.rov, res.game, { turn: -1 }, 8.4);
  assert.ok(Math.abs(res.game.turns) <= D.UNWOUND_TURNS,
    `back to ${res.game.turns}`);
  out = D.stepGame(res.game, res.rov, 0.1, {});
  assert.ok(!out.game.done.includes('tether'), 'needs the arm');
  out = D.stepGame(res.game, res.rov, 0.1, { arm: true });
  assert.ok(out.game.done.includes('tether'));
  assert.ok(out.say.some((s) => /тем же путём/.test(s)));
});

test('three turns warn of a kink once, and no points are counted', () => {
  const res = run({ ...D.newRov(), depth: 4 }, D.newGame(), { turn: 1 },
    22);
  assert.ok(res.game.turns >= D.KINK_TURNS);
  const warned = res.said.filter((s) => /три оборота/.test(s));
  assert.equal(warned.length, 1);
  assert.ok(!('score' in res.game) && !('points' in res.game));
});
