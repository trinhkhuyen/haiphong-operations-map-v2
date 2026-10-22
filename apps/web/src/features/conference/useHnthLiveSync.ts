// Đồng bộ trạng thái HNTH từ backend (snapshot monitor-state + SSE qua
// core/realtime) vào layer/store, và nhận diện thay đổi theo vòng giám sát
// để khoanh địa giới có trạng thái đổi.
import { useEffect, useRef } from "react";
import { toConnectionStatus } from "@haiphong-ops/hnth-protocol";
import { useAppStore } from "../../core/store";
import { emitAppEvent, onAppEvent } from "../../core/events";
import { refreshHnthSnapshot, subscribeHnthSnapshots, subscribeHnthStream, type HnthLivePayload } from "../../core/realtime/hnth-realtime";
import { HNTH_LAYER_ID, HNTH_STATUS_LABELS, normalizeHnthStatus, type HnthConnectionStatus, type HnthPointOverride } from "../layers/hnth-data-provider";
import type { OperationalLayer } from "../../core/types";
import type { HnthLiveAgent, HnthPointFeature } from "./hnth-types";

type LiveSyncOptions = {
  points: HnthPointFeature[];
  layer: OperationalLayer | undefined;
  continuousMonitoring: boolean;
  selectedAgentId: string;
  setSelectedAgentId: (agentId: string) => void;
  setLiveAgents: (agents: HnthLiveAgent[]) => void;
  setContinuousMonitoring: (enabled: boolean) => void;
  setPingConcurrency: (value: number) => void;
  setMonitorWaitSeconds: (value: number) => void;
};

