/**
 * Ludus: the core of the dive scene (operator, 2026-09-30: "делай
 * отдельную сцену погружения тщательно").
 *
 * Pure, deterministic functions with no three.js and no DOM, so every
 * rule of the dive is tested in node (tests/dive-core.test.js) and the
 * renderer (dive-scene.js) only draws what this module decides:
 *   - the floor: a cross-section of the Issyk-Kul shore, from the sand
 *     of the shallows over the shelf and its drowned terrace down the
 *     slope to the deep silt plain;
 *   - the water: temperature with a summer thermocline, light by
 *     Beer-Lambert (ludus-water.js), sound speed 1480/1435 m/s;
 *   - where each of the 99 lake objects and each fish school lives:
 *     always inside its own depth range (TABOO 0.07, no invention);
 *   - the ROV: thrust, drag, battery, the diver's ascent limit of
 *     10 m/min (TABOO 0.35 rule 19) and a sonar ping whose echo delay
 *     is the real 2 * range / c;
 *   - loot by the operator's rule (docs/ISSYK_KUL_FISH.md): keep,
 *     release, hand-over, or nothing to take.
 * No Math.random: every choice comes from a seed (TABOO 0.35 rule 15).
 */

'use strict';

(function (root) {
  const Water = (typeof module === 'object' && module.exports)
    ? require('../ludus-water.js')
    : root && root.LudusWater;

  // Distance from the shore (m) -> floor depth (m).  A cross-section in
  // the spirit of the northern shore: a gentle sandy shallows, the shelf
  // to about 20 m, a drowned shore terrace at 32-38 m (the old lake
  // level), a steep slope and the deep silt plain.  Game scale, to be
  // checked against a bathymetric chart before release.
  const PROFILE = [[0, 0], [40, 3], [160, 20], [230, 32], [260, 38],
    [420, 125], [520, 150], [700, 165]];
  const LENGTH_M = 700;
  const HALF_WIDTH_M = 90;
  const THERMOCLINE_M = 50;
  const CORRIDOR_M = 30;
  // Summer: warm mixed layer over cold deep water (about 4.5 degrees C
  // at depth in Issyk-Kul, which never freezes).  Surface value is a
  // July figure for the open lake; to be checked by a limnologist.
  const T_SURFACE = 18;
  const T_DEEP = 4.5;
  const ROV = {
    maxSpeed: 1.0,        // m/s horizontal: an observation-class ROV.
    maxVertical: 0.5,     // m/s up or down.
    accel: 0.8,           // m/s^2 at full thrust.
    drag: 1.2,            // 1/s linear water drag.
    yawRate: 0.9,         // rad/s at full stick.
    batterySec: 1800,     // 30 min at full thrust with the lamp on.
    minClearance: 0.6,    // m above the floor.
    maxDepth: 300,        // m, the tether length limits the dive.
  };

  function hash(text) {
    let h = 2166136261;
    for (let i = 0; i < text.length; i++) {
      h ^= text.charCodeAt(i);
      h = Math.imul(h, 16777619);
    }
    return h >>> 0;
  }

  /** mulberry32 seeded by a string: the same seed, the same world. */
  function rng(seed) {
    let a = hash(String(seed));
    return function next() {
      a = (a + 0x6D2B79F5) >>> 0;
      let t = a;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function baseDepth(x) {
    const cx = Math.max(0, Math.min(LENGTH_M, x));
    for (let i = 1; i < PROFILE.length; i++) {
      const [x0, d0] = PROFILE[i - 1];
      const [x1, d1] = PROFILE[i];
      if (cx <= x1) {
        return d0 + (d1 - d0) * (cx - x0) / (x1 - x0);
      }
    }
    return PROFILE[PROFILE.length - 1][1];
  }

  /**
   * Floor depth at (x, z).  Sand ripples and gentle undulation are
   * deterministic; their height grows with depth so the shallows stay
   * readable and the slope looks broken.
   */
  function floorDepth(x, z) {
    const d = baseDepth(x);
    const rough = 0.15 + Math.min(1.2, d / 60);
    return d + rough * (Math.sin(x * 0.11 + z * 0.07)
      + 0.5 * Math.sin(z * 0.23 - x * 0.05));
  }

  /** Inverse of the base profile: shore distance where the floor is d. */
  function xForDepth(d) {
    const cd = Math.max(0, Math.min(PROFILE[PROFILE.length - 1][1], d));
    for (let i = 1; i < PROFILE.length; i++) {
      const [x0, d0] = PROFILE[i - 1];
      const [x1, d1] = PROFILE[i];
      if (cd <= d1) {
        return x0 + (x1 - x0) * (cd - d0) / ((d1 - d0) || 1);
      }
    }
    return LENGTH_M;
  }

  function temperature(depth) {
    const k = 1 / (1 + Math.exp((depth - THERMOCLINE_M) / 4));
    return T_DEEP + (T_SURFACE - T_DEEP) * k;
  }

  // Where an object sits: on the floor, in the water column, or near
  // the surface.  Categories come from scripts/lake/lake_objects.py.
  const IN_WATER = new Set(['plankton', 'caustics', 'shafts', 'thermo',
    'snow', 'bubbles', 'turbid', 'seiche', 'karman', 'intwave', 'plume',
    'langmuir', 'upwelling']);

  function placement(o) {
    if (o.category === 'bird') {
      return 'surface';
    }
    if (o.category === 'water' || IN_WATER.has(o.item)) {
      return 'water';
    }
    return 'floor';
  }

  /**
   * Place the lake objects (not fish, not the tether, which the scene
   * draws live).  Each object ends up inside its own depth range: a
   * floor object on a floor of the right depth, a water object at a
   * depth of its range over deeper water.
   */
  function placeObjects(objects) {
    const out = [];
    (objects || []).forEach((o) => {
      if (o.category === 'fish' || o.item === 'tether') {
        return;
      }
      const r = rng(`dive:${o.id}`);
      const lo = o.depth[0];
      const hi = o.depth[1];
      const where = placement(o);
      // Things gather along the dive line (a corridor of +-30 m), so the
      // ROV meets them; spread over the whole shore they were out of
      // sight (first eye check of the 3D scene, 2026-09-30).
      const z = (r() * 2 - 1) * CORRIDOR_M;
      let x;
      let depth;
      if (where === 'floor') {
        const target = lo + (hi - lo) * (0.2 + 0.6 * r());
        x = xForDepth(target);
        depth = floorDepth(x, z);
        // Undulation may push the floor out of range at the edges;
        // step along the profile until it fits.
        for (let k = 0; k < 40 && (depth < lo || depth > hi); k++) {
          x += depth < lo ? 1.5 : -1.5;
          depth = floorDepth(x, z);
        }
      } else if (where === 'surface') {
        depth = Math.min(hi, 0.5 + r() * 2);
        x = xForDepth(Math.max(depth + 3, 5)) + r() * 20;
      } else {
        depth = lo + (hi - lo) * (0.25 + 0.5 * r());
        x = xForDepth(depth + 6 + r() * 10);
      }
      out.push({ id: o.id, item: o.item, category: o.category,
        ru: o.ru, shape: o.shape, colour: o.colour, size: o.size_m,
        flags: o.flags, depthRange: [lo, hi], where,
        x, z, depth: Math.max(0.3, depth), yaw: r() * Math.PI * 2 });
    });
    return out;
  }

  /**
   * One school per species, in the middle of its depth range and over
   * a floor at least as deep; bottom fish (loaches, tench) keep close
   * to the floor.
   */
  function fishSchools(fish) {
    return (fish || []).map((f) => {
      const r = rng(`school:${f.id}`);
      const lo = f.depth[0];
      const hi = f.depth[1];
      const depth = lo + (hi - lo) * (0.3 + 0.4 * r());
      const floorAt = f.bottom ? depth + 0.8 : depth + 3 + r() * 6;
      const x = xForDepth(Math.min(floorAt,
        PROFILE[PROFILE.length - 1][1]));
      const count = Math.max(1, Math.min(24, Math.round(f.school * 2)));
      return {
        id: f.id, ru: f.ru, latin: f.latin, status: f.status,
        loot: f.loot, redBook: !!f.redBook, colour: f.colour,
        length: f.length, bottom: !!f.bottom, depthRange: [lo, hi],
        centre: { x, z: (r() * 2 - 1) * CORRIDOR_M * 0.6, depth },
        radius: 2 + Math.sqrt(count) * 1.5,
        count, speed: 0.25 + f.length * 0.8,
        phase: r() * Math.PI * 2,
      };
    });
  }

  /**
   * Position and heading of fish i of a school at time t.  The school
   * circles its centre; each fish keeps its own radius and a slow
   * vertical sway, so the school breathes but never leaves its depth
   * range.
   */
  function fishAt(school, i, t) {
    const r = rng(`${school.id}:${i}`);
    const rad = school.radius * (0.4 + 0.6 * r());
    const off = r() * Math.PI * 2;
    const dir = school.id.length % 2 ? 1 : -1;
    const a = school.phase + off + dir * t * school.speed / rad;
    const sway = (school.bottom ? 0.2 : 1.2) * Math.sin(t * 0.4 + off);
    const [lo, hi] = school.depthRange;
    const depth = Math.max(lo, Math.min(hi, school.centre.depth + sway));
    return {
      x: school.centre.x + rad * Math.cos(a),
      z: school.centre.z + rad * Math.sin(a),
      depth,
      heading: a + dir * Math.PI / 2,
    };
  }

  function newRov() {
    return { x: 30, z: 0, depth: 1.5, yaw: Math.PI / 2,
      vx: 0, vz: 0, vy: 0, battery: 1, lamp: true,
      history: [] };
  }

  /**
   * Advance the ROV by dt seconds.  input: {forward, strafe, vertical,
   * turn} each in [-1, 1] (vertical > 0 is up), lamp boolean.  Returns
   * a new state; the old one is not changed.
   */
  function stepRov(state, input, dt) {
    const s = { ...state, history: state.history.slice(-40) };
    const inp = input || {};
    const clamp1 = (v) => Math.max(-1, Math.min(1, v || 0));
    const fwd = clamp1(inp.forward);
    const str = clamp1(inp.strafe);
    const ver = clamp1(inp.vertical);
    const power = s.battery > 0 ? 1 : 0;
    s.yaw += clamp1(inp.turn) * ROV.yawRate * dt * power;
    // Heading 0 looks along +x (away from the shore).
    const ax = (Math.cos(s.yaw) * fwd - Math.sin(s.yaw) * str)
      * ROV.accel * power;
    const az = (Math.sin(s.yaw) * fwd + Math.cos(s.yaw) * str)
      * ROV.accel * power;
    s.vx += (ax - ROV.drag * s.vx) * dt;
    s.vz += (az - ROV.drag * s.vz) * dt;
    s.vy += (ver * ROV.accel * power - ROV.drag * s.vy) * dt;
    const h = Math.hypot(s.vx, s.vz);
    if (h > ROV.maxSpeed) {
      s.vx *= ROV.maxSpeed / h;
      s.vz *= ROV.maxSpeed / h;
    }
    s.vy = Math.max(-ROV.maxVertical, Math.min(ROV.maxVertical, s.vy));
    s.x = Math.max(2, Math.min(LENGTH_M - 2, s.x + s.vx * dt));
    s.z = Math.max(-HALF_WIDTH_M + 2, Math.min(HALF_WIDTH_M - 2,
      s.z + s.vz * dt));
    s.depth -= s.vy * dt;
    const floor = floorDepth(s.x, s.z) - ROV.minClearance;
    s.depth = Math.max(0.3, Math.min(Math.min(floor, ROV.maxDepth),
      s.depth));
    const load = 0.25 + 0.5 * Math.max(Math.abs(fwd), Math.abs(str),
      Math.abs(ver)) + (s.lamp ? 0.25 : 0);
    s.battery = Math.max(0, s.battery - load * dt / ROV.batterySec);
    s.history.push([dt, s.depth]);
    return s;
  }

  /** Ascent rate over the last second or more of history, m/min. */
  function ascentRate(state) {
    let t = 0;
    let i = state.history.length - 1;
    if (i < 1) {
      return { mPerMin: 0, tooFast: false };
    }
    const now = state.history[i][1];
    while (i > 0 && t < 1) {
      t += state.history[i][0];
      i -= 1;
    }
    return Water.ascent(state.history[i][1], now, t)
      || { mPerMin: 0, tooFast: false };
  }

  function telemetry(state) {
    const floor = floorDepth(state.x, state.z);
    const range = Math.max(0, floor - state.depth);
    const up = ascentRate(state);
    return {
      depth: state.depth,
      floor,
      temperature: temperature(state.depth),
      pressureBar: Water.pressureBar(state.depth),
      heading: ((state.yaw * 180 / Math.PI) % 360 + 360) % 360,
      ascentMPerMin: up.mPerMin,
      ascentTooFast: up.tooFast,
      battery: state.battery,
      soundSpeed: Water.soundSpeed(state.depth, THERMOCLINE_M),
      echoDelay: Water.echoDelay(range, state.depth, THERMOCLINE_M),
      belowThermocline: state.depth > THERMOCLINE_M,
      light: Water.lightLeft(state.depth),
      shoreDistance: state.x,
    };
  }

  // Short, plain words for the result of an action (TABOO 0.39: no
  // church terms as labels; the reason is said as a craftsman would).
  const LOOT_WORDS = {
    keep: 'Взято в сумку.',
    release: 'Записано в журнал улова и отпущено: эту рыбу озеро '
      + 'бережёт.',
    'hand-over': 'Отложено для скриптория: чей это дом — узнает писец.',
    none: 'Взять нечего — только смотреть.',
    cross: 'На ней крест. Не трогаем, оставляем на месте.',
    site: 'Это часть памятника. Оставить на месте.',
    bird: 'Живая птица. Только смотреть.',
    water: 'Воду не унести. Только смотреть.',
  };

  /**
   * Apply the loot rule of a thing to the dive bag.  thing: {id, item,
   * category, flags: {loot}} or a fish school {id, loot}.  Returns
   * {bag, rule, text}; the bag is a new object.
   */
  function lootAction(thing, bag) {
    const b = {
      kept: (bag && bag.kept) ? bag.kept.slice() : [],
      released: (bag && bag.released) ? bag.released.slice() : [],
      handedOver: (bag && bag.handedOver) ? bag.handedOver.slice() : [],
    };
    const rule = thing.flags ? thing.flags.loot : thing.loot;
    const id = thing.item || thing.id;
    let text = LOOT_WORDS.none;
    if (rule === 'keep') {
      if (!b.kept.includes(id)) {
        b.kept.push(id);
      }
      text = LOOT_WORDS.keep;
    } else if (rule === 'release') {
      b.released.push(id);
      text = LOOT_WORDS.release;
    } else if (rule === 'hand-over') {
      if (!b.handedOver.includes(id)) {
        b.handedOver.push(id);
      }
      text = LOOT_WORDS['hand-over'];
    } else if (id === 'bulla') {
      text = LOOT_WORDS.cross;
    } else if (id === 'kosti') {
      text = LOOT_WORDS.site;
    } else if (thing.category === 'bird') {
      text = LOOT_WORDS.bird;
    } else if (thing.category === 'water') {
      text = LOOT_WORDS.water;
    }
    return { bag: b, rule: rule || null, text };
  }

  /** The nearest thing within reach in front of the ROV, or null. */
  function nearest(state, things, reach) {
    let best = null;
    let bestD = reach;
    things.forEach((t) => {
      const dx = t.x - state.x;
      const dz = t.z - state.z;
      const dy = t.depth - state.depth;
      const d = Math.hypot(dx, dy, dz);
      // Only what lies ahead: the camera looks along the heading.
      const ahead = dx * Math.cos(state.yaw) + dz * Math.sin(state.yaw);
      if (d < bestD && ahead > -0.5) {
        best = t;
        bestD = d;
      }
    });
    return best ? { thing: best, distance: bestD } : null;
  }

  const api = { PROFILE, LENGTH_M, HALF_WIDTH_M, THERMOCLINE_M, CORRIDOR_M,
    ROV,
    rng, baseDepth, floorDepth, xForDepth, temperature, placeObjects,
    fishSchools, fishAt, newRov, stepRov, ascentRate, telemetry,
    lootAction, nearest, LOOT_WORDS };
  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  }
  if (root) {
    root.LudusDiveCore = api;
  }
})(typeof window !== 'undefined' ? window : null);
