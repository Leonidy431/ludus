// Export the seeded dialogue trees as the offline content pack.
//
// The backend seeds Firestore from functions/src/scripts/
// seedComprehensiveTestData.ts.  The browser needs the same trees for a
// guest with no network (the constitution requires dialogues to work
// offline), so this script copies them instead of keeping a second,
// hand-written set that would drift from the seed.
//
// Usage: node scripts/export-dialogue-pack.js

'use strict';

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const ROOT = path.resolve(__dirname, '..');
const SEED = path.join(
  ROOT, 'functions/src/scripts/seedComprehensiveTestData.ts');
const OUT = path.join(ROOT, 'public/ludus/data/dialogue-trees.json');

const source = fs.readFileSync(SEED, 'utf8');
const start = source.indexOf('const dialogueTrees = [');
const end = source.indexOf('const testPlayers');
if (start < 0 || end < 0) {
  throw new Error('dialogueTrees block not found in the seed script');
}

// The block is a plain object literal, so it can be evaluated without a
// TypeScript compiler; the sandbox has no access to require or process.
const block = source.slice(start, end)
  .replace('const dialogueTrees =', 'result =');
const sandbox = { result: null };
vm.runInNewContext(block, sandbox, { timeout: 1000 });

const trees = sandbox.result;
if (!Array.isArray(trees) || trees.length === 0) {
  throw new Error('dialogueTrees evaluated to an empty value');
}

// The 24 trees of the chorus of 12 editors (CLAUDE.md TABOO 0.37) are the
// canonical content; they replace the seed's older trees for the same
// NPCs.  The chorus review stays in the source file and is not shipped.
const CHORUS = path.join(ROOT, 'functions/src/data/npc-dialogues-24.json');
const merged = Object.fromEntries(trees.map((tree) => [tree.npcId, tree]));
let sources = ['functions/src/scripts/seedComprehensiveTestData.ts'];
if (fs.existsSync(CHORUS)) {
  JSON.parse(fs.readFileSync(CHORUS, 'utf8')).forEach((tree) => {
    const { review, decisions, ...shipped } = tree;
    merged[tree.npcId] = shipped;
  });
  sources = ['functions/src/data/npc-dialogues-24.json', ...sources];
}
const pack = { source: sources.join(' + '), trees: merged };
fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, JSON.stringify(pack, null, 2) + '\n');
console.log(`wrote ${Object.keys(merged).length} trees -> `
  + `${path.relative(ROOT, OUT)}`);
