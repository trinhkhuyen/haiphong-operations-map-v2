import { useEffect, useMemo, useRef, useState } from "react";
import { FileText, MonitorUp } from "lucide-react";
import { MONITOR_LEASE_RENEW_SECONDS } from "@haiphong-ops/hnth-protocol";
import { useAppStore } from "../../core/store";
import { agentsApi, hnthApi } from "../../core/api/clients";
import { emitAppEvent, onAppEvent } from "../../core/events";
import { useHnthLiveStore, type HnthRosterPoint } from "../../core/realtime/hnth-live-store";
import { composeHnthLayer, HNTH_LAYER_ID, loadHnthDemoLayer, normalizeHnthStatus, type HnthConnectionStatus, type HnthPointOverride } from "../layers/hnth-data-provider";
import { HnthAgentSelector } from "./HnthAgentSelector";
import { HnthDeviceInfoModal } from "./HnthDeviceInfoModal";
import { HnthPointConfigForm } from "./HnthPointConfigForm";
import { HnthRosterControl } from "./HnthRosterControl";
import type { CatalogDraft } from "./HnthCatalogEditor";
import { classifyImportRows, rosterFromLayerPoints, type WardRef } from "./hnth-roster";
import { HnthPointList } from "./HnthPointList";
import { HnthStatusStyleEditor } from "./HnthStatusStyleEditor";
import { exportHnthPointsXlsx, readHnthImportFile, type HnthImportRow } from "./hnth-import-export";
import type { DiscoveredIp, HnthAgentRecord, HnthLiveAgent, HnthPointFeature } from "./hnth-types";
import { useHnthLiveSync } from "./useHnthLiveSync";


// Mức zoom cố định khi chọn một điểm trong danh sách menu HNTH.
// Tăng/giảm giá trị này nếu muốn điểm được hiển thị gần/xa hơn.
const HNTH_MENU_POINT_ZOOM = 10.5;

