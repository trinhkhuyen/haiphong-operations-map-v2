// Công cụ vẽ (Terra Draw), chế độ Khoanh vùng, hình đã lưu.
import type { GeoJSONStoreFeatures } from "terra-draw";
import type { DrawFeatureInfo, DrawMode, MapSearchTarget, SavedDrawFeature, ZoneMode } from "../types";
import type { AppSlice } from "./types";

export interface DrawingSlice {
  drawMode: DrawMode;
  zoneMode: ZoneMode;
  drawFillColor: string;
  drawOutlineColor: string;
  drawFillOpacity: number;
  selectedDrawFeatureId: string | number | null;
  selectedDrawFeatureInfo: DrawFeatureInfo | null;
  drawRadiusUpdate: { id: string | number; meters: number; request: number } | null;
  deleteDrawRequest: number;
  savedDrawFeatures: SavedDrawFeature[];
  saveSelectedObjectRequest: { name: string; request: number } | null;
  drawSearchTarget: MapSearchTarget | null;
  setDrawMode: (mode: DrawMode) => void;
  setZoneMode: (mode: ZoneMode) => void;
  setDrawFillColor: (color: string) => void;
  setDrawOutlineColor: (color: string) => void;
  setDrawFillOpacity: (opacity: number) => void;
  setSelectedDrawFeatureId: (id: string | number | null) => void;
  setSelectedDrawFeatureInfo: (info: DrawFeatureInfo | null) => void;
  setSelectedCircleRadius: (meters: number) => void;
  requestDeleteDrawFeature: () => void;
  upsertSavedDrawFeature: (feature: GeoJSONStoreFeatures, name?: string) => void;
  syncSavedDrawFeature: (feature: GeoJSONStoreFeatures) => void;
  setDrawSearchTarget: (target: MapSearchTarget | null) => void;
}

export const createDrawingSlice: AppSlice<DrawingSlice> = (set) => ({
  drawMode: null,
  zoneMode: "administrative",
  drawFillColor: "#fde68a",
  drawOutlineColor: "#d97706",
  drawFillOpacity: 0.42,
  selectedDrawFeatureId: null,
  selectedDrawFeatureInfo: null,
  drawRadiusUpdate: null,
  deleteDrawRequest: 0,
  savedDrawFeatures: [],
  saveSelectedObjectRequest: null,
  drawSearchTarget: null,
  setDrawMode: (drawMode) => set({ drawMode }),
  setZoneMode: (zoneMode) => set((state) => ({
    zoneMode,
    drawMode: zoneMode === "draw"
      ? "select"
      : zoneMode === "info" && state.selectedDrawFeatureId !== null
        ? "select"
        : null,
  })),
  setDrawFillColor: (drawFillColor) => set({ drawFillColor }),
  setDrawOutlineColor: (drawOutlineColor) => set({ drawOutlineColor }),
  setDrawFillOpacity: (drawFillOpacity) => set({ drawFillOpacity: Math.max(0.05, Math.min(1, drawFillOpacity)) }),
  setSelectedDrawFeatureId: (selectedDrawFeatureId) => set({ selectedDrawFeatureId }),
  setSelectedDrawFeatureInfo: (selectedDrawFeatureInfo) => set({ selectedDrawFeatureInfo }),
  setSelectedCircleRadius: (meters) => set((state) => {
    if (state.selectedDrawFeatureId === null || state.selectedDrawFeatureInfo?.kind !== "circle") return state;
    const radiusMeters = Math.max(100, Math.min(100000, meters));
    return {
      selectedDrawFeatureInfo: { ...state.selectedDrawFeatureInfo, radiusMeters },
      drawRadiusUpdate: { id: state.selectedDrawFeatureId, meters: radiusMeters, request: (state.drawRadiusUpdate?.request ?? 0) + 1 },
    };
  }),
  requestDeleteDrawFeature: () => set((state) => ({ deleteDrawRequest: state.deleteDrawRequest + 1 })),
  upsertSavedDrawFeature: (feature, requestedName) => set((state) => {
    if (feature.id === undefined) return state;
    const featureId = feature.id;
    const id = `geometry:${String(featureId)}`;
    const existing = state.savedDrawFeatures.find((item) => item.id === id);
    const now = Date.now();
    const saved: SavedDrawFeature = {
      id,
      featureId,
      name: requestedName?.trim() || existing?.name || "Đối tượng chưa đặt tên",
      visible: existing?.visible ?? true,
      feature,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    };
    return {
      savedDrawFeatures: existing
        ? state.savedDrawFeatures.map((item) => item.id === id ? saved : item)
        : [...state.savedDrawFeatures, saved],
    };
  }),
  syncSavedDrawFeature: (feature) => set((state) => {
    if (feature.id === undefined) return state;
    const id = `geometry:${String(feature.id)}`;
    if (!state.savedDrawFeatures.some((item) => item.id === id)) return state;
    return {
      savedDrawFeatures: state.savedDrawFeatures.map((item) => item.id === id
        ? { ...item, feature, updatedAt: Date.now() }
        : item),
    };
  }),
  setDrawSearchTarget: (drawSearchTarget) => set({ drawSearchTarget }),
});
