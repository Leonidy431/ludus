/**
 * index.ts — Cloud Functions Entry Point
 *
 * Exports all Ludus API endpoints:
 *
 * Health & Monitoring:
 * - ludusHealth: Health check endpoint (public)
 * - ludusMetrics: Metrics endpoint (admin-only)
 *
 * Dialogue System:
 * - getDialogueTree: GET /api/ludus/dialogue/tree/{npcId}
 * - getNpcMemory: GET /api/ludus/dialogue/memory/{npcId}/{playerId}
 * - persistDialogueState: POST /api/ludus/dialogue/state
 * - getDialogueStats: GET /api/ludus/dialogue/stats/{playerId}
 * - upsertDialogueTree: POST /api/ludus/dialogue/tree/{npcId} (ADMIN)
 */

import * as admin from 'firebase-admin';

// Initialize Firebase Admin SDK
admin.initializeApp();

// Single entry point for the Hosting "/api/**" rewrite (firebase.json).
export { api } from './api/ludus-router';

// Export Cloud Functions - Health & Monitoring
export { ludusHealth, ludusMetrics } from './api/ludus-health';

// Export Cloud Functions - Dialogue System
export {
  getDialogueTree,
  getNpcMemory,
  persistDialogueState,
  getDialogueStats,
  upsertDialogueTree,
} from './api/ludus-dialogue';
