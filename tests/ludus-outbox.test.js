'use strict';

// The outbox keeps rule acts while offline and sends them in order
// when the network returns; the server stays the judge (HLD F4).

const test = require('node:test');
const assert = require('node:assert/strict');
const O = require('../public/ludus/ludus-outbox.js');

function memStore() {
  const m = new Map();
  return { getItem: (k) => (m.has(k) ? m.get(k) : null),
    setItem: (k, v) => m.set(k, String(v)) };
}

const T = Date.parse('2026-09-29T12:00:00Z');

test('only rule operations are queued', () => {
  const s = memStore();
  assert.equal(O.enqueue(s, { op: 'practice', id: 'alms' }, T), true);
  assert.equal(O.enqueue(s, { op: 'acceptGift', gateId: 'x' }, T), false);
  assert.equal(O.enqueue(s, { op: 'confession' }, T), false);
  assert.equal(O.size(s), 1);
});

test('flush sends in order and stops at a network failure', async () => {
  const s = memStore();
  O.enqueue(s, { op: 'practice', id: 'a' }, T);
  O.enqueue(s, { op: 'practice', id: 'b' }, T);
  O.enqueue(s, { op: 'practice', id: 'c' }, T);
  const seen = [];
  const r = await O.flush(s, async (op) => {
    seen.push(op.id);
    if (op.id === 'b') {
      throw new Error('offline');
    }
    return { ok: true, status: 200 };
  }, T + 1000);
  assert.deepEqual(seen, ['a', 'b']);
  assert.deepEqual(r, { sent: 1, dropped: 0, left: 2 });
});

test('refused and stale acts are dropped, not replayed forever', async () => {
  const s = memStore();
  O.enqueue(s, { op: 'practice', id: 'old' }, T - 2 * 86400000);
  O.enqueue(s, { op: 'practice', id: 'bad' }, T);
  O.enqueue(s, { op: 'practice', id: 'good' }, T);
  const r = await O.flush(s, async (op) => (op.id === 'bad'
    ? { ok: false, status: 429 } : { ok: true, status: 200 }), T);
  assert.deepEqual(r, { sent: 1, dropped: 2, left: 0 });
});

test('a server error keeps the act for later', async () => {
  const s = memStore();
  O.enqueue(s, { op: 'practice', id: 'a' }, T);
  const r = await O.flush(s, async () => ({ ok: false, status: 503 }), T);
  assert.deepEqual(r, { sent: 0, dropped: 0, left: 1 });
});
