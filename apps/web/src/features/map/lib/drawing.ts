// Công cụ vẽ Terra Draw: marker chỉnh sửa/bán kính, mô tả hình, tổng hợp vùng khoanh.
import maplibregl, { type Map as MapLibreMap } from "maplibre-gl";
import { area as turfArea, booleanIntersects, booleanPointInPolygon, centroid, circle, distance, feature, point } from "@turf/turf";
import type { Feature, MultiPolygon, Point as GeoJSONPoint, Polygon } from "geojson";
import { TerraDraw, type GeoJSONStoreFeatures, type HexColor } from "terra-draw";
import { useAppStore } from "../../../core/store";
import type { DrawFeatureInfo } from "../../../core/types";

export interface ZoneSummaryItem {
  id: string;
  label: string;
  count: number;
  color: string;
}

export interface ZoneSummary {
  zoneCount: number;
  drawnZoneCount: number;
  administrativeZoneCount: number;
  totalAreaSquareMeters: number;
  estimatedPopulation: number;
  items: ZoneSummaryItem[];
}

export interface DrawEditMarkerHandle {
  marker: maplibregl.Marker;
  kind: "edge-label" | "move-handle" | "radius-handle";
}

// Terra Draw can emit a transient deselect while custom MapLibre markers edit
// geometry. Track the edited feature outside the marker DOM so a marker redraw
// cannot accidentally clear the active selection mid-drag.
export const drawEditDeselectGuards = new Set<string>();

export function featureColor(property: "fillColor" | "outlineColor", fallback: HexColor) {
  return (feature: { properties?: Record<string, unknown> }) => {
    const value = feature.properties?.[property];
    return typeof value === "string" && value.startsWith("#") ? value as HexColor : fallback;
  };
}

export function featureNumber(property: "fillOpacity", fallback: number) {
  return (feature: { properties?: Record<string, unknown> }) => {
    const value = feature.properties?.[property];
    return typeof value === "number" ? value : fallback;
  };
}

export function formatMapRadius(meters: number) {
  return meters >= 1000
    ? `${new Intl.NumberFormat("vi-VN", { maximumFractionDigits: 1 }).format(meters / 1000)} km`
    : `${Math.round(meters)} m`;
}

export function formatSummaryArea(squareMeters: number) {
  return `${new Intl.NumberFormat("vi-VN", { maximumFractionDigits: 1 }).format(squareMeters / 1_000_000)} km²`;
}

export function syncRadiusMarkers(map: MapLibreMap, draw: TerraDraw, markers: Map<string | number, maplibregl.Marker>) {
  const activeIds = new Set<string | number>();
  for (const snapshot of draw.getSnapshot()) {
    if (snapshot.id === undefined || snapshot.properties.mode !== "circle" || snapshot.geometry.type !== "Polygon") continue;
    const info = describeDrawFeature(draw, snapshot.id);
    if (!info?.radiusMeters) continue;
    activeIds.add(snapshot.id);
    let marker = markers.get(snapshot.id);
    if (!marker) {
      const element = document.createElement("div");
      element.className = "radius-map-label";
      marker = new maplibregl.Marker({ element, anchor: "bottom", offset: [0, -4] })
        .setLngLat(info.center)
        .addTo(map);
      markers.set(snapshot.id, marker);
    }
    marker.getElement().textContent = formatMapRadius(info.radiusMeters);
    marker.setLngLat(info.center);
  }
  for (const [id, marker] of markers) {
    if (activeIds.has(id)) continue;
    marker.remove();
    markers.delete(id);
  }
}

