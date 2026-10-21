// Ref và state dùng chung giữa các hook của MapCanvas (map, Terra Draw, marker,
// cờ sẵn sàng, thẻ thông tin...). Tạo một lần trong MapCanvas rồi truyền cho từng hook.
import { useRef, useState } from "react";
import maplibregl, { type Map as MapLibreMap } from "maplibre-gl";
import { TerraDraw } from "terra-draw";
import type { FixedMapInfo } from "../map-events";
import type { IconMarkerHandle } from "../lib/annotations";
import { type ZoneSummary, type DrawEditMarkerHandle, buildZoneSummary } from "../lib/drawing";

export function useMapScope() {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<MapLibreMap | null>(null);
  const drawRef = useRef<TerraDraw | null>(null);
  const radiusMarkersRef = useRef(new Map<string | number, maplibregl.Marker>());
  const drawEditMarkersRef = useRef(new Map<string, DrawEditMarkerHandle>());
  const textMarkersRef = useRef(new Map<string, maplibregl.Marker>());
  const iconMarkersRef = useRef(new Map<string, IconMarkerHandle>());
  const drawSearchMarkerRef = useRef<maplibregl.Marker | null>(null);
  const vietnamProvinceLabelMarkersRef = useRef<maplibregl.Marker[]>([]);
  const hnthHubPulseMarkerRef = useRef<maplibregl.Marker | null>(null);
  const hnthContinuousMonitoringRef = useRef(false);
  const hnthAgentOnlineRef = useRef(false);
  const hasSetInitialViewportRef = useRef(false);
  const homeTransitionTimeoutRef = useRef<number | null>(null);
  const inspectedBoundaryPulseTimeoutsRef = useRef<number[]>([]);
  // Ngăn effect tự zoom theo vùng đang khoanh ghi đè khung toàn Hải Phòng
  // trong thời gian đang chờ trước khi đi tới địa giới mặc định.
  const isHomeTransitionActiveRef = useRef(false);
  const suppressNextAdministrativeSelectionFitRef = useRef(false);
  const managedSavedFeatureIdsRef = useRef(new Set<string | number>());
  const isSyncingSavedFeaturesRef = useRef(false);
  const [isMapReady, setIsMapReady] = useState(false);
  const [isInitialRegionalMapReady, setIsInitialRegionalMapReady] = useState(false);
  const [isDrawReady, setIsDrawReady] = useState(false);
  const [isBaseMapMenuOpen, setIsBaseMapMenuOpen] = useState(false);
  const [inspectedAdministrativeId, setInspectedAdministrativeId] = useState<number | null>(null);
  const [inspectedAdministrativeIds, setInspectedAdministrativeIds] = useState<number[]>([]);
  const [fixedMapInfo, setFixedMapInfo] = useState<FixedMapInfo | null>(null);
  const [zoneSummary, setZoneSummary] = useState<ZoneSummary>({ zoneCount: 0, drawnZoneCount: 0, administrativeZoneCount: 0, totalAreaSquareMeters: 0, estimatedPopulation: 0, items: [] });

  const refreshZoneSummary = () => setZoneSummary(buildZoneSummary(drawRef.current));
  return { containerRef, mapRef, drawRef, radiusMarkersRef, drawEditMarkersRef, textMarkersRef, iconMarkersRef, drawSearchMarkerRef, vietnamProvinceLabelMarkersRef, hnthHubPulseMarkerRef, hnthContinuousMonitoringRef, hnthAgentOnlineRef, hasSetInitialViewportRef, homeTransitionTimeoutRef, inspectedBoundaryPulseTimeoutsRef, isHomeTransitionActiveRef, suppressNextAdministrativeSelectionFitRef, managedSavedFeatureIdsRef, isSyncingSavedFeaturesRef, isMapReady, setIsMapReady, isInitialRegionalMapReady, setIsInitialRegionalMapReady, isDrawReady, setIsDrawReady, isBaseMapMenuOpen, setIsBaseMapMenuOpen, inspectedAdministrativeId, setInspectedAdministrativeId, inspectedAdministrativeIds, setInspectedAdministrativeIds, fixedMapInfo, setFixedMapInfo, zoneSummary, setZoneSummary, refreshZoneSummary };
}

export type MapScope = ReturnType<typeof useMapScope>;
