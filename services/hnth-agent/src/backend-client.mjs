import { setAgentState } from "./status.mjs";

// Mọi request tới backend (hoặc relay cũ khi backendUrl rỗng) đi qua đây để log
// chuyển trạng thái kết nối đúng một lần mỗi khi đổi.
export function createBackendClient(config) {
  const apiBase = config.backendUrl ? new URL(config.backendUrl) : null;
  const apiUrl = (pathname) => apiBase ? new URL(pathname, apiBase).toString() : null;
  const telemetryUrl = apiBase ? apiUrl("/api/telemetry/ping-results") : config.relayUrl;
  // Đọc token mỗi lần gọi: agent-config và enroll có thể đổi token lúc đang chạy.
  const authHeaders = () => ({ authorization: `Bearer ${config.token}`, "content-type": "application/json" });

  let connection = "unknown";
  // Lần cuối backend trả lời 2xx; monitor dùng để tự dừng khi mất backend quá lâu.
  // Tính từ lúc khởi động để Agent không dừng ngay khi backend chưa kịp trả lời lần đầu.
  let lastContactAt = Date.now();
  function reportConnection(next, detail = "") {
    if (connection === next) return;
    connection = next;
    setAgentState({ backend: next });
    const prefix = next === "online" ? "BACKEND ONLINE" : next === "offline" ? "BACKEND OFFLINE" : "BACKEND AUTH ERROR";
    console.log(`[${new Date().toISOString()}] ${prefix}${detail ? `: ${detail}` : ""}`);
  }

  async function request(url, options = {}) {
    try {
      const response = await fetch(url, options);
      if (response.ok) lastContactAt = Date.now();
      if (response.status === 401 || response.status === 403) reportConnection("unauthorized", `${response.status} at ${new URL(url).pathname}`);
      else reportConnection(response.ok ? "online" : "offline", response.ok ? "" : `${response.status} at ${new URL(url).pathname}`);
      return response;
    } catch (error) {
      reportConnection("offline", error instanceof Error ? error.message : String(error));
      throw error;
    }
  }

  const postJson = (url, body) => request(url, { method: "POST", headers: authHeaders(), body: JSON.stringify(body) });

  // Không có backendUrl: lệnh và danh sách IP quét được đi tới cùng host với relayUrl.
  function commandsUrl() {
    const pathname = `/api/agents/${encodeURIComponent(config.agentId)}/commands`;
    if (apiBase) return apiUrl(pathname);
    const value = new URL(config.relayUrl);
    value.pathname = pathname;
    return value;
  }
  function discoveredIpsUrl() {
    const target = new URL(apiBase ? apiUrl("/api/telemetry/discovered-ips") : config.relayUrl);
    target.pathname = "/api/telemetry/discovered-ips";
    return target;
  }

  return { msSinceContact: () => Date.now() - lastContactAt, apiBase, apiUrl, telemetryUrl, authHeaders, request, postJson, commandsUrl, discoveredIpsUrl };
}
