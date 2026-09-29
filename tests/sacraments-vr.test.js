// Guarantees for the seven sacrament scenes (docs/SACRAMENTS_VR_SCENES.md,
// CLAUDE.md TABOO 0.26): the player is a witness, holy objects carry
// noInteract and noLoot, no microphone, no reward, no presence log.
// Run: node --test tests/*.test.js
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const IDS = ['confession', 'baptism', 'chrismation', 'eucharist',
  'ordination', 'marriage', 'unction'];
const scenes = JSON.parse(fs.readFileSync(
  path.join(ROOT, 'scripts/meta3d/sacrament-scenes.json'), 'utf8'));

test('there are exactly the seven sacraments', () => {
  assert.deepEqual(scenes.map((s) => s.id).sort(),
    IDS.map((i) => `sacrament-${i}`).sort());
});

test('every scene keeps the microphone off and gives nothing', () => {
  scenes.forEach((s) => {
    assert.equal(s.microphone, false, s.id);
    assert.equal(s.speechRecognition, false, s.id);
    assert.equal(s.logPresence, false, s.id);
    assert.equal(s.reward, null, s.id);
    assert.equal(s.attributes, null, s.id);
    assert.equal(s.gate, null, s.id);
  });
});

test('holy objects are never interactive or loot', () => {
  scenes.forEach((s) => {
    const holy = s.parts.filter((p) => p.flags && p.flags.holy);
    assert.ok(holy.length > 0, s.id);
    holy.forEach((p) => {
      assert.equal(p.flags.noInteract, true, `${s.id}/${p.name}`);
      assert.equal(p.flags.noLoot, true, `${s.id}/${p.name}`);
    });
  });
});

test('every scene has a witness line and a published model', () => {
  scenes.forEach((s) => {
    assert.ok(s.parts.some((p) => p.flags && p.flags.witnessLine), s.id);
    const meta = path.join(ROOT, `public/vr/models/scene/${s.id}.json`);
    assert.ok(fs.existsSync(meta), meta);
    assert.equal(JSON.parse(fs.readFileSync(meta, 'utf8')).microphone,
      false);
  });
});

test('the VR panel silences the microphone in a sacred zone', () => {
  const vr = fs.readFileSync(path.join(ROOT, 'public/vr/vr.js'), 'utf8');
  assert.match(vr, /ludus:sacred-zone/);
  assert.match(vr, /if \(inside\) stopListening\(\);/);
  assert.match(vr, /if \(voiceBtn\.disabled\) return;/);
});

test('no action performs a sacrament', () => {
  const re = /(bapti[sz]e|chrismate|commune|anoint|ordain|wed|absolve|крестить|помазать|причастить|соборовать|венчать|рукоположить)/i;
  const actions = require('../public/ludus/ludus-actions.js');
  actions.PRACTICES.forEach((p) => assert.equal(re.test(p.id), false));
  const game = fs.readFileSync(path.join(ROOT,
    'public/ludus/ludus-game.js'), 'utf8');
  const labels = game.match(/data-action="[^"]+"/g) || [];
  labels.forEach((l) => assert.equal(re.test(l), false, l));
});

test('confession and communion are seen only from afar', () => {
  const conf = scenes.find((s) => s.id === 'sacrament-confession');
  const line = conf.parts.find((p) => p.flags && p.flags.witnessLine);
  const analoy = conf.parts.find((p) => p.name === 'analoy-top');
  const dist = Math.abs(line.pos[2] - analoy.pos[2]);
  assert.ok(dist >= 4, `witness line only ${dist} m from the analogion`);
  assert.equal(conf.confessionAudible, false);
  conf.parts.filter((p) => p.flags && p.flags.npc).forEach((p) => {
    assert.equal(p.flags.wordsAudible, false, p.name);
  });
  const euch = scenes.find((s) => s.id === 'sacrament-eucharist');
  const eLine = euch.parts.find((p) => p.flags && p.flags.witnessLine);
  const solea = euch.parts.find((p) => p.name === 'solea');
  assert.ok(Math.abs(eLine.pos[2] - solea.pos[2]) >= 4);
});
