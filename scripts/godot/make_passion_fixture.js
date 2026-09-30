'use strict';
// Write godot/tests/passion_fixture.json from public/ludus/ludus-passion.js,
// the reference for the meeting of a passion on the road (PassionCore).
// Usage: node scripts/godot/make_passion_fixture.js
//
// Every stage and every option of every passion is walked for forms
// below, at and above the Wisdom that names the sign, and for a mentor
// met, unmet or met "zero times".  The factory's manifest is written
// into the fixture as well, because the headset has no port of the
// factory's data yet and the test hands it to PassionCore directly.

const fs = require('fs');
const path = require('path');
const P = require('../../public/ludus/ludus-passion.js');
const F = require('../../public/ludus/ludus-antagonist-factory.js');

const root = path.join(__dirname, '..', '..');
const data = require(path.join(root, 'public/ludus/data/passions.json'));
const fresh = () => JSON.parse(JSON.stringify(data));
// JSON has no undefined; the GDScript side reads a missing key as null.
const clean = (v) => (v === undefined ? null : JSON.parse(
  JSON.stringify(v)));

const OTHER = 'elder_sergius';
const actionsFor = (p) => [
  null,
  { met: {} },
  { met: { [p.teacher]: 1 } },
  { met: { [p.teacher === OTHER ? 'theodora' : OTHER]: 2 } },
  { met: { [p.teacher]: 0 } },
];
const formsFor = (p) => [
  { wisdom: p.wisdomToName - 1 },
  { wisdom: p.wisdomToName },
  { wisdom: p.wisdomToName + 3 },
];
// Odd forms, as a save file or an old client could hand them over.
const ODD_FORMS = [null, {}, { wisdom: '6' }, { wisdom: 'abc' },
  { wisdom: true }, { wisdom: null }];

const PROBES = ['look', 'turn', 'name', 'answer', 'stop', 'take',
  'remember', 'still', 'bogus'];

function walks(passion, form, actions) {
  const out = [];
  // Depth-first over the real options.  At every node each id that is
  // not offered is probed; the JS hands back the very same state, and
  // the ids for which it did are listed in `refused`.
  function go(state, ids) {
    const opts = P.options(state, passion, form, actions);
    const refused = PROBES.filter((id) => !opts.some((o) => o.id === id)
      && P.choose(state, id, passion, form, actions) === state);
    const node = { ids, state: clean(state), refused };
    out.push(node);
    if (!opts.length) {
      const prior = { [passion.id]: { meetings: 3, overcome: 1,
        captive: 1, discerned: true }, other: { meetings: 1 } };
      node.finish_empty = clean(P.finish({}, state));
      node.finish_prior = clean(P.finish(prior, state));
      return;
    }
    opts.forEach((o) => go(P.choose(state, o.id, passion, form, actions),
      ids.concat(o.id)));
  }
  go(P.start(passion), []);
  return out;
}

const cases = [];
function addCase(passion, form, actions) {
  const options = {};
  P.STAGES.concat(['nowhere']).forEach((stage) => {
    const s = { ...P.start(passion), stage };
    options[stage] = clean(P.options(s, passion, form, actions));
  });
  cases.push({ passion: passion.id, form: clean(form),
    actions: clean(actions), canName: P.canName(passion, form, actions),
    start: clean(P.start(passion)), options,
    walks: walks(passion, form, actions) });
}
data.passions.forEach((p) => {
  formsFor(p).forEach((f) => actionsFor(p).forEach((a) => addCase(p, f, a)));
});
const glut = data.passions.find((p) => p.id === 'gluttony');
ODD_FORMS.forEach((f) => addCase(glut, f, { met: {} }));
[{ met: { abba_john: 'yes' } }, { met: { abba_john: '' } },
  { met: { abba_john: true } }, { met: { abba_john: false } },
  { met: { abba_john: {} } }, { met: null }, {}]
  .forEach((a) => addCase(glut, { wisdom: 1 }, a));

// Records as a save could hold them, sane and broken.
const RECORDS = [
  null, 'text', [], {},
  { gluttony: { meetings: 2, overcome: 0, captive: 1, discerned: false } },
  { gluttony: { meetings: 2.7, overcome: -1, captive: '3',
    discerned: 'true' } },
  { Gluttony: { meetings: 1 }, glut_ony: { meetings: 1 },
    abcdefghijklmnopqrstu: { meetings: 1 }, abcdefghijklmnopqrst: {} },
  { gluttony: null, lust: 5, avarice: [], sadness: { meetings: null } },
  { gluttony: { meetings: 1, overcome: 1, discerned: true },
    lust: { meetings: 4, captive: 4 } },
  { gluttony: { overcome: 1 }, lust: { overcome: 2 }, avarice: {
    overcome: 1 }, sadness: { overcome: 1 }, anger: { overcome: 1 } },
  Object.fromEntries(data.order.map((id) => [id, { overcome: 1 }])),
  Object.fromEntries(data.order.slice(0, 7).map((id) => [id,
    { overcome: 1, meetings: 5 }])),
];
const normalize = RECORDS.map((r) => ({ raw: clean(r),
  out: P.normalizeRecord(r) }));

// The sprite of every passion over fourteen meetings, which crosses the
// seam between two rounds of the queue for the twelve-variant ones.
const sprites = [];
data.passions.forEach((p) => {
  for (let n = 0; n < 14; n += 1) {
    const rec = n ? { [p.id]: { meetings: n } } : {};
    sprites.push({ passion: p.id, record: rec,
      sprite: clean(P.spriteFor(p, rec)) });
  }
});
// A passion the factory has no art for, and one without `raw`.
const extra = [
  { id: 'nothing', raw: 'nothing' },
  { id: 'anger', teacher: 'x', wisdomToName: 1 },
];
extra.forEach((p) => sprites.push({ passion: null, entry: p,
  record: { anger: { meetings: 13 } },
  sprite: clean(P.spriteFor(p, { anger: { meetings: 13 } })) }));

const next = RECORDS.map((r) => {
  const d = fresh();
  const p = P.nextPassion(d, r);
  return { record: clean(r), passion: clean(p) };
});

fs.writeFileSync(path.join(root, 'godot/tests/passion_fixture.json'),
  JSON.stringify({ note: 'Generated by scripts/godot/make_passion_fixture'
    + '.js; do not edit.', stages: P.STAGES, manifest: F.MANIFEST, cases,
  normalize, sprites, next }) + '\n');
const nWalks = cases.reduce((s, c) => s + c.walks.length, 0);
console.log(`passion fixture: ${cases.length} cases, ${nWalks} walks, `
  + `${sprites.length} sprites, ${next.length} next`);
