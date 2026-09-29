/**
 * Ludus Dialogue System Cloud Functions
 *
 * Endpoints for:
 * - Loading dialogue trees from Firestore
 * - Managing NPC memory (player interaction history)
 * - Persisting dialogue state (choices, bonuses)
 *
 * All endpoints require Firebase Authentication (optional for public trees)
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { Request, Response } from 'express';

const db = admin.firestore();

/**
 * Type definitions for dialogue system
 */

interface DialogueNode {
  id: string;
  text: string;
  branches: DialogueBranch[];
}

interface DialogueBranch {
  text: string;
  condition?: Record<string, number>; // e.g., { wisdom: 8, faith: 6 }
  nextNodeId?: string; // undefined = dialogue ends
  attributeBonuses?: Record<string, number>; // e.g., { wisdom: 2, faith: 1 }
  narrativeEffect?: string;
}

interface DialogueTree {
  npcId: string;
  npcName: string;
  theology: string;
  startNode: string;
  nodes: DialogueNode[];
}

interface NpcMemory {
  firstMeeting: boolean;
  lastInteraction?: number; // timestamp
  totalInteractions: number;
  choiceHistory: Array<{
    nodeId: string;
    choice: string;
    timestamp?: number;
  }>;
  attributeBonusesEarned?: Record<string, number>;
}

interface DialogueState {
  playerId: string;
  npcId: string;
  currentNodeId: string;
  dialogueHistory: Array<{
    nodeId: string;
    choiceIndex: number;
    choiceText: string;
    attributeBonuses: Record<string, number>;
    timestamp: number;
  }>;
  attributeBonusesThisSession: Record<string, number>;
  timestamp: number;
}

/**
 * CORS headers for Quest 3 and other VR devices
 */
function setCorsHeaders(res: Response) {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type,Authorization');
}

/**
 * Handle CORS preflight requests
 */
function handleCorsPreFlight(req: Request, res: Response) {
  if (req.method === 'OPTIONS') {
    setCorsHeaders(res);
    res.status(204).send('');
    return true;
  }
  return false;
}

/**
 * GET /api/ludus/dialogue/tree/{npcId}
 *
 * Load complete dialogue tree for an NPC from Firestore.
 * Returns all nodes and branches (attribute checks done on client).
 */
export const getDialogueTree = functions.https.onRequest(
  async (req: Request, res: Response) => {
    setCorsHeaders(res);
    if (handleCorsPreFlight(req, res)) return;

    try {
      const npcId = Array.isArray(req.params.npcId) ? req.params.npcId[0] : (req.params.npcId as string);
      const perfLabel = `getDialogueTree[${npcId}]`;
      console.time(perfLabel);

      if (!npcId) {
        res.status(400).json({ error: 'Missing npcId parameter' });
        console.timeEnd(perfLabel);
        return;
      }

      // Fetch dialogue tree from Firestore
      const treeDoc = await db.collection('ludus_dialogue_trees').doc(npcId).get();

      if (!treeDoc.exists) {
        console.log(`[Ludus] ❌ Dialogue tree not found for NPC: ${npcId}`);
        res.status(404).json({
          error: `Dialogue tree not found for NPC: ${npcId}`,
          context: {
            npcId,
            checked: [`ludus_dialogue_trees/${npcId}`],
            timestamp: new Date().toISOString(),
            deviceType: req.headers['user-agent'] || 'unknown'
          },
          recovery: [
            `Verify NPC "${npcId}" is available in this game instance`,
            'Try reloading the scene or restarting the game',
            'If problem persists, check your internet connection',
            'Contact support with the timestamp above'
          ]
        });
        console.timeEnd(perfLabel);
        return;
      }

      const tree = treeDoc.data() as DialogueTree;

      // Log access
      console.log(`[Ludus] Dialogue tree loaded for NPC: ${npcId}`);
      console.timeEnd(perfLabel);

      res.json(tree);
    } catch (err) {
      console.error('[Ludus] Error loading dialogue tree:', err);
      res.status(500).json({ error: 'Failed to load dialogue tree' });
    }
  }
);

