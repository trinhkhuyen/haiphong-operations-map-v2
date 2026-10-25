import { useEffect, useMemo, useState } from "react";
import { Cable, CircleAlert, Clock3, FileText, HardDrive, RadioTower, Video, X } from "lucide-react";
import { useAppStore } from "../../core/store";
import { emitAppEvent, onAppEvent } from "../../core/events";
import type { CameraDevice } from "../../core/store/camera";
import { cameraChannelItems } from "./camera-channel-items";

type CameraMetricKey = "recorders" | "online" | "unconnected" | "lost";
type CameraMetric = { key: CameraMetricKey; label: string; value: number; total: number | "?"; icon: typeof HardDrive; tone: "connected" | "unknown" | "unconnected" | "lost" };
type CameraChannel = { id: number; name?: string; online?: boolean };
type CameraDetailRow = { id: string; device: CameraDevice; channel?: CameraChannel; label: string; detail: string; status: "online" | "offline" | "unknown" };

const channelItems = cameraChannelItems;

function channelStatus(device: CameraDevice, channel: CameraChannel): CameraDetailRow["status"] {
  if (channel.online === true) return "online";
  if (device.status === "offline") return "offline";
  return "unknown";
}

function channelTotals(device: CameraDevice) {
  const channels = channelItems(device);
  const total = typeof device.channels === "number" ? device.channels : channels.length;
  const online = device.status === "online" ? channels.length > 0 ? channels.filter((channel) => channel.online === true).length : Math.max(0, device.onlineChannels ?? 0) : 0;
  const lost = device.status === "offline" ? total : device.status === "online" && device.channels !== null ? Math.max(0, total - online) : 0;
  const unconnected = ["unknown", "credentials_required", "unsupported"].includes(device.status) ? total : 0;
  return { total, online, lost, unconnected };
}

function deviceRow(device: CameraDevice): CameraDetailRow {
  return { id: device.id, device, label: device.name, detail: `${device.ipAddress || "LAN chưa cấu hình"} · ${device.vendor || device.model || "Camera"}`, status: device.status === "online" ? "online" : device.status === "offline" ? "offline" : "unknown" };
}

function channelRows(devices: CameraDevice[], key: Exclude<CameraMetricKey, "recorders">): CameraDetailRow[] {
  const rows: CameraDetailRow[] = [];
  devices.forEach((device) => {
    const channels = channelItems(device);
    channels.forEach((channel) => {
      const status = channelStatus(device, channel);
      const matches = key === "online" ? status === "online" : key === "lost" ? status === "offline" : status === "unknown";
      if (matches) rows.push({ id: `${device.id}-${channel.id}`, device, channel, label: `${device.name} · ${channel.name || `Kênh ${channel.id}`}`, detail: `${device.ipAddress || "LAN chưa cấu hình"} · Đầu ghi ${device.name}`, status });
    });
    if (key === "unconnected" && channels.length === 0 && device.status !== "online") rows.push(deviceRow(device));
  });
  return rows;
}

