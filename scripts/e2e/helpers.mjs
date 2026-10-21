// Hạ tầng cho test e2e: Postgres schema riêng, backend thật và agent thật chạy
// bằng node, tất cả dọn sạch sau khi chạy. Không đụng dữ liệu hay cổng 8788.
import { spawn } from "node:child_process";
import { createRequire } from "node:module";
import { mkdirSync, writeFileSync } from "node:fs";
import net from "node:net";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
export const BACKEND_DIR = path.join(ROOT, "services", "hnth-backend");
export const AGENT_SCRIPT = path.join(ROOT, "services", "hnth-agent", "src", "agent.mjs");
export const pg = createRequire(path.join(BACKEND_DIR, "package.json"))("pg");

export const DATABASE_URL = process.env.E2E_DATABASE_URL || "postgres://hnth:hnth_local_password@127.0.0.1:5432/hnth";
export const withSearchPath = (url, schema) => `${url}${url.includes("?") ? "&" : "?"}options=${encodeURIComponent(`-c search_path=${schema}`)}`;

export const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/** Poll `check` cho tới khi trả giá trị truthy; ném lỗi kèm mô tả khi hết giờ. */
export async function waitFor(check, { timeout = 20000, interval = 250, message = "condition" } = {}) {
  const deadline = Date.now() + timeout;
  let lastError;
  while (Date.now() < deadline) {
    try { const value = await check(); if (value) return value; } catch (error) { lastError = error; }
    await sleep(interval);
  }
  throw new Error(`Timed out after ${timeout}ms waiting for ${message}${lastError ? `: ${lastError.message}` : ""}`);
}

export function freePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.unref();
    server.on("error", reject);
    server.listen(0, "127.0.0.1", () => { const { port } = server.address(); server.close(() => resolve(port)); });
  });
}

/** Chạy một tiến trình node, gom stdout+stderr để test đọc log. */
export function startNode(script, { env = {}, cwd = ROOT } = {}) {
  const child = spawn(process.execPath, [script], { cwd, env: { ...process.env, ...env }, stdio: ["ignore", "pipe", "pipe"], windowsHide: true });
  let output = "";
  child.stdout.on("data", (chunk) => { output += chunk; });
  child.stderr.on("data", (chunk) => { output += chunk; });
  const exited = new Promise((resolve) => child.on("exit", resolve));
  return {
    child,
    output: () => output,
    async stop() { if (child.exitCode === null && !child.killed) child.kill(); await Promise.race([exited, sleep(5000)]); },
  };
}

/** Gọi API backend; trả { status, body, headers } với body đã parse JSON nếu được. */
export function apiClient(baseUrl) {
  return async function api(method, pathname, { token, body, headers = {}, raw } = {}) {
    const init = { method, headers: { ...headers } };
    if (token) init.headers.authorization = `Bearer ${token}`;
    if (raw !== undefined) init.body = raw;
    else if (body !== undefined) { init.body = JSON.stringify(body); init.headers["content-type"] = "application/json"; }
    const response = await fetch(`${baseUrl}${pathname}`, init);
    const buffer = Buffer.from(await response.arrayBuffer());
    let parsed = buffer;
    try { parsed = JSON.parse(buffer.toString("utf8")); } catch { /* giữ buffer cho file tải về */ }
    return { status: response.status, body: parsed, headers: response.headers };
  };
}

/** Ghi config và chạy agent node thật. */
export function startAgent(dir, config, { version = "0.2.4-e2e" } = {}) {
  mkdirSync(dir, { recursive: true });
  if (config) writeFileSync(path.join(dir, "config.json"), JSON.stringify(config, null, 2));
  return startNode(AGENT_SCRIPT, { env: { HNTH_AGENT_CONFIG: path.join(dir, "config.json"), HNTH_AGENT_VERSION: version } });
}

/** Buffer giả lập file .exe có ProductVersion (UTF-16LE) giống resource electron-builder. */
export function fakeExe(version, size = 8192) {
  const buffer = Buffer.alloc(size);
  const key = Buffer.from("ProductVersion\0", "utf16le");
  key.copy(buffer, 1000);
  let cursor = 1000 + key.length;
  cursor += (4 - (cursor % 4)) % 4;
  Buffer.from(`${version}\0`, "utf16le").copy(buffer, cursor);
  return buffer;
}