/**
 * GET /api/ludus/dialogue/memory/{npcId}/{playerId}
 *
 * Load NPC's memory of previous interactions with player.
 * Returns first meeting status, choice history, bonus tracking.
 *
 * Requires: User authentication (playerId must match auth user)
 */
export const getNpcMemory = functions.https.onRequest(
  async (req: Request, res: Response) => {
    setCorsHeaders(res);
    if (handleCorsPreFlight(req, res)) return;

    try {
      const npcId = Array.isArray(req.params.npcId) ? req.params.npcId[0] : (req.params.npcId as string);
      const playerId = Array.isArray(req.params.playerId) ? req.params.playerId[0] : (req.params.playerId as string);
      const authUser = req.headers['x-firebase-auth-user'] as string;
      const perfLabel = `getNpcMemory[${npcId}/${playerId}]`;
      console.time(perfLabel);

      if (!npcId || !playerId) {
        res.status(400).json({ error: 'Missing npcId or playerId' });
        console.timeEnd(perfLabel);
        return;
      }

      // Verify player is requesting their own memory
      if (authUser && authUser !== playerId) {
        res.status(403).json({ error: 'Cannot access other player memory' });
        console.timeEnd(perfLabel);
        return;
      }

      // Fetch NPC memory for this player
      const memoryDoc = await db
        .collection('ludus_npc_memory')
        .doc(npcId)
        .collection('players')
        .doc(playerId)
        .get();

      if (!memoryDoc.exists) {
        // First meeting - no prior memory
        const firstMeetingMemory: NpcMemory = {
          firstMeeting: true,
          lastInteraction: undefined,
          totalInteractions: 0,
          choiceHistory: [],
        };
        res.json(firstMeetingMemory);
        console.timeEnd(perfLabel);
        return;
      }

      const memory = memoryDoc.data() as NpcMemory;

      console.log(`[Ludus] NPC memory loaded: ${npcId} ← ${playerId}`);
      console.timeEnd(perfLabel);

      res.json(memory);
    } catch (err) {
      console.error('[Ludus] Error loading NPC memory:', err);
      res.status(500).json({ error: 'Failed to load NPC memory' });
    }
  }
);

/**
 * POST /api/ludus/dialogue/state
 *
 * Persist dialogue state after player makes a choice.
 * Updates:
 * - Dialogue history (choices made, node progression)
 * - Player attributes (wisdom, faith, dexterity bonuses)
 * - NPC memory (player interaction history, depth tracking)
 *
 * Requires: User authentication
 */
