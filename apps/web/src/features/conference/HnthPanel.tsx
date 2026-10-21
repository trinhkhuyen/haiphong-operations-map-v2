import { useEffect, useMemo, useRef, useState } from "react";
import { Cable, CircleOff, Download, FileText, Info, Map, MonitorUp, Network, RadioTower, Save, Search, Upload, X, Zap } from "lucide-react";
import { toConnectionStatus } from "@haiphong-ops/hnth-protocol";
import { useAppStore } from "../../core/store";
import { agentsApi, hnthApi } from "../../core/api/clients";
import { emitAppEvent, onAppEvent } from "../../core/events";
import { refreshHnthSnapshot, subscribeHnthSnapshots, subscribeHnthStream, type HnthLivePayload } from "../../core/realtime/hnth-realtime";
import { useHnthLiveStore } from "../../core/realtime/hnth-live-store";
import { applyHnthPointOverrides, HNTH_LAYER_ID, HNTH_STATUS_LABELS, loadHnthDemoLayer, normalizeHnthStatus, type HnthConnectionStatus, type HnthPointOverride, type HnthStatusStyles } from "../layers/hnth-data-provider";
import { HnthDisconnectConfirmButton } from "./HnthDisconnectConfirmButton";
import { exportHnthPointsXlsx, readHnthImportFile, type HnthImportRow } from "./hnth-import-export";
import { exportHnthReportPdf } from "./hnth-report";
import type { HnthAssignedPoint, HnthPointFeature } from "./hnth-types";

const deviceCards = [
  { image: "/assets/hnth/vcs-terminal.svg", title: "Thiết bị đầu cuối VCS", model: "Cisco Webex Room Kit", detail: "SIP/H.323 · 4K UHD · Camera PTZ" },
  { image: "/assets/hnth/mixer.svg", title: "Bộ trộn âm thanh", model: "Yamaha MG10XU", detail: "10 kênh · USB Audio · DSP FX" },
  { image: "/assets/hnth/microphone.svg", title: "Hệ thống micro", model: "Shure MX418", detail: "Micro cổ ngỗng · Cardioid" },
  { image: "/assets/hnth/speaker.svg", title: "Hệ thống loa", model: "JBL Control 25-1", detail: "2 loa toàn dải · 200 W" },
];

const statusOrder: HnthConnectionStatus[] = ["unconnected", "connected", "lost"];

// Mức zoom cố định khi chọn một điểm trong danh sách menu HNTH.
// Tăng/giảm giá trị này nếu muốn điểm được hiển thị gần/xa hơn.
const HNTH_MENU_POINT_ZOOM = 10.5;

