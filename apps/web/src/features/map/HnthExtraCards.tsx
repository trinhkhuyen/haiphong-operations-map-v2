import { useEffect, useLayoutEffect, useMemo, useRef, useState, type RefObject } from "react";
import type { Map as MapLibreMap } from "maplibre-gl";
import { useAppStore } from "../../core/store";
import { onAppEvent } from "../../core/events";
import { HNTH_HUB, HNTH_LAYER_ID, HNTH_STATUS_LABELS, normalizeHnthStatus } from "../layers/hnth-data-provider";
import { focusHnthPoint } from "../conference/hnth-focus";
import type { HnthPointFeature } from "../conference/hnth-types";

type Line = { pointId: string; d: string; color: string };

/**
 * Điểm Sở/Ban/Ngành không có vị trí trên bản đồ: hiển thị thành cột card ở mép bản đồ, phía
 * đối diện log trong suốt (Ctrl+`). Đường nối vẽ bằng SVG từ điểm Trung tâm (tính lại khi bản
 * đồ di chuyển), màu đường/nền card theo cùng bảng màu trạng thái với xã/phường.
 */
export function HnthExtraCards({ mapRef, isMapReady }: { mapRef: RefObject<MapLibreMap | null>; isMapReady: boolean }) {
  const layer = useAppStore((state) => state.layers.find((item) => item.id === HNTH_LAYER_ID));
  const layerVisible = useAppStore((state) => state.layerVisibility[HNTH_LAYER_ID] !== false);
  const logOnRight = useAppStore((state) => state.hnthLogOnRight);
  const selectedPointId = useAppStore((state) => state.selectedHnthPointId);
  const lineStyles = useAppStore((state) => state.hnthLineStyles);
  const areaStyles = useAppStore((state) => state.hnthAreaStyles);
  const lineVisible = useAppStore((state) => state.hnthLineVisible);
  const areaVisible = useAppStore((state) => state.hnthAreaVisible);
  const extras = useMemo(() => (layer?.data.features ?? []).filter((item): item is HnthPointFeature => item.geometry.type === "Point" && item.properties?.role === "extra"), [layer]);
  const onRight = !logOnRight;
  const cardRefs = useRef(new Map<string, HTMLButtonElement>());
  const [lines, setLines] = useState<Line[]>([]);
  const [pulseId, setPulseId] = useState<string | null>(null);
  const [frame, setFrame] = useState(0);

  // Bản đồ di chuyển/đổi kích thước thì tính lại đường nối (gộp theo khung hình).
  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map || !extras.length) return;
    let raf = 0;
    const schedule = () => { if (!raf) raf = window.requestAnimationFrame(() => { raf = 0; setFrame((value) => value + 1); }); };
    map.on("move", schedule);
    map.on("resize", schedule);
    // Cột card đổi chỗ bằng CSS khi popup Chi tiết đóng/mở hoặc log đổi phía (không có sự kiện
    // bản đồ nào): theo dõi thay đổi trong khu vực bản đồ để vẽ lại đường nối.
    const area = map.getContainer().parentElement;
    const observer = new MutationObserver(schedule);
    if (area) observer.observe(area, { childList: true, subtree: true, attributes: true, attributeFilter: ["class"] });
    return () => { map.off("move", schedule); map.off("resize", schedule); observer.disconnect(); window.cancelAnimationFrame(raf); };
  }, [mapRef, isMapReady, extras.length]);

  useLayoutEffect(() => {
    const map = mapRef.current;
    if (!map || !isMapReady || !lineVisible) { setLines([]); return; }
    const box = map.getContainer().getBoundingClientRect();
    const hub = map.project(HNTH_HUB);
    setLines(extras.flatMap((item) => {
      const pointId = String(item.properties?.pointId ?? "");
      const card = cardRefs.current.get(pointId)?.getBoundingClientRect();
      const style = lineStyles[normalizeHnthStatus(item.properties?.status)];
      if (!card || !style?.visible) return [];
      // Gắn vào cạnh card gần điểm Trung tâm nhất (cột card có thể bị dời qua bên kia điểm Trung tâm).
      const left = card.left - box.left;
      const right = card.right - box.left;
      const x = hub.x <= left ? left : hub.x >= right ? right : (left + right) / 2;
      const y = card.top + card.height / 2 - box.top;
      // Cong nhẹ: điểm điều khiển ngang tầm điểm Trung tâm, giữa đường.
      return [{ pointId, color: style.color, d: `M${hub.x},${hub.y} Q${(hub.x + x) / 2},${hub.y} ${x},${y}` }];
    }));
  }, [frame, extras, onRight, lineStyles, lineVisible, isMapReady, mapRef]);

  useEffect(() => onAppEvent("hnth:extra-focus", ({ pointId }) => {
    setPulseId(null);
    window.requestAnimationFrame(() => setPulseId(pointId));
    cardRefs.current.get(pointId)?.scrollIntoView({ block: "nearest" });
  }), []);
  useEffect(() => {
    if (!pulseId) return;
    const timer = window.setTimeout(() => setPulseId(null), 1800);
    return () => window.clearTimeout(timer);
  }, [pulseId]);

  if (!layerVisible || !extras.length) return null;
  return <>
    <svg className="hnth-extra-lines" aria-hidden="true">
      {lines.map((line) => <path key={line.pointId} d={line.d} stroke={line.color} />)}
    </svg>
    <div className={`hnth-extra-cards ${onRight ? "is-right" : "is-left"}`} role="list" aria-label="Điểm cầu Sở/Ban/Ngành">
      {extras.map((item) => {
        const pointId = String(item.properties?.pointId ?? "");
        const status = normalizeHnthStatus(item.properties?.status);
        const area = areaStyles[status];
        const ip = String(item.properties?.ipAddress ?? "").trim();
        const background = areaVisible && area?.visible && area.color !== "transparent" ? `${area.color}33` : undefined;
        return <button
          key={pointId}
          ref={(element) => { if (element) cardRefs.current.set(pointId, element); else cardRefs.current.delete(pointId); }}
          type="button"
          role="listitem"
          className={`hnth-extra-card ${status}${selectedPointId === pointId ? " is-selected" : ""}${pulseId === pointId ? " is-pulsing" : ""}`}
          style={{ background, borderColor: lineStyles[status]?.visible ? lineStyles[status].color : undefined }}
          onClick={() => focusHnthPoint(item)}
        >
          <strong>{String(item.properties?.name ?? pointId)}</strong>
          <small>{ip || "Chưa có IP"}</small>
          <em><i/>{HNTH_STATUS_LABELS[status]}</em>
        </button>;
      })}
    </div>
  </>;
}
