// Playable missions and gate thresholds (ludus-missions.js,
// data/gate-trials.json).  Run: node --test tests/*.test.js
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const M = require('../public/ludus/ludus-missions.js');
const A = require('../public/ludus/ludus-actions.js');

const ROOT = path.join(__dirname, '..');
const data = (name) => require(path.join(ROOT, 'public/ludus/data', name));
const ctx = {
  spine: data('campaign-spine.json'),
  trials: data('gate-trials.json'),
  trees: data('dialogue-trees.json'),
  lake: data('lake-objects-99.json'),
  passions: data('passions.json'),
  actionsApi: A,
};
const GUEST = { wisdom: 1, faith: 1, dexterity: 1, constitution: 1,
  charisma: 1, cunning: 1, erudition: 1 };
const DAY = '2026-09-30';

// Play one choice the way the browser controller does: the missions
// module decides, the game applies bonuses, meetings and practices.
function play(run, choiceId) {
  const res = M.choose(ctx, run.state, choiceId, run.form, run.actions);
  const e = res.effects;
  Object.keys(e.bonuses).forEach((k) => {
    run.form[k] = Math.min(20, run.form[k] + e.bonuses[k]);
  });
  if (e.meet) {
    run.actions = A.recordMeeting(run.actions, e.meet);
  }
  if (e.practice) {
    run.actions = A.doPractice(run.actions, e.practice, { day: DAY });
  }
  run.state = res.state;
  return res;
}

function fresh() {
  return { state: M.emptyState(), form: { ...GUEST },
    actions: A.normalize(null) };
}

// A plain policy: hand the find over, keep the deed, take the first
// open branch of the talk, go down by the rope.
function policy(view) {
  const open = view.step.choices.filter((c) => !c.disabled);
  const has = (id) => open.some((c) => c.id === id);
  const want = { find: 'handover', practice: 'keep',
    dive: has('record') ? 'record' : 'rope' };
  return want[view.step.kind] || open[0].id;
}

function walkMission(run, id, pick) {
  run.state = M.start(ctx, run.state, id);
  assert.equal(run.state.current.id, id, `mission ${id} starts`);
  let completed = null;
  let guard = 0;
  while (!completed && guard < 20) {
    guard += 1;
    const v = M.view(ctx, run.state, run.form, run.actions);
    play(run, (pick || policy)(v));
    completed = M.advance(ctx, run.state).completed;
    run.state = M.advance(ctx, run.state).state;
  }
  return completed;
}

test('the spine is read whole: 7 acts, 99 missions, 7 on rewrite', () => {
  const cat = M.catalog(ctx, M.emptyState());
  assert.equal(cat.length, 7);
  const all = cat.flatMap((a) => a.missions);
  assert.equal(all.length, 99);
  const chorus = all.filter((m) => m.status === 'chorus').map((m) => m.id);
  assert.deepEqual(chorus.sort((a, b) => a - b), [14, 18, 19, 20, 32, 52,
    89]);
  assert.equal(all.filter((m) => m.status === 'next').length, 1);
  assert.equal(M.nextMission(ctx.spine, M.emptyState()), 1);
});

test('a mission on rewrite with the chorus never runs', () => {
  const st = M.emptyState();
  ctx.spine.needsChorusRewrite.forEach(({ id }) => {
    const can = M.canStart(ctx, st, id);
    assert.equal(can.ok, false);
    assert.equal(can.reason, 'на переписке у хора');
    assert.equal(M.start(ctx, st, id).current, null);
  });
});

test('every mission has four steps built from real data', () => {
  ctx.spine.order.forEach((id) => {
    const m = M.buildMission(ctx, id);
    assert.deepEqual(m.steps.map((s) => s.kind), M.STEP_ORDER);
    assert.deepEqual(M.buildMission(ctx, id), m, 'deterministic');
    m.steps.forEach((s) => {
      if (s.kind === 'find' || s.kind === 'dive') {
        assert.ok(ctx.lake.objects.some((o) => o.id === s.object),
          `${id}: lake object ${s.object}`);
      }
      if (s.kind === 'dialogue') {
        const tree = ctx.trees.trees[s.npc];
        assert.ok(tree, `${id}: tree ${s.npc}`);
        [s.node, s.warm].forEach((node) => {
          const n = tree.nodes.find((x) => x.id === node);
          assert.ok(n, `${s.npc}.${node}`);
          assert.ok(n.branches.some((b) => !b.condition),
            `${s.npc}.${node} has a branch open to a beginner`);
        });
      }
      if (s.kind === 'practice') {
        // Deeds only: prayer never becomes a key (TABOO 0.35 rule 16).
        assert.ok(['alms', 'forgive', 'obedience', 'fast',
          'secret_deed'].includes(s.practice), s.practice);
      }
    });
  });
});

