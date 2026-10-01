'use strict';
// Write godot/tests/fixtures/dialogue.json from
// public/ludus/ludus-npc-dialogue-manager.js, the reference for the
// headset's DialogueCore (godot/scripts/dialogue_core.gd).
//
// The browser module is run in a small sandbox as a guest (no player
// id): trees come from the bundled pack and nothing is sent anywhere.
// For each of the 24 trees and six FORM profiles the fixture records,
// per node, which branches the FORM opens, and a walk that always takes
// a fixed open branch, with the bonuses the module returns.  A synthetic
// tree with bad values checks the normalisation (only seven attributes,
// a bonus rounded and clamped to +1..+5, the start node fallback, and
// the loose Number() of numeric strings, null, true and arrays).
// Nothing is random: the same data gives the same file.
// Usage: node scripts/godot/make_dialogue_fixture.js

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const root = path.join(__dirname, '..', '..');
const PACK = path.join(root, 'public/ludus/data/dialogue-trees.json');
const SRC = path.join(root, 'public/ludus/ludus-npc-dialogue-manager.js');

const BAD_TREE = {
  npcId: 'fixture_bad',
  npcName: 'Fixture',
  startNode: 'missing',
  nodes: [
    { id: 'a', text: 'A', branches: [
      { text: 'round', nextNodeId: 'b',
        attributeBonuses: { wisdom: 2.5, faith: 9, cunning: -1,
          erudition: 0, ethos: 3 } },
      { text: 'gated', nextNodeId: '', condition: { wisdom: 6, ethos: 99 },
        attributeBonuses: { charisma: 4.4 } },
      { text: 'two', nextNodeId: 'b',
        condition: { faith: 3, constitution: 2 },
        attributeBonuses: { dexterity: 1.5 } },
    ] },
    // Values the JS Number() reads loosely: numeric strings, null (0),
    // true (1), a one-element array, blank strings; a truthy entry that
    // is not an object is a branch with no fields, a falsy one is
    // dropped; a falsy narrative effect is the empty string.
    { id: 'b', text: 'B', branches: [
      null, 0, '', 'bare string branch',
      { text: 'strings', nextNodeId: 'c', narrativeEffect: 0,
        condition: { wisdom: '5', faith: null, charisma: '',
          dexterity: [3], erudition: 'x', cunning: ' 2 ' },
        attributeBonuses: { erudition: '2', constitution: null,
          faith: '2.5', wisdom: 'x', cunning: true, charisma: [4] } },
      { text: 'null gate', nextNodeId: 'c', condition: { faith: null },
        attributeBonuses: { wisdom: '1' } },
    ] },
    { id: 'c', text: 'C', branches: [
      { text: 'array gate', condition: { constitution: ['7'] },
        attributeBonuses: { faith: 1 } },
    ] },
    { text: 'no id', branches: [] },
  ],
};

function sandbox() {
  const pack = JSON.parse(fs.readFileSync(PACK, 'utf8'));
  pack.trees.fixture_bad = BAD_TREE;
  const store = {};
  const ctx = {
    console: { log() {}, warn() {}, error() {} },
    window: { addEventListener() {} },
    fetch: (url) => Promise.resolve(url === '/ludus/data/dialogue-trees.json'
      ? { ok: true, json: () => Promise.resolve(pack) }
      : { ok: false, status: 404, json: () => Promise.resolve(null) }),
  };
  ctx.window.localStorage = {
    getItem: (k) => (k in store ? store[k] : null),
    setItem: (k, v) => { store[k] = String(v); },
    removeItem: (k) => { delete store[k]; },
  };
  vm.createContext(ctx);
  vm.runInContext(fs.readFileSync(SRC, 'utf8'), ctx, { filename: SRC });
  return { M: ctx.window.LudusDialogueManager, ids: Object.keys(pack.trees) };
}

const ATTRS = ['wisdom', 'faith', 'dexterity', 'constitution', 'charisma',
  'cunning', 'erudition'];
const flat = (v) => Object.fromEntries(ATTRS.map((a) => [a, v]));
const PROFILES = {
  all1: flat(1),
  all4: flat(4),
  all6: flat(6),
  all8: flat(8),
  all12: flat(12),
  mixed: Object.assign(flat(2), { wisdom: 9, faith: 3, erudition: 5 }),
  // A fractional value is kept by the game when a bonus is added.
  fraction: Object.assign(flat(3), { wisdom: 6.5, faith: 4.25 }),
};
const MAX_STEPS = 12;

const plain = (o) => JSON.parse(JSON.stringify(o));

async function main() {
  const { M, ids } = sandbox();
  M.init(null);
  const trees = {};
  for (const id of ids) {
    const tree = await M.loadDialogueTree(id);
    const shape = {
      startNode: tree.startNode,
      nodes: tree.nodes.map((n) => ({ id: n.id,
        branches: n.branches.map((b) => ({ condition: b.condition,
          attributeBonuses: b.attributeBonuses, nextNodeId: b.nextNodeId })),
      })),
      profiles: {},
    };
    for (const [name, start] of Object.entries(PROFILES)) {
      const open = {};
      tree.nodes.forEach((n) => {
        open[n.id] = M.getAvailableBranches(n, start)
          .map((b) => n.branches.indexOf(b));
      });
      // A walk that takes open branch (step % open) at every node; the
      // form grows by the bonuses the module returns, as the game does.
      await M.loadDialogueTree(id);
      const form = Object.assign({}, start);
      const walk = [];
      for (let step = 0; step < MAX_STEPS; step++) {
        const node = M.getCurrentNode();
        const avail = M.getAvailableBranches(node, form)
          .map((b) => node.branches.indexOf(b));
        const locked = node.branches.map((b, i) => i)
          .filter((i) => !avail.includes(i));
        let refused = null;
        if (locked.length > 0) {
          try {
            await M.processChoice(locked[0], form);
          } catch (err) {
            refused = { index: locked[0], locked: Boolean(err.locked),
              missing: err.missing || [] };
          }
        }
        if (avail.length === 0) {
          walk.push({ node: node.id, open: avail, refused, chose: null });
          break;
        }
        const pick = avail[step % avail.length];
        const res = await M.processChoice(pick, form);
        Object.entries(res.attributeBonuses).forEach(([a, v]) => {
          form[a] = (form[a] || 0) + v;
        });
        walk.push({ node: node.id, open: avail, refused, chose: pick,
          bonuses: res.attributeBonuses, next: res.nextNodeId,
          complete: res.complete, form: Object.assign({}, form) });
        if (res.complete) {
          break;
        }
      }
      shape.profiles[name] = { start, open, walk };
    }
    trees[id] = shape;
  }
  const out = { note: 'Generated by scripts/godot/make_dialogue_fixture.js '
    + 'from public/ludus/ludus-npc-dialogue-manager.js; do not edit.',
  bad_tree: BAD_TREE, trees: plain(trees) };
  const dest = path.join(root, 'godot/tests/fixtures/dialogue.json');
  fs.writeFileSync(dest, JSON.stringify(out, null, 1) + '\n');
  console.log(`dialogue fixture: ${ids.length} trees x `
    + `${Object.keys(PROFILES).length} profiles`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
