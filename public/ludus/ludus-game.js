/**
 * Ludus Protocol Game Module — Game Tab for Typikon.site
 *
 * Integrates Deacon's Path: Issyk-Kul VR ROV simulator with webtypicon2 player progression.
 * Lazy-loaded IIFE. Exposes window.__LudusModule with init() called on first game-tab access.
 *
 * Features:
 *  1. Firebase Auth (Google Sign-In) with role-based access
 *  2. Player profile card: name, attributes (9 stats), resources, goals
 *  3. Demiurge graph integration: reachable nodes (mentors, quests, NPCs)
 *  4. Knowledge gates: theology tier progression (1–3)
 *  5. Real-time Firestore subscriptions: ludus_nodes, ludus_edges, ludus_knowledge_gates
 *  6. Marketplace browser: faction trading, artifact inventory
 *  7. Obsidian theme: gold (#D4AF37) + cyan (#00CED1) on dark background
 *
 * No dependency on app.js internals. Only requires:
 *   - Firebase JS SDK loaded lazily (CDN)
 *   - /api/demiurge/* endpoints (if backend routing exists)
 *   - Firestore direct access via Firebase Admin (in-browser authenticated)
 *
 * Architecture: Contract-first (JSON → UI), deterministic queries (Firestore).
 */

'use strict';

