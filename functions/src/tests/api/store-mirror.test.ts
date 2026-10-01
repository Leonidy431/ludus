/**
 * Storage seam, phase P2 of
 * docs/version-3.0/HLD_BACKEND_3.0_VM8_HOT_MIRROR_2026-10-01.md.
 *
 * The same handler calls run twice: once through FirestoreStore over an
 * in-memory Firestore fake (the path the Cloud Function takes), once
 * through SqliteStore over a mirror file that mirrorSync filled from the
 * same fake.  The JSON answers must be equal, and every player write on
 * the mirror must answer 503.  No emulator and no credentials are used.
 */

import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';

jest.mock('../../middleware/auth', () => ({
  // A fixed uid stands in for a verified ID token; the token check
  // itself is not what this suite tests.
  verifyIdToken: jest.fn(async (header?: string) =>
    (header === 'Bearer good' ? { uid: 'abcdef0123456789zz' } : null)),
}));

import { FirestoreStore } from '../../store/firestore-store';
import { MirrorDb, SqliteStore } from '../../store/sqlite-store';
import { getStore, setStore, Store } from '../../store/store';
import { syncMirror, stampKey } from '../../scripts/mirrorSync';
import {
  getDialogueTree, getNpcMemory, getDialogueStats, persistDialogueState,
  upsertDialogueTree,
} from '../../api/ludus-dialogue';
import { ludusActions } from '../../api/ludus-actions';
import { ludusHealth } from '../../api/ludus-health';

// ---------------------------------------------------------------------
// A small Firestore fake: just the calls FirestoreStore and mirrorSync
// make, with Firestore's semantics for them (default order by id,
// orderBy drops documents without the field, merge is a deep merge).
// ---------------------------------------------------------------------

type Data = Record<string, any>;

interface Row {
  data: Data;
  seconds: number;
}

