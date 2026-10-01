'use strict';
// The Water Atlas and the own drawings in the web dive
// (public/ludus/dive/dive-atlas.js): the same placement as the headset
// (godot/scripts/atlas_traces.gd, dive.gd _build_own_drawings), the
// holy rules of the khachkar, and the knight's things to the scribe.

const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');

const Core = require('../public/ludus/dive/dive-core.js');
const A = require('../public/ludus/dive/dive-atlas.js');

const root = path.join(__dirname, '..');
const data = require('../public/ludus/data/atlas-99.json');
const find = (placed, id) => placed.find((p) => p.id === id);

test('placing is deterministic and needs no fixture', () => {
  for (const c of ['', 'spare', 'vault']) {
    assert.deepStrictEqual(A.place(data, c), A.place(data, c));
  }
  assert.deepStrictEqual(A.placeOwnDrawings(), A.placeOwnDrawings());
  // The seed is the headset's: the same string gives the same stream.
  const r1 = Core.rng('atlas:diary:spare');
  const r2 = Core.rng('atlas:diary:spare');
  for (let i = 0; i < 5; i++) {
    assert.strictEqual(r1(), r2());
  }
  const src = fs.readFileSync(path.join(root,
    'public/ludus/dive/dive-atlas.js'), 'utf8')
    + fs.readFileSync(path.join(root, 'public/ludus/dive/dive-view.js'),
      'utf8');
  assert.ok(!/Math\.random\(/.test(src), 'no Math.random');
});

test('the chronicle is written once and moves the traces', () => {
  assert.strictEqual(A.writeChronicle(data, null, 'spare'), 'spare');
  assert.strictEqual(A.writeChronicle(data, 'spare', 'vault'), 'spare');
  assert.strictEqual(A.writeChronicle(data, null, 'nonsense'), '');
  assert.strictEqual(A.writeChronicle(data, null, ''), '');
  const before = A.place(data, '');
  assert.strictEqual(before.length, data.traces.length, 'no passage yet');
  const spare = A.place(data, 'spare');
  const vault = A.place(data, 'vault');
  assert.strictEqual(spare.length, data.traces.length + 1);
  assert.strictEqual(spare[spare.length - 1].shape, 'spare');
  assert.strictEqual(vault[vault.length - 1].shape, 'vault');
  assert.ok(data.traces.some((t, i) => spare[i].x !== vault[i].x
    || spare[i].z !== vault[i].z), 'the choice moves the traces');
  spare.forEach((p) => {
    assert.ok(Math.abs(Core.floorDepth(p.x, p.z) - p.depth) < 0.01,
      `${p.id} lies on the floor`);
    const want = p.kind === 'passage' ? A.PASSAGE_DEPTH
      : data.traces.find((t) => t.id === p.id).depth;
    assert.ok(Math.abs(p.depth - want) < 3, `${p.id} near ${want} m`);
    assert.ok(Math.abs(p.z) <= Core.CORRIDOR_M * 0.5);
  });
});

test('same seed, same spot as the headset (godot/tests fixture)', () => {
  // test_atlas.gd compares AtlasTraces and dive.gd with this file; here
  // the web must still write exactly it (regenerate with
  // node scripts/godot/make_atlas_fixture.js).
  const fx = JSON.parse(fs.readFileSync(path.join(root,
    'godot/tests/fixtures/atlas-traces.json'), 'utf8'));
  for (const c of ['', 'spare', 'vault']) {
    const ours = A.place(data, c).map((p) => ({ id: p.id, kind: p.kind,
      shape: p.shape, x: p.x, z: p.z, depth: p.depth, yaw: p.yaw }));
    assert.deepStrictEqual(ours, fx.traces[c], `traces for '${c}'`);
  }
  const drawings = A.placeOwnDrawings().map((d) => ({ kit: d.kit,
    file: path.basename(d.file), x: d.x, z: d.z,
    centreDepth: d.centreDepth }));
  assert.deepStrictEqual(drawings, fx.drawings);
});

test('the khachkar: holy, not loot, the arm does not move', () => {
  const src = data.traces.find((t) => t.id === 'khachkar');
  assert.strictEqual(src.holy, true);
  assert.strictEqual(src.loot, null);
  const holy = A.place(data, 'spare').filter((p) => p.holy);
  assert.deepStrictEqual(holy.map((p) => p.id), ['khachkar']);
  const khachkar = find(A.place(data, 'spare'), 'khachkar');
  const bag = { atlas: [] };
  const r = A.take(bag, khachkar);
  assert.strictEqual(r.reach, false, 'the arm does not touch it');
  assert.strictEqual(r.text, A.UNKNOWN_RU, 'type unknown');
  assert.deepStrictEqual(r.bag, { atlas: [] }, 'nothing goes anywhere');
  assert.strictEqual(A.labelFor(khachkar, 0.5), '', 'no tag, even close');
  // The console: whole far away, gone beside it, never faster than
  // FADE_SECONDS for the whole way.
  assert.strictEqual(A.fadeTarget(10), 1);
  assert.strictEqual(A.fadeTarget(A.FADE_FAR), 1);
  assert.strictEqual(A.fadeTarget(2), 0);
  assert.ok(Math.abs(A.fadeTarget(4.5) - 0.5) < 1e-9);
  let alpha = 1;
  let t = 0;
  while (alpha > 0 && t < 5) {
    alpha = A.fadeStep(alpha, 0, 1 / 72);
    t += 1 / 72;
  }
  assert.ok(t >= A.FADE_SECONDS - 1 / 72 && t <= A.FADE_SECONDS + 2 / 72,
    `faded in ${t.toFixed(3)} s`);
  const pts = A.holyPoints(A.place(data, 'spare'));
  assert.strictEqual(pts.length, 1);
  const near = { x: khachkar.x - 2, z: khachkar.z, depth: khachkar.depth };
  assert.ok(A.holyDistance(near, pts) < A.FADE_NEAR);
  assert.strictEqual(A.holyDistance(near, []), Infinity);
});

test('the knight\'s things go to the scribe, not into the bag', () => {
  const placed = A.place(data, 'spare');
  const bag = { kept: [], released: [], handedOver: [] };
  const diary = find(placed, 'diary');
  const r = A.take(bag, diary);
  assert.strictEqual(r.reach, true);
  assert.deepStrictEqual(r.bag.atlas, ['diary']);
  assert.deepStrictEqual(r.bag.kept, []);
  assert.deepStrictEqual(r.bag.handedOver, []);
  assert.ok(r.text.includes('писцу'));
  assert.ok(!('atlas' in bag), 'take does not change its input');
  assert.strictEqual(A.take(r.bag, diary).bag.atlas.length, 1, 'once');
  const passage = A.take(bag, find(placed, 'passage'));
  assert.strictEqual(passage.reach, true);
  assert.ok(!('atlas' in passage.bag), 'the passage is looked at only');
  assert.ok(!('form' in r) && !('attribute' in r), 'no attribute');
  const page = A.scribePage(data, ['shield', 'diary', 'khachkar']);
  assert.ok(page.indexOf('Дневник') > 0
    && page.indexOf('Дневник') < page.indexOf('Щит'));
  assert.ok(!page.includes('Хачкар'));
  assert.strictEqual(A.scribePage(data, []), '');
  // A tag only up close (3.2 m).
  assert.strictEqual(A.labelFor(diary, 3), diary.ru);
  assert.strictEqual(A.labelFor(diary, 3.5), '');
});

test('own drawings: 12 files per kit, real sizes, their depth bands', () => {
  const placed = A.placeOwnDrawings();
  const total = A.OWN_DRAWINGS.reduce((s, k) => s + k.n, 0);
  assert.strictEqual(placed.length, total);
  A.OWN_DRAWINGS.forEach((kit) => {
    const files = A.kitFiles(kit);
    assert.strictEqual(files.length, 12);
    files.forEach((f) => {
      assert.ok(fs.existsSync(path.join(root, 'public/ludus/art/derived', f)),
        `web ${f}`);
      assert.ok(fs.existsSync(path.join(root, 'godot/art/derived', f)),
        `headset ${f}`);
    });
    // The same set the headset lists from its folder.
    const dir = path.join(root, 'godot/art/derived', kit.dir);
    const listed = fs.readdirSync(dir)
      .filter((f) => f.startsWith(kit.kit) && f.endsWith('.png')).sort();
    assert.deepStrictEqual(files.map((f) => path.basename(f)), listed);
    const mine = placed.filter((d) => d.kit === kit.kit);
    assert.strictEqual(mine.length, kit.n);
    mine.forEach((d, i) => {
      assert.strictEqual(d.size, kit.size);
      assert.ok(Math.abs(d.z) <= Core.CORRIDOR_M);
      const band = Core.baseDepth(d.x);
      assert.ok(band >= kit.depth[0] - 1e-9 && band <= kit.depth[1] + 1e-9,
        `${kit.kit} ${i} at ${band.toFixed(1)} m`);
      assert.ok(Math.abs(d.baseDepth - d.centreDepth - kit.size * 0.45)
        < 1e-9, 'stands on its lower edge');
      assert.strictEqual(d.loot, null);
      assert.strictEqual(d.holy, false);
      if (i > 0) {
        assert.notStrictEqual(d.file, mine[i - 1].file, 'no repeat');
      }
    });
  });
});

test('the web view keeps the holy rules in its drawing', () => {
  const view = fs.readFileSync(path.join(root,
    'public/ludus/dive/dive-view.js'), 'utf8');
  // No glow anywhere and no loot rule for the Atlas: the arm goes
  // through take(), which knows the khachkar.
  assert.ok(!/shadowBlur|shadowColor/.test(view), 'no glow');
  assert.ok(/Atlas\.take\(/.test(view));
  assert.ok(!/lootAction\(/.test(view), 'the Atlas never uses the bag');
  assert.ok(/Atlas\.fadeStep\(/.test(view) && /Atlas\.labelFor\(/.test(view));
  // The web writes no chronicle: it has no lectern yet.
  assert.ok(!/setItem\(Atlas\.CHRONICLE_KEY/.test(view));
});

test('own fish (DEF-056): only 12/12 kits swim, sized to real length', () => {
  const index = require('../public/ludus/data/fish-drawings.json');
  const fish = require('../public/ludus/data/issyk-kul-fish.json').fish;
  const schools = Core.fishSchools(fish);
  const placed = A.placeOwnFish(index, schools);
  assert.ok(placed.length > 0);
  for (const kit of index.kits) {
    assert.equal(kit.files.length, 12);
    for (const f of kit.files) {
      assert.ok(fs.existsSync(path.join(root, 'public/ludus/art/derived', f)),
        f);
    }
  }
  const short = new Set(index.short.map((s) => s.id));
  for (const f of placed) {
    assert.ok(!short.has(f.id), `${f.id} is short of 12`);
    const s = schools.find((x) => x.id === f.id);
    const kit = A.fishKit(index, f.id);
    const v = A.fishVariant(f.i);
    assert.equal(f.file, kit.files[v]);
    // The biggest fish of the drawing has the species' real length.
    assert.ok(Math.abs(f.size * kit.fish_px[v] / index.canvas_px
      - s.length) < 1e-9);
  }
  // Neighbours in a school never show the same variant.
  for (let i = 1; i < placed.length; i++) {
    if (placed[i].id === placed[i - 1].id) {
      assert.notEqual(placed[i].file, placed[i - 1].file);
    }
  }
  // The fixture the headset replays is current.
  const fx = require('../godot/tests/fixtures/atlas-traces.json');
  assert.deepEqual(fx.fish, placed.map((f) => ({ id: f.id, i: f.i,
    file: path.basename(f.file), size: f.size })));
});
