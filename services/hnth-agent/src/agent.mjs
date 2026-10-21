import { readFile, writeFile, mkdir, unlink } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { execFile, spawn } from "node:child_process";
import { promisify } from "node:util";
import { createHash, randomUUID, randomBytes } from "node:crypto";
import os from "node:os";
import dgram from "node:dgram";
import path from "node:path";
const exec = promisify(execFile);
const configPath = process.env.HNTH_AGENT_CONFIG || fileURLToPath(new URL("../config.json", import.meta.url));
const config = JSON.parse(await readFile(configPath, "utf8"));
// Version comes from the packaged executable. Token and agent identity remain
// in the persisted config so a token rotated before an upgrade is preserved.
const runtimeVersion = String(process.env.HNTH_AGENT_VERSION || config.version || "0.1.1");
config.version = runtimeVersion;
const apiBase = config.backendUrl ? new URL(config.backendUrl) : null;
const apiUrl = (path) => apiBase ? new URL(path, apiBase).toString() : null;
const telemetryUrl = apiBase ? apiUrl("/api/telemetry/ping-results") : config.relayUrl;
const authHeaders = () => ({ authorization: `Bearer ${config.token}`, "content-type": "application/json" });
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
async function ensureInstallationIdentity() {
  const machineId = await localMachineId();
  if (!config.machineId) { config.machineId = machineId; await persistConfig(); return; }
  if (config.machineId === machineId || !apiBase) return;
  const response = await backendFetch(apiUrl("/api/agents/clone"), { method: "POST", headers: authHeaders(), body: JSON.stringify({ agentId: config.agentId, machineId, name: `${config.agentName || "Agent HNTH"} - ${os.hostname()}` }) });
  if (!response.ok) throw new Error(`Agent clone registration returned ${response.status}`);
  const replacement = await response.json();
  config.agentId = replacement.agentId;
  config.token = replacement.token;
  config.agentName = replacement.name;
  config.machineId = machineId;
  await persistConfig();
  console.log(`detected cloned installation; registered new agent ${config.agentId} for ${os.hostname()}`);
}
const updateResultPath = path.join(path.dirname(String(configPath)), "update-result.json");
console.log(`HNTH Agent ${config.agentId} started; config: ${configPath}; relay: ${config.relayUrl}${apiBase ? `; backend: ${apiBase}` : ""}`);
let backendConnection = "unknown";
function reportBackendConnection(next, detail = "") {
  if (backendConnection === next) return;
  backendConnection = next;
  const prefix = next === "online" ? "BACKEND ONLINE" : next === "offline" ? "BACKEND OFFLINE" : "BACKEND AUTH ERROR";
  console.log(`[${new Date().toISOString()}] ${prefix}${detail ? `: ${detail}` : ""}`);
}
async function backendFetch(url, options = {}) {
  try {
    const response = await fetch(url, options);
    if (response.status === 401 || response.status === 403) reportBackendConnection("unauthorized", `${response.status} at ${new URL(url).pathname}`);
    else reportBackendConnection(response.ok ? "online" : "offline", response.ok ? "" : `${response.status} at ${new URL(url).pathname}`);
    return response;
  } catch (error) {
    reportBackendConnection("offline", error instanceof Error ? error.message : String(error));
    throw error;
  }
}
async function reportUpdateResult(result) {
  if (!apiBase || !result?.version || !result?.status) return false;
  const response = await backendFetch(apiUrl("/api/agents/update-result"), { method: "POST", headers: authHeaders(), body: JSON.stringify({ agentId: config.agentId, ...result }) });
  if (!response.ok) return false;
  if (result.status === "success") { config.version = String(result.version); delete config.pendingUpdate; await persistConfig(); }
  return true;
}
async function reportPendingUpdate() {
  let result;
  try { result = JSON.parse(await readFile(updateResultPath, "utf8")); } catch { return; }
  if (!apiBase || !result?.version || !result?.status) return;
  try {
    if (await reportUpdateResult(result)) await unlink(updateResultPath).catch(() => {});
  } catch (error) { console.error(`could not report update result: ${error.message}`); }
}
let monitorTimer;
let monitorRunId = 0;
let monitorPoints = [];
let monitorConcurrency = 1;
let monitorWaitSeconds = 3;
let monitorInitialCyclePending = false;
let monitoringActive = false;
let heartbeatTimer;
let scheduleTimer;
const lastSentStatuses = new Map();
const lastObservedStatuses = new Map();
let monitorRotation = 0;

