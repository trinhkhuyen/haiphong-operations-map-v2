// Chọn một điểm HNTH: bay tới, khoanh vùng địa giới (viền nhấp nháy rồi giữ viền dày)
// và mở thông tin điểm. Dùng chung cho popup Chi tiết, log giám sát và ô tìm kiếm HNTH.
import { useAppStore } from "../../core/store";
import { emitAppEvent } from "../../core/events";
import type { HnthPointFeature } from "./hnth-types";

export function focusHnthPoint(item: HnthPointFeature) {
  const state = useAppStore.getState();
  const pointId = String(item.properties?.pointId ?? item.id);
  if (item.properties?.role === "extra") {
    state.setSelectedHnthPointId(pointId);
    emitAppEvent("hnth:extra-focus", { pointId });
    emitAppEvent("map:context-info", { kind: "hnth", pointId });
    return;
  }
  const wardCode = String(item.properties?.wardCode ?? "");
  const administrativeId = state.administrativeUnits.find((unit) => String(unit.wardCode ?? "") === wardCode)?.id;
  state.setSelectedHnthPointId(pointId);
  emitAppEvent("hnth:focus", { coordinates: item.geometry.coordinates as [number, number], preserveZoom: true, administrativeId, boundaryWidthMultiplier: 2 });
  emitAppEvent("map:context-info", { kind: "hnth", pointId, administrativeId, pulseBoundary: true });
}

/** Bỏ dấu tiếng Việt và viết thường để gõ "ai quoc" vẫn tìm được "Ái Quốc". */
export const normalizeSearchText = (value: string) => value.normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/đ/g, "d").replace(/Đ/g, "D").toLowerCase().trim();
