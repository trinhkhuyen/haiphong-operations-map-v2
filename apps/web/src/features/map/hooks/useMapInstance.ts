// Dựng MapLibre + Terra Draw một lần, gắn click/phím toàn cục; đổi nền bản đồ.
import { useEffect } from "react";
import maplibregl from "maplibre-gl";
import { circle, feature } from "@turf/turf";
import { TerraDraw, TerraDrawCircleMode, TerraDrawLineStringMode, TerraDrawPolygonMode, TerraDrawRectangleMode, TerraDrawSelectMode } from "terra-draw";
import { TerraDrawMapLibreGLAdapter } from "terra-draw-maplibre-gl-adapter";
import { useAppStore } from "../../../core/store";
import { SELECTED_ZONE_FILL_OPACITY, OFFICIAL_ADMINISTRATIVE_LABEL_LAYER_ID, PRIORITY_ADMINISTRATIVE_LABEL_LAYER_ID, officialAdministrativeLabelsVisible } from "../lib/administrative";
import { syncTextMarkers, syncIconMarkers } from "../lib/annotations";
import { createBaseStyle, baseMapOptions } from "../lib/base-style";
import { drawEditDeselectGuards, featureColor, featureNumber, syncRadiusMarkers, syncDrawEditMarkers, cleanDrawFeatureForStorage, describeDrawFeature } from "../lib/drawing";
import { addOperationalLayer } from "../lib/operational-layers";
import { REGIONAL_LOADING_CENTER, REGIONAL_MIN_ZOOM, REGIONAL_OPERATIONAL_BOUNDS } from "../lib/viewport";
import type { MapScope } from "./useMapScope";
import type { MapInspection } from "./useMapInspection";

