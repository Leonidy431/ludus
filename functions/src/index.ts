/**
 * index.ts — Cloud Functions Entry Point
 *
 * Exports all Ludus API endpoints:
 * - ludusHealth: Health check endpoint (public)
 * - ludusMetrics: Metrics endpoint (admin-only)
 */

import * as admin from 'firebase-admin';

// Initialize Firebase Admin SDK
admin.initializeApp();

// Export Cloud Functions
export { ludusHealth, ludusMetrics } from './api/ludus-health';
