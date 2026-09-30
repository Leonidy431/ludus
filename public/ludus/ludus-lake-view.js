/**
 * Ludus: what the ROV sees — a 360-degree view of Issyk-Kul above the
 * telemetry (operator 2026-09-30: "above, the video window of what we
 * see in the lake; in the headset it is 360 degrees; the desert of the
 * shelf, sometimes we find objects and see the fish of Issyk-Kul").
 *
 * The view is drawn, not filmed, and nothing in it is random:
 *   - the whole 360-degree panorama (equirectangular, 2048 x 512) is a
 *     function of depth and time; the same depth always shows the same
 *     shelf, stones, finds and fish (seeded by depth band, TABOO 0.35
 *     rule 15);
 *   - water colour and light follow the physics in ludus-water.js: red
 *     fades first, then green (Beer-Lambert over clear water);
 *   - fish are the species that live in the lake, each only within its
 *     depth range (data/issyk-kul-fish.json); finds are neutral things
 *     of drowned settlements (a grinding stone, a pile, a seal, a jug);
 *     nothing holy is ever a find (TABOO 0.35 rule 6);
 *   - seeing is observation, not a catch: nothing is counted or paid.
 * On the web a window shows 90 degrees of the panorama, turned by the
 * ROV's heading or by dragging; in the headset the same panorama is the
 * texture of the sphere around the viewer (panorama() returns it).
 * Reduced motion: the fish stand still.
 */

'use strict';

