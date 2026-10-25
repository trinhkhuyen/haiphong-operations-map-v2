import { useEffect, useMemo, useState } from "react";
import type { CSSProperties } from "react";
import type { Map as MapLibreMap } from "maplibre-gl";
import { useAppStore } from "../../core/store";
import { emitAppEvent } from "../../core/events";
import { agentsApi } from "../../core/api/clients";
import { HNTH_LAYER_ID, normalizeHnthStatus } from "../layers/hnth-data-provider";
import { formatClockTime, useCurrentTime } from "../../app/MapTitleClock";
import { demoMode } from "../../core/runtime";

type Props = { mapRef: React.MutableRefObject<MapLibreMap | null>; isMapReady: boolean };
type ScaleMark = { label: string; pixels: number };
type CoordinateOverlayProps = Props & { longitude: number; latitude: number; longitudeVisible: boolean; latitudeVisible: boolean };
type CompassOverlayProps = Props & { bearing: number; visible: boolean };
const CENTER_OFFSET = 454;

function gaugeArcPath(cx: number, cy: number, radius: number) {
  const rad = (degrees: number) => (degrees * Math.PI) / 180;
  const sx = cx + radius * Math.sin(rad(225));
  const sy = cy - radius * Math.cos(rad(225));
  const ex = cx + radius * Math.sin(rad(135));
  const ey = cy - radius * Math.cos(rad(135));
  return `M${sx.toFixed(2)},${sy.toFixed(2)} A${radius},${radius} 0 1 1 ${ex.toFixed(2)},${ey.toFixed(2)}`;
}

function SampleGauge({ x, label, value, valueText, unit, max, decimals, icon, valueSuffix = "", onClick, active }: { x: number; label: string; value: number; valueText?: string; unit: string; max: number; decimals: number; icon?: "compass"; valueSuffix?: string; onClick?: () => void; active?: boolean }) {
  const fraction = Math.max(0, Math.min(1, value / max));
  const d = gaugeArcPath(x, 75, 40);
  return <g className={`hh-gauge${onClick ? " is-interactive" : ""}${active ? " is-active" : ""}`} onClick={onClick} role={onClick ? "button" : undefined} aria-label={onClick ? `${label}, bật tắt thước tỷ lệ` : undefined} style={onClick ? { pointerEvents: "auto", cursor: "pointer" } : undefined}>
    <circle className="hh-disc" cx={x} cy="75" r="43" />
    <path className="hh-g-track" d={d} />
    <path className="hh-g-fill" d={d} pathLength="1" strokeDasharray={`${fraction} 1`} />
    {icon === "compass" && <path className="hh-gauge-icon" transform={`translate(${x - 31} 59)`} d="M0,-8 C1,-3 3,-1 8,0 C3,1 1,3 0,8 C-1,3 -3,1 -8,0 C-3,-1 -1,-3 0,-8 Z" />}
    <text className="hh-g-label" x={x} y="59">{label}</text>
    <text className="hh-g-value" x={x} y="84">{valueText ?? `${value.toFixed(decimals)}${valueSuffix}`}</text>
    <text className="hh-g-unit" x={x} y="101">{unit}</text>
  </g>;
}