export function HnthPanel({ readOnly = false }: { readOnly?: boolean }) {
  const layer = useAppStore((state) => state.layers.find((item) => item.id === HNTH_LAYER_ID));
  const isDataLayerVisible = useAppStore((state) => Boolean(state.layerVisibility[HNTH_LAYER_ID]));
  const toggleLayer = useAppStore((state) => state.toggleLayer);
  const mergeOperationalLayers = useAppStore((state) => state.mergeOperationalLayers);
  const hnthPointOverrides = useAppStore((state) => state.hnthPointOverrides);
  const selectedId = useAppStore((state) => state.selectedHnthPointId);
  const setSelectedId = useAppStore((state) => state.setSelectedHnthPointId);
  const updateHnthPoint = useAppStore((state) => state.updateHnthPoint);
  const updateHnthPoints = useAppStore((state) => state.updateHnthPoints);
  const hnthLineVisible = useAppStore((state) => state.hnthLineVisible);
  const hnthLineStyles = useAppStore((state) => state.hnthLineStyles);
  const hnthAreaStyles = useAppStore((state) => state.hnthAreaStyles);
  const hnthAreaVisible = useAppStore((state) => state.hnthAreaVisible);
  const administrativeUnits = useAppStore((state) => state.administrativeUnits);
  const setHnthLineStyle = useAppStore((state) => state.setHnthLineStyle);
  const setHnthLineVisible = useAppStore((state) => state.setHnthLineVisible);
  const setHnthAreaStyle = useAppStore((state) => state.setHnthAreaStyle);
  const setHnthAreaVisible = useAppStore((state) => state.setHnthAreaVisible);
  const [query, setQuery] = useState("");
  const [ipAddress, setIpAddress] = useState("");
  const [gateway, setGateway] = useState("192.168.1.1");
  const [model, setModel] = useState("");
  const [discoveredIps, setDiscoveredIps] = useState<Array<{ ipAddress: string; model?: string; vendor?: string; modelVendor?: string; macAddress?: string }>>([]);
  const [isScanning, setIsScanning] = useState(false);
  const [scanSubnets, setScanSubnets] = useState("192.168.1.0/24");
  const HNTH_AGENT_ID = "agent-demo";
  const [agents, setAgents] = useState<Array<{ agentId: string; name: string; status: string; heartbeatSeconds?: number; monitorConfig?: { points?: HnthAssignedPoint[]; [key: string]: unknown } }>>([]);
  // Agent được chọn lưu ở backend (monitor_state.agent_id) và đến cùng snapshot
  // realtime, nên Guest/Trình chiếu và các Operator khác luôn thấy cùng một agent.
  const [selectedAgentId, setSelectedAgentId] = useState(HNTH_AGENT_ID);
  // Danh sách + trạng thái online lấy từ snapshot công khai; /api/agents (có
  // monitorConfig) chỉ tải được khi đã đăng nhập Operator/Admin.
  const [liveAgents, setLiveAgents] = useState<Array<{ agentId: string; name: string; status: string; version?: string }>>([]);
  const [agentSelectError, setAgentSelectError] = useState("");
  const [continuousMonitoring, setContinuousMonitoring] = useState(false);
  const [monitoringError, setMonitoringError] = useState("");
  const [pingConcurrency, setPingConcurrency] = useState(() => {
    const saved = Number(window.localStorage.getItem("hnth-monitor-concurrency"));
    return Number.isInteger(saved) && saved >= 1 && saved <= 30 ? saved : 1;
  });
  const [monitorWaitSeconds, setMonitorWaitSeconds] = useState(3);
  const [modal, setModal] = useState<"info" | null>(null);
  const [isReporting, setIsReporting] = useState(false);
  const importInputRef = useRef<HTMLInputElement>(null);
  const presentationWindowRef = useRef<Window | null>(null);

  const openPresentationWindow = () => {
    const presentationUrl = new URL(window.location.href);
    presentationUrl.searchParams.set("presentation", "1");
    presentationUrl.searchParams.set("panel", "conference");
    const presentationWindow = window.open(presentationUrl.toString(), "hnth-presentation", "popup=yes,width=1600,height=900,resizable=yes,scrollbars=no");
    if (!presentationWindow) {
      setMonitoringError("Trình duyệt đã chặn cửa sổ Trình chiếu. Hãy cho phép popup cho trang này rồi bấm lại.");
      return;
    }
    presentationWindowRef.current = presentationWindow;
    presentationWindow.focus();
  };

  useEffect(() => {
    const loadAgents = async () => {
      try {
        const response = await agentsApi.list();
        if (!response.ok) return;
        const nextAgents = await response.json() as Array<{ agentId: string; name: string; status: string; heartbeatSeconds?: number; monitorConfig?: { points?: HnthAssignedPoint[]; [key: string]: unknown } }>;
        setAgents(nextAgents);
      } catch { /* backend chưa sẵn sàng */ }
    };
    void loadAgents();
  }, []);

  const refreshDiscoveredIps = async () => {
    try {
      const response = await hnthApi.discoveredIps(selectedAgentId || undefined);
      if (!response.ok) return;
      const payload = await response.json() as { ips?: Array<{ ipAddress?: string; model?: string; vendor?: string; modelVendor?: string; macAddress?: string }> };
      setDiscoveredIps((payload.ips ?? [])
        .filter((item): item is { ipAddress: string; model?: string; vendor?: string; modelVendor?: string; macAddress?: string } => Boolean(item.ipAddress))
        .map((item) => ({ ...item, model: item.model || item.vendor || item.modelVendor || "" })));
    } catch { /* relay chưa cấu hình, giữ danh sách hiện tại */ }
  };

  const [switchingAgent, setSwitchingAgent] = useState(false);
  const chooseAgent = async (agentId: string) => {
    const previous = selectedAgentId;
    if (agentId === previous) return;
    const nextName = liveAgents.find((agent) => agent.agentId === agentId)?.name || agentId;
    const previousName = liveAgents.find((agent) => agent.agentId === previous)?.name || previous;
    // Đang giám sát: dừng hẳn trên agent cũ rồi mới bật lại trên agent mới, để
    // không có hai agent cùng ping và trộn trạng thái trên bản đồ.
    const restartMonitoring = continuousMonitoring;
    if (restartMonitoring && !window.confirm(`Đang Giám sát liên tục bằng "${previousName}".\nChuyển sang "${nextName}" sẽ dừng giám sát trên agent cũ và bắt đầu lại trên agent mới. Tiếp tục?`)) return;
    setAgentSelectError("");
    setSwitchingAgent(true);
    setSelectedAgentId(agentId);
    try {
      if (restartMonitoring) await setMonitoring(false, pingConcurrency, monitorWaitSeconds, previous);
      const response = await hnthApi.selectAgent(agentId);
      if (!response.ok) {
        const payload = await response.json().catch(() => ({})) as { error?: string };
        throw new Error(payload.error || `Không lưu được Agent đã chọn (HTTP ${response.status})`);
      }
      if (restartMonitoring) {
        resetHnthStatusesForNewMonitoring();
        await setMonitoring(true, pingConcurrency, monitorWaitSeconds, agentId);
      }
    } catch (error) {
      setSelectedAgentId(previous);
      setAgentSelectError(error instanceof Error ? error.message : "Không lưu được Agent đã chọn");
    } finally {
      setSwitchingAgent(false);
    }
  };

  const requestNetworkScan = async () => {
    setIsScanning(true);
    try {
      const subnets = scanSubnets.split(",").map((item) => item.trim()).filter(Boolean);
      const response = await hnthApi.scan({ scanSubnets: subnets, agentId: selectedAgentId || undefined });
      if (!response.ok) throw new Error(`Scan request failed: ${response.status}`);
      for (const delay of [3000, 7000, 15000, 30000]) window.setTimeout(() => void refreshDiscoveredIps(), delay);
    } catch {
      await refreshDiscoveredIps();
    } finally {
      window.setTimeout(() => setIsScanning(false), 5000);
    }
  };

  const setMonitoring = async (enabled: boolean, concurrency = pingConcurrency, waitSeconds = monitorWaitSeconds, agentId = selectedAgentId) => {
    setMonitoringError("");
    setContinuousMonitoring(enabled);
    const assignedPoints = agents.find((agent) => agent.agentId === agentId)?.monitorConfig?.points;
    const hasAssignment = Array.isArray(assignedPoints);
    // An Agent assignment is authoritative. Never silently expand an imported
    // list (for example 50 points) back to the full demo layer.
    const monitorPoints = hasAssignment ? assignedPoints.map((item) => ({ pointId: item.pointId, ipAddress: item.ipAddress, name: item.name || item.pointId, modelVendor: item.modelVendor })) : [...new globalThis.Map(points
      .map((item) => {
        const pointId = String(item.properties?.pointId ?? item.id ?? "").trim();
        const configuredIp = String(item.properties?.ipAddress ?? "").trim();
        return { pointId, ipAddress: configuredIp, name: String(item.properties?.name ?? pointId).trim() };
      })
      .filter((item) => item.pointId)
      .map((item) => [item.pointId, item])).values()];
    const response = await hnthApi.setMonitoring({ enabled, concurrency, waitSeconds, agentId, points: monitorPoints });
    if (!response.ok) {
      setContinuousMonitoring(!enabled);
      const message = `Backend từ chối lệnh Giám sát liên tục (${response.status}). Hãy kiểm tra đăng nhập và Backend.`;
      setMonitoringError(message);
      throw new Error(message);
    }
    if (enabled) {
      // Khi bắt đầu giám sát, đưa camera về khung tổng quan toàn TP để nhìn
      // đồng thời toàn bộ endpoint và các đường kết nối HNTH.
      emitAppEvent("map:fit-haiphong-overview");
    }
    useHnthLiveStore.getState().setMonitoring({ enabled, concurrency, waitSeconds });
  };

  const resetHnthStatusesForNewMonitoring = () => {
    monitoringFirstRoundCompleteRef.current = false;
    monitoringSeenPointIdsRef.current = new Set();
    monitoringPendingAdministrativeIdsRef.current = new Set();
    monitoringLastStatusRef.current = new globalThis.Map();
    const statusUpdates: Record<string, Partial<HnthPointOverride>> = {};
    for (const point of points) {
      const pointId = String(point.properties?.pointId ?? point.id ?? "");
      if (pointId) statusUpdates[pointId] = { status: "unknown" };
    }
    updateHnthPoints(statusUpdates);
  };

  useEffect(() => {
    window.localStorage.setItem("hnth-monitor-concurrency", String(pingConcurrency));
  }, [pingConcurrency]);

  useEffect(() => {
    void refreshDiscoveredIps();
  }, [selectedAgentId]);

  useEffect(() => {
    // Đọc trạng thái mới nhất thay vì giá trị capture lúc render. React StrictMode
    // có thể chạy effect khởi tạo hai lần; gọi toggle bằng giá trị cũ sẽ bật rồi
    // tắt lại lớp HNTH và làm cả hai switch hiển thị mất tác dụng.
    if (!useAppStore.getState().layerVisibility[HNTH_LAYER_ID]) toggleLayer(HNTH_LAYER_ID);
  }, []); // Luôn nạp dữ liệu HNTH; hai switch đường nối và màu nền điều khiển hiển thị độc lập.

  const points = useMemo(() => (layer?.data.features ?? [])
    .filter((item): item is HnthPointFeature => item.geometry.type === "Point")
    .sort((left, right) => String(left.properties?.name ?? "").localeCompare(
      String(right.properties?.name ?? ""),
      "vi",
      { sensitivity: "base", numeric: true },
  )), [layer]);
  const pointsRef = useRef(points);
  // Giữ snapshot authoritative cuối cùng trong suốt vòng đời component. Khi
  // App nạp lại/thay thế GeoJSON HNTH sau F5, snapshot có thể đã về trước đó
  // và việc merge lớp mới sẽ ghi đè trạng thái line/fill. Snapshot này được
  // replay ngay sau khi lớp HNTH mới sẵn sàng.
  const latestLivePayloadRef = useRef<unknown>(null);
  const monitoringFirstRoundCompleteRef = useRef(false);
  const monitoringSeenPointIdsRef = useRef(new Set<string>());
  const monitoringPendingAdministrativeIdsRef = useRef(new Set<number>());
  // Snapshot riêng của Agent theo từng endpoint. Không dùng layer/store làm
  // trạng thái trước đó vì applyLiveResults có thể cập nhật chúng trước khi
  // batch kế tiếp được đem ra so sánh.
  const monitoringLastStatusRef = useRef(new globalThis.Map<string, HnthConnectionStatus>());
  useEffect(() => { pointsRef.current = points; }, [points]);
  useEffect(() => {
    if (!isDataLayerVisible || points.length) return;
    let cancelled = false;
    // Bảo đảm menu HNTH có thể tự nạp dữ liệu ngay cả khi chu kỳ khởi tạo
    // bản đồ và chu kỳ khôi phục các lớp đã lưu diễn ra đồng thời.
    void loadHnthDemoLayer().then((loadedLayer) => {
      if (!cancelled) {
        mergeOperationalLayers([applyHnthPointOverrides(loadedLayer, hnthPointOverrides)]);
        emitAppEvent("hnth:layer-ready");
      }
    }).catch(() => undefined);
    return () => { cancelled = true; };
  }, [isDataLayerVisible, points.length, mergeOperationalLayers, hnthPointOverrides]);

  // Đồng bộ trạng thái từ relay server nếu agent LAN đang hoạt động.
  // Khi relay chưa được cấu hình hoặc mất kết nối, dữ liệu demo vẫn được giữ nguyên.
  useEffect(() => {
    if (!points.length) return;
    let cancelled = false;
    const handleMonitoringBatch = (
      batch: { end?: number; total?: number; results?: unknown; allResults?: unknown },
      monitoringEnabled = continuousMonitoring,
    ) => {
      // Agent gửi monitorBatch.allResults cho cả batch để frontend biết
      // endpoint nào vừa được quét; batch.results chỉ là payload rút gọn
      // của telemetry và có thể không tồn tại.
      const statusResults = Array.isArray(batch.allResults) ? batch.allResults : batch.results;
      // Khi SSE vừa chuyển trạng thái từ tắt sang bật, state React chưa kịp
      // render trong cùng callback. Dùng cờ từ chính snapshot backend để không
      // bỏ qua batch đầu tiên của chu kỳ giám sát.
      if (!monitoringEnabled || !Array.isArray(statusResults)) return;
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
      const snapshot = payload as { agents?: Array<{ agentId?: string; name?: string; status?: string; version?: string | null }>; monitoring?: { agentId?: string } };
      // Agent được chọn trong snapshot backend là nguồn sự thật (có thể vừa được
      // đổi từ client khác); trạng thái chỉ phát cho đúng agent đó.
      const activeAgentId = String(snapshot.monitoring?.agentId ?? "").trim() || selectedAgentId;
      if (snapshot.monitoring?.agentId) setSelectedAgentId(activeAgentId);
      if (Array.isArray(snapshot.agents)) {
        setLiveAgents(snapshot.agents
          .filter((item) => item.agentId)
          .map((item) => ({ agentId: String(item.agentId), name: String(item.name || item.agentId), status: String(item.status || "offline"), version: item.version ? String(item.version) : undefined })));
      }
      const monitorBatch = (payload as { monitorBatch?: { allResults?: unknown } }).monitorBatch;
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
  const filteredPoints = useMemo(() => {
    const normalized = query.trim().toLocaleLowerCase("vi");
    if (!normalized) return points;
    const normalizedIpQuery = normalized.replace(/\s+/g, "");
    return points.filter((item) => {
      const values = [item.properties?.name, item.properties?.ipAddress, item.properties?.gateway]
        .map((value) => String(value ?? "").toLocaleLowerCase("vi").trim());
      return values.some((value) => value.includes(normalized))
        // Cho phép tìm theo đoạn cuối của IP, ví dụ `.1.1` khớp `192.168.1.1`.
        || values.slice(1).some((value) => normalizedIpQuery.startsWith(".") && value.endsWith(normalizedIpQuery));
    });
  }, [points, query]);
  const selected = points.find((item) => String(item.properties?.pointId ?? item.id) === selectedId) ?? points[0];
  const selectedPointId = selected ? String(selected.properties?.pointId ?? selected.id) : null;
  const assignedIps = useMemo(() => new Set(points
    .filter((item) => String(item.properties?.pointId ?? item.id) !== selectedPointId)
    .map((item) => String(item.properties?.ipAddress ?? "").trim())
    .filter(Boolean)), [points, selectedPointId]);
  const selectedStatus = normalizeHnthStatus(selected?.properties?.status);

  const exportHnthReport = async () => {
    if (isReporting) return;
    setIsReporting(true);
    try {
      await exportHnthReportPdf(points);
    } finally {
      setIsReporting(false);
    }
  };

  useEffect(() => {
    if (!selected) return;
    setSelectedId(String(selected.properties?.pointId ?? selected.id));
    setIpAddress(String(selected.properties?.ipAddress ?? ""));
    setGateway(String(selected.properties?.gateway ?? "192.168.1.1"));
    setModel(String(selected.properties?.model ?? ""));
  }, [selectedPointId, selected, setSelectedId]);

  useEffect(() => {
    return onAppEvent("map:context-info", (detail) => {
      if (detail?.kind !== "hnth" || !detail.pointId) return;
      if (points.some((item) => String(item.properties?.pointId ?? item.id) === detail.pointId)) {
        setSelectedId(detail.pointId);
      }
    });
  }, [points, setSelectedId]);

  useEffect(() => {
    if (!modal) return;
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") setModal(null);
    };
    window.addEventListener("keydown", closeOnEscape);
    return () => window.removeEventListener("keydown", closeOnEscape);
  }, [modal]);

  const selectPoint = (item: HnthPointFeature) => {
    const id = String(item.properties?.pointId ?? item.id);
    const pointName = String(item.properties?.name ?? "");
    const wardCode = String(item.properties?.wardCode ?? "");
    const administrativeId = administrativeUnits.find((unit) => String(unit.wardCode ?? "") === wardCode)?.id;
    setSelectedId(id);
    setIpAddress(String(item.properties?.ipAddress ?? ""));
    setGateway(String(item.properties?.gateway ?? "192.168.1.1"));
    setModel(String(item.properties?.model ?? ""));
    emitAppEvent("hnth:focus", {
      coordinates: item.geometry.coordinates as [number, number],
      // Dùng mức tuyệt đối để kết quả không phụ thuộc khung hình trước đó.
      // Riêng Bạch Long Vĩ chỉ đổi tâm và giữ nguyên tỷ lệ bản đồ hiện tại.
      targetZoom: HNTH_MENU_POINT_ZOOM,
      preserveZoom: pointName.toLocaleLowerCase("vi").includes("bạch long vĩ"),
      // Điểm nhánh được khoanh bằng viền trắng dày gấp đôi nét mảnh cơ sở.
      administrativeId,
      boundaryWidthMultiplier: 2,
    });
    // Mở Popup Thông tin Endpoint cố định tương ứng với điểm vừa chọn.
    // Viền x2 đã được thiết lập bởi sự kiện hnth:focus ở trên.
    emitAppEvent("map:context-info", { kind: "hnth", pointId: id, administrativeId });
  };

  const saveConfig = async (status: HnthConnectionStatus = selectedStatus) => {
    if (!selectedPointId) return;
    const nextIp = ipAddress.trim();
    if (nextIp && assignedIps.has(nextIp)) {
      window.alert(`IP ${nextIp} đã được gán cho một điểm khác.`);
      return;
    }
    // An endpoint without an IP must never retain the previous connection
    // state. Clear it immediately in the local store so the status bar,
    // connection line and fill all switch to "unknown" before the backend
    // response/next monitoring cycle arrives.
    const nextStatus: HnthConnectionStatus = nextIp ? status : "unknown";
    updateHnthPoint(selectedPointId, { ipAddress: nextIp, gateway: gateway.trim(), model: model.trim(), status: nextStatus });
    try {
      await hnthApi.pointConfig({ pointId: selectedPointId, ipAddress: nextIp, modelVendor: model.trim() || undefined });
      if (continuousMonitoring) {
        const assignedPoints = agents.find((agent) => agent.agentId === selectedAgentId)?.monitorConfig?.points;
        const monitorPoints = Array.isArray(assignedPoints)
          ? assignedPoints.map((item) => ({ ...item, ipAddress: item.pointId === selectedPointId ? nextIp : item.ipAddress }))
          : points.map((item) => ({
            pointId: String(item.properties?.pointId ?? item.id),
            ipAddress: String(item.properties?.pointId === selectedPointId ? nextIp : item.properties?.ipAddress ?? ""),
          }));
        await hnthApi.setMonitoring({ enabled: true, concurrency: pingConcurrency, waitSeconds: monitorWaitSeconds, agentId: selectedAgentId, points: monitorPoints });
      }
    } catch { /* relay/agent offline; cấu hình local vẫn được lưu */ }
  };

  const exportPointConfig = () => exportHnthPointsXlsx(points);

  const importPointConfig = async (file: File) => {
    try {
      const imported: HnthImportRow[] = await readHnthImportFile(file);
      const byName = new globalThis.Map(imported.map((row) => [row.name.trim().toLocaleLowerCase("vi"), row]));
      const currentPoints = points;
      const updates = currentPoints.map((point) => {
        const pointId = String(point.properties?.pointId ?? point.id ?? "");
        const name = String(point.properties?.name ?? "").trim();
        const row = byName.get(name.toLocaleLowerCase("vi"));
        return row && pointId ? { pointId, row } : null;
      }).filter((item): item is { pointId: string; row: HnthImportRow } => Boolean(item));
      if (!updates.length) throw new Error("Không tìm thấy Tên điểm nào khớp với danh sách hiện tại.");
      for (const { pointId, row } of updates) {
        const values = { ipAddress: row.ipAddress, gateway: row.gateway, model: row.modelVendor };
        updateHnthPoint(pointId, { ...values, status: "unknown" });
        await hnthApi.pointConfig({ pointId, ipAddress: row.ipAddress, modelVendor: row.modelVendor || undefined, agentId: selectedAgentId });
      }
      const selectedAgent = agents.find((agent) => agent.agentId === selectedAgentId);
      const assignedPoints: HnthAssignedPoint[] = updates
        .filter(({ row }) => row.ipAddress)
        .map(({ pointId, row }) => ({ pointId, name: row.name, ipAddress: row.ipAddress, modelVendor: row.modelVendor }));
      if (selectedAgent && !readOnly) {
        const existingConfig = selectedAgent.monitorConfig || {};
        const saved = await agentsApi.update(selectedAgentId, { name: selectedAgent.name, heartbeatSeconds: selectedAgent.heartbeatSeconds || 30, monitorConfig: { ...existingConfig, points: assignedPoints } });
        if (!saved.ok) throw new Error(`Không lưu được danh sách điểm cho Agent (${saved.status}).`);
        setAgents((current) => current.map((agent) => agent.agentId === selectedAgentId ? { ...agent, monitorConfig: { ...existingConfig, points: assignedPoints } } : agent));
      }
      if (continuousMonitoring) {
        const monitorPoints = assignedPoints.map((item) => ({ pointId: item.pointId, ipAddress: item.ipAddress, name: item.name, modelVendor: item.modelVendor }));
        await hnthApi.setMonitoring({ enabled: true, concurrency: pingConcurrency, waitSeconds: monitorWaitSeconds, agentId: selectedAgentId, points: monitorPoints });
      }
      window.alert(`Đã nhập và cập nhật ${updates.length}/${imported.length} điểm HNTH.`);
    } catch (error) {
      window.alert(error instanceof Error ? error.message : "Không thể nhập file cấu hình HNTH.");
    } finally {
      if (importInputRef.current) importInputRef.current.value = "";
    }
  };

  return (
    <section className="panel-section hnth-panel">
      <div className="section-heading hnth-section-heading">
        <div>
          <span className="eyebrow">HẠ TẦNG TRUYỀN DẪN</span>
          <h2>Hội nghị truyền hình</h2>
          <span className="count-chip">{Math.max(0, points.length - 1)} điểm nhánh</span>
        </div>
      </div>

      <label className="outside-mask-toggle hnth-layer-toggle">
        <span><strong>Giám sát liên tục</strong><small>Agent ping {Array.isArray(agents.find((agent) => agent.agentId === selectedAgentId)?.monitorConfig?.points) ? agents.find((agent) => agent.agentId === selectedAgentId)?.monitorConfig?.points?.length ?? 0 : points.length} điểm theo chu kỳ 30 giây</small></span>
        <input type="checkbox" checked={continuousMonitoring} onChange={(event) => { const enabled = event.target.checked; if (enabled) resetHnthStatusesForNewMonitoring(); void setMonitoring(enabled).catch(() => undefined); }} /><i />
      </label>
      <div className="hnth-action-row" style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8, margin: "-3px 0 10px" }}>
        <button className="hnth-report-button" style={{ margin: 0 }} type="button" onClick={() => void exportHnthReport()} disabled={isReporting}>
          <FileText size={14}/> {isReporting ? "Đang tạo báo cáo..." : "Báo cáo"}
        </button>
        <button className="hnth-report-button hnth-presentation-button" style={{ margin: 0 }} type="button" onClick={openPresentationWindow}>
          <MonitorUp size={14}/> Trình chiếu
        </button>
      </div>
      {monitoringError && <div className="hnth-monitor-error" role="alert">{monitoringError}</div>}

      {selected && <div className="hnth-config-card">
        <div className="hnth-config-head"><span><Network size={15}/><b>Cấu hình điểm</b></span><i className={selectedStatus}>{HNTH_STATUS_LABELS[selectedStatus]}</i></div>
        <strong>{String(selected.properties?.name ?? "Điểm HNTH")}</strong>
        <label><span>Địa chỉ IP</span>
          <div className="hnth-ip-fields">
            <select disabled={readOnly} value={discoveredIps.some((item) => item.ipAddress === ipAddress) ? ipAddress : ""} onChange={(event) => {
              const value = event.target.value;
              const found = discoveredIps.find((item) => item.ipAddress === value);
              setIpAddress(value);
              if (found?.model || found?.vendor) setModel(found.model || found.vendor || "");
            }}>
              <option value="">Chọn IP đã quét...</option>
              {discoveredIps.map((item) => <option value={item.ipAddress} key={item.ipAddress} disabled={assignedIps.has(item.ipAddress) && item.ipAddress !== ipAddress}>{item.ipAddress}{assignedIps.has(item.ipAddress) ? " — Đã gán" : ""}{item.model || item.vendor || item.modelVendor ? ` — ${item.model || item.vendor || item.modelVendor}` : item.macAddress ? ` — Vendor chưa xác định · MAC ${item.macAddress}` : " — Vendor chưa xác định"}</option>)}
            </select>
            <input disabled={readOnly} className="hnth-manual-ip" value={ipAddress} onChange={(event) => setIpAddress(event.target.value)} placeholder="Hoặc nhập IP thủ công" />
            {discoveredIps.length > 0 ? <small className="hnth-live-hint">Đã nhận {discoveredIps.length} IP từ LAN agent</small> : <small className="hnth-live-hint">Chưa có IP từ agent — hãy Scan mạng LAN</small>}
          </div>
        </label>
        <label><span>Gateway</span><input disabled={readOnly} value={gateway} onChange={(event) => setGateway(event.target.value)} /></label>
        <label><span>Model/Vendor</span><input disabled={readOnly} value={model} onChange={(event) => setModel(event.target.value)} placeholder="Ví dụ: Cisco / Webex Room Kit" /></label>
        <button className="hnth-save" disabled={readOnly} onClick={() => saveConfig()}><Save size={14}/> Lưu cấu hình IP</button>
        <div className="hnth-actions">
          <button className="connect" disabled={readOnly} onClick={() => saveConfig("connected")}><Cable size={14}/> Kết nối</button>
          <HnthDisconnectConfirmButton disabled={readOnly} pointName={String(selected.properties?.name ?? "Điểm HNTH")} onConfirm={() => { if (!readOnly) saveConfig("unconnected"); }} />
          <button disabled={readOnly} onClick={() => { if (!selectedPointId || readOnly) return; emitAppEvent("hnth:test-point", { pointId: selectedPointId, ipAddress: ipAddress.trim(), runId: Date.now() }); }}><Zap size={14}/> Test</button>
          <button disabled={readOnly} onClick={() => setModal("info")}><Info size={14}/> Thông tin</button>
        </div>
        <div className="hnth-import-export">
          <input ref={importInputRef} type="file" accept=".csv,.xlsx,text/csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" hidden onChange={(event) => { const file = event.target.files?.[0]; if (file) void importPointConfig(file); }} />
          <button type="button" disabled={readOnly} onClick={() => importInputRef.current?.click()} title="Nhập danh sách Tên điểm, IP, Gateway, Model/Vendor"><Upload size={14}/> Import</button>
          <button type="button" disabled={readOnly} onClick={exportPointConfig} title="Xuất danh sách Tên điểm, IP, Gateway, Model/Vendor"><Download size={14}/> Export</button>
        </div>
      </div>}

      <label className="hnth-scan-subnets hnth-agent-select"><span>Agent HNTH dùng cho Scan và Giám sát</span><select value={selectedAgentId} onChange={(event) => void chooseAgent(event.target.value)} disabled={!liveAgents.length || readOnly || switchingAgent}>
          {liveAgents.length ? liveAgents.map((agent) => <option key={agent.agentId} value={agent.agentId}>{agent.status === "online" ? "● " : "○ "}{agent.name}{agent.version ? ` · v${agent.version}` : ""} — {agent.status === "online" ? "online" : "mất kết nối"}</option>) : <option value={selectedAgentId}>{selectedAgentId}</option>}
        </select>
        <small>{switchingAgent ? "Đang chuyển agent…" : readOnly ? "Đăng nhập Operator/Admin để đổi Agent." : `${selectedAgentId}${continuousMonitoring ? " · đang Giám sát liên tục; chọn agent khác sẽ chuyển giám sát sang agent đó" : ""}`}</small>
      </label>
      <div className="hnth-scan-controls">
        <label className="hnth-scan-subnets"><span>Subnet LAN</span><input value={scanSubnets} onChange={(event) => setScanSubnets(event.target.value)} placeholder="192.168.1.0/24" /></label>
        <button className="hnth-save" type="button" onClick={() => void requestNetworkScan()} disabled={readOnly || isScanning} title="Gửi lệnh cho agent quét mạng LAN"><Zap size={14}/> {isScanning ? "Đang quét..." : "Scan"}</button>
      </div>
      {agentSelectError && <p className="agent-error">{agentSelectError}</p>}

      <label className="hnth-search"><Search size={15}/><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Tìm tên điểm, IP, Gateway..."/></label>
      <div className="hnth-point-list">
        {!points.length && <div className="hnth-loading"><RadioTower size={20}/><span>Đang tải danh sách điểm HNTH...</span></div>}
        {filteredPoints.map((item) => {
          const id = String(item.properties?.pointId ?? item.id);
          const status = normalizeHnthStatus(item.properties?.status);
          return <button key={id} className={id === selectedPointId ? "active" : ""} onClick={() => selectPoint(item)}>
            <i className={status}/>
            <span><strong>{String(item.properties?.name ?? "Điểm HNTH")}</strong><small>{String(item.properties?.ipAddress ?? "Chưa cấu hình IP")}</small></span>
            <em>{item.properties?.role === "hub" ? "TRUNG TÂM" : HNTH_STATUS_LABELS[status].toLocaleUpperCase("vi")}</em>
          </button>;
        })}
      </div>

      <div className="hnth-bottom-controls">
        {continuousMonitoring && <label className="hnth-concurrency-slider"><span>Luồng ping đồng thời: <b>{pingConcurrency}</b></span><input type="range" min="1" max="30" value={pingConcurrency} onChange={(event) => { const value = Number(event.target.value); setPingConcurrency(value); void setMonitoring(true, value); }} /></label>}
        {continuousMonitoring && <label className="hnth-concurrency-slider"><span>Chờ sau mỗi vòng: <b>{monitorWaitSeconds}s</b></span><input type="range" min="1" max="10" value={monitorWaitSeconds} onChange={(event) => { const value = Number(event.target.value); setMonitorWaitSeconds(value); void setMonitoring(true, pingConcurrency, value); }} /></label>}

        <label className="outside-mask-toggle hnth-layer-toggle">
          <span><strong>Hiển thị sơ đồ kết nối</strong><small>Vàng: chưa kết nối · xanh: kết nối · đỏ: mất kết nối</small></span>
          <input type="checkbox" checked={hnthLineVisible} onChange={(event) => setHnthLineVisible(event.target.checked)} /><i />
        </label>
        <StatusStyleEditor title="Màu đường kết nối" styles={hnthLineStyles} onChange={setHnthLineStyle} />
        <label className="outside-mask-toggle hnth-layer-toggle hnth-area-toggle">
          <span><strong>Màu nền xã/phường</strong><small>Tô địa giới theo trạng thái điểm HNTH</small></span>
          <input type="checkbox" checked={hnthAreaVisible} onChange={(event) => setHnthAreaVisible(event.target.checked)} /><i />
        </label>
        {hnthAreaVisible && <StatusStyleEditor title="Màu nền địa giới" styles={hnthAreaStyles} onChange={setHnthAreaStyle} icon="map" />}

      </div>

      {modal && selected && <div className="hnth-modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) setModal(null); }}>
        <section className="hnth-modal info" role="dialog" aria-modal="true" aria-label="Thiết bị điểm nhánh">
          <header><span><Info size={17}/><strong>Thiết bị điểm nhánh</strong></span><button onClick={() => setModal(null)} aria-label="Đóng cửa sổ"><X size={18}/></button></header>
          <div className="hnth-modal-site"><RadioTower size={16}/><div><strong>{String(selected.properties?.name)}</strong><small>{ipAddress} · Gateway {gateway}</small></div></div>
          <div className="hnth-device-grid">
            {deviceCards.map((device) => <article key={device.title}><img src={device.image} alt={`Ảnh minh họa ${device.title}`}/><div><span>{device.title}</span><strong>{device.model}</strong><small>{device.detail}</small><em><CircleOff size={10}/> Ảnh và cấu hình minh họa</em></div></article>)}
          </div>
        </section>
      </div>}
    </section>
  );
}

function StatusStyleEditor({ title, styles, onChange, icon }: {
  title: string;
  styles: HnthStatusStyles;
  onChange: (status: HnthConnectionStatus, update: Partial<HnthStatusStyles[HnthConnectionStatus]>) => void;
  icon?: "map";
}) {
  return <details className="hnth-style-editor">
    <summary>{icon === "map" ? <Map size={14}/> : <Cable size={14}/>}<span>{title}</span></summary>
    <div>
      {statusOrder.map((status) => <label key={status}>
        <input type="checkbox" checked={styles[status].visible} onChange={(event) => onChange(status, { visible: event.target.checked })}/>
        <span>{HNTH_STATUS_LABELS[status]}</span>
        <input type="color" value={styles[status].color} onChange={(event) => onChange(status, { color: event.target.value })} aria-label={`Màu ${HNTH_STATUS_LABELS[status]}`}/>
        <code>{styles[status].visible ? styles[status].color.toUpperCase() : "ẨN"}</code>
      </label>)}
    </div>
  </details>;
}
