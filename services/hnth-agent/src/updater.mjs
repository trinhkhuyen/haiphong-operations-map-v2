import { createHash } from "node:crypto";
import { copyFile, mkdir, readFile, unlink, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { exec, sleep } from "./util.mjs";

const MAX_UPDATE_BYTES = 250 * 1024 * 1024;

export function createUpdater({ config, configPath, client, persistConfig }) {
  const updateResultPath = path.join(path.dirname(String(configPath)), "update-result.json");

  async function reportUpdateResult(result) {
    if (!client.apiBase || !result?.version || !result?.status) return false;
    const response = await client.postJson(client.apiUrl("/api/agents/update-result"), { agentId: config.agentId, ...result });
    if (!response.ok) return false;
    if (result.status === "success") { config.version = String(result.version); delete config.pendingUpdate; await persistConfig(); }
    return true;
  }

  // apply-update.ps1 ghi update-result.json rồi khởi động lại Agent; bản mới báo
  // kết quả đó cho backend lúc khởi động.
  async function reportPendingUpdate() {
    let result;
    try { result = JSON.parse(await readFile(updateResultPath, "utf8")); } catch { return; }
    if (!client.apiBase || !result?.version || !result?.status) return;
    try {
      if (await reportUpdateResult(result)) await unlink(updateResultPath).catch(() => {});
    } catch (error) { console.error(`could not report update result: ${error.message}`); }
  }

  async function applyUpdate(command) {
    try {
      if (!(command.path || command.url) || !command.sha256 || !command.version) throw new Error("agent-update requires path, sha256 and version");
      if (!process.versions.electron || process.platform !== "win32") throw new Error("remote update requires the packaged Windows Agent");
      if (command.fileName && !String(command.fileName).toLowerCase().endsWith(".exe")) throw new Error("remote update must be an .exe file");
      // Backend gửi đường dẫn tương đối; ghép với backendUrl của chính Agent để máy ở
      // LAN khác tải được. Token Agent chỉ được gửi tới đúng backend đã cấu hình.
      const source = new URL(command.path || command.url, client.apiBase || undefined);
      const response = await client.request(source, { headers: client.apiBase && source.origin === client.apiBase.origin ? { authorization: `Bearer ${config.token}` } : {} });
      if (!response.ok) throw new Error(`Update download returned ${response.status}`);
      const contentLength = Number(response.headers.get("content-length") || 0);
      if (contentLength > MAX_UPDATE_BYTES) throw new Error("Update file is too large (max 250 MB)");
      const bytes = Buffer.from(await response.arrayBuffer());
      if (bytes.length > MAX_UPDATE_BYTES) throw new Error("Update file is too large (max 250 MB)");
      const digest = createHash("sha256").update(bytes).digest("hex");
      if (digest.toLowerCase() !== String(command.sha256).toLowerCase()) throw new Error("Update SHA-256 mismatch; file was not staged");
      const updateDir = path.join(path.dirname(String(configPath)), "updates");
      await mkdir(updateDir, { recursive: true });
      const filePath = path.join(updateDir, `agent-${String(command.version).replace(/[^a-zA-Z0-9._-]/g, "_")}.exe`);
      await writeFile(filePath, bytes);
      // Electron Portable chạy từ thư mục giải nén tạm, bị launcher xóa khi Agent thoát.
      // Vì vậy updater là script PowerShell được copy ra cạnh config, và file cần thay
      // là file portable gốc (PORTABLE_EXECUTABLE_FILE), không phải process.execPath.
      const script = path.join(updateDir, "apply-update.ps1");
      await copyFile(fileURLToPath(new URL("./apply-update.ps1", import.meta.url)), script);
      const targetExe = process.env.PORTABLE_EXECUTABLE_FILE || process.execPath;
      // Launcher portable gom tiến trình con vào một Windows Job và kill cả Job khi Agent
      // thoát, kể cả tiến trình spawn detached. Tạo updater qua WMI (Win32_Process.Create)
      // để nó nằm ngoài Job đó; lệnh này trả về ngay sau khi updater đã được tạo.
      const quote = (value) => `"${String(value).replaceAll('"', "")}"`;
      const updaterCommand = ["powershell.exe", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", quote(script), "-ProcessId", process.pid, "-TargetExe", quote(targetExe), "-StagedFile", quote(filePath), "-ResultFile", quote(updateResultPath), "-Version", quote(command.version), "-Sha256", digest].join(" ");
      const env = { ...process.env, HNTH_UPDATER_COMMAND: updaterCommand };
      delete env.ELECTRON_RUN_AS_NODE;
      const launcher = "$si = New-CimInstance -ClassName Win32_ProcessStartup -ClientOnly -Property @{ ShowWindow = [uint16]0 }; $r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $env:HNTH_UPDATER_COMMAND; ProcessStartupInformation = $si }; if ($r.ReturnValue -ne 0) { Write-Error \"Win32_Process.Create returned $($r.ReturnValue)\"; exit 1 }; Write-Output $r.ProcessId";
      const { stdout } = await exec("powershell.exe", ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", launcher], { windowsHide: true, env });
      console.log(`updater started outside the portable job (pid ${stdout.trim()})`);
      config.pendingUpdate = { version: command.version, filePath, sha256: digest, stagedAt: new Date().toISOString() };
      await persistConfig();
      console.log(`verified update ${command.version}; updater started and Agent will restart after replacement`);
      await sleep(150);
      process.exit(0);
    } catch (error) {
      const detail = error instanceof Error ? error.message : String(error);
      console.error(`agent update failed: ${detail}`);
      try { await reportUpdateResult({ version: String(command.version || "unknown"), status: "failed", detail }); } catch (reportError) { console.error(`could not report update failure: ${reportError.message}`); }
    }
  }

  return { applyUpdate, reportPendingUpdate };
}
