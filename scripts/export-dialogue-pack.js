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

const pack = {
  source: 'functions/src/scripts/seedComprehensiveTestData.ts',
  trees: Object.fromEntries(trees.map((tree) => [tree.npcId, tree])),
};
fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, JSON.stringify(pack, null, 2) + '\n');
console.log(`wrote ${trees.length} trees -> ${path.relative(ROOT, OUT)}`);
