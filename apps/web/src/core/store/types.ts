import type { StateCreator } from "zustand";
import type { AdministrativeSlice } from "./administrative";
import type { AnnotationsSlice } from "./annotations";
import type { DrawingSlice } from "./drawing";
import type { HnthSlice } from "./hnth";
import type { CameraSlice } from "./camera";
import type { LayersSlice } from "./layers";
import type { MapSlice } from "./map";
import type { UiSlice } from "./ui";

export type AppState = UiSlice & LayersSlice & MapSlice & AdministrativeSlice & DrawingSlice & AnnotationsSlice & HnthSlice & CameraSlice;

/**
 * Một slice của useAppStore. `set`/`get` thao tác trên toàn bộ AppState, nên
 * action được phép đọc/ghi trường của slice khác (vd chọn nhãn thì chuyển sang
 * chế độ vẽ) — giữ nguyên ngữ nghĩa của store một khối trước đây.
 */
export type AppSlice<T> = StateCreator<AppState, [["zustand/persist", unknown]], [], T>;
