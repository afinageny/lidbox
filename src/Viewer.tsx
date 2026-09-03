import { useEffect, useRef } from "react";
import * as THREE from "three";
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls.js";
import { STLLoader } from "three/examples/jsm/loaders/STLLoader.js";
import type { Vars } from "./customizer";

const FALLBACK = {
  box: 0xd97757,
  lidUpper: 0x6bcb77,
  lidLower: 0x2f6f4e,
  other: 0x5ea8d8,
};

function hexColor(value: unknown, fallback: number) {
  const m = String(value ?? "")
    .trim()
    .match(/^#?([0-9a-fA-F]{6})$/);
  return m ? parseInt(m[1], 16) : fallback;
}

function partColors(vars: Vars = {}) {
  const box = hexColor(vars.color_box, FALLBACK.box);
  const lidUpper = hexColor(vars.color_lid_upper, FALLBACK.lidUpper);
  const lidLower = hexColor(vars.color_lid_lower, FALLBACK.lidLower);
  return { box, lidUpper, lidLower };
}

function colorFor(part: string, index: number, count: number, vars: Vars = {}) {
  const c = partColors(vars);
  if (count > 1) {
    const seq = [c.box, c.lidUpper, c.lidLower, c.lidUpper, c.lidLower];
    return seq[index] ?? FALLBACK.other;
  }
  if (part.startsWith("lidSandwichTop")) return c.lidUpper;
  if (part.startsWith("lidSandwichBottom")) return c.lidLower;
  return c.box;
}

const SCENE = {
  dark: { bg: 0x1b1e24, grid: 0x3d4450, gridMinor: 0x2a3038 },
  light: { bg: 0xe8eaee, grid: 0xb8bfc9, gridMinor: 0xd0d5dc },
};

function applySceneTheme(
  rec: { scene: THREE.Scene; grid?: THREE.GridHelper },
  theme: "light" | "dark"
) {
  const c = SCENE[theme];
  rec.scene.background = new THREE.Color(c.bg);
  if (!rec.grid) return;
  const mats = rec.grid.material;
  if (Array.isArray(mats)) {
    mats[0]?.color.setHex(c.grid);
    mats[1]?.color.setHex(c.gridMinor);
  } else {
    mats.color.setHex(c.grid);
  }
}

export function Viewer({
  stl,
  parts,
  part = "assembly",
  vars,
  theme = "light",
}: {
  stl: ArrayBuffer | null;
  parts?: ArrayBuffer[] | null;
  part?: string;
  vars?: Vars;
  theme?: "light" | "dark";
}) {
  const host = useRef<HTMLDivElement>(null);
  const ctx = useRef<{
    renderer: THREE.WebGLRenderer;
    scene: THREE.Scene;
    camera: THREE.PerspectiveCamera;
    controls: OrbitControls;
    meshes: THREE.Mesh[];
    grid?: THREE.GridHelper;
    frame: number;
  } | null>(null);
  const themeRef = useRef(theme);
  themeRef.current = theme;

  useEffect(() => {
    const el = host.current;
    if (!el) return;
    const scene = new THREE.Scene();
    const look = SCENE[theme];
    scene.background = new THREE.Color(look.bg);
    const camera = new THREE.PerspectiveCamera(45, 1, 0.1, 5000);
    camera.position.set(180, 140, 220);
    const renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    el.appendChild(renderer.domElement);
    const controls = new OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true;
    scene.add(new THREE.AmbientLight(0xffffff, 0.55));
    const key = new THREE.DirectionalLight(0xffffff, 0.9);
    key.position.set(80, 160, 120);
    scene.add(key);
    scene.add(new THREE.HemisphereLight(0x9ec9ff, 0x334155, 0.35));
    const grid = new THREE.GridHelper(400, 20, look.grid, look.gridMinor);
    scene.add(grid);

    const tick = () => {
      controls.update();
      renderer.render(scene, camera);
      rec.frame = requestAnimationFrame(tick);
    };
    const rec = { renderer, scene, camera, controls, meshes: [] as THREE.Mesh[], grid, frame: 0 };
    ctx.current = rec;
    const resize = () => {
      const w = el.clientWidth || 1;
      const h = el.clientHeight || 1;
      camera.aspect = w / h;
      camera.updateProjectionMatrix();
      renderer.setSize(w, h);
    };
    resize();
    const ro = new ResizeObserver(resize);
    ro.observe(el);
    rec.frame = requestAnimationFrame(tick);
    return () => {
      cancelAnimationFrame(rec.frame);
      ro.disconnect();
      controls.dispose();
      renderer.dispose();
      renderer.domElement.remove();
      ctx.current = null;
    };
  }, []);

  useEffect(() => {
    const rec = ctx.current;
    if (rec) applySceneTheme(rec, theme);
  }, [theme]);

  useEffect(() => {
    const rec = ctx.current;
    const buffers = parts?.length ? parts : stl ? [stl] : [];
    if (!rec || !buffers.length) return;
    for (const mesh of rec.meshes) {
      rec.scene.remove(mesh);
      mesh.geometry.dispose();
      (mesh.material as THREE.Material).dispose();
    }
    rec.meshes = [];

    const loader = new STLLoader();
    const geoms = buffers.map((buf) => {
      const geom = loader.parse(buf);
      geom.computeVertexNormals();
      geom.computeBoundingBox();
      return geom;
    });

    const world = new THREE.Box3();
    for (const g of geoms) world.union(g.boundingBox!);
    const ox = -(world.min.x + world.max.x) / 2;
    const oy = -(world.min.y + world.max.y) / 2;
    const oz = -world.min.z;
    for (const [i, g] of geoms.entries()) {
      g.translate(ox, oy, oz);
      const mat = new THREE.MeshStandardMaterial({
        color: colorFor(part, i, geoms.length, vars),
        metalness: 0.05,
        roughness: 0.45,
      });
      const mesh = new THREE.Mesh(g, mat);
      mesh.rotation.x = -Math.PI / 2;
      rec.scene.add(mesh);
      rec.meshes.push(mesh);
    }

    const size = world.getSize(new THREE.Vector3());
    const span = Math.max(size.x, size.y, 40);
    const height = size.z;
    if (rec.grid) {
      rec.scene.remove(rec.grid);
      rec.grid.geometry.dispose();
      const gmat = rec.grid.material;
      if (Array.isArray(gmat)) gmat.forEach((m) => m.dispose());
      else gmat.dispose();
    }
    const look = SCENE[themeRef.current];
    const gridSize = Math.ceil((span * 2.4) / 20) * 20;
    rec.grid = new THREE.GridHelper(gridSize, 20, look.grid, look.gridMinor);
    rec.scene.add(rec.grid);
    rec.camera.position.set(span * 1.4, height * 0.55 + span * 0.7, span * 1.5);
    rec.controls.target.set(0, height / 2, 0);
    rec.controls.update();
  }, [stl, parts, part, vars]);

  return <div className="viewer" ref={host} />;
}
