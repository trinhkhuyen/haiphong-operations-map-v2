import { useCallback, useEffect, useRef, useState } from "react";
import { createRoot, type Root } from "react-dom/client";
import { Cable, FileText, Home, Layers3, Map as MapIcon, Mountain, Satellite, X, Zap } from "lucide-react";
import maplibregl, { type GeoJSONSource, type Map as MapLibreMap } from "maplibre-gl";
import { area as turfArea, bbox, booleanIntersects, booleanPointInPolygon, centroid, circle, distance, feature, featureCollection, point, union } from "@turf/turf";
import type { Feature, MultiPolygon, Point as GeoJSONPoint, Polygon } from "geojson";
import { TerraDraw, TerraDrawCircleMode, TerraDrawLineStringMode, TerraDrawPolygonMode, TerraDrawRectangleMode, TerraDrawSelectMode, type GeoJSONStoreFeatures, type HexColor } from "terra-draw";
import { TerraDrawMapLibreGLAdapter } from "terra-draw-maplibre-gl-adapter";
import { useAppStore } from "../../core/store";
import { mapIconByKey } from "../../core/map-icons";
import type { AdministrativeUnit, BaseMapMode, DrawFeatureInfo, OperationalLayer } from "../../core/types";
import { unitsToFeatureCollection } from "../administrative/data-provider";
import { HNTH_LAYER_ID, HNTH_STATUS_LABELS, normalizeHnthStatus, type HnthConnectionStatus, type HnthStatusStyles } from "../layers/hnth-data-provider";
import { HnthDisconnectConfirmButton } from "../conference/HnthDisconnectConfirmButton";
import { FIT_HAIPHONG_OVERVIEW_EVENT, MAP_ADMINISTRATIVE_PULSE_EVENT, MAP_CAPTURE_BACKGROUND_EVENT, MAP_CONTEXT_INFO_EVENT, MAP_PRESENTATION_GEOMETRY_EVENT } from "./map-events";

// Tạo style theo đúng chế độ nền đã lưu ngay từ frame đầu tiên. Nếu luôn khởi
// tạo OSM rồi mới đổi sang vệ tinh sau sự kiện `load`, MapLibre sẽ lộ một mảng
// tile OSM sáng hình chữ nhật trong lúc reload.
const createBaseStyle = (initialMode: BaseMapMode): maplibregl.StyleSpecification => ({
  version: 8,
  // Bộ glyph dùng cho lớp nhãn 114 xã/phường/đặc khu chính thức bên dưới.
  // Nền raster không thể dùng CSS để xóa chữ đã nằm sẵn trong ảnh tile.
  glyphs: "https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf",
  sources: {
    osm: {
      type: "raster",
      tiles: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"],
      tileSize: 256,
      attribution: "© OpenStreetMap contributors",
    },
    satellite: {
      type: "raster",
      tiles: ["https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"],
      tileSize: 256,
      maxzoom: 19,
      attribution: "Tiles © Esri — Source: Esri, Maxar, Earthstar Geographics, and the GIS User Community",
    },
    terrain: {
      type: "raster",
      tiles: ["https://a.tile.opentopomap.org/{z}/{x}/{y}.png", "https://b.tile.opentopomap.org/{z}/{x}/{y}.png", "https://c.tile.opentopomap.org/{z}/{x}/{y}.png"],
      tileSize: 256,
      maxzoom: 17,
      attribution: "Kartendaten: © OpenStreetMap-Mitwirkende, SRTM | Kartendarstellung: © OpenTopoMap (CC-BY-SA)",
    },
  },
  layers: [
    { id: "base-map-background", type: "background", paint: { "background-color": "#071722" } },
    {
      id: "base-map-standard",
      type: "raster",
      source: "osm",
      layout: { visibility: initialMode === "standard" ? "visible" : "none" },
      paint: { "raster-saturation": -0.75, "raster-brightness-max": 0.72, "raster-contrast": 0.18, "raster-fade-duration": 0 },
    },
    {
      id: "base-map-satellite",
      type: "raster",
      source: "satellite",
      layout: { visibility: initialMode === "satellite" ? "visible" : "none" },
      paint: { "raster-fade-duration": 0 },
    },
    {
      id: "base-map-terrain",
      type: "raster",
      source: "terrain",
      layout: { visibility: initialMode === "terrain" ? "visible" : "none" },
      paint: { "raster-fade-duration": 0 },
    },
  ],
});

const baseMapOptions: { id: BaseMapMode; label: string; description: string; icon: typeof MapIcon }[] = [
  { id: "standard", label: "Tiêu chuẩn", description: "Đường phố và địa danh", icon: MapIcon },
  { id: "satellite", label: "Vệ tinh", description: "Ảnh vệ tinh Esri", icon: Satellite },
  { id: "terrain", label: "Địa hình", description: "Địa hình và cao độ", icon: Mountain },
];

// Độ đục nền dùng chung khi chọn vùng tự vẽ hoặc focus địa giới lần 2.
// MapLibre/Terra Draw dùng 0 = trong suốt hoàn toàn, 1 = đặc hoàn toàn.
// Ví dụ: 0.05 = trong suốt 95%, 0.08 = 92%, 0.15 = 85%.
const SELECTED_ZONE_FILL_OPACITY = 0.08;

// Màu phủ các địa giới xung quanh khi đã chọn địa giới/cụm địa giới làm khung mặc định.
// Chỉnh mã dưới đây để đổi màu. Một số màu nhạt có thể dùng:
// - Xanh ngọc nhạt (đang dùng): #99F6E4
// - Xanh dương nhạt (sky):      #BAE6FD
// - Xanh lá nhạt:               #BBF7D0
// - Blue nhạt:                  #BFDBFE
const DEFAULT_VIEWPORT_SURROUNDING_FILL_COLOR = "#99F6E4";
const DEFAULT_VIEWPORT_SURROUNDING_LINE_COLOR = "#5EEAD4";

// Chuyển cảnh về khung mặc định của địa giới luôn đi qua toàn TP Hải Phòng:
// 800 ms để về khung thành phố, giữ nguyên 2 giây, rồi mới zoom vào địa giới.
// Muốn tự chỉnh thời gian dừng, thay giá trị HOME_CITY_PAUSE_MS bên dưới:
// 1000 = 1 giây, 2000 = 2 giây, 3000 = 3 giây, ...
const HOME_CITY_TRANSITION_DURATION_MS = 800;
const HOME_CITY_PAUSE_MS = 1000;
const HAIPHONG_FALLBACK_BOUNDS: [[number, number], [number, number]] = [[105.92, 20.48], [107.16, 21.28]];

// Khung thu nhỏ tối đa của bản đồ vận hành (theo ảnh mốc ngày 14/10/2026):
// phía tây thấy Điện Biên, phía bắc thấy Tuyên Quang và phía nam thấy Nghệ An.
// Đây là camera bản đồ thật dùng ngay trong lúc khởi động, không phải ảnh nền.
// Có thể tinh chỉnh nhẹ 3 giá trị dưới đây nếu kích thước màn hình triển khai đổi.
const REGIONAL_LOADING_CENTER: [number, number] = [105.95, 21.02];
const REGIONAL_MIN_ZOOM = 6.25;

// Khóa vùng pan để không kéo ra ngoài khu vực dữ liệu cần vận hành. Biên phía
// đông vẫn bao gồm đặc khu Bạch Long Vĩ và vùng biển lân cận.
const REGIONAL_OPERATIONAL_BOUNDS: [[number, number], [number, number]] = [[101.85, 18.25], [110.05, 23.6]];

function setMobileHomePanBounds(map: MapLibreMap, administrativeUnits: AdministrativeUnit[]) {
  if (!window.matchMedia("(max-width: 760px)").matches) return;
  const bounds = getHaiphongOverviewBounds(administrativeUnits);
  const width = Math.abs(bounds[1][0] - bounds[0][0]);
  const height = Math.abs(bounds[1][1] - bounds[0][1]);
  // Cho tâm bản đồ lệch tối đa 1/4 kích thước thành phố mỗi phía. Như vậy
  // khi người dùng kéo trên mobile, ít nhất khoảng 1/2 thành phố vẫn nằm
  // trong khung nhìn, thay vì bị kéo hẳn ra ngoài màn hình.
  const marginLng = Math.max(width * 0.35, 0.08);
  const marginLat = Math.max(height * 0.35, 0.06);
  map.setMaxBounds([
    [bounds[0][0] - marginLng, bounds[0][1] - marginLat],
    [bounds[1][0] + marginLng, bounds[1][1] + marginLat],
  ]);
}

// MapLibre tính một level là gấp đôi/nhỏ một nửa; ảnh mẫu chỉ cần lùi
// khoảng nửa level để TP vẫn rộng gần bằng thanh trạng thái.
const MOBILE_HOME_ZOOM_OUT_LEVELS = 2.5;
const MOBILE_HOME_PAN_DOWN_PX = 40;

function fitMobileHomeOverview(map: MapLibreMap, administrativeUnits: AdministrativeUnit[], duration: number) {
  // Tạm bỏ maxBounds để MapLibre không kẹp tâm bản đồ khi fit với padding lớn.
  map.stop();
  map.resize();
  map.setMaxBounds(null);
  fitHaiphongOverview(map, administrativeUnits, duration);
  window.setTimeout(() => {
    // Lùi đúng 3 mức sau khi fit bounds, rồi đẩy nội dung xuống dưới thanh
    // trạng thái để điểm cao nhất của thành phố không bị thanh che lên.
    const zoom = Math.max(map.getMinZoom(), map.getZoom() - MOBILE_HOME_ZOOM_OUT_LEVELS);
    map.zoomTo(zoom, { duration: 0 });
    const overviewBounds = getHaiphongOverviewBounds(administrativeUnits);
    map.setCenter([
      (overviewBounds[0][0] + overviewBounds[1][0]) / 2,
      (overviewBounds[0][1] + overviewBounds[1][1]) / 2,
    ]);
    map.panBy([0, MOBILE_HOME_PAN_DOWN_PX], { duration: 0 });
    // Mốc Home hiện tại là mức zoom-out thấp nhất trên mobile. Người dùng
    // vẫn có thể zoom in, nhưng không thể zoom xa hơn làm thành phố biến khỏi
    // khung hình.
    map.setMinZoom(map.getZoom());
    setMobileHomePanBounds(map, administrativeUnits);
  }, Math.max(0, duration) + 50);
}

// Màu điểm UBND theo loại đơn vị hành chính.
// Xã và phường dùng hai sắc xanh khác nhau; đặc khu dùng tím nhạt.
const UBND_POINT_COLORS = {
  "xã": "#14B8A6",
  "phường": "#3B82F6",
  "đặc khu": "#C084FC",
} as const;

const OFFICIAL_ADMINISTRATIVE_LABEL_SOURCE_ID = "official-administrative-label-points";
const OFFICIAL_ADMINISTRATIVE_LABEL_LAYER_ID = "official-administrative-labels";
const PRIORITY_ADMINISTRATIVE_LABEL_LAYER_ID = "official-administrative-labels-priority";
const PRIORITY_ADMINISTRATIVE_LABEL_NAMES = ["Chu Văn An", "Nam Đồ Sơn", "Đồ Sơn", "Bạch Long Vĩ"];

function buildOfficialAdministrativeLabelPoints(units: AdministrativeUnit[]): GeoJSON.FeatureCollection<GeoJSONPoint> {
  return featureCollection(units.map((unit) => point(unit.coordinates, {
    id: unit.id,
    name: unit.name,
    type: unit.type,
    shortType: unit.type === "phường" ? "P" : unit.type === "xã" ? "X" : "ĐK",
    priority: PRIORITY_ADMINISTRATIVE_LABEL_NAMES.includes(unit.name),
  })));
}

function officialAdministrativeLabelsVisible(baseMapMode: BaseMapMode) {
  // Nền Tiêu chuẩn và Địa hình đều là ảnh raster đã ghép chữ vào tile nên không
  // thể ẩn riêng nhãn cũ trong Hải Phòng. Chỉ chèn bộ nhãn hành chính mới trên
  // nền Vệ tinh (không có chữ) để tuyệt đối tránh hai bộ tên đè lên nhau.
  return baseMapMode === "satellite";
}

interface ZoneSummaryItem {
  id: string;
  label: string;
  count: number;
  color: string;
}

interface ZoneSummary {
  zoneCount: number;
  drawnZoneCount: number;
  administrativeZoneCount: number;
  totalAreaSquareMeters: number;
  estimatedPopulation: number;
  items: ZoneSummaryItem[];
}

interface IconMarkerHandle {
  marker: maplibregl.Marker;
  root: Root;
}

interface DrawEditMarkerHandle {
  marker: maplibregl.Marker;
  kind: "edge-label" | "move-handle" | "radius-handle";
}

type FixedMapInfo =
  | { kind: "administrative"; unitId: number; includeConnectionPoint: boolean }
  | { kind: "hnth"; pointId: string; administrativeId?: number; pulseBoundary?: boolean };

// Terra Draw can emit a transient deselect while custom MapLibre markers edit
// geometry. Track the edited feature outside the marker DOM so a marker redraw
// cannot accidentally clear the active selection mid-drag.
const drawEditDeselectGuards = new Set<string>();

function getHaiphongOverviewBounds(administrativeUnits: AdministrativeUnit[]) {
  // Bạch Long Vĩ vẫn được hiển thị nhưng không tham gia bounds tổng quan vì
  // vị trí đảo ở xa sẽ làm phần lãnh thổ liền khối bị thu nhỏ quá mức.
  const viewportUnits = administrativeUnits.filter((unit) => unit.name.trim().toLocaleLowerCase("vi") !== "bạch long vĩ");
  const units = viewportUnits.length > 0 ? viewportUnits : administrativeUnits;
  return units.length > 0
    ? (() => {
        const cityBounds = bbox(unitsToFeatureCollection(units));
        return [[cityBounds[0], cityBounds[1]], [cityBounds[2], cityBounds[3]]] as [[number, number], [number, number]];
      })()
    : HAIPHONG_FALLBACK_BOUNDS;
}

const HAIPHONG_OVERVIEW_PADDING = { top: 36, right: 36, bottom: 36, left: 36 };
// Mobile có phần sidebar cố định bên trái và viewport hẹp (đặc biệt iPhone 11).
// Mức đệm này giữ toàn TP trong khung nhưng vẫn cho bề ngang xấp xỉ 3 ô trạng thái.
const HAIPHONG_MOBILE_OVERVIEW_PADDING = { top: 84, right: 8, bottom: 84, left: 8 };

function getHaiphongOverviewPadding() {
  return window.matchMedia("(max-width: 760px)").matches
    ? HAIPHONG_MOBILE_OVERVIEW_PADDING
    : HAIPHONG_OVERVIEW_PADDING;
}

function fitHaiphongOverview(map: MapLibreMap, administrativeUnits: AdministrativeUnit[], duration: number) {
  const bounds = getHaiphongOverviewBounds(administrativeUnits);

  map.fitBounds(bounds, {
    padding: getHaiphongOverviewPadding(),
    bearing: 0,
    pitch: 0,
    duration,
  });
}

