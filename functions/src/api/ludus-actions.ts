/**
 * ACTION layer on the backend: ritual counters written to Firestore.
 *
 * The browser module public/ludus/ludus-actions.js evaluates gates for
 * guests on the device.  Signed-in players need the same counters in
 * the database ("Firestore as Heaven": ludus_players/{id}.actions), so
 * they survive a reload and another device.  The client cannot write
 * there itself: the security rules compare request.auth.uid with the
 * document id, while player ids are "player-<uid16>", so every write
 * goes through this endpoint with the Admin SDK.
 *
 * The server never trusts counts sent by the client.  It receives one
 * operation at a time, applies it with the same rules as the browser
 * module and checks what the client cannot prove:
 *   - stillness counts one minute at most every 60 seconds;
 *   - a fast is kept once per day, and the day must be within one day
 *     of the server's UTC date (time zones differ, the calendar not);
 *   - the bow for gates 4-6 is accepted only when the FORM stored in
 *     the database and the counters already satisfy the gate.
 * Every accepted operation is appended to ludus_actions_log, which is
 * never deleted (CLAUDE.md TABOO 0.25 item 5).  Counters are shown to
 * the player and never turned into XP (TABOO 0.35 rule 16).
 */

import * as admin from 'firebase-admin';
import { Request, Response } from 'express';

import { verifyIdToken } from '../middleware/auth';

const db = admin.firestore();

export interface Actions {
  prayerCount: number;
  fastDays: number;
  meditationHours: number;
  lastFastDay: string | null;
  lastStillnessAt: number;
  met: Record<string, number>;
  gifts: Record<string, true>;
  practices: Record<string, { count: number; lastDay: string | null;
    lastAt: number }>;
}

interface Practice {
  id: string;
  kind: 'count' | 'daily' | 'timer';
  minutes?: number;
  legacy?: 'prayerCount' | 'fastDays' | 'meditationHours';
}

// Must stay equal (ids, kinds, minutes, legacy keys) to PRACTICES in
// public/ludus/ludus-actions.js; the labels, passions and patristic
// sources live there, next to the UI that shows them.
export const PRACTICES: Practice[] = [
  { id: 'prayer_rope', kind: 'count', legacy: 'prayerCount' },
  { id: 'fast', kind: 'daily', legacy: 'fastDays' },
  { id: 'stillness', kind: 'timer', minutes: 1, legacy: 'meditationHours' },
  { id: 'prostrations', kind: 'count' },
  { id: 'vigil', kind: 'timer', minutes: 10 },
  { id: 'handiwork', kind: 'timer', minutes: 5 },
  { id: 'alms', kind: 'daily' },
  { id: 'forgive', kind: 'daily' },
  { id: 'thanksgiving', kind: 'daily' },
  { id: 'guard_thoughts', kind: 'daily' },
  { id: 'obedience', kind: 'daily' },
  { id: 'secret_deed', kind: 'daily' },
];

interface Gate {
  id: string;
  wisdom: number;
  mentors: string[];
  rite: { key: 'prayerCount' | 'fastDays' | 'meditationHours'; min: number };
  gift?: boolean;
}

// Must stay equal to GATES in public/ludus/ludus-actions.js; the test
// ludus-actions.test.ts compares both tables.
export const GATES: Gate[] = [
  { id: 'foundational', wisdom: 4, mentors: ['theodora'],
    rite: { key: 'prayerCount', min: 10 } },
  { id: 'liturgical', wisdom: 6, mentors: ['theodora', 'elder_sergius'],
    rite: { key: 'prayerCount', min: 33 } },
  { id: 'ascetic', wisdom: 8, mentors: ['abba_john'],
    rite: { key: 'fastDays', min: 1 } },
  { id: 'contemplative', wisdom: 10, mentors: ['elder_sergius'],
    gift: true, rite: { key: 'meditationHours', min: 10 / 60 } },
  { id: 'mystical', wisdom: 12, mentors: ['sister_catherine'],
    gift: true, rite: { key: 'meditationHours', min: 30 / 60 } },
  { id: 'apophatic', wisdom: 14,
    mentors: ['elder_sergius', 'theodora', 'abba_john', 'sister_catherine'],
    gift: true, rite: { key: 'meditationHours', min: 1 } },
];

const ID_RE = /^[a-z_]{1,40}$/;
const DAY_RE = /^\d{4}-\d{2}-\d{2}$/;
const STILLNESS_GAP_MS = 60_000;
const DAY_MS = 86_400_000;

