/**
 * Firestore implementation of the storage seam.
 *
 * It is a thin wrapper: every method makes the same Admin SDK call the
 * handlers made before the seam existed, so LUDUS_STORE=firestore keeps
 * the Cloud Function's behaviour unchanged.
 */

import * as admin from 'firebase-admin';

import type {
  DocData, QueryDoc, QueryOptions, Store, StoreTx,
} from './store';

type Firestore = admin.firestore.Firestore;

export class FirestoreStore implements Store {
  readonly mode = 'firestore' as const;
  readonly writable = true;
  private readonly injected?: Firestore;
  private readonly stamp: () => unknown;

  /**
   * The database and the timestamp source can be injected so the same
   * class runs against an in-memory fake in tests; in production both
   * come from the default Admin SDK app.
   */
  constructor(db?: Firestore, serverTime?: () => unknown) {
    this.injected = db;
    this.stamp = serverTime
      || (() => admin.firestore.FieldValue.serverTimestamp());
  }

  // Resolved per call: admin.firestore() throws before initializeApp(),
  // and the handlers' modules are imported before it in some entries.
  private get db(): Firestore {
    return this.injected || admin.firestore();
  }

  async get(path: string): Promise<DocData | null> {
    const snap = await this.db.doc(path).get();
    return snap.exists ? (snap.data() || {}) : null;
  }

  async set(path: string, data: DocData, options?: { merge?: boolean }):
    Promise<void> {
    if (options?.merge) {
      await this.db.doc(path).set(data, { merge: true });
    } else {
      await this.db.doc(path).set(data);
    }
  }

  async query(collection: string, options: QueryOptions = {}):
    Promise<QueryDoc[]> {
    let q: admin.firestore.Query = this.db.collection(collection);
    if (options.where) {
      q = q.where(options.where.field, '==', options.where.value);
    }
    if (options.orderBy) {
      q = q.orderBy(options.orderBy.field, options.orderBy.direction);
    }
    if (options.limit !== undefined) {
      q = q.limit(options.limit);
    }
    const snap = await q.get();
    return snap.docs.map((d) => ({ id: d.id, path: d.ref.path,
      data: d.data() }));
  }

  async count(collection: string): Promise<number> {
    const snap = await this.db.collection(collection).count().get();
    return snap.data().count;
  }

  async transaction<T>(fn: (tx: StoreTx) => Promise<T>): Promise<T> {
    const db = this.db;
    return db.runTransaction(async (t) => {
      const tx: StoreTx = {
        async get(path) {
          const snap = await t.get(db.doc(path));
          return snap.exists ? (snap.data() || {}) : null;
        },
        set(path, data, options) {
          if (options?.merge) {
            t.set(db.doc(path), data, { merge: true });
          } else {
            t.set(db.doc(path), data);
          }
        },
        update(path, data) {
          t.update(db.doc(path), data);
        },
        create(collection, data) {
          t.create(db.collection(collection).doc(), data);
        },
      };
      return fn(tx);
    });
  }

  serverTime(): unknown {
    return this.stamp();
  }
}
