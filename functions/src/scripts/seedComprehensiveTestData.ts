/**
 * Comprehensive Test Data Seeding Script
 *
 * Seeds Firestore with complete test scenarios:
 * - Multiple dialogue trees (4+ NPCs)
 * - Edge case test players (extreme attributes)
 * - Error condition scenarios
 * - Performance baseline data
 *
 * Usage: npx ts-node functions/src/scripts/seedComprehensiveTestData.ts
 */

import * as admin from 'firebase-admin';
import * as fs from 'fs';
import * as path from 'path';

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: process.env.FIREBASE_PROJECT_ID || 'ludus-firestore',
  });
}

const db = admin.firestore();

/**
 * DIALOGUE TREES: 4 NPCs with varying theologies
 */
const dialogueTrees = [
  {
    npcId: 'elder_sergius',
    npcName: 'Elder Sergius',
    theology: 'Hesychasm (Contemplative Prayer)',
    startNode: 'greeting',
    nodes: [
      {
        id: 'greeting',
        text: 'Peace be with you, seeker of silence.',
        branches: [
          {
            text: 'I seek understanding through contemplation',
            condition: { wisdom: 5 },
            nextNodeId: 'contemplation_path',
            attributeBonuses: { wisdom: 2, faith: 1 },
            narrativeEffect: 'Elder nods approvingly'
          },
          {
            text: 'Teach me about prayer of the heart',
            nextNodeId: 'heart_prayer',
            attributeBonuses: { faith: 2 },
          },
          {
            text: 'I have many doubts',
            condition: { wisdom: 2 },
            nextNodeId: 'doubt_path',
            attributeBonuses: { faith: 1 },
          }
        ]
      },
      {
        id: 'contemplation_path',
        text: 'The Jesus prayer: "Lord Jesus Christ, have mercy on me." Repeat in silence.',
        branches: [
          {
            text: 'I will practice this discipline',
            nextNodeId: null,
            attributeBonuses: { wisdom: 3, constitution: 1 }
          }
        ]
      },
      {
        id: 'heart_prayer',
        text: 'The heart prayer connects intellect with spirit, body with soul.',
        branches: [
          {
            text: 'How do I begin?',
            nextNodeId: 'prayer_practice',
            attributeBonuses: { faith: 2 }
          }
        ]
      },
      {
        id: 'prayer_practice',
        text: 'Begin with 40 times daily. Morning, noon, evening. The prayer becomes your heartbeat.',
        branches: [
          {
            text: 'I accept this practice',
            nextNodeId: null,
            attributeBonuses: { faith: 3, constitution: 2 }
          }
        ]
      },
      {
        id: 'doubt_path',
        text: 'Doubt is not sin. Doubt is the beginning of wisdom.',
        branches: [
          {
            text: 'How do I move past doubt?',
            nextNodeId: null,
            attributeBonuses: { wisdom: 2, faith: 1 }
          }
        ]
      }
    ]
  },
  {
    npcId: 'theodora',
    npcName: 'Theodora',
    theology: 'Liturgical Theology (Community & Worship)',
    startNode: 'greeting',
    nodes: [
      {
        id: 'greeting',
        text: 'Welcome, brother deacon. Come, join us in the Divine Liturgy.',
        branches: [
          {
            text: 'What is the meaning of the liturgy?',
            nextNodeId: 'liturgy_meaning',
            attributeBonuses: { erudition: 1, faith: 1 }
          },
          {
            text: 'Teach me the hymns',
            nextNodeId: 'hymns',
            attributeBonuses: { charisma: 1, faith: 1 }
          },
          {
            text: 'I feel lost in ritual',
            nextNodeId: 'ritual_guidance',
            attributeBonuses: { faith: 1 }
          }
        ]
      },
      {
        id: 'liturgy_meaning',
        text: 'The Liturgy is heaven on earth. In it, we stand before the throne of God.',
        branches: [
          {
            text: 'I want to understand deeper',
            nextNodeId: null,
            attributeBonuses: { wisdom: 2, erudition: 2 }
          }
        ]
      },
      {
        id: 'hymns',
        text: 'The hymns carry theology in song. Listen to the words as you sing.',
        branches: [
          {
            text: 'I will sing with the community',
            nextNodeId: null,
            attributeBonuses: { charisma: 2, faith: 2 }
          }
        ]
      },
      {
        id: 'ritual_guidance',
        text: 'The ritual gives structure to our prayer. Let it guide you naturally.',
        branches: [
          {
            text: 'Show me the way',
            nextNodeId: null,
            attributeBonuses: { faith: 2 }
          }
        ]
      }
    ]
  },
  {
    npcId: 'abba_john',
    npcName: 'Abba John the Desert Father',
    theology: 'Ascetic Discipline (Monastic Practice)',
    startNode: 'greeting',
    nodes: [
      {
        id: 'greeting',
        text: 'Why have you come to the wilderness?',
        branches: [
          {
            text: 'To escape the world',
            nextNodeId: 'escape_path',
            attributeBonuses: { constitution: 1 }
          },
          {
            text: 'To strengthen my spirit',
            condition: { faith: 6 },
            nextNodeId: 'strength_path',
            attributeBonuses: { faith: 2, constitution: 1 }
          },
          {
            text: 'I do not know',
            nextNodeId: 'seeking_path',
            attributeBonuses: { wisdom: 1 }
          }
        ]
      },
      {
        id: 'escape_path',
        text: 'Escape is not enough. You must seek transformation.',
        branches: [
          {
            text: 'Teach me discipline',
            nextNodeId: null,
            attributeBonuses: { constitution: 2, faith: 1 }
          }
        ]
      },
      {
        id: 'strength_path',
        text: 'The wilderness refines the soul. Fast. Pray. Labor.',
        branches: [
          {
            text: 'I am ready for asceticism',
            nextNodeId: null,
            attributeBonuses: { constitution: 3, faith: 2 }
          }
        ]
      },
      {
        id: 'seeking_path',
        text: 'Seeking without knowing is the beginning of monastic life.',
        branches: [
          {
            text: 'I will seek in the silence',
            nextNodeId: null,
            attributeBonuses: { wisdom: 2, faith: 1 }
          }
        ]
      }
    ]
  },
  {
    npcId: 'sister_catherine',
    npcName: 'Sister Catherine',
    theology: 'Mystical Theology (Divine Union)',
    startNode: 'greeting',
    nodes: [
      {
        id: 'greeting',
        text: 'What does your heart seek?',
        branches: [
          {
            text: 'Union with the Divine',
            condition: { wisdom: 8, faith: 8 },
            nextNodeId: 'union_path',
            attributeBonuses: { wisdom: 2, faith: 3 }
          },
          {
            text: 'How can I know God?',
            nextNodeId: 'knowledge_path',
            attributeBonuses: { wisdom: 1, faith: 1 }
          },
          {
            text: 'The path seems impossible',
            nextNodeId: 'struggle_path',
            attributeBonuses: { faith: 1 }
          },
          {
            text: 'And when a candle burns well, whose is the credit?',
            text_ru: 'А когда свеча горит хорошо, чья это заслуга?',
            nextNodeId: 'own_light',
            attributeBonuses: { wisdom: 1 }
          }
        ]
      },
      // Pride's discernment node (CLAUDE.md TABOO 0.35 rule 13).  The
      // shipped tree of Sister Catherine is the chorus tree in
      // functions/src/data/npc-dialogues-24.json, which replaces this
      // one in the offline pack; the node is copied here word for word
      // so that the Firestore test data teaches the same sign.  In the
      // chorus tree it is reached from wax_and_flame and leads on to
      // quiet_candle; this older tree has neither, so both ways end.
      {
        id: 'own_light',
        voice: 'own',
        text: 'After a good day in the workshop there is a voice that comes softly: "See what a straight candle you poured. This was your own doing." It sounds like honest pleasure in work, so no one guards against it. But it speaks as if the wax had lit itself. The wax came from the bees, the flame from another hand, and the hands themselves were given. When I hear that voice I ask the candle: what have you that you did not receive? It never has an answer.',
        text_ru: 'После удачного дня в мастерской приходит тихий голос: «Смотри, какую ровную свечу ты отлила. Это твоё собственное дело». Он звучит как честная радость от работы, поэтому его никто не стережётся. Но говорит он так, будто воск загорелся сам. Воск дали пчёлы, огонь поднесла чужая рука, да и сами руки даны. Когда я слышу этот голос, я спрашиваю свечу: что у тебя есть, чего бы ты не получила? Ответа у неё не бывает.',
        meaning: 'Discernment cue for pride, the eighth passion: the thought that ascribes one\'s good deeds and progress to oneself ("this was your own doing"). St John Climacus calls pride a denial of God and the ascription of one\'s achievements to oneself; the remedy is humility, remembering that every good is received. The mentor teaches the sign, not a weapon: the passion is cut by recognising it and giving thanks.',
        source: 'The Ladder of Divine Ascent, step 23 (on pride); 1 Corinthians 4:7',
        branches: [
          {
            text: 'Then I will thank the hand that brought the flame.',
            text_ru: 'Тогда я поблагодарю руку, что поднесла огонь.',
            nextNodeId: null,
            attributeBonuses: { wisdom: 2 },
            narrativeEffect: 'She nods once and trims a wick with her thumbnail.'
          },
          {
            text: 'But I did pour it well.',
            text_ru: 'Но ведь я и правда хорошо её отлил.',
            nextNodeId: null,
            attributeBonuses: {},
            narrativeEffect: 'Sister Catherine sets the candle on the shelf. In the dark it is only wax.'
          }
        ]
      },
      {
        id: 'union_path',
        text: 'The divine marriage of soul and spirit. You are ready for theosis.',
        branches: [
          {
            text: 'I dedicate myself to union',
            nextNodeId: null,
            attributeBonuses: { wisdom: 3, faith: 3 }
          }
        ]
      },
      {
        id: 'knowledge_path',
        text: 'God is known through love, not intellect alone.',
        branches: [
          {
            text: 'Teach me to love as you do',
            nextNodeId: null,
            attributeBonuses: { faith: 2, charisma: 1 }
          }
        ]
      },
      {
        id: 'struggle_path',
        text: 'The way is narrow. But grace meets the struggling soul.',
        branches: [
          {
            text: 'I will persevere',
            nextNodeId: null,
            attributeBonuses: { constitution: 2, faith: 2 }
          }
        ]
      }
    ]
  }
];