function restoreHaiphongOverviewIfZoomedOut(map: MapLibreMap, clickedCoordinate?: [number, number]) {
  const administrativeUnits = useAppStore.getState().administrativeUnits;
  if (clickedCoordinate) {
    const clickedInsideMainlandHaiphong = administrativeUnits.some((unit) => (
      unit.name.trim().toLocaleLowerCase("vi") !== "bạch long vĩ"
      && booleanPointInPolygon(point(clickedCoordinate), feature(unit.geometry as Polygon | MultiPolygon))
    ));
    if (!clickedInsideMainlandHaiphong) return false;
  }
  const bounds = getHaiphongOverviewBounds(administrativeUnits);
  const overviewCamera = map.cameraForBounds(bounds, { padding: getHaiphongOverviewPadding() });
  // Chỉ phục hồi khi người dùng đang nhìn rộng hơn khung toàn thành phố.
  // Dung sai nhỏ tránh camera rung do sai số thập phân ở đúng mức zoom chuẩn.
  if (!overviewCamera || typeof overviewCamera.zoom !== "number" || map.getZoom() >= overviewCamera.zoom - 0.05) return false;
  fitHaiphongOverview(map, administrativeUnits, 700);
  return true;
}

export function MapCanvas() {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<MapLibreMap | null>(null);
  const drawRef = useRef<TerraDraw | null>(null);
  const radiusMarkersRef = useRef(new Map<string | number, maplibregl.Marker>());
  const drawEditMarkersRef = useRef(new Map<string, DrawEditMarkerHandle>());
  const textMarkersRef = useRef(new Map<string, maplibregl.Marker>());
  const iconMarkersRef = useRef(new Map<string, IconMarkerHandle>());
  const drawSearchMarkerRef = useRef<maplibregl.Marker | null>(null);
  const vietnamProvinceLabelMarkersRef = useRef<maplibregl.Marker[]>([]);
  const hnthHubPulseMarkerRef = useRef<maplibregl.Marker | null>(null);
  const hnthContinuousMonitoringRef = useRef(false);
  const hnthAgentOnlineRef = useRef(false);
  const hasSetInitialViewportRef = useRef(false);
  const homeTransitionTimeoutRef = useRef<number | null>(null);
  const inspectedBoundaryPulseTimeoutsRef = useRef<number[]>([]);
  // Ngăn effect tự zoom theo vùng đang khoanh ghi đè khung toàn Hải Phòng
  // trong thời gian đang chờ trước khi đi tới địa giới mặc định.
  const isHomeTransitionActiveRef = useRef(false);
  const suppressNextAdministrativeSelectionFitRef = useRef(false);
  const managedSavedFeatureIdsRef = useRef(new Set<string | number>());
  const isSyncingSavedFeaturesRef = useRef(false);
  const [isMapReady, setIsMapReady] = useState(false);
  const [isInitialRegionalMapReady, setIsInitialRegionalMapReady] = useState(false);
  const [isDrawReady, setIsDrawReady] = useState(false);
  const [isBaseMapMenuOpen, setIsBaseMapMenuOpen] = useState(false);
  const [inspectedAdministrativeId, setInspectedAdministrativeId] = useState<number | null>(null);
  const [inspectedAdministrativeIds, setInspectedAdministrativeIds] = useState<number[]>([]);
  const [fixedMapInfo, setFixedMapInfo] = useState<FixedMapInfo | null>(null);
  const [zoneSummary, setZoneSummary] = useState<ZoneSummary>({ zoneCount: 0, drawnZoneCount: 0, administrativeZoneCount: 0, totalAreaSquareMeters: 0, estimatedPopulation: 0, items: [] });
  const layers = useAppStore((state) => state.layers);
  const clusterLevel = useAppStore((state) => state.clusterLevel);
  const baseMapMode = useAppStore((state) => state.baseMapMode);
  const drawMode = useAppStore((state) => state.drawMode);
  const administrativeUnits = useAppStore((state) => state.administrativeUnits);
  const administrativeStatus = useAppStore((state) => state.administrativeStatus);
  const selectedAdministrativeIds = useAppStore((state) => state.selectedAdministrativeIds);
  const focusedAdministrativeId = useAppStore((state) => state.focusedAdministrativeId);
  const dimOutsideHaiphong = useAppStore((state) => state.dimOutsideHaiphong);
  const defaultViewportEnabled = useAppStore((state) => state.defaultViewportEnabled);
  const defaultViewport = useAppStore((state) => state.defaultViewport);
  const defaultViewportSaveRequest = useAppStore((state) => state.defaultViewportSaveRequest);
  const defaultAdministrativeIds = useAppStore((state) => state.defaultAdministrativeIds);
  const defaultAdministrativeSaveRequest = useAppStore((state) => state.defaultAdministrativeSaveRequest);
  const administrativeFillColor = useAppStore((state) => state.administrativeFillColor);
  const administrativeOutlineColor = useAppStore((state) => state.administrativeOutlineColor);
  const administrativeFillOpacity = useAppStore((state) => state.administrativeFillOpacity);
  const drawFillColor = useAppStore((state) => state.drawFillColor);
  const drawOutlineColor = useAppStore((state) => state.drawOutlineColor);
  const drawFillOpacity = useAppStore((state) => state.drawFillOpacity);
  const selectedDrawFeatureId = useAppStore((state) => state.selectedDrawFeatureId);
  const drawRadiusUpdate = useAppStore((state) => state.drawRadiusUpdate);
  const deleteDrawRequest = useAppStore((state) => state.deleteDrawRequest);
  const textAnnotations = useAppStore((state) => state.textAnnotations);
  const iconAnnotations = useAppStore((state) => state.iconAnnotations);
  const selectedAnnotation = useAppStore((state) => state.selectedAnnotation);
  const drawSearchTarget = useAppStore((state) => state.drawSearchTarget);
  const hnthLineStyles = useAppStore((state) => state.hnthLineStyles);
  const hnthAreaStyles = useAppStore((state) => state.hnthAreaStyles);
  const hnthAreaVisible = useAppStore((state) => state.hnthAreaVisible);
  const hnthLineVisible = useAppStore((state) => state.hnthLineVisible);
  const hnthPointVisible = useAppStore((state) => state.hnthPointVisible);
  const activePanel = useAppStore((state) => state.activePanel);
  const savedDrawFeatures = useAppStore((state) => state.savedDrawFeatures);
  const saveSelectedObjectRequest = useAppStore((state) => state.saveSelectedObjectRequest);
  const focusSavedObjectRequest = useAppStore((state) => state.focusSavedObjectRequest);

  const fixedAdministrativeUnit = fixedMapInfo?.kind === "administrative"
    ? administrativeUnits.find((unit) => unit.id === fixedMapInfo.unitId)
    : undefined;
  const fixedHnthProperties = fixedMapInfo?.kind === "hnth"
    ? layers.find((layer) => layer.id === HNTH_LAYER_ID)?.data.features.find((item) => (
        item.geometry.type === "Point" && String(item.properties?.pointId ?? item.id) === fixedMapInfo.pointId
      ))?.properties
    : undefined;

  const refreshZoneSummary = () => setZoneSummary(buildZoneSummary(drawRef.current));

  const stopInspectedBoundaryPulse = useCallback(() => {
    for (const timeoutId of inspectedBoundaryPulseTimeoutsRef.current) window.clearTimeout(timeoutId);
    inspectedBoundaryPulseTimeoutsRef.current = [];
    const map = mapRef.current;
    if (map?.getLayer("administrative-inspected-line")) {
      map.setPaintProperty("administrative-inspected-line", "line-width", 1.1);
    }
  }, []);

  const pulseInspectedBoundary = useCallback((administrativeId: number | number[], cycleCount = 5, boundaryWidthMultiplier = 1, durationMs?: number, animate = true) => {
    const map = mapRef.current;
    if (!map?.getLayer("administrative-inspected-line")) return;
    const administrativeIds = [...new Set((Array.isArray(administrativeId) ? administrativeId : [administrativeId])
      .map((id) => Number(id))
      .filter((id) => Number.isFinite(id)))];
    if (!administrativeIds.length) return;
    stopInspectedBoundaryPulse();
    setInspectedAdministrativeId(administrativeIds[0]);
    setInspectedAdministrativeIds(administrativeIds);
    map.setFilter("administrative-inspected-line", administrativeIds.length === 1
      ? ["==", ["get", "id"], administrativeIds[0]]
      : ["in", ["get", "id"], ["literal", administrativeIds]]);
    map.moveLayer("administrative-inspected-line");

    // Lặp tối đa năm chu kỳ nhận diện: mảnh 1x → đậm 2x → đậm 3x → mảnh.
    // Sau chu kỳ cuối, giữ viền ở mức x2 để địa giới vẫn dễ nhận biết.
    // stopInspectedBoundaryPulse hủy toàn bộ chu kỳ khi nhấn Esc hoặc chọn nhánh khác.
    const normalizedCycleCount = Math.max(1, Math.min(5, Math.round(cycleCount)));
    const baseWidth = 1.1 * Math.max(1, boundaryWidthMultiplier);
    if (!animate) {
      // Thay đổi trạng thái tự động chỉ hiển thị viền trắng mảnh x2,
      // không chạy hiệu ứng tăng/giảm độ dày.
      map.setPaintProperty("administrative-inspected-line", "line-width", baseWidth);
      if (durationMs !== undefined) {
        inspectedBoundaryPulseTimeoutsRef.current = [window.setTimeout(() => {
          stopInspectedBoundaryPulse();
          const currentMap = mapRef.current;
          if (currentMap?.getLayer("administrative-inspected-line")) {
            currentMap.setFilter("administrative-inspected-line", ["==", ["get", "id"], -1]);
          }
          setInspectedAdministrativeId(null);
          setInspectedAdministrativeIds([]);
        }, Math.max(1, durationMs))];
      }
      return;
    }
    const steps = Array.from({ length: normalizedCycleCount }, (_, cycleIndex) => {
      const cycleStart = cycleIndex * 840;
      return [
        { delay: cycleStart, width: baseWidth },
        { delay: cycleStart + 280, width: baseWidth * 2 },
        { delay: cycleStart + 560, width: baseWidth * 3 },
        { delay: cycleStart + 840, width: cycleIndex === normalizedCycleCount - 1 ? baseWidth * 2 : baseWidth },
      ];
    }).flat();
    inspectedBoundaryPulseTimeoutsRef.current = steps.map(({ delay, width }) => window.setTimeout(() => {
      const currentMap = mapRef.current;
      if (currentMap?.getLayer("administrative-inspected-line")) {
        currentMap.setPaintProperty("administrative-inspected-line", "line-width", width);
      }
    }, delay));
    if (durationMs !== undefined) {
      inspectedBoundaryPulseTimeoutsRef.current.push(window.setTimeout(() => {
        stopInspectedBoundaryPulse();
      }, Math.max(1, durationMs)));
    }
  }, [stopInspectedBoundaryPulse]);

  useEffect(() => {
    const pulseAdministrativeBoundary = (event: Event) => {
      const detail = (event as CustomEvent<{ administrativeId?: number; administrativeIds?: number[]; cycles?: number; boundaryWidthMultiplier?: number; durationMs?: number; animate?: boolean }>).detail;
      const ids = detail?.administrativeIds?.length ? detail.administrativeIds : detail?.administrativeId === undefined ? [] : [detail.administrativeId];
      if (!ids.length) return;
      pulseInspectedBoundary(ids, detail.cycles ?? 3, detail.boundaryWidthMultiplier ?? 1, detail.durationMs, detail.animate ?? true);
    };
    window.addEventListener(MAP_ADMINISTRATIVE_PULSE_EVENT, pulseAdministrativeBoundary);
    return () => window.removeEventListener(MAP_ADMINISTRATIVE_PULSE_EVENT, pulseAdministrativeBoundary);
  }, [pulseInspectedBoundary]);

  const clearMapInspection = useCallback(() => {
    stopInspectedBoundaryPulse();
    setInspectedAdministrativeId(null);
    setInspectedAdministrativeIds([]);
    setFixedMapInfo(null);
    if (mapRef.current) clearAdministrativeConnection(mapRef.current);
  }, [stopInspectedBoundaryPulse]);

  const goHome = useCallback(() => {
    const map = mapRef.current;
    if (!map) return;
    const state = useAppStore.getState();

    if (homeTransitionTimeoutRef.current !== null) {
      window.clearTimeout(homeTransitionTimeoutRef.current);
      homeTransitionTimeoutRef.current = null;
    }
    isHomeTransitionActiveRef.current = false;

    if (state.defaultViewportEnabled && state.defaultViewport) {
      if (state.defaultAdministrativeIds.length > 0) {
        setMobileHomePanBounds(map, state.administrativeUnits);
        if (window.matchMedia("(max-width: 760px)").matches) {
          fitMobileHomeOverview(map, state.administrativeUnits, HOME_CITY_TRANSITION_DURATION_MS);
          return;
        }
        isHomeTransitionActiveRef.current = true;
        fitHaiphongOverview(map, state.administrativeUnits, HOME_CITY_TRANSITION_DURATION_MS);
        homeTransitionTimeoutRef.current = window.setTimeout(() => {
          homeTransitionTimeoutRef.current = null;
          const latestState = useAppStore.getState();
          isHomeTransitionActiveRef.current = false;
          if (!latestState.defaultViewportEnabled || !latestState.defaultViewport || latestState.defaultAdministrativeIds.length === 0) return;
          map.easeTo({ ...latestState.defaultViewport, duration: HOME_CITY_TRANSITION_DURATION_MS });
        }, HOME_CITY_TRANSITION_DURATION_MS + HOME_CITY_PAUSE_MS);
        return;
      }
      map.setMaxBounds(REGIONAL_OPERATIONAL_BOUNDS);
      map.easeTo({ ...state.defaultViewport, duration: 800 });
      return;
    }
    setMobileHomePanBounds(map, state.administrativeUnits);
    fitHaiphongOverview(map, state.administrativeUnits, HOME_CITY_TRANSITION_DURATION_MS);
  }, []);

  const goHomeTilted = useCallback(() => {
    const map = mapRef.current;
    if (!map) return;
    const state = useAppStore.getState();
    const isMobile = window.matchMedia("(max-width: 760px)").matches;

    if (isMobile && state.defaultAdministrativeIds.length > 0) {
      // Tính camera Home trước, sau đó đặt pitch trong cùng một transition.
      // Không gọi goHome() trước để tránh camera bị fitBounds ghi đè rồi mới nghiêng.
      const bounds = getHaiphongOverviewBounds(state.administrativeUnits);
      const homeCamera = map.cameraForBounds(bounds, {
        padding: HAIPHONG_MOBILE_OVERVIEW_PADDING,
        bearing: 0,
        pitch: 0,
      });
      if (!homeCamera?.center) return;
      map.stop();
      map.setMaxBounds(null);
      const zoom = Math.max(map.getMinZoom(), (homeCamera.zoom ?? map.getZoom()) - MOBILE_HOME_ZOOM_OUT_LEVELS);
      const projectedCenter = map.project(homeCamera.center);
      const shiftedCenter = map.unproject([projectedCenter.x, projectedCenter.y + MOBILE_HOME_PAN_DOWN_PX]);
      map.easeTo({ center: shiftedCenter, zoom, pitch: map.getMaxPitch(), bearing: 0, duration: HOME_CITY_TRANSITION_DURATION_MS });
      return;
    }

    if (state.defaultViewport) {
      map.easeTo({ ...state.defaultViewport, pitch: map.getMaxPitch(), bearing: 0, duration: HOME_CITY_TRANSITION_DURATION_MS });
      return;
    }

    const bounds = getHaiphongOverviewBounds(state.administrativeUnits);
    const homeCamera = map.cameraForBounds(bounds, { padding: HAIPHONG_OVERVIEW_PADDING, bearing: 0, pitch: 0 });
    if (homeCamera?.center) map.easeTo({ ...homeCamera, pitch: map.getMaxPitch(), bearing: 0, duration: HOME_CITY_TRANSITION_DURATION_MS });
  }, []);

  useEffect(() => {
    const fitCityOverview = () => {
      const map = mapRef.current;
      if (!map) return;

      if (homeTransitionTimeoutRef.current !== null) {
        window.clearTimeout(homeTransitionTimeoutRef.current);
        homeTransitionTimeoutRef.current = null;
      }
      isHomeTransitionActiveRef.current = false;

      // Menu có thể vừa mở rộng từ trạng thái thu gọn; resize trước để bounds
      // được tính theo đúng kích thước canvas hiện tại.
      map.resize();
      setMobileHomePanBounds(map, useAppStore.getState().administrativeUnits);
      fitHaiphongOverview(map, useAppStore.getState().administrativeUnits, HOME_CITY_TRANSITION_DURATION_MS);
    };

    window.addEventListener(FIT_HAIPHONG_OVERVIEW_EVENT, fitCityOverview);
    return () => window.removeEventListener(FIT_HAIPHONG_OVERVIEW_EVENT, fitCityOverview);
  }, []);

  useEffect(() => {
    const focusHnthPoint = (event: Event) => {
      const detail = (event as CustomEvent<{
        coordinates?: [number, number];
        preserveZoom?: boolean;
        zoomFraction?: number;
        targetZoom?: number;
        administrativeId?: number;
        boundaryWidthMultiplier?: number;
      }>).detail;
      const coordinates = detail?.coordinates;
      if (!coordinates || !mapRef.current) return;
      if (detail.administrativeId !== undefined) {
        stopInspectedBoundaryPulse();
        setInspectedAdministrativeId(detail.administrativeId);
        setInspectedAdministrativeIds([detail.administrativeId]);
        if (mapRef.current.getLayer("administrative-inspected-line")) {
          const widthMultiplier = Math.max(1, detail.boundaryWidthMultiplier ?? 1);
          mapRef.current.setPaintProperty("administrative-inspected-line", "line-width", 1.1 * widthMultiplier);
        }
      }
      const currentZoom = mapRef.current.getZoom();
      const zoomFraction = Math.max(0, Math.min(1, detail.zoomFraction ?? 1));
      const targetZoom = detail.targetZoom ?? (currentZoom < 13
        ? currentZoom + ((13 - currentZoom) * zoomFraction)
        : currentZoom);
      mapRef.current.easeTo({
        center: coordinates,
        ...(detail.preserveZoom ? {} : { zoom: targetZoom }),
        duration: 700,
      });
    };
    window.addEventListener("hnth:focus", focusHnthPoint);
    return () => window.removeEventListener("hnth:focus", focusHnthPoint);
  }, [stopInspectedBoundaryPulse]);

  useEffect(() => {
    const showContextInfo = (event: Event) => {
      const detail = (event as CustomEvent<FixedMapInfo>).detail;
      if (detail?.kind === "hnth" && detail.pointId) {
        setFixedMapInfo(detail);
        setInspectedAdministrativeId(detail.administrativeId ?? null);
        setInspectedAdministrativeIds(detail.administrativeId === undefined ? [] : [detail.administrativeId]);
        if (detail.pulseBoundary && detail.administrativeId !== undefined) {
          pulseInspectedBoundary(detail.administrativeId);
        }
      }
    };
    window.addEventListener(MAP_CONTEXT_INFO_EVENT, showContextInfo);
    return () => window.removeEventListener(MAP_CONTEXT_INFO_EVENT, showContextInfo);
  }, [pulseInspectedBoundary]);

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;
    // Đọc trực tiếp cấu hình persisted trước khi dựng MapLibre để không có
    // một frame OSM mặc định xen giữa lúc khởi động chế độ vệ tinh/địa hình.
    const initialBaseMapMode = useAppStore.getState().baseMapMode;
    const map = new maplibregl.Map({
      container: containerRef.current,
      style: createBaseStyle(initialBaseMapMode),
      center: REGIONAL_LOADING_CENTER,
      zoom: REGIONAL_MIN_ZOOM,
      minZoom: REGIONAL_MIN_ZOOM,
      maxBounds: REGIONAL_OPERATIONAL_BOUNDS,
      renderWorldCopies: false,
      pitch: 0,
      bearing: 0,
    });
    mapRef.current = map;
    // Luôn hiển thị la bàn; hướng Bắc và góc nhìn phẳng là trạng thái mặc định sau reload.
    map.addControl(new maplibregl.NavigationControl({ showCompass: true, showZoom: true, visualizePitch: true }), "bottom-right");
    map.addControl(new maplibregl.FullscreenControl(), "bottom-right");
    map.on("load", () => {
      setIsMapReady(true);
      // Chỉ rời khung vùng Bắc Bộ - Bắc Trung Bộ sau khi các tile nền đang nhìn
      // thấy đã tải xong. Nhờ vậy chính bản đồ thật là nền chờ của ứng dụng.
      map.once("idle", () => {
        if (mapRef.current === map) setIsInitialRegionalMapReady(true);
      });
      map.triggerRepaint();
      const state = useAppStore.getState();
      for (const layer of state.layers) {
        if (layer.visible && layer.data.features.length) addOperationalLayer(map, layer, state.clusterLevel);
      }
      syncTextMarkers(map, useAppStore.getState().textAnnotations, textMarkersRef.current);
      syncIconMarkers(map, useAppStore.getState().iconAnnotations, iconMarkersRef.current);
      map.on("click", (event) => {
        const state = useAppStore.getState();
        if (state.activePanel === "layers" || state.activePanel === "conference") {
          const clickedInsideHaiphong = map.getLayer("administrative-fill")
            ? map.queryRenderedFeatures(event.point, { layers: ["administrative-fill"] }).length > 0
            : false;
          if (!clickedInsideHaiphong) {
            clearMapInspection();
          }
        }
        if (state.activePanel === "zones" && state.zoneMode === "administrative" && state.focusedAdministrativeId !== null) {
          const clickedInsideHaiphong = map.getLayer("administrative-fill")
            ? map.queryRenderedFeatures(event.point, { layers: ["administrative-fill"] }).length > 0
            : false;
          // Click ra ngoài 114 địa giới chỉ thoát focus, không bỏ vùng đã khoanh.
          if (!clickedInsideHaiphong) state.clearAdministrativeFocus();
        }
        const coordinates: [number, number] = [Number(event.lngLat.lng.toFixed(6)), Number(event.lngLat.lat.toFixed(6))];
        if (state.drawMode === "text" && state.textDraft.trim()) state.addTextAnnotation(coordinates);
        if (state.drawMode === "icon") state.addIconAnnotation(coordinates);
      });
      const draw = new TerraDraw({
        adapter: new TerraDrawMapLibreGLAdapter({ map }),
        modes: [
          new TerraDrawSelectMode({
            flags: {
              polygon: { feature: { draggable: true, coordinates: { midpoints: true, draggable: true, deletable: true } } },
              rectangle: { feature: { draggable: true, coordinates: { draggable: true, deletable: true } } },
              circle: { feature: { draggable: true, scaleable: true } },
              linestring: { feature: { draggable: true, coordinates: { midpoints: true, draggable: true, deletable: true } } },
              multilinestring: { feature: { draggable: true, coordinates: { midpoints: true, draggable: true, deletable: true } } },
            },
            keyEvents: { deselect: "Escape", delete: "Delete", rotate: null, scale: null },
            styles: {
              selectedPolygonColor: "#ffffff",
              selectedPolygonFillOpacity: SELECTED_ZONE_FILL_OPACITY,
              selectedPolygonOutlineColor: "#ffffff",
              selectedPolygonOutlineWidth: 3,
              selectedLineStringColor: "#ffffff",
              selectedLineStringWidth: 4,
              selectedLineStringDash: [8, 6],
              selectionPointColor: "#f8fafc",
              selectionPointOutlineColor: "#0f172a",
              selectionPointWidth: 5,
              selectionPointOutlineWidth: 2,
              midPointColor: "#f8fafc",
              midPointOutlineColor: "#0f172a",
            },
          }),
          new TerraDrawPolygonMode({ styles: { fillColor: featureColor("fillColor", "#fde68a"), fillOpacity: featureNumber("fillOpacity", 0.42), outlineColor: featureColor("outlineColor", "#d97706"), outlineWidth: 2.5 } }),
          new TerraDrawRectangleMode({ styles: { fillColor: featureColor("fillColor", "#fde68a"), fillOpacity: featureNumber("fillOpacity", 0.42), outlineColor: featureColor("outlineColor", "#d97706"), outlineWidth: 2.5 } }),
          new TerraDrawCircleMode({ showCoordinatePoints: false, styles: { fillColor: featureColor("fillColor", "#fde68a"), fillOpacity: featureNumber("fillOpacity", 0.42), outlineColor: featureColor("outlineColor", "#d97706"), outlineWidth: 2.5 } }),
          new TerraDrawLineStringMode({ finishOnNthCoordinate: 2, styles: { lineStringColor: featureColor("outlineColor", "#d97706"), lineStringWidth: 4, lineStringDash: [8, 6] } }),
          new TerraDrawLineStringMode({ modeName: "multilinestring", styles: { lineStringColor: featureColor("outlineColor", "#d97706"), lineStringWidth: 4, lineStringDash: [8, 6] } }),
        ],
      });
      draw.start();
      // Terra Draw exposes polygon outlines as a MapLibre line layer. Applying
      // the dash pattern at that layer keeps both normal and selected zones
      // consistently dashed without replacing the user's own outline color.
      if (map.getLayer("td-polygon-outline")) {
        map.setPaintProperty("td-polygon-outline", "line-dasharray", [3, 2]);
      }
      drawRef.current = draw;
      setIsDrawReady(true);
      draw.on("finish", (id) => {
        const state = useAppStore.getState();
        draw.updateFeatureProperties(id, { fillColor: state.drawFillColor, fillOpacity: state.drawFillOpacity, outlineColor: state.drawOutlineColor });
        // Terra Draw emits its temporary drawing deselection after `finish`.
        // Re-select on the next frame so that event cannot clear the durable
        // application selection or return the panel to the drawing tab.
        draw.setMode("select");
        state.setDrawMode("select");
        window.requestAnimationFrame(() => {
          draw.selectFeature(id);
          const currentState = useAppStore.getState();
          currentState.setSelectedDrawFeatureId(id);
          currentState.setSelectedDrawFeatureInfo(describeDrawFeature(draw, id));
          currentState.setZoneMode("info");
          syncRadiusMarkers(map, draw, radiusMarkersRef.current);
          syncDrawEditMarkers(map, draw, id, drawEditMarkersRef.current);
          refreshZoneSummary();
        });
      });
      draw.on("select", (id) => {
        const state = useAppStore.getState();
        state.clearSelectedAnnotation();
        const selectedFeature = draw.getSnapshotFeature(id);
        state.setSelectedDrawFeatureId(id);
        state.setSelectedDrawFeatureInfo(describeDrawFeature(draw, id));
        const fillColor = selectedFeature?.properties.fillColor;
        const fillOpacity = selectedFeature?.properties.fillOpacity;
        const outlineColor = selectedFeature?.properties.outlineColor;
        if (typeof fillColor === "string") state.setDrawFillColor(fillColor);
        if (typeof fillOpacity === "number") state.setDrawFillOpacity(fillOpacity);
        if (typeof outlineColor === "string") state.setDrawOutlineColor(outlineColor);
        state.setZoneMode("info");
        syncDrawEditMarkers(map, draw, id, drawEditMarkersRef.current);
      });
      draw.on("deselect", (id) => {
        if (drawEditDeselectGuards.has(String(id))) return;
        const isDraggingEditHandle = Array.from(drawEditMarkersRef.current.values()).some(
          ({ marker }) => marker.getElement().dataset.drawEditDragging === "true",
        );
        // Geometry updates performed by a custom marker can make Terra Draw
        // emit a transient deselect. The drag itself is still the active edit,
        // so keep both the information panel and edit handles mounted.
        if (isDraggingEditHandle) return;
        const state = useAppStore.getState();
        if (state.selectedDrawFeatureId !== id) return;
        state.setSelectedDrawFeatureId(null);
        state.setSelectedDrawFeatureInfo(null);
        if (state.zoneMode === "info") state.setZoneMode("draw");
        syncDrawEditMarkers(map, draw, null, drawEditMarkersRef.current);
      });
      draw.on("change", (ids) => {
        const state = useAppStore.getState();
        if (state.selectedDrawFeatureId !== null && ids.includes(state.selectedDrawFeatureId)) {
          state.setSelectedDrawFeatureInfo(describeDrawFeature(draw, state.selectedDrawFeatureId));
        }
        syncRadiusMarkers(map, draw, radiusMarkersRef.current);
        // Do not reposition a custom control marker while MapLibre is actively
        // dragging it. Resetting its coordinate inside `drag` cancels the drag
        // gesture before the geometry can follow the pointer.
        if (drawEditDeselectGuards.size === 0) {
          syncDrawEditMarkers(map, draw, state.selectedDrawFeatureId, drawEditMarkersRef.current);
        }
        refreshZoneSummary();
        if (!isSyncingSavedFeaturesRef.current) {
          for (const id of ids) {
            const snapshot = draw.getSnapshotFeature(id);
            if (snapshot) state.syncSavedDrawFeature(cleanDrawFeatureForStorage(snapshot));
          }
        }
      });
    });
    const handleKeyDown = (event: KeyboardEvent) => {
      const state = useAppStore.getState();
      if (event.key === "Escape" && (state.activePanel === "layers" || state.activePanel === "conference")) {
        event.preventDefault();
        clearMapInspection();
        return;
      }
      if (event.key === "Escape" && state.activePanel === "zones" && state.zoneMode === "administrative" && state.focusedAdministrativeId !== null) {
        event.preventDefault();
        // Escape đưa địa giới về trạng thái khoanh vùng lần 1, không xóa lựa chọn.
        state.clearAdministrativeFocus();
        return;
      }
      if (event.key !== "Delete" && event.key !== "Backspace") return;
      const target = event.target as HTMLElement | null;
      if (target?.matches("input, textarea, [contenteditable='true']")) return;
      if (state.selectedAnnotation && state.drawMode === "select") {
        event.preventDefault();
        state.deleteSelectedAnnotation();
        return;
      }
      if (state.selectedDrawFeatureId !== null && (state.zoneMode === "draw" || state.zoneMode === "info")) {
        event.preventDefault();
        const savedId = `geometry:${String(state.selectedDrawFeatureId)}`;
        if (state.savedDrawFeatures.some((item) => item.id === savedId)) state.deleteSavedObject("geometry", savedId);
        drawRef.current?.removeFeatures([state.selectedDrawFeatureId]);
        if (mapRef.current && drawRef.current) syncRadiusMarkers(mapRef.current, drawRef.current, radiusMarkersRef.current);
        state.setSelectedDrawFeatureId(null);
        state.setSelectedDrawFeatureInfo(null);
        state.setZoneMode("draw");
        refreshZoneSummary();
        return;
      }
      if (state.activePanel === "zones" && state.zoneMode === "administrative" && state.focusedAdministrativeId !== null) {
        event.preventDefault();
        state.removeAdministrativeUnit(state.focusedAdministrativeId);
        return;
      }
    };
    // Bắt phím ở capture phase để thư viện vẽ không chặn Escape/Delete trước ứng dụng.
    window.addEventListener("keydown", handleKeyDown, true);
    return () => {
      window.removeEventListener("keydown", handleKeyDown, true);
      if (homeTransitionTimeoutRef.current !== null) {
        window.clearTimeout(homeTransitionTimeoutRef.current);
        homeTransitionTimeoutRef.current = null;
      }
      isHomeTransitionActiveRef.current = false;
      for (const marker of radiusMarkersRef.current.values()) marker.remove();
      radiusMarkersRef.current.clear();
      for (const handle of drawEditMarkersRef.current.values()) handle.marker.remove();
      drawEditMarkersRef.current.clear();
      for (const marker of textMarkersRef.current.values()) marker.remove();
      textMarkersRef.current.clear();
      for (const handle of iconMarkersRef.current.values()) { handle.root.unmount(); handle.marker.remove(); }
      iconMarkersRef.current.clear();
      for (const marker of vietnamProvinceLabelMarkersRef.current) marker.remove();
      vietnamProvinceLabelMarkersRef.current = [];
      drawSearchMarkerRef.current?.remove();
      drawSearchMarkerRef.current = null;
      drawRef.current?.stop();
      map.remove();
      mapRef.current = null;
    };
  }, []);

  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map) return;
    for (const option of baseMapOptions) {
      const layerId = `base-map-${option.id}`;
      if (map.getLayer(layerId)) map.setLayoutProperty(layerId, "visibility", option.id === baseMapMode ? "visible" : "none");
    }
    const administrativeLabelVisibility = officialAdministrativeLabelsVisible(baseMapMode) ? "visible" : "none";
    for (const layerId of [OFFICIAL_ADMINISTRATIVE_LABEL_LAYER_ID, PRIORITY_ADMINISTRATIVE_LABEL_LAYER_ID]) {
      if (map.getLayer(layerId)) map.setLayoutProperty(layerId, "visibility", administrativeLabelVisibility);
    }
  }, [baseMapMode, isMapReady]);

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement | null;
      if (target?.isContentEditable || target?.tagName === "INPUT" || target?.tagName === "TEXTAREA" || target?.tagName === "SELECT") return;
      if (event.key === "Home" || event.key === "0") {
        event.preventDefault();
        goHome();
        return;
      }
      if (event.key === "2" || event.key === "3") {
        event.preventDefault();
        useAppStore.getState().setBaseMapMode(event.key === "2" ? "satellite" : "standard");
        return;
      }
      if (event.key === "4" || event.key === "5" || event.key === "6") {
        event.preventDefault();
        const state = useAppStore.getState();
        if (event.key === "4") state.setHnthLineVisible(!state.hnthLineVisible);
        if (event.key === "5") state.setHnthAreaVisible(!state.hnthAreaVisible);
        if (event.key === "6") state.setHnthPointVisible(!state.hnthPointVisible);
        return;
      }
      if (event.key === "1") {
        event.preventDefault();
        goHomeTilted();
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [goHome, goHomeTilted]);

  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !isInitialRegionalMapReady || !map || hasSetInitialViewportRef.current) return;

    if (defaultViewportEnabled && defaultViewport) {
      // Chờ dữ liệu địa giới để khung trung gian dùng đúng bounds Hải Phòng.
      // Chỉ dùng bounds dự phòng nếu nguồn địa giới thực sự bị lỗi.
      if (defaultAdministrativeIds.length > 0 && administrativeUnits.length === 0 && administrativeStatus !== "error") return;
      hasSetInitialViewportRef.current = true;
      useAppStore.getState().setInitialViewportReady(true);

      if (defaultAdministrativeIds.length > 0) {
        // Khi khởi động với địa giới/cụm địa giới mặc định, luôn cho người dùng
        // thấy toàn Hải Phòng trong khoảng HOME_CITY_PAUSE_MS trước khi zoom vào khung đã lưu.
        // Chỉ bắt đầu đếm sau sự kiện `idle`: lúc đó bản đồ nền và địa giới ở
        // khung toàn thành phố đã render xong, nên thời gian chờ là thời gian
        // người dùng thực sự nhìn thấy chứ không bị tiêu hao trong lúc reload.
        isHomeTransitionActiveRef.current = true;
        setMobileHomePanBounds(map, administrativeUnits);
        if (window.matchMedia("(max-width: 760px)").matches) {
          fitMobileHomeOverview(map, administrativeUnits, 0);
          isHomeTransitionActiveRef.current = false;
          map.triggerRepaint();
          return;
        }
        fitHaiphongOverview(map, administrativeUnits, 0);
        map.once("idle", () => {
          if (mapRef.current !== map) return;
          homeTransitionTimeoutRef.current = window.setTimeout(() => {
            homeTransitionTimeoutRef.current = null;
            const latestState = useAppStore.getState();
            isHomeTransitionActiveRef.current = false;
            if (!latestState.defaultViewportEnabled || !latestState.defaultViewport || latestState.defaultAdministrativeIds.length === 0) return;
            map.easeTo({ ...latestState.defaultViewport, duration: HOME_CITY_TRANSITION_DURATION_MS });
          }, HOME_CITY_PAUSE_MS);
        });
        map.triggerRepaint();
      } else {
        map.jumpTo(defaultViewport);
      }
      return;
    }

    if (administrativeUnits.length > 0) {
      setMobileHomePanBounds(map, administrativeUnits);
      if (window.matchMedia("(max-width: 760px)").matches) {
        fitMobileHomeOverview(map, administrativeUnits, 0);
      } else {
        fitHaiphongOverview(map, administrativeUnits, 0);
      }
      hasSetInitialViewportRef.current = true;
      useAppStore.getState().setInitialViewportReady(true);
      return;
    }

    if (administrativeStatus === "error") {
      // Fallback khi dịch vụ địa giới tạm lỗi; không chặn vĩnh viễn các lớp đã lưu.
      if (window.matchMedia("(max-width: 760px)").matches) {
        fitMobileHomeOverview(map, [], 0);
      } else {
        fitHaiphongOverview(map, [], 0);
      }
      hasSetInitialViewportRef.current = true;
      useAppStore.getState().setInitialViewportReady(true);
    }
  }, [administrativeUnits, administrativeStatus, defaultAdministrativeIds, defaultViewport, defaultViewportEnabled, isInitialRegionalMapReady, isMapReady]);

  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map || defaultViewportSaveRequest === 0) return;

    // Chỉ chụp khung hình tại đúng thời điểm người dùng bấm nút lưu.
    // Pan/zoom sau đó không được tự động ghi đè khung hình mặc định này.
    const center = map.getCenter();
    useAppStore.getState().setDefaultViewport({
      center: [Number(center.lng.toFixed(6)), Number(center.lat.toFixed(6))],
      zoom: Number(map.getZoom().toFixed(3)),
      bearing: Number(map.getBearing().toFixed(2)),
      pitch: Number(map.getPitch().toFixed(2)),
    });
  }, [defaultViewportSaveRequest, isMapReady]);

  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map || !defaultAdministrativeSaveRequest) return;
    const units = administrativeUnits.filter((candidate) => defaultAdministrativeSaveRequest.ids.includes(candidate.id));
    if (units.length === 0) return;

    const unitBounds = bbox(unitsToFeatureCollection(units));
    map.setBearing(0);
    map.setPitch(0);
    map.fitBounds([[unitBounds[0], unitBounds[1]], [unitBounds[2], unitBounds[3]]], {
      padding: { top: 72, right: 72, bottom: 72, left: 72 },
      maxZoom: 14,
      duration: 0,
    });
    const center = map.getCenter();
    useAppStore.getState().setDefaultAdministrativeViewport(units.map((unit) => unit.id), {
      center: [Number(center.lng.toFixed(6)), Number(center.lat.toFixed(6))],
      zoom: Number(map.getZoom().toFixed(3)),
      bearing: 0,
      pitch: 0,
    });
  }, [administrativeUnits, defaultAdministrativeSaveRequest, isMapReady]);

  useEffect(() => {
    const map = mapRef.current;
    drawSearchMarkerRef.current?.remove();
    drawSearchMarkerRef.current = null;
    if (!map || !drawSearchTarget) return;

    const element = document.createElement("div");
    element.className = "draw-search-map-marker";
    const pin = document.createElement("i");
    pin.setAttribute("aria-hidden", "true");
    const label = document.createElement("span");
    label.textContent = drawSearchTarget.name;
    element.append(pin, label);
    drawSearchMarkerRef.current = new maplibregl.Marker({ element, anchor: "bottom" })
      .setLngLat(drawSearchTarget.coordinates)
      .addTo(map);

    const bounds = drawSearchTarget.bbox;
    if (bounds && Math.abs(bounds[2] - bounds[0]) + Math.abs(bounds[3] - bounds[1]) > 0.0001) {
      map.fitBounds([[bounds[0], bounds[1]], [bounds[2], bounds[3]]], { padding: 110, maxZoom: 17, duration: 850 });
    } else {
      map.flyTo({ center: drawSearchTarget.coordinates, zoom: 16, duration: 850, essential: true });
    }
  }, [drawSearchTarget]);

  // Trên màn hình nhỏ không cho người dùng zoom ra ngoài khung toàn thành phố.
  // Desktop giữ nguyên hành vi MapLibre mặc định.
  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map) return;
    const mobileQuery = window.matchMedia("(max-width: 760px)");
    const syncMobileMinZoom = () => {
      if (!mobileQuery.matches) { map.setMinZoom(0); return; }
      const overviewCamera = map.cameraForBounds(getHaiphongOverviewBounds(administrativeUnits), { padding: getHaiphongOverviewPadding() });
      map.setMinZoom(Math.max(0, (overviewCamera?.zoom ?? 0) - MOBILE_HOME_ZOOM_OUT_LEVELS));
    };
    syncMobileMinZoom();
    mobileQuery.addEventListener("change", syncMobileMinZoom);
    window.addEventListener("resize", syncMobileMinZoom);
    return () => {
      mobileQuery.removeEventListener("change", syncMobileMinZoom);
      window.removeEventListener("resize", syncMobileMinZoom);
      map.setMinZoom(0);
    };
  }, [administrativeUnits, isMapReady]);

  useEffect(() => {
    const map = mapRef.current;
    // Sự kiện `load` đã đảm bảo style có thể thêm source/layer. Không dùng
    // isStyleLoaded() ở đây vì tile raster nền còn tải có thể làm nó tạm false,
    // khiến effect bỏ lỡ vĩnh viễn dữ liệu vừa nạp cho tới khi người dùng click.
    if (!isMapReady || !map) return;
    const contextualAdministrativeIds = activePanel === "conference" ? [] : [...new Set([
      ...(activePanel === "zones" ? selectedAdministrativeIds : []),
      ...(defaultViewportEnabled ? defaultAdministrativeIds : []),
    ])];
    const renderedLayers = buildContextualOperationalLayers(layers, administrativeUnits, contextualAdministrativeIds);
    const sourceCache = operationalSourceDataCache.get(map) ?? new Map<string, unknown>();
    operationalSourceDataCache.set(map, sourceCache);
    for (const layer of renderedLayers) {
      const source = map.getSource(layer.id) as GeoJSONSource | undefined;
      if (source && sourceCache.get(layer.id) !== layer.data) {
        if (layer.id === HNTH_LAYER_ID) {
          syncHnthSourceData(map, source, layer.data);
        } else {
          source.setData(layer.data);
        }
        sourceCache.set(layer.id, layer.data);
      }
      else if ((layer.visible || layer.id === HNTH_LAYER_ID) && layer.data.features.length) {
        addOperationalLayer(map, layer, useAppStore.getState().clusterLevel);
        sourceCache.set(layer.id, layer.data);
        if (layer.id === HNTH_LAYER_ID) rememberHnthFeatureProperties(map, layer.data);
      }
      // HNTH có hai switch hiển thị riêng cho sơ đồ kết nối và màu nền địa
      // giới. Không để cơ chế bật/tắt lớp dữ liệu chung ghi đè hai switch đó.
      if (layer.id !== HNTH_LAYER_ID) {
        // Trong HNTH, UBND được thay bằng điểm nhánh và màu trạng thái kết nối.
        // Chỉ ẩn hiển thị tạm thời, không thay đổi cấu hình bật/tắt đã lưu.
        const visibility = layer.id === "government-ubnd" && activePanel === "conference"
          ? "none"
          : layer.visible ? "visible" : "none";
        setOperationalLayerVisibility(map, layer.id, visibility);
      }
    }
    // Dữ liệu nghiệp vụ phải nằm trên lớp làm mờ và lớp nền địa giới.
    raiseOperationalLayers(map, renderedLayers);
    refreshZoneSummary();
  }, [layers, administrativeUnits, selectedAdministrativeIds, defaultViewportEnabled, defaultAdministrativeIds, activePanel, isMapReady]);

  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map) return;
    const clusterRadius = clusterRadiusForLevel(clusterLevel);
    for (const layer of layers) {
      if (layer.geometryMode === "line") continue;
      const source = map.getSource(layer.id) as GeoJSONSource | undefined;
      source?.setClusterOptions({ cluster: true, clusterMaxZoom: 13, clusterRadius });
    }
  }, [clusterLevel, isMapReady]);

  useEffect(() => {
    if (!isDrawReady || !drawRef.current) return;
    drawRef.current.setMode(drawMode === "text" || drawMode === "icon" ? "static" : drawMode ?? "static");
    if (mapRef.current) mapRef.current.getCanvas().style.cursor = drawMode === "text" || drawMode === "icon" ? "crosshair" : "";
    if (mapRef.current) {
      syncTextMarkers(mapRef.current, textAnnotations, textMarkersRef.current);
      syncIconMarkers(mapRef.current, iconAnnotations, iconMarkersRef.current);
    }
  }, [drawMode, isDrawReady]);

  useEffect(() => {
    if (mapRef.current) syncTextMarkers(mapRef.current, textAnnotations, textMarkersRef.current);
  }, [textAnnotations, selectedAnnotation]);

  useEffect(() => {
    if (mapRef.current) syncIconMarkers(mapRef.current, iconAnnotations, iconMarkersRef.current);
  }, [iconAnnotations, selectedAnnotation]);

  useEffect(() => {
    if (!drawRef.current || selectedDrawFeatureId === null) return;
    const savedId = `geometry:${String(selectedDrawFeatureId)}`;
    const state = useAppStore.getState();
    if (state.savedDrawFeatures.some((item) => item.id === savedId)) state.deleteSavedObject("geometry", savedId);
    drawRef.current.removeFeatures([selectedDrawFeatureId]);
    useAppStore.getState().setSelectedDrawFeatureId(null);
    useAppStore.getState().setSelectedDrawFeatureInfo(null);
    useAppStore.getState().setZoneMode("draw");
    if (mapRef.current) {
      syncRadiusMarkers(mapRef.current, drawRef.current, radiusMarkersRef.current);
      syncDrawEditMarkers(mapRef.current, drawRef.current, null, drawEditMarkersRef.current);
    }
    refreshZoneSummary();
  }, [deleteDrawRequest]);

  useEffect(() => {
    const draw = drawRef.current;
    if (!isDrawReady || !draw) return;
    const nextManagedIds = new Set(savedDrawFeatures.map((item) => item.featureId));
    isSyncingSavedFeaturesRef.current = true;
    try {
      for (const id of managedSavedFeatureIdsRef.current) {
        const remainsVisible = savedDrawFeatures.some((item) => item.featureId === id && item.visible);
        if (!remainsVisible && draw.hasFeature(id)) draw.removeFeatures([id]);
      }
      for (const item of savedDrawFeatures) {
        if (item.visible && !draw.hasFeature(item.featureId)) draw.addFeatures([cleanDrawFeatureForStorage(item.feature)]);
        if (!item.visible && draw.hasFeature(item.featureId)) draw.removeFeatures([item.featureId]);
      }
    } finally {
      isSyncingSavedFeaturesRef.current = false;
      managedSavedFeatureIdsRef.current = nextManagedIds;
    }
    if (mapRef.current) {
      syncRadiusMarkers(mapRef.current, draw, radiusMarkersRef.current);
      syncDrawEditMarkers(mapRef.current, draw, useAppStore.getState().selectedDrawFeatureId, drawEditMarkersRef.current);
    }
    refreshZoneSummary();
  }, [isDrawReady, savedDrawFeatures]);

  useEffect(() => {
    const draw = drawRef.current;
    if (!draw || !saveSelectedObjectRequest || selectedDrawFeatureId === null) return;
    const snapshot = draw.getSnapshotFeature(selectedDrawFeatureId);
    if (snapshot) useAppStore.getState().upsertSavedDrawFeature(cleanDrawFeatureForStorage(snapshot), saveSelectedObjectRequest.name);
  }, [saveSelectedObjectRequest, selectedDrawFeatureId]);

  useEffect(() => {
    const request = focusSavedObjectRequest;
    const map = mapRef.current;
    if (!request || !map) return;
    const state = useAppStore.getState();
    if (request.kind === "text") {
      const item = state.textAnnotations.find((annotation) => annotation.id === request.id);
      if (!item) return;
      map.easeTo({ center: item.coordinates, zoom: Math.max(map.getZoom(), 15), duration: 600 });
      state.selectAnnotation("text", item.id);
      return;
    }
    if (request.kind === "icon") {
      const item = state.iconAnnotations.find((annotation) => annotation.id === request.id);
      if (!item) return;
      map.easeTo({ center: item.coordinates, zoom: Math.max(map.getZoom(), 15), duration: 600 });
      state.selectAnnotation("icon", item.id);
      return;
    }
    const item = state.savedDrawFeatures.find((featureItem) => featureItem.id === request.id);
    const draw = drawRef.current;
    if (!item || !draw) return;
    if (!draw.hasFeature(item.featureId)) draw.addFeatures([cleanDrawFeatureForStorage(item.feature)]);
    const featureBounds = bbox(item.feature);
    map.fitBounds([[featureBounds[0], featureBounds[1]], [featureBounds[2], featureBounds[3]]], { padding: 90, maxZoom: 16, duration: 600 });
    draw.setMode("select");
    state.setDrawMode("select");
    draw.selectFeature(item.featureId);
  }, [focusSavedObjectRequest]);

  useEffect(() => {
    if (!drawRef.current || selectedDrawFeatureId === null) return;
    drawRef.current.updateFeatureProperties(selectedDrawFeatureId, { fillColor: drawFillColor, fillOpacity: drawFillOpacity, outlineColor: drawOutlineColor });
  }, [selectedDrawFeatureId, drawFillColor, drawOutlineColor, drawFillOpacity]);

  useEffect(() => {
    if (!drawRef.current || !drawRadiusUpdate) return;
    const info = describeDrawFeature(drawRef.current, drawRadiusUpdate.id);
    if (!info || info.kind !== "circle") return;
    const resizedCircle = circle(info.center, drawRadiusUpdate.meters, { steps: 96, units: "meters" });
    const geometry = {
      ...resizedCircle.geometry,
      coordinates: resizedCircle.geometry.coordinates.map((ring) =>
        ring.map(([longitude, latitude]) => [
          Number(longitude.toFixed(6)),
          Number(latitude.toFixed(6)),
        ]),
      ),
    };
    drawRef.current.updateFeatureGeometry(drawRadiusUpdate.id, geometry);
    useAppStore.getState().setSelectedDrawFeatureInfo(describeDrawFeature(drawRef.current, drawRadiusUpdate.id));
    if (mapRef.current) {
      syncRadiusMarkers(mapRef.current, drawRef.current, radiusMarkersRef.current);
      syncDrawEditMarkers(mapRef.current, drawRef.current, drawRadiusUpdate.id, drawEditMarkersRef.current);
    }
    refreshZoneSummary();
  }, [drawRadiusUpdate]);

  useEffect(() => {
    if (!mapRef.current || !drawRef.current) return;
    syncDrawEditMarkers(
      mapRef.current,
      drawRef.current,
      drawMode === "select" ? selectedDrawFeatureId : null,
      drawEditMarkersRef.current,
    );
  }, [selectedDrawFeatureId, drawMode, isDrawReady]);

  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map || administrativeUnits.length === 0) return;
    const data = unitsToFeatureCollection(administrativeUnits);
    if (!map.getSource("administrative-units")) {
      map.addSource("administrative-units", { type: "geojson", data });
    } else {
      (map.getSource("administrative-units") as GeoJSONSource).setData(data);
    }
    const officialLabelPoints = buildOfficialAdministrativeLabelPoints(administrativeUnits);
    if (!map.getSource(OFFICIAL_ADMINISTRATIVE_LABEL_SOURCE_ID)) {
      map.addSource(OFFICIAL_ADMINISTRATIVE_LABEL_SOURCE_ID, { type: "geojson", data: officialLabelPoints });
    } else {
      (map.getSource(OFFICIAL_ADMINISTRATIVE_LABEL_SOURCE_ID) as GeoJSONSource).setData(officialLabelPoints);
    }
    if (!map.getSource("haiphong-outside-mask")) {
      map.addSource("haiphong-outside-mask", { type: "geojson", data: buildOutsideMask(administrativeUnits) });
    } else {
      (map.getSource("haiphong-outside-mask") as GeoJSONSource).setData(buildOutsideMask(administrativeUnits));
    }
    if (!map.getLayer("haiphong-outside-mask")) {
      map.addLayer({ id: "haiphong-outside-mask", type: "fill", source: "haiphong-outside-mask", layout: { visibility: useAppStore.getState().dimOutsideHaiphong ? "visible" : "none" }, paint: { "fill-color": "#03101a", "fill-opacity": 0.64 } });
    }
    const shouldBindAdministrativeInteractions = !map.getLayer("administrative-fill");
    if (!map.getLayer("administrative-fill")) {
      map.addLayer({ id: "administrative-fill", type: "fill", source: "administrative-units", paint: { "fill-color": "#38bdf8", "fill-opacity": 0.045 } });
    }
    if (!map.getLayer("administrative-line")) {
      map.addLayer({ id: "administrative-line", type: "line", source: "administrative-units", paint: { "line-color": "#73a8bd", "line-width": 0.8, "line-opacity": 0.42 } });
    }
    const administrativeLabelVisibility = officialAdministrativeLabelsVisible(useAppStore.getState().baseMapMode) ? "visible" : "none";
    if (!map.getLayer(OFFICIAL_ADMINISTRATIVE_LABEL_LAYER_ID)) {
      map.addLayer({
        id: OFFICIAL_ADMINISTRATIVE_LABEL_LAYER_ID,
        type: "symbol",
        source: OFFICIAL_ADMINISTRATIVE_LABEL_SOURCE_ID,
        minzoom: 8,
        filter: ["==", ["get", "priority"], false],
        layout: {
          visibility: administrativeLabelVisibility,
          "text-field": ["concat", ["get", "shortType"], ". ", ["get", "name"]],
          "text-font": ["Noto Sans Regular"],
          "text-size": ["interpolate", ["linear"], ["zoom"], 8, 9.5, 11, 12],
          "text-offset": [0, 1.05],
          "text-anchor": "top",
          "text-max-width": 10,
          "text-allow-overlap": false,
          "text-ignore-placement": false,
        },
        paint: {
          "text-color": "#f8fafc",
          "text-halo-color": "#07131e",
          "text-halo-width": 1.6,
          "text-halo-blur": 0.4,
        },
      });
    }
    if (!map.getLayer(PRIORITY_ADMINISTRATIVE_LABEL_LAYER_ID)) {
      map.addLayer({
        id: PRIORITY_ADMINISTRATIVE_LABEL_LAYER_ID,
        type: "symbol",
        source: OFFICIAL_ADMINISTRATIVE_LABEL_SOURCE_ID,
        minzoom: 7.5,
        filter: ["==", ["get", "priority"], true],
        layout: {
          visibility: administrativeLabelVisibility,
          "text-field": ["concat", ["get", "shortType"], ". ", ["get", "name"]],
          "text-font": ["Noto Sans Regular"],
          "text-size": ["interpolate", ["linear"], ["zoom"], 7.5, 10, 11, 12.5],
          // Hai phường Đồ Sơn ở gần nhau: neo nhãn về hai phía đối diện để
          // cả Đồ Sơn và Nam Đồ Sơn luôn đọc được ở khung toàn thành phố.
          "text-anchor": [
            "match", ["get", "name"],
            "Nam Đồ Sơn", "bottom-right",
            "Đồ Sơn", "top-left",
            "top",
          ],
          "text-offset": [0, 0.8],
          "text-max-width": 12,
          "text-allow-overlap": true,
          "text-ignore-placement": false,
        },
        paint: {
          "text-color": "#ffffff",
          "text-halo-color": "#04111b",
          "text-halo-width": 2,
          "text-halo-blur": 0.45,
        },
      });
    }
    if (!map.getLayer("administrative-selected")) {
      const preferences = useAppStore.getState();
      map.addLayer({ id: "administrative-selected", type: "fill", source: "administrative-units", filter: ["==", ["get", "id"], -1], paint: { "fill-color": preferences.administrativeFillColor, "fill-opacity": preferences.administrativeFillOpacity, "fill-outline-color": preferences.administrativeOutlineColor } });
    }
    if (!map.getLayer("administrative-selected-line")) {
      map.addLayer({ id: "administrative-selected-line", type: "line", source: "administrative-units", filter: ["==", ["get", "id"], -1], paint: { "line-color": useAppStore.getState().administrativeOutlineColor, "line-width": 2.8, "line-opacity": 1, "line-dasharray": [3, 2] } });
    }
    if (!map.getLayer("administrative-focused")) {
      map.addLayer({ id: "administrative-focused", type: "fill", source: "administrative-units", filter: ["==", ["get", "id"], -1], paint: { "fill-color": "#ffffff", "fill-opacity": SELECTED_ZONE_FILL_OPACITY } });
    }
    if (!map.getLayer("administrative-focused-line")) {
      map.addLayer({ id: "administrative-focused-line", type: "line", source: "administrative-units", filter: ["==", ["get", "id"], -1], paint: { "line-color": "#ffffff", "line-width": 3.4, "line-opacity": 1, "line-dasharray": [3, 2] } });
    }
    if (!map.getLayer("administrative-inspected-line")) {
      // Viền xem địa giới dùng riêng cho menu Lớp đối tượng và HNTH. Đây là
      // đường trắng liền, mảnh và không thêm địa giới vào vùng của Khoanh vùng.
      map.addLayer({ id: "administrative-inspected-line", type: "line", source: "administrative-units", filter: ["==", ["get", "id"], -1], paint: { "line-color": "#ffffff", "line-width": 1.1, "line-opacity": 1 } });
    }
    if (!map.getLayer("administrative-hnth-hover-line")) {
      // Chỉ menu HNTH dùng lớp này: địa giới dưới con trỏ có viền trắng mảnh;
      // filter luôn chỉ chứa một id nên khi rê sang nơi khác, viền cũ tự mất.
      map.addLayer({ id: "administrative-hnth-hover-line", type: "line", source: "administrative-units", filter: ["==", ["get", "id"], -1], paint: { "line-color": "#ffffff", "line-width": 1.1, "line-opacity": 0.95 } });
    }
    if (!map.getSource("administrative-focus-connection")) {
      map.addSource("administrative-focus-connection", { type: "geojson", data: featureCollection([]) });
    }
    if (!map.getLayer("administrative-focus-connection-casing")) {
      map.addLayer({ id: "administrative-focus-connection-casing", type: "line", source: "administrative-focus-connection", filter: ["==", ["geometry-type"], "LineString"], paint: { "line-color": "#06131d", "line-width": 5.5, "line-opacity": 0.88 } });
    }
    if (!map.getLayer("administrative-focus-connection-line")) {
      map.addLayer({ id: "administrative-focus-connection-line", type: "line", source: "administrative-focus-connection", filter: ["==", ["geometry-type"], "LineString"], paint: { "line-color": "#2dd4bf", "line-width": 2.6, "line-opacity": 1 } });
    }
    if (!map.getLayer("administrative-focus-connection-point")) {
      map.addLayer({
        id: "administrative-focus-connection-point",
        type: "circle",
        source: "administrative-focus-connection",
        filter: ["==", ["geometry-type"], "Point"],
        paint: {
          "circle-radius": 5,
          // Đồng bộ màu điểm đại diện với lớp UBND: xã xanh ngọc, phường
          // xanh dương và đặc khu tím nhạt.
          "circle-color": [
            "match", ["get", "administrativeType"],
            "xã", UBND_POINT_COLORS.xã,
            "phường", UBND_POINT_COLORS.phường,
            "đặc khu", UBND_POINT_COLORS["đặc khu"],
            UBND_POINT_COLORS.xã,
          ],
          "circle-stroke-color": "#ffffff",
          "circle-stroke-width": 2.2,
        },
      });
    }
    if (shouldBindAdministrativeInteractions) {
      map.on("click", "administrative-fill", (event) => {
        const state = useAppStore.getState();
        const id = Number(event.features?.[0]?.properties?.id);
        if (!id) return;
        const clickedUnit = state.administrativeUnits.find((candidate) => candidate.id === id);
        const restoredCityOverview = clickedUnit?.name.trim().toLocaleLowerCase("vi") === "bạch long vĩ"
          ? false
          : restoreHaiphongOverviewIfZoomedOut(map);
        if (state.activePanel === "conference") {
          // Trên mobile, chạm vào địa giới là thao tác chọn/khoanh vùng trước
          // hết; không mở thẻ chi tiết endpoint che mất phần lớn bản đồ.
          if (window.matchMedia("(max-width: 760px)").matches && clickedUnit) {
            map.setMaxBounds(REGIONAL_OPERATIONAL_BOUNDS);
            setInspectedAdministrativeId(id);
            setInspectedAdministrativeIds([id]);
            // Mobile chỉ giữ viền khoanh vùng, không mở popup chi tiết kết nối.
            setFixedMapInfo(null);
            clearAdministrativeConnection(map);
            const unitBounds = bbox(clickedUnit.geometry as Polygon | MultiPolygon);
            map.fitBounds([[unitBounds[0], unitBounds[1]], [unitBounds[2], unitBounds[3]]], { padding: 56, maxZoom: 12, duration: 700 });
            return;
          }
          // Trong menu HNTH, toàn bộ mặt địa giới là vùng tương tác của điểm
          // nhánh. Nhờ vậy người dùng không cần bấm chính xác vào chấm tròn.
          // Nếu bấm ngay trên chấm thì để handler của chấm xử lý, tránh mở 2 popup.
          if (hasHnthPointAt(map, event.point)) return;
          const wardCode = String(event.features?.[0]?.properties?.wardCode ?? "");
          const hnthLayer = state.layers.find((item) => item.id === HNTH_LAYER_ID);
          const branch = hnthLayer?.data.features.find((item) => (
            item.geometry.type === "Point"
            && item.properties?.role === "branch"
            && String(item.properties?.wardCode ?? "") === wardCode
          ));
          if (branch?.geometry.type === "Point") {
            showHnthPointPopup(map, branch.geometry.coordinates as [number, number], branch.properties);
          }
          return;
        }
        if (state.activePanel === "zones" && state.zoneMode === "administrative") {
          // Khi click từ mức zoom-out rộng hơn thành phố, ưu tiên dừng ở khung
          // toàn Hải Phòng thay vì lập tức phóng tiếp vào riêng địa giới vừa chọn.
          suppressNextAdministrativeSelectionFitRef.current = restoredCityOverview && !window.matchMedia("(max-width: 760px)").matches;
          const wasFocused = state.focusedAdministrativeId === id;
          state.cycleAdministrativeUnit(id);
          if (wasFocused) {
            setFixedMapInfo(null);
            clearAdministrativeConnection(map);
            return;
          }
          const unit = clickedUnit;
          if (unit) {
            setFixedMapInfo({ kind: "administrative", unitId: unit.id, includeConnectionPoint: false });
            showAdministrativeConnection(map, unit);
          }
          return;
        }

        // Ở các menu còn lại, click vào phần nền của địa giới sẽ mở thông tin
        // xã/phường/đặc khu. Nếu đang click đúng một đối tượng nghiệp vụ thì để
        // popup của đối tượng đó xử lý, tránh hai popup xuất hiện cùng lúc.
        if (hasInspectableOperationalFeatureAt(map, event.point)) return;
        const unit = clickedUnit;
        if (!unit) return;
        if (state.activePanel === "layers") {
          setInspectedAdministrativeId(id);
          setInspectedAdministrativeIds([id]);
        }
        setFixedMapInfo({ kind: "administrative", unitId: unit.id, includeConnectionPoint: false });
        showAdministrativeConnection(map, unit);
      });
      map.on("mouseenter", "administrative-fill", () => {
        map.getCanvas().style.cursor = "pointer";
      });
      map.on("mousemove", "administrative-fill", (event) => {
        if (useAppStore.getState().activePanel !== "conference") return;
        const hoveredId = Number(event.features?.[0]?.properties?.id);
        if (!hoveredId || !map.getLayer("administrative-hnth-hover-line")) return;
        map.setFilter("administrative-hnth-hover-line", ["==", ["get", "id"], hoveredId]);
        map.moveLayer("administrative-hnth-hover-line");
      });
      map.on("mouseleave", "administrative-fill", () => {
        map.getCanvas().style.cursor = "";
        if (map.getLayer("administrative-hnth-hover-line")) {
          map.setFilter("administrative-hnth-hover-line", ["==", ["get", "id"], -1]);
        }
      });
    }
    // Hiệu ứng địa giới được tạo sau dữ liệu nghiệp vụ; đưa các lớp đang bật
    // trở lại trên cùng để đường/điểm không bị lớp làm mờ che khuất.
    if (map.getLayer("vietnam-province-boundaries")) map.moveLayer("vietnam-province-boundaries");
    raiseOperationalLayers(map, useAppStore.getState().layers);
    if (map.getLayer(OFFICIAL_ADMINISTRATIVE_LABEL_LAYER_ID)) map.moveLayer(OFFICIAL_ADMINISTRATIVE_LABEL_LAYER_ID);
    if (map.getLayer(PRIORITY_ADMINISTRATIVE_LABEL_LAYER_ID)) map.moveLayer(PRIORITY_ADMINISTRATIVE_LABEL_LAYER_ID);
  }, [administrativeUnits, isMapReady]);

  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map?.getSource("administrative-units")) return;
    const hnthLayer = layers.find((layer) => layer.id === HNTH_LAYER_ID);
    if (!hnthLayer) return;
    // HNTH là lớp giám sát nền: chuyển menu không được làm mất điểm, line,
    // màu nền hoặc các popup khi agent vẫn đang chạy.
    syncHnthVisualStyles(map, hnthLayer, hnthLineVisible, hnthLineStyles, hnthAreaStyles, hnthAreaVisible, hnthPointVisible, true);

    // Sau F5, React có thể cập nhật trạng thái trước khi MapLibre nạp xong
    // source GeoJSON. Khi đó querySourceFeatures() trả về rỗng, cache đánh
    // dấu là đã đồng bộ và line/fill không được vẽ lại. Đồng bộ lại khi một
    // trong hai source liên quan phát thông báo đã nạp dữ liệu; thao tác này
    // chỉ cập nhật feature-state, không setData nên không gây nháy bản đồ.
    const resyncAfterSourceLoad = (event: { sourceId?: string }) => {
      if (event.sourceId !== HNTH_LAYER_ID && event.sourceId !== "administrative-units") return;
      const latestLayer = useAppStore.getState().layers.find((layer) => layer.id === HNTH_LAYER_ID);
      if (!latestLayer) return;
      syncHnthVisualStyles(map, latestLayer, hnthLineVisible, hnthLineStyles, hnthAreaStyles, hnthAreaVisible, hnthPointVisible, true, true);
    };
    map.on("sourcedata", resyncAfterSourceLoad);
    return () => {
      map.off("sourcedata", resyncAfterSourceLoad);
    };
  }, [layers, administrativeUnits, hnthLineVisible, hnthLineStyles, hnthAreaStyles, hnthAreaVisible, hnthPointVisible, activePanel, isMapReady]);

  useEffect(() => {
    // Popup HNTH và trạng thái giám sát là lớp vận hành nền, nên giữ nguyên
    // khi người dùng chuyển sang menu khác. Các popup ngữ cảnh khác vẫn đóng.
    if (fixedMapInfo?.kind === "hnth") return;
    clearMapInspection();
    const map = mapRef.current;
    if (map?.getLayer("administrative-hnth-hover-line")) {
      map.setFilter("administrative-hnth-hover-line", ["==", ["get", "id"], -1]);
    }
  }, [activePanel, clearMapInspection, fixedMapInfo?.kind]);

  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map?.getLayer("administrative-inspected-line")) return;
    const ids = activePanel === "layers" || activePanel === "conference" ? inspectedAdministrativeIds : [];
    map.setFilter("administrative-inspected-line", ids.length === 1 ? ["==", ["get", "id"], ids[0]] : ids.length > 1 ? ["in", ["get", "id"], ["literal", ids]] : ["==", ["get", "id"], -1]);
    if (ids.length) map.moveLayer("administrative-inspected-line");
  }, [activePanel, inspectedAdministrativeIds, administrativeUnits, isMapReady]);

  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map) return;
    const controller = new AbortController();

    void fetch("/data/vietnam-provinces.geojson", { signal: controller.signal })
      .then((response) => {
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return response.json() as Promise<GeoJSON.FeatureCollection>;
      })
      .then((data) => {
        if (controller.signal.aborted) return;
        if (!map.getSource("vietnam-provinces")) {
          map.addSource("vietnam-provinces", {
            type: "geojson",
            data,
            attribution: "Ranh giới tỉnh: GISData (đơn vị hành chính Việt Nam từ 2025)",
          });
        } else {
          (map.getSource("vietnam-provinces") as GeoJSONSource).setData(data);
        }
        if (!map.getLayer("vietnam-province-boundaries")) {
          map.addLayer({
            id: "vietnam-province-boundaries",
            type: "line",
            source: "vietnam-provinces",
            filter: ["==", ["get", "kind"], "boundary"],
            paint: {
              "line-color": "#ffffff",
              "line-width": ["interpolate", ["linear"], ["zoom"], 7, 0.75, 11, 1.25],
              "line-opacity": 0.9,
              "line-dasharray": [2.4, 2.4],
            },
          });
        }

        for (const marker of vietnamProvinceLabelMarkersRef.current) marker.remove();
        vietnamProvinceLabelMarkersRef.current = data.features
          .filter((item): item is GeoJSON.Feature<GeoJSON.Point> =>
            item.geometry?.type === "Point"
            && ["label", "archipelago-label"].includes(String(item.properties?.kind)),
          )
          .map((item) => {
            const element = document.createElement("div");
            const isArchipelago = item.properties?.kind === "archipelago-label";
            const name = String(item.properties?.name ?? "");
            element.className = `vietnam-province-label${isArchipelago ? " archipelago-label" : ""}`;
            element.textContent = name;
            element.setAttribute("aria-label", name.replace("\n", " "));
            const coordinates = item.geometry.coordinates as [number, number];
            // Nhãn Hưng Yên nằm sát vùng hiển thị Hải Phòng ở các mức zoom
            // tổng quan. Dịch nhẹ về tây-bắc để không chồng lên địa giới,
            // áp dụng tại lớp nhãn dùng chung cho mọi chế độ bản đồ.
            const normalizedName = name.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toUpperCase();
            const labelCoordinates: [number, number] = normalizedName === "HUNG YEN"
              ? [coordinates[0] - 0.12, coordinates[1] + 0.05]
              : coordinates;
            return new maplibregl.Marker({ element, anchor: "center" })
              .setLngLat(labelCoordinates)
              .addTo(map);
          });
      })
      .catch((error: unknown) => {
        if (!controller.signal.aborted) console.warn("Không tải được ranh giới tỉnh/thành Việt Nam.", error);
      });

    return () => controller.abort();
  }, [isMapReady]);

  useEffect(() => {
    const removeHubPulse = () => {
      hnthHubPulseMarkerRef.current?.remove();
      hnthHubPulseMarkerRef.current = null;
    };

    const syncHubPulse = () => {
      const map = mapRef.current;
      const hnthLayer = layers.find((layer) => layer.id === HNTH_LAYER_ID);
      const hub = hnthLayer?.data.features.find((feature) => (
        feature.geometry.type === "Point" && feature.properties?.role === "hub"
      ));
      if (!map || !isMapReady || !hnthContinuousMonitoringRef.current || !hnthAgentOnlineRef.current || activePanel !== "conference" || !hub || hub.geometry.type !== "Point") {
        removeHubPulse();
        return;
      }
      if (!hnthHubPulseMarkerRef.current) {
        const element = document.createElement("div");
        element.className = "hnth-hub-pulse-marker";
        element.setAttribute("aria-label", "Giám sát liên tục đang hoạt động tại Trung tâm Chính trị - Hành chính");
        element.innerHTML = '<span class="hnth-hub-pulse-dot"></span><span class="hnth-hub-pulse-ring"></span>';
        hnthHubPulseMarkerRef.current = new maplibregl.Marker({ element, anchor: "center" })
          .setLngLat(hub.geometry.coordinates as [number, number])
          .addTo(map);
      } else {
        hnthHubPulseMarkerRef.current.setLngLat(hub.geometry.coordinates as [number, number]);
      }
    };

    const onMonitoring = (event: Event) => {
      hnthContinuousMonitoringRef.current = Boolean((event as CustomEvent<{ enabled?: boolean }>).detail?.enabled);
      syncHubPulse();
    };
    const onAgentStatus = (event: Event) => {
      // Sự kiện này luôn mô tả agent đang được chọn cho HNTH (HnthPanel/App lọc sẵn).
      const detail = (event as CustomEvent<{ agentId?: string; online?: boolean }>).detail;
      hnthAgentOnlineRef.current = Boolean(detail.online);
      syncHubPulse();
    };
    window.addEventListener("hnth:continuous-monitoring", onMonitoring);
    window.addEventListener("hnth:agent-status", onAgentStatus);
    syncHubPulse();
    return () => {
      window.removeEventListener("hnth:continuous-monitoring", onMonitoring);
      window.removeEventListener("hnth:agent-status", onAgentStatus);
      removeHubPulse();
    };
  }, [activePanel, isMapReady, layers]);

  useEffect(() => {
    const captureBackground = (event: Event) => {
      const detail = (event as CustomEvent<{ resolve?: (dataUrl: string | null) => void; staticOnly?: boolean }>).detail;
      const resolve = detail?.resolve;
      const map = mapRef.current;
      if (!resolve || !map || !isMapReady) { resolve?.(null); return; }
      const canvas = map.getCanvas();
      const hiddenLayers = detail.staticOnly
        ? [
          `${HNTH_LAYER_ID}-line-glow`, `${HNTH_LAYER_ID}-line`, `${HNTH_LAYER_ID}-branch-point`,
          `${HNTH_LAYER_ID}-area`,
          `${HNTH_LAYER_ID}-area-unknown`, `${HNTH_LAYER_ID}-area-unconnected`,
          `${HNTH_LAYER_ID}-area-connected`, `${HNTH_LAYER_ID}-area-lost`,
        ].filter((id) => map.getLayer(id) && map.getLayoutProperty(id, "visibility") !== "none")
        : [];
      for (const id of hiddenLayers) map.setLayoutProperty(id, "visibility", "none");
      const handleRender = () => {
        map.off("render", handleRender);
        try {
          resolve(canvas.toDataURL("image/jpeg", 0.9));
        } catch {
          resolve(null);
        } finally {
          for (const id of hiddenLayers) map.setLayoutProperty(id, "visibility", "visible");
        }
      };
      map.once("render", handleRender);
      map.triggerRepaint();
    };
    window.addEventListener(MAP_CAPTURE_BACKGROUND_EVENT, captureBackground);
    return () => window.removeEventListener(MAP_CAPTURE_BACKGROUND_EVENT, captureBackground);
  }, [isMapReady]);

  useEffect(() => {
    const providePresentationGeometry = (event: Event) => {
      const resolve = (event as CustomEvent<{ resolve?: (value: unknown) => void }>).detail?.resolve;
      const map = mapRef.current;
      if (!resolve || !map || !isMapReady) { resolve?.(null); return; }
      const projectCoordinate = (coordinates: [number, number]) => {
        const projected = map.project(coordinates);
        return [Number(projected.x.toFixed(2)), Number(projected.y.toFixed(2))] as [number, number];
      };
      const projectGeometry = (geometry: GeoJSON.Geometry): unknown => {
        if (geometry.type === "Point") return projectCoordinate(geometry.coordinates as [number, number]);
        if (geometry.type === "LineString" || geometry.type === "MultiPoint") return geometry.coordinates.map((item) => projectCoordinate(item as [number, number]));
        if (geometry.type === "Polygon" || geometry.type === "MultiLineString") return geometry.coordinates.map((line) => line.map((item) => projectCoordinate(item as [number, number])));
        if (geometry.type === "MultiPolygon") return geometry.coordinates.map((polygon) => polygon.map((line) => line.map((item) => projectCoordinate(item as [number, number]))));
        if (geometry.type === "GeometryCollection") return geometry.geometries.map(projectGeometry);
        return null;
      };
      const state = useAppStore.getState();
      const hnthLayer = state.layers.find((item) => item.id === HNTH_LAYER_ID);
      const features = hnthLayer?.data.features ?? [];
      const hub = features.find((item) => item.geometry.type === "Point" && item.properties?.role === "hub");
      const branches = features
        .filter((item) => item.geometry.type === "Point" && item.properties?.role === "branch")
        .map((item) => ({
          pointId: String(item.properties?.pointId ?? item.id ?? ""),
          wardCode: String(item.properties?.wardCode ?? ""),
          coordinates: projectCoordinate((item.geometry as GeoJSON.Point).coordinates as [number, number]),
        }));
      const lines = features
        .filter((item) => item.geometry.type === "LineString")
        .map((item) => ({
          pointId: String(item.properties?.pointId ?? item.id ?? ""),
          geometry: projectGeometry(item.geometry),
        }));
      const areas = state.administrativeUnits.map((unit) => ({
        wardCode: String(unit.wardCode),
        geometry: projectGeometry(unit.geometry),
      }));
      const canvas = map.getCanvas();
      resolve({
        width: canvas.clientWidth || canvas.width,
        height: canvas.clientHeight || canvas.height,
        hub: hub?.geometry.type === "Point" ? projectCoordinate(hub.geometry.coordinates as [number, number]) : null,
        branches,
        lines,
        areas,
        lineVisible: state.hnthLineVisible,
        areaVisible: state.hnthAreaVisible,
        lineStyles: state.hnthLineStyles,
        areaStyles: state.hnthAreaStyles,
      });
    };
    window.addEventListener(MAP_PRESENTATION_GEOMETRY_EVENT, providePresentationGeometry);
    return () => window.removeEventListener(MAP_PRESENTATION_GEOMETRY_EVENT, providePresentationGeometry);
  }, [isMapReady]);

  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map?.getLayer("haiphong-outside-mask")) return;
    map.setLayoutProperty("haiphong-outside-mask", "visibility", dimOutsideHaiphong ? "visible" : "none");
  }, [dimOutsideHaiphong, isMapReady]);

  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map?.getLayer("administrative-fill")) return;
    // Khi click lần 2, địa giới focus chỉ dùng lớp trắng trong suốt giống vùng tự vẽ;
    // loại nó khỏi lớp nền "đã chọn" để hai lớp màu không chồng làm nền bị đậm.
    const visibleSelectedIds = activePanel === "zones"
      ? selectedAdministrativeIds.filter((id) => id !== focusedAdministrativeId)
      : [];
    const filter: maplibregl.FilterSpecification = visibleSelectedIds.length > 0
      ? ["in", ["get", "id"], ["literal", visibleSelectedIds]]
      : ["==", ["get", "id"], -1];
    if (map.getLayer("administrative-selected")) map.setFilter("administrative-selected", filter);
    if (map.getLayer("administrative-selected-line")) map.setFilter("administrative-selected-line", filter);
    refreshZoneSummary();
    // Trong chuyển cảnh Home/khởi động, giữ nguyên khung toàn Hải Phòng đủ thời
    // gian cấu hình; không để danh sách vùng đã chọn tự zoom sớm vào địa giới.
    if (isHomeTransitionActiveRef.current) return;
    if (activePanel !== "zones" || selectedAdministrativeIds.length === 0) return;
    if (suppressNextAdministrativeSelectionFitRef.current) {
      suppressNextAdministrativeSelectionFitRef.current = false;
      return;
    }
    const selected = administrativeUnits.filter((unit) => selectedAdministrativeIds.includes(unit.id));
    if (selected.length === 0) return;
    const bounds = bbox(unitsToFeatureCollection(selected));
    map.fitBounds([[bounds[0], bounds[1]], [bounds[2], bounds[3]]], { padding: 80, maxZoom: 12.5, duration: 700 });
  }, [selectedAdministrativeIds, focusedAdministrativeId, administrativeUnits, activePanel, isMapReady]);

  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map?.getLayer("administrative-fill")) return;
    const filter: maplibregl.FilterSpecification = ["==", ["get", "id"], focusedAdministrativeId ?? -1];
    if (map.getLayer("administrative-focused")) map.setFilter("administrative-focused", filter);
    if (map.getLayer("administrative-focused-line")) map.setFilter("administrative-focused-line", filter);

    const connectionSource = map.getSource("administrative-focus-connection") as GeoJSONSource | undefined;
    connectionSource?.setData(featureCollection([]));
    if (focusedAdministrativeId === null) {
      setFixedMapInfo((current) => current?.kind === "administrative" ? null : current);
      return;
    }

    const unit = administrativeUnits.find((candidate) => candidate.id === focusedAdministrativeId);
    if (!unit) return;
    setFixedMapInfo({ kind: "administrative", unitId: unit.id, includeConnectionPoint: true });
    showAdministrativeConnection(map, unit);
  }, [focusedAdministrativeId, administrativeUnits, isMapReady]);

  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map?.getLayer("administrative-fill") || !map.getLayer("administrative-line")) return;
    const showZoneSelection = activePanel === "zones";
    const selectedCondition: maplibregl.ExpressionSpecification = showZoneSelection && selectedAdministrativeIds.length > 0
      ? ["in", ["get", "id"], ["literal", selectedAdministrativeIds]]
      : ["==", ["get", "id"], -1];
    const focusedCondition: maplibregl.ExpressionSpecification = ["==", ["get", "id"], showZoneSelection ? focusedAdministrativeId ?? -1 : -1];
    // HNTH tự tô nền theo trạng thái kết nối nên không chồng màu khung mặc định.
    const hasDefaultAdministrativeUnit = activePanel !== "conference" && defaultViewportEnabled && defaultAdministrativeIds.length > 0;
    const defaultCondition: maplibregl.ExpressionSpecification = hasDefaultAdministrativeUnit
      ? ["in", ["get", "id"], ["literal", defaultAdministrativeIds]]
      : ["==", ["get", "id"], -1];
    map.setPaintProperty("administrative-fill", "fill-color", [
      "case",
      focusedCondition, "#ffffff",
      defaultCondition, "#fde68a",
      selectedCondition, administrativeFillColor,
      hasDefaultAdministrativeUnit, DEFAULT_VIEWPORT_SURROUNDING_FILL_COLOR,
      "#38bdf8",
    ]);
    map.setPaintProperty("administrative-fill", "fill-opacity", [
      "case",
      focusedCondition, 0,
      // Địa giới mặc định không bị phủ màu để phần bản đồ bên trong hiển thị 100%.
      defaultCondition, 0,
      // Vùng đã chọn được tô bởi lớp administrative-selected ở phía trên để
      // độ trong suốt người dùng chọn không bị cộng dồn qua hai lớp nền.
      selectedCondition, 0,
      // 0.15 = độ đục 15% (trong suốt 85%) cho màu phủ các địa giới còn lại.
      hasDefaultAdministrativeUnit, 0.15,
      0.045,
    ]);
    map.setPaintProperty("administrative-line", "line-color", [
      "case",
      focusedCondition, "#ffffff",
      defaultCondition, "#fbbf24",
      selectedCondition, administrativeOutlineColor,
      hasDefaultAdministrativeUnit, DEFAULT_VIEWPORT_SURROUNDING_LINE_COLOR,
      "#73a8bd",
    ]);
    map.setPaintProperty("administrative-line", "line-width", [
      "case",
      focusedCondition, 3.4,
      defaultCondition, 2.8,
      selectedCondition, 2.8,
      0.8,
    ]);
    map.setPaintProperty("administrative-line", "line-opacity", [
      "case",
      focusedCondition, 1,
      defaultCondition, 1,
      selectedCondition, 1,
      0.42,
    ]);
  }, [selectedAdministrativeIds, focusedAdministrativeId, defaultAdministrativeIds, defaultViewportEnabled, administrativeFillColor, administrativeOutlineColor, administrativeFillOpacity, administrativeUnits, activePanel, isMapReady]);

  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map?.getLayer("administrative-selected")) return;
    map.setPaintProperty("administrative-selected", "fill-color", administrativeFillColor);
    map.setPaintProperty("administrative-selected", "fill-opacity", administrativeFillOpacity);
    map.setPaintProperty("administrative-selected-line", "line-color", administrativeOutlineColor);
  }, [administrativeFillColor, administrativeOutlineColor, administrativeFillOpacity, administrativeUnits, isMapReady]);

  return (
    <>
      <div ref={containerRef} className="map-canvas" aria-label="Bản đồ giám sát Hải Phòng" />
      <div className="map-navigation-tools" aria-label="Công cụ điều hướng bản đồ">
        {isBaseMapMenuOpen && (
          <div className="base-map-menu" role="menu" aria-label="Chế độ bản đồ">
            <span>CHẾ ĐỘ BẢN ĐỒ</span>
            {baseMapOptions.map((option) => {
              const Icon = option.icon;
              return (
                <button
                  key={option.id}
                  className={baseMapMode === option.id ? "active" : ""}
                  type="button"
                  role="menuitemradio"
                  aria-checked={baseMapMode === option.id}
                  onClick={() => {
                    useAppStore.getState().setBaseMapMode(option.id);
                    setIsBaseMapMenuOpen(false);
                  }}
                >
                  <Icon size={16}/><span><strong>{option.label}</strong><small>{option.description}</small></span>
                </button>
              );
            })}
          </div>
        )}
        <button
          className={isBaseMapMenuOpen ? "active" : ""}
          type="button"
          title="Chọn chế độ bản đồ"
          aria-label="Chọn chế độ bản đồ"
          aria-expanded={isBaseMapMenuOpen}
          onClick={() => setIsBaseMapMenuOpen((open) => !open)}
        ><Layers3 size={17}/></button>
        <button type="button" title="Về khung hình mặc định (Home)" aria-label="Go home về khung hình mặc định" onClick={goHome}><Home size={17}/></button>
      </div>
      {fixedAdministrativeUnit && fixedMapInfo?.kind === "administrative" && (
        <AdministrativeFixedInfoCard
          unit={fixedAdministrativeUnit}
          includeConnectionPoint={fixedMapInfo.includeConnectionPoint}
          onClose={() => {
            clearMapInspection();
            if (activePanel === "zones") useAppStore.getState().clearAdministrativeFocus();
          }}
        />
      )}
      {fixedHnthProperties && fixedMapInfo?.kind === "hnth" && (
        <HnthFixedInfoCard properties={fixedHnthProperties} onClose={clearMapInspection} />
      )}
      {activePanel === "zones" && zoneSummary.zoneCount > 0 && (
        <aside className="zone-summary-popup" aria-label="Thông tin tổng hợp đối tượng các lớp">
          <span>THÔNG TIN TỔNG HỢP</span>
          <strong>{zoneSummary.zoneCount} vùng đang bật</strong>
          <div>
            {zoneSummary.items.map((item) => (
              <p key={item.id}><i style={{ backgroundColor: item.color }}/><b>{item.count}</b> {item.label}</p>
            ))}
          </div>
          {zoneSummary.items.every((item) => item.count === 0) && <small>Chưa có đối tượng thuộc các lớp đang bật nằm trong vùng.</small>}
          <div className="zone-summary-totals">
            <p><span>Phân loại vùng</span><b>{zoneSummary.drawnZoneCount} vùng và {zoneSummary.administrativeZoneCount} địa giới</b></p>
            <p><span>Tổng diện tích</span><b>{formatSummaryArea(zoneSummary.totalAreaSquareMeters)}</b></p>
            <p><span>Tổng dân số <em>(ước tính)</em></span><b>≈ {new Intl.NumberFormat("vi-VN").format(zoneSummary.estimatedPopulation)} người</b></p>
          </div>
        </aside>
      )}
    </>
  );
}

