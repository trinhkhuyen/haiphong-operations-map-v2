// Dữ liệu chủ điểm cầu (Import) và danh sách phiên họp chọn điểm từ dữ liệu chủ (Operator).
// Dữ liệu chủ + danh sách đang áp dụng đi kèm snapshot công khai (realtime.currentState) nên
// mọi màn hình, kể cả Guest/Trình chiếu, thấy cùng tên điểm và cùng các điểm Sở/Ban/Ngành.
// Agent chỉ nhận các điểm của danh sách đang áp dụng (hoặc toàn bộ dữ liệu chủ khi không chọn).
import { pool } from "../db.mjs";
import { requireRole } from "../auth.mjs";
import { normalizeRosterPointIds, normalizeRosterPoints, rosterAgentPoints } from "../services/rosters.mjs";

const SUMMARY = "id,name,jsonb_array_length(point_ids) AS \"pointCount\",updated_at AS \"updatedAt\"";
const isUuid = (value) => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(String(value));

export const loadCatalog = async () => (await pool.query("SELECT points FROM hnth_catalog WHERE id=1")).rows[0]?.points ?? [];

/** Điểm của phiên: danh sách đang áp dụng lọc từ dữ liệu chủ; không chọn danh sách = toàn bộ dữ liệu chủ; chưa Import = null. */
export async function sessionPoints() {
  const catalog = await loadCatalog();
  if (!catalog.length) return null;
  const roster = (await pool.query("SELECT r.point_ids FROM monitor_state m JOIN hnth_rosters r ON r.id=m.active_roster_id WHERE m.id=1")).rows[0];
  if (!roster) return catalog;
  const ids = new Set(roster.point_ids);
  return catalog.filter((point) => ids.has(point.pointId));
}

