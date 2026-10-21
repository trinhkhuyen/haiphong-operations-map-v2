const { app, Menu, Tray, nativeImage, shell, dialog } = require("electron");
const { spawn } = require("node:child_process");
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

function argValue(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : "";
}

function isProcessRunning(pid) {
  try { process.kill(Number(pid), 0); return true; } catch (error) { return error?.code === "EPERM"; }
}

async function applyUpdate() {
  const targetPid = Number(argValue("--target-pid"));
  const fallbackPortableDir = process.env.PORTABLE_EXECUTABLE_DIR || path.dirname(process.execPath);
  const fallbackPortableName = process.env.PORTABLE_EXECUTABLE_APP_FILENAME || path.basename(process.env.PORTABLE_EXECUTABLE_FILE || process.execPath);
  const targetExe = path.resolve(argValue("--target-exe") || process.env.PORTABLE_EXECUTABLE_FILE || path.join(fallbackPortableDir, fallbackPortableName));
  const stagedFile = path.resolve(argValue("--staged-file"));
  const resultFile = path.resolve(argValue("--result-file"));
  const version = argValue("--updated-version");
  const result = (status, detail) => fs.promises.mkdir(path.dirname(resultFile), { recursive: true }).then(() => fs.promises.writeFile(resultFile, JSON.stringify({ version, status, detail, reportedAt: new Date().toISOString() }, null, 2)));
  try {
    if (!targetPid || !targetExe || !stagedFile || !resultFile || !version) throw new Error("updater arguments are incomplete");
    for (let attempt = 0; attempt < 120 && isProcessRunning(targetPid); attempt += 1) await new Promise((resolve) => setTimeout(resolve, 250));
    if (isProcessRunning(targetPid)) throw new Error("old Agent did not exit within 30 seconds");
    await fs.promises.access(stagedFile, fs.constants.R_OK);
    await fs.promises.access(targetExe, fs.constants.W_OK);
    const backup = `${targetExe}.previous`;
    const replacement = `${targetExe}.replacement`;
    await fs.promises.copyFile(targetExe, backup);
    await fs.promises.copyFile(stagedFile, replacement);
    await fs.promises.rename(targetExe, `${targetExe}.old`);
    try { await fs.promises.rename(replacement, targetExe); } catch (error) { await fs.promises.rename(`${targetExe}.old`, targetExe).catch(() => {}); throw error; }
    await fs.promises.unlink(`${targetExe}.old`).catch(() => {});
    await result("success", `Agent ${version} đã được thay thế an toàn; khởi chạy ${targetExe}`);
    const child = spawn(targetExe, [], { detached: true, stdio: "ignore", windowsHide: true, cwd: path.dirname(targetExe) });
    child.unref();
  } catch (error) {
    await result("failed", error instanceof Error ? error.message : String(error));
  }
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
  process.env.ELECTRON_RUN_AS_NODE = "1";
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
  if (process.argv.includes("--hnth-apply-update")) {
    await applyUpdate();
    app.quit();
    return;
  }
  app.setAppUserModelId("vn.haiphong.ops.hnth-agent");
  if (!process.env.HNTH_AGENT_CONFIG && isPackaged) {
    const portableDir = process.env.PORTABLE_EXECUTABLE_DIR || path.dirname(process.execPath);
    const externalConfigPath = path.join(portableDir, "config.json");
    if (fs.existsSync(externalConfigPath)) configPath = externalConfigPath;
  }
  tray = new Tray(createTrayIcon());
  tray.setToolTip("Agent HNTH đang chạy");
  updateMenu();
  void startAgent();
});

app.on("window-all-closed", (event) => event.preventDefault());
