'use strict';
// Write godot/tests/trial_fixture.json from public/ludus/ludus-missions.js:
// the thresholds of the gates (trialView, chooseTrial) and the fall they
// can lead to (fallStatus, liftFall), the reference for TrialCore.
// Each record keeps its inputs (state, gate, option, form, actions), so
// the GDScript side replays the very same calls.
// Usage: node scripts/godot/make_trial_fixture.js

const fs = require('fs');
const path = require('path');
const M = require('../../public/ludus/ludus-missions.js');
const A = require('../../public/ludus/ludus-actions.js');

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
const form = (w) => ({ wisdom: w, faith: 1, dexterity: 1, constitution: 1,
  charisma: 1, cunning: 1, erudition: 1 });
const clone = (o) => JSON.parse(JSON.stringify(o));

// Actions that open every gate up to the apophatic one.
function openAll() {
  let a = A.normalize({});
  for (let i = 0; i < 33; i++) {
    a = A.prayKnot(a);
  }
  ['theodora', 'elder_sergius', 'abba_john', 'sister_catherine']
    .forEach((m) => { a = A.recordMeeting(a, m); });
  a.fastDays = 1;
  a = A.addStillness(a, 60);
  ['contemplative', 'mystical', 'apophatic'].forEach((g) => {
    a = A.acceptGift(a, form(14), g);
  });
  return a;
}

const view = (tv) => (tv ? { open: tv.open, passed: tv.passed,
  waiting: tv.waiting, locked: tv.locked, reason: tv.reason,
  disabled: tv.options.map((o) => o.disabled) } : null);
const status = (fs_) => ({ fallen: fs_.fallen, passion: fs_.passion || null,
  teacher: fs_.teacher || null, sober: Boolean(fs_.sober),
  taught: Boolean(fs_.taught), canLift: Boolean(fs_.canLift) });

const records = [];
function record(op, st, gateId, optionId, f, a) {
  const input = { op, state: clone(st), gateId, optionId, form: clone(f),
    actions: clone(a) };
  let out;
  if (op === 'view') {
    out = { view: view(M.trialView(ctx, st, gateId, f, a)) };
  } else if (op === 'choose') {
    const res = M.chooseTrial(ctx, st, gateId, optionId, f, a);
    out = { outcome: res.outcome, reply: res.reply,
      state: { trials: res.state.trials, trialWait: res.state.trialWait,
        fall: res.state.fall } };
    st = res.state;
  } else if (op === 'status') {
    out = { status: status(M.fallStatus(ctx, st, a)) };
  } else {
    st = M.liftFall(ctx, st, a);
    out = { state: { trials: st.trials, trialWait: st.trialWait,
      fall: st.fall } };
  }
  records.push({ ...input, out });
  return st;
}

// A closed gate: nothing can be chosen.
let st = M.emptyState();
record('view', st, 'foundational', null, form(1), A.normalize({}));
record('choose', st, 'foundational', 'rock', form(1), A.normalize({}));

// A state whose thresholds below this gate are passed: the ladder asks
// for the threshold of gate N before gate N+1 opens.
function passedBelow(gateId) {
  const s = M.emptyState();
  M.GATE_IDS.slice(0, M.GATE_IDS.indexOf(gateId))
    .forEach((g) => { s.trials[g] = true; });
  return s;
}

// Every gate, every option, from a state with all gates open.
const all = openAll();
ctx.trials.trials.forEach((t) => {
  t.options.forEach((o) => {
    let s = passedBelow(t.gateId);
    let a = clone(all);
    s = record('view', s, t.gateId, null, form(14), a);
    s = record('choose', s, t.gateId, o.id, form(14), a);
    s = record('view', s, t.gateId, null, form(14), a);
    if (o.outcome === 'return') {
      // Waiting ends with a new talk with the mentor.
      a = A.recordMeeting(a, t.mentor);
      s = record('view', s, t.gateId, null, form(14), a);
    }
    if (o.outcome === 'fall') {
      s = record('status', s, null, null, form(14), a);
      s = record('lift', s, null, null, form(14), a);
      a = A.addStillness(a, 1);
      s = record('status', s, null, null, form(14), a);
      s = record('lift', s, null, null, form(14), a);
      const p = ctx.passions.passions.find((x) => x.id === o.passion);
      a = A.recordMeeting(a, p ? p.teacher : 'elder_sergius');
      s = record('status', s, null, null, form(14), a);
      s = record('lift', s, null, null, form(14), a);
      s = record('status', s, null, null, form(14), a);
    }
  });
});

// The ladder waits for the threshold below: with every gate open by the
// three-part check, the liturgical threshold is closed until the
// foundational one is passed; a "return" there keeps it closed.
{
  const first = ctx.trials.trials.find((t) => t.gateId === 'foundational');
  const opt = (k) => first.options.find((o) => o.outcome === k).id;
  let s = M.emptyState();
  const a = clone(all);
  s = record('view', s, 'liturgical', null, form(14), a);
  s = record('choose', s, 'foundational', opt('return'), form(14), a);
  s = record('view', s, 'liturgical', null, form(14), a);
  s = record('choose', s, 'liturgical', null, form(14), a);
  const b = A.recordMeeting(clone(a), first.mentor);
  s = record('choose', s, 'foundational', opt('through'), form(14), b);
  s = record('view', s, 'liturgical', null, form(14), b);
}

// A second fall never overwrites the first: while a fall lasts every
// threshold is locked, so the other gate's fall option changes nothing.
{
  const t1 = ctx.trials.trials.find((t) => t.gateId === 'foundational');
  const t2 = ctx.trials.trials.find((t) => t.gateId === 'liturgical');
  const fall = (t) => t.options.find((o) => o.outcome === 'fall').id;
  const thr = (t) => t.options.find((o) => o.outcome === 'through').id;
  let s = M.emptyState();
  const a = clone(all);
  s.trials.foundational = true;
  s = record('choose', s, 'liturgical', fall(t2), form(14), a);
  s = record('view', s, 'liturgical', null, form(14), a);
  s = record('view', s, 'ascetic', null, form(14), a);
  s = record('choose', s, 'liturgical', fall(t2), form(14), a);
  s = record('choose', s, 'liturgical', thr(t2), form(14), a);
  s = record('status', s, null, null, form(14), a);
  // The first trial was passed before the fall; nothing reopens it.
  s = record('view', s, t1.gateId, null, form(14), a);
}

fs.writeFileSync(path.join(root, 'godot/tests/trial_fixture.json'),
  JSON.stringify({ note: 'Generated by scripts/godot/make_trial_fixture.js;'
    + ' do not edit.', records }, null, 1) + '\n');
console.log(`trial fixture: ${records.length} records`);
