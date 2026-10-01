/**
 * The container server (backend 3.0, P1) answers over real HTTP and
 * routes through the same dispatch() as the Cloud Function.
 */

import type { AddressInfo } from 'net';
import type { Server } from 'http';

jest.mock('firebase-admin', () => ({
  apps: [],
  initializeApp: jest.fn(),
  firestore: Object.assign(jest.fn(() => ({})), {
    FieldValue: { serverTimestamp: jest.fn(), increment: jest.fn() },
  }),
  auth: jest.fn(() => ({ verifyIdToken: jest.fn() })),
}));

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { createApp } = require('../../server');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const router = require('../../api/ludus-router');

let server: Server;
let base = '';

beforeAll((done) => {
  server = createApp().listen(0, () => {
    base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
    done();
  });
});

afterAll((done) => {
  server.close(() => done());
});

test('an unknown path answers 404 JSON from dispatch', async () => {
  const res = await fetch(`${base}/api/ludus/nowhere`);
  expect(res.status).toBe(404);
  const body = (await res.json()) as { error: string };
  expect(body.error).toBe('No route for GET /api/ludus/nowhere');
});

test('the Cloud Function and the server share one dispatcher', () => {
  expect(typeof router.dispatch).toBe('function');
  expect(router.matchRoute('GET', '/api/ludus/health')).toEqual(
    { name: 'ludusHealth', params: {} });
});

test('a crafted path cannot reach a handler', async () => {
  const res = await fetch(`${base}/api/ludus/dialogue/tree/..%2F..%2Fx`);
  expect(res.status).toBe(404);
});
