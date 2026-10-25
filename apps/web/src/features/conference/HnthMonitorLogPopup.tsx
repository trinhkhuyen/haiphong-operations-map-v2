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

const LOG_LAYOUT_KEY = "hnth-monitor-log-layout";
type LogLayout = { transparent?: boolean; onRight?: boolean; atBottom?: boolean; large?: boolean };
function readLogLayout(): LogLayout {
  try { return JSON.parse(window.localStorage.getItem(LOG_LAYOUT_KEY) || "{}") as LogLayout; } catch { return {}; }
}
function writeLogLayout(layout: LogLayout) {
  try { window.localStorage.setItem(LOG_LAYOUT_KEY, JSON.stringify(layout)); } catch { /* localStorage bị chặn */ }
}

// Chuyển động của từng điểm cầu: 2/3 thời gian đầu tăng tốc dần, 1/3 cuối
// giảm tốc dần trước khi dừng. Hai đoạn có cùng vận tốc tại điểm nối để không
// tạo thêm một cú giật giữa chừng khi ticker chuyển sang điểm mới.
function easeAccelerationTwoThirds(progress: number) {
  const t = Math.min(1, Math.max(0, progress));
  const accelerationPart = 2 / 3;
  if (t < accelerationPart) {
    const local = t / accelerationPart;
    return accelerationPart * local ** 3;
  }
  const local = (t - accelerationPart) / (1 - accelerationPart);
  return accelerationPart + (1 - accelerationPart) * (1 - (1 - local) ** 3);
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
  const overlayOnRight = useAppStore((state) => state.hnthLogOnRight);
  const overlayAtBottom = useAppStore((state) => state.hnthLogAtBottom);
  // Ctrl+↑ / Ctrl+↓: chữ log trong suốt to gấp 1,5 lần / về cỡ thường.
  const [overlayLargeText, setOverlayLargeText] = useState(() => readLogLayout().large === true);
  // Kiểu trong suốt, vị trí và cỡ chữ của log được lưu lại qua F5 (lưu riêng theo trình duyệt,
  // không qua store persist). Đọc một lần khi mở trang rồi ghi lại mỗi khi thay đổi.
  useEffect(() => {
    const saved = readLogLayout();
    const state = useAppStore.getState();
    if (typeof saved.transparent === "boolean") state.setHnthTransparentPopups(saved.transparent);
    if (typeof saved.onRight === "boolean") state.setHnthLogOnRight(saved.onRight);
    if (typeof saved.atBottom === "boolean") state.setHnthLogAtBottom(saved.atBottom);
  }, []);
  useEffect(() => {
    const save = () => {
      const state = useAppStore.getState();
      writeLogLayout({ transparent: state.hnthTransparentPopups, onRight: state.hnthLogOnRight, atBottom: state.hnthLogAtBottom, large: overlayLargeText });
    };
    save();
    return useAppStore.subscribe((state, previous) => {
      if (state.hnthTransparentPopups !== previous.hnthTransparentPopups || state.hnthLogOnRight !== previous.hnthLogOnRight || state.hnthLogAtBottom !== previous.hnthLogAtBottom) save();
    });
  }, [overlayLargeText]);
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
      // Log đang ở cạnh dưới: Ctrl+` chỉ đảo phía cột card Sở/Ban/Ngành (card luôn ở phía đối diện
      // hnthLogOnRight); log vẫn giữ 1 hàng ở dưới.
      const state = useAppStore.getState();
      state.setHnthLogOnRight(!state.hnthLogOnRight);
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
  const logSeqRef = useRef(0);
  const scrollAnimationRef = useRef(0);
  const scrollAnimationLastAtRef = useRef(0);
  const scrollPointQueueRef = useRef<number[]>([]);
  const scrollLastQueuedSeqRef = useRef(0);
  const scrollSegmentStartedAtRef = useRef(0);
  const scrollSegmentFromRef = useRef(0);
  const scrollSegmentTargetRef = useRef(0);
  const sectionRef = useRef<HTMLElement | null>(null);
  // Kéo thả log trong suốt: nhấn giữ chuột trái và kéo (quá 5px mới tính là kéo, nhấn rồi thả
  // tại chỗ vẫn là bấm chọn dòng). Thả ở dải dưới cùng bản đồ -> 1 hàng ở cạnh dưới; còn lại
  // gắn sang mép trái/phải gần con trỏ (card Sở/Ban/Ngành chuyển sang phía đối diện).
  const suppressClickRef = useRef(false);
  // Theo dõi di chuyển/thả trên cả cửa sổ: kéo nhanh con trỏ rời vùng log ngay, sự kiện sẽ rơi
  // vào bản đồ bên dưới. Không setPointerCapture để nhấn-thả tại chỗ vẫn là click vào dòng log.
  const onDragStart = (event: React.PointerEvent<HTMLElement>) => {
    const section = sectionRef.current;
    if (!monitorLogOverlay || event.button !== 0 || !section) return;
    // Chặn bôi chọn chữ khi kéo (click vẫn được phát để chọn dòng log).
    event.preventDefault();
    const start = { x: event.clientX, y: event.clientY };
    let moved = false;
    const onMove = (move: PointerEvent) => {
      const dx = move.clientX - start.x;
      const dy = move.clientY - start.y;
      if (!moved && Math.hypot(dx, dy) < 5) return;
      if (!moved) { moved = true; section.classList.add("is-dragging"); }
      section.style.transform = `translate(${dx}px, ${dy}px)`;
    };
    const onUp = (up: PointerEvent) => {
      window.removeEventListener("pointermove", onMove);
      window.removeEventListener("pointerup", onUp);
      window.removeEventListener("pointercancel", onUp);
      if (!moved) return;
      suppressClickRef.current = true;
      window.setTimeout(() => { suppressClickRef.current = false; }, 0);
      section.style.transform = "";
      section.classList.remove("is-dragging");
      const area = section.parentElement?.getBoundingClientRect();
      if (!area || up.type === "pointercancel") return;
      const state = useAppStore.getState();
      if (up.clientY > area.bottom - area.height * 0.22) { state.setHnthLogAtBottom(true); return; }
      state.setHnthLogAtBottom(false);
      state.setHnthLogOnRight(up.clientX > area.left + area.width / 2);
    };
    window.addEventListener("pointermove", onMove);
    window.addEventListener("pointerup", onUp);
    window.addEventListener("pointercancel", onUp);
  };
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
      const entries = items.map((item) => ({ ...toEntry({ ...item, checkedAt: item.checkedAt ?? batch.sentAt }), seq: ++logSeqRef.current }));
      setMonitorLog((current) => [...current, ...entries].slice(-1000));
    });
  }, [allPoints, continuousMonitoring, monitorConcurrency, updateHnthPoint]);

  useEffect(() => {
    const newestSeq = monitorLog.reduce((max, item) => Math.max(max, item.seq ?? 0), 0);
    if (!monitorAutoFocus) {
      window.cancelAnimationFrame(scrollAnimationRef.current);
      scrollAnimationRef.current = 0;
      scrollAnimationLastAtRef.current = 0;
      scrollPointQueueRef.current = [];
      scrollSegmentStartedAtRef.current = 0;
      // Khi bật lại AutoFocus, chỉ các điểm phát sinh sau thời điểm bật mới
      // được đưa vào hàng đợi; không chạy lại toàn bộ log cũ.
      scrollLastQueuedSeqRef.current = newestSeq;
      return;
    }
    const list = monitorLogListRef.current;
    if (!list) return;
    if (!(monitorLogOverlay && overlayAtBottom)) {
      window.cancelAnimationFrame(scrollAnimationRef.current);
      scrollAnimationRef.current = 0;
      scrollAnimationLastAtRef.current = 0;
      scrollPointQueueRef.current = [];
      scrollSegmentStartedAtRef.current = 0;
      scrollLastQueuedSeqRef.current = newestSeq;
      list.scrollTop = list.scrollHeight;
      return;
    }

    // Một batch có thể chứa rất nhiều luồng/điểm. Không lấy scrollWidth cuối
    // làm đích ngay (cách đó khiến một batch lớn kéo màn hình liên tục). Mỗi
    // seq mới tương ứng đúng một điểm; xếp chúng vào hàng đợi và chỉ xử lý
    // điểm kế tiếp sau khi điểm hiện tại đã tới vị trí cuối của nó.
    const newSeqs = monitorLog
      .map((item) => item.seq ?? 0)
      .filter((seq) => seq > scrollLastQueuedSeqRef.current)
      .sort((a, b) => a - b);
    if (newSeqs.length) {
      scrollPointQueueRef.current.push(...newSeqs);
      scrollLastQueuedSeqRef.current = Math.max(scrollLastQueuedSeqRef.current, ...newSeqs);
    }

    if (scrollAnimationRef.current || !scrollPointQueueRef.current.length) return;
    scrollAnimationLastAtRef.current = performance.now();
    const step = (now: number) => {
      const currentList = monitorLogListRef.current;
      if (!currentList || !monitorAutoFocus || !monitorLogOverlay || !overlayAtBottom) {
        scrollAnimationRef.current = 0;
        scrollAnimationLastAtRef.current = 0;
        scrollPointQueueRef.current = [];
        scrollSegmentStartedAtRef.current = 0;
        return;
      }
      const currentSeq = scrollPointQueueRef.current[0];
      const row = currentSeq
        ? currentList.querySelector<HTMLElement>(`[data-monitor-seq="${currentSeq}"]`)
        : null;
      if (!row) {
        // Có thể điểm đã bị cắt khỏi cửa sổ 1000 dòng trước khi được vẽ.
        scrollPointQueueRef.current.shift();
        if (!scrollPointQueueRef.current.length) {
          scrollAnimationRef.current = 0;
          scrollAnimationLastAtRef.current = 0;
          return;
        }
        scrollAnimationRef.current = window.requestAnimationFrame(step);
        return;
      }

      // Tính đích theo hình học của đúng một dòng mới, không dùng scrollWidth
      // và không coi một khoảng pixel là một "điểm". Đích là vị trí vừa đủ để
      // dòng này hiện trọn ở mép phải của ticker.
      if (!scrollSegmentStartedAtRef.current) {
        const listRect = currentList.getBoundingClientRect();
        const rowRect = row.getBoundingClientRect();
        const maxScroll = Math.max(0, currentList.scrollWidth - currentList.clientWidth);
        const target = Math.max(0, Math.min(maxScroll, currentList.scrollLeft + rowRect.right - listRect.right));
        scrollSegmentFromRef.current = currentList.scrollLeft;
        scrollSegmentTargetRef.current = target;
        scrollSegmentStartedAtRef.current = now;
      }

      const from = scrollSegmentFromRef.current;
      const target = scrollSegmentTargetRef.current;
      const distance = target - from;
      // Mỗi điểm có một nhịp cố định; không phụ thuộc số pixel hay số luồng
      // trong batch. Điểm tiếp theo chỉ được lấy sau khi đoạn này kết thúc.
      const t = Math.min(1, Math.max(0, (now - scrollSegmentStartedAtRef.current) / 360));
      const eased = easeAccelerationTwoThirds(t);
      currentList.scrollLeft = from + distance * eased;
      if (t < 1) {
        scrollAnimationRef.current = window.requestAnimationFrame(step);
        return;
      }
      currentList.scrollLeft = target;
      scrollSegmentStartedAtRef.current = 0;
      scrollPointQueueRef.current.shift();
      if (!scrollPointQueueRef.current.length) {
        scrollAnimationRef.current = 0;
        scrollAnimationLastAtRef.current = 0;
        return;
      }
      scrollAnimationLastAtRef.current = now;
      scrollAnimationRef.current = window.requestAnimationFrame(step);
    };
    scrollAnimationRef.current = window.requestAnimationFrame(step);
  }, [monitorAutoFocus, monitorLog, monitorLogOverlay, overlayAtBottom]);

  useEffect(() => () => {
    window.cancelAnimationFrame(scrollAnimationRef.current);
    scrollAnimationRef.current = 0;
    scrollAnimationLastAtRef.current = 0;
    scrollPointQueueRef.current = [];
    scrollSegmentStartedAtRef.current = 0;
  }, []);

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
  return <section className={`hnth-monitor-log-popup${monitorLogOverlay ? ` is-overlay${overlayAtBottom ? " is-bottom" : overlayOnRight ? " is-right" : ""}${overlayLargeText ? " is-large" : ""}` : monitorLogCollapsed ? " is-collapsed" : ""}`} role="region" aria-label="Log giám sát liên tục" ref={sectionRef} onPointerDown={onDragStart} onClickCapture={(event) => { if (suppressClickRef.current) { event.preventDefault(); event.stopPropagation(); } }}>
    {!monitorLogOverlay && <header><span><RadioTower size={16}/><strong>Log giám sát liên tục</strong><em>{monitorConcurrency} luồng</em></span><span className="hnth-monitor-log-actions"><label><input data-hnth-monitor-autofocus="true" type="checkbox" checked={monitorAutoFocus} onChange={(event) => setMonitorAutoFocus(event.target.checked)}/> AutoFocus</label><button type="button" className="hnth-monitor-log-toggle" onClick={() => setMonitorLogCollapsed((value) => !value)} title={monitorLogCollapsed ? "Mở rộng log" : "Thu nhỏ log"} aria-label={monitorLogCollapsed ? "Mở rộng log" : "Thu nhỏ log"}>{monitorLogCollapsed ? <ChevronUp size={13}/> : <ChevronDown size={13}/>}</button><button type="button" onClick={exportMonitorLog}>Export</button></span></header>}
    {showList && <div data-hnth-monitor-log-list="true" ref={monitorLogListRef} className="hnth-monitor-log-list">
      {monitorLog.length === 0 && <small>Đang chờ kết quả từ agent...</small>}
      {monitorLog.map((item, index) => {
        const point = allPoints.find((candidate) => String(candidate.properties?.pointId ?? candidate.id) === item.pointId);
        return <button data-monitor-seq={item.seq ?? undefined} className={`hnth-monitor-log-row ${item.status.toLowerCase()}`} key={item.seq ?? `${item.pointId}-${item.timestamp}-${index}`} type="button" onClick={() => { if (point) onFocusPoint(point); }}><i/><span><strong>{item.name}</strong><small>{item.ip} · {item.status} {item.time}</small></span></button>;
      })}
    </div>}
  </section>;
}