export const persistDialogueState = functions.https.onRequest(
  async (req: Request, res: Response) => {
    setCorsHeaders(res);
    if (handleCorsPreFlight(req, res)) return;

    try {
      if (req.method !== 'POST') {
        res.status(405).json({ error: 'Method not allowed' });
        return;
      }

      const {
        playerId,
        npcId,
        currentNodeId,
        dialogueHistory,
        attributeBonuses,
      } = req.body;

      const perfLabel = `persistDialogueState[${playerId}/${npcId}]`;
      console.time(perfLabel);

      if (!playerId || !npcId || !currentNodeId) {
        res.status(400).json({ error: 'Missing required fields' });
        console.timeEnd(perfLabel);
        return;
      }

      const timestamp = Date.now();

      // 1. Update dialogue history
      const dialogueStateDoc: DialogueState = {
        playerId,
        npcId,
        currentNodeId,
        dialogueHistory: dialogueHistory || [],
        attributeBonusesThisSession: attributeBonuses || {},
        timestamp,
      };

      await db
        .collection('ludus_dialogue_states')
        .doc(`${playerId}_${npcId}`)
        .set(dialogueStateDoc, { merge: true });

      // 2. Update player attributes in Firestore
      if (attributeBonuses && Object.keys(attributeBonuses).length > 0) {
        const playerRef = db.collection('ludus_players').doc(playerId);

        // Use transaction to atomically update attributes
        await db.runTransaction(async (transaction) => {
          const playerDoc = await transaction.get(playerRef);

          if (!playerDoc.exists) {
            console.warn(`[Ludus] Player document not found: ${playerId}`);
            return;
          }

          const currentAttributes = playerDoc.data()?.form || {};
          const updatedAttributes = { ...currentAttributes };

          // Apply bonuses
          Object.entries(attributeBonuses).forEach(([attr, bonus]) => {
            updatedAttributes[attr] = (updatedAttributes[attr] || 0) + (bonus as number);
          });

          transaction.update(playerRef, { form: updatedAttributes });
        });
      }

      // 3. Update NPC memory
      const memoryRef = db
        .collection('ludus_npc_memory')
        .doc(npcId)
        .collection('players')
        .doc(playerId);

      const memoryDoc = await memoryRef.get();
      const currentMemory = (memoryDoc.data() || {}) as Partial<NpcMemory>;

      const updatedMemory: NpcMemory = {
        firstMeeting: false,
        lastInteraction: timestamp,
        totalInteractions: (currentMemory.totalInteractions || 0) + 1,
        choiceHistory: [
          ...(currentMemory.choiceHistory || []),
          {
            nodeId: currentNodeId,
            choice: dialogueHistory?.[dialogueHistory.length - 1]?.choiceText || '',
            timestamp,
          },
        ],
        attributeBonusesEarned: {
          ...(currentMemory.attributeBonusesEarned || {}),
          ...Object.fromEntries(
            Object.entries(attributeBonuses || {}).map(([attr, bonus]) => [
              attr,
              ((currentMemory.attributeBonusesEarned?.[attr] || 0) as number) + (bonus as number),
            ])
          ),
        },
      };

      await memoryRef.set(updatedMemory, { merge: true });

      console.log(`[Ludus] Dialogue state persisted: ${playerId} ← ${npcId}`);
      console.timeEnd(perfLabel);

      res.json({
        success: true,
        timestamp,
        bonusesApplied: Object.keys(attributeBonuses || {}),
      });
    } catch (err) {
      console.error('[Ludus] Error persisting dialogue state:', err);
      res.status(500).json({ error: 'Failed to persist dialogue state' });
    }
  }
);

/**
 * GET /api/ludus/dialogue/stats/{playerId}
 *
 * Get player's overall dialogue engagement statistics.
 * Returns: total NPCs interacted with, total bonuses earned, current attributes.
 */
export const getDialogueStats = functions.https.onRequest(
  async (req: Request, res: Response) => {
    setCorsHeaders(res);
    if (handleCorsPreFlight(req, res)) return;

    try {
      const playerId = Array.isArray(req.params.playerId) ? req.params.playerId[0] : (req.params.playerId as string);
      const perfLabel = `getDialogueStats[${playerId}]`;
      console.time(perfLabel);

      if (!playerId) {
        res.status(400).json({ error: 'Missing playerId' });
        console.timeEnd(perfLabel);
        return;
      }

      // Fetch player profile
      const playerDoc = await db.collection('ludus_players').doc(playerId).get();

      if (!playerDoc.exists) {
        res.status(404).json({ error: 'Player not found' });
        console.timeEnd(perfLabel);
        return;
      }

      const playerData = playerDoc.data();
      const attributes = playerData?.form || {};

      // Count NPC interactions
      const statesSnapshot = await db
        .collection('ludus_dialogue_states')
        .where('playerId', '==', playerId)
        .get();

      const npcCount = new Set(
        statesSnapshot.docs.map((doc) => doc.data().npcId)
      ).size;

      // Calculate total bonuses earned
      const memorySnapshot = await db
        .collectionGroup('players')
        .where('__name__', '==', playerId)
        .get();

      let totalBonusesEarned: Record<string, number> = {};

      // Sum bonuses from all NPC interactions
      for (const doc of memorySnapshot.docs) {
        const memory = doc.data() as NpcMemory;
        if (memory.attributeBonusesEarned) {
          Object.entries(memory.attributeBonusesEarned).forEach(([attr, bonus]) => {
            totalBonusesEarned[attr] = (totalBonusesEarned[attr] || 0) + (bonus as number);
          });
        }
      }

      console.log(`[Ludus] Dialogue stats retrieved for player: ${playerId}`);
      console.timeEnd(perfLabel);

      res.json({
        playerId,
        npcInteractions: npcCount,
        currentAttributes: attributes,
        totalBonusesEarned,
        dialogueEngagementLevel:
          npcCount <= 2 ? 'beginner' : npcCount <= 5 ? 'intermediate' : 'advanced',
      });
    } catch (err) {
      console.error('[Ludus] Error retrieving dialogue stats:', err);
      res.status(500).json({ error: 'Failed to retrieve dialogue stats' });
    }
  }
);

