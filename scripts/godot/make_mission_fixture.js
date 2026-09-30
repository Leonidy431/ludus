'use strict';
// Write godot/tests/fixtures/missions.json from public/ludus/ludus-missions.js:
// the campaign of missions (buildMission, nextMission, catalog, canStart,
// start, view, choose, advance, fallStatus, liftFall), the reference for
// MissionCore (godot/scripts/mission_core.gd).
//
// 99 missions with four steps each and the full state after every step
// would be megabytes, so the campaign is recorded as walks: a chain of
// operations with the expected output of each.  The GDScript side keeps
// its own state, FORM and rule along the chain and compares every step,
// so the passage between missions, acts and gate locks is checked too.
// Usage: node scripts/godot/make_mission_fixture.js

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
// The date is passed in, as the game passes the player's local day, so
// the fixture does not depend on the clock.
const DAY = '2026-09-30';
// As in ludus-game.js: FORM never grows past 20.
const ATTR_MAX = 20;
const clone = (o) => JSON.parse(JSON.stringify(o));
const form = (v) => ({ wisdom: v, faith: v, dexterity: v, constitution: v,
  charisma: v, cunning: v, erudition: v });

// What ludus-game.js does with the effects of a choice (applyEffects in
// ludus-missions.js, then recordMeeting, doPractice and applyBonuses).
function applyEffects(f, a, e) {
  let actions = a;
  const next = { ...f };
  if (e.meet) {
    actions = A.recordMeeting(actions, e.meet);
  }
  if (e.practice) {
    actions = A.doPractice(actions, e.practice, { day: DAY });
  }
  Object.keys(e.bonuses).forEach((k) => {
    next[k] = Math.min(ATTR_MAX, (next[k] || 0) + e.bonuses[k]);
  });
  return { form: next, actions };
}

const digest = (st) => ({
  done: Object.keys(st.done).map(Number).sort((x, y) => x - y),
  current: st.current ? { id: st.current.id, step: st.current.step,
    scene: st.current.scene } : null,
  flags: Object.keys(st.flags).sort(),
  lines: st.lines,
  trials: Object.keys(st.trials).sort(),
  fall: st.fall ? { passion: st.fall.passion, teacher: st.fall.teacher,
    since: st.fall.since } : null,
});

// The light digest after every choice and step: counts and the fall.
// The full digest is written at every start and lift; the views that
// follow read the lines and flags, so a drift shows there at once.
const light = (st) => ({
  done: Object.keys(st.done).length,
  current: st.current ? [st.current.id, st.current.step] : null,
  flags: Object.keys(st.flags).length,
  lines: Object.keys(st.lines).length,
  fall: st.fall ? { passion: st.fall.passion, teacher: st.fall.teacher,
    since: st.fall.since } : null,
});

const choiceDigest = (c) => [c.id, c.text, Boolean(c.disabled),
  c.reason || '', c.cue || '', Boolean(c.deep), Boolean(c.lure)];

const viewDigest = (v) => (v ? {
  id: v.mission.id,
  index: v.index,
  total: v.total,
  kindRu: v.kindRu,
  last: v.last,
  scene: v.scene,
  step: { kind: v.step.kind, title: v.step.title, text: v.step.text,
    speaker: v.step.speaker || '', node: v.step.node || '',
    voice: v.step.voice || '', meaning: v.step.meaning,
    source: v.step.source, choices: v.step.choices.map(choiceDigest) },
} : null);

const catDigest = (cat) => cat.map((act) => ({ id: act.id,
  lock: act.lock, complete: act.complete,
  status: act.missions.map((m) => m.status[0]).join('') }));

const sum = (o, f) => Object.keys(o).reduce((n, k) => n + f(o[k]), 0);
const rule = (a) => ({ met: sum(a.met, (x) => x), fastDays: a.fastDays,
  practices: sum(a.practices, (x) => x.count) });

const statusDigest = (s) => ({ fallen: s.fallen, passion: s.passion || null,
  teacher: s.teacher || null, sober: Boolean(s.sober),
  taught: Boolean(s.taught), canLift: Boolean(s.canLift) });

// Every mission's shape, chorus ones included.
const build = ctx.spine.order.map((id) => {
  const m = M.buildMission(ctx, id);
  return { id, out: { title: m.title, actIndex: m.actIndex, actId: m.actId,
    actTitle: m.actTitle, chorus: m.chorus, intro: m.intro,
    meaning: m.meaning, source: m.source, passion: m.passion,
    depthNeed: m.depthNeed, ceiling: m.ceiling, steps: m.steps } };
});

// Storage is not trusted: junk is dropped, known shapes are kept.
const normalize = [
  null,
  { done: { 1: true, 2: 'yes', x: true, 1234: true }, flags: { 'm1.kept':
    true, 'BAD FLAG': true, 'm2.kept': 1 }, lines: { sargis: 'open_hand',
    Bad: 'x', vardan: 'v marks' }, trials: { foundational: true,
    ascetic: 'yes', nowhere: true }, trialWait: { liturgical: 2.7,
    mystical: 'x' }, current: { id: 3, step: -2, scene: { text: 'a',
    choice: 5 } }, fall: { passion: 'avarice', teacher: 'Bad',
    since: { sobriety: 2.9, met: -1 } } },
  { current: { id: 'abc', step: 1 }, fall: { passion: 'lust' } },
  { current: { id: '12', step: 2.6, scene: null }, fall: { passion:
    'pride', teacher: 'abba_john' } },
].map((raw) => ({ raw, out: digest(M.normalizeState(raw)) }));

