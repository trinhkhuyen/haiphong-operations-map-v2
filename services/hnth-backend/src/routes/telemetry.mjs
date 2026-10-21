// Agent đẩy kết quả đo về backend (token agent).
import { pool } from "../db.mjs";

export function registerTelemetryRoutes(router, { auth, realtime }) {
  const touchAgent = (agentId) => pool.query("UPDATE agents SET status='online',last_seen_at=now() WHERE agent_id=$1", [agentId]);

  router.add("POST", "/api/telemetry/ping-results", async ({ req, readBody, reply }) => {
    const body = await readBody();
    if (!body.agentId || !Array.isArray(body.results)) return reply(400, { error: "invalid snapshot" });
    if (!(await auth.agentAuthorizedForId(req, body.agentId))) return reply(401, { error: "unauthorized" });
    await touchAgent(body.agentId);
    for (const item of body.results) {
      const pointId = String(item.pointId || item.ipAddress || "").trim();
      if (!pointId) continue;
      const ipAddress = String(item.ipAddress || "").trim() || null;
      // IP rỗng là cấu hình chưa xác định, bất kể agent/client gửi status gì.
      // Không cho phép dữ liệu cũ hoặc payload lỗi biến điểm này thành offline/lost.
      const status = ipAddress ? (item.status || "unknown") : "unknown";
      const checkedAt = item.checkedAt || new Date().toISOString();
      await pool.query("INSERT INTO endpoints(endpoint_id,name,ip_address,status,latency_ms,packet_loss_pct,jitter_ms,checked_at) VALUES($1,$1,$2::inet,$3,$4,$5,$6,$7) ON CONFLICT(endpoint_id) DO UPDATE SET ip_address=excluded.ip_address,status=excluded.status,latency_ms=excluded.latency_ms,packet_loss_pct=excluded.packet_loss_pct,jitter_ms=excluded.jitter_ms,checked_at=excluded.checked_at,updated_at=now()", [pointId, ipAddress, status, item.latencyMs ?? null, item.packetLossPct ?? null, item.jitterMs ?? null, checkedAt]);
      // Agent có thể gửi lại cùng một trạng thái (đặc biệt điểm trung tâm được gửi ở
      // mỗi vòng). Chỉ ghi log khi trạng thái hoặc IP thay đổi; snapshot vẫn broadcast
      // đầy đủ để bản đồ cập nhật tức thời.
      const previous = await pool.query("SELECT ip_address::text AS ip_address,status FROM monitor_logs WHERE agent_id=$1 AND endpoint_id=$2 ORDER BY received_at DESC LIMIT 1", [body.agentId, pointId]);
      const changed = !previous.rowCount || String(previous.rows[0].ip_address ?? "") !== String(ipAddress ?? "") || previous.rows[0].status !== status;
      if (changed) await pool.query("INSERT INTO monitor_logs(agent_id,endpoint_id,ip_address,status,latency_ms,packet_loss_pct,jitter_ms,checked_at) VALUES($1,$2,$3,$4,$5,$6,$7,$8)", [body.agentId, pointId, ipAddress, status, item.latencyMs ?? null, item.packetLossPct ?? null, item.jitterMs ?? null, checkedAt]);
    }
    await realtime.broadcastState({ monitorBatch: body.monitorBatch ? { ...body.monitorBatch, results: body.results, allResults: body.monitorBatch.allResults || body.results } : undefined });
    return reply(202, { accepted: true });
  }, { public: true });

  router.add("POST", "/api/telemetry/discovered-ips", async ({ req, readBody, reply }) => {
    const body = await readBody();
    if (!body.agentId || !Array.isArray(body.ips)) return reply(400, { error: "invalid scan" });
    if (!(await auth.agentAuthorizedForId(req, body.agentId))) return reply(401, { error: "unauthorized" });
    await touchAgent(body.agentId);
    for (const item of body.ips) await pool.query("INSERT INTO discovered_ips(agent_id,ip_address,status,mac_address,model_vendor,discovered_at) VALUES($1,$2,$3,$4,$5,$6) ON CONFLICT(agent_id,ip_address) DO UPDATE SET status=excluded.status,mac_address=COALESCE(excluded.mac_address,discovered_ips.mac_address),model_vendor=COALESCE(excluded.model_vendor,discovered_ips.model_vendor),discovered_at=excluded.discovered_at", [body.agentId, item.ipAddress, item.status || "online", item.macAddress || null, item.modelVendor || item.model || null, item.discoveredAt || new Date().toISOString()]);
    realtime.broadcast({ type: "discovered-ips", agentId: body.agentId, ips: body.ips });
    return reply(202, { accepted: true, count: body.ips.length });
  }, { public: true });

  router.add("POST", "/api/telemetry/snmp-results", async ({ req, readBody, reply }) => {
    const body = await readBody();
    if (!body.agentId || !Array.isArray(body.results)) return reply(400, { error: "invalid snmp payload" });
    if (!(await auth.agentAuthorizedForId(req, body.agentId))) return reply(401, { error: "unauthorized" });
    await touchAgent(body.agentId);
    for (const item of body.results) {
      if (!item.host || !item.oid) continue;
      await pool.query("INSERT INTO snmp_results(agent_id,target_id,host,oid,value,value_type,checked_at) VALUES($1,$2,$3::inet,$4,$5,$6,$7)", [body.agentId, item.targetId || item.host, item.host, item.oid, item.value ?? null, item.valueType || null, item.checkedAt || new Date().toISOString()]);
    }
    realtime.broadcast({ type: "snmp-results", agentId: body.agentId, results: body.results });
    return reply(202, { accepted: true, count: body.results.length });
  }, { public: true });
}