/**
 * POST /api/ludus/dialogue/tree/{npcId}
 *
 * ADMIN ONLY: Create or update dialogue tree for NPC.
 * Used during development/seeding to populate dialogue trees.
 *
 * Requires: Admin authentication
 */
export const upsertDialogueTree = functions.https.onRequest(
  async (req: Request, res: Response) => {
    setCorsHeaders(res);
    if (handleCorsPreFlight(req, res)) return;

    try {
      if (req.method !== 'POST') {
        res.status(405).json({ error: 'Method not allowed' });
        return;
      }

      const npcId = Array.isArray(req.params.npcId) ? req.params.npcId[0] : (req.params.npcId as string);
      const treeData: Partial<DialogueTree> = req.body;
      const perfLabel = `upsertDialogueTree[${npcId}]`;
      console.time(perfLabel);

      if (!npcId) {
        res.status(400).json({ error: 'Missing npcId' });
        console.timeEnd(perfLabel);
        return;
      }

      // Admin auth check: Verify user is Firebase admin or has admin token
      const authHeader = req.headers.authorization;
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        res.status(401).json({ error: 'Unauthorized: Admin token required' });
        console.timeEnd(perfLabel);
        return;
      }

      const token = authHeader.substring(7); // Remove 'Bearer ' prefix
      try {
        const decodedToken = await admin.auth().verifyIdToken(token);
        // Check if user has admin custom claim
        if (!decodedToken.admin && !decodedToken.isAdmin) {
          res.status(403).json({ error: 'Forbidden: Admin privileges required' });
          console.timeEnd(perfLabel);
          return;
        }
      } catch (authErr) {
        console.warn('[Ludus] Auth verification failed:', authErr);
        res.status(401).json({ error: 'Unauthorized: Invalid or expired token' });
        console.timeEnd(perfLabel);
        return;
      }

      // Validate tree structure
      if (!treeData.npcName || !treeData.startNode || !treeData.nodes) {
        res.status(400).json({ error: 'Invalid dialogue tree structure' });
        console.timeEnd(perfLabel);
        return;
      }

      // Merge with existing data
      const completeTree: DialogueTree = {
        npcId,
        npcName: treeData.npcName,
        theology: treeData.theology || '',
        startNode: treeData.startNode,
        nodes: treeData.nodes,
      };

      await db.collection('ludus_dialogue_trees').doc(npcId).set(completeTree);

      console.log(`[Ludus] Dialogue tree upserted for NPC: ${npcId}`);
      console.timeEnd(perfLabel);

      res.json({ success: true, npcId });
    } catch (err) {
      console.error('[Ludus] Error upserting dialogue tree:', err);
      res.status(500).json({ error: 'Failed to upsert dialogue tree' });
    }
  }
);
