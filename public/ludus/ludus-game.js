/**
 * Ludus game core: auth, player FORM, reachable NPCs and knowledge gates.
 *
 * This is the Meta Quest 3 browser build.  The module is a self-contained
 * IIFE that registers window.__LudusModule; index.html calls
 * window.__LudusModule.init() once after DOMContentLoaded and renders into
 * #ludus-auth, #ludus-profile, #ludus-network, #ludus-gates and
 * #ludus-error inside #ludus-game-container.
 *
 * Demiurgic Causality (CLAUDE.md, taboo 0):
 *   FORM (7 attributes) -> ACTION (dialogue choices) -> GOAL (gates).
 * The UI therefore shows exactly the seven constitutional attributes and
 * derives gate access deterministically; nothing is random.  A gate
 * opens only on three conditions at once (Wisdom, mentors met and a
 * rite from actions{}), which window.LudusActions evaluates; gates 4-6
 * also wait for a bow, "not to me" (CLAUDE.md TABOO 0.35 rule 14).
 *
 * Data sources (field-name adapter, see readPlayerForm()):
 *   - ludus_players/{playerId}.form.*    canonical FORM, written by the
 *                                        dialogue Cloud Function.
 *   - ludus_nodes/{playerId}.attributes  legacy Demiurge graph node; only
 *                                        read when .form is missing.
 *   - ludus_nodes / ludus_edges          graph for reachable NPCs/quests.
 *   - ludus_knowledge_gates              gate questions for this player.
 *
 * Firebase is optional.  When the SDK cannot be fetched (blocked CDN,
 * offline headset) or no config is supplied, init() still resolves within
 * FIREBASE_LOAD_TIMEOUT_MS and the module enters a guest/offline state.
 */

'use strict';

