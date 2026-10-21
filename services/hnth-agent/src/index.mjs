// Điểm vào của Agent: chạy ngay khi được import (node src/index.mjs, hoặc
// desktop/main.cjs import trong Electron). Lỗi đọc config ném ra cho nơi gọi.
import { fileURLToPath } from "node:url";
import { createBackendClient } from "./backend-client.mjs";
import { createCommandHandler } from "./commands.mjs";
import { loadAgentConfig, saveAgentConfig } from "./config.mjs";
import { createIdentity } from "./identity.mjs";
import { createMonitor } from "./monitor.mjs";
import { createTelemetry } from "./telemetry.mjs";
import { createUpdater } from "./updater.mjs";
import { numeric } from "./util.mjs";

const configPath = process.env.HNTH_AGENT_CONFIG || fileURLToPath(new URL("../config.json", import.meta.url));
const { config, runtimeVersion } = await loadAgentConfig(configPath, process.env.HNTH_AGENT_VERSION);
const persistConfig = () => saveAgentConfig(configPath, config);
const client = createBackendClient(config);
const context = { config, configPath, runtimeVersion, client, persistConfig };
const identity = createIdentity(context);
const updater = createUpdater(context);
const monitor = createMonitor(context);
const telemetry = createTelemetry({ ...context, monitor });
console.log(`HNTH Agent ${config.agentId} started; config: ${configPath}; relay: ${config.relayUrl}${client.apiBase ? `; backend: ${client.apiBase}` : ""}`);

const logError = (error) => console.error(error.message);
let heartbeatTimer;
let scheduleTimer;
function restartHeartbeat(seconds) {
  clearInterval(heartbeatTimer);
  heartbeatTimer = setInterval(() => void identity.sendHeartbeat().catch(logError), seconds * 1000);
}
function configureSchedule() {
  clearInterval(scheduleTimer);
  const seconds = numeric(config.scanScheduleSeconds, 0, 0, 86400);
  if (seconds > 0) scheduleTimer = setInterval(() => void telemetry.reportLocalNetwork().catch((error) => console.error(`scheduled scan: ${error.message}`)), seconds * 1000);
}
const commands = createCommandHandler({ ...context, monitor, telemetry, updater, restartHeartbeat, configureSchedule });

await updater.reportPendingUpdate();
await identity.register().catch(logError);
await identity.sendHeartbeat().catch(logError);
await telemetry.reportConfiguredPoints().catch(logError);
setInterval(() => void telemetry.reportConfiguredPoints().catch(logError), config.intervalMs || 30000);
setInterval(() => void commands.poll().catch(logError), 3000);
// Heartbeat định kỳ 30 giây để backend và giao diện nhận biết Agent kịp thời.
restartHeartbeat(30);
configureSchedule();
