import path from "node:path";

// Giá trị chỉ dùng khi chạy local (pnpm dev / docker-compose.source.yml). Production
// (NODE_ENV=production, docker-compose.production|demo.yml) bắt buộc truyền qua env.
const DEV_JWT_SECRET = "local-only-change-this-jwt-secret";
const DEV_AGENT_TOKEN = "local-hnth-test-7f3c9a2e5d1b";

export function loadConfig(env = process.env) {
  const production = env.NODE_ENV === "production";
  const missing = ["JWT_SECRET", "HNTH_AGENT_TOKEN"].filter((name) => !String(env[name] || "").trim());
  if (production && missing.length) throw new Error(`Thiếu biến môi trường bắt buộc ở production: ${missing.join(", ")}`);
  return {
    production,
    port: Number(env.PORT || 8788),
    // DATABASE_URL do db.mjs tự đọc khi tạo pool.
    jwtSecret: env.JWT_SECRET || DEV_JWT_SECRET,
    agentToken: env.HNTH_AGENT_TOKEN || DEV_AGENT_TOKEN,
    // Agent mặc định khi monitor_state chưa có agent nào được chọn.
    defaultAgentId: env.HNTH_DEFAULT_AGENT_ID || "agent-demo",
    adminUsername: env.ADMIN_USERNAME || "admin",
    adminPassword: env.ADMIN_PASSWORD || "admin123!",
    webOrigins: (env.WEB_ORIGIN || "http://127.0.0.1:5173").split(",").map((origin) => origin.trim()).filter(Boolean),
    releaseDir: path.resolve(env.HNTH_RELEASE_DIR || path.join(process.cwd(), "agent-releases")),
    // Docker production đặt backend sau Caddy (chỉ `expose`), nên mặc định tin
    // X-Forwarded-For/-Proto ở production. Dev chạy trực tiếp thì không.
    trustProxy: env.TRUST_PROXY ? env.TRUST_PROXY === "true" : production,
    // Cookie refresh có cờ Secure: "auto" = theo từng request (HTTPS mới đặt), vì bản
    // demo LAN chạy production qua http://IP và cookie Secure sẽ không được gửi lại.
    cookieSecure: ["true", "false"].includes(env.COOKIE_SECURE) ? env.COOKIE_SECURE === "true" : "auto",
  };
}
