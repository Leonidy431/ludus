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
import { ludusActions } from './ludus-actions';

type Handler = (req: Request, res: Response) => void | Promise<void>;

interface Route {
  method: 'GET' | 'POST' | 'ANY';
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
  // One handler reads (GET) and applies an operation (POST); the
  // player is taken from the ID token, never from the path.
  { method: 'ANY', name: 'ludusActions', keys: [],
    pattern: /^\/api\/ludus\/actions\/?$/ },
];

const HANDLERS: Record<string, Handler> = {
  getDialogueTree: getDialogueTree as unknown as Handler,
  upsertDialogueTree: upsertDialogueTree as unknown as Handler,
  getNpcMemory: getNpcMemory as unknown as Handler,
  persistDialogueState: persistDialogueState as unknown as Handler,
  getDialogueStats: getDialogueStats as unknown as Handler,
  ludusHealth: ludusHealth as unknown as Handler,
  ludusActions: ludusActions as unknown as Handler,
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
    if (verb !== 'OPTIONS' && route.method !== 'ANY'
        && verb !== route.method) {
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

/**
 * The one dispatcher behind both entry points: the Cloud Function "api"
 * (Firebase Hosting rewrite) and the container server (server.ts, the
 * own backend 3.0 on VM8).  Both run exactly this code, so the "pairing"
 * of docs/version-3.0/HLD_BACKEND_3.0_VM8_HOT_MIRROR_2026-10-01.md can
 * compare their answers.
 */
export async function dispatch(req: Request, res: Response): Promise<void> {
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

export const api = functions.https.onRequest(dispatch);
