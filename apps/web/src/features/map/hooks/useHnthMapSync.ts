// Đồng bộ kiểu hiển thị lớp HNTH (line/điểm/tô địa giới theo trạng thái).
import { useEffect } from "react";
import { useAppStore } from "../../../core/store";
import { HNTH_LAYER_ID } from "../../layers/hnth-data-provider";
import { HNTH_SIGNAL_SOURCE_ID, syncHnthVisualStyles } from "../lib/hnth-layer";
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
    if (!isMapReady || !map || activePanel !== "conference") return;

    const trySyncHnthVisuals = () => {
      const hnthLayer = useAppStore.getState().layers.find((layer) => layer.id === HNTH_LAYER_ID);
      // Keep the listeners attached while MapLibre is still creating sources.
      // This is important after F5: the HNTH source and administrative source
      // are created in different effects and are not guaranteed to exist in
      // the same render pass.
      // The administrative source is independent from HNTH signal dots. Do
      // not block the line/signal sync on its slower F5 load; the feature
      // state helper already ignores it until that source exists.
      if (!hnthLayer || !map.getSource(HNTH_LAYER_ID) || !map.getSource(HNTH_SIGNAL_SOURCE_ID)) return;
      // HNTH là lớp giám sát nền: chuyển menu không được làm mất điểm, line,
      // màu nền hoặc các popup khi agent vẫn đang chạy.
      syncHnthVisualStyles(map, hnthLayer, hnthLineVisible, hnthLineStyles, hnthAreaStyles, hnthAreaVisible, hnthPointVisible, true, true);
    };

    // Sau F5, React có thể cập nhật trạng thái trước khi MapLibre nạp xong
    // source GeoJSON. Khi đó querySourceFeatures() trả về rỗng, cache đánh
    // dấu là đã đồng bộ và line/fill không được vẽ lại. Đồng bộ lại khi một
    // trong hai source liên quan phát thông báo đã nạp dữ liệu; thao tác này
    // chỉ cập nhật feature-state, không setData nên không gây nháy bản đồ.
    const resyncAfterSourceLoad = (event: { sourceId?: string }) => {
      if (event.sourceId !== HNTH_LAYER_ID && event.sourceId !== HNTH_SIGNAL_SOURCE_ID && event.sourceId !== "administrative-units") return;
      trySyncHnthVisuals();
    };
    // `sourcedata` is not guaranteed for a source that is added after the
    // listener is attached, so also retry once when MapLibre reaches idle.
    map.once("idle", trySyncHnthVisuals);
    map.on("sourcedata", resyncAfterSourceLoad);
    return () => {
      map.off("idle", trySyncHnthVisuals);
      map.off("sourcedata", resyncAfterSourceLoad);
    };
  }, [layers, administrativeUnits, hnthLineVisible, hnthLineStyles, hnthAreaStyles, hnthAreaVisible, hnthPointVisible, activePanel, isMapReady]);
}
