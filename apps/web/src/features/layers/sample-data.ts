import type { FeatureCollection, Geometry } from "geojson";
import type { OperationalLayer } from "../../core/types";

const collection = (features: FeatureCollection<Geometry>["features"] = []): FeatureCollection<Geometry> => ({ type: "FeatureCollection", features });

const pointLayer = (
  layer: Omit<OperationalLayer, "data" | "count" | "source">,
  points: Array<[number, number, string, string?]>,
): OperationalLayer => ({
  ...layer,
  count: points.length,
  source: "demo",
  data: collection(points.map(([lng, lat, name, status = "active"], index) => ({
    type: "Feature" as const,
    id: index,
    properties: { name, status, type: layer.name },
    geometry: { type: "Point" as const, coordinates: [lng, lat] },
  }))),
});

const liveLayer = (layer: Omit<OperationalLayer, "data" | "count" | "source">): OperationalLayer => ({
  ...layer, count: 0, source: "openstreetmap", data: collection(),
});

const derivedLayer = (layer: Omit<OperationalLayer, "data" | "count" | "source">): OperationalLayer => ({
  ...layer, count: 0, source: "derived", data: collection(),
});

export const sampleLayers: OperationalLayer[] = [
  pointLayer({ id: "cameras", name: "Camera giám sát", category: "camera", group: "monitoring", color: "#2dd4bf", icon: "camera", visible: true }, [
    [106.682, 20.864, "Camera Cầu Rào", "online"], [106.69, 20.846, "Camera Lạch Tray", "online"],
    [106.675, 20.858, "Camera Ngã 5", "warning"], [106.705, 20.872, "Camera Lê Hồng Phong", "online"],
    [106.642, 20.861, "Camera Hùng Vương", "offline"], [106.728, 20.842, "Camera Đình Vũ", "online"],
    [106.755, 20.791, "Camera Cát Hải", "online"], [106.607, 20.947, "Camera An Dương", "online"],
  ]),
  derivedLayer({ id: "hnth-network", name: "HNTH", category: "network", group: "monitoring", color: "#38bdf8", icon: "radio", geometryMode: "line", visible: false }),
  pointLayer({ id: "terminals", name: "Bến xe & đầu mối", category: "transport", group: "transport", color: "#fbbf24", icon: "bus", visible: true }, [
    [106.68, 20.849, "Bến xe Cầu Rào"], [106.669, 20.879, "Bến xe Thượng Lý"],
    [106.721, 20.82, "Bến tàu Đình Vũ"], [106.774, 20.734, "Bến phà Gót"],
  ]),
  liveLayer({ id: "transport-expressways", name: "Cao tốc", category: "transport", group: "transport", color: "#fb7185", icon: "route", geometryMode: "line", visible: true }),
  liveLayer({ id: "transport-national-roads", name: "Quốc lộ", category: "transport", group: "transport", color: "#f59e0b", icon: "route", geometryMode: "line", visible: true }),
  liveLayer({ id: "transport-provincial-roads", name: "Tỉnh lộ", category: "transport", group: "transport", color: "#facc15", icon: "route", geometryMode: "line", visible: true }),
  liveLayer({ id: "hydro-rivers", name: "Sông", category: "hydrology", group: "hydrology", color: "#38bdf8", icon: "waves", visible: true }),
  liveLayer({ id: "hydro-streams", name: "Suối", category: "hydrology", group: "hydrology", color: "#22d3ee", icon: "waves", visible: true }),
  liveLayer({ id: "hydro-waterbodies", name: "Ao, hồ", category: "hydrology", group: "hydrology", color: "#0ea5e9", icon: "waves", visible: true }),
  liveLayer({ id: "government-ubnd", name: "UBND", category: "facility", group: "government", color: "#60a5fa", icon: "landmark", visible: true }),
  liveLayer({ id: "government-culture", name: "Nhà văn hóa", category: "facility", group: "government", color: "#818cf8", icon: "landmark", visible: false }),
  liveLayer({ id: "government-one-stop", name: "Trung tâm DVSNC (một cửa)", category: "facility", group: "government", color: "#a78bfa", icon: "landmark", visible: true }),
  liveLayer({ id: "government-police", name: "Công an", category: "facility", group: "government", color: "#f87171", icon: "shield", visible: true }),
  liveLayer({ id: "government-departments", name: "Sở, ban, ngành", category: "facility", group: "government", color: "#c084fc", icon: "landmark", visible: false }),
  liveLayer({ id: "government-other", name: "Cơ quan khác", category: "facility", group: "government", color: "#94a3b8", icon: "landmark", visible: false }),
];

export const createLayerCatalog = (): OperationalLayer[] => sampleLayers.map((layer) => ({
  ...layer,
  visible: false,
  count: 0,
  data: collection(),
}));

export const loadBundledOperationalLayers = (layerIds: string[]): OperationalLayer[] => {
  const requested = new Set(layerIds);
  return sampleLayers
    .filter((layer) => layer.source === "demo" && requested.has(layer.id))
    .map((layer) => ({ ...layer, data: structuredClone(layer.data) }));
};
