// AntagonistFactory (CLAUDE.md TABOO 0.3 rules 49-60, 95): the queue,
// the alpha hitbox, the radius and the opt-in analytics id.
// Run: node --test tests/*.test.js
// Regenerate the manifest inside the factory after the runner ships new
// passions: node tests/ludus-antagonist-factory.test.js --write
'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const FACTORY = path.join(ROOT, 'public/ludus/ludus-antagonist-factory.js');
const DIR = path.join(ROOT, 'public/ludus/art/derived/DEF-001');

function metas() {
  return fs.readdirSync(DIR).filter((f) => f.endsWith('.json')).sort()
    .map((f) => JSON.parse(fs.readFileSync(path.join(DIR, f), 'utf8')));
}

if (process.argv.includes('--write')) {
  const F = require(FACTORY);
  const body = JSON.stringify(F.fromMeta(metas()));
  const src = fs.readFileSync(FACTORY, 'utf8');
  const start = '/* BEGIN GENERATED MANIFEST */';
  const end = '/* END GENERATED MANIFEST */';
  const a = src.indexOf(start) + start.length;
  const b = src.indexOf(end);
  // One object per line keeps the diff of a new passion readable.
  const lines = JSON.parse(body).map((o) => `    ${JSON.stringify(o)},`);
  const block = `\n  const MANIFEST = [\n${
    lines.join('\n')}\n  ];\n  `;
  fs.writeFileSync(FACTORY, src.slice(0, a) + block + src.slice(b));
  console.log(`manifest: ${lines.length} objects`);
  process.exit(0);
}

const test = require('node:test');
const assert = require('node:assert/strict');
const F = require(FACTORY);
const P = require('../public/ludus/ludus-passion.js');
const data = require('../public/ludus/data/passions.json');

test('the embedded manifest is exactly the shipped meta files', () => {
  assert.deepEqual(JSON.parse(JSON.stringify(F.MANIFEST)),
    F.fromMeta(metas()));
  F.MANIFEST.forEach((o) => {
    assert.equal(o.variants.length, 12, o.id);
    o.variants.forEach((v) => {
      assert.ok(fs.existsSync(path.join(DIR, v.file)), v.file);
      assert.ok(v.shape >= F.THRESHOLD, `${v.file} ${v.shape}`);
    });
  });
});

test('pride, the passion that was missing, now has its twelve', () => {
  assert.ok(F.passions().includes('pride'));
  assert.equal(F.variantsOf('pride').length, 12);
});

test('all eight passions have their twelve (HLD follow-ups D3)', () => {
  assert.deepEqual([...F.passions()].sort(), [...F.PASSIONS].sort());
  F.PASSIONS.forEach((p) => {
    assert.ok(F.variantsOf(p).length >= 12, p);
  });
  // Lust is our own drawing, never raw material (chorus decision
  // docs/CHORUS_LUST_2026-09-30.md).
  metas().filter((m) => m.passion === 'lust').forEach((m) => {
    assert.equal(m.raw_material, false, m.name);
    assert.equal(m.origin, 'own-procedural-drawing', m.name);
  });
});

test('the queue never shows the same variant twice in a row', () => {
  F.passions().forEach((passion) => {
    const n = F.variantsOf(passion).length;
    const q = F.queue(passion, 'player-1', n * 6);
    for (let i = 1; i < q.length; i += 1) {
      assert.notEqual(`${q[i].objectId}${q[i].slot}`,
        `${q[i - 1].objectId}${q[i - 1].slot}`, `${passion} at ${i}`);
    }
    // Each round holds every variant exactly once.
    for (let r = 0; r < 6; r += 1) {
      const ids = new Set(q.slice(r * n, (r + 1) * n)
        .map((v) => v.objectId + v.slot));
      assert.equal(ids.size, n, `${passion} round ${r}`);
    }
  });
});

test('the seam between rounds is guarded even for two variants', () => {
  for (let n = 0; n < 200; n += 1) {
    assert.notEqual(F.queueIndex(2, 'k', n), F.queueIndex(2, 'k', n + 1));
  }
});

