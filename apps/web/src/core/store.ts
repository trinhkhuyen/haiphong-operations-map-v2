import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { GeoJSONStoreFeatures } from "terra-draw";
import type { AdministrativeUnit, BaseMapMode, DrawFeatureInfo, DrawMode, IconAnnotation, MapIconKey, MapSearchTarget, OperationalLayer, SavedDrawFeature, SavedMapViewport, SavedObjectKind, TextAnnotation, ZoneMode } from "./types";
import { createLayerCatalog, sampleLayers } from "../features/layers/sample-data";
import type { HnthConnectionStatus, HnthPointOverride, HnthStatusStyles, HnthVisualStyle } from "../features/layers/hnth-data-provider";
import { DEFAULT_HNTH_AREA_STYLES, DEFAULT_HNTH_LINE_STYLES, HNTH_LAYER_ID, HNTH_STATUS_LABELS, normalizeHnthStatus } from "../features/layers/hnth-data-provider";

const initialLayerVisibility = Object.fromEntries(
  sampleLayers.map((layer) => [layer.id, false]),
) as Record<string, boolean>;

interface AppState {
  layers: OperationalLayer[];
  layerVisibility: Record<string, boolean>;
  loadedLayerIds: string[];
  loadingLayerIds: string[];
  operationalDataStatus: "idle" | "loading" | "ready" | "error";
  clusterLevel: number;
  baseMapMode: BaseMapMode;
  activePanel: "layers" | "zones" | "saved" | "routing" | "conference" | "agents";
  hnthPointOverrides: Record<string, HnthPointOverride>;
  selectedHnthPointId: string | null;
  hnthLineVisible: boolean;
  hnthPointVisible: boolean;
  hnthLineStyles: HnthStatusStyles;
  hnthAreaStyles: HnthStatusStyles;
  hnthAreaVisible: boolean;
  drawMode: DrawMode;
  search: string;
  zoneMode: ZoneMode;
  administrativeUnits: AdministrativeUnit[];
  administrativeStatus: "idle" | "loading" | "ready" | "error";
  initialViewportReady: boolean;
  administrativeQuery: string;
  selectedAdministrativeIds: number[];
  focusedAdministrativeId: number | null;
  dimOutsideHaiphong: boolean;
  defaultViewportEnabled: boolean;
  defaultViewport: SavedMapViewport | null;
  defaultViewportSaveRequest: number;
  defaultAdministrativeIds: number[];
  defaultAdministrativeSaveRequest: { ids: number[]; request: number } | null;
  administrativeFillColor: string;
  administrativeOutlineColor: string;
  administrativeFillOpacity: number;
  drawFillColor: string;
  drawOutlineColor: string;
  drawFillOpacity: number;
  selectedDrawFeatureId: string | number | null;
  selectedDrawFeatureInfo: DrawFeatureInfo | null;
  drawRadiusUpdate: { id: string | number; meters: number; request: number } | null;
  deleteDrawRequest: number;
  textDraft: string;
  textAnnotations: TextAnnotation[];
  iconDraft: MapIconKey;
  iconAnnotations: IconAnnotation[];
  selectedAnnotation: { kind: "text" | "icon"; id: string } | null;
  savedDrawFeatures: SavedDrawFeature[];
  saveSelectedObjectRequest: { name: string; request: number } | null;
  focusSavedObjectRequest: { kind: SavedObjectKind; id: string; request: number } | null;
  drawSearchTarget: MapSearchTarget | null;
  setActivePanel: (panel: AppState["activePanel"]) => void;
  setDrawMode: (mode: DrawMode) => void;
  setSearch: (value: string) => void;
  setZoneMode: (mode: ZoneMode) => void;
  setAdministrativeUnits: (units: AdministrativeUnit[]) => void;
  setAdministrativeStatus: (status: AppState["administrativeStatus"]) => void;
  setInitialViewportReady: (ready: boolean) => void;
  setAdministrativeQuery: (value: string) => void;
  toggleAdministrativeUnit: (id: number) => void;
  cycleAdministrativeUnit: (id: number) => void;
  selectAdministrativeUnit: (id: number) => void;
  removeAdministrativeUnit: (id: number) => void;
  clearAdministrativeFocus: () => void;
  clearAdministrativeSelection: () => void;
  setDimOutsideHaiphong: (enabled: boolean) => void;
  setDefaultViewportEnabled: (enabled: boolean) => void;
  setDefaultViewport: (viewport: SavedMapViewport) => void;
  requestDefaultViewportSave: () => void;
  setDefaultAdministrativeViewport: (ids: number[], viewport: SavedMapViewport) => void;
  requestDefaultAdministrativeSave: (ids: number[]) => void;
  setAdministrativeFillColor: (color: string) => void;
  setAdministrativeOutlineColor: (color: string) => void;
  setAdministrativeFillOpacity: (opacity: number) => void;
  setDrawFillColor: (color: string) => void;
  setDrawOutlineColor: (color: string) => void;
  setDrawFillOpacity: (opacity: number) => void;
  setSelectedDrawFeatureId: (id: string | number | null) => void;
  setSelectedDrawFeatureInfo: (info: DrawFeatureInfo | null) => void;
  setSelectedCircleRadius: (meters: number) => void;
  requestDeleteDrawFeature: () => void;
  setTextDraft: (value: string) => void;
  addTextAnnotation: (coordinates: [number, number]) => void;
  setIconDraft: (icon: MapIconKey) => void;
  addIconAnnotation: (coordinates: [number, number]) => void;
  selectAnnotation: (kind: "text" | "icon", id: string) => void;
  updateSelectedAnnotationText: (text: string) => void;
  updateSelectedAnnotationIcon: (icon: MapIconKey) => void;
  updateSelectedAnnotationColor: (color: string) => void;
  moveAnnotation: (kind: "text" | "icon", id: string, coordinates: [number, number]) => void;
  deleteSelectedAnnotation: () => void;
  clearSelectedAnnotation: () => void;
  saveSelectedObject: (name: string) => void;
  upsertSavedDrawFeature: (feature: GeoJSONStoreFeatures, name?: string) => void;
  syncSavedDrawFeature: (feature: GeoJSONStoreFeatures) => void;
  toggleSavedObject: (kind: SavedObjectKind, id: string) => void;
  renameSavedObject: (kind: SavedObjectKind, id: string, name: string) => void;
  deleteSavedObject: (kind: SavedObjectKind, id: string) => void;
  requestFocusSavedObject: (kind: SavedObjectKind, id: string) => void;
  setDrawSearchTarget: (target: MapSearchTarget | null) => void;
  toggleLayer: (id: string) => void;
  setClusterLevel: (level: number) => void;
  setBaseMapMode: (mode: BaseMapMode) => void;
  setOperationalDataStatus: (status: AppState["operationalDataStatus"]) => void;
  markLayersLoading: (ids: string[]) => void;
  markLayersFailed: (ids: string[]) => void;
  mergeOperationalLayers: (layers: OperationalLayer[]) => void;
  updateHnthPoint: (pointId: string, update: Partial<HnthPointOverride>) => void;
  updateHnthPoints: (updates: Record<string, Partial<HnthPointOverride>>) => void;
  setSelectedHnthPointId: (pointId: string | null) => void;
  setHnthLineVisible: (visible: boolean) => void;
  setHnthPointVisible: (visible: boolean) => void;
  setHnthLineStyle: (status: HnthConnectionStatus, update: Partial<HnthVisualStyle>) => void;
  setHnthAreaStyle: (status: HnthConnectionStatus, update: Partial<HnthVisualStyle>) => void;
  setHnthAreaVisible: (visible: boolean) => void;
}

