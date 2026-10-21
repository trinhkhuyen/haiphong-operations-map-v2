import bcrypt from "bcryptjs";
import { pool } from "../db.mjs";
import { hash, userView } from "../auth.mjs";
import { clientIp } from "../http.mjs";
import { createLoginLimiter } from "../services/login-limiter.mjs";

export function registerAuthRoutes(router, { auth, config, loginLimiter = createLoginLimiter() }) {
  router.add("POST", "/api/auth/login", async ({ req, readBody, reply }) => {
    const body = await readBody();
    const ip = clientIp(req, config.trustProxy);
    const gate = loginLimiter.check(ip, body.username);
    if (!gate.allowed) return reply(429, { error: "too many login attempts" }, { "retry-after": String(gate.retryAfterSeconds) });
    const result = await pool.query("SELECT * FROM users WHERE username=$1 AND is_active=true", [body.username]);
    const user = result.rows[0];
    if (!user || !(await bcrypt.compare(String(body.password || ""), user.password_hash))) {
      loginLimiter.recordFailure(ip, body.username);
      return reply(401, { error: "invalid credentials" });
    }
    loginLimiter.recordSuccess(ip, body.username);
    return reply(200, { accessToken: auth.signAccessToken(user), user: userView(user) }, { "set-cookie": await auth.issueRefreshCookie(user.id, req) });
  }, { public: true });

  // Xoay vòng: refresh token cũ bị thu hồi, cấp token mới.
  router.add("POST", "/api/auth/refresh", async ({ req, reply }) => {
    const raw = auth.readRefreshToken(req);
    if (!raw) return reply(401, { error: "refresh required" });
    const result = await pool.query("SELECT u.* FROM refresh_tokens r JOIN users u ON u.id=r.user_id WHERE r.token_hash=$1 AND r.revoked_at IS NULL AND r.expires_at>now() AND u.is_active=true", [hash(raw)]);
    const user = result.rows[0];
    if (!user) return reply(401, { error: "invalid refresh" });
    await pool.query("UPDATE refresh_tokens SET revoked_at=now() WHERE token_hash=$1", [hash(raw)]);
    return reply(200, { accessToken: auth.signAccessToken(user), user: userView(user) }, { "set-cookie": await auth.issueRefreshCookie(user.id, req) });
  }, { public: true });

  router.add("POST", "/api/auth/logout", async ({ req, reply }) => {
    const raw = auth.readRefreshToken(req);
    if (raw) await pool.query("UPDATE refresh_tokens SET revoked_at=now() WHERE token_hash=$1", [hash(raw)]);
    return reply(200, { ok: true }, { "set-cookie": auth.clearedRefreshCookie(req) });
  }, { public: true });

  router.add("GET", "/api/auth/me", async ({ user, reply }) => reply(200, userView(user)));

  router.add("POST", "/api/auth/change-password", async ({ user, readBody, reply }) => {
    const body = await readBody();
    if (String(body.newPassword || "").length < 8) return reply(400, { error: "Mật khẩu mới tối thiểu 8 ký tự" });
    const current = await pool.query("SELECT password_hash FROM users WHERE id=$1", [user.id]);
    if (!current.rowCount || !(await bcrypt.compare(String(body.currentPassword || ""), current.rows[0].password_hash))) return reply(400, { error: "Mật khẩu hiện tại không đúng" });
    await pool.query("UPDATE users SET password_hash=$1,updated_at=now() WHERE id=$2", [await bcrypt.hash(String(body.newPassword), 12), user.id]);
    return reply(200, { ok: true });
  });

  router.add("PUT", "/api/auth/profile", async ({ user, readBody, reply }) => {
    const body = await readBody();
    const displayName = String(body.displayName || "").trim();
    if (!displayName) return reply(400, { error: "Họ và tên là bắt buộc" });
    const result = await pool.query("UPDATE users SET display_name=$1,department=$2,phone=$3,updated_at=now() WHERE id=$4 RETURNING *", [displayName, String(body.department || "").trim(), String(body.phone || "").trim(), user.id]);
    return reply(200, { user: userView(result.rows[0]) });
  });
}
