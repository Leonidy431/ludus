/**
 * Ludus NPC Dialogue Manager
 *
 * Manages dialogue trees, branching logic, and NPC interactions.
 * Loads dialogue state from Firestore, handles player choices,
 * updates attributes, and maintains NPC memory across sessions.
 */

'use strict';

window.LudusDialogueManager = (function () {
  const DIALOGUE_API = '/api/ludus/dialogue';

  let state = {
    currentDialogue: null,
    currentNodeId: null,
    npcId: null,
    playerId: null,
    dialogueHistory: [],
    npcMemory: {},
    initialized: false,
  };

  // ── NPC Profiles (indexed from ludus/docs/NPC_DIALOGUE_SYSTEM.md) ──────
  const NPC_PROFILES = {
    elder_sergius: {
      name: 'Elder Sergius',
      role: 'Hesychast Mentor',
      theology: 'Apophatic Prayer',
      attributes: { wisdom: 14, faith: 15, erudition: 12 },
      voiceProfile: 'Deep, measured, with pauses for reflection',
      audioTheme: 'desert-bell-theme',
    },
    theodora: {
      name: 'Theodora',
      role: 'Desert Mother',
      theology: 'Ascetic Practice',
      attributes: { dexterity: 13, constitution: 14, faith: 13 },
      voiceProfile: 'Gentle, warm, encouraging',
      audioTheme: 'monastery-theme',
    },
    isaias: {
      name: 'Isaias',
      role: 'Scribe of Wisdom',
      theology: 'Cataphatic Teaching',
      attributes: { erudition: 15, wisdom: 13, intelligence: 14 },
      voiceProfile: 'Articulate, scholarly, precise',
      audioTheme: 'library-theme',
    },
    abbot_moses: {
      name: 'Abbot Moses',
      role: 'Desert Father',
      theology: 'Forgiveness & Repentance',
      attributes: { wisdom: 13, charisma: 12, faith: 14 },
      voiceProfile: 'Calm, forgiving, contemplative',
      audioTheme: 'fire-theme',
    },
    sister_catherine: {
      name: 'Sister Catherine',
      role: 'Spiritual Director',
      theology: 'Theosis & Deification',
      attributes: { wisdom: 14, charisma: 13, faith: 14 },
      voiceProfile: 'Clear, guide-like, uplifting',
      audioTheme: 'choir-theme',
    },
  };

  // ── Dialogue Node Structure ─────────────────────────────────────────────
  // Each dialogue node has:
  // {
  //   id: 'node_id',
  //   text: 'Dialogue text spoken by NPC',
  //   branches: [
  //     {
  //       text: 'Player choice',
  //       condition: { wisdom: 8, faith: 6 },  // Optional: required attributes
  //       nextNodeId: 'next_node_id',
  //       attributeBonuses: { wisdom: 2, faith: 1 },
  //       narrativeEffect: 'description of what happens'
  //     }
  //   ]
  // }

  /**
   * Load dialogue tree for given NPC from Firestore
   */
  async function loadDialogueTree(npcId) {
    try {
      const response = await fetch(`${DIALOGUE_API}/tree/${npcId}`);
      if (!response.ok) throw new Error(`HTTP ${response.status}`);

      const dialogueTree = await response.json();
      state.npcId = npcId;
      state.currentNodeId = dialogueTree.startNode || 'node_1';

      // Load NPC memory for this player
      await loadNpcMemory(npcId);

      state.initialized = true;
      return dialogueTree;
    } catch (err) {
      console.error(`[Ludus] Failed to load dialogue tree for ${npcId}:`, err);
      throw err;
    }
  }

  /**
   * Load NPC's memory of previous interactions with player
   */
  async function loadNpcMemory(npcId) {
    try {
      const playerId = state.playerId;
      const response = await fetch(`${DIALOGUE_API}/memory/${npcId}/${playerId}`);
      if (!response.ok) return; // No prior memory

      state.npcMemory = await response.json();
      console.log(`[Ludus] Loaded NPC memory for ${npcId}:`, state.npcMemory);
    } catch (err) {
      console.warn(`[Ludus] No prior NPC memory (first meeting):`, err);
      state.npcMemory = { firstMeeting: true };
    }
  }

  /**
   * Get current dialogue node
   */
  function getCurrentNode(dialogueTree) {
    if (!dialogueTree.nodes) return null;
    return dialogueTree.nodes.find(n => n.id === state.currentNodeId);
  }

  /**
   * Check if player meets branch condition
   * condition: { wisdom: 8, faith: 6 } means wisdom >= 8 AND faith >= 6
   */
  function checkCondition(condition, playerAttributes) {
    if (!condition) return true; // No condition = always available

    return Object.entries(condition).every(([attr, required]) => {
      return (playerAttributes[attr] || 0) >= required;
    });
  }

  /**
   * Get available branches for current node based on player attributes
   */
  function getAvailableBranches(node, playerAttributes) {
    if (!node || !node.branches) return [];

    return node.branches.filter(branch =>
      checkCondition(branch.condition, playerAttributes)
    );
  }

  /**
   * Process player choice:
   * 1. Validate choice is available
   * 2. Apply attribute bonuses
   * 3. Record choice in dialogue history
   * 4. Move to next node
   * 5. Update NPC memory
   * 6. Send to Firestore for persistence
   */
  async function processChoice(branchIndex, playerAttributes) {
    const currentNode = state.currentDialogue?.nodes?.find(
      n => n.id === state.currentNodeId
    );

    if (!currentNode || !currentNode.branches) {
      throw new Error('No branches available');
    }

    const availableBranches = getAvailableBranches(currentNode, playerAttributes);
    const branch = availableBranches[branchIndex];

    if (!branch) {
      throw new Error(`Branch index ${branchIndex} not available`);
    }

    // Record choice
    state.dialogueHistory.push({
      nodeId: state.currentNodeId,
      choiceIndex: branchIndex,
      choiceText: branch.text,
      timestamp: Date.now(),
      attributeBonuses: branch.attributeBonuses || {},
    });

    // Update NPC memory
    state.npcMemory.lastInteraction = Date.now();
    state.npcMemory.totalInteractions = (state.npcMemory.totalInteractions || 0) + 1;
    state.npcMemory.choiceHistory = state.npcMemory.choiceHistory || [];
    state.npcMemory.choiceHistory.push({
      nodeId: state.currentNodeId,
      choice: branch.text,
    });

    // Move to next node
    const nextNodeId = branch.nextNodeId;
    if (!nextNodeId) {
      // Dialogue end
      console.log('[Ludus] Dialogue complete');
      return {
        complete: true,
        attributeBonuses: branch.attributeBonuses || {},
        narrativeEffect: branch.narrativeEffect || '',
      };
    }

    state.currentNodeId = nextNodeId;

    // Persist to Firestore
    await persistDialogueState(playerAttributes, branch.attributeBonuses);

    return {
      complete: false,
      nextNodeId: nextNodeId,
      attributeBonuses: branch.attributeBonuses || {},
      narrativeEffect: branch.narrativeEffect || '',
    };
  }

  /**
   * Persist dialogue state to Firestore
   */
  async function persistDialogueState(playerAttributes, attributeBonuses) {
    try {
      const payload = {
        playerId: state.playerId,
        npcId: state.npcId,
        currentNodeId: state.currentNodeId,
        dialogueHistory: state.dialogueHistory,
        npcMemory: state.npcMemory,
        attributeBonuses: attributeBonuses,
        timestamp: Date.now(),
      };

      const response = await fetch(`${DIALOGUE_API}/state`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }

      console.log('[Ludus] Dialogue state persisted');
    } catch (err) {
      console.error('[Ludus] Failed to persist dialogue state:', err);
      // Don't throw; allow offline play
    }
  }

  /**
   * Format dialogue node for UI display
   */
  function formatNodeForUI(node, playerAttributes) {
    if (!node) return null;

    const availableBranches = getAvailableBranches(node, playerAttributes);

    return {
      nodeId: node.id,
      npcName: NPC_PROFILES[state.npcId]?.name || 'NPC',
      text: node.text,
      branches: availableBranches.map((branch, idx) => ({
        index: idx,
        text: branch.text,
        locked: !checkCondition(branch.condition, playerAttributes),
        requiredAttributes: branch.condition || {},
        bonuses: branch.attributeBonuses || {},
      })),
    };
  }

  /**
   * Initialize dialogue manager with player ID
   */
  function init(playerId) {
    state.playerId = playerId;
    state.initialized = true;
    console.log('[Ludus Dialogue] Initialized for player:', playerId);
  }

  /**
   * Get NPC profile by ID
   */
  function getNpcProfile(npcId) {
    return NPC_PROFILES[npcId] || null;
  }

  /**
   * Get dialogue history
   */
  function getDialogueHistory() {
    return state.dialogueHistory;
  }

  /**
   * Get NPC memory
   */
  function getNpcMemory() {
    return state.npcMemory;
  }

  /**
   * Reset dialogue state (for testing or new dialogue)
   */
  function reset() {
    state = {
      currentDialogue: null,
      currentNodeId: null,
      npcId: null,
      playerId: state.playerId,
      dialogueHistory: [],
      npcMemory: {},
      initialized: state.initialized,
    };
  }

  // ── Public API ──────────────────────────────────────────────────────────
  return {
    init,
    loadDialogueTree,
    getCurrentNode,
    getAvailableBranches,
    processChoice,
    formatNodeForUI,
    getNpcProfile,
    getDialogueHistory,
    getNpcMemory,
    reset,
    NPC_PROFILES,
  };
})();

console.log('[Ludus] NPC Dialogue Manager loaded');
