import type { AdministrativeUnit } from "../../core/types";
import { publicAsset } from "../../core/runtime";

interface OfficialMapping {
  id: number;
  wardCode: string;
  tenhc: string;
  loai: AdministrativeUnit["type"];
  coordinates: [number, number];
}

interface OfficialGeometry {
  wardCode: string;
  geometry: GeoJSON.Geometry;
}

export interface UbndPoint {
  id: string;
  wardCode: string;
  name: string;
  coordinates: [number, number];
}

const OFFICIAL_BASE = publicAsset("hp-official/data_geometry");

export async function loadAdministrativeUnits(): Promise<AdministrativeUnit[]> {
  const [mappingResponse, geometryResponse] = await Promise.all([
    fetch(`${OFFICIAL_BASE}/mapping_4.json`),
    fetch(`${OFFICIAL_BASE}/geometry_4.json`),
  ]);

  if (!mappingResponse.ok || !geometryResponse.ok) {
    throw new Error("Không tải được dữ liệu địa giới Hải Phòng");
  }

  const mappings = (await mappingResponse.json()) as OfficialMapping[];
  const geometries = (await geometryResponse.json()) as OfficialGeometry[];
  const geometryByCode = new Map(geometries.map((item) => [item.wardCode, item.geometry]));

  return mappings
    .map((item) => ({
      id: item.id,
      wardCode: item.wardCode,
      name: item.tenhc,
      type: item.loai,
      coordinates: item.coordinates.map(Number) as [number, number],
      geometry: geometryByCode.get(item.wardCode),
    }))
    .filter((item): item is AdministrativeUnit => Boolean(item.geometry))
    .sort((a, b) => a.name.localeCompare(b.name, "vi"));
}

/** Các mốc UBND xã/phường dùng để gán camera trên bản đồ. */
export async function loadGovernmentUbndPoints(): Promise<UbndPoint[]> {
  const response = await fetch(publicAsset("data/osm-layers/government-ubnd.json"));
  if (!response.ok) throw new Error("Không tải được lớp mốc UBND");
  const data = await response.json() as GeoJSON.FeatureCollection<GeoJSON.Point, { name?: string; wardCode?: string }>;
  return data.features
    .filter((feature) => Boolean(feature.geometry?.type === "Point" && feature.properties?.wardCode))
    .map((feature) => ({
      id: String(feature.id ?? feature.properties?.wardCode),
      wardCode: String(feature.properties?.wardCode),
      name: String(feature.properties?.name || "Mốc UBND"),
      coordinates: feature.geometry.coordinates as [number, number],
    }))
    .sort((a, b) => a.name.localeCompare(b.name, "vi"));
}

export function unitsToFeatureCollection(units: AdministrativeUnit[]): GeoJSON.FeatureCollection {
  return {
    type: "FeatureCollection",
    features: units.map((unit) => ({
      type: "Feature",
      id: unit.id,
      properties: { id: unit.id, name: unit.name, type: unit.type, wardCode: unit.wardCode },
      geometry: unit.geometry,
    })),
  };
}