const numeric = (value, fallback, min, max) => Math.max(min, Math.min(max, Number.isFinite(Number(value)) ? Number(value) : fallback));
const probeCount = (point) => numeric(point.probeCount ?? config.probeCount ?? 4, 4, 1, 10);
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function ping(point) {
  if (!String(point.ipAddress || "").trim()) {
    return { pointId: point.pointId, name: point.name || point.pointId, ipAddress: "", status: "unknown", latencyMs: null, checkedAt: new Date().toISOString() };
  }
  const samples = [];
  for (let index = 0; index < probeCount(point); index += 1) {
    const started = Date.now();
    try {
      const args = process.platform === "win32" ? ["-n", "1", "-w", String(numeric(point.timeoutMs ?? config.pingTimeoutMs, 1000, 100, 10000)), point.ipAddress] : ["-c", "1", "-W", "1", point.ipAddress];
      await exec(process.platform === "win32" ? "ping.exe" : "ping", args, { windowsHide: true });
      samples.push(Date.now() - started);
    } catch { /* packet lost */ }
    if (index + 1 < probeCount(point)) await sleep(numeric(point.probeIntervalMs ?? config.probeIntervalMs, 250, 0, 5000));
  }
  const loss = Math.round((1 - samples.length / probeCount(point)) * 10000) / 100;
  const latency = samples.length ? Math.round(samples.reduce((sum, value) => sum + value, 0) / samples.length) : null;
  const jitter = samples.length > 1 ? Math.round(samples.slice(1).reduce((sum, value, index) => sum + Math.abs(value - samples[index]), 0) / (samples.length - 1) * 100) / 100 : 0;
  const successfulProbes = samples.length;
  // A single successful ICMP reply is not enough to call an endpoint online.
  // With the default four probes: 4/4 is online, 2-3/4 is inconclusive, and
  // 0-1/4 is offline. The frontend maps these to Chờ kết nối, Chưa xác định,
  // and Mất kết nối respectively.
  const status = successfulProbes === probeCount(point)
    ? "online"
    : successfulProbes * 2 >= probeCount(point)
      ? "unknown"
      : "offline";
  return { pointId: point.pointId, name: point.name || point.pointId, ipAddress: point.ipAddress, status, latencyMs: latency, packetLossPct: loss, jitterMs: jitter, probeCount: probeCount(point), checkedAt: new Date().toISOString() };
}

