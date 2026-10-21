// Lớp dữ liệu vận hành (camera, UBND, OSM...): thêm/ẩn/xếp lớp, gom cụm, popup.
import maplibregl, { type Map as MapLibreMap } from "maplibre-gl";
import { booleanPointInPolygon, feature } from "@turf/turf";
import type { Feature, MultiPolygon, Point as GeoJSONPoint, Polygon } from "geojson";
import { useAppStore } from "../../../core/store";
import type { AdministrativeUnit, OperationalLayer } from "../../../core/types";
import { HNTH_LAYER_ID } from "../../layers/hnth-data-provider";
import { addHnthLayer, hasHnthPointAt } from "./hnth-layer";
import { restoreHaiphongOverviewIfZoomedOut } from "./viewport";

// Màu điểm UBND theo loại đơn vị hành chính.
// Xã và phường dùng hai sắc xanh khác nhau; đặc khu dùng tím nhạt.
export const UBND_POINT_COLORS = {
  "xã": "#14B8A6",
  "phường": "#3B82F6",
  "đặc khu": "#C084FC",
} as const;

export function clusterRadiusForLevel(level: number) {
  // 10 keeps the previous 42 px behavior. At level 1, two 14 px markers
  // need to be visually touching before MapLibre combines them.
  return Math.round(8 + ((Math.max(1, Math.min(10, level)) - 1) * 34) / 9);
}

export function buildContextualOperationalLayers(
  layers: OperationalLayer[],
  administrativeUnits: AdministrativeUnit[],
  selectedAdministrativeIds: number[],
): OperationalLayer[] {
  if (selectedAdministrativeIds.length === 0) return layers;
  const selectedIdSet = new Set(selectedAdministrativeIds);
  const selectedBoundaries = administrativeUnits
    .filter((unit) => selectedIdSet.has(unit.id) && (unit.geometry.type === "Polygon" || unit.geometry.type === "MultiPolygon"))
    .map((unit) => feature(unit.geometry as Polygon | MultiPolygon));

  return layers.map((layer) => {
    if (layer.id !== "government-ubnd") return layer;
    const features = layer.data.features.filter((candidate) => (
      candidate.geometry.type === "Point"
      && selectedBoundaries.some((boundary) => booleanPointInPolygon(candidate as Feature<GeoJSONPoint>, boundary))
    ));
    return {
      ...layer,
      // Chỉ bật tạm thời trên canvas; `layerVisibility` vẫn giữ nguyên cấu hình.
      visible: true,
      count: features.length,
      data: { ...layer.data, features },
    };
  });
}

export function raiseOperationalLayers(map: MapLibreMap, layers: ReturnType<typeof useAppStore.getState>["layers"]) {
  for (const layer of layers) {
    if (!layer.visible || layer.data.features.length === 0) continue;
    // Thứ tự này giữ viền đệm dưới nét đường, số cụm trên vòng tròn cụm.
    for (const suffix of ["fill", "line-glow", "line-casing", "line", "cluster", "point", "hub-halo", "hub-point", "branch-point", "cluster-count"]) {
      const id = `${layer.id}-${suffix}`;
      if (map.getLayer(id)) map.moveLayer(id);
    }
  }
}

export function setOperationalLayerVisibility(map: MapLibreMap, layerId: string, visibility: "visible" | "none") {
  for (const suffix of ["fill", "line-glow", "line-casing", "line", "point", "hub-halo", "hub-point", "branch-point", "cluster", "cluster-count"]) {
    const id = `${layerId}-${suffix}`;
    if (map.getLayer(id)) map.setLayoutProperty(id, "visibility", visibility);
  }
}

