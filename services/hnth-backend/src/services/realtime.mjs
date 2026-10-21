import { pool } from "../db.mjs";

// Agent coi là online nếu có tín hiệu (heartbeat/telemetry) trong 30 giây gần nhất.
export const AGENT_ONLINE_WINDOW_MS = 30000;
export const isAgentOnline = (lastSeenAt, now = Date.now()) => Boolean(lastSeenAt) && now - new Date(lastSeenAt).getTime() < AGENT_ONLINE_WINDOW_MS;
export const withLiveStatus = (agent, now = Date.now()) => ({ ...agent, status: isAgentOnline(agent.lastSeenAt, now) ? "online" : "offline" });

const ENDPOINT_COLUMNS = "endpoint_id AS \"pointId\",name,host(ip_address) AS \"ipAddress\",model_vendor AS \"modelVendor\",status,latency_ms AS \"latencyMs\",packet_loss_pct AS \"packetLossPct\",jitter_ms AS \"jitterMs\",checked_at AS \"checkedAt\"";
export const AGENT_SUMMARY_COLUMNS = "agent_id AS \"agentId\",name,status,last_seen_at AS \"lastSeenAt\",version";

export function createRealtime(config) {
  const clients = new Set();

  // Agent đang được chọn cho chức năng HNTH, lưu trong monitor_state để mọi client
  // (Operator, Guest, cửa sổ Trình chiếu) cùng thấy một agent. Các API không truyền
  // agentId đều dùng agent này thay vì HNTH_DEFAULT_AGENT_ID.
  async function selectedAgentId() {
    const result = await pool.query("SELECT agent_id FROM monitor_state WHERE id=1");
    return result.rows[0]?.agent_id || config.defaultAgentId;
  }

  // B: hết lease (không còn trang Operator nào gia hạn) thì tắt cờ giám sát và gửi
  // monitor-stop cho Agent. Trả true khi vừa tắt để nơi gọi phát lại trạng thái.
  async function expireMonitorLease() {
    const expired = await pool.query("UPDATE monitor_state SET enabled=false,started_at=NULL,lease_expires_at=NULL,updated_at=now(),revision=revision+1 WHERE id=1 AND enabled AND lease_expires_at < now() RETURNING agent_id");
    if (!expired.rowCount) return false;
    const agentId = expired.rows[0].agent_id;
    await pool.query("UPDATE commands SET status='superseded' WHERE agent_id=$1 AND status='pending' AND type IN ('monitor-start','monitor-stop')", [agentId]);
    await pool.query("INSERT INTO commands(agent_id,type,payload) VALUES($1,'monitor-stop',$2)", [agentId, JSON.stringify({ reason: "lease-expired" })]);
    console.log(`[${new Date().toISOString()}] monitoring lease expired; sent monitor-stop to ${agentId}`);
    return true;
  }

  /** Quét lease định kỳ, kể cả khi không ai đọc trạng thái. unref để không giữ tiến trình sống. */
  function startLeaseSweeper(intervalMs = 15000) {
    const timer = setInterval(() => void expireMonitorLease().then((expired) => expired && broadcastState()).catch((error) => console.error(`Monitor lease sweep failed: ${error.message}`)), intervalMs);
    timer.unref();
    return () => clearInterval(timer);
  }

  /** Snapshot đầy đủ dùng chung cho /api/hnth/monitor-state, /status và SSE. */
  async function currentState() {
    // Kiểm tra lease ngay khi đọc để không trả cờ "đang giám sát" đã hết hạn.
    if (await expireMonitorLease()) setImmediate(() => void broadcastState());
    const monitor = await pool.query("SELECT enabled,agent_id AS \"agentId\",concurrency,wait_seconds AS \"waitSeconds\",session_id AS \"sessionId\",started_at AS \"startedAt\",updated_at AS \"updatedAt\",lease_expires_at AS \"leaseExpiresAt\",revision FROM monitor_state WHERE id=1");
    const row = monitor.rows[0] || { enabled: false, agentId: config.defaultAgentId, concurrency: 1, waitSeconds: 3, sessionId: null, startedAt: null, updatedAt: null, leaseExpiresAt: null, revision: 0 };
    const [agentConfig, agents] = await Promise.all([
      pool.query("SELECT monitor_config AS \"monitorConfig\" FROM agents WHERE agent_id=$1", [row.agentId]),
      pool.query(`SELECT ${AGENT_SUMMARY_COLUMNS} FROM agents ORDER BY agent_id`),
    ]);
    const configuredPoints = agentConfig.rows[0]?.monitorConfig?.points;
    const assignedPointIds = Array.isArray(configuredPoints)
      ? configuredPoints.map((point) => String(point?.pointId || point?.point_id || "").trim()).filter(Boolean)
      : null;
    const endpoints = assignedPointIds
      ? await pool.query(`SELECT ${ENDPOINT_COLUMNS} FROM endpoints WHERE enabled=true AND endpoint_id = ANY($1::text[]) ORDER BY endpoint_id`, [assignedPointIds])
      : await pool.query(`SELECT ${ENDPOINT_COLUMNS} FROM endpoints WHERE enabled=true AND endpoint_id LIKE 'hnth-%' ORDER BY endpoint_id`);
    const now = Date.now();
    return { monitoring: row, assignedPointIds, results: endpoints.rows, agents: agents.rows.map((agent) => withLiveStatus(agent, now)) };
  }

  function broadcast(event) {
    const payload = `data: ${JSON.stringify(event)}\n\n`;
    for (const client of clients) { try { client.write(payload); } catch { clients.delete(client); } }
  }

  async function broadcastState(extra = {}) {
    try { broadcast({ type: "state", ...(await currentState()), ...extra }); } catch (error) { console.error(`Realtime state broadcast failed: ${error.message}`); }
  }

  /** Mở luồng SSE: gửi snapshot ngay, giữ kết nối bằng keepalive 5 giây. */
  async function openStream(req, res, corsOrigin) {
    res.writeHead(200, { "content-type": "text/event-stream; charset=utf-8", "cache-control": "no-cache, no-transform", "connection": "keep-alive", "x-accel-buffering": "no", "access-control-allow-origin": corsOrigin, "access-control-allow-credentials": "true", "vary": "Origin" });
    res.flushHeaders?.();
    clients.add(res);
    try { res.write(`data: ${JSON.stringify({ type: "state", ...(await currentState()) })}\n\n`); } catch { clients.delete(res); }
    const timer = setInterval(() => { try { res.write(`: keepalive ${Date.now()}\n\n`); } catch { clearInterval(timer); clients.delete(res); } }, 5000);
    req.on("close", () => { clearInterval(timer); clients.delete(res); });
  }

  const healthCheck = () => pool.query("SELECT 1");

  return { selectedAgentId, expireMonitorLease, startLeaseSweeper, currentState, broadcast, broadcastState, openStream, healthCheck };
}
