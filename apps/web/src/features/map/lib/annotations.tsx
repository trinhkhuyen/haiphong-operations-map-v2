// Marker nhãn chữ và biểu tượng trên bản đồ.
import { createRoot, type Root } from "react-dom/client";
import maplibregl, { type Map as MapLibreMap } from "maplibre-gl";
import { useAppStore } from "../../../core/store";
import { mapIconByKey } from "../../../core/map-icons";
import { restoreHaiphongOverviewIfZoomedOut } from "./viewport";

export interface IconMarkerHandle {
  marker: maplibregl.Marker;
  root: Root;
}

export function syncTextMarkers(
  map: MapLibreMap,
  annotations: ReturnType<typeof useAppStore.getState>["textAnnotations"],
  markers: Map<string, maplibregl.Marker>,
) {
  const visibleAnnotations = annotations.filter((annotation) => annotation.visible !== false);
  const activeIds = new Set(visibleAnnotations.map((annotation) => annotation.id));
  for (const annotation of visibleAnnotations) {
    let marker = markers.get(annotation.id);
    if (!marker) {
      const element = document.createElement("div");
      element.className = "map-text-annotation";
      element.addEventListener("click", (event) => {
        event.stopPropagation();
        restoreHaiphongOverviewIfZoomedOut(map, annotation.coordinates);
        if (useAppStore.getState().drawMode === "select") useAppStore.getState().selectAnnotation("text", annotation.id);
      });
      marker = new maplibregl.Marker({ element, anchor: "center", draggable: true })
        .setLngLat(annotation.coordinates)
        .addTo(map);
      marker.on("dragend", () => {
        const position = marker?.getLngLat();
        if (position) useAppStore.getState().moveAnnotation("text", annotation.id, [position.lng, position.lat]);
      });
      markers.set(annotation.id, marker);
    }
    const element = marker.getElement();
    element.textContent = annotation.text;
    element.style.color = annotation.color;
    element.classList.toggle("selected", useAppStore.getState().selectedAnnotation?.kind === "text" && useAppStore.getState().selectedAnnotation?.id === annotation.id);
    marker.setDraggable(useAppStore.getState().drawMode === "select");
    marker.setLngLat(annotation.coordinates);
  }
  for (const [id, marker] of markers) {
    if (activeIds.has(id)) continue;
    marker.remove();
    markers.delete(id);
  }
}

export function syncIconMarkers(
  map: MapLibreMap,
  annotations: ReturnType<typeof useAppStore.getState>["iconAnnotations"],
  markers: Map<string, IconMarkerHandle>,
) {
  const visibleAnnotations = annotations.filter((annotation) => annotation.visible !== false);
  const activeIds = new Set(visibleAnnotations.map((annotation) => annotation.id));
  for (const annotation of visibleAnnotations) {
    let handle = markers.get(annotation.id);
    if (!handle) {
      const element = document.createElement("div");
      element.className = "map-icon-annotation";
      element.addEventListener("click", (event) => {
        event.stopPropagation();
        restoreHaiphongOverviewIfZoomedOut(map, annotation.coordinates);
        if (useAppStore.getState().drawMode === "select") useAppStore.getState().selectAnnotation("icon", annotation.id);
      });
      const root = createRoot(element);
      const marker = new maplibregl.Marker({ element, anchor: "center", draggable: true })
        .setLngLat(annotation.coordinates)
        .addTo(map);
      marker.on("dragend", () => {
        const position = marker.getLngLat();
        useAppStore.getState().moveAnnotation("icon", annotation.id, [position.lng, position.lat]);
      });
      handle = { marker, root };
      markers.set(annotation.id, handle);
    }
    const Icon = mapIconByKey[annotation.icon].icon;
    handle.root.render(<Icon size={21} strokeWidth={2.2}/>);
    handle.marker.getElement().style.color = annotation.color;
    handle.marker.getElement().classList.toggle("selected", useAppStore.getState().selectedAnnotation?.kind === "icon" && useAppStore.getState().selectedAnnotation?.id === annotation.id);
    handle.marker.setDraggable(useAppStore.getState().drawMode === "select");
    handle.marker.setLngLat(annotation.coordinates);
  }
  for (const [id, handle] of markers) {
    if (activeIds.has(id)) continue;
    handle.root.unmount();
    handle.marker.remove();
    markers.delete(id);
  }
}