/**
 * TEST PLAYERS: 20 players covering all attribute ranges and dialogue paths
 */
const testPlayers = [
  // Baseline (10 from fixtures)
  ...JSON.parse(fs.readFileSync(path.join(__dirname, '../tests/fixtures/players.json'), 'utf-8')),

  // Edge cases
  {
    playerId: 'test-edge-max-wisdom',
    name: 'Scholar Maximus',
    form: { wisdom: 20, faith: 2, dexterity: 1, constitution: 1, charisma: 1, cunning: 1, erudition: 18 },
    actions: { prayerCount: 1, fastDays: 0, meditationHours: 2 },
    goal: { currentGate: 'apophatic', enlightenmentLevel: 'expert', npcRelations: [] }
  },
  {
    playerId: 'test-edge-max-faith',
    name: 'Faithful Heart Extreme',
    form: { wisdom: 2, faith: 20, dexterity: 1, constitution: 2, charisma: 18, cunning: 1, erudition: 1 },
    actions: { prayerCount: 50, fastDays: 20, meditationHours: 40 },
    goal: { currentGate: 'mystical', enlightenmentLevel: 'saint', npcRelations: [] }
  },
  {
    playerId: 'test-edge-min-stats',
    name: 'Beginner',
    form: { wisdom: 1, faith: 1, dexterity: 1, constitution: 1, charisma: 1, cunning: 1, erudition: 1 },
    actions: { prayerCount: 0, fastDays: 0, meditationHours: 0 },
    goal: { currentGate: 'foundational', enlightenmentLevel: 'none', npcRelations: [] }
  },
  {
    playerId: 'test-edge-max-constitution',
    name: 'Ascetic Master',
    form: { wisdom: 1, faith: 5, dexterity: 1, constitution: 20, charisma: 1, cunning: 1, erudition: 1 },
    actions: { prayerCount: 60, fastDays: 30, meditationHours: 100 },
    goal: { currentGate: 'ascetic', enlightenmentLevel: 'master', npcRelations: [] }
  },
  {
    playerId: 'test-edge-high-cunning',
    name: 'Cunning Strategist',
    form: { wisdom: 5, faith: 1, dexterity: 10, constitution: 1, charisma: 8, cunning: 18, erudition: 5 },
    actions: { prayerCount: 2, fastDays: 0, meditationHours: 1 },
    goal: { currentGate: 'foundational', enlightenmentLevel: 'beginner', npcRelations: [] }
  },
  {
    playerId: 'test-edge-balanced-high',
    name: 'Perfect Balance',
    form: { wisdom: 10, faith: 10, dexterity: 10, constitution: 10, charisma: 10, cunning: 5, erudition: 10 },
    actions: { prayerCount: 30, fastDays: 10, meditationHours: 20 },
    goal: { currentGate: 'contemplative', enlightenmentLevel: 'advanced', npcRelations: [] }
  }
];

