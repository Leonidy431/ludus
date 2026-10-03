// Export the seeded dialogue trees as the offline content pack.
//
// The backend seeds Firestore from functions/src/scripts/
// seedComprehensiveTestData.ts.  The browser needs the same trees for a
// guest with no network (the constitution requires dialogues to work
// offline), so this script copies them instead of keeping a second,
// hand-written set that would drift from the seed.
//
// Usage: node scripts/export-dialogue-pack.js [--check]
//
// --check writes nothing: it builds the pack in memory and exits with 1
// if the shipped file differs, so CI catches a seed or a chorus tree
// edited without the pack being exported again.

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
// The people of the 12 stories walked in the headset (docs/STORY_12_
// CHARACTERS_2026-10-02.md) are added after the 24, under the same
// contract (scripts/check_dialogues.py); they replace nothing.
const STORY = path.join(ROOT, 'functions/src/data/npc-dialogues-story12.json');
if (fs.existsSync(STORY)) {
  JSON.parse(fs.readFileSync(STORY, 'utf8')).forEach((tree) => {
    if (merged[tree.npcId]) {
      throw new Error(`story tree ${tree.npcId} repeats an existing NPC`);
    }
    const { review, decisions, ...shipped } = tree;
    merged[tree.npcId] = shipped;
  });
  sources = [...sources, 'functions/src/data/npc-dialogues-story12.json'];
}
const pack = { source: sources.join(' + '), trees: merged };
const text = JSON.stringify(pack, null, 2) + '\n';
const rel = path.relative(ROOT, OUT);
if (process.argv.includes('--check')) {
  const shipped = fs.existsSync(OUT) ? fs.readFileSync(OUT, 'utf8') : '';
  if (shipped !== text) {
    console.error(`${rel} is stale: run node scripts/export-dialogue-pack.js`);
    process.exit(1);
  }
  console.log(`${rel} is current (${Object.keys(merged).length} trees)`);
} else {
  fs.mkdirSync(path.dirname(OUT), { recursive: true });
  fs.writeFileSync(OUT, text);
  console.log(`wrote ${Object.keys(merged).length} trees -> ${rel}`);
}
