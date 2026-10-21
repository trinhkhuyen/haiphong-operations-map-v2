// Viền kiểm tra địa giới (nháy viền), thẻ thông tin cố định và lệnh focus điểm HNTH.
import { useCallback, useEffect } from "react";
import { onAppEvent } from "../../../core/events";
import { clearAdministrativeConnection } from "../lib/administrative";
import type { MapScope } from "./useMapScope";

export function useMapInspection(context: MapScope) {
  const { mapRef, inspectedBoundaryPulseTimeoutsRef, setInspectedAdministrativeId, setInspectedAdministrativeIds, setFixedMapInfo } = context;
  const stopInspectedBoundaryPulse = useCallback(() => {
    for (const timeoutId of inspectedBoundaryPulseTimeoutsRef.current) window.clearTimeout(timeoutId);
    inspectedBoundaryPulseTimeoutsRef.current = [];
    const map = mapRef.current;
    if (map?.getLayer("administrative-inspected-line")) {
      map.setPaintProperty("administrative-inspected-line", "line-width", 1.1);
    }
  }, []);

  const pulseInspectedBoundary = useCallback((administrativeId: number | number[], cycleCount = 5, boundaryWidthMultiplier = 1, durationMs?: number, animate = true) => {
    const map = mapRef.current;
    if (!map?.getLayer("administrative-inspected-line")) return;
    const administrativeIds = [...new Set((Array.isArray(administrativeId) ? administrativeId : [administrativeId])
      .map((id) => Number(id))
      .filter((id) => Number.isFinite(id)))];
    if (!administrativeIds.length) return;
    stopInspectedBoundaryPulse();
    setInspectedAdministrativeId(administrativeIds[0]);
    setInspectedAdministrativeIds(administrativeIds);
    map.setFilter("administrative-inspected-line", administrativeIds.length === 1
      ? ["==", ["get", "id"], administrativeIds[0]]
      : ["in", ["get", "id"], ["literal", administrativeIds]]);
    map.moveLayer("administrative-inspected-line");

    // Lặp tối đa năm chu kỳ nhận diện: mảnh 1x → đậm 2x → đậm 3x → mảnh.
    // Sau chu kỳ cuối, giữ viền ở mức x2 để địa giới vẫn dễ nhận biết.
    // stopInspectedBoundaryPulse hủy toàn bộ chu kỳ khi nhấn Esc hoặc chọn nhánh khác.
    const normalizedCycleCount = Math.max(1, Math.min(5, Math.round(cycleCount)));
    const baseWidth = 1.1 * Math.max(1, boundaryWidthMultiplier);
    if (!animate) {
      // Thay đổi trạng thái tự động chỉ hiển thị viền trắng mảnh x2,
      // không chạy hiệu ứng tăng/giảm độ dày.
      map.setPaintProperty("administrative-inspected-line", "line-width", baseWidth);
      if (durationMs !== undefined) {
        inspectedBoundaryPulseTimeoutsRef.current = [window.setTimeout(() => {
          stopInspectedBoundaryPulse();
          const currentMap = mapRef.current;
          if (currentMap?.getLayer("administrative-inspected-line")) {
            currentMap.setFilter("administrative-inspected-line", ["==", ["get", "id"], -1]);
          }
          setInspectedAdministrativeId(null);
          setInspectedAdministrativeIds([]);
        }, Math.max(1, durationMs))];
      }
      return;
    }
    const steps = Array.from({ length: normalizedCycleCount }, (_, cycleIndex) => {
      const cycleStart = cycleIndex * 840;
      return [
        { delay: cycleStart, width: baseWidth },
        { delay: cycleStart + 280, width: baseWidth * 2 },
        { delay: cycleStart + 560, width: baseWidth * 3 },
        { delay: cycleStart + 840, width: cycleIndex === normalizedCycleCount - 1 ? baseWidth * 2 : baseWidth },
      ];
    }).flat();
    inspectedBoundaryPulseTimeoutsRef.current = steps.map(({ delay, width }) => window.setTimeout(() => {
      const currentMap = mapRef.current;
      if (currentMap?.getLayer("administrative-inspected-line")) {
        currentMap.setPaintProperty("administrative-inspected-line", "line-width", width);
      }
    }, delay));
    if (durationMs !== undefined) {
      inspectedBoundaryPulseTimeoutsRef.current.push(window.setTimeout(() => {
        stopInspectedBoundaryPulse();
      }, Math.max(1, durationMs)));
    }
  }, [stopInspectedBoundaryPulse]);

  useEffect(() => {
    return onAppEvent("map:administrative-pulse", (detail) => {
      const ids = detail?.administrativeIds?.length ? detail.administrativeIds : detail?.administrativeId === undefined ? [] : [detail.administrativeId];
      if (!ids.length) return;
      pulseInspectedBoundary(ids, detail.cycles ?? 3, detail.boundaryWidthMultiplier ?? 1, detail.durationMs, detail.animate ?? true);
    });
  }, [pulseInspectedBoundary]);

  const clearMapInspection = useCallback(() => {
    stopInspectedBoundaryPulse();
    setInspectedAdministrativeId(null);
    setInspectedAdministrativeIds([]);
    setFixedMapInfo(null);
    if (mapRef.current) clearAdministrativeConnection(mapRef.current);
  }, [stopInspectedBoundaryPulse]);

  useEffect(() => {
    return onAppEvent("hnth:focus", (detail) => {
      const coordinates = detail?.coordinates;
      if (!coordinates || !mapRef.current) return;
      if (detail.administrativeId !== undefined) {
        stopInspectedBoundaryPulse();
        setInspectedAdministrativeId(detail.administrativeId);
        setInspectedAdministrativeIds([detail.administrativeId]);
        if (mapRef.current.getLayer("administrative-inspected-line")) {
          const widthMultiplier = Math.max(1, detail.boundaryWidthMultiplier ?? 1);
          mapRef.current.setPaintProperty("administrative-inspected-line", "line-width", 1.1 * widthMultiplier);
        }
      }
      const currentZoom = mapRef.current.getZoom();
      const zoomFraction = Math.max(0, Math.min(1, detail.zoomFraction ?? 1));
      const targetZoom = detail.targetZoom ?? (currentZoom < 13
        ? currentZoom + ((13 - currentZoom) * zoomFraction)
        : currentZoom);
      mapRef.current.easeTo({
        center: coordinates,
        ...(detail.preserveZoom ? {} : { zoom: targetZoom }),
        duration: 700,
      });
    });
  }, [stopInspectedBoundaryPulse]);

  useEffect(() => {
    return onAppEvent("map:context-info", (detail) => {
      if (detail?.kind === "hnth" && detail.pointId) {
        setFixedMapInfo(detail);
        setInspectedAdministrativeId(detail.administrativeId ?? null);
        setInspectedAdministrativeIds(detail.administrativeId === undefined ? [] : [detail.administrativeId]);
        if (detail.pulseBoundary && detail.administrativeId !== undefined) {
          pulseInspectedBoundary(detail.administrativeId);
        }
      }
    });
  }, [pulseInspectedBoundary]);
  return { stopInspectedBoundaryPulse, pulseInspectedBoundary, clearMapInspection };
}

export type MapInspection = ReturnType<typeof useMapInspection>;