function featureColor(property: "fillColor" | "outlineColor", fallback: HexColor) {
  return (feature: { properties?: Record<string, unknown> }) => {
    const value = feature.properties?.[property];
    return typeof value === "string" && value.startsWith("#") ? value as HexColor : fallback;
  };
}

function featureNumber(property: "fillOpacity", fallback: number) {
  return (feature: { properties?: Record<string, unknown> }) => {
    const value = feature.properties?.[property];
    return typeof value === "number" ? value : fallback;
  };
}

function formatMapRadius(meters: number) {
  return meters >= 1000
    ? `${new Intl.NumberFormat("vi-VN", { maximumFractionDigits: 1 }).format(meters / 1000)} km`
    : `${Math.round(meters)} m`;
}

function formatSummaryArea(squareMeters: number) {
  return `${new Intl.NumberFormat("vi-VN", { maximumFractionDigits: 1 }).format(squareMeters / 1_000_000)} km²`;
}

function AdministrativeFixedInfoCard({
  unit,
  includeConnectionPoint,
  onClose,
}: {
  unit: AdministrativeUnit;
  includeConnectionPoint: boolean;
  onClose: () => void;
}) {
  const areaSquareMeters = turfArea(feature(unit.geometry));
  const estimatedPopulation = Math.round((areaSquareMeters / 1_000_000) * 1450);
  return (
    <aside className="map-fixed-info-card" aria-label={`Thông tin địa giới ${unit.name}`}>
      <button className="map-fixed-info-close" type="button" onClick={onClose} aria-label="Đóng thông tin địa giới"><X size={15}/></button>
      <span>THÔNG TIN ĐỊA GIỚI</span>
      <strong>{unit.type} {unit.name}</strong>
      <small>Mã đơn vị: {unit.wardCode}</small>
      <dl>
        <dt>Diện tích</dt><dd>{formatSummaryArea(areaSquareMeters)}</dd>
        <dt>Dân số (ước tính)</dt><dd>≈ {new Intl.NumberFormat("vi-VN").format(estimatedPopulation)} người</dd>
        {includeConnectionPoint && <><dt>Điểm kết nối</dt><dd>UBND {unit.type} {unit.name}</dd></>}
      </dl>
    </aside>
  );
}

