#!/usr/bin/env node
// Kiểm tra nhanh toàn bộ workspace trước khi coi một thay đổi là xong.
//   node scripts/check.mjs          -> typecheck web + kiểm tra cú pháp các service Node
//   node scripts/check.mjs --build  -> thêm vite build production
//   node scripts/check.mjs --test   -> thêm unit test web (vitest)
import { spawnSync } from "node:child_process";
import { readdirSync, statSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const withBuild = process.argv.includes("--build");
const withTest = process.argv.includes("--test");
const isWindows = process.platform === "win32";
const failures = [];

function run(label, command, args, cwd = root) {
  const started = Date.now();
  // .CMD shims trên Windows phải chạy qua shell; node.exe thì không (đường dẫn có dấu cách).
  const result = isWindows && /\.cmd$/i.test(command)
    ? spawnSync([`"${command}"`, ...args].join(" "), { cwd, encoding: "utf8", shell: true })
    : spawnSync(command, args, { cwd, encoding: "utf8" });
  const seconds = ((Date.now() - started) / 1000).toFixed(1);
  if (result.status === 0) {
    console.log(`✔ ${label} (${seconds}s)`);
    return;
  }
  failures.push(label);
  console.log(`✘ ${label} (${seconds}s)`);
  process.stdout.write(`${result.stdout || ""}${result.stderr || ""}${result.error ? `${result.error.message}\n` : ""}`);
}

function nodeSources(dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    if (name === "node_modules" || name === "outputs" || name === "agent-releases") continue;
    const full = path.join(dir, name);
    if (statSync(full).isDirectory()) out.push(...nodeSources(full));
    else if (/\.(mjs|cjs)$/.test(name)) out.push(full);
  }
  return out;
}

const tsc = path.join(root, "apps/web/node_modules/.bin", isWindows ? "tsc.CMD" : "tsc");
run("web: tsc -b", tsc, ["-b", "--pretty", "false"], path.join(root, "apps/web"));

for (const file of [...nodeSources(path.join(root, "services")), ...nodeSources(path.join(root, "scripts"))]) {
  run(`node --check ${path.relative(root, file).replaceAll("\\", "/")}`, process.execPath, ["--check", file]);
}

if (withTest) {
  const vitest = path.join(root, "apps/web/node_modules/.bin", isWindows ? "vitest.CMD" : "vitest");
  run("web: vitest run", vitest, ["run"], path.join(root, "apps/web"));
}

if (withBuild) {
  const vite = path.join(root, "apps/web/node_modules/.bin", isWindows ? "vite.CMD" : "vite");
  run("web: vite build", vite, ["build"], path.join(root, "apps/web"));
}

if (failures.length) {
  console.log(`\n${failures.length} bước thất bại: ${failures.join(", ")}`);
  process.exit(1);
}
console.log("\nTất cả kiểm tra đều đạt.");
