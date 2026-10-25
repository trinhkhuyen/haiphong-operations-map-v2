// Lớp HNTH: điểm, đường nối, tô địa giới theo trạng thái; đồng bộ feature-state không dựng lại source.
import maplibregl, { type GeoJSONSource, type Map as MapLibreMap } from "maplibre-gl";
import { useAppStore } from "../../../core/store";
import type { OperationalLayer } from "../../../core/types";
import { HNTH_LAYER_ID, normalizeHnthStatus, type HnthConnectionStatus, type HnthStatusStyles } from "../../layers/hnth-data-provider";
import { emitAppEvent } from "../../../core/events";
import { restoreHaiphongOverviewIfZoomedOut } from "./viewport";

export const hnthVisualSyncCache = new WeakMap<MapLibreMap, { staticKey: string; dynamicKey: string }>();
export const hnthFeatureStateCache = new WeakMap<MapLibreMap, Map<string, HnthConnectionStatus>>();
export const hnthAdministrativeStateCache = new WeakMap<MapLibreMap, Map<string, HnthConnectionStatus>>();
export const hnthFeaturePropertiesCache = new WeakMap<MapLibreMap, Map<string, Record<string, unknown>>>();

type HnthSignalLine = {
  coordinates: [number, number][];
  pointId: string;
  status: HnthConnectionStatus;
  // Bạch Long Vĩ là tuyến đặc biệt ở vùng biển xa: chỉ tăng độ rõ/tốc độ
  // cho tín hiệu của tuyến này, không thay đổi toàn bộ các tuyến MapLibre.
  signalSpeed: number;
  signalScale: number;
  signalBlur: number;
};
type HnthSignalAnimation = { frame: number | null; phase: number; lastFrameAt: number; lines: HnthSignalLine[]; key: string };
export const hnthSignalAnimationCache = new WeakMap<MapLibreMap, HnthSignalAnimation>();

// Exported for the React sync hook so it can wait for the dedicated signal
// source during a cold MapLibre boot (for example after F5).
export const HNTH_SIGNAL_SOURCE_ID = `${HNTH_LAYER_ID}-signal`;
// Keep the source and style-layer IDs distinct. MapLibre accepts separate
// namespaces in theory, but a shared ID can be dropped during style updates;
// the explicit suffix makes the moving-dot layer survive cold starts/F5.
export const HNTH_SIGNAL_LAYER_ID = `${HNTH_LAYER_ID}-signal-points`;

function pointAlongLine(coordinates: [number, number][], progress: number): [number, number] {
  if (coordinates.length < 2) return coordinates[0] ?? [0, 0];
  const lengths = [0];
  for (let index = 1; index < coordinates.length; index += 1) {
    const [x1, y1] = coordinates[index - 1];
    const [x2, y2] = coordinates[index];
    lengths.push(lengths[index - 1] + Math.hypot(x2 - x1, y2 - y1));
  }
  const total = lengths[lengths.length - 1];
  if (!total) return coordinates[0];
  const target = Math.max(0, Math.min(1, progress)) * total;
  const segment = Math.max(1, lengths.findIndex((length) => length >= target));
  const start = lengths[segment - 1];
  const end = lengths[segment];
  const ratio = end === start ? 0 : (target - start) / (end - start);
  return [
    coordinates[segment - 1][0] + (coordinates[segment][0] - coordinates[segment - 1][0]) * ratio,
    coordinates[segment - 1][1] + (coordinates[segment][1] - coordinates[segment - 1][1]) * ratio,
  ];
}

function isBachLongViLine(feature: GeoJSON.Feature<GeoJSON.LineString>): boolean {
  const name = String(feature.properties?.name ?? "").trim().toLocaleLowerCase("vi-VN");
  return name.includes("bạch long vĩ");
}

