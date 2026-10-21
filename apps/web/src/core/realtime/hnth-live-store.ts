// Trạng thái live dùng chung từ backend (không persist): backend sống/chết, agent
// đang được chọn cho HNTH và cờ Giám sát liên tục. Chỉ `hnth-realtime` và thao
// tác bật/tắt giám sát ghi vào đây; thay cho các event hnth:agent-status và
// hnth:continuous-monitoring trước đây.
import { create } from "zustand";

export type LinkState = "checking" | "online" | "offline";
export type MonitoringInfo = { enabled: boolean; concurrency?: number; waitSeconds?: number };
export type SelectedAgentInfo = { agentId: string; name: string; state: LinkState; checkedAt: number | null };

type HnthLiveState = {
  backend: LinkState;
  backendCheckedAt: number | null;
  agent: SelectedAgentInfo;
  monitoring: MonitoringInfo;
  setBackend: (backend: LinkState) => void;
  setAgent: (agent: Omit<SelectedAgentInfo, "checkedAt">) => void;
  setMonitoring: (monitoring: MonitoringInfo) => void;
};

export const useHnthLiveStore = create<HnthLiveState>()((set, get) => ({
  backend: "checking",
  backendCheckedAt: null,
  agent: { agentId: "", name: "Agent HNTH", state: "checking", checkedAt: null },
  monitoring: { enabled: false },
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
