'use strict';

// The 26 acts of the place hearts on the web page play the headset's own
// walk (godot/tests/deeds_graph.gd → public/ludus/data/place-deeds.json):
// same steps, same words, same once-a-day record.  The Godot test checks
// that the file still matches the code; this one checks the page side.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const D = require('../public/ludus/ludus-place-deeds.js');

const GRAPH = JSON.parse(fs.readFileSync(path.join(__dirname,
  '../public/ludus/data/place-deeds.json'), 'utf8'));

// The stop-list is the headset's own file (godot/data/church-words.json,
// copied byte for byte to the web) with its one rule of matching, so the
// page and the headset hold one list: no church word on a button, a
// reply or a panel line (TABOO 0.39 item 3; blind spot 16).
const C = require('../public/ludus/ludus-church-words.js');
const CHURCH = JSON.parse(fs.readFileSync(path.join(__dirname,
  '../public/ludus/data/church-words.json'), 'utf8'));

function hasChurchWord(s) {
  return C.churchWord(CHURCH, s) !== '';
}

test('all 26 acts are in the walk, each with its start', () => {
  const ids = D.ids(GRAPH);
  assert.equal(ids.length, 26);
  ids.forEach((id) => {
    const v = D.view(GRAPH, D.start(GRAPH, id));
    assert.equal(v.done, false, id);
    assert.equal(v.reply, '', id);
    assert.ok(v.options.length > 0, id);
  });
  assert.ok(ids.includes('forge-nail') && ids.includes('share-water'));
  // Each act has its place: a name and the heart's words, plain words.
  ids.forEach((id) => {
    const p = D.place(GRAPH, id);
    assert.ok(p.id && p.title && p.heart && p.teaching, id);
    assert.ok(!hasChurchWord(p.heart), id + ': ' + p.heart);
  });
});

test('every act closes by its buttons or by waiting, and a closed act '
  + 'offers no button', () => {
  D.ids(GRAPH).forEach((id) => {
    const seen = new Set([0]);
    const queue = [D.start(GRAPH, id)];
    let closed = false;
    while (queue.length && !closed) {
      const st = queue.shift();
      const v = D.view(GRAPH, st);
      const nexts = v.options.filter((o) => !o.disabled)
        .map((o) => D.choose(GRAPH, st, o.id));
      nexts.push(D.wait(GRAPH, st));
      for (const n of nexts) {
        if (D.view(GRAPH, n).done) {
          closed = true;
          assert.equal(D.view(GRAPH, n).options.length, 0, id);
          break;
        }
        if (!seen.has(n.node)) {
          seen.add(n.node);
          queue.push(n);
        }
      }
    }
    assert.ok(closed, id + ': some way closes the act');
  });
});

test('no church word in any button, reply or line', () => {
  assert.ok(CHURCH.stems.length >= 20 && CHURCH.stems.includes('молитв'));
  D.ids(GRAPH).forEach((id) => {
    GRAPH.acts[id].nodes.forEach((n, i) => {
      const v = D.view(GRAPH, { act: id, node: i });
      const texts = v.lines.concat([v.reply],
        v.options.map((o) => o.text));
      texts.forEach((t) => assert.ok(!hasChurchWord(t), id + ': ' + t));
    });
  });
});

test('a closed button says why and moves nothing; an unknown one too',
  () => {
    D.ids(GRAPH).forEach((id) => {
      GRAPH.acts[id].nodes.forEach((n, i) => {
        const st = { act: id, node: i };
        D.view(GRAPH, st).options.filter((o) => o.disabled)
          .forEach((o) => {
            assert.ok(o.reason !== '', id + ': ' + o.text);
            assert.deepEqual(D.choose(GRAPH, st, o.id), st);
          });
        assert.deepEqual(D.choose(GRAPH, st, 'no-such-step'), st);
      });
    });
  });

test('the storm is waited out, by the seconds the headset counts', () => {
  const nodes = GRAPH.acts['wait-out-storm'].nodes;
  const waits = nodes.filter((n) => n.wait);
  assert.ok(waits.length > 0);
  waits.forEach((n) => assert.ok(n.wait.seconds > 0
    && Number.isInteger(n.wait.seconds)));
});

test('the record counts once a day and keeps only its shape', () => {
  const day = '2026-10-01';
  const r = D.record({}, GRAPH, 'test-ice', day);
  assert.deepEqual(r, { 'test-ice': { count: 1, lastDay: day } });
  assert.deepEqual(D.record(r, GRAPH, 'test-ice', day), r);
  assert.equal(D.record(r, GRAPH, 'test-ice', '2026-10-02')['test-ice']
    .count, 2);
  // The same hand-edited save as tests/test_place_deeds.gd _record.
  assert.deepEqual(D.normalize({ 'test-ice': { count: '9',
    lastDay: 'yesterday' }, unknown: { count: 5 }, x: 3 }, GRAPH),
  { 'test-ice': { count: 0, lastDay: null } });
  assert.deepEqual(D.normalize(null, GRAPH), {});
});

test('the module has no act logic, randomness, storage or network', () => {
  const src = fs.readFileSync(path.join(__dirname,
    '../public/ludus/ludus-place-deeds.js'), 'utf8');
  for (const api of ['Math.random', 'localStorage', 'sessionStorage',
    'indexedDB', 'fetch(', 'XMLHttpRequest', 'sendBeacon',
    'document.cookie']) {
    assert.ok(!src.includes(api), api);
  }
  // No act id is spelled in the module: the acts live only in the walk.
  D.ids(GRAPH).forEach((id) => assert.ok(!src.includes(id), id));
});
