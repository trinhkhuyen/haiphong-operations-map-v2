const { app, Menu, Tray, nativeImage, shell, dialog } = require("electron");
const path = require("node:path");
const fs = require("node:fs");

const isPackaged = app.isPackaged;
const agentRoot = isPackaged
  ? path.join(process.resourcesPath, "agent")
  : path.resolve(__dirname, "..");
let configPath = process.env.HNTH_AGENT_CONFIG || path.join(agentRoot, "config.json");
const agentPath = path.join(agentRoot, "src", "index.mjs");
let tray;
// Chỉ lỗi khởi động cần hiện bằng chữ; trạng thái thường thể hiện bằng màu icon.
let startupError = "";
// Cập nhật từ src/status.mjs qua sự kiện process (Agent chạy chung tiến trình).
let agentState = { backend: "unknown", monitoring: false, scanning: 0 };
let iconKind = "normal";

// Bản portable chạy từ thư mục giải nén tạm (resources bị xóa khi thoát), nên config
// phải nằm ngoài: ưu tiên cạnh file .exe, nếu thư mục đó không ghi được thì dùng
// %APPDATA%\HNTH Agent. Lần chạy đầu tiên config được tạo từ bản mẫu đóng gói sẵn.
// Định danh Agent gắn với thư mục chứa config này (xem src/identity.mjs).
function resolvePackagedConfigPath() {
  const template = path.join(agentRoot, "config.json");
  const portableDir = process.env.PORTABLE_EXECUTABLE_DIR || path.dirname(process.execPath);
  const candidates = [path.join(portableDir, "config.json"), path.join(app.getPath("appData"), "HNTH Agent", "config.json")];
  const existing = candidates.find((candidate) => fs.existsSync(candidate));
  if (existing) return existing;
  for (const candidate of candidates) {
    try {
      fs.mkdirSync(path.dirname(candidate), { recursive: true });
      fs.copyFileSync(template, candidate, fs.constants.COPYFILE_EXCL);
      return candidate;
    } catch { /* thử vị trí tiếp theo */ }
  }
  return template;
}

// Vàng: mất backend (Agent vẫn heartbeat/poll để tự nối lại). Đỏ: đang giám sát/quét.
function trayIconKind() {
  if (startupError || agentState.backend === "offline" || agentState.backend === "unauthorized") return "offline";
  if (agentState.monitoring || agentState.scanning > 0) return "busy";
  return "normal";
}

// Mỗi trạng thái một file PNG sinh bởi create-icon.cjs (hnth-agent.png là bình thường).
const iconCache = new Map();
function createTrayIcon(kind = "normal") {
  if (!iconCache.has(kind)) iconCache.set(kind, nativeImage.createFromPath(path.join(__dirname, kind === "normal" ? "hnth-agent.png" : `hnth-agent-${kind}.png`)));
  return iconCache.get(kind);
}

function refreshTrayIcon() {
  const kind = trayIconKind();
  if (!tray || kind === iconKind) return;
  iconKind = kind;
  tray.setImage(createTrayIcon(kind));
}

// agentId đọc lại từ config mỗi lần làm mới menu: Agent có thể đổi id khi
// phát hiện bản copy và tự enroll (xem src/identity.mjs).
function readConfig() {
  try { return JSON.parse(fs.readFileSync(configPath, "utf8")); } catch { return {}; }
}

function updateMenu() {
  if (!tray) return;
  const version = app.getVersion();
  const config = readConfig();
  const name = config.agentName || "Agent HNTH";
  tray.setToolTip(`${name} · v${version}${startupError ? ` · ${startupError}` : ""}`);
  tray.setContextMenu(Menu.buildFromTemplate([
    { label: name, enabled: false },
    { label: `Phiên bản: ${version}`, enabled: false },
    ...(startupError ? [{ label: startupError, enabled: false }] : []),
    { label: `Agent ID: ${config.agentId || "chưa có"}`, enabled: false },
    { type: "separator" },
    { label: "Mở file cấu hình", click: () => shell.openPath(configPath) },
    // Thư mục chứa config (cạnh file .exe), không phải thư mục giải nén tạm của bản portable.
    { label: "Mở thư mục Agent", click: () => shell.openPath(path.dirname(configPath)) },
    { type: "separator" },
    { label: "Thoát Agent HNTH", click: () => app.quit() },
  ]));
}

async function startAgent() {
  if (!fs.existsSync(configPath)) {
    dialog.showErrorBox("Không tìm thấy cấu hình Agent", `Không tìm thấy file:\n${configPath}`);
    app.quit();
    return;
  }
  process.env.HNTH_AGENT_CONFIG = configPath;
  // The packaged executable version is authoritative; keep the persisted
  // config for the existing agent identity and rotated token.
  process.env.HNTH_AGENT_VERSION = app.getVersion();
  try {
    await import(`file://${agentPath.replaceAll("\\", "/")}`);
  } catch (error) {
    startupError = "Lỗi khởi động";
    dialog.showErrorBox("Agent HNTH không khởi động được", error instanceof Error ? error.stack || error.message : String(error));
  }
  updateMenu();
  refreshTrayIcon();
}

process.on("hnth-agent-state", (state) => { agentState = state; refreshTrayIcon(); });

app.whenReady().then(async () => {
  app.setAppUserModelId("vn.haiphong.ops.hnth-agent");
  if (!process.env.HNTH_AGENT_CONFIG && isPackaged) configPath = resolvePackagedConfigPath();
  tray = new Tray(createTrayIcon());
  updateMenu();
  void startAgent();
  setInterval(updateMenu, 15000);
});

app.on("window-all-closed", (event) => event.preventDefault());
