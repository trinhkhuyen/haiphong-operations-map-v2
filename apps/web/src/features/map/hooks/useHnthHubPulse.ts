// Vòng nhịp tại Trung tâm khi đang Giám sát liên tục và agent online (menu HNTH).
import { useEffect } from "react";
import maplibregl from "maplibre-gl";
import { useAppStore } from "../../../core/store";
import { HNTH_LAYER_ID } from "../../layers/hnth-data-provider";
import { useHnthLiveStore } from "../../../core/realtime/hnth-live-store";
import type { MapScope } from "./useMapScope";

export function useHnthHubPulse(context: MapScope) {
  const { mapRef, hnthHubPulseMarkerRef, hnthContinuousMonitoringRef, hnthAgentOnlineRef, isMapReady } = context;
  const layers = useAppStore((state) => state.layers);
  const hubEnabled = useAppStore((state) => state.hubEnabled);
  const activePanel = useAppStore((state) => state.activePanel);
  useEffect(() => {
    const removeHubPulse = () => {
      hnthHubPulseMarkerRef.current?.remove();
      hnthHubPulseMarkerRef.current = null;
    };

    const syncHubPulse = () => {
      const map = mapRef.current;
      const hnthLayer = layers.find((layer) => layer.id === HNTH_LAYER_ID);
      const hub = hnthLayer?.data.features.find((feature) => (
        feature.geometry.type === "Point" && feature.properties?.role === "hub"
      ));
      const shouldShowHubMarker = hubEnabled || (hnthContinuousMonitoringRef.current && hnthAgentOnlineRef.current && activePanel === "conference");
      if (!map || !isMapReady || !shouldShowHubMarker || !hub || hub.geometry.type !== "Point") {
        removeHubPulse();
        return;
      }
      if (!hnthHubPulseMarkerRef.current) {
        const element = document.createElement("div");
        element.className = "hnth-hub-pulse-marker";
        element.setAttribute("aria-label", "Giám sát liên tục đang hoạt động tại Trung tâm Chính trị - Hành chính");
        element.innerHTML = '<span class="hnth-hub-pulse-dot"></span><span class="hnth-hub-pulse-ring"></span>';
        hnthHubPulseMarkerRef.current = new maplibregl.Marker({ element, anchor: "center" })
          .setLngLat(hub.geometry.coordinates as [number, number])
          .addTo(map);
      } else {
        hnthHubPulseMarkerRef.current.setLngLat(hub.geometry.coordinates as [number, number]);
      }
    };

    // Cờ giám sát và trạng thái agent đang chọn cho HNTH đến từ core/realtime.
    const readLiveState = (live: ReturnType<typeof useHnthLiveStore.getState>) => {
      hnthContinuousMonitoringRef.current = live.monitoring.enabled;
      hnthAgentOnlineRef.current = live.agent.state === "online";
    };
    readLiveState(useHnthLiveStore.getState());
    const stopLive = useHnthLiveStore.subscribe((live, previous) => {
      if (live.monitoring === previous.monitoring && live.agent === previous.agent) return;
      readLiveState(live);
      syncHubPulse();
    });
    syncHubPulse();
    return () => {
      stopLive();
      removeHubPulse();
    };
  }, [activePanel, hubEnabled, isMapReady, layers]);
}
