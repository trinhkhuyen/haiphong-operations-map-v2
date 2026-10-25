// Menu đang mở và ô tìm kiếm.
import type { AppSlice } from "./types";

export interface UiSlice {
  activePanel: "layers" | "zones" | "saved" | "routing" | "conference" | "camera" | "agents" | "hub";
  hubEnabled: boolean;
  hubGlassmorphism: boolean;
  hubOpacity: number;
  search: string;
  setActivePanel: (panel: UiSlice["activePanel"]) => void;
  setHubEnabled: (enabled: boolean) => void;
  setHubGlassmorphism: (enabled: boolean) => void;
  setHubOpacity: (opacity: number) => void;
  setSearch: (value: string) => void;
}

export const createUiSlice: AppSlice<UiSlice> = (set) => ({
  // HNTH là màn hình vận hành mặc định cho người dùng mới. Lựa chọn menu hiện
  // tại được persist để F5/Ctrl+F5 không đưa người dùng quay lại HNTH.
  activePanel: "conference",
  hubEnabled: true,
  hubGlassmorphism: true,
  hubOpacity: 0.72,
  search: "",
  setActivePanel: (activePanel) => set((state) => ({
    activePanel,
    // Focus địa giới chỉ là trạng thái tương tác tạm thời của Khoanh vùng / Địa giới.
    // Xóa focus khi chuyển menu để click trên bản đồ không còn mang ngữ nghĩa khoanh vùng.
    focusedAdministrativeId: activePanel === "zones" ? state.focusedAdministrativeId : null,
  })),
  setSearch: (search) => set({ search }),
  setHubEnabled: (hubEnabled) => set({ hubEnabled }),
  setHubGlassmorphism: (hubGlassmorphism) => set({ hubGlassmorphism }),
  setHubOpacity: (hubOpacity) => set({ hubOpacity: Math.min(1, Math.max(0.25, hubOpacity)) }),
});
