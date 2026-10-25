import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Video } from "lucide-react";
import { centroid } from "@turf/turf";
import { useAppStore } from "../../core/store";
import { onAppEvent, emitAppEvent } from "../../core/events";
import type { Map as MapLibreMap } from "maplibre-gl";
import type { RefObject } from "react";
import { loadGovernmentUbndPoints, type UbndPoint } from "../administrative/data-provider";
import { HNTH_HUB } from "../layers/hnth-data-provider";
import { CameraStreamModal } from "../camera/CameraStreamModal";
import { cameraChannelItems } from "../camera/camera-channel-items";

function curvedConnectionPath(from: { x: number; y: number }, to: { x: number; y: number }) {
  const dx = to.x - from.x;
  const dy = to.y - from.y;
  const distance = Math.max(1, Math.hypot(dx, dy));
  const bend = Math.min(72, Math.max(26, distance * 0.18));
  const controlX = (from.x + to.x) / 2 - (dy / distance) * bend;
  const controlY = (from.y + to.y) / 2 + (dx / distance) * bend;
  return `M ${from.x} ${from.y} Q ${controlX} ${controlY} ${to.x} ${to.y}`;
}

export function CameraMapOverlays({ mapRef, isMapReady }: { mapRef: RefObject<MapLibreMap | null>; isMapReady: boolean }) {
  const devices = useAppStore((state) => state.cameraDevices);
  const units = useAppStore((state) => state.administrativeUnits);
  const [ubndPoints, setUbndPoints] = useState<UbndPoint[]>([]);
  const selectedId = useAppStore((state) => state.selectedCameraId);
  const select = useAppStore((state) => state.selectCamera);
  const [version, setVersion] = useState(0);
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [stream, setStream] = useState<{ device: typeof selected; channel: number } | null>(null);
  const [streamAnchor, setStreamAnchor] = useState<{ x: number; y: number } | null>(null);
  const [hovered, setHovered] = useState<{ deviceId: string; channelId?: number } | null>(null);
  const monitoringTargetRef = useRef<{ x: number; y: number } | null>(null);
  const closeTimerRef = useRef<number | null>(null);
  const selected = devices.find((device) => device.id === selectedId) ?? null;
  const showInfo = useCallback((deviceId: string) => {
    if (closeTimerRef.current !== null) {
      window.clearTimeout(closeTimerRef.current);
    }
    select(deviceId);
    closeTimerRef.current = window.setTimeout(() => {
      select(null);
      closeTimerRef.current = null;
    }, 5000);
  }, [select]);

  useEffect(() => () => {
    if (closeTimerRef.current !== null) {
      window.clearTimeout(closeTimerRef.current);
    }
  }, []);
  useEffect(() => { void loadGovernmentUbndPoints().then(setUbndPoints).catch(() => setUbndPoints([])); }, []);
  useEffect(() => onAppEvent("map:context-info", (detail) => {
    if (detail.kind === "camera") {
      showInfo(detail.deviceId);
    }
  }), [showInfo]);
  useEffect(() => onAppEvent("camera:disconnect", ({ deviceId }) => {
    setStream((current) => current?.device?.id === deviceId ? null : current);
    setExpandedId((current) => current === deviceId ? null : current);
  }), []);
  useEffect(() => onAppEvent("camera:expand", ({ deviceId }) => setExpandedId(deviceId)), []);
  const positions = useMemo(() => devices.map((device) => {
    const ubndPoint = ubndPoints.find((point) => point.wardCode === device.administrativeId);
    const legacyUnit = units.find((item) => String(item.id) === device.administrativeId);
    const coordinates = device.longitude !== null && device.latitude !== null ? [device.longitude, device.latitude] as [number, number] : ubndPoint?.coordinates ?? (legacyUnit ? centroid(legacyUnit.geometry).geometry.coordinates as [number, number] : null);
    const point = coordinates && mapRef.current ? mapRef.current.project(coordinates) : null;
    return { device, point };
  }), [devices, units, ubndPoints, mapRef, isMapReady, version]);
  useEffect(() => { const map = mapRef.current; if (!map) return; const refresh = () => setVersion((value) => value + 1); map.on("move", refresh); map.on("resize", refresh); return () => { map.off("move", refresh); map.off("resize", refresh); }; }, [mapRef, isMapReady]);
  useEffect(() => {
    if (!stream) { setStreamAnchor(null); return; }
    let frame = 0;
    const update = () => {
      const modal = document.querySelector<HTMLElement>(".camera-stream-modal");
      const backdrop = document.querySelector<HTMLElement>(".camera-stream-backdrop");
      if (!modal || !backdrop) return;
      const modalRect = modal.getBoundingClientRect();
      const backdropRect = backdrop.getBoundingClientRect();
      const target = monitoringTargetRef.current;
      if (!target) return;
      const targetX = backdropRect.left + target.x;
      const targetY = backdropRect.top + target.y;
      const centerX = modalRect.left + modalRect.width / 2;
      const sourceX = targetX < centerX ? modalRect.left : modalRect.right;
      const sourceY = Math.max(modalRect.top + 12, Math.min(targetY, modalRect.bottom - 12));
      setStreamAnchor({ x: sourceX - backdropRect.left, y: sourceY - backdropRect.top });
    };
    frame = window.requestAnimationFrame(update);
    window.addEventListener("resize", update);
    return () => { window.cancelAnimationFrame(frame); window.removeEventListener("resize", update); };
  }, [stream, expandedId, version]);
  const hubPoint = mapRef.current?.project(HNTH_HUB) ?? null;
  const channelItems = cameraChannelItems;
  if (!isMapReady) return null;
  const monitoringDevice = stream?.device ? positions.find((item) => item.device.id === stream.device?.id && item.point) : null;
  const monitoringChannels = monitoringDevice ? cameraChannelItems(monitoringDevice.device).filter((channel) => channel.online) : [];
  const monitoringChannelIndex = monitoringDevice && stream ? monitoringChannels.findIndex((channel) => channel.id === stream.channel) : -1;
  const monitoringAngle = monitoringChannelIndex >= 0 ? monitoringChannelIndex * (360 / monitoringChannels.length) : 0;
  const monitoringChannelExpanded = Boolean(monitoringDevice && stream && expandedId === monitoringDevice.device.id && monitoringChannelIndex >= 0);
  const monitoringTarget = monitoringDevice?.point
    ? monitoringChannelExpanded
      ? { x: monitoringDevice.point.x + Math.sin(monitoringAngle * Math.PI / 180) * 42, y: monitoringDevice.point.y - Math.cos(monitoringAngle * Math.PI / 180) * 42 }
      : { x: monitoringDevice.point.x, y: monitoringDevice.point.y }
    : null;
  monitoringTargetRef.current = monitoringTarget;
  return <><div className="camera-connection-lines">{hubPoint && positions.filter((item) => item.point).map(({ device, point }) => <svg key={device.id} className={`camera-connection-line ${device.status}`} aria-hidden="true"><path d={`M ${hubPoint.x} ${hubPoint.y} L ${point!.x} ${point!.y}`} /></svg>)}{streamAnchor && monitoringTarget && <svg className="camera-stream-connection-line active" aria-hidden="true"><path d={curvedConnectionPath(streamAnchor, monitoringTarget)} /></svg>}</div>{hubPoint && <div className="camera-hub-anchor" style={{ left: hubPoint.x, top: hubPoint.y }} title="Trung tâm Chính trị - Hành chính" />}
    <div className="camera-map-markers">{positions.filter((item) => item.point).map(({ device, point }) => {
      const onlineChannels = cameraChannelItems(device).filter((channel) => channel.online);
      const isMonitoringThisRecorder = stream?.device?.id === device.id;
      const isRecorderHighlighted = isMonitoringThisRecorder ? expandedId !== device.id : selectedId === device.id;
      return <div key={device.id} className="camera-marker-group" style={{ left: point!.x, top: point!.y }}><button className={`camera-map-marker ${isRecorderHighlighted ? "active" : ""}`} aria-label={`${device.name} · ${onlineChannels.length}/${device.channels ?? "?"} kênh online`} onMouseEnter={() => setHovered({ deviceId: device.id })} onMouseLeave={() => setHovered(null)} onClick={() => { showInfo(device.id); setExpandedId((current) => current === device.id ? null : device.id); }}><span>{onlineChannels.length}</span></button>{hovered?.deviceId === device.id && hovered.channelId === undefined && <div className="camera-map-tooltip" role="tooltip"><strong>{device.name}</strong><small>{onlineChannels.length}/{device.channels ?? "?"} kênh online</small></div>}{expandedId === device.id && onlineChannels.length > 0 && <div className="camera-channel-markers">{onlineChannels.map((channel, index) => { const angle = index * (360 / onlineChannels.length); const isStreaming = stream?.device?.id === device.id && stream.channel === channel.id; return <button type="button" key={channel.id} className={`camera-channel-marker online connected ${isStreaming ? "selected" : ""}`} style={{ transform: `rotate(${angle}deg) translateY(-42px)` }} aria-label={`${channel.name || `Kênh ${channel.id}`} · Kênh ${channel.id}`} onMouseEnter={() => setHovered({ deviceId: device.id, channelId: channel.id })} onMouseLeave={() => setHovered(null)} onClick={(event) => { event.stopPropagation(); setStream({ device, channel: channel.id }); }}><Video size={16} style={{ transform: `rotate(${-angle}deg)` }}/></button>; })}</div>}{hovered?.deviceId === device.id && hovered.channelId !== undefined && <div className="camera-map-tooltip" role="tooltip"><strong>{onlineChannels.find((channel) => channel.id === hovered.channelId)?.name || `Kênh ${hovered.channelId}`}</strong><small>Kênh {hovered.channelId}</small></div>}</div>;
    })}</div>
    <div className="camera-extra-cards">{positions.filter((item) => !item.point).map(({ device }) => <button key={device.id} className="camera-extra-card" onClick={() => { showInfo(device.id); setExpandedId(device.id); }}><Video size={15}/><span><strong>{device.name}</strong><small>Thiết bị ngoài mốc · cần kinh độ/vĩ độ</small></span></button>)}</div>{selected && <aside className="camera-fixed-info-card"><span>THÔNG TIN CAMERA</span><strong>{selected.name}</strong><small>{selected.serialNumber || "Thiết bị LAN"}</small><dl><dt>Mốc UBND</dt><dd>{selected.administrativeId ? ubndPoints.find((point) => point.wardCode === selected.administrativeId)?.name ?? "Mốc UBND đã gán" : "Ngoài danh sách mốc UBND"}</dd><dt>Kênh online / tổng</dt><dd>{selected.status === "online" ? `${channelItems(selected).filter((channel) => channel.online).length} / ${selected.channels ?? "?"}` : selected.channels ?? "Chưa dò"}</dd>{selected.status === "online" && selected.channels === null && <><dt>Đã xác thực</dt><dd>{channelItems(selected).filter((channel) => channel.online).map((channel) => `Kênh ${channel.id}`).join(", ") || "Chưa có"}</dd></>}<dt>Trạng thái</dt><dd>{selected.status === "online" ? "Đang kết nối" : selected.status === "offline" ? "Mất kết nối" : "Chưa kiểm tra"}</dd></dl></aside>}{stream?.device && <CameraStreamModal device={stream.device} channel={stream.channel} onClose={() => setStream(null)} />}</>;
}