function berLength(length) { return length < 128 ? Buffer.from([length]) : Buffer.from([0x81, length]); }
function ber(type, value) { return Buffer.concat([Buffer.from([type]), berLength(value.length), value]); }
function berInteger(value) { const out = Buffer.alloc(4); out.writeInt32BE(value); return ber(0x02, out.subarray(out.findIndex((byte) => byte !== 0) < 0 ? 3 : out.findIndex((byte) => byte !== 0))); }
function berOid(oid) { const parts = oid.split(".").map(Number); const bytes = [parts[0] * 40 + parts[1]]; for (const part of parts.slice(2)) { const stack = [part & 0x7f]; let rest = part >>> 7; while (rest) { stack.unshift((rest & 0x7f) | 0x80); rest >>>= 7; } bytes.push(...stack); } return ber(0x06, Buffer.from(bytes)); }
function readBer(buffer, offset = 0) { const type = buffer[offset]; let length = buffer[offset + 1]; let cursor = offset + 2; if (length & 0x80) { const count = length & 0x7f; length = 0; for (let i = 0; i < count; i += 1) length = length * 256 + buffer[cursor++]; } return { type, start: offset, valueStart: cursor, end: cursor + length, value: buffer.subarray(cursor, cursor + length) }; }
function collectBer(buffer, output = []) { let offset = 0; while (offset + 2 <= buffer.length) { const item = readBer(buffer, offset); output.push(item); if (item.type & 0x20) collectBer(item.value, output); offset = item.end; } return output; }
function snmpPacket(community, oid, requestId) { const variable = ber(0x30, Buffer.concat([berOid(oid), ber(0x05, Buffer.alloc(0))])); const pdu = ber(0xa0, Buffer.concat([berInteger(requestId), berInteger(0), berInteger(0), ber(0x30, variable)])); return ber(0x30, Buffer.concat([berInteger(1), ber(0x04, Buffer.from(community)), pdu])); }
async function snmpGet(target, oid) {
  return new Promise((resolve, reject) => { const socket = dgram.createSocket("udp4"); const requestId = Math.floor(Math.random() * 2_000_000_000); const timer = setTimeout(() => { socket.close(); reject(new Error("SNMP timeout")); }, numeric(target.timeoutMs ?? config.snmpTimeoutMs, 1500, 200, 10000)); socket.on("message", (message) => { clearTimeout(timer); socket.close(); const items = collectBer(message); const value = items.reverse().find((item) => ![0x30, 0xa0, 0xa2, 0x02, 0x04, 0x06].includes(item.type)); const fallback = items.find((item) => item.type === 0x04 && item.value.toString() !== String(target.community || "public")); resolve({ value: (value || fallback)?.value?.toString("utf8") || "", valueType: value?.type ? `0x${value.type.toString(16)}` : "unknown" }); }); socket.send(snmpPacket(target.community || "public", oid, requestId), Number(target.port || 161), target.host, (error) => { if (error) { clearTimeout(timer); socket.close(); reject(error); } }); });
}
async function collectSnmp() {
  const rows = [];
  for (const target of Array.isArray(config.snmpTargets) ? config.snmpTargets : []) for (const oid of Array.isArray(target.oids) ? target.oids : []) { try { const result = await snmpGet(target, oid); rows.push({ targetId: target.targetId || target.host, host: target.host, oid, ...result, checkedAt: new Date().toISOString() }); } catch (error) { rows.push({ targetId: target.targetId || target.host, host: target.host, oid, value: null, valueType: "error", error: error.message, checkedAt: new Date().toISOString() }); } }
  return rows;
}
async function sendSnmp() { const results = await collectSnmp(); if (!results.length || !apiBase) return; const response = await backendFetch(apiUrl("/api/telemetry/snmp-results"), { method: "POST", headers: authHeaders(), body: JSON.stringify({ agentId: config.agentId, results }) }); if (!response.ok) throw new Error(`SNMP upload returned ${response.status}`); }
async function persistConfig() {
  await mkdir(path.dirname(String(configPath)), { recursive: true });
  await writeFile(configPath, `${JSON.stringify(config, null, 2)}\n`, "utf8");
}
function configureSchedule() { clearInterval(scheduleTimer); const seconds = numeric(config.scanScheduleSeconds, 0, 0, 86400); if (seconds > 0) scheduleTimer = setInterval(() => void scanLocalNetwork().catch((error) => console.error(`scheduled scan: ${error.message}`)), seconds * 1000); }

async function networkIdentity(ipAddress) {
  if (process.platform !== "win32") return {};
  try {
    const { stdout } = await exec("arp.exe", ["-a", ipAddress], { windowsHide: true });
    const match = stdout.match(/\b([0-9a-f]{2}(?:-[0-9a-f]{2}){5})\b/i);
    if (!match) return {};
    const macAddress = match[1].toUpperCase();
    const modelVendor = vendorFromMac(macAddress);
    return { macAddress, ...(modelVendor ? { modelVendor } : {}) };
  } catch { return {}; }
}

