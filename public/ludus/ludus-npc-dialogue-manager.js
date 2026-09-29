/**
 * Ludus NPC Dialogue Manager
 *
 * Manages dialogue trees, branching logic, and NPC interactions.
 * Loads dialogue trees and NPC memory from the Cloud Functions API for
 * signed-in players and from the bundled pack for guests (who have no
 * backend), checks the player's FORM (attributes) against branch
 * conditions,
 * records choices and keeps NPC memory across sessions.
 *
 * Demiurgic Causality: FORM (attributes) gates which branches are open,
 * the chosen branch is the ACTION, and its attribute bonuses are the
 * GOAL (teaching).  Nothing here is random: every bonus comes from the
 * tree data and is the direct consequence of a choice.
 */

'use strict';

window.LudusDialogueManager = (function () {
  // These must match the routes exported in functions/src/index.ts
  // (tree, memory, state, stats under /api/ludus/dialogue).
  const DIALOGUE_API = '/api/ludus/dialogue';
  const BUNDLED_TREES_URL = '/ludus/data/dialogue-trees.json';

  // The constitution fixes exactly seven attributes.  Conditions and
  // bonuses that name anything else are dropped, so a typo in seeded
  // data cannot invent an eighth attribute on the client.
  const ATTRIBUTES = Object.freeze([
    'wisdom',
    'faith',
    'dexterity',
    'constitution',
    'charisma',
    'cunning',
    'erudition',
  ]);

  // The constitution says one dialogue choice grants +1 to +5 per
  // attribute; larger values in the data are clamped rather than
  // trusted, which keeps progression bounded even with bad seed data.
  const MAX_BONUS_PER_CHOICE = 5;

  // Storage keys for offline play.  Trees are cached after every
  // successful load and unsent state is queued until the network is
  // back, so a headset that loses Wi-Fi mid-conversation keeps going.
  const TREE_CACHE_PREFIX = 'ludus.dialogue.tree.';
  const PENDING_KEY = 'ludus.dialogue.pending';
  const PENDING_LIMIT = 50;

  let state = createEmptyState(null, null);

  // An optional async function returning a Firebase ID token.  The
  // backend requires authentication for memory and state, so the game
  // module can pass one to init() once the player is signed in.
  let getAuthToken = null;
  let flushing = null;

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
      // The spec gives Isaias a Faith and Charisma focus; the former
      // "intelligence" key was not one of the seven attributes.
      attributes: { erudition: 15, wisdom: 13, charisma: 14 },
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
  // The shape matches DialogueTree in functions/src/api/ludus-dialogue.ts:
  // {
  //   npcId, npcName, theology, startNode,
  //   nodes: [{
  //     id: 'node_id',
  //     text: 'Dialogue text spoken by NPC',
  //     branches: [{
  //       text: 'Player choice',
  //       condition: { wisdom: 8, faith: 6 },  // Optional minimums.
  //       nextNodeId: 'next_node_id',           // Absent = dialogue ends.
  //       attributeBonuses: { wisdom: 2, faith: 1 },
  //       narrativeEffect: 'description of what happens'
  //     }]
  //   }]
  // }

  function createEmptyState(playerId, initialized) {
    return {
      currentDialogue: null,
      currentNodeId: null,
      npcId: null,
      playerId: playerId,
      dialogueHistory: [],
      npcMemory: {},
      initialized: Boolean(initialized),
      processing: false,
      offline: false,
    };
  }

  // ── Storage helpers ─────────────────────────────────────────────────────
  // Every access is wrapped because storage throws in private windows
  // and in some embedded browsers; losing the cache must never break
  // the conversation itself.
  function storageGet(key) {
    try {
      const raw = window.localStorage.getItem(key);
      return raw ? JSON.parse(raw) : null;
    } catch (err) {
      return null;
    }
  }

  function storageSet(key, value) {
    try {
      window.localStorage.setItem(key, JSON.stringify(value));
      return true;
    } catch (err) {
      return false;
    }
  }

  // ── Sanitising data from the network ────────────────────────────────────
  // Keep only the seven attributes and finite numbers, so conditions
  // and bonuses are always well-formed for the checks below.
  function sanitiseAttributeMap(map, clampBonus) {
    const clean = {};
    if (!map || typeof map !== 'object') {
      return clean;
    }
    ATTRIBUTES.forEach((attr) => {
      const value = Number(map[attr]);
      if (!Number.isFinite(value)) {
        return;
      }
      if (clampBonus) {
        const bonus = Math.min(MAX_BONUS_PER_CHOICE, Math.round(value));
        if (bonus > 0) {
          clean[attr] = bonus;
        }
      } else {
        clean[attr] = value;
      }
    });
    return clean;
  }

  // Normalise a tree so the rest of the module can rely on its shape.
  // Returns null when the payload is not a usable dialogue tree.
  function normaliseTree(raw, npcId) {
    if (!raw || !Array.isArray(raw.nodes) || raw.nodes.length === 0) {
      return null;
    }
    const nodes = raw.nodes
      .filter((node) => node && typeof node.id === 'string')
      .map((node) => ({
        id: node.id,
        text: String(node.text == null ? '' : node.text),
        branches: (Array.isArray(node.branches) ? node.branches : [])
          .filter(Boolean)
          .map((branch) => ({
            text: String(branch.text == null ? '' : branch.text),
            condition: sanitiseAttributeMap(branch.condition, false),
            nextNodeId: typeof branch.nextNodeId === 'string' &&
              branch.nextNodeId ? branch.nextNodeId : null,
            attributeBonuses: sanitiseAttributeMap(
              branch.attributeBonuses, true),
            narrativeEffect: String(branch.narrativeEffect || ''),
          })),
      }));
    if (nodes.length === 0) {
      return null;
    }
    const startNode = nodes.some((n) => n.id === raw.startNode) ?
      raw.startNode : nodes[0].id;
    return {
      npcId: typeof raw.npcId === 'string' ? raw.npcId : npcId,
      npcName: typeof raw.npcName === 'string' ? raw.npcName : '',
      theology: typeof raw.theology === 'string' ? raw.theology : '',
      startNode: startNode,
      nodes: nodes,
    };
  }

  async function buildHeaders(extra) {
    const headers = Object.assign({}, extra || {});
    if (typeof getAuthToken === 'function') {
      try {
        const token = await getAuthToken();
        if (token) {
          headers.Authorization = 'Bearer ' + token;
        }
      } catch (err) {
        // A token failure falls back to an anonymous request; the
        // backend decides whether that is allowed.
        console.warn('[Ludus Dialogue] Auth token unavailable:', err);
      }
    }
    return headers;
  }

  // The pack is fetched once per page and shared by all NPCs.  It is a
  // static file, so the service worker can serve it offline as well.
  let bundledPack = null;

  async function loadBundledTree(npcId) {
    try {
      if (!bundledPack) {
        bundledPack = fetch(BUNDLED_TREES_URL).then((response) => {
          if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
          }
          return response.json();
        });
      }
      const pack = await bundledPack;
      return (pack && pack.trees && pack.trees[npcId]) || null;
    } catch (err) {
      // Allow a later retry instead of caching the failure forever.
      bundledPack = null;
      console.warn('[Ludus] Bundled dialogue pack unavailable:',
        err.message);
      return null;
    }
  }

  // Local sources only: the bundled pack first, then the tree cached
  // by an earlier online session.  The pack is the reviewed content of
  // this build, so it wins over a cache that may be older.
  async function loadLocalTree(npcId) {
    const bundled = normaliseTree(await loadBundledTree(npcId), npcId);
    if (bundled) {
      return bundled;
    }
    return normaliseTree(storageGet(TREE_CACHE_PREFIX + npcId), npcId);
  }

  // Signed-in players ask the API first, so they receive trees seeded
  // after this build shipped; the offline cache and the bundled pack
  // keep the conversation going when the network drops.
  async function loadRemoteTree(npcId) {
    const cacheKey = TREE_CACHE_PREFIX + npcId;
    try {
      const url = `${DIALOGUE_API}/tree/${encodeURIComponent(npcId)}`;
      const response = await fetch(url, { headers: await buildHeaders() });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      const tree = normaliseTree(await response.json(), npcId);
      if (!tree) {
        throw new Error('Malformed dialogue tree');
      }
      storageSet(cacheKey, tree);
      return { tree: tree, offline: false, error: null };
    } catch (err) {
      let tree = normaliseTree(storageGet(cacheKey), npcId);
      if (!tree) {
        tree = normaliseTree(await loadBundledTree(npcId), npcId);
      }
      if (tree) {
        console.warn(`[Ludus] Using cached dialogue tree for ${npcId}`);
      }
      return { tree: tree, offline: Boolean(tree), error: err };
    }
  }

  /**
   * Load the dialogue tree for the given NPC.
   *
   * A guest (init() with no playerId, which is how the game starts a
   * conversation in guest or offline mode or when Firebase is not
   * configured) has no backend to ask, so the bundled pack is used
   * directly and no request is sent: asking the API first only put a
   * 404 in the console of every guest session.  A signed-in player
   * tries the API first, then the offline cache and the pack.  Throws
   * only when no source has a usable tree; the error carries
   * ``offline = true`` so the UI can explain why.
   */
  async function loadDialogueTree(npcId) {
    if (typeof npcId !== 'string' || !npcId) {
      throw new Error('npcId is required');
    }
    let tree = null;
    let fromCache = false;
    let cause = null;

    if (state.playerId) {
      const result = await loadRemoteTree(npcId);
      tree = result.tree;
      fromCache = result.offline;
      cause = result.error;
    } else {
      // Guest play is local by design, not a lost connection, so the
      // "will sync when the headset reconnects" notice stays hidden:
      // a guest's progress lives on the device and never syncs.
      tree = await loadLocalTree(npcId);
      cause = tree ? null : new Error('No bundled dialogue tree');
    }

    if (!tree) {
      console.error(
        `[Ludus] Failed to load dialogue tree for ${npcId}:`, cause);
      const failure = new Error(
        `Dialogue with ${npcId} is unavailable offline`);
      failure.offline = true;
      failure.cause = cause;
      throw failure;
    }

    // A new conversation starts from a clean slate; keeping the old
    // history would mix one NPC's memory into another's.
    state = createEmptyState(state.playerId, true);
    state.npcId = npcId;
    state.currentDialogue = tree;
    state.currentNodeId = tree.startNode;
    state.offline = fromCache;

    await loadNpcMemory(npcId);
    return tree;
  }

  /**
   * Load NPC's memory of previous interactions with the player.
   */
  async function loadNpcMemory(npcId) {
    const firstMeeting = {
      firstMeeting: true,
      totalInteractions: 0,
      choiceHistory: [],
    };
    const playerId = state.playerId;
    if (!playerId) {
      // Guests have no server-side memory; asking for /memory/null
      // would only produce a 404 on every conversation.
      state.npcMemory = firstMeeting;
      return;
    }
    try {
      const url = `${DIALOGUE_API}/memory/` +
        `${encodeURIComponent(npcId)}/${encodeURIComponent(playerId)}`;
      const response = await fetch(url, { headers: await buildHeaders() });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      const memory = await response.json();
      state.npcMemory = Object.assign(firstMeeting, memory || {});
    } catch (err) {
      console.warn('[Ludus] No NPC memory available (first meeting):',
        err.message);
      state.npcMemory = firstMeeting;
    }
  }

  /**
   * Get current dialogue node.
   *
   * The tree argument is optional; without it the loaded tree is used.
   */
  function getCurrentNode(dialogueTree) {
    const tree = dialogueTree || state.currentDialogue;
    if (!tree || !Array.isArray(tree.nodes)) {
      return null;
    }
    return tree.nodes.find((n) => n.id === state.currentNodeId) || null;
  }

  /**
   * Check if player meets branch condition.
   *
   * condition { wisdom: 8, faith: 6 } means wisdom >= 8 AND faith >= 6.
   */
  function checkCondition(condition, playerAttributes) {
    if (!condition) {
      return true;
    }
    const attrs = playerAttributes || {};
    return Object.entries(condition).every(([attr, required]) => {
      return (Number(attrs[attr]) || 0) >= required;
    });
  }

  // List the unmet requirements of a condition, so the UI can teach
  // the player which part of their FORM still has to grow.
  function missingRequirements(condition, playerAttributes) {
    const attrs = playerAttributes || {};
    return Object.entries(condition || {})
      .filter(([attr, required]) => (Number(attrs[attr]) || 0) < required)
      .map(([attr, required]) => ({
        attribute: attr,
        required: required,
        current: Number(attrs[attr]) || 0,
      }));
  }

  /**
   * Get available branches for a node based on player attributes.
   */
  function getAvailableBranches(node, playerAttributes) {
    if (!node || !Array.isArray(node.branches)) {
      return [];
    }
    return node.branches.filter((branch) =>
      checkCondition(branch.condition, playerAttributes)
    );
  }

  /**
   * Process player choice.
   *
   * ``branchIndex`` is the index in ``node.branches`` (the same value
   * formatNodeForUI puts in ``index``).  Locked branches are refused,
   * so a stale or forged index cannot bypass a knowledge gate.
   */
  async function processChoice(branchIndex, playerAttributes) {
    if (state.processing) {
      throw new Error('A choice is already being processed');
    }
    const currentNode = getCurrentNode();
    if (!currentNode || currentNode.branches.length === 0) {
      throw new Error('No branches available');
    }
    const branch = currentNode.branches[branchIndex];
    if (!branch) {
      throw new Error(`Branch index ${branchIndex} not available`);
    }
    if (!checkCondition(branch.condition, playerAttributes)) {
      const error = new Error(`Branch index ${branchIndex} is locked`);
      error.locked = true;
      error.missing = missingRequirements(branch.condition,
        playerAttributes);
      throw error;
    }

    state.processing = true;
    try {
      const now = Date.now();
      const bonuses = Object.assign({}, branch.attributeBonuses);
      const fromNodeId = state.currentNodeId;

      state.dialogueHistory.push({
        nodeId: fromNodeId,
        choiceIndex: branchIndex,
        choiceText: branch.text,
        timestamp: now,
        attributeBonuses: bonuses,
      });

      const memory = state.npcMemory;
      memory.firstMeeting = false;
      memory.lastInteraction = now;
      memory.totalInteractions = (memory.totalInteractions || 0) + 1;
      memory.choiceHistory = memory.choiceHistory || [];
      memory.choiceHistory.push({
        nodeId: fromNodeId,
        choice: branch.text,
        timestamp: now,
      });

      const complete = !branch.nextNodeId;
      if (!complete) {
        state.currentNodeId = branch.nextNodeId;
      }

      // The final choice is persisted too: its bonuses are usually
      // the largest, and dropping them would lose the teaching.
      await persistDialogueState(bonuses, complete);

      return {
        complete: complete,
        nextNodeId: complete ? null : branch.nextNodeId,
        attributeBonuses: bonuses,
        narrativeEffect: branch.narrativeEffect || '',
      };
    } finally {
      state.processing = false;
    }
  }

  async function postState(payload) {
    const response = await fetch(`${DIALOGUE_API}/state`, {
      method: 'POST',
      headers: await buildHeaders({ 'Content-Type': 'application/json' }),
      body: JSON.stringify(payload),
    });
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
  }

  function queuePending(payload) {
    const queue = storageGet(PENDING_KEY) || [];
    queue.push(payload);
    // Oldest entries go first: the newest state includes the full
    // history, so it is the one worth keeping.
    storageSet(PENDING_KEY, queue.slice(-PENDING_LIMIT));
  }

  /**
   * Send queued offline state to the backend, oldest first.
   *
   * Returns the number of entries still waiting.
   */
  function flushPending() {
    // Concurrent flushes (the 'online' event racing a new choice)
    // would post the head of the queue twice, so they share one run.
    if (!flushing) {
      flushing = drainPending().finally(() => {
        flushing = null;
      });
    }
    return flushing;
  }

  async function drainPending() {
    const queue = storageGet(PENDING_KEY) || [];
    // A guest has no account and no token, so posting an entry left by
    // an earlier signed-in session would only fail with a 4xx.  The
    // queue waits until that player signs in again.
    if (!state.playerId) {
      return queue.length;
    }
    while (queue.length > 0) {
      try {
        await postState(queue[0]);
      } catch (err) {
        break;
      }
      queue.shift();
      storageSet(PENDING_KEY, queue);
    }
    return queue.length;
  }

  /**
   * Persist dialogue state to the backend, or queue it when offline.
   */
  async function persistDialogueState(attributeBonuses, complete) {
    if (!state.playerId) {
      // Guests play locally; there is no account to persist to.
      return;
    }
    const payload = {
      playerId: state.playerId,
      npcId: state.npcId,
      currentNodeId: state.currentNodeId,
      dialogueHistory: state.dialogueHistory.slice(),
      npcMemory: state.npcMemory,
      attributeBonuses: attributeBonuses || {},
      complete: Boolean(complete),
      timestamp: Date.now(),
    };
    try {
      await postState(payload);
      state.offline = false;
      await flushPending();
    } catch (err) {
      // Queue instead of throwing, so the dialogue continues offline
      // and syncs when the headset reconnects.
      state.offline = true;
      queuePending(payload);
      console.warn('[Ludus] Dialogue state queued for sync:', err.message);
    }
  }

  /**
   * Format dialogue node for UI display.
   *
   * All branches are returned, locked ones flagged, so the player sees
   * which paths their FORM does not open yet and what is required.
   */
  function formatNodeForUI(node, playerAttributes) {
    if (!node) {
      return null;
    }
    const tree = state.currentDialogue || {};
    const profile = NPC_PROFILES[state.npcId];
    return {
      nodeId: node.id,
      npcName: (profile && profile.name) || tree.npcName || 'NPC',
      text: node.text,
      branches: (node.branches || []).map((branch, idx) => ({
        index: idx,
        text: branch.text,
        locked: !checkCondition(branch.condition, playerAttributes),
        requiredAttributes: Object.assign({}, branch.condition),
        missing: missingRequirements(branch.condition, playerAttributes),
        bonuses: Object.assign({}, branch.attributeBonuses),
      })),
    };
  }

  /**
   * Initialize dialogue manager with player ID.
   *
   * ``options.getAuthToken`` is an optional async function returning a
   * Firebase ID token for authenticated endpoints.
   */
  function init(playerId, options) {
    state.playerId = playerId || null;
    state.initialized = true;
    if (options && typeof options.getAuthToken === 'function') {
      getAuthToken = options.getAuthToken;
    }
    flushPending();
    console.log('[Ludus Dialogue] Initialized for player:', playerId);
  }

  /**
   * Get NPC profile by ID.
   */
  function getNpcProfile(npcId) {
    return NPC_PROFILES[npcId] || null;
  }

  /**
   * Get dialogue history.
   */
  function getDialogueHistory() {
    return state.dialogueHistory;
  }

  /**
   * Get NPC memory.
   */
  function getNpcMemory() {
    return state.npcMemory;
  }

  /**
   * Report whether the last load or save used the offline path.
   */
  function isOffline() {
    return state.offline;
  }

  /**
   * Reset dialogue state (for testing or new dialogue).
   */
  function reset() {
    state = createEmptyState(state.playerId, state.initialized);
  }

  // Unsent state is retried as soon as the browser reports a network.
  window.addEventListener('online', () => {
    flushPending();
  });

  // ── Public API ──────────────────────────────────────────────────────────
  return {
    init,
    loadDialogueTree,
    getCurrentNode,
    getAvailableBranches,
    checkCondition,
    processChoice,
    formatNodeForUI,
    getNpcProfile,
    getDialogueHistory,
    getNpcMemory,
    flushPending,
    isOffline,
    reset,
    ATTRIBUTES,
    NPC_PROFILES,
  };
})();

console.log('[Ludus] NPC Dialogue Manager loaded');
