// Đồng bộ chế độ vẽ, nhãn/biểu tượng, hình đã lưu, màu/bán kính vào Terra Draw.
import { useEffect } from "react";
import { bbox, circle } from "@turf/turf";
import { useAppStore } from "../../../core/store";
import { syncTextMarkers, syncIconMarkers } from "../lib/annotations";
import { syncRadiusMarkers, syncDrawEditMarkers, cleanDrawFeatureForStorage, describeDrawFeature } from "../lib/drawing";
import type { MapScope } from "./useMapScope";

export function useDrawingSync(context: MapScope) {
  const { mapRef, drawRef, radiusMarkersRef, drawEditMarkersRef, textMarkersRef, iconMarkersRef, managedSavedFeatureIdsRef, isSyncingSavedFeaturesRef, isDrawReady, refreshZoneSummary } = context;
  const drawMode = useAppStore((state) => state.drawMode);
  const drawFillColor = useAppStore((state) => state.drawFillColor);
  const drawOutlineColor = useAppStore((state) => state.drawOutlineColor);
  const drawFillOpacity = useAppStore((state) => state.drawFillOpacity);
  const selectedDrawFeatureId = useAppStore((state) => state.selectedDrawFeatureId);
  const drawRadiusUpdate = useAppStore((state) => state.drawRadiusUpdate);
  const deleteDrawRequest = useAppStore((state) => state.deleteDrawRequest);
  const textAnnotations = useAppStore((state) => state.textAnnotations);
  const iconAnnotations = useAppStore((state) => state.iconAnnotations);
  const selectedAnnotation = useAppStore((state) => state.selectedAnnotation);
  const savedDrawFeatures = useAppStore((state) => state.savedDrawFeatures);
  const saveSelectedObjectRequest = useAppStore((state) => state.saveSelectedObjectRequest);
  const focusSavedObjectRequest = useAppStore((state) => state.focusSavedObjectRequest);
  useEffect(() => {
    if (!isDrawReady || !drawRef.current) return;
    drawRef.current.setMode(drawMode === "text" || drawMode === "icon" ? "static" : drawMode ?? "static");
    if (mapRef.current) mapRef.current.getCanvas().style.cursor = drawMode === "text" || drawMode === "icon" ? "crosshair" : "";
    if (mapRef.current) {
      syncTextMarkers(mapRef.current, textAnnotations, textMarkersRef.current);
      syncIconMarkers(mapRef.current, iconAnnotations, iconMarkersRef.current);
    }
  }, [drawMode, isDrawReady]);

  useEffect(() => {
    if (mapRef.current) syncTextMarkers(mapRef.current, textAnnotations, textMarkersRef.current);
  }, [textAnnotations, selectedAnnotation]);

  useEffect(() => {
    if (mapRef.current) syncIconMarkers(mapRef.current, iconAnnotations, iconMarkersRef.current);
  }, [iconAnnotations, selectedAnnotation]);

  useEffect(() => {
    if (!drawRef.current || selectedDrawFeatureId === null) return;
    const savedId = `geometry:${String(selectedDrawFeatureId)}`;
    const state = useAppStore.getState();
    if (state.savedDrawFeatures.some((item) => item.id === savedId)) state.deleteSavedObject("geometry", savedId);
    drawRef.current.removeFeatures([selectedDrawFeatureId]);
    useAppStore.getState().setSelectedDrawFeatureId(null);
    useAppStore.getState().setSelectedDrawFeatureInfo(null);
    useAppStore.getState().setZoneMode("draw");
    if (mapRef.current) {
      syncRadiusMarkers(mapRef.current, drawRef.current, radiusMarkersRef.current);
      syncDrawEditMarkers(mapRef.current, drawRef.current, null, drawEditMarkersRef.current);
    }
    refreshZoneSummary();
  }, [deleteDrawRequest]);

  useEffect(() => {
    const draw = drawRef.current;
    if (!isDrawReady || !draw) return;
    const nextManagedIds = new Set(savedDrawFeatures.map((item) => item.featureId));
    isSyncingSavedFeaturesRef.current = true;
    try {
      for (const id of managedSavedFeatureIdsRef.current) {
        const remainsVisible = savedDrawFeatures.some((item) => item.featureId === id && item.visible);
        if (!remainsVisible && draw.hasFeature(id)) draw.removeFeatures([id]);
      }
      for (const item of savedDrawFeatures) {
        if (item.visible && !draw.hasFeature(item.featureId)) draw.addFeatures([cleanDrawFeatureForStorage(item.feature)]);
        if (!item.visible && draw.hasFeature(item.featureId)) draw.removeFeatures([item.featureId]);
      }
    } finally {
      isSyncingSavedFeaturesRef.current = false;
      managedSavedFeatureIdsRef.current = nextManagedIds;
    }
    if (mapRef.current) {
      syncRadiusMarkers(mapRef.current, draw, radiusMarkersRef.current);
      syncDrawEditMarkers(mapRef.current, draw, useAppStore.getState().selectedDrawFeatureId, drawEditMarkersRef.current);
    }
    refreshZoneSummary();
  }, [isDrawReady, savedDrawFeatures]);

  useEffect(() => {
    const draw = drawRef.current;
    if (!draw || !saveSelectedObjectRequest || selectedDrawFeatureId === null) return;
    const snapshot = draw.getSnapshotFeature(selectedDrawFeatureId);
    if (snapshot) useAppStore.getState().upsertSavedDrawFeature(cleanDrawFeatureForStorage(snapshot), saveSelectedObjectRequest.name);
  }, [saveSelectedObjectRequest, selectedDrawFeatureId]);

  useEffect(() => {
    const request = focusSavedObjectRequest;
    const map = mapRef.current;
    if (!request || !map) return;
    const state = useAppStore.getState();
    if (request.kind === "text") {
      const item = state.textAnnotations.find((annotation) => annotation.id === request.id);
      if (!item) return;
      map.easeTo({ center: item.coordinates, zoom: Math.max(map.getZoom(), 15), duration: 600 });
      state.selectAnnotation("text", item.id);
      return;
    }
    if (request.kind === "icon") {
      const item = state.iconAnnotations.find((annotation) => annotation.id === request.id);
      if (!item) return;
      map.easeTo({ center: item.coordinates, zoom: Math.max(map.getZoom(), 15), duration: 600 });
      state.selectAnnotation("icon", item.id);
      return;
    }
    const item = state.savedDrawFeatures.find((featureItem) => featureItem.id === request.id);
    const draw = drawRef.current;
    if (!item || !draw) return;
    if (!draw.hasFeature(item.featureId)) draw.addFeatures([cleanDrawFeatureForStorage(item.feature)]);
    const featureBounds = bbox(item.feature);
    map.fitBounds([[featureBounds[0], featureBounds[1]], [featureBounds[2], featureBounds[3]]], { padding: 90, maxZoom: 16, duration: 600 });
    draw.setMode("select");
    state.setDrawMode("select");
    draw.selectFeature(item.featureId);
  }, [focusSavedObjectRequest]);

  useEffect(() => {
    if (!drawRef.current || selectedDrawFeatureId === null) return;
    drawRef.current.updateFeatureProperties(selectedDrawFeatureId, { fillColor: drawFillColor, fillOpacity: drawFillOpacity, outlineColor: drawOutlineColor });
  }, [selectedDrawFeatureId, drawFillColor, drawOutlineColor, drawFillOpacity]);

  useEffect(() => {
    if (!drawRef.current || !drawRadiusUpdate) return;
    const info = describeDrawFeature(drawRef.current, drawRadiusUpdate.id);
    if (!info || info.kind !== "circle") return;
    const resizedCircle = circle(info.center, drawRadiusUpdate.meters, { steps: 96, units: "meters" });
    const geometry = {
      ...resizedCircle.geometry,
      coordinates: resizedCircle.geometry.coordinates.map((ring) =>
        ring.map(([longitude, latitude]) => [
          Number(longitude.toFixed(6)),
          Number(latitude.toFixed(6)),
        ]),
      ),
    };
    drawRef.current.updateFeatureGeometry(drawRadiusUpdate.id, geometry);
    useAppStore.getState().setSelectedDrawFeatureInfo(describeDrawFeature(drawRef.current, drawRadiusUpdate.id));
    if (mapRef.current) {
      syncRadiusMarkers(mapRef.current, drawRef.current, radiusMarkersRef.current);
      syncDrawEditMarkers(mapRef.current, drawRef.current, drawRadiusUpdate.id, drawEditMarkersRef.current);
    }
    refreshZoneSummary();
  }, [drawRadiusUpdate]);

  useEffect(() => {
    if (!mapRef.current || !drawRef.current) return;
    syncDrawEditMarkers(
      mapRef.current,
      drawRef.current,
      drawMode === "select" ? selectedDrawFeatureId : null,
      drawEditMarkersRef.current,
    );
  }, [selectedDrawFeatureId, drawMode, isDrawReady]);
}
