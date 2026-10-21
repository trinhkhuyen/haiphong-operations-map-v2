import http from "node:http";

const port = Number(process.env.PORT || 8787);
const agentToken = process.env.HNTH_AGENT_TOKEN || "change-me";
const latest = new Map();
const monitorHistory = new Map();
const clients = new Set();
const commands = new Map();
const discoveredIps = new Map();
const monitorPointsByAgent = new Map();

function json(response, status, body) {
  response.writeHead(status, { "content-type": "application/json; charset=utf-8", "access-control-allow-origin": "*" });
  response.end(JSON.stringify(body));
}

function broadcast(message) {
  const payload = `data: ${JSON.stringify(message)}\n\n`;
  for (const client of clients) client.write(payload);
}

const server = http.createServer(async (request, response) => {
  if (request.method === "OPTIONS") {
    response.writeHead(204, { "access-control-allow-origin": "*", "access-control-allow-headers": "content-type, authorization" });
    return response.end();
  }
  if (request.method === "GET" && request.url === "/health") return json(response, 200, { ok: true, agents: latest.size });
  if (request.method === "GET" && request.url === "/api/hnth/status") return json(response, 200, { updatedAt: new Date().toISOString(), results: [...latest.values()].flatMap((item) => item.results) });
  if (request.method === "GET" && request.url === "/api/hnth/monitor-log") return json(response, 200, { entries: monitorHistory.get(process.env.HNTH_DEFAULT_AGENT_ID || "agent-demo") || [] });
  if (request.method === "POST" && request.url === "/api/hnth/scan") {
    const agentId = request.headers["x-agent-id"] || process.env.HNTH_DEFAULT_AGENT_ID || "agent-demo";
    let body = "";
    request.on("data", (chunk) => { body += chunk; });
    request.on("end", () => {
      try {
        const payload = body ? JSON.parse(body) : {};
        const scanSubnets = Array.isArray(payload.scanSubnets) ? payload.scanSubnets.filter((item) => typeof item === "string") : undefined;
        commands.set(agentId, { type: "scan-local-network", scanSubnets, requestedAt: new Date().toISOString() });
        json(response, 202, { accepted: true, agentId });
      } catch { json(response, 400, { error: "invalid json" }); }
    });
    return;
  }
  if (request.method === "POST" && request.url === "/api/hnth/test") {
    const agentId = request.headers["x-agent-id"] || process.env.HNTH_DEFAULT_AGENT_ID || "agent-demo";
    let body = "";
    request.on("data", (chunk) => { body += chunk; });
    request.on("end", () => {
      try {
        const payload = body ? JSON.parse(body) : {};
        if (typeof payload.pointId !== "string" || typeof payload.ipAddress !== "string") return json(response, 400, { error: "pointId and ipAddress are required" });
        commands.set(agentId, { type: "test-point", pointId: payload.pointId, ipAddress: payload.ipAddress, requestedAt: new Date().toISOString() });
        json(response, 202, { accepted: true, agentId });
      } catch { json(response, 400, { error: "invalid json" }); }
    });
    return;
  }
  if (request.method === "POST" && request.url === "/api/hnth/point-config") {
    const agentId = request.headers["x-agent-id"] || process.env.HNTH_DEFAULT_AGENT_ID || "agent-demo";
    let body = "";
    request.on("data", (chunk) => { body += chunk; });
    request.on("end", () => {
      try {
        const payload = body ? JSON.parse(body) : {};
        if (typeof payload.pointId !== "string" || typeof payload.ipAddress !== "string") return json(response, 400, { error: "pointId and ipAddress are required" });
        commands.set(agentId, { type: "point-config", pointId: payload.pointId, ipAddress: payload.ipAddress.trim(), requestedAt: new Date().toISOString() });
        json(response, 202, { accepted: true, agentId });
      } catch { json(response, 400, { error: "invalid json" }); }
    });
    return;
  }
  if (request.method === "POST" && request.url === "/api/hnth/monitor") {
    const agentId = request.headers["x-agent-id"] || process.env.HNTH_DEFAULT_AGENT_ID || "agent-demo";
    let body = "";
    request.on("data", (chunk) => { body += chunk; });
    request.on("end", () => {
      try {
        const payload = body ? JSON.parse(body) : {};
        const requestedPoints = Array.isArray(payload.points) ? payload.points.filter((item) => item && typeof item.pointId === "string" && typeof item.ipAddress === "string" && item.ipAddress.trim()) : [];
        const previousPoints = monitorPointsByAgent.get(agentId) || [];
        // A transient frontend render must never replace a complete monitoring
        // roster with a partial one (observed payloads of 12-14 points while
        // changing concurrency). Keep the last complete roster instead.
        const points = payload.enabled && requestedPoints.length < 100 && previousPoints.length >= 100
          ? previousPoints
          : requestedPoints;
        if (payload.enabled && points.length >= 100) monitorPointsByAgent.set(agentId, points);
        const enabled = Boolean(payload.enabled);
        if (enabled) {
          // A new monitoring session starts from an explicitly unknown state.
          // Clear the relay snapshot as well as the browser state; otherwise a
          // reconnect or SSE snapshot can immediately resurrect old statuses.
          const previous = latest.get(agentId);
          const previousByPoint = new Map((previous?.results || []).map((item) => [item.pointId, item]));
          const resetResults = points.map((point) => ({
            ...(previousByPoint.get(point.pointId) || {}),
            pointId: point.pointId,
            ipAddress: point.ipAddress,
            status: "unknown",
            checkedAt: new Date().toISOString(),
          }));
          latest.set(agentId, { agentId, timestamp: new Date().toISOString(), results: resetResults });
          monitorHistory.set(agentId, []);
          broadcast({ type: "snapshot", agentId, results: resetResults, reset: true });
        }
        commands.set(agentId, { type: enabled ? "monitor-start" : "monitor-stop", points, resetStatuses: enabled, concurrency: Math.min(30, Math.max(1, Number(payload.concurrency) || 1)), waitSeconds: Math.min(10, Math.max(1, Number(payload.waitSeconds) || 3)), requestedAt: new Date().toISOString() });
        json(response, 202, { accepted: true, agentId, points: points.length, requestedPoints: requestedPoints.length, rosterPreserved: points !== requestedPoints });
      } catch { json(response, 400, { error: "invalid json" }); }
    });
    return;
  }
  const commandMatch = request.method === "GET" && request.url.match(/^\/api\/agents\/([^/]+)\/commands$/);
  if (commandMatch) {
    const command = commands.get(commandMatch[1]);
    commands.delete(commandMatch[1]);
    return json(response, 200, command || { type: "none" });
  }
  if (request.method === "GET" && request.url === "/api/hnth/discovered-ips") return json(response, 200, { updatedAt: new Date().toISOString(), ips: [...discoveredIps.values()].flat() });
  if (request.method === "GET" && request.url === "/api/hnth/stream") {
    response.writeHead(200, { "content-type": "text/event-stream; charset=utf-8", "cache-control": "no-cache, no-transform", connection: "keep-alive", "x-accel-buffering": "no", "access-control-allow-origin": "*" });
    response.flushHeaders?.();
    response.write(`data: ${JSON.stringify({ type: "snapshot", results: [...latest.values()].flatMap((item) => item.results) })}\n\n`);
    clients.add(response);
    const timer = setInterval(() => { try { response.write(`: keepalive ${Date.now()}\n\n`); } catch { clearInterval(timer); clients.delete(response); } }, 5000);
    request.on("close", () => { clearInterval(timer); clients.delete(response); });
    return;
  }
  if (request.method === "POST" && request.url === "/api/telemetry/ping-results") {
    if (request.headers.authorization !== `Bearer ${agentToken}`) return json(response, 401, { error: "unauthorized" });
    let body = "";
    request.on("data", (chunk) => { body += chunk; });
    request.on("end", () => {
      try {
        const snapshot = JSON.parse(body);
        if (!snapshot.agentId || !Array.isArray(snapshot.results)) return json(response, 400, { error: "invalid snapshot" });
        const previous = latest.get(snapshot.agentId);
        const resultsByPoint = new Map((previous?.results || []).map((item) => [item.pointId, item]));
        for (const item of snapshot.results) resultsByPoint.set(item.pointId, item);
        latest.set(snapshot.agentId, { ...snapshot, results: [...resultsByPoint.values()] });
        if (snapshot.monitorBatch) {
          const history = monitorHistory.get(snapshot.agentId) || [];
          history.push({ ...snapshot.monitorBatch, results: snapshot.results, receivedAt: new Date().toISOString() });
          monitorHistory.set(snapshot.agentId, history.slice(-500));
        }
        broadcast({ type: "snapshot", agentId: snapshot.agentId, results: snapshot.results, monitorBatch: snapshot.monitorBatch ? { ...snapshot.monitorBatch, results: snapshot.results, allResults: snapshot.monitorBatch.allResults || snapshot.results } : undefined });
        json(response, 202, { accepted: true });
      } catch { json(response, 400, { error: "invalid json" }); }
    });
    return;
  }
  if (request.method === "POST" && request.url === "/api/telemetry/discovered-ips") {
    if (request.headers.authorization !== `Bearer ${agentToken}`) return json(response, 401, { error: "unauthorized" });
    let body = "";
    request.on("data", (chunk) => { body += chunk; });
    request.on("end", () => {
      try {
        const snapshot = JSON.parse(body);
        if (!snapshot.agentId || !Array.isArray(snapshot.ips)) return json(response, 400, { error: "invalid scan" });
        discoveredIps.set(snapshot.agentId, snapshot.ips);
        broadcast({ type: "discovered-ips", agentId: snapshot.agentId, ips: snapshot.ips });
        json(response, 202, { accepted: true });
      } catch { json(response, 400, { error: "invalid json" }); }
    });
    return;
  }
  json(response, 404, { error: "not found" });
});

server.listen(port, "0.0.0.0", () => console.log(`Relay HNTH listening on :${port}`));
