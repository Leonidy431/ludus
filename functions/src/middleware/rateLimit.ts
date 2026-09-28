import * as functions from 'firebase-functions';
import { getFirestore } from 'firebase-admin/firestore';

export interface RateLimitConfig {
  windowMs: number;
  maxRequests: number;
  keyGenerator?: (req: functions.https.Request) => string;
}

/**
 * Rate limiting via Firestore document counters.
 * Tracks requests per key (default: uid/ip) within a time window.
 */
export function rateLimit(config: RateLimitConfig) {
  return async (req: functions.https.Request, res: functions.Response, next: () => void) => {
    const key = config.keyGenerator?.(req) || (req as any).user?.uid || req.ip;
    if (!key) {
      res.status(400).json({ error: 'Could not determine rate limit key' });
      return;
    }

    const db = getFirestore();
    const counterRef = db.collection('ludus_rate_limits').doc(key);
    const now = Date.now();

    try {
      const result = await db.runTransaction(async (tx) => {
        const snap = await tx.get(counterRef);
        const data = snap.data();

        if (!data || (now - data.lastUpdate) > config.windowMs) {
          tx.set(counterRef, { count: 1, lastUpdate: now }, { merge: true });
          return true;
        }

        if (data.count >= config.maxRequests) {
          return false;
        }

        tx.update(counterRef, { count: data.count + 1, lastUpdate: now });
        return true;
      });

      if (!result) {
        res.status(429).json({
          error: 'Rate limit exceeded',
          retryAfter: Math.ceil(config.windowMs / 1000)
        });
        return;
      }

      next();
    } catch (error) {
      console.error('[RateLimit] Error:', error);
      next();
    }
  };
}

export const rateLimitPresets = {
  healthEndpoint: {
    windowMs: 60000,
    maxRequests: 30
  },
  gameAction: {
    windowMs: 60000,
    maxRequests: 10
  },
  admin: {
    windowMs: 60000,
    maxRequests: 100
  }
};
