// Browser side of the Meta 3D generator (CLAUDE.md TABOO 0.32).
//
// Runs inside Chromium because three.js' GLTFExporter needs a DOM-like
// environment.  Two builders are exposed on window:
//   svgToGlb(svgText, opts)   layered extrusion of an SVG (LOD0 proxy);
//   boxToGlb(spec)            primitive from a prompt's "box" field.
// Both return {glb: base64, tris, bbox} so node can write the files.
import * as THREE from 'three';
import { SVGLoader } from 'three/addons/loaders/SVGLoader.js';
import { GLTFExporter } from 'three/addons/exporters/GLTFExporter.js';

// Quest 3 budget for a proxy (TABOO 0.32 item 4).
const TRI_BUDGET = 5000;

// One material per colour keeps draw calls low on the headset.
const materials = new Map();
function material(color, opacity) {
  const key = `${color}|${opacity}`;
  if (!materials.has(key)) {
    materials.set(key, new THREE.MeshStandardMaterial({
      color: new THREE.Color().setStyle(color || '#8a6a34'),
      roughness: 0.8,
      metalness: 0.05,
      transparent: opacity < 1,
      opacity,
      side: THREE.DoubleSide,
    }));
  }
  return materials.get(key);
}

function countTris(root) {
  let tris = 0;
  root.traverse((o) => {
    if (o.isMesh) {
      const g = o.geometry;
      tris += (g.index ? g.index.count : g.attributes.position.count) / 3;
    }
  });
  return Math.round(tris);
}

async function exportGlb(root) {
  const exporter = new GLTFExporter();
  const buf = await exporter.parseAsync(root, { binary: true });
  const bytes = new Uint8Array(buf);
  let bin = '';
  for (let i = 0; i < bytes.length; i += 0x8000) {
    bin += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
  }
  const box = new THREE.Box3().setFromObject(root);
  const size = box.getSize(new THREE.Vector3());
  return {
    glb: btoa(bin),
    tris: countTris(root),
    bbox: [size.x, size.y, size.z].map((v) => +v.toFixed(3)),
  };
}

// Each SVG element becomes one slab; later elements sit in front, so the
// drawing order of the SVG turns into depth, like a carved relief.
window.svgToGlb = async function svgToGlb(svgText, opts) {
  const data = new SVGLoader().parse(svgText);
  const vb = (data.xml.getAttribute('viewBox') || '0 0 100 100')
    .split(/[\s,]+/).map(Number);
  const [vx, vy, vw, vh] = vb;
  const scale = opts.height / vh;
  // layerDepth is in SVG user units: the root group is scaled to metres
  // once, so a 140-unit NPC with 0.6-unit layers gets 7.5 mm steps.  The
  // first preview spread layers metres apart because depth was divided
  // by the scale here and then scaled again by the root.
  const layer = opts.layerDepth;
  const root = new THREE.Group();
  root.name = opts.id;
  let segments = 6;
  let z = 0;
  data.paths.forEach((path) => {
    const style = path.userData.style;
    // A full-canvas background rectangle is a frame, not the object; a
    // location keeps it as a back plane, other kinds drop it.
    const node = path.userData.node;
    if (node && node.tagName === 'rect'
        && +node.getAttribute('width') >= vw * 0.98
        && +node.getAttribute('height') >= vh * 0.98) {
      if (!opts.keepBackground) {
        return;
      }
    }
    const opacity = (style.fillOpacity ?? 1) * (style.opacity ?? 1);
    if (style.fill && style.fill !== 'none') {
      SVGLoader.createShapes(path).forEach((shape) => {
        const geo = new THREE.ExtrudeGeometry(shape, {
          depth: layer, bevelEnabled: false, curveSegments: segments,
        });
        const mesh = new THREE.Mesh(geo, material(style.fill, opacity));
        mesh.position.z = z;
        root.add(mesh);
      });
    }
    if (style.stroke && style.stroke !== 'none') {
      path.subPaths.forEach((sub) => {
        const pts = sub.getPoints(segments);
        const geo = SVGLoader.pointsToStroke(pts, style);
        if (geo) {
          const mesh = new THREE.Mesh(geo,
            material(style.stroke, style.strokeOpacity ?? 1));
          mesh.position.z = z + layer * 1.05;
          root.add(mesh);
        }
      });
    }
    z += layer;
  });
  // SVG y grows downward; flip and centre so the model stands on y = 0.
  root.scale.set(scale, -scale, scale);
  root.position.set(-(vx + vw / 2) * scale, (vy + vh) * scale, 0);
  const wrap = new THREE.Group();
  wrap.name = opts.id;
  wrap.add(root);
  wrap.userData = opts.userData;
  const out = await exportGlb(wrap);
  out.overBudget = out.tris > TRI_BUDGET;
  return out;
};

// Primitive proxies from the prompt's "box" wording.
window.boxToGlb = async function boxToGlb(spec) {
  const s = spec.size;
  let geo;
  switch (spec.shape) {
    case 'capsule':
      geo = new THREE.CapsuleGeometry(s * 0.25, s * 0.5, 4, 12);
      geo.translate(0, s / 2, 0);
      break;
    case 'cylinder':
      geo = new THREE.CylinderGeometry(s / 2, s / 2, s, 16);
      geo.translate(0, s / 2, 0);
      break;
    case 'sphere':
      geo = new THREE.SphereGeometry(s / 2, 16, 12);
      geo.translate(0, s / 2, 0);
      break;
    case 'torus':
      geo = new THREE.TorusGeometry(s / 2, s / 8, 8, 24);
      geo.rotateX(Math.PI / 2);
      break;
    case 'plane':
      geo = new THREE.BoxGeometry(s, s * 1.33, 0.02);
      geo.translate(0, s * 0.665, 0);
      break;
    case 'zone':
      geo = new THREE.BoxGeometry(s, s * 0.5, s);
      geo.translate(0, s * 0.25, 0);
      break;
    case 'emitter':
      geo = new THREE.IcosahedronGeometry(s / 2, 1);
      geo.translate(0, s / 2, 0);
      break;
    default:
      geo = new THREE.BoxGeometry(s, s, s);
      geo.translate(0, s / 2, 0);
  }
  const mesh = new THREE.Mesh(geo, material(spec.color, spec.opacity));
  mesh.name = spec.id;
  mesh.userData = spec.userData;
  return exportGlb(mesh);
};

window.meta3dReady = true;
