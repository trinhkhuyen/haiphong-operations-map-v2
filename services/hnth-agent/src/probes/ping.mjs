import net from "node:net";
import { classifyProbeResult } from "@haiphong-ops/hnth-protocol";
import { exec, numeric, sleep } from "../util.mjs";

// Địa chỉ đến từ lệnh test-point chưa được backend kiểm tra; chỉ cho literal IP
// đi vào ping.exe để không chèn được tham số (vd "-t") hay tên máy tùy ý.
export const isPingTarget = (value) => net.isIP(String(value)) !== 0;

export function pingArgs(platform, ipAddress, timeoutMs) {
  return platform === "win32" ? ["-n", "1", "-w", String(timeoutMs), ipAddress] : ["-c", "1", "-W", "1", ipAddress];
}

/** Một gói ICMP; reject khi mất gói hoặc đích không phải IP. */
export async function pingHost(ipAddress, timeoutMs) {
  if (!isPingTarget(ipAddress)) throw new Error(`not an IP address: ${ipAddress}`);
  await exec(process.platform === "win32" ? "ping.exe" : "ping", pingArgs(process.platform, ipAddress, timeoutMs), { windowsHide: true });
}

/** Tổng hợp độ trễ (ms) các gói nhận được thành latency/loss/jitter và trạng thái. */
export function summarizeSamples(samples, count) {
  const packetLossPct = Math.round((1 - samples.length / count) * 10000) / 100;
  const latencyMs = samples.length ? Math.round(samples.reduce((sum, value) => sum + value, 0) / samples.length) : null;
  const jitterMs = samples.length > 1 ? Math.round(samples.slice(1).reduce((sum, value, index) => sum + Math.abs(value - samples[index]), 0) / (samples.length - 1) * 100) / 100 : 0;
  // Ngưỡng online/unknown/offline dùng chung trong hnth-protocol; frontend hiển
  // thị tương ứng Chờ kết nối, Chưa xác định, Mất kết nối.
  return { status: classifyProbeResult(samples.length, count), latencyMs, packetLossPct, jitterMs };
}

export const probeCount = (point, config) => numeric(point.probeCount ?? config.probeCount ?? 4, 4, 1, 10);

export async function ping(point, config) {
  if (!String(point.ipAddress || "").trim()) {
    return { pointId: point.pointId, name: point.name || point.pointId, ipAddress: "", status: "unknown", latencyMs: null, checkedAt: new Date().toISOString() };
  }
  const count = probeCount(point, config);
  const target = String(point.ipAddress).trim();
  const samples = [];
  for (let index = 0; index < count; index += 1) {
    const started = Date.now();
    try {
      await pingHost(target, numeric(point.timeoutMs ?? config.pingTimeoutMs, 1000, 100, 10000));
      samples.push(Date.now() - started);
    } catch { /* packet lost */ }
    if (index + 1 < count) await sleep(numeric(point.probeIntervalMs ?? config.probeIntervalMs, 250, 0, 5000));
  }
  const { status, latencyMs, packetLossPct, jitterMs } = summarizeSamples(samples, count);
  return { pointId: point.pointId, name: point.name || point.pointId, ipAddress: point.ipAddress, status, latencyMs, packetLossPct, jitterMs, probeCount: count, checkedAt: new Date().toISOString() };
}
