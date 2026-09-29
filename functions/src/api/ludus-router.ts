/**
 * Single HTTP entry point for Firebase Hosting's "/api/**" rewrite.
 *
 * firebase.json rewrites every /api/** request to a function named
 * "api", which did not exist.  The dialogue handlers also read
 * req.params, but functions.https.onRequest has no router, so params
 * were always empty and every call answered 400.  This module matches
 * the path, fills req.params and hands the request to the handler.
 */

import * as functions from 'firebase-functions';
import { Request, Response } from 'express';

import {
  getDialogueTree,
  getNpcMemory,
  persistDialogueState,
  getDialogueStats,
  upsertDialogueTree,
} from './ludus-dialogue';
import { ludusHealth } from './ludus-health';

type Handler = (req: Request, res: Response) => void | Promise<void>;

interface Route {
  method: 'GET' | 'POST';
  pattern: RegExp;
  keys: string[];
  name: string;
}

// Segments are limited to id-safe characters, so a crafted path cannot
// smuggle a slash or a dot-dot into a Firestore document id.
const SEG = '([A-Za-z0-9_-]{1,128})';

export const ROUTES: Route[] = [
  { method: 'GET', name: 'getDialogueTree', keys: ['npcId'],
    pattern: new RegExp(`^/api/ludus/dialogue/tree/${SEG}/?$`) },
  { method: 'POST', name: 'upsertDialogueTree', keys: ['npcId'],
    pattern: new RegExp(`^/api/ludus/dialogue/tree/${SEG}/?$`) },
  { method: 'GET', name: 'getNpcMemory', keys: ['npcId', 'playerId'],
    pattern: new RegExp(`^/api/ludus/dialogue/memory/${SEG}/${SEG}/?$`) },
  { method: 'POST', name: 'persistDialogueState', keys: [],
    pattern: /^\/api\/ludus\/dialogue\/state\/?$/ },
  { method: 'GET', name: 'getDialogueStats', keys: ['playerId'],
    pattern: new RegExp(`^/api/ludus/dialogue/stats/${SEG}/?$`) },
  { method: 'GET', name: 'ludusHealth', keys: [],
    pattern: /^\/api\/ludus\/health\/?$/ },
];

const HANDLERS: Record<string, Handler> = {
  getDialogueTree: getDialogueTree as unknown as Handler,
  upsertDialogueTree: upsertDialogueTree as unknown as Handler,
  getNpcMemory: getNpcMemory as unknown as Handler,
  persistDialogueState: persistDialogueState as unknown as Handler,
  getDialogueStats: getDialogueStats as unknown as Handler,
  ludusHealth: ludusHealth as unknown as Handler,
};

export interface RouteMatch {
  name: string;
  params: Record<string, string>;
}

/**
 * Pure path matcher, kept separate so it is testable without Firestore.
 *
 * OPTIONS matches any route on the path, because the handlers answer
 * the CORS preflight themselves and need to be reached for it.
 */
export function matchRoute(method: string, path: string): RouteMatch | null {
  const verb = method.toUpperCase();
  for (const route of ROUTES) {
    if (verb !== 'OPTIONS' && verb !== route.method) {
      continue;
    }
    const found = route.pattern.exec(path);
    if (!found) {
      continue;
    }
    const params: Record<string, string> = {};
    route.keys.forEach((key, i) => {
      params[key] = found[i + 1];
    });
    return { name: route.name, params };
  }
  return null;
}

export const api = functions.https.onRequest(
  async (req: Request, res: Response) => {
    const match = matchRoute(req.method, req.path);
    if (!match) {
      res.status(404).json({
        error: `No route for ${req.method} ${req.path}`,
        recovery: ['Check the API path and method'],
      });
      return;
    }
    // Express declares params as read-only in types but it is a plain
    // writable object at runtime; the handlers read their ids from it.
    (req as unknown as { params: Record<string, string> }).params =
      match.params;
    await HANDLERS[match.name](req, res);
  }
);
