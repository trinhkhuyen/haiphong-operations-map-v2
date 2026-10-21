import { useEffect, useMemo, useRef, useState } from "react";
import { Cable, CircleAlert, CircleHelp, Clock3, FileText, GripHorizontal, RadioTower, X, Zap } from "lucide-react";
import { toConnectionStatus } from "@haiphong-ops/hnth-protocol";
import { useAppStore } from "../../core/store";
import { hnthApi } from "../../core/api/clients";
import { emitAppEvent, onAppEvent } from "../../core/events";
import { HNTH_LAYER_ID, HNTH_STATUS_LABELS, normalizeHnthStatus, type HnthConnectionStatus } from "../layers/hnth-data-provider";
import { HnthDisconnectConfirmButton } from "./HnthDisconnectConfirmButton";
import { HnthMonitorLogPopup } from "./HnthMonitorLogPopup";
import { HnthPointLogPopup, useHnthPointLog } from "./HnthPointLogPopup";
import { focusHnthPoint } from "./hnth-focus";
import type { HnthPointFeature } from "./hnth-types";

const cards: Array<{ status: HnthConnectionStatus; label: string; icon: typeof Cable }> = [
  { status: "unknown", label: "CHƯA XÁC ĐỊNH", icon: CircleHelp },
  { status: "connected", label: "ĐÃ KẾT NỐI", icon: Cable },
  { status: "unconnected", label: "CHƯA KẾT NỐI", icon: Clock3 },
  { status: "lost", label: "MẤT KẾT NỐI", icon: CircleAlert },
];

export function HnthStatusMetrics() {
  const transparentPopups = useAppStore((state) => state.hnthTransparentPopups);
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
  const { pointLog, pointLogEntries, pointLogLoading, openPointLog, closePointLog } = useHnthPointLog(allPoints);
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
    return onAppEvent("hnth:test-point", (detail) => {
      const pointId = detail?.pointId;
      if (!pointId) return;
      setAutoPingEnabled(false);
      setTestSequencePosition(null);
      setTestPointId(pointId);
      setTestRunId(detail?.runId ?? Date.now());
      if (detail?.ipAddress) void hnthApi.testPoint({ pointId, ipAddress: detail.ipAddress });
      window.setTimeout(async () => {
        try {
          const response = await hnthApi.status();
          if (!response.ok) return;
          const payload = await response.json() as { results?: Array<{ pointId?: string; ipAddress?: string | null; status?: string; latencyMs?: number | null }> };
          const result = payload.results?.find((item) => item.pointId === pointId);
          const hasIp = Boolean(String(allPoints.find((item) => String(item.properties?.pointId ?? item.id) === pointId)?.properties?.ipAddress ?? "").trim());
          if (result?.status) updateHnthPoint(pointId, { status: toConnectionStatus(result.status, hasIp) });
        } catch { /* agent/relay may be offline; popup still shows the local state */ }
      }, 1800);
    });
  }, []);

  const focusPoint = focusHnthPoint;

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
        // Mỗi lượt Tự động Ping nhận diện địa giới bằng đúng ba chu kỳ viền.
        emitAppEvent("map:administrative-pulse", { administrativeId, cycles: 3 });
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
      className={`hnth-status-detail-popup${transparentPopups ? " is-overlay" : ""}`}
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
                  emitAppEvent("hnth:focus", { coordinates: item.geometry.coordinates as [number, number], preserveZoom: true });
                } else {
                  // Các điểm còn lại luôn đưa camera về khung toàn cảnh Hải Phòng.
                  emitAppEvent("map:fit-haiphong-overview");
                }
                // Nháy độ dày viền 1x → 2x → 3x → 1x, tối đa năm chu kỳ.
                emitAppEvent("map:context-info", { kind: "hnth", pointId, administrativeId, pulseBoundary: true });
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
                          emitAppEvent("hnth:test-point", { pointId, ipAddress: String(item.properties?.ipAddress ?? ""), runId: Date.now() });
                          if (administrativeId !== undefined) emitAppEvent("map:administrative-pulse", { administrativeId, cycles: 3 });
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
    <HnthMonitorLogPopup allPoints={allPoints} onFocusPoint={focusPoint} />
    <HnthPointLogPopup pointLog={pointLog} pointLogEntries={pointLogEntries} pointLogLoading={pointLogLoading} onClose={closePointLog} />
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
