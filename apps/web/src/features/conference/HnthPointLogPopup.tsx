// Popup Log endpoint: lịch sử thay đổi trạng thái của một điểm (monitor_logs).
import { useEffect, useState } from "react";
import { FileText, X } from "lucide-react";
import { hnthApi } from "../../core/api/clients";
import { onAppEvent } from "../../core/events";
import type { HnthPointFeature } from "./hnth-types";
import type { MonitorLogApiEntry, MonitorLogEntry } from "./monitor-log";

type PointLog = { pointId: string; name: string };

/** Trạng thái popup + mở log (cả từ sự kiện hnth:open-point-log của popup trên bản đồ). */
export function useHnthPointLog(allPoints: HnthPointFeature[]) {
  const [pointLog, setPointLog] = useState<{ pointId: string; name: string } | null>(null);
  const [pointLogEntries, setPointLogEntries] = useState<MonitorLogEntry[]>([]);
  const [pointLogLoading, setPointLogLoading] = useState(false);

  const openPointLog = async (item: HnthPointFeature) => {
    const pointId = String(item.properties?.pointId ?? item.id);
    const name = String(item.properties?.name ?? "Endpoint");
    setPointLog({ pointId, name });
    setPointLogEntries([]);
    setPointLogLoading(true);
    try {
      const response = await hnthApi.monitorLog(pointId);
      if (!response.ok) return;
      const payload = await response.json() as { entries?: MonitorLogApiEntry[] };
      const entries = (payload.entries ?? []).map((entry) => {
        const parsed = String(entry.checkedAt ?? entry.receivedAt ?? "");
        const timestamp = Date.parse(parsed) || Date.now();
        const rawStatus = String(entry.status ?? "unknown");
        return {
          pointId,
          name,
          ip: String(entry.ipAddress ?? item.properties?.ipAddress ?? ""),
          status: rawStatus === "online" ? "Online" : rawStatus === "offline" ? "Offline" : "Chưa xác định",
          time: new Date(timestamp).toLocaleTimeString("vi-VN", { hour: "2-digit", minute: "2-digit", second: "2-digit" }),
          timestamp,
        };
      }).sort((left, right) => left.timestamp - right.timestamp);
      setPointLogEntries(entries);
    } finally {
      setPointLogLoading(false);
    }
  };

  useEffect(() => {
    return onAppEvent("hnth:open-point-log", (detail) => {
      const pointId = String(detail?.pointId ?? "");
      if (!pointId) return;
      const item = allPoints.find((candidate) => String(candidate.properties?.pointId ?? candidate.id) === pointId);
      if (item) void openPointLog(item);
    });
  }, [allPoints]);

  return { pointLog, pointLogEntries, pointLogLoading, openPointLog, closePointLog: () => setPointLog(null) };
}

export function HnthPointLogPopup({ pointLog, pointLogEntries, pointLogLoading, onClose }: { pointLog: PointLog | null; pointLogEntries: MonitorLogEntry[]; pointLogLoading: boolean; onClose: () => void }) {
  if (!pointLog) return null;
  return <section className="hnth-point-log-popup" role="dialog" aria-modal="true" aria-label={`Log ${pointLog.name}`}>
    <header><span><FileText size={16}/><strong>Log endpoint</strong></span><button type="button" onClick={onClose} aria-label="Đóng log endpoint"><X size={17}/></button></header>
    <div className="hnth-point-log-title"><strong>{pointLog.name}</strong><small>{pointLog.pointId}</small></div>
    <div className="hnth-point-log-list">
      {pointLogLoading && <small>Đang tải log...</small>}
      {!pointLogLoading && pointLogEntries.length === 0 && <small>Chưa có log thay đổi trạng thái.</small>}
      {pointLogEntries.map((item, index) => <div className={`hnth-monitor-log-row ${item.status.toLowerCase()}`} key={`${item.timestamp}-${index}`}><i/><span><strong>{item.status}</strong><small>{item.ip || "Chưa có IP"} · {item.time}</small></span></div>)}
    </div>
  </section>;
}
