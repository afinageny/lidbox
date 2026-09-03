import { unzipSync, zipSync } from "fflate";
import { b64urlToBytes, bytesToB64url, decodeText, encodeText, isZip } from "./base64";
import { parseLiteral, type Vars } from "./customizer";

const MAX_UNCOMPRESSED = 16 * 1024 * 1024;

export type Project = {
  files: Record<string, Uint8Array>;
  main: string;
  vars?: Vars;
  error?: string;
};

export function defaultProject(scad: string, name = "lidbox.scad"): Project {
  return { files: { [name]: encodeText(scad) }, main: name };
}

export function readUrlParams(): URLSearchParams {
  const merged = new URLSearchParams(window.location.search);
  const rawHash = window.location.hash.replace(/^#/, "");
  if (rawHash.includes("=")) {
    const hashParams = new URLSearchParams(rawHash);
    for (const [key, value] of hashParams) merged.set(key, value);
  }
  return merged;
}

export function requestedCatalogFile(params: URLSearchParams = readUrlParams()): string | null {
  const raw = params.get("file") ?? params.get("model");
  if (!raw) return null;
  const base = raw.replace(/\\/g, "/").split("/").pop() ?? "";
  if (!base) return null;
  return base.toLowerCase().endsWith(".scad") ? base : `${base}.scad`;
}

export function pickCatalogFile(
  catalog: Record<string, string>,
  requested?: string | null
): { name: string; source: string } | null {
  if (!requested) return null;
  const want = requested.toLowerCase();
  const name = Object.keys(catalog).find((key) => key.toLowerCase() === want);
  if (!name) return null;
  return { name, source: catalog[name] };
}

export function catalogFileUrl(name: string, vars: Vars = {}): string {
  const url = new URL(window.location.href);
  url.search = "";
  url.hash = "";
  url.searchParams.set("file", name);
  for (const [key, value] of Object.entries(vars)) {
    url.searchParams.set(`d.${key}`, String(value));
  }
  return url.toString();
}

export function syncProjectUrl(
  files: Record<string, Uint8Array>,
  main: string,
  vars: Vars,
  catalog: Record<string, string>
): boolean {
  if (isSingleScad(files) && catalog[main] === fileText(files, main)) {
    const next = new URL(catalogFileUrl(main, vars));
    if (location.pathname === next.pathname && location.search === next.search && location.hash === next.hash) {
      return true;
    }
    history.replaceState(null, "", next);
    return true;
  }
  return replaceShareUrl(files, main, vars);
}

export function readVarsFromParams(params: URLSearchParams = readUrlParams()): Vars {
  const vars: Vars = {};
  for (const [key, value] of params) {
    if (!key.startsWith("d.")) continue;
    const name = key.slice(2);
    if (!name) continue;
    vars[name] = parseLiteral(value).value;
  }
  return vars;
}

export function loadProjectFromUrl(): Project | null {
  const params = readUrlParams();
  const vars = readVarsFromParams(params);
  const payload = params.get("zip") ?? params.get("scad") ?? params.get("src");
  if (!payload) return null;
  try {
    const bytes = b64urlToBytes(payload);
    if (params.has("zip") || isZip(bytes)) {
      const files = unzipProject(bytes);
      return { files, main: pickMain(files, params.get("main")), vars };
    }
    const path = sanitizeName(params.get("name")) ?? "main.scad";
    return { files: { [path]: bytes }, main: path, vars };
  } catch (err) {
    return {
      files: {},
      main: "main.scad",
      vars,
      error: err instanceof Error ? err.message : String(err),
    };
  }
}

export function unzipProject(bytes: Uint8Array): Record<string, Uint8Array> {
  const entries = unzipSync(bytes);
  const files: Record<string, Uint8Array> = {};
  let total = 0;
  for (const [raw, data] of Object.entries(entries)) {
    const path = raw.replace(/\\/g, "/");
    if (!path || path.endsWith("/") || path.split("/").includes("..")) continue;
    total += data.length;
    if (total > MAX_UNCOMPRESSED) throw new Error("Archive is too large");
    files[path] = data;
  }
  if (!Object.keys(files).length) throw new Error("Archive is empty");
  return stripCommonRoot(files);
}

export function pickMain(files: Record<string, Uint8Array>, requested?: string | null): string {
  const scads = Object.keys(files).filter((p) => p.toLowerCase().endsWith(".scad"));
  if (requested) {
    const hit = scads.find(
      (p) => p === requested || p.endsWith(`/${requested}`) || p.toLowerCase() === requested.toLowerCase()
    );
    if (!hit) throw new Error(`Archive has no ${requested}`);
    return hit;
  }
  const preferred =
    scads.find((p) => /(^|\/)main\.scad$/i.test(p)) ??
    scads.find((p) => !p.includes("/")) ??
    scads[0];
  if (!preferred) throw new Error("No .scad file in the data");
  return preferred;
}

export const MAX_SHARE_URL = 120000;

export function isSingleScad(files: Record<string, Uint8Array>): boolean {
  const names = Object.keys(files);
  return names.length === 1 && names[0].toLowerCase().endsWith(".scad");
}

export function shareUrl(files: Record<string, Uint8Array>, main: string, vars: Vars = {}): string {
  const url = new URL(window.location.href);
  url.search = "";
  url.hash = projectToHash(files, main, vars);
  return url.toString();
}

/** Keep the address bar in sync for a single .scad. Returns false if skipped (zip / too long). */
export function replaceShareUrl(
  files: Record<string, Uint8Array>,
  main: string,
  vars: Vars = {}
): boolean {
  if (!isSingleScad(files)) return false;
  const url = shareUrl(files, main, vars);
  if (url.length > MAX_SHARE_URL) return false;
  const next = new URL(url);
  if (location.pathname === next.pathname && location.search === next.search && location.hash === next.hash) {
    return true;
  }
  history.replaceState(null, "", next);
  return true;
}

export function clearShareUrl() {
  const url = new URL(window.location.href);
  url.search = "";
  url.hash = "";
  if (location.search === "" && location.hash === "") return;
  history.replaceState(null, "", url);
}

export function projectToHash(files: Record<string, Uint8Array>, main: string, vars: Vars = {}): string {
  const names = Object.keys(files);
  const query = new URLSearchParams();
  const single = names.length === 1 ? names[0] : null;
  if (single && single.toLowerCase().endsWith(".scad")) {
    query.set("scad", bytesToB64url(files[single]));
    if (single !== "main.scad") query.set("name", single.split("/").pop()!);
  } else {
    query.set("zip", bytesToB64url(zipSync(files, { level: 6 })));
    query.set("main", main);
  }
  for (const [name, value] of Object.entries(vars)) {
    query.set(`d.${name}`, String(value));
  }
  return query.toString();
}

export function scadPaths(files: Record<string, Uint8Array>): string[] {
  return Object.keys(files)
    .filter((p) => p.toLowerCase().endsWith(".scad"))
    .sort();
}

export function fileText(files: Record<string, Uint8Array>, path: string): string {
  const bytes = files[path];
  return bytes ? decodeText(bytes) : "";
}

function stripCommonRoot(files: Record<string, Uint8Array>): Record<string, Uint8Array> {
  const keys = Object.keys(files);
  const first = keys[0]?.split("/")[0];
  if (!first) return files;
  const prefix = `${first}/`;
  if (!keys.some((k) => k.startsWith(prefix))) return files;
  if (!keys.every((k) => k === first || k.startsWith(prefix))) return files;
  const next: Record<string, Uint8Array> = {};
  for (const [key, value] of Object.entries(files)) {
    if (key === first) continue;
    next[key.slice(prefix.length)] = value;
  }
  return next;
}

function sanitizeName(name: string | null): string | null {
  if (!name) return null;
  const base = name.replace(/\\/g, "/").split("/").pop() ?? "";
  if (!/^[\w.-]+$/.test(base)) return "main.scad";
  return base.toLowerCase().endsWith(".scad") ? base : `${base}.scad`;
}

export { encodeText, decodeText };
