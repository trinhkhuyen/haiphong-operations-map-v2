import type { Feature, FeatureCollection, Geometry, LineString, Point } from "geojson";
import type { OperationalLayer } from "../../core/types";

export const HNTH_LAYER_ID = "hnth-network";

export type HnthConnectionStatus = "unknown" | "unconnected" | "connected" | "lost";

export interface HnthVisualStyle {
  color: string;
  visible: boolean;
}

export type HnthStatusStyles = Record<HnthConnectionStatus, HnthVisualStyle>;

export const HNTH_STATUS_LABELS: Record<HnthConnectionStatus, string> = {
  unknown: "Chưa xác định",
  unconnected: "Chờ kết nối",
  connected: "Đã kết nối",
  lost: "Mất kết nối",
};

export const DEFAULT_HNTH_LINE_STYLES: HnthStatusStyles = {
  unknown: { color: "transparent", visible: false },
  unconnected: { color: "#facc15", visible: true },
  connected: { color: "#00FFFF", visible: true },
  lost: { color: "#ef4444", visible: true },
};

export const DEFAULT_HNTH_AREA_STYLES: HnthStatusStyles = {
  unknown: { color: "transparent", visible: false },
  unconnected: { color: "#fde047", visible: true },
  connected: { color: "#4ade80", visible: true },
  lost: { color: "#fb7185", visible: true },
};

export interface HnthPointOverride {
  ipAddress: string;
  gateway: string;
  model: string;
  status: HnthConnectionStatus;
}

// Vị trí thật theo Google Maps: Trung tâm Chính trị - Hành chính TP. Hải Phòng.
const HNTH_HUB: [number, number] = [106.6790562, 20.8821839];

interface UbndSnapshotProperties {
  name?: string;
  wardCode?: string;
  administrativeType?: string;
}

export async function loadHnthDemoLayer(signal?: AbortSignal): Promise<OperationalLayer> {
  const response = await fetch("/data/osm-layers/government-ubnd.json", { signal });
  if (!response.ok) throw new Error(`Không tải được danh sách UBND (${response.status})`);
  const ubnd = await response.json() as FeatureCollection<Geometry, UbndSnapshotProperties>;
  const branchPoints = ubnd.features.filter((item): item is Feature<Point, UbndSnapshotProperties> => item.geometry.type === "Point");
  const features: Feature<Geometry>[] = [];

  features.push({
    type: "Feature",
    id: "hnth-hub",
    properties: {
      pointId: "hnth-hub",
      name: "Trung tâm Chính trị - Hành chính TP. Hải Phòng",
      role: "hub",
      roleLabel: "Điểm chính HNTH",
      status: "unknown",
      ipAddress: "",
      gateway: "192.168.1.1",
      source: "Dữ liệu demo HNTH",
    },
    geometry: { type: "Point", coordinates: HNTH_HUB },
  });

  branchPoints.forEach((branch, index) => {
    const coordinates = branch.geometry.coordinates as [number, number];
    // Khi chưa có dữ liệu Agent, mọi điểm đều được coi là mất kết nối.
    // Ping thành công mới chuyển sang "Chờ kết nối".
    const status: HnthConnectionStatus = "unknown";
    const commonProperties = {
      pointId: `hnth-branch-${index + 1}`,
      name: branch.properties?.name ?? `Điểm nhánh HNTH ${index + 1}`,
      wardCode: branch.properties?.wardCode ?? "",
      administrativeType: branch.properties?.administrativeType ?? "xã/phường/đặc khu",
      role: "branch",
      roleLabel: "Điểm nhánh HNTH",
      status,
      ipAddress: "",
      gateway: "192.168.1.1",
      source: "Dữ liệu demo HNTH",
    };

    features.push({
      type: "Feature",
      id: `hnth-link-${index + 1}`,
      properties: commonProperties,
      geometry: { type: "LineString", coordinates: buildArc(HNTH_HUB, coordinates, index) } satisfies LineString,
    });
    features.push({
      type: "Feature",
      id: `hnth-branch-${index + 1}`,
      properties: commonProperties,
      geometry: { type: "Point", coordinates },
    });
  });

  return {
    id: HNTH_LAYER_ID,
    name: "HNTH",
    category: "network",
    group: "monitoring",
    color: "#38bdf8",
    icon: "radio",
    visible: true,
    count: branchPoints.length + 1,
    data: { type: "FeatureCollection", features },
    geometryMode: "line",
    source: "derived",
  };
}

export function applyHnthPointOverrides(layer: OperationalLayer, overrides: Record<string, HnthPointOverride>): OperationalLayer {
  if (!Object.keys(overrides).length) return layer;
  return {
    ...layer,
    data: {
      ...layer.data,
      features: layer.data.features.map((item) => {
        const pointId = String(item.properties?.pointId ?? item.id ?? "");
        const override = overrides[pointId];
        if (!override) return item;
        const status = normalizeHnthStatus(override.status);
        return {
          ...item,
          properties: {
            ...item.properties,
            ...override,
            // IP rỗng là cấu hình hợp lệ: điểm này phải giữ unknown và không
            // được tự sinh hoặc phục hồi IP demo từ dữ liệu cũ.
            ipAddress: override.ipAddress.trim(),
            gateway: override.gateway.trim() ? override.gateway.trim() : item.properties?.gateway,
            status,
            ...(status !== "unknown" ? { statusLabel: HNTH_STATUS_LABELS[status] } : { statusLabel: undefined }),
          },
        };
      }),
    },
  };
}

export function normalizeHnthStatus(status: unknown): HnthConnectionStatus {
  // Tương thích dữ liệu đã lưu từ phiên bản 2 trạng thái trước đây.
  if (status === "disconnected") return "lost";
  return status === "unknown" || status === "unconnected" || status === "lost" || status === "connected" ? status : "unknown";
}

function buildArc(from: [number, number], to: [number, number], index: number): [number, number][] {
  const dx = to[0] - from[0];
  const dy = to[1] - from[1];
  const distance = Math.hypot(dx, dy);
  if (distance < 0.00001) return [from, to];
  const direction = index % 2 === 0 ? 1 : -1;
  const curve = Math.min(distance * 0.16, 0.08) * direction;
  const control: [number, number] = [
    (from[0] + to[0]) / 2 - (dy / distance) * curve,
    (from[1] + to[1]) / 2 + (dx / distance) * curve,
  ];
  return Array.from({ length: 25 }, (_, step) => {
    const t = step / 24;
    const inverse = 1 - t;
    return [
      inverse * inverse * from[0] + 2 * inverse * t * control[0] + t * t * to[0],
      inverse * inverse * from[1] + 2 * inverse * t * control[1] + t * t * to[1],
    ];
  });
}
