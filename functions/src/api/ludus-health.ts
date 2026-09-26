/**
 * Ludus Health Check Endpoint — /api/ludus/health
 *
 * Monitors infrastructure readiness for Ludus Protocol game:
 * - Firestore collections (ludus_nodes, ludus_edges, ludus_knowledge_gates)
 * - Seed data initialization (min nodes, edges, gates)
 * - DemiurgeSimulator performance (last cycle duration)
 * - Player data availability (active player count)
 *
 * Response: { status: "ok"|"degraded"|"down", components: {...}, timestamp: ISO8601 }
 *
 * Used by: CI/CD health checks, load balancers, monitoring dashboards.
 */

import * as functions from 'firebase-functions';
import { getFirestore, Timestamp, FieldValue } from 'firebase-admin/firestore';

interface HealthCheckResponse {
  status: 'ok' | 'degraded' | 'down';
  timestamp: string;
  components: {
    firestore: {
      status: 'ok' | 'error';
      nodeCount: number;
      edgeCount: number;
      gateCount: number;
      message?: string;
    };
    seed_data: {
      status: 'ok' | 'warning';
      playerCount: number;
      npcCount: number;
      expectedPlayers: number;
      expectedNpcs: number;
      message?: string;
    };
    simulation: {
      status: 'ok' | 'slow';
      lastCycleDurationMs: number;
      cycleCountSinceInit: number;
      targetCycleDurationMs: number;
      message?: string;
    };
  };
  uptime_seconds?: number;
}

const HEALTH_CHECK_COUNTERS = {
  START_TIME: Date.now(),
  CHECKS_PASSED: 0,
  CHECKS_FAILED: 0,
};

/**
 * Health check endpoint: Verify Ludus collections + seed data + performance.
 */
