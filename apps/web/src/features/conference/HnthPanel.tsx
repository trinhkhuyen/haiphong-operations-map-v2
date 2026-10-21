import { useEffect, useMemo, useRef, useState } from "react";
import * as XLSX from "xlsx";
import { Cable, CircleOff, Download, FileText, Info, Map, MonitorUp, Network, RadioTower, Save, Search, Upload, X, Zap } from "lucide-react";
import type { Feature, Point } from "geojson";
import { useAppStore } from "../../core/store";
import { hnthFetch } from "../../core/hnth-api";
import { applyHnthPointOverrides, HNTH_LAYER_ID, HNTH_STATUS_LABELS, loadHnthDemoLayer, normalizeHnthStatus, type HnthConnectionStatus, type HnthPointOverride, type HnthStatusStyles } from "../layers/hnth-data-provider";
import { FIT_HAIPHONG_OVERVIEW_EVENT, MAP_ADMINISTRATIVE_PULSE_EVENT, MAP_CAPTURE_BACKGROUND_EVENT, MAP_CONTEXT_INFO_EVENT } from "../map/map-events";
import { HnthDisconnectConfirmButton } from "./HnthDisconnectConfirmButton";

type HnthPointFeature = Feature<Point, Record<string, unknown>>;
type HnthAssignedPoint = { pointId: string; name?: string; ipAddress: string; modelVendor?: string };

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

type HnthImportRow = { name: string; ipAddress: string; gateway: string; modelVendor: string };

function csvEscape(value: unknown) {
  const text = String(value ?? "");
  return /[",\r\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
}

function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let value = "";
  let quoted = false;
  for (let index = 0; index < text.length; index += 1) {
    const character = text[index];
    const next = text[index + 1];
    if (character === '"') {
      if (quoted && next === '"') { value += '"'; index += 1; }
      else quoted = !quoted;
    } else if (character === "," && !quoted) {
      row.push(value); value = "";
    } else if ((character === "\n" || character === "\r") && !quoted) {
      if (character === "\r" && next === "\n") index += 1;
      row.push(value); value = "";
      if (row.some((cell) => cell.trim())) rows.push(row);
      row = [];
    } else value += character;
  }
  if (value || row.length) { row.push(value); if (row.some((cell) => cell.trim())) rows.push(row); }
  return rows;
}

function normalizeCsvHeader(value: string) {
  return value.replace(/^\uFEFF/, "").trim().toLocaleLowerCase("vi").normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[đĐ]/g, "d").replace(/[\s_/-]+/g, "");
}

function parseHnthCsv(text: string): HnthImportRow[] {
  const rows = parseCsv(text);
  if (rows.length < 2) return [];
  const headers = rows[0].map(normalizeCsvHeader);
  const findColumn = (...names: string[]) => headers.findIndex((header) => names.includes(header));
  const nameIndex = findColumn("tendiem", "name");
  const ipIndex = findColumn("ip", "địachỉip", "diachiip", "ipaddress");
  const gatewayIndex = findColumn("gateway", "congmacdinh");
  const modelIndex = findColumn("modelvendor", "model", "vendor", "modelvender");
  if (nameIndex < 0) throw new Error("CSV phải có cột Tên điểm");
  return rows.slice(1).map((row) => ({
    name: String(row[nameIndex] ?? "").trim(),
    ipAddress: String(ipIndex >= 0 ? row[ipIndex] ?? "" : "").trim(),
    gateway: String(gatewayIndex >= 0 ? row[gatewayIndex] ?? "" : "192.168.1.1").trim() || "192.168.1.1",
    modelVendor: String(modelIndex >= 0 ? row[modelIndex] ?? "" : "").trim(),
  })).filter((row) => row.name);
}

type HnthReportPoint = { name: string; ipAddress: string; status: HnthConnectionStatus };

function pdfText(value: string) {
  return value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[đĐ]/g, "d").replace(/[^\x20-\x7E]/g, "?");
}

function dataUrlBytes(dataUrl: string) {
  const encoded = dataUrl.split(",", 2)[1] ?? "";
  const binary = atob(encoded);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
  return bytes;
}