export function syncDrawEditMarkers(
  map: MapLibreMap,
  draw: TerraDraw,
  selectedId: string | number | null,
  markers: Map<string, DrawEditMarkerHandle>,
) {
  const activeKeys = new Set<string>();
  if (selectedId !== null) {
    const snapshot = draw.getSnapshotFeature(selectedId);
    if (snapshot?.geometry.type === "Polygon") {
      const mode = snapshot.properties.mode;
      const ring = (snapshot.geometry.coordinates[0] ?? []) as [number, number][];
      const info = describeDrawFeature(draw, selectedId);

      if ((mode === "polygon" || mode === "rectangle") && info && isValidLngLat(info.center)) {
        const moveKey = `${selectedId}:move`;
        activeKeys.add(moveKey);
        let moveHandle = markers.get(moveKey);
        if (!moveHandle) {
          const element = document.createElement("button");
          element.type = "button";
          element.className = "draw-move-handle";
          element.title = "Kéo để di chuyển toàn bộ hình";
          element.setAttribute("aria-label", "Di chuyển toàn bộ hình");
          const marker = new maplibregl.Marker({ element, anchor: "center" })
            .setLngLat(info.center)
            .addTo(map);
          element.addEventListener("mousedown", (event) => {
            if (event.button !== 0) return;
            const current = draw.getSnapshotFeature(selectedId);
            if (current?.geometry.type !== "Polygon") return;
            const originalRing = (current.geometry.coordinates[0] as [number, number][]).map(([lng, lat]) => [lng, lat] as [number, number]);
            const originalCenter = describeDrawFeature(draw, selectedId)?.center ?? info.center;
            const wasDragPanEnabled = map.dragPan.isEnabled();
            drawEditDeselectGuards.add(String(selectedId));
            element.dataset.drawEditDragging = "true";
            if (wasDragPanEnabled) map.dragPan.disable();

            const moveShape = (moveEvent: MouseEvent) => {
              moveEvent.preventDefault();
              moveEvent.stopPropagation();
              const position = pointerEventLngLat(map, moveEvent);
              const deltaLng = position[0] - originalCenter[0];
              const deltaLat = position[1] - originalCenter[1];
              marker.setLngLat(position);
              draw.updateFeatureGeometry(selectedId, {
                type: "Polygon",
                coordinates: [originalRing.map(([lng, lat]) => [
                  Number((lng + deltaLng).toFixed(6)),
                  Number((lat + deltaLat).toFixed(6)),
                ])],
              });
            };
            const endShapeMove = (endEvent: MouseEvent) => {
              endEvent.preventDefault();
              endEvent.stopPropagation();
              window.removeEventListener("mousemove", moveShape, true);
              window.removeEventListener("mouseup", endShapeMove, true);
              if (wasDragPanEnabled) map.dragPan.enable();
              finishDrawMarkerEdit(map, draw, selectedId, markers);
              window.setTimeout(() => {
                drawEditDeselectGuards.delete(String(selectedId));
                delete element.dataset.drawEditDragging;
              }, 100);
            };
            window.addEventListener("mousemove", moveShape, true);
            window.addEventListener("mouseup", endShapeMove, true);
            event.preventDefault();
            event.stopPropagation();
          });
          for (const eventName of ["click", "dblclick"]) {
            element.addEventListener(eventName, (event) => {
              event.preventDefault();
              event.stopPropagation();
              if (eventName === "click") window.setTimeout(() => {
              drawEditDeselectGuards.delete(String(selectedId));
              delete element.dataset.drawEditDragging;
              }, 100);
            });
          }
          moveHandle = { marker, kind: "move-handle" };
          markers.set(moveKey, moveHandle);
        }
        moveHandle.marker.setLngLat(info.center);

        for (let index = 0; index < ring.length - 1; index += 1) {
          const start = ring[index];
          const end = ring[index + 1];
          if (!isValidLngLat(start) || !isValidLngLat(end)) continue;
          const edgeKey = `${selectedId}:edge:${index}`;
          activeKeys.add(edgeKey);
          let edgeHandle = markers.get(edgeKey);
          if (!edgeHandle) {
            const element = document.createElement("span");
            element.className = "draw-edge-length-label";
            const marker = new maplibregl.Marker({ element, anchor: "center" }).setLngLat(start).addTo(map);
            edgeHandle = { marker, kind: "edge-label" };
            markers.set(edgeKey, edgeHandle);
          }
          const edgeMeters = distance(point(start), point(end), { units: "meters" });
          edgeHandle.marker.getElement().textContent = formatMapRadius(edgeMeters);
          edgeHandle.marker.setLngLat([(start[0] + end[0]) / 2, (start[1] + end[1]) / 2]);
        }
      }

      if (mode === "circle" && info?.radiusMeters && isValidLngLat(info.center) && isValidLngLat(ring[0])) {
        const radiusKey = `${selectedId}:radius`;
        activeKeys.add(radiusKey);
        let radiusHandle = markers.get(radiusKey);
        if (!radiusHandle) {
          const element = document.createElement("button");
          element.type = "button";
          element.className = "radius-resize-handle";
          element.title = "Kéo để thay đổi bán kính";
          element.setAttribute("aria-label", "Thay đổi bán kính đường tròn");
          const marker = new maplibregl.Marker({ element, anchor: "center" })
            .setLngLat(ring[0])
            .addTo(map);
          element.addEventListener("mousedown", (event) => {
            if (event.button !== 0) return;
            const fixedCenter = describeDrawFeature(draw, selectedId)?.center ?? info.center;
            const wasDragPanEnabled = map.dragPan.isEnabled();
            drawEditDeselectGuards.add(String(selectedId));
            element.dataset.drawEditDragging = "true";
            if (wasDragPanEnabled) map.dragPan.disable();

            const resizeCircle = (moveEvent: MouseEvent) => {
              moveEvent.preventDefault();
              moveEvent.stopPropagation();
              const position = pointerEventLngLat(map, moveEvent);
              marker.setLngLat(position);
              const radiusMeters = Math.max(5, distance(point(fixedCenter), point(position), { units: "meters" }));
              const resized = circle(fixedCenter, radiusMeters, { steps: 96, units: "meters" });
              draw.updateFeatureGeometry(selectedId, {
                ...resized.geometry,
                coordinates: resized.geometry.coordinates.map((coordinates) => coordinates.map(([lng, lat]) => [
                  Number(lng.toFixed(6)),
                  Number(lat.toFixed(6)),
                ])),
              });
            };
            const endCircleResize = (endEvent: MouseEvent) => {
              endEvent.preventDefault();
              endEvent.stopPropagation();
              window.removeEventListener("mousemove", resizeCircle, true);
              window.removeEventListener("mouseup", endCircleResize, true);
              if (wasDragPanEnabled) map.dragPan.enable();
              finishDrawMarkerEdit(map, draw, selectedId, markers);
              window.setTimeout(() => {
                drawEditDeselectGuards.delete(String(selectedId));
                delete element.dataset.drawEditDragging;
              }, 100);
            };
            window.addEventListener("mousemove", resizeCircle, true);
            window.addEventListener("mouseup", endCircleResize, true);
            event.preventDefault();
            event.stopPropagation();
          });
          for (const eventName of ["click", "dblclick"]) {
            element.addEventListener(eventName, (event) => {
              event.preventDefault();
              event.stopPropagation();
              if (eventName === "click") window.setTimeout(() => {
              drawEditDeselectGuards.delete(String(selectedId));
              delete element.dataset.drawEditDragging;
              }, 100);
            });
          }
          radiusHandle = { marker, kind: "radius-handle" };
          markers.set(radiusKey, radiusHandle);
        }
        radiusHandle.marker.setLngLat(ring[0]);
      }
    }
    if (snapshot?.geometry.type === "LineString" && snapshot.properties.mode === "multilinestring") {
      const coordinates = snapshot.geometry.coordinates as [number, number][];
      for (let index = 0; index < coordinates.length - 1; index += 1) {
        const start = coordinates[index];
        const end = coordinates[index + 1];
        if (!isValidLngLat(start) || !isValidLngLat(end)) continue;
        const segmentKey = `${selectedId}:segment:${index}`;
        activeKeys.add(segmentKey);
        let segmentHandle = markers.get(segmentKey);
        if (!segmentHandle) {
          const element = document.createElement("span");
          element.className = "draw-edge-length-label";
          const marker = new maplibregl.Marker({ element, anchor: "center" }).setLngLat(start).addTo(map);
          segmentHandle = { marker, kind: "edge-label" };
          markers.set(segmentKey, segmentHandle);
        }
        const segmentMeters = distance(point(start), point(end), { units: "meters" });
        segmentHandle.marker.getElement().textContent = formatMapRadius(segmentMeters);
        segmentHandle.marker.setLngLat([(start[0] + end[0]) / 2, (start[1] + end[1]) / 2]);
      }
    }
  }

  for (const [key, handle] of markers) {
    if (activeKeys.has(key)) continue;
    handle.marker.remove();
    markers.delete(key);
  }
}

