import bcrypt from "bcryptjs";
import { pool } from "../db.mjs";
import { normalizeMenus, requireRole, ROLE_RANK } from "../auth.mjs";

const USER_COLUMNS = "id,username,display_name AS \"displayName\",role,department,phone,menu_permissions AS \"menuPermissions\",is_active AS \"isActive\",created_at AS \"createdAt\"";
const audit = (userId, action, resource, metadata) => pool.query("INSERT INTO audit_logs(user_id,action,resource,metadata) VALUES($1,$2,$3,$4)", [userId, action, resource, JSON.stringify(metadata)]);

export function registerUserRoutes(router) {
  router.add("GET", "/api/users", async ({ user, reply }) => {
    if (!requireRole(user, "admin")) return reply(403, { error: "forbidden" });
    const rows = await pool.query(`SELECT ${USER_COLUMNS} FROM users ORDER BY username`);
    return reply(200, rows.rows);
  });

  router.add("POST", "/api/users", async ({ user, readBody, reply }) => {
    if (!requireRole(user, "admin")) return reply(403, { error: "forbidden" });
    const body = await readBody();
    const username = String(body.username || "").trim();
    const displayName = String(body.displayName || username).trim();
    const role = String(body.role || "viewer");
    const password = String(body.password || "");
    if (!/^[a-zA-Z0-9._-]{3,40}$/.test(username) || !displayName || password.length < 8 || !Object.hasOwn(ROLE_RANK, role)) return reply(400, { error: "username, displayName, role and password (min 8 chars) are required" });
    try {
      const result = await pool.query(`INSERT INTO users(username,password_hash,display_name,role,department,phone,menu_permissions,is_active) VALUES($1,$2,$3,$4,$5,$6,$7,$8) RETURNING ${USER_COLUMNS}`, [username, await bcrypt.hash(password, 12), displayName, role, String(body.department || "").trim(), String(body.phone || "").trim(), JSON.stringify(normalizeMenus(body.menuPermissions)), body.isActive !== false]);
      await audit(user.id, "create", "user", { username, role });
      return reply(201, result.rows[0]);
    } catch (error) {
      if (error.code === "23505") return reply(409, { error: "username already exists" });
      throw error;
    }
  });

  router.add("PUT", "/api/users/:id", async ({ user, params, readBody, reply }) => {
    if (!requireRole(user, "admin")) return reply(403, { error: "forbidden" });
    const body = await readBody();
    const role = String(body.role || "viewer");
    if (!Object.hasOwn(ROLE_RANK, role)) return reply(400, { error: "invalid role" });
    if (params.id === user.id && body.isActive === false) return reply(400, { error: "cannot deactivate current user" });
    const displayName = String(body.displayName || "").trim();
    if (!displayName) return reply(400, { error: "displayName is required" });
    const result = await pool.query(`UPDATE users SET display_name=$1,role=$2,department=$3,phone=$4,menu_permissions=$5,is_active=$6,updated_at=now() WHERE id=$7 RETURNING ${USER_COLUMNS}`, [displayName, role, String(body.department || "").trim(), String(body.phone || "").trim(), JSON.stringify(normalizeMenus(body.menuPermissions)), body.isActive !== false, params.id]);
    if (!result.rowCount) return reply(404, { error: "user not found" });
    if (body.password) await pool.query("UPDATE users SET password_hash=$1,updated_at=now() WHERE id=$2", [await bcrypt.hash(String(body.password), 12), params.id]);
    await audit(user.id, "update", "user", { targetUserId: params.id, role });
    return reply(200, result.rows[0]);
  });

  // "Xóa" là vô hiệu hóa, giữ lịch sử audit.
  router.add("DELETE", "/api/users/:id", async ({ user, params, reply }) => {
    if (!requireRole(user, "admin")) return reply(403, { error: "forbidden" });
    if (params.id === user.id) return reply(400, { error: "cannot delete current user" });
    const result = await pool.query("UPDATE users SET is_active=false,updated_at=now() WHERE id=$1 RETURNING id", [params.id]);
    if (!result.rowCount) return reply(404, { error: "user not found" });
    await audit(user.id, "delete", "user", { targetUserId: params.id });
    return reply(200, { ok: true });
  });

  router.add("GET", "/api/audit-logs", async ({ user, reply }) => {
    if (!requireRole(user, "admin")) return reply(403, { error: "forbidden" });
    const rows = await pool.query("SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT 500");
    return reply(200, rows.rows);
  });
}
