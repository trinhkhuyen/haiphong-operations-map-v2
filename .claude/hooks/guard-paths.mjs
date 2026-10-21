// PreToolUse(Edit|Write): chặn sửa các thư mục rác/sinh ra và file bí mật.
// Exit 2 + stderr => Claude Code chặn thao tác và đưa lý do về cho model.
import path from "node:path";

const input = JSON.parse(await new Promise((resolve) => { let raw = ""; process.stdin.on("data", (c) => (raw += c)); process.stdin.on("end", () => resolve(raw || "{}")); }));
const filePath = input.tool_input?.file_path;
if (!filePath) process.exit(0);

const root = process.env.CLAUDE_PROJECT_DIR || process.cwd();
const rel = path.relative(root, path.resolve(root, filePath)).replaceAll("\\", "/");

const rules = [
  [/^\.codex_tmp\//, ".codex_tmp/ là rác của AI trước (Chrome profile, ảnh chụp) — không sửa"],
  [/^(outputs|artifacts|\.openai|\.pnpm-store)\//, "thư mục bản build/đóng gói — không sửa tay"],
  [/^services\/hnth-agent\/outputs\//, "bản build Agent — sinh bởi electron-builder"],
  [/(^|\/)node_modules\//, "node_modules — cài lại bằng pnpm install"],
  [/(^|\/)dist\//, "dist/ là output của vite build"],
  [/^pnpm-lock\.yaml$/, "pnpm-lock.yaml chỉ được cập nhật qua pnpm install/add"],
  [/^\.env\.(production|source|demo)$/, "file env thật chứa bí mật — người dùng tự sửa"],
];

for (const [pattern, reason] of rules) {
  if (pattern.test(rel)) {
    process.stderr.write(`Bị chặn bởi .claude/hooks/guard-paths.mjs: ${rel} — ${reason}.\n`);
    process.exit(2);
  }
}