export function HnthPanel({ readOnly = false, canRenewLease = !readOnly }: { readOnly?: boolean; canRenewLease?: boolean }) {
  const hnthTransparentPopups = useAppStore((state) => state.hnthTransparentPopups);
  const setHnthTransparentPopups = useAppStore((state) => state.setHnthTransparentPopups);
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
  const [ipAddress, setIpAddress] = useState("");
  const [gateway, setGateway] = useState("192.168.1.1");
  const [model, setModel] = useState("");
  const [discoveredIps, setDiscoveredIps] = useState<DiscoveredIp[]>([]);
  const [isScanning, setIsScanning] = useState(false);
  const [scanSubnets, setScanSubnets] = useState("192.168.1.0/24");
  const HNTH_AGENT_ID = "agent-demo";
  const [agents, setAgents] = useState<HnthAgentRecord[]>([]);
  // Agent được chọn lưu ở backend (monitor_state.agent_id) và đến cùng snapshot
  // realtime, nên Guest/Trình chiếu và các Operator khác luôn thấy cùng một agent.
  const [selectedAgentId, setSelectedAgentId] = useState(HNTH_AGENT_ID);
  // Danh sách + trạng thái online lấy từ snapshot công khai; /api/agents (có
  // monitorConfig) chỉ tải được khi đã đăng nhập Operator/Admin.
  const [liveAgents, setLiveAgents] = useState<HnthLiveAgent[]>([]);
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
        const nextAgents = await response.json() as HnthAgentRecord[];
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
    resetMonitoringTracking();
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
  useEffect(() => {
    if (!isDataLayerVisible || points.length) return;
    let cancelled = false;
    // Bảo đảm menu HNTH có thể tự nạp dữ liệu ngay cả khi chu kỳ khởi tạo
    // bản đồ và chu kỳ khôi phục các lớp đã lưu diễn ra đồng thời.
    void loadHnthDemoLayer().then((loadedLayer) => {
      if (!cancelled) {
        mergeOperationalLayers([composeHnthLayer(loadedLayer, hnthPointOverrides, useHnthLiveStore.getState().catalog, useHnthLiveStore.getState().activeRoster)]);
        emitAppEvent("hnth:layer-ready");
      }
    }).catch(() => undefined);
    return () => { cancelled = true; };
  }, [isDataLayerVisible, points.length, mergeOperationalLayers, hnthPointOverrides]);

  // Đổi/sửa danh sách phiên họp (từ máy này hoặc máy khác qua realtime): dựng lại lớp HNTH
  // theo danh sách mới rồi phát layer-ready để trạng thái mới nhất từ backend được áp lại.
  const catalog = useHnthLiveStore((state) => state.catalog);
  const activeRoster = useHnthLiveStore((state) => state.activeRoster);
  const appliedSessionRef = useRef<{ catalog: typeof catalog; roster: typeof activeRoster } | null>(null);
  useEffect(() => {
    const previous = appliedSessionRef.current;
    appliedSessionRef.current = { catalog, roster: activeRoster };
    // Lần đầu chưa có dữ liệu chủ thì lớp mặc định đã đúng, không cần dựng lại.
    if (!previous && !catalog) return;
    if (previous && previous.catalog === catalog && previous.roster === activeRoster) return;
    let cancelled = false;
    void loadHnthDemoLayer().then((baseLayer) => {
      if (cancelled) return;
      mergeOperationalLayers([composeHnthLayer(baseLayer, useAppStore.getState().hnthPointOverrides, catalog, activeRoster)]);
      emitAppEvent("hnth:layer-ready");
    }).catch(() => undefined);
    return () => { cancelled = true; };
  }, [catalog, activeRoster, mergeOperationalLayers]);

  // Ctrl+Enter: bật/tắt Giám sát liên tục giống gạt switch. Chỉ trang có quyền điều khiển
  // (không readOnly: Guest/Viewer/Trình chiếu không có). Ref giữ hàm mới nhất vì setMonitoring
  // đọc danh sách điểm/agent hiện tại.
  const toggleMonitoringRef = useRef<() => void>(() => undefined);
  toggleMonitoringRef.current = () => {
    const enabled = !continuousMonitoring;
    if (enabled) resetHnthStatusesForNewMonitoring();
    void setMonitoring(enabled).catch(() => undefined);
  };
  useEffect(() => {
    if (readOnly) return;
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key !== "Enter" || !event.ctrlKey || event.repeat) return;
      event.preventDefault();
      toggleMonitoringRef.current();
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [readOnly]);

  // Chỉ Operator/Admin bật/tắt được giám sát; trang của họ còn mở thì giữ lease.
  // Điều kiện theo vai trò tài khoản, không theo readOnly. Guest/Viewer không gia hạn.
  // Gia hạn ngay khi bật và khi tab hiện lại (trình duyệt có thể hãm timer của tab ẩn).
  useEffect(() => {
    if (!continuousMonitoring || !canRenewLease) return;
    const renew = () => void hnthApi.renewMonitorLease().catch(() => undefined);
    renew();
    const timer = window.setInterval(renew, MONITOR_LEASE_RENEW_SECONDS * 1000);
    const onVisible = () => { if (document.visibilityState === "visible") renew(); };
    document.addEventListener("visibilitychange", onVisible);
    return () => { window.clearInterval(timer); document.removeEventListener("visibilitychange", onVisible); };
  }, [continuousMonitoring, canRenewLease]);

  const { resetMonitoringTracking } = useHnthLiveSync({ points, layer, continuousMonitoring, selectedAgentId, setSelectedAgentId, setLiveAgents, setContinuousMonitoring, setPingConcurrency, setMonitorWaitSeconds });
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
      // Module báo cáo (vẽ canvas + dựng PDF) chỉ tải khi bấm Báo cáo.
      const { exportHnthReportPdf } = await import("./hnth-report");
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

  const exportPointConfig = () => void exportHnthPointsXlsx(points);

  // Import = đọc file thành dữ liệu chủ điểm cầu (xã/phường, Trung tâm, Sở/Ban/Ngành) rồi mở
  // popup để xem lại và lưu; các danh sách phiên họp chọn điểm từ dữ liệu chủ này.
  const [catalogDraft, setCatalogDraft] = useState<CatalogDraft | null>(null);
  const [wardRefs, setWardRefs] = useState<WardRef[]>([]);
  useEffect(() => {
    void loadHnthDemoLayer().then((baseLayer) => setWardRefs(baseLayer.data.features
      .filter((item) => item.geometry.type === "Point" && item.properties?.role === "branch")
      .map((item) => ({ pointId: String(item.properties?.pointId ?? ""), name: String(item.properties?.name ?? "") })))).catch(() => undefined);
  }, []);
  // Chưa từng Import: 115 điểm đang hiển thị (IP lấy từ backend) làm dữ liệu chủ ban đầu, Trung tâm đứng đầu.
  const hasCatalog = useHnthLiveStore((state) => Boolean(state.catalog?.points.length));
  const fallbackCatalog = useMemo(() => hasCatalog ? [] : rosterFromLayerPoints(points).sort((a, b) => Number(b.kind === "hub") - Number(a.kind === "hub")), [hasCatalog, points]);

  const importPointConfig = async (file: File) => {
    try {
      const imported: HnthImportRow[] = await readHnthImportFile(file);
      const { points: rosterPoints, report } = classifyImportRows(imported, wardRefs);
      if (!rosterPoints.length) throw new Error("File không có dòng Tên điểm nào.");
      setCatalogDraft({ points: rosterPoints, report });
    } catch (error) {
      window.alert(error instanceof Error ? error.message : "Không thể nhập file cấu hình HNTH.");
    }
  };

  // Sau khi áp dụng/sửa danh sách đang dùng: tải lại phân công Agent và bắt đầu lại giám sát theo điểm mới.
  const restartMonitoringForRoster = async (rosterPoints: HnthRosterPoint[] | null) => {
    const response = await agentsApi.list().catch(() => null);
    if (response?.ok) setAgents(await response.json() as HnthAgentRecord[]);
    const monitorPoints = rosterPoints
      ? rosterPoints.filter((point) => point.ipAddress).map((point) => ({ pointId: point.pointId, ipAddress: point.ipAddress, name: point.name, modelVendor: point.modelVendor }))
      : rosterFromLayerPoints(composeHnthLayer(await loadHnthDemoLayer(), useAppStore.getState().hnthPointOverrides, null, null).data.features
        .filter((item): item is HnthPointFeature => item.geometry.type === "Point")).filter((point) => point.ipAddress)
        .map((point) => ({ pointId: point.pointId, ipAddress: point.ipAddress, name: point.name, modelVendor: point.modelVendor }));
    resetHnthStatusesForNewMonitoring();
    await hnthApi.setMonitoring({ enabled: true, concurrency: pingConcurrency, waitSeconds: monitorWaitSeconds, agentId: selectedAgentId, points: monitorPoints });
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

      {selected && <HnthPointConfigForm
        point={selected}
        status={selectedStatus}
        readOnly={readOnly}
        discoveredIps={discoveredIps}
        assignedIps={assignedIps}
        ipAddress={{ value: ipAddress, onChange: setIpAddress }}
        gateway={{ value: gateway, onChange: setGateway }}
        model={{ value: model, onChange: setModel }}
        onSave={(status) => void saveConfig(status)}
        onTest={() => { if (selectedPointId) emitAppEvent("hnth:test-point", { pointId: selectedPointId, ipAddress: ipAddress.trim(), runId: Date.now() }); }}
        onShowInfo={() => setModal("info")}
        onImport={importPointConfig}
        onExport={exportPointConfig}
        rosterSlot={<HnthRosterControl readOnly={readOnly} wards={wardRefs} fallbackCatalog={fallbackCatalog} catalogDraft={catalogDraft} setCatalogDraft={setCatalogDraft} onApplied={restartMonitoringForRoster} />}
      />}

      <HnthAgentSelector
        liveAgents={liveAgents}
        selectedAgentId={selectedAgentId}
        readOnly={readOnly}
        switchingAgent={switchingAgent}
        continuousMonitoring={continuousMonitoring}
        onChooseAgent={(agentId) => void chooseAgent(agentId)}
        scanSubnets={scanSubnets}
        onScanSubnetsChange={setScanSubnets}
        isScanning={isScanning}
        onScan={() => void requestNetworkScan()}
        error={agentSelectError}
      />

      <HnthPointList points={points} selectedPointId={selectedPointId} onSelect={selectPoint} />

      <div className="hnth-bottom-controls">
        {continuousMonitoring && <label className="hnth-concurrency-slider"><span>Luồng ping đồng thời: <b>{pingConcurrency}</b></span><input type="range" min="1" max="30" value={pingConcurrency} onChange={(event) => { const value = Number(event.target.value); setPingConcurrency(value); void setMonitoring(true, value); }} /></label>}
        {continuousMonitoring && <label className="hnth-concurrency-slider"><span>Chờ sau mỗi vòng: <b>{monitorWaitSeconds}s</b></span><input type="range" min="1" max="10" value={monitorWaitSeconds} onChange={(event) => { const value = Number(event.target.value); setMonitorWaitSeconds(value); void setMonitoring(true, pingConcurrency, value); }} /></label>}

        <label className="outside-mask-toggle hnth-layer-toggle">
          <span><strong>Hiển thị sơ đồ kết nối</strong><small>Vàng: chưa kết nối · xanh: kết nối · đỏ: mất kết nối</small></span>
          <input type="checkbox" checked={hnthLineVisible} onChange={(event) => setHnthLineVisible(event.target.checked)} /><i />
        </label>
        <HnthStatusStyleEditor title="Màu đường kết nối" styles={hnthLineStyles} onChange={setHnthLineStyle} signalStatuses />
        <label className="outside-mask-toggle hnth-layer-toggle hnth-area-toggle">
          <span><strong>Màu nền xã/phường</strong><small>Tô địa giới theo trạng thái điểm HNTH</small></span>
          <input type="checkbox" checked={hnthAreaVisible} onChange={(event) => setHnthAreaVisible(event.target.checked)} /><i />
        </label>
        {hnthAreaVisible && <HnthStatusStyleEditor title="Màu nền địa giới" styles={hnthAreaStyles} onChange={setHnthAreaStyle} icon="map" />}
        <label className="outside-mask-toggle hnth-layer-toggle">
          <span><strong>Popup trong suốt</strong><small>Log và Chi tiết hiển thị thẳng trên bản đồ (phím 8)</small></span>
          <input type="checkbox" checked={hnthTransparentPopups} onChange={(event) => setHnthTransparentPopups(event.target.checked)} /><i />
        </label>

      </div>

      {modal && selected && <HnthDeviceInfoModal name={String(selected.properties?.name)} ipAddress={ipAddress} gateway={gateway} onClose={() => setModal(null)} />}
    </section>
  );
}