export function useMapInstance(context: MapScope & MapInspection) {
  const { containerRef, mapRef, drawRef, radiusMarkersRef, drawEditMarkersRef, textMarkersRef, iconMarkersRef, drawSearchMarkerRef, vietnamProvinceLabelMarkersRef, homeTransitionTimeoutRef, isHomeTransitionActiveRef, isSyncingSavedFeaturesRef, isMapReady, setIsMapReady, setIsInitialRegionalMapReady, setIsDrawReady, refreshZoneSummary, clearMapInspection } = context;
  const layers = useAppStore((state) => state.layers);
  const baseMapMode = useAppStore((state) => state.baseMapMode);
  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;
    // Đọc trực tiếp cấu hình persisted trước khi dựng MapLibre để không có
    // một frame OSM mặc định xen giữa lúc khởi động chế độ vệ tinh/địa hình.
    const initialBaseMapMode = useAppStore.getState().baseMapMode;
    const map = new maplibregl.Map({
      container: containerRef.current,
      style: createBaseStyle(initialBaseMapMode),
      center: REGIONAL_LOADING_CENTER,
      zoom: REGIONAL_MIN_ZOOM,
      minZoom: REGIONAL_MIN_ZOOM,
      maxBounds: REGIONAL_OPERATIONAL_BOUNDS,
      renderWorldCopies: false,
      pitch: 0,
      bearing: 0,
    });
    mapRef.current = map;
    // Luôn hiển thị la bàn; hướng Bắc và góc nhìn phẳng là trạng thái mặc định sau reload.
    map.addControl(new maplibregl.NavigationControl({ showCompass: true, showZoom: true, visualizePitch: true }), "bottom-right");
    map.addControl(new maplibregl.FullscreenControl(), "bottom-right");
    map.on("load", () => {
      setIsMapReady(true);
      // Chỉ rời khung vùng Bắc Bộ - Bắc Trung Bộ sau khi các tile nền đang nhìn
      // thấy đã tải xong. Nhờ vậy chính bản đồ thật là nền chờ của ứng dụng.
      map.once("idle", () => {
        if (mapRef.current === map) setIsInitialRegionalMapReady(true);
      });
      map.triggerRepaint();
      const state = useAppStore.getState();
      for (const layer of state.layers) {
        if (layer.visible && layer.data.features.length) addOperationalLayer(map, layer, state.clusterLevel);
      }
      syncTextMarkers(map, useAppStore.getState().textAnnotations, textMarkersRef.current);
      syncIconMarkers(map, useAppStore.getState().iconAnnotations, iconMarkersRef.current);
      map.on("click", (event) => {
        const state = useAppStore.getState();
        if (state.activePanel === "layers" || state.activePanel === "conference") {
          const clickedInsideHaiphong = map.getLayer("administrative-fill")
            ? map.queryRenderedFeatures(event.point, { layers: ["administrative-fill"] }).length > 0
            : false;
          if (!clickedInsideHaiphong) {
            clearMapInspection();
          }
        }
        if (state.activePanel === "zones" && state.zoneMode === "administrative" && state.focusedAdministrativeId !== null) {
          const clickedInsideHaiphong = map.getLayer("administrative-fill")
            ? map.queryRenderedFeatures(event.point, { layers: ["administrative-fill"] }).length > 0
            : false;
          // Click ra ngoài 114 địa giới chỉ thoát focus, không bỏ vùng đã khoanh.
          if (!clickedInsideHaiphong) state.clearAdministrativeFocus();
        }
        const coordinates: [number, number] = [Number(event.lngLat.lng.toFixed(6)), Number(event.lngLat.lat.toFixed(6))];
        if (state.drawMode === "text" && state.textDraft.trim()) state.addTextAnnotation(coordinates);
        if (state.drawMode === "icon") state.addIconAnnotation(coordinates);
      });
      const draw = new TerraDraw({
        adapter: new TerraDrawMapLibreGLAdapter({ map }),
        modes: [
          new TerraDrawSelectMode({
            flags: {
              polygon: { feature: { draggable: true, coordinates: { midpoints: true, draggable: true, deletable: true } } },
              rectangle: { feature: { draggable: true, coordinates: { draggable: true, deletable: true } } },
              circle: { feature: { draggable: true, scaleable: true } },
              linestring: { feature: { draggable: true, coordinates: { midpoints: true, draggable: true, deletable: true } } },
              multilinestring: { feature: { draggable: true, coordinates: { midpoints: true, draggable: true, deletable: true } } },
            },
            keyEvents: { deselect: "Escape", delete: "Delete", rotate: null, scale: null },
            styles: {
              selectedPolygonColor: "#ffffff",
              selectedPolygonFillOpacity: SELECTED_ZONE_FILL_OPACITY,
              selectedPolygonOutlineColor: "#ffffff",
              selectedPolygonOutlineWidth: 3,
              selectedLineStringColor: "#ffffff",
              selectedLineStringWidth: 4,
              selectedLineStringDash: [8, 6],
              selectionPointColor: "#f8fafc",
              selectionPointOutlineColor: "#0f172a",
              selectionPointWidth: 5,
              selectionPointOutlineWidth: 2,
              midPointColor: "#f8fafc",
              midPointOutlineColor: "#0f172a",
            },
          }),
          new TerraDrawPolygonMode({ styles: { fillColor: featureColor("fillColor", "#fde68a"), fillOpacity: featureNumber("fillOpacity", 0.42), outlineColor: featureColor("outlineColor", "#d97706"), outlineWidth: 2.5 } }),
          new TerraDrawRectangleMode({ styles: { fillColor: featureColor("fillColor", "#fde68a"), fillOpacity: featureNumber("fillOpacity", 0.42), outlineColor: featureColor("outlineColor", "#d97706"), outlineWidth: 2.5 } }),
          new TerraDrawCircleMode({ showCoordinatePoints: false, styles: { fillColor: featureColor("fillColor", "#fde68a"), fillOpacity: featureNumber("fillOpacity", 0.42), outlineColor: featureColor("outlineColor", "#d97706"), outlineWidth: 2.5 } }),
          new TerraDrawLineStringMode({ finishOnNthCoordinate: 2, styles: { lineStringColor: featureColor("outlineColor", "#d97706"), lineStringWidth: 4, lineStringDash: [8, 6] } }),
          new TerraDrawLineStringMode({ modeName: "multilinestring", styles: { lineStringColor: featureColor("outlineColor", "#d97706"), lineStringWidth: 4, lineStringDash: [8, 6] } }),
        ],
      });
      draw.start();
      // Terra Draw exposes polygon outlines as a MapLibre line layer. Applying
      // the dash pattern at that layer keeps both normal and selected zones
      // consistently dashed without replacing the user's own outline color.
      if (map.getLayer("td-polygon-outline")) {
        map.setPaintProperty("td-polygon-outline", "line-dasharray", [3, 2]);
      }
      drawRef.current = draw;
      setIsDrawReady(true);
      draw.on("finish", (id) => {
        const state = useAppStore.getState();
        draw.updateFeatureProperties(id, { fillColor: state.drawFillColor, fillOpacity: state.drawFillOpacity, outlineColor: state.drawOutlineColor });
        // Terra Draw emits its temporary drawing deselection after `finish`.
        // Re-select on the next frame so that event cannot clear the durable
        // application selection or return the panel to the drawing tab.
        draw.setMode("select");
        state.setDrawMode("select");
        window.requestAnimationFrame(() => {
          draw.selectFeature(id);
          const currentState = useAppStore.getState();
          currentState.setSelectedDrawFeatureId(id);
          currentState.setSelectedDrawFeatureInfo(describeDrawFeature(draw, id));
          currentState.setZoneMode("info");
          syncRadiusMarkers(map, draw, radiusMarkersRef.current);
          syncDrawEditMarkers(map, draw, id, drawEditMarkersRef.current);
          refreshZoneSummary();
        });
      });
      draw.on("select", (id) => {
        const state = useAppStore.getState();
        state.clearSelectedAnnotation();
        const selectedFeature = draw.getSnapshotFeature(id);
        state.setSelectedDrawFeatureId(id);
        state.setSelectedDrawFeatureInfo(describeDrawFeature(draw, id));
        const fillColor = selectedFeature?.properties.fillColor;
        const fillOpacity = selectedFeature?.properties.fillOpacity;
        const outlineColor = selectedFeature?.properties.outlineColor;
        if (typeof fillColor === "string") state.setDrawFillColor(fillColor);
        if (typeof fillOpacity === "number") state.setDrawFillOpacity(fillOpacity);
        if (typeof outlineColor === "string") state.setDrawOutlineColor(outlineColor);
        state.setZoneMode("info");
        syncDrawEditMarkers(map, draw, id, drawEditMarkersRef.current);
      });
      draw.on("deselect", (id) => {
        if (drawEditDeselectGuards.has(String(id))) return;
        const isDraggingEditHandle = Array.from(drawEditMarkersRef.current.values()).some(
          ({ marker }) => marker.getElement().dataset.drawEditDragging === "true",
        );
        // Geometry updates performed by a custom marker can make Terra Draw
        // emit a transient deselect. The drag itself is still the active edit,
        // so keep both the information panel and edit handles mounted.
        if (isDraggingEditHandle) return;
        const state = useAppStore.getState();
        if (state.selectedDrawFeatureId !== id) return;
        state.setSelectedDrawFeatureId(null);
        state.setSelectedDrawFeatureInfo(null);
        if (state.zoneMode === "info") state.setZoneMode("draw");
        syncDrawEditMarkers(map, draw, null, drawEditMarkersRef.current);
      });
      draw.on("change", (ids) => {
        const state = useAppStore.getState();
        if (state.selectedDrawFeatureId !== null && ids.includes(state.selectedDrawFeatureId)) {
          state.setSelectedDrawFeatureInfo(describeDrawFeature(draw, state.selectedDrawFeatureId));
        }
        syncRadiusMarkers(map, draw, radiusMarkersRef.current);
        // Do not reposition a custom control marker while MapLibre is actively
        // dragging it. Resetting its coordinate inside `drag` cancels the drag
        // gesture before the geometry can follow the pointer.
        if (drawEditDeselectGuards.size === 0) {
          syncDrawEditMarkers(map, draw, state.selectedDrawFeatureId, drawEditMarkersRef.current);
        }
        refreshZoneSummary();
        if (!isSyncingSavedFeaturesRef.current) {
          for (const id of ids) {
            const snapshot = draw.getSnapshotFeature(id);
            if (snapshot) state.syncSavedDrawFeature(cleanDrawFeatureForStorage(snapshot));
          }
        }
      });
    });
    const handleKeyDown = (event: KeyboardEvent) => {
      const state = useAppStore.getState();
      if (event.key === "Escape" && (state.activePanel === "layers" || state.activePanel === "conference")) {
        event.preventDefault();
        clearMapInspection();
        return;
      }
      if (event.key === "Escape" && state.activePanel === "zones" && state.zoneMode === "administrative" && state.focusedAdministrativeId !== null) {
        event.preventDefault();
        // Escape đưa địa giới về trạng thái khoanh vùng lần 1, không xóa lựa chọn.
        state.clearAdministrativeFocus();
        return;
      }
      if (event.key !== "Delete" && event.key !== "Backspace") return;
      const target = event.target as HTMLElement | null;
      if (target?.matches("input, textarea, [contenteditable='true']")) return;
      if (state.selectedAnnotation && state.drawMode === "select") {
        event.preventDefault();
        state.deleteSelectedAnnotation();
        return;
      }
      if (state.selectedDrawFeatureId !== null && (state.zoneMode === "draw" || state.zoneMode === "info")) {
        event.preventDefault();
        const savedId = `geometry:${String(state.selectedDrawFeatureId)}`;
        if (state.savedDrawFeatures.some((item) => item.id === savedId)) state.deleteSavedObject("geometry", savedId);
        drawRef.current?.removeFeatures([state.selectedDrawFeatureId]);
        if (mapRef.current && drawRef.current) syncRadiusMarkers(mapRef.current, drawRef.current, radiusMarkersRef.current);
        state.setSelectedDrawFeatureId(null);
        state.setSelectedDrawFeatureInfo(null);
        state.setZoneMode("draw");
        refreshZoneSummary();
        return;
      }
      if (state.activePanel === "zones" && state.zoneMode === "administrative" && state.focusedAdministrativeId !== null) {
        event.preventDefault();
        state.removeAdministrativeUnit(state.focusedAdministrativeId);
        return;
      }
    };
    // Bắt phím ở capture phase để thư viện vẽ không chặn Escape/Delete trước ứng dụng.
    window.addEventListener("keydown", handleKeyDown, true);
    return () => {
      window.removeEventListener("keydown", handleKeyDown, true);
      if (homeTransitionTimeoutRef.current !== null) {
        window.clearTimeout(homeTransitionTimeoutRef.current);
        homeTransitionTimeoutRef.current = null;
      }
      isHomeTransitionActiveRef.current = false;
      for (const marker of radiusMarkersRef.current.values()) marker.remove();
      radiusMarkersRef.current.clear();
      for (const handle of drawEditMarkersRef.current.values()) handle.marker.remove();
      drawEditMarkersRef.current.clear();
      for (const marker of textMarkersRef.current.values()) marker.remove();
      textMarkersRef.current.clear();
      for (const handle of iconMarkersRef.current.values()) { handle.root.unmount(); handle.marker.remove(); }
      iconMarkersRef.current.clear();
      for (const marker of vietnamProvinceLabelMarkersRef.current) marker.remove();
      vietnamProvinceLabelMarkersRef.current = [];
      drawSearchMarkerRef.current?.remove();
      drawSearchMarkerRef.current = null;
      drawRef.current?.stop();
      map.remove();
      mapRef.current = null;
    };
  }, []);

  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map) return;
    for (const option of baseMapOptions) {
      const layerId = `base-map-${option.id}`;
      if (map.getLayer(layerId)) map.setLayoutProperty(layerId, "visibility", option.id === baseMapMode ? "visible" : "none");
    }
    const administrativeLabelVisibility = officialAdministrativeLabelsVisible(baseMapMode) ? "visible" : "none";
    for (const layerId of [OFFICIAL_ADMINISTRATIVE_LABEL_LAYER_ID, PRIORITY_ADMINISTRATIVE_LABEL_LAYER_ID]) {
      if (map.getLayer(layerId)) map.setLayoutProperty(layerId, "visibility", administrativeLabelVisibility);
    }
  }, [baseMapMode, isMapReady]);
}