function HnthFixedInfoCard({ properties, onClose }: { properties: Record<string, unknown>; onClose: () => void }) {
  const status = normalizeHnthStatus(properties.status);
  const pointId = String(properties.pointId ?? "");
  const pointName = String(properties.name ?? "Điểm nhánh HNTH");
  const updateHnthPoint = useAppStore((state) => state.updateHnthPoint);
  const setConnectionStatus = (nextStatus: HnthConnectionStatus) => {
    if (pointId) updateHnthPoint(pointId, { status: nextStatus });
  };
  return (
    <aside className="map-fixed-info-card hnth" aria-label={`Thông tin Endpoint ${String(properties.name ?? "Điểm nhánh")}`}>
      <button className="map-fixed-info-close" type="button" onClick={onClose} aria-label="Đóng thông tin Endpoint"><X size={15}/></button>
      <span>THÔNG TIN ENDPOINT</span>
      <strong>{pointName}</strong>
      <small>{String(properties.roleLabel ?? "Điểm nhánh HNTH")}</small>
      <dl>
        <dt>IP</dt><dd>{String(properties.ipAddress ?? "Chưa cấu hình")}</dd>
        <dt>Gateway</dt><dd>{String(properties.gateway ?? "Chưa cấu hình")}</dd>
        <dt>Model/Vendor</dt><dd>{String(properties.model ?? "Chưa cấu hình")}</dd>
        {status !== "unknown" && <><dt>Trạng thái</dt><dd className={`hnth-status ${status}`}>{HNTH_STATUS_LABELS[status]}</dd></>}
        <dt>Nguồn</dt><dd>{String(properties.source ?? "Dữ liệu vận hành")}</dd>
      </dl>
      <div className="hnth-popup-actions">
        <button
          type="button"
          onClick={() => {
            if (!pointId) return;
            window.dispatchEvent(new CustomEvent("hnth:test-point", { detail: { pointId, ipAddress: String(properties.ipAddress ?? ""), runId: Date.now() } }));
          }}
        ><Zap size={13}/> Test</button>
        <button
          className="log"
          type="button"
          onClick={() => {
            if (!pointId) return;
            window.dispatchEvent(new CustomEvent("hnth:open-point-log", { detail: { pointId } }));
          }}
        ><FileText size={13}/> Log</button>
        {status === "connected"
          ? <HnthDisconnectConfirmButton pointName={pointName} onConfirm={() => setConnectionStatus("unconnected")} />
          : <button className="connect" type="button" onClick={() => setConnectionStatus("connected")}><Cable size={13}/> Kết nối</button>}
      </div>
    </aside>
  );
}

