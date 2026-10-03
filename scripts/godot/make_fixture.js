'use strict';
// Write godot/tests/fixture.json from the JS dive core, so the GDScript
// port (godot/scripts/dive_core.gd) is checked number by number against
// the reference (docs/HLD_HEADSET_BUILD_2026-09-30.md, P0).
// Usage: node scripts/godot/make_fixture.js

const fs = require('fs');
const path = require('path');
const D = require('../../public/ludus/dive/dive-core.js');

const root = path.join(__dirname, '..', '..');
const objects = require(path.join(root,
  'public/ludus/data/lake-objects-99.json')).objects;
const fish = require(path.join(root,
  'public/ludus/data/issyk-kul-fish.json')).fish;

const rngSamples = ['dive:x', 'school:chebak', 'Иссык'].map((seed) => {
  const r = D.rng(seed);
  return { seed, values: [r(), r(), r(), r(), r()] };
});
const schools = D.fishSchools(fish);
const fishSamples = schools.slice(0, 6).map((s) => ({
  id: s.id, at: [0, 3, 17.5].map((t) => D.fishAt(s, 2, t)),
}));
let rov = D.newRov();
const inputs = [];
for (let i = 0; i < 120; i++) {
  inputs.push({ forward: (i % 30) / 30, strafe: i % 7 === 0 ? 0.5 : 0,
    vertical: i < 80 ? -0.8 : 1, turn: i % 11 === 0 ? 0.3 : 0 });
}
inputs.forEach((inp) => { rov = D.stepRov(rov, inp, 0.1); });
const t = D.telemetry(rov);

// A game scenario: rise too fast from 70 m, stop, then cross down.
function scenario() {
  let r = { ...D.newRov(), x: 400, depth: 70 };
  let g = D.newGame();
  const plan = [[{ vertical: 1 }, 50], [{}, 200], [{ vertical: -1 }, 30],
    [{ vertical: 1 }, 80], [{ vertical: -1 }, 400]];
  const said = [];
  plan.forEach(([inp, steps]) => {
    for (let i = 0; i < steps; i++) {
      r = D.stepRov(r, { ...inp, drift: D.current(r.x, i * 0.1) }, 0.1);
      const out = D.stepGame(g, r, 0.1, { handedOver: 0 });
      g = out.game;
      said.push(...out.say);
    }
  });
  return { done: g.done, fallen: g.fallen, said: said.length,
    depth: r.depth, z: r.z };
}

// The tether: a full turn and a bit, the same way back, then the arm.
function tetherScenario() {
  let r = { ...D.newRov(), depth: 4 };
  let g = D.newGame();
  const said = [];
  const plan = [[{ turn: 1 }, 84, false], [{ turn: -1 }, 84, false],
    [{}, 1, true], [{ turn: 1 }, 220, false]];
  plan.forEach(([inp, steps, arm]) => {
    for (let i = 0; i < steps; i++) {
      r = D.stepRov(r, inp, 0.1);
      const out = D.stepGame(g, r, 0.1, { handedOver: 0, arm });
      g = out.game;
      said.push(...out.say);
    }
  });
  return { done: g.done, turns: g.turns, wound: g.wound, said: said.length,
    yaw: r.yaw };
}

// A flat battery at 120 m: the vehicle floats up, never faster than
// 10 m/min, and the narrator tells it once going up and once at the top
// (CLAUDE.md TABOO 0.017, rule 19).
function recoveryScenario() {
  let r = { ...D.newRov(), x: 500, depth: 120, battery: 0, vy: -0.4 };
  let g = D.newGame();
  const said = [];
  const depths = [];
  let fastest = 0;
  for (let i = 0; i < 2000; i++) {
    const before = r.depth;
    r = D.stepRov(r, { vertical: -1, forward: 1 }, 0.5);
    fastest = Math.max(fastest, (before - r.depth) / 0.5 * 60);
    const out = D.stepGame(g, r, 0.5, { handedOver: 0 });
    g = out.game;
    said.push(...out.say);
    if (i % 200 === 0) {
      depths.push(r.depth);
    }
  }
  return { depths, final: r.depth, fastest, said: said.length,
    recovering: g.recovering, recovered: g.recovered, done: g.done };
}

