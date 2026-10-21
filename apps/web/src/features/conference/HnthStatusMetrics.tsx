import { useEffect, useMemo, useRef, useState } from "react";
import { Cable, ChevronDown, ChevronUp, CircleAlert, CircleHelp, Clock3, FileText, GripHorizontal, RadioTower, X, Zap } from "lucide-react";
import type { Feature, Point } from "geojson";
import { toConnectionStatus } from "@haiphong-ops/hnth-protocol";
import { useAppStore } from "../../core/store";
import { hnthFetch } from "../../core/hnth-api";
import { HNTH_LAYER_ID, HNTH_STATUS_LABELS, normalizeHnthStatus, type HnthConnectionStatus } from "../layers/hnth-data-provider";
import { FIT_HAIPHONG_OVERVIEW_EVENT, MAP_ADMINISTRATIVE_PULSE_EVENT, MAP_CONTEXT_INFO_EVENT } from "../map/map-events";
import { HnthDisconnectConfirmButton } from "./HnthDisconnectConfirmButton";

type HnthPointFeature = Feature<Point, Record<string, unknown>>;
type MonitorLogEntry = { pointId: string; name: string; ip: string; status: string; time: string; timestamp: number };
type MonitorLogApiEntry = { pointId?: string; ipAddress?: string | null; status?: string; latencyMs?: number | null; checkedAt?: string; receivedAt?: string };

const cards: Array<{ status: HnthConnectionStatus; label: string; icon: typeof Cable }> = [
  { status: "unknown", label: "CHƯA XÁC ĐỊNH", icon: CircleHelp },
  { status: "connected", label: "ĐÃ KẾT NỐI", icon: Cable },
  { status: "unconnected", label: "CHƯA KẾT NỐI", icon: Clock3 },
  { status: "lost", label: "MẤT KẾT NỐI", icon: CircleAlert },
];

