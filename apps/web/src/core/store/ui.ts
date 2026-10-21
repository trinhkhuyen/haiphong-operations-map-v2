// Menu đang mở và ô tìm kiếm.
import type { AppSlice } from "./types";

export interface UiSlice {
  activePanel: "layers" | "zones" | "saved" | "routing" | "conference" | "agents";
  search: string;
  setActivePanel: (panel: UiSlice["activePanel"]) => void;
  setSearch: (value: string) => void;
}

export const createUiSlice: AppSlice<UiSlice> = (set) => ({
  // HNTH là màn hình vận hành mặc định của bản trình diễn/public.
  // Trạng thái này không được persist nên mọi phiên truy cập mới đều mở đúng menu HNTH.
  activePanel: "conference",
  search: "",
  setActivePanel: (activePanel) => set((state) => ({
    activePanel,
    // Focus địa giới chỉ là trạng thái tương tác tạm thời của Khoanh vùng / Địa giới.
    // Xóa focus khi chuyển menu để click trên bản đồ không còn mang ngữ nghĩa khoanh vùng.
    focusedAdministrativeId: activePanel === "zones" ? state.focusedAdministrativeId : null,
  })),
  setSearch: (search) => set({ search }),
});
