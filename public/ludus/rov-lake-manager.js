/**
 * ROV Lake Manager — Real-time Telemetry & Attribute Mapping
 *
 * Integrates VM8 Ludus backend telemetry with webtypicon2 ROV Lake tab.
 * Manages WebSocket subscriptions, telemetry buffering, attribute mapping,
 * and UI updates for live ROV dive metrics.
 *
 * Architecture:
 *  1. VM8 Backend Connection: IAP tunnel to ludus-api (10.20.0.2:3000)
 *  2. Telemetry Stream: Firestore real-time updates on ludus_telemetry collection
 *  3. Attribute Mapping: Depth/Velocity/Power → Wisdom/Dexterity/Constitution
 *  4. UI Rendering: Live attribute bars, telemetry readouts, status indicators
 */

'use strict';

(function () {
  const VM8_API = 'http://10.20.0.2:3000'; // IAP tunnel endpoint (from docs)
  const TELEMETRY_ENDPOINT = `${VM8_API}/api/ludus/telemetry`;
  const FIRESTORE_API = '/api/ludus/firestore'; // Proxy endpoint (if available)

  // ── State ────────────────────────────────────────────────────────────────
  let state = {
    playerId: null,
    isConnected: false,
    telemetryBuffer: [],
    currentTelemetry: null,
    mappedAttributes: {
      wisdom: 10,
      constitution: 10,
      dexterity: 10,
    },
    lastUpdate: null,
    unsubscribes: [],
  };

  // ── Telemetry mapping: Raw ROV values → D&D attributes ──────────────────
  const ATTRIBUTE_MAPPING = {
    // Depth (0-300m) → Wisdom (8-18)
    wisdom: {
      calculate: (telemetry) => {
        const depth = telemetry.depth || 0;
        return Math.min(18, Math.max(8, Math.floor(8 + (depth / 300) * 10)));
      },
      emoji: '🕯️',
      label: 'Wisdom',
    },
    // Power (0-1.0) → Constitution (8-18)
    constitution: {
      calculate: (telemetry) => {
        const power = telemetry.power || 0;
        return Math.min(18, Math.max(8, Math.floor(8 + power * 10)));
      },
      emoji: '❤️',
      label: 'Constitution',
    },
    // Velocity (0-5 m/s) → Dexterity (8-18)
    dexterity: {
      calculate: (telemetry) => {
        const velocity = telemetry.velocity || 0;
        return Math.min(18, Math.max(8, Math.floor(8 + (velocity / 5) * 10)));
      },
      emoji: '🤸',
      label: 'Dexterity',
    },
  };

  // ── Telemetry metrics (display format) ────────────────────────────────────
  const TELEMETRY_METRICS = [
    { key: 'depth', label: 'Depth', unit: 'm', emoji: '🌊', precision: 1 },
    { key: 'velocity', label: 'Velocity', unit: 'm/s', emoji: '⚡', precision: 2 },
    { key: 'power', label: 'Power', unit: '%', emoji: '⚙️', precision: 0, scale: 100 },
    { key: 'heading', label: 'Heading', unit: '°', emoji: '🧭', precision: 0 },
  ];

  // ── Connect to VM8 telemetry stream via Firestore subscription ───────────
  async function connectTelemetry(playerId, db) {
    if (!db) {
      console.warn('[ROVLake] Firestore not available, skipping telemetry subscription');
      return;
    }

    state.playerId = playerId;

    try {
      console.log('[ROVLake] Subscribing to telemetry for player:', playerId);

      // Subscribe to player's telemetry document in Firestore
      // Ludus backend writes to ludus_nodes/{playerId}/telemetry in real-time
      const unsubscribe = db.collection('ludus_nodes').doc(playerId)
        .onSnapshot(
          (doc) => {
            if (doc.exists) {
              const playerNode = doc.data();
              if (playerNode.telemetry) {
                handleTelemetryUpdate(playerNode.telemetry);
                state.isConnected = true;
                updateConnectionStatus(true);
              }
            }
          },
          (error) => {
            console.error('[ROVLake] Telemetry subscription error:', error);
            state.isConnected = false;
            updateConnectionStatus(false);
          }
        );

      state.unsubscribes.push(unsubscribe);
    } catch (error) {
      console.error('[ROVLake] Failed to connect telemetry:', error);
      state.isConnected = false;
      updateConnectionStatus(false);
    }
  }

  // ── Handle incoming telemetry update ─────────────────────────────────────
  function handleTelemetryUpdate(telemetry) {
    state.currentTelemetry = telemetry;
    state.lastUpdate = new Date();

    // Buffer telemetry for averaging (1-second window)
    state.telemetryBuffer.push(telemetry);
    if (state.telemetryBuffer.length > 30) { // 30 Hz × 1 second
      state.telemetryBuffer.shift();
    }

    // Calculate averaged telemetry
    const avgTelemetry = averageTelemetry(state.telemetryBuffer);

    // Map to D&D attributes
    mapAttributesFromTelemetry(avgTelemetry);

    // Update UI
    renderTelemetryReadout();
    renderAttributeMappings();
    renderStatus();
  }

  // ── Average telemetry buffer (1-second window) ───────────────────────────
  function averageTelemetry(buffer) {
    if (buffer.length === 0) return state.currentTelemetry || {};

    const avg = {};
    TELEMETRY_METRICS.forEach(({ key }) => {
      const values = buffer.map((t) => t[key] || 0);
      avg[key] = values.reduce((a, b) => a + b, 0) / values.length;
    });

    return avg;
  }

  // ── Map telemetry to D&D attributes ──────────────────────────────────────
  function mapAttributesFromTelemetry(telemetry) {
    Object.entries(ATTRIBUTE_MAPPING).forEach(([attrKey, { calculate }]) => {
      state.mappedAttributes[attrKey] = calculate(telemetry);
    });
  }

  // ── Format telemetry value for display ───────────────────────────────────
  function formatTelemetryValue(value, metric) {
    if (typeof value !== 'number') return '—';

    // Apply scale if defined (e.g., power: 0-1.0 → 0-100%)
    const scaled = metric.scale ? value * metric.scale : value;
    return scaled.toFixed(metric.precision);
  }

  // ── Render telemetry readout (depth, velocity, power, heading) ──────────
  function renderTelemetryReadout() {
    const container = document.getElementById('rov-telemetry');
    if (!container || !state.currentTelemetry) return;

    const telemetryHtml = TELEMETRY_METRICS.map(({ key, label, unit, emoji, precision, scale }) => {
      const value = state.currentTelemetry[key] || 0;
      const formatted = formatTelemetryValue(value, { precision, scale });

      return `
        <div class="rov-metric">
          <span class="rov-metric-emoji">${emoji}</span>
          <span class="rov-metric-label">${label}</span>
          <span class="rov-metric-value">${formatted} <span class="rov-metric-unit">${unit}</span></span>
        </div>
      `;
    }).join('');

    const lastUpdateTime = state.lastUpdate ? state.lastUpdate.toLocaleTimeString() : '—';

    container.innerHTML = `
      <div class="rov-telemetry-panel">
        <h3>🌊 ROV Telemetry</h3>
        <div class="rov-metrics-grid">
          ${telemetryHtml}
        </div>
        <p class="rov-timestamp">Last update: ${lastUpdateTime}</p>
      </div>
    `;
  }

  // ── Render attribute mappings (how telemetry maps to D&D stats) ─────────
  function renderAttributeMappings() {
    const container = document.getElementById('rov-attribute-mapping');
    if (!container) return;

    const mappingHtml = Object.entries(ATTRIBUTE_MAPPING).map(([key, { emoji, label }]) => {
      const value = state.mappedAttributes[key] || 10;
      const pct = (value / 20) * 100;

      let sourceMetric = '';
      if (key === 'wisdom') {
        sourceMetric = `${state.currentTelemetry?.depth || 0}m depth`;
      } else if (key === 'constitution') {
        sourceMetric = `${(state.currentTelemetry?.power || 0).toFixed(2)} power`;
      } else if (key === 'dexterity') {
        sourceMetric = `${state.currentTelemetry?.velocity || 0} m/s velocity`;
      }

      return `
        <div class="rov-attr-mapping">
          <div class="rov-attr-header">
            <span class="rov-attr-emoji">${emoji}</span>
            <span class="rov-attr-label">${label}</span>
            <span class="rov-attr-value">${value.toFixed(1)} / 20</span>
          </div>
          <div class="rov-attr-bar-container">
            <div class="rov-attr-bar" style="--pct: ${pct}%">
              <div class="rov-attr-bar-fill"></div>
            </div>
          </div>
          <p class="rov-attr-source">← From: ${sourceMetric}</p>
        </div>
      `;
    }).join('');

    container.innerHTML = `
      <div class="rov-attribute-mapping-panel">
        <h3>📊 Attribute Mapping</h3>
        <p class="rov-mapping-desc">How ROV telemetry affects your D&D attributes</p>
        <div class="rov-mappings">
          ${mappingHtml}
        </div>
      </div>
    `;
  }

  // ── Update connection status indicator ────────────────────────────────────
  function updateConnectionStatus(connected) {
    const statusEl = document.getElementById('rov-connection-status');
    if (!statusEl) return;

    const statusClass = connected ? 'connected' : 'disconnected';
    const statusText = connected ? '🟢 Connected' : '🔴 Disconnected';

    statusEl.className = `rov-status-indicator ${statusClass}`;
    statusEl.textContent = statusText;
  }

  // ── Render status panel ──────────────────────────────────────────────────
  function renderStatus() {
    const container = document.getElementById('rov-status');
    if (!container) return;

    const statusHtml = `
      <div class="rov-status-panel">
        <div class="rov-status-header">
          <h3>Status</h3>
          <div id="rov-connection-status" class="rov-status-indicator ${state.isConnected ? 'connected' : 'disconnected'}">
            ${state.isConnected ? '🟢 Connected' : '🔴 Disconnected'}
          </div>
        </div>
        <div class="rov-status-info">
          <p><strong>Player:</strong> ${state.playerId || '—'}</p>
          <p><strong>Last Update:</strong> ${state.lastUpdate ? state.lastUpdate.toLocaleTimeString() : '—'}</p>
          <p><strong>Buffer Size:</strong> ${state.telemetryBuffer.length} samples</p>
        </div>
      </div>
    `;

    container.innerHTML = statusHtml;
  }

  // ── Disconnect and cleanup ───────────────────────────────────────────────
  function disconnect() {
    state.unsubscribes.forEach((unsubscribe) => {
      if (typeof unsubscribe === 'function') unsubscribe();
    });
    state.unsubscribes = [];
    state.isConnected = false;
    updateConnectionStatus(false);
    console.log('[ROVLake] Disconnected from telemetry stream');
  }

  // ── Public API ───────────────────────────────────────────────────────────
  window.__ROVLakeManager = {
    connect: connectTelemetry,
    disconnect,
    getTelemetry: () => state.currentTelemetry,
    getAttributes: () => state.mappedAttributes,
    isConnected: () => state.isConnected,
    renderTelemetry: renderTelemetryReadout,
    renderAttributes: renderAttributeMappings,
    renderStatus,
  };

  console.log('[ROVLake] Manager registered as window.__ROVLakeManager');
})();
