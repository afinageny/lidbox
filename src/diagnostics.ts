export type Diag = {
  file: string;
  line: number;
  message: string;
};

const NOISE = /could not initialize localization|application path is/i;

/** OpenSCAD WASM prepends `$preview=...;` before compiling the main file. */
const MAIN_LINE_SHIFT = 1;

export function cleanOpenScadLog(text: string): string {
  return text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line && !NOISE.test(line) && !/^ECHO:/i.test(line))
    .join("\n");
}

export function parseOpenScadDiagnostics(
  text: string,
  mainFile: string,
  knownFiles: string[]
): Diag[] {
  const cleaned = cleanOpenScadLog(text);
  if (!cleaned) return [];
  const diags: Diag[] = [];
  for (const line of cleaned.split("\n")) {
    const match = line.match(/in file\s+'?([^',\s]+)'?, line\s+(\d+)/i);
    if (!match) continue;
    const rawPath = match[1];
    const oscLine = Number(match[2]);
    const file = resolveProjectFile(rawPath, knownFiles) ?? relativeWorkPath(rawPath);
    const isMain = sameFile(file, mainFile);
    const userLine = Math.max(1, oscLine - (isMain ? MAIN_LINE_SHIFT : 0));
    diags.push({
      file,
      line: userLine,
      message: prettyMessage(line),
    });
  }
  if (!diags.length) {
    const msg = prettyMessage(cleaned);
    if (msg) diags.push({ file: mainFile, line: 1, message: msg });
  }
  return dedupe(diags);
}

export function formatDiag(d: Diag): string {
  return `${d.file}:${d.line}: ${d.message}`;
}

export function sameFile(a: string, b: string): boolean {
  const na = normalize(a);
  const nb = normalize(b);
  if (na === nb) return true;
  const ba = na.split("/").pop();
  const bb = nb.split("/").pop();
  return Boolean(ba && bb && ba === bb);
}

function prettyMessage(raw: string): string {
  let msg = cleanOpenScadLog(raw);
  msg = msg.replace(/^ERROR:\s*/i, "");
  const parser = msg.match(/Parser error:\s*([^,\n]+)/i);
  if (parser) return parser[1].replace(/\s+in file\s+.*/i, "").trim();
  msg = msg.replace(/\s+in file\s+.*/i, "").trim();
  msg = msg.replace(/\s*Can't parse file\s+'[^']+'\s*!/i, "").trim();
  return msg || "OpenSCAD error";
}

function relativeWorkPath(file: string): string {
  return file.replace(/\\/g, "/").replace(/^\/work\//, "").replace(/^\//, "");
}

function normalize(file: string): string {
  return relativeWorkPath(file).toLowerCase();
}

function resolveProjectFile(file: string, knownFiles: string[]): string | undefined {
  const rel = relativeWorkPath(file);
  const hit =
    knownFiles.find((k) => k === rel) ??
    knownFiles.find((k) => sameFile(k, rel));
  return hit;
}

function dedupe(diags: Diag[]): Diag[] {
  const seen = new Set<string>();
  return diags.filter((d) => {
    const key = `${d.file}:${d.line}:${d.message}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}