// Nhận diện Vendor ở mức OUI từ MAC lấy được trong ARP cache. Đây là thông tin
// bổ trợ; nếu thiết bị không có trong bảng OUI thì vẫn gửi IP/MAC bình thường.
function vendorFromMac(macAddress) {
  const oui = macAddress.replace(/[:-]/g, "").slice(0, 6);
  const vendors = {
    "00000C": "Cisco",
    "001A2B": "Cisco",
    "001B54": "Cisco",
    "0026CB": "Cisco",
    "001C23": "Dell",
    "001E4F": "Dell",
    "0023AE": "Dell",
    "3C2C30": "Dell",
    "00155D": "Microsoft Hyper-V",
    "001C42": "Parallels",
    "005056": "VMware",
    "000569": "VMware",
    "001C14": "VMware",
    "001B21": "Intel",
    "3C970E": "Intel",
    "001E68": "Hewlett-Packard",
    "3C4A92": "Hewlett-Packard",
    "001E67": "Lenovo",
    "F8BC12": "Lenovo",
    "00184D": "Netgear",
    "001F33": "Netgear",
    "001A11": "Google",
    "B827EB": "Raspberry Pi",
    "DC4A3E": "Raspberry Pi",
    "001B63": "Cisco-Linksys",
    "00259C": "Cisco-Linksys",
    "0017F2": "Apple",
    "3C0754": "Apple",
    "ACDE48": "Apple",
    "0013D4": "Polycom",
    "64167F": "Poly",
    "001565": "Yealink"
  };
  return vendors[oui] || "";
}

async function scanAndSend() {
  if (monitoringActive) return;
  const results = [];
  for (const point of config.points) results.push(await ping(point));
  const response = await backendFetch(telemetryUrl, { method: "POST", headers: authHeaders(), body: JSON.stringify({ agentId: config.agentId, timestamp: new Date().toISOString(), results }) });
  if (!response.ok) throw new Error(`Relay returned ${response.status}`);
  console.log(`sent ${results.length} configured point results at ${new Date().toISOString()}`);
  await sendSnmp();
}

async function monitorOnce() {
  const runId = monitorRunId;
  // Freeze the inputs for this cycle. A concurrency change replaces the
  // shared configuration while a cycle may still be awaiting ping results;
  // reading the mutable arrays below would then produce mixed totals/batches.
  // Ưu tiên điểm chưa có kết quả, sau đó điểm mất kết nối. Các điểm cùng
  // nhóm vẫn được xoay vòng để không có endpoint nào bị cố định ở cuối.
  const priority = (point) => {
    const status = lastObservedStatuses.get(point.pointId);
    return status === undefined ? 0 : status === "offline" ? 1 : 2;
  };
  const cycleConcurrency = monitorConcurrency;
  // Khi vừa bật hoặc vừa nhận cấu hình mới, phải gửi kết quả của toàn bộ
  // vòng đầu tiên, kể cả khi trạng thái trùng với cache cũ. Nếu lọc thay đổi
  // theo từng batch, các endpoint ở cuối vòng có thể mãi giữ unknown trên UI.
  const sendAllResults = monitorInitialCyclePending;
  const grouped = monitorPoints.slice().sort((a, b) => priority(a) - priority(b));
  const cyclePoints = grouped.length ? grouped.slice(monitorRotation % grouped.length).concat(grouped.slice(0, monitorRotation % grouped.length)) : grouped;
  monitorRotation = (monitorRotation + cycleConcurrency) % Math.max(1, cyclePoints.length);
  let total = 0;
  for (let offset = 0; offset < cyclePoints.length; offset += cycleConcurrency) {
    if (runId !== monitorRunId) return;
    const results = await Promise.all(cyclePoints.slice(offset, offset + cycleConcurrency).map(ping));
    for (const item of results) lastObservedStatuses.set(item.pointId, item.status);
    // Điểm trung tâm là endpoint bắt buộc của HNTH. Gửi lại điểm này ở mỗi
    // vòng để không bị giữ "Chưa xác định" nếu frontend/backend vừa khởi
    // động lại hoặc cache trạng thái cũ chưa đồng bộ.
    const changedResults = sendAllResults
      ? results
      : results.filter((item) => item.pointId === "hnth-hub" || lastSentStatuses.get(item.pointId) !== item.status);
    const batch = { start: offset + 1, end: offset + results.length, total: cyclePoints.length, concurrency: cycleConcurrency, sentAt: new Date().toISOString(), allResults: results };
    if (!changedResults.length) {
      console.log(`[${batch.sentAt}] monitoring batch ${offset + 1}-${offset + results.length}/${cyclePoints.length} with ${cycleConcurrency} concurrent pings: no status changes`);
      for (const item of results) console.log(`- ${item.name || item.pointId} : ${item.ipAddress || "Chưa có IP"} : ${item.status}`);
      continue;
    }
    const response = await backendFetch(telemetryUrl, { method: "POST", headers: authHeaders(), body: JSON.stringify({ agentId: config.agentId, timestamp: batch.sentAt, results: changedResults, monitorBatch: batch }) });
    if (!response.ok) throw new Error(`Relay monitor upload returned ${response.status}`);
    total += results.length;
    for (const item of changedResults) lastSentStatuses.set(item.pointId, item.status);
    console.log(`[${batch.sentAt}] monitoring batch ${offset + 1}-${offset + results.length}/${cyclePoints.length} with ${cycleConcurrency} concurrent pings`);
    for (const item of results) console.log(`- ${item.name || item.pointId} : ${item.ipAddress || "Chưa có IP"} : ${item.status}`);
  }
  monitorInitialCyclePending = false;
  return total;
}

