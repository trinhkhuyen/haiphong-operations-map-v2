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
  if (map.getSource(layer.id)) return;
  map.addSource(layer.id, { type: "geojson", data: layer.data, promoteId: "pointId" });
  const lineFilter: maplibregl.FilterSpecification = ["==", ["geometry-type"], "LineString"];
  const hubFilter: maplibregl.FilterSpecification = ["all", ["==", ["geometry-type"], "Point"], ["==", ["get", "role"], "hub"]];
  const branchFilter: maplibregl.FilterSpecification = ["all", ["==", ["geometry-type"], "Point"], ["==", ["get", "role"], "branch"]];
  const preferences = useAppStore.getState();
  const statusColor = hnthStatusColorExpression(preferences.hnthLineStyles);

  map.addLayer({ id: `${layer.id}-line-glow`, type: "line", source: layer.id, filter: lineFilter, paint: { "line-color": statusColor, "line-width": ["interpolate", ["linear"], ["zoom"], 7, 4, 14, 7], "line-opacity": 0.16 } });
  map.addLayer({ id: `${layer.id}-line`, type: "line", source: layer.id, filter: lineFilter, paint: { "line-color": statusColor, "line-width": ["interpolate", ["linear"], ["zoom"], 7, 1.2, 14, 2.6], "line-opacity": 0.94, "line-dasharray": [3, 2] } });
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