export function pointerEventLngLat(map: MapLibreMap, event: MouseEvent): [number, number] {
  const bounds = map.getContainer().getBoundingClientRect();
  const lngLat = map.unproject([event.clientX - bounds.left, event.clientY - bounds.top]);
  return [lngLat.lng, lngLat.lat];
}

export function isValidLngLat(value: unknown): value is [number, number] {
  return Array.isArray(value)
    && value.length >= 2
    && Number.isFinite(value[0])
    && Number.isFinite(value[1]);
}

export function finishDrawMarkerEdit(
  map: MapLibreMap,
  draw: TerraDraw,
  id: string | number,
  markers: Map<string, DrawEditMarkerHandle>,
) {
  const state = useAppStore.getState();
  // Resetting an already-active select mode emits a deselect event in Terra Draw.
  // Keep the current mode so releasing an edit handle does not clear selection.
  if (draw.getMode() !== "select") draw.setMode("select");
  state.setDrawMode("select");
  state.setSelectedDrawFeatureId(id);
  state.setSelectedDrawFeatureInfo(describeDrawFeature(draw, id));
  state.setZoneMode("info");
  // Re-select after the marker's pointer-up/click sequence. Otherwise the map
  // can interpret the release as a deselect and hide the edit handles.
  const restoreSelection = () => {
    const snapshot = draw.getSnapshotFeature(id);
    if (snapshot && snapshot.properties.selected !== true) draw.selectFeature(id);
    const currentState = useAppStore.getState();
    currentState.setSelectedDrawFeatureId(id);
    currentState.setSelectedDrawFeatureInfo(describeDrawFeature(draw, id));
    currentState.setZoneMode("info");
    syncDrawEditMarkers(map, draw, id, markers);
  };
  // The synthetic click generated after a marker drag can arrive after the
  // next animation frame. A zero-delay task runs after that click and restores
  // the edited object as the active selection without visible interaction lag.
  window.setTimeout(restoreSelection, 0);
}