export const ludusHealth = functions.https.onRequest(async (req, res) => {
  try {
    const db = getFirestore();
    const response: HealthCheckResponse = {
      status: 'ok',
      timestamp: new Date().toISOString(),
      components: {
        firestore: { status: 'ok', nodeCount: 0, edgeCount: 0, gateCount: 0 },
        seed_data: {
          status: 'ok',
          playerCount: 0,
          npcCount: 0,
          expectedPlayers: 5,
          expectedNpcs: 20,
        },
        simulation: {
          status: 'ok',
          lastCycleDurationMs: 0,
          cycleCountSinceInit: 0,
          targetCycleDurationMs: 8,
        },
      },
      uptime_seconds: Math.round((Date.now() - HEALTH_CHECK_COUNTERS.START_TIME) / 1000),
    };

    // ────────────────────────────────────────────────────────────────────────
    // Component 1: Firestore Collection Availability
    // ────────────────────────────────────────────────────────────────────────

    try {
      const [nodeSnaps, edgeSnaps, gateSnaps] = await Promise.all([
        db.collection('ludus_nodes').limit(1).get(),
        db.collection('ludus_edges').limit(1).get(),
        db.collection('ludus_knowledge_gates').limit(1).get(),
      ]);

      // Count documents (expensive query, but cached)
      const nodeCount = await countCollection(db, 'ludus_nodes');
      const edgeCount = await countCollection(db, 'ludus_edges');
      const gateCount = await countCollection(db, 'ludus_knowledge_gates');

      response.components.firestore = {
        status: 'ok',
        nodeCount,
        edgeCount,
        gateCount,
      };

      // Warn if collections are empty
      if (nodeCount === 0 || edgeCount === 0) {
        response.components.firestore.status = 'error';
        response.components.firestore.message = 'Collections not initialized. Run seedDemiurgeData.ts.';
        response.status = 'down';
      }
    } catch (error) {
      response.components.firestore.status = 'error';
      response.components.firestore.message = `Firestore error: ${error instanceof Error ? error.message : String(error)}`;
      response.status = 'down';
      HEALTH_CHECK_COUNTERS.CHECKS_FAILED++;
    }

    // ────────────────────────────────────────────────────────────────────────
    // Component 2: Seed Data Verification
    // ────────────────────────────────────────────────────────────────────────

    try {
      const playerSnaps = await db.collection('ludus_nodes')
        .where('nodeType', '==', 'player')
        .limit(100)
        .get();

      const npcSnaps = await db.collection('ludus_nodes')
        .where('nodeType', '==', 'npc')
        .limit(100)
        .get();

      const playerCount = playerSnaps.size;
      const npcCount = npcSnaps.size;

      response.components.seed_data = {
        status: 'ok',
        playerCount,
        npcCount,
        expectedPlayers: 5,
        expectedNpcs: 20,
      };

      // Warn if seed data is incomplete
      if (playerCount < 5 || npcCount < 20) {
        response.components.seed_data.status = 'warning';
        response.components.seed_data.message =
          `Incomplete seed data: ${playerCount} players (expected 5), ${npcCount} NPCs (expected 20)`;
        if (response.status === 'ok') {
          response.status = 'degraded';
        }
      }
    } catch (error) {
      response.components.seed_data.status = 'warning';
      response.components.seed_data.message = `Seed data check failed: ${error instanceof Error ? error.message : String(error)}`;
      if (response.status === 'ok') {
        response.status = 'degraded';
      }
    }

    // ────────────────────────────────────────────────────────────────────────
    // Component 3: Simulation Performance
    // ────────────────────────────────────────────────────────────────────────

    try {
      const healthSnaps = await db.collection('ludus_health_checks')
        .orderBy('timestamp', 'desc')
        .limit(1)
        .get();

      if (!healthSnaps.empty) {
        const latestHealth = healthSnaps.docs[0].data();
        const cycleDuration = latestHealth.avgSimulationCycleMs || 0;

        response.components.simulation = {
          status: cycleDuration <= 8 ? 'ok' : 'slow',
          lastCycleDurationMs: cycleDuration,
          cycleCountSinceInit: latestHealth.cycleCount || 0,
          targetCycleDurationMs: 8,
        };

        if (cycleDuration > 10) {
          response.components.simulation.message =
            `Simulation slow: ${cycleDuration}ms (target 8ms). Check node/edge count.`;
          if (response.status === 'ok') {
            response.status = 'degraded';
          }
        }
      } else {
        response.components.simulation = {
          status: 'ok',
          lastCycleDurationMs: 0,
          cycleCountSinceInit: 0,
          targetCycleDurationMs: 8,
          message: 'No health checks recorded yet. Demiurge may not have run.',
        };
      }
    } catch (error) {
      response.components.simulation.status = 'ok';
      response.components.simulation.message = `Could not retrieve simulation metrics: ${error instanceof Error ? error.message : String(error)}`;
    }

    // ────────────────────────────────────────────────────────────────────────
    // Response
    // ────────────────────────────────────────────────────────────────────────

    // Set HTTP status based on health status
    const httpStatus = response.status === 'ok' ? 200 : response.status === 'degraded' ? 503 : 503;

    res.status(httpStatus).json(response);

    if (response.status === 'ok') {
      HEALTH_CHECK_COUNTERS.CHECKS_PASSED++;
    } else {
      HEALTH_CHECK_COUNTERS.CHECKS_FAILED++;
    }
  } catch (error) {
    console.error('[Ludus Health] Uncaught error:', error);
    res.status(500).json({
      status: 'down',
      timestamp: new Date().toISOString(),
      components: {
        firestore: { status: 'error', nodeCount: 0, edgeCount: 0, gateCount: 0, message: 'Health check crashed' },
        seed_data: { status: 'warning', playerCount: 0, npcCount: 0, expectedPlayers: 5, expectedNpcs: 20 },
        simulation: { status: 'ok', lastCycleDurationMs: 0, cycleCountSinceInit: 0, targetCycleDurationMs: 8 },
      },
    });
    HEALTH_CHECK_COUNTERS.CHECKS_FAILED++;
  }
});

/**
 * Count documents in a collection (uses a denormalized counter or COUNT query).
 * For now, query the collection with a limit to avoid expensive full scans.
 */
async function countCollection(db: any, collectionName: string): Promise<number> {
  const snapshot = await db.collection(collectionName).count().get();
  return snapshot.data().count;
}

/**
 * Metrics endpoint: Expose check pass/fail counters for monitoring.
 */
export const ludusMetrics = functions.https.onRequest((req, res) => {
  res.json({
    health_checks_passed: HEALTH_CHECK_COUNTERS.CHECKS_PASSED,
    health_checks_failed: HEALTH_CHECK_COUNTERS.CHECKS_FAILED,
    uptime_seconds: Math.round((Date.now() - HEALTH_CHECK_COUNTERS.START_TIME) / 1000),
  });
});
