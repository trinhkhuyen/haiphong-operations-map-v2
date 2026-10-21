import crypto from "node:crypto";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { pool } from "./db.mjs";
import { readCookie } from "./http.mjs";

export const ROLE_RANK = { viewer: 1, operator: 2, admin: 3 };
export const ALL_MENUS = ["layers", "zones", "saved", "routing", "conference", "agents"];
const REFRESH_COOKIE = "hnth_refresh";
const REFRESH_MAX_AGE_SECONDS = 2592000;

export const hash = (value) => crypto.createHash("sha256").update(value).digest("hex");
export const requireRole = (user, minimum) => Boolean(user) && ROLE_RANK[user.role] >= ROLE_RANK[minimum];
export const normalizeMenus = (value) => Array.isArray(value) ? value.filter((item) => ALL_MENUS.includes(item)) : ALL_MENUS;
export const userView = (user) => ({ id: user.id, username: user.username, displayName: user.display_name, role: user.role, department: user.department || "", phone: user.phone || "", menuPermissions: user.menu_permissions || ALL_MENUS });

export function createAuth(config) {
  const signAccessToken = (user) => jwt.sign({ sub: user.id, username: user.username, role: user.role }, config.jwtSecret, { expiresIn: "15m" });

  /** Người dùng của Bearer JWT nếu hợp lệ và còn hoạt động, ngược lại null. */
  async function authenticateUser(req) {
    const value = String(req.headers.authorization || "");
    if (!value.startsWith("Bearer ")) return null;
    try {
      const claims = jwt.verify(value.slice(7), config.jwtSecret);
      const result = await pool.query("SELECT id,username,display_name,role,is_active,menu_permissions FROM users WHERE id=$1", [claims.sub]);
      return result.rows[0]?.is_active ? result.rows[0] : null;
    } catch { return null; }
  }

  /** Token chung HNTH_AGENT_TOKEN mở mọi agentId; token riêng chỉ mở đúng agent của nó. */
  async function agentAuthorizedForId(req, agentId) {
    const value = String(req.headers.authorization || "");
    if (value === `Bearer ${config.agentToken}`) return true;
    if (!value.startsWith("Bearer ")) return false;
    const result = await pool.query("SELECT token_hash FROM agents WHERE agent_id=$1", [agentId]);
    return result.rowCount > 0 && result.rows[0].token_hash === hash(value.slice(7));
  }

  /** Tạo refresh token mới (lưu hash), trả giá trị Set-Cookie. */
  async function issueRefreshCookie(userId) {
    const raw = crypto.randomBytes(48).toString("hex");
    await pool.query("INSERT INTO refresh_tokens(user_id,token_hash,expires_at) VALUES($1,$2,now()+interval '30 days')", [userId, hash(raw)]);
    return `${REFRESH_COOKIE}=${raw}; HttpOnly; SameSite=Lax; Path=/; Max-Age=${REFRESH_MAX_AGE_SECONDS}`;
  }

  const readRefreshToken = (req) => readCookie(req, REFRESH_COOKIE);
  const clearedRefreshCookie = `${REFRESH_COOKIE}=; HttpOnly; Path=/; Max-Age=0`;

  async function seedAdmin() {
    const found = await pool.query("SELECT id FROM users WHERE username=$1", [config.adminUsername]);
    if (!found.rowCount) await pool.query("INSERT INTO users(username,password_hash,display_name,role) VALUES($1,$2,$3,'admin')", [config.adminUsername, await bcrypt.hash(config.adminPassword, 12), "HNTH Administrator"]);
  }

  return { signAccessToken, authenticateUser, agentAuthorizedForId, issueRefreshCookie, readRefreshToken, clearedRefreshCookie, seedAdmin };
}
