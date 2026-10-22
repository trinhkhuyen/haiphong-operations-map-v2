// Trạng thái live dùng chung từ backend (không persist): backend sống/chết, agent
// đang được chọn cho HNTH và cờ Giám sát liên tục. Chỉ `hnth-realtime` và thao
// tác bật/tắt giám sát ghi vào đây; thay cho các event hnth:agent-status và
// hnth:continuous-monitoring trước đây.
import { create } from "zustand";

export type LinkState = "checking" | "online" | "offline";
export type MonitoringInfo = { enabled: boolean; concurrency?: number; waitSeconds?: number };
export type HnthRosterPointKind = "hub" | "ward" | "extra";
/** Một điểm trong dữ liệu chủ điểm cầu (backend hnth_catalog.points, nạp bằng Import). */
export type HnthRosterPoint = { pointId: string; kind: HnthRosterPointKind; name: string; ipAddress: string; gateway?: string; modelVendor?: string };
export type HnthCatalog = { points: HnthRosterPoint[]; updatedAt?: string };
/** Danh sách phiên họp: chỉ là các mã điểm chọn từ dữ liệu chủ. */
export type HnthRoster = { id: string; name: string; pointIds: string[]; updatedAt?: string };
export type SelectedAgentInfo = { agentId: string; name: string; state: LinkState; checkedAt: number | null };

type HnthLiveState = {
  backend: LinkState;
  backendCheckedAt: number | null;
  agent: SelectedAgentInfo;
  monitoring: MonitoringInfo;
  /** Dữ liệu chủ điểm cầu; null = chưa Import (dùng 115 điểm mặc định). */
  catalog: HnthCatalog | null;
  /** Danh sách của phiên đang áp dụng; null = toàn bộ dữ liệu chủ. */
  activeRoster: HnthRoster | null;
  setSessionPoints: (catalog: HnthCatalog | null, roster: HnthRoster | null) => void;
  setBackend: (backend: LinkState) => void;
  setAgent: (agent: Omit<SelectedAgentInfo, "checkedAt">) => void;
  setMonitoring: (monitoring: MonitoringInfo) => void;
};

export const useHnthLiveStore = create<HnthLiveState>()((set, get) => ({
  backend: "checking",
  backendCheckedAt: null,
  agent: { agentId: "", name: "Agent HNTH", state: "checking", checkedAt: null },
  monitoring: { enabled: false },
  catalog: null,
  activeRoster: null,
  // Snapshot đến mỗi 2-5 giây: chỉ thay khi dữ liệu thật sự đổi để lớp HNTH không dựng lại liên tục.
  setSessionPoints: (catalog, activeRoster) => {
    const catalogKey = (value: HnthCatalog | null) => value ? `${value.updatedAt ?? ""}|${value.points.length}` : "";
    const rosterKey = (value: HnthRoster | null) => value ? `${value.id}|${value.updatedAt ?? ""}|${value.pointIds.length}` : "";
    const current = get();
    const patch: Partial<HnthLiveState> = {};
    if (catalogKey(current.catalog) !== catalogKey(catalog)) patch.catalog = catalog;
    if (rosterKey(current.activeRoster) !== rosterKey(activeRoster)) patch.activeRoster = activeRoster;
    if (Object.keys(patch).length) set(patch);
  },
  setBackend: (backend) => set({ backend, backendCheckedAt: Date.now() }),
  setAgent: (agent) => set({ agent: { ...agent, checkedAt: Date.now() } }),
  // Chỉ thay object khi giá trị đổi: listener đồng bộ (log giám sát, nhịp hub)
  // phân biệt "phiên mới" bằng tham chiếu, và snapshot đến mỗi 2-5 giây.
  setMonitoring: (monitoring) => {
    const current = get().monitoring;
    if (current.enabled === monitoring.enabled && current.concurrency === monitoring.concurrency && current.waitSeconds === monitoring.waitSeconds) return;
    set({ monitoring });
  },
}));
