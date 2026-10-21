#!/usr/bin/env node
// Smoke test chỉ-đọc cho hnth-backend đang chạy. Không ghi dữ liệu.
//   node scripts/smoke-backend.mjs                       -> http://127.0.0.1:8788
//   BACKEND_URL=https://map.example.vn node scripts/smoke-backend.mjs   (qua Caddy production)
//   Không trỏ vào Vite dev (5173): Vite chỉ proxy /api, /health sẽ trả về index.html.
//   SMOKE_USER=admin SMOKE_PASSWORD=... node scripts/smoke-backend.mjs (kiểm tra thêm đăng nhập)
const base = (process.env.BACKEND_URL || "http://127.0.0.1:8788").replace(/\/$/, "");
let failed = 0;

async function check(label, path, { expect = 200, init = {}, validate } = {}) {
  try {
    const response = await fetch(`${base}${path}`, init);
    const body = await response.json().catch(() => null);
    const problem = response.status !== expect ? `HTTP ${response.status}, mong đợi ${expect}` : validate?.(body);
    if (problem) throw new Error(problem);
    console.log(`✔ ${label}`);
    return body;
  } catch (error) {
    failed += 1;
    console.log(`✘ ${label}: ${error.message}`);
    return null;
  }
}

await check("GET /health", "/health", { validate: (b) => (b?.ok ? null : "ok !== true") });
await check("GET /api/hnth/monitor-state", "/api/hnth/monitor-state", { validate: (b) => (Array.isArray(b?.results) && Array.isArray(b?.agents) ? null : "thiếu results/agents") });
await check("GET /api/agent-status", "/api/agent-status", { validate: (b) => (b && "status" in b ? null : "thiếu status") });
await check("GET /api/agents không có token -> 401", "/api/agents", { expect: 401 });
await check("POST /api/telemetry/ping-results sai token -> 401", "/api/telemetry/ping-results", {
  expect: 401,
  init: { method: "POST", headers: { "content-type": "application/json", authorization: "Bearer invalid-smoke-token" }, body: JSON.stringify({ agentId: "smoke-nonexistent", results: [] }) },
});

if (process.env.SMOKE_USER && process.env.SMOKE_PASSWORD) {
  const login = await check("POST /api/auth/login", "/api/auth/login", {
    init: { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ username: process.env.SMOKE_USER, password: process.env.SMOKE_PASSWORD }) },
    validate: (b) => (b?.accessToken ? null : "thiếu accessToken"),
  });
  if (login?.accessToken) {
    await check("GET /api/auth/me", "/api/auth/me", { init: { headers: { authorization: `Bearer ${login.accessToken}` } }, validate: (b) => (b?.username ? null : "thiếu username") });
  }
}

console.log(failed ? `\n${failed} kiểm tra thất bại (${base})` : `\nBackend OK (${base})`);
// Không gọi process.exit(): trên Node 25/Windows thoát cứng khi socket keep-alive
// của fetch còn mở gây assertion libuv (UV_HANDLE_CLOSING).
process.exitCode = failed ? 1 : 0;