function num(value: unknown): number {
  const n = Number(value);
  return Number.isFinite(n) && n > 0 ? n : 0;
}

/** Drop unknown keys and bad values, as the browser module does. */
export function normalize(raw: unknown): Actions {
  const src = (raw && typeof raw === 'object' ? raw : {}) as
    Record<string, unknown>;
  const met: Record<string, number> = {};
  const gifts: Record<string, true> = {};
  const srcMet = (src.met && typeof src.met === 'object' ? src.met : {}) as
    Record<string, unknown>;
  Object.keys(srcMet).forEach((id) => {
    if (ID_RE.test(id)) {
      met[id] = Math.floor(num(srcMet[id]));
    }
  });
  const srcGifts = (src.gifts && typeof src.gifts === 'object'
    ? src.gifts : {}) as Record<string, unknown>;
  GATES.forEach((gate) => {
    if (srcGifts[gate.id] === true) {
      gifts[gate.id] = true;
    }
  });
  const practices: Actions['practices'] = {};
  const srcPr = (src.practices && typeof src.practices === 'object'
    ? src.practices : {}) as Record<string, Record<string, unknown>>;
  PRACTICES.forEach((pr) => {
    const item = srcPr[pr.id];
    if (!pr.legacy && item && typeof item === 'object') {
      practices[pr.id] = {
        count: Math.floor(num(item.count)),
        lastDay: typeof item.lastDay === 'string'
          && DAY_RE.test(item.lastDay) ? item.lastDay : null,
        lastAt: num(item.lastAt),
      };
    }
  });
  return {
    practices,
    prayerCount: Math.floor(num(src.prayerCount)),
    fastDays: Math.floor(num(src.fastDays)),
    meditationHours: num(src.meditationHours),
    lastFastDay: typeof src.lastFastDay === 'string'
      && DAY_RE.test(src.lastFastDay) ? src.lastFastDay : null,
    lastStillnessAt: num(src.lastStillnessAt),
    met,
    gifts,
  };
}

/** True when every condition except the gift holds for the gate. */
export function readyForGift(gate: Gate, form: Record<string, unknown>,
  actions: Actions): boolean {
  if (!gate.gift || num(form.wisdom) < gate.wisdom) {
    return false;
  }
  if (gate.mentors.some((id) => !actions.met[id])) {
    return false;
  }
  return num(actions[gate.rite.key]) + 1e-9 >= gate.rite.min;
}

export type Op =
  | { op: 'practice'; id: string; day?: string }
  | { op: 'prayKnot' }
  | { op: 'keepFast'; day: string }
  | { op: 'addStillness' }
  | { op: 'recordMeeting'; npcId: string }
  | { op: 'acceptGift'; gateId: string };

export class ActionError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

function checkDay(day: unknown, now: number): string {
  if (!DAY_RE.test(String(day))) {
    throw new ActionError(400, 'day must be YYYY-MM-DD');
  }
  const drift = Math.abs(Date.parse(`${day}T12:00:00Z`) - now);
  if (!(drift <= 1.5 * DAY_MS)) {
    throw new ActionError(400, 'day is not today');
  }
  return String(day);
}

/**
 * One act of a practice.  A timer is accepted only when at least its
 * length has passed since the previous accepted session, so the client
 * cannot report ten vigils in one minute.
 */
function applyPractice(next: Actions, id: string, day: unknown,
  now: number): Actions {
  const pr = PRACTICES.find((p) => p.id === id);
  if (!pr) {
    throw new ActionError(400, 'unknown practice');
  }
  if (pr.legacy === 'prayerCount') {
    next.prayerCount += 1;
    return next;
  }
  if (pr.legacy === 'fastDays') {
    const d = checkDay(day, now);
    if (next.lastFastDay !== d) {
      next.fastDays += 1;
      next.lastFastDay = d;
    }
    return next;
  }
  if (pr.legacy === 'meditationHours') {
    if (now - next.lastStillnessAt < STILLNESS_GAP_MS) {
      throw new ActionError(429, 'one minute of stillness per minute');
    }
    next.meditationHours = +(next.meditationHours + 1 / 60).toFixed(4);
    next.lastStillnessAt = now;
    return next;
  }
  const item = next.practices[pr.id] || { count: 0, lastDay: null,
    lastAt: 0 };
  if (pr.kind === 'count') {
    item.count += 1;
  } else if (pr.kind === 'daily') {
    const d = checkDay(day, now);
    if (item.lastDay === d) {
      return next;
    }
    item.count += 1;
    item.lastDay = d;
  } else {
    const minutes = pr.minutes || 1;
    if (now - item.lastAt < minutes * 60_000) {
      throw new ActionError(429, `one session per ${minutes} min`);
    }
    item.count += minutes;
    item.lastAt = now;
  }
  next.practices[pr.id] = item;
  return next;
}