function isPlain(v: unknown): v is Data {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

function deepMerge(base: Data, patch: Data): Data {
  const out: Data = { ...base };
  Object.entries(patch).forEach(([k, v]) => {
    out[k] = isPlain(v) && isPlain(out[k]) ? deepMerge(out[k], v) : v;
  });
  return out;
}

function getField(data: Data, field: string): unknown {
  return field.split('.').reduce<any>((o, k) => (o == null ? o : o[k]),
    data);
}

class FakeFirestore {
  rows = new Map<string, Row>();
  private clock = 1_700_000_000;
  private auto = 0;

  put(p: string, data: Data): void {
    this.clock += 1;
    this.rows.set(p, { data: JSON.parse(JSON.stringify(data)),
      seconds: this.clock });
  }

  private snap(p: string) {
    const row = this.rows.get(p);
    return {
      exists: !!row,
      id: p.split('/').pop() as string,
      ref: { path: p },
      updateTime: row ? { seconds: row.seconds, nanoseconds: 0 } : undefined,
      data: () => (row ? JSON.parse(JSON.stringify(row.data)) : undefined),
    };
  }

  doc(p: string) {
    return {
      path: p,
      get: async () => this.snap(p),
      set: async (data: Data, opts?: { merge?: boolean }) => {
        const prev = this.rows.get(p);
        this.put(p, opts?.merge && prev ? deepMerge(prev.data, data) : data);
      },
    };
  }

  private query(match: (p: string) => boolean, filters: Array<(d: Data,
    p: string) => boolean> = [], order?: [string, string],
  lim?: number): any {
    const run = () => {
      let paths = Array.from(this.rows.keys()).filter(match)
        .filter((p) => filters.every((f) => f(this.rows.get(p)!.data, p)))
        .sort((a, b) => (a.split('/').pop()! < b.split('/').pop()! ? -1
          : 1));
      if (order) {
        const [field, dir] = order;
        paths = paths.filter((p) =>
          getField(this.rows.get(p)!.data, field) !== undefined);
        paths.sort((a, b) => {
          const x = getField(this.rows.get(a)!.data, field) as number;
          const y = getField(this.rows.get(b)!.data, field) as number;
          return dir === 'desc' ? y - x : x - y;
        });
      }
      if (lim !== undefined) {
        paths = paths.slice(0, lim);
      }
      const docs = paths.map((p) => this.snap(p));
      return { docs, size: docs.length, empty: docs.length === 0 };
    };
    return {
      where: (field: string, op: string, value: unknown) => {
        expect(op).toBe('==');
        return this.query(match, [...filters,
          (d: Data, p: string) => (field === '__name__'
            ? p.split('/').pop() === value : getField(d, field) === value)],
        order, lim);
      },
      orderBy: (field: string, dir = 'asc') =>
        this.query(match, filters, [field, dir], lim),
      limit: (n: number) => this.query(match, filters, order, n),
      get: async () => run(),
      count: () => ({ get: async () => ({ data: () => ({
        count: run().size }) }) }),
    };
  }

  collection(c: string) {
    const depth = c.split('/').length + 1;
    const q = this.query((p) => p.startsWith(`${c}/`)
      && p.split('/').length === depth);
    q.doc = (id?: string) => {
      this.auto += 1;
      return this.doc(`${c}/${id || `auto${String(this.auto).padStart(4,
        '0')}`}`);
    };
    return q;
  }

  collectionGroup(g: string) {
    return this.query((p) => {
      const parts = p.split('/');
      return parts[parts.length - 2] === g;
    });
  }

  async listCollections() {
    const ids = new Set(Array.from(this.rows.keys())
      .map((p) => p.split('/')[0]));
    return Array.from(ids).map((id) => ({ id }));
  }

  async runTransaction<T>(fn: (t: any) => Promise<T>): Promise<T> {
    const writes: Array<() => void> = [];
    const t = {
      get: async (ref: { path: string }) => this.snap(ref.path),
      set: (ref: { path: string }, data: Data,
        opts?: { merge?: boolean }) => writes.push(() => {
        const prev = this.rows.get(ref.path);
        this.put(ref.path, opts?.merge && prev
          ? deepMerge(prev.data, data) : data);
      }),
      update: (ref: { path: string }, data: Data) => writes.push(() => {
        const prev = this.rows.get(ref.path);
        if (!prev) {
          throw new Error('NOT_FOUND');
        }
        this.put(ref.path, { ...prev.data, ...data });
      }),
      create: (ref: { path: string }, data: Data) => writes.push(() => {
        if (this.rows.has(ref.path)) {
          throw new Error('ALREADY_EXISTS');
        }
        this.put(ref.path, data);
      }),
    };
    const result = await fn(t);
    writes.forEach((w) => w());
    return result;
  }
}

// ---------------------------------------------------------------------
// Fixtures: the documents a seeded Ludus project holds.
// ---------------------------------------------------------------------

const PLAYER = 'player-abcdef0123456789';
const OTHER = 'player-0000000000000000';

function seed(db: FakeFirestore): void {
  db.put(`ludus_players/${PLAYER}`, {
    form: { wisdom: 5, faith: 3, dexterity: 2 },
    actions: { prayerCount: 7, fastDays: 1, meditationHours: 0.5,
      lastFastDay: '2026-09-30', lastStillnessAt: 123,
      met: { elder_sergius: 1 }, gifts: {},
      practices: { alms: { count: 2, lastDay: '2026-09-30', lastAt: 9 },
        secret_deed: { count: 4, lastDay: '2026-09-30', lastAt: 9 } },
      passions: {} },
  });
  db.put(`ludus_players/${OTHER}`, { form: { wisdom: 1 } });
  db.put('ludus_dialogue_trees/elder_sergius', {
    npcId: 'elder_sergius', npcName: 'Elder Sergius',
    theology: 'hesychasm', startNode: 'n1',
    nodes: [{ id: 'n1', text: 'Silence first.', branches: [
      { text: 'I listen', attributeBonuses: { wisdom: 1 } }] }],
  });
  db.put(`ludus_npc_memory/elder_sergius/players/${PLAYER}`, {
    firstMeeting: false, lastInteraction: 1700000000000,
    totalInteractions: 2,
    choiceHistory: [{ nodeId: 'n1', choice: 'I listen' }],
    attributeBonusesEarned: { wisdom: 2 },
  });
  db.put(`ludus_npc_memory/theodora/players/${PLAYER}`, {
    firstMeeting: false, totalInteractions: 1, choiceHistory: [],
    attributeBonusesEarned: { wisdom: 1, faith: 1 },
  });
  db.put(`ludus_npc_memory/theodora/players/${OTHER}`, {
    firstMeeting: false, totalInteractions: 1, choiceHistory: [],
    attributeBonusesEarned: { faith: 9 },
  });
  db.put(`ludus_dialogue_states/${PLAYER}_elder_sergius`, {
    playerId: PLAYER, npcId: 'elder_sergius', currentNodeId: 'n1' });
  db.put(`ludus_dialogue_states/${PLAYER}_theodora`, {
    playerId: PLAYER, npcId: 'theodora', currentNodeId: 'n2' });
  db.put(`ludus_dialogue_states/${OTHER}_theodora`, {
    playerId: OTHER, npcId: 'theodora', currentNodeId: 'n2' });
  ['p1', 'p2', 'n1', 'n2', 'n3'].forEach((id) => db.put(`ludus_nodes/${id}`,
    { nodeType: id.startsWith('p') ? 'player' : 'npc' }));
  db.put('ludus_edges/e1', { from: 'p1', to: 'n1' });
  db.put('ludus_knowledge_gates/foundational', { level: 1 });
  db.put('ludus_health_checks/h1', { timestamp: 100,
    avgSimulationCycleMs: 4, cycleCount: 10 });
  db.put('ludus_health_checks/h2', { timestamp: 200,
    avgSimulationCycleMs: 12, cycleCount: 20 });
  db.put('ludus_health_checks/h3', { avgSimulationCycleMs: 99 });
  // Not a game collection: the mirror must never copy it.
  db.put('subscribers/s1', { email: 'nobody@example.org' });
}

// ---------------------------------------------------------------------
// Request/response doubles shaped like the Express objects.
// ---------------------------------------------------------------------

interface Answer {
  status: number;
  body: any;
  headers: Record<string, string>;
}

async function call(handler: unknown, req: Partial<Data>): Promise<Answer> {
  const answer: Answer = { status: 200, body: undefined, headers: {} };
  const res: any = {
    set: (k: string, v: string) => {
      answer.headers[k] = v;
      return res;
    },
    status: (s: number) => {
      answer.status = s;
      return res;
    },
    json: (b: unknown) => {
      answer.body = JSON.parse(JSON.stringify(b));
      return res;
    },
    send: (b: unknown) => {
      answer.body = b;
      return res;
    },
  };
  await (handler as (q: unknown, s: unknown) => Promise<void>)({
    method: 'GET', params: {}, body: {}, headers: {}, ...req }, res);
  return answer;
}

// Fields that carry the moment of the call are equal only in shape.
function stable(a: Answer): Answer {
  const body = a.body && typeof a.body === 'object'
    ? JSON.parse(JSON.stringify(a.body)) : a.body;
  if (body && typeof body === 'object') {
    delete body.timestamp;
    delete body.uptime_seconds;
    if (body.context) {
      delete body.context.timestamp;
    }
  }
  return { ...a, body };
}

const READS: Array<[string, unknown, Partial<Data>]> = [
  ['tree found', getDialogueTree, { params: { npcId: 'elder_sergius' } }],
  ['tree missing', getDialogueTree, { params: { npcId: 'nobody' },
    headers: { 'user-agent': 'Quest 3' } }],
  ['memory found', getNpcMemory, { params: { npcId: 'elder_sergius',
    playerId: PLAYER } }],
  ['memory first meeting', getNpcMemory, { params: { npcId: 'kassia',
    playerId: PLAYER } }],
  ['memory of another player', getNpcMemory, { params: {
    npcId: 'elder_sergius', playerId: PLAYER },
  headers: { 'x-firebase-auth-user': OTHER } }],
  ['stats', getDialogueStats, { params: { playerId: PLAYER } }],
  ['stats missing player', getDialogueStats, { params: {
    playerId: 'player-missing' } }],
  ['actions read', ludusActions, { headers: {
    authorization: 'Bearer good' } }],
  ['actions unauthenticated', ludusActions, {}],
  ['health', ludusHealth, {}],
];

describe('storage seam: Firestore and the SQLite hot mirror', () => {
  let dir: string;
  let file: string;
  let fake: FakeFirestore;
  let firestore: Store;
  let mirror: SqliteStore;

  beforeAll(async () => {
    // The handlers log every call; the answers are what is asserted.
    jest.spyOn(console, 'log').mockImplementation(() => undefined);
    jest.spyOn(console, 'warn').mockImplementation(() => undefined);
    jest.spyOn(console, 'error').mockImplementation(() => undefined);
    dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ludus-mirror-'));
    file = path.join(dir, 'nested', 'mirror.sqlite');
    fake = new FakeFirestore();
    seed(fake);
    firestore = new FirestoreStore(fake as any, () => 'SERVER_TIME');
    const writer = new MirrorDb(file);
    await syncMirror(fake as any, writer);
    writer.close();
    mirror = new SqliteStore(file);
  });

  afterAll(() => {
    jest.restoreAllMocks();
    mirror.close();
    setStore(null);
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it.each(READS)('answers "%s" the same from both stores',
    async (_name, handler, req) => {
      setStore(firestore);
      const fromFirestore = await call(handler, req);
      setStore(mirror);
      const fromMirror = await call(handler, req);
      expect(stable(fromMirror)).toEqual(stable(fromFirestore));
    });

  it('gives the expected answers, not just equal ones', async () => {
    setStore(mirror);
    const stats = await call(getDialogueStats,
      { params: { playerId: PLAYER } });
    expect(stats.status).toBe(200);
    // Two NPCs, and the other player's memory is not counted.
    expect(stats.body).toEqual({ playerId: PLAYER, npcInteractions: 2,
      currentAttributes: { wisdom: 5, faith: 3, dexterity: 2 },
      totalBonusesEarned: { wisdom: 3, faith: 1 },
      dialogueEngagementLevel: 'beginner' });

    const actions = await call(ludusActions,
      { headers: { authorization: 'Bearer good' } });
    expect(actions.body.playerId).toBe(PLAYER);
    expect(actions.body.actions.prayerCount).toBe(7);
    // The secret deed's count stays hidden on the mirror as well.
    expect(actions.body.actions.practices.secret_deed)
      .toEqual({ lastDay: '2026-09-30' });

    const health = await call(ludusHealth, {});
    expect(health.status).toBe(503);
    expect(health.body.components.firestore).toEqual({ status: 'ok',
      nodeCount: 5, edgeCount: 1, gateCount: 1 });
    expect(health.body.components.seed_data.playerCount).toBe(2);
    expect(health.body.components.seed_data.npcCount).toBe(3);
    // Newest by timestamp; the document without one is left out.
    expect(health.body.components.simulation.lastCycleDurationMs).toBe(12);
  });

  it('answers 503 to every player write on the mirror', async () => {
    setStore(mirror);
    const writes: Array<[unknown, Partial<Data>]> = [
      [persistDialogueState, { method: 'POST', body: { playerId: PLAYER,
        npcId: 'elder_sergius', currentNodeId: 'n1',
        attributeBonuses: { wisdom: 1 } } }],
      [upsertDialogueTree, { method: 'POST',
        params: { npcId: 'elder_sergius' },
        headers: { authorization: 'Bearer admin' },
        body: { npcName: 'X', startNode: 'n1', nodes: [] } }],
      [ludusActions, { method: 'POST',
        headers: { authorization: 'Bearer good' },
        body: { op: 'prayKnot' } }],
    ];
    for (const [handler, req] of writes) {
      const answer = await call(handler, req);
      expect(answer.status).toBe(503);
      expect(answer.body.error).toMatch(/read-only mirror/i);
      expect(answer.body.store).toBe('mirror');
      expect(answer.headers['Retry-After']).toBe('60');
    }
    // Nothing reached the file: the stored state is unchanged.
    expect((await mirror.get(`ludus_players/${PLAYER}`))!.form)
      .toEqual({ wisdom: 5, faith: 3, dexterity: 2 });
    await expect(mirror.set()).rejects.toThrow(/read-only/);
  });

  it('keeps writing through Firestore in firestore mode', async () => {
    const db = new FakeFirestore();
    seed(db);
    setStore(new FirestoreStore(db as any, () => 'SERVER_TIME'));
    const saved = await call(persistDialogueState, { method: 'POST',
      body: { playerId: PLAYER, npcId: 'elder_sergius',
        currentNodeId: 'n1', attributeBonuses: { wisdom: 1 },
        dialogueHistory: [{ choiceText: 'I listen' }] } });
    expect(saved.status).toBe(200);
    expect(saved.body.bonusesApplied).toEqual(['wisdom']);
    expect(db.rows.get(`ludus_players/${PLAYER}`)!.data.form.wisdom)
      .toBe(6);
    const memory = db.rows.get(
      `ludus_npc_memory/elder_sergius/players/${PLAYER}`)!.data;
    expect(memory.totalInteractions).toBe(3);
    expect(memory.attributeBonusesEarned).toEqual({ wisdom: 3 });

    const acted = await call(ludusActions, { method: 'POST',
      headers: { authorization: 'Bearer good' }, body: { op: 'prayKnot' } });
    expect(acted.status).toBe(200);
    expect(acted.body.actions.prayerCount).toBe(8);
    const log = Array.from(db.rows.entries())
      .filter(([p]) => p.startsWith('ludus_actions_log/'));
    expect(log).toHaveLength(1);
    expect(log[0][1].data).toMatchObject({ playerId: PLAYER,
      op: 'prayKnot', at: 'SERVER_TIME' });
  });
});

describe('mirrorSync', () => {
  let dir: string;

  beforeEach(() => {
    dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ludus-sync-'));
  });

  afterEach(() => {
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('copies only ludus_* and is idempotent with a watermark',
    async () => {
      const db = new FakeFirestore();
      seed(db);
      const writer = new MirrorDb(path.join(dir, 'm.sqlite'));
      const first = await syncMirror(db as any, writer);
      const byKey = Object.fromEntries(first.map((r) => [r.source, r]));
      expect(Object.keys(byKey)).not.toContain('subscribers');
      expect(byKey.ludus_players).toMatchObject({ scanned: 2, written: 2,
        unchanged: 0, deleted: 0 });
      expect(byKey['group:players']).toMatchObject({ scanned: 3,
        written: 3 });
      const total = (writer.db.prepare('SELECT COUNT(*) AS n FROM docs')
        .get() as { n: number }).n;
      expect(total).toBe(first.reduce((n, r) => n + r.scanned, 0));
      expect(writer.db.prepare(
        "SELECT COUNT(*) AS n FROM docs WHERE path LIKE 'subscribers/%'")
        .get()).toEqual({ n: 0 });

      // A second run with nothing changed writes nothing.
      const second = await syncMirror(db as any, writer);
      second.forEach((r) => {
        expect(r.written).toBe(0);
        expect(r.deleted).toBe(0);
        expect(r.unchanged).toBe(r.scanned);
      });
      expect(second.map((r) => r.watermark))
        .toEqual(first.map((r) => r.watermark));

      // One change and one deletion: exactly those reach the mirror.
      db.put(`ludus_players/${OTHER}`, { form: { wisdom: 2 } });
      db.rows.delete('ludus_edges/e1');
      const third = Object.fromEntries((await syncMirror(db as any, writer,
        ['ludus_players', 'ludus_edges'])).map((r) => [r.source, r]));
      expect(Object.keys(third).sort())
        .toEqual(['ludus_edges', 'ludus_players']);
      expect(third.ludus_players).toMatchObject({ written: 1,
        unchanged: 1 });
      expect(third.ludus_players.watermark! > byKey.ludus_players.watermark!)
        .toBe(true);
      expect(third.ludus_edges).toMatchObject({ scanned: 0, deleted: 1 });
      writer.close();

      const reader = new SqliteStore(path.join(dir, 'm.sqlite'));
      expect(await reader.get(`ludus_players/${OTHER}`))
        .toEqual({ form: { wisdom: 2 } });
      expect(await reader.count('ludus_edges')).toBe(0);
      reader.close();
    });

  it('orders watermarks by nanoseconds, not just milliseconds', () => {
    expect(stampKey({ seconds: 5, nanoseconds: 2 })
      > stampKey({ seconds: 5, nanoseconds: 1 })).toBe(true);
    expect(stampKey({ seconds: 10, nanoseconds: 0 })
      > stampKey({ seconds: 9, nanoseconds: 999999999 })).toBe(true);
  });
});

describe('getStore()', () => {
  const saved = { ...process.env };

  afterEach(() => {
    process.env = { ...saved };
    setStore(null);
  });

  it('defaults to Firestore and chooses the mirror by LUDUS_STORE', () => {
    delete process.env.LUDUS_STORE;
    setStore(null);
    expect(getStore().mode).toBe('firestore');
    process.env.LUDUS_STORE = 'mirror';
    process.env.LUDUS_MIRROR_DB = '/nonexistent/mirror.sqlite';
    setStore(null);
    const store = getStore();
    expect(store.mode).toBe('mirror');
    expect(store.writable).toBe(false);
  });

  it('refuses an unknown mode instead of falling back', () => {
    process.env.LUDUS_STORE = 'postgres';
    setStore(null);
    expect(() => getStore()).toThrow(/Unknown LUDUS_STORE/);
  });

  it('reports a missing mirror file as an error on use', async () => {
    const store = new SqliteStore('/nonexistent/mirror.sqlite');
    await expect(store.get('ludus_players/x')).rejects.toThrow();
  });
});