export function HnthStatusMetrics() {
  // Use the Vite same-origin /api proxy by default so mobile clients do not
  // resolve 127.0.0.1 to the phone itself.
  const apiBase = ((import.meta.env.VITE_HNTH_BACKEND_URL as string | undefined) || "").replace(/\/$/, "");
  const layer = useAppStore((state) => state.layers.find((item) => item.id === HNTH_LAYER_ID));
  const administrativeUnits = useAppStore((state) => state.administrativeUnits);
  const setSelectedHnthPointId = useAppStore((state) => state.setSelectedHnthPointId);
  const updateHnthPoint = useAppStore((state) => state.updateHnthPoint);
  const [detailStatus, setDetailStatus] = useState<HnthConnectionStatus | null>(null);
  // Hai công tắc dưới đây mới chỉ là cấu hình giao diện minh họa.
  // Chưa thực hiện ping hoặc tự động kết nối tới thiết bị thật.
  const [autoPingEnabled, setAutoPingEnabled] = useState(false);
  const [autoConnectEnabled, setAutoConnectEnabled] = useState(false);
  const [testPointId, setTestPointId] = useState<string | null>(null);
  const [testRunId, setTestRunId] = useState(0);
  const [testLines, setTestLines] = useState<string[]>([]);
  const [testSequencePosition, setTestSequencePosition] = useState<number | null>(null);
  const [testPopupPosition, setTestPopupPosition] = useState<{ left: number; top: number } | null>(null);
  const [continuousMonitoring, setContinuousMonitoring] = useState(false);
  const [monitorConcurrency, setMonitorConcurrency] = useState(2);
  const [monitorLog, setMonitorLog] = useState<MonitorLogEntry[]>([]);
  const [pointLog, setPointLog] = useState<{ pointId: string; name: string } | null>(null);
  const [pointLogEntries, setPointLogEntries] = useState<MonitorLogEntry[]>([]);
  const [pointLogLoading, setPointLogLoading] = useState(false);
  const [monitorAutoFocus, setMonitorAutoFocus] = useState(true);
  const [monitorLogCollapsed, setMonitorLogCollapsed] = useState(() => window.matchMedia("(max-width: 760px)").matches);
  const monitorLogListRef = useRef<HTMLDivElement | null>(null);
  const monitoringSessionRef = useRef(false);
  const hasAppliedDefaultDetailStatus = useRef(false);
  const testPopupRef = useRef<HTMLElement | null>(null);
  const testDragRef = useRef<{
    pointerId: number;
    startX: number;
    startY: number;
    left: number;
    top: number;
    maxLeft: number;
    maxTop: number;
  } | null>(null);
  const allPoints = useMemo(() => (layer?.data.features ?? []).filter((item): item is HnthPointFeature => (
    item.geometry.type === "Point"
  )), [layer]);
  // HNTH gồm 114 điểm địa giới và 1 điểm Trung tâm Chính trị - Hành chính.
  // Điểm trung tâm cũng là endpoint được giám sát nên phải được tính vào
  // các nhóm trạng thái và tổng số trên thanh trạng thái.
  const points = allPoints;
  const grouped = useMemo(() => Object.fromEntries(cards.map(({ status }) => [
    status,
    points
      .filter((item) => normalizeHnthStatus(item.properties?.status) === status)
      .sort((left, right) => String(left.properties?.name ?? "").localeCompare(
        String(right.properties?.name ?? ""),
        "vi",
        { sensitivity: "base", numeric: true },
      )),
  ])) as Record<HnthConnectionStatus, HnthPointFeature[]>, [points]);
  const selected = detailStatus ? grouped[detailStatus] : [];
  const testPoint = testPointId
    ? allPoints.find((item) => String(item.properties?.pointId ?? item.id) === testPointId)
    : undefined;
  const testOutcome = useMemo<"success" | "failed" | null>(() => {
    const summaryLine = testLines.find((line) => line.startsWith("Packets:"));
    if (!summaryLine) return null;
    return summaryLine.includes("Lost = 0") ? "success" : "failed";
  }, [testLines]);

  useEffect(() => {
    // Mỗi lần mở menu HNTH (kể cả sau khi reload), ưu tiên mở danh sách
    // Mất kết nối sau khi dữ liệu điểm nhánh đã nạp xong. Cờ này bảo đảm
    // người dùng vẫn có thể đóng popup mà nó không tự bật lại trong cùng phiên mở menu.
    if (hasAppliedDefaultDetailStatus.current || points.length === 0) return;
    hasAppliedDefaultDetailStatus.current = true;
    // Mobile vẫn giữ thanh 4 trạng thái, nhưng không tự mở bảng chi tiết
    // Mất kết nối vì popup che phần lớn vùng bản đồ.
    if (grouped.lost.length > 0 && !window.matchMedia("(max-width: 760px)").matches) setDetailStatus("lost");
  }, [grouped.lost.length, points.length]);

  useEffect(() => {
    const openManualTest = (event: Event) => {
      const detail = (event as CustomEvent<{ pointId?: string; ipAddress?: string; runId?: number }>).detail;
      const pointId = detail?.pointId;
      if (!pointId) return;
      setAutoPingEnabled(false);
      setTestSequencePosition(null);
      setTestPointId(pointId);
      setTestRunId(detail?.runId ?? Date.now());
      if (detail?.ipAddress) void hnthFetch(`${apiBase}/api/hnth/test`, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ pointId, ipAddress: detail.ipAddress }) });
      window.setTimeout(async () => {
        try {
          const response = await hnthFetch(`${apiBase}/api/hnth/status`);
          if (!response.ok) return;
          const payload = await response.json() as { results?: Array<{ pointId?: string; ipAddress?: string | null; status?: string; latencyMs?: number | null }> };
          const result = payload.results?.find((item) => item.pointId === pointId);
          const hasIp = Boolean(String(allPoints.find((item) => String(item.properties?.pointId ?? item.id) === pointId)?.properties?.ipAddress ?? "").trim());
          if (result?.status) updateHnthPoint(pointId, { status: toConnectionStatus(result.status, hasIp) });
        } catch { /* agent/relay may be offline; popup still shows the local state */ }
      }, 1800);
    };
    window.addEventListener("hnth:test-point", openManualTest);
    return () => window.removeEventListener("hnth:test-point", openManualTest);
  }, []);

  useEffect(() => {
    const onMonitoring = (event: Event) => {
      const detail = (event as CustomEvent<{ enabled?: boolean; concurrency?: number }>).detail;
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
    window.addEventListener("hnth:continuous-monitoring", onMonitoring);
    return () => window.removeEventListener("hnth:continuous-monitoring", onMonitoring);
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
    const onMonitoringBatch = (event: Event) => {
      const batch = (event as CustomEvent<{ sentAt?: string; results?: MonitorLogApiEntry[]; allResults?: MonitorLogApiEntry[] }>).detail;
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
    };
    window.addEventListener("hnth:monitor-batch", onMonitoringBatch);
    return () => window.removeEventListener("hnth:monitor-batch", onMonitoringBatch);
  }, [allPoints, continuousMonitoring, monitorConcurrency, updateHnthPoint]);

  useEffect(() => {
    if (!monitorAutoFocus) return;
    const list = monitorLogListRef.current;
    if (!list) return;
    list.scrollTop = list.scrollHeight;
  }, [monitorAutoFocus, monitorLog]);

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

  const focusPoint = (item: HnthPointFeature) => {
    const pointId = String(item.properties?.pointId ?? item.id);
    const wardCode = String(item.properties?.wardCode ?? "");
    const administrativeId = administrativeUnits.find((unit) => String(unit.wardCode ?? "") === wardCode)?.id;
    setSelectedHnthPointId(pointId);
    window.dispatchEvent(new CustomEvent("hnth:focus", {
      detail: { coordinates: item.geometry.coordinates as [number, number], preserveZoom: true, administrativeId, boundaryWidthMultiplier: 2 },
    }));
    window.dispatchEvent(new CustomEvent(MAP_CONTEXT_INFO_EVENT, {
      detail: { kind: "hnth", pointId, administrativeId, pulseBoundary: true },
    }));
  };

  const openPointLog = async (item: HnthPointFeature) => {
    const pointId = String(item.properties?.pointId ?? item.id);
    const name = String(item.properties?.name ?? "Endpoint");
    setPointLog({ pointId, name });
    setPointLogEntries([]);
    setPointLogLoading(true);
    try {
      const response = await hnthFetch(`${apiBase}/api/hnth/monitor-log?pointId=${encodeURIComponent(pointId)}`);
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
    const handleOpenPointLog = (event: Event) => {
      const pointId = String((event as CustomEvent<{ pointId?: string }>).detail?.pointId ?? "");
      if (!pointId) return;
      const item = allPoints.find((candidate) => String(candidate.properties?.pointId ?? candidate.id) === pointId);
      if (item) void openPointLog(item);
    };
    window.addEventListener("hnth:open-point-log", handleOpenPointLog);
    return () => window.removeEventListener("hnth:open-point-log", handleOpenPointLog);
  }, [allPoints]);

  useEffect(() => {
    if (!autoPingEnabled) return;
    const lostPoints = grouped.lost;
    if (!lostPoints.length) {
      setAutoPingEnabled(false);
      setTestPointId(null);
      setTestSequencePosition(null);
      return;
    }
    let index = 0;
    let timeoutId: number | null = null;
    const testNextPoint = () => {
      const item = lostPoints[index % lostPoints.length];
      const wardCode = String(item.properties?.wardCode ?? "");
      const administrativeId = administrativeUnits.find((unit) => String(unit.wardCode ?? "") === wardCode)?.id;
      setTestPointId(String(item.properties?.pointId ?? item.id));
      setTestSequencePosition((index % lostPoints.length) + 1);
      if (administrativeId !== undefined) {
        window.dispatchEvent(new CustomEvent(MAP_ADMINISTRATIVE_PULSE_EVENT, {
          // Mỗi lượt Tự động Ping nhận diện địa giới bằng đúng ba chu kỳ viền.
          detail: { administrativeId, cycles: 3 },
        }));
      }
      index += 1;
      // Dữ liệu HNTH hiện là mô phỏng: mỗi lượt chờ đủ thời gian chạy hết bốn gói ping.
      timeoutId = window.setTimeout(testNextPoint, 3000);
    };
    testNextPoint();
    return () => {
      if (timeoutId !== null) window.clearTimeout(timeoutId);
    };
  }, [administrativeUnits, autoPingEnabled, grouped.lost]);

  useEffect(() => {
    if (!testPoint) return;
    const ip = String(testPoint.properties?.ipAddress ?? "Chưa cấu hình");
    const connected = normalizeHnthStatus(testPoint.properties?.status) === "connected";
    const output = connected
      ? [
          `Pinging ${ip} with 32 bytes of data:`,
          `Reply from ${ip}: bytes=32 time=12ms TTL=63`,
          `Reply from ${ip}: bytes=32 time=15ms TTL=63`,
          `Reply from ${ip}: bytes=32 time=11ms TTL=63`,
          `Reply from ${ip}: bytes=32 time=13ms TTL=63`,
          "Packets: Sent = 4, Received = 4, Lost = 0 (0% loss)",
          "Minimum = 11ms, Maximum = 15ms, Average = 12ms",
        ]
      : [
          `Pinging ${ip} with 32 bytes of data:`,
          "Request timed out.", "Request timed out.", "Request timed out.", "Request timed out.",
          "Packets: Sent = 4, Received = 0, Lost = 4 (100% loss)",
        ];
    setTestLines([]);
    let index = 0;
    const timer = window.setInterval(() => {
      setTestLines(output.slice(0, index + 1));
      index += 1;
      if (index >= output.length) window.clearInterval(timer);
    }, 330);
    return () => window.clearInterval(timer);
  }, [testPointId, testPoint?.properties?.status, testRunId]);

  useEffect(() => {
    if (!detailStatus) return;
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") setDetailStatus(null);
    };
    window.addEventListener("keydown", closeOnEscape);
    return () => window.removeEventListener("keydown", closeOnEscape);
  }, [detailStatus]);

  return <>
    <div className="metric-strip hnth-metric-strip" aria-label="Tổng hợp trạng thái Hội nghị truyền hình">
      {cards.map(({ status, label, icon: Icon }) => <button
        key={status}
        className={`${status}${detailStatus === status ? " active" : ""}`}
        aria-pressed={detailStatus === status}
        onClick={() => setDetailStatus((current) => current === status ? null : status)}
      >
        <span className={`metric-icon ${status}`}><Icon size={17}/></span>
        <p><small>{label}</small><strong>{grouped[status].length}<em> / {points.length} điểm</em></strong></p>
      </button>)}
    </div>

    {/* Popup Chi tiết trạng thái HNTH: bảng cố định bên phải, ngay dưới Thanh trạng thái HNTH. */}
    {detailStatus && <section
      className="hnth-status-detail-popup"
      role="region"
      aria-label={`Popup Chi tiết trạng thái HNTH: ${HNTH_STATUS_LABELS[detailStatus]}`}
    >
        <header><span><RadioTower size={17}/><strong>Chi tiết: {HNTH_STATUS_LABELS[detailStatus]}</strong></span><button onClick={() => setDetailStatus(null)} aria-label="Đóng Popup Chi tiết trạng thái HNTH"><X size={18}/></button></header>
        <div className="hnth-alert-summary">
          <div className="hnth-alert-summary-count"><i className={detailStatus}/><strong>{selected.length} điểm</strong></div>
          {detailStatus === "lost" && <label className="hnth-summary-toggle">
            <span>Tự động Ping</span>
            <input type="checkbox" checked={autoPingEnabled} onChange={(event) => {
              const enabled = event.target.checked;
              setAutoPingEnabled(enabled);
              if (!enabled) setTestSequencePosition(null);
            }}/>
            <span className="hnth-summary-switch-track" aria-hidden="true"/>
          </label>}
          {detailStatus === "unconnected" && <label className="hnth-summary-toggle">
            <span>Tự động Kết nối</span>
            <input type="checkbox" checked={autoConnectEnabled} onChange={(event) => setAutoConnectEnabled(event.target.checked)}/>
            <span className="hnth-summary-switch-track" aria-hidden="true"/>
          </label>}
        </div>
        <div className="hnth-alert-list">
          {selected.length === 0 && <p>Không có điểm nào trong trạng thái này.</p>}
          {selected.map((item) => {
            const pointId = String(item.properties?.pointId ?? item.id);
            const pointName = String(item.properties?.name ?? "Điểm HNTH");
            return <div className="hnth-alert-row" key={pointId}>
              <button className="hnth-alert-focus" type="button" onClick={() => {
                setSelectedHnthPointId(pointId);
                const wardCode = String(item.properties?.wardCode ?? "");
                const administrativeId = administrativeUnits.find((unit) => String(unit.wardCode ?? "") === wardCode)?.id;
                const isBachLongVi = pointName.toLocaleLowerCase("vi").includes("bạch long vĩ");
                if (isBachLongVi) {
                  // Bạch Long Vĩ nằm xa đất liền: chỉ đưa tâm bản đồ tới Endpoint,
                  // giữ nguyên mức zoom hiện tại để không thay đổi tỷ lệ người dùng.
                  window.dispatchEvent(new CustomEvent("hnth:focus", {
                    detail: { coordinates: item.geometry.coordinates as [number, number], preserveZoom: true },
                  }));
                } else {
                  // Các điểm còn lại luôn đưa camera về khung toàn cảnh Hải Phòng.
                  window.dispatchEvent(new Event(FIT_HAIPHONG_OVERVIEW_EVENT));
                }
                window.dispatchEvent(new CustomEvent(MAP_CONTEXT_INFO_EVENT, {
                  // Nháy độ dày viền 1x → 2x → 3x → 1x, tối đa năm chu kỳ.
                  detail: { kind: "hnth", pointId, administrativeId, pulseBoundary: true },
                }));
              }}>
                <i className={detailStatus}/><span><strong>{pointName}</strong><small>IP {String(item.properties?.ipAddress ?? "Chưa cấu hình")} · Gateway {String(item.properties?.gateway ?? "Chưa cấu hình")}</small></span>
              </button>
              <div className="hnth-alert-actions">
                <button className="hnth-alert-action log" type="button" onClick={() => void openPointLog(item)}><FileText size={12}/> Log</button>
                {detailStatus === "connected"
                  ? <HnthDisconnectConfirmButton pointName={pointName} className="hnth-alert-action disconnect" onConfirm={() => updateHnthPoint(pointId, { status: "unconnected" })}/>
                  : detailStatus === "lost"
                    ? <button
                        className="hnth-alert-action test"
                        type="button"
                        onClick={() => {
                          const wardCode = String(item.properties?.wardCode ?? "");
                          const administrativeId = administrativeUnits.find((unit) => String(unit.wardCode ?? "") === wardCode)?.id;
                          window.dispatchEvent(new CustomEvent("hnth:test-point", { detail: { pointId, ipAddress: String(item.properties?.ipAddress ?? ""), runId: Date.now() } }));
                          if (administrativeId !== undefined) window.dispatchEvent(new CustomEvent(MAP_ADMINISTRATIVE_PULSE_EVENT, { detail: { administrativeId, cycles: 3 } }));
                        }}
                      ><Zap size={12}/> Test/Ping</button>
                    : <button className="hnth-alert-action connect" type="button" onClick={() => updateHnthPoint(pointId, { status: "connected" })}><Cable size={12}/> Kết nối</button>}
              </div>
            </div>;
          })}
        </div>
      </section>
    }

    {/* Popup Log nằm phía dưới; có thể thu nhỏ/mở rộng và kéo mép dưới để đổi chiều cao. */}
    {continuousMonitoring && <section className={`hnth-monitor-log-popup${monitorLogCollapsed ? " is-collapsed" : ""}`} role="region" aria-label="Log giám sát liên tục">
      <header><span><RadioTower size={16}/><strong>Log giám sát liên tục</strong><em>{monitorConcurrency} luồng</em></span><span className="hnth-monitor-log-actions"><label><input data-hnth-monitor-autofocus="true" type="checkbox" checked={monitorAutoFocus} onChange={(event) => setMonitorAutoFocus(event.target.checked)}/> AutoFocus</label><button type="button" className="hnth-monitor-log-toggle" onClick={() => setMonitorLogCollapsed((value) => !value)} title={monitorLogCollapsed ? "Mở rộng log" : "Thu nhỏ log"} aria-label={monitorLogCollapsed ? "Mở rộng log" : "Thu nhỏ log"}>{monitorLogCollapsed ? <ChevronUp size={13}/> : <ChevronDown size={13}/>}</button><button type="button" onClick={exportMonitorLog}>Export</button></span></header>
      {!monitorLogCollapsed && <div data-hnth-monitor-log-list="true" ref={monitorLogListRef} className="hnth-monitor-log-list">
        {monitorLog.length === 0 && <small>Đang chờ kết quả từ agent...</small>}
        {monitorLog.map((item, index) => {
          const point = allPoints.find((candidate) => String(candidate.properties?.pointId ?? candidate.id) === item.pointId);
          return <button className={`hnth-monitor-log-row ${item.status.toLowerCase()}`} key={`${item.pointId}-${item.timestamp}-${index}`} type="button" onClick={() => { if (point) focusPoint(point); }}><i/><span><strong>{item.name}</strong><small>{item.ip} · {item.status} {item.time}</small></span></button>;
        })}
      </div>}
    </section>}
    {pointLog && <section className="hnth-point-log-popup" role="dialog" aria-modal="true" aria-label={`Log ${pointLog.name}`}>
      <header><span><FileText size={16}/><strong>Log endpoint</strong></span><button type="button" onClick={() => setPointLog(null)} aria-label="Đóng log endpoint"><X size={17}/></button></header>
      <div className="hnth-point-log-title"><strong>{pointLog.name}</strong><small>{pointLog.pointId}</small></div>
      <div className="hnth-point-log-list">
        {pointLogLoading && <small>Đang tải log...</small>}
        {!pointLogLoading && pointLogEntries.length === 0 && <small>Chưa có log thay đổi trạng thái.</small>}
        {pointLogEntries.map((item, index) => <div className={`hnth-monitor-log-row ${item.status.toLowerCase()}`} key={`${item.timestamp}-${index}`}><i/><span><strong>{item.status}</strong><small>{item.ip || "Chưa có IP"} · {item.time}</small></span></div>)}
      </div>
    </section>}
    {/* Popup Chi tiết Test: nằm phía trên popup Log, mặc định ở góc trái và có thể kéo bằng thanh thông tin điểm. */}
    {testPoint && <section
      ref={testPopupRef}
      className="hnth-test-detail-popup"
      role="region"
      aria-label="Popup Chi tiết Test"
      style={testPopupPosition ? { left: testPopupPosition.left, top: testPopupPosition.top, right: "auto", bottom: "auto" } : undefined}
    >
      <div
        className={`hnth-test-site hnth-test-drag-bar${testOutcome ? ` ${testOutcome}` : ""}`}
        onPointerDown={(event) => {
          if (event.button !== 0) return;
          const popup = testPopupRef.current;
          const parent = popup?.offsetParent as HTMLElement | null;
          if (!popup || !parent) return;
          const popupRect = popup.getBoundingClientRect();
          const parentRect = parent.getBoundingClientRect();
          testDragRef.current = {
            pointerId: event.pointerId,
            startX: event.clientX,
            startY: event.clientY,
            left: popupRect.left - parentRect.left,
            top: popupRect.top - parentRect.top,
            maxLeft: Math.max(6, parent.clientWidth - popupRect.width - 6),
            maxTop: Math.max(6, parent.clientHeight - popupRect.height - 6),
          };
          event.currentTarget.setPointerCapture(event.pointerId);
        }}
        onPointerMove={(event) => {
          const drag = testDragRef.current;
          if (!drag || drag.pointerId !== event.pointerId) return;
          setTestPopupPosition({
            left: Math.min(drag.maxLeft, Math.max(6, drag.left + event.clientX - drag.startX)),
            top: Math.min(drag.maxTop, Math.max(6, drag.top + event.clientY - drag.startY)),
          });
        }}
        onPointerUp={(event) => {
          if (testDragRef.current?.pointerId !== event.pointerId) return;
          testDragRef.current = null;
          event.currentTarget.releasePointerCapture(event.pointerId);
        }}
        onPointerCancel={() => { testDragRef.current = null; }}
      >
        <span className="hnth-test-drag-icon" aria-hidden="true"><GripHorizontal size={15}/><Zap size={13}/></span>
        <div>
          <strong>{String(testPoint.properties?.name ?? "Điểm HNTH")}</strong>
          <small>{String(testPoint.properties?.ipAddress ?? "Chưa cấu hình IP")} · Gateway {String(testPoint.properties?.gateway ?? "Chưa cấu hình")}</small>
        </div>
        {autoPingEnabled && testSequencePosition !== null && <em>{testSequencePosition}/{grouped.lost.length}</em>}
        <button onClick={(event) => {
          event.stopPropagation();
          setAutoPingEnabled(false);
          setTestPointId(null);
          setTestSequencePosition(null);
          setTestPopupPosition(null);
        }} onPointerDown={(event) => event.stopPropagation()} aria-label="Đóng Popup Chi tiết Test"><X size={16}/></button>
      </div>
      <div className="hnth-terminal compact">
        <div className={`hnth-terminal-status${testOutcome ? ` ${testOutcome}` : ""}`}><i/><i/><i/></div>
        <pre>{testLines.join("\n")}<b>▌</b></pre>
      </div>
    </section>}
  </>;
}