function setHnthSignalData(map: MapLibreMap, lines: HnthSignalLine[], phase: number, styles: HnthStatusStyles) {
  const source = map.getSource(HNTH_SIGNAL_SOURCE_ID) as GeoJSONSource | undefined;
  if (!source) return;
  const features: GeoJSON.Feature<GeoJSON.Point>[] = [];
  for (const [lineIndex, line] of lines.entries()) {
    const style = styles[line.status];
    if (!style?.visible || !style.signal) continue;
    // Hai chấm lệch pha giúp thấy rõ chiều truyền mà vẫn giữ nét đứt gốc.
    for (const offset of [0, 0.5]) {
      const progress = (phase * line.signalSpeed + offset) % 1;
      features.push({
        type: "Feature",
        // Riêng Bạch Long Vĩ giữ độ sáng tối đa ổn định từ đầu tới cuối
        // tuyến, không áp dụng hiệu ứng mờ dần khi chấm tới endpoint.
        properties: {
          signalColor: style.color,
          signalScale: line.signalScale,
          signalOpacity: line.signalSpeed !== 1 ? 1 : 0.98,
          signalBlur: line.signalBlur,
        },
        geometry: { type: "Point", coordinates: pointAlongLine(line.coordinates, progress) },
        id: `${lineIndex}-${offset}`,
      });
    }
  }
  source.setData({ type: "FeatureCollection", features });
}

function addHnthSignalLayer(map: MapLibreMap) {
  if (map.getLayer(HNTH_SIGNAL_LAYER_ID)) return;
  map.addLayer({ id: HNTH_SIGNAL_LAYER_ID, type: "circle", source: HNTH_SIGNAL_SOURCE_ID, paint: {
    "circle-color": ["get", "signalColor"],
    // Keep the expression deliberately simple: MapLibre rejects a compound
    // arithmetic expression here during cold start, which silently omitted
    // the entire signal layer. Bạch Long Vĩ still gets a slightly larger dot.
    "circle-radius": ["case", ["==", ["get", "signalScale"], 1.35], 4, 3],
    "circle-opacity": ["coalesce", ["get", "signalOpacity"], 0.98],
    "circle-blur": ["coalesce", ["get", "signalBlur"], 0.08],
    "circle-stroke-color": ["get", "signalColor"],
    "circle-stroke-width": 1,
    "circle-stroke-opacity": 0.55,
  } });
}

