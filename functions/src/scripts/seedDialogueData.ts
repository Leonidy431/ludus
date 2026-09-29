/**
 * Seed Dialogue Data Script
 *
 * Populates Firestore with NPC dialogue trees, memories, and state.
 * Run locally with: npx ts-node functions/src/scripts/seedDialogueData.ts
 *
 * Or call via Cloud Function (admin-only):
 * curl -X POST https://us-central1-ludus.cloudfunctions.net/seedDialogueData
 */

import * as admin from 'firebase-admin';

// Initialize Firebase Admin SDK (use service account when running locally)
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: process.env.FIREBASE_PROJECT_ID || 'ludus-firestore',
  });
}

const db = admin.firestore();

/**
 * Dialogue tree for Elder Sergius (First Meeting)
 */
const ELDER_SERGIUS_FIRST_MEETING = {
  npcId: 'elder_sergius',
  npcName: 'Elder Sergius',
  theology: 'Apophatic Prayer & Hesychasm',
  startNode: 'sergius_001',
  nodes: [
    {
      id: 'sergius_001',
      text: `"Welcome, seeker. The desert has long taught that wisdom begins in silence.
             Many come seeking answers. Few seek the questions themselves."`,
      branches: [
        {
          text: 'Teach me the desert\'s secrets',
          condition: { wisdom: 8 },
          nextNodeId: 'sergius_002',
          attributeBonuses: { wisdom: 2 },
          narrativeEffect: 'Sergius nods, recognizing your readiness.',
        },
        {
          text: 'Why silence over words?',
          nextNodeId: 'sergius_003',
          attributeBonuses: { faith: 1, wisdom: 1 },
          narrativeEffect: 'Sergius smiles at your philosophical interest.',
        },
        {
          text: 'I seek a quick answer',
          nextNodeId: 'sergius_004',
          attributeBonuses: { faith: 1 },
          narrativeEffect: 'Sergius chuckles gently, teaching through patience.',
        },
      ],
    },
    {
      id: 'sergius_002',
      text: `"Good. You carry the mark of one who has suffered questions without answers.
             This is the beginning of wisdom—apophatic knowledge, unknowing through divine darkness."`,
      branches: [
        {
          text: 'How do I embrace this unknowing?',
          nextNodeId: 'sergius_005',
          attributeBonuses: { wisdom: 3, faith: 2 },
          narrativeEffect: 'You feel your understanding deepen.',
        },
        {
          text: 'This is too mysterious for me',
          nextNodeId: 'sergius_006',
          attributeBonuses: { faith: 1 },
          narrativeEffect: 'Sergius accepts your current path.',
        },
      ],
    },
    {
      id: 'sergius_003',
      text: `"Ah, you ask the right question. Words can point, but they cannot reach.
             Silence is the language of the soul speaking to the Divine—cataphatic knowledge fails where apophatic begins."`,
      branches: [
        {
          text: 'I want to learn this path',
          nextNodeId: 'sergius_002',
          attributeBonuses: { wisdom: 1, faith: 1 },
          narrativeEffect: 'You redirect toward deeper teaching.',
        },
        {
          text: 'I prefer action to contemplation',
          nextNodeId: 'sergius_004',
          attributeBonuses: { dexterity: 1 },
          narrativeEffect: 'Sergius understands your temperament.',
        },
      ],
    },
    {
      id: 'sergius_004',
      text: `"Patience, friend. The desert does not rush. Here, we measure time by prayer, not by goals.
             Perhaps you will learn that the quickest path is the longest—through surrendering the rush itself."`,
      branches: [
        {
          text: 'I will try patience',
          nextNodeId: 'sergius_003',
          attributeBonuses: { constitution: 1, faith: 1 },
          narrativeEffect: 'You commit to learning.',
        },
        {
          text: 'I have other duties',
          nextNodeId: null, // Dialogue ends
          attributeBonuses: {},
          narrativeEffect: 'Sergius blesses you in parting.',
        },
      ],
    },
    {
      id: 'sergius_005',
      text: `"Through hesychasm—the prayer of the heart. Repeat the Jesus Prayer until it becomes your breath itself.
             'Lord Jesus Christ, Son of God, have mercy on me, a sinner.' Let this rhythm guide you beyond thought."`,
      branches: [
        {
          text: 'I will practice this daily',
          nextNodeId: null,
          attributeBonuses: { wisdom: 2, faith: 2, constitution: 1 },
          narrativeEffect: 'Sergius gives you a small prayer rope. Your training begins.',
        },
      ],
    },
    {
      id: 'sergius_006',
      text: `"Then perhaps your path lies elsewhere. But know this—the door is always open.
             When the questions become too heavy to carry alone, return. The desert will be waiting."`,
      branches: [
        {
          text: 'Thank you, Elder',
          nextNodeId: null,
          attributeBonuses: {},
          narrativeEffect: 'You part respectfully.',
        },
      ],
    },
  ],
};

