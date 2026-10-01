/**
 * SQLite hot mirror of the ludus_* Firestore collections.
 *
 * The same kind of adapter as the webtypicon2 panopticon mirror
 * (PANOPTICON_FULL_MIRROR_HLD.md section 3.3, better-sqlite3): every
 * document is one row holding its JSON, keyed by its full path.  The
 * JSON is exactly what Express would send for the Firestore document
 * (JSON.stringify of the same data), so a handler answers the same
 * bytes from either store.
 *
 * Two classes share the file:
 *   MirrorDb     the writer, used only by scripts/mirrorSync.ts;
 *   SqliteStore  the read-only Store the handlers see in mirror mode.
 * Keeping the writer out of the Store means a player request has no
 * code path that can change the mirror.
 */

import * as fs from 'fs';
import * as path from 'path';
import type BetterSqlite3 from 'better-sqlite3';

import {
  DocData, QueryDoc, QueryOptions, Store, StoreReadOnlyError, StoreTx,
  splitDocPath,
} from './store';

type Database = BetterSqlite3.Database;

const SCHEMA = `
CREATE TABLE IF NOT EXISTS docs (
  path TEXT PRIMARY KEY,
  parent TEXT NOT NULL,
  id TEXT NOT NULL,
  source TEXT NOT NULL,
  data TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS docs_parent ON docs (parent, id);
CREATE INDEX IF NOT EXISTS docs_source ON docs (source);
CREATE TABLE IF NOT EXISTS sync_state (
  source TEXT PRIMARY KEY,
  watermark TEXT,
  synced_at TEXT NOT NULL,
  docs INTEGER NOT NULL
);
`;

// Field names become part of a JSON path inside SQL; anything outside
// plain identifiers is refused instead of being escaped.
const FIELD = /^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)*$/;

function jsonPath(field: string): string {
  if (!FIELD.test(field)) {
    throw new Error(`Unsupported field for the mirror: ${field}`);
  }
  return `$.${field}`;
}

function openDb(file: string, readonly: boolean): Database {
  // Required lazily: only the mirror container and the sync script need
  // the native module.
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const Sqlite = require('better-sqlite3') as typeof BetterSqlite3;
  if (readonly) {
    return new Sqlite(file, { readonly: true, fileMustExist: true });
  }
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const db = new Sqlite(file);
  // WAL lets the server keep reading while the sync script writes.
  db.pragma('journal_mode = WAL');
  db.exec(SCHEMA);
  return db;
}

/** Writer side of the mirror; the sync script is its only user. */
export class MirrorDb {
  readonly db: Database;

  constructor(file: string) {
    this.db = openDb(file, false);
  }

  watermark(source: string): string | null {
    const row = this.db.prepare(
      'SELECT watermark FROM sync_state WHERE source = ?').get(source) as
      { watermark: string | null } | undefined;
    return row ? row.watermark : null;
  }

  /** Every source a previous run recorded, empty ones included. */
  sources(): string[] {
    return (this.db.prepare('SELECT source FROM sync_state ORDER BY source')
      .all() as Array<{ source: string }>).map((r) => r.source);
  }

  rowStamp(docPath: string): string | null {
    const row = this.db.prepare(
      'SELECT updated_at FROM docs WHERE path = ?').get(docPath) as
      { updated_at: string } | undefined;
    return row ? row.updated_at : null;
  }

  paths(source: string): string[] {
    return (this.db.prepare('SELECT path FROM docs WHERE source = ?')
      .all(source) as Array<{ path: string }>).map((r) => r.path);
  }

  upsert(source: string, docPath: string, data: DocData,
    updatedAt: string): void {
    const { parent, id } = splitDocPath(docPath);
    if (!parent.startsWith('ludus_')) {
      // The mirror holds the game's collections only, never the rest
      // of a shared Firebase project.
      throw new Error(`Refusing to mirror outside ludus_*: ${docPath}`);
    }
    this.db.prepare(
      `INSERT INTO docs (path, parent, id, source, data, updated_at)
       VALUES (?, ?, ?, ?, ?, ?)
       ON CONFLICT(path) DO UPDATE SET data = excluded.data,
         updated_at = excluded.updated_at, source = excluded.source`)
      .run(docPath, parent, id, source, JSON.stringify(data), updatedAt);
  }