async function captureMapBackground(staticOnly = false): Promise<HTMLImageElement | null> {
  // Chỉ yêu cầu MapCanvas chụp một frame khi xuất báo cáo; không giữ
  // preserveDrawingBuffer trong suốt thời gian người dùng thao tác bản đồ.
  const composedDataUrl = await new Promise<string | null>((resolve) => {
    window.dispatchEvent(new CustomEvent(MAP_CAPTURE_BACKGROUND_EVENT, { detail: { resolve, staticOnly } }));
    window.setTimeout(() => resolve(null), 2000);
  });
  if (!composedDataUrl) return null;
  const result = new Image();
  result.src = composedDataUrl;
  await new Promise<void>((resolve) => { result.onload = () => resolve(); result.onerror = () => resolve(); });
  return result.naturalWidth ? result : null;
}

function pdfBytes(chunks: Uint8Array[]) {
  const total = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
  const result = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) { result.set(chunk, offset); offset += chunk.length; }
  return result;
}

function buildImagePdf(pages: Array<{ dataUrl: string; width: number; height: number }>) {
  const encoder = new TextEncoder();
  const objects: Uint8Array[] = [];
  const pageObjectNumbers: number[] = [];
  const pageContentNumbers: number[] = [];
  const imageObjectNumbers: number[] = [];
  let nextObject = 4;
  for (const page of pages) {
    imageObjectNumbers.push(nextObject++);
    pageObjectNumbers.push(nextObject++);
    pageContentNumbers.push(nextObject++);
  }
  const objectCount = nextObject - 1;
  const putObject = (number: number, body: Uint8Array) => {
    objects[number] = pdfBytes([encoder.encode(`${number} 0 obj\n`), body, encoder.encode("\nendobj\n")]);
  };
  putObject(1, encoder.encode("<< /Type /Catalog /Pages 2 0 R >>"));
  putObject(2, encoder.encode(`<< /Type /Pages /Kids [${pageObjectNumbers.map((number) => `${number} 0 R`).join(" ")}] /Count ${pageObjectNumbers.length} >>`));
  putObject(3, encoder.encode("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"));
  pages.forEach((page, index) => {
    const imageBytes = dataUrlBytes(page.dataUrl);
    const imageObject = imageObjectNumbers[index];
    const pageObject = pageObjectNumbers[index];
    const contentObject = pageContentNumbers[index];
    putObject(imageObject, pdfBytes([
      encoder.encode(`<< /Type /XObject /Subtype /Image /Width ${page.width} /Height ${page.height} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length ${imageBytes.length} >>\nstream\n`),
      imageBytes,
      encoder.encode("\nendstream"),
    ]));
    // A page content object must be a PDF stream.  Writing the drawing
    // commands directly as the object body produces a malformed PDF which
    // some viewers open as a blank document.
    const content = encoder.encode(`q 595 0 0 842 0 0 cm /Im${index + 1} Do Q`);
    putObject(contentObject, pdfBytes([
      encoder.encode(`<< /Length ${content.length} >>\nstream\n`),
      content,
      encoder.encode("\nendstream"),
    ]));
    putObject(pageObject, encoder.encode(`<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /XObject << /Im${index + 1} ${imageObject} 0 R >> >> /Contents ${contentObject} 0 R >>`));
  });
  const header = encoder.encode("%PDF-1.4\n%\xFF\xFF\xFF\xFF\n");
  const chunks: Uint8Array[] = [header];
  const offsets = new Array<number>(objectCount + 1).fill(0);
  let offset = header.length;
  for (let number = 1; number <= objectCount; number += 1) {
    offsets[number] = offset;
    chunks.push(objects[number]);
    offset += objects[number].length;
  }
  const xrefOffset = offset;
  chunks.push(encoder.encode(`xref\n0 ${objectCount + 1}\n0000000000 65535 f \n${offsets.slice(1).map((item) => `${String(item).padStart(10, "0")} 00000 n \n`).join("")}trailer\n<< /Size ${objectCount + 1} /Root 1 0 R >>\nstartxref\n${xrefOffset}\n%%EOF`));
  return pdfBytes(chunks);
}

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
  const [selectedAgentId, setSelectedAgentId] = useState(HNTH_AGENT_ID);
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

  // Use same-origin /api in local development so the Vite proxy routes
  // requests to the backend. A hard-coded loopback URL breaks hydration
  // after reload (and for clients opening the site from another machine).
  const relayBase = ((import.meta.env.VITE_HNTH_BACKEND_URL as string | undefined) || (import.meta.env.VITE_HNTH_RELAY_URL as string | undefined) || "").replace(/\/$/, "");

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
        const response = await hnthFetch(`${relayBase}/api/agents`);
        if (!response.ok) return;
        const nextAgents = await response.json() as Array<{ agentId: string; name: string; status: string; heartbeatSeconds?: number; monitorConfig?: { points?: HnthAssignedPoint[]; [key: string]: unknown } }>;
        setAgents(nextAgents);
        setSelectedAgentId((current) => nextAgents.some((agent) => agent.agentId === current)
          ? current
          : nextAgents.find((agent) => agent.status === "online")?.agentId || nextAgents[0]?.agentId || HNTH_AGENT_ID);
      } catch { /* backend chưa sẵn sàng */ }
    };
    void loadAgents();
  }, [relayBase]);

  const refreshDiscoveredIps = async () => {
    try {
      const response = await hnthFetch(`${relayBase}/api/hnth/discovered-ips${selectedAgentId ? `?agentId=${encodeURIComponent(selectedAgentId)}` : ""}`);
      if (!response.ok) return;
      const payload = await response.json() as { ips?: Array<{ ipAddress?: string; model?: string; vendor?: string; modelVendor?: string; macAddress?: string }> };
      setDiscoveredIps((payload.ips ?? [])
        .filter((item): item is { ipAddress: string; model?: string; vendor?: string; modelVendor?: string; macAddress?: string } => Boolean(item.ipAddress))
        .map((item) => ({ ...item, model: item.model || item.vendor || item.modelVendor || "" })));
    } catch { /* relay chưa cấu hình, giữ danh sách hiện tại */ }
  };

  const requestNetworkScan = async () => {
    setIsScanning(true);
    try {
      const subnets = scanSubnets.split(",").map((item) => item.trim()).filter(Boolean);
      const response = await hnthFetch(`${relayBase}/api/hnth/scan`, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ scanSubnets: subnets, agentId: selectedAgentId || undefined }) });
      if (!response.ok) throw new Error(`Scan request failed: ${response.status}`);
      for (const delay of [3000, 7000, 15000, 30000]) window.setTimeout(() => void refreshDiscoveredIps(), delay);
    } catch {
      await refreshDiscoveredIps();
    } finally {
      window.setTimeout(() => setIsScanning(false), 5000);
    }
  };

  const setMonitoring = async (enabled: boolean, concurrency = pingConcurrency, waitSeconds = monitorWaitSeconds) => {
    setMonitoringError("");
    setContinuousMonitoring(enabled);
    const assignedPoints = agents.find((agent) => agent.agentId === selectedAgentId)?.monitorConfig?.points;
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
    const response = await hnthFetch(`${relayBase}/api/hnth/monitor`, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ enabled, concurrency, waitSeconds, agentId: selectedAgentId, points: monitorPoints }) });
    if (!response.ok) {
      setContinuousMonitoring(!enabled);
      const message = `Backend từ chối lệnh Giám sát liên tục (${response.status}). Hãy kiểm tra đăng nhập và Backend.`;
      setMonitoringError(message);
      throw new Error(message);
    }
    if (enabled) {
      // Khi bắt đầu giám sát, đưa camera về khung tổng quan toàn TP để nhìn
      // đồng thời toàn bộ endpoint và các đường kết nối HNTH.
      window.dispatchEvent(new Event(FIT_HAIPHONG_OVERVIEW_EVENT));
    }
    window.dispatchEvent(new CustomEvent("hnth:continuous-monitoring", { detail: { enabled, concurrency, waitSeconds } }));
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
  }, [relayBase, selectedAgentId]);

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
        window.dispatchEvent(new Event("hnth:layer-ready"));
      }
    }).catch(() => undefined);
    return () => { cancelled = true; };
  }, [isDataLayerVisible, points.length, mergeOperationalLayers, hnthPointOverrides]);

  // Đồng bộ trạng thái từ relay server nếu agent LAN đang hoạt động.
  // Khi relay chưa được cấu hình hoặc mất kết nối, dữ liệu demo vẫn được giữ nguyên.
  useEffect(() => {
    if (!points.length) return;
    const relayBase = ((import.meta.env.VITE_HNTH_BACKEND_URL as string | undefined) || (import.meta.env.VITE_HNTH_RELAY_URL as string | undefined))?.replace(/\/$/, "");
    // This endpoint returns the monitoring flag and the complete authoritative
    // snapshot together. It makes a Guest opened after round 1 hydrate exactly
    // like a Guest that was already watching the SSE stream.
    const statusUrl = `${relayBase || ""}/api/hnth/monitor-state`;
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
        const nextStatus: HnthConnectionStatus = !hasIp ? "unknown" : item.status === "online" ? "unconnected" : item.status === "offline" ? "lost" : "unknown";
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
        window.dispatchEvent(new CustomEvent(MAP_ADMINISTRATIVE_PULSE_EVENT, {
          // Khoanh tự động dùng đúng độ dày chuẩn x2 nét mảnh và chỉ giữ
          // hiệu ứng khoảng 5 giây, không nhân x2 thêm một lần nữa.
          detail: { administrativeIds: [...changedAdministrativeIds], cycles: 1, boundaryWidthMultiplier: 2, durationMs: 5000, animate: false },
        }));
      }
    };
    const applyLiveResults = (payload: unknown) => {
      if (!payload || typeof payload !== "object") return;
      // Ghi snapshot ngay cả khi effect hiện tại vừa bị cleanup. Khi reload,
      // monitor-state/SSE có thể trả về đúng lúc lớp GeoJSON HNTH đang thay
      // đổi; snapshot này sẽ được replay sau sự kiện layer-ready.
      latestLivePayloadRef.current = payload;
      if (cancelled) return;
      const agents = (payload as { agents?: Array<{ agentId?: string; status?: string }> }).agents;
      const hnthAgent = Array.isArray(agents) ? agents.find((item) => String(item.agentId ?? "") === selectedAgentId) : undefined;
      if (hnthAgent) {
        window.dispatchEvent(new CustomEvent("hnth:agent-status", {
          detail: { agentId: selectedAgentId, online: hnthAgent.status === "online", source: "backend" },
        }));
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
          const nextStatus: HnthConnectionStatus = !hasIp ? "unknown" : item.status === "online" ? "unconnected" : item.status === "offline" ? "lost" : "unknown";
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
        const status: HnthConnectionStatus = !hasIp ? "unknown" : live.status === "online" ? "unconnected" : live.status === "offline" ? "lost" : "unknown";
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
    const load = async () => {
      try {
        const response = await hnthFetch(statusUrl);
        if (!response.ok) return;
        const payload = await response.json() as { monitoring?: { enabled?: boolean; concurrency?: number; waitSeconds?: number }; results?: unknown };
        // Initial hydration must not reset the local map. The backend snapshot
        // is already authoritative and contains the latest round's statuses.
        if (payload.monitoring) {
          const enabled = Boolean(payload.monitoring.enabled);
          setContinuousMonitoring(enabled);
          window.dispatchEvent(new CustomEvent("hnth:continuous-monitoring", { detail: { enabled, concurrency: payload.monitoring.concurrency, waitSeconds: payload.monitoring.waitSeconds, source: "backend" } }));
          if (Number.isFinite(payload.monitoring.concurrency)) setPingConcurrency(Math.max(1, Math.min(30, Number(payload.monitoring.concurrency))));
          if (Number.isFinite(payload.monitoring.waitSeconds)) setMonitorWaitSeconds(Math.max(1, Math.min(10, Number(payload.monitoring.waitSeconds))));
        }
        applyLiveResults(payload);
      } catch { /* demo fallback */ }
    };
    const handleLayerReady = () => {
      // Nếu snapshot đã về trước khi layer được nạp, áp dụng lại ngay. Nếu
      // chưa có snapshot thì đọc lại backend để không phụ thuộc SSE đã đến
      // trước hay sau quá trình khởi tạo bản đồ.
      if (latestLivePayloadRef.current) applyLiveResults(latestLivePayloadRef.current);
      else void load();
    };
    window.addEventListener("hnth:layer-ready", handleLayerReady);
    void load();
    let source: EventSource | null = null;
    const connect = () => {
      if (cancelled) return;
      source?.close();
      source = new EventSource(`${relayBase || ""}/api/hnth/stream`);
      source.onmessage = (event) => {
        try {
          const payload = JSON.parse(event.data) as { type?: string; results?: unknown; monitoring?: { enabled?: boolean; concurrency?: number; waitSeconds?: number }; monitorBatch?: { end?: number; total?: number; results?: unknown; allResults?: unknown } };
          if (payload.monitoring) {
            const remoteEnabled = Boolean(payload.monitoring.enabled);
            // The backend resets the shared state when the admin starts a new
            // session. Other clients must consume that authoritative snapshot,
            // not locally reset/overwrite it from a stale React closure.
            setContinuousMonitoring(remoteEnabled);
            window.dispatchEvent(new CustomEvent("hnth:continuous-monitoring", { detail: { enabled: remoteEnabled, concurrency: payload.monitoring.concurrency, waitSeconds: payload.monitoring.waitSeconds, source: "backend" } }));
            if (Number.isFinite(payload.monitoring.concurrency)) setPingConcurrency(Math.max(1, Math.min(30, Number(payload.monitoring.concurrency))));
            if (Number.isFinite(payload.monitoring.waitSeconds)) setMonitorWaitSeconds(Math.max(1, Math.min(10, Number(payload.monitoring.waitSeconds))));
          }
          if (payload.monitorBatch) {
            handleMonitoringBatch(payload.monitorBatch, payload.monitoring?.enabled ?? continuousMonitoring);
            // Một nguồn batch duy nhất cho toàn bộ UI HNTH. Component log và
            // cửa sổ trình chiếu không tự mở SSE riêng nữa.
            window.dispatchEvent(new CustomEvent("hnth:monitor-batch", { detail: payload.monitorBatch }));
          }
          applyLiveResults(payload);
        } catch { /* bỏ qua sự kiện lỗi định dạng */ }
      };
    };
    connect();
    // SSE là kênh realtime chính. Snapshot định kỳ giúp phục hồi trạng thái
    // nếu trình duyệt tạm ngắt/throttle kết nối khi tab chạy nền.
    // SSE chỉ phát khi có sự kiện. Khi Agent vẫn đang giám sát nhưng không có
    // thay đổi trạng thái, Guest vẫn phải chủ động lấy snapshot đầy đủ để
    // khôi phục line/fill và trạng thái mới nhất.
    const refreshTimer = window.setInterval(() => { void load(); }, continuousMonitoring ? 2000 : 5000);
    const handleVisibilityChange = () => {
      if (document.visibilityState === "visible") {
        connect();
        void load();
      }
    };
    document.addEventListener("visibilitychange", handleVisibilityChange);
    return () => {
      cancelled = true;
      window.clearInterval(refreshTimer);
      window.removeEventListener("hnth:layer-ready", handleLayerReady);
      document.removeEventListener("visibilitychange", handleVisibilityChange);
      source?.close();
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
  const isConnected = selectedStatus === "connected";

  const exportHnthReport = async () => {
    if (isReporting) return;
    setIsReporting(true);
    try {
      const generatedAt = new Date();
      const generatedAtText = generatedAt.toLocaleString("vi-VN", { dateStyle: "full", timeStyle: "medium" });
      const reportPoints: HnthReportPoint[] = points.map((point) => ({
        name: String(point.properties?.name ?? "Điểm HNTH"),
        ipAddress: String(point.properties?.ipAddress ?? "").trim(),
        status: normalizeHnthStatus(point.properties?.status),
      }));
      const groups: Array<{ status: HnthConnectionStatus; title: string; color: string }> = [
        { status: "lost", title: "Mất kết nối", color: "#dc2626" },
        { status: "unconnected", title: "Chưa kết nối", color: "#ca8a04" },
        { status: "connected", title: "Đã kết nối", color: "#059669" },
        { status: "unknown", title: "Chưa xác định", color: "#64748b" },
      ];
      let mapImage: HTMLImageElement | null = null;
      try { mapImage = await captureMapBackground(); } catch { /* Vẫn xuất được báo cáo chữ nếu ảnh không chụp được. */ }
      const pageWidth = 1600;
      const pageHeight = 2200;
      const pages: Array<{ dataUrl: string; width: number; height: number }> = [];
      const drawPage = (pageNumber: number, drawBody: (ctx: CanvasRenderingContext2D) => void) => {
        const canvas = document.createElement("canvas");
        canvas.width = pageWidth;
        canvas.height = pageHeight;
        const context = canvas.getContext("2d");
        if (!context) return;
        context.fillStyle = "#ffffff";
        context.fillRect(0, 0, pageWidth, pageHeight);
        context.fillStyle = "#0f2935";
        context.font = "700 42px Segoe UI, Arial, sans-serif";
        context.fillText("BÁO CÁO GIÁM SÁT HỘI NGHỊ TRUYỀN HÌNH", 70, 85);
        context.fillStyle = "#52616b";
        context.font = "24px Segoe UI, Arial, sans-serif";
        context.fillText(`Thời gian xuất: ${generatedAtText}`, 70, 130);
        context.fillText(`Tổng số endpoint: ${reportPoints.length}`, 70, 168);
        drawBody(context);
        context.fillStyle = "#82909a";
        context.font = "18px Segoe UI, Arial, sans-serif";
        context.fillText(`Trang ${pageNumber}`, pageWidth - 160, pageHeight - 35);
        pages.push({ dataUrl: canvas.toDataURL("image/jpeg", 0.9), width: pageWidth, height: pageHeight });
      };
      drawPage(1, (context) => {
        let y = 220;
        if (mapImage) {
          const maxWidth = pageWidth - 140;
          const maxHeight = 760;
          const scale = Math.min(maxWidth / mapImage.naturalWidth, maxHeight / mapImage.naturalHeight);
          const width = Math.max(1, Math.round(mapImage.naturalWidth * scale));
          const height = Math.max(1, Math.round(mapImage.naturalHeight * scale));
          context.drawImage(mapImage, (pageWidth - width) / 2, y, width, height);
          y += height + 45;
        } else {
          context.fillStyle = "#f1f5f9";
          context.fillRect(70, y, pageWidth - 140, 180);
          context.fillStyle = "#52616b";
          context.font = "24px Segoe UI, Arial, sans-serif";
          context.fillText("Không thể chụp canvas bản đồ tại thời điểm xuất báo cáo.", 105, y + 100);
          y += 230;
        }
        context.fillStyle = "#0f2935";
        context.font = "700 28px Segoe UI, Arial, sans-serif";
        context.fillText("Tổng hợp trạng thái", 70, y);
        y += 54;
        groups.forEach((group, index) => {
          const count = reportPoints.filter((point) => point.status === group.status).length;
          const x = 70 + (index % 2) * 760;
          const rowY = y + Math.floor(index / 2) * 68;
          context.fillStyle = group.color;
          context.fillRect(x, rowY - 22, 20, 20);
          context.fillStyle = "#25343c";
          context.font = "24px Segoe UI, Arial, sans-serif";
          context.fillText(`${group.title}: ${count}`, x + 34, rowY);
        });
      });
      type ReportListRow = { heading?: string; left?: string; right?: string; blank?: boolean };
      const listRows: ReportListRow[] = [];
      for (const group of groups) {
        const groupPoints = reportPoints.filter((point) => point.status === group.status);
        listRows.push({ heading: `${group.title} (${groupPoints.length})` });
        // Nhóm dài hơn 10 dòng được dàn thành hai cột riêng của chính nhóm đó.
        // Các nhóm ngắn vẫn giữ một cột để dễ đọc.
        if (groupPoints.length > 10) {
          for (let index = 0; index < groupPoints.length; index += 2) {
            const left = groupPoints[index];
            const right = groupPoints[index + 1];
            listRows.push({
              left: `• ${left.name} — ${left.ipAddress || "Chưa cấu hình IP"}`,
              right: right ? `• ${right.name} — ${right.ipAddress || "Chưa cấu hình IP"}` : "",
            });
          }
        } else {
          for (const point of groupPoints) listRows.push({ left: `• ${point.name} — ${point.ipAddress || "Chưa cấu hình IP"}` });
        }
        listRows.push({ blank: true });
      }
      const rowsPerPage = 52;
      for (let start = 0; start < listRows.length; start += rowsPerPage) {
        const pageRows = listRows.slice(start, start + rowsPerPage);
        drawPage(pages.length + 1, (context) => {
          let y = 235;
          for (const row of pageRows) {
            if (row.blank) { y += 18; continue; }
            if (row.heading) {
              context.fillStyle = "#0f6674";
              context.font = "700 25px Segoe UI, Arial, sans-serif";
              context.fillText(row.heading, 80, y);
              y += 40;
              continue;
            }
            context.fillStyle = "#25343c";
            context.font = "21px Segoe UI, Arial, sans-serif";
            if (row.left) context.fillText(row.left, 80, y);
            if (row.right) context.fillText(row.right, 810, y);
            y += 32;
          }
        });
      }
      const pdf = buildImagePdf(pages);
      const url = URL.createObjectURL(new Blob([pdf], { type: "application/pdf" }));
      const link = document.createElement("a");
      link.href = url;
      link.download = `bao-cao-hnth-${generatedAt.toISOString().slice(0, 19).replaceAll(":", "-")}.pdf`;
      link.click();
      window.setTimeout(() => URL.revokeObjectURL(url), 1000);
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
    const onMapSelection = (event: Event) => {
      const detail = (event as CustomEvent<{ kind?: string; pointId?: string }>).detail;
      if (detail?.kind !== "hnth" || !detail.pointId) return;
      if (points.some((item) => String(item.properties?.pointId ?? item.id) === detail.pointId)) {
        setSelectedId(detail.pointId);
      }
    };
    window.addEventListener(MAP_CONTEXT_INFO_EVENT, onMapSelection);
    return () => window.removeEventListener(MAP_CONTEXT_INFO_EVENT, onMapSelection);
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
    window.dispatchEvent(new CustomEvent("hnth:focus", {
      detail: {
        coordinates: item.geometry.coordinates,
        // Dùng mức tuyệt đối để kết quả không phụ thuộc khung hình trước đó.
        // Riêng Bạch Long Vĩ chỉ đổi tâm và giữ nguyên tỷ lệ bản đồ hiện tại.
        targetZoom: HNTH_MENU_POINT_ZOOM,
        preserveZoom: pointName.toLocaleLowerCase("vi").includes("bạch long vĩ"),
        // Điểm nhánh được khoanh bằng viền trắng dày gấp đôi nét mảnh cơ sở.
        administrativeId,
        boundaryWidthMultiplier: 2,
      },
    }));
    window.dispatchEvent(new CustomEvent(MAP_CONTEXT_INFO_EVENT, {
      // Mở Popup Thông tin Endpoint cố định tương ứng với điểm vừa chọn.
      // Viền x2 đã được thiết lập bởi sự kiện hnth:focus ở trên.
      detail: { kind: "hnth", pointId: id, administrativeId },
    }));
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
      await hnthFetch(`${relayBase}/api/hnth/point-config`, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ pointId: selectedPointId, ipAddress: nextIp, modelVendor: model.trim() || undefined }) });
      if (continuousMonitoring) {
        const assignedPoints = agents.find((agent) => agent.agentId === selectedAgentId)?.monitorConfig?.points;
        const monitorPoints = Array.isArray(assignedPoints)
          ? assignedPoints.map((item) => ({ ...item, ipAddress: item.pointId === selectedPointId ? nextIp : item.ipAddress }))
          : points.map((item) => ({
            pointId: String(item.properties?.pointId ?? item.id),
            ipAddress: String(item.properties?.pointId === selectedPointId ? nextIp : item.properties?.ipAddress ?? ""),
          }));
        await hnthFetch(`${relayBase}/api/hnth/monitor`, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ enabled: true, concurrency: pingConcurrency, waitSeconds: monitorWaitSeconds, agentId: selectedAgentId, points: monitorPoints }) });
      }
    } catch { /* relay/agent offline; cấu hình local vẫn được lưu */ }
  };

  const exportPointConfig = () => {
    const header = ["Tên điểm", "IP", "Gateway", "Model/Vendor"];
    const rows = points.map((point) => [
      String(point.properties?.name ?? ""),
      String(point.properties?.ipAddress ?? ""),
      String(point.properties?.gateway || "192.168.1.1"),
      String(point.properties?.model || point.properties?.modelVendor || ""),
    ]);
    const sheet = XLSX.utils.aoa_to_sheet([header, ...rows]);
    sheet["!cols"] = [{ wch: 44 }, { wch: 18 }, { wch: 18 }, { wch: 22 }];
    for (let column = 0; column < header.length; column += 1) {
      const cell = sheet[XLSX.utils.encode_cell({ r: 0, c: column })];
      if (cell) cell.s = { font: { bold: true } };
    }
    const book = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(book, sheet, "Danh sach HNTH");
    XLSX.writeFile(book, `hnth-danh-sach-diem-${new Date().toISOString().slice(0, 10)}.xlsx`, { cellStyles: true });
  };

  const importPointConfig = async (file: File) => {
    try {
      let imported: HnthImportRow[];
      if (file.name.toLocaleLowerCase().endsWith(".xlsx")) {
        const workbook = XLSX.read(new Uint8Array(await file.arrayBuffer()), { type: "array" });
        const sheet = workbook.Sheets[workbook.SheetNames[0]];
        const rows = XLSX.utils.sheet_to_json<unknown[]>(sheet, { header: 1, defval: "" });
        imported = rows.slice(1).filter((row) => String(row[0] ?? "").trim()).map((row) => ({
          name: String(row[0] ?? "").trim(),
          ipAddress: String(row[1] ?? "").trim(),
          gateway: String(row[2] ?? "").trim(),
          modelVendor: String(row[3] ?? "").trim(),
        }));
      } else {
        imported = parseHnthCsv(await file.text());
      }
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
        await hnthFetch(`${relayBase}/api/hnth/point-config`, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ pointId, ipAddress: row.ipAddress, modelVendor: row.modelVendor || undefined, agentId: selectedAgentId }) });
      }
      const selectedAgent = agents.find((agent) => agent.agentId === selectedAgentId);
      const assignedPoints: HnthAssignedPoint[] = updates
        .filter(({ row }) => row.ipAddress)
        .map(({ pointId, row }) => ({ pointId, name: row.name, ipAddress: row.ipAddress, modelVendor: row.modelVendor }));
      if (selectedAgent && !readOnly) {
        const existingConfig = selectedAgent.monitorConfig || {};
        const saved = await hnthFetch(`${relayBase}/api/agents/${encodeURIComponent(selectedAgentId)}`, { method: "PATCH", headers: { "content-type": "application/json" }, body: JSON.stringify({ name: selectedAgent.name, heartbeatSeconds: selectedAgent.heartbeatSeconds || 30, monitorConfig: { ...existingConfig, points: assignedPoints } }) });
        if (!saved.ok) throw new Error(`Không lưu được danh sách điểm cho Agent (${saved.status}).`);
        setAgents((current) => current.map((agent) => agent.agentId === selectedAgentId ? { ...agent, monitorConfig: { ...existingConfig, points: assignedPoints } } : agent));
      }
      if (continuousMonitoring) {
        const monitorPoints = assignedPoints.map((item) => ({ pointId: item.pointId, ipAddress: item.ipAddress, name: item.name, modelVendor: item.modelVendor }));
        await hnthFetch(`${relayBase}/api/hnth/monitor`, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ enabled: true, concurrency: pingConcurrency, waitSeconds: monitorWaitSeconds, agentId: selectedAgentId, points: monitorPoints }) });
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
          <button disabled={readOnly} onClick={() => { if (!selectedPointId || readOnly) return; window.dispatchEvent(new CustomEvent("hnth:test-point", { detail: { pointId: selectedPointId, ipAddress: ipAddress.trim(), runId: Date.now() } })); }}><Zap size={14}/> Test</button>
          <button disabled={readOnly} onClick={() => setModal("info")}><Info size={14}/> Thông tin</button>
        </div>
        <div className="hnth-import-export">
          <input ref={importInputRef} type="file" accept=".csv,.xlsx,text/csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" hidden onChange={(event) => { const file = event.target.files?.[0]; if (file) void importPointConfig(file); }} />
          <button type="button" disabled={readOnly} onClick={() => importInputRef.current?.click()} title="Nhập danh sách Tên điểm, IP, Gateway, Model/Vendor"><Upload size={14}/> Import</button>
          <button type="button" disabled={readOnly} onClick={exportPointConfig} title="Xuất danh sách Tên điểm, IP, Gateway, Model/Vendor"><Download size={14}/> Export</button>
        </div>
      </div>}

      <div className="hnth-scan-controls">
        <label className="hnth-scan-subnets"><span>Agent HNTH</span><select value={selectedAgentId} onChange={(event) => setSelectedAgentId(event.target.value)} disabled={!agents.length || readOnly}>
          {agents.length ? agents.map((agent) => <option key={agent.agentId} value={agent.agentId}>{agent.name} ({agent.agentId})</option>) : <option value={HNTH_AGENT_ID}>{HNTH_AGENT_ID}</option>}
        </select></label>
        <label className="hnth-scan-subnets"><span>Subnet LAN</span><input value={scanSubnets} onChange={(event) => setScanSubnets(event.target.value)} placeholder="192.168.1.0/24" /></label>
        <button className="hnth-save" type="button" onClick={() => void requestNetworkScan()} disabled={readOnly || isScanning} title="Gửi lệnh cho agent quét mạng LAN"><Zap size={14}/> {isScanning ? "Đang quét..." : "Scan"}</button>
      </div>

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
