// API Agent gọi (không có JWT người dùng): xác thực bằng token agent trong từng route.
import crypto from "node:crypto";
import { createReadStream } from "node:fs";
import { pool } from "../db.mjs";
import { hash } from "../auth.mjs";

export function registerAgentApiRoutes(router, { auth, realtime }) {
  const unauthorized = (reply) => reply(401, { error: "unauthorized" });
  // agent_id đã gắn với bản cài khác (thư mục Agent bị copy): trả 409 để Agent tự
  // xin id riêng qua /api/agents/clone, tránh hai máy dùng chung một id.
  async function ownedByAnotherInstallation(agentId, installationId) {
    if (!installationId) return false;
    const owner = await pool.query("SELECT installation_id FROM agents WHERE agent_id=$1", [agentId]);
    return Boolean(owner.rows[0]?.installation_id) && owner.rows[0].installation_id !== installationId;
  }

  router.add("POST", "/api/agents/register", async ({ req, readBody, reply }) => {
    const body = await readBody();
    if (!body.agentId) return reply(400, { error: "agentId required" });
    if (!(await auth.agentAuthorizedForId(req, body.agentId))) return unauthorized(reply);
    const installationId = String(body.installationId || "").trim() || null;
    if (await ownedByAnotherInstallation(body.agentId, installationId)) return reply(409, { error: "agent id belongs to another installation" });
    try {
      await pool.query("INSERT INTO agents(agent_id,name,machine_id,installation_id,token_hash,status,last_seen_at,version) VALUES($1,$2,$3,$4,$5,'online',now(),$6) ON CONFLICT(agent_id) DO UPDATE SET name=excluded.name,machine_id=COALESCE(excluded.machine_id,agents.machine_id),installation_id=COALESCE(agents.installation_id,excluded.installation_id),status='online',last_seen_at=now(),version=excluded.version", [body.agentId, body.name || body.agentId, body.machineId || null, installationId, hash(String(req.headers.authorization).slice(7)), body.version || null]);
    } catch (error) {
      // installation_id này đã gắn với một agent khác (Agent mất config rồi đăng ký lại bằng id cũ).
      if (error.code === "23505") return reply(409, { error: "installation already registered as another agent" });
      throw error;
    }
    void realtime.broadcastState();
    return reply(200, { ok: true, agentId: body.agentId });
  }, { public: true });

  router.add("POST", "/api/agents/clone", async ({ req, readBody, reply }) => {
    const body = await readBody();
    const sourceId = String(body.agentId || "");
    const machineId = String(body.machineId || "").trim();
    const installationId = String(body.installationId || "").trim() || null;
    if (!sourceId || !machineId) return reply(400, { error: "agentId and machineId are required" });
    if (!(await auth.agentAuthorizedForId(req, sourceId))) return unauthorized(reply);
    const token = crypto.randomBytes(32).toString("hex");
    // Agent có thể đã enroll thành công nhưng chết trước khi lưu config: cấp lại
    // token cho đúng agent của bản cài đó thay vì sinh thêm agent trùng lặp.
    const existing = installationId ? await pool.query("UPDATE agents SET token_hash=$2,machine_id=$3,status='online',last_seen_at=now() WHERE installation_id=$1 RETURNING agent_id AS \"agentId\",name", [installationId, hash(token), machineId]) : { rowCount: 0 };
    if (existing.rowCount) { void realtime.broadcastState(); return reply(200, { ...existing.rows[0], token, machineId, installationId }); }
    const source = await pool.query("SELECT name,monitor_config,heartbeat_seconds FROM agents WHERE agent_id=$1", [sourceId]);
    const agentId = `agent-${crypto.randomUUID()}`;
    const name = String(body.name || `${source.rows[0]?.name || "Agent HNTH"} - ${machineId.slice(0, 8)}`).trim();
    await pool.query("INSERT INTO agents(agent_id,name,machine_id,installation_id,token_hash,status,last_seen_at,version,heartbeat_seconds,monitor_config) VALUES($1,$2,$3,$4,$5,'online',now(),$6,$7,$8)", [agentId, name, machineId, installationId, hash(token), body.version ? String(body.version) : null, source.rows[0]?.heartbeat_seconds ?? 30, JSON.stringify(source.rows[0]?.monitor_config || {})]);
    void realtime.broadcastState();
    return reply(201, { agentId, name, token, machineId, installationId });
  }, { public: true });

  router.add("POST", "/api/agents/heartbeat", async ({ req, readBody, reply }) => {
    const body = await readBody();
    if (!body.agentId) return reply(400, { error: "agentId required" });
    if (!(await auth.agentAuthorizedForId(req, body.agentId))) return unauthorized(reply);
    if (body.installationId && await ownedByAnotherInstallation(body.agentId, String(body.installationId))) return reply(409, { error: "agent id belongs to another installation" });
    const result = await pool.query("UPDATE agents SET status='online',last_seen_at=now(),version=COALESCE($2,version),machine_id=COALESCE($3,machine_id) WHERE agent_id=$1 RETURNING agent_id AS \"agentId\",status,last_seen_at AS \"lastSeenAt\",version", [body.agentId, body.version || null, body.machineId || null]);
    if (!result.rowCount) return reply(404, { error: "agent not registered" });
    void realtime.broadcastState();
    return reply(200, { ok: true, ...result.rows[0] });
  }, { public: true });

  // Agent poll mỗi 3 giây, nhận tối đa một lệnh pending (cũ nhất) mỗi lần.
  router.add("GET", "/api/agents/:agentId/commands", async ({ req, params, reply }) => {
    if (!(await auth.agentAuthorizedForId(req, params.agentId))) return unauthorized(reply);
    const result = await pool.query("WITH next AS (SELECT id FROM commands WHERE agent_id=$1 AND status='pending' ORDER BY created_at LIMIT 1) UPDATE commands c SET status='claimed',claimed_at=now() FROM next WHERE c.id=next.id RETURNING c.type,c.payload", [params.agentId]);
    const command = result.rows[0];
    // Đổi token: từ lúc Agent nhận lệnh, chỉ token mới còn hợp lệ.
    if (command?.type === "agent-config" && command.payload?.token) await pool.query("UPDATE agents SET token_hash=$1 WHERE agent_id=$2", [hash(String(command.payload.token)), params.agentId]);
    return reply(200, command ? { type: command.type, ...command.payload } : { type: "none" });
  }, { public: true });

  router.add("POST", "/api/agents/update-result", async ({ req, readBody, reply }) => {
    const body = await readBody();
    const agentId = String(body.agentId || "");
    if (!agentId || !(await auth.agentAuthorizedForId(req, agentId))) return unauthorized(reply);
    const version = String(body.version || "").trim();
    const status = String(body.status || "failed").trim();
    if (!version || !["success", "failed"].includes(status)) return reply(400, { error: "invalid update result" });
    await pool.query("INSERT INTO agent_update_events(agent_id,version,status,detail) VALUES($1,$2,$3,$4)", [agentId, version, status, String(body.detail || "").slice(0, 2000)]);
    if (status === "success") await pool.query("UPDATE agents SET version=$2,status='online',last_seen_at=now() WHERE agent_id=$1", [agentId, version]);
    return reply(202, { accepted: true });
  }, { public: true });

  router.add("GET", "/api/agent-releases/:version", async ({ req, res, url, params, reply }) => {
    const agentId = String(url.searchParams.get("agentId") || "");
    if (!agentId || !(await auth.agentAuthorizedForId(req, agentId))) return unauthorized(reply);
    const release = await pool.query("SELECT file_path,file_name,sha256,size_bytes FROM agent_releases WHERE version=$1", [params.version]);
    if (!release.rowCount) return reply(404, { error: "release not found" });
    const item = release.rows[0];
    res.writeHead(200, { "content-type": "application/vnd.microsoft.portable-executable", "content-length": item.size_bytes, "content-disposition": `attachment; filename="${item.file_name}"`, "cache-control": "no-store" });
    createReadStream(item.file_path).on("error", () => res.destroy()).pipe(res);
  }, { public: true });
}
