import type { AdministrativeUnit } from "../../core/types";

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

const OFFICIAL_BASE = "/hp-official/data_geometry";

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

