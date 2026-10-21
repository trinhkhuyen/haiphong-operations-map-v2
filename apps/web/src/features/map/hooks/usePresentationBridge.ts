// Chụp nền bản đồ cho báo cáo và hình học đã chiếu cho cửa sổ trình chiếu.
import { useEffect } from "react";
import { useAppStore } from "../../../core/store";
import { HNTH_LAYER_ID } from "../../layers/hnth-data-provider";
import { onAppEvent } from "../../../core/events";
import type { MapScope } from "./useMapScope";

export function usePresentationBridge(context: MapScope) {
  const { mapRef, isMapReady } = context;
  useEffect(() => {
    return onAppEvent("map:capture-background", (detail) => {
      const resolve = detail?.resolve;
      const map = mapRef.current;
      if (!resolve || !map || !isMapReady) { resolve?.(null); return; }
      const canvas = map.getCanvas();
      const hiddenLayers = detail.staticOnly
        ? [
          `${HNTH_LAYER_ID}-line-glow`, `${HNTH_LAYER_ID}-line`, `${HNTH_LAYER_ID}-branch-point`,
          `${HNTH_LAYER_ID}-area`,
          `${HNTH_LAYER_ID}-area-unknown`, `${HNTH_LAYER_ID}-area-unconnected`,
          `${HNTH_LAYER_ID}-area-connected`, `${HNTH_LAYER_ID}-area-lost`,
        ].filter((id) => map.getLayer(id) && map.getLayoutProperty(id, "visibility") !== "none")
        : [];
      for (const id of hiddenLayers) map.setLayoutProperty(id, "visibility", "none");
      const handleRender = () => {
        map.off("render", handleRender);
        try {
          resolve(canvas.toDataURL("image/jpeg", 0.9));
        } catch {
          resolve(null);
        } finally {
          for (const id of hiddenLayers) map.setLayoutProperty(id, "visibility", "visible");
        }
      };
      map.once("render", handleRender);
      map.triggerRepaint();
    });
  }, [isMapReady]);

  useEffect(() => {
    return onAppEvent("map:presentation-geometry", (detail) => {
      const resolve = detail?.resolve;
      const map = mapRef.current;
      if (!resolve || !map || !isMapReady) { resolve?.(null); return; }
      const projectCoordinate = (coordinates: [number, number]) => {
        const projected = map.project(coordinates);
        return [Number(projected.x.toFixed(2)), Number(projected.y.toFixed(2))] as [number, number];
      };
      const projectGeometry = (geometry: GeoJSON.Geometry): unknown => {
        if (geometry.type === "Point") return projectCoordinate(geometry.coordinates as [number, number]);
        if (geometry.type === "LineString" || geometry.type === "MultiPoint") return geometry.coordinates.map((item) => projectCoordinate(item as [number, number]));
        if (geometry.type === "Polygon" || geometry.type === "MultiLineString") return geometry.coordinates.map((line) => line.map((item) => projectCoordinate(item as [number, number])));
        if (geometry.type === "MultiPolygon") return geometry.coordinates.map((polygon) => polygon.map((line) => line.map((item) => projectCoordinate(item as [number, number]))));
        if (geometry.type === "GeometryCollection") return geometry.geometries.map(projectGeometry);
        return null;
      };
      const state = useAppStore.getState();
      const hnthLayer = state.layers.find((item) => item.id === HNTH_LAYER_ID);
      const features = hnthLayer?.data.features ?? [];
      const hub = features.find((item) => item.geometry.type === "Point" && item.properties?.role === "hub");
      const branches = features
        .filter((item) => item.geometry.type === "Point" && item.properties?.role === "branch")
        .map((item) => ({
          pointId: String(item.properties?.pointId ?? item.id ?? ""),
          wardCode: String(item.properties?.wardCode ?? ""),
          coordinates: projectCoordinate((item.geometry as GeoJSON.Point).coordinates as [number, number]),
        }));
      const lines = features
        .filter((item) => item.geometry.type === "LineString")
        .map((item) => ({
          pointId: String(item.properties?.pointId ?? item.id ?? ""),
          geometry: projectGeometry(item.geometry),
        }));
      const areas = state.administrativeUnits.map((unit) => ({
        wardCode: String(unit.wardCode),
        geometry: projectGeometry(unit.geometry),
      }));
      const canvas = map.getCanvas();
      resolve({
        width: canvas.clientWidth || canvas.width,
        height: canvas.clientHeight || canvas.height,
        hub: hub?.geometry.type === "Point" ? projectCoordinate(hub.geometry.coordinates as [number, number]) : null,
        branches,
        lines,
        areas,
        lineVisible: state.hnthLineVisible,
        areaVisible: state.hnthAreaVisible,
        lineStyles: state.hnthLineStyles,
        areaStyles: state.hnthAreaStyles,
      });
    });
  }, [isMapReady]);
}