// The echo through the layer: a ping from 30 m over the deep plain.
function layeredEcho() {
  const s = { ...D.newRov(), x: 500, depth: 30 };
  const t = D.telemetry(s);
  return { depth: s.depth, x: s.x, echoDelay: t.echoDelay,
    soundSpeed: t.soundSpeed, pressureBar: t.pressureBar };
}

// Biomes, bubble columns and the layer in the sonar
// (docs/HLD_DIVE_BIOMES_BUBBLES_2026-09-30.md).
const BREATH = require('../../public/ludus/ludus-sacred-synth.js').BREATH;
function biomeFixture() {
  const places = [[3, 20], [30, 1], [48, 30], [52, 30], [80, 40],
    [90, 1], [112, 30], [116, 30], [150, 2], [10, 1]];
  const looks = places.map(([d, c]) => ({ d, c, ...D.biomeLook(d, c) }));
  const colours = ['#1e1e20', '#6a6a6a', '#e8f4f8', '#a0503a', '#5a3a22'];
  const contrast = colours.map((hex) => ({ hex,
    ratio: D.BIOMES.map((b) => D.biomeContrast(hex, b)) }));
  const columns = ['basic', 'athonite', 'sinaite'].map((name, n) => {
    const col = D.bubbleColumn(`fx:${name}`, 100 + n, 2 * n, 12 + n * 7,
      0.2, 3 + n, BREATH[name]);
    const at = [0, 7.3, 31.9, 64.25].map((t) => [0, 1, 4, col.count - 1]
      .map((i) => D.bubbleAt(col, i, t, n !== 1)));
    return { name, count: col.count, perMinute: D.bubblesPerMinute(col),
      jitter: col.jitter, at,
      puff: [0, 4.2, 6.5, 9.9, 13.1].map((t) => D.bubblePuff(BREATH[name],
        t)) };
  });
  return { looks, contrast, columns,
    layerEcho: [[10, 80], [49, 60], [55, 90], [20, 40]].map(([d, f]) =>
      D.layerEcho(d, f)),
    crossing: [[49, 51], [51, 49], [30, 31], [50, 50]].map(([a, b]) =>
      D.thermoCrossing(a, b)) };
}

const fixture = {
  biomes: biomeFixture(),
  game: scenario(),
  recovery: recoveryScenario(),
  layeredEcho: layeredEcho(),
  tether: tetherScenario(),
  note: 'Generated by scripts/godot/make_fixture.js; do not edit.',
  rng: rngSamples,
  floor: [0, 35, 160, 245, 333.3, 690].map((x) => ({ x,
    base: D.baseDepth(x), floor: D.floorDepth(x, 12.5) })),
  xForDepth: [0, 5, 20, 37, 90, 160].map((d) => ({ d, x: D.xForDepth(d) })),
  temperature: [0, 40, 50, 60, 150].map((d) => ({ d,
    t: D.temperature(d) })),
  placed: D.placeObjects(objects).map((p) => ({ id: p.id, x: p.x, z: p.z,
    depth: p.depth, yaw: p.yaw, where: p.where })),
  schools: schools.map((s) => ({ id: s.id, centre: s.centre,
    radius: s.radius, count: s.count, phase: s.phase })),
  fishAt: fishSamples,
  rov: { inputs, final: { x: rov.x, z: rov.z, depth: rov.depth,
    yaw: rov.yaw, battery: rov.battery },
  telemetry: { temperature: t.temperature, ascentMPerMin: t.ascentMPerMin,
    echoDelay: t.echoDelay, soundSpeed: t.soundSpeed,
    pressureBar: t.pressureBar } },
};
fs.writeFileSync(path.join(root, 'godot/tests/fixture.json'),
  JSON.stringify(fixture, null, 1) + '\n');
console.log(`fixture: ${fixture.placed.length} objects, `
  + `${fixture.schools.length} schools`);
