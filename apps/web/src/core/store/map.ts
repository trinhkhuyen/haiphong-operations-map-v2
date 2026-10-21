// Nền bản đồ, nền tối ngoài Hải Phòng, khung nhìn mặc định.
import type { BaseMapMode, SavedMapViewport } from "../types";
import type { AppSlice } from "./types";

export interface MapSlice {
  baseMapMode: BaseMapMode;
  initialViewportReady: boolean;
  dimOutsideHaiphong: boolean;
  defaultViewportEnabled: boolean;
  defaultViewport: SavedMapViewport | null;
  defaultViewportSaveRequest: number;
  defaultAdministrativeIds: number[];
  defaultAdministrativeSaveRequest: { ids: number[]; request: number } | null;
  setBaseMapMode: (mode: BaseMapMode) => void;
  setInitialViewportReady: (ready: boolean) => void;
  setDimOutsideHaiphong: (enabled: boolean) => void;
  setDefaultViewportEnabled: (enabled: boolean) => void;
  setDefaultViewport: (viewport: SavedMapViewport) => void;
  requestDefaultViewportSave: () => void;
  setDefaultAdministrativeViewport: (ids: number[], viewport: SavedMapViewport) => void;
  requestDefaultAdministrativeSave: (ids: number[]) => void;
}

export const createMapSlice: AppSlice<MapSlice> = (set) => ({
  baseMapMode: "standard",
  initialViewportReady: false,
  // Mặc định bật lớp nền tối bên ngoài địa giới Hải Phòng. Bản public chạy
  // trên origin riêng nên không dùng được localStorage của bản chạy local.
  dimOutsideHaiphong: true,
  defaultViewportEnabled: false,
  defaultViewport: null,
  defaultViewportSaveRequest: 0,
  defaultAdministrativeIds: [],
  defaultAdministrativeSaveRequest: null,
  setInitialViewportReady: (initialViewportReady) => set({ initialViewportReady }),
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
  setBaseMapMode: (baseMapMode) => set({ baseMapMode }),
});