export function useHnthLiveSync({ points, layer, continuousMonitoring, selectedAgentId, setSelectedAgentId, setLiveAgents, setContinuousMonitoring, setPingConcurrency, setMonitorWaitSeconds }: LiveSyncOptions) {
  const mergeOperationalLayers = useAppStore((state) => state.mergeOperationalLayers);
  const updateHnthPoints = useAppStore((state) => state.updateHnthPoints);
  const pointsRef = useRef(points);
  // Giữ snapshot authoritative cuối cùng trong suốt vòng đời component. Khi
  // App nạp lại/thay thế GeoJSON HNTH sau F5, snapshot có thể đã về trước đó
  // và việc merge lớp mới sẽ ghi đè trạng thái line/fill. Snapshot này được
  // replay ngay sau khi lớp HNTH mới sẵn sàng.
  const latestLivePayloadRef = useRef<unknown>(null);
  const monitoringFirstRoundCompleteRef = useRef(false);
  const monitoringSeenPointIdsRef = useRef(new Set<string>());
  const monitoringPendingAdministrativeIdsRef = useRef(new Set<number>());
  const monitoringSessionIdRef = useRef<string | null>(null);
  // Snapshot riêng của Agent theo từng endpoint. Không dùng layer/store làm
  // trạng thái trước đó vì applyLiveResults có thể cập nhật chúng trước khi
  // batch kế tiếp được đem ra so sánh.
  const monitoringLastStatusRef = useRef(new globalThis.Map<string, HnthConnectionStatus>());
  const resetMonitoringTracking = () => {
    monitoringFirstRoundCompleteRef.current = false;
    monitoringSeenPointIdsRef.current = new Set();
    monitoringPendingAdministrativeIdsRef.current = new Set();
    monitoringLastStatusRef.current = new globalThis.Map();
  };
  useEffect(() => { pointsRef.current = points; }, [points]);

  // Đồng bộ trạng thái từ relay server nếu agent LAN đang hoạt động.
  // Khi relay chưa được cấu hình hoặc mất kết nối, dữ liệu demo vẫn được giữ nguyên.
  useEffect(() => {
    if (!points.length) return;
    let cancelled = false;
    const handleMonitoringBatch = (
      batch: { end?: number; total?: number; sessionId?: string | null; results?: unknown; allResults?: unknown },
      monitoringEnabled = continuousMonitoring,
    ) => {
      // Agent gửi monitorBatch.allResults cho cả batch để frontend biết
      // endpoint nào vừa được quét; batch.results chỉ là payload rút gọn
      // của telemetry và có thể không tồn tại.
      const statusResults = Array.isArray(batch.allResults) ? batch.allResults : batch.results;
      // Khi SSE vừa chuyển trạng thái từ tắt sang bật, state React chưa kịp
      // render trong cùng callback. Dùng cờ từ chính snapshot backend để không
      // bỏ qua batch đầu tiên của chu kỳ giám sát.
      const batchSessionId = String(batch.sessionId || "").trim() || null;
      if (!monitoringEnabled || !Array.isArray(statusResults) || (batchSessionId && batchSessionId !== monitoringSessionIdRef.current)) return;
      const currentPoints = pointsRef.current;
      const pointById = new globalThis.Map(currentPoints.map((feature) => [String(feature.properties?.pointId ?? feature.id ?? "").trim(), feature]));
      const pointByIp = new globalThis.Map(currentPoints.map((feature) => [String(feature.properties?.ipAddress ?? "").trim(), feature]));
      const changedAdministrativeIds = new Set<number>();
      for (const item of statusResults as Array<{ pointId?: unknown; ipAddress?: unknown; status?: unknown }>) {
        const point = pointById.get(String(item.pointId ?? "").trim()) ?? pointByIp.get(String(item.ipAddress ?? "").trim());
        const pointId = String(point?.properties?.pointId ?? point?.id ?? "").trim();
        if (!pointId || !point) continue;
        monitoringSeenPointIdsRef.current.add(pointId);
        const hasIp = Boolean(String(point.properties?.ipAddress ?? "").trim());
        const nextStatus: HnthConnectionStatus = toConnectionStatus(item.status, hasIp);
        const previousStatus = monitoringLastStatusRef.current.get(pointId)
          ?? normalizeHnthStatus(useAppStore.getState().hnthPointOverrides[pointId]?.status ?? point.properties?.status);
        // Ghi snapshot trước khi applyLiveResults cập nhật layer/store. Đây là
        // mốc chuẩn để nhận diện thay đổi ở vòng 2 và các vòng tiếp theo.
        monitoringLastStatusRef.current.set(pointId, nextStatus);
        if (previousStatus !== nextStatus) {
          const wardCode = String(point.properties?.wardCode ?? "").trim();
          const administrativeId = useAppStore.getState().administrativeUnits.find((unit) => String(unit.wardCode ?? "") === wardCode)?.id;
          if (administrativeId !== undefined) {
            if (monitoringFirstRoundCompleteRef.current) changedAdministrativeIds.add(administrativeId);
            else monitoringPendingAdministrativeIdsRef.current.add(administrativeId);
          }
        }
      }
      if (!monitoringFirstRoundCompleteRef.current) {
        const expectedPointIds = currentPoints
          .map((point) => String(point.properties?.pointId ?? point.id ?? "").trim())
          .filter(Boolean);
        // Chỉ kết thúc vòng đầu khi toàn bộ danh sách điểm hiện tại đã xuất
        // hiện trong kết quả Agent. Không dùng end >= total một mình vì một
        // batch cũ/khác cấu hình có thể làm frontend kết luận sớm, khiến các
        // điểm ở cuối danh sách vẫn unknown nhưng đã bắt đầu khoanh vùng.
        const allPointsSeen = expectedPointIds.length > 0
          && expectedPointIds.every((pointId) => monitoringSeenPointIdsRef.current.has(pointId));
        const reportedFullBatch = Number(batch.end ?? 0) >= Number(batch.total ?? 0)
          && Number(batch.total ?? 0) >= expectedPointIds.length
          && expectedPointIds.length > 0;
        if (allPointsSeen || reportedFullBatch) {
          monitoringFirstRoundCompleteRef.current = true;
          // Vòng đầu chỉ thiết lập trạng thái nền. Không phát pulse cho các
          // thay đổi từ unknown/demo ở vòng này; từ vòng kế tiếp mới chỉ
          // khoanh đúng địa giới có trạng thái thay đổi.
          monitoringPendingAdministrativeIdsRef.current.clear();
        }
      }
      if (changedAdministrativeIds.size) {
        // Khoanh tự động dùng đúng độ dày chuẩn x2 nét mảnh và chỉ giữ
        // hiệu ứng khoảng 5 giây, không nhân x2 thêm một lần nữa.
        emitAppEvent("map:administrative-pulse", { administrativeIds: [...changedAdministrativeIds], cycles: 1, boundaryWidthMultiplier: 2, durationMs: 5000, animate: false });
      }
    };
    const applyLiveResults = (payload: unknown) => {
      if (!payload || typeof payload !== "object") return;
      // Ghi snapshot ngay cả khi effect hiện tại vừa bị cleanup. Khi reload,
      // monitor-state/SSE có thể trả về đúng lúc lớp GeoJSON HNTH đang thay
      // đổi; snapshot này sẽ được replay sau sự kiện layer-ready.
      latestLivePayloadRef.current = payload;
      if (cancelled) return;
      const snapshot = payload as { agents?: Array<{ agentId?: string; name?: string; status?: string; version?: string | null }>; monitoring?: { agentId?: string; enabled?: boolean; sessionId?: string | null } };
      // Agent được chọn trong snapshot backend là nguồn sự thật (có thể vừa được
      // đổi từ client khác); trạng thái chỉ phát cho đúng agent đó.
      const activeAgentId = String(snapshot.monitoring?.agentId ?? "").trim() || selectedAgentId;
      if (snapshot.monitoring?.agentId) setSelectedAgentId(activeAgentId);
      if (Array.isArray(snapshot.agents)) {
        setLiveAgents(snapshot.agents
          .filter((item) => item.agentId)
          .map((item) => ({ agentId: String(item.agentId), name: String(item.name || item.agentId), status: String(item.status || "offline"), version: item.version ? String(item.version) : undefined })));
      }
      const monitorBatch = (payload as { monitorBatch?: { sessionId?: string | null; allResults?: unknown } }).monitorBatch;
      const payloadSessionId = String(snapshot.monitoring?.sessionId || monitorBatch?.sessionId || "").trim() || null;
      if (payloadSessionId && payloadSessionId !== monitoringSessionIdRef.current) return;
      // Agent gửi `results` rút gọn chỉ gồm các thay đổi để tiết kiệm băng
      // thông, còn `allResults` là đúng batch vừa quét. Dùng allResults cho
      // phần vẽ để line/fill cập nhật ngay theo từng batch/số luồng, không bị
      // dồn đến cuối cả vòng.
      const stateResults = (payload as { results?: unknown }).results;
      // `results` is the backend's complete authoritative snapshot. The
      // monitor batch is only metadata/log context; using its partial batch
      // as the visual state made other clients retain stale/unknown points.
      const results = Array.isArray(stateResults)
        ? stateResults
        : monitorBatch?.allResults;
      if (!Array.isArray(results)) return;
      const currentPoints = pointsRef.current;
      const pointById = new globalThis.Map(currentPoints.map((feature) => [String(feature.properties?.pointId ?? feature.id ?? "").trim(), feature]));
      const pointByIp = new globalThis.Map(currentPoints.map((feature) => [String(feature.properties?.ipAddress ?? "").trim(), feature]));
      const resolvedLive = new globalThis.Map<string, { status: string; ipAddress?: string | null; latencyMs?: number | null }>();
      const statusUpdates: Record<string, Partial<HnthPointOverride>> = {};
      const currentState = useAppStore.getState();
      for (const item of results as Array<{ pointId?: unknown; ipAddress?: unknown; status?: unknown; latencyMs?: number | null }>) {
        // pointId là khóa định danh ổn định. Chỉ fallback theo IP vì IP có
        // thể vừa được đổi hoặc tạm thời bị trùng trong cấu hình cũ.
        const point = pointById.get(String(item.pointId ?? "").trim())
          ?? pointByIp.get(String(item.ipAddress ?? "").trim());
        const resolvedPointId = String(point?.properties?.pointId ?? point?.id ?? "").trim();
        if (!resolvedPointId) continue;
        resolvedLive.set(resolvedPointId, { ipAddress: String(item.ipAddress ?? "").trim() || null, status: String(item.status ?? "unknown"), latencyMs: item.latencyMs });
          // IP trong snapshot backend là nguồn sự thật; dùng nó thay vì IP
          // đang nằm trong layer cũ để xử lý ngay cấu hình vừa đổi từ client khác.
          const reportedIp = String(item.ipAddress ?? "").trim();
          // IP trong snapshot backend là nguồn sự thật. Không dùng IP cũ còn
          // nằm trong layer làm fallback, nếu không endpoint đã bị xóa IP vẫn
          // bị ping/đánh dấu như một endpoint có cấu hình.
          const hasIp = Boolean(reportedIp);
          const nextStatus: HnthConnectionStatus = toConnectionStatus(item.status, hasIp);
        if (currentState.hnthPointOverrides[resolvedPointId]?.status !== nextStatus) {
          statusUpdates[resolvedPointId] = { status: nextStatus };
        }
      }
      updateHnthPoints(statusUpdates);
      const currentLayer = useAppStore.getState().layers.find((item) => item.id === HNTH_LAYER_ID) ?? layer;
      if (!currentLayer) return;
      let visualDataChanged = false;
      const nextFeatures = currentLayer.data.features.map((feature) => {
        const pointId = String(feature.properties?.pointId ?? feature.id ?? "").trim();
        const live = resolvedLive.get(pointId);
        if (!live) return feature;
        // Ping chỉ xác nhận thiết bị reachable, chưa chứng minh đang tham gia hội nghị.
        const reportedIp = live.ipAddress ?? "";
        // Backend phải quyết định IP hiện hành; IP trong feature chỉ là dữ
        // liệu hiển thị cũ và không được dùng lại sau khi người dùng sửa/xóa.
        const hasIp = Boolean(String(reportedIp).trim());
        const status: HnthConnectionStatus = toConnectionStatus(live.status, hasIp);
        const nextSource = status === "unknown" ? feature.properties?.source : "Dữ liệu thật từ LAN agent";
        const nextDataSource = status === "unknown" ? feature.properties?.dataSource : "live";
        // SSE cũng phát lại snapshot định kỳ. Không thay object/layer nếu trạng thái
        // hiển thị không đổi; việc setData lặp lại làm MapLibre dựng lại line/fill,
        // tạo cảm giác các đường cung và vùng tô bị giật mỗi 1–2 giây.
        if (feature.properties?.status === status
          && String(feature.properties?.ipAddress ?? "") === String(reportedIp)
          && feature.properties?.source === nextSource
          && feature.properties?.dataSource === nextDataSource) return feature;
        visualDataChanged = true;
        return {
          ...feature,
          properties: {
            ...feature.properties,
            ...(reportedIp ? { ipAddress: reportedIp } : { ipAddress: null }),
            status,
            ...(status === "unknown" ? { statusLabel: undefined } : { statusLabel: HNTH_STATUS_LABELS[status] }),
            source: nextSource,
            dataSource: nextDataSource,
            latencyMs: live.latencyMs ?? null,
          },
        };
      });
      if (!visualDataChanged) return;
      mergeOperationalLayers([{
        ...currentLayer,
        data: { ...currentLayer.data, features: nextFeatures },
      }]);
    };
    const applyMonitoringSettings = (monitoring: NonNullable<HnthLivePayload["monitoring"]>) => {
      // The backend resets the shared state when the admin starts a new
      // session. Other clients must consume that authoritative snapshot,
      // not locally reset/overwrite it from a stale React closure.
      const nextSessionId = String(monitoring.sessionId || "").trim() || null;
      if (nextSessionId !== monitoringSessionIdRef.current) {
        monitoringSessionIdRef.current = nextSessionId;
        resetMonitoringTracking();
      }
      setContinuousMonitoring(Boolean(monitoring.enabled));
      if (Number.isFinite(monitoring.concurrency)) setPingConcurrency(Math.max(1, Math.min(30, Number(monitoring.concurrency))));
      if (Number.isFinite(monitoring.waitSeconds)) setMonitorWaitSeconds(Math.max(1, Math.min(10, Number(monitoring.waitSeconds))));
    };
    // monitor-state trả cờ giám sát và snapshot đầy đủ cùng lúc, nên Guest mở
    // trang sau vòng 1 vẫn hydrate giống Guest đã xem SSE từ đầu. Initial
    // hydration must not reset the local map: the snapshot is authoritative.
    const applySnapshot = (payload: HnthLivePayload) => {
      if (payload.monitoring) applyMonitoringSettings(payload.monitoring);
      applyLiveResults(payload);
    };
    const stopLayerReady = onAppEvent("hnth:layer-ready", () => {
      // Nếu snapshot đã về trước khi layer được nạp, áp dụng lại ngay. Nếu
      // chưa có snapshot thì đọc lại backend để không phụ thuộc SSE đã đến
      // trước hay sau quá trình khởi tạo bản đồ.
      if (latestLivePayloadRef.current) applyLiveResults(latestLivePayloadRef.current);
      else void refreshHnthSnapshot();
    });
    // SSE và snapshot định kỳ do core/realtime quản lý (một kết nối cho cả trang).
    // Khi đang giám sát, snapshot dày hơn để Guest khôi phục line/fill kể cả khi
    // Agent không gửi thay đổi nào.
    const stopSnapshots = subscribeHnthSnapshots(continuousMonitoring ? 2000 : 5000, (result) => {
      if (result.ok) applySnapshot(result.payload);
    });
    const stopStream = subscribeHnthStream((payload) => {
      if (payload.monitoring) applyMonitoringSettings(payload.monitoring);
      if (payload.monitorBatch) handleMonitoringBatch(payload.monitorBatch, payload.monitoring?.enabled ?? continuousMonitoring);
      applyLiveResults(payload);
    });
    return () => {
      cancelled = true;
      stopSnapshots();
      stopStream();
      stopLayerReady();
    };
  // Khi bật/tắt giám sát, tạo lại handler SSE để closure luôn dùng đúng
  // trạng thái hiện tại; nếu chỉ phụ thuộc points.length, handler cũ có thể
  // giữ continuousMonitoring=false và bỏ qua toàn bộ batch vòng 2.
  }, [continuousMonitoring, mergeOperationalLayers, points.length]);

  return { resetMonitoringTracking };
}
