/**
 * auth.ts — JWT & Firebase Auth Middleware
 *
 * Validates Bearer token from Authorization header and extracts user context.
 * Supports:
 * - Firebase ID Token verification
 * - Role-based access control (admin vs. player)
 * - Optional auth (for public endpoints)
 */

import * as functions from 'firebase-functions';
import { getAuth } from 'firebase-admin/auth';

export interface AuthContext {
  uid: string;
  email?: string;
  role: 'admin' | 'player';
  isAuthenticated: boolean;
}

export interface AuthOptions {
  required?: boolean; // If true, request must have valid token
  adminOnly?: boolean; // If true, only admin role allowed
}

/**
 * Extract and validate Authorization Bearer token
 * Returns auth context or null if not authenticated
 */
export async function verifyIdToken(authHeader?: string): Promise<AuthContext | null> {
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return null;
  }

  const token = authHeader.slice(7); // Remove "Bearer " prefix

  try {
    const decodedToken = await getAuth().verifyIdToken(token);

    // Determine role based on custom claims or default to 'player'
    const role = (decodedToken.admin === true) ? 'admin' : 'player';

    return {
      uid: decodedToken.uid,
      email: decodedToken.email,
      role,
      isAuthenticated: true,
    };
  } catch (error) {
    console.error('[Auth] Token verification failed:', error instanceof Error ? error.message : String(error));
    return null;
  }
}

/**
 * Express-style middleware for auth validation
 * Usage: app.use(requireAuth()) or app.use(requireAuth({ adminOnly: true }))
 */
export function requireAuth(options: AuthOptions = {}) {
  return async (req: functions.https.Request, res: functions.Response, next: () => void) => {
    const authContext = await verifyIdToken(req.headers.authorization);

    if (!authContext && options.required) {
      res.status(401).json({ error: 'Unauthorized', message: 'Missing or invalid authorization token' });
      return;
    }

    if (authContext && options.adminOnly && authContext.role !== 'admin') {
      res.status(403).json({ error: 'Forbidden', message: 'Admin role required' });
      return;
    }

    // Attach auth context to request for downstream handlers
    (req as any).auth = authContext;
    next();
  };
}

/**
 * Extract auth context from request (populated by requireAuth middleware)
 */
export function getRequestAuth(req: functions.https.Request): AuthContext | null {
  return (req as any).auth || null;
}

/**
 * Check if request is from authenticated admin
 */
export function isAdmin(req: functions.https.Request): boolean {
  const auth = getRequestAuth(req);
  return auth?.role === 'admin';
}

/**
 * Get user UID from request (safe accessor)
 */
export function getUserId(req: functions.https.Request): string | null {
  const auth = getRequestAuth(req);
  return auth?.uid || null;
}
