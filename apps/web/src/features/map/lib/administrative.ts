// Lớp địa giới hành chính: nhãn tên chính thức, nền tối ngoài Hải Phòng, đường nối tới UBND.
import type { GeoJSONSource, Map as MapLibreMap } from "maplibre-gl";
import { feature, featureCollection, point, union } from "@turf/turf";
import type { Feature, MultiPolygon, Point as GeoJSONPoint, Polygon } from "geojson";
import { useAppStore } from "../../../core/store";
import type { AdministrativeUnit, BaseMapMode } from "../../../core/types";

// Độ đục nền dùng chung khi chọn vùng tự vẽ hoặc focus địa giới lần 2.
// MapLibre/Terra Draw dùng 0 = trong suốt hoàn toàn, 1 = đặc hoàn toàn.
// Ví dụ: 0.05 = trong suốt 95%, 0.08 = 92%, 0.15 = 85%.
export const SELECTED_ZONE_FILL_OPACITY = 0.08;

// Màu phủ các địa giới xung quanh khi đã chọn địa giới/cụm địa giới làm khung mặc định.
// Chỉnh mã dưới đây để đổi màu. Một số màu nhạt có thể dùng:
// - Xanh ngọc nhạt (đang dùng): #99F6E4
// - Xanh dương nhạt (sky):      #BAE6FD
// - Xanh lá nhạt:               #BBF7D0
// - Blue nhạt:                  #BFDBFE
export const DEFAULT_VIEWPORT_SURROUNDING_FILL_COLOR = "#99F6E4";
export const DEFAULT_VIEWPORT_SURROUNDING_LINE_COLOR = "#5EEAD4";

export const OFFICIAL_ADMINISTRATIVE_LABEL_SOURCE_ID = "official-administrative-label-points";
export const OFFICIAL_ADMINISTRATIVE_LABEL_LAYER_ID = "official-administrative-labels";
export const PRIORITY_ADMINISTRATIVE_LABEL_LAYER_ID = "official-administrative-labels-priority";
export const PRIORITY_ADMINISTRATIVE_LABEL_NAMES = ["Chu Văn An", "Nam Đồ Sơn", "Đồ Sơn", "Bạch Long Vĩ"];

export function buildOfficialAdministrativeLabelPoints(units: AdministrativeUnit[]): GeoJSON.FeatureCollection<GeoJSONPoint> {
  return featureCollection(units.map((unit) => point(unit.coordinates, {
    id: unit.id,
    name: unit.name,
    type: unit.type,
    shortType: unit.type === "phường" ? "P" : unit.type === "xã" ? "X" : "ĐK",
    priority: PRIORITY_ADMINISTRATIVE_LABEL_NAMES.includes(unit.name),
  })));
}

export function officialAdministrativeLabelsVisible(baseMapMode: BaseMapMode) {
  // Nền Tiêu chuẩn và Địa hình đều là ảnh raster đã ghép chữ vào tile nên không
  // thể ẩn riêng nhãn cũ trong Hải Phòng. Chỉ chèn bộ nhãn hành chính mới trên
  // nền Vệ tinh (không có chữ) để tuyệt đối tránh hai bộ tên đè lên nhau.
  return baseMapMode === "satellite";
}

export function showAdministrativeConnection(map: MapLibreMap, unit: AdministrativeUnit) {
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

export function clearAdministrativeConnection(map: MapLibreMap) {
  const source = map.getSource("administrative-focus-connection") as GeoJSONSource | undefined;
  source?.setData(featureCollection([]));
}

export function buildOutsideMask(units: ReturnType<typeof useAppStore.getState>["administrativeUnits"]): Feature<Polygon> {
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
