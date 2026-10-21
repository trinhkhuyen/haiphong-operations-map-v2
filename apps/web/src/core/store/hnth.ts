// Cấu hình/trạng thái điểm HNTH người dùng sửa và kiểu hiển thị line/vùng.
import type { HnthConnectionStatus, HnthPointOverride, HnthStatusStyles, HnthVisualStyle } from "../../features/layers/hnth-data-provider";
import { DEFAULT_HNTH_AREA_STYLES, DEFAULT_HNTH_LINE_STYLES, HNTH_LAYER_ID, HNTH_STATUS_LABELS, normalizeHnthStatus } from "../../features/layers/hnth-data-provider";
import type { AppSlice } from "./types";

export interface HnthSlice {
  hnthPointOverrides: Record<string, HnthPointOverride>;
  selectedHnthPointId: string | null;
  hnthLineVisible: boolean;
  hnthPointVisible: boolean;
  hnthLineStyles: HnthStatusStyles;
  hnthAreaStyles: HnthStatusStyles;
  hnthAreaVisible: boolean;
  /** Log giám sát và popup Chi tiết hiển thị trong suốt trên bản đồ (phím 8 / switch menu HNTH). Không persist. */
  hnthTransparentPopups: boolean;
  setHnthTransparentPopups: (value: boolean) => void;
  updateHnthPoint: (pointId: string, update: Partial<HnthPointOverride>) => void;
  updateHnthPoints: (updates: Record<string, Partial<HnthPointOverride>>) => void;
  setSelectedHnthPointId: (pointId: string | null) => void;
  setHnthLineVisible: (visible: boolean) => void;
  setHnthPointVisible: (visible: boolean) => void;
  setHnthLineStyle: (status: HnthConnectionStatus, update: Partial<HnthVisualStyle>) => void;
  setHnthAreaStyle: (status: HnthConnectionStatus, update: Partial<HnthVisualStyle>) => void;
  setHnthAreaVisible: (visible: boolean) => void;
}

export const createHnthSlice: AppSlice<HnthSlice> = (set) => ({
  hnthPointOverrides: {},
  // Lựa chọn tạm thời dùng chung giữa địa giới trên bản đồ, danh sách điểm
  // và thẻ Cấu hình điểm HNTH. Không lưu vào localStorage vì đây là trạng thái phiên.
  selectedHnthPointId: null,
  hnthLineVisible: true,
  hnthPointVisible: true,
  hnthLineStyles: DEFAULT_HNTH_LINE_STYLES,
  hnthAreaStyles: DEFAULT_HNTH_AREA_STYLES,
  hnthAreaVisible: true,
  hnthTransparentPopups: false,
  updateHnthPoint: (pointId, update) => set((state) => {
    const currentFeature = state.layers.find((layer) => layer.id === HNTH_LAYER_ID)?.data.features.find((item) => String(item.properties?.pointId ?? item.id ?? "") === pointId);
    const current = state.hnthPointOverrides[pointId] ?? {
      ipAddress: String(currentFeature?.properties?.ipAddress ?? ""),
      gateway: String(currentFeature?.properties?.gateway ?? "192.168.1.1"),
      model: String(currentFeature?.properties?.model ?? ""),
      status: normalizeHnthStatus(currentFeature?.properties?.status),
    };
    const next = { ...current, ...update, status: normalizeHnthStatus(update.status ?? current.status) };
    return {
      hnthPointOverrides: { ...state.hnthPointOverrides, [pointId]: next },
      layers: state.layers.map((layer) => layer.id !== HNTH_LAYER_ID ? layer : ({
        ...layer,
        data: {
          ...layer.data,
          features: layer.data.features.map((item) => {
            const featurePointId = String(item.properties?.pointId ?? item.id ?? "");
            if (featurePointId !== pointId) return item;
            return {
              ...item,
              properties: {
                ...item.properties,
                ...next,
                statusLabel: HNTH_STATUS_LABELS[next.status],
              },
            };
          }),
        },
      })),
    };
  }),
  updateHnthPoints: (updates) => set((state) => {
    const entries = Object.entries(updates).filter(([pointId]) => pointId.trim());
    if (!entries.length) return state;

    const hnthLayer = state.layers.find((layer) => layer.id === HNTH_LAYER_ID);
    const nextOverrides = { ...state.hnthPointOverrides };
    let overridesChanged = false;
    for (const [pointId, update] of entries) {
      const currentFeature = hnthLayer?.data.features.find((item) => String(item.properties?.pointId ?? item.id ?? "") === pointId);
      const current = nextOverrides[pointId] ?? {
        ipAddress: String(currentFeature?.properties?.ipAddress ?? ""),
        gateway: String(currentFeature?.properties?.gateway ?? "192.168.1.1"),
        model: String(currentFeature?.properties?.model ?? ""),
        status: normalizeHnthStatus(currentFeature?.properties?.status),
      };
      const next = { ...current, ...update, status: normalizeHnthStatus(update.status ?? current.status) };
      if (current.ipAddress !== next.ipAddress || current.gateway !== next.gateway || current.model !== next.model || current.status !== next.status) {
        nextOverrides[pointId] = next;
        overridesChanged = true;
      }
    }
    if (!overridesChanged) return state;

    let layerChanged = false;
    const layers = state.layers.map((layer) => layer.id !== HNTH_LAYER_ID ? layer : ({
      ...layer,
      data: {
        ...layer.data,
        features: layer.data.features.map((item) => {
          const pointId = String(item.properties?.pointId ?? item.id ?? "");
          const next = nextOverrides[pointId];
          if (!next || !entries.some(([id]) => id === pointId)) return item;
          layerChanged = true;
          return {
            ...item,
            properties: {
              ...item.properties,
              ...next,
              statusLabel: HNTH_STATUS_LABELS[next.status],
            },
          };
        }),
      },
    }));
    return { hnthPointOverrides: nextOverrides, ...(layerChanged ? { layers } : {}) };
  }),
  setSelectedHnthPointId: (selectedHnthPointId) => set({ selectedHnthPointId }),
  setHnthLineVisible: (hnthLineVisible) => set({ hnthLineVisible }),
  setHnthPointVisible: (hnthPointVisible) => set({ hnthPointVisible }),
  setHnthLineStyle: (status, update) => set((state) => ({
    hnthLineStyles: { ...state.hnthLineStyles, [status]: { ...state.hnthLineStyles[status], ...update } },
  })),
  setHnthAreaStyle: (status, update) => set((state) => ({
    hnthAreaStyles: { ...state.hnthAreaStyles, [status]: { ...state.hnthAreaStyles[status], ...update } },
  })),
  setHnthAreaVisible: (hnthAreaVisible) => set({ hnthAreaVisible }),
  setHnthTransparentPopups: (hnthTransparentPopups) => set({ hnthTransparentPopups }),
});