/** Thanh trạng thái và popup chi tiết riêng cho menu Camera. */
export function CameraStatusMetrics() {
  const devices = useAppStore((state) => state.cameraDevices);
  const logs = useAppStore((state) => state.cameraLogs);
  const [detailKey, setDetailKey] = useState<CameraMetricKey | null>(null);
  const metrics = useMemo(() => devices.reduce((summary, device) => {
    const totals = channelTotals(device);
    summary.totalRecorders += 1;
    summary.onlineRecorders += device.status === "online" ? 1 : 0;
    summary.totalChannels += totals.total;
    summary.onlineChannels += totals.online;
    summary.unconnectedChannels += totals.unconnected;
    summary.lostChannels += totals.lost;
    return summary;
  }, { totalRecorders: 0, onlineRecorders: 0, totalChannels: 0, onlineChannels: 0, unconnectedChannels: 0, lostChannels: 0 }), [devices]);
  const cards: CameraMetric[] = [
    { key: "recorders", label: "ĐẦU GHI ONLINE", value: metrics.onlineRecorders, total: metrics.totalRecorders, icon: HardDrive, tone: "connected" },
    { key: "online", label: "CAMERA ONLINE", value: metrics.onlineChannels, total: devices.some((device) => device.status === "online" && device.channels === null) ? "?" : metrics.totalChannels, icon: Video, tone: "connected" },
    { key: "lost", label: "CAMERA MẤT KẾT NỐI", value: metrics.lostChannels, total: devices.some((device) => device.status === "online" && device.channels === null) ? "?" : metrics.totalChannels, icon: CircleAlert, tone: "lost" },
    { key: "unconnected", label: "CAMERA CHƯA KẾT NỐI", value: metrics.unconnectedChannels, total: devices.some((device) => device.status === "online" && device.channels === null) ? "?" : metrics.totalChannels, icon: Clock3, tone: "unconnected" },
  ];
  const selectedCard = cards.find((card) => card.key === detailKey);
  const selectedRows = useMemo(() => {
    if (!detailKey) return [];
    if (detailKey === "recorders") return devices.filter((device) => device.status === "online").map(deviceRow);
    return channelRows(devices, detailKey);
  }, [detailKey, devices]);
  useEffect(() => {
    if (!detailKey) return;
    const closeOnEscape = (event: KeyboardEvent) => { if (event.key === "Escape") setDetailKey(null); };
    window.addEventListener("keydown", closeOnEscape);
    return () => window.removeEventListener("keydown", closeOnEscape);
  }, [detailKey]);
  useEffect(() => onAppEvent("camera:close-overlays", () => setDetailKey(null)), []);
  const focusRow = (row: CameraDetailRow) => {
    useAppStore.getState().selectCamera(row.device.id);
    emitAppEvent("map:context-info", { kind: "camera", deviceId: row.device.id });
  };
  return <>
    <div className="metric-strip hnth-metric-strip camera-metric-strip" aria-label="Tổng hợp trạng thái Camera">
      {cards.map(({ key, label, value, total, icon: Icon, tone }) => <button key={key} className={`${tone}${detailKey === key ? " active" : ""}`} aria-pressed={detailKey === key} onClick={() => setDetailKey((current) => current === key ? null : key)}>
        <span className={`metric-icon ${tone}`}><Icon size={17}/></span><p><small>{label}</small><strong>{value}<em> / {total} {key === "recorders" ? "đầu ghi" : "camera"}</em></strong></p>
      </button>)}
    </div>
    {selectedCard && <section className="hnth-status-detail-popup camera-status-detail-popup" role="region" aria-label={`Chi tiết Camera: ${selectedCard.label}`}>
      <header><span><HardDrive size={17}/><strong>Chi tiết: {selectedCard.label}</strong></span><button type="button" onClick={() => setDetailKey(null)} aria-label="Đóng popup chi tiết Camera"><X size={18}/></button></header>
      <div className="hnth-alert-summary"><div className="hnth-alert-summary-count"><i className={selectedCard.tone}/><strong>{selectedRows.length} {detailKey === "recorders" ? "đầu ghi" : "camera"}</strong></div></div>
      <div className="hnth-alert-list">
        {selectedRows.length === 0 && <p>Không có thiết bị/kênh nào trong trạng thái này.</p>}
        {selectedRows.map((row) => <div className="camera-status-detail-row" key={row.id}>
          <button className="hnth-alert-focus" type="button" onClick={() => focusRow(row)}><i className={row.status}/><span><strong>{row.label}</strong><small>{row.detail}{row.channel ? ` · ${row.channel.online ? "Đang phát" : "Không phát"}` : ""}</small></span></button>
          <div className="camera-status-detail-actions"><small>{row.device.status === "online" ? `${channelTotals(row.device).online}/${row.device.channels ?? "?"} kênh` : row.device.status === "offline" ? "Mất kết nối" : "Chưa kiểm tra"}</small>{detailKey === "recorders" && <button type="button" title={row.device.status === "online" ? "Ngắt kết nối" : "Kết nối"} onClick={() => emitAppEvent(row.device.status === "online" ? "camera:disconnect" : "camera:probe", { deviceId: row.device.id })}><Cable size={12}/></button>}<span title={`${logs.filter((item) => item.deviceId === row.device.id).length} log`}><FileText size={12}/>{logs.filter((item) => item.deviceId === row.device.id).length}</span></div>
        </div>)}
      </div>
    </section>}
  </>;
}