export const useAppStore = create<AppState>()(persist((set) => ({
  // Chỉ khởi tạo catalog rỗng. Dữ liệu của từng lớp được nạp sau khi cấu hình
  // đã khôi phục và xác nhận lớp đó đang bật.
  layers: createLayerCatalog(),
  layerVisibility: initialLayerVisibility,
  loadedLayerIds: [],
  loadingLayerIds: [],
  operationalDataStatus: "idle",
  clusterLevel: 1,
  baseMapMode: "standard",
  // HNTH là màn hình vận hành mặc định của bản trình diễn/public.
  // Trạng thái này không được persist nên mọi phiên truy cập mới đều mở đúng menu HNTH.
  activePanel: "conference",
  hnthPointOverrides: {},
  // Lựa chọn tạm thời dùng chung giữa địa giới trên bản đồ, danh sách điểm
  // và thẻ Cấu hình điểm HNTH. Không lưu vào localStorage vì đây là trạng thái phiên.
  selectedHnthPointId: null,
  hnthLineVisible: true,
  hnthPointVisible: true,
  hnthLineStyles: DEFAULT_HNTH_LINE_STYLES,
  hnthAreaStyles: DEFAULT_HNTH_AREA_STYLES,
  hnthAreaVisible: true,
  drawMode: null,
  search: "",
  zoneMode: "administrative",
  administrativeUnits: [],
  administrativeStatus: "idle",
  initialViewportReady: false,
  administrativeQuery: "",
  selectedAdministrativeIds: [],
  focusedAdministrativeId: null,
  // Mặc định bật lớp nền tối bên ngoài địa giới Hải Phòng. Bản public chạy
  // trên origin riêng nên không dùng được localStorage của bản chạy local.
  dimOutsideHaiphong: true,
  defaultViewportEnabled: false,
  defaultViewport: null,
  defaultViewportSaveRequest: 0,
  defaultAdministrativeIds: [],
  defaultAdministrativeSaveRequest: null,
  administrativeFillColor: "#fde68a",
  administrativeOutlineColor: "#d97706",
  administrativeFillOpacity: 0.42,
  drawFillColor: "#fde68a",
  drawOutlineColor: "#d97706",
  drawFillOpacity: 0.42,
  selectedDrawFeatureId: null,
  selectedDrawFeatureInfo: null,
  drawRadiusUpdate: null,
  deleteDrawRequest: 0,
  textDraft: "Nhãn mới",
  textAnnotations: [],
  iconDraft: "place",
  iconAnnotations: [],
  selectedAnnotation: null,
  savedDrawFeatures: [],
  saveSelectedObjectRequest: null,
  focusSavedObjectRequest: null,
  drawSearchTarget: null,
  setActivePanel: (activePanel) => set((state) => ({
    activePanel,
    // Focus địa giới chỉ là trạng thái tương tác tạm thời của Khoanh vùng / Địa giới.
    // Xóa focus khi chuyển menu để click trên bản đồ không còn mang ngữ nghĩa khoanh vùng.
    focusedAdministrativeId: activePanel === "zones" ? state.focusedAdministrativeId : null,
  })),
  setDrawMode: (drawMode) => set({ drawMode }),
  setSearch: (search) => set({ search }),
  setZoneMode: (zoneMode) => set((state) => ({
    zoneMode,
    drawMode: zoneMode === "draw"
      ? "select"
      : zoneMode === "info" && state.selectedDrawFeatureId !== null
        ? "select"
        : null,
  })),
  setAdministrativeUnits: (administrativeUnits) => set({ administrativeUnits, administrativeStatus: "ready" }),
  setAdministrativeStatus: (administrativeStatus) => set({ administrativeStatus }),
  setInitialViewportReady: (initialViewportReady) => set({ initialViewportReady }),
  setAdministrativeQuery: (administrativeQuery) => set({ administrativeQuery }),
  toggleAdministrativeUnit: (id) => set((state) => ({
    selectedAdministrativeIds: state.selectedAdministrativeIds.includes(id)
      ? state.selectedAdministrativeIds.filter((item) => item !== id)
      : [...state.selectedAdministrativeIds, id],
    focusedAdministrativeId: state.focusedAdministrativeId === id ? null : state.focusedAdministrativeId,
  })),
  cycleAdministrativeUnit: (id) => set((state) => {
    const active = state.selectedAdministrativeIds.includes(id);
    if (!active) return { selectedAdministrativeIds: [...state.selectedAdministrativeIds, id], focusedAdministrativeId: null };
    if (state.focusedAdministrativeId !== id) return { focusedAdministrativeId: id };
    return {
      selectedAdministrativeIds: state.selectedAdministrativeIds.filter((item) => item !== id),
      focusedAdministrativeId: null,
    };
  }),
  selectAdministrativeUnit: (id) => set((state) => ({
    selectedAdministrativeIds: state.selectedAdministrativeIds.includes(id)
      ? state.selectedAdministrativeIds
      : [...state.selectedAdministrativeIds, id],
  })),
  removeAdministrativeUnit: (id) => set((state) => ({
    selectedAdministrativeIds: state.selectedAdministrativeIds.filter((item) => item !== id),
    focusedAdministrativeId: state.focusedAdministrativeId === id ? null : state.focusedAdministrativeId,
  })),
  clearAdministrativeFocus: () => set({ focusedAdministrativeId: null }),
  clearAdministrativeSelection: () => set({ selectedAdministrativeIds: [], focusedAdministrativeId: null }),
  setDimOutsideHaiphong: (dimOutsideHaiphong) => set({ dimOutsideHaiphong }),
  setDefaultViewportEnabled: (defaultViewportEnabled) => set({ defaultViewportEnabled }),
  setDefaultViewport: (defaultViewport) => set({ defaultViewport, defaultAdministrativeIds: [], defaultViewportSaveRequest: 0 }),
  requestDefaultViewportSave: () => set((state) => ({ defaultViewportSaveRequest: state.defaultViewportSaveRequest + 1 })),
  setDefaultAdministrativeViewport: (defaultAdministrativeIds, defaultViewport) => set({
    defaultAdministrativeIds,
    defaultViewport,
    defaultViewportEnabled: true,
    defaultAdministrativeSaveRequest: null,
  }),
  requestDefaultAdministrativeSave: (ids) => set((state) => ({
    defaultAdministrativeSaveRequest: {
      ids,
      request: (state.defaultAdministrativeSaveRequest?.request ?? 0) + 1,
    },
  })),
  setAdministrativeFillColor: (administrativeFillColor) => set({ administrativeFillColor }),
  setAdministrativeOutlineColor: (administrativeOutlineColor) => set({ administrativeOutlineColor }),
  setAdministrativeFillOpacity: (administrativeFillOpacity) => set({ administrativeFillOpacity: Math.max(0.05, Math.min(1, administrativeFillOpacity)) }),
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
  setTextDraft: (textDraft) => set({ textDraft }),
  addTextAnnotation: (coordinates) => set((state) => {
    const text = state.textDraft.trim();
    if (!text) return state;
    return {
      textAnnotations: [...state.textAnnotations, {
        id: `text-${Date.now()}-${state.textAnnotations.length}`,
        text,
        coordinates,
        color: state.drawOutlineColor,
        visible: true,
        saved: false,
      }],
      drawMode: "select",
    };
  }),
  setIconDraft: (iconDraft) => set({ iconDraft }),
  addIconAnnotation: (coordinates) => set((state) => ({
    iconAnnotations: [...state.iconAnnotations, {
      id: `icon-${Date.now()}-${state.iconAnnotations.length}`,
      icon: state.iconDraft,
      coordinates,
      color: state.drawOutlineColor,
      visible: true,
      saved: false,
    }],
    drawMode: "select",
  })),
  selectAnnotation: (kind, id) => set({ selectedAnnotation: { kind, id }, selectedDrawFeatureId: null, selectedDrawFeatureInfo: null, zoneMode: "draw", drawMode: "select" }),
  updateSelectedAnnotationText: (text) => set((state) => state.selectedAnnotation?.kind === "text" ? ({
    textAnnotations: state.textAnnotations.map((annotation) => annotation.id === state.selectedAnnotation?.id ? { ...annotation, text } : annotation),
  }) : state),
  updateSelectedAnnotationIcon: (icon) => set((state) => state.selectedAnnotation?.kind === "icon" ? ({
    iconAnnotations: state.iconAnnotations.map((annotation) => annotation.id === state.selectedAnnotation?.id ? { ...annotation, icon } : annotation),
  }) : state),
  updateSelectedAnnotationColor: (color) => set((state) => {
    if (!state.selectedAnnotation) return state;
    return state.selectedAnnotation.kind === "text"
      ? { textAnnotations: state.textAnnotations.map((annotation) => annotation.id === state.selectedAnnotation?.id ? { ...annotation, color } : annotation) }
      : { iconAnnotations: state.iconAnnotations.map((annotation) => annotation.id === state.selectedAnnotation?.id ? { ...annotation, color } : annotation) };
  }),
  moveAnnotation: (kind, id, coordinates) => set((state) => kind === "text" ? ({
    textAnnotations: state.textAnnotations.map((annotation) => annotation.id === id ? { ...annotation, coordinates } : annotation),
  }) : ({
    iconAnnotations: state.iconAnnotations.map((annotation) => annotation.id === id ? { ...annotation, coordinates } : annotation),
  })),
  deleteSelectedAnnotation: () => set((state) => {
    if (!state.selectedAnnotation) return state;
    return state.selectedAnnotation.kind === "text"
      ? { textAnnotations: state.textAnnotations.filter((annotation) => annotation.id !== state.selectedAnnotation?.id), selectedAnnotation: null }
      : { iconAnnotations: state.iconAnnotations.filter((annotation) => annotation.id !== state.selectedAnnotation?.id), selectedAnnotation: null };
  }),
  clearSelectedAnnotation: () => set({ selectedAnnotation: null }),
  saveSelectedObject: (rawName) => set((state) => {
    const name = rawName.trim() || "Đối tượng chưa đặt tên";
    if (state.selectedAnnotation?.kind === "text") {
      return {
        textAnnotations: state.textAnnotations.map((item) => item.id === state.selectedAnnotation?.id
          ? { ...item, name, saved: true, visible: true }
          : item),
      };
    }
    if (state.selectedAnnotation?.kind === "icon") {
      return {
        iconAnnotations: state.iconAnnotations.map((item) => item.id === state.selectedAnnotation?.id
          ? { ...item, name, saved: true, visible: true }
          : item),
      };
    }
    if (state.selectedDrawFeatureId === null) return state;
    return {
      saveSelectedObjectRequest: {
        name,
        request: (state.saveSelectedObjectRequest?.request ?? 0) + 1,
      },
    };
  }),
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
  toggleSavedObject: (kind, id) => set((state) => {
    if (kind === "geometry") return { savedDrawFeatures: state.savedDrawFeatures.map((item) => item.id === id ? { ...item, visible: !item.visible } : item) };
    if (kind === "text") return { textAnnotations: state.textAnnotations.map((item) => item.id === id ? { ...item, visible: item.visible === false } : item) };
    return { iconAnnotations: state.iconAnnotations.map((item) => item.id === id ? { ...item, visible: item.visible === false } : item) };
  }),
  renameSavedObject: (kind, id, rawName) => set((state) => {
    const name = rawName.trim();
    if (!name) return state;
    if (kind === "geometry") return { savedDrawFeatures: state.savedDrawFeatures.map((item) => item.id === id ? { ...item, name } : item) };
    if (kind === "text") return { textAnnotations: state.textAnnotations.map((item) => item.id === id ? { ...item, name } : item) };
    return { iconAnnotations: state.iconAnnotations.map((item) => item.id === id ? { ...item, name } : item) };
  }),
  deleteSavedObject: (kind, id) => set((state) => {
    if (kind === "geometry") return { savedDrawFeatures: state.savedDrawFeatures.filter((item) => item.id !== id) };
    if (kind === "text") return { textAnnotations: state.textAnnotations.filter((item) => item.id !== id), selectedAnnotation: state.selectedAnnotation?.id === id ? null : state.selectedAnnotation };
    return { iconAnnotations: state.iconAnnotations.filter((item) => item.id !== id), selectedAnnotation: state.selectedAnnotation?.id === id ? null : state.selectedAnnotation };
  }),
  requestFocusSavedObject: (kind, id) => set((state) => ({
    focusSavedObjectRequest: { kind, id, request: (state.focusSavedObjectRequest?.request ?? 0) + 1 },
    savedDrawFeatures: kind === "geometry" ? state.savedDrawFeatures.map((item) => item.id === id ? { ...item, visible: true } : item) : state.savedDrawFeatures,
    textAnnotations: kind === "text" ? state.textAnnotations.map((item) => item.id === id ? { ...item, visible: true } : item) : state.textAnnotations,
    iconAnnotations: kind === "icon" ? state.iconAnnotations.map((item) => item.id === id ? { ...item, visible: true } : item) : state.iconAnnotations,
  })),
  setDrawSearchTarget: (drawSearchTarget) => set({ drawSearchTarget }),
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
  setBaseMapMode: (baseMapMode) => set({ baseMapMode }),
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
}), {
  name: "haiphong-map-display-preferences",
  version: 4,
  migrate: (persistedState, version) => {
    const saved = (persistedState ?? {}) as Record<string, unknown>;
    // v2 bật lại nền tối một lần cho các trình duyệt đã từng mở bản public v1.
    // Sau migration, lựa chọn bật/tắt của người dùng tiếp tục được lưu bình thường.
    const migrated = version < 2 ? { ...saved, dimOutsideHaiphong: true } : saved;
    if (version < 3 && migrated.hnthPointOverrides && typeof migrated.hnthPointOverrides === "object") {
      migrated.hnthPointOverrides = Object.fromEntries(Object.entries(migrated.hnthPointOverrides as Record<string, HnthPointOverride>).map(([id, point]) => [
        id,
        { ...point, status: normalizeHnthStatus(point.status) },
      ]));
    }
    // v4: trạng thái khởi tạo HNTH phải là "unknown"; chỉ kết quả ping hoặc
    // thao tác vận hành hiện tại mới được chuyển sang trạng thái kết nối.
    if (version < 4 && migrated.hnthPointOverrides && typeof migrated.hnthPointOverrides === "object") {
      migrated.hnthPointOverrides = Object.fromEntries(Object.entries(migrated.hnthPointOverrides as Record<string, HnthPointOverride>).map(([id, point]) => [
        id,
        { ...point, status: "unknown" },
      ]));
    }
    return migrated;
  },
  partialize: (state) => ({
    layerVisibility: state.layerVisibility,
    clusterLevel: state.clusterLevel,
    baseMapMode: state.baseMapMode,
    dimOutsideHaiphong: state.dimOutsideHaiphong,
    defaultViewportEnabled: state.defaultViewportEnabled,
    defaultViewport: state.defaultViewport,
    defaultAdministrativeIds: state.defaultAdministrativeIds,
    administrativeFillColor: state.administrativeFillColor,
    administrativeOutlineColor: state.administrativeOutlineColor,
    administrativeFillOpacity: state.administrativeFillOpacity,
    drawFillColor: state.drawFillColor,
    drawOutlineColor: state.drawOutlineColor,
    drawFillOpacity: state.drawFillOpacity,
    savedDrawFeatures: state.savedDrawFeatures,
    textAnnotations: state.textAnnotations.filter((item) => item.saved),
    iconAnnotations: state.iconAnnotations.filter((item) => item.saved),
    hnthPointOverrides: state.hnthPointOverrides,
    hnthLineVisible: state.hnthLineVisible,
    hnthLineStyles: state.hnthLineStyles,
    hnthAreaStyles: state.hnthAreaStyles,
    hnthAreaVisible: state.hnthAreaVisible,
  }),
  merge: (persistedState, currentState) => {
    const saved = persistedState as Partial<Pick<AppState, "layerVisibility" | "clusterLevel" | "baseMapMode" | "dimOutsideHaiphong" | "defaultViewportEnabled" | "defaultViewport" | "defaultAdministrativeIds" | "administrativeFillColor" | "administrativeOutlineColor" | "administrativeFillOpacity" | "drawFillColor" | "drawOutlineColor" | "drawFillOpacity" | "savedDrawFeatures" | "textAnnotations" | "iconAnnotations" | "hnthPointOverrides" | "hnthLineVisible" | "hnthLineStyles" | "hnthAreaStyles" | "hnthAreaVisible">> & {
      // Tương thích cấu hình cũ từng chỉ lưu một địa giới.
      defaultAdministrativeId?: number | null;
    };
    const layerVisibility = { ...currentState.layerVisibility, ...saved.layerVisibility };
    const defaultAdministrativeIds = saved.defaultAdministrativeIds
      ?? (saved.defaultAdministrativeId !== null && saved.defaultAdministrativeId !== undefined ? [saved.defaultAdministrativeId] : []);
    const hnthLineStyles = { ...currentState.hnthLineStyles, ...saved.hnthLineStyles };
    // Nâng màu xanh lá mặc định cũ lên màu cyan mới; màu người dùng tự chọn vẫn được giữ nguyên.
    if (saved.hnthLineStyles?.connected?.color.toLowerCase() === "#22c55e") {
      hnthLineStyles.connected = {
        ...hnthLineStyles.connected,
        color: currentState.hnthLineStyles.connected.color,
      };
    }
    return {
      ...currentState,
      ...saved,
      layerVisibility,
      defaultAdministrativeIds,
      savedDrawFeatures: saved.savedDrawFeatures ?? [],
      textAnnotations: (saved.textAnnotations ?? []).map((item) => ({ ...item, saved: true, visible: item.visible !== false })),
      iconAnnotations: (saved.iconAnnotations ?? []).map((item) => ({ ...item, saved: true, visible: item.visible !== false })),
      hnthPointOverrides: saved.hnthPointOverrides ?? {},
      hnthLineVisible: saved.hnthLineVisible ?? currentState.hnthLineVisible,
      hnthLineStyles,
      hnthAreaStyles: { ...currentState.hnthAreaStyles, ...saved.hnthAreaStyles },
      hnthAreaVisible: saved.hnthAreaVisible ?? currentState.hnthAreaVisible,
      layers: currentState.layers.map((layer) => ({
        ...layer,
        visible: layerVisibility[layer.id] ?? layer.visible,
      })),
    };
  },
}));
