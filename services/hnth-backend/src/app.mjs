import { createAuth } from "./auth.mjs";
import { createCors, readJson, sendJson } from "./http.mjs";
import { createRouter } from "./router.mjs";
import { createRealtime } from "./services/realtime.mjs";
import { registerAgentApiRoutes } from "./routes/agent-api.mjs";
import { registerAgentRoutes } from "./routes/agents.mjs";
import { registerAuthRoutes } from "./routes/auth.mjs";
import { registerHnthRoutes } from "./routes/hnth.mjs";
import { registerTelemetryRoutes } from "./routes/telemetry.mjs";
import { registerUserRoutes } from "./routes/users.mjs";

/** Dựng toàn bộ backend; trả request handler cho http.createServer. */
export function createApp(config) {
  const corsOrigin = createCors(config.webOrigins);
  const auth = createAuth(config);
  const realtime = createRealtime(config);
  const router = createRouter();
  const deps = { config, auth, realtime };
  registerAuthRoutes(router, deps);
  registerUserRoutes(router, deps);
  registerAgentApiRoutes(router, deps);
  registerAgentRoutes(router, deps);
  registerTelemetryRoutes(router, deps);
  registerHnthRoutes(router, deps);

  async function handle(req, res) {
    const origin = corsOrigin(req);
    const reply = (status, body, headers = {}) => sendJson(res, status, body, headers, origin);
    try {
      if (req.method === "OPTIONS") return reply(204, {});
      const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);
      if (req.method === "GET" && url.pathname === "/health") {
        await realtime.healthCheck();
        return reply(200, { ok: true, service: "hnth-backend", database: "ok" });
      }
      const match = router.match(req.method, url.pathname);
      // Route riêng tư và mọi đường dẫn không khớp đều cần đăng nhập trước: chưa đăng
      // nhập thì 401 (không lộ route nào tồn tại), đã đăng nhập mà không khớp thì 404.
      let user = null;
      if (!match?.route.public) {
        user = await auth.authenticateUser(req);
        if (!user) return reply(401, { error: "unauthorized" });
        if (!match) return reply(404, { error: "not found" });
      }
      return await match.route.handler({ req, res, url, params: match.params, user, reply, corsOrigin: origin, readBody: () => readJson(req) });
    } catch (error) {
      console.error(error);
      // Không trả nguyên error.message (có thể lộ câu SQL, tên bảng, đường dẫn file).
      if (error.message === "invalid json") return reply(400, { error: "invalid json" });
      if (error.message === "body too large") return reply(413, { error: "body too large" });
      return reply(500, { error: "internal error" });
    }
  }

  return { handle, auth, realtime };
}