/**
 * Dialogue tree for Theodora (Desert Mother - Ascetic Practice)
 */
const THEODORA_ASCETIC_PATH = {
  npcId: 'theodora',
  npcName: 'Theodora',
  theology: 'Ascetic Practice & Theosis',
  startNode: 'theodora_001',
  nodes: [
    {
      id: 'theodora_001',
      text: `"You come seeking the path of the body? Good. Many forget that the flesh must be
             trained as carefully as the spirit. I teach through practice, not words."`,
      branches: [
        {
          text: 'Teach me fasting and discipline',
          nextNodeId: 'theodora_002',
          attributeBonuses: { constitution: 2 },
          narrativeEffect: 'Theodora nods, approving your directness.',
        },
        {
          text: 'What is the point of asceticism?',
          nextNodeId: 'theodora_003',
          attributeBonuses: { wisdom: 1, faith: 1 },
          narrativeEffect: 'Theodora appreciates your inquiry.',
        },
        {
          text: 'I prefer gentleness over harsh discipline',
          nextNodeId: 'theodora_004',
          attributeBonuses: { charisma: 1 },
          narrativeEffect: 'Theodora listens without judgment.',
        },
      ],
    },
    {
      id: 'theodora_002',
      text: `"Begin with bread and water three days weekly. Then extend. Let hunger teach you
             what the belly blinds us to. The body becomes a school of the soul."`,
      branches: [
        {
          text: 'I accept this challenge',
          nextNodeId: null,
          attributeBonuses: { constitution: 3, faith: 1 },
          narrativeEffect: 'Theodora gives you food rationing instructions.',
        },
      ],
    },
    {
      id: 'theodora_003',
      text: `"Theosis—deification. Through discipline, the body becomes transparent to divine light.
             It is not punishment; it is preparation. As gold is purified by fire, so is the soul by asceticism."`,
      branches: [
        {
          text: 'I understand now',
          nextNodeId: 'theodora_002',
          attributeBonuses: { wisdom: 2, faith: 2 },
          narrativeEffect: 'The teaching settles in your heart.',
        },
      ],
    },
    {
      id: 'theodora_004',
      text: `"Gentleness has its place. But know—true compassion sometimes demands harshness.
             A surgeon's knife cuts to heal. Let your body learn this balance."`,
      branches: [
        {
          text: 'I will find my own measure',
          nextNodeId: null,
          attributeBonuses: { wisdom: 1, constitution: 1, faith: 1 },
          narrativeEffect: 'Theodora respects your wisdom in finding balance.',
        },
      ],
    },
  ],
};

/**
 * Seed all dialogue trees to Firestore
 */
async function seedDialogueTrees() {
  try {
    console.log('[Seed] Starting dialogue tree population...');

    // Seed Elder Sergius
    await db
      .collection('ludus_dialogue_trees')
      .doc('elder_sergius')
      .set(ELDER_SERGIUS_FIRST_MEETING);
    console.log('[Seed] ✅ Elder Sergius dialogue tree created');

    // Seed Theodora
    await db
      .collection('ludus_dialogue_trees')
      .doc('theodora')
      .set(THEODORA_ASCETIC_PATH);
    console.log('[Seed] ✅ Theodora dialogue tree created');

    // Seed initial NPC memory (empty, will be populated by players)
    const npcIds = ['elder_sergius', 'theodora', 'isaias', 'abbot_moses', 'sister_catherine'];

    for (const npcId of npcIds) {
      await db.collection('ludus_npc_memory').doc(npcId).set({
        npcId,
        createdAt: new Date(),
        totalInteractions: 0,
      });
      console.log(`[Seed] ✅ NPC memory document created for ${npcId}`);
    }

    console.log('[Seed] ✅ All dialogue trees seeded successfully!');
    console.log('[Seed] Total: 2 dialogue trees, 5 NPC memory documents');
  } catch (err) {
    console.error('[Seed] Error seeding dialogue data:', err);
    throw err;
  }
}

/**
 * Run seed (if executed directly)
 */
if (require.main === module) {
  seedDialogueTrees()
    .then(() => {
      console.log('[Seed] Seed complete. Exiting...');
      process.exit(0);
    })
    .catch((err) => {
      console.error('[Seed] Fatal error:', err);
      process.exit(1);
    });
}

export { seedDialogueTrees };
