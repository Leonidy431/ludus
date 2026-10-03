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
 *   - the ROV: thrust, drag, battery (flat, it floats up and is hauled
 *     in on the tether), the ascent limit of 10 m/min (TABOO 0.35
 *     rule 19) and a sonar ping whose echo delay is the real
 *     2 * range / c, summed leg by leg through the thermocline;
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
  // With the battery flat the vehicle is lost to the dive, never the
  // person (CLAUDE.md TABOO 0.017): it is trimmed slightly positive, as
  // real ROVs are, so it floats up while the tether is hauled in.  8
  // m/min keeps a margin under the 10 m/min of rule 19.
  const RECOVERY_RISE_M_PER_MIN = 8;
  // The shallowest depth stepRov allows: the vehicle is at the surface.
  const SURFACE_DEPTH_M = 0.3;
  const RECOVERY_RU = 'Заряд кончился. Аппарат всплывает сам, его '
    + 'выбирают тросом: медленно, не быстрее десяти метров в минуту.';
  const RECOVERED_RU = 'Аппарат у поверхности. Его несут на стапель.';
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
    if (power > 0) {
      s.vy += (ver * ROV.accel - ROV.drag * s.vy) * dt;
    } else {
      // No thrust: buoyancy and the hauled tether lift it, and drag
      // eases it towards the recovery rate, never past it.
      const rise = RECOVERY_RISE_M_PER_MIN / 60;
      s.vy = Math.min(s.vy + ROV.drag * (rise - s.vy) * dt, rise);
    }
    const h = Math.hypot(s.vx, s.vz);
    if (h > ROV.maxSpeed) {
      s.vx *= ROV.maxSpeed / h;
      s.vz *= ROV.maxSpeed / h;
    }
    s.vy = Math.max(-ROV.maxVertical, Math.min(ROV.maxVertical, s.vy));
    s.x = Math.max(2, Math.min(LENGTH_M - 2, s.x + s.vx * dt));
    // inp.drift: the current along z in m/s (see current()); water
    // carries the ROV whatever the thrusters do.
    s.z = Math.max(-HALF_WIDTH_M + 2, Math.min(HALF_WIDTH_M - 2,
      s.z + (s.vz + (inp.drift || 0)) * dt));
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

  /**
   * A ping down rangeM from depth and back: the part of the path above
   * the layer runs at 1480 m/s and the part below it at 1435 m/s, so an
   * echo through the thermocline is the sum of both legs.
   */
  function echoDelay(depth, rangeM) {
    const bottom = depth + Math.max(0, rangeM);
    const above = Math.max(0, Math.min(bottom, THERMOCLINE_M)
      - Math.min(depth, THERMOCLINE_M));
    const below = Math.max(0, Math.max(bottom, THERMOCLINE_M)
      - Math.max(depth, THERMOCLINE_M));
    return 2 * (above / Water.C_ABOVE + below / Water.C_BELOW);
  }

  /** True once a vehicle with a flat battery is back at the surface. */
  function recovered(state) {
    return state.battery <= 0 && state.depth <= SURFACE_DEPTH_M + 1e-6;
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
      echoDelay: echoDelay(state.depth, range),
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

  // --- The dive as a game (HLD P2): each depth band is a task. --------
  //
  // Shallows: a training course after PADI/EFR drills (buoyancy, a
  // compass heading, a slow controlled ascent).  Shelf: finds for the
  // scribe.  Slope: the tether and the current.  Thermocline: the
  // crossing, heard as the speed of sound falling from 1480 to 1435 m/s.
  // Deep: silence, lamp off and still.  A rise faster than 10 m/min is a
  // fall, not a death: the lights dim and nothing counts until a safety
  // stop is held (TABOO 0.35 rule 19; no sin counter, no lost points).
  const TASKS = [
    { id: 'hover', band: 'shallows',
      ru: 'Курс: зависнуть на месте 10 с, не уходя по глубине дальше '
        + '0,3 м.' },
    { id: 'heading', band: 'shallows',
      ru: 'Курс: идти по компасу 10 с, не сбиваясь больше чем на 10°.' },
    { id: 'tether', band: 'shallows',
      ru: 'Трос: сделай полный оборот, вернись обратными поворотами к '
        + 'нулю и сними петлю манипулятором.' },
    { id: 'slowrise', band: 'shallows',
      ru: 'Курс: подняться на 3 м не быстрее 10 м/мин.' },
    { id: 'finds', band: 'shelf',
      ru: 'Шельф: найти три вещи затопленного посада для писца.' },
    { id: 'slope', band: 'slope',
      ru: 'Свал: спуститься по тросу на 45 м против течения.' },
    { id: 'thermocline', band: 'thermocline',
      ru: 'Термоклин: пересечь слой и услышать, как меняется звук.' },
    { id: 'silence', band: 'deep',
      ru: 'Глубина: погасить лампу и замереть на 20 с ниже 100 м.' },
  ];
  // The scribe's line after three finds: whose house it was.  The
  // underwater surveys of 2025 found brick walls, a millstone, glazed
  // brick and smith's tongs of the 13th-15th centuries on the shelf.
  const SCRIBE = {
    ru: 'Писец разложил находки на полотне: «Кирпич с глазурью, '
      + 'черепок, железо. Здесь жил не бедняк — мастер при дороге. Вода '
      + 'пришла, он ушёл, а дом остался говорить за него».',
    meaning: 'Things outlive their owners and testify for them; the '
      + 'player learns to read a place, not to plunder it.',
    source: 'International underwater archaeological expedition on '
      + 'Issyk-Kul, 2025 (IA RAS): walls, millstone, glazed brick, '
      + 'tongs, 13th-15th c.',
  };
  const SAFETY_STOP_SEC = 15;
  const FALL_AFTER_SEC = 2;

  function newGame() {
    const progress = {};
    TASKS.forEach((t) => { progress[t.id] = 0; });
    return { done: [], progress, fallen: false, fastFor: 0, stillFor: 0,
      holdDepth: null, holdHeading: null, riseFrom: null,
      crossedFrom: null, finds: 0, scribeTold: false,
      turns: 0, lastYaw: null, wound: false, kinkWarned: false,
      recovering: false, recovered: false };
  }

  function speedOf(rov) {
    return Math.hypot(rov.vx, rov.vz, rov.vy);
  }

  // Tether turns, as a real ROV console counts them: every full turn
  // of the vehicle twists the cable once more.  Three turns kink it.
  const KINK_TURNS = 3;
  const UNWOUND_TURNS = 0.1;

  function wrapAngle(a) {
    const tau = Math.PI * 2;
    return ((a + Math.PI) % tau + tau) % tau - Math.PI;
  }

  /**
   * Advance the game by dt after the ROV moved.  events: {handedOver:
   * number of finds handed over so far, arm: true on the step the
   * manipulator reached out}.  Returns {game, say: [texts]}.
   * Pure and deterministic like the rest of the core.
   */
  function stepGame(game, rov, dt, events) {
    const g = { ...game, done: game.done.slice(),
      progress: { ...game.progress } };
    const say = [];
    const tel = telemetry(rov);
    const finish = (id, text) => {
      if (!g.done.includes(id)) {
        g.done.push(id);
        say.push(text);
      }
    };
    // The tether twists with every turn, fallen or not: the cable does
    // not know about the light.
    if (g.lastYaw !== null) {
      g.turns += wrapAngle(rov.yaw - g.lastYaw) / (Math.PI * 2);
    }
    g.lastYaw = rov.yaw;
    if (Math.abs(g.turns) >= 1) {
      g.wound = true;
    }
    if (!g.kinkWarned && Math.abs(g.turns) >= KINK_TURNS) {
      g.kinkWarned = true;
      say.push('Трос закручен на три оборота: так ломают кабель. '
        + 'Разверни его обратно.');
    } else if (Math.abs(g.turns) < KINK_TURNS - 1) {
      g.kinkWarned = false;
    }
    // A flat battery ends the dive quietly: the narrator says so once,
    // the vehicle rises on its own, and nothing else counts (no task is
    // earned by floating up).
    if (rov.battery <= 0) {
      if (!g.recovering) {
        g.recovering = true;
        say.push(RECOVERY_RU);
      }
      if (!g.recovered && recovered(rov)) {
        g.recovered = true;
        say.push(RECOVERED_RU);
      }
      return { game: g, say };
    }
    // Fall: a sustained rise faster than the diver's limit.
    g.fastFor = tel.ascentTooFast ? g.fastFor + dt : 0;
    if (!g.fallen && g.fastFor >= FALL_AFTER_SEC) {
      g.fallen = true;
      g.stillFor = 0;
      say.push('Слишком быстро вверх: трос не успевают выбрать, слабина '
        + 'ложится петлёй к винту. Свет тускнеет. Замри: остановка '
        + 'безопасности даст выбрать слабину.');
    }
    const still = speedOf(rov) < 0.05;
    g.stillFor = still ? g.stillFor + dt : 0;
    if (g.fallen) {
      if (g.stillFor >= SAFETY_STOP_SEC) {
        g.fallen = false;
        g.stillFor = 0;
        say.push('Слабина выбрана, винт чист. Свет вернулся.');
      }
      return { game: g, say };
    }
    const d = rov.depth;
    if (d < 6) {
      // Buoyancy: stay within 0.3 m of where the hover began.
      if (still || Math.abs(rov.vy) < 0.03) {
        if (g.holdDepth === null) {
          g.holdDepth = d;
        }
        const ok = Math.abs(d - g.holdDepth) <= 0.3;
        g.progress.hover = ok ? g.progress.hover + dt : 0;
        if (!ok) {
          g.holdDepth = d;
        }
      } else {
        g.holdDepth = null;
        g.progress.hover = 0;
      }
      if (g.progress.hover >= 10) {
        finish('hover', 'Зависание удалось: ты держишь глубину, а не '
          + 'она тебя.');
      }
      // Heading: move forward within 10 degrees of one course.
      const moving = Math.hypot(rov.vx, rov.vz) > 0.2;
      if (moving) {
        if (g.holdHeading === null) {
          g.holdHeading = tel.heading;
        }
        const diff = Math.abs(((tel.heading - g.holdHeading) + 540)
          % 360 - 180);
        g.progress.heading = diff <= 10 ? g.progress.heading + dt : 0;
        if (diff > 10) {
          g.holdHeading = tel.heading;
        }
      } else {
        g.holdHeading = null;
        g.progress.heading = 0;
      }
      if (g.progress.heading >= 10) {
        finish('heading', 'Курс выдержан: компас ведёт, когда глаз '
          + 'ничего не видит.');
      }
    }
    // Tether: wound a full turn, brought back to zero the same way, and
    // the loop lifted off with the manipulator.
    if (g.wound && Math.abs(g.turns) <= UNWOUND_TURNS && events
        && events.arm) {
      finish('tether', 'Петля снята: трос не рвут, его разворачивают тем '
        + 'же путём.');
    }
    // Slow rise: three metres up without breaking 10 m/min.
    if (rov.vy > 0.01 && !tel.ascentTooFast) {
      if (g.riseFrom === null) {
        g.riseFrom = d;
      }
      if (g.riseFrom - d >= 3) {
        finish('slowrise', 'Медленное всплытие: трос выбирают без '
          + 'слабины, петля не ложится на винт.');
      }
    } else {
      g.riseFrom = null;
    }
    // Shelf finds for the scribe.
    g.finds = (events && events.handedOver) || g.finds;
    if (g.finds >= 3) {
      finish('finds', 'Три находки у писца.');
      if (!g.scribeTold) {
        g.scribeTold = true;
        say.push(SCRIBE.ru);
      }
    }
    // Slope: down the drop to 45 m.
    if (rov.x >= 260 && d >= 45) {
      finish('slope', 'Свал пройден: трос держит, течение не унесло.');
    }
    // Thermocline: from above 45 m to below 55 m.
    if (d < 45) {
      g.crossedFrom = 'above';
    } else if (d > 55 && g.crossedFrom === 'above') {
      finish('thermocline', 'Слой пройден. Вода стала холодной, а звук '
        + 'медленнее: 1480 → 1435 м/с. Эхо приходит позже.');
    }
    // Deep silence: below 100 m, lamp off, still for 20 s.
    if (d > 100 && !rov.lamp && still) {
      g.progress.silence += dt;
      if (g.progress.silence >= 20) {
        finish('silence', 'Тишина глубины. Здесь слышно только своё '
          + 'дыхание.');
      }
    } else {
      g.progress.silence = 0;
    }
    return { game: g, say };
  }

  /**
   * Lateral drift of the seiche current on the slope (m/s along z):
   * slow, reversing every few minutes, strongest mid-slope.
   */
  function current(x, t) {
    if (x < 230 || x > 440) {
      return 0;
    }
    const k = Math.sin(Math.PI * (x - 230) / 210);
    return 0.18 * k * Math.sin(t / 45);
  }

  // --- Biomes, bubbles, the thermocline heard (HLD_DIVE_BIOMES_BUBBLES).
  //
  // Five underwater biomes (TABOO 0.3 rule 59, TABOO 0.35 rule 19).  The
  // water colour, the fog and the light of each come from the absorption
  // of clear water (ludus-water.js), not from a palette.
  const BIOMES = ['shallows', 'thermocline', 'deep', 'night', 'sediments'];
  // Half-thickness of the thermocline band (m): the layer is 8-10 m
  // thick in summer; the band is where one sees and hears it.
  const THERMO_BAND_M = 5;
  // Below this mean fraction of surface light the lamp is the only
  // light: the "night" of the dive, from about 113 m in clear water.
  const NIGHT_LIGHT = 0.12;
  // Near the silt floor (clearance below this, floor deeper than the
  // gravel shelf) the view is the bottom sediments.
  const SEDIMENT_CLEARANCE_M = 2.5;
  const SEDIMENT_FROM_M = 30;
  const SILT = [0.33, 0.31, 0.28];
  // The lamp lights things this far away: out and back through water.
  const VIEW_M = 3;
  // A reference place for each biome (depth, clearance): where the
  // readability test looks at every object.
  const BIOME_REF = {
    shallows: { depth: 8, clearance: 10 },
    thermocline: { depth: 50, clearance: 20 },
    deep: { depth: 80, clearance: 20 },
    night: { depth: 140, clearance: 10 },
    sediments: { depth: 90, clearance: 1 },
  };
  const FOG = { shallows: 0.035, thermocline: 0.045, deep: 0.05,
    night: 0.05, sediments: 0.09 };

  function lightMean(depth) {
    const l = Water.lightLeft(depth);
    return (l.red + l.green + l.blue) / 3;
  }

  /** Which of the five biomes the ROV is in. */
  function biomeOf(depth, clearance) {
    const floor = depth + clearance;
    if (clearance <= SEDIMENT_CLEARANCE_M && floor >= SEDIMENT_FROM_M) {
      return 'sediments';
    }
    if (lightMean(depth) < NIGHT_LIGHT) {
      return 'night';
    }
    if (Math.abs(depth - THERMOCLINE_M) <= THERMO_BAND_M) {
      return 'thermocline';
    }
    return depth > THERMOCLINE_M ? 'deep' : 'shallows';
  }

  /**
   * Colour of the water around the ROV (display 0..1): surface light
   * scattered by clear water and dimmed band by band (Beer-Lambert).
   * The same numbers dive.gd drew before the biomes.
   */
  function waterColour(depth) {
    const l = Water.lightLeft(depth);
    const k = 1 / (1 + Math.max(0, depth) / 60);
    return [(40 * l.red * k + 4) / 255, (150 * l.green * k + 8) / 255,
      (190 * l.blue * k + 14) / 255];
  }

  /** The look of the water: biome, colour, fog, ambient and sun. */
  function biomeLook(depth, clearance) {
    const biome = biomeOf(depth, clearance);
    let water = waterColour(depth);
    if (biome === 'sediments') {
      // Stirred silt hangs in the water near the floor.
      // the silt scatters what light is left there, so it is as dim.
      const avg = lightMean(depth);
      water = water.map((c, i) => c * 0.75 + SILT[i] * 0.25 * avg);
    }
    const light = lightMean(depth);
    return { biome, water, fog: FOG[biome],
      ambient: biome === 'night' ? 0.05 : 0.25 + 0.6 * light,
      sun: biome === 'night' ? 0 : 0.15 + 1.1 * light };
  }

  function toLinear(c) {
    return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
  }

  function luminance(rgb) {
    const l = rgb.map(toLinear);
    return 0.2126 * l[0] + 0.7152 * l[1] + 0.0722 * l[2];
  }

  function hexRgb(hex) {
    const h = String(hex).replace('#', '');
    return [0, 2, 4].map((i) => parseInt(h.slice(i, i + 2), 16) / 255);
  }

  /**
   * An object's colour as seen at VIEW_M in a biome: its albedo lit by
   * what sunlight is left there and by the lamp (out and back through
   * the water, band by band), then veiled by the biome's fog.
   */
  function seenColour(rgb, biome) {
    const ref = BIOME_REF[biome];
    const look = biomeLook(ref.depth, ref.clearance);
    const sun = Water.lightLeft(ref.depth);
    const bands = ['red', 'green', 'blue'];
    const veil = Math.exp(-look.fog * VIEW_M);
    return rgb.map((c, i) => {
      const a = Water.ABSORPTION[bands[i]];
      const light = (biome === 'night' ? 0 : sun[bands[i]])
        * Math.exp(-a * VIEW_M) + Math.exp(-2 * a * VIEW_M);
      return Math.min(1, c * light) * veil + look.water[i] * (1 - veil);
    });
  }

  /** What an object is seen against: the water, or the silt floor. */
  function biomeBackground(biome) {
    if (biome === 'sediments') {
      return seenColour(SILT, 'sediments');
    }
    const ref = BIOME_REF[biome];
    return biomeLook(ref.depth, ref.clearance).water;
  }

  /** Luminance contrast ratio (WCAG form) of a colour in a biome. */
  function biomeContrast(hex, biome) {
    const a = luminance(seenColour(hexRgb(hex), biome));
    const b = luminance(biomeBackground(biome));
    return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
  }

  // Bubbles: they rise at about 0.25 m/s (a few-millimetre bubble's
  // terminal speed) and swell as the pressure falls (Boyle: the volume
  // goes as 1/p, the radius as its cube root).
  const BUBBLE_RISE = 0.25;
  const BUBBLE_R0 = 0.012;
  // The Mangustik's vent bleeds the air trapped in its frame only while
  // the pressure has not yet doubled (the first 10.2 m of the descent).
  const VENT_UNTIL_M = 10.2;

  function breathCycle(p) {
    return p.inhale + p.holdIn + p.exhale + p.holdOut;
  }

  /**
   * How strongly a column breathes out at time t, 0..1: bubbles leave
   * only on the exhale of the active hesychast pattern, never on the
   * inhale or the holds.
   */
  function bubblePuff(pattern, t) {
    const cycle = breathCycle(pattern);
    const q = ((t % cycle) + cycle) % cycle - pattern.inhale
      - pattern.holdIn;
    if (q < 0 || q >= pattern.exhale) {
      return 0;
    }
    return Math.sin(Math.PI * q / pattern.exhale);
  }

  /**
   * A bubble column: from a floor at `bottom` (m) up to `top` (m), with
   * `perBreath` bubbles on every exhale.  The small jitter of each
   * bubble is seeded by the column id, fixed once.
   */
  function bubbleColumn(id, x, z, bottom, top, perBreath, pattern) {
    const r = rng(`bubble:${id}`);
    const jitter = [];
    for (let j = 0; j < perBreath; j++) {
      jitter.push({ dx: (r() - 0.5) * 0.3, dz: (r() - 0.5) * 0.3,
        phase: r() * Math.PI * 2, f: 1.5 + r() * 1.5 });
    }
    const height = Math.max(0, bottom - top);
    const cycle = breathCycle(pattern);
    const alive = Math.ceil(height / BUBBLE_RISE / cycle) + 1;
    return { id, x, z, bottom, top, perBreath, jitter, pattern,
      count: perBreath * alive };
  }

  /**
   * Bubble i of a column at time t: {x, z, depth, size, visible}.  Each
   * breath k releases perBreath bubbles spread over its exhale; slot i
   * holds the bubble of the breath (i / perBreath) cycles ago.  wobble
   * false is the reduced-motion column: straight up, no sway.
   */
  function bubbleAt(col, i, t, wobble) {
    const p = col.pattern;
    const cycle = breathCycle(p);
    const j = i % col.perBreath;
    const m = Math.floor(i / col.perBreath);
    const k = Math.floor(t / cycle) - m;
    const birth = k * cycle + p.inhale + p.holdIn
      + p.exhale * (j + 0.5) / col.perBreath;
    const age = t - birth;
    const depth = col.bottom - BUBBLE_RISE * age;
    const jit = col.jitter[j];
    if (age < 0 || depth < col.top) {
      return { x: col.x, z: col.z, depth: col.bottom, size: 0,
        visible: false };
    }
    const sway = wobble ? 0.04 * Math.sin(jit.f * age + jit.phase) : 0;
    const size = BUBBLE_R0 * Math.cbrt(Water.pressureBar(col.bottom)
      / Water.pressureBar(depth));
    return { x: col.x + jit.dx + sway, z: col.z + jit.dz, depth, size,
      visible: true };
  }

  /** Bubbles one column releases per minute. */
  function bubblesPerMinute(col) {
    return 60 / breathCycle(col.pattern) * col.perBreath;
  }

  /**
   * The thermocline in the sonar: a density step reflects a part of the
   * ping.  Looking down from above the layer at a floor below it, a
   * faint echo returns after 2 * (layer - depth) / c.  Returns that
   * delay in seconds, or null when the layer is not between.
   */
  function layerEcho(depth, floor) {
    if (depth >= THERMOCLINE_M || floor <= THERMOCLINE_M) {
      return null;
    }
    return 2 * (THERMOCLINE_M - depth) / Water.C_ABOVE;
  }

  /**
   * Crossing the layer between two readings: 'down', 'up' or null.
   * The sound speed changes there (1480 -> 1435 m/s) and the ear hears
   * the sonar's pitch glide by the same ratio.
   */
  function thermoCrossing(prevDepth, depth) {
    if (prevDepth <= THERMOCLINE_M && depth > THERMOCLINE_M) {
      return 'down';
    }
    if (prevDepth > THERMOCLINE_M && depth <= THERMOCLINE_M) {
      return 'up';
    }
    return null;
  }

  const api = { PROFILE, LENGTH_M, HALF_WIDTH_M, THERMOCLINE_M, CORRIDOR_M,
    TASKS, SCRIBE, SAFETY_STOP_SEC, RECOVERY_RISE_M_PER_MIN,
    SURFACE_DEPTH_M, RECOVERY_RU, RECOVERED_RU, echoDelay, recovered, KINK_TURNS, UNWOUND_TURNS, newGame,
    stepGame, current,
    BIOMES, BIOME_REF, THERMO_BAND_M, NIGHT_LIGHT, VIEW_M, SILT,
    BUBBLE_RISE, BUBBLE_R0, VENT_UNTIL_M, biomeOf, biomeLook, waterColour,
    seenColour, biomeBackground, biomeContrast, luminance, hexRgb,
    bubblePuff, bubbleColumn, bubbleAt, bubblesPerMinute, layerEcho,
    thermoCrossing,
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
