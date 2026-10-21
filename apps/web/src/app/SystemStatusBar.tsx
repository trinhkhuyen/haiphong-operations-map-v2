import { useEffect } from "react";
import { subscribeHnthSnapshots } from "../core/realtime/hnth-realtime";
import { useHnthLiveStore } from "../core/realtime/hnth-live-store";

const checkedAtText = (checkedAt: number | null) => checkedAt
  ? `Kiểm tra ${new Date(checkedAt).toLocaleTimeString("vi-VN", { hour: "2-digit", minute: "2-digit" })}`
  : "Chưa có kết quả kiểm tra";

/**
 * Trạng thái Backend và Agent đang chọn cho HNTH trên thanh tiêu đề. Dữ liệu do
 * core/realtime cập nhật từ snapshot monitor-state và SSE (một nguồn cho cả trang).
 */
export function SystemStatusBar() {
  const backendState = useHnthLiveStore((state) => state.backend);
  const backendCheckedAt = useHnthLiveStore((state) => state.backendCheckedAt);
  const agentState = useHnthLiveStore((state) => state.agent.state);
  const agentCheckedAt = useHnthLiveStore((state) => state.agent.checkedAt);
  const agentDisplayName = useHnthLiveStore((state) => state.agent.name);

  // Status bar cần snapshot ít nhất mỗi 10 giây kể cả khi HnthPanel chưa có điểm.
  useEffect(() => subscribeHnthSnapshots(10000, () => undefined), []);

  return <>
    <div className={`system-state ${backendState}`} title="Trạng thái kết nối Backend"><span className="pulse"/><div><strong>{backendState === "online" ? "Backend đang hoạt động" : backendState === "offline" ? "Backend mất kết nối" : "Đang kiểm tra Backend"}</strong><small>{checkedAtText(backendCheckedAt)}</small></div></div>
    <div className={`system-state agent-state ${agentState}`} title={`Trạng thái ${agentDisplayName}`}><span className="pulse"/><div><strong>{agentState === "online" ? `${agentDisplayName} đang hoạt động` : agentState === "offline" ? `${agentDisplayName} mất kết nối` : `Đang kiểm tra ${agentDisplayName}`}</strong><small>{checkedAtText(agentCheckedAt)}</small></div></div>
  </>;
}
