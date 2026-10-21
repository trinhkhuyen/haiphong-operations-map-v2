// E2E hợp đồng API của hnth-backend với agent thật. Ghi lại hành vi hiện tại để
// các bước refactor backend/agent (GĐ2–3) chứng minh không đổi hành vi.
// Chạy: pnpm test:e2e  (cần Postgres local; không có thì cả bộ được skip).
import { after, before, describe, it } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { cpSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { apiClient, BACKEND_DIR, DATABASE_URL, fakeExe, freePort, pg, startAgent, startNode, waitFor, withSearchPath } from "./helpers.mjs";

const AGENT_TOKEN = "e2e-shared-agent-token-123456";
const ADMIN = { username: "admin", password: "e2e-admin-pass-123" };
const schema = `hnth_e2e_${process.pid}`;

// Không có Postgres thì skip cả bộ thay vì báo đỏ (máy chưa dựng DB local).
const admin = new pg.Client({ connectionString: DATABASE_URL });
let skipReason = false;
try { await admin.connect(); } catch (error) { skipReason = `Không kết nối được Postgres (${DATABASE_URL.replace(/:[^:@/]+@/, ":***@")}): ${error.message}`; }

describe("hnth-backend e2e", { skip: skipReason }, () => {
  const tmp = mkdtempSync(path.join(os.tmpdir(), "hnth-e2e-"));
  const agents = [];
  let backend;
  let api;
  let db;
  let adminToken;
  const agentDir = (name) => path.join(tmp, "agents", name);
  const readConfig = (name) => JSON.parse(readFileSync(path.join(agentDir(name), "config.json"), "utf8"));
  const runAgent = (name, config) => { const handle = startAgent(agentDir(name), config); agents.push(handle); return handle; };
  const template = (agentId) => ({ agentId, agentName: `E2E ${agentId}`, backendUrl: "", token: AGENT_TOKEN, intervalMs: 600000, scanSubnets: [], points: [] });
  const monitorState = async () => (await api("GET", "/api/hnth/monitor-state")).body;
  const commands = async (agentId, type) => (await db.query("SELECT status,payload FROM commands WHERE agent_id=$1 AND type=$2 ORDER BY created_at", [agentId, type])).rows;
  let baseUrl;

  before(async () => {
    await admin.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE; CREATE SCHEMA ${schema}`);
    const port = await freePort();
    baseUrl = `http://127.0.0.1:${port}`;
    api = apiClient(baseUrl);
    backend = startNode(path.join(BACKEND_DIR, "src", "server.mjs"), {
      cwd: BACKEND_DIR,
      env: {
        PORT: String(port), DATABASE_URL: withSearchPath(DATABASE_URL, schema), HNTH_AGENT_TOKEN: AGENT_TOKEN, JWT_SECRET: "e2e-jwt-secret",
        ADMIN_USERNAME: ADMIN.username, ADMIN_PASSWORD: ADMIN.password, HNTH_DEFAULT_AGENT_ID: "agent-a",
        HNTH_RELEASE_DIR: path.join(tmp, "releases"), WEB_ORIGIN: "http://127.0.0.1:5173",
      },
    });
    await waitFor(async () => (await api("GET", "/health")).status === 200, { message: `backend /health\n${backend.output()}` });
    db = new pg.Client({ connectionString: withSearchPath(DATABASE_URL, schema) });
    await db.connect();
    adminToken = (await api("POST", "/api/auth/login", { body: ADMIN })).body.accessToken;
    assert.ok(adminToken, "admin login");
  });

  after(async () => {
    await Promise.all(agents.map((agent) => agent.stop()));
    await backend?.stop();
    await db?.end().catch(() => {});
    await admin.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`).catch(() => {});
    await admin.end().catch(() => {});
    rmSync(tmp, { recursive: true, force: true });
  });

  it("1. endpoint công khai và chặn truy cập không có quyền", async () => {
    assert.deepEqual((await api("GET", "/health")).body, { ok: true, service: "hnth-backend", database: "ok" });
    const state = await monitorState();
    assert.equal(state.monitoring.agentId, "agent-a");
    assert.ok(Array.isArray(state.results) && Array.isArray(state.agents));
    assert.equal((await api("GET", "/api/agents")).status, 401);
    assert.equal((await api("POST", "/api/telemetry/ping-results", { token: "sai-token", body: { agentId: "agent-a", results: [] } })).status, 401);
    assert.equal((await api("GET", "/api/khong-ton-tai", { token: adminToken })).status, 404);
  });

  it("2. đăng nhập, me, refresh xoay token, logout", async () => {
    assert.equal((await api("POST", "/api/auth/login", { body: { ...ADMIN, password: "sai" } })).status, 401);
    const login = await api("POST", "/api/auth/login", { body: ADMIN });
    assert.equal(login.status, 200);
    assert.equal(login.body.user.role, "admin");
    const cookie = login.headers.get("set-cookie").split(";")[0];
    assert.match(cookie, /^hnth_refresh=/);
    assert.equal((await api("GET", "/api/auth/me", { token: login.body.accessToken })).body.username, "admin");
    const refreshed = await api("POST", "/api/auth/refresh", { headers: { cookie } });
    assert.equal(refreshed.status, 200);
    const rotated = refreshed.headers.get("set-cookie").split(";")[0];
    assert.notEqual(rotated, cookie);
    assert.equal((await api("POST", "/api/auth/refresh", { headers: { cookie } })).status, 401, "refresh cũ đã bị thu hồi");
    assert.equal((await api("POST", "/api/auth/logout", { headers: { cookie: rotated } })).status, 200);
    assert.equal((await api("POST", "/api/auth/refresh", { headers: { cookie: rotated } })).status, 401);
  });

  it("3. quản lý user và phân quyền viewer", async () => {
    const created = await api("POST", "/api/users", { token: adminToken, body: { username: "viewer1", displayName: "Viewer", role: "viewer", password: "viewer-pass-1" } });
    assert.equal(created.status, 201);
    assert.equal((await api("POST", "/api/users", { token: adminToken, body: { username: "viewer1", displayName: "Viewer", role: "viewer", password: "viewer-pass-1" } })).status, 409);
    const viewerToken = (await api("POST", "/api/auth/login", { body: { username: "viewer1", password: "viewer-pass-1" } })).body.accessToken;
    assert.equal((await api("GET", "/api/users", { token: viewerToken })).status, 403);
    assert.equal((await api("POST", "/api/hnth/scan", { token: viewerToken, body: {} })).status, 403);
    assert.equal((await api("DELETE", `/api/users/${created.body.id}`, { token: adminToken })).status, 200);
    assert.equal((await api("POST", "/api/auth/login", { body: { username: "viewer1", password: "viewer-pass-1" } })).status, 401);
  });

  it("4. định danh agent: bản gốc giữ id, bản copy và bản mẫu trùng id được cấp id riêng", async () => {
    runAgent("a", { ...template("agent-a"), backendUrl: baseUrl });
    await waitFor(() => readConfig("a").installationId, { message: "agent A lưu installationId" });
    assert.equal(readConfig("a").agentId, "agent-a");

    cpSync(agentDir("a"), agentDir("b"), { recursive: true });
    const b = runAgent("b");
    const configB = await waitFor(() => { const config = readConfig("b"); return config.agentId !== "agent-a" && config; }, { message: "bản copy B nhận id mới" });
    assert.notEqual(configB.token, AGENT_TOKEN, "B có token riêng");
    assert.notEqual(configB.installationId, readConfig("a").installationId);

    runAgent("c", { ...template("agent-a"), backendUrl: baseUrl });
    const configC = await waitFor(() => { const config = readConfig("c"); return config.agentId !== "agent-a" && config; }, { message: "bản mẫu C trùng id được cấp id mới" });
    assert.notEqual(configC.agentId, configB.agentId);

    await b.stop();
    const b2 = runAgent("b");
    await waitFor(() => b2.output().includes(`registered agent ${configB.agentId}`), { message: "B chạy lại đăng ký đúng id cũ" });
    assert.equal(readConfig("b").agentId, configB.agentId);

    const ids = (await monitorState()).agents.map((agent) => agent.agentId).sort();
    assert.deepEqual(ids, ["agent-a", configB.agentId, configC.agentId].sort());
  });

  it("5. chọn agent cho HNTH được lưu và dùng làm mặc định", async () => {
    const agentB = readConfig("b").agentId;
    assert.equal((await api("POST", "/api/hnth/selected-agent", { token: adminToken, body: { agentId: "khong-ton-tai" } })).status, 404);
    assert.equal((await api("POST", "/api/hnth/selected-agent", { token: adminToken, body: { agentId: agentB } })).status, 200);
    assert.equal((await monitorState()).monitoring.agentId, agentB);
    assert.equal((await api("GET", "/api/agent-status")).body.agentId, agentB);
    assert.equal((await api("POST", "/api/hnth/selected-agent", { token: adminToken, body: { agentId: "agent-a" } })).status, 200);
  });

  it("6. bật/tắt giám sát gửi lệnh tới đúng agent; đang giám sát thì không đổi agent", async () => {
    const points = [{ pointId: "hnth-e2e-1", name: "Loopback", ipAddress: "127.0.0.1" }];
    assert.equal((await api("POST", "/api/hnth/monitor", { token: adminToken, body: { enabled: true, agentId: "agent-a", concurrency: 1, waitSeconds: 1, points } })).status, 202);
    const state = await monitorState();
    assert.equal(state.monitoring.enabled, true);
    await waitFor(async () => (await commands("agent-a", "monitor-start")).some((row) => row.status === "claimed"), { message: "agent A nhận monitor-start" });
    const agentA = agents[0];
    await waitFor(() => agentA.output().includes("continuous monitoring started"), { message: "log agent A bắt đầu giám sát" });
    assert.equal((await api("POST", "/api/hnth/selected-agent", { token: adminToken, body: { agentId: readConfig("b").agentId } })).status, 409);
    await waitFor(async () => (await monitorState()).results.find((row) => row.pointId === "hnth-e2e-1" && row.status !== "unknown"), { timeout: 30000, message: "kết quả ping 127.0.0.1" });
    assert.equal((await api("POST", "/api/hnth/monitor", { token: adminToken, body: { enabled: false, agentId: "agent-a", points } })).status, 202);
    await waitFor(() => agentA.output().includes("continuous monitoring stopped"), { message: "log agent A dừng giám sát" });
    assert.equal((await monitorState()).monitoring.enabled, false);
  });

  it("7. phát hành bản cập nhật: tự đọc version, lệnh dùng đường dẫn tương đối, agent báo kết quả", async () => {
    const exe = fakeExe("9.9.9");
    const upload = await api("POST", "/api/agent-releases?fileName=Agent.exe", { token: adminToken, raw: exe, headers: { "content-type": "application/octet-stream" } });
    assert.equal(upload.status, 201);
    assert.equal(upload.body.version, "9.9.9");
    assert.equal(upload.body.sha256, createHash("sha256").update(exe).digest("hex"));
    assert.equal((await api("POST", "/api/agent-releases?fileName=Agent.exe&version=1.0.0", { token: adminToken, raw: exe, headers: { "content-type": "application/octet-stream" } })).status, 400);
    assert.equal((await api("POST", "/api/agent-releases?fileName=Agent.exe", { token: adminToken, raw: Buffer.alloc(100), headers: { "content-type": "application/octet-stream" } })).status, 400);

    assert.equal((await api("GET", "/api/agent-releases/9.9.9?agentId=agent-a")).status, 401);
    const download = await api("GET", "/api/agent-releases/9.9.9?agentId=agent-a", { token: AGENT_TOKEN });
    assert.equal(download.status, 200);
    assert.ok(Buffer.compare(download.body, exe) === 0);

    assert.equal((await api("POST", "/api/agents/agent-a/commands", { token: adminToken, body: { type: "agent-update", version: "0.0.1" } })).status, 404);
    assert.equal((await api("POST", "/api/agents/agent-a/commands", { token: adminToken, body: { type: "agent-update", version: "9.9.9", url: "http://evil.example/x.exe", sha256: "x" } })).status, 202);
    const [command] = (await commands("agent-a", "agent-update")).slice(-1);
    assert.equal(command.payload.path, "/api/agent-releases/9.9.9?agentId=agent-a");
    assert.equal(command.payload.sha256, upload.body.sha256);
    assert.equal(command.payload.url, undefined, "không dùng URL do client gửi");
    // Agent chạy bằng node (không phải bản Electron đóng gói) phải từ chối và báo failed.
    const event = await waitFor(async () => (await db.query("SELECT status,detail FROM agent_update_events WHERE agent_id='agent-a' AND version='9.9.9'")).rows[0], { message: "agent A báo kết quả cập nhật" });
    assert.equal(event.status, "failed");
    assert.match(event.detail, /packaged Windows Agent/);
    const listed = (await api("GET", "/api/agents", { token: adminToken })).body.find((agent) => agent.agentId === "agent-a");
    assert.equal(listed.lastUpdate.status, "failed");
  });

  it("8. telemetry: endpoint có IP rỗng luôn unknown", async () => {
    const response = await api("POST", "/api/telemetry/ping-results", { token: AGENT_TOKEN, body: { agentId: "agent-a", results: [{ pointId: "hnth-e2e-empty", ipAddress: "", status: "online" }, { pointId: "hnth-e2e-2", ipAddress: "10.255.255.1", status: "offline", latencyMs: null }] } });
    assert.equal(response.status, 202);
    const results = (await monitorState()).results;
    assert.equal(results.find((row) => row.pointId === "hnth-e2e-empty").status, "unknown");
    assert.equal(results.find((row) => row.pointId === "hnth-e2e-2").status, "offline");
  });
});
