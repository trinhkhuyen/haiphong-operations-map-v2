// Unit test cho phần thuần của Agent (không ping, không mạng, không ghi file).
import { describe, it } from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import { createBackendClient } from "../src/backend-client.mjs";
import { applyAgentConfig } from "../src/config.mjs";
import { installationIdFor, isCopiedInstallation } from "../src/identity.mjs";
import { createMonitor, orderCyclePoints, resultsToSend } from "../src/monitor.mjs";
import { isPingTarget, pingArgs, pingHost, summarizeSamples } from "../src/probes/ping.mjs";
import { expandSubnet, vendorFromMac } from "../src/probes/scan.mjs";
import { ber, berInteger, berOid, collectBer, parseSnmpResponse, snmpPacket } from "../src/probes/snmp.mjs";

describe("probes/scan", () => {
  it("expandSubnet: /24 bỏ địa chỉ mạng và broadcast", () => {
    const hosts = expandSubnet("192.168.1.77/24");
    assert.equal(hosts.length, 254);
    assert.equal(hosts[0], "192.168.1.1");
    assert.equal(hosts.at(-1), "192.168.1.254");
  });
  it("expandSubnet: /30 căn theo biên subnet", () => {
    assert.deepEqual(expandSubnet("10.0.0.6/30"), ["10.0.0.5", "10.0.0.6"]);
    assert.deepEqual(expandSubnet("10.0.0.9/29"), ["10.0.0.9", "10.0.0.10", "10.0.0.11", "10.0.0.12", "10.0.0.13", "10.0.0.14"]);
  });
  it("expandSubnet: chỉ nhận /24-/30", () => {
    assert.throws(() => expandSubnet("10.0.0.0/23"), /Only \/24-\/30/);
    assert.throws(() => expandSubnet("10.0.0.0/31"), /Only \/24-\/30/);
  });
  it("vendorFromMac: tra OUI, chấp nhận cả '-' và ':'", () => {
    assert.equal(vendorFromMac("00-15-65-AA-BB-CC"), "Yealink");
    assert.equal(vendorFromMac("B8:27:EB:00:11:22"), "Raspberry Pi");
    assert.equal(vendorFromMac("12-34-56-78-9A-BC"), "");
  });
});

describe("probes/ping", () => {
  it("chỉ literal IP mới được đưa vào ping", async () => {
    assert.equal(isPingTarget("10.1.2.3"), true);
    assert.equal(isPingTarget("fe80::1"), true);
    for (const value of ["", "-t", "-n 100 10.1.2.3", "10.1.2.3 -t", "host.local", "999.1.1.1", undefined]) assert.equal(isPingTarget(value), false, String(value));
    await assert.rejects(pingHost("-t", 100), /not an IP address/);
  });
  it("tham số ping theo nền tảng", () => {
    assert.deepEqual(pingArgs("win32", "10.0.0.1", 1000), ["-n", "1", "-w", "1000", "10.0.0.1"]);
    assert.deepEqual(pingArgs("linux", "10.0.0.1", 1000), ["-c", "1", "-W", "1", "10.0.0.1"]);
  });
  it("tổng hợp latency/loss/jitter và trạng thái theo hnth-protocol", () => {
    assert.deepEqual(summarizeSamples([10, 20, 30, 20], 4), { status: "online", latencyMs: 20, packetLossPct: 0, jitterMs: 10 });
    assert.deepEqual(summarizeSamples([10, 14], 4), { status: "unknown", latencyMs: 12, packetLossPct: 50, jitterMs: 4 });
    assert.deepEqual(summarizeSamples([7], 4), { status: "offline", latencyMs: 7, packetLossPct: 75, jitterMs: 0 });
    assert.deepEqual(summarizeSamples([], 3), { status: "offline", latencyMs: null, packetLossPct: 100, jitterMs: 0 });
  });
});

