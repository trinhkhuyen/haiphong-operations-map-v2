// Địa giới hành chính: dữ liệu, lựa chọn/focus, màu tô.
import type { AdministrativeUnit } from "../types";
import type { AppSlice } from "./types";

export interface AdministrativeSlice {
  administrativeUnits: AdministrativeUnit[];
  administrativeStatus: "idle" | "loading" | "ready" | "error";
  administrativeQuery: string;
  selectedAdministrativeIds: number[];
  focusedAdministrativeId: number | null;
  administrativeFillColor: string;
  administrativeOutlineColor: string;
  administrativeFillOpacity: number;
  setAdministrativeUnits: (units: AdministrativeUnit[]) => void;
  setAdministrativeStatus: (status: AdministrativeSlice["administrativeStatus"]) => void;
  setAdministrativeQuery: (value: string) => void;
  toggleAdministrativeUnit: (id: number) => void;
  cycleAdministrativeUnit: (id: number) => void;
  selectAdministrativeUnit: (id: number) => void;
  removeAdministrativeUnit: (id: number) => void;
  clearAdministrativeFocus: () => void;
  clearAdministrativeSelection: () => void;
  setAdministrativeFillColor: (color: string) => void;
  setAdministrativeOutlineColor: (color: string) => void;
  setAdministrativeFillOpacity: (opacity: number) => void;
}

export const createAdministrativeSlice: AppSlice<AdministrativeSlice> = (set) => ({
  administrativeUnits: [],
  administrativeStatus: "idle",
  administrativeQuery: "",
  selectedAdministrativeIds: [],
  focusedAdministrativeId: null,
  administrativeFillColor: "#fde68a",
  administrativeOutlineColor: "#d97706",
  administrativeFillOpacity: 0.42,
  setAdministrativeUnits: (administrativeUnits) => set({ administrativeUnits, administrativeStatus: "ready" }),
  setAdministrativeStatus: (administrativeStatus) => set({ administrativeStatus }),
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
  setAdministrativeFillColor: (administrativeFillColor) => set({ administrativeFillColor }),
  setAdministrativeOutlineColor: (administrativeOutlineColor) => set({ administrativeOutlineColor }),
  setAdministrativeFillOpacity: (administrativeFillOpacity) => set({ administrativeFillOpacity: Math.max(0.05, Math.min(1, administrativeFillOpacity)) }),
});