export function addOperationalLayer(map: MapLibreMap, layer: ReturnType<typeof useAppStore.getState>["layers"][number], clusterLevel: number) {
  // React có thể chạy lại effect đồng bộ lớp khi đổi menu (đặc biệt trong
  // StrictMode). MapLibre không cho phép addSource trùng id; coi lớp đã có
  // source là đã được khởi tạo để tránh làm sập toàn bộ MapCanvas.
  if (map.getSource(layer.id)) return;
  if (layer.id === HNTH_LAYER_ID) {
    addHnthLayer(map, layer);
    return;
  }
  const isLinearLayer = layer.category === "hydrology" || layer.geometryMode === "line";
  const isUbndLayer = layer.id === "government-ubnd";
  map.addSource(layer.id, { type: "geojson", data: layer.data, cluster: !isLinearLayer, clusterMaxZoom: 13, clusterRadius: clusterRadiusForLevel(clusterLevel) });
  if (isLinearLayer) {
    if (layer.category === "hydrology") {
      map.addLayer({ id: `${layer.id}-fill`, type: "fill", source: layer.id, filter: ["==", ["geometry-type"], "Polygon"], paint: { "fill-color": layer.color, "fill-opacity": 0.3 } });
    }
    if (layer.category === "transport") {
      map.addLayer({ id: `${layer.id}-line-casing`, type: "line", source: layer.id, paint: { "line-color": "#07131e", "line-width": ["interpolate", ["linear"], ["zoom"], 8, 5, 14, 9], "line-opacity": 0.84 } });
    }
    map.addLayer({ id: `${layer.id}-line`, type: "line", source: layer.id, paint: { "line-color": layer.color, "line-width": ["interpolate", ["linear"], ["zoom"], 8, layer.category === "transport" ? 3 : 1.2, 14, layer.category === "transport" ? 6 : 3.5], "line-opacity": 1 } });
    map.on("click", `${layer.id}-line`, (event) => {
      if (!canInspectOperationalFeature()) return;
      if (hasHnthPointAt(map, event.point)) return;
      const item = event.features?.[0];
      if (!item) return;
      restoreHaiphongOverviewIfZoomedOut(map, [event.lngLat.lng, event.lngLat.lat]);
      new maplibregl.Popup({ offset: 12, closeButton: false })
        .setLngLat(event.lngLat)
        .setHTML(buildOperationalPopupHtml(layer.name, item.properties))
        .addTo(map);
    });
    map.on("mouseenter", `${layer.id}-line`, () => {
      if (canInspectOperationalFeature()) map.getCanvas().style.cursor = "pointer";
    });
    map.on("mouseleave", `${layer.id}-line`, () => { map.getCanvas().style.cursor = ""; });
  } else {
    const pointColor: maplibregl.ExpressionSpecification | string = isUbndLayer
      ? ["match", ["get", "administrativeType"], "xã", UBND_POINT_COLORS.xã, "phường", UBND_POINT_COLORS.phường, "đặc khu", UBND_POINT_COLORS["đặc khu"], layer.color]
      : layer.color;
    // Riêng điểm/cụm UBND thu nhỏ còn 2/3 để bản đồ đỡ dày, các lớp khác giữ nguyên kích thước.
    map.addLayer({ id: `${layer.id}-cluster`, type: "circle", source: layer.id, filter: ["has", "point_count"], paint: { "circle-color": layer.color, "circle-radius": isUbndLayer ? ["step", ["get", "point_count"], 11.3, 10, 15.3] : ["step", ["get", "point_count"], 17, 10, 23], "circle-stroke-color": "#07131e", "circle-stroke-width": isUbndLayer ? 2 : 3 } });
    map.addLayer({ id: `${layer.id}-cluster-count`, type: "symbol", source: layer.id, filter: ["has", "point_count"], layout: { "text-field": ["get", "point_count_abbreviated"], "text-size": isUbndLayer ? 9 : 12 }, paint: { "text-color": "#061019" } });
    map.addLayer({ id: `${layer.id}-point`, type: "circle", source: layer.id, filter: ["!", ["has", "point_count"]], paint: { "circle-color": pointColor, "circle-radius": isUbndLayer ? 4.7 : 7, "circle-stroke-color": "#eaf6ff", "circle-stroke-width": isUbndLayer ? 1.3 : 2 } });
    for (const clusterSuffix of ["cluster", "cluster-count"] as const) {
      map.on("click", `${layer.id}-${clusterSuffix}`, (event) => {
        if (!canInspectOperationalFeature()) return;
        restoreHaiphongOverviewIfZoomedOut(map, [event.lngLat.lng, event.lngLat.lat]);
      });
    }
    map.on("click", `${layer.id}-point`, (event) => {
      if (!canInspectOperationalFeature()) return;
      if (hasHnthPointAt(map, event.point)) return;
      const feature = event.features?.[0];
      const coordinates = (feature?.geometry as GeoJSON.Point | undefined)?.coordinates;
      if (!feature || !coordinates) return;
      restoreHaiphongOverviewIfZoomedOut(map, coordinates as [number, number]);
      new maplibregl.Popup({ offset: 12, closeButton: false })
        .setLngLat(coordinates as [number, number])
        .setHTML(buildOperationalPopupHtml(layer.name, feature.properties))
        .addTo(map);
    });
    map.on("mouseenter", `${layer.id}-point`, () => {
      if (canInspectOperationalFeature()) map.getCanvas().style.cursor = "pointer";
    });
    map.on("mouseleave", `${layer.id}-point`, () => { map.getCanvas().style.cursor = ""; });
  }
}
export const operationalSourceDataCache = new WeakMap<MapLibreMap, Map<string, unknown>>();

export function hasInspectableOperationalFeatureAt(map: MapLibreMap, screenPoint: maplibregl.PointLike) {
  if (!canInspectOperationalFeature()) return false;
  const interactiveLayerIds = useAppStore.getState().layers.flatMap((layer) => (
    [`${layer.id}-point`, `${layer.id}-line`]
      .filter((id) => Boolean(map.getLayer(id)) && map.getLayoutProperty(id, "visibility") !== "none")
  ));
  return interactiveLayerIds.length > 0
    && map.queryRenderedFeatures(screenPoint, { layers: interactiveLayerIds }).length > 0;
}

export function canInspectOperationalFeature() {
  const state = useAppStore.getState();
  return state.activePanel === "layers"
    || state.activePanel === "conference"
    || (state.activePanel === "zones" && (state.zoneMode === "draw" || state.zoneMode === "info"));
}

export function buildOperationalPopupHtml(layerName: string, properties: Record<string, unknown> | null | undefined) {
  const values = properties ?? {};
  const details = [
    values.roleLabel ? `Vai trò: ${String(values.roleLabel)}` : null,
    values.ref ? `Mã / ký hiệu: ${String(values.ref)}` : null,
    values.administrativeType ? `Phân loại: ${String(values.administrativeType)}` : values.type ? `Phân loại: ${String(values.type)}` : null,
    values.address ? `Địa chỉ: ${String(values.address)}` : null,
    values.ipAddress ? `IP: ${String(values.ipAddress)}` : null,
    values.gateway ? `Gateway: ${String(values.gateway)}` : null,
    values.statusLabel ? `Trạng thái: ${String(values.statusLabel)}` : values.status ? `Trạng thái: ${String(values.status)}` : null,
    `Nguồn: ${String(values.source ?? "Dữ liệu vận hành")}`,
  ].filter((value): value is string => Boolean(value));
  return `<div class="map-popup"><span>${escapeHtml(layerName)}</span><strong>${escapeHtml(String(values.name ?? "Đối tượng"))}</strong>${details.map((detail) => `<small>${escapeHtml(detail)}</small>`).join("")}</div>`;
}

export function escapeHtml(value: string) {
  return value.replace(/[&<>'"]/g, (character) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" })[character] ?? character);
}
