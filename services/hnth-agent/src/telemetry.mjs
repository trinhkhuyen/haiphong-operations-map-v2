import { ping } from "./probes/ping.mjs";
import { discoverHosts } from "./probes/scan.mjs";
import { getAgentState, setAgentState } from "./status.mjs";
import { collectSnmp } from "./probes/snmp.mjs";

/** Gửi kết quả đo lên backend: điểm cấu hình sẵn, SNMP, quét LAN. */
export function createTelemetry({ config, client, monitor }) {
  async function reportSnmp() {
    const results = await collectSnmp(config);
    if (!results.length || !client.apiBase) return;
    const response = await client.postJson(client.apiUrl("/api/telemetry/snmp-results"), { agentId: config.agentId, results });
    if (!response.ok) throw new Error(`SNMP upload returned ${response.status}`);
  }

  // Báo cáo định kỳ config.points; nhường cho Giám sát liên tục khi đang chạy.
  async function reportConfiguredPoints() {
    if (monitor.isActive()) return;
    const results = [];
    for (const point of config.points) results.push(await ping(point, config));
    const response = await client.postJson(client.telemetryUrl, { agentId: config.agentId, timestamp: new Date().toISOString(), results });
    if (!response.ok) throw new Error(`Relay returned ${response.status}`);
    console.log(`sent ${results.length} configured point results at ${new Date().toISOString()}`);
    await reportSnmp();
  }

  async function reportLocalNetwork(scanSubnets = config.scanSubnets || []) {
    // Đếm số lượt quét đang chạy (lệnh và lịch quét có thể chồng nhau) để tray hiện màu "đang chạy".
    setAgentState({ scanning: getAgentState().scanning + 1 });
    let ips;
    try { ips = await discoverHosts(scanSubnets, config); } finally { setAgentState({ scanning: getAgentState().scanning - 1 }); }
    const response = await client.postJson(client.discoveredIpsUrl(), { agentId: config.agentId, ips });
    if (!response.ok) throw new Error(`Relay scan upload returned ${response.status}`);
    console.log(`uploaded ${ips.length} discovered LAN IPs to relay at ${new Date().toISOString()}`);
  }

  // Lệnh test-point: ping một điểm ngoài vòng giám sát và gửi kết quả ngay.
  async function reportTestPoint(command) {
    const result = await ping({ pointId: command.pointId, ipAddress: command.ipAddress }, config);
    const upload = await client.postJson(client.telemetryUrl, { agentId: config.agentId, timestamp: new Date().toISOString(), results: [result] });
    if (!upload.ok) throw new Error(`Relay test upload returned ${upload.status}`);
    console.log(`tested ${command.pointId} ${command.ipAddress}: ${result.status}`);
  }

  return { reportConfiguredPoints, reportLocalNetwork, reportTestPoint };
}
