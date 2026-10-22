// Chức năng HNTH: live-view công khai (Guest, Trình chiếu) và điều khiển giám sát (Operator).
import { isIP } from "node:net";
import { MONITOR_LEASE_SECONDS } from "@haiphong-ops/hnth-protocol";
import { pool } from "../db.mjs";
import { requireRole } from "../auth.mjs";
import { AGENT_SUMMARY_COLUMNS, withLiveStatus } from "../services/realtime.mjs";

export function registerHnthRoutes(router, { realtime }) {
  const agentExists = async (agentId) => (await pool.query("SELECT agent_id FROM agents WHERE agent_id=$1", [agentId])).rowCount > 0;

  // ---- Công khai, chỉ đọc: Guest phải xem được trạng thái HNTH dùng chung mà không cần đăng nhập.
  router.add("GET", "/api/hnth/stream", ({ req, res, corsOrigin }) => realtime.openStream(req, res, corsOrigin), { public: true });
  router.add("GET", "/api/hnth/monitor-state", async ({ reply }) => reply(200, await realtime.currentState()), { public: true });
  router.add("GET", "/api/hnth/status", async ({ reply }) => reply(200, await realtime.currentState()), { public: true });

  router.add("GET", "/api/hnth/endpoints", async ({ reply }) => {
    const rows = await pool.query("SELECT endpoint_id AS \"pointId\",name,host(ip_address) AS \"ipAddress\",model_vendor AS \"modelVendor\",status,latency_ms AS \"latencyMs\",packet_loss_pct AS \"packetLossPct\",jitter_ms AS \"jitterMs\",checked_at AS \"checkedAt\" FROM endpoints WHERE enabled=true AND endpoint_id LIKE 'hnth-%' ORDER BY name");
    return reply(200, rows.rows);
  }, { public: true });

  router.add("GET", "/api/hnth/discovered-ips", async ({ url, reply }) => {
    const agentId = url.searchParams.get("agentId") || (await realtime.selectedAgentId());
    const rows = await pool.query("SELECT host(ip_address) AS \"ipAddress\",status,mac_address AS \"macAddress\",model_vendor AS \"modelVendor\",discovered_at AS \"discoveredAt\" FROM discovered_ips WHERE agent_id=$1 ORDER BY ip_address", [agentId]);
    return reply(200, { updatedAt: new Date().toISOString(), agentId, ips: rows.rows });
  }, { public: true });

  router.add("GET", "/api/hnth/monitor-log", async ({ url, reply }) => {
    const pointId = String(url.searchParams.get("pointId") || "").trim();
    const agentId = await realtime.selectedAgentId();
    const columns = "endpoint_id AS \"pointId\",ip_address AS \"ipAddress\",status,latency_ms AS \"latencyMs\",checked_at AS \"checkedAt\",received_at AS \"receivedAt\"";
    const rows = pointId
      ? await pool.query(`SELECT ${columns} FROM monitor_logs WHERE agent_id=$1 AND endpoint_id=$2 ORDER BY received_at DESC LIMIT 1000`, [agentId, pointId])
      : await pool.query(`SELECT ${columns} FROM monitor_logs WHERE agent_id=$1 ORDER BY received_at DESC LIMIT 1000`, [agentId]);
    return reply(200, { entries: rows.rows, pointId: pointId || null });
  }, { public: true });

  // Mặc định là agent đang được chọn cho HNTH.
  router.add("GET", "/api/agent-status", async ({ url, reply }) => {
    const agentId = url.searchParams.get("agentId") || (await realtime.selectedAgentId());
    const result = await pool.query(`SELECT ${AGENT_SUMMARY_COLUMNS} FROM agents WHERE agent_id=$1`, [agentId]);
    if (!result.rowCount) return reply(200, { agentId, name: agentId, status: "offline", lastSeenAt: null });
    return reply(200, withLiveStatus(result.rows[0]));
  }, { public: true });

  // ---- Điều khiển (Operator trở lên).
  router.add("POST", "/api/hnth/scan", async ({ user, readBody, reply }) => {
    if (!requireRole(user, "operator")) return reply(403, { error: "forbidden" });
    const body = await readBody();
    const agentId = String(body.agentId || (await realtime.selectedAgentId()));
    if (!(await agentExists(agentId))) return reply(404, { error: "agent not found" });
    await pool.query("INSERT INTO commands(agent_id,type,payload) VALUES($1,'scan-local-network',$2)", [agentId, JSON.stringify({ scanSubnets: body.scanSubnets || [] })]);
    return reply(202, { accepted: true, agentId });
  });

  router.add("POST", "/api/hnth/test", async ({ user, readBody, reply }) => {
    if (!requireRole(user, "operator")) return reply(403, { error: "forbidden" });
    const body = await readBody();
    // Agent đưa ipAddress vào ping.exe: chỉ nhận literal IP (agent cũng tự chặn).
    const pointId = String(body.pointId || "").trim();
    const ipAddress = String(body.ipAddress || "").trim();
    if (!pointId || !isIP(ipAddress)) return reply(400, { error: "pointId and a valid ipAddress are required" });
    await pool.query("INSERT INTO commands(agent_id,type,payload) VALUES($1,'test-point',$2)", [await realtime.selectedAgentId(), JSON.stringify({ pointId, ipAddress })]);
    return reply(202, { accepted: true });
  });

  router.add("POST", "/api/hnth/point-config", async ({ user, readBody, reply }) => {
    if (!requireRole(user, "operator")) return reply(403, { error: "forbidden" });
    const body = await readBody();
    const pointId = String(body.pointId || "").trim();
    const ipAddress = String(body.ipAddress || "").trim();
    const agentId = String(body.agentId || (await realtime.selectedAgentId()));
    if (!pointId) return reply(400, { error: "pointId is required" });
    if (!(await agentExists(agentId))) return reply(404, { error: "agent not found" });
    const endpoint = await pool.query("INSERT INTO endpoints(endpoint_id,name,ip_address,model_vendor,status,checked_at) VALUES($1,$1,CASE WHEN $2='' THEN NULL ELSE $2::inet END,$3,'unknown',NULL) ON CONFLICT(endpoint_id) DO UPDATE SET ip_address=excluded.ip_address,model_vendor=COALESCE(excluded.model_vendor,endpoints.model_vendor),status='unknown',checked_at=NULL,updated_at=now() RETURNING endpoint_id AS \"pointId\",host(ip_address) AS \"ipAddress\",status", [pointId, ipAddress, body.modelVendor || null]);
    // Có dữ liệu chủ điểm cầu thì IP sửa ở Cấu hình điểm cũng lưu vào dữ liệu chủ.
    await pool.query("UPDATE hnth_catalog c SET points=(SELECT jsonb_agg(CASE WHEN p->>'pointId'=$1 THEN p || jsonb_build_object('ipAddress',$2::text,'modelVendor',COALESCE($3::text,p->>'modelVendor')) ELSE p END ORDER BY ord) FROM jsonb_array_elements(c.points) WITH ORDINALITY AS e(p,ord)),updated_at=now() WHERE c.id=1 AND c.points @> jsonb_build_array(jsonb_build_object('pointId',$1::text))", [pointId, ipAddress, body.modelVendor || null]);
    // Lệnh cấu hình điểm mới thay lệnh cũ chưa được Agent nhận cho cùng điểm.
    await pool.query("UPDATE commands SET status='superseded' WHERE agent_id=$1 AND status='pending' AND type='point-config' AND payload->>'pointId'=$2", [agentId, pointId]);
    await pool.query("INSERT INTO commands(agent_id,type,payload) VALUES($1,'point-config',$2)", [agentId, JSON.stringify({ pointId, ipAddress, modelVendor: body.modelVendor || null, forceTest: Boolean(ipAddress) })]);
    await realtime.broadcastState();
    return reply(202, { accepted: true, agentId, endpoint: endpoint.rows[0] });
  });

  router.add("POST", "/api/hnth/selected-agent", async ({ user, readBody, reply }) => {
    if (!requireRole(user, "operator")) return reply(403, { error: "forbidden" });
    const body = await readBody();
    const agentId = String(body.agentId || "").trim();
    if (!agentId || !(await agentExists(agentId))) return reply(404, { error: "agent not found" });
    // Đang giám sát liên tục thì agent cũ vẫn ping; đổi agent giữa chừng sẽ làm
    // trạng thái trên bản đồ trộn kết quả của hai agent.
    const monitor = await pool.query("SELECT enabled,agent_id FROM monitor_state WHERE id=1");
    if (monitor.rows[0]?.enabled && monitor.rows[0].agent_id !== agentId) return reply(409, { error: "Tắt Giám sát liên tục trước khi đổi Agent" });
    await pool.query("UPDATE monitor_state SET agent_id=$1,updated_at=now(),revision=revision+1 WHERE id=1", [agentId]);
    await pool.query("INSERT INTO audit_logs(user_id,action,resource,metadata) VALUES($1,'select','hnth-agent',$2)", [user.id, JSON.stringify({ agentId })]);
    await realtime.broadcastState();
    return reply(200, { agentId });
  });

  // Giao diện Operator đang mở gia hạn lease mỗi MONITOR_LEASE_RENEW_SECONDS. Không gia hạn
  // phiên đã tắt/hết hạn (renewed=false) để đóng hết cửa sổ thì giám sát dừng thật.
  router.add("POST", "/api/hnth/monitor/lease", async ({ user, reply }) => {
    if (!requireRole(user, "operator")) return reply(403, { error: "forbidden" });
    const result = await pool.query("UPDATE monitor_state SET lease_expires_at=now() + make_interval(secs => $1) WHERE id=1 AND enabled AND (lease_expires_at IS NULL OR lease_expires_at >= now()) RETURNING lease_expires_at AS \"leaseExpiresAt\"", [MONITOR_LEASE_SECONDS]);
    return reply(200, { renewed: result.rowCount > 0, leaseExpiresAt: result.rows[0]?.leaseExpiresAt ?? null });
  });

  router.add("POST", "/api/hnth/monitor", async ({ user, readBody, reply }) => {
    if (!requireRole(user, "operator")) return reply(403, { error: "forbidden" });
    const body = await readBody();
    const submittedPoints = Array.isArray(body.points) ? body.points.map((point) => ({
      point_id: String(point.point_id ?? point.pointId ?? ""),
      name: String(point.name ?? point.pointName ?? point.point_id ?? point.pointId ?? ""),
      ip_address: String(point.ip_address ?? point.ipAddress ?? "").trim(),
      model_vendor: point.model_vendor ?? point.modelVendor ?? null,
    })).filter((point) => point.point_id) : [];
    // Danh sách gửi lên là nguồn sự thật cho agent/phiên này. Không gộp với danh mục
    // endpoint toàn cục: danh sách import 50 điểm không được biến thành 115 điểm cũ.
    const points = submittedPoints.filter((point) => point.ip_address);
    const currentMonitor = await pool.query("SELECT enabled,session_id AS \"sessionId\" FROM monitor_state WHERE id=1");
    const wasEnabled = Boolean(currentMonitor.rows[0]?.enabled);
    const previousSessionId = currentMonitor.rows[0]?.sessionId ?? null;
    const startingNewSession = Boolean(body.enabled) && (!wasEnabled || body.resetStatuses === true);
    if (body.enabled) {
      // Lưu cấu hình trước khi dựng lệnh: database là nguồn sự thật, yêu cầu mới không
      // được làm sống lại danh sách IP cũ trong bộ nhớ hay hàng đợi.
      await pool.query("UPDATE endpoints SET ip_address=NULL,status='unknown',checked_at=NULL,updated_at=now() WHERE endpoint_id = ANY($1::text[]) AND enabled=true", [submittedPoints.filter((point) => !point.ip_address).map((point) => point.point_id)]);
      await pool.query("INSERT INTO endpoints(endpoint_id,name,ip_address,model_vendor) SELECT x.point_id,x.point_id,x.ip_address,x.model_vendor FROM jsonb_to_recordset($1::jsonb) AS x(point_id text,ip_address inet,model_vendor text) ON CONFLICT(endpoint_id) DO UPDATE SET ip_address=excluded.ip_address,model_vendor=COALESCE(excluded.model_vendor,endpoints.model_vendor),updated_at=now()", [JSON.stringify(points)]);
      // Mỗi lần bật là một phiên mới: endpoint quay về unknown trước batch đầu tiên.
      // Không xóa monitor_logs vì đó là lịch sử.
      if (startingNewSession && points.length) await pool.query("UPDATE endpoints SET status='unknown',checked_at=NULL,updated_at=now() WHERE endpoint_id = ANY($1::text[])", [points.map((point) => point.point_id)]);
    }
    const concurrency = Math.max(1, Math.min(30, Number(body.concurrency || 1)));
    const waitSeconds = Math.max(1, Math.min(10, Number(body.waitSeconds || 3)));
    const targetAgentId = String(body.agentId || (await realtime.selectedAgentId()));
    if (!(await agentExists(targetAgentId))) return reply(404, { error: "agent not found" });
    if (startingNewSession) {
      await pool.query("UPDATE monitor_state SET enabled=true,agent_id=$1,concurrency=$2,wait_seconds=$3,session_id=gen_random_uuid(),started_at=now(),lease_expires_at=now() + make_interval(secs => $4),updated_at=now(),revision=revision+1 WHERE id=1", [targetAgentId, concurrency, waitSeconds, MONITOR_LEASE_SECONDS]);
    } else {
      await pool.query("UPDATE monitor_state SET enabled=$1,agent_id=$2,concurrency=$3,wait_seconds=$4,started_at=CASE WHEN $1 THEN COALESCE(started_at,now()) ELSE NULL END,lease_expires_at=CASE WHEN $1 THEN now() + make_interval(secs => $5) ELSE NULL END,updated_at=now(),revision=revision+1 WHERE id=1", [Boolean(body.enabled), targetAgentId, concurrency, waitSeconds, MONITOR_LEASE_SECONDS]);
    }
    await pool.query("UPDATE commands SET status='superseded' WHERE agent_id=$1 AND status='pending' AND type IN ('monitor-start','monitor-stop')", [targetAgentId]);
    const session = await pool.query("SELECT session_id AS \"sessionId\" FROM monitor_state WHERE id=1");
    const sessionId = session.rows[0]?.sessionId ?? (body.enabled ? previousSessionId : null);
    await pool.query("INSERT INTO commands(agent_id,type,payload) VALUES($1,$2,$3)", [targetAgentId, body.enabled ? "monitor-start" : "monitor-stop", JSON.stringify({ points: points.map((point) => ({ pointId: point.point_id, name: point.name, ipAddress: point.ip_address, modelVendor: point.model_vendor })), concurrency, waitSeconds, resetStatuses: startingNewSession, sessionId })]);
    await realtime.broadcastState();
    return reply(202, { accepted: true, points: points.length, sessionId });
  });
}