export function cleanDrawFeatureForStorage(featureValue: GeoJSONStoreFeatures) {
  const featureCopy = JSON.parse(JSON.stringify(featureValue)) as GeoJSONStoreFeatures;
  const properties = { ...(featureCopy.properties ?? {}) };
  // Các thuộc tính dưới đây chỉ phục vụ phiên chọn/sửa hiện tại của Terra Draw.
  // Không lưu chúng để đối tượng khôi phục sau reload không mang theo điểm điều khiển cũ.
  delete properties.selected;
  delete properties.currentlyDrawing;
  delete properties.coordinatePointIds;
  delete properties.edited;
  featureCopy.properties = properties;
  return featureCopy;
}

export function buildZoneSummary(draw: TerraDraw | null): ZoneSummary {
  const state = useAppStore.getState();
  const zones: Feature<Polygon | MultiPolygon>[] = [];
  for (const snapshot of draw?.getSnapshot() ?? []) {
    if (snapshot.geometry.type === "Polygon") zones.push(feature(snapshot.geometry as Polygon));
  }
  const drawnZoneCount = zones.length;
  for (const unit of state.administrativeUnits) {
    if (!state.selectedAdministrativeIds.includes(unit.id)) continue;
    if (unit.geometry.type === "Polygon" || unit.geometry.type === "MultiPolygon") {
      zones.push(feature(unit.geometry as Polygon | MultiPolygon));
    }
  }
  const administrativeZoneCount = zones.length - drawnZoneCount;
  const totalAreaSquareMeters = zones.reduce((total, zone) => total + turfArea(zone), 0);
  // Tạm tính theo mật độ trung bình cấu hình cho bản demo. Khi có dữ liệu dân số
  // chính thức, trường này có thể thay bằng tổng dân số của từng đơn vị hành chính.
  const estimatedPopulation = Math.round((totalAreaSquareMeters / 1_000_000) * 1450);

  const layerLabels: Record<string, string> = {
    camera: "camera",
    facility: "cơ quan nhà nước",
    transport: "bến xe / đầu mối",
  };
  const items = state.layers.filter((layer) => (
    layer.visible || (layer.id === "government-ubnd" && (
      state.selectedAdministrativeIds.length > 0
      || (state.defaultViewportEnabled && state.defaultAdministrativeIds.length > 0)
    ))
  )).map((layer): ZoneSummaryItem => {
    if (layer.category === "hydrology") {
      const count = zones.filter((zone) => layer.data.features.some((river) => booleanIntersects(zone, river))).length;
      return { id: layer.id, label: `địa giới/vùng chứa ${layer.name.toLowerCase()}`, count, color: layer.color };
    }
    const count = layer.data.features.filter((candidate) => (
      candidate.geometry.type === "Point" && zones.some((zone) => booleanPointInPolygon(candidate as Feature<GeoJSONPoint>, zone))
    )).length;
    const label = layer.id === "government-ubnd" ? "UBND" : layerLabels[layer.category] ?? layer.name.toLowerCase();
    return { id: layer.id, label, count, color: layer.color };
  });
  return { zoneCount: zones.length, drawnZoneCount, administrativeZoneCount, totalAreaSquareMeters, estimatedPopulation, items };
}