function syncHnthSignalAnimation(
  map: MapLibreMap,
  layer: OperationalLayer,
  lineVisible: boolean,
  styles: HnthStatusStyles,
  statusByPointId: Map<string, HnthConnectionStatus>,
) {
  const animation = hnthSignalAnimationCache.get(map) ?? { frame: null, phase: 0, lastFrameAt: 0, lines: [], key: "" };
  const lines = layer.data.features
    .filter((feature): feature is GeoJSON.Feature<GeoJSON.LineString> => feature.geometry.type === "LineString")
    .map((feature) => ({
      coordinates: feature.geometry.coordinates as [number, number][],
      // Dùng cùng nguồn trạng thái với màu line. Điều này rất quan trọng khi
      // đổi IP giữa hai điểm: feature-state có thể đã đổi sang unconnected
      // trong khi thuộc tính volatile status trên source còn là bản cũ.
      pointId: String(feature.properties?.pointId ?? feature.id ?? ""),
      status: statusByPointId.get(String(feature.properties?.pointId ?? feature.id ?? ""))
        ?? normalizeHnthStatus(feature.properties?.status),
      // Chỉ tăng riêng Bạch Long Vĩ vì tuyến này hiển thị trên vùng biển tối
      // và cần tín hiệu rõ hơn; các tuyến khác giữ nguyên tốc độ/kích thước.
      // 1.18 là chậm hơn cấu hình cũ 1.35 một chút để chuyển động dễ theo dõi.
      signalSpeed: isBachLongViLine(feature) ? 1.18 : 1,
      signalScale: isBachLongViLine(feature) ? 1.35 : 1,
      signalBlur: isBachLongViLine(feature) ? 0.02 : 0.08,
    }))
    .filter((line) => line.pointId && (line.status === "unconnected" || line.status === "connected"));
  // The HNTH line source can be added by the map-load callback before the
  // dedicated signal source is added by the operational-layer sync. Do not
  // cache a running animation during that gap: otherwise the later sync may
  // see the same key and skip initialization even though no signal point was
  // ever written to MapLibre.
  if (!map.getSource(HNTH_SIGNAL_SOURCE_ID)) {
    if (animation.frame !== null) cancelAnimationFrame(animation.frame);
    animation.frame = null;
    animation.key = "";
    animation.lines = lines;
    hnthSignalAnimationCache.set(map, animation);
    return;
  }
  const key = JSON.stringify({ lineVisible, lines: lines.map((line) => `${line.pointId}:${line.status}:${line.signalSpeed}:${line.signalScale}:${line.signalBlur}`), styles: { unconnected: styles.unconnected, connected: styles.connected } });
  const shouldAnimate = lineVisible && lines.some((line) => styles[line.status]?.visible && styles[line.status]?.signal);
  animation.lines = lines;
  if (!shouldAnimate) {
    if (animation.frame !== null) cancelAnimationFrame(animation.frame);
    animation.frame = null;
    animation.key = key;
    setHnthSignalData(map, [], 0, styles);
    return;
  }
  if (animation.frame !== null && animation.key === key) return;
  if (animation.frame !== null) cancelAnimationFrame(animation.frame);
  animation.key = key;
  animation.phase = 0;
  animation.lastFrameAt = 0;
  // Seed the source immediately. Waiting for the first throttled animation
  // frame made the dots appear to be missing during a cold MapLibre boot.
  setHnthSignalData(map, animation.lines, animation.phase, styles);
  const tick = (now: number) => {
    const current = hnthSignalAnimationCache.get(map);
    if (!current || current.frame === null) return;
    if (now - current.lastFrameAt >= 45) {
      current.lastFrameAt = now;
      current.phase = (current.phase + 0.012) % 1;
      setHnthSignalData(map, current.lines, current.phase, useAppStore.getState().hnthLineStyles);
    }
    current.frame = requestAnimationFrame(tick);
  };
  animation.frame = requestAnimationFrame(tick);
  hnthSignalAnimationCache.set(map, animation);
}

export function normalizedHnthProperties(properties: GeoJSON.GeoJsonProperties | null | undefined): Record<string, unknown> {
  return Object.fromEntries(Object.entries(properties ?? {}).filter(([, value]) => value !== undefined));
}

export function hnthFeatureId(feature: GeoJSON.Feature): string | number | null {
  if (typeof feature.id === "string" || typeof feature.id === "number") return feature.id;
  const pointId = feature.properties?.pointId;
  return typeof pointId === "string" || typeof pointId === "number" ? pointId : null;
}

export function rememberHnthFeatureProperties(map: MapLibreMap, data: GeoJSON.FeatureCollection) {
  const snapshot = new Map<string, Record<string, unknown>>();
  for (const item of data.features) {
    const id = hnthFeatureId(item);
    if (id !== null) snapshot.set(String(id), normalizedHnthProperties(item.properties));
  }
  hnthFeaturePropertiesCache.set(map, snapshot);
}

