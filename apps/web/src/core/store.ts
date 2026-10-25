// Store ứng dụng (Zustand + persist). Mỗi nhóm trạng thái là một slice trong
// `core/store/`; file này chỉ ráp slice và gắn persist (`core/store/persist.ts`).
import { create } from "zustand";
import { persist } from "zustand/middleware";
import { createAdministrativeSlice } from "./store/administrative";
import { createAnnotationsSlice } from "./store/annotations";
import { createDrawingSlice } from "./store/drawing";
import { createHnthSlice } from "./store/hnth";
import { createCameraSlice } from "./store/camera";
import { createLayersSlice } from "./store/layers";
import { createMapSlice } from "./store/map";
import { persistOptions } from "./store/persist";
import type { AppState } from "./store/types";
import { createUiSlice } from "./store/ui";

export type { AppState } from "./store/types";

export const useAppStore = create<AppState>()(persist((...args) => ({
  ...createLayersSlice(...args),
  ...createUiSlice(...args),
  ...createHnthSlice(...args),
  ...createCameraSlice(...args),
  ...createDrawingSlice(...args),
  ...createAdministrativeSlice(...args),
  ...createMapSlice(...args),
  ...createAnnotationsSlice(...args),
}), persistOptions));