export function describeDrawFeature(draw: TerraDraw, id: string | number): DrawFeatureInfo | null {
  const snapshot = draw.getSnapshotFeature(id);
  if (!snapshot || (snapshot.geometry.type !== "Polygon" && snapshot.geometry.type !== "LineString")) return null;
  const geoFeature = feature(snapshot.geometry);
  const center = centroid(geoFeature).geometry.coordinates as [number, number];
  if (snapshot.geometry.type === "LineString") {
    const coordinates = snapshot.geometry.coordinates;
    const lengthMeters = coordinates.slice(1).reduce((total, coordinate, index) => (
      total + distance(point(coordinates[index]), point(coordinate), { units: "meters" })
    ), 0);
    return { id, kind: snapshot.properties.mode === "multilinestring" ? "multiline" : "line", perimeterMeters: lengthMeters, center };
  }
  const mode = snapshot.properties.mode;
  const kind: DrawFeatureInfo["kind"] = mode === "circle" ? "circle" : mode === "rectangle" ? "rectangle" : "polygon";
  const rings = snapshot.geometry.coordinates;
  const perimeterMeters = rings.reduce((total, ring) => total + ring.slice(1).reduce((ringTotal, coordinate, index) => (
    ringTotal + distance(point(ring[index]), point(coordinate), { units: "meters" })
  ), 0), 0);
  const radiusMeters = kind === "circle" && rings[0]?.[0]
    ? distance(point(center), point(rings[0][0]), { units: "meters" })
    : undefined;
  return {
    id,
    kind,
    areaSquareMeters: turfArea(geoFeature),
    perimeterMeters,
    radiusMeters,
    center,
  };
}
