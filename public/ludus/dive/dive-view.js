/**
 * Ludus: the web dive, drawn as a section of the shore (the headset has
 * the same floor in 3D, godot/scripts/dive.gd).  Everything it shows is
 * decided by dive-core.js and dive-atlas.js; this file only draws and
 * reads the keys:
 *   - the water by Beer-Lambert, the floor of the dive line, the
 *     thermocline at 50 m;
 *   - the knight's traces of the Water Atlas where the chronicle put
 *     them, and the passage (whole or fallen) once it is written;
 *   - the own drawings of the shore (D6) standing on the floor in their
 *     real sizes, fainter the farther they stand from the dive line;
 *   - the Mangustik with its lamp and its arm.
 * The khachkar is drawn in its own stone, with no tag and no glow; the
 * arm does not move beside it and the console fades (as in the
 * headset).  The knight's things go to the scribe, not into the bag.
 * No Math.random: the rubble of the vault has its own seed.
 */

'use strict';

(function () {
  const Core = window.LudusDiveCore;
  const Atlas = window.LudusDiveAtlas;
  const Water = window.LudusWater;
  const PX_PER_M = 56;
  const LAMP_M = 5;
  const ART = '../art/derived/';

  const params = new URLSearchParams(window.location.search);
  const canvas = document.getElementById('dive-canvas');
  const ctx = canvas.getContext('2d');
  const consoleEl = document.getElementById('dive-console');
  const telemetryEl = document.getElementById('dive-telemetry');
  const messageEl = document.getElementById('dive-message');

  const state = {
    rov: Core.newRov(),
    keys: {},
    held: {},
    consoleAlpha: 1,
    message: '',
    messageLeft: 0,
    armLeft: 0,
    data: null,
    traces: [],
    holy: [],
    drawings: [],
    fish: [],
    fishIndex: null,
    time: 0,
    images: {},
    bag: { atlas: [] },
    last: 0,
  };
  // The section looks from the shore out to the deep: heading along +x.
  state.rov.yaw = 0;

  function readStore(key) {
    try {
      return window.localStorage.getItem(key);
    } catch (e) {
      return null;
    }
  }

  function writeStore(key, value) {
    try {
      window.localStorage.setItem(key, value);
    } catch (e) {
      // A private window: the scribe's list lives for this visit only.
    }
  }

  function loadBag() {
    try {
      const b = JSON.parse(readStore(Atlas.BAG_KEY) || 'null');
      if (b && Array.isArray(b.atlas)) {
        return { atlas: b.atlas.filter((id) => typeof id === 'string') };
      }
    } catch (e) {
      // A broken save starts an empty list, never a broken dive.
    }
    return { atlas: [] };
  }

  /**
   * The chronicle is written at the lectern (in the headset, in the
   * hub); the web has no lectern yet, so the dive reads it and falls
   * back to "" (no passage).  ?chronicle= shows a floor for proof
   * frames without saving anything, as dive.gd does for its shots.
   */
  function chronicle(data) {
    const shown = params.get('chronicle');
    if (shown !== null) {
      return Atlas.writeChronicle(data, null, shown);
    }
    return Atlas.writeChronicle(data, readStore(Atlas.CHRONICLE_KEY), '');
  }

  function say(text) {
    state.message = text;
    state.messageLeft = 7;
  }

  // --- Light ------------------------------------------------------------

  function sunAt(depth) {
    const l = Water.lightLeft(depth);
    return (l.red + l.green + l.blue) / 3;
  }

  /** How lit a point is: the sun left at its depth plus the ROV's lamp. */
  function litAt(x, depth, z) {
    const r = state.rov;
    const d = Math.hypot(x - r.x, depth - r.depth, z - r.z);
    const lamp = r.lamp ? 0.9 * Math.exp(-d / LAMP_M) : 0;
    return Math.max(0.06, Math.min(1, sunAt(depth) + lamp));
  }

  function rgbCss(rgb, k) {
    const c = rgb.map((v) => Math.round(Math.max(0, Math.min(1, v * k))
      * 255));
    return `rgb(${c[0]}, ${c[1]}, ${c[2]})`;
  }

  function hexScaled(hex, k) {
    return rgbCss(Core.hexRgb(hex), k);
  }

  // --- Projection -------------------------------------------------------

  function view() {
    const w = canvas.clientWidth;
    const h = canvas.clientHeight;
    return { w, h, cx: w * 0.4, cy: h * 0.45 };
  }

  function toScreen(v, x, depth) {
    return [v.cx + (x - state.rov.x) * PX_PER_M,
      v.cy + (depth - state.rov.depth) * PX_PER_M];
  }

  /** Things off the dive line fade into the water (the section's depth). */
  function veil(z) {
    return Math.max(0.18, Math.exp(-Math.abs(z - state.rov.z) / 14));
  }

  // --- Drawing ----------------------------------------------------------

  function drawWater(v) {
    const top = state.rov.depth - v.cy / PX_PER_M;
    for (let y = 0; y < v.h; y += 6) {
      const d = top + y / PX_PER_M;
      ctx.fillStyle = d < 0 ? '#9fb4c0' : rgbCss(Core.waterColour(d), 1);
      ctx.fillRect(0, y, v.w, 6);
    }
    // The thermocline: a thin shimmer of the density step, not a wall.
    const [, ty] = toScreen(v, 0, Core.THERMOCLINE_M);
    if (ty > -4 && ty < v.h + 4) {
      ctx.fillStyle = 'rgba(207, 232, 255, 0.10)';
      ctx.fillRect(0, ty - 3, v.w, 6);
    }
  }

  function drawFloor(v) {
    const r = state.rov;
    const x0 = r.x - v.cx / PX_PER_M - 1;
    const x1 = r.x + (v.w - v.cx) / PX_PER_M + 1;
    ctx.beginPath();
    for (let x = x0; x <= x1; x += 0.25) {
      const [sx, sy] = toScreen(v, x, Core.floorDepth(x, r.z));
      if (x === x0) {
        ctx.moveTo(sx, sy);
      } else {
        ctx.lineTo(sx, sy);
      }
    }
    ctx.lineTo(v.w + 10, v.h + 10);
    ctx.lineTo(-10, v.h + 10);
    ctx.closePath();
    const floor = Core.floorDepth(r.x, r.z);
    // Sand in the shallows, grey silt in the deep, lit only by what the
    // sun leaves at that depth; the lamp's cone is drawn over it.
    const base = floor < 40 ? '#b49a74' : '#6d6a62';
    ctx.fillStyle = hexScaled(base, Math.max(0.12, sunAt(floor)));
    ctx.fill();
  }

  function drawDrawing(v, d) {
    const img = state.images[d.file];
    if (!img || !img.complete || !img.naturalWidth) {
      return;
    }
    const [sx, sy] = toScreen(v, d.x, d.centreDepth);
    const s = d.size * PX_PER_M;
    if (sx < -s || sx > v.w + s || sy < -s || sy > v.h + s) {
      return;
    }
    ctx.save();
    ctx.globalAlpha = veil(d.z);
    ctx.filter = `brightness(${litAt(d.x, d.baseDepth, d.z).toFixed(3)})`;
    ctx.drawImage(img, sx - s / 2, sy - s / 2, s, s);
    ctx.restore();
  }

  /**
   * A fish of our own drawing (DEF-056) as the school's rule shows it
   * now, seen from the ROV (Atlas.fishSpot: the cell of its queue, the
   * view from below or above only at a steep angle, a resting fish on
   * the floor).  A side view faces left and is turned by the view when
   * the fish swims to +x, never drawn mirrored.  Lit and veiled like
   * the drawings.
   */
  function drawFish(v, f) {
    const p = Atlas.fishSpot(state.fishIndex, f.kit, f.school, f.i,
      state.time, state.rov);
    const img = state.images[p.file];
    if (!img || !img.complete || !img.naturalWidth) {
      return;
    }
    const [sx, sy] = toScreen(v, p.x, p.depth);
    const s = p.size * PX_PER_M;
    if (sx < -s || sx > v.w + s || sy < -s || sy > v.h + s) {
      return;
    }
    ctx.save();
    ctx.globalAlpha = veil(p.z);
    ctx.filter = `brightness(${litAt(p.x, p.depth, p.z).toFixed(3)})`;
    ctx.translate(sx, sy);
    if (!p.top && Math.cos(p.heading) > 0) {
      ctx.scale(-1, 1);
    }
    ctx.drawImage(img, -s / 2, -s / 2, s, s);
    ctx.restore();
  }

  function part(v, p, dx, dy, w, h, colour) {
    const [sx, sy] = toScreen(v, p.x + dx, p.depth - dy);
    ctx.fillStyle = colour;
    ctx.fillRect(sx - w * PX_PER_M / 2, sy - h * PX_PER_M / 2,
      w * PX_PER_M, h * PX_PER_M);
  }

  /**
   * A khachkar of our own drawing: an upright slab with a cross in low
   * relief, split tips and a rosette.  The same stone as the slab, seen
   * by the lamp like any stone: no halo, no glow, no tag.
   */
  function drawKhachkar(v, p, k) {
    const stone = hexScaled(p.colour, k);
    const relief = hexScaled(p.colour, k * 1.18);
    const edge = hexScaled(p.colour, k * 0.7);
    part(v, p, 0, 0.8, 0.9, 1.6, stone);
    ctx.strokeStyle = edge;
    ctx.lineWidth = 1;
    const [ex, ey] = toScreen(v, p.x - 0.45, p.depth - 1.6);
    ctx.strokeRect(ex, ey, 0.9 * PX_PER_M, 1.6 * PX_PER_M);
    part(v, p, 0, 1.0, 0.1, 0.8, relief);
    part(v, p, 0, 1.15, 0.56, 0.1, relief);
    [[0, 1.42], [0, 0.58], [-0.3, 1.15], [0.3, 1.15]].forEach(([dx, dy]) => {
      part(v, p, dx, dy, 0.12, 0.12, relief);
    });
    const [rx, ry] = toScreen(v, p.x, p.depth - 0.3);
    ctx.beginPath();
    ctx.arc(rx, ry, 0.11 * PX_PER_M, 0, Math.PI * 2);
    ctx.fillStyle = relief;
    ctx.fill();
  }

  function drawTrace(v, p) {
    const k = litAt(p.x, p.depth, p.z);
    const c = hexScaled(p.colour, k);
    ctx.save();
    ctx.globalAlpha = veil(p.z);
    const [sx, sy] = toScreen(v, p.x, p.depth);
    switch (p.shape) {
      case 'book':
        part(v, p, 0, 0.04, 0.3, 0.08, c);
        break;
      case 'amphora':
        // Lying on its side, half in the silt.
        ctx.beginPath();
        ctx.ellipse(sx, sy - 0.08 * PX_PER_M, 0.3 * PX_PER_M,
          0.13 * PX_PER_M, -0.1, 0, Math.PI * 2);
        ctx.fillStyle = c;
        ctx.fill();
        part(v, p, 0.33, 0.1, 0.1, 0.07, c);
        break;
      case 'astrolabe':
        ctx.beginPath();
        ctx.ellipse(sx, sy - 0.04 * PX_PER_M, 0.13 * PX_PER_M,
          0.05 * PX_PER_M, 0, 0, Math.PI * 2);
        ctx.strokeStyle = c;
        ctx.lineWidth = 2.5;
        ctx.stroke();
        break;
      case 'shield':
        ctx.beginPath();
        ctx.ellipse(sx, sy - 0.12 * PX_PER_M, 0.45 * PX_PER_M,
          0.14 * PX_PER_M, 0, 0, Math.PI * 2);
        ctx.fillStyle = c;
        ctx.fill();
        part(v, p, 0, 0.2, 0.18, 0.08, hexScaled(p.colour, k * 0.85));
        break;
      case 'khachkar':
        drawKhachkar(v, p, k);
        break;
      case 'spare':
        part(v, p, -1.1, 1.1, 0.5, 2.2, c);
        part(v, p, 1.1, 1.1, 0.5, 2.2, c);
        part(v, p, 0, 2.4, 2.8, 0.45, c);
        break;
      case 'vault': {
        const r = Core.rng('atlas:rubble');
        for (let i = 0; i < 9; i++) {
          const s = 0.7 + 0.6 * r();
          const dx = (r() - 0.5) * 2.4;
          const dy = 0.15 + 0.2 * (i % 3);
          // The depth offset and the three turns of the headset's
          // stone: not drawn in the section, drawn so the seed stays
          // in step with dive.gd.
          r();
          r();
          r();
          r();
          part(v, p, dx, dy, 0.5 * s, 0.35 * s,
            hexScaled(p.colour, k * (1 - 0.1 * (i % 3))));
        }
        break;
      }
      default:
        break;
    }
    ctx.restore();
    const r = state.rov;
    const tag = Atlas.labelFor(p, Math.hypot(p.x - r.x, p.depth - r.depth,
      p.z - r.z));
    if (tag) {
      ctx.font = '13px system-ui, sans-serif';
      ctx.fillStyle = 'rgba(240, 240, 240, 0.9)';
      ctx.fillText(tag, sx + 8, sy - 0.6 * PX_PER_M);
    }
  }

  function drawRov(v) {
    const r = state.rov;
    const facing = Math.cos(r.yaw) >= 0 ? 1 : -1;
    const x = v.cx;
    const y = v.cy;
    // The lamp: instrument light (6500 K), a cone ahead.
    if (r.lamp) {
      const g = ctx.createRadialGradient(x, y, 4, x, y, LAMP_M * PX_PER_M);
      g.addColorStop(0, 'rgba(207, 232, 255, 0.22)');
      g.addColorStop(1, 'rgba(207, 232, 255, 0)');
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.arc(x, y, LAMP_M * PX_PER_M, facing > 0 ? -0.45 : Math.PI - 0.45,
        facing > 0 ? 0.45 : Math.PI + 0.45);
      ctx.closePath();
      ctx.fill();
    }
    // The body: an oak-and-copper frame of the workshop, 0.6 x 0.35 m.
    ctx.fillStyle = '#7a5a3a';
    ctx.fillRect(x - 12, y - 7, 24, 14);
    ctx.fillStyle = '#b87333';
    ctx.fillRect(x - 12, y - 9, 24, 3);
    ctx.fillStyle = '#cfe8ff';
    ctx.fillRect(x + facing * 10 - 2, y - 3, 4, 5);
    // The arm reaches out only when it may.
    const reach = state.armLeft > 0 ? 1 : 0.35;
    ctx.strokeStyle = '#8c8c8c';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(x + facing * 10, y + 6);
    ctx.lineTo(x + facing * (10 + 40 * reach), y + 6 + 18 * reach);
    ctx.stroke();
  }

  function draw() {
    const v = view();
    const dpr = window.devicePixelRatio || 1;
    // Both sides are checked: a phone address bar or a Quest browser
    // window changes only the height, and a stale buffer would stretch.
    const bw = Math.round(v.w * dpr);
    const bh = Math.round(v.h * dpr);
    if (canvas.width !== bw || canvas.height !== bh) {
      canvas.width = bw;
      canvas.height = bh;
    }
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    drawWater(v);
    // Far things first, then the floor of the line, then what is near.
    const z = state.rov.z;
    const far = state.drawings.filter((d) => d.z - z < -2);
    const near = state.drawings.filter((d) => d.z - z >= -2);
    far.forEach((d) => drawDrawing(v, d));
    drawFloor(v);
    near.forEach((d) => drawDrawing(v, d));
    state.fish.forEach((f) => drawFish(v, f));
    state.traces.forEach((p) => drawTrace(v, p));
    drawRov(v);
  }

  // --- The console ------------------------------------------------------

  function updateConsole(dt) {
    const target = Atlas.fadeTarget(Atlas.holyDistance(state.rov,
      state.holy));
    state.consoleAlpha = Atlas.fadeStep(state.consoleAlpha, target, dt);
    consoleEl.style.opacity = state.consoleAlpha.toFixed(3);
    consoleEl.setAttribute('aria-hidden',
      state.consoleAlpha < 0.05 ? 'true' : 'false');
    const t = Core.telemetry(state.rov);
    telemetryEl.textContent = [
      `Глубина ${t.depth.toFixed(1)} м · дно ${t.floor.toFixed(1)} м`,
      `Вода ${t.temperature.toFixed(1)} °C · ${t.pressureBar.toFixed(2)} бар`,
      `Звук ${t.soundSpeed.toFixed(0)} м/с · берег ${t.shoreDistance
        .toFixed(0)} м`,
      `Батарея ${Math.round(t.battery * 100)} % · писцу `
        + `${state.bag.atlas.length}`,
    ].join('\n');
    if (state.messageLeft > 0) {
      state.messageLeft -= dt;
      messageEl.textContent = state.message;
    } else {
      messageEl.textContent = '';
    }
  }

  // --- Input ------------------------------------------------------------

  function input() {
    const k = state.keys;
    const h = state.held;
    const right = k.ArrowRight || k.KeyD || h.right;
    const left = k.ArrowLeft || k.KeyA || h.left;
    if (right && !left) {
      state.rov.yaw = 0;
    } else if (left && !right) {
      state.rov.yaw = Math.PI;
    }
    return {
      forward: (right || left) && !(right && left) ? 1 : 0,
      vertical: (k.ArrowUp || k.KeyW || h.up ? 1 : 0)
        - (k.ArrowDown || k.KeyS || h.down ? 1 : 0),
      // Along the shore: z grows to the right of the dive line.
      strafe: ((k.KeyE || h.far ? 1 : 0) - (k.KeyQ || h.near ? 1 : 0))
        * (Math.cos(state.rov.yaw) >= 0 ? 1 : -1),
      turn: 0,
    };
  }

  /**
   * The arm: the knight's things go to the scribe; at the khachkar the
   * arm does not move at all and the protocol answers "type unknown".
   */
  function reach() {
    const hit = Core.nearest(state.rov, state.traces, Atlas.REACH_M);
    if (!hit) {
      state.armLeft = 0.6;
      say('Рядом ничего нет. Подойди ближе.');
      return;
    }
    const res = Atlas.take(state.bag, hit.thing);
    if (res.reach) {
      state.armLeft = 0.6;
    }
    state.bag = res.bag;
    writeStore(Atlas.BAG_KEY, JSON.stringify(state.bag));
    say(res.text);
  }

  function bindKeys() {
    window.addEventListener('keydown', (e) => {
      if (e.code === 'Space' || e.code === 'Enter') {
        if (!e.repeat) {
          reach();
        }
        e.preventDefault();
        return;
      }
      if (e.code === 'KeyL' && !e.repeat) {
        state.rov.lamp = !state.rov.lamp;
      }
      state.keys[e.code] = true;
      if (e.code.startsWith('Arrow')) {
        e.preventDefault();
      }
    });
    window.addEventListener('keyup', (e) => {
      state.keys[e.code] = false;
    });
    window.addEventListener('blur', () => {
      state.keys = {};
      state.held = {};
    });
    document.querySelectorAll('[data-hold]').forEach((b) => {
      const name = b.getAttribute('data-hold');
      const on = (e) => {
        state.held[name] = true;
        e.preventDefault();
      };
      const off = () => {
        state.held[name] = false;
      };
      b.addEventListener('pointerdown', on);
      b.addEventListener('pointerup', off);
      b.addEventListener('pointerleave', off);
      b.addEventListener('pointercancel', off);
    });
    const arm = document.getElementById('dive-arm');
    if (arm) {
      arm.addEventListener('click', reach);
    }
  }

  // --- Proof frames -----------------------------------------------------

  /**
   * ?goto=diary|khachkar|passage|drawings puts the ROV 2.5 m short of the
   * thing, up the slope, as dive.gd does for its proof frames.  It is a
   * mark of the sonar, not a jump in the game: nothing is counted.
   */
  function goTo(where) {
    let target = state.traces.find((p) => p.id === where);
    if (!target && where === 'drawings') {
      const reeds = state.drawings.filter((d) => d.kit === 'own_rdest');
      target = reeds.reduce((a, b) => (Math.abs(a.z) <= Math.abs(b.z)
        ? a : b));
      target = { x: target.x + 3, depth: target.baseDepth, z: target.z };
    }
    if (!target) {
      return;
    }
    // Up the slope the floor lifts the ROV, so at a holy thing the
    // stand-off shrinks until the ROV is inside FADE_NEAR: the proof frame
    // must show the console truly gone, not 3.04 m away at 0.012.
    const holy = Boolean(target.holy);
    let rov = null;
    for (let off = 2.5; off >= 0.75; off -= 0.25) {
      rov = standOff(target, off);
      if (!holy || Atlas.holyDistance(rov, state.holy)
          <= Atlas.FADE_NEAR - 0.2) {
        break;
      }
    }
    state.rov = rov;
  }

  function standOff(target, off) {
    const rov = Core.newRov();
    rov.x = target.x - off;
    rov.z = target.z;
    rov.yaw = 0;
    rov.depth = Math.max(0.5, Math.min(target.depth - 1.0,
      Core.floorDepth(rov.x, rov.z) - Core.ROV.minClearance));
    return rov;
  }

  // --- Loop -------------------------------------------------------------

  function frame(now) {
    const dt = Math.min(0.1, state.last ? (now - state.last) / 1000 : 0);
    state.last = now;
    state.time += dt;
    state.rov = Core.stepRov(state.rov, input(), dt);
    state.armLeft = Math.max(0, state.armLeft - dt);
    updateConsole(dt);
    draw();
    window.requestAnimationFrame(frame);
  }

  /**
   * The fish of our own drawing: the schools of the lake (dive-core.js)
   * whose species has a 12/12 kit, one entry per fish; what each shows
   * is chosen every frame (drawFish).  Without the index the dive goes
   * on without them.
   */
  async function loadFish() {
    try {
      const [idx, fish] = await Promise.all([
        fetch('../data/fish-drawings.json').then((r) => r.json()),
        fetch('../data/issyk-kul-fish.json').then((r) => r.json())]);
      state.fishIndex = idx;
      const out = [];
      Core.fishSchools(fish.fish).forEach((sc) => {
        const kit = Atlas.fishKit(idx, sc.id);
        for (let i = 0; kit && i < sc.count; i++) {
          out.push({ school: sc, kit, i });
        }
      });
      return out;
    } catch (e) {
      return [];
    }
  }

  async function start() {
    const res = await fetch('../data/atlas-99.json');
    state.data = await res.json();
    const choice = chronicle(state.data);
    state.traces = Atlas.place(state.data, choice);
    state.holy = Atlas.holyPoints(state.traces);
    state.drawings = Atlas.placeOwnDrawings();
    state.fish = await loadFish();
    state.bag = loadBag();
    const files = state.drawings.map((d) => d.file);
    state.fish.forEach((f) => {
      if (f.i === 0) {
        files.push(...f.kit.files);
      }
    });
    files.forEach((file) => {
      if (!state.images[file]) {
        const img = new Image();
        img.decoding = 'async';
        img.src = ART + file;
        state.images[file] = img;
      }
    });
    const chronicleEl = document.getElementById('dive-chronicle');
    if (chronicleEl) {
      const o = Atlas.option(state.data, choice);
      chronicleEl.textContent = o ? o.written_ru
        : 'Летопись ещё не записана: прохода на свале нет.';
    }
    const where = params.get('goto');
    if (where) {
      goTo(where);
    }
    bindKeys();
    window.requestAnimationFrame(frame);
  }

  start().catch((e) => {
    messageEl.textContent = 'Погружение не загрузилось.';
    consoleEl.style.opacity = '1';
    throw e;
  });
})();
