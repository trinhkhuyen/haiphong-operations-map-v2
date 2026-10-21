// Danh mục lớp vận hành, lớp nào bật/đã nạp, mức gom cụm.
import type { OperationalLayer } from "../types";
import { createLayerCatalog, sampleLayers } from "../../features/layers/sample-data";
import type { AppSlice } from "./types";

const initialLayerVisibility = Object.fromEntries(
  sampleLayers.map((layer) => [layer.id, false]),
) as Record<string, boolean>;

export interface LayersSlice {
  layers: OperationalLayer[];
  layerVisibility: Record<string, boolean>;
  loadedLayerIds: string[];
  loadingLayerIds: string[];
  operationalDataStatus: "idle" | "loading" | "ready" | "error";
  clusterLevel: number;
  toggleLayer: (id: string) => void;
  setClusterLevel: (level: number) => void;
  setOperationalDataStatus: (status: LayersSlice["operationalDataStatus"]) => void;
  markLayersLoading: (ids: string[]) => void;
  markLayersFailed: (ids: string[]) => void;
  mergeOperationalLayers: (layers: OperationalLayer[]) => void;
}

export const createLayersSlice: AppSlice<LayersSlice> = (set) => ({
  // Chỉ khởi tạo catalog rỗng. Dữ liệu của từng lớp được nạp sau khi cấu hình
  // đã khôi phục và xác nhận lớp đó đang bật.
  layers: createLayerCatalog(),
  layerVisibility: initialLayerVisibility,
  loadedLayerIds: [],
  loadingLayerIds: [],
  operationalDataStatus: "idle",
  clusterLevel: 1,
  toggleLayer: (id) => set((state) => {
    const currentLayer = state.layers.find((layer) => layer.id === id);
    if (!currentLayer) return state;
    const visible = !currentLayer.visible;
    return {
      layers: state.layers.map((layer) => layer.id === id ? { ...layer, visible } : layer),
      layerVisibility: { ...state.layerVisibility, [id]: visible },
    };
  }),
  setClusterLevel: (level) => set({ clusterLevel: Math.max(1, Math.min(10, Math.round(level))) }),
  setOperationalDataStatus: (operationalDataStatus) => set({ operationalDataStatus }),
  markLayersLoading: (ids) => set((state) => ({
    loadingLayerIds: [...new Set([...state.loadingLayerIds, ...ids])],
    operationalDataStatus: "loading",
  })),
  markLayersFailed: (ids) => set((state) => ({
    loadingLayerIds: state.loadingLayerIds.filter((id) => !ids.includes(id)),
    operationalDataStatus: "error",
  })),
  mergeOperationalLayers: (incomingLayers) => set((state) => {
    const layers = state.layers.map((layer) => {
      const incoming = incomingLayers.find((candidate) => candidate.id === layer.id);
      return {
        ...(incoming ?? layer),
        visible: state.layerVisibility[layer.id] ?? layer.visible,
      };
    });
    const loadingLayerIds = state.loadingLayerIds.filter((id) => !incomingLayers.some((layer) => layer.id === id));
    return {
      layers,
      layerVisibility: Object.fromEntries(layers.map((layer) => [layer.id, layer.visible])),
      loadedLayerIds: [...new Set([...state.loadedLayerIds, ...incomingLayers.map((layer) => layer.id)])],
      loadingLayerIds,
      operationalDataStatus: loadingLayerIds.length ? "loading" : "ready",
    };
  }),
});