export function registerHnthRosterRoutes(router, { realtime }) {
  const syncAgent = async () => {
    const state = (await pool.query("SELECT agent_id FROM monitor_state WHERE id=1")).rows[0];
    if (state) await applyRosterToAgent(state.agent_id, await sessionPoints());
  };
  const readRoster = async (body) => {
    const name = String(body?.name ?? "").trim().slice(0, 120);
    if (!name) return { error: "Tên danh sách là bắt buộc" };
    const catalogIds = new Set((await loadCatalog()).map((point) => point.pointId));
    const normalized = normalizeRosterPointIds(body?.pointIds, catalogIds);
    return normalized.error ? normalized : { name, pointIds: normalized.pointIds };
  };

  router.add("GET", "/api/hnth/catalog", async ({ user, reply }) => {
    if (!requireRole(user, "operator")) return reply(403, { error: "forbidden" });
    const row = (await pool.query("SELECT points,updated_at AS \"updatedAt\" FROM hnth_catalog WHERE id=1")).rows[0];
    return reply(200, { points: row?.points ?? [], updatedAt: row?.updatedAt ?? null });
  });

  // Import thay toàn bộ dữ liệu chủ. Điểm bị bỏ khỏi dữ liệu chủ cũng bị bỏ khỏi mọi danh sách.
  router.add("PUT", "/api/hnth/catalog", async ({ user, readBody, reply }) => {
    if (!requireRole(user, "operator")) return reply(403, { error: "forbidden" });
    const normalized = normalizeRosterPoints((await readBody())?.points);
    if (normalized.error) return reply(400, { error: normalized.error });
    if (!normalized.points.length) return reply(400, { error: "Dữ liệu điểm cầu phải có ít nhất 1 điểm" });
    await pool.query("INSERT INTO hnth_catalog(id,points,updated_at) VALUES(1,$1,now()) ON CONFLICT(id) DO UPDATE SET points=excluded.points,updated_at=now()", [JSON.stringify(normalized.points)]);
    const ids = normalized.points.map((point) => point.pointId);
    const pruned = await pool.query("UPDATE hnth_rosters SET point_ids=(SELECT COALESCE(jsonb_agg(e.pid ORDER BY e.ord),'[]'::jsonb) FROM jsonb_array_elements_text(point_ids) WITH ORDINALITY AS e(pid,ord) WHERE e.pid = ANY($1::text[])),updated_at=now() WHERE EXISTS (SELECT 1 FROM jsonb_array_elements_text(point_ids) AS e(pid) WHERE NOT (e.pid = ANY($1::text[]))) RETURNING name", [ids]);
    await syncAgent();
    await realtime.broadcastState();
    return reply(200, { pointCount: normalized.points.length, prunedRosters: pruned.rows.map((row) => row.name) });
  });

  router.add("GET", "/api/hnth/rosters", async ({ user, reply }) => {
    if (!requireRole(user, "operator")) return reply(403, { error: "forbidden" });
    const rows = await pool.query(`SELECT ${SUMMARY} FROM hnth_rosters ORDER BY name`);
    const active = await pool.query("SELECT active_roster_id FROM monitor_state WHERE id=1");
    return reply(200, { rosters: rows.rows, activeRosterId: active.rows[0]?.active_roster_id ?? null });
  });

  router.add("GET", "/api/hnth/rosters/:id", async ({ user, params, reply }) => {
    if (!requireRole(user, "operator")) return reply(403, { error: "forbidden" });
    if (!isUuid(params.id)) return reply(404, { error: "roster not found" });
    const row = await pool.query("SELECT id,name,point_ids AS \"pointIds\",updated_at AS \"updatedAt\" FROM hnth_rosters WHERE id=$1", [params.id]);
    return row.rowCount ? reply(200, row.rows[0]) : reply(404, { error: "roster not found" });
  });

  router.add("POST", "/api/hnth/rosters", async ({ user, readBody, reply }) => {
    if (!requireRole(user, "operator")) return reply(403, { error: "forbidden" });
    const roster = await readRoster(await readBody());
    if (roster.error) return reply(400, { error: roster.error });
    const created = await pool.query(`INSERT INTO hnth_rosters(name,point_ids,created_by) VALUES($1,$2,$3) ON CONFLICT(name) DO NOTHING RETURNING ${SUMMARY}`, [roster.name, JSON.stringify(roster.pointIds), user.id]);
    if (!created.rowCount) return reply(409, { error: `Đã có danh sách tên "${roster.name}"` });
    return reply(201, created.rows[0]);
  });

  router.add("PUT", "/api/hnth/rosters/:id", async ({ user, params, readBody, reply }) => {
    if (!requireRole(user, "operator")) return reply(403, { error: "forbidden" });
    if (!isUuid(params.id)) return reply(404, { error: "roster not found" });
    const roster = await readRoster(await readBody());
    if (roster.error) return reply(400, { error: roster.error });
    const duplicate = await pool.query("SELECT 1 FROM hnth_rosters WHERE name=$1 AND id<>$2", [roster.name, params.id]);
    if (duplicate.rowCount) return reply(409, { error: `Đã có danh sách tên "${roster.name}"` });
    const updated = await pool.query(`UPDATE hnth_rosters SET name=$2,point_ids=$3,updated_at=now() WHERE id=$1 RETURNING ${SUMMARY}`, [params.id, roster.name, JSON.stringify(roster.pointIds)]);
    if (!updated.rowCount) return reply(404, { error: "roster not found" });
    // Sửa đúng danh sách đang áp dụng thì đồng bộ ngay điểm giao cho Agent và mọi màn hình.
    const active = await pool.query("SELECT 1 FROM monitor_state WHERE id=1 AND active_roster_id=$1", [params.id]);
    if (active.rowCount) {
      await syncAgent();
      await realtime.broadcastState();
    }
    return reply(200, { ...updated.rows[0], active: active.rowCount > 0 });
  });

  router.add("DELETE", "/api/hnth/rosters/:id", async ({ user, params, reply }) => {
    if (!requireRole(user, "operator")) return reply(403, { error: "forbidden" });
    if (!isUuid(params.id)) return reply(404, { error: "roster not found" });
    const active = await pool.query("SELECT 1 FROM monitor_state WHERE id=1 AND active_roster_id=$1", [params.id]);
    if (active.rowCount) return reply(409, { error: "Danh sách đang áp dụng, hãy chọn danh sách khác trước khi xóa" });
    const deleted = await pool.query("DELETE FROM hnth_rosters WHERE id=$1", [params.id]);
    return deleted.rowCount ? reply(200, { deleted: true }) : reply(404, { error: "roster not found" });
  });

  // Áp dụng danh sách cho phiên hiện tại; id "default" = toàn bộ dữ liệu chủ (chưa Import thì 115 điểm mặc định).
  // Đang Giám sát liên tục thì giao diện gửi lại lệnh bật để Agent ping theo danh sách mới.
  router.add("POST", "/api/hnth/rosters/:id/activate", async ({ user, params, reply }) => {
    if (!requireRole(user, "operator")) return reply(403, { error: "forbidden" });
    const useDefault = params.id === "default";
    if (!useDefault && !isUuid(params.id)) return reply(404, { error: "roster not found" });
    const roster = useDefault ? null : (await pool.query("SELECT id,name FROM hnth_rosters WHERE id=$1", [params.id])).rows[0];
    if (!useDefault && !roster) return reply(404, { error: "roster not found" });
    const state = (await pool.query("UPDATE monitor_state SET active_roster_id=$1,updated_at=now(),revision=revision+1 WHERE id=1 RETURNING enabled", [roster?.id ?? null])).rows[0];
    await syncAgent();
    await pool.query("INSERT INTO audit_logs(user_id,action,resource,metadata) VALUES($1,'activate','hnth-roster',$2)", [user.id, JSON.stringify({ rosterId: roster?.id ?? null, name: roster?.name ?? "default" })]);
    await realtime.broadcastState();
    return reply(200, { activeRosterId: roster?.id ?? null, monitoring: Boolean(state?.enabled), points: await sessionPoints() });
  });
}

/**
 * Ghi điểm của phiên vào endpoints (tên + IP) và danh sách điểm giao cho Agent.
 * `points` null = chưa có dữ liệu chủ: bỏ phân công để giao diện tự giao 115 điểm mặc định như trước.
 */
export async function applyRosterToAgent(agentId, points) {
  if (points) {
    for (const point of points) {
      await pool.query("INSERT INTO endpoints(endpoint_id,name,ip_address,model_vendor) VALUES($1,$2,NULLIF($3,'')::inet,NULLIF($4,'')) ON CONFLICT(endpoint_id) DO UPDATE SET name=excluded.name,ip_address=excluded.ip_address,model_vendor=COALESCE(excluded.model_vendor,endpoints.model_vendor),enabled=true,updated_at=now()", [point.pointId, point.name, point.ipAddress, point.modelVendor]);
    }
  }
  const agent = (await pool.query("SELECT heartbeat_seconds,monitor_config FROM agents WHERE agent_id=$1", [agentId])).rows[0];
  if (!agent) return;
  const monitorConfig = { ...(agent.monitor_config || {}) };
  if (points) monitorConfig.points = rosterAgentPoints(points);
  else delete monitorConfig.points;
  await pool.query("UPDATE agents SET monitor_config=$2 WHERE agent_id=$1", [agentId, JSON.stringify(monitorConfig)]);
  await pool.query("INSERT INTO commands(agent_id,type,payload) VALUES($1,'agent-config',$2)", [agentId, JSON.stringify({ heartbeatSeconds: agent.heartbeat_seconds || 30, ...monitorConfig })]);
}
