/**
 * Seed the 24 NPC dialogue trees of the chorus of 12 editors
 * (CLAUDE.md TABOO 0.37) into Firestore ludus_dialogue_trees/{npcId}.
 *
 * The same file feeds the offline pack (scripts/export-dialogue-pack.js),
 * so the browser and the database carry one text.  The chorus review
 * (fixes, dissent) stays in the source file as the record of decisions
 * and is not written to the game database.
 *
 * Run against the emulator:
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8085 npx ts-node \
 *     src/scripts/seedNpcDialogues24.ts
 */

import * as admin from 'firebase-admin';
import * as fs from 'fs';
import * as path from 'path';

const SOURCE = path.join(__dirname, '..', 'data', 'npc-dialogues-24.json');
// The people of the 12 stories walked in the headset, under the same
// contract (scripts/check_dialogues.py); seeded with the 24.
const STORY = path.join(__dirname, '..', 'data',
  'npc-dialogues-story12.json');

export function loadTrees(file: string = SOURCE): Record<string, unknown>[] {
  const trees = JSON.parse(fs.readFileSync(file, 'utf8')) as
    Record<string, unknown>[];
  return trees.map((tree) => {
    const { review: _review, decisions: _decisions, ...shipped } = tree;
    return shipped;
  });
}

export async function seedNpcDialogues24(
  db: admin.firestore.Firestore): Promise<number> {
  const trees = loadTrees().concat(fs.existsSync(STORY)
    ? loadTrees(STORY) : []);
  const batch = db.batch();
  trees.forEach((tree) => {
    batch.set(db.collection('ludus_dialogue_trees')
      .doc(String(tree.npcId)), tree);
  });
  await batch.commit();
  return trees.length;
}

if (require.main === module) {
  if (!admin.apps.length) {
    admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT
      || 'demo-ludus' });
  }
  seedNpcDialogues24(admin.firestore())
    .then((n) => console.log(`[Seed] ${n} NPC dialogue trees written`))
    .catch((e) => {
      console.error('[Seed] failed:', e);
      process.exitCode = 1;
    });
}
