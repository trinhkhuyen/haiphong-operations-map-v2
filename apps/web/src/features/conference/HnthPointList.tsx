import { useMemo, useState } from "react";
import { RadioTower, Search } from "lucide-react";
import { HNTH_STATUS_LABELS, normalizeHnthStatus } from "../layers/hnth-data-provider";
import type { HnthPointFeature } from "./hnth-types";

/** Ô tìm kiếm + danh sách điểm HNTH; bấm một điểm để chọn và đưa bản đồ tới đó. */
export function HnthPointList({ points, selectedPointId, onSelect }: { points: HnthPointFeature[]; selectedPointId: string | null; onSelect: (point: HnthPointFeature) => void }) {
  const [query, setQuery] = useState("");
  const filteredPoints = useMemo(() => {
    const normalized = query.trim().toLocaleLowerCase("vi");
    if (!normalized) return points;
    const normalizedIpQuery = normalized.replace(/\s+/g, "");
    return points.filter((item) => {
      const values = [item.properties?.name, item.properties?.ipAddress, item.properties?.gateway]
        .map((value) => String(value ?? "").toLocaleLowerCase("vi").trim());
      return values.some((value) => value.includes(normalized))
        // Cho phép tìm theo đoạn cuối của IP, ví dụ `.1.1` khớp `192.168.1.1`.
        || values.slice(1).some((value) => normalizedIpQuery.startsWith(".") && value.endsWith(normalizedIpQuery));
    });
  }, [points, query]);

  return <>
    <label className="hnth-search"><Search size={15}/><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Tìm tên điểm, IP, Gateway..."/></label>
    <div className="hnth-point-list">
      {!points.length && <div className="hnth-loading"><RadioTower size={20}/><span>Đang tải danh sách điểm HNTH...</span></div>}
      {filteredPoints.map((item) => {
        const id = String(item.properties?.pointId ?? item.id);
        const status = normalizeHnthStatus(item.properties?.status);
        return <button key={id} className={id === selectedPointId ? "active" : ""} onClick={() => onSelect(item)}>
          <i className={status}/>
          <span><strong>{String(item.properties?.name ?? "Điểm HNTH")}</strong><small>{String(item.properties?.ipAddress ?? "Chưa cấu hình IP")}</small></span>
          <em>{item.properties?.role === "hub" ? "TRUNG TÂM" : HNTH_STATUS_LABELS[status].toLocaleUpperCase("vi")}</em>
        </button>;
      })}
    </div>
  </>;
}