export function syncHnthSourceData(map: MapLibreMap, source: GeoJSONSource, data: GeoJSON.FeatureCollection) {
  const previous = hnthFeaturePropertiesCache.get(map);
  const current = new Map<string, Record<string, unknown>>();
  const updates: Array<{
    id: string | number;
    addOrUpdateProperties?: Array<{ key: string; value: unknown }>;
    removeProperties?: string[];
  }> = [];
  let canApplyDiff = Boolean(previous) && previous?.size === data.features.length;

  for (const item of data.features) {
    const id = hnthFeatureId(item);
    if (id === null) {
      canApplyDiff = false;
      continue;
    }
    const key = String(id);
    const nextProperties = normalizedHnthProperties(item.properties);
    current.set(key, nextProperties);
    const previousProperties = previous?.get(key);
    if (!previousProperties) {
      canApplyDiff = false;
      continue;
    }
    // Trạng thái ping và độ trễ được vẽ bằng feature-state. Không đẩy các
    // thuộc tính thay đổi theo từng batch vào GeoJSON source, vì setData/
    // updateData khiến MapLibre dựng lại toàn bộ line/fill và gây nhấp nháy.
    const volatileProperties = new Set(["status", "statusLabel", "latencyMs", "source", "dataSource"]);
    const stablePrevious = Object.fromEntries(Object.entries(previousProperties).filter(([key]) => !volatileProperties.has(key)));
    const stableNext = Object.fromEntries(Object.entries(nextProperties).filter(([key]) => !volatileProperties.has(key)));
    const changed = JSON.stringify(stablePrevious) !== JSON.stringify(stableNext);
    if (!changed) continue;
    const addOrUpdateProperties = Object.entries(stableNext)
      .filter(([property, value]) => stablePrevious[property] !== value)
      .map(([key, value]) => ({ key, value }));
    const removeProperties = Object.keys(stablePrevious).filter((property) => !(property in stableNext));
    updates.push({ id, addOrUpdateProperties, removeProperties });
  }

  if (canApplyDiff && updates.length && typeof source.updateData === "function") {
    source.updateData({ update: updates });
  } else if (!canApplyDiff && previous) {
    source.setData(data);
  }
  hnthFeaturePropertiesCache.set(map, current);
}

export function hnthStatusColorExpression(styles: HnthStatusStyles): maplibregl.ExpressionSpecification {
  return [
    "match", ["feature-state", "hnthStatus"],
    "unconnected", styles.unconnected.visible ? styles.unconnected.color : "transparent",
    "connected", styles.connected.visible ? styles.connected.color : "transparent",
    "lost", styles.lost.visible ? styles.lost.color : "transparent",
    "transparent",
  ];
}

export function syncHnthPointFeatureStates(
  map: MapLibreMap,
  statusByPointId: Map<string, HnthConnectionStatus>,
) {
  if (!map.getSource(HNTH_LAYER_ID)) return;
  const previous = hnthFeatureStateCache.get(map) ?? new Map<string, HnthConnectionStatus>();
  const next = new Map<string, HnthConnectionStatus>();
  for (const feature of map.querySourceFeatures(HNTH_LAYER_ID)) {
    const pointId = String(feature.properties?.pointId ?? feature.id ?? "").trim();
    if (!pointId || feature.id === undefined || feature.id === null) continue;
    const status = statusByPointId.get(pointId) ?? "unknown";
    next.set(String(feature.id), status);
    if (previous.get(String(feature.id)) === status) continue;
    map.setFeatureState(
      { source: HNTH_LAYER_ID, id: feature.id },
      { hnthStatus: status },
    );
  }
  hnthFeatureStateCache.set(map, next);
}

export function hnthAreaColorExpression(styles: HnthStatusStyles): maplibregl.ExpressionSpecification {
  return [
    "match", ["feature-state", "hnthStatus"],
    "unconnected", styles.unconnected.visible ? styles.unconnected.color : "transparent",
    "connected", styles.connected.visible ? styles.connected.color : "transparent",
    "lost", styles.lost.visible ? styles.lost.color : "transparent",
    "transparent",
  ];
}

export function hnthAreaOpacityExpression(styles: HnthStatusStyles): maplibregl.ExpressionSpecification {
  return [
    "match", ["feature-state", "hnthStatus"],
    "unconnected", styles.unconnected.visible ? 0.18 : 0,
    "connected", styles.connected.visible ? 0.18 : 0,
    "lost", styles.lost.visible ? 0.18 : 0,
    0,
  ];
}