async function monitorLoop() {
  const runId = ++monitorRunId;
  while (runId === monitorRunId && monitorPoints.length > 0) {
    await monitorOnce();
    if (runId !== monitorRunId) return;
    await new Promise((resolve) => { monitorTimer = setTimeout(resolve, monitorWaitSeconds * 1000); });
  }
}

function expandSubnet(cidr) {
  const [base, prefixText] = cidr.split("/");
  const prefix = Number(prefixText);
  if (prefix < 24 || prefix > 30) throw new Error(`Only /24-/30 scan subnets are supported: ${cidr}`);
  const octets = base.split(".").map(Number);
  const size = 2 ** (32 - prefix);
  const hostCount = Math.max(1, size - 2);
  const start = octets[3] & (256 - size);
  return Array.from({ length: hostCount }, (_, index) => `${octets[0]}.${octets[1]}.${octets[2]}.${start + index + 1}`);
}

async function scanLocalNetwork(scanSubnets = config.scanSubnets || []) {
  const targets = scanSubnets.flatMap(expandSubnet);
  const ips = [];
  const concurrency = numeric(config.scanConcurrency, 32, 1, 128);
  const delayMs = numeric(config.scanDelayMs, 0, 0, 60000);
  for (let offset = 0; offset < targets.length; offset += concurrency) {
    const batch = targets.slice(offset, offset + concurrency);
    const results = await Promise.all(batch.map(async (ipAddress) => {
      try {
        const args = process.platform === "win32" ? ["-n", "1", "-w", "500", ipAddress] : ["-c", "1", "-W", "1", ipAddress];
        await exec(process.platform === "win32" ? "ping.exe" : "ping", args, { windowsHide: true });
        return { ipAddress, status: "online", ...(await networkIdentity(ipAddress)), discoveredAt: new Date().toISOString() };
      } catch { return null; }
    }));
    ips.push(...results.filter(Boolean));
    if (delayMs && offset + concurrency < targets.length) await sleep(delayMs);
  }
  const target = new URL(apiBase ? apiUrl("/api/telemetry/discovered-ips") : config.relayUrl);
  target.pathname = "/api/telemetry/discovered-ips";
  const response = await backendFetch(target, { method: "POST", headers: authHeaders(), body: JSON.stringify({ agentId: config.agentId, ips }) });
  if (!response.ok) throw new Error(`Relay scan upload returned ${response.status}`);
  console.log(`uploaded ${ips.length} discovered LAN IPs to relay at ${new Date().toISOString()}`);
}

