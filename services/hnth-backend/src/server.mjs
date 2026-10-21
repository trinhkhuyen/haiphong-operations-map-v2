import http from "node:http";
import crypto from "node:crypto";
import path from "node:path";
import { createReadStream, createWriteStream } from "node:fs";
import { mkdir, unlink, rename, open } from "node:fs/promises";
import { once } from "node:events";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { migrate, pool } from "./db.mjs";

const port = Number(process.env.PORT || 8788);
const jwtSecret = process.env.JWT_SECRET || "local-only-change-this-jwt-secret";
const agentToken = process.env.HNTH_AGENT_TOKEN || "local-hnth-test-7f3c9a2e5d1b";
// Local development uses the agent id from services/hnth-agent/config.json.
// Deployments can override this with HNTH_DEFAULT_AGENT_ID.
const defaultAgent = process.env.HNTH_DEFAULT_AGENT_ID || "agent-demo";
const allowedWebOrigins = (process.env.WEB_ORIGIN || "http://127.0.0.1:5173")
  .split(",")
  .map((origin) => origin.trim())
  .filter(Boolean);
const roleRank = { viewer: 1, operator: 2, admin: 3 };
const sseClients = new Set();
const releaseRoot = path.resolve(process.env.HNTH_RELEASE_DIR || path.join(process.cwd(), "agent-releases"));
const maxReleaseBytes = 250 * 1024 * 1024;
const safeReleaseVersion = (value) => String(value || "").trim().match(/^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/)?.[0] || null;
const safeReleaseFileName = (value) => path.basename(String(value || "agent.exe")).replace(/[^A-Za-z0-9._-]/g, "_");
async function writeRelease(req, filePath) {
  const output = createWriteStream(filePath, { flags: "wx" });
  const digest = crypto.createHash("sha256");
  let size = 0;
  try {
    for await (const chunk of req) {
      size += chunk.length;
      if (size > maxReleaseBytes) throw new Error("release file is too large (max 250 MB)");
      digest.update(chunk);
      if (!output.write(chunk)) await once(output, "drain");
    }
    output.end();
    await once(output, "close");
    return { size, sha256: digest.digest("hex") };
  } catch (error) {
    output.destroy();
    await unlink(filePath).catch(() => {});
    throw error;
  }
}
// Đọc chuỗi ProductVersion (UTF-16LE) trong resource VS_VERSIONINFO của file .exe.
// Với bản portable của electron-builder, resource của launcher nằm trong vài trăm KB
// đầu file, trước phần dữ liệu nén, nên chỉ cần đọc 2 MB đầu.
const productVersionKey = Buffer.from("ProductVersion\0", "utf16le");
async function readExeVersion(filePath) {
  const handle = await open(filePath, "r");
  try {
    const { buffer, bytesRead } = await handle.read(Buffer.alloc(2 * 1024 * 1024), 0, 2 * 1024 * 1024, 0);
    const data = buffer.subarray(0, bytesRead);
    for (let index = data.indexOf(productVersionKey); index >= 0; index = data.indexOf(productVersionKey, index + 1)) {
      let cursor = index + productVersionKey.length;
      cursor += (4 - (cursor % 4)) % 4;
      let value = "";
      for (; cursor + 1 < data.length; cursor += 2) { const code = data.readUInt16LE(cursor); if (!code) break; value += String.fromCharCode(code); }
      const match = value.trim().match(/^\d+\.\d+\.\d+(?:[-.][0-9A-Za-z.-]+)?/);
      if (match) return match[0];
    }
    return null;
  } finally { await handle.close(); }
}
// Agent đang được chọn cho chức năng HNTH, lưu trong monitor_state để mọi client
// (Operator, Guest, cửa sổ Trình chiếu) cùng thấy một agent. Các API không truyền
// agentId đều dùng agent này thay vì HNTH_DEFAULT_AGENT_ID.
async function selectedAgentId() {
  const result = await pool.query("SELECT agent_id FROM monitor_state WHERE id=1");
  return result.rows[0]?.agent_id || defaultAgent;
}
function broadcast(event) { const payload = `data: ${JSON.stringify(event)}\n\n`; for (const client of sseClients) { try { client.write(payload); } catch { sseClients.delete(client); } } }
async function currentRealtimeState() {
  const monitor = await pool.query("SELECT enabled,agent_id AS \"agentId\",concurrency,wait_seconds AS \"waitSeconds\",session_id AS \"sessionId\",started_at AS \"startedAt\",updated_at AS \"updatedAt\",revision FROM monitor_state WHERE id=1");
  const row = monitor.rows[0] || { enabled: false, agentId: defaultAgent, concurrency: 1, waitSeconds: 3, sessionId: null, startedAt: null, updatedAt: null, revision: 0 };
  const [agentConfig, agents] = await Promise.all([
    pool.query("SELECT monitor_config AS \"monitorConfig\" FROM agents WHERE agent_id=$1", [row.agentId]),
    pool.query("SELECT agent_id AS \"agentId\",name,status,last_seen_at AS \"lastSeenAt\",version FROM agents ORDER BY agent_id"),
  ]);
  const configuredPoints = agentConfig.rows[0]?.monitorConfig?.points;
  const assignedPointIds = Array.isArray(configuredPoints)
    ? configuredPoints.map((point) => String(point?.pointId || point?.point_id || "").trim()).filter(Boolean)
    : null;
  const endpoints = assignedPointIds
    ? await pool.query("SELECT endpoint_id AS \"pointId\",name,host(ip_address) AS \"ipAddress\",model_vendor AS \"modelVendor\",status,latency_ms AS \"latencyMs\",packet_loss_pct AS \"packetLossPct\",jitter_ms AS \"jitterMs\",checked_at AS \"checkedAt\" FROM endpoints WHERE enabled=true AND endpoint_id = ANY($1::text[]) ORDER BY endpoint_id", [assignedPointIds])
    : await pool.query("SELECT endpoint_id AS \"pointId\",name,host(ip_address) AS \"ipAddress\",model_vendor AS \"modelVendor\",status,latency_ms AS \"latencyMs\",packet_loss_pct AS \"packetLossPct\",jitter_ms AS \"jitterMs\",checked_at AS \"checkedAt\" FROM endpoints WHERE enabled=true AND endpoint_id LIKE 'hnth-%' ORDER BY endpoint_id");
  const now = Date.now();
  const normalizedAgents = agents.rows.map((agent) => ({ ...agent, status: agent.lastSeenAt && now - new Date(agent.lastSeenAt).getTime() < 30000 ? "online" : "offline" }));
  return { monitoring: row, assignedPointIds, results: endpoints.rows, agents: normalizedAgents };
}
async function broadcastRealtimeState(extra = {}) {
  try { broadcast({ type: "state", ...(await currentRealtimeState()), ...extra }); } catch (error) { console.error(`Realtime state broadcast failed: ${error.message}`); }
}
async function broadcastRealtimeStateTo(client) {
  try { client.write(`data: ${JSON.stringify({ type: "state", ...(await currentRealtimeState()) })}\n\n`); } catch { sseClients.delete(client); }
}
function corsOrigin(req) {
  const origin = String(req.headers.origin || "");
  return allowedWebOrigins.includes("*") ? (origin || "*") : (allowedWebOrigins.includes(origin) ? origin : allowedWebOrigins[0]);
}
const json = (res, status, body, headers = {}, req = null) => { res.writeHead(status, { "content-type": "application/json; charset=utf-8", "cache-control": "no-store, no-cache, must-revalidate", "pragma": "no-cache", "access-control-allow-origin": corsOrigin(req || { headers: {} }), "access-control-allow-credentials": "true", "access-control-allow-headers": "content-type, authorization, x-agent-id", "access-control-allow-methods": "GET,POST,PUT,DELETE,OPTIONS", "vary": "Origin", ...headers }); res.end(JSON.stringify(body)); };
const readJson = (req) => new Promise((resolve, reject) => { let raw = ""; req.on("data", (chunk) => { raw += chunk; if (raw.length > 2_000_000) reject(new Error("body too large")); }); req.on("end", () => { try { resolve(raw ? JSON.parse(raw) : {}); } catch { reject(new Error("invalid json")); } }); req.on("error", reject); });
const hash = (value) => crypto.createHash("sha256").update(value).digest("hex");
const token = (user) => jwt.sign({ sub: user.id, username: user.username, role: user.role }, jwtSecret, { expiresIn: "15m" });
const allMenus = ["layers", "zones", "saved", "routing", "conference", "agents"];
const userView = (user) => ({ id: user.id, username: user.username, displayName: user.display_name, role: user.role, department: user.department || "", phone: user.phone || "", menuPermissions: user.menu_permissions || allMenus });
const normalizeMenus = (value) => Array.isArray(value) ? value.filter((item) => allMenus.includes(item)) : allMenus;
async function auth(req) { const value = String(req.headers.authorization || ""); if (!value.startsWith("Bearer ")) return null; try { const claims = jwt.verify(value.slice(7), jwtSecret); const result = await pool.query("SELECT id,username,display_name,role,is_active,menu_permissions FROM users WHERE id=$1", [claims.sub]); return result.rows[0]?.is_active ? result.rows[0] : null; } catch { return null; } }
function requireRole(user, minimum) { return user && roleRank[user.role] >= roleRank[minimum]; }
function agentAuthorized(req) { return req.headers.authorization === `Bearer ${agentToken}`; }
async function agentAuthorizedForId(req, agentId) {
  if (agentAuthorized(req)) return true;
  const value = String(req.headers.authorization || "");
  if (!value.startsWith("Bearer ")) return false;
  const result = await pool.query("SELECT token_hash FROM agents WHERE agent_id=$1", [agentId]);
  return result.rowCount > 0 && result.rows[0].token_hash === hash(value.slice(7));
}
async function seedAdmin() { const username = process.env.ADMIN_USERNAME || "admin"; const password = process.env.ADMIN_PASSWORD || "admin123!"; const found = await pool.query("SELECT id FROM users WHERE username=$1", [username]); if (!found.rowCount) await pool.query("INSERT INTO users(username,password_hash,display_name,role) VALUES($1,$2,$3,'admin')", [username, await bcrypt.hash(password, 12), "HNTH Administrator"]); }

