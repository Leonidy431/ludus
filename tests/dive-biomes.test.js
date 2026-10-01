'use strict';

// Biomes, bubble columns and the thermocline heard in the dive
// (docs/HLD_DIVE_BIOMES_BUBBLES_2026-09-30.md; CLAUDE.md TABOO 0.35
// rules 19-20, TABOO 0.3 rule 59).  The GDScript port is checked number
// by number in godot/tests/test_biomes.gd on godot/tests/fixture.json.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const D = require('../public/ludus/dive/dive-core.js');
const W = require('../public/ludus/ludus-water.js');
const synth = require('../public/ludus/ludus-sacred-synth.js');
const objects = require('../public/ludus/data/lake-objects-99.json').objects;
const atlas = require('../public/ludus/data/atlas-99.json');
const known = require('../godot/tests/fixtures/biome_contrast_known.json');

test('five biomes, each reachable, decided by depth and clearance', () => {
  assert.equal(D.biomeOf(5, 20), 'shallows');
  assert.equal(D.biomeOf(45, 30), 'thermocline');
  assert.equal(D.biomeOf(55, 30), 'thermocline');
  assert.equal(D.biomeOf(56, 30), 'deep');
  assert.equal(D.biomeOf(44.9, 30), 'shallows');
  // The lamp is the only light below about 113 m of clear water.
  assert.equal(D.biomeOf(112, 30), 'deep');
  assert.equal(D.biomeOf(114, 30), 'night');
  // Near the silt floor, but not on the sandy shallows.
  assert.equal(D.biomeOf(80, 1), 'sediments');
  assert.equal(D.biomeOf(10, 1), 'shallows');
  const seen = new Set();
  for (let d = 0; d <= 160; d += 1) {
    seen.add(D.biomeOf(d, 30));
    seen.add(D.biomeOf(d, 1));
  }
  assert.deepEqual([...seen].sort(), [...D.BIOMES].sort());
});

test('the water darkens with depth and red leaves first', () => {
  let prev = D.luminance(D.waterColour(0));
  for (let d = 5; d <= 160; d += 5) {
    const y = D.luminance(D.waterColour(d));
    assert.ok(y <= prev, `darker at ${d} m`);
    prev = y;
  }
  const w = D.waterColour(30);
  assert.ok(w[0] < w[1] && w[1] < w[2], 'blue-green at 30 m');
  const night = D.biomeLook(140, 10);
  assert.equal(night.sun, 0);
  assert.ok(night.ambient < D.biomeLook(80, 20).ambient);
  assert.ok(D.biomeLook(90, 1).fog > D.biomeLook(90, 20).fog,
    'stirred silt thickens the fog');
});

test('bubbles leave on the exhale of the prayer breath', () => {
  for (const [name, p] of Object.entries(synth.BREATH)) {
    const col = D.bubbleColumn(`t:${name}`, 0, 0, 20, 0, 4, p);
    assert.equal(D.bubblesPerMinute(col), 4 * W.bubblesPerMinute(p), name);
    const cycle = p.inhale + p.holdIn + p.exhale + p.holdOut;
    for (let t = 0; t < cycle; t += 0.05) {
      const q = t - p.inhale - p.holdIn;
      const exhaling = q >= 0 && q < p.exhale;
      assert.equal(D.bubblePuff(p, t) > 0, exhaling && q > 0,
        `${name} at ${t.toFixed(2)} s`);
    }
  }
});

test('a rising bubble swells as the pressure falls (Boyle)', () => {
  const p = synth.BREATH.athonite;
  const col = D.bubbleColumn('boyle', 0, 0, 30.6, 0, 1, p);
  let top = null;
  for (let i = 0; i < col.count; i++) {
    const b = D.bubbleAt(col, i, 200, false);
    if (b.visible && (!top || b.depth < top.depth)) {
      top = b;
    }
    if (b.visible) {
      const want = Math.cbrt(W.pressureBar(30.6) / W.pressureBar(b.depth));
      assert.ok(Math.abs(b.size / D.BUBBLE_R0 - want) < 1e-12);
      assert.equal(b.x, col.x + col.jitter[0].dx, 'reduced motion: straight');
    }
  }
  assert.ok(top.size / D.BUBBLE_R0 > 1.45);
});

test('the thermocline is in the sonar and crossing it is noticed', () => {
  assert.ok(Math.abs(D.layerEcho(20, 140) - 60 / 1480) < 1e-12);
  assert.equal(D.layerEcho(60, 140), null, 'below the layer: none');
  assert.equal(D.layerEcho(20, 40), null, 'floor above the layer: none');
  assert.equal(D.thermoCrossing(49.9, 50.1), 'down');
  assert.equal(D.thermoCrossing(50.1, 49.9), 'up');
  assert.equal(D.thermoCrossing(50, 50), null);
});

// Rule 20: the breath timings are the hesychasm module's.  The module
// is a sibling repository; where it is checked out, its source is read
// and compared with the table the game uses.
function moduleSource() {
  const tries = [process.env.HESYCHASM_MODULE,
    path.join(__dirname, '..', '..', 'hesychasm-meditation-module'),
    '/home/user/hesychasm-meditation-module'].filter(Boolean);
  for (const dir of tries) {
    const f = path.join(dir, 'src/hesychasm/breathing_patterns.py');
    if (fs.existsSync(f)) {
      return fs.readFileSync(f, 'utf8');
    }
  }
  return null;
}

test('BREATH equals hesychasm-meditation-module breathing_patterns.py',
  (t) => {
    const src = moduleSource();
    if (!src) {
      t.skip('hesychasm-meditation-module is not checked out here');
      return;
    }
    for (const [name, p] of Object.entries(synth.BREATH)) {
      const at = src.indexOf(`def create_${name}_pattern`);
      assert.ok(at >= 0, `create_${name}_pattern in the module`);
      const body = src.slice(at, at + 1200);
      const num = (k) => Number(body.match(
        new RegExp(`${k}_duration=([\\d.]+)`))[1]);
      assert.deepEqual([num('inhale'), num('hold_in'), num('exhale'),
        num('hold_out')], [p.inhale, p.holdIn, p.exhale, p.holdOut], name);
    }
  });

test('readability in five biomes: things read by lamp or rim, not paint',
  () => {
    // Operator, 2026-09-30: a thing is read by the lamp's highlight when
    // there is a lamp, else by the rim light, never by repainting it
    // (godot/scripts/rim_light.gd).  Paint contrast below 1.5 is still
    // measured here, but it is no longer a failure: the headset fixture
    // must show nothing unread under the lamp, and under the rim only
    // the holy things, which by rule get no band.
    const things = objects.map((o) => [`lake:${o.id}`, o.colour])
      .concat(atlas.traces.map((tr) => [`atlas:${tr.id}`, tr.colour]))
      .concat([['atlas:passage', '#6f6a60']]);
    let paintLow = 0;
    for (const [, hex] of things) {
      const low = D.BIOMES.filter((b) => D.biomeContrast(hex, b) < 1.5);
      for (const b of low) assert.ok(D.BIOMES.includes(b));
      paintLow += low.length;
    }
    assert.ok(paintLow > 0, 'paint alone leaves some pairs unread');
    assert.deepEqual(known.lamp, {});
    const holy = new Set(['atlas:khachkar'].concat(objects
      .filter((o) => o.item === 'bulla' || (o.flags && (o.flags.holy
        || o.flags.noInteract))).map((o) => `lake:${o.id}`)));
    for (const key of Object.keys(known.rim)) {
      assert.ok(holy.has(key), `${key} unread under the rim is holy`);
    }
  });
