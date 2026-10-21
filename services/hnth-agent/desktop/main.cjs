const { app, Menu, Tray, nativeImage, shell, dialog } = require("electron");
const path = require("node:path");
const fs = require("node:fs");

const isPackaged = app.isPackaged;
const agentRoot = isPackaged
  ? path.join(process.resourcesPath, "agent")
  : path.resolve(__dirname, "..");
let configPath = process.env.HNTH_AGENT_CONFIG || path.join(agentRoot, "config.json");
const agentPath = path.join(agentRoot, "src", "agent.mjs");
let tray;
let agentStatus = "Đang khởi động…";

// Bản portable chạy từ thư mục giải nén tạm (resources bị xóa khi thoát), nên config
// phải nằm ngoài: ưu tiên cạnh file .exe, nếu thư mục đó không ghi được thì dùng
// %APPDATA%\HNTH Agent. Lần chạy đầu tiên config được tạo từ bản mẫu đóng gói sẵn.
// Định danh Agent gắn với thư mục chứa config này (xem register() trong agent.mjs).
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

function createTrayIcon() {
  const iconPath = path.join(__dirname, "hnth-agent.png");
  return nativeImage.createFromBuffer(fs.readFileSync(iconPath));
}

function updateMenu() {
  if (!tray) return;
  tray.setContextMenu(Menu.buildFromTemplate([
    { label: `Agent HNTH: ${agentStatus}`, enabled: false },
    { type: "separator" },
    { label: "Mở file cấu hình", click: () => shell.openPath(configPath) },
    { label: "Mở thư mục Agent", click: () => shell.openPath(agentRoot) },
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
    agentStatus = "Đang hoạt động";
  } catch (error) {
    agentStatus = "Lỗi khởi động";
    dialog.showErrorBox("Agent HNTH không khởi động được", error instanceof Error ? error.stack || error.message : String(error));
  }
  updateMenu();
}

app.whenReady().then(async () => {
  app.setAppUserModelId("vn.haiphong.ops.hnth-agent");
  if (!process.env.HNTH_AGENT_CONFIG && isPackaged) configPath = resolvePackagedConfigPath();
  tray = new Tray(createTrayIcon());
  tray.setToolTip("Agent HNTH đang chạy");
  updateMenu();
  void startAgent();
});

app.on("window-all-closed", (event) => event.preventDefault());