function distanceInKm(first: { lng: number; lat: number }, second: { lng: number; lat: number }) {
  const earthRadiusKm = 6371;
  const radians = (value: number) => (value * Math.PI) / 180;
  const dLat = radians(second.lat - first.lat);
  const dLng = radians(second.lng - first.lng);
  const lat1 = radians(first.lat);
  const lat2 = radians(second.lat);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return earthRadiusKm * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function makeScaleMark(rawDistanceKm: number, targetPixels: number): ScaleMark {
  if (!Number.isFinite(rawDistanceKm) || rawDistanceKm <= 0) return { label: "1 km", pixels: targetPixels };
  const magnitude = 10 ** Math.floor(Math.log10(rawDistanceKm));
  const niceValue = [1, 2, 5, 10].map((step) => step * magnitude).filter((value) => value <= rawDistanceKm).pop() ?? magnitude;
  const decimals = niceValue < 1 ? 1 : 0;
  return { label: `${niceValue.toFixed(decimals)} km`, pixels: Math.max(52, Math.min(targetPixels, targetPixels * (niceValue / rawDistanceKm))) };
}

function MapScaleOverlay({ mapRef, isMapReady, visible }: Props & { visible: boolean }) {
  const [horizontal, setHorizontal] = useState<ScaleMark>({ label: "1 km", pixels: 150 });
  const [vertical, setVertical] = useState<ScaleMark>({ label: "1 km", pixels: 110 });

  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map || !visible) return;
    const updateScales = () => {
      const { clientWidth, clientHeight } = map.getContainer();
      if (!clientWidth || !clientHeight) return;
      const horizontalY = Math.min(84, Math.max(28, clientHeight * 0.14));
      const horizontalPixels = Math.min(220, Math.max(130, clientWidth * 0.13));
      const verticalX = Math.max(20, clientWidth - 72);
      const verticalPixels = Math.min(180, Math.max(100, clientHeight * 0.18));
      const horizontalDistance = distanceInKm(map.unproject([Math.max(12, (clientWidth - horizontalPixels) / 2), horizontalY]), map.unproject([Math.max(12, (clientWidth - horizontalPixels) / 2) + horizontalPixels, horizontalY]));
      const verticalDistance = distanceInKm(map.unproject([verticalX, Math.max(12, (clientHeight - verticalPixels) / 2)]), map.unproject([verticalX, Math.max(12, (clientHeight - verticalPixels) / 2) + verticalPixels]));
      setHorizontal(makeScaleMark(horizontalDistance, horizontalPixels));
      setVertical(makeScaleMark(verticalDistance, verticalPixels));
    };
    updateScales();
    map.on("move", updateScales);
    map.on("rotate", updateScales);
    map.on("zoom", updateScales);
    map.on("pitch", updateScales);
    map.on("resize", updateScales);
    return () => {
      map.off("move", updateScales);
      map.off("rotate", updateScales);
      map.off("zoom", updateScales);
      map.off("pitch", updateScales);
      map.off("resize", updateScales);
    };
  }, [isMapReady, mapRef, visible]);

  if (!visible) return null;
  return <div className="map-scale-overlay" aria-label="Thước tỷ lệ bản đồ, đơn vị km">
    <div className="map-scale-horizontal" style={{ width: `${horizontal.pixels}px` }}>
      <span>{horizontal.label}</span>
      <i />
    </div>
    <div className="map-scale-vertical" style={{ height: `${vertical.pixels}px` }}>
      <i />
      <span>{vertical.label}</span>
    </div>
  </div>;
}

function coordinatePath(map: MapLibreMap, axis: "longitude" | "latitude", value: number) {
  const points: string[] = [];
  const segments = 72;
  for (let index = 0; index <= segments; index += 1) {
    const progress = index / segments;
    const point = axis === "longitude"
      ? map.project({ lng: value, lat: -85 + progress * 170 })
      : map.project({ lng: -180 + progress * 360, lat: value });
    points.push(`${point.x.toFixed(1)},${point.y.toFixed(1)}`);
  }
  return points.join(" ");
}