(function () {
  // The SDK version is pinned so a CDN update can never change behaviour
  // underneath a headset build that has already been tested.
  const FIREBASE_SDK_BASE = 'https://www.gstatic.com/firebasejs/10.12.2/';
  const FIREBASE_SDK_FILES = [
    'firebase-app-compat.min.js',
    'firebase-auth-compat.min.js',
    'firebase-firestore-compat.min.js',
  ];

  // One budget for the whole SDK chain.  It must stay below the 15 s
  // boot watchdog in index.html so our own offline message wins.
  const FIREBASE_LOAD_TIMEOUT_MS = 10000;

  // Attribute bars use the same 0-20 range as the seed data and the
  // backend validation, so a full bar means the top of the scale.
  const ATTR_MAX = 20;

  // The seven constitutional attributes (CLAUDE.md, section 3).  Keys
  // must match ludus_players.form.* exactly.
  const ATTRIBUTES = [
    { key: 'wisdom', label: 'Wisdom', emoji: '🕯️',
      tooltip: 'Understanding of the teachings (Gregory of Nyssa)' },
    { key: 'faith', label: 'Faith', emoji: '⛪',
      tooltip: 'Trust, pistis (Pseudo-Dionysius)' },
    { key: 'dexterity', label: 'Dexterity', emoji: '🤲',
      tooltip: 'Practice and ritual skill (John of Damascus)' },
    { key: 'constitution', label: 'Constitution', emoji: '🪨',
      tooltip: 'Endurance in fasting and prayer (Isaac the Syrian)' },
    { key: 'charisma', label: 'Charisma', emoji: '✨',
      tooltip: 'Building community (Gregory the Theologian)' },
    { key: 'cunning', label: 'Cunning', emoji: '🗝️',
      tooltip: 'Hidden paths; rarely approved' },
    { key: 'erudition', label: 'Erudition', emoji: '📚',
      tooltip: 'Knowledge of texts (Synaxarion tradition)' },
  ];

  // The Wisdom thresholds of the six gates (CLAUDE.md, section 4).  They
  // only draw the ticks on the Wisdom bar: Wisdom is one condition of
  // three, and whether a gate is open is decided by LudusActions.
  const GATE_LADDER = [
    { id: 'foundational', label: 'Foundational', wisdom: 4 },
    { id: 'liturgical', label: 'Liturgical', wisdom: 6 },
    { id: 'ascetic', label: 'Ascetic', wisdom: 8 },
    { id: 'contemplative', label: 'Contemplative', wisdom: 10 },
    { id: 'mystical', label: 'Mystical', wisdom: 12 },
    { id: 'apophatic', label: 'Apophatic', wisdom: 14 },
  ];

  // A guest starts at the seed minimum (1 in every attribute).  Growth
  // must come from dialogue choices, never from a random roll.
  const GUEST_FORM = Object.freeze(ATTRIBUTES.reduce((form, attr) => {
    form[attr.key] = 1;
    return form;
  }, {}));

  // Project art lives next to the modules.  Paths are root-absolute for
  // the same reason as the asset URLs in index.html: hosting rewrites
  // deep links to the shell, and a relative path would then break.
  const ART = '/ludus/art/';

  // The mentors a guest can meet without any network.  Their dialogue
  // trees ship in /ludus/data/dialogue-trees.json (exported from the
  // backend seed), so ids must match the seed's npcId values.
  const MENTORS = [
    { npcId: 'elder_sergius', name: 'Elder Sergius',
      teaching: 'Hesychasm: prayer of the heart',
      portrait: 'npc-elder-sergius.svg',
      profile: { wisdom: 14, faith: 15, erudition: 12 } },
    { npcId: 'theodora', name: 'Theodora',
      teaching: 'The Divine Liturgy',
      portrait: 'npc-theodora.svg',
      profile: { faith: 13, erudition: 12, charisma: 11 } },
    { npcId: 'abba_john', name: 'Abba John',
      teaching: 'Ascetic discipline of the desert',
      portrait: 'npc-abba-john.svg',
      profile: { constitution: 14, faith: 12, wisdom: 10 } },
    { npcId: 'sister_catherine', name: 'Sister Catherine',
      teaching: 'Mystical theology and theosis',
      portrait: 'npc-sister-catherine.svg',
      profile: { wisdom: 14, faith: 14, charisma: 13 } },
  ];

  // Resonance at or above this value lights the mentor's portrait.  The
  // resolution (CLAUDE.md TABOO 0.25) replaces the nimbus with a glow
  // that appears only when the player's FORM matches the saint's path.
  const RESONANCE_GLOW = 0.8;

  // Resonance ("ethos") is the cosine similarity between the player's
  // seven attributes and a mentor's profile.  It is a derived metric,
  // not an eighth attribute, so the constitution's seven stay intact;
  // it measures the shape of the soul's growth, not its size.
  function resonanceWith(profile, form) {
    let dot = 0;
    let a2 = 0;
    let b2 = 0;
    ATTRIBUTES.forEach((attr) => {
      const a = toScore(form && form[attr.key]);
      const b = toScore(profile[attr.key]);
      dot += a * b;
      a2 += a * a;
      b2 += b * b;
    });
    return a2 && b2 ? dot / Math.sqrt(a2 * b2) : 0;
  }

  // A guest's FORM is kept on the device, so the growth earned in
  // dialogue survives a reload even without an account.
  const GUEST_FORM_KEY = 'ludus.guest.form';

  // The guest's ACTION counters (prayer rope, fasts, stillness, mentors
  // met, bows) live beside the FORM for the same reason.
  const GUEST_ACTIONS_KEY = 'ludus.guest.actions';

  // Seconds in a minute of a timed practice.  A constant, so a test can
  // read how long a session is; it is never shortened in play.
  const PRACTICE_MINUTE_SECONDS = 60;

  const RESOURCES = [
    { key: 'gold', label: 'Gold', emoji: '💰' },
    { key: 'faith', label: 'Faith', emoji: '⛪' },
    { key: 'knowledge', label: 'Knowledge', emoji: '📖' },
    { key: 'influence', label: 'Influence', emoji: '👑' },
  ];

  // Fallback strings until window.__i18n provides translations.
  const i18nKeys = {
    'ludus.tab': 'Ludus Protocol',
    'ludus.signin': 'Sign in to play',
    'ludus.profile': 'Player Profile',
    'ludus.attributes': 'Form (attributes)',
    'ludus.resources': 'Resources',
    'ludus.quests': 'Quests',
    'ludus.gates': 'Knowledge Gates',
    'ludus.mentor': 'Mentors',
    'ludus.loading': 'Connecting to the monastery...',
    'ludus.error': 'Error loading game data',
    'ludus.offline.title': 'Playing offline as a guest',
    'ludus.offline.unreachable':
      'Online services could not be reached, so sign-in and sync are ' +
      'unavailable. Your progress stays on this device for now.',
    'ludus.offline.unconfigured':
      'Online services are not configured for this build, so sign-in ' +
      'and sync are unavailable. You can still play as a guest.',
    'ludus.retry': 'Try again',
  };

  const state = {
    auth: null,
    user: null,
    playerId: null,
    playerNode: null,
    playerForm: null,
    formSource: null,
    // ACTION counters, always in the normalised LudusActions shape.
    actions: null,
    // A running timed practice (stillness, vigil, handiwork):
    // { id, endsAt, timer } or null.  Only one runs at a time.
    practiceTimer: null,
    reachableNodes: [],
    knowledgeGates: [],
    // One of 'loading', 'online', 'offline'.
    mode: 'loading',
    offlineReason: null,
    initialized: false,
    listenersBound: false,
    errorTimer: null,
  };

  // Resolve a UI string, preferring the host's translation service.
  function t(key) {
    const globalI18n = window.__i18n;
    if (globalI18n && typeof globalI18n.getString === 'function') {
      return globalI18n.getString(key) || i18nKeys[key] || key;
    }
    return i18nKeys[key] || key;
  }

  // Every value that reaches innerHTML passes through here.  Display
  // names and Firestore fields are user-controlled, so without this any
  // player could run script in another player's headset.
  function escapeHtml(value) {
    if (value === null || value === undefined) {
      return '';
    }
    return String(value)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  // Coerce a stored attribute to a finite number.  Missing values render
  // as 0 instead of an invented default, so the bar never lies.
  function toScore(value) {
    const num = Number(value);
    return Number.isFinite(num) ? num : 0;
  }

  // Render one attribute bar.  The Wisdom bar also carries tick marks at
  // the gate thresholds so the player sees how far the next gate is.
  function formatAttributeBar(key, value, max) {
    const score = toScore(value);
    const clamped = Math.max(0, Math.min(max, score));
    const pct = ((clamped / max) * 100).toFixed(2);
    let ticks = '';
    if (key === 'wisdom') {
      ticks = GATE_LADDER.map((gate) => {
        const left = ((gate.wisdom / max) * 100).toFixed(2);
        const reached = score >= gate.wisdom ? ' is-reached' : '';
        return `<span class="attr-tick${reached}" style="left: ${left}%"`
          + ` title="${escapeHtml(gate.label)}: Wisdom ${gate.wisdom}">`
          + '</span>';
      }).join('');
    }
    return `<div class="attr-bar" role="meter" aria-valuemin="0"`
      + ` aria-valuemax="${max}" aria-valuenow="${clamped}"`
      + ` style="--pct: ${pct}%">`
      + '<div class="attr-fill"></div>'
      + ticks
      + `<span class="attr-val">${escapeHtml(score)}</span>`
      + '</div>';
  }

  function formatResource(value) {
    if (typeof value !== 'number' || !Number.isFinite(value)) {
      return '—';
    }
    return String(Math.round(value * 10) / 10);
  }

  // Load one classic script, rejecting on network error or when the
  // shared deadline passes.  A failed tag is removed so a later retry
  // starts clean instead of reusing a broken element.
  function loadScript(src, deadline) {
    return new Promise((resolve, reject) => {
      const remaining = deadline - Date.now();
      if (remaining <= 0) {
        reject(new Error('Firebase SDK load timed out'));
        return;
      }
      const script = document.createElement('script');
      script.src = src;
      script.async = true;
      const timer = setTimeout(() => {
        cleanup(true);
        reject(new Error('Firebase SDK load timed out'));
      }, remaining);

      function cleanup(failed) {
        clearTimeout(timer);
        script.onload = null;
        script.onerror = null;
        if (failed && script.parentNode) {
          script.parentNode.removeChild(script);
        }
      }

      script.onload = () => {
        cleanup(false);
        resolve();
      };
      script.onerror = () => {
        cleanup(true);
        reject(new Error('Firebase SDK could not be loaded: ' + src));
      };
      document.head.appendChild(script);
    });
  }

  // Load the compat SDK in order (auth and firestore extend the app
  // namespace) and initialise the default app.  Rejects on any failure
  // so init() can fall back to the guest state.
  async function initFirebase() {
    const config = window.FIREBASE_CONFIG || {};
    if (!config.apiKey) {
      const err = new Error('FIREBASE_CONFIG is missing an apiKey');
      err.code = 'ludus/unconfigured';
      throw err;
    }

    const fb = window.firebase;
    const haveSdk = fb && typeof fb.initializeApp === 'function'
      && typeof fb.auth === 'function'
      && typeof fb.firestore === 'function';
    if (!haveSdk) {
      const deadline = Date.now() + FIREBASE_LOAD_TIMEOUT_MS;
      for (const file of FIREBASE_SDK_FILES) {
        await loadScript(FIREBASE_SDK_BASE + file, deadline);
      }
    }

    const firebase = window.firebase;
    if (!firebase || typeof firebase.initializeApp !== 'function') {
      throw new Error('Firebase SDK loaded but did not register');
    }
    if (!firebase.apps.length) {
      firebase.initializeApp(config);
    }
    state.auth = firebase.auth();
  }

  // Player ids follow the existing "player-<first 16 uid chars>" scheme
  // so documents written by earlier builds stay reachable.
  function playerIdFor(user) {
    return `player-${String(user.uid).substring(0, 16)}`;
  }

  async function signInWithGoogle() {
    if (state.mode !== 'online' || !state.auth) {
      showError('Sign-in is unavailable while offline.');
      return;
    }
    try {
      const provider = new window.firebase.auth.GoogleAuthProvider();
      const result = await state.auth.signInWithPopup(provider);
      await setUser(result.user);
    } catch (error) {
      console.error('[Ludus] Auth error:', error);
      showError('Authentication failed');
    }
  }

  async function signOut() {
    if (!state.auth) {
      return;
    }
    try {
      await state.auth.signOut();
      await setUser(null);
    } catch (error) {
      console.error('[Ludus] Sign-out error:', error);
      showError('Sign-out failed');
    }
  }

  // Single entry point for user changes.  Popup sign-in and the auth
  // listener both land here, so the render path is identical for both.
  async function setUser(user) {
    if (user && state.user && state.user.uid === user.uid
        && state.playerForm) {
      return;
    }
    state.user = user || null;
    state.playerId = user ? playerIdFor(user) : null;
    state.playerNode = null;
    state.playerForm = null;
    state.formSource = null;
    state.actions = null;
    stopPracticeTimer();
    state.reachableNodes = [];
    state.knowledgeGates = [];
    if (user) {
      await loadPlayerData();
      // The stored rule comes from the backend, which can read the
      // player's document; the direct read above may be refused.
      await loadServerActions();
    } else {
      renderGameUI();
    }
  }

  // Field-name adapter.  The dialogue backend persists FORM under
  // ludus_players.form, while the older Demiurge graph stored
  // ludus_nodes.attributes (with non-constitutional keys such as
  // strength).  Prefer .form and keep only the seven canonical keys.
  function readPlayerForm(playerDoc, playerNode) {
    const pick = (source) => ATTRIBUTES.reduce((form, attr) => {
      form[attr.key] = toScore(source[attr.key]);
      return form;
    }, {});
    if (playerDoc && playerDoc.form && typeof playerDoc.form === 'object') {
      return { form: pick(playerDoc.form), source: 'ludus_players.form' };
    }
    if (playerNode && playerNode.attributes
        && typeof playerNode.attributes === 'object') {
      return {
        form: pick(playerNode.attributes),
        source: 'ludus_nodes.attributes',
      };
    }
    return { form: pick({}), source: 'none' };
  }

  // Fetch everything the profile needs.  Reads are independent, so one
  // denied collection only blanks its own panel instead of all of them.
  async function loadPlayerData() {
    const playerId = state.playerId;
    let db;
    try {
      db = window.firebase.firestore();
    } catch (error) {
      console.error('[Ludus] Firestore unavailable:', error);
      showError('Failed to load game data');
      renderGameUI();
      return;
    }

    const [playerRes, nodeRes, nodesRes, edgesRes, gatesRes] =
      await Promise.allSettled([
        db.collection('ludus_players').doc(playerId).get(),
        db.collection('ludus_nodes').doc(playerId).get(),
        db.collection('ludus_nodes').limit(100).get(),
        db.collection('ludus_edges').limit(500).get(),
        db.collection('ludus_knowledge_gates')
          .where('nodeId', '==', playerId).limit(10).get(),
      ]);

    // The user may have signed out while the reads were in flight.
    if (state.playerId !== playerId) {
      return;
    }

    const failed = [playerRes, nodeRes, nodesRes, edgesRes, gatesRes]
      .filter((res) => res.status === 'rejected');
    failed.forEach((res) => {
      console.error('[Ludus] Data load error:', res.reason);
    });

    const docData = (res) => (res.status === 'fulfilled' && res.value.exists
      ? res.value.data() : null);
    const playerDoc = docData(playerRes);
    state.playerNode = docData(nodeRes);
    const adapted = readPlayerForm(playerDoc, state.playerNode);
    state.playerForm = adapted.form;
    state.formSource = adapted.source;
    // The ACTION layer is read beside FORM (players.actions in the
    // "Firestore as Heaven" shape) and normalised, so a tampered or
    // older record can neither crash the ladder nor add counters.
    state.actions = normalizeActions(playerDoc && playerDoc.actions);

    const nodes = {};
    if (nodesRes.status === 'fulfilled') {
      nodesRes.value.forEach((doc) => {
        nodes[doc.id] = doc.data();
      });
    }
    const edges = [];
    if (edgesRes.status === 'fulfilled') {
      edgesRes.value.forEach((doc) => {
        edges.push(doc.data());
      });
    }
    state.reachableNodes = performBFS(playerId, nodes, edges, 2);

    state.knowledgeGates = [];
    if (gatesRes.status === 'fulfilled') {
      gatesRes.value.forEach((doc) => {
        state.knowledgeGates.push({ id: doc.id, ...doc.data() });
      });
    }

    if (failed.length) {
      showError('Some game data could not be loaded');
    }
    renderGameUI();
  }

  // Firestore has no graph queries, so reachability is computed here.
  // Edges are indexed once and the queue uses a cursor, keeping this
  // O(V + E) instead of rescanning every edge per visited node.
  function performBFS(startNodeId, nodes, edges, maxDepth) {
    const outbound = new Map();
    edges.forEach((edge) => {
      if (!edge || !edge.sourceNodeId) {
        return;
      }
      if (!outbound.has(edge.sourceNodeId)) {
        outbound.set(edge.sourceNodeId, []);
      }
      outbound.get(edge.sourceNodeId).push(edge.targetNodeId);
    });

    const visited = new Set([startNodeId]);
    const queue = [[startNodeId, 0]];
    const reachable = [];
    for (let head = 0; head < queue.length; head += 1) {
      const [nodeId, depth] = queue[head];
      if (nodes[nodeId]) {
        reachable.push({ id: nodeId, ...nodes[nodeId], depth });
      }
      if (depth >= maxDepth) {
        continue;
      }
      (outbound.get(nodeId) || []).forEach((target) => {
        if (!visited.has(target)) {
          visited.add(target);
          queue.push([target, depth + 1]);
        }
      });
    }
    return reachable;
  }

  // The ACTION layer is a separate script.  If it failed to load, the
  // gates stay closed and say so, rather than falling back to the old
  // Wisdom-only check that TABOO 0.35 rule 14 calls a bug.
  function actionsApi() {
    const api = window.LudusActions;
    return api && typeof api.evaluateLadder === 'function' ? api : null;
  }

  function normalizeActions(raw) {
    const api = actionsApi();
    return api ? api.normalize(raw) : null;
  }

  // The highest open gate, judged on all three conditions, or null.
  function currentGateFor(form) {
    const api = actionsApi();
    return api && state.actions ? api.currentGate(form, state.actions)
      : null;
  }

  // Mentor ids become the names the player sees on the mentor cards.
  function mentorName(npcId) {
    const mentor = MENTORS.find((m) => m.npcId === npcId);
    return mentor ? mentor.name : npcId;
  }

  // The text of one missing condition.  Dialogue items are rebuilt from
  // the mentor list so the player reads "Theodora", not "theodora".
  function missingText(item) {
    if (item.kind === 'dialogue' && Array.isArray(item.mentors)) {
      return `Speak with ${item.mentors.map(mentorName).join(', ')}`;
    }
    return item.text;
  }

  // Today's date on the player's own calendar, as YYYY-MM-DD.  A fast
  // belongs to the local day, not to the UTC one.
  function localIsoDay(date) {
    const d = date || new Date();
    const pad = (n) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-`
      + pad(d.getDate());
  }

  function renderAuthPanel() {
    const container = document.getElementById('ludus-auth');
    if (!container) {
      return;
    }

    if (state.mode === 'loading') {
      container.innerHTML = '<div class="ludus-loading" role="status">'
        + `${escapeHtml(t('ludus.loading'))}</div>`;
      return;
    }

    if (state.mode === 'offline') {
      const reasonKey = state.offlineReason === 'unconfigured'
        ? 'ludus.offline.unconfigured' : 'ludus.offline.unreachable';
      // Retry only makes sense when the network, not the build, failed.
      const retry = state.offlineReason === 'unconfigured' ? ''
        : '<button type="button" class="ludus-retry-btn"'
          + ` data-action="retry">${escapeHtml(t('ludus.retry'))}</button>`;
      container.innerHTML = '<div class="ludus-offline-panel" role="status">'
        + `<h3>${escapeHtml(t('ludus.offline.title'))}</h3>`
        + `<p>${escapeHtml(t(reasonKey))}</p>`
        + retry
        + '</div>';
      return;
    }

    if (!state.user) {
      container.innerHTML = '<div class="ludus-signin-panel">'
        + `<h3 data-i18n="ludus.signin">${escapeHtml(t('ludus.signin'))}`
        + '</h3>'
        + '<button type="button" class="ludus-signin-btn"'
        + ' data-action="signin">🔐 Sign in with Google</button>'
        + '</div>';
      return;
    }

    container.innerHTML = '<div class="ludus-profile-header">'
      + '<span class="ludus-player-name">'
      + `${escapeHtml(state.user.displayName || 'Player')}</span>`
      + '<button type="button" class="ludus-signout-btn"'
      + ' data-action="signout">Sign out</button>'
      + '</div>';
  }

  function renderPlayerProfile() {
    const container = document.getElementById('ludus-profile');
    if (!container) {
      return;
    }
    const form = state.playerForm;
    if (!form) {
      container.innerHTML = '';
      return;
    }

    // The drawn badge replaces the emoji: emoji glyphs differ between
    // headsets and some Quest fonts lack them entirely.
    const attrHtml = ATTRIBUTES.map((attr) => '<div class="ludus-attr-item">'
      + `<img class="ludus-attr-icon" src="${ART}attr-${attr.key}.svg"`
      + ` alt="" title="${escapeHtml(attr.tooltip)}" width="40"`
      + ' height="40">'
      + `<span class="ludus-attr-label">${escapeHtml(attr.label)}</span>`
      + formatAttributeBar(attr.key, form[attr.key], ATTR_MAX)
      + '</div>').join('');

    // Resources exist only on the legacy graph node; hide the section
    // rather than show a column of dashes for guests.
    const resources = (state.playerNode && state.playerNode.resources)
      || null;
    const resourceHtml = resources ? '<div class="ludus-resources">'
      + `<h4 data-i18n="ludus.resources">${escapeHtml(t('ludus.resources'))}`
      + '</h4>'
      + RESOURCES.map((res) => '<div class="ludus-resource-item">'
        + `<span class="ludus-res-emoji" aria-hidden="true">${res.emoji}`
        + '</span>'
        + `<span class="ludus-res-label">${escapeHtml(res.label)}</span>`
        + '<span class="ludus-res-val">'
        + `${escapeHtml(formatResource(resources[res.key]))}</span>`
        + '</div>').join('')
      + '</div>' : '';

    const gate = currentGateFor(form);
    const goalText = (state.playerNode && state.playerNode.causality
      && state.playerNode.causality.goal) || 'Redemption and wisdom';
    const gateText = gate ? gate.label
      : 'Not yet through the first gate';

    container.innerHTML = '<div class="ludus-profile-card">'
      + '<div class="ludus-hero">'
      + `<img class="ludus-hero-portrait" src="${ART}`
      + 'player-deacon-orarion.svg" alt="The deacon, the player\'s hero"'
      + ' width="100" height="140">'
      + '<h3 class="ludus-profile-title" data-i18n="ludus.profile">'
      + `${escapeHtml(t('ludus.profile'))}</h3>`
      + '</div>'
      + '<div class="ludus-attributes">'
      + '<h4 data-i18n="ludus.attributes">'
      + `${escapeHtml(t('ludus.attributes'))}</h4>`
      + attrHtml
      + '</div>'
      + resourceHtml
      + '<div class="ludus-causality">'
      + `<p><strong>Goal:</strong> ${escapeHtml(goalText)}</p>`
      + `<p><strong>Current gate:</strong> ${escapeHtml(gateText)}</p>`
      + '</div>'
      + '</div>';
  }

  // A node's display name: the id minus its type prefix.
  function nodeName(node) {
    const raw = String(node.nodeId || node.id || '');
    return raw.replace(/^(npc|quest)-/, '');
  }

  function renderReachableNodes() {
    const container = document.getElementById('ludus-network');
    if (!container) {
      return;
    }
    if (!state.playerForm) {
      container.innerHTML = '';
      return;
    }

    // Core mentors are always reachable: they are the ACTION half of
    // FORM -> ACTION -> GOAL, and a guest must be able to learn too.
    const coreHtml = MENTORS.map((m) => {
      const resonance = resonanceWith(m.profile, state.playerForm);
      const glow = resonance >= RESONANCE_GLOW ? ' is-resonant' : '';
      const pct = Math.round(resonance * 100);
      return '<div class="ludus-node-card'
      + ` ludus-mentor-card ludus-core-mentor${glow}"`
      + ` style="--resonance: ${resonance.toFixed(3)}">`
      + `<img class="ludus-mentor-portrait" src="${ART}${m.portrait}"`
      + ' alt="" width="100" height="140">'
      + `<h4>${escapeHtml(m.name)}</h4>`
      + `<p class="ludus-node-role">${escapeHtml(m.teaching)}</p>`
      + `<p class="ludus-resonance" title="Resonance of your FORM with`
      + ` this path">Resonance ${pct}%</p>`
      + '<button type="button" class="ludus-talk-btn" data-action="talk"'
      + ` data-npc-id="${escapeHtml(m.npcId)}">Talk with `
      + `${escapeHtml(m.name)}</button>`
      + '</div>';
    }).join('');

    if (state.mode !== 'online' || !state.user) {
      container.innerHTML = '<div class="ludus-network">'
        + '<section class="ludus-mentors">'
        + `<h3 data-i18n="ludus.mentor">${escapeHtml(t('ludus.mentor'))}`
        + `</h3><div class="ludus-mentor-grid">${coreHtml}</div>`
        + '</section></div>';
      return;
    }

    const mentors = state.reachableNodes
      .filter((n) => n.nodeType === 'npc' && n.depth === 1);
    const quests = state.reachableNodes.filter((n) => n.nodeType === 'quest');

    const mentorHtml = mentors.map((n) => {
      const causality = n.causality || {};
      return '<div class="ludus-node-card ludus-mentor-card">'
        + `<h4>${escapeHtml(nodeName(n))}</h4>`
        + `<p class="ludus-node-role">${escapeHtml(causality.form || 'NPC')}`
        + '</p>'
        + '<p class="ludus-node-goal">'
        + `${escapeHtml(causality.action || '...')}</p>`
        + '</div>';
    }).join('');

    const questHtml = quests.map((n) => {
      const causality = n.causality || {};
      return '<div class="ludus-node-card ludus-quest-card">'
        + `<h4>${escapeHtml(nodeName(n))}</h4>`
        + '<p>'
        + `${escapeHtml(causality.action || 'Complete this objective')}</p>`
        + '</div>';
    }).join('');

    container.innerHTML = '<div class="ludus-network">'
      + '<section class="ludus-mentors">'
      + `<h3 data-i18n="ludus.mentor">${escapeHtml(t('ludus.mentor'))}</h3>`
      + `<div class="ludus-mentor-grid">${coreHtml}${mentorHtml}</div>`
      + '</section>'
      + '<section class="ludus-quests">'
      + `<h3 data-i18n="ludus.quests">${escapeHtml(t('ludus.quests'))}</h3>`
      + (questHtml || '<p class="ludus-empty">No quests available</p>')
      + '</section>'
      + '</div>';
  }

  // The label of a timed practice.  While it runs it shows the time
  // left, so the player sees that only a whole session counts; a second
  // press stops it and nothing is recorded.
  function timerLabel(practice) {
    const run = state.practiceTimer;
    if (!run || run.id !== practice.id) {
      return `${practice.label}: ${practice.minutes} min`;
    }
    const left = Math.max(0, Math.ceil((run.endsAt - Date.now()) / 1000));
    const mm = Math.floor(left / 60);
    const ss = String(left % 60).padStart(2, '0');
    return `${practice.label}: ${mm}:${ss} (press to stop)`;
  }

  // One button of the rule.  Daily practices lock once kept today;
  // a secret good deed shows no number at all (Mt 6:3-4).
  function practiceButton(api, practice) {
    const today = localIsoDay();
    const kept = practice.kind === 'daily'
      && api.keptToday(state.actions, practice.id, today);
    const running = state.practiceTimer
      && state.practiceTimer.id === practice.id;
    const busy = state.practiceTimer && !running;
    const tally = api.practiceTally(state.actions, practice.id);
    let label = practice.label;
    if (practice.kind === 'timer') {
      label = timerLabel(practice);
    } else if (kept) {
      label = `${practice.label} — kept today`;
    }
    const title = `Against ${practice.passion}; ${practice.virtue}. `
      + `${practice.source}`;
    return '<div class="ludus-practice">'
      + `<button type="button" class="ludus-rule-btn${running
        ? ' is-running' : ''}" data-action="practice"`
      + ` data-practice-id="${escapeHtml(practice.id)}"`
      + ` title="${escapeHtml(title)}"`
      + (practice.kind === 'timer'
        ? ` aria-pressed="${running ? 'true' : 'false'}"` : '')
      + (kept || busy ? ' disabled' : '')
      + `>${escapeHtml(label)}</button>`
      + `<span class="ludus-practice-tally">${escapeHtml(tally.text)}</span>`
      + '</div>';
  }

  // The rule of prayer: twelve practices from LudusActions.PRACTICES.
  // Counters are shown plainly and never turn into points: TABOO 0.35
  // rule 16 forbids XP from prayer, so the panel says what was done and
  // nothing about what it "earned".
  function renderRulePanel(ladder) {
    const api = actionsApi();
    // The bow is offered only where every other condition already
    // holds and the lower gates are passed, so it can never be taken
    // for a shortcut past a missing step.
    const bows = ladder.filter((check) => check.readyForGift
      && check.missing.some((m) => m.kind === 'gift')
      && !check.missing.some((m) => m.kind === 'ladder'))
      .map((check) => '<button type="button"'
        + ' class="ludus-rule-btn ludus-bow-btn" data-action="bow"'
        + ` data-gate-id="${escapeHtml(check.gate.id)}">`
        + `Bow: not to me (${escapeHtml(check.gate.label)})</button>`)
      .join('');

    return '<section class="ludus-rule" aria-labelledby="ludus-rule-h">'
      + '<h4 id="ludus-rule-h">Rule of prayer</h4>'
      + '<div class="ludus-rule-actions ludus-practice-grid">'
      + api.PRACTICES.map((pr) => practiceButton(api, pr)).join('')
      + '</div>'
      + (bows ? `<div class="ludus-rule-actions">${bows}</div>` : '')
      + '</section>';
  }

  // The ladder is judged on three conditions (FORM, mentors met and a
  // rite), all of which live on the device for a guest, so it renders
  // offline too; Firestore gate questions are appended when they exist.
  function renderKnowledgeGates() {
    const container = document.getElementById('ludus-gates');
    if (!container) {
      return;
    }
    if (!state.playerForm) {
      container.innerHTML = '';
      return;
    }

    const api = actionsApi();
    if (!api || !state.actions) {
      container.innerHTML = '<div class="ludus-gates-panel">'
        + `<h3 data-i18n="ludus.gates">${escapeHtml(t('ludus.gates'))}</h3>`
        + '<p class="ludus-empty">The gates cannot be read right now.'
        + ' Please reload the page.</p></div>';
      return;
    }

    const ladder = api.evaluateLadder(state.playerForm, state.actions);
    const ladderHtml = ladder.map((check, index) => {
      const gate = check.gate;
      const open = check.open;
      const status = open ? 'Open'
        : '<ul class="ludus-gate-missing">'
          + check.missing.map((m) => '<li>'
            + `${escapeHtml(missingText(m))}</li>`).join('')
          + '</ul>';
      return `<li class="ludus-gate-step ${open ? 'is-open' : 'is-locked'}"`
        + ` data-gate-id="${escapeHtml(gate.id)}">`
        + `<img class="ludus-gate-icon" src="${ART}gate-${index + 1}-`
        + `${escapeHtml(gate.id)}.svg" alt="" width="48" height="48">`
        + `<span class="ludus-gate-level">${index + 1}</span>`
        + `<span class="ludus-gate-name">${escapeHtml(gate.label)}</span>`
        + `<div class="ludus-gate-status">${status}</div>`
        + '</li>';
    }).join('');

    const gateHtml = state.knowledgeGates.map((g) => {
      // Tier drives a CSS class, so only a small integer may pass.
      const tier = Math.max(1, Math.min(6, parseInt(g.tier, 10) || 1));
      return `<div class="ludus-gate-card ludus-tier-${tier}">`
        + `<h4>${escapeHtml(g.title || 'Knowledge Gate')}</h4>`
        + `<p class="ludus-gate-subject">${escapeHtml(g.subject || '—')}</p>`
        + '<p class="ludus-gate-question">'
        + `&ldquo;${escapeHtml(g.question || '')}&rdquo;</p>`
        + '<button type="button" class="ludus-gate-btn"'
        + ` data-action="open-gate" data-gate-id="${escapeHtml(g.id)}">`
        + 'Answer Question</button>'
        + '</div>';
    }).join('');

    container.innerHTML = '<div class="ludus-gates-panel">'
      + `<h3 data-i18n="ludus.gates">${escapeHtml(t('ludus.gates'))}</h3>`
      + `<ol class="ludus-gate-ladder">${ladderHtml}</ol>`
      + renderRulePanel(ladder)
      + gateHtml
      + '</div>';
  }

  function renderGameUI() {
    renderAuthPanel();
    renderPlayerProfile();
    renderReachableNodes();
    renderKnowledgeGates();
    announcePlayer();
  }

  // Other modules (dialogue, ROV) need the current FORM but must not
  // reach into this closure, so changes are broadcast as an event.
  function announcePlayer() {
    try {
      document.dispatchEvent(new CustomEvent('ludus:player-changed', {
        detail: {
          playerId: state.playerId,
          form: state.playerForm ? { ...state.playerForm } : null,
          mode: state.mode,
        },
      }));
    } catch (error) {
      console.warn('[Ludus] Could not announce player change:', error);
    }
  }

  function showError(message) {
    const errorBox = document.getElementById('ludus-error');
    if (!errorBox) {
      return;
    }
    errorBox.textContent = message;
    errorBox.hidden = false;
    // Restart the timer so a second error is not hidden early by the
    // first error's pending timeout.
    clearTimeout(state.errorTimer);
    state.errorTimer = setTimeout(() => {
      errorBox.hidden = true;
    }, 5000);
  }

  // Read the guest's saved FORM.  Only the seven attributes are taken,
  // and storage errors fall back to the seed minimum.
  function loadGuestForm() {
    const form = { ...GUEST_FORM };
    try {
      const saved = JSON.parse(
        window.localStorage.getItem(GUEST_FORM_KEY) || 'null');
      if (saved && typeof saved === 'object') {
        ATTRIBUTES.forEach((attr) => {
          const value = Number(saved[attr.key]);
          if (Number.isFinite(value) && value >= 1) {
            form[attr.key] = Math.min(ATTR_MAX, value);
          }
        });
      }
    } catch (error) {
      console.warn('[Ludus] Guest progress unavailable:', error.message);
    }
    return form;
  }

  function saveGuestForm() {
    try {
      window.localStorage.setItem(GUEST_FORM_KEY,
        JSON.stringify(state.playerForm));
    } catch (error) {
      // Private windows refuse storage; progress then lasts only for
      // this session, which is still better than failing the choice.
      console.warn('[Ludus] Guest progress not saved:', error.message);
    }
  }

  // Read the guest's saved ACTION counters.  normalize() keeps only the
  // known counters, so a hand-edited record cannot add new ones.
  function loadGuestActions() {
    let saved = null;
    try {
      saved = JSON.parse(
        window.localStorage.getItem(GUEST_ACTIONS_KEY) || 'null');
    } catch (error) {
      console.warn('[Ludus] Guest actions unavailable:', error.message);
    }
    return normalizeActions(saved);
  }

  function saveGuestActions() {
    try {
      window.localStorage.setItem(GUEST_ACTIONS_KEY,
        JSON.stringify(state.actions));
    } catch (error) {
      // As with FORM, a refused write keeps the counters for this
      // session only; the action itself must not fail.
      console.warn('[Ludus] Guest actions not saved:', error.message);
    }
  }

  // Store new counters, re-render what depends on them and tell other
  // modules (sound, analytics) what was done.  Nothing here adds to
  // FORM: an action is recorded and shown, never paid for.
  function commitActions(kind, next, op) {
    if (!next) {
      return;
    }
    if (op) {
      syncAction(op);
    }
    // Re-rendering replaces the buttons, so the focused one is noted
    // and focused again; a pointer or keyboard user keeps their place.
    const active = document.activeElement;
    const focusKey = active && active.getAttribute
      ? active.getAttribute('data-action') : null;
    const focusGate = focusKey ? active.getAttribute('data-gate-id') : null;
    const focusPractice = focusKey
      ? active.getAttribute('data-practice-id') : null;

    state.actions = next;
    if (state.formSource === 'guest') {
      saveGuestActions();
    }
    renderPlayerProfile();
    renderKnowledgeGates();

    if (focusKey) {
      const selector = `#ludus-gates [data-action="${focusKey}"]`
        + (focusGate ? `[data-gate-id="${focusGate}"]` : '')
        + (focusPractice ? `[data-practice-id="${focusPractice}"]` : '');
      let target = null;
      try {
        target = document.querySelector(selector);
      } catch (error) {
        target = null;
      }
      if (target && !target.disabled) {
        target.focus();
      }
    }
    try {
      document.dispatchEvent(new CustomEvent('ludus:action', {
        detail: { kind, actions: { ...state.actions } },
      }));
    } catch (error) {
      console.warn('[Ludus] Could not announce action:', error);
    }
  }

  // Signed-in players keep their rule in the database: every accepted
  // act is sent to /api/ludus/actions, which re-applies it with the same
  // rules, journals it and answers with the stored counters.  The local
  // state is shown at once; the server's answer then replaces it, so a
  // rejected act (for example a second vigil in the same ten minutes)
  // does not linger on screen.
  async function syncAction(op) {
    if (state.mode !== 'online' || !state.user) {
      return;
    }
    try {
      const token = await state.user.getIdToken();
      const res = await fetch('/api/ludus/actions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json',
          Authorization: `Bearer ${token}` },
        body: JSON.stringify(op),
      });
      const body = await res.json().catch(() => ({}));
      if (!res.ok) {
        showError(body.error || 'The rule could not be saved.');
      }
      if (body && body.actions) {
        state.actions = normalizeActions(body.actions);
        renderPlayerProfile();
        renderKnowledgeGates();
      }
    } catch (error) {
      console.warn('[Ludus] Action not saved:', error.message);
      showError('Offline: the rule is kept on screen until reload.');
    }
  }

  // Read a signed-in player's rule from the backend.  The client cannot
  // read ludus_players itself (the rules compare uid with the document
  // id, and ids are "player-<uid16>"), so the server answers for it.
  async function loadServerActions() {
    if (state.mode !== 'online' || !state.user) {
      return;
    }
    try {
      const token = await state.user.getIdToken();
      const res = await fetch('/api/ludus/actions', {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.ok) {
        const body = await res.json();
        state.actions = normalizeActions(body.actions);
        renderPlayerProfile();
        renderKnowledgeGates();
      }
    } catch (error) {
      console.warn('[Ludus] Could not load the rule:', error.message);
    }
  }

  // Run one ACTION through the pure LudusActions layer.
  function doAction(kind, id) {
    const api = actionsApi();
    if (!api || !state.actions || !state.playerForm) {
      showError('The rule of prayer is not available right now.');
      return;
    }
    if (kind === 'bow') {
      commitActions(kind, api.acceptGift(state.actions, state.playerForm, id),
        { op: 'acceptGift', gateId: id });
      return;
    }
    const practice = api.PRACTICES.find((p) => p.id === id);
    if (!practice) {
      return;
    }
    if (practice.kind === 'timer') {
      togglePracticeTimer(practice);
      return;
    }
    const day = localIsoDay();
    commitActions(practice.id, api.doPractice(state.actions, practice.id,
      { day }), { op: 'practice', id: practice.id, day });
  }

  function stopPracticeTimer() {
    if (state.practiceTimer) {
      clearInterval(state.practiceTimer.timer);
      state.practiceTimer = null;
    }
  }

  // Refresh only the running button's text each second.  Re-rendering
  // the panel would steal focus and flicker.
  function updateTimerButton(practice) {
    const button = document.querySelector('#ludus-gates [data-action='
      + `"practice"][data-practice-id="${practice.id}"]`);
    if (button) {
      button.textContent = timerLabel(practice);
      const running = Boolean(state.practiceTimer
        && state.practiceTimer.id === practice.id);
      button.setAttribute('aria-pressed', running ? 'true' : 'false');
      button.classList.toggle('is-running', running);
    }
  }

  // A timed practice counts only when it is completed: stopping early
  // records nothing, and while one runs the other timers wait.
  function togglePracticeTimer(practice) {
    if (state.practiceTimer) {
      const same = state.practiceTimer.id === practice.id;
      stopPracticeTimer();
      renderKnowledgeGates();
      if (same) {
        return;
      }
    }
    const endsAt = Date.now()
      + practice.minutes * PRACTICE_MINUTE_SECONDS * 1000;
    const timer = setInterval(() => {
      const run = state.practiceTimer;
      if (!run || Date.now() < run.endsAt) {
        updateTimerButton(practice);
        return;
      }
      stopPracticeTimer();
      const api = actionsApi();
      if (api && state.actions) {
        commitActions(practice.id, api.doPractice(state.actions,
          practice.id, { minutes: practice.minutes }),
          { op: 'practice', id: practice.id });
      }
    }, 1000);
    state.practiceTimer = { id: practice.id, endsAt, timer };
    renderKnowledgeGates();
  }

  // A dialogue choice is the only source of growth: its bonuses come
  // from the tree data, so FORM -> ACTION -> GOAL stays deterministic.
  function applyDialogueResult(result) {
    const bonuses = (result && result.attributeBonuses) || {};
    if (!state.playerForm || Object.keys(bonuses).length === 0) {
      return;
    }
    const next = { ...state.playerForm };
    ATTRIBUTES.forEach((attr) => {
      const bonus = Number(bonuses[attr.key]);
      if (Number.isFinite(bonus) && bonus > 0) {
        next[attr.key] = Math.min(ATTR_MAX, toScore(next[attr.key]) + bonus);
      }
    });
    state.playerForm = next;
    if (state.formSource === 'guest') {
      saveGuestForm();
    }
    renderPlayerProfile();
    renderReachableNodes();
    renderKnowledgeGates();
    announcePlayer();
  }

  async function talkTo(npcId) {
    const manager = window.LudusDialogueManager;
    const ui = window.LudusDialogueUI;
    if (!npcId || !manager || !ui || !state.playerForm) {
      showError('Dialogue is not available right now.');
      return;
    }
    // Guests have no server-side memory, so they are passed as null
    // and the manager skips the /memory request.
    const signedIn = state.mode === 'online' && state.user;
    manager.init(signedIn ? state.playerId : null, {
      getAuthToken: signedIn ? () => state.user.getIdToken() : null,
    });
    // The first choice taken in this conversation records the meeting,
    // even when it carries no bonus: a gate asks whether the player sat
    // with the mentor, not whether the talk paid in attributes.
    let met = false;
    const onChoice = (result) => {
      const api = actionsApi();
      if (!met && api && state.actions) {
        met = true;
        commitActions('meeting', api.recordMeeting(state.actions, npcId),
          { op: 'recordMeeting', npcId });
      }
      applyDialogueResult(result);
    };
    await ui.open(npcId, { ...state.playerForm }, onChoice);
  }

  // One delegated listener replaces the old inline onclick attributes,
  // which needed globals and would be blocked by a strict CSP.
  function bindListeners() {
    if (state.listenersBound) {
      return;
    }
    const root = document.getElementById('ludus-game-container')
      || document.body;
    root.addEventListener('click', (event) => {
      const target = event.target instanceof Element
        ? event.target.closest('[data-action]') : null;
      if (!target || !root.contains(target)) {
        return;
      }
      const action = target.getAttribute('data-action');
      if (action === 'signin') {
        signInWithGoogle();
      } else if (action === 'signout') {
        signOut();
      } else if (action === 'retry') {
        retry();
      } else if (action === 'talk') {
        talkTo(target.getAttribute('data-npc-id'));
      } else if (action === 'practice') {
        doAction('practice', target.getAttribute('data-practice-id'));
      } else if (action === 'bow') {
        doAction('bow', target.getAttribute('data-gate-id'));
      } else if (action === 'open-gate') {
        // The gate quiz lives in the dialogue layer; this module only
        // reports which gate the player chose.
        document.dispatchEvent(new CustomEvent('ludus:gate-selected', {
          detail: {
            gateId: target.getAttribute('data-gate-id'),
            playerId: state.playerId,
          },
        }));
      }
    });
    state.listenersBound = true;
  }

  function enterOffline(error) {
    state.mode = 'offline';
    state.offlineReason = error && error.code === 'ludus/unconfigured'
      ? 'unconfigured' : 'unreachable';
    state.auth = null;
    state.user = null;
    state.playerId = 'guest';
    state.playerNode = null;
    state.playerForm = loadGuestForm();
    state.formSource = 'guest';
    state.actions = loadGuestActions();
    state.reachableNodes = [];
    state.knowledgeGates = [];
    console.warn('[Ludus] Offline guest mode:', error && error.message);
    renderGameUI();
  }

  // Connect to Firebase, or fall back to guest mode.  Never rejects and
  // never waits longer than FIREBASE_LOAD_TIMEOUT_MS on the network.
  async function connect() {
    state.mode = 'loading';
    renderAuthPanel();
    try {
      await initFirebase();
    } catch (error) {
      enterOffline(error);
      return;
    }
    state.mode = 'online';
    state.playerForm = null;
    state.playerId = null;
    state.actions = null;
    stopPracticeTimer();
    renderGameUI();
    state.auth.onAuthStateChanged((user) => {
      setUser(user).catch((error) => {
        console.error('[Ludus] Player load error:', error);
        showError(t('ludus.error'));
      });
    });
  }

  async function retry() {
    if (state.mode === 'loading') {
      return;
    }
    await connect();
  }

  // Called once by index.html after DOMContentLoaded.
  async function init() {
    if (state.initialized) {
      return;
    }
    state.initialized = true;
    console.log('[Ludus] Initializing module...');
    bindListeners();
    await connect();
    console.log(`[Ludus] Module initialized (${state.mode})`);
  }

  window.__LudusModule = {
    init,
    signInWithGoogle,
    signOut,
    retry,
    getPlayerData: () => state.playerNode,
    getPlayerForm: () => (state.playerForm ? { ...state.playerForm } : null),
    getMode: () => state.mode,
    getActions: () => (state.actions ? { ...state.actions } : null),
    getReachableNodes: () => state.reachableNodes,
  };

  console.log('[Ludus] Module registered as window.__LudusModule');
})();