export function syncHnthAdministrativeFeatureStates(
  map: MapLibreMap,
  statusByWardCode: Map<string, HnthConnectionStatus>,
) {
  if (!map.getSource("administrative-units")) return;
  const previous = hnthAdministrativeStateCache.get(map) ?? new Map<string, HnthConnectionStatus>();
  const next = new Map<string, HnthConnectionStatus>();
  for (const feature of map.querySourceFeatures("administrative-units")) {
    if (feature.id === undefined || feature.id === null) continue;
    const wardCode = String(feature.properties?.wardCode ?? "");
    const status = statusByWardCode.get(wardCode) ?? "unknown";
    const featureKey = String(feature.id);
    next.set(featureKey, status);
    if (previous.get(featureKey) === status) continue;
    map.setFeatureState(
      { source: "administrative-units", id: feature.id },
      { hnthStatus: status },
    );
  }
  hnthAdministrativeStateCache.set(map, next);
}

export function syncHnthVisualStyles(
  map: MapLibreMap,
  layer: OperationalLayer,
  lineVisible: boolean,
  lineStyles: HnthStatusStyles,
  areaStyles: HnthStatusStyles,
  areaVisible: boolean,
  pointVisible: boolean,
  isConferencePanelActive: boolean,
  forceDynamicSync = false,
) {
  const statusByWardCode = new Map<string, HnthConnectionStatus>();
  const statusByPointId = new Map<string, HnthConnectionStatus>();
  for (const item of layer.data.features) {
    if (item.geometry.type !== "Point" || item.properties?.role !== "branch") continue;
    const wardCode = String(item.properties?.wardCode ?? "");
    if (wardCode) statusByWardCode.set(wardCode, normalizeHnthStatus(item.properties?.status));
    const pointId = String(item.properties?.pointId ?? item.id ?? "").trim();
    if (pointId) statusByPointId.set(pointId, normalizeHnthStatus(item.properties?.status));
  }
  const statusKey = [...statusByPointId.entries()].map(([pointId, status]) => `${pointId}:${status}`).join("|");
  const staticKey = JSON.stringify({ lineVisible, areaVisible, pointVisible, isConferencePanelActive, lineStyles, areaStyles });
  const previous = hnthVisualSyncCache.get(map);
  if (!forceDynamicSync && previous?.staticKey === staticKey && previous.dynamicKey === statusKey) return;
  hnthVisualSyncCache.set(map, { staticKey, dynamicKey: statusKey });
  const colorExpression = hnthStatusColorExpression(lineStyles);
  const areaColorExpression = hnthAreaColorExpression(areaStyles);
  const areaOpacityExpression = hnthAreaOpacityExpression(areaStyles);
  const staticChanged = previous?.staticKey !== staticKey;
  const dynamicChanged = forceDynamicSync || previous?.dynamicKey !== statusKey;
  for (const id of [`${HNTH_LAYER_ID}-line-glow`, `${HNTH_LAYER_ID}-line`]) {
    if (!map.getLayer(id)) continue;
    if (staticChanged) {
      map.setPaintProperty(id, "line-color", colorExpression);
      map.setLayoutProperty(id, "visibility", lineVisible ? "visible" : "none");
    }
  }
  // Switch "Hiển thị sơ đồ kết nối" chỉ điều khiển các đường cung. Điểm trung
  // tâm/nhánh vẫn hiện khi tắt switch, nhưng chỉ trong menu Hội nghị truyền hình.
  // Khi chuyển sang menu khác, ẩn toàn bộ điểm HNTH để không che các lớp bản đồ.
  for (const id of [`${HNTH_LAYER_ID}-hub-halo`, `${HNTH_LAYER_ID}-hub-point`, `${HNTH_LAYER_ID}-branch-point`]) {
    if (!map.getLayer(id)) continue;
    if (staticChanged) map.setLayoutProperty(id, "visibility", isConferencePanelActive && pointVisible ? "visible" : "none");
  }
  if (staticChanged && map.getLayer(`${HNTH_LAYER_ID}-branch-point`)) {
    map.setPaintProperty(`${HNTH_LAYER_ID}-branch-point`, "circle-color", colorExpression);
  }
  if (dynamicChanged) {
    syncHnthPointFeatureStates(map, statusByPointId);
    syncHnthAdministrativeFeatureStates(map, statusByWardCode);
  }
  // Chạy sau khi statusByPointId đã được đồng bộ để chấm tín hiệu luôn khớp
  // màu line, kể cả trường hợp người dùng hoán đổi IP giữa hai điểm.
  syncHnthSignalAnimation(map, layer, lineVisible, lineStyles, statusByPointId);
  const beforeId = map.getLayer(`${HNTH_LAYER_ID}-line-glow`) ? `${HNTH_LAYER_ID}-line-glow` : undefined;
  const areaId = `${HNTH_LAYER_ID}-area`;
  if (!map.getLayer(areaId)) {
    map.addLayer({
      id: areaId,
      type: "fill",
      source: "administrative-units",
      layout: { visibility: "none" },
      paint: { "fill-color": areaColorExpression, "fill-opacity": areaOpacityExpression },
    }, beforeId);
  } else if (staticChanged) {
    map.setPaintProperty(areaId, "fill-color", areaColorExpression);
    map.setPaintProperty(areaId, "fill-opacity", areaOpacityExpression);
  }
  // Màu nền trạng thái HNTH chỉ thuộc menu Hội nghị truyền hình. Khi đổi
  // menu, luôn ẩn lớp này dù switch vẫn được lưu ở trạng thái bật.
  if (map.getLayer(areaId) && staticChanged) map.setLayoutProperty(areaId, "visibility", isConferencePanelActive && areaVisible ? "visible" : "none");
}

