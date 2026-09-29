/**
 * ROV Lake Manager: live dive telemetry for the Meta Quest 3 build.
 *
 * The ROV (DiveComputer) writes its latest sample into the player's
 * Firestore node (ludus_nodes/{playerId}.telemetry).  This module
 * subscribes to that node, shows depth, temperature and pressure in
 * physical units, and derives ONE deterministic consequence from it:
 * a Wisdom observation bonus that grows with depth (CLAUDE.md, section
 * C: "depth -> Wisdom bonus for observation").
 *
 * Demiurgic Causality: FORM (the telemetry the player produced by
 * diving) -> ACTION (observing at depth) -> GOAL (a Wisdom insight and
 * a short lesson about the water layer the ROV is in).  There is no
 * randomness anywhere in this file.
 *
 * Public API (window.__ROVLakeManager) keeps the historical names:
 * connect, disconnect, getTelemetry, getAttributes, isConnected,
 * renderTelemetry, renderAttributes, renderStatus.  getInsight is new.
 */

'use strict';

(function () {
  // The panel lives in the container that index.html reserves for it.
  // The older ids (#rov-telemetry etc.) never existed in this build, so
  // nothing used to render at all.
  const ROOT_ID = 'ludus-rov-container';

  // A sample older than this is shown as stale.  The backend posts at
  // 1 Hz, so five missed posts means the dive link is really down.
  const STALE_AFTER_MS = 5000;

  // Hydrostatic pressure in a fresh-water lake: rho * g = 1000 * 9.81
  // Pa per metre = 0.0981 bar/m, on top of one standard atmosphere.
  // Issyk-Kul is slightly saline (about 6 g/L), which changes the
  // result by less than one percent, so fresh water is close enough.
  const SURFACE_PRESSURE_BAR = 1.01325;
  const BAR_PER_METRE = 0.0981;

  // No lake reachable by the ROV exceeds about 700 m (70 bar), so an
  // untyped "pressure" above this threshold must have been sent in kPa.
  const KPA_THRESHOLD = 100;

  // Each depth threshold crossed adds +1 Wisdom, giving +0..+5, the
  // same range the dialogue system uses for a single deep choice.
  // Bands, not a formula, so the player can learn where the next
  // insight lies.
  const WISDOM_DEPTH_BANDS_M = [30, 60, 120, 200, 300];

  // Water layers of a temperate lake.  Below the thermocline the water
  // settles near 4 degC, where fresh water is densest; the lesson for
  // each layer follows the spiritual path from the surface inwards.
  const WATER_LAYERS = [
    {
      maxC: 4.5,
      name: 'Hypolimnion',
      lesson: 'Cold, still water that does not move with the wind: '
        + 'the stillness of hesychia (Isaac the Syrian).',
    },
    {
      maxC: 15,
      name: 'Thermocline',
      lesson: 'A boundary where warmth gives way to depth: the soul '
        + 'passing from the senses to the heart (Gregory of Nyssa).',
    },
    {
      maxC: Infinity,
      name: 'Epilimnion',
      lesson: 'Sunlit surface water, stirred by every breeze: the '
        + 'beginning of the path, where attention is still scattered.',
    },
  ];

  // Readouts in display order.  "digits" is fixed so values do not
  // jitter in width while the ROV moves.
  const METRICS = [
    { key: 'depth', label: 'Depth', unit: 'm', digits: 1 },
    { key: 'temperature', label: 'Temperature', unit: '°C',
      digits: 1 },
    { key: 'pressure', label: 'Pressure', unit: 'bar', digits: 2 },
    { key: 'velocity', label: 'Velocity', unit: 'm/s', digits: 2 },
    { key: 'power', label: 'Power', unit: '%', digits: 0 },
    { key: 'heading', label: 'Heading', unit: '°', digits: 0 },
  ];

  const state = {
    playerId: null,
    isConnected: false,
    currentTelemetry: null,
    lastUpdate: null,
    insight: { attribute: 'wisdom', bonus: 0, depth: null },
    unsubscribes: [],
    staleTimer: null,
    rafId: null,
    dom: null,
    offlineReason: 'waiting for the game to start.',
    lastPlayerDetail: null,
  };

  // Firestore data is written by devices and other clients, so every
  // field is untrusted: only finite numbers are accepted.  Strings are
  // refused rather than parsed, which also keeps markup out of the UI.
  function finiteOrNull(value) {
    return typeof value === 'number' && Number.isFinite(value)
      ? value
      : null;
  }

  function firstFinite(raw, keys) {
    for (const key of keys) {
      const value = finiteOrNull(raw[key]);
      if (value !== null) {
        return value;
      }
    }
    return null;
  }

  // The Unity bridge posts "lastDepth"-style keys while the emulator
  // posts plain "depth"; both shapes are folded into one here.
  function normaliseTelemetry(raw) {
    if (!raw || typeof raw !== 'object') {
      return null;
    }
    const depth = firstFinite(raw, ['depth', 'lastDepth']);
    const out = {
      depth: depth === null ? null : Math.max(0, depth),
      temperature: firstFinite(raw, ['temperature', 'temp',
        'lastTemperature']),
      velocity: firstFinite(raw, ['velocity', 'lastVelocity']),
      heading: firstFinite(raw, ['heading', 'lastHeading']),
      power: null,
      pressure: null,
      pressureDerived: false,
    };

    // Power arrives as a 0..1 fraction and is shown as a percentage.
    const power = firstFinite(raw, ['power', 'lastPower']);
    if (power !== null) {
      out.power = Math.min(1, Math.max(0, power)) * 100;
    }

    if (out.heading !== null) {
      out.heading = ((out.heading % 360) + 360) % 360;
    }

    const kpa = firstFinite(raw, ['pressureKpa']);
    const untyped = firstFinite(raw, ['pressure', 'pressureBar']);
    if (kpa !== null) {
      out.pressure = kpa / 100;
    } else if (untyped !== null) {
      out.pressure = untyped > KPA_THRESHOLD ? untyped / 100 : untyped;
    } else if (out.depth !== null) {
      // Without a sensor value the pressure is still known from depth,
      // but it is marked so the player can tell measured from derived.
      out.pressure = SURFACE_PRESSURE_BAR + out.depth * BAR_PER_METRE;
      out.pressureDerived = true;
    }

    const hasAny = METRICS.some(({ key }) => out[key] !== null);
    return hasAny ? out : null;
  }

  function wisdomBonusForDepth(depth) {
    if (depth === null) {
      return 0;
    }
    return WISDOM_DEPTH_BANDS_M.filter((band) => depth >= band).length;
  }

  function nextBandForDepth(depth) {
    const current = depth === null ? 0 : depth;
    const next = WISDOM_DEPTH_BANDS_M.find((band) => current < band);
    return next === undefined ? null : next;
  }

  function layerForTemperature(temperature) {
    if (temperature === null) {
      return null;
    }
    return WATER_LAYERS.find((layer) => temperature <= layer.maxC);
  }

  function formatValue(value, digits) {
    return value === null ? '—' : value.toFixed(digits);
  }

  // ── DOM ────────────────────────────────────────────────────────────

  // Small helper so the whole panel is built with textContent only;
  // no telemetry or player id ever passes through innerHTML.
  function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) {
      node.className = className;
    }
    if (text !== undefined) {
      node.textContent = text;
    }
    return node;
  }

  // The panel is built once and later updated in place.  Rebuilding it
  // at the 30 Hz sample rate would thrash layout on the Quest browser.
  function ensurePanel() {
    const root = document.getElementById(ROOT_ID);
    if (!root) {
      return null;
    }
    if (state.dom && root.contains(state.dom.panel)) {
      return state.dom;
    }

    const panel = el('section', 'rov-lake-tab');
    panel.setAttribute('aria-labelledby', 'rov-lake-title');

    const telemetry = el('div', 'rov-telemetry-panel');
    const title = el('h3', null, 'ROV Lake telemetry');
    title.id = 'rov-lake-title';
    telemetry.appendChild(title);

    const grid = el('dl', 'rov-metrics-grid');
    const values = {};
    METRICS.forEach(({ key, label, unit }) => {
      const cell = el('div', 'rov-metric');
      cell.dataset.metric = key;
      cell.appendChild(el('dt', 'rov-metric-label', label));
      const dd = el('dd', 'rov-metric-value');
      const number = el('span', 'rov-metric-number', '—');
      dd.appendChild(number);
      dd.appendChild(el('span', 'rov-metric-unit', unit));
      cell.appendChild(dd);
      grid.appendChild(cell);
      values[key] = number;
    });
    telemetry.appendChild(grid);

    const empty = el('p', 'rov-empty');
    telemetry.appendChild(empty);
    const timestamp = el('p', 'rov-timestamp');
    telemetry.appendChild(timestamp);

    const insight = el('div', 'rov-attribute-mapping-panel');
    insight.appendChild(el('h3', null, 'Observation insight'));
    insight.appendChild(el('p', 'rov-mapping-desc',
      'Depth → Wisdom: each depth band reached while observing '
      + 'adds +1 Wisdom (up to +5).'));
    const row = el('div', 'rov-attr-mapping');
    const header = el('div', 'rov-attr-header');
    header.appendChild(el('span', 'rov-attr-label', 'Wisdom'));
    const bonus = el('span', 'rov-attr-value', '+0');
    header.appendChild(bonus);
    row.appendChild(header);

    const bar = el('div', 'rov-attr-bar-container');
    bar.setAttribute('role', 'meter');
    bar.setAttribute('aria-label', 'Wisdom observation bonus');
    bar.setAttribute('aria-valuemin', '0');
    bar.setAttribute('aria-valuemax', String(WISDOM_DEPTH_BANDS_M.length));
    bar.setAttribute('aria-valuenow', '0');
    const fill = el('div', 'rov-attr-bar');
    bar.appendChild(fill);
    row.appendChild(bar);

    const source = el('p', 'rov-attr-source');
    row.appendChild(source);
    insight.appendChild(row);
    const lesson = el('p', 'rov-lesson');
    insight.appendChild(lesson);

    const status = el('div', 'rov-status-panel');
    const statusHeader = el('div', 'rov-status-header');
    statusHeader.appendChild(el('h3', null, 'Dive link'));
    const indicator = el('div', 'rov-status-indicator disconnected',
      'Disconnected');
    indicator.id = 'rov-connection-status';
    // Only the link state is announced; the numbers change many times
    // a second and would drown a screen reader.
    indicator.setAttribute('role', 'status');
    indicator.setAttribute('aria-live', 'polite');
    statusHeader.appendChild(indicator);
    status.appendChild(statusHeader);
    const info = el('div', 'rov-status-info');
    const player = el('p');
    const age = el('p');
    info.appendChild(player);
    info.appendChild(age);
    status.appendChild(info);

    panel.appendChild(telemetry);
    panel.appendChild(insight);
    panel.appendChild(status);
    root.replaceChildren(panel);

    state.dom = {
      panel, values, empty, timestamp, bonus, bar, fill, source, lesson,
      indicator, player, age,
    };
    return state.dom;
  }

  function render() {
    state.rafId = null;
    const dom = ensurePanel();
    if (!dom) {
      return;
    }
    const t = state.currentTelemetry;
    const stale = isStale();

    METRICS.forEach(({ key, digits }) => {
      dom.values[key].textContent = formatValue(t ? t[key] : null, digits);
    });
    const pressureCell = dom.values.pressure.parentNode;
    pressureCell.title = t && t.pressureDerived
      ? 'Derived from depth (fresh water, 0.0981 bar/m + 1 atm)'
      : '';
    dom.values.pressure.textContent = (t && t.pressureDerived ? '≈'
      : '') + dom.values.pressure.textContent;

    dom.panel.classList.toggle('rov-stale', Boolean(t) && stale);
    dom.panel.classList.toggle('rov-no-data', !t);
    dom.empty.hidden = Boolean(t);
    dom.empty.textContent = state.isConnected || state.playerId
      ? 'No telemetry yet. Start a dive on the headset to see live data.'
      : 'Telemetry unavailable: ' + state.offlineReason;
    dom.timestamp.textContent = state.lastUpdate
      ? 'Last sample: ' + state.lastUpdate.toLocaleTimeString()
      : '';

    const { bonus, depth } = state.insight;
    const max = WISDOM_DEPTH_BANDS_M.length;
    dom.bonus.textContent = '+' + bonus + ' / +' + max;
    dom.bar.setAttribute('aria-valuenow', String(bonus));
    dom.fill.style.setProperty('--pct', (bonus / max) * 100 + '%');
    const next = nextBandForDepth(depth);
    const depthText = depth === null
      ? 'no depth reading'
      : depth.toFixed(1) + ' m';
    dom.source.textContent = 'From depth: ' + depthText
      + (next === null ? ' (deepest band reached)'
        : ' · next insight at ' + next + ' m');

    const layer = layerForTemperature(t ? t.temperature : null);
    dom.lesson.hidden = !layer;
    dom.lesson.textContent = layer ? layer.name + ': ' + layer.lesson : '';

    updateConnectionStatus(state.isConnected && !stale);
    dom.player.textContent = 'Player: ' + (state.playerId || '—');
    dom.age.textContent = state.lastUpdate
      ? 'Sample age: ' + Math.round(sampleAgeMs() / 1000) + ' s'
        + (stale ? ' (stale)' : '')
      : 'Sample age: —';
  }

  // Samples can arrive at 30 Hz; the panel only needs one paint per
  // frame, so renders are coalesced into a single animation frame.
  function scheduleRender() {
    if (state.rafId !== null) {
      return;
    }
    if (typeof window.requestAnimationFrame === 'function') {
      state.rafId = window.requestAnimationFrame(render);
    } else {
      render();
    }
  }

  function sampleAgeMs() {
    return state.lastUpdate ? Date.now() - state.lastUpdate.getTime() : 0;
  }

  function isStale() {
    return Boolean(state.lastUpdate) && sampleAgeMs() > STALE_AFTER_MS;
  }

  function updateConnectionStatus(connected) {
    const indicator = state.dom && state.dom.indicator;
    if (!indicator) {
      return;
    }
    let text = 'Disconnected';
    if (connected) {
      text = 'Connected';
    } else if (state.isConnected) {
      text = 'Signal lost';
    }
    // Writing the same text again would re-announce it every second.
    if (indicator.textContent !== text) {
      indicator.textContent = text;
    }
    indicator.className = 'rov-status-indicator '
      + (connected ? 'connected' : 'disconnected');
  }

  // ── Telemetry ──────────────────────────────────────────────────────

  function handleTelemetryUpdate(raw) {
    const telemetry = normaliseTelemetry(raw);
    if (!telemetry) {
      return;
    }
    state.currentTelemetry = telemetry;
    state.lastUpdate = new Date();

    const bonus = wisdomBonusForDepth(telemetry.depth);
    const changed = bonus !== state.insight.bonus;
    state.insight = { attribute: 'wisdom', bonus, depth: telemetry.depth };
    if (changed) {
      // The game core owns the player's FORM; this module only reports
      // the insight so the award is applied (and saved) in one place.
      document.dispatchEvent(new CustomEvent('ludus:rov-insight', {
        detail: { ...state.insight },
      }));
    }
    scheduleRender();
  }

  function startStaleTimer() {
    stopStaleTimer();
    // Staleness depends on time passing without samples, so it needs
    // its own clock; it is cleared in disconnect() and on pagehide.
    state.staleTimer = window.setInterval(scheduleRender, 1000);
  }

  function stopStaleTimer() {
    if (state.staleTimer !== null) {
      window.clearInterval(state.staleTimer);
      state.staleTimer = null;
    }
  }

  async function connectTelemetry(playerId, db) {
    // A second connect (new sign-in) must not leave the previous
    // listener alive, or two players' samples would interleave.
    disconnect();
    state.playerId = typeof playerId === 'string' ? playerId : null;

    if (!db || typeof db.collection !== 'function' || !state.playerId) {
      state.offlineReason = 'no connection to the game server.';
      console.warn('[ROVLake] Firestore not available; panel stays idle');
      scheduleRender();
      return;
    }

    try {
      const unsubscribe = db.collection('ludus_nodes').doc(state.playerId)
        .onSnapshot(
          (doc) => {
            state.isConnected = true;
            const node = doc && doc.exists ? doc.data() : null;
            if (node && node.telemetry) {
              handleTelemetryUpdate(node.telemetry);
            } else {
              scheduleRender();
            }
          },
          (error) => {
            console.error('[ROVLake] Telemetry subscription error:',
              error && error.message);
            state.isConnected = false;
            state.offlineReason = 'the telemetry stream was refused.';
            scheduleRender();
          },
        );
      state.unsubscribes.push(unsubscribe);
      startStaleTimer();
    } catch (error) {
      console.error('[ROVLake] Failed to connect telemetry:',
        error && error.message);
      state.isConnected = false;
      state.offlineReason = 'the telemetry stream could not start.';
    }
    scheduleRender();
  }

  function disconnect() {
    state.unsubscribes.forEach((unsubscribe) => {
      if (typeof unsubscribe === 'function') {
        try {
          unsubscribe();
        } catch (error) {
          console.warn('[ROVLake] Unsubscribe failed:', error);
        }
      }
    });
    state.unsubscribes = [];
    stopStaleTimer();
    if (state.rafId !== null) {
      window.cancelAnimationFrame(state.rafId);
      state.rafId = null;
    }
    const wasConnected = state.isConnected;
    state.isConnected = false;
    updateConnectionStatus(false);
    if (wasConnected) {
      console.log('[ROVLake] Disconnected from telemetry stream');
    }
  }

  // The game core announces sign-in, sign-out and offline mode with
  // this event instead of exposing its Firestore handle, so the panel
  // follows the same player the rest of the game is showing.
  function onPlayerChanged(event) {
    const detail = (event && event.detail) || {};
    state.lastPlayerDetail = detail;
    const firebase = window.firebase;
    const online = detail.mode === 'online' && firebase
      && firebase.apps && firebase.apps.length > 0
      && typeof firebase.firestore === 'function';

    if (online && detail.playerId) {
      // The game core re-announces on every render; resubscribing each
      // time would churn Firestore listeners for the same player.
      const subscribed = state.unsubscribes.length > 0;
      if (detail.playerId !== state.playerId || !subscribed) {
        connectTelemetry(detail.playerId, firebase.firestore());
      }
      return;
    }
    disconnect();
    state.playerId = null;
    state.currentTelemetry = null;
    state.lastUpdate = null;
    state.insight = { attribute: 'wisdom', bonus: 0, depth: null };
    state.offlineReason = detail.mode === 'offline'
      ? 'offline guest mode (no dive link).'
      : 'sign in to link the ROV.';
    scheduleRender();
  }

  document.addEventListener('ludus:player-changed', onPlayerChanged);
  window.addEventListener('pagehide', disconnect);
  // A page restored from the back/forward cache keeps this closure but
  // lost its listener on pagehide, so the last known player is replayed.
  window.addEventListener('pageshow', (event) => {
    if (event.persisted && state.lastPlayerDetail) {
      state.playerId = null;
      onPlayerChanged({ detail: state.lastPlayerDetail });
    }
  });

  // Draw the empty state at once so the container is never a blank gap
  // while the game core is still loading or has fallen back offline.
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', scheduleRender,
      { once: true });
  } else {
    scheduleRender();
  }

  // ── Public API ─────────────────────────────────────────────────────
  window.__ROVLakeManager = {
    connect: connectTelemetry,
    disconnect,
    getTelemetry: () => (state.currentTelemetry
      ? { ...state.currentTelemetry }
      : null),
    // Historically this returned absolute scores that overwrote the
    // FORM; it now returns only the earned observation bonus, because
    // attributes change through choices, not by raw sensor readings.
    getAttributes: () => ({ wisdom: state.insight.bonus }),
    getInsight: () => ({ ...state.insight }),
    isConnected: () => state.isConnected,
    renderTelemetry: scheduleRender,
    renderAttributes: scheduleRender,
    renderStatus: scheduleRender,
  };

  console.log('[ROVLake] Manager registered as window.__ROVLakeManager');
})();