test('two different choices lead to two different scenes', () => {
  const a = fresh();
  const b = fresh();
  [a, b].forEach((run) => { run.state = M.start(ctx, run.state, 1); });
  play(a, 'handover');
  play(b, 'note');
  const sceneA = a.state.current.scene.text;
  assert.notEqual(sceneA, b.state.current.scene.text);
  // Walk both to the talk: the honest find changes how Sargis meets
  // the player, so the next scene itself differs.
  [a, b].forEach((run) => {
    run.state = M.advance(ctx, run.state).state;
    play(run, 'keep');
    run.state = M.advance(ctx, run.state).state;
  });
  const va = M.view(ctx, a.state, a.form, a.actions);
  const vb = M.view(ctx, b.state, b.form, b.actions);
  assert.equal(va.step.kind, 'dialogue');
  assert.equal(va.step.node, 'open_hand');
  assert.equal(vb.step.node, 'scales_greeting');
  assert.notEqual(va.step.text, vb.step.text);
  // The same choices always give the same scene.
  const c = fresh();
  c.state = M.start(ctx, c.state, 1);
  play(c, 'handover');
  assert.equal(c.state.current.scene.text, sceneA);
});

test('bonuses are +1..+5, only to the seven attributes', () => {
  const rich = { wisdom: 20, faith: 20, dexterity: 20, constitution: 20,
    charisma: 20, cunning: 20, erudition: 20 };
  ctx.spine.order.forEach((id) => {
    if (M.canStart(ctx, M.emptyState(), id).reason === 'на переписке у хора') {
      return;
    }
    const m = M.buildMission(ctx, id);
    m.steps.forEach((s, i) => {
      const st = { ...M.emptyState(), current: { id, step: i, scene: null },
        flags: { [`m${id}.kept`]: true } };
      const v = M.view(ctx, st, rich, A.normalize(null));
      v.step.choices.filter((c) => !c.lure).forEach((c) => {
        const res = M.choose(ctx, st, c.id, rich, A.normalize(null));
        Object.entries(res.effects.bonuses).forEach(([k, n]) => {
          assert.ok(M.ATTRS.includes(k), k);
          assert.ok(Number.isInteger(n) && n >= 1 && n <= 5, `${k}=${n}`);
        });
        assert.ok(res.state.current.scene.text.length > 0);
      });
    });
  });
});

test('a practice of prayer never pays: the deed opens, the secret hides',
  () => {
    const src = fs.readFileSync(path.join(ROOT,
      'public/ludus/ludus-missions.js'), 'utf8');
    assert.equal(/Math\.random/.test(src), false, 'no Math.random');
    Object.keys(M.PRACTICE_RU).forEach((id) => {
      assert.ok(!['prayer_rope', 'stillness', 'prostrations', 'vigil',
        'thanksgiving', 'guard_thoughts'].includes(id));
    });
    // Mission 2 keeps the secret deed: nothing visible opens.
    const run = fresh();
    run.state = { ...M.emptyState(), done: { 1: true, 3: true } };
    run.state = M.start(ctx, run.state, 4);
    const m = M.buildMission(ctx, 4);
    assert.equal(m.steps[1].practice, 'secret_deed');
    play(run, 'note');
    run.state = M.advance(ctx, run.state).state;
    const res = play(run, 'keep');
    assert.equal(res.effects.opens, null);
    assert.deepEqual(res.effects.bonuses, {});
  });

