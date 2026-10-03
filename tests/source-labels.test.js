// Russian labels of the campaign's sources (data/source-labels-ru.json,
// ludus-source-labels.js, godot/scripts/source_labels.gd).
// Run: node --test tests/*.test.js
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const M = require('../public/ludus/ludus-missions.js');
const A = require('../public/ludus/ludus-actions.js');
const L = require('../public/ludus/ludus-source-labels.js');

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
const TABLE = data('source-labels-ru.json');
const LABELS = TABLE.labels;

// Sources shown as they are, on purpose.  Empty: every source the
// campaign cites has its Russian label.  A source added here must say
// why it keeps its original form.
const FALLBACK = {};

// Every source a panel of the campaign can show: the act's teaching,
// the find, the deed, the dive, the talk (the node the step opens, the
// warm node, and every reply a branch leads to), the fall (the
// passion's ladder), the meeting on the road, and the thresholds.
function campaignSources() {
  const out = new Map();
  const add = (src, where) => {
    if (src) {
      out.set(src, (out.get(src) || []).concat(where));
    }
  };
  const nodeOf = (npc, id) => {
    const tree = ctx.trees.trees[npc];
    return tree.nodes.find((n) => n.id === id)
      || tree.nodes.find((n) => n.id === tree.startNode);
  };
  ctx.spine.missions.forEach((entry) => {
    const m = M.buildMission(ctx, entry.id);
    if (!m) {
      return;
    }
    add(m.source, `mission ${m.id}`);
    m.steps.forEach((s) => {
      if (s.kind === 'find') {
        add('Deuteronomy 22:1-3', 'find');
      } else if (s.kind === 'dive') {
        add('Psalm 103:24-25 (LXX; 104 in Hebrew numbering)', 'dive');
      } else if (s.kind === 'practice') {
        add(A.PRACTICES.find((p) => p.id === s.practice).source,
          `deed ${s.practice}`);
      } else if (s.kind === 'dialogue') {
        [s.node, s.warm].forEach((id) => {
          const n = nodeOf(s.npc, id);
          add(n.source, `${s.npc}:${n.id}`);
          (n.branches || []).forEach((b) => {
            const r = ctx.trees.trees[s.npc].nodes
              .find((x) => x.id === b.nextNodeId);
            if (r) {
              add(r.source, `${s.npc}:${r.id}`);
            }
          });
        });
      }
    });
  });
  ctx.passions.passions.forEach((p) => {
    add(p.ladder, `ladder ${p.id}`);
    add(p.source, `passion ${p.id}`);
  });
  ctx.trials.trials.forEach((t) => {
    add(t.source, `threshold ${t.gateId}`);
    t.options.forEach((o) => add(o.source, `threshold ${t.gateId}`));
  });
  return out;
}

const numbers = (s) => (s.match(/\d+/g) || []).map(Number)
  .sort((a, b) => a - b);

test('every campaign source has a label or an explicit fallback', () => {
  const all = campaignSources();
  assert.ok(all.size > 100, `campaign sources: ${all.size}`);
  all.forEach((where, src) => {
    assert.ok(LABELS[src] || FALLBACK[src],
      `no Russian label for "${src}" (${where[0]})`);
  });
});

test('no label changes a book, chapter, verse, step or canon number',
  () => {
    Object.entries(LABELS).forEach(([src, e]) => {
      assert.deepEqual(numbers(e.ru), numbers(src), `${src} -> ${e.ru}`);
    });
  });

test('labels are Russian and uncertain ones say what to check', () => {
  const english = /\b(Ladder|Psalm|Ps|Matthew|Matt|Mt|Luke|Lk|John|Jn|Prov|Proverbs|Synaxarion|Apophthegmata|Evagrius|step|steps|Homily|Homilies|Catechism|Treatises)\b/;
  Object.entries(LABELS).forEach(([src, e]) => {
    assert.equal(typeof e.ru, 'string', src);
    assert.ok(e.ru.length > 0, src);
    assert.ok(/[а-яё]/i.test(e.ru), `not Russian: ${e.ru}`);
    assert.equal(english.test(e.ru), false, `English left in: ${e.ru}`);
    // No Latin word of three letters or more either: only the siglum
    // LXX and Roman numerals of books and councils are kept.
    const latin = (e.ru.match(/[A-Za-z]{3,}/g) || [])
      .filter((w) => w !== 'LXX' && !/^[IVXLC]+$/.test(w));
    assert.deepEqual(latin, [], `Latin left in: ${e.ru}`);
    if (e.check) {
      assert.ok(typeof e.why === 'string' && e.why.length > 20,
        `check without why: ${src}`);
    }
  });
});

test('the table is one file for the web and the headset', () => {
  const web = fs.readFileSync(path.join(ROOT,
    'public/ludus/data/source-labels-ru.json'));
  const godot = fs.readFileSync(path.join(ROOT,
    'godot/data/source-labels-ru.json'));
  assert.ok(web.equals(godot), 'copies differ');
  const ci = fs.readFileSync(path.join(ROOT, '.github/workflows/godot.yml'),
    'utf8');
  // CI compares every same-named JSON of the two builds in one loop
  // (scripts/ci/check_shared_copies.py), this file among them.
  assert.ok(/check_shared_copies\.py/.test(ci), 'CI compares the copies');
});

test('the formatter falls back to the original, silently', async () => {
  assert.equal(L.labelRu(TABLE, 'Deuteronomy 22:1-3'), 'Втор. 22:1–3');
  assert.equal(L.labelRu(LABELS, 'Ladder, step 3'), 'Лествица, слово 3');
  assert.equal(L.labelRu(TABLE, 'Psalm 103:24-25 (LXX; 104 in Hebrew '
    + 'numbering)'), 'Пс. 103:24–25 (по LXX; 104 по еврейскому счёту)');
  assert.equal(L.labelRu(TABLE, 'Unknown 1:1'), 'Unknown 1:1');
  assert.equal(L.labelRu(null, 'Ladder, step 3'), 'Ladder, step 3');
  assert.equal(L.labelRu({ labels: { x: { ru: '' } } }, 'x'), 'x');
  assert.equal(L.labelRu(TABLE, 'toString'), 'toString');
  // A failed fetch gives no table, and nothing is thrown or logged.
  const failing = () => Promise.reject(new Error('offline'));
  assert.equal(await L.load(failing), null);
  const src = fs.readFileSync(path.join(ROOT,
    'public/ludus/ludus-source-labels.js'), 'utf8');
  assert.equal(/console\./.test(src), false, 'the formatter logs nothing');
});

test('the web panels show sources through the formatter', () => {
  const src = fs.readFileSync(path.join(ROOT,
    'public/ludus/ludus-missions.js'), 'utf8');
  assert.ok(src.includes('L.labelRu(ui.labels, src)'),
    'sourceLine formats the source');
  const page = fs.readFileSync(path.join(ROOT, 'public/index.html'),
    'utf8');
  assert.ok(page.indexOf('ludus-source-labels.js')
    < page.indexOf('ludus-missions.js"'), 'labels load before missions');
  // The road panel of the passions shows its sources the same way, as
  // the headset does (SourceLabels.ru in hub.gd).
  const game = fs.readFileSync(path.join(ROOT,
    'public/ludus/ludus-game.js'), 'utf8');
  assert.ok(game.includes('sourceRu(passion.source)')
    && game.includes('sourceRu(passion.ladder)'),
    'the road panel formats the passion sources');
  // The canonical data keeps its English sources (it mirrors the
  // webtypicon2 game source): the labels live only in the display table.
  assert.equal(M.ACT_PLAN.prologue.source, 'Ladder, step 3');
});
