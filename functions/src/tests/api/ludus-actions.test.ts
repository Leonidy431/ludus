/**
 * Server-side ACTION layer.  applyOp is pure, so these tests need no
 * emulator: the clock and the stored FORM are passed in.  The parity
 * test keeps the server tables equal to the browser module, which the
 * guest mode uses on the device.
 */

jest.mock('firebase-admin', () => ({
  firestore: Object.assign(() => ({}), { FieldValue: {} }),
}));

import {
  applyOp, normalize, GATES, PRACTICES, ActionError, playerIdForUid,
} from '../../api/ludus-actions';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const client = require('../../../../public/ludus/ludus-actions.js');

const NOW = Date.parse('2026-09-29T12:00:00Z');
const EMPTY = normalize({});

function expectError(fn: () => unknown, status: number) {
  try {
    fn();
  } catch (e) {
    expect(e).toBeInstanceOf(ActionError);
    expect((e as ActionError).status).toBe(status);
    return;
  }
  throw new Error('expected an ActionError');
}

describe('ludus actions (server)', () => {
  it('matches the browser gates and practices', () => {
    expect(GATES.map((g) => [g.id, g.wisdom, g.mentors, g.rite.key,
      g.rite.min, !!g.gift])).toEqual(client.GATES.map((g: any) =>
      [g.id, g.wisdom, g.mentors, g.rite.key, g.rite.min, !!g.gift]));
    expect(PRACTICES.map((p) => [p.id, p.kind, p.minutes, p.legacy]))
      .toEqual(client.PRACTICES.map((p: any) =>
        [p.id, p.kind, p.minutes, p.legacy]));
    expect(PRACTICES).toHaveLength(12);
  });

  it('counts a daily practice once per day and rejects another day',
    () => {
      let a = applyOp(EMPTY, { op: 'practice', id: 'alms',
        day: '2026-09-29' }, NOW, {});
      a = applyOp(a, { op: 'practice', id: 'alms', day: '2026-09-29' },
        NOW, {});
      expect(a.practices.alms.count).toBe(1);
      expectError(() => applyOp(a, { op: 'practice', id: 'alms',
        day: '2026-10-05' }, NOW, {}), 400);
    });

  it('accepts a timer only after its full length', () => {
    let a = applyOp(EMPTY, { op: 'practice', id: 'vigil' }, NOW, {});
    expect(a.practices.vigil.count).toBe(10);
    expectError(() => applyOp(a, { op: 'practice', id: 'vigil' },
      NOW + 9 * 60_000, {}), 429);
    a = applyOp(a, { op: 'practice', id: 'vigil' }, NOW + 10 * 60_000, {});
    expect(a.practices.vigil.count).toBe(20);
  });

  it('keeps the legacy operations as aliases', () => {
    let a = applyOp(EMPTY, { op: 'prayKnot' }, NOW, {});
    a = applyOp(a, { op: 'keepFast', day: '2026-09-29' }, NOW, {});
    a = applyOp(a, { op: 'addStillness' }, NOW, {});
    expect([a.prayerCount, a.fastDays, a.meditationHours])
      .toEqual([1, 1, +(1 / 60).toFixed(4)]);
    expectError(() => applyOp(a, { op: 'addStillness' }, NOW + 1000, {}),
      429);
  });

  it('accepts the bow only when the stored FORM and counters allow',
    () => {
      let a = applyOp(EMPTY, { op: 'recordMeeting', npcId: 'elder_sergius' },
        NOW, {});
      expectError(() => applyOp(a, { op: 'acceptGift',
        gateId: 'contemplative' }, NOW, { wisdom: 10 }), 409);
      for (let i = 0; i < 10; i += 1) {
        a = applyOp(a, { op: 'addStillness' }, NOW + i * 60_000, {});
      }
      expectError(() => applyOp(a, { op: 'acceptGift',
        gateId: 'contemplative' }, NOW, { wisdom: 9 }), 409);
      a = applyOp(a, { op: 'acceptGift', gateId: 'contemplative' }, NOW,
        { wisdom: 10 });
      expect(a.gifts.contemplative).toBe(true);
      expectError(() => applyOp(a, { op: 'acceptGift',
        gateId: 'foundational' }, NOW, { wisdom: 20 }), 400);
    });

  it('rejects unknown practices and ids that could reach a path', () => {
    expectError(() => applyOp(EMPTY, { op: 'practice', id: 'xp_boost' },
      NOW, {}), 400);
    expectError(() => applyOp(EMPTY, { op: 'recordMeeting',
      npcId: '../x' }, NOW, {}), 400);
  });

  it('never grows the FORM', () => {
    let a = EMPTY;
    PRACTICES.forEach((p, i) => {
      a = applyOp(a, { op: 'practice', id: p.id, day: '2026-09-29' },
        NOW + i * 3_600_000, {});
    });
    expect(Object.keys(a)).not.toContain('wisdom');
    expect(Object.keys(a)).not.toContain('xp');
  });

  it('keeps the outcome of a passion encounter, not a score', () => {
    let a = applyOp(EMPTY, { op: 'passionEnd', passion: 'gluttony',
      end: 'captive' }, NOW, {});
    a = applyOp(a, { op: 'passionEnd', passion: 'gluttony', end: 'virtue',
      named: true }, NOW, {});
    a = applyOp(a, { op: 'passionEnd', passion: 'lust', end: 'left' },
      NOW, {});
    expect(a.passions.gluttony).toEqual({ meetings: 2, overcome: 1,
      captive: 1, discerned: true });
    expect(a.passions.lust).toEqual({ meetings: 1, overcome: 0,
      captive: 0, discerned: false });
    expect(normalize(JSON.parse(JSON.stringify(a))).passions)
      .toEqual(a.passions);
    expect(Object.keys(a)).not.toContain('wisdom');
  });

  it('rejects an unknown passion or ending', () => {
    expectError(() => applyOp(EMPTY, { op: 'passionEnd',
      passion: 'greed2', end: 'virtue' }, NOW, {}), 400);
    expectError(() => applyOp(EMPTY, { op: 'passionEnd',
      passion: 'anger', end: 'won' }, NOW, {}), 400);
  });

  it('derives the player id from the uid only', () => {
    expect(playerIdForUid('abcdefghijklmnopqrstu')).toBe(
      'player-abcdefghijklmnop');
  });
});