/**
 * Apply one operation.  Pure: the clock and the stored FORM are passed
 * in, so tests need no emulator and no real time.
 */
export function applyOp(current: Actions, input: Op, now: number,
  form: Record<string, unknown>): Actions {
  const next = normalize(current);
  switch (input.op) {
    case 'practice':
      return applyPractice(next, input.id, input.day, now);
    // The first three operations predate the twelve practices and are
    // kept as aliases, so an older client keeps working.
    case 'prayKnot':
      return applyPractice(next, 'prayer_rope', undefined, now);
    case 'keepFast':
      return applyPractice(next, 'fast', input.day, now);
    case 'addStillness':
      return applyPractice(next, 'stillness', undefined, now);
    case 'recordMeeting':
      if (!ID_RE.test(String(input.npcId))) {
        throw new ActionError(400, 'bad npcId');
      }
      next.met[input.npcId] = (next.met[input.npcId] || 0) + 1;
      return next;
    case 'acceptGift': {
      const gate = GATES.find((g) => g.id === input.gateId);
      if (!gate || !gate.gift) {
        throw new ActionError(400, 'this gate is not received as a gift');
      }
      if (!readyForGift(gate, form, next)) {
        throw new ActionError(409, 'the other conditions are not met yet');
      }
      next.gifts[gate.id] = true;
      return next;
    }
    default:
      throw new ActionError(400, 'unknown op');
  }
}

function setCors(res: Response): void {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type,Authorization');
}

/** Same scheme as playerIdFor() in public/ludus/ludus-game.js. */
export function playerIdForUid(uid: string): string {
  return `player-${uid.substring(0, 16)}`;
}

/** The client-visible shape: no server bookkeeping fields. */
function publicView(actions: Actions): Record<string, unknown> {
  const { lastStillnessAt: _hidden, practices, ...rest } = actions;
  const shown: Record<string, unknown> = {};
  Object.keys(practices).forEach((id) => {
    const { lastAt: _at, ...item } = practices[id];
    // A secret good deed is stored for the journal but its count is
    // not sent back: counting it in front of the player would feed
    // vainglory (Mt 6:3-4).  Only "kept today" is needed by the UI.
    shown[id] = id === 'secret_deed' ? { lastDay: item.lastDay } : item;
  });
  return { ...rest, practices: shown };
}

/** GET /api/ludus/actions and POST /api/ludus/actions {op, ...}. */
export async function ludusActions(req: Request, res: Response):
  Promise<void> {
  setCors(res);
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  const auth = await verifyIdToken(req.headers.authorization);
  if (!auth) {
    res.status(401).json({ error: 'Sign in to keep your rule of prayer' });
    return;
  }
  const playerId = playerIdForUid(auth.uid);
  const ref = db.collection('ludus_players').doc(playerId);

  if (req.method === 'GET') {
    const snap = await ref.get();
    res.json({ playerId,
      actions: publicView(normalize(snap.exists ? snap.get('actions') : {})) });
    return;
  }

  const input = (req.body || {}) as Op;
  try {
    const actions = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const data = snap.exists ? snap.data() || {} : {};
      const next = applyOp(normalize(data.actions), input, Date.now(),
        (data.form || {}) as Record<string, unknown>);
      tx.set(ref, { actions: next }, { merge: true });
      // The journal only grows; it records what was done, not a score.
      tx.create(db.collection('ludus_actions_log').doc(), {
        playerId, op: input.op,
        npcId: 'npcId' in input ? input.npcId : null,
        gateId: 'gateId' in input ? input.gateId : null,
        practice: input.op === 'practice' ? input.id : null,
        at: admin.firestore.FieldValue.serverTimestamp(),
      });
      return next;
    });
    res.json({ playerId, actions: publicView(actions) });
  } catch (error) {
    if (error instanceof ActionError) {
      res.status(error.status).json({ error: error.message });
      return;
    }
    console.error('[ludusActions]', error);
    res.status(500).json({ error: 'Could not save the action' });
  }
}