const server = http.createServer(async (req, res) => {
  try {
    if (req.method === "OPTIONS") return json(res, 204, {});
    const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);
    if (req.method === "GET" && url.pathname === "/health") { await pool.query("SELECT 1"); return json(res, 200, { ok: true, service: "hnth-backend", database: "ok" }); }
    if (req.method === "GET" && url.pathname === "/api/agent-status") { const requestedAgentId = url.searchParams.get("agentId") || (await selectedAgentId()); const result = requestedAgentId ? await pool.query("SELECT agent_id AS \"agentId\",name,status,last_seen_at AS \"lastSeenAt\",version FROM agents WHERE agent_id=$1", [requestedAgentId]) : await pool.query("SELECT agent_id AS \"agentId\",name,status,last_seen_at AS \"lastSeenAt\",version FROM agents ORDER BY last_seen_at DESC NULLS LAST,agent_id LIMIT 1"); if (!result.rowCount) return json(res, 200, { agentId: requestedAgentId || null, name: requestedAgentId || "Agent HNTH", status: "offline", lastSeenAt: null }, {}, req); const agent = result.rows[0]; const online = agent.lastSeenAt && (Date.now() - new Date(agent.lastSeenAt).getTime()) < 30000; return json(res, 200, { ...agent, status: online ? "online" : "offline" }, {}, req); }
    if (url.pathname.startsWith("/api/agent-releases/") && req.method === "GET") {
      const agentId = String(url.searchParams.get("agentId") || "");
      if (!agentId || !(await agentAuthorizedForId(req, agentId))) return json(res, 401, { error: "unauthorized" }, {}, req);
      const version = decodeURIComponent(url.pathname.split("/").pop() || "");
      const release = await pool.query("SELECT file_path,file_name,sha256,size_bytes FROM agent_releases WHERE version=$1", [version]);
      if (!release.rowCount) return json(res, 404, { error: "release not found" }, {}, req);
      const item = release.rows[0];
      res.writeHead(200, { "content-type": "application/vnd.microsoft.portable-executable", "content-length": item.size_bytes, "content-disposition": `attachment; filename=\"${item.file_name}\"`, "cache-control": "no-store" });
      return createReadStream(item.file_path).on("error", () => res.destroy()).pipe(res);
    }
    if (url.pathname === "/api/agents/update-result" && req.method === "POST") {
      const body = await readJson(req);
      const agentId = String(body.agentId || "");
      if (!agentId || !(await agentAuthorizedForId(req, agentId))) return json(res, 401, { error: "unauthorized" }, {}, req);
      const version = String(body.version || "").trim();
      const status = String(body.status || "failed").trim();
      if (!version || !["success", "failed"].includes(status)) return json(res, 400, { error: "invalid update result" }, {}, req);
      await pool.query("INSERT INTO agent_update_events(agent_id,version,status,detail) VALUES($1,$2,$3,$4)", [agentId, version, status, String(body.detail || "").slice(0, 2000)]);
      if (status === "success") await pool.query("UPDATE agents SET version=$2,status='online',last_seen_at=now() WHERE agent_id=$1", [agentId, version]);
      return json(res, 202, { accepted: true }, {}, req);
    }
    if (url.pathname === "/api/auth/login" && req.method === "POST") { const body = await readJson(req); const result = await pool.query("SELECT * FROM users WHERE username=$1 AND is_active=true", [body.username]); const user = result.rows[0]; if (!user || !(await bcrypt.compare(String(body.password || ""), user.password_hash))) return json(res, 401, { error: "invalid credentials" }); const raw = crypto.randomBytes(48).toString("hex"); await pool.query("INSERT INTO refresh_tokens(user_id,token_hash,expires_at) VALUES($1,$2,now()+interval '30 days')", [user.id, hash(raw)]); res.setHeader("set-cookie", `hnth_refresh=${raw}; HttpOnly; SameSite=Lax; Path=/; Max-Age=2592000`); return json(res, 200, { accessToken: token(user), user: userView(user) }); }
    if (url.pathname === "/api/auth/refresh" && req.method === "POST") { const raw = String(req.headers.cookie || "").match(/(?:^|;)\s*hnth_refresh=([^;]+)/)?.[1]; if (!raw) return json(res, 401, { error: "refresh required" }); const result = await pool.query("SELECT u.* FROM refresh_tokens r JOIN users u ON u.id=r.user_id WHERE r.token_hash=$1 AND r.revoked_at IS NULL AND r.expires_at>now() AND u.is_active=true", [hash(raw)]); const user = result.rows[0]; if (!user) return json(res, 401, { error: "invalid refresh" }); await pool.query("UPDATE refresh_tokens SET revoked_at=now() WHERE token_hash=$1", [hash(raw)]); const next = crypto.randomBytes(48).toString("hex"); await pool.query("INSERT INTO refresh_tokens(user_id,token_hash,expires_at) VALUES($1,$2,now()+interval '30 days')", [user.id, hash(next)]); res.setHeader("set-cookie", `hnth_refresh=${next}; HttpOnly; SameSite=Lax; Path=/; Max-Age=2592000`); return json(res, 200, { accessToken: token(user), user: userView(user) }); }
    if (url.pathname === "/api/auth/me" && req.method === "GET") { const user = await auth(req); return user ? json(res, 200, userView(user)) : json(res, 401, { error: "unauthorized" }); }
    if (url.pathname === "/api/auth/change-password" && req.method === "POST") { const user = await auth(req); if (!user) return json(res, 401, { error: "unauthorized" }); const body = await readJson(req); if (String(body.newPassword || "").length < 8) return json(res, 400, { error: "Mật khẩu mới tối thiểu 8 ký tự" }); const current = await pool.query("SELECT password_hash FROM users WHERE id=$1", [user.id]); if (!current.rowCount || !(await bcrypt.compare(String(body.currentPassword || ""), current.rows[0].password_hash))) return json(res, 400, { error: "Mật khẩu hiện tại không đúng" }); await pool.query("UPDATE users SET password_hash=$1,updated_at=now() WHERE id=$2", [await bcrypt.hash(String(body.newPassword), 12), user.id]); return json(res, 200, { ok: true }); }
    if (url.pathname === "/api/auth/profile" && req.method === "PUT") { const user = await auth(req); if (!user) return json(res, 401, { error: "unauthorized" }); const body = await readJson(req); const displayName = String(body.displayName || "").trim(); if (!displayName) return json(res, 400, { error: "Họ và tên là bắt buộc" }); const result = await pool.query("UPDATE users SET display_name=$1,department=$2,phone=$3,updated_at=now() WHERE id=$4 RETURNING *", [displayName, String(body.department || "").trim(), String(body.phone || "").trim(), user.id]); return json(res, 200, { user: userView(result.rows[0]) }); }
    if (url.pathname === "/api/auth/logout" && req.method === "POST") { const raw = String(req.headers.cookie || "").match(/(?:^|;)\s*hnth_refresh=([^;]+)/)?.[1]; if (raw) await pool.query("UPDATE refresh_tokens SET revoked_at=now() WHERE token_hash=$1", [hash(raw)]); res.setHeader("set-cookie", "hnth_refresh=; HttpOnly; Path=/; Max-Age=0"); return json(res, 200, { ok: true }); }
    if (url.pathname === "/api/agents/register" && req.method === "POST") {
      const body = await readJson(req);
      if (!body.agentId) return json(res, 400, { error: "agentId required" });
      if (!(await agentAuthorizedForId(req, body.agentId))) return json(res, 401, { error: "unauthorized" });
      const installationId = String(body.installationId || "").trim() || null;
      // agent_id đã thuộc về bản cài khác (file Agent bị copy sang máy/thư mục mới):
      // từ chối để Agent tự xin id riêng qua /api/agents/clone, tránh hai máy dùng chung id.
      const owner = await pool.query("SELECT installation_id FROM agents WHERE agent_id=$1", [body.agentId]);
      if (installationId && owner.rows[0]?.installation_id && owner.rows[0].installation_id !== installationId) return json(res, 409, { error: "agent id belongs to another installation" });
      try {
        await pool.query("INSERT INTO agents(agent_id,name,machine_id,installation_id,token_hash,status,last_seen_at,version) VALUES($1,$2,$3,$4,$5,'online',now(),$6) ON CONFLICT(agent_id) DO UPDATE SET name=excluded.name,machine_id=COALESCE(excluded.machine_id,agents.machine_id),installation_id=COALESCE(agents.installation_id,excluded.installation_id),status='online',last_seen_at=now(),version=excluded.version", [body.agentId, body.name || body.agentId, body.machineId || null, installationId, hash(String(req.headers.authorization).slice(7)), body.version || null]);
      } catch (error) {
        // installation_id này đã gắn với một agent khác (Agent mất config rồi đăng ký lại bằng id cũ).
        if (error.code === "23505") return json(res, 409, { error: "installation already registered as another agent" });
        throw error;
      }
      void broadcastRealtimeState();
      return json(res, 200, { ok: true, agentId: body.agentId });
    }
    if (url.pathname === "/api/agents/clone" && req.method === "POST") {
      const body = await readJson(req);
      const sourceId = String(body.agentId || "");
      const machineId = String(body.machineId || "").trim();
      const installationId = String(body.installationId || "").trim() || null;
      if (!sourceId || !machineId) return json(res, 400, { error: "agentId and machineId are required" });
      if (!(await agentAuthorizedForId(req, sourceId))) return json(res, 401, { error: "unauthorized" });
      const token = crypto.randomBytes(32).toString("hex");
      // Agent có thể đã enroll thành công nhưng chết trước khi lưu config: cấp lại
      // token cho đúng agent của bản cài đó thay vì sinh thêm agent trùng lặp.
      const existing = installationId ? await pool.query("UPDATE agents SET token_hash=$2,machine_id=$3,status='online',last_seen_at=now() WHERE installation_id=$1 RETURNING agent_id AS \"agentId\",name", [installationId, hash(token), machineId]) : { rowCount: 0 };
      if (existing.rowCount) { void broadcastRealtimeState(); return json(res, 200, { ...existing.rows[0], token, machineId, installationId }); }
      const source = await pool.query("SELECT name,monitor_config,heartbeat_seconds FROM agents WHERE agent_id=$1", [sourceId]);
      const agentId = `agent-${crypto.randomUUID()}`;
      const name = String(body.name || `${source.rows[0]?.name || "Agent HNTH"} - ${machineId.slice(0, 8)}`).trim();
      await pool.query("INSERT INTO agents(agent_id,name,machine_id,installation_id,token_hash,status,last_seen_at,version,heartbeat_seconds,monitor_config) VALUES($1,$2,$3,$4,$5,'online',now(),$6,$7,$8)", [agentId, name, machineId, installationId, hash(token), body.version ? String(body.version) : null, source.rows[0]?.heartbeat_seconds ?? 30, JSON.stringify(source.rows[0]?.monitor_config || {})]);
      void broadcastRealtimeState();
      return json(res, 201, { agentId, name, token, machineId, installationId });
    }
    if (url.pathname === "/api/agents/heartbeat" && req.method === "POST") { const body = await readJson(req); if (!body.agentId) return json(res, 400, { error: "agentId required" }); if (!(await agentAuthorizedForId(req, body.agentId))) return json(res, 401, { error: "unauthorized" }); if (body.installationId) { const owner = await pool.query("SELECT installation_id FROM agents WHERE agent_id=$1", [body.agentId]); if (owner.rows[0]?.installation_id && owner.rows[0].installation_id !== String(body.installationId)) return json(res, 409, { error: "agent id belongs to another installation" }); } const result = await pool.query("UPDATE agents SET status='online',last_seen_at=now(),version=COALESCE($2,version),machine_id=COALESCE($3,machine_id) WHERE agent_id=$1 RETURNING agent_id AS \"agentId\",status,last_seen_at AS \"lastSeenAt\",version", [body.agentId, body.version || null, body.machineId || null]); if (!result.rowCount) return json(res, 404, { error: "agent not registered" }); void broadcastRealtimeState(); return json(res, 200, { ok: true, ...result.rows[0] }); }
    if (url.pathname.startsWith("/api/agents/") && url.pathname.endsWith("/commands") && req.method === "GET") { const agentId = url.pathname.split("/")[3]; if (!(await agentAuthorizedForId(req, agentId))) return json(res, 401, { error: "unauthorized" }); const result = await pool.query("WITH next AS (SELECT id FROM commands WHERE agent_id=$1 AND status='pending' ORDER BY created_at LIMIT 1) UPDATE commands c SET status='claimed',claimed_at=now() FROM next WHERE c.id=next.id RETURNING c.type,c.payload", [agentId]); const command = result.rows[0]; if (command?.type === "agent-config" && command.payload?.token) await pool.query("UPDATE agents SET token_hash=$1 WHERE agent_id=$2", [hash(String(command.payload.token)), agentId]); return json(res, 200, command ? { type: command.type, ...command.payload } : { type: "none" }); }
    if (url.pathname === "/api/telemetry/ping-results" && req.method === "POST") { const body = await readJson(req); if (!body.agentId || !Array.isArray(body.results)) return json(res, 400, { error: "invalid snapshot" }); if (!(await agentAuthorizedForId(req, body.agentId))) return json(res, 401, { error: "unauthorized" }); await pool.query("UPDATE agents SET status='online',last_seen_at=now() WHERE agent_id=$1", [body.agentId]); for (const item of body.results) { const pointId = String(item.pointId || item.ipAddress || "").trim(); if (!pointId) continue; const ipAddress = String(item.ipAddress || "").trim() || null;
      // IP rỗng là cấu hình chưa xác định, bất kể agent/client gửi status gì.
      // Không cho phép dữ liệu cũ hoặc payload lỗi biến điểm này thành offline/lost.
      const status = ipAddress ? (item.status || "unknown") : "unknown";
      const checkedAt = item.checkedAt || new Date().toISOString(); await pool.query("INSERT INTO endpoints(endpoint_id,name,ip_address,status,latency_ms,packet_loss_pct,jitter_ms,checked_at) VALUES($1,$1,$2::inet,$3,$4,$5,$6,$7) ON CONFLICT(endpoint_id) DO UPDATE SET ip_address=excluded.ip_address,status=excluded.status,latency_ms=excluded.latency_ms,packet_loss_pct=excluded.packet_loss_pct,jitter_ms=excluded.jitter_ms,checked_at=excluded.checked_at,updated_at=now()", [pointId, ipAddress, status, item.latencyMs ?? null, item.packetLossPct ?? null, item.jitterMs ?? null, checkedAt]);
        // Agent có thể gửi lại cùng một trạng thái (đặc biệt điểm trung tâm
        // được gửi ở mỗi vòng). Chỉ ghi log khi trạng thái hoặc IP thay đổi;
        // snapshot vẫn broadcast đầy đủ để bản đồ cập nhật tức thời.
        const previous = await pool.query("SELECT ip_address::text AS ip_address,status FROM monitor_logs WHERE agent_id=$1 AND endpoint_id=$2 ORDER BY received_at DESC LIMIT 1", [body.agentId, pointId]);
        const changed = !previous.rowCount || String(previous.rows[0].ip_address ?? "") !== String(ipAddress ?? "") || previous.rows[0].status !== status;
        if (changed) await pool.query("INSERT INTO monitor_logs(agent_id,endpoint_id,ip_address,status,latency_ms,packet_loss_pct,jitter_ms,checked_at) VALUES($1,$2,$3,$4,$5,$6,$7,$8)", [body.agentId, pointId, ipAddress, status, item.latencyMs ?? null, item.packetLossPct ?? null, item.jitterMs ?? null, checkedAt]);
      } await broadcastRealtimeState({ monitorBatch: body.monitorBatch ? { ...body.monitorBatch, results: body.results, allResults: body.monitorBatch.allResults || body.results } : undefined }); return json(res, 202, { accepted: true }); }
    if (url.pathname === "/api/telemetry/discovered-ips" && req.method === "POST") { const body = await readJson(req); if (!body.agentId || !Array.isArray(body.ips)) return json(res, 400, { error: "invalid scan" }); if (!(await agentAuthorizedForId(req, body.agentId))) return json(res, 401, { error: "unauthorized" }); await pool.query("UPDATE agents SET status='online',last_seen_at=now() WHERE agent_id=$1", [body.agentId]); for (const item of body.ips) await pool.query("INSERT INTO discovered_ips(agent_id,ip_address,status,mac_address,model_vendor,discovered_at) VALUES($1,$2,$3,$4,$5,$6) ON CONFLICT(agent_id,ip_address) DO UPDATE SET status=excluded.status,mac_address=COALESCE(excluded.mac_address,discovered_ips.mac_address),model_vendor=COALESCE(excluded.model_vendor,discovered_ips.model_vendor),discovered_at=excluded.discovered_at", [body.agentId, item.ipAddress, item.status || "online", item.macAddress || null, item.modelVendor || item.model || null, item.discoveredAt || new Date().toISOString()]); broadcast({ type: "discovered-ips", agentId: body.agentId, ips: body.ips }); return json(res, 202, { accepted: true, count: body.ips.length }); }
    if (url.pathname === "/api/telemetry/snmp-results" && req.method === "POST") { const body = await readJson(req); if (!body.agentId || !Array.isArray(body.results)) return json(res, 400, { error: "invalid snmp payload" }); if (!(await agentAuthorizedForId(req, body.agentId))) return json(res, 401, { error: "unauthorized" }); await pool.query("UPDATE agents SET status='online',last_seen_at=now() WHERE agent_id=$1", [body.agentId]); for (const item of body.results) { if (!item.host || !item.oid) continue; await pool.query("INSERT INTO snmp_results(agent_id,target_id,host,oid,value,value_type,checked_at) VALUES($1,$2,$3::inet,$4,$5,$6,$7)", [body.agentId, item.targetId || item.host, item.host, item.oid, item.value ?? null, item.valueType || null, item.checkedAt || new Date().toISOString()]); } broadcast({ type: "snmp-results", agentId: body.agentId, results: body.results }); return json(res, 202, { accepted: true, count: body.results.length }); }
    if (url.pathname === "/api/hnth/stream" && req.method === "GET") { res.writeHead(200, { "content-type": "text/event-stream; charset=utf-8", "cache-control": "no-cache, no-transform", "connection": "keep-alive", "x-accel-buffering": "no", "access-control-allow-origin": corsOrigin(req), "access-control-allow-credentials": "true", "vary": "Origin" }); res.flushHeaders?.(); sseClients.add(res); await broadcastRealtimeStateTo(res); const timer = setInterval(() => { try { res.write(`: keepalive ${Date.now()}\n\n`); } catch { clearInterval(timer); sseClients.delete(res); } }, 5000); req.on("close", () => { clearInterval(timer); sseClients.delete(res); }); return; }
    // These are read-only live-view endpoints. Guest users must be able to
    // observe the shared HNTH state without logging in; command/configuration
    // endpoints remain protected by the role check below.
    if (url.pathname === "/api/hnth/status" && req.method === "GET") { return json(res, 200, await currentRealtimeState(), {}, req); }
    if (url.pathname === "/api/hnth/monitor-state" && req.method === "GET") { return json(res, 200, await currentRealtimeState(), {}, req); }
    if (url.pathname === "/api/hnth/endpoints" && req.method === "GET") { const rows = await pool.query("SELECT endpoint_id AS \"pointId\",name,host(ip_address) AS \"ipAddress\",model_vendor AS \"modelVendor\",status,latency_ms AS \"latencyMs\",packet_loss_pct AS \"packetLossPct\",jitter_ms AS \"jitterMs\",checked_at AS \"checkedAt\" FROM endpoints WHERE enabled=true AND endpoint_id LIKE 'hnth-%' ORDER BY name"); return json(res, 200, rows.rows, {}, req); }
    if (url.pathname === "/api/hnth/discovered-ips" && req.method === "GET") { const agentId = url.searchParams.get("agentId") || (await selectedAgentId()); const rows = await pool.query("SELECT host(ip_address) AS \"ipAddress\",status,mac_address AS \"macAddress\",model_vendor AS \"modelVendor\",discovered_at AS \"discoveredAt\" FROM discovered_ips WHERE agent_id=$1 ORDER BY ip_address", [agentId]); return json(res, 200, { updatedAt: new Date().toISOString(), agentId, ips: rows.rows }, {}, req); }
    if (url.pathname === "/api/hnth/monitor-log" && req.method === "GET") { const pointId = String(url.searchParams.get("pointId") || "").trim(); const rows = pointId ? await pool.query("SELECT endpoint_id AS \"pointId\",ip_address AS \"ipAddress\",status,latency_ms AS \"latencyMs\",checked_at AS \"checkedAt\",received_at AS \"receivedAt\" FROM monitor_logs WHERE agent_id=$1 AND endpoint_id=$2 ORDER BY received_at DESC LIMIT 1000", [(await selectedAgentId()), pointId]) : await pool.query("SELECT endpoint_id AS \"pointId\",ip_address AS \"ipAddress\",status,latency_ms AS \"latencyMs\",checked_at AS \"checkedAt\",received_at AS \"receivedAt\" FROM monitor_logs WHERE agent_id=$1 ORDER BY received_at DESC LIMIT 1000", [(await selectedAgentId())]); return json(res, 200, { entries: rows.rows, pointId: pointId || null }, {}, req); }
    if (req.method === "GET" && url.pathname === "/api/agent-status") { const agentId = url.searchParams.get("agentId") || (await selectedAgentId()); const result = await pool.query("SELECT agent_id AS \"agentId\",name,status,last_seen_at AS \"lastSeenAt\",version FROM agents WHERE agent_id=$1", [agentId]); if (!result.rowCount) return json(res, 200, { agentId, name: agentId, status: "offline", lastSeenAt: null }, {}, req); const agent = result.rows[0]; const online = agent.lastSeenAt && (Date.now() - new Date(agent.lastSeenAt).getTime()) < 30000; return json(res, 200, { ...agent, status: online ? "online" : "offline" }, {}, req); }
    const user = await auth(req); if (!user) return json(res, 401, { error: "unauthorized" });
    if (url.pathname === "/api/agent-releases" && req.method === "GET") {
      if (!requireRole(user, "operator")) return json(res, 403, { error: "forbidden" });
      const rows = await pool.query("SELECT version,file_name AS \"fileName\",sha256,size_bytes AS \"sizeBytes\",created_at AS \"createdAt\" FROM agent_releases ORDER BY created_at DESC");
      return json(res, 200, rows.rows);
    }
    if (url.pathname === "/api/agent-releases" && req.method === "POST") {
      if (!requireRole(user, "admin")) return json(res, 403, { error: "admin required" });
      const fileName = safeReleaseFileName(url.searchParams.get("fileName"));
      if (!fileName.toLowerCase().endsWith(".exe")) return json(res, 400, { error: "Chỉ chấp nhận file Agent dạng .exe" });
      await mkdir(releaseRoot, { recursive: true });
      const tempPath = path.join(releaseRoot, `${crypto.randomUUID()}.upload`);
      const uploaded = await writeRelease(req, tempPath);
      // Version lấy từ chính file .exe (ProductVersion do electron-builder ghi), không
      // dựa vào số người dùng gõ: Agent báo về đúng version này sau khi cập nhật.
      const version = safeReleaseVersion(await readExeVersion(tempPath));
      const requested = url.searchParams.get("version");
      if (!version || (requested && safeReleaseVersion(requested) !== version)) {
        await unlink(tempPath).catch(() => {});
        return json(res, 400, { error: version ? `File là bản ${version}, không phải ${requested}` : "Không đọc được version trong file .exe; hãy dùng file Agent build bằng electron-builder" });
      }
      const finalPath = path.join(releaseRoot, `hnth-agent-${version}.exe`);
      await unlink(finalPath).catch(() => {});
      await rename(tempPath, finalPath);
      const result = await pool.query("INSERT INTO agent_releases(version,file_name,file_path,sha256,size_bytes,created_by) VALUES($1,$2,$3,$4,$5,$6) ON CONFLICT(version) DO UPDATE SET file_name=excluded.file_name,file_path=excluded.file_path,sha256=excluded.sha256,size_bytes=excluded.size_bytes,created_by=excluded.created_by,created_at=now() RETURNING version,file_name AS \"fileName\",sha256,size_bytes AS \"sizeBytes\"", [version, fileName, finalPath, uploaded.sha256, uploaded.size, user.id]);
      return json(res, 201, result.rows[0]);
    }
    if (url.pathname === "/api/agents" && req.method === "GET") { if (!requireRole(user, "operator")) return json(res, 403, { error: "forbidden" }); const rows = await pool.query("SELECT a.agent_id AS \"agentId\",a.name,a.status,a.last_seen_at AS \"lastSeenAt\",a.version,a.heartbeat_seconds AS \"heartbeatSeconds\",a.monitor_config AS \"monitorConfig\",(SELECT json_build_object('version',e.version,'status',e.status,'detail',e.detail,'reportedAt',e.reported_at) FROM agent_update_events e WHERE e.agent_id=a.agent_id ORDER BY e.reported_at DESC LIMIT 1) AS \"lastUpdate\" FROM agents a ORDER BY a.name,a.agent_id"); const now = Date.now(); const agents = rows.rows.map((agent) => ({ ...agent, status: agent.lastSeenAt && now - new Date(agent.lastSeenAt).getTime() < 30000 ? "online" : "offline" })); return json(res, 200, agents); }
    if (url.pathname.startsWith("/api/agents/") && url.pathname.endsWith("/token") && req.method === "POST") { if (!requireRole(user, "admin")) return json(res, 403, { error: "forbidden" }); const agentId = decodeURIComponent(url.pathname.split("/")[3]); const body = await readJson(req); const newToken = String(body.token || "").trim(); if (newToken.length < 16) return json(res, 400, { error: "Token phải có ít nhất 16 ký tự" }); const found = await pool.query("SELECT agent_id FROM agents WHERE agent_id=$1", [agentId]); if (!found.rowCount) return json(res, 404, { error: "agent not found" }); await pool.query("INSERT INTO commands(agent_id,type,payload) VALUES($1,'agent-config',$2)", [agentId, JSON.stringify({ token: newToken })]); return json(res, 202, { accepted: true, agentId }); }
    if (url.pathname.startsWith("/api/agents/") && req.method === "PATCH") { if (!requireRole(user, "admin")) return json(res, 403, { error: "forbidden" }); const agentId = decodeURIComponent(url.pathname.split("/")[3]); const body = await readJson(req); const name = String(body.name || "").trim(); const heartbeatSeconds = Math.max(5, Math.min(30, Number(body.heartbeatSeconds || 30))); if (!name) return json(res, 400, { error: "name is required" }); const config = body.monitorConfig && typeof body.monitorConfig === "object" ? body.monitorConfig : {}; const newToken = String(body.token || "").trim(); const result = await pool.query("UPDATE agents SET name=$1,heartbeat_seconds=$2,monitor_config=$3 WHERE agent_id=$4 RETURNING agent_id AS \"agentId\",name,status,last_seen_at AS \"lastSeenAt\",version,heartbeat_seconds AS \"heartbeatSeconds\",monitor_config AS \"monitorConfig\"", [name, heartbeatSeconds, JSON.stringify(config), agentId]); if (result.rowCount) { const payload = { heartbeatSeconds, ...config, ...(newToken ? { token: newToken } : {}) }; await pool.query("INSERT INTO commands(agent_id,type,payload) VALUES($1,'agent-config',$2)", [agentId, JSON.stringify(payload)]); } return result.rowCount ? json(res, 200, result.rows[0]) : json(res, 404, { error: "agent not found" }); }
    if (url.pathname.startsWith("/api/agents/") && url.pathname.endsWith("/commands") && req.method === "POST") { if (!requireRole(user, "operator")) return json(res, 403, { error: "forbidden" }); const body = await readJson(req); const agentId = url.pathname.split("/")[3]; const type = String(body.type || ""); const allowed = new Set(["scan-local-network", "test-point", "point-config", "monitor-start", "monitor-stop", "agent-update"]); if (!allowed.has(type)) return json(res, 400, { error: "unsupported command" }); if (type === "agent-update" && !requireRole(user, "admin")) return json(res, 403, { error: "admin required for agent updates" }); let { type: ignored, ...payload } = body;
      if (type === "agent-update") {
        // Lệnh cập nhật lấy file/SHA-256 từ bản release đã lưu, không tin URL do trình duyệt
        // gửi lên. `path` là đường dẫn tương đối: Agent tự ghép với backendUrl của chính nó,
        // nên máy ở LAN khác vẫn tải được (trước đây URL mặc định là 127.0.0.1 của máy Agent).
        const version = safeReleaseVersion(body.version);
        const release = version ? await pool.query("SELECT version,file_name,sha256,size_bytes FROM agent_releases WHERE version=$1", [version]) : { rowCount: 0 };
        if (!release.rowCount) return json(res, 404, { error: "release not found; upload the .exe first" });
        const item = release.rows[0];
        payload = { version: item.version, sha256: item.sha256, fileName: item.file_name, sizeBytes: Number(item.size_bytes), path: `/api/agent-releases/${encodeURIComponent(item.version)}?agentId=${encodeURIComponent(agentId)}` };
        await pool.query("UPDATE commands SET status='superseded' WHERE agent_id=$1 AND status='pending' AND type='agent-update'", [agentId]);
      }
      await pool.query("INSERT INTO commands(agent_id,type,payload) VALUES($1,$2,$3)", [agentId, type, payload]); return json(res, 202, { accepted: true, agentId, type }); }
    if (url.pathname === "/api/hnth/status" && req.method === "GET") { const rows = await pool.query("SELECT endpoint_id AS \"pointId\",host(ip_address) AS \"ipAddress\",status,checked_at AS \"checkedAt\" FROM endpoints WHERE enabled=true ORDER BY endpoint_id"); return json(res, 200, { updatedAt: new Date().toISOString(), results: rows.rows }); }
    if (url.pathname === "/api/hnth/monitor-state" && req.method === "GET") { return json(res, 200, await currentRealtimeState()); }
    if (url.pathname === "/api/hnth/discovered-ips" && req.method === "GET") { const agentId = url.searchParams.get("agentId") || (await selectedAgentId()); const rows = await pool.query("SELECT host(ip_address) AS \"ipAddress\",status,mac_address AS \"macAddress\",model_vendor AS \"modelVendor\",discovered_at AS \"discoveredAt\" FROM discovered_ips WHERE agent_id=$1 ORDER BY ip_address", [agentId]); return json(res, 200, { updatedAt: new Date().toISOString(), agentId, ips: rows.rows }); }
    if (url.pathname === "/api/hnth/monitor-log" && req.method === "GET") { const pointId = String(url.searchParams.get("pointId") || "").trim(); const rows = pointId ? await pool.query("SELECT endpoint_id AS \"pointId\",ip_address AS \"ipAddress\",status,latency_ms AS \"latencyMs\",checked_at AS \"checkedAt\",received_at AS \"receivedAt\" FROM monitor_logs WHERE agent_id=$1 AND endpoint_id=$2 ORDER BY received_at DESC LIMIT 1000", [(await selectedAgentId()), pointId]) : await pool.query("SELECT endpoint_id AS \"pointId\",ip_address AS \"ipAddress\",status,latency_ms AS \"latencyMs\",checked_at AS \"checkedAt\",received_at AS \"receivedAt\" FROM monitor_logs WHERE agent_id=$1 ORDER BY received_at DESC LIMIT 1000", [(await selectedAgentId())]); return json(res, 200, { entries: rows.rows, pointId: pointId || null }); }
    if (url.pathname === "/api/hnth/scan" && req.method === "POST") { if (!requireRole(user, "operator")) return json(res, 403, { error: "forbidden" }); const body = await readJson(req); const agentId = String(body.agentId || (await selectedAgentId())); const found = await pool.query("SELECT agent_id FROM agents WHERE agent_id=$1", [agentId]); if (!found.rowCount) return json(res, 404, { error: "agent not found" }); await pool.query("INSERT INTO commands(agent_id,type,payload) VALUES($1,'scan-local-network',$2)", [agentId, JSON.stringify({ scanSubnets: body.scanSubnets || [] })]); return json(res, 202, { accepted: true, agentId }); }
    if (url.pathname === "/api/hnth/test" && req.method === "POST") { if (!requireRole(user, "operator")) return json(res, 403, { error: "forbidden" }); const body = await readJson(req); await pool.query("INSERT INTO commands(agent_id,type,payload) VALUES($1,'test-point',$2)", [(await selectedAgentId()), JSON.stringify({ pointId: body.pointId, ipAddress: body.ipAddress })]); return json(res, 202, { accepted: true }); }
    if (url.pathname === "/api/hnth/point-config" && req.method === "POST") { if (!requireRole(user, "operator")) return json(res, 403, { error: "forbidden" }); const body = await readJson(req); const pointId = String(body.pointId || "").trim(); const ipAddress = String(body.ipAddress || "").trim(); const agentId = String(body.agentId || (await selectedAgentId())); if (!pointId) return json(res, 400, { error: "pointId is required" }); const agent = await pool.query("SELECT agent_id FROM agents WHERE agent_id=$1", [agentId]); if (!agent.rowCount) return json(res, 404, { error: "agent not found" }); const endpoint = await pool.query("INSERT INTO endpoints(endpoint_id,name,ip_address,model_vendor,status,checked_at) VALUES($1,$1,CASE WHEN $2='' THEN NULL ELSE $2::inet END,$3,'unknown',NULL) ON CONFLICT(endpoint_id) DO UPDATE SET ip_address=excluded.ip_address,model_vendor=COALESCE(excluded.model_vendor,endpoints.model_vendor),status='unknown',checked_at=NULL,updated_at=now() RETURNING endpoint_id AS \"pointId\",host(ip_address) AS \"ipAddress\",status", [pointId, ipAddress, body.modelVendor || null]); await pool.query("UPDATE commands SET status='superseded' WHERE agent_id=$1 AND status='pending' AND type='point-config' AND payload->>'pointId'=$2", [agentId, pointId]); await pool.query("INSERT INTO commands(agent_id,type,payload) VALUES($1,'point-config',$2)", [agentId, JSON.stringify({ pointId, ipAddress, modelVendor: body.modelVendor || null, forceTest: Boolean(ipAddress) })]); await broadcastRealtimeState(); return json(res, 202, { accepted: true, agentId, endpoint: endpoint.rows[0] }); }
    if (url.pathname === "/api/hnth/selected-agent" && req.method === "POST") {
      if (!requireRole(user, "operator")) return json(res, 403, { error: "forbidden" });
      const body = await readJson(req);
      const agentId = String(body.agentId || "").trim();
      const found = agentId ? await pool.query("SELECT agent_id FROM agents WHERE agent_id=$1", [agentId]) : { rowCount: 0 };
      if (!found.rowCount) return json(res, 404, { error: "agent not found" });
      // Đang giám sát liên tục thì agent cũ vẫn ping; đổi agent giữa chừng sẽ làm
      // trạng thái trên bản đồ trộn kết quả của hai agent.
      const monitor = await pool.query("SELECT enabled,agent_id FROM monitor_state WHERE id=1");
      if (monitor.rows[0]?.enabled && monitor.rows[0].agent_id !== agentId) return json(res, 409, { error: "Tắt Giám sát liên tục trước khi đổi Agent" });
      await pool.query("UPDATE monitor_state SET agent_id=$1,updated_at=now(),revision=revision+1 WHERE id=1", [agentId]);
      await pool.query("INSERT INTO audit_logs(user_id,action,resource,metadata) VALUES($1,'select','hnth-agent',$2)", [user.id, JSON.stringify({ agentId })]);
      await broadcastRealtimeState();
      return json(res, 200, { agentId });
    }
    if (url.pathname === "/api/hnth/monitor" && req.method === "POST") {
      if (!requireRole(user, "operator")) return json(res, 403, { error: "forbidden" });
      const body = await readJson(req);
      const submittedPoints = Array.isArray(body.points) ? body.points.map((point) => ({
        point_id: String(point.point_id ?? point.pointId ?? ""),
        name: String(point.name ?? point.pointName ?? point.point_id ?? point.pointId ?? ""),
        ip_address: String(point.ip_address ?? point.ipAddress ?? "").trim(),
        model_vendor: point.model_vendor ?? point.modelVendor ?? null,
      })).filter((point) => point.point_id) : [];
      const requestedPoints = submittedPoints.filter((point) => point.ip_address);
      // The submitted list is authoritative for this Agent/session. Do not
      // merge it with the global endpoint registry: an imported 50-point list
      // must never turn into the previous 115-point list.
      const points = requestedPoints;
      const currentMonitor = await pool.query("SELECT enabled FROM monitor_state WHERE id=1");
      const wasEnabled = Boolean(currentMonitor.rows[0]?.enabled);
      const startingNewSession = Boolean(body.enabled) && (!wasEnabled || body.resetStatuses === true);
      if (body.enabled) {
        // Persist the submitted configuration before building the command snapshot.
        // The database is the source of truth; a new slider/config request must not
        // resurrect an older in-memory or queued IP list.
        await pool.query("UPDATE endpoints SET ip_address=NULL,status='unknown',checked_at=NULL,updated_at=now() WHERE endpoint_id = ANY($1::text[]) AND enabled=true", [submittedPoints.filter((point) => !point.ip_address).map((point) => point.point_id)]);
        await pool.query("INSERT INTO endpoints(endpoint_id,name,ip_address,model_vendor) SELECT x.point_id,x.point_id,x.ip_address,x.model_vendor FROM jsonb_to_recordset($1::jsonb) AS x(point_id text,ip_address inet,model_vendor text) ON CONFLICT(endpoint_id) DO UPDATE SET ip_address=excluded.ip_address,model_vendor=COALESCE(excluded.model_vendor,endpoints.model_vendor),updated_at=now()", [JSON.stringify(requestedPoints)]);
        // Mỗi lần bật là một phiên mới: toàn bộ endpoint phải quay về
        // unknown trước khi Agent bắt đầu batch đầu tiên. Không xóa
        // monitor_logs vì đó là lịch sử; endpoint hiện tại được đọc từ đây.
        if (startingNewSession && points.length) await pool.query("UPDATE endpoints SET status='unknown',checked_at=NULL,updated_at=now() WHERE endpoint_id = ANY($1::text[])", [points.map((point) => point.point_id)]);
      }
      const concurrency = Math.max(1, Math.min(30, Number(body.concurrency || 1)));
      const waitSeconds = Math.max(1, Math.min(10, Number(body.waitSeconds || 3)));
      const targetAgentId = String(body.agentId || (await selectedAgentId()));
      const targetAgent = await pool.query("SELECT agent_id FROM agents WHERE agent_id=$1", [targetAgentId]);
      if (!targetAgent.rowCount) return json(res, 404, { error: "agent not found" });
      if (startingNewSession) {
        await pool.query("UPDATE monitor_state SET enabled=true,agent_id=$1,concurrency=$2,wait_seconds=$3,session_id=gen_random_uuid(),started_at=now(),updated_at=now(),revision=revision+1 WHERE id=1", [targetAgentId, concurrency, waitSeconds]);
      } else {
        await pool.query("UPDATE monitor_state SET enabled=$1,agent_id=$2,concurrency=$3,wait_seconds=$4,started_at=CASE WHEN $1 THEN COALESCE(started_at,now()) ELSE NULL END,updated_at=now(),revision=revision+1 WHERE id=1", [Boolean(body.enabled), targetAgentId, concurrency, waitSeconds]);
      }
      await pool.query("UPDATE commands SET status='superseded' WHERE agent_id=$1 AND status='pending' AND type IN ('monitor-start','monitor-stop')", [targetAgentId]);
      await pool.query("INSERT INTO commands(agent_id,type,payload) VALUES($1,$2,$3)", [targetAgentId, body.enabled ? "monitor-start" : "monitor-stop", JSON.stringify({ points: points.map((point) => ({ pointId: point.point_id, name: point.name, ipAddress: point.ip_address, modelVendor: point.model_vendor })), concurrency, waitSeconds, resetStatuses: startingNewSession })]);
      await broadcastRealtimeState();
      return json(res, 202, { accepted: true, points: points.length, sessionId: (await pool.query("SELECT session_id AS \"sessionId\" FROM monitor_state WHERE id=1")).rows[0]?.sessionId });
    }
    if (url.pathname === "/api/users" && req.method === "GET") { if (!requireRole(user, "admin")) return json(res, 403, { error: "forbidden" }); const rows = await pool.query("SELECT id,username,display_name AS \"displayName\",role,department,phone,menu_permissions AS \"menuPermissions\",is_active AS \"isActive\",created_at AS \"createdAt\" FROM users ORDER BY username"); return json(res, 200, rows.rows); }
    if (url.pathname === "/api/users" && req.method === "POST") { if (!requireRole(user, "admin")) return json(res, 403, { error: "forbidden" }); const body = await readJson(req); const username = String(body.username || "").trim(); const displayName = String(body.displayName || username).trim(); const role = String(body.role || "viewer"); const password = String(body.password || ""); const department = String(body.department || "").trim(); const phone = String(body.phone || "").trim(); const menus = normalizeMenus(body.menuPermissions); if (!/^[a-zA-Z0-9._-]{3,40}$/.test(username) || !displayName || password.length < 8 || !Object.hasOwn(roleRank, role)) return json(res, 400, { error: "username, displayName, role and password (min 8 chars) are required" }); try { const result = await pool.query("INSERT INTO users(username,password_hash,display_name,role,department,phone,menu_permissions,is_active) VALUES($1,$2,$3,$4,$5,$6,$7,$8) RETURNING id,username,display_name AS \"displayName\",role,department,phone,menu_permissions AS \"menuPermissions\",is_active AS \"isActive\",created_at AS \"createdAt\"", [username, await bcrypt.hash(password, 12), displayName, role, department, phone, JSON.stringify(menus), body.isActive !== false]); await pool.query("INSERT INTO audit_logs(user_id,action,resource,metadata) VALUES($1,'create','user',$2)", [user.id, JSON.stringify({ username, role })]); return json(res, 201, result.rows[0]); } catch (error) { if (error.code === "23505") return json(res, 409, { error: "username already exists" }); throw error; } }
    if (url.pathname.startsWith("/api/users/") && req.method === "PUT") { if (!requireRole(user, "admin")) return json(res, 403, { error: "forbidden" }); const id = url.pathname.split("/")[3]; const body = await readJson(req); const role = String(body.role || "viewer"); if (!Object.hasOwn(roleRank, role)) return json(res, 400, { error: "invalid role" }); if (id === user.id && body.isActive === false) return json(res, 400, { error: "cannot deactivate current user" }); const displayName = String(body.displayName || "").trim(); if (!displayName) return json(res, 400, { error: "displayName is required" }); const result = await pool.query("UPDATE users SET display_name=$1,role=$2,department=$3,phone=$4,menu_permissions=$5,is_active=$6,updated_at=now() WHERE id=$7 RETURNING id,username,display_name AS \"displayName\",role,department,phone,menu_permissions AS \"menuPermissions\",is_active AS \"isActive\",created_at AS \"createdAt\"", [displayName, role, String(body.department || "").trim(), String(body.phone || "").trim(), JSON.stringify(normalizeMenus(body.menuPermissions)), body.isActive !== false, id]); if (!result.rowCount) return json(res, 404, { error: "user not found" }); if (body.password) await pool.query("UPDATE users SET password_hash=$1,updated_at=now() WHERE id=$2", [await bcrypt.hash(String(body.password), 12), id]); await pool.query("INSERT INTO audit_logs(user_id,action,resource,metadata) VALUES($1,'update','user',$2)", [user.id, JSON.stringify({ targetUserId: id, role })]); return json(res, 200, result.rows[0]); }
    if (url.pathname.startsWith("/api/users/") && req.method === "DELETE") { if (!requireRole(user, "admin")) return json(res, 403, { error: "forbidden" }); const id = url.pathname.split("/")[3]; if (id === user.id) return json(res, 400, { error: "cannot delete current user" }); const result = await pool.query("UPDATE users SET is_active=false,updated_at=now() WHERE id=$1 RETURNING id", [id]); if (!result.rowCount) return json(res, 404, { error: "user not found" }); await pool.query("INSERT INTO audit_logs(user_id,action,resource,metadata) VALUES($1,'delete','user',$2)", [user.id, JSON.stringify({ targetUserId: id })]); return json(res, 200, { ok: true }); }
    if (url.pathname === "/api/hnth/endpoints" && req.method === "GET") { const rows = await pool.query("SELECT endpoint_id AS \"pointId\",name,host(ip_address) AS \"ipAddress\",model_vendor AS \"modelVendor\",status,checked_at AS \"checkedAt\" FROM endpoints WHERE enabled=true ORDER BY name"); return json(res, 200, rows.rows); }
    if (url.pathname === "/api/audit-logs" && req.method === "GET") { if (!requireRole(user, "admin")) return json(res, 403, { error: "forbidden" }); const rows = await pool.query("SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT 500"); return json(res, 200, rows.rows); }
    return json(res, 404, { error: "not found" });
  } catch (error) { console.error(error); return json(res, error.message === "invalid json" ? 400 : 500, { error: error.message }); }
});
try { await migrate(); await seedAdmin(); server.listen(port, "0.0.0.0", () => console.log(`HNTH Backend listening on :${port}`)); } catch (error) { console.error(`HNTH Backend startup failed: ${error.message}`); process.exitCode = 1; }
