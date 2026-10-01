'use strict';

// The prayer rope of the headset keeps the pace of the breath
// (godot/scripts/rope_core.gd, RopeCore.BREATH).  TABOO 0.35 rule 20:
// breath timings come only from hesychasm-meditation-module.  This test
// ties the rope's table to the JS synth's BREATH (the web's copy) and,
// when the module is checked out beside ludus (or HESYCHASM_MODULE
// points at it), to breathing_patterns.py itself.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const synth = require('../public/ludus/ludus-sacred-synth.js');

const ropeSrc = fs.readFileSync(path.join(__dirname, '..', 'godot',
  'scripts', 'rope_core.gd'), 'utf8');

function ropeTable() {
  const start = ropeSrc.indexOf('const BREATH :=');
  assert.ok(start >= 0, 'const BREATH in rope_core.gd');
  const body = ropeSrc.slice(start, start + ropeSrc.slice(start)
    .search(/\n}/));
  const out = {};
  for (const m of body.matchAll(/"(\w+)": \{"inhale": ([\d.]+), "hold_in": ([\d.]+), "exhale": ([\d.]+),\s*"hold_out": ([\d.]+)\}/g)) {
    out[m[1]] = [m[2], m[3], m[4], m[5]].map(Number);
  }
  return out;
}

test('the rope breathes by the same table as the web synth', () => {
  const rope = ropeTable();
  assert.deepEqual(Object.keys(rope).sort(),
    Object.keys(synth.BREATH).sort());
  for (const [name, p] of Object.entries(synth.BREATH)) {
    assert.deepEqual(rope[name], [p.inhale, p.holdIn, p.exhale, p.holdOut],
      name);
  }
});

test('the rope breathes by the hesychasm module itself', (t) => {
  const file = path.join(process.env.HESYCHASM_MODULE
    || path.join(__dirname, '..', '..', 'hesychasm-meditation-module'),
  'src', 'hesychasm', 'breathing_patterns.py');
  if (!fs.existsSync(file)) {
    t.skip(`module not checked out at ${file}`);
    return;
  }
  const py = fs.readFileSync(file, 'utf8');
  const rope = ropeTable();
  for (const name of Object.keys(rope)) {
    const at = py.indexOf(`def create_${name}_pattern`);
    assert.ok(at >= 0, `create_${name}_pattern in the module`);
    const body = py.slice(at, at + 1500);
    const num = (key) => Number(body.match(
      new RegExp(`${key}_duration=([\\d.]+)`))[1]);
    assert.deepEqual(rope[name], [num('inhale'), num('hold_in'),
      num('exhale'), num('hold_out')], name);
  }
});
