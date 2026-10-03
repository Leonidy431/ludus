// Every person of the valley drawn by ludus-game.js has a portrait.
// The page builds the image path from the npcId (npc-<id with _ as ->
// .svg); a load run on the dev server (2026-10-03) found ten people of
// the twelve stories with no portrait, so the page showed ten 404s.
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.join(__dirname, '..');
const ART = path.join(ROOT, 'public', 'ludus', 'art');
const PACK = path.join(ROOT, 'public', 'ludus', 'data',
  'dialogue-trees.json');

test('each valley NPC has npc-<id>.svg in public/ludus/art', () => {
  const trees = JSON.parse(fs.readFileSync(PACK, 'utf8')).trees || {};
  const missing = Object.values(trees)
    .filter((t) => t && t.npcId)
    .map((t) => `npc-${t.npcId.replace(/_/g, '-')}.svg`)
    .filter((f) => !fs.existsSync(path.join(ART, f)));
  assert.deepStrictEqual(missing, []);
});