describe("probes/snmp (BER)", () => {
  it("mã hóa INTEGER và OID", () => {
    assert.equal(berInteger(0).toString("hex"), "020100");
    assert.equal(berInteger(1).toString("hex"), "020101");
    assert.equal(berInteger(0x1234).toString("hex"), "02021234");
    assert.equal(berOid("1.3.6.1.2.1.1.1.0").toString("hex"), "06082b06010201010100");
    // Thành phần >127 dùng nhiều byte base-128 (enterprise 2011 = 0x8f 0x5b).
    assert.equal(berOid("1.3.6.1.4.1.2011").toString("hex"), "06072b060104018f5b");
  });
  it("GetRequest v2c đúng từng byte", () => {
    assert.equal(snmpPacket("public", "1.3.6.1.2.1.1.1.0", 1).toString("hex"),
      "30260201010406" + "7075626c6963" + "a019020101020100020100300e300c06082b060102010101000500");
  });
  it("collectBer duyệt cả phần tử lồng nhau", () => {
    const types = collectBer(snmpPacket("public", "1.3.6.1.2.1.1.1.0", 1)).map((item) => item.type);
    assert.deepEqual(types, [0x30, 0x02, 0x04, 0xa0, 0x02, 0x02, 0x02, 0x30, 0x30, 0x06, 0x05]);
  });
  const response = (value) => ber(0x30, Buffer.concat([berInteger(1), ber(0x04, Buffer.from("public")), ber(0xa2, Buffer.concat([berInteger(7), berInteger(0), berInteger(0), ber(0x30, ber(0x30, Buffer.concat([berOid("1.3.6.1.2.1.1.1.0"), value])))]))]));
  it("đọc giá trị OCTET STRING (bỏ qua community)", () => {
    assert.deepEqual(parseSnmpResponse(response(ber(0x04, Buffer.from("Cisco IOS"))), "public"), { value: "Cisco IOS", valueType: "unknown" });
  });
  it("đọc kiểu ứng dụng (TimeTicks 0x43)", () => {
    assert.equal(parseSnmpResponse(response(ber(0x43, Buffer.from([0x01, 0x02]))), "public").valueType, "0x43");
  });
});

describe("monitor", () => {
  const points = ["a", "b", "c", "d"].map((pointId) => ({ pointId }));
  const observed = new Map([["a", "online"], ["b", "offline"], ["d", "online"]]);
  it("ưu tiên điểm chưa có kết quả, rồi điểm mất kết nối, rồi xoay vòng", () => {
    assert.deepEqual(orderCyclePoints(points, observed, 0).map((point) => point.pointId), ["c", "b", "a", "d"]);
    assert.deepEqual(orderCyclePoints(points, observed, 1).map((point) => point.pointId), ["b", "a", "d", "c"]);
    assert.deepEqual(orderCyclePoints(points, observed, 6).map((point) => point.pointId), ["a", "d", "c", "b"]);
    assert.deepEqual(orderCyclePoints([], observed, 3), []);
  });
  it("chỉ gửi kết quả đổi trạng thái, luôn gửi hnth-hub; vòng đầu gửi tất cả", () => {
    const results = [{ pointId: "a", status: "online" }, { pointId: "b", status: "offline" }, { pointId: "hnth-hub", status: "online" }];
    const lastSent = new Map([["a", "online"], ["b", "online"], ["hnth-hub", "online"]]);
    assert.deepEqual(resultsToSend(results, lastSent, false).map((item) => item.pointId), ["b", "hnth-hub"]);
    assert.equal(resultsToSend(results, lastSent, true), results);
  });
  it("upload lỗi không làm chết vòng; mất backend quá ngưỡng thì tự dừng", async () => {
    let since = 0;
    let uploads = 0;
    const client = { telemetryUrl: "http://backend.invalid", msSinceContact: () => since, postJson: async () => { uploads += 1; throw new Error("ECONNREFUSED"); } };
    const monitor = createMonitor({ config: { agentId: "t", probeCount: 1 }, client, backendLossStopMs: 1000 });
    monitor.start({ points: [{ pointId: "p1", ipAddress: "" }], waitSeconds: 1 });
    await new Promise((resolve) => setTimeout(resolve, 1300));
    assert.ok(uploads >= 2, "vòng vẫn chạy tiếp sau upload lỗi");
    assert.equal(monitor.isActive(), true);
    since = 5000;
    await new Promise((resolve) => setTimeout(resolve, 1300));
    assert.equal(monitor.isActive(), false, "tự dừng khi mất backend");
    const after = uploads;
    await new Promise((resolve) => setTimeout(resolve, 1300));
    assert.equal(uploads, after, "đã dừng hẳn, không ping/gửi ngầm");
  });
});