/**
 * ERROR CONDITION TEST DATA
 */
const errorTestCases = [
  {
    id: 'error_missing_npcId',
    description: 'Missing npcId parameter',
    request: { /* no npcId */ },
    expectedStatus: 400,
    expectedError: 'Missing npcId parameter'
  },
  {
    id: 'error_invalid_playerId',
    description: 'PlayerId crosses authentication boundary',
    request: { playerId: 'hacker-attempt', npcId: 'elder_sergius' },
    expectedStatus: 403,
    expectedError: 'Cannot access other player memory'
  },
  {
    id: 'error_malformed_json',
    description: 'Malformed JSON in POST body',
    request: 'not json',
    expectedStatus: 400,
    expectedError: 'Invalid JSON'
  },
  {
    id: 'error_missing_admin_auth',
    description: 'Attempt to upsert without admin token',
    request: { npcId: 'test', npcName: 'Test', startNode: 'start', nodes: [] },
    expectedStatus: 401,
    expectedError: 'Unauthorized: Admin token required'
  },
  {
    id: 'error_expired_token',
    description: 'Attempt with expired auth token',
    request: { npcId: 'test' },
    expectedStatus: 401,
    expectedError: 'Unauthorized: Invalid or expired token'
  }
];

/**
 * Main seeding function
 */
