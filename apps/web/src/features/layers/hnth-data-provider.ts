import type { ConnectionStatus } from "@haiphong-ops/hnth-protocol";
import type { Feature, FeatureCollection, Geometry, LineString, Point } from "geojson";
import type { OperationalLayer } from "../../core/types";
import type { HnthCatalog, HnthRoster, HnthRosterPoint } from "../../core/realtime/hnth-live-store";
import { publicAsset } from "../../core/runtime";

export const HNTH_LAYER_ID = "hnth-network";

// Từ vựng trạng thái hiển thị dùng chung với backend/agent (packages/hnth-protocol).
export type HnthConnectionStatus = ConnectionStatus;

export interface HnthVisualStyle {
  color: string;
  visible: boolean;
  /** Chấm tín hiệu chạy dọc đường kết nối; chỉ dùng cho kiểu đường HNTH. */
  signal?: boolean;
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
  unconnected: { color: "#facc15", visible: true, signal: false },
  connected: { color: "#00FFFF", visible: true, signal: false },
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
export const HNTH_HUB: [number, number] = [106.6790562, 20.8821839];
/** Tên cố định của điểm Trung tâm (Import chấp nhận cả tên cũ "... TP. Hải Phòng"). */
export const HNTH_HUB_NAME = "Trung tâm Chính trị - Hành chính";

interface UbndSnapshotProperties {
  name?: string;
  wardCode?: string;
  administrativeType?: string;
}

// Lớp gốc (chưa áp danh sách phiên/IP) dùng lại khi đổi danh sách phiên họp, không tải lại file.
let baseLayerPromise: Promise<OperationalLayer> | null = null;
export function loadHnthDemoLayer(): Promise<OperationalLayer> {
  baseLayerPromise ??= buildHnthDemoLayer().catch((error: unknown) => { baseLayerPromise = null; throw error; });
  return baseLayerPromise;
}

async function buildHnthDemoLayer(signal?: AbortSignal): Promise<OperationalLayer> {
  const response = await fetch(publicAsset("data/osm-layers/government-ubnd.json"), { signal });
  if (!response.ok) throw new Error(`Không tải được danh sách UBND (${response.status})`);
  const ubnd = await response.json() as FeatureCollection<Geometry, UbndSnapshotProperties>;
  const branchPoints = ubnd.features.filter((item): item is Feature<Point, UbndSnapshotProperties> => item.geometry.type === "Point");
  const features: Feature<Geometry>[] = [];

  features.push({
    type: "Feature",
    id: "hnth-hub",
    properties: {
      pointId: "hnth-hub",
      name: HNTH_HUB_NAME,
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

/** Điểm của phiên: danh sách đang áp dụng lọc từ dữ liệu chủ; không chọn danh sách = toàn bộ dữ liệu chủ. */
export function hnthSessionPoints(catalog: HnthCatalog | null, roster: HnthRoster | null): HnthRosterPoint[] | null {
  if (!catalog?.points.length) return null;
  if (!roster) return catalog.points;
  const ids = new Set(roster.pointIds);
  return catalog.points.filter((point) => ids.has(point.pointId));
}

/**
 * Lớp HNTH theo dữ liệu chủ + danh sách phiên họp: chỉ giữ xã/phường của phiên (xã/phường khác
 * "không tham gia": không vẽ, không đếm, không ping), thêm điểm Sở/Ban/Ngành (role "extra",
 * không có vị trí thật nên không vẽ trên bản đồ mà hiển thị bằng card), lấy tên Sở/Ban/Ngành và
 * IP/Gateway/Model từ dữ liệu chủ. Trạng thái vẫn lấy từ `overrides` (kết quả giám sát gần nhất).
 * Chưa Import dữ liệu chủ thì giữ 115 điểm mặc định như trước.
 */
export function composeHnthLayer(base: OperationalLayer, overrides: Record<string, HnthPointOverride>, catalog: HnthCatalog | null, roster: HnthRoster | null): OperationalLayer {
  const sessionPoints = hnthSessionPoints(catalog, roster);
  if (!sessionPoints) return applyHnthPointOverrides(base, overrides);
  const byId = new Map(sessionPoints.map((point) => [point.pointId, point]));
  const kept = base.data.features.filter((item) => {
    const pointId = String(item.properties?.pointId ?? "");
    return pointId === "hnth-hub" || byId.has(pointId);
  });
  const extras: Feature<Geometry>[] = sessionPoints.filter((point) => point.kind === "extra").map((point) => ({
    type: "Feature",
    id: point.pointId,
    properties: { pointId: point.pointId, name: point.name, role: "extra", roleLabel: "Sở/Ban/Ngành", status: "unknown", ipAddress: "", gateway: "", source: roster?.name ?? "Dữ liệu điểm cầu" },
    geometry: { type: "Point", coordinates: HNTH_HUB },
  }));
  const withStatus = applyHnthPointOverrides({ ...base, count: kept.filter((item) => item.geometry.type === "Point").length + extras.length, data: { ...base.data, features: [...kept, ...extras] } }, overrides);
  return {
    ...withStatus,
    data: {
      ...withStatus.data,
      features: withStatus.data.features.map((item) => {
        const point = byId.get(String(item.properties?.pointId ?? ""));
        if (!point) return item;
        const ipAddress = point.ipAddress.trim();
        // Không có IP thì luôn "Chưa xác định", giống quy ước ở backend.
        const status = ipAddress ? normalizeHnthStatus(item.properties?.status) : "unknown";
        return { ...item, properties: { ...item.properties, ...(point.kind === "extra" ? { name: point.name } : {}), ipAddress, gateway: point.gateway || item.properties?.gateway || "", model: point.modelVendor || item.properties?.model || "", status, statusLabel: status === "unknown" ? undefined : HNTH_STATUS_LABELS[status] } };
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
