import type { PersistOptions } from "zustand/middleware";
import type { HnthPointOverride } from "../../features/layers/hnth-data-provider";
import type { CameraDevice } from "./camera";
import { normalizeHnthStatus } from "../../features/layers/hnth-data-provider";
import type { AppState } from "./types";

// Dữ liệu đã lưu trong localStorage của người dùng: key, version và các trường
// dưới đây được store.test.ts khóa lại. Đổi hình dạng thì tăng version + migrate.
type PersistedPreferences = Pick<AppState, "activePanel" | "hubEnabled" | "hubGlassmorphism" | "hubOpacity" | "layerVisibility" | "clusterLevel" | "baseMapMode" | "dimOutsideHaiphong" | "defaultViewportEnabled" | "defaultViewport" | "defaultAdministrativeIds" | "administrativeFillColor" | "administrativeOutlineColor" | "administrativeFillOpacity" | "drawFillColor" | "drawOutlineColor" | "drawFillOpacity" | "savedDrawFeatures" | "textAnnotations" | "iconAnnotations" | "hnthPointOverrides" | "hnthLineVisible" | "hnthLineStyles" | "hnthAreaStyles" | "hnthAreaVisible" | "cameraDevices">;

const PANEL_IDS = ["layers", "zones", "saved", "routing", "conference", "camera", "agents", "hub"] as const;
const isPanelId = (value: unknown): value is AppState["activePanel"] => typeof value === "string" && PANEL_IDS.includes(value as AppState["activePanel"]);

export const persistOptions: PersistOptions<AppState, Record<string, unknown>> = {
  name: "haiphong-map-display-preferences",
  version: 7,
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
    activePanel: state.activePanel,
    hubEnabled: state.hubEnabled,
    hubGlassmorphism: state.hubGlassmorphism,
    hubOpacity: state.hubOpacity,
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
    // Mật khẩu chỉ tồn tại trong form gửi tới backend, không lưu localStorage.
    cameraDevices: state.cameraDevices.map(({ password: _password, ...device }) => device),
  }),
  merge: (persistedState, currentState) => {
    const saved = persistedState as Partial<PersistedPreferences> & {
      // Tương thích cấu hình cũ từng chỉ lưu một địa giới.
      defaultAdministrativeId?: number | null;
    };
    const layerVisibility = { ...currentState.layerVisibility, ...saved.layerVisibility };
    const defaultAdministrativeIds = saved.defaultAdministrativeIds
      ?? (saved.defaultAdministrativeId !== null && saved.defaultAdministrativeId !== undefined ? [saved.defaultAdministrativeId] : []);
    const hnthLineStyles = { ...currentState.hnthLineStyles, ...saved.hnthLineStyles };
    const activePanel = isPanelId(saved.activePanel) ? saved.activePanel : currentState.activePanel;
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
      activePanel,
      hubEnabled: saved.hubEnabled ?? currentState.hubEnabled,
      hubGlassmorphism: saved.hubGlassmorphism ?? currentState.hubGlassmorphism,
      hubOpacity: saved.hubOpacity ?? currentState.hubOpacity,
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
      cameraDevices: (saved.cameraDevices as CameraDevice[] | undefined) ?? currentState.cameraDevices,
      layers: currentState.layers.map((layer) => ({
        ...layer,
        visible: layerVisibility[layer.id] ?? layer.visible,
      })),
    };
  },
};
