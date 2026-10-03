'use strict';

// HLD F10 (CH24-24): the web build agrees with the water model and the
// Typikon.  The ROV panel takes pressure from ludus-water.js and the
// water layer from the single thermocline at 50 m; no bell plays as
// music or answers the player's prayer; the Paschalion holds past 2099.
// Run: node --test tests/*.test.js

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const W = require('../public/ludus/ludus-water.js');
const C = require('../public/ludus/ludus-liturgical-clock.js');
const synth = require('../public/ludus/ludus-sacred-synth.js');

const pub = (f) => path.join(__dirname, '..', 'public', 'ludus', f);

// Loads a browser module into a minimal window.  The document stays in
// the "loading" state, so the modules register their API but draw
// nothing; the logic under test never touches the DOM.
function loadInWindow(file, extra) {
  const sandbox = Object.assign({ console, setTimeout, clearTimeout,
    Promise }, extra || {});
  sandbox.window = sandbox;
  sandbox.addEventListener = function () {};
  sandbox.document = {
    readyState: 'loading',
    addEventListener() {},
    getElementById() { return null; },
    createElement() { return { style: {} }; },
    visibilityState: 'visible',
  };
  sandbox.navigator = { userAgent: 'test', onLine: false };
  vm.createContext(sandbox);
  vm.runInContext(fs.readFileSync(pub(file), 'utf8'), sandbox);
  return sandbox;
}

test('ROV panel pressure comes from LudusWater: 102 m = 11.01325 bar',
  () => {
    const win = loadInWindow('rov-lake-manager.js', { LudusWater: W });
    const rov = win.__ROVLakeManager;
    assert.ok(Math.abs(rov._pressureFromDepth(102) - 11.01325) < 0.001);
    assert.equal(rov._pressureFromDepth(102), W.pressureBar(102));
    // The page without ludus-water.js shows the same number.
    const bare = loadInWindow('rov-lake-manager.js').__ROVLakeManager;
    assert.ok(Math.abs(bare._pressureFromDepth(102) - 11.01325) < 0.001);
    // The old private constant is gone from the source.
    const src = fs.readFileSync(pub('rov-lake-manager.js'), 'utf8');
    assert.ok(!src.includes('0.0981'), 'no 0.0981 bar/m');
  });

test('ROV water layer follows depth against the 50 m thermocline', () => {
  const rov = loadInWindow('rov-lake-manager.js',
    { LudusWater: W }).__ROVLakeManager;
  assert.equal(rov.THERMOCLINE_M, 50);
  assert.equal(rov._layerForDepth(null), null);
  assert.equal(rov._layerForDepth(10), 'epilimnion');
  assert.equal(rov._layerForDepth(50), 'thermocline');
  assert.equal(rov._layerForDepth(120), 'hypolimnion');
  assert.equal(rov._layerForDepth(668), 'hypolimnion');
});

test('no bell in the music catalog; prayer is not answered by a bell',
  () => {
    const win = loadInWindow('ludus-audio-manager.js',
      { LudusLiturgicalClock: C });
    const audio = win.LudusAudioManager;
    const bellRecipes = ['blagovest', 'blagovest_stroke',
      'small_bell_stroke', 'trezvon', 'trezvon_motif', 'perezvon',
      'perebor', 'zvon_v_dvoi'];
    for (const key of Object.keys(audio.MUSIC_CATALOG)) {
      assert.ok(!/bell/i.test(key), `music track ${key}`);
      assert.ok(!bellRecipes.includes(synth.resolve
        ? synth.resolve(key) : key), `music track ${key} is a bell`);
      assert.equal(audio.bellAllowed(key, new Date('2026-04-10T12:00')),
        true, `${key} is not a bell order`);
    }
    // The prayer cue is a breath, not a bell, on any day.
    assert.equal(audio.bellAllowed('prayer_delivered',
      new Date('2026-04-11T12:00')), true);
    if (synth.resolve) {
      assert.equal(synth.resolve('prayer_delivered'), 'breathing');
      assert.equal(synth.resolve('monastery_bells'), null);
    }
    for (const [key, sfx] of Object.entries(audio.SFX_CATALOG || {})) {
      assert.notEqual(sfx.cue, 'prayer_delivered', `sfx ${key}`);
    }
  });

test('Pascha 2100 is 2 May (Julian offset 14 days after 2099)', () => {
  const iso = (d) => d.toISOString().slice(0, 10);
  assert.equal(C.julianOffsetDays(2099), 13);
  assert.equal(C.julianOffsetDays(2100), 14);
  assert.equal(iso(C.paschaCivil(2099)), '2099-04-12');
  assert.equal(iso(C.paschaCivil(2100)), '2100-05-02');
  // Pascha is always a Sunday.
  for (const y of [2099, 2100, 2101, 2150, 2200]) {
    assert.equal(C.paschaCivil(y).getUTCDay(), 0, `Pascha ${y}`);
  }
  // The headset computes the offset by the same rule.
  const gd = fs.readFileSync(path.join(__dirname, '..', 'godot',
    'scripts', 'audio', 'typikon.gd'), 'utf8');
  assert.ok(gd.includes('year / 100 - year / 400 - 2'), 'typikon.gd');
  assert.ok(!/_day\(year, month, day\) \+ 13 \* DAY/.test(gd),
    'no fixed +13 in pascha_civil');
});
