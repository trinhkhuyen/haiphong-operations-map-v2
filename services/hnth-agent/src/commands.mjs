import { applyAgentConfig } from "./config.mjs";

/** Nhận một lệnh pending từ backend (mỗi 3 giây) và chuyển tới module xử lý. */
export function createCommandHandler({ config, configPath, client, persistConfig, monitor, telemetry, updater, restartHeartbeat, configureSchedule }) {
  async function handle(command) {
    if (command.type === "agent-config") {
      const { heartbeatSeconds, tokenChanged } = applyAgentConfig(config, command);
      restartHeartbeat(heartbeatSeconds);
      await persistConfig();
      configureSchedule();
      console.log(`agent configuration updated and saved to ${configPath}: heartbeat every ${heartbeatSeconds}s${tokenChanged ? "; token changed" : ""}`);
    }
    if (command.type === "agent-update") await updater.applyUpdate(command);
    if (command.type === "scan-local-network") await telemetry.reportLocalNetwork(command.scanSubnets);
    if (command.type === "test-point") await telemetry.reportTestPoint(command);
    if (command.type === "point-config") await monitor.configurePoint(command);
    if (command.type === "monitor-start") monitor.start(command);
    if (command.type === "monitor-stop") monitor.stop();
  }

  async function poll() {
    const response = await client.request(client.commandsUrl(), { headers: client.apiBase ? client.authHeaders() : undefined });
    if (!response.ok) return;
    await handle(await response.json());
  }

  return { poll, handle };
}
