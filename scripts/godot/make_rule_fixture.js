'use strict';
// Write godot/tests/fixtures/rule.json from public/ludus/ludus-actions.js
// (the rule of prayer: normalize, doPractice, practiceTally, keptToday)
// and public/ludus/ludus-missions.js (fallStatus, liftFall): the
// reference for RuleCore and for the evening watch over thoughts that
// lifts a fall in the hub.  The GDScript side replays every step with
// the same inputs and compares the whole rule after each one.
// Usage: node scripts/godot/make_rule_fixture.js

const fs = require('fs');
const path = require('path');
const A = require('../../public/ludus/ludus-actions.js');
const M = require('../../public/ludus/ludus-missions.js');

const root = path.join(__dirname, '..', '..');
const data = (name) => require(path.join(root, 'public/ludus/data', name));
const ctx = {
  spine: data('campaign-spine.json'),
  trials: data('gate-trials.json'),
  trees: data('dialogue-trees.json'),
  lake: data('lake-objects-99.json'),
  passions: data('passions.json'),
  actionsApi: A,
};
const clone = (o) => JSON.parse(JSON.stringify(o));
const IDS = A.PRACTICES.map((p) => p.id);

// The whole rule as the port must see it after a step (passions are
// kept apart in the hub, so they are left out here).
function snapshot(a, day) {
  const n = A.normalize(a);
  const tally = {};
  const kept = {};
  IDS.forEach((id) => {
    const t = A.practiceTally(n, id);
    tally[id] = { shown: t.shown, value: t.shown ? t.value : null,
      text: t.text };
    kept[id] = A.keptToday(n, id, day);
  });
  return { actions: { practices: n.practices, prayerCount: n.prayerCount,
    fastDays: n.fastDays, meditationHours: n.meditationHours,
    lastFastDay: n.lastFastDay, met: n.met, gifts: n.gifts },
  tally, kept };
}

const chains = [];

// 1. Every practice, every kind of input: good and bad days, repeats on
// the same day, the next day, short and whole timer sessions, unknown
// ids.  Each step: {op, id, opts, day, want}.
{
  const steps = [];
  let a = A.normalize({});
  const days = ['2026-09-30', '2026-09-30', '2026-10-01', 'bad-day', null,
    '2026-10-01', '2026-10-02'];
  const minutes = [0, 0.9, 1, 4.99, 5, 9, 10, 12, -3, 'x'];
  let k = 0;
  days.forEach((day) => {
    IDS.concat(['nope', 'communion']).forEach((id) => {
      const opts = { day, minutes: minutes[k % minutes.length] };
      k += 1;
      a = A.doPractice(a, id, opts);
      steps.push({ op: 'practice', id, opts, day, want: snapshot(a, day) });
    });
  });
  chains.push({ name: 'every practice', start: {}, steps });
}

// 2. Stored records, honest and tampered: normalize must keep only the
// known shapes (the hub reads its save file through it).
const stored = [
  {},
  null,
  'text',
  { prayerCount: 12.7, fastDays: -2, meditationHours: 0.25,
    lastFastDay: '2026-09-30', met: { theodora: 2, 'Bad Key': 3,
      abba_john: 'x' }, gifts: { mystical: true, contemplative: 'yes',
      unknown_gate: true } },
  { practices: { guard_thoughts: { count: 3.9, lastDay: '2026-09-29' },
    prayer_rope: { count: 99, lastDay: '2026-09-29' },
    fast: { count: 4 }, invented: { count: 50 },
    vigil: { count: -1, lastDay: 'yesterday' }, alms: 7 } },
  { prayerCount: Infinity, meditationHours: NaN, practices: [] },
];
stored.forEach((raw, i) => {
  chains.push({ name: `stored ${i}`, start: raw === undefined ? null : raw,
    steps: [{ op: 'none', day: '2026-09-29',
      want: snapshot(raw, '2026-09-29') }] });
});

// 3. The evening watch lifts a fall exactly as the web does: a fall at
// a threshold, the watch kept (twice the same day counts once), then
// the talk with the passion's teacher; and the other order.
function openAll() {
  let a = A.normalize({});
  for (let i = 0; i < 33; i++) {
    a = A.prayKnot(a);
  }
  ['theodora', 'elder_sergius', 'abba_john', 'sister_catherine']
    .forEach((m) => { a = A.recordMeeting(a, m); });
  a.fastDays = 1;
  a = A.addStillness(a, 60);
  const f = { wisdom: 14, faith: 1, dexterity: 1, constitution: 1,
    charisma: 1, cunning: 1, erudition: 1 };
  ['contemplative', 'mystical', 'apophatic'].forEach((g) => {
    a = A.acceptGift(a, f, g);
  });
  return { a, f };
}
const falls = [];
ctx.trials.trials.forEach((trial) => {
  trial.options.filter((o) => o.outcome === 'fall').forEach((o) => {
    falls.push({ gate: trial.gateId, option: o.id });
  });
});
falls.forEach((fall, i) => {
  const { a: a0, f } = openAll();
  let st = M.emptyState();
  st = M.chooseTrial(ctx, st, fall.gate, fall.option, f, a0).state;
  const teacher = st.fall.teacher;
  const steps = [];
  let a = a0;
  const status = () => {
    const s = M.fallStatus(ctx, st, a);
    return { fallen: s.fallen, sober: Boolean(s.sober),
      taught: Boolean(s.taught), canLift: Boolean(s.canLift) };
  };
  const push = (op, extra) => {
    steps.push({ op, ...extra, day: '2026-09-30',
      want: { ...snapshot(a, '2026-09-30'), status: status(),
        fall: st.fall ? clone(st.fall) : null } });
  };
  push('fall', { gate: fall.gate, option: fall.option });
  const order = i % 2 === 0 ? ['watch', 'watch', 'meet', 'lift']
    : ['meet', 'lift', 'watch', 'lift'];
  order.forEach((op) => {
    if (op === 'watch') {
      a = A.doPractice(a, 'guard_thoughts', { day: '2026-09-30' });
      push('practice', { id: 'guard_thoughts',
        opts: { day: '2026-09-30' } });
    } else if (op === 'meet') {
      a = A.recordMeeting(a, teacher);
      push('meet', { id: teacher });
    } else {
      st = M.liftFall(ctx, st, a);
      push('lift', {});
    }
  });
  chains.push({ name: `fall ${fall.gate}/${fall.option}`, start: clone(a0),
    fallGate: fall.gate, fallOption: fall.option, steps });
});

const out = path.join(root, 'godot/tests/fixtures/rule.json');
fs.writeFileSync(out, `${JSON.stringify({ chains }, null, 1)}\n`);
const n = chains.reduce((s, c) => s + c.steps.length, 0);
console.log(`wrote ${path.relative(root, out)}: ${chains.length} chains, `
  + `${n} steps`);