function showAdministrativeConnection(map: MapLibreMap, unit: AdministrativeUnit) {
  const source = map.getSource("administrative-focus-connection") as GeoJSONSource | undefined;
  const connectionData: GeoJSON.FeatureCollection = {
    type: "FeatureCollection",
    features: [
      point(unit.coordinates, {
        role: "administrative-center",
        administrativeType: unit.type,
      }),
    ],
  };
  source?.setData(connectionData);
  for (const id of [
    "administrative-focus-connection-casing",
    "administrative-focus-connection-line",
    "administrative-focus-connection-point",
  ]) {
    if (map.getLayer(id)) map.moveLayer(id);
  }
}

function clearAdministrativeConnection(map: MapLibreMap) {
  const source = map.getSource("administrative-focus-connection") as GeoJSONSource | undefined;
  source?.setData(featureCollection([]));
}

function syncRadiusMarkers(map: MapLibreMap, draw: TerraDraw, markers: Map<string | number, maplibregl.Marker>) {
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

function syncDrawEditMarkers(
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

function pointerEventLngLat(map: MapLibreMap, event: MouseEvent): [number, number] {
  const bounds = map.getContainer().getBoundingClientRect();
  const lngLat = map.unproject([event.clientX - bounds.left, event.clientY - bounds.top]);
  return [lngLat.lng, lngLat.lat];
}

function isValidLngLat(value: unknown): value is [number, number] {
  return Array.isArray(value)
    && value.length >= 2
    && Number.isFinite(value[0])
    && Number.isFinite(value[1]);
}

function finishDrawMarkerEdit(
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

function cleanDrawFeatureForStorage(featureValue: GeoJSONStoreFeatures) {
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

function syncTextMarkers(
  map: MapLibreMap,
  annotations: ReturnType<typeof useAppStore.getState>["textAnnotations"],
  markers: Map<string, maplibregl.Marker>,
) {
  const visibleAnnotations = annotations.filter((annotation) => annotation.visible !== false);
  const activeIds = new Set(visibleAnnotations.map((annotation) => annotation.id));
  for (const annotation of visibleAnnotations) {
    let marker = markers.get(annotation.id);
    if (!marker) {
      const element = document.createElement("div");
      element.className = "map-text-annotation";
      element.addEventListener("click", (event) => {
        event.stopPropagation();
        restoreHaiphongOverviewIfZoomedOut(map, annotation.coordinates);
        if (useAppStore.getState().drawMode === "select") useAppStore.getState().selectAnnotation("text", annotation.id);
      });
      marker = new maplibregl.Marker({ element, anchor: "center", draggable: true })
        .setLngLat(annotation.coordinates)
        .addTo(map);
      marker.on("dragend", () => {
        const position = marker?.getLngLat();
        if (position) useAppStore.getState().moveAnnotation("text", annotation.id, [position.lng, position.lat]);
      });
      markers.set(annotation.id, marker);
    }
    const element = marker.getElement();
    element.textContent = annotation.text;
    element.style.color = annotation.color;
    element.classList.toggle("selected", useAppStore.getState().selectedAnnotation?.kind === "text" && useAppStore.getState().selectedAnnotation?.id === annotation.id);
    marker.setDraggable(useAppStore.getState().drawMode === "select");
    marker.setLngLat(annotation.coordinates);
  }
  for (const [id, marker] of markers) {
    if (activeIds.has(id)) continue;
    marker.remove();
    markers.delete(id);
  }
}

function syncIconMarkers(
  map: MapLibreMap,
  annotations: ReturnType<typeof useAppStore.getState>["iconAnnotations"],
  markers: Map<string, IconMarkerHandle>,
) {
  const visibleAnnotations = annotations.filter((annotation) => annotation.visible !== false);
  const activeIds = new Set(visibleAnnotations.map((annotation) => annotation.id));
  for (const annotation of visibleAnnotations) {
    let handle = markers.get(annotation.id);
    if (!handle) {
      const element = document.createElement("div");
      element.className = "map-icon-annotation";
      element.addEventListener("click", (event) => {
        event.stopPropagation();
        restoreHaiphongOverviewIfZoomedOut(map, annotation.coordinates);
        if (useAppStore.getState().drawMode === "select") useAppStore.getState().selectAnnotation("icon", annotation.id);
      });
      const root = createRoot(element);
      const marker = new maplibregl.Marker({ element, anchor: "center", draggable: true })
        .setLngLat(annotation.coordinates)
        .addTo(map);
      marker.on("dragend", () => {
        const position = marker.getLngLat();
        useAppStore.getState().moveAnnotation("icon", annotation.id, [position.lng, position.lat]);
      });
      handle = { marker, root };
      markers.set(annotation.id, handle);
    }
    const Icon = mapIconByKey[annotation.icon].icon;
    handle.root.render(<Icon size={21} strokeWidth={2.2}/>);
    handle.marker.getElement().style.color = annotation.color;
    handle.marker.getElement().classList.toggle("selected", useAppStore.getState().selectedAnnotation?.kind === "icon" && useAppStore.getState().selectedAnnotation?.id === annotation.id);
    handle.marker.setDraggable(useAppStore.getState().drawMode === "select");
    handle.marker.setLngLat(annotation.coordinates);
  }
  for (const [id, handle] of markers) {
    if (activeIds.has(id)) continue;
    handle.root.unmount();
    handle.marker.remove();
    markers.delete(id);
  }
}

function buildOutsideMask(units: ReturnType<typeof useAppStore.getState>["administrativeUnits"]): Feature<Polygon> {
  // Khung nền tối bao trọn lãnh thổ Việt Nam và hai quần đảo, đồng thời tránh
  // phần dư quá lớn ở phía bắc. Thay các mốc [tây, bắc, đông, nam] tại đây
  // nếu sau này cần mở rộng hoặc thu hẹp vùng làm mờ.
  const worldRing: [number, number][] = [[95, 26], [120, 26], [120, 7], [95, 7], [95, 26]];
  const holes: [number, number][][] = [];
  const boundaries = units
    .filter((unit) => unit.geometry.type === "Polygon" || unit.geometry.type === "MultiPolygon")
    .map((unit) => feature(unit.geometry as Polygon | MultiPolygon));
  const cityBoundary = boundaries.length > 0 ? union(featureCollection(boundaries)) : null;
  if (cityBoundary?.geometry.type === "Polygon") holes.push(cityBoundary.geometry.coordinates[0] as [number, number][]);
  if (cityBoundary?.geometry.type === "MultiPolygon") {
    for (const polygon of cityBoundary.geometry.coordinates) holes.push(polygon[0] as [number, number][]);
  }
  return feature({ type: "Polygon", coordinates: [worldRing, ...holes] });
}

function buildZoneSummary(draw: TerraDraw | null): ZoneSummary {
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

function describeDrawFeature(draw: TerraDraw, id: string | number): DrawFeatureInfo | null {
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

function clusterRadiusForLevel(level: number) {
  // 10 keeps the previous 42 px behavior. At level 1, two 14 px markers
  // need to be visually touching before MapLibre combines them.
  return Math.round(8 + ((Math.max(1, Math.min(10, level)) - 1) * 34) / 9);
}

function buildContextualOperationalLayers(
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

function raiseOperationalLayers(map: MapLibreMap, layers: ReturnType<typeof useAppStore.getState>["layers"]) {
  for (const layer of layers) {
    if (!layer.visible || layer.data.features.length === 0) continue;
    // Thứ tự này giữ viền đệm dưới nét đường, số cụm trên vòng tròn cụm.
    for (const suffix of ["fill", "line-glow", "line-casing", "line", "cluster", "point", "hub-halo", "hub-point", "branch-point", "cluster-count"]) {
      const id = `${layer.id}-${suffix}`;
      if (map.getLayer(id)) map.moveLayer(id);
    }
  }
}

function setOperationalLayerVisibility(map: MapLibreMap, layerId: string, visibility: "visible" | "none") {
  for (const suffix of ["fill", "line-glow", "line-casing", "line", "point", "hub-halo", "hub-point", "branch-point", "cluster", "cluster-count"]) {
    const id = `${layerId}-${suffix}`;
    if (map.getLayer(id)) map.setLayoutProperty(id, "visibility", visibility);
  }
}

function addOperationalLayer(map: MapLibreMap, layer: ReturnType<typeof useAppStore.getState>["layers"][number], clusterLevel: number) {
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

const hnthVisualSyncCache = new WeakMap<MapLibreMap, { staticKey: string; dynamicKey: string }>();
const hnthFeatureStateCache = new WeakMap<MapLibreMap, Map<string, HnthConnectionStatus>>();
const hnthAdministrativeStateCache = new WeakMap<MapLibreMap, Map<string, HnthConnectionStatus>>();
const operationalSourceDataCache = new WeakMap<MapLibreMap, Map<string, unknown>>();
const hnthFeaturePropertiesCache = new WeakMap<MapLibreMap, Map<string, Record<string, unknown>>>();

function normalizedHnthProperties(properties: GeoJSON.GeoJsonProperties | null | undefined): Record<string, unknown> {
  return Object.fromEntries(Object.entries(properties ?? {}).filter(([, value]) => value !== undefined));
}

function hnthFeatureId(feature: GeoJSON.Feature): string | number | null {
  if (typeof feature.id === "string" || typeof feature.id === "number") return feature.id;
  const pointId = feature.properties?.pointId;
  return typeof pointId === "string" || typeof pointId === "number" ? pointId : null;
}

function rememberHnthFeatureProperties(map: MapLibreMap, data: GeoJSON.FeatureCollection) {
  const snapshot = new Map<string, Record<string, unknown>>();
  for (const item of data.features) {
    const id = hnthFeatureId(item);
    if (id !== null) snapshot.set(String(id), normalizedHnthProperties(item.properties));
  }
  hnthFeaturePropertiesCache.set(map, snapshot);
}

function syncHnthSourceData(map: MapLibreMap, source: GeoJSONSource, data: GeoJSON.FeatureCollection) {
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

function hnthStatusColorExpression(styles: HnthStatusStyles): maplibregl.ExpressionSpecification {
  return [
    "match", ["feature-state", "hnthStatus"],
    "unconnected", styles.unconnected.visible ? styles.unconnected.color : "transparent",
    "connected", styles.connected.visible ? styles.connected.color : "transparent",
    "lost", styles.lost.visible ? styles.lost.color : "transparent",
    "transparent",
  ];
}

function syncHnthPointFeatureStates(
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

function hnthAreaColorExpression(styles: HnthStatusStyles): maplibregl.ExpressionSpecification {
  return [
    "match", ["feature-state", "hnthStatus"],
    "unconnected", styles.unconnected.visible ? styles.unconnected.color : "transparent",
    "connected", styles.connected.visible ? styles.connected.color : "transparent",
    "lost", styles.lost.visible ? styles.lost.color : "transparent",
    "transparent",
  ];
}

function hnthAreaOpacityExpression(styles: HnthStatusStyles): maplibregl.ExpressionSpecification {
  return [
    "match", ["feature-state", "hnthStatus"],
    "unconnected", styles.unconnected.visible ? 0.18 : 0,
    "connected", styles.connected.visible ? 0.18 : 0,
    "lost", styles.lost.visible ? 0.18 : 0,
    0,
  ];
}

function syncHnthAdministrativeFeatureStates(
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

function syncHnthVisualStyles(
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

function addHnthLayer(map: MapLibreMap, layer: OperationalLayer) {
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

function hasHnthPointAt(map: MapLibreMap, screenPoint: maplibregl.PointLike) {
  // Ở menu khác, điểm HNTH không được chặn thao tác xem lớp dữ liệu nằm dưới.
  if (!canInspectHnthFeature()) return false;
  const pointLayerIds = [`${HNTH_LAYER_ID}-hub-point`, `${HNTH_LAYER_ID}-branch-point`].filter((id) => Boolean(map.getLayer(id)));
  return pointLayerIds.length > 0 && map.queryRenderedFeatures(screenPoint, { layers: pointLayerIds }).length > 0;
}

function hasInspectableOperationalFeatureAt(map: MapLibreMap, screenPoint: maplibregl.PointLike) {
  if (!canInspectOperationalFeature()) return false;
  const interactiveLayerIds = useAppStore.getState().layers.flatMap((layer) => (
    [`${layer.id}-point`, `${layer.id}-line`]
      .filter((id) => Boolean(map.getLayer(id)) && map.getLayoutProperty(id, "visibility") !== "none")
  ));
  return interactiveLayerIds.length > 0
    && map.queryRenderedFeatures(screenPoint, { layers: interactiveLayerIds }).length > 0;
}

function canInspectHnthFeature() {
  return Boolean(useAppStore.getState().layers.some((layer) => layer.id === HNTH_LAYER_ID));
}

function showHnthPointPopup(
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
  window.dispatchEvent(new CustomEvent<FixedMapInfo>(MAP_CONTEXT_INFO_EVENT, {
    detail: { kind: "hnth", pointId, administrativeId },
  }));
}

function canInspectOperationalFeature() {
  const state = useAppStore.getState();
  return state.activePanel === "layers"
    || state.activePanel === "conference"
    || (state.activePanel === "zones" && (state.zoneMode === "draw" || state.zoneMode === "info"));
}

function buildOperationalPopupHtml(layerName: string, properties: Record<string, unknown> | null | undefined) {
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

function escapeHtml(value: string) {
  return value.replace(/[&<>'"]/g, (character) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" })[character] ?? character);
}
