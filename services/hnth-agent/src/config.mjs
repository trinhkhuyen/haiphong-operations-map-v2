import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";

// config.json là nguồn sự thật về token, agentId và installationId; Agent ghi lại
// file này khi nhận agent-config, khi enroll và khi cập nhật thành công.
export async function loadAgentConfig(configPath, envVersion) {
  const config = JSON.parse(await readFile(configPath, "utf8"));
  // Version comes from the packaged executable. Token and agent identity remain
  // in the persisted config so a token rotated before an upgrade is preserved.
  const runtimeVersion = String(envVersion || config.version || "0.1.1");
  config.version = runtimeVersion;
  return { config, runtimeVersion };
}

export async function saveAgentConfig(configPath, config) {
  await mkdir(path.dirname(String(configPath)), { recursive: true });
  await writeFile(configPath, `${JSON.stringify(config, null, 2)}\n`, "utf8");
}

export const AGENT_CONFIG_KEYS = ["scanSubnets", "scanConcurrency", "scanDelayMs", "scanScheduleSeconds", "probeCount", "probeIntervalMs", "snmpTargets", "points"];

/** Áp lệnh agent-config vào config (chưa ghi file); trả chu kỳ heartbeat mới. */
export function applyAgentConfig(config, command) {
  const heartbeatSeconds = Math.max(5, Math.min(30, Number(command.heartbeatSeconds) || 30));
  for (const key of AGENT_CONFIG_KEYS) if (command[key] !== undefined) config[key] = command[key];
  if (command.token) config.token = String(command.token);
  return { heartbeatSeconds, tokenChanged: Boolean(command.token) };
}