test('the fall: dim light, two paths closed, lifted by sobriety and a '
  + 'talk, and nothing is counted', () => {
  const run = fresh();
  run.state = M.start(ctx, run.state, 1);
  const res = play(run, 'lure');
  assert.equal(res.effects.fall, 'gluttony');
  assert.deepEqual(res.effects.bonuses, {}, 'no attribute is taken');
  let fsn = M.fallStatus(ctx, run.state, run.actions);
  assert.equal(fsn.fallen, true);
  assert.equal(fsn.closed.length, 2);
  assert.equal(fsn.teacher, 'abba_john');
  // Deep answers are closed; the mission itself goes on.
  run.state = M.advance(ctx, run.state).state;
  play(run, 'keep');
  run.state = M.advance(ctx, run.state).state;
  play(run, 'b0');
  run.state = M.advance(ctx, run.state).state;
  const dive = M.view(ctx, run.state, { ...run.form, wisdom: 20 },
    run.actions);
  const record = dive.step.choices.find((c) => c.id === 'record');
  assert.equal(record.disabled, true);
  play(run, 'rope');
  run.state = M.advance(ctx, run.state).state;
  assert.equal(run.state.done[1], true);
  // The road to the next mission is closed.
  assert.equal(M.canStart(ctx, run.state, 3).ok, false);
  // A talk alone does not lift it, nor the watch alone.
  run.actions = A.recordMeeting(run.actions, 'abba_john');
  assert.equal(M.fallStatus(ctx, run.state, run.actions).canLift, false);
  assert.equal(M.liftFall(ctx, run.state, run.actions).fall.passion,
    'gluttony');
  run.actions = A.doPractice(run.actions, 'guard_thoughts', { day: DAY });
  fsn = M.fallStatus(ctx, run.state, run.actions);
  assert.equal(fsn.canLift, true);
  run.state = M.liftFall(ctx, run.state, run.actions);
  assert.equal(run.state.fall, null);
  assert.equal(M.canStart(ctx, run.state, 3).ok, true);
  // No sin counter anywhere in the saved state.
  const saved = JSON.stringify(run.state);
  assert.equal(/gluttony|fall|sin|count/i.test(saved.replace(
    /"fall":null/, '')), false, saved);
});

test('act 1 can be played from start to end; act 2 waits for the '
  + 'first threshold', () => {
  const run = fresh();
  const acts = ctx.spine.acts;
  [0, 1].forEach((i) => {
    acts[i].missions.forEach((id) => {
      if (M.canStart(ctx, run.state, id).reason === 'на переписке у хора') {
        return;
      }
      assert.equal(walkMission(run, id), id);
    });
  });
  const cat = M.catalog(ctx, run.state);
  assert.equal(cat[0].complete, true);
  assert.equal(cat[1].complete, true);
  assert.match(cat[2].lock, /порог/);
  assert.equal(M.nextMission(ctx.spine, run.state), null);
  // FORM grows by understanding, not by the number of missions: after
  // act 1 Wisdom has passed the first gate and not the last.
  assert.ok(run.form.wisdom >= 4 && run.form.wisdom < 14,
    `wisdom ${run.form.wisdom}`);
  // The threshold is offered only when the gate's three conditions hold.
  let tv = M.trialView(ctx, run.state, 'foundational', run.form,
    run.actions);
  assert.equal(tv.open, false);
  run.actions = A.recordMeeting(run.actions, 'theodora');
  for (let i = 0; i < 10; i += 1) {
    run.actions = A.prayKnot(run.actions);
  }
  tv = M.trialView(ctx, run.state, 'foundational', run.form, run.actions);
  assert.equal(tv.open, true);
  // "Return" sends the player to the mentor before a second try.
  let res = M.chooseTrial(ctx, run.state, 'foundational', 'sand', run.form,
    run.actions);
  assert.equal(res.outcome, 'return');
  run.state = res.state;
  tv = M.trialView(ctx, run.state, 'foundational', run.form, run.actions);
  assert.equal(tv.waiting, true);
  assert.ok(tv.options.every((o) => o.disabled));
  run.actions = A.recordMeeting(run.actions, 'theodora');
  res = M.chooseTrial(ctx, run.state, 'foundational', 'rock', run.form,
    run.actions);
  assert.equal(res.outcome, 'through');
  run.state = res.state;
  assert.equal(M.catalog(ctx, run.state)[2].lock, null);
  assert.equal(M.nextMission(ctx.spine, run.state), 16);
});

