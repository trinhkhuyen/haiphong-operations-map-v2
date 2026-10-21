// Hiển thị lựa chọn địa giới: viền kiểm tra, vùng đã khoanh/focus, nền tối, màu khoanh.
import { useEffect } from "react";
import { Home } from "lucide-react";
import maplibregl, { type GeoJSONSource } from "maplibre-gl";
import { bbox, featureCollection } from "@turf/turf";
import { useAppStore } from "../../../core/store";
import { unitsToFeatureCollection } from "../../administrative/data-provider";
import { DEFAULT_VIEWPORT_SURROUNDING_FILL_COLOR, DEFAULT_VIEWPORT_SURROUNDING_LINE_COLOR, showAdministrativeConnection } from "../lib/administrative";
import type { MapScope } from "./useMapScope";
import type { MapInspection } from "./useMapInspection";

export function useAdministrativeSelection(context: MapScope & MapInspection) {
  const { mapRef, isHomeTransitionActiveRef, suppressNextAdministrativeSelectionFitRef, isMapReady, inspectedAdministrativeIds, fixedMapInfo, setFixedMapInfo, refreshZoneSummary, clearMapInspection } = context;
  const layers = useAppStore((state) => state.layers);
  const administrativeUnits = useAppStore((state) => state.administrativeUnits);
  const selectedAdministrativeIds = useAppStore((state) => state.selectedAdministrativeIds);
  const focusedAdministrativeId = useAppStore((state) => state.focusedAdministrativeId);
  const dimOutsideHaiphong = useAppStore((state) => state.dimOutsideHaiphong);
  const defaultViewportEnabled = useAppStore((state) => state.defaultViewportEnabled);
  const defaultAdministrativeIds = useAppStore((state) => state.defaultAdministrativeIds);
  const administrativeFillColor = useAppStore((state) => state.administrativeFillColor);
  const administrativeOutlineColor = useAppStore((state) => state.administrativeOutlineColor);
  const administrativeFillOpacity = useAppStore((state) => state.administrativeFillOpacity);
  const activePanel = useAppStore((state) => state.activePanel);
  useEffect(() => {
    // Popup HNTH và trạng thái giám sát là lớp vận hành nền, nên giữ nguyên
    // khi người dùng chuyển sang menu khác. Các popup ngữ cảnh khác vẫn đóng.
    if (fixedMapInfo?.kind === "hnth") return;
    clearMapInspection();
    const map = mapRef.current;
    if (map?.getLayer("administrative-hnth-hover-line")) {
      map.setFilter("administrative-hnth-hover-line", ["==", ["get", "id"], -1]);
    }
  }, [activePanel, clearMapInspection, fixedMapInfo?.kind]);

  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map?.getLayer("administrative-inspected-line")) return;
    const ids = activePanel === "layers" || activePanel === "conference" ? inspectedAdministrativeIds : [];
    map.setFilter("administrative-inspected-line", ids.length === 1 ? ["==", ["get", "id"], ids[0]] : ids.length > 1 ? ["in", ["get", "id"], ["literal", ids]] : ["==", ["get", "id"], -1]);
    if (ids.length) map.moveLayer("administrative-inspected-line");
  }, [activePanel, inspectedAdministrativeIds, administrativeUnits, isMapReady]);

  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map?.getLayer("haiphong-outside-mask")) return;
    map.setLayoutProperty("haiphong-outside-mask", "visibility", dimOutsideHaiphong ? "visible" : "none");
  }, [dimOutsideHaiphong, isMapReady]);

  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map?.getLayer("administrative-fill")) return;
    // Khi click lần 2, địa giới focus chỉ dùng lớp trắng trong suốt giống vùng tự vẽ;
    // loại nó khỏi lớp nền "đã chọn" để hai lớp màu không chồng làm nền bị đậm.
    const visibleSelectedIds = activePanel === "zones"
      ? selectedAdministrativeIds.filter((id) => id !== focusedAdministrativeId)
      : [];
    const filter: maplibregl.FilterSpecification = visibleSelectedIds.length > 0
      ? ["in", ["get", "id"], ["literal", visibleSelectedIds]]
      : ["==", ["get", "id"], -1];
    if (map.getLayer("administrative-selected")) map.setFilter("administrative-selected", filter);
    if (map.getLayer("administrative-selected-line")) map.setFilter("administrative-selected-line", filter);
    refreshZoneSummary();
    // Trong chuyển cảnh Home/khởi động, giữ nguyên khung toàn Hải Phòng đủ thời
    // gian cấu hình; không để danh sách vùng đã chọn tự zoom sớm vào địa giới.
    if (isHomeTransitionActiveRef.current) return;
    if (activePanel !== "zones" || selectedAdministrativeIds.length === 0) return;
    if (suppressNextAdministrativeSelectionFitRef.current) {
      suppressNextAdministrativeSelectionFitRef.current = false;
      return;
    }
    const selected = administrativeUnits.filter((unit) => selectedAdministrativeIds.includes(unit.id));
    if (selected.length === 0) return;
    const bounds = bbox(unitsToFeatureCollection(selected));
    map.fitBounds([[bounds[0], bounds[1]], [bounds[2], bounds[3]]], { padding: 80, maxZoom: 12.5, duration: 700 });
  }, [selectedAdministrativeIds, focusedAdministrativeId, administrativeUnits, activePanel, isMapReady]);

  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map?.getLayer("administrative-fill")) return;
    const filter: maplibregl.FilterSpecification = ["==", ["get", "id"], focusedAdministrativeId ?? -1];
    if (map.getLayer("administrative-focused")) map.setFilter("administrative-focused", filter);
    if (map.getLayer("administrative-focused-line")) map.setFilter("administrative-focused-line", filter);

    const connectionSource = map.getSource("administrative-focus-connection") as GeoJSONSource | undefined;
    connectionSource?.setData(featureCollection([]));
    if (focusedAdministrativeId === null) {
      setFixedMapInfo((current) => current?.kind === "administrative" ? null : current);
      return;
    }

    const unit = administrativeUnits.find((candidate) => candidate.id === focusedAdministrativeId);
    if (!unit) return;
    setFixedMapInfo({ kind: "administrative", unitId: unit.id, includeConnectionPoint: true });
    showAdministrativeConnection(map, unit);
  }, [focusedAdministrativeId, administrativeUnits, isMapReady]);

  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map?.getLayer("administrative-fill") || !map.getLayer("administrative-line")) return;
    const showZoneSelection = activePanel === "zones";
    const selectedCondition: maplibregl.ExpressionSpecification = showZoneSelection && selectedAdministrativeIds.length > 0
      ? ["in", ["get", "id"], ["literal", selectedAdministrativeIds]]
      : ["==", ["get", "id"], -1];
    const focusedCondition: maplibregl.ExpressionSpecification = ["==", ["get", "id"], showZoneSelection ? focusedAdministrativeId ?? -1 : -1];
    // HNTH tự tô nền theo trạng thái kết nối nên không chồng màu khung mặc định.
    const hasDefaultAdministrativeUnit = activePanel !== "conference" && defaultViewportEnabled && defaultAdministrativeIds.length > 0;
    const defaultCondition: maplibregl.ExpressionSpecification = hasDefaultAdministrativeUnit
      ? ["in", ["get", "id"], ["literal", defaultAdministrativeIds]]
      : ["==", ["get", "id"], -1];
    map.setPaintProperty("administrative-fill", "fill-color", [
      "case",
      focusedCondition, "#ffffff",
      defaultCondition, "#fde68a",
      selectedCondition, administrativeFillColor,
      hasDefaultAdministrativeUnit, DEFAULT_VIEWPORT_SURROUNDING_FILL_COLOR,
      "#38bdf8",
    ]);
    map.setPaintProperty("administrative-fill", "fill-opacity", [
      "case",
      focusedCondition, 0,
      // Địa giới mặc định không bị phủ màu để phần bản đồ bên trong hiển thị 100%.
      defaultCondition, 0,
      // Vùng đã chọn được tô bởi lớp administrative-selected ở phía trên để
      // độ trong suốt người dùng chọn không bị cộng dồn qua hai lớp nền.
      selectedCondition, 0,
      // 0.15 = độ đục 15% (trong suốt 85%) cho màu phủ các địa giới còn lại.
      hasDefaultAdministrativeUnit, 0.15,
      0.045,
    ]);
    map.setPaintProperty("administrative-line", "line-color", [
      "case",
      focusedCondition, "#ffffff",
      defaultCondition, "#fbbf24",
      selectedCondition, administrativeOutlineColor,
      hasDefaultAdministrativeUnit, DEFAULT_VIEWPORT_SURROUNDING_LINE_COLOR,
      "#73a8bd",
    ]);
    map.setPaintProperty("administrative-line", "line-width", [
      "case",
      focusedCondition, 3.4,
      defaultCondition, 2.8,
      selectedCondition, 2.8,
      0.8,
    ]);
    map.setPaintProperty("administrative-line", "line-opacity", [
      "case",
      focusedCondition, 1,
      defaultCondition, 1,
      selectedCondition, 1,
      0.42,
    ]);
  }, [selectedAdministrativeIds, focusedAdministrativeId, defaultAdministrativeIds, defaultViewportEnabled, administrativeFillColor, administrativeOutlineColor, administrativeFillOpacity, administrativeUnits, activePanel, isMapReady]);

  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map?.getLayer("administrative-selected")) return;
    map.setPaintProperty("administrative-selected", "fill-color", administrativeFillColor);
    map.setPaintProperty("administrative-selected", "fill-opacity", administrativeFillOpacity);
    map.setPaintProperty("administrative-selected-line", "line-color", administrativeOutlineColor);
  }, [administrativeFillColor, administrativeOutlineColor, administrativeFillOpacity, administrativeUnits, isMapReady]);
}