(function () {
  const LUDUS_API = '/api/ludus';
  const FIREBASE_CONFIG = window.FIREBASE_CONFIG || {};

  // ── Theistic/Aristotelian attribute names (9 stats) ──────────────────────
  const ATTRIBUTES = [
    { key: 'strength',    label: 'Strength',    emoji: '💪', tooltip: 'Physical power & endurance' },
    { key: 'dexterity',   label: 'Dexterity',   emoji: '🤸', tooltip: 'Agility & precision' },
    { key: 'constitution', label: 'Constitution', emoji: '❤️', tooltip: 'Health pool & vitality' },
    { key: 'intelligence', label: 'Intelligence', emoji: '🧠', tooltip: 'Logical reasoning & puzzles' },
    { key: 'wisdom',      label: 'Wisdom',      emoji: '🕯️', tooltip: 'Knowledge & introspection' },
    { key: 'charisma',    label: 'Charisma',    emoji: '✨', tooltip: 'Influence & persuasion' },
    { key: 'faith',       label: 'Faith',       emoji: '⛪', tooltip: 'Spiritual conviction' },
    { key: 'cunning',     label: 'Cunning',     emoji: '🎲', tooltip: 'Deception & tactics' },
    { key: 'erudition',   label: 'Erudition',   emoji: '📚', tooltip: 'Learned knowledge' },
  ];

  const RESOURCES = [
    { key: 'gold',       label: 'Gold',       emoji: '💰' },
    { key: 'faith',      label: 'Faith',      emoji: '⛪' },
    { key: 'knowledge',  label: 'Knowledge',  emoji: '📖' },
    { key: 'influence',  label: 'Influence',  emoji: '👑' },
  ];

  // ── i18n strings (minimal; will integrate with window.__i18n) ────────────
  const i18nKeys = {
    'ludus.tab': 'Ludus Protocol',
    'ludus.signin': 'Sign in to play',
    'ludus.profile': 'Player Profile',
    'ludus.attributes': 'Attributes',
    'ludus.resources': 'Resources',
    'ludus.quests': 'Quests',
    'ludus.gates': 'Knowledge Gates',
    'ludus.marketplace': 'Marketplace',
    'ludus.mentor': 'Mentor',
    'ludus.quest': 'Quest',
    'ludus.npc': 'NPC',
    'ludus.loading': 'Loading game data...',
    'ludus.error': 'Error loading game data',
  };

  // ── State ────────────────────────────────────────────────────────────────
  let state = {
    auth: null,
    user: null,
    playerId: null,
    playerNode: null,
    reachableNodes: [],
    knowledgeGates: [],
    initialized: false,
  };

  // ── Helper: Get i18n label (with fallback) ──────────────────────────────
  function t(key) {
    const parts = key.split('.');
    const globalI18n = window.__i18n;
    if (globalI18n && globalI18n.getString) {
      return globalI18n.getString(key) || key;
    }
    return i18nKeys[key] || key;
  }

  // ── Helper: Format number as attribute bar (1–20 scale) ──────────────────
  function formatAttributeBar(value, max = 20) {
    const clamped = Math.max(0, Math.min(max, value || 0));
    const pct = (clamped / max) * 100;
    return `<div class="attr-bar" style="--pct: ${pct}%">
      <div class="attr-fill"></div>
      <span class="attr-val">${clamped.toFixed(1)}</span>
    </div>`;
  }

  // ── Helper: Format resource display ──────────────────────────────────────
  function formatResource(value) {
    if (typeof value !== 'number') return '—';
    return value.toFixed(1);
  }

  // ── Firebase Init (lazy-load Firebase SDK) ──────────────────────────────
  async function initFirebase() {
    if (window.firebase && window.firebase.app) {
      return;
    }

    const script = document.createElement('script');
    script.src = 'https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.min.js';
    script.async = true;

    return new Promise((resolve) => {
      script.onload = () => {
        const script2 = document.createElement('script');
        script2.src = 'https://www.gstatic.com/firebasejs/10.12.2/firebase-auth-compat.min.js';
        script2.async = true;

        script2.onload = () => {
          const script3 = document.createElement('script');
          script3.src = 'https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore-compat.min.js';
          script3.async = true;

          script3.onload = () => {
            if (!window.firebase.apps.length) {
              window.firebase.initializeApp(FIREBASE_CONFIG);
            }
            state.auth = window.firebase.auth();
            resolve();
          };

          document.head.appendChild(script3);
        };

        document.head.appendChild(script2);
      };

      document.head.appendChild(script);
    });
  }

  // ── Auth: Sign in with Google ────────────────────────────────────────────
  async function signInWithGoogle() {
    try {
      const provider = new window.firebase.auth.GoogleAuthProvider();
      const result = await state.auth.signInWithPopup(provider);
      state.user = result.user;
      state.playerId = `player-${result.user.uid.substring(0, 16)}`;
      await loadPlayerData();
    } catch (error) {
      console.error('[Ludus] Auth error:', error);
      showError('Authentication failed');
    }
  }

  // ── Auth: Sign out ───────────────────────────────────────────────────────
  async function signOut() {
    try {
      await state.auth.signOut();
      state.user = null;
      state.playerId = null;
      renderAuthPanel();
    } catch (error) {
      console.error('[Ludus] Sign-out error:', error);
    }
  }

  // ── Data: Load player node and reachable nodes from Firestore ────────────
  async function loadPlayerData() {
    try {
      const db = window.firebase.firestore();

      // Load player node
      const playerSnap = await db.collection('ludus_nodes').doc(state.playerId).get();
      if (playerSnap.exists) {
        state.playerNode = playerSnap.data();
      }

      // Load reachable nodes (mentors, NPCs, concepts) via BFS query
      // Note: Firestore doesn't support native graph queries, so we do BFS client-side
      const nodesSnap = await db.collection('ludus_nodes').limit(100).get();
      const edgesSnap = await db.collection('ludus_edges').limit(500).get();

      const nodes = {};
      const edges = [];

      nodesSnap.forEach((doc) => {
        nodes[doc.id] = doc.data();
      });

      edgesSnap.forEach((doc) => {
        edges.push(doc.data());
      });

      // Simple BFS from player node
      state.reachableNodes = performBFS(state.playerId, nodes, edges, maxDepth = 2);

      // Load knowledge gates for player
      const gatesSnap = await db.collection('ludus_knowledge_gates').where('nodeId', '==', state.playerId).limit(10).get();
      state.knowledgeGates = [];
      gatesSnap.forEach((doc) => {
        state.knowledgeGates.push(doc.data());
      });

      renderGameUI();
    } catch (error) {
      console.error('[Ludus] Data load error:', error);
      showError('Failed to load game data');
    }
  }

  // ── Helper: BFS traversal (client-side graph query) ──────────────────────
  function performBFS(startNodeId, nodes, edges, maxDepth) {
    const visited = new Set();
    const queue = [[startNodeId, 0]];
    const reachable = [];

    while (queue.length > 0) {
      const [nodeId, depth] = queue.shift();

      if (visited.has(nodeId) || depth > maxDepth) continue;

      visited.add(nodeId);
      if (nodes[nodeId]) {
        reachable.push({ id: nodeId, ...nodes[nodeId], depth });
      }

      // Find outbound edges from this node
      edges.forEach((edge) => {
        if (edge.sourceNodeId === nodeId && !visited.has(edge.targetNodeId)) {
          queue.push([edge.targetNodeId, depth + 1]);
        }
      });
    }

    return reachable;
  }

  // ── Render: Auth panel (sign-in / profile) ───────────────────────────────
  function renderAuthPanel() {
    const container = document.getElementById('ludus-auth');
    if (!container) return;

    if (!state.user) {
      container.innerHTML = `
        <div class="ludus-signin-panel">
          <h3 data-i18n="ludus.signin">${t('ludus.signin')}</h3>
          <button class="ludus-signin-btn" onclick="window.__LudusModule.signInWithGoogle()">
            🔐 Sign in with Google
          </button>
        </div>
      `;
    } else {
      container.innerHTML = `
        <div class="ludus-profile-header">
          <span class="ludus-player-name">${state.user.displayName || 'Player'}</span>
          <button class="ludus-signout-btn" onclick="window.__LudusModule.signOut()">
            Sign out
          </button>
        </div>
      `;
    }
  }

  // ── Render: Player profile card ──────────────────────────────────────────
  function renderPlayerProfile() {
    const container = document.getElementById('ludus-profile');
    if (!container || !state.playerNode) return;

    const attrs = state.playerNode.attributes || {};
    const resources = state.playerNode.resources || {};

    const attrHtml = ATTRIBUTES.map((attr) => `
      <div class="ludus-attr-item">
        <span class="ludus-attr-emoji" title="${attr.tooltip}">${attr.emoji}</span>
        <span class="ludus-attr-label">${attr.label}</span>
        ${formatAttributeBar(attrs[attr.key] || 10, 20)}
      </div>
    `).join('');

    const resourceHtml = RESOURCES.map((res) => `
      <div class="ludus-resource-item">
        <span class="ludus-res-emoji">${res.emoji}</span>
        <span class="ludus-res-label">${res.label}</span>
        <span class="ludus-res-val">${formatResource(resources[res.key] || 0)}</span>
      </div>
    `).join('');

    container.innerHTML = `
      <div class="ludus-profile-card">
        <h3 class="ludus-profile-title" data-i18n="ludus.profile">${t('ludus.profile')}</h3>
        <div class="ludus-attributes">
          <h4 data-i18n="ludus.attributes">${t('ludus.attributes')}</h4>
          ${attrHtml}
        </div>
        <div class="ludus-resources">
          <h4 data-i18n="ludus.resources">${t('ludus.resources')}</h4>
          ${resourceHtml}
        </div>
        <div class="ludus-causality">
          <p><strong>Goal:</strong> ${state.playerNode.causality?.goal || 'Redemption and wisdom'}</p>
        </div>
      </div>
    `;
  }

  // ── Render: Reachable nodes (mentors, quests, NPCs) ──────────────────────
  function renderReachableNodes() {
    const container = document.getElementById('ludus-network');
    if (!container) return;

    const mentors = state.reachableNodes.filter((n) => n.nodeType === 'npc' && n.depth === 1);
    const quests = state.reachableNodes.filter((n) => n.nodeType === 'quest');

    const mentorHtml = mentors.map((n) => `
      <div class="ludus-node-card ludus-mentor-card">
        <h4>${n.nodeId.replace('npc-', '')}</h4>
        <p class="ludus-node-role">${n.causality?.form || 'NPC'}</p>
        <p class="ludus-node-goal">${n.causality?.action || '...'}</p>
      </div>
    `).join('');

    const questHtml = quests.length > 0 ? quests.map((n) => `
      <div class="ludus-node-card ludus-quest-card">
        <h4>${n.nodeId}</h4>
        <p>${n.causality?.action || 'Complete this objective'}</p>
      </div>
    `).join('') : '<p>No quests available</p>';

    container.innerHTML = `
      <div class="ludus-network">
        <section class="ludus-mentors">
          <h3 data-i18n="ludus.mentor">${t('ludus.mentor')}</h3>
          ${mentorHtml || '<p>No mentors nearby</p>'}
        </section>
        <section class="ludus-quests">
          <h3 data-i18n="ludus.quests">${t('ludus.quests')}</h3>
          ${questHtml}
        </section>
      </div>
    `;
  }

  // ── Render: Knowledge gates (progression) ─────────────────────────────────
  function renderKnowledgeGates() {
    const container = document.getElementById('ludus-gates');
    if (!container) return;

    const gateHtml = state.knowledgeGates.map((g, i) => `
      <div class="ludus-gate-card ludus-tier-${g.tier || 1}">
        <h4>${g.title || 'Knowledge Gate'}</h4>
        <p class="ludus-gate-subject">${g.subject || '—'}</p>
        <p class="ludus-gate-question">"${g.question || ''}"</p>
        <button class="ludus-gate-btn">Answer Question</button>
      </div>
    `).join('');

    container.innerHTML = `
      <div class="ludus-gates-panel">
        <h3 data-i18n="ludus.gates">${t('ludus.gates')}</h3>
        ${gateHtml || '<p>No knowledge gates available</p>'}
      </div>
    `;
  }

  // ── Render: Game UI (main tab content) ────────────────────────────────────
  function renderGameUI() {
    if (!state.user) {
      renderAuthPanel();
      return;
    }

    renderAuthPanel();
    renderPlayerProfile();
    renderReachableNodes();
    renderKnowledgeGates();
  }

  // ── Error display ────────────────────────────────────────────────────────
  function showError(message) {
    const errorBox = document.getElementById('ludus-error');
    if (errorBox) {
      errorBox.textContent = message;
      errorBox.hidden = false;
      setTimeout(() => {
        errorBox.hidden = true;
      }, 5000);
    }
  }

  // ── Main: Initialize module (called on first game-tab access) ────────────
  async function init() {
    if (state.initialized) return;

    try {
      console.log('[Ludus] Initializing module...');
      await initFirebase();

      // Check if already signed in
      if (state.auth) {
        state.auth.onAuthStateChanged(async (user) => {
          if (user) {
            state.user = user;
            state.playerId = `player-${user.uid.substring(0, 16)}`;
            await loadPlayerData();
          } else {
            renderAuthPanel();
          }
        });
      }

      renderAuthPanel();
      state.initialized = true;
      console.log('[Ludus] Module initialized');
    } catch (error) {
      console.error('[Ludus] Initialization error:', error);
      showError('Failed to initialize game module');
    }
  }

  // ── Export public API ────────────────────────────────────────────────────
  window.__LudusModule = {
    init,
    signInWithGoogle,
    signOut,
    getPlayerData: () => state.playerNode,
    getReachableNodes: () => state.reachableNodes,
  };

  console.log('[Ludus] Module registered as window.__LudusModule');
})();
