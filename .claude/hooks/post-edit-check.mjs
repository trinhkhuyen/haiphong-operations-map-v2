// PostToolUse(Edit|Write): kiểm tra nhanh file vừa sửa.
//  - .mjs/.cjs/.js trong services|packages|scripts -> node --check
//  - .ts/.tsx trong apps/web/src                    -> tsc -b của apps/web (~10-15s)
// Lỗi => exit 2, stderr được đưa lại cho model để sửa ngay.
import { spawnSync } from "node:child_process";
import path from "node:path";

const input = JSON.parse(await new Promise((resolve) => { let raw = ""; process.stdin.on("data", (c) => (raw += c)); process.stdin.on("end", () => resolve(raw || "{}")); }));
const filePath = input.tool_input?.file_path || input.tool_response?.filePath;
if (!filePath) process.exit(0);

const root = process.env.CLAUDE_PROJECT_DIR || process.cwd();
const abs = path.resolve(root, filePath);
const rel = path.relative(root, abs).replaceAll("\\", "/");
const isWindows = process.platform === "win32";

function fail(label, result) {
  const output = `${result.stdout || ""}${result.stderr || ""}${result.error?.message || ""}`.trim();
  process.stderr.write(`${label} thất bại sau khi sửa ${rel}:\n${output.split("\n").slice(0, 40).join("\n")}\n`);
  process.exit(2);
}

if (/^(services|packages|scripts)\/.+\.(mjs|cjs|js)$/.test(rel) && !rel.includes("/node_modules/") && !rel.includes("/outputs/")) {
  const result = spawnSync(process.execPath, ["--check", abs], { encoding: "utf8" });
  if (result.status !== 0) fail("node --check", result);
} else if (/^apps\/web\/src\/.+\.tsx?$/.test(rel)) {
  const webDir = path.join(root, "apps/web");
  const tsc = path.join(webDir, "node_modules/.bin", isWindows ? "tsc.CMD" : "tsc");
  // .CMD shim trên Windows cần shell; truyền cả lệnh dạng chuỗi để tránh cảnh báo DEP0190.
  const result = isWindows
    ? spawnSync(`"${tsc}" -b --pretty false`, { cwd: webDir, encoding: "utf8", shell: true })
    : spawnSync(tsc, ["-b", "--pretty", "false"], { cwd: webDir, encoding: "utf8" });
  if (result.status !== 0) fail("tsc -b (apps/web)", result);
}