function MapCoordinateOverlay({ mapRef, isMapReady, longitude, latitude, longitudeVisible, latitudeVisible }: CoordinateOverlayProps) {
  const [paths, setPaths] = useState({ longitude: "", latitude: "" });

  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map || (!longitudeVisible && !latitudeVisible)) return;
    const updatePaths = () => setPaths({
      longitude: longitudeVisible ? coordinatePath(map, "longitude", longitude) : "",
      latitude: latitudeVisible ? coordinatePath(map, "latitude", latitude) : "",
    });
    updatePaths();
    map.on("move", updatePaths);
    map.on("rotate", updatePaths);
    map.on("zoom", updatePaths);
    map.on("pitch", updatePaths);
    map.on("resize", updatePaths);
    return () => {
      map.off("move", updatePaths);
      map.off("rotate", updatePaths);
      map.off("zoom", updatePaths);
      map.off("pitch", updatePaths);
      map.off("resize", updatePaths);
    };
  }, [isMapReady, latitude, latitudeVisible, longitude, longitudeVisible, mapRef]);

  if (!longitudeVisible && !latitudeVisible) return null;
  return <svg className="map-coordinate-overlay" aria-label="Đường kinh độ và vĩ độ bản đồ">
    {longitudeVisible && <polyline className="map-coordinate-line longitude" points={paths.longitude} />}
    {latitudeVisible && <polyline className="map-coordinate-line latitude" points={paths.latitude} />}
  </svg>;
}

function MapCompassOverlay({ mapRef, isMapReady, bearing, visible }: CompassOverlayProps) {
  const [geometry, setGeometry] = useState({ cx: 0, cy: 0, ex: 0, ey: 0, radius: 0, arc: "" });

  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map || !visible) return;
    const updateGeometry = () => {
      const { clientWidth, clientHeight } = map.getContainer();
      const center = map.project(map.getCenter());
      const radius = Math.min(115, Math.max(72, Math.min(clientWidth, clientHeight) * 0.12));
      const normalizedBearing = ((bearing % 360) + 360) % 360;
      const radians = (normalizedBearing * Math.PI) / 180;
      const ex = center.x - radius * Math.sin(radians);
      const ey = center.y - radius * Math.cos(radians);
      const largeArc = normalizedBearing > 180 ? 1 : 0;
      const sweep = normalizedBearing <= 180 ? 1 : 0;
      setGeometry({
        cx: center.x,
        cy: center.y,
        ex,
        ey,
        radius,
        arc: `M ${center.x.toFixed(1)} ${(center.y - radius).toFixed(1)} A ${radius.toFixed(1)} ${radius.toFixed(1)} 0 ${largeArc} ${sweep} ${ex.toFixed(1)} ${ey.toFixed(1)}`,
      });
    };
    updateGeometry();
    map.on("move", updateGeometry);
    map.on("rotate", updateGeometry);
    map.on("zoom", updateGeometry);
    map.on("pitch", updateGeometry);
    map.on("resize", updateGeometry);
    return () => {
      map.off("move", updateGeometry);
      map.off("rotate", updateGeometry);
      map.off("zoom", updateGeometry);
      map.off("pitch", updateGeometry);
      map.off("resize", updateGeometry);
    };
  }, [bearing, isMapReady, mapRef, visible]);

  if (!visible) return null;
  return <svg className="map-compass-overlay" aria-label={`Góc la bàn ${Math.round(bearing)} độ`}>
    <path className="map-compass-angle" d={geometry.arc} />
    <line className="map-compass-ray" x1={geometry.cx} y1={geometry.cy} x2={geometry.ex} y2={geometry.ey} />
    <line className="map-compass-north" x1={geometry.cx} y1={geometry.cy} x2={geometry.cx} y2={geometry.cy - geometry.radius} />
    <circle className="map-compass-center" cx={geometry.cx} cy={geometry.cy} r="4" />
    <text className="map-compass-label" x={geometry.cx + 12} y={geometry.cy - 14}>GÓC LA BÀN {Math.round(bearing)}°</text>
  </svg>;
}