(function (root) {
  const PANO_W = 2048;
  const PANO_H = 512;
  const FOV_DEG = 90;

  function hash(text) {
    let h = 2166136261;
    for (let i = 0; i < text.length; i++) {
      h ^= text.charCodeAt(i);
      h = Math.imul(h, 16777619);
    }
    return h >>> 0;
  }

  // mulberry32: a small deterministic generator for a given seed.
  function rng(seed) {
    let a = seed >>> 0;
    return function () {
      a = (a + 0x6D2B79F5) >>> 0;
      let t = a;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  /**
   * What lives and lies around the ROV at this depth: pure, so tests
   * can check it.  Returns {fish: [{id, azimuth, height, count, speed}],
   * finds: [{id, azimuth}], stones: [...]}.
   */
  function scene(depth, data) {
    const band = Math.max(0, Math.floor(depth / 5));
    const r = rng(hash(`issyk-kul:${band}`));
    const fish = [];
    (data.fish || []).forEach((f) => {
      if (depth < f.depth[0] || depth > f.depth[1]) {
        return;
      }
      // Two chances in three that a species is in view at this band.
      if (r() < 0.34) {
        return;
      }
      fish.push({
        id: f.id,
        azimuth: r() * 360,
        height: f.bottom ? 0.86 + r() * 0.05 : 0.35 + r() * 0.4,
        count: Math.max(1, Math.round(f.school * (0.6 + r() * 0.8))),
        speed: (r() < 0.5 ? -1 : 1) * (2 + r() * 4),
      });
    });
    const finds = [];
    (data.finds || []).forEach((f) => {
      if (depth >= f.depth[0] && depth <= f.depth[1] && r() < 0.35) {
        finds.push({ id: f.id, azimuth: r() * 360 });
      }
    });
    const stones = [];
    for (let i = 0; i < 40; i++) {
      stones.push({ azimuth: r() * 360, size: 4 + r() * 14, y: r() });
    }
    // The 99 objects of the lake (scripts/lake/lake_objects.py), except
    // fish, which come from the species list above.  At most one state
    // of an item at a time, each in its depth range.
    const objects = [];
    const seenItems = new Set();
    (data.objects || []).forEach((o) => {
      if (o.category === 'fish' || depth < o.depth[0] || depth > o.depth[1]
          || seenItems.has(o.item)) {
        return;
      }
      seenItems.add(o.item);
      if (r() < 0.55) {
        objects.push({ id: o.id, azimuth: r() * 360, y: r() });
      }
    });
    return { band, fish, finds, stones, objects };
  }

  function waterColour(depth, water) {
    const left = water ? water.lightLeft(depth)
      : { red: Math.exp(-0.34 * depth), green: Math.exp(-0.057 * depth),
        blue: Math.exp(-0.009 * depth) };
    // Surface light scattered by clear water, dimmed band by band.
    const k = 1 / (1 + depth / 60);
    return {
      r: Math.round(40 * left.red * k + 4),
      g: Math.round(150 * left.green * k + 8),
      b: Math.round(190 * left.blue * k + 14),
    };
  }

  function drawFish(ctx, x, y, len, colour, dir) {
    ctx.save();
    ctx.translate(x, y);
    ctx.scale(dir, 1);
    ctx.fillStyle = colour;
    ctx.beginPath();
    ctx.ellipse(0, 0, len, len * 0.32, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.moveTo(-len * 0.9, 0);
    ctx.lineTo(-len * 1.45, -len * 0.35);
    ctx.lineTo(-len * 1.45, len * 0.35);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = 'rgba(10,20,25,0.8)';
    ctx.beginPath();
    ctx.arc(len * 0.6, -len * 0.06, Math.max(1, len * 0.07), 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  // Stroke n lines of m points each; point(i, k) gives the k-th point of
  // line i.  The style of the seiche current: thin, half-transparent.
  function flowLines(ctx, n, m, point) {
    ctx.globalAlpha = 0.7;
    ctx.lineWidth = 2;
    for (let i = 0; i < n; i++) {
      ctx.beginPath();
      for (let k = 0; k < m; k++) {
        const [px, py] = point(i, k);
        k ? ctx.lineTo(px, py) : ctx.moveTo(px, py);
      }
      ctx.stroke();
    }
  }

  // One simple drawing per shape family; colours come from the data.
  function drawObject(ctx, o, x, floorY, t) {
    const c = o.colour;
    // Small things are drawn at least 28 px wide, or they vanish in the
    // 90-degree window (the first test showed a caption of six objects
    // over an almost empty floor).
    const s = Math.max(28, Math.min(160, o.size_m * 70));
    const y = floorY + 10;
    ctx.save();
    ctx.fillStyle = c;
    ctx.strokeStyle = c;
    switch (o.shape) {
      case 'boulder': case 'outcrop':
        ctx.beginPath();
        ctx.ellipse(x, y + s * 0.2, s * 0.6, s * 0.35, 0, Math.PI, 0);
        ctx.fill();
        break;
      case 'jar': case 'bottle':
        ctx.beginPath();
        ctx.ellipse(x, y, s * 0.3, s * 0.45, 0.4, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillRect(x - s * 0.08, y - s * 0.6, s * 0.16, s * 0.25);
        break;
      case 'disc': case 'ring':
        ctx.lineWidth = Math.max(2, s * 0.12);
        ctx.beginPath();
        ctx.ellipse(x, y + 6, s * 0.4, s * 0.14, 0, 0, Math.PI * 2);
        o.shape === 'ring' ? ctx.stroke() : ctx.fill();
        break;
      case 'slab': case 'brick': case 'sinker': case 'anchor': case 'shard':
      case 'shell': case 'sherds':
        for (let i = 0; i < (o.shape === 'sherds' ? 6 : 1); i++) {
          ctx.fillRect(x + i * 9 - 20 * (o.shape === 'sherds'),
            y + (i % 3) * 5, s * 0.5, s * 0.22);
        }
        break;
      case 'pile': case 'stems': case 'reeds': case 'chain': case 'rope':
        ctx.lineWidth = o.shape === 'pile' ? 6 : 2;
        for (let i = 0; i < (o.shape === 'pile' ? 1 : 6); i++) {
          const sway = o.shape === 'pile' ? 0 : 6 * Math.sin(t + i);
          ctx.beginPath();
          ctx.moveTo(x + i * 7, y + 12);
          ctx.quadraticCurveTo(x + i * 7 + sway, y - s, x + i * 7
            + sway * 1.5, y - s * 2.2);
          ctx.stroke();
        }
        break;
      case 'wall': case 'beam': case 'terrace': case 'edge':
        ctx.fillRect(x - s * 1.2, y + 2, s * 2.4, 8);
        break;
      case 'bird':
        ctx.beginPath();
        ctx.ellipse(x, floorY * 0.2, 16, 6, 0.2, 0, Math.PI * 2);
        ctx.fill();
        break;
      case 'bubbles':
        ctx.globalAlpha = 0.6;
        for (let i = 0; i < 14; i++) {
          const by = (floorY - ((t * 40 + i * 37) % floorY));
          ctx.beginPath();
          ctx.arc(x + 4 * Math.sin(i + t), by, 2 + (i % 3), 0, Math.PI * 2);
          ctx.stroke();
        }
        break;
      case 'light':
        ctx.globalAlpha = 0.12;
        for (let i = 0; i < 4; i++) {
          ctx.beginPath();
          ctx.moveTo(x + i * 30, 0);
          ctx.lineTo(x + i * 30 + 40, floorY);
          ctx.lineTo(x + i * 30 + 55, floorY);
          ctx.lineTo(x + i * 30 + 10, 0);
          ctx.fill();
        }
        break;
      case 'net':
        ctx.globalAlpha = 0.8;
        ctx.lineWidth = 1;
        for (let i = 0; i <= 8; i++) {
          ctx.beginPath();
          ctx.moveTo(x - s + i * s / 4, y - s * 0.6);
          ctx.lineTo(x - s + i * s / 4 + 10, y + 14);
          ctx.moveTo(x - s, y - s * 0.6 + i * (s * 0.6 + 14) / 8);
          ctx.lineTo(x + s, y - s * 0.6 + i * (s * 0.6 + 14) / 8);
          ctx.stroke();
        }
        break;
      case 'swarm': case 'particles': case 'shells': case 'gravel':
        for (let i = 0; i < 26; i++) {
          const px = x + ((i * 53) % 90) - 45 + 3 * Math.sin(t * 2 + i);
          const py = y + ((i * 31) % 22) - 6;
          ctx.beginPath();
          ctx.ellipse(px, py, o.shape === 'gravel' ? 5 : 3, 2.2, i, 0,
            Math.PI * 2);
          ctx.fill();
        }
        break;
      case 'seep': case 'current':
        ctx.globalAlpha = 0.7;
        ctx.lineWidth = 2;
        for (let i = 0; i < 5; i++) {
          ctx.beginPath();
          for (let k = 0; k < 12; k++) {
            const px = o.shape === 'seep' ? x + i * 8 + 4 * Math.sin(k + t * 3)
              : x - s + k * s / 6;
            const py = o.shape === 'seep' ? y + 10 - k * 9
              : y - 40 - i * 10 + 4 * Math.sin(k + t * 2);
            k ? ctx.lineTo(px, py) : ctx.moveTo(px, py);
          }
          ctx.stroke();
        }
        break;
      // The water's motion in the manner of the seiche current, which
      // the operator liked (2026-09-30: "такого больше"): moving lines
      // that trace the flow, each after its own physics.
      case 'eddy':
        // A Karman vortex street: pairs of whirls shed behind an
        // obstacle, alternating sides and drifting downstream.
        flowLines(ctx, 5, 14, (i, k) => {
          const cx = x - s + i * s * 0.5 + ((t * 20) % (s * 0.5));
          const cy = y - 30 + (i % 2 ? 14 : -14);
          const a = k / 13 * Math.PI * 2 * (i % 2 ? 1 : -1) + t * 2;
          const r = 4 + k * 1.1;
          return [cx + r * Math.cos(a), cy + r * 0.6 * Math.sin(a)];
        });
        break;
      case 'intwave': case 'layer':
        // An internal wave on the density step: long, slow and tall,
        // because the layers differ little in weight.
        flowLines(ctx, 4, 16, (i, k) => [x - 200 + k * 26,
          floorY * 0.45 + i * 6 + 14 * Math.sin(k * 0.45 - t * 0.6 + i * 0.3)]);
        break;
      case 'plume':
        // Cold, muddy river water slides under the lake as a fan.
        flowLines(ctx, 6, 12, (i, k) => [x - s + k * s / 6,
          y - 10 + (i - 2.5) * (2 + k * 1.6) + 3 * Math.sin(k + t * 2 + i)]);
        break;
      case 'langmuir':
        // Wind rolls the surface into parallel cells; lines of foam and
        // plankton gather where the rolls meet.
        flowLines(ctx, 5, 10, (i, k) => [x - s + i * s * 0.45
          + 3 * Math.sin(k + t * 1.5), 6 + k * 7]);
        break;
      case 'upwelling':
        // Deep water rising at the edge of the drop, spreading as it
        // meets lighter water above.
        flowLines(ctx, 5, 12, (i, k) => [x + (i - 2) * (6 + k * 3)
          + 3 * Math.sin(k + t * 2), y + 10 - k * 8]);
        break;
      case 'ripples': case 'silt': case 'cloud':
        // Sand ripples, a trail of silt and a drifting cloud: all read
        // as lines shaped by the same slow current.
        flowLines(ctx, o.shape === 'cloud' ? 6 : 4, 12, (i, k) => [
          x - s * 0.9 + k * s * 0.15,
          (o.shape === 'cloud' ? y - 30 : y + 4) + i * 5
          + (o.shape === 'ripples' ? 3 * Math.sin(k * 1.6)
            : 4 * Math.sin(k * 0.8 + t * 1.2 + i))]);
        break;
      default:
        // Fields and clouds: a patch on or near the floor, outlined.
        ctx.globalAlpha = 0.55;
        ctx.beginPath();
        ctx.ellipse(x, y + 8, s * 0.9, 12, 0, 0, Math.PI * 2);
        ctx.fill();
        ctx.globalAlpha = 0.9;
        ctx.stroke();
    }
    ctx.restore();
  }

  /**
   * Draw the full 360-degree panorama for a depth at time t (seconds).
   * images: {findId: HTMLImageElement} for finds already loaded.
   */
  function drawPanorama(ctx, depth, t, data, images, water) {
    const c = waterColour(depth, water);
    const grad = ctx.createLinearGradient(0, 0, 0, PANO_H);
    grad.addColorStop(0, `rgb(${c.r * 1.6 | 0},${c.g * 1.4 | 0},`
      + `${c.b * 1.3 | 0})`);
    grad.addColorStop(0.7, `rgb(${c.r},${c.g},${c.b})`);
    grad.addColorStop(1, `rgb(${c.r * 0.6 | 0},${c.g * 0.6 | 0},`
      + `${c.b * 0.6 | 0})`);
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, PANO_W, PANO_H);

    const s = scene(depth, data);
    const floorY = PANO_H * 0.78;
    // The shelf: pale sand fading into the water with depth.
    const sandK = Math.exp(-depth / 45);
    ctx.fillStyle = `rgba(${150 + 60 * sandK | 0},${135 + 50 * sandK | 0},`
      + `${95 + 40 * sandK | 0},${0.55 + 0.35 * sandK})`;
    ctx.fillRect(0, floorY, PANO_W, PANO_H - floorY);
    ctx.strokeStyle = `rgba(255,255,230,${0.08 + 0.1 * sandK})`;
    for (let row = 0; row < 6; row++) {
      ctx.beginPath();
      const y0 = floorY + 10 + row * 16;
      for (let x = 0; x <= PANO_W; x += 16) {
        ctx.lineTo(x, y0 + 3 * Math.sin(x / 37 + row));
      }
      ctx.stroke();
    }
    s.stones.forEach((st) => {
      const x = st.azimuth / 360 * PANO_W;
      const y = floorY + 8 + st.y * (PANO_H - floorY - 16);
      ctx.fillStyle = 'rgba(70,65,55,0.55)';
      ctx.beginPath();
      ctx.ellipse(x, y, st.size, st.size * 0.45, 0, 0, Math.PI * 2);
      ctx.fill();
    });
    s.finds.forEach((f) => {
      const img = images && images[f.id];
      const x = f.azimuth / 360 * PANO_W;
      if (img && img.complete && img.naturalWidth) {
        ctx.globalAlpha = 0.85;
        ctx.drawImage(img, x - 28, floorY + 14, 56, 56);
        ctx.globalAlpha = 1;
      }
    });
    const objById = {};
    (data.objects || []).forEach((o) => { objById[o.id] = o; });
    s.objects.forEach((o) => {
      drawObject(ctx, objById[o.id], o.azimuth / 360 * PANO_W, floorY, t);
    });
    // Marine snow: fixed flakes drifting down slowly.
    const snow = rng(hash(`snow:${s.band}`));
    ctx.fillStyle = 'rgba(230,240,240,0.25)';
    for (let i = 0; i < 160; i++) {
      const x = snow() * PANO_W;
      const y = (snow() * PANO_H + t * 4) % floorY;
      ctx.fillRect(x, y, 1.5, 1.5);
    }
    const byId = {};
    (data.fish || []).forEach((f) => { byId[f.id] = f; });
    s.fish.forEach((f, k) => {
      const spec = byId[f.id];
      const len = 8 + spec.length * 40;
      for (let i = 0; i < f.count; i++) {
        const az = (f.azimuth + f.speed * t + i * 3.1 + 360 * 4) % 360;
        const x = az / 360 * PANO_W;
        const y = f.height * PANO_H + ((i * 37 + k * 11) % 23) - 11
          + 3 * Math.sin(t * 1.3 + i);
        drawFish(ctx, x, y, len, spec.colour, Math.sign(f.speed));
      }
    });
    return s;
  }

  /** A canvas with the whole panorama (the headset's sphere texture). */
  function panorama(depth, t, data, images, water) {
    const cv = root.document.createElement('canvas');
    cv.width = PANO_W;
    cv.height = PANO_H;
    drawPanorama(cv.getContext('2d'), depth, t, data, images, water);
    return cv;
  }

  /** Names of what is inside the window centred on a heading. */
  function inView(s, heading, data) {
    const half = FOV_DEG / 2;
    const near = (az) => {
      const d = Math.abs(((az - heading + 540) % 360) - 180);
      return d <= half;
    };
    const fish = s.fish.filter((f) => near(f.azimuth))
      .map((f) => (data.fish.find((x) => x.id === f.id) || {}));
    const finds = s.finds.filter((f) => near(f.azimuth))
      .map((f) => (data.finds.find((x) => x.id === f.id) || {}));
    const objects = (s.objects || []).filter((o) => near(o.azimuth))
      .map((o) => ((data.objects || []).find((x) => x.id === o.id) || {}));
    return { fish, finds, objects };
  }

  const api = { scene, inView, waterColour, drawPanorama, panorama, drawObject,
    PANO_W, PANO_H, FOV_DEG };
  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  }
  if (!root || !root.document) {
    return;
  }
  root.LudusLakeView = api;

  // ── Browser: the window above the telemetry. ──
  const view = { depth: 5, heading: 0, drag: null, data: null,
    images: {}, pano: null, panoCtx: null, win: null, caption: null,
    raf: 0, lastScene: null };

  async function loadData() {
    if (view.data) {
      return view.data;
    }
    const res = await fetch('/ludus/data/issyk-kul-fish.json');
    view.data = res.ok ? await res.json() : { fish: [], finds: [] };
    const more = await fetch('/ludus/data/lake-objects-99.json');
    view.data.objects = more.ok ? (await more.json()).objects : [];
    view.data.finds.forEach((f) => {
      const img = new root.Image();
      img.src = f.art;
      view.images[f.id] = img;
    });
    return view.data;
  }

  function frame(time) {
    view.raf = 0;
    if (!view.win || !view.data) {
      return;
    }
    const still = root.matchMedia
      && root.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const t = still ? 0 : time / 1000;
    view.lastScene = drawPanorama(view.panoCtx, view.depth, t, view.data,
      view.images, root.LudusWater);
    const ctx = view.win.getContext('2d');
    const w = view.win.width;
    const h = view.win.height;
    const srcW = PANO_W * FOV_DEG / 360;
    let sx = ((view.heading - FOV_DEG / 2) / 360 * PANO_W + PANO_W)
      % PANO_W;
    const first = Math.min(srcW, PANO_W - sx);
    ctx.drawImage(view.pano, sx, 0, first, PANO_H, 0, 0,
      w * first / srcW, h);
    if (first < srcW) {
      ctx.drawImage(view.pano, 0, 0, srcW - first, PANO_H,
        w * first / srcW, 0, w * (srcW - first) / srcW, h);
    }
    const seen = inView(view.lastScene, view.heading, view.data);
    const names = seen.fish.map((f) => f.ru)
      .concat(seen.finds.map((f) => `находка: ${f.ru}`))
      .concat(seen.objects.map((o) => o.ru));
    view.caption.textContent = `${Math.round(view.heading)}° · `
      + `${view.depth.toFixed(1)} м · `
      + (names.length ? names.join(', ') : 'песок шельфа');
    if (!still && !root.document.hidden) {
      view.raf = root.requestAnimationFrame(frame);
    }
  }

  function schedule() {
    if (!view.raf) {
      view.raf = root.requestAnimationFrame(frame);
    }
  }

  /** Build the window inside a container, once. */
  function mount(container) {
    if (view.win && container.contains(view.win)) {
      return;
    }
    const box = root.document.createElement('div');
    box.className = 'rov-lake-view';
    const win = root.document.createElement('canvas');
    win.width = 960;
    win.height = 540;
    win.className = 'rov-lake-view-window';
    win.setAttribute('role', 'img');
    win.setAttribute('aria-label',
      'View from the ROV: 360 degrees, drag to turn');
    const caption = root.document.createElement('p');
    caption.className = 'rov-lake-view-caption';
    caption.setAttribute('aria-live', 'polite');
    box.append(win, caption);
    container.prepend(box);
    view.win = win;
    view.caption = caption;
    view.pano = root.document.createElement('canvas');
    view.pano.width = PANO_W;
    view.pano.height = PANO_H;
    view.panoCtx = view.pano.getContext('2d');
    win.addEventListener('pointerdown', (e) => {
      view.drag = { x: e.clientX, heading: view.heading };
      win.setPointerCapture(e.pointerId);
    });
    win.addEventListener('pointermove', (e) => {
      if (!view.drag) {
        return;
      }
      const deg = (e.clientX - view.drag.x) / win.clientWidth * FOV_DEG;
      view.heading = (view.drag.heading - deg + 360) % 360;
      schedule();
    });
    win.addEventListener('pointerup', () => { view.drag = null; });
    loadData().then(schedule);
  }

  /** Telemetry drives depth and, when the pilot is not dragging, heading. */
  function update(telemetry) {
    if (!telemetry) {
      return;
    }
    if (Number.isFinite(telemetry.depth)) {
      view.depth = Math.max(0, telemetry.depth);
    }
    if (Number.isFinite(telemetry.heading) && !view.drag) {
      view.heading = ((telemetry.heading % 360) + 360) % 360;
    }
    schedule();
  }

  api.mount = mount;
  api.update = update;
  api._view = view;
})(typeof window !== 'undefined' ? window : null);
