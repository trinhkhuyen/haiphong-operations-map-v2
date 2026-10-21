// Khung nhìn: tổng quan Hải Phòng, Home trên mobile, giới hạn kéo bản đồ.
import type { Map as MapLibreMap } from "maplibre-gl";
import { bbox, booleanPointInPolygon, feature, point } from "@turf/turf";
import type { MultiPolygon, Polygon } from "geojson";
import { useAppStore } from "../../../core/store";
import type { AdministrativeUnit } from "../../../core/types";
import { unitsToFeatureCollection } from "../../administrative/data-provider";

// Chuyển cảnh về khung mặc định của địa giới luôn đi qua toàn TP Hải Phòng:
// 800 ms để về khung thành phố, giữ nguyên 2 giây, rồi mới zoom vào địa giới.
// Muốn tự chỉnh thời gian dừng, thay giá trị HOME_CITY_PAUSE_MS bên dưới:
// 1000 = 1 giây, 2000 = 2 giây, 3000 = 3 giây, ...
export const HOME_CITY_TRANSITION_DURATION_MS = 800;
export const HOME_CITY_PAUSE_MS = 1000;
export const HAIPHONG_FALLBACK_BOUNDS: [[number, number], [number, number]] = [[105.92, 20.48], [107.16, 21.28]];

// Khung thu nhỏ tối đa của bản đồ vận hành (theo ảnh mốc ngày 14/10/2026):
// phía tây thấy Điện Biên, phía bắc thấy Tuyên Quang và phía nam thấy Nghệ An.
// Đây là camera bản đồ thật dùng ngay trong lúc khởi động, không phải ảnh nền.
// Có thể tinh chỉnh nhẹ 3 giá trị dưới đây nếu kích thước màn hình triển khai đổi.
export const REGIONAL_LOADING_CENTER: [number, number] = [105.95, 21.02];
export const REGIONAL_MIN_ZOOM = 6.25;

// Khóa vùng pan để không kéo ra ngoài khu vực dữ liệu cần vận hành. Biên phía
// đông vẫn bao gồm đặc khu Bạch Long Vĩ và vùng biển lân cận.
export const REGIONAL_OPERATIONAL_BOUNDS: [[number, number], [number, number]] = [[101.85, 18.25], [110.05, 23.6]];

export function setMobileHomePanBounds(map: MapLibreMap, administrativeUnits: AdministrativeUnit[]) {
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
export const MOBILE_HOME_ZOOM_OUT_LEVELS = 2.5;
export const MOBILE_HOME_PAN_DOWN_PX = 40;

export function fitMobileHomeOverview(map: MapLibreMap, administrativeUnits: AdministrativeUnit[], duration: number) {
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

export function getHaiphongOverviewBounds(administrativeUnits: AdministrativeUnit[]) {
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

export const HAIPHONG_OVERVIEW_PADDING = { top: 36, right: 36, bottom: 36, left: 36 };
// Mobile có phần sidebar cố định bên trái và viewport hẹp (đặc biệt iPhone 11).
// Mức đệm này giữ toàn TP trong khung nhưng vẫn cho bề ngang xấp xỉ 3 ô trạng thái.
export const HAIPHONG_MOBILE_OVERVIEW_PADDING = { top: 84, right: 8, bottom: 84, left: 8 };

export function getHaiphongOverviewPadding() {
  return window.matchMedia("(max-width: 760px)").matches
    ? HAIPHONG_MOBILE_OVERVIEW_PADDING
    : HAIPHONG_OVERVIEW_PADDING;
}

export function fitHaiphongOverview(map: MapLibreMap, administrativeUnits: AdministrativeUnit[], duration: number) {
  const bounds = getHaiphongOverviewBounds(administrativeUnits);

  map.fitBounds(bounds, {
    padding: getHaiphongOverviewPadding(),
    bearing: 0,
    pitch: 0,
    duration,
  });
}

export function restoreHaiphongOverviewIfZoomedOut(map: MapLibreMap, clickedCoordinate?: [number, number]) {
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
