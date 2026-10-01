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
import Logger from '../utils/logger';
import { getStore, refuseWriteOnMirror } from '../store/store';

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

    const startTime = Date.now();
    try {
      const npcId = Array.isArray(req.params.npcId) ? req.params.npcId[0] : (req.params.npcId as string);

      if (!npcId) {
        Logger.warn('Missing npcId parameter', { endpoint: 'getDialogueTree' });
        res.status(400).json({ error: 'Missing npcId parameter' });
        return;
      }

      // Fetch dialogue tree from Firestore
      const treeData = await getStore().get(`ludus_dialogue_trees/${npcId}`);

      if (!treeData) {
        const duration = Date.now() - startTime;
        Logger.failure('Dialogue tree not found', 'getDialogueTree', duration, 404, { npcId });
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
        return;
      }

      const tree = treeData as unknown as DialogueTree;
      const duration = Date.now() - startTime;

      Logger.success('Dialogue tree loaded', 'getDialogueTree', duration, { npcId });
      res.json(tree);
    } catch (err) {
      const duration = Date.now() - startTime;
      Logger.error('Error loading dialogue tree', err, { endpoint: 'getDialogueTree', duration });
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

    const startTime = Date.now();
    try {
      const npcId = Array.isArray(req.params.npcId) ? req.params.npcId[0] : (req.params.npcId as string);
      const playerId = Array.isArray(req.params.playerId) ? req.params.playerId[0] : (req.params.playerId as string);
      const authUser = req.headers['x-firebase-auth-user'] as string;

      if (!npcId || !playerId) {
        Logger.warn('Missing npcId or playerId', { endpoint: 'getNpcMemory' });
        res.status(400).json({ error: 'Missing npcId or playerId' });
        return;
      }

      // Verify player is requesting their own memory
      if (authUser && authUser !== playerId) {
        const duration = Date.now() - startTime;
        Logger.failure('Unauthorized memory access attempt', 'getNpcMemory', duration, 403, { npcId, playerId });
        res.status(403).json({ error: 'Cannot access other player memory' });
        return;
      }

      // Fetch NPC memory for this player
      const memoryData = await getStore()
        .get(`ludus_npc_memory/${npcId}/players/${playerId}`);

      if (!memoryData) {
        // First meeting - no prior memory
        const firstMeetingMemory: NpcMemory = {
          firstMeeting: true,
          lastInteraction: undefined,
          totalInteractions: 0,
          choiceHistory: [],
        };
        const duration = Date.now() - startTime;
        Logger.success('First meeting - no prior memory', 'getNpcMemory', duration, { npcId, playerId });
        res.json(firstMeetingMemory);
        return;
      }

      const memory = memoryData as unknown as NpcMemory;
      const duration = Date.now() - startTime;

      Logger.success('NPC memory loaded', 'getNpcMemory', duration, { npcId, playerId });
      res.json(memory);
    } catch (err) {
      const duration = Date.now() - startTime;
      Logger.error('Error loading NPC memory', err, { endpoint: 'getNpcMemory', duration });
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

    const startTime = Date.now();
    try {
      if (req.method !== 'POST') {
        res.status(405).json({ error: 'Method not allowed' });
        return;
      }

      const store = getStore();
      if (refuseWriteOnMirror(store, res)) {
        return;
      }

      const {
        playerId,
        npcId,
        currentNodeId,
        dialogueHistory,
        attributeBonuses,
      } = req.body;

      if (!playerId || !npcId || !currentNodeId) {
        Logger.warn('Missing required fields for dialogue state', { endpoint: 'persistDialogueState' });
        res.status(400).json({ error: 'Missing required fields' });
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

      await store.set(`ludus_dialogue_states/${playerId}_${npcId}`,
        { ...dialogueStateDoc }, { merge: true });

      // 2. Update player attributes in Firestore
      if (attributeBonuses && Object.keys(attributeBonuses).length > 0) {
        const playerPath = `ludus_players/${playerId}`;

        // Use transaction to atomically update attributes
        await store.transaction(async (transaction) => {
          const playerDoc = await transaction.get(playerPath);

          if (!playerDoc) {
            Logger.warn('Player document not found during attribute update', { playerId, endpoint: 'persistDialogueState' });
            return;
          }

          const currentAttributes =
            (playerDoc.form || {}) as Record<string, number>;
          const updatedAttributes = { ...currentAttributes };

          // Apply bonuses
          Object.entries(attributeBonuses).forEach(([attr, bonus]) => {
            updatedAttributes[attr] = (updatedAttributes[attr] || 0) + (bonus as number);
          });

          transaction.update(playerPath, { form: updatedAttributes });
        });
      }

      // 3. Update NPC memory
      const memoryPath = `ludus_npc_memory/${npcId}/players/${playerId}`;

      const currentMemory =
        ((await store.get(memoryPath)) || {}) as Partial<NpcMemory>;

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

      await store.set(memoryPath, { ...updatedMemory }, { merge: true });

      const duration = Date.now() - startTime;
      Logger.success('Dialogue state persisted with attribute updates', 'persistDialogueState', duration, {
        playerId,
        npcId,
      });

      res.json({
        success: true,
        timestamp,
        bonusesApplied: Object.keys(attributeBonuses || {}),
      });
    } catch (err) {
      const duration = Date.now() - startTime;
      Logger.error('Error persisting dialogue state', err, { endpoint: 'persistDialogueState', duration });
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

    const startTime = Date.now();
    try {
      const playerId = Array.isArray(req.params.playerId) ? req.params.playerId[0] : (req.params.playerId as string);

      if (!playerId) {
        Logger.warn('Missing playerId', { endpoint: 'getDialogueStats' });
        res.status(400).json({ error: 'Missing playerId' });
        return;
      }

      // Fetch player profile
      const store = getStore();
      const playerData = await store.get(`ludus_players/${playerId}`);

      if (!playerData) {
        const duration = Date.now() - startTime;
        Logger.failure('Player not found', 'getDialogueStats', duration, 404, { playerId });
        res.status(404).json({ error: 'Player not found' });
        return;
      }

      const attributes = playerData.form || {};

      // Count NPC interactions
      const states = await store.query('ludus_dialogue_states',
        { where: { field: 'playerId', value: playerId } });

      const npcIds = Array.from(new Set(
        states.map((doc) => doc.data.npcId as string)
      ));
      const npcCount = npcIds.length;

      // Calculate total bonuses earned.  The memory documents are read
      // by their exact path, one per NPC the player spoke with.  The
      // earlier collectionGroup('players').where('__name__', '==', id)
      // is rejected by Firestore (a collection-group id filter needs a
      // full document path), so this endpoint always answered 500.
      // persistDialogueState writes the state and the memory together,
      // so the NPC list from the states is the complete set.
      const memories = await Promise.all(npcIds
        .filter((id) => typeof id === 'string' && id.length > 0)
        .map((id) => store.get(`ludus_npc_memory/${id}/players/${playerId}`)));

      const totalBonusesEarned: Record<string, number> = {};

      // Sum bonuses from all NPC interactions
      for (const data of memories) {
        if (!data) {
          continue;
        }
        const memory = data as unknown as NpcMemory;
        if (memory.attributeBonusesEarned) {
          Object.entries(memory.attributeBonusesEarned).forEach(([attr, bonus]) => {
            totalBonusesEarned[attr] = (totalBonusesEarned[attr] || 0) + (bonus as number);
          });
        }
      }

      const duration = Date.now() - startTime;
      Logger.success(`Dialogue stats retrieved (${npcCount} NPCs)`, 'getDialogueStats', duration, { playerId });

      res.json({
        playerId,
        npcInteractions: npcCount,
        currentAttributes: attributes,
        totalBonusesEarned,
        dialogueEngagementLevel:
          npcCount <= 2 ? 'beginner' : npcCount <= 5 ? 'intermediate' : 'advanced',
      });
    } catch (err) {
      const duration = Date.now() - startTime;
      Logger.error('Error retrieving dialogue stats', err, { endpoint: 'getDialogueStats', duration });
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

    const startTime = Date.now();
    try {
      if (req.method !== 'POST') {
        res.status(405).json({ error: 'Method not allowed' });
        return;
      }

      const store = getStore();
      if (refuseWriteOnMirror(store, res)) {
        return;
      }

      const npcId = Array.isArray(req.params.npcId) ? req.params.npcId[0] : (req.params.npcId as string);
      const treeData: Partial<DialogueTree> = req.body;

      if (!npcId) {
        Logger.warn('Missing npcId for upsert', { endpoint: 'upsertDialogueTree' });
        res.status(400).json({ error: 'Missing npcId' });
        return;
      }

      // Admin auth check: Verify user is Firebase admin or has admin token
      const authHeader = req.headers.authorization;
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        const duration = Date.now() - startTime;
        Logger.failure('Missing admin token', 'upsertDialogueTree', duration, 401, { npcId });
        res.status(401).json({ error: 'Unauthorized: Admin token required' });
        return;
      }

      const token = authHeader.substring(7); // Remove 'Bearer ' prefix
      try {
        const decodedToken = await admin.auth().verifyIdToken(token);
        // Check if user has admin custom claim
        if (!decodedToken.admin && !decodedToken.isAdmin) {
          const duration = Date.now() - startTime;
          Logger.failure('Insufficient privileges', 'upsertDialogueTree', duration, 403, { npcId });
          res.status(403).json({ error: 'Forbidden: Admin privileges required' });
          return;
        }
      } catch (authErr) {
        const duration = Date.now() - startTime;
        Logger.warn('Auth verification failed', { npcId, endpoint: 'upsertDialogueTree' });
        res.status(401).json({ error: 'Unauthorized: Invalid or expired token' });
        return;
      }

      // Validate tree structure
      if (!treeData.npcName || !treeData.startNode || !treeData.nodes) {
        Logger.warn('Invalid dialogue tree structure', { npcId, endpoint: 'upsertDialogueTree' });
        res.status(400).json({ error: 'Invalid dialogue tree structure' });
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

      await store.set(`ludus_dialogue_trees/${npcId}`, { ...completeTree });

      const duration = Date.now() - startTime;
      Logger.success(`Dialogue tree upserted (${treeData.nodes?.length || 0} nodes)`, 'upsertDialogueTree', duration, {
        npcId,
      });

      res.json({ success: true, npcId });
    } catch (err) {
      const duration = Date.now() - startTime;
      Logger.error('Error upserting dialogue tree', err, { endpoint: 'upsertDialogueTree', duration });
      res.status(500).json({ error: 'Failed to upsert dialogue tree' });
    }
  }
);