  remove(docPath: string): void {
    this.db.prepare('DELETE FROM docs WHERE path = ?').run(docPath);
  }

  setState(source: string, watermark: string | null, docs: number): void {
    this.db.prepare(
      `INSERT INTO sync_state (source, watermark, synced_at, docs)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(source) DO UPDATE SET watermark = excluded.watermark,
         synced_at = excluded.synced_at, docs = excluded.docs`)
      .run(source, watermark, new Date().toISOString(), docs);
  }

  close(): void {
    this.db.close();
  }
}

/** Read-only Store over the mirror file, used when LUDUS_STORE=mirror. */
export class SqliteStore implements Store {
  readonly mode = 'mirror' as const;
  readonly writable = false;
  private readonly file: string;
  private handle: Database | null = null;

  constructor(file: string) {
    this.file = file;
  }

  // Opened on first use: a container started before the first sync
  // still boots and answers health with the error instead of crashing.
  private get db(): Database {
    if (!this.handle) {
      this.handle = openDb(this.file, true);
    }
    return this.handle;
  }

  async get(docPath: string): Promise<DocData | null> {
    splitDocPath(docPath);
    const row = this.db.prepare('SELECT data FROM docs WHERE path = ?')
      .get(docPath) as { data: string } | undefined;
    return row ? JSON.parse(row.data) as DocData : null;
  }

  async set(): Promise<void> {
    throw new StoreReadOnlyError();
  }

  async query(collection: string, options: QueryOptions = {}):
    Promise<QueryDoc[]> {
    const args: unknown[] = [collection];
    let sql = 'SELECT path, id, data FROM docs WHERE parent = ?';
    if (options.where) {
      const { field, value } = options.where;
      // SQLite has no boolean; json_extract turns JSON true into 1.
      const bound = typeof value === 'boolean' ? (value ? 1 : 0) : value;
      if (field === '__name__') {
        sql += ' AND id = ?';
      } else {
        sql += ' AND json_extract(data, ?) = ?';
        args.push(jsonPath(field));
      }
      args.push(bound);
    }
    if (options.orderBy) {
      const p = jsonPath(options.orderBy.field);
      const dir = options.orderBy.direction === 'desc' ? 'DESC' : 'ASC';
      // Firestore leaves out documents without the ordered field, and a
      // Timestamp arrives here as {_seconds, _nanoseconds} JSON.
      sql += ` AND json_extract(data, ?) IS NOT NULL
        ORDER BY COALESCE(json_extract(data, ?), json_extract(data, ?),
          json_extract(data, ?)) ${dir}, id ${dir}`;
      args.push(p, `${p}._seconds`, `${p}.seconds`, p);
    } else {
      // Firestore's default order is by document id.
      sql += ' ORDER BY id';
    }
    if (options.limit !== undefined) {
      sql += ' LIMIT ?';
      args.push(Math.max(0, Math.floor(options.limit)));
    }
    const rows = this.db.prepare(sql).all(...args) as
      Array<{ path: string; id: string; data: string }>;
    return rows.map((r) => ({ id: r.id, path: r.path,
      data: JSON.parse(r.data) as DocData }));
  }

  async count(collection: string): Promise<number> {
    const row = this.db.prepare(
      'SELECT COUNT(*) AS n FROM docs WHERE parent = ?').get(collection) as
      { n: number };
    return row.n;
  }

  async transaction<T>(fn: (tx: StoreTx) => Promise<T>): Promise<T> {
    // Reads inside a transaction are plain reads on a read-only file;
    // every write throws, so a missed guard fails loudly, not silently.
    const tx: StoreTx = {
      get: (docPath) => this.get(docPath),
      set: () => {
        throw new StoreReadOnlyError();
      },
      update: () => {
        throw new StoreReadOnlyError();
      },
      create: () => {
        throw new StoreReadOnlyError();
      },
    };
    return fn(tx);
  }

  serverTime(): unknown {
    return new Date().toISOString();
  }

  close(): void {
    if (this.handle) {
      this.handle.close();
      this.handle = null;
    }
  }
}
