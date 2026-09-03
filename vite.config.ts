import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import react from "@vitejs/plugin-react";
import { defineConfig, searchForWorkspaceRoot, type Plugin } from "vite";

const webRoot = path.dirname(fileURLToPath(import.meta.url));
const OPENSCAD_DIR = path.resolve(webRoot, "openscad");
const repoName = process.env.GITHUB_REPOSITORY?.split("/")[1];
const pagesBase = process.env.GITHUB_PAGES === "true" && repoName ? `/${repoName}/` : "/";

function scadName(name: string) {
  const base = path.basename(name.trim());
  return base.toLowerCase().endsWith(".scad") ? base : `${base}.scad`;
}

function listScadFiles() {
  if (!fs.existsSync(OPENSCAD_DIR) || !fs.statSync(OPENSCAD_DIR).isDirectory()) return [];
  return fs
    .readdirSync(OPENSCAD_DIR)
    .filter((name) => name.toLowerCase().endsWith(".scad") && !name.startsWith("."))
    .sort((a, b) => a.localeCompare(b, undefined, { sensitivity: "base" }))
    .map((name) => ({ name, file: path.join(OPENSCAD_DIR, name) }));
}

function resolveScadFile(): string {
  const spec = process.env.SCAD?.trim();
  const listed = listScadFiles();
  const byName = (name: string) =>
    listed.find((item) => item.name.toLowerCase() === scadName(name).toLowerCase());

  if (spec) {
    const named = byName(spec);
    if (named) return named.file;
    const abs = path.isAbsolute(spec) ? spec : path.resolve(process.cwd(), spec);
    if (fs.existsSync(abs) && fs.statSync(abs).isFile()) return path.normalize(abs);
    const names = listed.map((item) => item.name).join(", ") || "(empty)";
    throw new Error(
      `OpenSCAD file not found: ${spec}\nFiles in openscad/: ${names}\nPass a name from openscad/, --scad <file>, or SCAD=`
    );
  }

  const preferred = byName("lidbox.scad") ?? listed[0];
  if (!preferred) {
    throw new Error(`No .scad files in ${OPENSCAD_DIR}`);
  }
  return preferred.file;
}

function scadEntryPlugin(file: string): Plugin {
  const virtualId = "virtual:scad";
  const resolvedId = `\0${virtualId}`;
  const name = path.basename(file);
  return {
    name: "scad-entry",
    configResolved(config) {
      config.logger.info(`OpenSCAD ${file}`);
    },
    resolveId(id) {
      if (id === virtualId) return resolvedId;
    },
    load(id) {
      if (id !== resolvedId) return;
      this.addWatchFile(file);
      const source = fs.readFileSync(file, "utf8");
      return `export const source = ${JSON.stringify(source)};\nexport const name = ${JSON.stringify(name)};\n`;
    },
    configureServer(server) {
      server.watcher.add(file);
    },
    handleHotUpdate({ file: changed, server }) {
      if (path.resolve(changed) !== path.resolve(file)) return;
      server.ws.send({ type: "full-reload" });
      return [];
    },
  };
}

function scadCatalogPlugin(defaultFile: string): Plugin {
  const virtualId = "virtual:scad-catalog";
  const resolvedId = `\0${virtualId}`;
  return {
    name: "scad-catalog",
    resolveId(id) {
      if (id === virtualId) return resolvedId;
    },
    load(id) {
      if (id !== resolvedId) return;
      const files: Record<string, string> = {};
      for (const item of listScadFiles()) {
        this.addWatchFile(item.file);
        files[item.name] = fs.readFileSync(item.file, "utf8");
      }
      const defaultName = path.basename(defaultFile);
      return `export const files = ${JSON.stringify(files)};\nexport const defaultName = ${JSON.stringify(defaultName)};\n`;
    },
    configureServer(server) {
      server.watcher.add(OPENSCAD_DIR);
    },
    handleHotUpdate({ file: changed, server }) {
      const norm = path.resolve(changed);
      if (!norm.startsWith(OPENSCAD_DIR) || !norm.toLowerCase().endsWith(".scad")) return;
      server.ws.send({ type: "full-reload" });
      return [];
    },
  };
}

const scadFile = resolveScadFile();

export default defineConfig({
  base: pagesBase,
  plugins: [react(), scadEntryPlugin(scadFile), scadCatalogPlugin(scadFile)],
  server: {
    port: 5173,
    host: "127.0.0.1",
    fs: {
      allow: [webRoot, searchForWorkspaceRoot(webRoot), OPENSCAD_DIR, path.dirname(scadFile)],
    },
  },
});
