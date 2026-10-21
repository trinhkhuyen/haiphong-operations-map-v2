import { createHash } from "node:crypto";
import os from "node:os";
import path from "node:path";
import { exec } from "./util.mjs";

async function localMachineId() {
  if (process.platform === "win32") {
    try {
      const { stdout } = await exec("reg.exe", ["query", "HKLM\\SOFTWARE\\Microsoft\\Cryptography", "/v", "MachineGuid"], { windowsHide: true });
      const value = stdout.match(/MachineGuid\s+REG_SZ\s+([^\r\n]+)/i)?.[1]?.trim();
      if (value) return value;
    } catch { /* fallback below */ }
  }
  return createHash("sha256").update(`${os.hostname()}|${process.env.USERNAME || process.env.USER || "unknown"}`).digest("hex").slice(0, 32);
}

// Định danh bản cài = máy (MachineGuid) + thư mục chứa config.json. Copy thư mục
// Agent sang máy khác hoặc sang thư mục khác trên cùng máy đều cho installationId
// mới; khi đó Agent tự xin agentId + token riêng thay vì dùng chung id với bản gốc.
export function installationIdFor(machineId, configPath) {
  const configDir = path.resolve(path.dirname(String(configPath))).toLowerCase();
  return createHash("sha256").update(`${machineId}|${configDir}`).digest("hex").slice(0, 32);
}

// Config mang installationId/machineId của nơi khác nghĩa là thư mục Agent đã bị copy.
export function isCopiedInstallation(config, { machineId, installationId }) {
  return config.installationId ? config.installationId !== installationId : Boolean(config.machineId && config.machineId !== machineId);
}

export function createIdentity({ config, configPath, runtimeVersion, client, persistConfig }) {
  let installation;
  async function currentInstallation() {
    if (installation) return installation;
    const machineId = await localMachineId();
    installation = { machineId, installationId: installationIdFor(machineId, configPath) };
    return installation;
  }

  async function enrollAsNewAgent(reason) {
    const { machineId, installationId } = await currentInstallation();
    const response = await client.postJson(client.apiUrl("/api/agents/clone"), { agentId: config.agentId, machineId, installationId, name: `${config.agentName || "Agent HNTH"} - ${os.hostname()}`, version: runtimeVersion });
    if (!response.ok) throw new Error(`Agent enrollment returned ${response.status}`);
    const replacement = await response.json();
    const previousId = config.agentId;
    Object.assign(config, { agentId: replacement.agentId, token: replacement.token, agentName: replacement.name, machineId, installationId });
    await persistConfig();
    console.log(`${reason}: ${previousId} -> agent ${config.agentId} (${os.hostname()})`);
  }

  async function register(attempt = 0) {
    if (!client.apiBase) return;
    const current = await currentInstallation();
    const { machineId, installationId } = current;
    if (isCopiedInstallation(config, current)) await enrollAsNewAgent("copied Agent installation detected");
    const response = await client.postJson(client.apiUrl("/api/agents/register"), { agentId: config.agentId, machineId, installationId, name: config.agentName || config.agentId, version: runtimeVersion });
    if (response.status === 409 && attempt === 0) {
      await enrollAsNewAgent("agent id already used by another installation");
      return register(attempt + 1);
    }
    if (!response.ok) throw new Error(`Backend registration returned ${response.status}`);
    if (config.installationId !== installationId || config.machineId !== machineId) {
      Object.assign(config, { machineId, installationId });
      await persistConfig();
    }
    console.log(`registered agent ${config.agentId} with backend (installation ${installationId})`);
  }

  async function sendHeartbeat() {
    if (!client.apiBase) return;
    const { installationId } = await currentInstallation();
    const response = await client.postJson(client.apiUrl("/api/agents/heartbeat"), { agentId: config.agentId, machineId: config.machineId, installationId, version: runtimeVersion, sentAt: new Date().toISOString() });
    // 409: agentId này đã thuộc bản cài khác -> đăng ký lại, register() sẽ tự xin id mới.
    if (response.status === 409) { await register(); return; }
    if (!response.ok) throw new Error(`Backend heartbeat returned ${response.status}`);
  }

  return { register, sendHeartbeat };
}