test('the queue is deterministic and depends on the seed', () => {
  const a = F.queue('pride', 's1', 24).map((v) => v.slot);
  assert.deepEqual(a, F.queue('pride', 's1', 24).map((v) => v.slot));
  assert.notDeepEqual(a, F.queue('pride', 's2', 24).map((v) => v.slot));
});

test('the hitbox is the alpha hull, not a square', () => {
  const s = F.sprite('pride', 0, 'x');
  assert.ok(s.hitbox.hull.length > 4);
  s.hitbox.hull.forEach(([x, y]) => {
    assert.ok(x >= 0 && x <= 1 && y >= 0 && y <= 1);
  });
  const square = { hitbox: { hull: [[0, 0], [1, 0], [1, 1], [0, 1]] } };
  assert.equal(F.hitTest(square, 0.5, 0.5), true);
  assert.equal(F.hitTest(square, 1.5, 0.5), false);
  // The corner of the sprite square lies outside every passion's hull.
  F.passions().forEach((p) => {
    assert.equal(F.hitTest(F.sprite(p, 0, 'x'), 0.01, 0.01), false, p);
  });
});

test('a stranger form gets a smaller interaction radius', () => {
  const area = 10000;
  const base = Math.sqrt(area / Math.PI) / 256;
  assert.equal(F.interactionRadius(0.35, area), base);
  assert.ok(F.interactionRadius(0.6, area) < base);
  assert.ok(F.interactionRadius(1, area) >= base / 2 - 1e-12);
});

test('analytics are opt-in and never leave through this module', () => {
  const s = F.sprite('pride', 0, 'x');
  assert.match(s.analyticsId,
    /^ludus\.variant\.pride\.[0-9a-f]{10}\.v(0[1-9]|1[0-2])$/);
  const seen = [];
  assert.equal(F.track(s), false);
  F.setAnalytics({ optIn: false, sink: (e) => seen.push(e) });
  assert.equal(F.track(s), false);
  F.setAnalytics({ optIn: true, sink: (e) => seen.push(e) });
  assert.equal(F.track(s), true);
  assert.deepEqual(seen, [{ event: 'ludus.variant.shown',
    id: s.analyticsId }]);
  F.setAnalytics({ optIn: false });
  assert.equal(F.track(s), false);
  const code = fs.readFileSync(FACTORY, 'utf8');
  ['Math.random', 'fetch(', 'XMLHttpRequest', 'sendBeacon', 'WebSocket',
    'localStorage', 'firebase', 'console.'].forEach((word) => {
    assert.ok(!code.includes(word), word);
  });
});

test('the road shows the factory sprite, a new one each meeting', () => {
  const copy = JSON.parse(JSON.stringify(data));
  const record = {};
  copy.order.slice(0, 7).forEach((id) => {
    record[id] = { meetings: 1, overcome: 1, captive: 0, discerned: true };
  });
  const first = P.nextPassion(copy, record);
  assert.equal(first.id, 'pride');
  assert.match(first.art, /^\/ludus\/art\/derived\/DEF-001\/ant_pride_/);
  assert.equal(first.sprite.passion, 'pride');
  // The entry is updated in place, so its art is copied before asking
  // again.
  const firstArt = first.art;
  assert.equal(P.nextPassion(copy, record).art, firstArt,
    'stable across re-renders');
  record.pride = { meetings: 1, overcome: 0, captive: 1, discerned: false };
  assert.notEqual(P.nextPassion(copy, record).art, firstArt);
});

test('a passion without shipped sprites keeps its own art', () => {
  const copy = JSON.parse(JSON.stringify(data));
  const lust = copy.passions.find((p) => p.id === 'lust');
  const record = { gluttony: { meetings: 1, overcome: 1 } };
  const next = P.nextPassion(copy, record);
  assert.equal(next.id, 'lust');
  assert.equal(next.art, lust.art);
});
