// Style nền MapLibre (OSM / vệ tinh / địa hình) và danh sách lựa chọn nền.
import { Map as MapIcon, Mountain, Satellite } from "lucide-react";
import maplibregl from "maplibre-gl";
import type { BaseMapMode } from "../../../core/types";

// Tạo style theo đúng chế độ nền đã lưu ngay từ frame đầu tiên. Nếu luôn khởi
// tạo OSM rồi mới đổi sang vệ tinh sau sự kiện `load`, MapLibre sẽ lộ một mảng
// tile OSM sáng hình chữ nhật trong lúc reload.
export const createBaseStyle = (initialMode: BaseMapMode): maplibregl.StyleSpecification => ({
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

export const baseMapOptions: { id: BaseMapMode; label: string; description: string; icon: typeof MapIcon }[] = [
  { id: "standard", label: "Tiêu chuẩn", description: "Đường phố và địa danh", icon: MapIcon },
  { id: "satellite", label: "Vệ tinh", description: "Ảnh vệ tinh Esri", icon: Satellite },
  { id: "terrain", label: "Địa hình", description: "Địa hình và cao độ", icon: Mountain },
];