test('gate trials: one per gate, a choice by understanding, not a quiz',
  () => {
    const trials = ctx.trials.trials;
    assert.deepEqual(trials.map((t) => t.gateId), M.GATE_IDS);
    const text = JSON.stringify(ctx.trials);
    assert.equal(/correctIndex|"correct"|"answer"|"score"/.test(text), false);
    trials.forEach((t) => {
      assert.ok(t.meaning && t.source && t.scene_ru && t.mentor);
      assert.equal(t.options.filter((o) => o.outcome === 'through').length,
        1, t.gateId);
      assert.ok(t.options.some((o) => o.outcome === 'return'));
      t.options.forEach((o) => {
        assert.ok(['through', 'return', 'fall'].includes(o.outcome));
        assert.ok(o.meaning && o.source && o.reply_ru && o.text_ru);
        assert.ok(['own', 'paraphrase'].includes(o.voice), o.id);
        if (o.outcome === 'fall') {
          assert.ok(ctx.passions.passions.some((p) => p.id === o.passion));
        }
      });
    });
    assert.equal(M.resolveGate({ gateId: 'ascetic' }), 'ascetic');
    assert.equal(M.resolveGate({ gateId: 'fs-doc-1', tier: '2' }),
      'liturgical');
    assert.equal(M.resolveGate({ gateId: 'x' }), null);
  });

test('no church word stands on a button or a label', () => {
  assert.ok(M.STOP_WORDS.test('Святой путь'));
  assert.ok(M.STOP_WORDS.test('путь к спасению'));
  assert.equal(M.STOP_WORDS.test('Святитель'), false);
  const strings = [];
  Object.values(M.LURES).forEach((l) => strings.push(l.find, l.dive));
  Object.values(M.PRACTICE_RU).forEach((p) => strings.push(p.label,
    p.after));
  M.SOBRIETY.forEach((s) => strings.push(s.label));
  ctx.trials.trials.forEach((t) => {
    strings.push(t.title_ru);
    t.options.forEach((o) => strings.push(o.text_ru));
  });
  ctx.spine.missions.forEach((m) => strings.push(m.title));
  ctx.spine.order.forEach((id) => {
    const m = M.buildMission(ctx, id);
    strings.push(m.intro);
    m.steps.forEach((s, i) => {
      if (s.kind === 'dialogue') {
        return;
      }
      const st = { ...M.emptyState(), current: { id, step: i, scene: null } };
      M.view(ctx, st, GUEST, A.normalize(null)).step.choices
        .forEach((c) => strings.push(c.text));
    });
  });
  strings.forEach((s) => assert.equal(M.STOP_WORDS.test(s), false, s));
});

test('every source the missions and thresholds cite is in the canon', (t) => {
  const sources = [];
  ctx.trials.trials.forEach((tr) => {
    sources.push([tr.gateId, tr.source, null]);
    tr.options.forEach((o) => sources.push([`${tr.gateId}/${o.id}`,
      o.source, o.passion || null]));
  });
  Object.entries(M.ACT_PLAN).forEach(([id, p]) => {
    sources.push([`act/${id}`, p.source, null]);
  });
  const m = M.buildMission(ctx, 31);
  m.steps.forEach((s, i) => {
    if (s.kind === 'dialogue') {
      return;
    }
    const st = { ...M.emptyState(), current: { id: 31, step: i,
      scene: null } };
    sources.push([`step/${s.kind}`, M.view(ctx, st, GUEST,
      A.normalize(null)).step.source, null]);
  });
  const script = [
    'import json, sys',
    "sys.path.insert(0, 'scripts')",
    'import check_canon as c',
    "canon = c.Canon(json.load(open('data/patristic-canon.json')))",
    'bad = []',
    'for where, src, passion in json.load(sys.stdin):',
    '    errors, _ = canon.check(src)',
    '    if passion:',
    "        errors += canon.check(f'{src} ({passion})')[0]",
    "    bad += [f'{where}: {e}' for e in errors]",
    "print('\\n'.join(bad) or 'OK')",
  ].join('\n');
  const run = spawnSync('python3', ['-c', script], { cwd: ROOT,
    input: JSON.stringify(sources), encoding: 'utf8' });
  if (run.error && run.error.code === 'ENOENT') {
    t.skip('python3 is not installed; scripts/check_canon.py cannot run');
    return;
  }
  assert.equal(run.status, 0, run.stderr);
  assert.equal(run.stdout.trim(), 'OK', run.stdout);
});
