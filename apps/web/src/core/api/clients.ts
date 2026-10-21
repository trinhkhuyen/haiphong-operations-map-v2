// Client theo nhóm API. Mỗi hàm gom đường dẫn, method và kiểu body vào một chỗ
// và trả về Response: nơi gọi tự đọc status/body như trước (thông báo lỗi khác
// nhau tùy màn hình).
import { apiUrl } from "./base";
import { hnthFetch, jsonRequest } from "./http";

export type MonitorPointRequest = { pointId: string; name?: string; ipAddress?: string | null; modelVendor?: string | null };
export type MonitorRequest = { enabled: boolean; concurrency?: number; waitSeconds?: number; agentId?: string; points?: unknown[] };
export type PointConfigRequest = { pointId: string; ipAddress: string; modelVendor?: string; agentId?: string };

export const hnthApi = {
  /** Cờ giám sát + snapshot đầy đủ (công khai, Guest cũng đọc được). */
  monitorState: () => hnthFetch(apiUrl("/api/hnth/monitor-state")),
  status: () => hnthFetch(apiUrl("/api/hnth/status")),
  streamUrl: () => apiUrl("/api/hnth/stream"),
  monitorLog: (pointId: string) => hnthFetch(apiUrl(`/api/hnth/monitor-log?pointId=${encodeURIComponent(pointId)}`)),
  discoveredIps: (agentId?: string) => hnthFetch(apiUrl(`/api/hnth/discovered-ips${agentId ? `?agentId=${encodeURIComponent(agentId)}` : ""}`)),
  testPoint: (body: { pointId: string; ipAddress: string }) => hnthFetch(apiUrl("/api/hnth/test"), jsonRequest("POST", body)),
  pointConfig: (body: PointConfigRequest) => hnthFetch(apiUrl("/api/hnth/point-config"), jsonRequest("POST", body)),
  setMonitoring: (body: MonitorRequest) => hnthFetch(apiUrl("/api/hnth/monitor"), jsonRequest("POST", body)),
  selectAgent: (agentId: string) => hnthFetch(apiUrl("/api/hnth/selected-agent"), jsonRequest("POST", { agentId })),
  scan: (body: { scanSubnets: string[]; agentId?: string }) => hnthFetch(apiUrl("/api/hnth/scan"), jsonRequest("POST", body)),
};

const agentPath = (agentId: string, suffix = "") => apiUrl(`/api/agents/${encodeURIComponent(agentId)}${suffix}`);

export const agentsApi = {
  list: (init: RequestInit = {}) => hnthFetch(apiUrl("/api/agents"), init),
  update: (agentId: string, body: Record<string, unknown>) => hnthFetch(agentPath(agentId), jsonRequest("PATCH", body)),
  setToken: (agentId: string, token: string) => hnthFetch(agentPath(agentId, "/token"), jsonRequest("POST", { token })),
  sendCommand: (agentId: string, body: { type: string } & Record<string, unknown>) => hnthFetch(agentPath(agentId, "/commands"), jsonRequest("POST", body)),
  uploadRelease: (file: File, query: { version?: string; fileName: string }) => {
    const params = `?version=${encodeURIComponent(query.version ?? "")}&fileName=${encodeURIComponent(query.fileName)}`;
    return hnthFetch(apiUrl(`/api/agent-releases${params}`), { method: "POST", headers: { "content-type": "application/octet-stream" }, body: file });
  },
};

export const usersApi = {
  list: () => hnthFetch(apiUrl("/api/users")),
  create: (body: Record<string, unknown>) => hnthFetch(apiUrl("/api/users"), jsonRequest("POST", body)),
  /** PUT thay toàn bộ hồ sơ; có `password` thì đổi luôn mật khẩu. */
  update: (id: string, body: Record<string, unknown>) => hnthFetch(apiUrl(`/api/users/${id}`), jsonRequest("PUT", body)),
  disable: (id: string) => hnthFetch(apiUrl(`/api/users/${id}`), { method: "DELETE" }),
};