export function addHnthLayer(map: MapLibreMap, layer: OperationalLayer) {
  // React's map-load callback and the operational-layer effect can race on a
  // cold start. The first call may leave the sources present while the
  // second call hits the old early return before adding the signal layer.
  // Complete the missing signal layer instead of treating source existence as
  // proof that the whole HNTH layer is initialized.
  if (map.getSource(layer.id) && map.getSource(HNTH_SIGNAL_SOURCE_ID) && map.getLayer(`${layer.id}-line`)) {
    addHnthSignalLayer(map);
    return;
  }
  if (!map.getSource(layer.id)) map.addSource(layer.id, { type: "geojson", data: layer.data, promoteId: "pointId" });
  // Tín hiệu là một lớp điểm riêng. Nét đứt của line giữ nguyên; lớp này chỉ
  // thêm chấm màu chạy khi người dùng bật checkbox cho Chờ kết nối/Đã kết nối.
  if (!map.getSource(HNTH_SIGNAL_SOURCE_ID)) map.addSource(HNTH_SIGNAL_SOURCE_ID, { type: "geojson", data: { type: "FeatureCollection", features: [] } });
  const lineFilter: maplibregl.FilterSpecification = ["==", ["geometry-type"], "LineString"];
  const hubFilter: maplibregl.FilterSpecification = ["all", ["==", ["geometry-type"], "Point"], ["==", ["get", "role"], "hub"]];
  const branchFilter: maplibregl.FilterSpecification = ["all", ["==", ["geometry-type"], "Point"], ["==", ["get", "role"], "branch"]];
  const preferences = useAppStore.getState();
  const statusColor = hnthStatusColorExpression(preferences.hnthLineStyles);

  map.addLayer({ id: `${layer.id}-line-glow`, type: "line", source: layer.id, filter: lineFilter, paint: { "line-color": statusColor, "line-width": ["interpolate", ["linear"], ["zoom"], 7, 4, 14, 7], "line-opacity": 0.16 } });
  map.addLayer({ id: `${layer.id}-line`, type: "line", source: layer.id, filter: lineFilter, paint: { "line-color": statusColor, "line-width": ["interpolate", ["linear"], ["zoom"], 7, 1.2, 14, 2.6], "line-opacity": 0.94, "line-dasharray": [3, 2] } });
  addHnthSignalLayer(map);
  map.addLayer({ id: `${layer.id}-hub-halo`, type: "circle", source: layer.id, filter: hubFilter, paint: { "circle-color": "#22d3ee", "circle-radius": 14, "circle-opacity": 0.18 } });
  map.addLayer({ id: `${layer.id}-hub-point`, type: "circle", source: layer.id, filter: hubFilter, paint: { "circle-color": "#06b6d4", "circle-radius": 8, "circle-stroke-color": "#0e7490", "circle-stroke-width": 1.2 } });
  map.addLayer({ id: `${layer.id}-branch-point`, type: "circle", source: layer.id, filter: branchFilter, paint: {
    "circle-color": statusColor,
    // Không vẽ mốc trước khi endpoint được quét. Feature-state được reset về
    // unknown khi bật monitoring và chuyển sang online/offline khi agent trả kết quả.
    "circle-opacity": ["match", ["feature-state", "hnthStatus"], "unknown", 0, 1],
    "circle-radius": ["interpolate", ["linear"], ["zoom"], 7, 2.5, 14, 5],
    "circle-stroke-color": "#ffffff",
    "circle-stroke-opacity": ["match", ["feature-state", "hnthStatus"], "unknown", 0, 1],
    "circle-stroke-width": 1.2,
  } });

  for (const suffix of ["line", "hub-point", "branch-point"] as const) {
    const layerId = `${layer.id}-${suffix}`;
    map.on("click", layerId, (event) => {
      if (!canInspectHnthFeature()) return;
      if (suffix === "line" && hasHnthPointAt(map, event.point)) return;
      const selected = event.features?.[0];
      if (!selected) return;
      const coordinates = selected.geometry.type === "Point" ? selected.geometry.coordinates as [number, number] : [event.lngLat.lng, event.lngLat.lat] as [number, number];
      restoreHaiphongOverviewIfZoomedOut(map, coordinates);
      showHnthPointPopup(map, coordinates, selected.properties);
    });
    map.on("mouseenter", layerId, () => { if (canInspectHnthFeature()) map.getCanvas().style.cursor = "pointer"; });
    map.on("mouseleave", layerId, () => { map.getCanvas().style.cursor = ""; });
  }
}

