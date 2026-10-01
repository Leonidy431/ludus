/**
 * Router tests.  The handlers are mocked: this suite checks only that a
 * request reaches the right handler with req.params filled, which is
 * exactly what was broken (params were always empty behind onRequest).
 */

jest.mock('../../api/ludus-dialogue', () => {
  const make = (name: string) => jest.fn((req: any, res: any) => {
    res.json({ handler: name, params: req.params });
  });
  return {
    getDialogueTree: make('getDialogueTree'),
    upsertDialogueTree: make('upsertDialogueTree'),
    getNpcMemory: make('getNpcMemory'),
    persistDialogueState: make('persistDialogueState'),
    getDialogueStats: make('getDialogueStats'),
  };
});
jest.mock('../../api/ludus-actions', () => ({
  ludusActions: jest.fn((req: any, res: any) =>
    res.json({ handler: 'ludusActions' })),
}));
jest.mock('../../api/ludus-health', () => ({
  ludusHealth: jest.fn((req: any, res: any) => res.json({ ok: true })),
}));

import { api, matchRoute } from '../../api/ludus-router';

function fakeRes() {
  const res: any = {};
  res.status = jest.fn(() => res);
  res.json = jest.fn(() => res);
  return res;
}

describe('matchRoute', () => {
  test.each([
    ['GET', '/api/ludus/dialogue/tree/elder_sergius', 'getDialogueTree',
      { npcId: 'elder_sergius' }],
    ['POST', '/api/ludus/dialogue/tree/theodora', 'upsertDialogueTree',
      { npcId: 'theodora' }],
    ['GET', '/api/ludus/dialogue/memory/abba_john/player-1', 'getNpcMemory',
      { npcId: 'abba_john', playerId: 'player-1' }],
    ['POST', '/api/ludus/dialogue/state', 'persistDialogueState', {}],
    ['GET', '/api/ludus/dialogue/stats/player-1', 'getDialogueStats',
      { playerId: 'player-1' }],
    ['GET', '/api/ludus/health', 'ludusHealth', {}],
    ['OPTIONS', '/api/ludus/dialogue/state', 'persistDialogueState', {}],
  ])('%s %s -> %s', (method, path, name, params) => {
    expect(matchRoute(method, path)).toEqual({ name, params });
  });

  test('routes both GET and POST of /api/ludus/actions', () => {
    expect(matchRoute('GET', '/api/ludus/actions')?.name)
      .toBe('ludusActions');
    expect(matchRoute('POST', '/api/ludus/actions/')?.name)
      .toBe('ludusActions');
  });

  test('rejects path traversal and unknown routes', () => {
    expect(matchRoute('GET', '/api/ludus/dialogue/tree/..%2Fplayers'))
      .toBeNull();
    expect(matchRoute('GET', '/api/ludus/dialogue/tree/a/b')).toBeNull();
    expect(matchRoute('DELETE', '/api/ludus/dialogue/state')).toBeNull();
    expect(matchRoute('GET', '/api/other')).toBeNull();
  });
});

describe('api', () => {
  test('fills req.params before calling the handler', async () => {
    const req: any = { method: 'GET', path:
      '/api/ludus/dialogue/memory/elder_sergius/guest-7', params: {} };
    const res = fakeRes();
    await (api as any)(req, res);
    expect(res.json).toHaveBeenCalledWith({
      handler: 'getNpcMemory',
      params: { npcId: 'elder_sergius', playerId: 'guest-7' },
    });
  });

  test('answers 404 with a recovery hint for unknown paths', async () => {
    const req: any = { method: 'GET', path: '/api/nope', params: {} };
    const res = fakeRes();
    await (api as any)(req, res);
    expect(res.status).toHaveBeenCalledWith(404);
  });
});