async function seedComprehensiveData() {
  console.log('[Seed] Starting comprehensive test data seeding...\n');

  try {
    // 1. Seed dialogue trees
    console.log('[Seed] 📚 Seeding dialogue trees...');
    for (const tree of dialogueTrees) {
      await db.collection('ludus_dialogue_trees').doc(tree.npcId).set(tree);
      console.log(`  ✅ ${tree.npcName} (${tree.theology})`);
    }
    console.log(`[Seed] ✓ ${dialogueTrees.length} dialogue trees seeded\n`);

    // 2. Seed test players
    console.log('[Seed] 👥 Seeding test player profiles...');
    for (const player of testPlayers) {
      await db.collection('ludus_players').doc(player.playerId).set(player);
    }
    console.log(`[Seed] ✓ ${testPlayers.length} test players seeded\n`);

    // 3. Seed initial NPC memory (first interactions)
    console.log('[Seed] 💭 Initializing NPC memory...');
    for (const player of testPlayers.slice(0, 5)) {
      for (const tree of dialogueTrees) {
        const memory = {
          firstMeeting: true,
          lastInteraction: undefined,
          totalInteractions: 0,
          choiceHistory: [],
          attributeBonusesEarned: {}
        };
        await db
          .collection('ludus_npc_memory')
          .doc(tree.npcId)
          .collection('players')
          .doc(player.playerId)
          .set(memory);
      }
    }
    console.log('[Seed] ✓ NPC memory initialized for sample players\n');

    // 4. Save error test cases as reference
    console.log('[Seed] ⚠️ Creating error test case reference...');
    await db
      .collection('ludus_test_data')
      .doc('error_cases')
      .set({ cases: errorTestCases, timestamp: Date.now() });
    console.log(`[Seed] ✓ ${errorTestCases.length} error test cases documented\n`);

    // 5. Create performance baseline document
    console.log('[Seed] ⏱️ Creating performance baseline...');
    const baseline = {
      created: new Date().toISOString(),
      dialogueTreesCount: dialogueTrees.length,
      testPlayersCount: testPlayers.length,
      targetMetrics: {
        getDialogueTree: { p50: '50ms', p95: '100ms', p99: '200ms' },
        getNpcMemory: { p50: '40ms', p95: '80ms', p99: '150ms' },
        persistDialogueState: { p50: '150ms', p95: '300ms', p99: '500ms' },
        getDialogueStats: { p50: '100ms', p95: '200ms', p99: '400ms' }
      }
    };
    await db.collection('ludus_test_data').doc('performance_baseline').set(baseline);
    console.log('[Seed] ✓ Performance baseline established\n');

    console.log('═'.repeat(60));
    console.log('✅ ALL COMPREHENSIVE TEST DATA SEEDED SUCCESSFULLY!');
    console.log('═'.repeat(60));
    console.log('\nSummary:');
    console.log(`  • Dialogue Trees: ${dialogueTrees.length}`);
    console.log(`  • Test Players: ${testPlayers.length}`);
    console.log(`  • Error Test Cases: ${errorTestCases.length}`);
    console.log(`  • NPCs with Memory: ${dialogueTrees.length} × 5 players`);
    console.log('\nReady for Phase 3 testing! 🚀\n');

    process.exit(0);
  } catch (err) {
    console.error('[Seed] ❌ Error during seeding:', err);
    process.exit(1);
  }
}

// Run seeding
seedComprehensiveData();
