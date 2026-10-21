// Đồng bộ kiểu hiển thị lớp HNTH (line/điểm/tô địa giới theo trạng thái).
import { useEffect } from "react";
import { useAppStore } from "../../../core/store";
import { HNTH_LAYER_ID } from "../../layers/hnth-data-provider";
import { syncHnthVisualStyles } from "../lib/hnth-layer";
import type { MapScope } from "./useMapScope";

export function useHnthMapSync(context: MapScope) {
  const { mapRef, isMapReady } = context;
  const layers = useAppStore((state) => state.layers);
  const administrativeUnits = useAppStore((state) => state.administrativeUnits);
  const hnthLineStyles = useAppStore((state) => state.hnthLineStyles);
  const hnthAreaStyles = useAppStore((state) => state.hnthAreaStyles);
  const hnthAreaVisible = useAppStore((state) => state.hnthAreaVisible);
  const hnthLineVisible = useAppStore((state) => state.hnthLineVisible);
  const hnthPointVisible = useAppStore((state) => state.hnthPointVisible);
  const activePanel = useAppStore((state) => state.activePanel);
  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map?.getSource("administrative-units")) return;
    const hnthLayer = layers.find((layer) => layer.id === HNTH_LAYER_ID);
    if (!hnthLayer) return;
    // HNTH là lớp giám sát nền: chuyển menu không được làm mất điểm, line,
    // màu nền hoặc các popup khi agent vẫn đang chạy.
    syncHnthVisualStyles(map, hnthLayer, hnthLineVisible, hnthLineStyles, hnthAreaStyles, hnthAreaVisible, hnthPointVisible, true);

    // Sau F5, React có thể cập nhật trạng thái trước khi MapLibre nạp xong
    // source GeoJSON. Khi đó querySourceFeatures() trả về rỗng, cache đánh
    // dấu là đã đồng bộ và line/fill không được vẽ lại. Đồng bộ lại khi một
    // trong hai source liên quan phát thông báo đã nạp dữ liệu; thao tác này
    // chỉ cập nhật feature-state, không setData nên không gây nháy bản đồ.
    const resyncAfterSourceLoad = (event: { sourceId?: string }) => {
      if (event.sourceId !== HNTH_LAYER_ID && event.sourceId !== "administrative-units") return;
      const latestLayer = useAppStore.getState().layers.find((layer) => layer.id === HNTH_LAYER_ID);
      if (!latestLayer) return;
      syncHnthVisualStyles(map, latestLayer, hnthLineVisible, hnthLineStyles, hnthAreaStyles, hnthAreaVisible, hnthPointVisible, true, true);
    };
    map.on("sourcedata", resyncAfterSourceLoad);
    return () => {
      map.off("sourcedata", resyncAfterSourceLoad);
    };
  }, [layers, administrativeUnits, hnthLineVisible, hnthLineStyles, hnthAreaStyles, hnthAreaVisible, hnthPointVisible, activePanel, isMapReady]);
}
