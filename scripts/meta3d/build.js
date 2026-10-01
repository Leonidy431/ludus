#!/usr/bin/env node
// Meta 3D generator (CLAUDE.md TABOO 0.32): every SVG and every text
// prompt gets a .glb proxy plus a meta-json in public/vr/models/<kind>/.
//
// The proxies are honest LOD0 placeholders ("lod": "proxy"): an SVG
// becomes a layered relief, a prompt becomes the primitive its "box"
// field names.  A modelled asset later replaces the proxy under the same
// id with "lod": "final".
//
// Usage (from the repo root, after `npm ci` in scripts/meta3d):
//   PW=$(npm root -g)/playwright node scripts/meta3d/build.js [--only svg|prompts]
'use strict';

const fs = require('fs');
const http = require('http');
const path = require('path');
const { chromium } = require(process.env.PW || 'playwright');

const ROOT = path.resolve(__dirname, '../..');
const OUT = path.join(ROOT, 'public/vr/models');
const THREE_DIR = path.join(__dirname, 'node_modules/three');
const PROMPTS = path.join(ROOT, 'docs/PROMPTS_1070_2026-09-29.json');
// Seven sacrament places (docs/SACRAMENTS_VR_SCENES.md): the player is a
// witness, holy objects carry noInteract/noLoot, the microphone is off.
const SCENES = path.join(__dirname, 'sacrament-scenes.json');
const LAKE = path.join(ROOT, 'public/ludus/data/lake-objects-99.json');
const SVG_DIRS = [
  path.join(ROOT, 'SVG'),
  path.join(ROOT, 'public/ludus/art'),
];

// Real-world heights in metres per SVG prefix, so a monk is not the size
// of a chalice.  Gates and attribute icons are wall plaques.
const SVG_HEIGHT = {
  npc: 1.75, loc: 3.0, obj: 0.4, ui: 0.3, gate: 1.2, attr: 0.3,
};

// Icons stay flat boards in a kiot (TABOO 0.32 item 3): an Orthodox
// image is a painted board, never a statue, so no relief depth.
const ICON_RE = /ikon|icon|obraz|киот|икон/i;

// Holy objects are never interactive loot (TABOO 0.2 item 3).
const SACRED_RE = new RegExp(
  'potir|chalice|kadilo|censer|krest|cross|kolokol|bell|evangel|gospel|'
  + 'diskos|antimins|ikon|icon|moshchi|relic|kropilo|'
  + 'потир|дискос|кадил|крест|колокол|евангел|икон|антиминс|мощ|кропил',
  'i');

const TRANSLIT = {
  а: 'a', б: 'b', в: 'v', г: 'g', д: 'd', е: 'e', ё: 'e', ж: 'zh', з: 'z',
  и: 'i', й: 'y', к: 'k', л: 'l', м: 'm', н: 'n', о: 'o', п: 'p', р: 'r',
  с: 's', т: 't', у: 'u', ф: 'f', х: 'kh', ц: 'ts', ч: 'ch', ш: 'sh',
  щ: 'shch', ъ: '', ы: 'y', ь: '', э: 'e', ю: 'yu', я: 'ya',
};

function slug(text) {
  return text.toLowerCase().split('').map((c) => TRANSLIT[c] ?? c).join('')
    .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 48);
}

const PROMPT_KIND = {
  'предмет': 'obj', 'NPC': 'npc', 'локация': 'loc', 'событие': 'event',
  'интерфейс': 'ui', 'звук': 'sound',
};

// The "box" field is short Russian wording such as "капсула 0.25м,
// осмотр только"; the first shape word and the first size decide it.
function parseBox(prompt) {
  const text = (prompt.box || '').toLowerCase();
  const num = text.match(/(\d+(?:[.,]\d+)?)\s*м(?![а-я])/);
  const kind = PROMPT_KIND[prompt.type] || 'obj';
  const byKind = { npc: 1.75, loc: 4, event: 2, ui: 0.4, sound: 0.3 };
  let size = num ? parseFloat(num[1].replace(',', '.')) : (byKind[kind] || 0.3);
  let shape = 'box';
  if (/капсул|capsule/.test(text)) shape = 'capsule';
  else if (/цилиндр|cylinder|свиток|мешок|источник/.test(text)) shape = 'cylinder';
  else if (/сфер|sphere|шар|камень/.test(text)) shape = 'sphere';
  else if (/тор|круг|кольц/.test(text)) shape = 'torus';
  else if (/плоскост|ui|панел|книга|дверь|ворота/.test(text)) shape = 'plane';
  else if (/триггер|зона|навмеш|келья|trigger/.test(text)) shape = 'zone';
  if (kind === 'sound') shape = 'emitter';
  if (kind === 'ui' && shape === 'box') shape = 'plane';
  if (kind === 'event' && shape === 'box' && !num) shape = 'zone';
  if (kind === 'npc' && shape === 'box' && !num) shape = 'capsule';
  if (ICON_RE.test(prompt.name)) shape = 'plane';
  // Guard against wording like "0.02м" for a room-sized zone.
  size = Math.min(Math.max(size, 0.05), 30);
  return { kind, shape, size };
}

