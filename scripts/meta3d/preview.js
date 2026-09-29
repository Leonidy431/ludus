#!/usr/bin/env node
// Render a contact sheet of .glb proxies so a person can check them by
// eye before commit (CLAUDE.md TABOO 0.6: no "done" without a picture).
// Usage: PW=... node scripts/meta3d/preview.js out.png a.glb b.glb ...
'use strict';

const fs = require('fs');
const http = require('http');
const path = require('path');
const { chromium } = require(process.env.PW || 'playwright');

const THREE_DIR = path.join(__dirname, 'node_modules/three');
const [out, ...files] = process.argv.slice(2);

const page = `<!doctype html><meta charset="utf-8">
<body style="margin:0;background:#1b1b22;color:#ddd;font:12px sans-serif">
<div id="g" style="display:grid;grid-template-columns:repeat(6,256px);gap:6px;padding:6px"></div>
<script type="importmap">{"imports":{"three":"/three/build/three.module.js",
"three/addons/":"/three/examples/jsm/"}}</script>
<script type="module">
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
const names = ${JSON.stringify(files.map((f) => path.basename(f)))};
const loader = new GLTFLoader();
for (let i = 0; i < names.length; i++) {
  const gltf = await loader.loadAsync('/m/' + i);
  const scene = new THREE.Scene();
  scene.background = new THREE.Color('#2a2a33');
  scene.add(new THREE.HemisphereLight('#ffffff', '#443322', 2.2));
  const sun = new THREE.DirectionalLight('#ffe8c0', 2.5);
  sun.position.set(2, 3, 4);
  scene.add(sun, gltf.scene);
  const box = new THREE.Box3().setFromObject(gltf.scene);
  const size = box.getSize(new THREE.Vector3()).length() || 1;
  const c = box.getCenter(new THREE.Vector3());
  const cam = new THREE.PerspectiveCamera(35, 1, size / 100, size * 10);
  cam.position.set(c.x + size * 0.9, c.y + size * 0.45, c.z + size * 1.5);
  cam.lookAt(c);
  const r = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
  r.setSize(256, 256);
  r.render(scene, cam);
  const fig = document.createElement('figure');
  fig.style.margin = 0;
  fig.append(r.domElement, Object.assign(document.createElement('figcaption'),
    { textContent: names[i] }));
  document.getElementById('g').append(fig);
}
window.done = true;
</script>`;

const server = http.createServer((req, res) => {
  const url = decodeURIComponent(req.url);
  if (url === '/') {
    res.writeHead(200, { 'content-type': 'text/html' });
    return res.end(page);
  }
  let file = null;
  if (url.startsWith('/m/')) file = files[+url.slice(3)];
  else if (url.startsWith('/three/')) file = path.join(THREE_DIR, url.slice(7));
  if (!file || !fs.existsSync(file)) {
    res.writeHead(404);
    return res.end();
  }
  res.writeHead(200, { 'content-type': url.startsWith('/m/')
    ? 'model/gltf-binary' : 'text/javascript' });
  fs.createReadStream(file).pipe(res);
});

server.listen(0, '127.0.0.1', async () => {
  const browser = await chromium.launch({ args: ['--use-gl=swiftshader',
    '--enable-unsafe-swiftshader'] });
  const p = await browser.newPage({ viewport: { width: 1600, height: 900 } });
  p.on('pageerror', (e) => console.error(String(e)));
  await p.goto(`http://127.0.0.1:${server.address().port}/`);
  await p.waitForFunction(() => window.done === true, null,
    { timeout: 120000 });
  await p.screenshot({ path: out, fullPage: true });
  await browser.close();
  server.close();
  console.log(out, files.length);
});
