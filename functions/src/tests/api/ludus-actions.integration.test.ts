/**
 * The actions endpoint against the Firestore emulator: an operation is
 * written to ludus_players/{id}.actions in a transaction and journalled
 * in ludus_actions_log.  Token verification is mocked (no Auth
 * emulator here); everything below it is the real handler and database.
 * Run with: npm run test:emu
 */

import * as admin from 'firebase-admin';

if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'demo-ludus' });
}

jest.mock('../../middleware/auth', () => ({
  verifyIdToken: jest.fn(async (h?: string) =>
    (h === 'Bearer good' ? { uid: 'uid-actions-test-0001', role: 'player',
      isAuthenticated: true } : null)),
}));

import { ludusActions } from '../../api/ludus-actions';

const onEmulator = !!process.env.FIRESTORE_EMULATOR_HOST;
const maybe = onEmulator ? describe : describe.skip;

function call(method: string, body?: unknown, token = 'good') {
  const out: { status: number; body: any } = { status: 200, body: null };
  const res: any = {
    set: () => res,
    status: (s: number) => { out.status = s; return res; },
    json: (b: unknown) => { out.body = b; return res; },
    send: () => res,
  };
  const req: any = { method, body,
    headers: { authorization: `Bearer ${token}` } };
  return ludusActions(req, res).then(() => out);
}

maybe('POST/GET /api/ludus/actions (Firestore emulator)', () => {
  const ref = () => admin.firestore().collection('ludus_players')
    .doc('player-uid-actions-test');

  beforeAll(async () => {
    await ref().set({ form: { wisdom: 4 } });
  });

  it('refuses without a valid token', async () => {
    expect((await call('GET', undefined, 'bad')).status).toBe(401);
  });

  it('writes an operation to the player and the journal', async () => {
    const today = new Date().toISOString().slice(0, 10);
    const r1 = await call('POST', { op: 'practice', id: 'prayer_rope' });
    const r2 = await call('POST', { op: 'practice', id: 'alms', day: today });
    expect(r1.status).toBe(200);
    expect(r2.body.actions.practices.alms.count).toBe(1);
    const snap = await ref().get();
    expect(snap.get('actions.prayerCount')).toBe(1);
    expect(snap.get('form.wisdom')).toBe(4);
    const log = await admin.firestore().collection('ludus_actions_log')
      .where('playerId', '==', 'player-uid-actions-test').get();
    expect(log.size).toBeGreaterThanOrEqual(2);
  });

  it('survives a reload: GET returns what was stored', async () => {
    const r = await call('GET');
    expect(r.body.playerId).toBe('player-uid-actions-test');
    expect(r.body.actions.prayerCount).toBe(1);
  });

  it('answers 409 for a bow that is not due', async () => {
    const r = await call('POST', { op: 'acceptGift', gateId: 'mystical' });
    expect(r.status).toBe(409);
  });
});