const COLOR = {
  obj: '#c8a56a', npc: '#8a6a34', loc: '#2a1808', event: '#e8c87a',
  ui: '#e8d9b8', sound: '#5a8ab0',
};

function serve() {
  const page = '<!doctype html><meta charset="utf-8"><script type="importmap">'
    + '{"imports":{"three":"/three/build/three.module.js",'
    + '"three/addons/":"/three/examples/jsm/"}}</script>'
    + '<script type="module" src="/page.js"></script>';
  const server = http.createServer((req, res) => {
    const url = decodeURIComponent(req.url.split('?')[0]);
    let file = null;
    if (url === '/') {
      res.writeHead(200, { 'content-type': 'text/html' });
      res.end(page);
      return;
    }
    if (url === '/page.js') file = path.join(__dirname, 'page.js');
    else if (url.startsWith('/three/')) {
      file = path.join(THREE_DIR, url.slice(7));
    }
    if (!file || !file.startsWith(__dirname) || !fs.existsSync(file)) {
      res.writeHead(404);
      res.end();
      return;
    }
    res.writeHead(200, { 'content-type': 'text/javascript' });
    fs.createReadStream(file).pipe(res);
  });
  return new Promise((ok) => server.listen(0, '127.0.0.1',
    () => ok(server)));
}

function write(kind, id, result, meta) {
  const dir = path.join(OUT, kind);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, `${id}.glb`),
    Buffer.from(result.glb, 'base64'));
  fs.writeFileSync(path.join(dir, `${id}.json`), JSON.stringify({
    id, kind, lod: 'proxy', tris: result.tris, bbox_m: result.bbox,
    ...meta,
  }, null, 1) + '\n');
}

function svgJobs() {
  const seen = new Set();
  const jobs = [];
  SVG_DIRS.forEach((dir) => {
    const walk = (d) => fs.readdirSync(d, { withFileTypes: true })
      .forEach((e) => {
        const p = path.join(d, e.name);
        if (e.isDirectory() && e.name !== 'derived') walk(p);
        else if (e.name.endsWith('.svg')) {
          const id = e.name.replace(/\.svg$/, '');
          if (!seen.has(id)) {
            seen.add(id);
            jobs.push({ id, file: p });
          }
        }
      });
    walk(dir);
  });
  return jobs;
}

