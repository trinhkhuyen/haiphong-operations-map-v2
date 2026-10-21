// Ranh giới và nhãn tỉnh/thành Việt Nam quanh Hải Phòng.
import { useEffect } from "react";
import maplibregl, { type GeoJSONSource } from "maplibre-gl";
import type { MapScope } from "./useMapScope";

export function useVietnamProvinceBoundaries(context: MapScope) {
  const { mapRef, vietnamProvinceLabelMarkersRef, isMapReady } = context;
  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map) return;
    const controller = new AbortController();

    void fetch("/data/vietnam-provinces.geojson", { signal: controller.signal })
      .then((response) => {
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return response.json() as Promise<GeoJSON.FeatureCollection>;
      })
      .then((data) => {
        if (controller.signal.aborted) return;
        if (!map.getSource("vietnam-provinces")) {
          map.addSource("vietnam-provinces", {
            type: "geojson",
            data,
            attribution: "Ranh giới tỉnh: GISData (đơn vị hành chính Việt Nam từ 2025)",
          });
        } else {
          (map.getSource("vietnam-provinces") as GeoJSONSource).setData(data);
        }
        if (!map.getLayer("vietnam-province-boundaries")) {
          map.addLayer({
            id: "vietnam-province-boundaries",
            type: "line",
            source: "vietnam-provinces",
            filter: ["==", ["get", "kind"], "boundary"],
            paint: {
              "line-color": "#ffffff",
              "line-width": ["interpolate", ["linear"], ["zoom"], 7, 0.75, 11, 1.25],
              "line-opacity": 0.9,
              "line-dasharray": [2.4, 2.4],
            },
          });
        }

        for (const marker of vietnamProvinceLabelMarkersRef.current) marker.remove();
        vietnamProvinceLabelMarkersRef.current = data.features
          .filter((item): item is GeoJSON.Feature<GeoJSON.Point> =>
            item.geometry?.type === "Point"
            && ["label", "archipelago-label"].includes(String(item.properties?.kind)),
          )
          .map((item) => {
            const element = document.createElement("div");
            const isArchipelago = item.properties?.kind === "archipelago-label";
            const name = String(item.properties?.name ?? "");
            element.className = `vietnam-province-label${isArchipelago ? " archipelago-label" : ""}`;
            element.textContent = name;
            element.setAttribute("aria-label", name.replace("\n", " "));
            const coordinates = item.geometry.coordinates as [number, number];
            // Nhãn Hưng Yên nằm sát vùng hiển thị Hải Phòng ở các mức zoom
            // tổng quan. Dịch nhẹ về tây-bắc để không chồng lên địa giới,
            // áp dụng tại lớp nhãn dùng chung cho mọi chế độ bản đồ.
            const normalizedName = name.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toUpperCase();
            const labelCoordinates: [number, number] = normalizedName === "HUNG YEN"
              ? [coordinates[0] - 0.12, coordinates[1] + 0.05]
              : coordinates;
            return new maplibregl.Marker({ element, anchor: "center" })
              .setLngLat(labelCoordinates)
              .addTo(map);
          });
      })
      .catch((error: unknown) => {
        if (!controller.signal.aborted) console.warn("Không tải được ranh giới tỉnh/thành Việt Nam.", error);
      });

    return () => controller.abort();
  }, [isMapReady]);
}
