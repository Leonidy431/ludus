/**
 * auth.ts — Firebase ID token verification middleware for Ludus Cloud Functions
 *
 * S12 CRITICAL blocker: Authentication & Authorization.
 *
 * Verifies the `Authorization: Bearer <idToken>` header against Firebase Auth,
 * and exposes two guard helpers for `functions.https.onRequest` handlers:
 *
 *   - requireAuth(handler)  — any signed-in user (decoded token attached to req.ludusAuth)
 *   - requireAdmin(handler) — signed-in user with the `admin` custom claim
 *
 * These wrap the same `(req, res) => void | Promise<void>` signature used by
 * `functions.https.onRequest`, so existing endpoints opt in with zero shape change:
 *
 *   export const ludusMetrics = functions.https.onRequest(requireAdmin(async (req, res) => { ... }));
 *
 * Admin custom claim is set via `admin.auth().setCustomUserClaims(uid, { admin: true })`
 * from a trusted server-side context (e.g. a one-off provisioning script) — never
 * settable by the client itself.
 */

import type { Request, Response } from 'firebase-functions';
import { getAuth, DecodedIdToken } from 'firebase-admin/auth';

export interface AuthenticatedRequest extends Request {
  ludusAuth?: DecodedIdToken;
}

type Handler = (req: AuthenticatedRequest, res: Response) => void | Promise<void>;

/**
 * Extract and verify the bearer token from the Authorization header.
 * Returns the decoded token, or null if absent/invalid/expired.
 * Never throws — callers decide what an absent/invalid token means (401 vs. anonymous).
 */
export async function verifyIdToken(req: Request): Promise<DecodedIdToken | null> {
  const header = req.get('Authorization') || req.get('authorization');
  if (!header || !header.startsWith('Bearer ')) return null;

  const idToken = header.slice('Bearer '.length).trim();
  if (!idToken) return null;

  try {
    // checkRevoked: false — a revocation check costs an extra Firestore-backed
    // lookup per request; the CRITICAL requirement here is "is this a real,
    // unexpired Firebase ID token", not "was it explicitly revoked mid-session".
    return await getAuth().verifyIdToken(idToken, false);
  } catch {
    // Any verification failure (malformed, expired, wrong project, signature
    // mismatch) is treated identically: no valid identity. Never leak which.
    return null;
  }
}

export function isAdminToken(token: DecodedIdToken): boolean {
  return token.admin === true;
}

/**
 * Reject unauthenticated requests with 401 before the handler runs.
 * On success, `req.ludusAuth` carries the decoded token for the handler to use
 * (e.g. scoping a query to `req.ludusAuth.uid`).
 */
export function requireAuth(handler: Handler): Handler {
  return async (req, res) => {
    const token = await verifyIdToken(req);
    if (!token) {
      res.status(401).json({ error: 'unauthorized', message: 'Missing or invalid Authorization: Bearer <idToken> header.' });
      return;
    }
    req.ludusAuth = token;
    await handler(req, res);
  };
}

/**
 * Reject requests that are not signed in as an admin (401 if not signed in at
 * all, 403 if signed in but lacking the `admin` custom claim).
 */
export function requireAdmin(handler: Handler): Handler {
  return async (req, res) => {
    const token = await verifyIdToken(req);
    if (!token) {
      res.status(401).json({ error: 'unauthorized', message: 'Missing or invalid Authorization: Bearer <idToken> header.' });
      return;
    }
    if (!isAdminToken(token)) {
      res.status(403).json({ error: 'forbidden', message: 'Admin custom claim required.' });
      return;
    }
    req.ludusAuth = token;
    await handler(req, res);
  };
}
