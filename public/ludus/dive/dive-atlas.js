/**
 * Ludus: the Water Atlas in the web dive (TABOO 0.03, rules 3-4) and
 * the own drawings of the shore (D6).  A port of the headset's
 * godot/scripts/atlas_traces.gd, of CockpitCore's console fade and of
 * the placement loop in dive.gd _build_own_drawings, so the web and the
 * headset put every thing on the same spot of the same floor.
 *
 * Pure, deterministic functions with no DOM: tests/dive-atlas.test.js
 * checks them in node, and godot/tests/test_atlas.gd replays the same
 * placements from godot/tests/fixtures/atlas-traces.json (written by
 * scripts/godot/make_atlas_fixture.js from this file).
 *
 * Holy rules, as in the headset: the khachkar is noInteract/noLoot, the
 * arm does not move beside it and the console goes out; the knight's
 * things go to the scribe, never into the bag; the chronicle's choice
 * gives no attribute and no counter.  No Math.random anywhere.
 */

'use strict';

(function (root) {
  const Core = (typeof module === 'object' && module.exports)
    ? require('./dive-core.js')
    : root && root.LudusDiveCore;

  // The passage of nodes 26-27 lies on the slope at this depth.
  const PASSAGE_DEPTH = 44.0;
  const UNKNOWN_RU = 'Тип не определён.';
  // The console fades beside a holy thing: whole beyond FADE_FAR
  // metres, gone inside FADE_NEAR, never faster than FADE_SECONDS for
  // the whole way (godot/scripts/cockpit_core.gd).
  const FADE_FAR = 6.0;
  const FADE_NEAR = 3.0;
  const FADE_MIN = 0.0;
  const FADE_SECONDS = 1.75;
  // The arm's reach, the same as REACH_M in dive.gd.
  const REACH_M = 4.0;
  // A tag is read only up close (TABOO 0.013 rule 4).
  const TAG_M = 3.2;
  // Where the web keeps the chronicle's choice.  The web has no lectern
  // yet, so the dive only reads it; without it the passage is not drawn
  // (the headset writes it in the hub, hub.json "chronicle").
  const CHRONICLE_KEY = 'ludus.atlas.chronicle';
  const BAG_KEY = 'ludus.dive.atlas';

  // The neutral things of the shore drawn by our own generator (D6,
  // scripts/raw_assets/neutral_procedural.py), the same table as
  // OWN_DRAWINGS in dive.gd: real size in metres, the depth band where
  // the thing lives on this shore, how many stand in the dive.  `stem`
  // names the kit's 12 files (the web cannot list a folder).
  const OWN_DRAWINGS = [
    { dir: 'DEF-057', kit: 'own_boulder', stem: 'own_boulder_4d9da8b0ae',
      size: 0.9, depth: [3.0, 25.0], n: 24 },
    { dir: 'DEF-057', kit: 'own_quartz', stem: 'own_quartz_e0197ebc07',
      size: 0.25, depth: [0.5, 6.0], n: 24 },
    { dir: 'DEF-058', kit: 'own_trostnik', stem: 'own_trostnik_cbc1190335',
      size: 1.6, depth: [0.3, 2.0], n: 36 },
    { dir: 'DEF-058', kit: 'own_rdest', stem: 'own_rdest_2d5b9cbcc1',
      size: 0.9, depth: [1.5, 8.0], n: 30 },
    { dir: 'DEF-059', kit: 'own_balka', stem: 'own_balka_fc14815fb5',
      size: 1.8, depth: [4.0, 18.0], n: 12 },
    { dir: 'DEF-059', kit: 'own_khum', stem: 'own_khum_04712f8b8b',
      size: 0.8, depth: [8.0, 22.0], n: 8 },
  ];
  const VARIANTS = 12;

  function options(data) {
    return data.chronicle.options;
  }

  function option(data, id) {
    return options(data).find((o) => o.id === id) || null;
  }

  /**
   * Write the chronicle.  Only the first choice counts: a chronicle is
   * written once.  Returns the stored choice ("" when none).
   */
  function writeChronicle(data, current, id) {
    if (typeof current === 'string' && option(data, current)) {
      return current;
    }
    return option(data, id) ? id : '';
  }

  /**
   * A point on the floor of the dive line near `depth`, moved along the
   * shore by the seed (the order of the rng calls is the headset's).
   */
  function onFloor(seedText, depth) {
    const r = Core.rng(seedText);
    const z = (r() * 2 - 1) * Core.CORRIDOR_M * 0.5;
    let x = Core.xForDepth(depth);
    let d = Core.floorDepth(x, z);
    for (let k = 0; k < 40 && Math.abs(d - depth) > 1.0; k++) {
      x += d < depth ? 0.5 : -0.5;
      d = Core.floorDepth(x, z);
    }
    return { x, z, depth: d, yaw: r() * Math.PI * 2 };
  }

  /**
   * Everything of the Atlas on the lake floor for this chronicle choice
   * ("" before it is written: the passage is not drawn yet).
   */
  function place(data, choice) {
    const out = data.traces.map((tr) => {
      const at = onFloor(`atlas:${tr.id}:${choice}`, tr.depth);
      return { ...JSON.parse(JSON.stringify(tr)), ...at, kind: 'trace' };
    });
    const o = option(data, choice);
    if (o) {
      const at = onFloor(`atlas:passage:${choice}`, PASSAGE_DEPTH);
      out.push({ ...at, id: 'passage', kind: 'passage', shape: choice,
        ru: o.lake_ru, holy: false, loot: null, size: 2.5,
        colour: '#6f6a60', scribe_ru: o.written_ru });
    }
    return out;
  }

  /**
   * The arm meets a thing of the Atlas.  Returns {bag, text, reach}:
   * reach is false for a holy thing (the arm does not move), and only
   * the knight's things are handed to the scribe (bag.atlas).  No
   * attribute changes here or anywhere; the input is not changed.
   */
  function take(bag, thing) {
    const b = JSON.parse(JSON.stringify(bag || {}));
    const atlas = (b.atlas || []).slice();
    if (thing.holy) {
      return { bag: b, text: UNKNOWN_RU, reach: false };
    }
    if (thing.loot === 'hand-over') {
      if (!atlas.includes(thing.id)) {
        atlas.push(thing.id);
      }
      b.atlas = atlas;
      return { bag: b, reach: true,
        text: `${thing.ru} — писцу. Не в сумку: это чужая память.` };
    }
    return { bag: b, reach: true,
      text: `${thing.ru}. ${thing.scribe_ru || ''}` };
  }

  /** Holy points for the console's fade: {x, y, z} with y = -depth. */
  function holyPoints(placed) {
    return placed.filter((p) => p.holy)
      .map((p) => ({ x: p.x, y: -p.depth, z: p.z }));
  }

  /** Distance from the ROV to the nearest holy point (Infinity if none). */
  function holyDistance(rov, points) {
    let best = Infinity;
    points.forEach((p) => {
      best = Math.min(best, Math.hypot(rov.x - p.x, -rov.depth - p.y,
        rov.z - p.z));
    });
    return best;
  }

  /** How visible the console should be at this distance. */
  function fadeTarget(distance) {
    if (distance >= FADE_FAR) {
      return 1.0;
    }
    if (distance <= FADE_NEAR) {
      return FADE_MIN;
    }
    return FADE_MIN + (1.0 - FADE_MIN)
      * (distance - FADE_NEAR) / (FADE_FAR - FADE_NEAR);
  }

  /** One frame towards the target, as Godot's move_toward does. */
  function fadeStep(alpha, target, dt) {
    const delta = dt / FADE_SECONDS;
    if (Math.abs(target - alpha) <= delta) {
      return target;
    }
    return alpha + Math.sign(target - alpha) * delta;
  }

  /**
   * The tag a thing shows: only up close (3.2 m, TABOO 0.013 rule 4),
   * and never at a holy thing (no tag, no glow, no hint).
   */
  function labelFor(thing, distance) {
    if (thing.holy || distance > TAG_M) {
      return '';
    }
    return thing.ru || '';
  }

  /** What the scribe says of the things handed over, in list order. */
  function scribePage(data, handed) {
    const lines = data.traces
      .filter((tr) => handed.includes(tr.id) && String(tr.scribe_ru) !== '')
      .map((tr) => `${tr.ru}. ${tr.scribe_ru}`);
    if (!lines.length) {
      return '';
    }
    return 'Писцу передано со дна\n\n' + lines.join('\n\n');
  }

  /** The kit's 12 variant files, sorted as the headset lists them. */
  function kitFiles(kit) {
    const out = [];
    for (let v = 1; v <= VARIANTS; v++) {
      out.push(`${kit.dir}/${kit.stem}_v${String(v).padStart(2, '0')}.png`);
    }
    return out.sort();
  }

  /**
   * Where each own drawing stands: the loop of dive.gd
   * _build_own_drawings, step by step.  Each billboard stands on its
   * lower edge on the floor; `baseDepth` is the floor under it and
   * `centreDepth` the centre the headset's Sprite3D is placed at.
   * Scenery only: never loot, never holy.
   */
  function placeOwnDrawings() {
    const out = [];
    OWN_DRAWINGS.forEach((kit) => {
      const files = kitFiles(kit);
      const r = Core.rng(`own:${kit.kit}`);
      for (let i = 0; i < kit.n; i++) {
        const d = kit.depth[0] + (kit.depth[1] - kit.depth[0]) * r();
        const z = (r() * 2 - 1) * Core.CORRIDOR_M;
        const x = Core.xForDepth(d);
        const floor = Core.floorDepth(x, z);
        out.push({ kit: kit.kit, file: files[i % files.length], x, z,
          size: kit.size, baseDepth: floor,
          centreDepth: floor - kit.size * 0.45,
          loot: null, holy: false, kind: 'drawing' });
      }
    });
    return out;
  }

  const api = { PASSAGE_DEPTH, UNKNOWN_RU, FADE_FAR, FADE_NEAR, FADE_MIN,
    FADE_SECONDS, REACH_M, TAG_M, CHRONICLE_KEY, BAG_KEY, OWN_DRAWINGS, VARIANTS,
    options, option, writeChronicle, onFloor, place, take, holyPoints,
    holyDistance, labelFor, fadeTarget, fadeStep, scribePage, kitFiles,
    placeOwnDrawings };
  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  }
  if (root) {
    root.LudusDiveAtlas = api;
  }
})(typeof window !== 'undefined' ? window : null);
