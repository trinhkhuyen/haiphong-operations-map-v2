import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

// Môi trường node: dựng window/document/EventSource/fetch giả trước khi import
// (auth.ts đọc sessionStorage ngay lúc import).
const windowTarget = new EventTarget();
vi.stubGlobal("window", Object.assign(windowTarget, {
  setInterval: (handler: () => void, ms: number) => setInterval(handler, ms),
  clearInterval: (id?: number) => clearInterval(id),
}));
vi.stubGlobal("document", Object.assign(new EventTarget(), { visibilityState: "visible" }));
vi.stubGlobal("sessionStorage", { getItem: () => null, setItem: () => undefined, removeItem: () => undefined });

class FakeEventSource {
  static instances: FakeEventSource[] = [];
  onmessage: ((event: MessageEvent<string>) => void) | null = null;
  closed = false;
  constructor(public url: string) { FakeEventSource.instances.push(this); }
  close() { this.closed = true; }
  emit(payload: unknown) { this.onmessage?.({ data: JSON.stringify(payload) } as MessageEvent<string>); }
}
vi.stubGlobal("EventSource", FakeEventSource);

let snapshot: { status: number; body: unknown } = { status: 200, body: {} };
const fetchMock = vi.fn(async (_input: RequestInfo | URL, _init?: RequestInit) => new Response(JSON.stringify(snapshot.body), { status: snapshot.status }));
vi.stubGlobal("fetch", fetchMock);

const realtime = await import("./hnth-realtime");
const { useHnthLiveStore } = await import("./hnth-live-store");
const { emitAppEvent, onAppEvent } = await import("../events");
const initialLive = useHnthLiveStore.getState();

const monitorState = (agentStatus: string, enabled = false) => ({
  monitoring: { enabled, concurrency: 2, waitSeconds: 3, agentId: "agent-a" },
  agents: [{ agentId: "agent-a", name: " Agent A ", status: agentStatus }, { agentId: "agent-b", name: "B", status: "online" }],
  results: [],
});

beforeEach(() => {
  useHnthLiveStore.setState(initialLive, true);
  fetchMock.mockClear();
  FakeEventSource.instances = [];
  snapshot = { status: 200, body: monitorState("online") };
  vi.useFakeTimers();
});
afterEach(() => { vi.useRealTimers(); });

describe("hnth-realtime: snapshot", () => {
  it("ghi trạng thái backend/agent đang chọn/giám sát vào store rồi mới gọi listener", async () => {
    const seen: unknown[] = [];
    const stop = realtime.subscribeHnthSnapshots(5000, (result) => {
      const live = useHnthLiveStore.getState();
      seen.push([result.ok, live.backend, live.agent.state, live.agent.name, live.monitoring.concurrency]);
    });
    await realtime.refreshHnthSnapshot();
    stop();
    expect(seen).toEqual([[true, "online", "online", "Agent A", 2]]);
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(String(fetchMock.mock.calls[0]?.[0])).toBe("/api/hnth/monitor-state");
  });

  it("backend lỗi hoặc không phản hồi: backend và agent đều offline, listener nhận ok=false", async () => {
    const results: boolean[] = [];
    const stop = realtime.subscribeHnthSnapshots(5000, (result) => results.push(result.ok));
    await realtime.refreshHnthSnapshot();
    snapshot = { status: 500, body: { error: "x" } };
    await vi.advanceTimersByTimeAsync(5000);
    expect(useHnthLiveStore.getState().backend).toBe("offline");
    expect(useHnthLiveStore.getState().agent.state).toBe("offline");
    fetchMock.mockRejectedValueOnce(new Error("network"));
    await vi.advanceTimersByTimeAsync(5000);
    stop();
    expect(results).toEqual([true, false, false]);
  });

  it("poll theo chu kỳ ngắn nhất của các subscriber; hủy hết thì dừng", async () => {
    const stopSlow = realtime.subscribeHnthSnapshots(10000, () => undefined);
    const stopFast = realtime.subscribeHnthSnapshots(2000, () => undefined);
    await realtime.refreshHnthSnapshot();
    fetchMock.mockClear();
    await vi.advanceTimersByTimeAsync(6000);
    expect(fetchMock).toHaveBeenCalledTimes(3);
    stopFast();
    fetchMock.mockClear();
    await vi.advanceTimersByTimeAsync(10000);
    expect(fetchMock).toHaveBeenCalledTimes(1);
    stopSlow();
    fetchMock.mockClear();
    await vi.advanceTimersByTimeAsync(30000);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("gộp các yêu cầu trùng khi một request đang chạy", async () => {
    await Promise.all([realtime.refreshHnthSnapshot(), realtime.refreshHnthSnapshot(), realtime.refreshHnthSnapshot()]);
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });
});

describe("hnth-realtime: SSE", () => {
  it("một EventSource dùng chung; đóng khi listener cuối cùng hủy", () => {
    const stop = realtime.subscribeHnthStream(() => undefined);
    const [source] = FakeEventSource.instances;
    expect(source.url).toBe("/api/hnth/stream");
    stop();
    expect(source.closed).toBe(true);
  });

  it("thứ tự: store (giám sát/agent) → listener stream → listener batch", () => {
    const order: string[] = [];
    const stopMonitoringWatch = useHnthLiveStore.subscribe((state, previous) => {
      if (state.monitoring !== previous.monitoring) order.push(`monitoring:${state.monitoring.enabled}`);
    });
    const stopStream = realtime.subscribeHnthStream((payload) => order.push(`stream:${payload.type}:agent=${useHnthLiveStore.getState().agent.state}`));
    const stopBatch = realtime.subscribeMonitorBatches((batch) => order.push(`batch:${batch.end}`));
    FakeEventSource.instances.at(-1)!.emit({ type: "state", ...monitorState("offline", true), monitorBatch: { end: 2, total: 4 } });
    // Cùng giá trị giám sát: không phát lại cho listener của store.
    FakeEventSource.instances.at(-1)!.emit({ type: "state", ...monitorState("offline", true) });
    stopMonitoringWatch(); stopStream(); stopBatch();
    expect(order).toEqual(["monitoring:true", "stream:state:agent=offline", "batch:2", "stream:state:agent=offline"]);
  });

  it("message không phải JSON bị bỏ qua", () => {
    const listener = vi.fn();
    const stop = realtime.subscribeHnthStream(listener);
    FakeEventSource.instances.at(-1)!.onmessage?.({ data: "not json" } as MessageEvent<string>);
    stop();
    expect(listener).not.toHaveBeenCalled();
  });
});

describe("core/events", () => {
  it("phát/nghe theo tên sự kiện cũ, hủy đăng ký được", () => {
    const received: unknown[] = [];
    const stop = onAppEvent("hnth:open-point-log", (detail) => received.push(detail));
    const raw = vi.fn();
    window.addEventListener("hnth:open-point-log", raw);
    emitAppEvent("hnth:open-point-log", { pointId: "p1" });
    stop();
    emitAppEvent("hnth:open-point-log", { pointId: "p2" });
    window.removeEventListener("hnth:open-point-log", raw);
    expect(received).toEqual([{ pointId: "p1" }]);
    expect(raw).toHaveBeenCalledTimes(2);
  });
});
