/**
 * Storage seam of the Ludus backend (version 3.0, phase P2 of
 * docs/version-3.0/HLD_BACKEND_3.0_VM8_HOT_MIRROR_2026-10-01.md).
 *
 * The handlers used to call admin.firestore() directly, so the VM8
 * container could only run against Google's database.  This module
 * names the few document operations the handlers really use and lets
 * the environment pick the backing store:
 *
 *   LUDUS_STORE=firestore (default)  Firestore through the Admin SDK,
 *       credentials from GOOGLE_APPLICATION_CREDENTIALS, exactly as the
 *       Cloud Function behaves today;
 *   LUDUS_STORE=mirror               a local SQLite file
 *       (LUDUS_MIRROR_DB, default /data/ludus-data/mirror.sqlite) that
 *       scripts/mirrorSync.ts fills from the ludus_* collections.  The
 *       mirror is read-only for players until cutover: a write there
 *       would fork the player's state away from Firestore, which stays
 *       the single source of truth until phase P5.
 *
 * The operation list was taken from the handlers, not guessed (the
 * risk named in webtypicon2 PANOPTICON_FULL_MIRROR_HLD.md section 3.3):
 * get a document, set or merge it, query one collection by one equality
 * with an optional order and limit, count a collection, and a
 * transaction that reads, sets, updates and appends a journal entry.
 */

import type { Response } from 'express';

export type DocData = Record<string, unknown>;

export interface QueryOptions {
  // Only equality is used by the handlers; a wider filter language would
  // be code the mirror must imitate without a caller to test it.
  where?: { field: string; value: string | number | boolean };
  orderBy?: { field: string; direction: 'asc' | 'desc' };
  limit?: number;
}

export interface QueryDoc {
  id: string;
  path: string;
  data: DocData;
}

export interface StoreTx {
  get(path: string): Promise<DocData | null>;
  set(path: string, data: DocData, options?: { merge?: boolean }): void;
  update(path: string, data: DocData): void;
  // Adds a document with a generated id; used for the action journal,
  // which only grows (CLAUDE.md TABOO 0.25 item 5).
  create(collection: string, data: DocData): void;
}

export interface Store {
  readonly mode: 'firestore' | 'mirror';
  // False on the read-only mirror; handlers answer 503 before writing.
  readonly writable: boolean;
  get(path: string): Promise<DocData | null>;
  set(path: string, data: DocData, options?: { merge?: boolean }):
    Promise<void>;
  query(collection: string, options?: QueryOptions): Promise<QueryDoc[]>;
  count(collection: string): Promise<number>;
  transaction<T>(fn: (tx: StoreTx) => Promise<T>): Promise<T>;
  // The time the server stamps on a journal entry: Firestore's own
  // server timestamp, or an ISO string where there is no server.
  serverTime(): unknown;
}

/** Thrown by the mirror if a write reaches it despite the guard. */
export class StoreReadOnlyError extends Error {
  constructor() {
    super('The Ludus mirror is read-only until cutover');
    this.name = 'StoreReadOnlyError';
  }
}

export const DEFAULT_MIRROR_DB = '/data/ludus-data/mirror.sqlite';

let current: Store | null = null;

/**
 * The store chosen by LUDUS_STORE, created on first use.  Lazy, so that
 * importing a handler no longer needs an initialised Firebase app and
 * the mirror container never loads Firestore credentials it lacks.
 */
export function getStore(): Store {
  if (current) {
    return current;
  }
  const mode = (process.env.LUDUS_STORE || 'firestore').toLowerCase();
  if (mode === 'mirror') {
    // Required here, not at the top, so the Cloud Function never loads
    // the native SQLite module it does not need.
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const { SqliteStore } = require('./sqlite-store');
    current = new SqliteStore(
      process.env.LUDUS_MIRROR_DB || DEFAULT_MIRROR_DB) as Store;
  } else if (mode === 'firestore') {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const { FirestoreStore } = require('./firestore-store');
    current = new FirestoreStore() as Store;
  } else {
    // A typo must not silently fall back to the production database.
    throw new Error(`Unknown LUDUS_STORE "${mode}" (firestore|mirror)`);
  }
  return current as Store;
}

/** Tests and the container entry point inject a store explicitly. */
export function setStore(store: Store | null): void {
  current = store;
}

/**
 * Answers 503 and returns true when the store cannot take writes.
 *
 * 503 rather than 403: nothing is wrong with the request or the player,
 * the service is temporarily serving from the hot mirror, and the
 * client may retry against the primary (Cloud Function) address.
 */
export function refuseWriteOnMirror(store: Store, res: Response): boolean {
  if (store.writable) {
    return false;
  }
  res.set('Retry-After', '60');
  res.status(503).json({
    error: 'Read-only mirror: player writes are paused until cutover',
    store: store.mode,
    recovery: [
      'Your progress was not saved here; nothing was lost',
      'Retry later or use the primary game server',
    ],
  });
  return true;
}

/**
 * Splits "a/b/c/d" into the parent collection path and the document id.
 * Document paths always have an even number of segments.
 */
export function splitDocPath(path: string): { parent: string; id: string } {
  const parts = path.split('/');
  if (parts.length < 2 || parts.length % 2 !== 0
      || parts.some((p) => p.length === 0)) {
    throw new Error(`Not a document path: ${path}`);
  }
  return { parent: parts.slice(0, -1).join('/'), id: parts[parts.length - 1] };
}