describe("identity", () => {
  // Đường dẫn theo hệ điều hành đang chạy test (CI là Linux, Agent thật chạy Windows).
  it("installationId phụ thuộc máy và thư mục config, không phân biệt hoa thường", () => {
    const a = installationIdFor("guid-1", path.join("C:", "Agent", "config.json"));
    assert.match(a, /^[0-9a-f]{32}$/);
    assert.equal(installationIdFor("guid-1", path.join("C:", "AGENT", "config.json")), a);
    assert.notEqual(installationIdFor("guid-1", path.join("C:", "Agent2", "config.json")), a);
    assert.notEqual(installationIdFor("guid-2", path.join("C:", "Agent", "config.json")), a);
  });
  it("phát hiện bản copy theo installationId, hoặc machineId với config cũ", () => {
    const current = { machineId: "m1", installationId: "i1" };
    assert.equal(isCopiedInstallation({}, current), false);
    assert.equal(isCopiedInstallation({ installationId: "i1", machineId: "other" }, current), false);
    assert.equal(isCopiedInstallation({ installationId: "i2" }, current), true);
    assert.equal(isCopiedInstallation({ machineId: "m1" }, current), false);
    assert.equal(isCopiedInstallation({ machineId: "m2" }, current), true);
  });
});

describe("config", () => {
  it("agent-config chỉ nhận các khóa cho phép, giới hạn heartbeat 5-30 giây", () => {
    const config = { agentId: "x", token: "old", points: [] };
    const result = applyAgentConfig(config, { type: "agent-config", heartbeatSeconds: 2, points: [{ pointId: "p" }], agentId: "hijack", token: 123 });
    assert.deepEqual(result, { heartbeatSeconds: 5, tokenChanged: true });
    assert.deepEqual(config, { agentId: "x", token: "123", points: [{ pointId: "p" }] });
    assert.equal(applyAgentConfig(config, { heartbeatSeconds: 99 }).heartbeatSeconds, 30);
    assert.deepEqual(applyAgentConfig(config, {}), { heartbeatSeconds: 30, tokenChanged: false });
    assert.equal(config.token, "123");
  });
});

describe("backend-client", () => {
  it("backendUrl: URL API và token đọc tại thời điểm gọi", () => {
    const config = { backendUrl: "http://10.0.0.5:8788", agentId: "agent a", token: "t1" };
    const client = createBackendClient(config);
    assert.equal(client.telemetryUrl, "http://10.0.0.5:8788/api/telemetry/ping-results");
    assert.equal(client.commandsUrl(), "http://10.0.0.5:8788/api/agents/agent%20a/commands");
    assert.equal(String(client.discoveredIpsUrl()), "http://10.0.0.5:8788/api/telemetry/discovered-ips");
    config.token = "t2";
    config.agentId = "agent-b";
    assert.equal(client.authHeaders().authorization, "Bearer t2");
    assert.equal(client.commandsUrl(), "http://10.0.0.5:8788/api/agents/agent-b/commands");
  });
  it("không có backendUrl: đi qua host của relay cũ", () => {
    const client = createBackendClient({ relayUrl: "http://relay:8787/api/telemetry/ping-results", agentId: "a" });
    assert.equal(client.apiBase, null);
    assert.equal(client.telemetryUrl, "http://relay:8787/api/telemetry/ping-results");
    assert.equal(String(client.commandsUrl()), "http://relay:8787/api/agents/a/commands");
    assert.equal(String(client.discoveredIpsUrl()), "http://relay:8787/api/telemetry/discovered-ips");
  });
});
