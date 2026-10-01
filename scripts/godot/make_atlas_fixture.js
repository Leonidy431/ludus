'use strict';
// Write godot/tests/fixtures/atlas-traces.json from
// public/ludus/dive/dive-atlas.js: where the web dive puts the knight's
// traces for each chronicle choice ("", spare, vault) and where it
// stands the own drawings of the shore (D6).  godot/tests/test_atlas.gd
// places the same things with AtlasTraces and the loop of dive.gd
// _build_own_drawings and compares every number, so the web and the
// headset show one floor.
// Usage: node scripts/godot/make_atlas_fixture.js

const fs = require('fs');
const path = require('path');
const A = require('../../public/ludus/dive/dive-atlas.js');

const root = path.join(__dirname, '..', '..');
const data = require(path.join(root, 'public/ludus/data/atlas-99.json'));
const Core = require('../../public/ludus/dive/dive-core.js');
const fishIndex = require(path.join(root,
  'public/ludus/data/fish-drawings.json'));
const fishData = require(path.join(root,
  'public/ludus/data/issyk-kul-fish.json'));

// Only the numbers the placement decides: the rest is the data itself.
const pick = (p) => ({ id: p.id, kind: p.kind, shape: p.shape,
  x: p.x, z: p.z, depth: p.depth, yaw: p.yaw });
const out = {
  note: 'Written by scripts/godot/make_atlas_fixture.js; do not edit.',
  traces: {},
  drawings: A.placeOwnDrawings().map((d) => ({ kit: d.kit,
    file: path.basename(d.file), x: d.x, z: d.z,
    centreDepth: d.centreDepth })),
  // The fish of our own drawing (DEF-056): which variant each fish of a
  // school shows and how big it is drawn.
  fish: A.placeOwnFish(fishIndex, Core.fishSchools(fishData.fish))
    .map((f) => ({ id: f.id, i: f.i, file: path.basename(f.file),
      size: f.size })),
};
['', 'spare', 'vault'].forEach((c) => {
  out.traces[c] = A.place(data, c).map(pick);
});
const file = path.join(root, 'godot/tests/fixtures/atlas-traces.json');
fs.writeFileSync(file, JSON.stringify(out, null, 1) + '\n');
console.log(`${file}: ${out.drawings.length} drawings, `
  + `${out.fish.length} fish, `
  + `${out.traces.spare.length} traces with the passage`);