async function main() {
  const only = process.argv.includes('--only')
    ? process.argv[process.argv.indexOf('--only') + 1] : null;
  const server = await serve();
  const browser = await chromium.launch();
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  await page.goto(`http://127.0.0.1:${server.address().port}/`);
  await page.waitForFunction(() => window.meta3dReady === true);
  const report = { svg: 0, prompts: 0, overBudget: [], failed: [] };

  if (!only || only === 'svg') {
    for (const job of svgJobs()) {
      const prefix = job.id.split('-')[0];
      const kind = SVG_HEIGHT[prefix] ? prefix : 'obj';
      const icon = ICON_RE.test(job.id);
      const sacred = SACRED_RE.test(job.id);
      try {
        const res = await page.evaluate(([text, opts]) =>
          window.svgToGlb(text, opts), [fs.readFileSync(job.file, 'utf8'), {
          id: job.id,
          height: SVG_HEIGHT[kind],
          // Icons are boards: almost no relief.  Locations are dioramas.
          layerDepth: icon ? 0.05 : (kind === 'loc' ? 1.2 : 0.6),
          keepBackground: kind === 'loc' || icon,
          userData: { noInteract: icon, noLoot: sacred || icon },
        }]);
        write(kind, job.id, res, {
          source: path.relative(ROOT, job.file),
          method: icon ? 'flat-board' : 'layered-svg-extrusion',
          collider: kind === 'loc' ? 'none (scene backdrop)'
            : 'convex hull of the alpha silhouette',
          noInteract: icon, noLoot: sacred || icon,
        });
        report.svg += 1;
        if (res.overBudget) report.overBudget.push(job.id);
      } catch (e) {
        report.failed.push(`${job.id}: ${e.message.split('\n')[0]}`);
      }
    }
  }

  if (!only || only === 'prompts') {
    const prompts = JSON.parse(fs.readFileSync(PROMPTS, 'utf8'));
    const used = new Set();
    for (const [i, prompt] of prompts.entries()) {
      const box = parseBox(prompt);
      let id = `p${String(i + 1).padStart(4, '0')}-${slug(prompt.name)}`;
      while (used.has(id)) id += '-x';
      used.add(id);
      const sacred = SACRED_RE.test(prompt.name);
      const icon = ICON_RE.test(prompt.name);
      try {
        const res = await page.evaluate((spec) => window.boxToGlb(spec), {
          id, shape: box.shape, size: box.size,
          color: COLOR[box.kind],
          // Triggers, zones and emitters are editor volumes, so they are
          // drawn translucent and hidden in the built scene.
          opacity: ['zone', 'emitter'].includes(box.shape) ? 0.25 : 1,
          userData: { noInteract: icon, noLoot: sacred || icon },
        });
        write(box.kind, id, res, {
          source: `docs/PROMPTS_1070_2026-09-29.json#${i}`,
          name: prompt.name, type: prompt.type, storyline: prompt.storyline,
          box: prompt.box, shape: box.shape, size_m: box.size,
          method: 'primitive-from-box-field',
          collider: ['zone', 'emitter'].includes(box.shape)
            ? 'trigger volume' : `${box.shape} ${box.size} m`,
          hiddenInBuild: ['zone', 'emitter'].includes(box.shape),
          noInteract: icon, noLoot: sacred || icon,
        });
        report.prompts += 1;
      } catch (e) {
        report.failed.push(`${id}: ${e.message.split('\n')[0]}`);
      }
    }
  }

  if (only === 'scenes' || !only) {
    report.scenes = 0;
    const scenes = JSON.parse(fs.readFileSync(SCENES, 'utf8'));
    for (const scene of scenes) {
      try {
        const res = await page.evaluate((spec) => window.sceneToGlb(spec),
          { id: scene.id, parts: scene.parts, lights: scene.lights,
            userData: { microphone: false, logPresence: false } });
        const { parts, lights, ...meta } = scene;
        write('scene', scene.id, res, {
          ...meta,
          source: 'scripts/meta3d/sacrament-scenes.json',
          method: 'scene-kit-primitives',
          holyObjects: parts.filter((x) => x.flags && x.flags.holy)
            .map((x) => x.name),
          lights: lights.map((l) => l.name),
        });
        report.scenes += 1;
      } catch (e) {
        report.failed.push(`${scene.id}: ${e.message.split('\n')[0]}`);
      }
    }
  }

  // The 99 objects of Issyk-Kul are drawn in detail by
  // scripts/meta3d/lake_details.py (fins, barbels, the millstone's eye,
  // the net's floats).  The old box kit below is kept only on request
  // (--only lake-boxes), so a full run no longer overwrites them.
  if (only === 'lake-boxes') {
    report.lake = 0;
    const lake = JSON.parse(fs.readFileSync(LAKE, 'utf8')).objects;
    for (const obj of lake) {
      const id = `lake-${obj.id.replace(/\./g, '-')}`;
      try {
        const res = await page.evaluate((spec) => window.sceneToGlb(spec),
          { id, parts: obj.parts, lights: [],
            userData: { ...obj.flags, category: obj.category } });
        write('lake', id, res, {
          name: obj.ru, category: obj.category, band: obj.band,
          depth_m: obj.depth, flags: obj.flags,
          source: 'public/ludus/data/lake-objects-99.json',
          method: 'lake-kit-primitives',
        });
        report.lake += 1;
      } catch (e) {
        report.failed.push(`${id}: ${e.message.split('\n')[0]}`);
      }
    }
  }

  report.pageErrors = errors;
  fs.mkdirSync(OUT, { recursive: true });
  // A partial run (--only) writes its own report, so the full report is
  // never overwritten with zeros for the parts that were not rebuilt.
  fs.writeFileSync(path.join(OUT, only ? `report-${only}.json`
    : 'report.json'),
    JSON.stringify(report, null, 1) + '\n');
  console.log(JSON.stringify({ ...report,
    overBudget: report.overBudget.length, failed: report.failed.length }));
  await browser.close();
  server.close();
  if (report.failed.length) process.exitCode = 1;
}

main();
