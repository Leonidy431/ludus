/**
 * Copies the ludus_* Firestore collections into the SQLite hot mirror
 * (docs/version-3.0/HLD_BACKEND_3.0_VM8_HOT_MIRROR_2026-10-01.md, P2).
 *
 * Usage, on the VM8 volume, with a service account that can read the
 * ludus_* collections (never committed to the repo):
 *
 *   GOOGLE_APPLICATION_CREDENTIALS=/data/ludus-data/sa.json \
 *     node lib/scripts/mirrorSync.js [--db PATH] [--only NAME[,NAME]]
 *
 * PATH defaults to LUDUS_MIRROR_DB or /data/ludus-data/mirror.sqlite.
 *
 * The webtypicon2 mirror (functions/src/panopticon/mirrorSync.ts) is
 * pushed by Firestore triggers.  Ludus has no triggers deployed for
 * this yet, so the sync pulls instead, and pulling must be safe to
 * repeat: each source keeps an updatedAt watermark (the newest
 * Firestore updateTime it has copied), unchanged documents are not
 * rewritten, and a second run with no changes writes nothing.
 *
 * Firestore cannot filter a query by a document's updateTime, so the
 * watermark saves writes, not reads: every run still lists the
 * collection.  That full listing is also what lets the mirror drop a
 * document that was deleted in Firestore, so the mirror never answers
 * with data the primary no longer has.  The ludus_* collections are
 * small; if one grows large, a trigger push like webtypicon2's is the
 * next step.
 */

import * as admin from 'firebase-admin';

import { DEFAULT_MIRROR_DB, DocData } from '../store/store';
import { MirrorDb } from '../store/sqlite-store';

type Firestore = admin.firestore.Firestore;

export const MIRROR_PREFIX = 'ludus_';

// Subcollections are reached through their collection group, because
// their parent documents (ludus_npc_memory/{npcId}) may not exist on
// their own.  Only paths under ludus_* are kept.
export const MIRRORED_GROUPS = ['players'];

export interface Source {
  key: string;
  read(): Promise<SourceDoc[]>;
}

export interface SourceDoc {
  path: string;
  data: DocData;
  updatedAt: string;
}

export interface SyncReport {
  source: string;
  scanned: number;
  written: number;
  unchanged: number;
  deleted: number;
  watermark: string | null;
}

interface Stamp {
  seconds: number;
  nanoseconds: number;
}

/**
 * A sortable text form of a Firestore Timestamp.  ISO strings stop at
 * milliseconds, and two writes in the same millisecond would then look
 * equal to the watermark; seconds and nanoseconds, zero-padded, keep
 * the full order as plain string comparison.
 */
export function stampKey(t: Stamp | undefined | null): string {
  if (!t) {
    return '000000000000.000000000';
  }
  return `${String(t.seconds).padStart(12, '0')}.`
    + `${String(t.nanoseconds).padStart(9, '0')}`;
}

function toDocs(snap: admin.firestore.QuerySnapshot): SourceDoc[] {
  return snap.docs
    .filter((d) => d.ref.path.startsWith(MIRROR_PREFIX))
    .map((d) => ({
      path: d.ref.path,
      // Stored as the JSON Express would send, so a handler answers the
      // same bytes from the mirror as from Firestore.
      data: JSON.parse(JSON.stringify(d.data())) as DocData,
      updatedAt: stampKey(d.updateTime as unknown as Stamp),
    }));
}

/** The top-level ludus_* collections plus the mirrored groups. */
export async function discoverSources(db: Firestore,
  only?: string[], known: string[] = []): Promise<Source[]> {
  // listCollections() forgets a collection once its last document is
  // deleted; the sources the mirror already holds are added back so
  // their stale rows are removed instead of being served forever.
  const listed = (await db.listCollections()).map((c) => c.id);
  const top = Array.from(new Set([...listed,
    ...known.filter((k) => !k.startsWith('group:'))]))
    .filter((id) => id.startsWith(MIRROR_PREFIX))
    .sort();
  const sources: Source[] = top.map((id) => ({
    key: id,
    read: async () => toDocs(await db.collection(id).get()),
  }));
  MIRRORED_GROUPS.forEach((group) => {
    sources.push({
      key: `group:${group}`,
      read: async () => toDocs(await db.collectionGroup(group).get()),
    });
  });
  if (only && only.length > 0) {
    return sources.filter((s) => only.includes(s.key));
  }
  return sources;
}

/** Brings one source up to date inside one SQLite transaction. */
export async function syncSource(source: Source, mirror: MirrorDb):
  Promise<SyncReport> {
  // Firestore is read first and in full: the SQLite transaction below
  // is synchronous, so a failed read leaves the previous copy intact.
  const docs = await source.read();
  const report: SyncReport = {
    source: source.key, scanned: docs.length, written: 0, unchanged: 0,
    deleted: 0, watermark: mirror.watermark(source.key),
  };
  const apply = mirror.db.transaction(() => {
    const seen = new Set<string>();
    let newest = report.watermark;
    docs.forEach((doc) => {
      seen.add(doc.path);
      const stored = mirror.rowStamp(doc.path);
      // At or below the watermark and already present means this exact
      // version was copied by an earlier run.
      if (stored !== null && report.watermark !== null
          && doc.updatedAt <= report.watermark
          && stored === doc.updatedAt) {
        report.unchanged += 1;
      } else {
        mirror.upsert(source.key, doc.path, doc.data, doc.updatedAt);
        report.written += 1;
      }
      if (newest === null || doc.updatedAt > newest) {
        newest = doc.updatedAt;
      }
    });
    mirror.paths(source.key).forEach((p) => {
      if (!seen.has(p)) {
        mirror.remove(p);
        report.deleted += 1;
      }
    });
    report.watermark = newest;
    mirror.setState(source.key, newest, docs.length);
  });
  apply();
  return report;
}

export async function syncMirror(db: Firestore, mirror: MirrorDb,
  only?: string[]): Promise<SyncReport[]> {
  const reports: SyncReport[] = [];
  for (const source of await discoverSources(db, only,
    mirror.sources())) {
    reports.push(await syncSource(source, mirror));
  }
  return reports;
}

function argValue(args: string[], name: string): string | undefined {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const file = argValue(args, '--db') || process.env.LUDUS_MIRROR_DB
    || DEFAULT_MIRROR_DB;
  const only = (argValue(args, '--only') || '').split(',')
    .map((s) => s.trim()).filter(Boolean);
  // Credentials come from GOOGLE_APPLICATION_CREDENTIALS on the VM
  // volume or from the CI secret; the script never reads a key itself.
  if (admin.apps.length === 0) {
    admin.initializeApp();
  }
  const mirror = new MirrorDb(file);
  try {
    const reports = await syncMirror(admin.firestore(), mirror, only);
    console.log(JSON.stringify({ db: file, reports }, null, 2));
  } finally {
    mirror.close();
  }
}

if (require.main === module) {
  main().catch((err: unknown) => {
    console.error('[mirrorSync] failed:', err);
    process.exit(1);
  });
}
