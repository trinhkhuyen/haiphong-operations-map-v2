// Kênh realtime HNTH duy nhất của trang: một EventSource `/api/hnth/stream` và
// một vòng poll `/api/hnth/monitor-state` dùng chung cho mọi màn hình.
// - SSE là kênh chính nhưng chỉ phát khi có sự kiện; snapshot định kỳ giúp phục
//   hồi khi trình duyệt throttle/ngắt kết nối lúc tab chạy nền, và cho Guest mở
//   trang giữa phiên giám sát thấy ngay trạng thái mới nhất.
// - Chu kỳ poll = chu kỳ ngắn nhất mà các subscriber đang yêu cầu.
// - Trạng thái backend/agent/giám sát được ghi vào useHnthLiveStore trước khi
//   gọi listener, để listener đồng bộ thấy trạng thái mới (thứ tự như event cũ).
import { hnthApi } from "../api/clients";
import { useHnthLiveStore, type HnthCatalog, type HnthRoster } from "./hnth-live-store";

type AgentSummary = { agentId?: string; name?: string; status?: string; version?: string | null };
type MonitoringPayload = { enabled?: boolean; concurrency?: number; waitSeconds?: number; agentId?: string; sessionId?: string | null };

export type MonitorBatch = { start?: number; end?: number; total?: number; concurrency?: number; sentAt?: string; sessionId?: string | null; results?: unknown; allResults?: unknown };

/** Snapshot monitor-state và message SSE cùng một hình dạng (backend broadcastState). */
export type HnthLivePayload = {
  type?: string;
  monitoring?: MonitoringPayload;
  agents?: AgentSummary[];
  results?: unknown;
  monitorBatch?: MonitorBatch;
  catalog?: HnthCatalog | null;
  activeRoster?: HnthRoster | null;
};

export type SnapshotResult = { ok: true; payload: HnthLivePayload } | { ok: false; payload: null };

type SnapshotSubscriber = { intervalMs: number; listener: (result: SnapshotResult) => void };

const snapshotSubscribers = new Set<SnapshotSubscriber>();
const streamListeners = new Set<(payload: HnthLivePayload) => void>();
const batchListeners = new Set<(batch: MonitorBatch) => void>();
let pollTimer: number | undefined;
let pollIntervalMs = 0;
let inFlight: Promise<void> | null = null;
let source: EventSource | null = null;
let visibilityBound = false;

function applyRoster(payload: HnthLivePayload) {
  // Payload cũ (backend chưa nâng cấp) không có khóa này: giữ nguyên danh sách hiện tại.
  if (!("activeRoster" in payload)) return;
  const catalog = payload.catalog && Array.isArray(payload.catalog.points) ? payload.catalog : null;
  const roster = payload.activeRoster && Array.isArray(payload.activeRoster.pointIds) ? payload.activeRoster : null;
  useHnthLiveStore.getState().setSessionPoints(catalog, roster);
}

function applyMonitoring(monitoring: MonitoringPayload | undefined) {
  if (!monitoring) return;
  useHnthLiveStore.getState().setMonitoring({ enabled: Boolean(monitoring.enabled), concurrency: monitoring.concurrency, waitSeconds: monitoring.waitSeconds });
}

// Chỉ phản ánh agent đang được chọn cho HNTH (monitor_state.agent_id), không
// phải agent vừa gửi heartbeat gần nhất khi nhiều agent cùng kết nối.
function applySelectedAgent(payload: HnthLivePayload, ok: boolean) {
  if (!Array.isArray(payload.agents)) return;
  const live = useHnthLiveStore.getState();
  const agentId = String(payload.monitoring?.agentId ?? "").trim() || live.agent.agentId;
  const agent = payload.agents.find((item) => String(item.agentId ?? "") === agentId);
  live.setAgent({ agentId, name: agent?.name?.trim() || agentId || "Agent HNTH", state: ok && agent?.status === "online" ? "online" : "offline" });
}

