// Quản lý Agent và bản phát hành từ giao diện (JWT Operator/Admin).
import crypto from "node:crypto";
import path from "node:path";
import { mkdir, rename, unlink } from "node:fs/promises";
import { OPERATOR_COMMAND_TYPES } from "@haiphong-ops/hnth-protocol";
import { pool } from "../db.mjs";
import { requireRole } from "../auth.mjs";
import { withLiveStatus } from "../services/realtime.mjs";
import { readExeFileVersion, safeReleaseFileName, safeReleaseVersion, writeRelease } from "../services/releases.mjs";

const enqueue = (agentId, type, payload) => pool.query("INSERT INTO commands(agent_id,type,payload) VALUES($1,$2,$3)", [agentId, type, typeof payload === "string" ? payload : JSON.stringify(payload)]);

export function registerAgentRoutes(router, { config }) {
  router.add("GET", "/api/agents", async ({ user, reply }) => {
    if (!requireRole(user, "operator")) return reply(403, { error: "forbidden" });
    const rows = await pool.query("SELECT a.agent_id AS \"agentId\",a.name,a.status,a.last_seen_at AS \"lastSeenAt\",a.version,a.heartbeat_seconds AS \"heartbeatSeconds\",a.monitor_config AS \"monitorConfig\",(SELECT json_build_object('version',e.version,'status',e.status,'detail',e.detail,'reportedAt',e.reported_at) FROM agent_update_events e WHERE e.agent_id=a.agent_id ORDER BY e.reported_at DESC LIMIT 1) AS \"lastUpdate\" FROM agents a ORDER BY a.name,a.agent_id");
    const now = Date.now();
    return reply(200, rows.rows.map((agent) => withLiveStatus(agent, now)));
  });

  router.add("PATCH", "/api/agents/:agentId", async ({ user, params, readBody, reply }) => {
    if (!requireRole(user, "admin")) return reply(403, { error: "forbidden" });
    const body = await readBody();
    const name = String(body.name || "").trim();
    const heartbeatSeconds = Math.max(5, Math.min(30, Number(body.heartbeatSeconds || 30)));
    if (!name) return reply(400, { error: "name is required" });
    const monitorConfig = body.monitorConfig && typeof body.monitorConfig === "object" ? body.monitorConfig : {};
    const newToken = String(body.token || "").trim();
    const result = await pool.query("UPDATE agents SET name=$1,heartbeat_seconds=$2,monitor_config=$3 WHERE agent_id=$4 RETURNING agent_id AS \"agentId\",name,status,last_seen_at AS \"lastSeenAt\",version,heartbeat_seconds AS \"heartbeatSeconds\",monitor_config AS \"monitorConfig\"", [name, heartbeatSeconds, JSON.stringify(monitorConfig), params.agentId]);
    if (!result.rowCount) return reply(404, { error: "agent not found" });
    await enqueue(params.agentId, "agent-config", { heartbeatSeconds, ...monitorConfig, ...(newToken ? { token: newToken } : {}) });
    return reply(200, result.rows[0]);
  });

  router.add("POST", "/api/agents/:agentId/token", async ({ user, params, readBody, reply }) => {
    if (!requireRole(user, "admin")) return reply(403, { error: "forbidden" });
    const body = await readBody();
    const newToken = String(body.token || "").trim();
    if (newToken.length < 16) return reply(400, { error: "Token phải có ít nhất 16 ký tự" });
    const found = await pool.query("SELECT agent_id FROM agents WHERE agent_id=$1", [params.agentId]);
    if (!found.rowCount) return reply(404, { error: "agent not found" });
    await enqueue(params.agentId, "agent-config", { token: newToken });
    return reply(202, { accepted: true, agentId: params.agentId });
  });

  router.add("POST", "/api/agents/:agentId/commands", async ({ user, params, readBody, reply }) => {
    if (!requireRole(user, "operator")) return reply(403, { error: "forbidden" });
    const body = await readBody();
    const { agentId } = params;
    const type = String(body.type || "");
    if (!OPERATOR_COMMAND_TYPES.includes(type)) return reply(400, { error: "unsupported command" });
    if (type === "agent-update" && !requireRole(user, "admin")) return reply(403, { error: "admin required for agent updates" });
    let { type: _type, ...payload } = body;
    if (type === "agent-update") {
      // Lệnh cập nhật lấy file/SHA-256 từ bản release đã lưu, không tin URL do trình duyệt
      // gửi lên. `path` là đường dẫn tương đối: Agent tự ghép với backendUrl của chính nó,
      // nên máy ở LAN khác vẫn tải được.
      const version = safeReleaseVersion(body.version);
      const release = version ? await pool.query("SELECT version,file_name,sha256,size_bytes FROM agent_releases WHERE version=$1", [version]) : { rowCount: 0 };
      if (!release.rowCount) return reply(404, { error: "release not found; upload the .exe first" });
      const item = release.rows[0];
      payload = { version: item.version, sha256: item.sha256, fileName: item.file_name, sizeBytes: Number(item.size_bytes), path: `/api/agent-releases/${encodeURIComponent(item.version)}?agentId=${encodeURIComponent(agentId)}` };
      await pool.query("UPDATE commands SET status='superseded' WHERE agent_id=$1 AND status='pending' AND type='agent-update'", [agentId]);
    }
    await enqueue(agentId, type, payload);
    return reply(202, { accepted: true, agentId, type });
  });

  router.add("GET", "/api/agent-releases", async ({ user, reply }) => {
    if (!requireRole(user, "operator")) return reply(403, { error: "forbidden" });
    const rows = await pool.query("SELECT version,file_name AS \"fileName\",sha256,size_bytes AS \"sizeBytes\",created_at AS \"createdAt\" FROM agent_releases ORDER BY created_at DESC");
    return reply(200, rows.rows);
  });

  // Body là file .exe thô (application/octet-stream).
  router.add("POST", "/api/agent-releases", async ({ req, url, user, reply }) => {
    if (!requireRole(user, "admin")) return reply(403, { error: "admin required" });
    const fileName = safeReleaseFileName(url.searchParams.get("fileName"));
    if (!fileName.toLowerCase().endsWith(".exe")) return reply(400, { error: "Chỉ chấp nhận file Agent dạng .exe" });
    await mkdir(config.releaseDir, { recursive: true });
    const tempPath = path.join(config.releaseDir, `${crypto.randomUUID()}.upload`);
    const uploaded = await writeRelease(req, tempPath);
    // Version lấy từ chính file .exe (ProductVersion do electron-builder ghi), không
    // dựa vào số người dùng gõ: Agent báo về đúng version này sau khi cập nhật.
    const version = safeReleaseVersion(await readExeFileVersion(tempPath));
    const requested = url.searchParams.get("version");
    if (!version || (requested && safeReleaseVersion(requested) !== version)) {
      await unlink(tempPath).catch(() => {});
      return reply(400, { error: version ? `File là bản ${version}, không phải ${requested}` : "Không đọc được version trong file .exe; hãy dùng file Agent build bằng electron-builder" });
    }
    const finalPath = path.join(config.releaseDir, `hnth-agent-${version}.exe`);
    await unlink(finalPath).catch(() => {});
    await rename(tempPath, finalPath);
    const result = await pool.query("INSERT INTO agent_releases(version,file_name,file_path,sha256,size_bytes,created_by) VALUES($1,$2,$3,$4,$5,$6) ON CONFLICT(version) DO UPDATE SET file_name=excluded.file_name,file_path=excluded.file_path,sha256=excluded.sha256,size_bytes=excluded.size_bytes,created_by=excluded.created_by,created_at=now() RETURNING version,file_name AS \"fileName\",sha256,size_bytes AS \"sizeBytes\"", [version, fileName, finalPath, uploaded.sha256, uploaded.size, user.id]);
    return reply(201, result.rows[0]);
  });
}
