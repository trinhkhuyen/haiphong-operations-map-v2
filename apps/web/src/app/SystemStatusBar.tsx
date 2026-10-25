import { useEffect, useState } from "react";
import { agentsApi } from "../core/api/clients";
import { subscribeHnthSnapshots } from "../core/realtime/hnth-realtime";
import { useHnthLiveStore } from "../core/realtime/hnth-live-store";
import { useAppStore } from "../core/store";
import { demoMode } from "../core/runtime";

const checkedAtText = (checkedAt: number | null) => checkedAt
  ? `Kiểm tra ${new Date(checkedAt).toLocaleTimeString("vi-VN", { hour: "2-digit", minute: "2-digit" })}`
  : "Chưa có kết quả kiểm tra";

/**
 * Trạng thái Backend và Agent đang chọn cho HNTH trên thanh tiêu đề. Dữ liệu do
 * core/realtime cập nhật từ snapshot monitor-state và SSE (một nguồn cho cả trang).
 */
export function SystemStatusBar() {
  const activePanel = useAppStore((state) => state.activePanel);
  const backendState = useHnthLiveStore((state) => state.backend);
  const backendCheckedAt = useHnthLiveStore((state) => state.backendCheckedAt);
  const agentState = useHnthLiveStore((state) => state.agent.state);
  const agentCheckedAt = useHnthLiveStore((state) => state.agent.checkedAt);
  const agentDisplayName = useHnthLiveStore((state) => state.agent.name);
  const [cameraAgent, setCameraAgent] = useState<{ state: "checking" | "online" | "offline"; checkedAt: number | null }>({ state: "checking", checkedAt: null });

  // Status bar cần snapshot ít nhất mỗi 10 giây kể cả khi HnthPanel chưa có điểm.
  useEffect(() => demoMode ? undefined : subscribeHnthSnapshots(10000, () => undefined), []);

  useEffect(() => {
    if (demoMode) return;
    if (activePanel !== "camera") return;
    let cancelled = false;
    const loadCameraAgent = async () => {
      try {
        const response = await agentsApi.list();
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const agents = await response.json() as Array<{ agentId?: string; name?: string; status?: string }>;
        const agent = agents.find((item) => /camera/i.test(`${item.name || ""} ${item.agentId || ""}`));
        if (!cancelled) setCameraAgent({ state: agent?.status === "online" ? "online" : "offline", checkedAt: Date.now() });
      } catch {
        if (!cancelled) setCameraAgent({ state: "offline", checkedAt: Date.now() });
      }
    };
    setCameraAgent({ state: "checking", checkedAt: null });
    void loadCameraAgent();
    const timer = window.setInterval(() => void loadCameraAgent(), 10000);
    return () => { cancelled = true; window.clearInterval(timer); };
  }, [activePanel]);

  const isCameraMenu = activePanel === "camera";
  const displayedAgentState = demoMode ? "online" : isCameraMenu ? cameraAgent.state : agentState;
  const displayedAgentCheckedAt = demoMode ? null : isCameraMenu ? cameraAgent.checkedAt : agentCheckedAt;
  const displayedAgentName = demoMode ? "Dữ liệu tĩnh" : isCameraMenu ? "Agent Camera" : agentDisplayName;
  const displayedBackendState = demoMode ? "online" : backendState;

  return <>
    <div className={`system-state ${displayedBackendState}`} title={demoMode ? "Chế độ demo tĩnh" : "Trạng thái kết nối Backend"}><span className="pulse"/><div><strong>{demoMode ? "Bản demo tĩnh" : displayedBackendState === "online" ? "Backend đang hoạt động" : displayedBackendState === "offline" ? "Backend mất kết nối" : "Đang kiểm tra Backend"}</strong><small>{demoMode ? "Map + HUD + dữ liệu mẫu" : checkedAtText(backendCheckedAt)}</small></div></div>
    <div className={`system-state agent-state ${displayedAgentState}`} title={`Trạng thái ${displayedAgentName}`}><span className="pulse"/><div><strong>{displayedAgentState === "online" ? `${displayedAgentName} đang hoạt động` : displayedAgentState === "offline" ? `${displayedAgentName} mất kết nối` : `Đang kiểm tra ${displayedAgentName}`}</strong><small>{checkedAtText(displayedAgentCheckedAt)}</small></div></div>
  </>;
}