async function fetchSnapshot() {
  const live = useHnthLiveStore.getState();
  let result: SnapshotResult;
  try {
    const response = await hnthApi.monitorState();
    const payload = await response.json().catch(() => null) as HnthLivePayload | null;
    live.setBackend(response.ok ? "online" : "offline");
    if (response.ok && payload) {
      applySelectedAgent(payload, true);
      applyMonitoring(payload.monitoring);
      applyRoster(payload);
      result = { ok: true, payload };
    } else {
      // Backend lỗi thì không biết agent còn sống: hiển thị mất kết nối như trước.
      live.setAgent({ ...live.agent, state: "offline" });
      result = { ok: false, payload: null };
    }
  } catch {
    live.setBackend("offline");
    live.setAgent({ ...useHnthLiveStore.getState().agent, state: "offline" });
    result = { ok: false, payload: null };
  }
  for (const subscriber of [...snapshotSubscribers]) {
    try { subscriber.listener(result); } catch (error) { console.error(error); }
  }
}

/** Đọc snapshot ngay; gộp các yêu cầu trùng lúc một request đang chạy. */
export function refreshHnthSnapshot() {
  inFlight ??= fetchSnapshot().finally(() => { inFlight = null; });
  return inFlight;
}

function reschedulePolling() {
  const next = snapshotSubscribers.size ? Math.min(...[...snapshotSubscribers].map((item) => item.intervalMs)) : 0;
  if (next === pollIntervalMs) return;
  window.clearInterval(pollTimer);
  pollIntervalMs = next;
  pollTimer = next ? window.setInterval(() => void refreshHnthSnapshot(), next) : undefined;
}

function handleStreamMessage(event: MessageEvent<string>) {
  let payload: HnthLivePayload;
  try { payload = JSON.parse(event.data) as HnthLivePayload; } catch { return; /* bỏ qua sự kiện lỗi định dạng */ }
  applyMonitoring(payload.monitoring);
  applyRoster(payload);
  applySelectedAgent(payload, true);
  for (const listener of [...streamListeners]) {
    try { listener(payload); } catch (error) { console.error(error); }
  }
  // Một nguồn batch duy nhất cho toàn bộ UI HNTH (log giám sát, trình chiếu).
  if (payload.monitorBatch) for (const listener of [...batchListeners]) listener(payload.monitorBatch);
}

function connectStream() {
  source?.close();
  source = new EventSource(hnthApi.streamUrl());
  source.onmessage = handleStreamMessage;
}

function bindVisibility() {
  if (visibilityBound) return;
  visibilityBound = true;
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState !== "visible") return;
    if (streamListeners.size) connectStream();
    if (snapshotSubscribers.size) void refreshHnthSnapshot();
  });
}

/** Nhận snapshot monitor-state mỗi `intervalMs` (và ngay khi đăng ký). */
export function subscribeHnthSnapshots(intervalMs: number, listener: (result: SnapshotResult) => void) {
  const subscriber = { intervalMs, listener };
  snapshotSubscribers.add(subscriber);
  bindVisibility();
  reschedulePolling();
  void refreshHnthSnapshot();
  return () => { snapshotSubscribers.delete(subscriber); reschedulePolling(); };
}

/** Nhận từng message SSE; SSE chỉ mở khi có ít nhất một listener. */
export function subscribeHnthStream(listener: (payload: HnthLivePayload) => void) {
  streamListeners.add(listener);
  bindVisibility();
  // Mở lại kết nối mỗi lần đăng ký (như khi HnthPanel tạo lại handler trước đây),
  // để trình duyệt không giữ một kết nối đã bị proxy cắt im lặng.
  connectStream();
  return () => {
    streamListeners.delete(listener);
    if (!streamListeners.size) { source?.close(); source = null; }
  };
}

/** Batch giám sát của Agent (monitorBatch trong message SSE). */
export function subscribeMonitorBatches(listener: (batch: MonitorBatch) => void) {
  batchListeners.add(listener);
  return () => { batchListeners.delete(listener); };
}
