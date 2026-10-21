// Popup Log giám sát liên tục (góc dưới): ghi từng batch Agent gửi về, thu nhỏ/mở
// rộng được, Export ra .txt. Bắt đầu phiên giám sát mới thì xóa log và đưa mọi
// điểm về "Chưa xác định".
import { useEffect, useRef, useState } from "react";
import { ChevronDown, ChevronUp, RadioTower } from "lucide-react";
import { useAppStore } from "../../core/store";
import { subscribeMonitorBatches } from "../../core/realtime/hnth-realtime";
import { useHnthLiveStore, type MonitoringInfo } from "../../core/realtime/hnth-live-store";
import type { HnthPointFeature } from "./hnth-types";
import type { MonitorLogApiEntry, MonitorLogEntry } from "./monitor-log";

// Trạng thái thu nhỏ của popup log lưu riêng (không qua store persist) vì chỉ là tiện ích hiển thị.
// Chưa lưu lần nào thì mặc định thu nhỏ trên màn hình hẹp.
const MONITOR_LOG_COLLAPSED_KEY = "hnth-monitor-log-collapsed";
function readMonitorLogCollapsed() {
  try {
    const saved = window.localStorage.getItem(MONITOR_LOG_COLLAPSED_KEY);
    if (saved !== null) return saved === "1";
  } catch { /* localStorage bị chặn: dùng mặc định */ }
  return window.matchMedia("(max-width: 760px)").matches;
}