// Chorus missions never run; a mission ahead cannot be started.
const starts = [];
[14, 18, 19, 20, 32, 52, 89, 1, 2, 3, 99].forEach((id) => {
  const st = M.emptyState();
  starts.push({ id, out: { can: M.canStart(ctx, st, id),
    state: digest(M.start(ctx, st, id)) } });
});

function walk(name, form0, actions0, lureEvery) {
  let st = M.emptyState();
  let f = clone(form0);
  let a = clone(actions0);
  const steps = [];
  const choose = (id) => {
    const res = M.choose(ctx, st, id, f, a);
    const applied = applyEffects(f, a, res.effects);
    f = applied.form;
    a = applied.actions;
    st = res.state;
    steps.push({ do: 'choose', choice: id, out: { effects: res.effects,
      scene: st.current ? st.current.scene : null, state: light(st),
      form: f, rule: rule(a) } });
  };
  const advance = () => {
    const res = M.advance(ctx, st);
    st = res.state;
    steps.push({ do: 'advance', out: { completed: res.completed,
      state: light(st) } });
  };
  const status = () => steps.push({ do: 'status',
    out: statusDigest(M.fallStatus(ctx, st, a)) });
  const lift = () => {
    st = M.liftFall(ctx, st, a);
    steps.push({ do: 'lift', out: digest(st) });
  };
  for (let guard = 0; guard < 400; guard += 1) {
    const cat = M.catalog(ctx, st);
    steps.push({ do: 'catalog', out: catDigest(cat) });
    const next = M.nextMission(ctx.spine, st);
    steps.push({ do: 'next', out: next });
    if (next === null) {
      // The next act waits for the threshold of its gate; the choices
      // at the thresholds are checked by the trial fixture, so here the
      // gate is simply crossed.
      const i = cat.findIndex((act) => act.lock && !act.complete);
      const gate = M.GATE_FOR_ACT[i];
      if (i < 0 || !gate || st.trials[gate]) {
        break;
      }
      st.trials[gate] = true;
      steps.push({ do: 'pass', gate });
      continue;
    }
    steps.push({ do: 'canStart', id: next,
      out: M.canStart(ctx, st, next) });
    st = M.start(ctx, st, next);
    steps.push({ do: 'start', id: next,
      out: next % 10 === 1 ? digest(st) : light(st) });
    if (next % 5 === 0) {
      // Walking on without a scene changes nothing.
      advance();
    }
    for (let s = 0; s < 4; s += 1) {
      const v = M.view(ctx, st, f, a);
      steps.push({ do: 'view', out: viewDigest(v) });
      const ch = v.step.choices;
      const shut = ch.find((c) => c.disabled);
      if (shut && (next + s) % 3 === 0) {
        choose(shut.id);
      }
      const lureNow = !st.fall && next % lureEvery === 4
        && ((next % 2 === 0 && s === 0) || (next % 2 === 1 && s === 3));
      let pick;
      if (lureNow) {
        pick = ch.find((c) => c.lure).id;
      } else {
        const open = ch.filter((c) => !c.disabled && !c.lure);
        pick = open[(next * 7 + s * 3) % open.length].id;
      }
      choose(pick);
      if (next % 7 === 0 && s === 1) {
        // A second choice on the same scene changes nothing.
        choose(pick);
      }
      advance();
    }
    if (st.fall) {
      const teacher = st.fall.teacher;
      steps.push({ do: 'canStart', id: M.nextMission(ctx.spine, st),
        out: M.canStart(ctx, st, M.nextMission(ctx.spine, st)) });
      status();
      a = A.addStillness(a, 1);
      steps.push({ do: 'still', minutes: 1 });
      status();
      lift();
      a = A.recordMeeting(a, teacher);
      steps.push({ do: 'meet', npc: teacher });
      status();
      lift();
      status();
    }
  }
  return { name, form: form0, actions: actions0, steps };
}

const guest = walk('guest', form(1), A.normalize({}), 9);
// A mature FORM that has sat with the teachers: the deep answers open
// and the signs of the passions are shown under their lures.
let mature = A.normalize({});
['elder_sergius', 'theodora', 'abba_john', 'sister_catherine', 'abba_moses',
  'macrina', 'kassiani'].forEach((n) => { mature = A.recordMeeting(mature, n); });
const deep = walk('mature', form(9), mature, 6);

const out = { note: 'Generated by scripts/godot/make_mission_fixture.js;'
  + ' do not edit.', build, normalize, starts, walks: [guest, deep] };
// One record per line keeps a diff readable.
const lines = (arr) => arr.map((x) => JSON.stringify(x)).join(',\n');
const text = '{"note":' + JSON.stringify(out.note) + ',\n'
  + '"build":[\n' + lines(build) + '],\n'
  + '"normalize":[\n' + lines(normalize) + '],\n'
  + '"starts":[\n' + lines(starts) + '],\n'
  + '"walks":[\n' + out.walks.map((w) => '{"name":' + JSON.stringify(w.name)
    + ',"form":' + JSON.stringify(w.form) + ',"actions":'
    + JSON.stringify(w.actions) + ',"steps":[\n' + lines(w.steps) + ']}')
    .join(',\n') + ']}\n';
const file = path.join(root, 'godot/tests/fixtures/missions.json');
fs.mkdirSync(path.dirname(file), { recursive: true });
fs.writeFileSync(file, text);
const n = out.walks.reduce((s, w) => s + w.steps.length, 0);
console.log(`mission fixture: ${build.length} missions, ${normalize.length}`
  + ` normalize, ${starts.length} starts, ${n} walk steps`
  + ` (${out.walks.map((w) => w.steps.filter((s) => s.do === 'advance'
    && s.out.completed).length).join(' + ')} missions completed)`);