export function hasHnthPointAt(map: MapLibreMap, screenPoint: maplibregl.PointLike) {
  // Ở menu khác, điểm HNTH không được chặn thao tác xem lớp dữ liệu nằm dưới.
  if (!canInspectHnthFeature()) return false;
  const pointLayerIds = [`${HNTH_LAYER_ID}-hub-point`, `${HNTH_LAYER_ID}-branch-point`].filter((id) => Boolean(map.getLayer(id)));
  return pointLayerIds.length > 0 && map.queryRenderedFeatures(screenPoint, { layers: pointLayerIds }).length > 0;
}

export function canInspectHnthFeature() {
  return Boolean(useAppStore.getState().layers.some((layer) => layer.id === HNTH_LAYER_ID));
}

export function showHnthPointPopup(
  _map: MapLibreMap,
  _coordinates: [number, number],
  properties: Record<string, unknown> | null | undefined,
) {
  const pointId = String(properties?.pointId ?? "");
  // Mọi cách chọn điểm HNTH (bấm chấm, đường nối hoặc toàn vùng địa giới)
  // đều cập nhật cùng lựa chọn với thẻ Cấu hình điểm ở menu bên trái.
  if (!pointId) return;
  const state = useAppStore.getState();
  state.setSelectedHnthPointId(pointId);
  if (window.matchMedia("(max-width: 760px)").matches) return;
  const wardCode = String(properties?.wardCode ?? "");
  const administrativeId = state.administrativeUnits.find((unit) => String(unit.wardCode ?? "") === wardCode)?.id;
  emitAppEvent("map:context-info", { kind: "hnth", pointId, administrativeId });
}