export function HubOverlay(_props: Props) {
  const { mapRef, isMapReady } = _props;
  const enabled = useAppStore((state) => state.hubEnabled);
  const glass = useAppStore((state) => state.hubGlassmorphism);
  const opacity = useAppStore((state) => state.hubOpacity);
  const cameraDevices = useAppStore((state) => state.cameraDevices);
  const hnthLayer = useAppStore((state) => state.layers.find((item) => item.id === HNTH_LAYER_ID));
  const [agentMetrics, setAgentMetrics] = useState({ online: demoMode ? 1 : 0, total: demoMode ? 2 : 0 });
  const [scaleVisible, setScaleVisible] = useState(false);
  const [longitudeVisible, setLongitudeVisible] = useState(false);
  const [latitudeVisible, setLatitudeVisible] = useState(false);
  const [compassVisible, setCompassVisible] = useState(false);
  const currentTime = useCurrentTime();
  const [mapTelemetry, setMapTelemetry] = useState({ longitude: 0, latitude: 0, zoom: 0, bearing: 0 });

  useEffect(() => {
    if (demoMode) return;
    let cancelled = false;
    const loadAgents = async () => {
      try {
        const response = await agentsApi.list();
        if (!response.ok) return;
        const payload = await response.json() as Array<{ status?: string }>;
        if (!cancelled) setAgentMetrics({ online: payload.filter((agent) => agent.status === "online").length, total: payload.length });
      } catch { /* HUB giữ số liệu gần nhất khi backend tạm thời không phản hồi. */ }
    };
    void loadAgents();
    const timer = window.setInterval(() => void loadAgents(), 10000);
    return () => { cancelled = true; window.clearInterval(timer); };
  }, []);

  const cameraMetrics = useMemo(() => {
    let online = 0;
    const total = cameraDevices.length;
    cameraDevices.forEach((device) => {
      const onlineChannels = device.status === "online"
        ? device.channelStates?.length
          ? device.channelStates.filter((channel) => channel.online === true).length
          : Math.max(0, device.onlineChannels ?? 0)
        : 0;
      online += onlineChannels;
    });
    return { online, total };
  }, [cameraDevices]);

  const hnthMetrics = useMemo(() => {
    const points = (hnthLayer?.data.features ?? []).filter((feature) => feature.geometry.type === "Point");
    const waiting = points.filter((point) => normalizeHnthStatus(point.properties?.status) === "unconnected").length;
    return { waiting, total: points.length };
  }, [hnthLayer]);

  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map) return;
    const updateTelemetry = () => {
      const center = map.getCenter();
      setMapTelemetry({
        longitude: center.lng,
        latitude: center.lat,
        zoom: map.getZoom(),
        bearing: ((map.getBearing() % 360) + 360) % 360,
      });
    };
    updateTelemetry();
    map.on("move", updateTelemetry);
    map.on("rotate", updateTelemetry);
    map.on("zoom", updateTelemetry);
    map.on("pitch", updateTelemetry);
    map.on("moveend", updateTelemetry);
    map.on("rotateend", updateTelemetry);
    map.on("zoomend", updateTelemetry);
    map.on("pitchend", updateTelemetry);
    return () => {
      map.off("move", updateTelemetry);
      map.off("rotate", updateTelemetry);
      map.off("zoom", updateTelemetry);
      map.off("pitch", updateTelemetry);
      map.off("moveend", updateTelemetry);
      map.off("rotateend", updateTelemetry);
      map.off("zoomend", updateTelemetry);
      map.off("pitchend", updateTelemetry);
    };
  }, [isMapReady, mapRef]);

  if (!enabled) return null;
  const style = { "--hub-opacity": opacity } as CSSProperties;
  return <>
  <aside className={`map-hub sample-hud ${glass ? "is-glass" : "is-solid"}`} style={style} aria-label="HUB telemetry Starship">
    <svg className="hub-sample-svg" viewBox="0 0 1920 148" preserveAspectRatio="none" role="img" aria-label="Starship flight telemetry">
      <path className="hh-shell" d="M0,148 V32 Q0,20 12,20 H628 C648,20 656,42 680,42 H1240 C1264,42 1272,20 1292,20 H1908 Q1920,20 1920,32 V148 Z" />
      <g transform={`translate(${CENTER_OFFSET} 0)`}>
      <path className="hh-bowl" d="M207,148 A495,495 0 0 1 806,148 Z" />
      <path className="hh-bowl-edge" d="M207,148 A495,495 0 0 1 806,148" />
      <path className="hh-clock-scale" d="M207,148 A495,495 0 0 1 806,148" pathLength="24" strokeDasharray="0.08 0.92" />
      <path className="hh-track" d="M159,148 A547.5,547.5 0 0 1 853,148" pathLength="1" />
      <path className="hh-prog" d="M159,148 A547.5,547.5 0 0 1 853,148" pathLength="1" strokeDasharray="0.512 1" />
      <text className="hh-time" x="506" y="92">{formatClockTime(currentTime)}</text>
      <text className="hh-title" x="506" y="108">GIÁM SÁT TP HẢI PHÒNG</text>
      <g className="hh-status"><circle cx="506" cy="123" r="3" /><text x="516" y="126">ONLINE 83%</text></g>
      </g>
      <g className="hh-side-gauges">
        <SampleGauge x={100} label="KINH ĐỘ 1" value={mapTelemetry.longitude} unit="°" max={180} decimals={1} onClick={() => setLongitudeVisible((current) => !current)} active={longitudeVisible} /><SampleGauge x={255} label="VĨ ĐỘ 2" value={mapTelemetry.latitude} unit="°" max={90} decimals={1} onClick={() => setLatitudeVisible((current) => !current)} active={latitudeVisible} /><SampleGauge x={410} label="ZOOM 3" value={mapTelemetry.zoom} unit="" max={22} decimals={1} onClick={() => setScaleVisible((current) => !current)} active={scaleVisible} /><SampleGauge x={565} label="LA BÀN 4" value={mapTelemetry.bearing} unit="" valueSuffix="°" max={360} decimals={0} icon="compass" onClick={() => setCompassVisible((current) => !current)} active={compassVisible} />
        <SampleGauge x={1355} label="AGENT 5" value={agentMetrics.online} valueText={`${agentMetrics.online}/${agentMetrics.total}`} unit="ONLINE / TỔNG" max={Math.max(1, agentMetrics.total)} decimals={0} onClick={() => emitAppEvent("ui:open-panel", "agents")} />
        <SampleGauge x={1510} label="CAMERA 6" value={cameraMetrics.online} valueText={`${cameraMetrics.online}/${cameraMetrics.total}`} unit="ONLINE / ĐẦU GHI" max={Math.max(1, cameraMetrics.total)} decimals={0} onClick={() => emitAppEvent("ui:open-panel", "camera")} />
        <SampleGauge x={1665} label="HNTH 7" value={hnthMetrics.waiting} valueText={`${hnthMetrics.waiting}/${hnthMetrics.total}`} unit="CHỜ / TỔNG" max={Math.max(1, hnthMetrics.total)} decimals={0} onClick={() => emitAppEvent("ui:open-panel", "conference")} />
        <SampleGauge x={1820} label="ONLINE 8" value={83} unit="%" max={100} decimals={0} />
      </g>
      <path className="hh-center-hitarea" d="M613,148 A547.5,547.5 0 0 1 1307,148 L1307,148 H613 Z" onClick={() => emitAppEvent("ui:open-panel", "hub")} role="button" aria-label="Mở menu cấu hình HUB" />
    </svg>
  </aside>
  <MapCoordinateOverlay mapRef={mapRef} isMapReady={isMapReady} longitude={mapTelemetry.longitude} latitude={mapTelemetry.latitude} longitudeVisible={longitudeVisible} latitudeVisible={latitudeVisible} />
  <MapCompassOverlay mapRef={mapRef} isMapReady={isMapReady} bearing={mapTelemetry.bearing} visible={compassVisible} />
  <MapScaleOverlay mapRef={mapRef} isMapReady={isMapReady} visible={scaleVisible} />
  </>;
}