export function HnthMonitorLogPopup({ allPoints, onFocusPoint }: { allPoints: HnthPointFeature[]; onFocusPoint: (point: HnthPointFeature) => void }) {
  const updateHnthPoint = useAppStore((state) => state.updateHnthPoint);
  const [continuousMonitoring, setContinuousMonitoring] = useState(false);
  const [monitorConcurrency, setMonitorConcurrency] = useState(2);
  const [monitorLog, setMonitorLog] = useState<MonitorLogEntry[]>([]);
  const [monitorAutoFocus, setMonitorAutoFocus] = useState(true);
  const [monitorLogCollapsed, setMonitorLogCollapsed] = useState(readMonitorLogCollapsed);
  useEffect(() => {
    try { window.localStorage.setItem(MONITOR_LOG_COLLAPSED_KEY, monitorLogCollapsed ? "1" : "0"); } catch { /* bỏ qua */ }
  }, [monitorLogCollapsed]);
  // Phím 8: lần lẻ chuyển log sang dạng trong suốt hiển thị thẳng trên bản đồ
  // (không tiêu đề, mờ dần trên/dưới, cao gấp đôi); lần chẵn về dạng popup.
  // Cờ dùng chung với popup Chi tiết và switch ở cuối menu HNTH.
  const monitorLogOverlay = useAppStore((state) => state.hnthTransparentPopups);
  // Ctrl+`: đưa log trong suốt sang mép phải bản đồ và ngược lại (chỉ áp dụng ở chế độ trong suốt).
  const [overlayOnRight, setOverlayOnRight] = useState(false);
  // Ctrl+↑ / Ctrl+↓: chữ log trong suốt to gấp 1,5 lần / về cỡ thường.
  const [overlayLargeText, setOverlayLargeText] = useState(false);
  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (!event.ctrlKey) return;
      if (event.key === "ArrowUp" || event.key === "ArrowDown") {
        event.preventDefault();
        setOverlayLargeText(event.key === "ArrowUp");
        return;
      }
      if (event.code !== "Backquote") return;
      event.preventDefault();
      setOverlayOnRight((value) => !value);
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, []);
  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement | null;
      if (event.key !== "8" || target?.isContentEditable || target?.tagName === "INPUT" || target?.tagName === "TEXTAREA" || target?.tagName === "SELECT") return;
      event.preventDefault();
      const state = useAppStore.getState();
      state.setHnthTransparentPopups(!state.hnthTransparentPopups);
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, []);
  const monitorLogListRef = useRef<HTMLDivElement | null>(null);
  const monitoringSessionRef = useRef(false);

  useEffect(() => {
    const onMonitoring = (detail: MonitoringInfo) => {
      const enabled = Boolean(detail?.enabled);
      setContinuousMonitoring(enabled);
      if (detail?.concurrency) setMonitorConcurrency(detail.concurrency);
      // Khi bắt đầu một phiên mới, không được nạp lại log/trạng thái của
      // phiên trước. Phiên tắt chỉ giữ nguyên kết quả gần nhất trên bản đồ.
      const startedNewSession = enabled && !monitoringSessionRef.current;
      monitoringSessionRef.current = enabled;
      if (startedNewSession) {
        setMonitorLog([]);
        allPoints.forEach((point) => {
          const pointId = String(point.properties?.pointId ?? point.id ?? "");
          if (pointId) updateHnthPoint(pointId, { status: "unknown" });
        });
      }
    };
    // Nghe đồng bộ (không qua render) để reset log của phiên mới chạy trước khi
    // batch đầu tiên của phiên đó được ghi vào log.
    return useHnthLiveStore.subscribe((state, previous) => {
      if (state.monitoring !== previous.monitoring) onMonitoring(state.monitoring);
    });
  }, [allPoints, updateHnthPoint]);

  useEffect(() => {
    if (!continuousMonitoring) return;
    const toEntry = (item: MonitorLogApiEntry): MonitorLogEntry => {
      const pointId = String(item.pointId ?? "");
      const point = allPoints.find((candidate) => String(candidate.properties?.pointId ?? candidate.id) === pointId)
        ?? allPoints.find((candidate) => String(candidate.properties?.ipAddress ?? "").trim() === String(item.ipAddress ?? "").trim());
      const timestamp = Date.parse(String(item.checkedAt ?? item.receivedAt ?? "")) || Date.now();
      const rawStatus = String(point?.properties?.ipAddress ?? "").trim() ? String(item.status ?? "unknown") : "unknown";
      return {
        pointId: String(point?.properties?.pointId ?? point?.id ?? pointId),
        name: String(point?.properties?.name ?? item.pointId ?? "Endpoint"),
        ip: String(item.ipAddress ?? point?.properties?.ipAddress ?? ""),
        status: rawStatus === "online" ? "Online" : rawStatus === "offline" ? "Offline" : "Chưa xác định",
        time: new Date(timestamp).toLocaleTimeString("vi-VN", { hour: "2-digit", minute: "2-digit", second: "2-digit" }),
        timestamp,
      };
    };
    return subscribeMonitorBatches((monitorBatch) => {
      const batch = monitorBatch as { sentAt?: string; results?: MonitorLogApiEntry[]; allResults?: MonitorLogApiEntry[] };
      // allResults là toàn bộ endpoint của batch hiện tại. results chỉ là
      // payload thay đổi trạng thái để cập nhật trạng thái nhẹ hơn, không
      // được dùng làm log vì sẽ làm mất các dòng endpoint không đổi.
      const items = Array.isArray(batch?.allResults)
        ? batch.allResults
        : Array.isArray(batch?.results) ? batch.results : [];
      if (!items.length) return;
      // HnthPanel là nơi duy nhất cập nhật trạng thái trong store. Component
      // này chỉ ghi log, tránh hai SSE cùng ghi một điểm và làm MapLibre nháy.
      const entries = items.map((item) => toEntry({ ...item, checkedAt: item.checkedAt ?? batch.sentAt }));
      setMonitorLog((current) => [...current, ...entries].slice(-1000));
    });
  }, [allPoints, continuousMonitoring, monitorConcurrency, updateHnthPoint]);

  useEffect(() => {
    if (!monitorAutoFocus) return;
    const list = monitorLogListRef.current;
    if (!list) return;
    list.scrollTop = list.scrollHeight;
  }, [monitorAutoFocus, monitorLog, monitorLogOverlay]);

  const exportMonitorLog = () => {
    const text = monitorLog.map((item) => `${item.time}\t${item.name}\t${item.ip}\t${item.status}`).join("\n");
    const blob = new Blob([`Thời gian\tEndpoint\tIP\tTrạng thái\n${text}`], { type: "text/plain;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = `hnth-monitor-log-${new Date().toISOString().slice(0, 10)}.txt`;
    anchor.click();
    URL.revokeObjectURL(url);
  };

  if (!continuousMonitoring) return null;
  const showList = monitorLogOverlay || !monitorLogCollapsed;
  return <section className={`hnth-monitor-log-popup${monitorLogOverlay ? ` is-overlay${overlayOnRight ? " is-right" : ""}${overlayLargeText ? " is-large" : ""}` : monitorLogCollapsed ? " is-collapsed" : ""}`} role="region" aria-label="Log giám sát liên tục">
    {!monitorLogOverlay && <header><span><RadioTower size={16}/><strong>Log giám sát liên tục</strong><em>{monitorConcurrency} luồng</em></span><span className="hnth-monitor-log-actions"><label><input data-hnth-monitor-autofocus="true" type="checkbox" checked={monitorAutoFocus} onChange={(event) => setMonitorAutoFocus(event.target.checked)}/> AutoFocus</label><button type="button" className="hnth-monitor-log-toggle" onClick={() => setMonitorLogCollapsed((value) => !value)} title={monitorLogCollapsed ? "Mở rộng log" : "Thu nhỏ log"} aria-label={monitorLogCollapsed ? "Mở rộng log" : "Thu nhỏ log"}>{monitorLogCollapsed ? <ChevronUp size={13}/> : <ChevronDown size={13}/>}</button><button type="button" onClick={exportMonitorLog}>Export</button></span></header>}
    {showList && <div data-hnth-monitor-log-list="true" ref={monitorLogListRef} className="hnth-monitor-log-list">
      {monitorLog.length === 0 && <small>Đang chờ kết quả từ agent...</small>}
      {monitorLog.map((item, index) => {
        const point = allPoints.find((candidate) => String(candidate.properties?.pointId ?? candidate.id) === item.pointId);
        return <button className={`hnth-monitor-log-row ${item.status.toLowerCase()}`} key={`${item.pointId}-${item.timestamp}-${index}`} type="button" onClick={() => { if (point) onFocusPoint(point); }}><i/><span><strong>{item.name}</strong><small>{item.ip} · {item.status} {item.time}</small></span></button>;
      })}
    </div>}
  </section>;
}