async function pollCommands() {
  const target = apiBase ? apiUrl(`/api/agents/${encodeURIComponent(config.agentId)}/commands`) : (() => { const value = new URL(config.relayUrl); value.pathname = `/api/agents/${encodeURIComponent(config.agentId)}/commands`; return value; })();
  const response = await backendFetch(target, { headers: apiBase ? authHeaders() : undefined });
  if (!response.ok) return;
  const command = await response.json();
  if (command.type === "agent-config") {
    const seconds = Math.max(5, Math.min(30, Number(command.heartbeatSeconds) || 30));
    clearInterval(heartbeatTimer);
    heartbeatTimer = setInterval(() => void sendHeartbeat().catch((error) => console.error(error.message)), seconds * 1000);
    for (const key of ["scanSubnets", "scanConcurrency", "scanDelayMs", "scanScheduleSeconds", "probeCount", "probeIntervalMs", "snmpTargets", "points"]) if (command[key] !== undefined) config[key] = command[key];
    if (command.token) config.token = String(command.token);
    await persistConfig();
    configureSchedule();
    console.log(`agent configuration updated and saved to ${configPath}: heartbeat every ${seconds}s${command.token ? "; token changed" : ""}`);
  }
  if (command.type === "agent-update") {
    try {
      if (!command.url || !command.sha256 || !command.version) throw new Error("agent-update requires url, sha256 and version");
      if (!process.versions.electron || process.platform !== "win32") throw new Error("remote update requires the packaged Windows Agent");
      if (command.fileName && !String(command.fileName).toLowerCase().endsWith(".exe")) throw new Error("remote update must be an .exe file");
      const response = await backendFetch(command.url, { headers: { authorization: `Bearer ${config.token}` } });
      if (!response.ok) throw new Error(`Update download returned ${response.status}`);
      const contentLength = Number(response.headers.get("content-length") || 0);
      if (contentLength > 250 * 1024 * 1024) throw new Error("Update file is too large (max 250 MB)");
      const bytes = Buffer.from(await response.arrayBuffer());
      if (bytes.length > 250 * 1024 * 1024) throw new Error("Update file is too large (max 250 MB)");
      const digest = createHash("sha256").update(bytes).digest("hex");
      if (digest.toLowerCase() !== String(command.sha256).toLowerCase()) throw new Error("Update SHA-256 mismatch; file was not staged");
      const updateDir = path.join(path.dirname(String(configPath)), "updates");
      await mkdir(updateDir, { recursive: true });
      const filePath = path.join(updateDir, `agent-${String(command.version).replace(/[^a-zA-Z0-9._-]/g, "_")}.exe`);
      await writeFile(filePath, bytes);
      const resultFile = updateResultPath;
      // Electron Portable runs from a temporary extracted executable. Replace and
      // relaunch the original portable file, not process.execPath.
      const portableDir = process.env.PORTABLE_EXECUTABLE_DIR || path.dirname(process.execPath);
      const portableName = process.env.PORTABLE_EXECUTABLE_APP_FILENAME || path.basename(process.env.PORTABLE_EXECUTABLE_FILE || process.execPath);
      const targetExe = process.env.PORTABLE_EXECUTABLE_FILE || path.join(portableDir, portableName);
      const updater = spawn(process.execPath, ["--hnth-apply-update", "--target-pid", String(process.pid), "--target-exe", targetExe, "--staged-file", filePath, "--result-file", resultFile, "--updated-version", String(command.version)], { detached: true, stdio: "ignore", windowsHide: true });
      updater.unref();
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
  if (command.type === "scan-local-network") await scanLocalNetwork(command.scanSubnets);
  if (command.type === "test-point") {
    const result = await ping({ pointId: command.pointId, ipAddress: command.ipAddress });
    const upload = await backendFetch(telemetryUrl, { method: "POST", headers: authHeaders(), body: JSON.stringify({ agentId: config.agentId, timestamp: new Date().toISOString(), results: [result] }) });
    if (!upload.ok) throw new Error(`Relay test upload returned ${upload.status}`);
    console.log(`tested ${command.pointId} ${command.ipAddress}: ${result.status}`);
  }
  if (command.type === "point-config") {
    const existing = monitorPoints.find((point) => point.pointId === command.pointId);
    monitorPoints = existing
      ? monitorPoints.map((point) => point.pointId === command.pointId ? { ...point, ipAddress: command.ipAddress } : point)
      : [...monitorPoints, { pointId: command.pointId, ipAddress: command.ipAddress }];
    lastSentStatuses.delete(command.pointId);
    console.log(`${existing ? "updated" : "added"} ${command.pointId} IP to ${command.ipAddress}; ${monitorPoints.length} monitoring points`);
    if (command.forceTest !== false) {
      const result = await ping({ pointId: command.pointId, ipAddress: command.ipAddress });
      lastObservedStatuses.set(command.pointId, result.status);
      const upload = await backendFetch(telemetryUrl, { method: "POST", headers: authHeaders(), body: JSON.stringify({ agentId: config.agentId, timestamp: result.checkedAt, results: [result] }) });
      if (!upload.ok) throw new Error(`IP update test upload returned ${upload.status}`);
      lastSentStatuses.set(command.pointId, result.status);
      console.log(`tested updated IP ${command.pointId} ${command.ipAddress}: ${result.status}`);
    }
  }
  if (command.type === "monitor-start") {
    const previousConcurrency = monitorConcurrency;
    const previousWaitSeconds = monitorWaitSeconds;
    monitorRunId += 1;
    monitoringActive = true;
    monitorPoints = (command.points || []).map((point) => ({ ...point, name: point.name || point.pointId }));
    lastSentStatuses.clear();
    lastObservedStatuses.clear();
    monitorInitialCyclePending = true;
    monitorRotation = 0;
    monitorConcurrency = command.concurrency || 1;
    monitorWaitSeconds = command.waitSeconds || 3;
    clearTimeout(monitorTimer);
    console.log(`continuous monitoring started/updated: reset status cache${command.resetStatuses ? " and restarting from unknown" : ""}; ${monitorConcurrency} concurrent pings, ${monitorWaitSeconds}s wait after each cycle${previousConcurrency === monitorConcurrency ? "" : ` (was ${previousConcurrency} concurrent)`}${previousWaitSeconds === monitorWaitSeconds ? "" : ` (was ${previousWaitSeconds}s wait)`}; ${monitorPoints.length} points`);
    void monitorLoop().catch((error) => console.error(error.message));
  }
  if (command.type === "monitor-stop") {
    monitoringActive = false;
    monitorRunId += 1;
    clearTimeout(monitorTimer);
    monitorTimer = undefined;
    monitorPoints = [];
    console.log("continuous monitoring stopped");
  }
}

async function sendHeartbeat() {
  if (!apiBase) return;
  const response = await backendFetch(apiUrl("/api/agents/heartbeat"), { method: "POST", headers: authHeaders(), body: JSON.stringify({ agentId: config.agentId, machineId: config.machineId, version: runtimeVersion, sentAt: new Date().toISOString() }) });
  if (!response.ok) throw new Error(`Backend heartbeat returned ${response.status}`);
}

async function register() {
  if (!apiBase) return;
  const response = await backendFetch(apiUrl("/api/agents/register"), { method: "POST", headers: authHeaders(), body: JSON.stringify({ agentId: config.agentId, machineId: config.machineId, name: config.agentName || config.agentId, version: runtimeVersion }) });
  if (!response.ok) throw new Error(`Backend registration returned ${response.status}`);
  console.log(`registered agent ${config.agentId} with backend`);
}

await ensureInstallationIdentity().catch((error) => console.error(`installation identity check failed: ${error.message}`));
await reportPendingUpdate();
await register().catch((error) => console.error(error.message));
await sendHeartbeat().catch((error) => console.error(error.message));
await scanAndSend().catch((error) => console.error(error.message));
setInterval(() => void scanAndSend().catch((error) => console.error(error.message)), config.intervalMs || 30000);
setInterval(() => void pollCommands().catch((error) => console.error(error.message)), 3000);
// Heartbeat định kỳ 30 giây để backend và giao diện nhận biết Agent kịp thời.
heartbeatTimer = setInterval(() => void sendHeartbeat().catch((error) => console.error(error.message)), 30000);
configureSchedule();
