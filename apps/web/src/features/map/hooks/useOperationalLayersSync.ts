// Đồng bộ các lớp dữ liệu vận hành vào source MapLibre; mức gom cụm.
import { useEffect } from "react";
import type { GeoJSONSource } from "maplibre-gl";
import { useAppStore } from "../../../core/store";
import { HNTH_LAYER_ID } from "../../layers/hnth-data-provider";
import { rememberHnthFeatureProperties, syncHnthSourceData } from "../lib/hnth-layer";
import { clusterRadiusForLevel, buildContextualOperationalLayers, raiseOperationalLayers, setOperationalLayerVisibility, addOperationalLayer, operationalSourceDataCache } from "../lib/operational-layers";
import type { MapScope } from "./useMapScope";

export function useOperationalLayersSync(context: MapScope) {
  const { mapRef, isMapReady, refreshZoneSummary } = context;
  const layers = useAppStore((state) => state.layers);
  const clusterLevel = useAppStore((state) => state.clusterLevel);
  const administrativeUnits = useAppStore((state) => state.administrativeUnits);
  const selectedAdministrativeIds = useAppStore((state) => state.selectedAdministrativeIds);
  const defaultViewportEnabled = useAppStore((state) => state.defaultViewportEnabled);
  const defaultAdministrativeIds = useAppStore((state) => state.defaultAdministrativeIds);
  const activePanel = useAppStore((state) => state.activePanel);
  useEffect(() => {
    const map = mapRef.current;
    // Sự kiện `load` đã đảm bảo style có thể thêm source/layer. Không dùng
    // isStyleLoaded() ở đây vì tile raster nền còn tải có thể làm nó tạm false,
    // khiến effect bỏ lỡ vĩnh viễn dữ liệu vừa nạp cho tới khi người dùng click.
    if (!isMapReady || !map) return;
    const contextualAdministrativeIds = activePanel === "conference" ? [] : [...new Set([
      ...(activePanel === "zones" ? selectedAdministrativeIds : []),
      ...(defaultViewportEnabled ? defaultAdministrativeIds : []),
    ])];
    const renderedLayers = buildContextualOperationalLayers(layers, administrativeUnits, contextualAdministrativeIds);
    const sourceCache = operationalSourceDataCache.get(map) ?? new Map<string, unknown>();
    operationalSourceDataCache.set(map, sourceCache);
    for (const layer of renderedLayers) {
      const source = map.getSource(layer.id) as GeoJSONSource | undefined;
      if (source && sourceCache.get(layer.id) !== layer.data) {
        if (layer.id === HNTH_LAYER_ID) {
          syncHnthSourceData(map, source, layer.data);
        } else {
          source.setData(layer.data);
        }
        sourceCache.set(layer.id, layer.data);
      }
      else if ((layer.visible || layer.id === HNTH_LAYER_ID) && layer.data.features.length) {
        addOperationalLayer(map, layer, useAppStore.getState().clusterLevel);
        sourceCache.set(layer.id, layer.data);
        if (layer.id === HNTH_LAYER_ID) rememberHnthFeatureProperties(map, layer.data);
      }
      // HNTH có hai switch hiển thị riêng cho sơ đồ kết nối và màu nền địa
      // giới. Không để cơ chế bật/tắt lớp dữ liệu chung ghi đè hai switch đó.
      if (layer.id !== HNTH_LAYER_ID) {
        // Trong HNTH, UBND được thay bằng điểm nhánh và màu trạng thái kết nối.
        // Chỉ ẩn hiển thị tạm thời, không thay đổi cấu hình bật/tắt đã lưu.
        const visibility = layer.id === "government-ubnd" && activePanel === "conference"
          ? "none"
          : layer.visible ? "visible" : "none";
        setOperationalLayerVisibility(map, layer.id, visibility);
      } else {
        // Camera dùng bản đồ TP riêng; không để lớp giám sát HNTH lọt sang màn hình Camera.
        setOperationalLayerVisibility(map, layer.id, activePanel === "conference" ? "visible" : "none");
      }
    }
    // Dữ liệu nghiệp vụ phải nằm trên lớp làm mờ và lớp nền địa giới.
    raiseOperationalLayers(map, renderedLayers);
    refreshZoneSummary();
  }, [layers, administrativeUnits, selectedAdministrativeIds, defaultViewportEnabled, defaultAdministrativeIds, activePanel, isMapReady]);

  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map) return;
    const clusterRadius = clusterRadiusForLevel(clusterLevel);
    for (const layer of layers) {
      if (layer.geometryMode === "line") continue;
      const source = map.getSource(layer.id) as GeoJSONSource | undefined;
      source?.setClusterOptions({ cluster: true, clusterMaxZoom: 13, clusterRadius });
    }
  }, [clusterLevel, isMapReady]);
}
