'use strict';

// The exported journal: the player's own record, no secret count, no
// confession, no measure of holiness (HLD F5; TABOO 0.26, 0.39).

const test = require('node:test');
const assert = require('node:assert/strict');
const A = require('../public/ludus/ludus-actions.js');
const J = require('../public/ludus/ludus-journal.js');
const passionData = require('../public/ludus/data/passions.json');

function sample() {
  let a = A.EMPTY;
  a = A.doPractice(a, 'prayer_rope');
  a = A.doPractice(a, 'secret_deed', { day: '2026-09-29' });
  a = A.doPractice(a, 'secret_deed', { day: '2026-09-30' });
  return {
    form: { wisdom: 5, faith: 3 },
    actions: a,
    passions: { gluttony: { meetings: 2, overcome: 1, captive: 1,
      discerned: true } },
    passionData,
    now: new Date('2026-09-30T08:00:00Z'),
  };
}

test('the page lists form, rule, ladder and the road', () => {
  const md = J.toMarkdown(sample(), A);
  assert.match(md, /^# The way/);
  assert.match(md, /- Wisdom: 5/);
  assert.match(md, /- Erudition: 0/);
  assert.match(md, /named at its first sign \(2 meetings\)/);
  assert.match(md, /Written on 2026-09-30/);
});

test('the secret good deed is never counted on the page', () => {
  const md = J.toMarkdown(sample(), A);
  const secret = A.PRACTICES.find((p) => p.secret);
  const line = md.split('\n').find((l) => l.includes(secret.label));
  assert.ok(line, 'the practice is named');
  assert.match(line, /known to God/);
  assert.doesNotMatch(line, /\d/);
});

test('no church words as labels and nothing about confession', () => {
  const md = J.toMarkdown(sample(), A);
  assert.doesNotMatch(md, /confession|исповед/i);
  assert.doesNotMatch(md, /\b(grace|saint|holiness level|martyr)\b/i);
});

// The acts done at the hearts of places (blind spot 12): the place's
// title, how many times and the last day; unknown acts are dropped.
test('the deeds of places: title, times and last day, known acts only',
  () => {
    const graph = require('../public/ludus/data/place-deeds.json');
    const places = {};
    Object.keys(graph.acts).forEach((id) => {
      places[id] = graph.acts[id].place.title;
    });
    const md = J.toMarkdown(Object.assign(sample(), {
      deeds: { 'wait-out-storm': { count: 2, lastDay: '2026-10-01' },
        'forge-nail': { count: 0, lastDay: null },
        'no-such-act': { count: 9, lastDay: '2026-10-01' } },
      deedPlaces: places,
    }), A);
    assert.match(md, new RegExp('## Deeds of places\\n\\n- Штормовой '
      + 'залив: done 2 times, last on 2026-10-01\\.\\n\\n'));
    assert.doesNotMatch(md, /no-such-act|Кузня/);
    const none = J.toMarkdown(sample(), A);
    assert.match(none, /- No act at the heart of a place done yet\./);
  });
