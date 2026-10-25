import { booleanIntersects, booleanPointInPolygon, feature } from "@turf/turf";
import type { Feature, Geometry, LineString, Point, Polygon } from "geojson";
import type { AdministrativeUnit, OperationalLayer } from "../../core/types";
import { sampleLayers } from "./sample-data";
import { publicAsset } from "../../core/runtime";

interface OsmElement {
  type: "node" | "way" | "relation";
  id: number;
  lat?: number;
  lon?: number;
  center?: { lat: number; lon: number };
  geometry?: Array<{ lat: number; lon: number }>;
  tags?: Record<string, string>;
}

interface OverpassResponse { elements: OsmElement[] }
const DEFAULT_ENDPOINTS = [
  "/overpass/api/interpreter",
  "https://overpass-api.de/api/interpreter",
  "https://overpass.kumi.systems/api/interpreter",
];
const CACHE_KEY = "hp-ops-osm-layers-v2";
const CACHE_TTL = 24 * 60 * 60 * 1000;

const normalize = (value: string) => value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/đ/g, "d").toLowerCase();

export async function loadOsmOperationalLayers(units: AdministrativeUnit[], layerIds: string[], signal?: AbortSignal): Promise<OperationalLayer[]> {
  const osmLayerIds = new Set(sampleLayers.filter((layer) => layer.source === "openstreetmap").map((layer) => layer.id));
  const requestedIds = [...new Set(layerIds.filter((id) => osmLayerIds.has(id)))];
  if (!requestedIds.length) return [];

  const snapshotData: Record<string, GeoJSON.FeatureCollection> = {};
  await Promise.all(requestedIds.map(async (id) => {
    try {
      const response = await fetch(publicAsset(`data/osm-layers/${encodeURIComponent(id)}.json`), { signal });
      if (response.ok) snapshotData[id] = await response.json() as GeoJSON.FeatureCollection;
    } catch (error) {
      if (signal?.aborted) throw error;
    }
  }));
  if (Object.keys(snapshotData).length === requestedIds.length) {
    writeCache(snapshotData);
    return hydrateLayers(snapshotData, requestedIds, units);
  }

  const cached = readCache();
  if (cached) {
    for (const id of requestedIds) {
      if (!snapshotData[id] && cached[id]) snapshotData[id] = cached[id];
    }
  }
  if (Object.keys(snapshotData).length === requestedIds.length) return hydrateLayers(snapshotData, requestedIds, units);

  const bbox = mainlandBbox(units);
  const bboxText = bbox.join(",");
  const [rivers, streams, waters, roads, facilities] = await Promise.all([
    queryOverpass(`way["waterway"="river"](${bboxText});out tags geom;`, signal),
    queryOverpass(`way["waterway"="stream"](${bboxText});out tags geom;`, signal),
    queryOverpass(`way["natural"="water"](${bboxText});out tags geom;`, signal),
    queryOverpass(`way["highway"~"^(motorway|motorway_link|trunk|primary|secondary)$"](${bboxText});out tags geom;`, signal),
    queryOverpass(`(nwr["amenity"~"^(police|community_centre|townhall)$"](${bboxText});nwr["office"="government"](${bboxText}););out tags center;`, signal),
  ]);

  const boundaries = units.map((unit) => feature(unit.geometry));
  const layerFeatures: Record<string, Feature<Geometry>[]> = {
    "transport-expressways": [], "transport-national-roads": [], "transport-provincial-roads": [],
    "hydro-rivers": groupNamedWaterways(rivers.elements.map(toWaterwayFeature).filter(isFeature).filter((item) => intersectsCity(item, boundaries)), "Sông"),
    "hydro-streams": groupNamedWaterways(streams.elements.map(toWaterwayFeature).filter(isFeature).filter((item) => intersectsCity(item, boundaries)), "Suối"),
    "hydro-waterbodies": waters.elements.map(toWaterbodyFeature).filter(isFeature).filter((item) => intersectsCity(item, boundaries)),
    "government-ubnd": [], "government-culture": [], "government-one-stop": [],
    "government-police": [], "government-departments": [], "government-other": [],
  };

  for (const element of roads.elements) {
    const layerId = classifyRoad(element);
    const item = toRoadFeature(element);
    if (layerId && item && intersectsCity(item, boundaries)) layerFeatures[layerId].push(item);
  }
  for (const id of ["transport-expressways", "transport-national-roads", "transport-provincial-roads"]) {
    layerFeatures[id] = groupRoadSegments(layerFeatures[id] as Feature<LineString>[]);
  }

  const seenFacilities = new Set<string>();
  for (const element of facilities.elements) {
    const item = toFacilityFeature(element);
    if (!item || !intersectsCity(item, boundaries)) continue;
    const coordinates = (item.geometry as Point).coordinates;
    const key = `${normalize(String(item.properties?.name ?? ""))}:${coordinates.map((value) => value.toFixed(4)).join(":")}`;
    if (seenFacilities.has(key)) continue;
    seenFacilities.add(key);
    layerFeatures[classifyFacility(element)].push(item);
  }

  const serialized: Record<string, GeoJSON.FeatureCollection> = Object.fromEntries(
    Object.entries(layerFeatures).map(([id, features]) => [id, { type: "FeatureCollection" as const, features }]),
  );
  writeCache(serialized);
  return hydrateLayers(serialized, requestedIds, units);
}

function mainlandBbox(units: AdministrativeUnit[]): [number, number, number, number] {
  const coordinates: number[][] = [];
  const walk = (value: unknown) => {
    if (!Array.isArray(value)) return;
    if (typeof value[0] === "number" && typeof value[1] === "number") coordinates.push(value as number[]);
    else value.forEach(walk);
  };
  units.filter((unit) => unit.coordinates[0] < 107.3).forEach((unit) => walk((unit.geometry as { coordinates?: unknown }).coordinates));
  return [
    Math.min(...coordinates.map((item) => item[1])) - 0.02,
    Math.min(...coordinates.map((item) => item[0])) - 0.02,
    Math.max(...coordinates.map((item) => item[1])) + 0.02,
    Math.max(...coordinates.map((item) => item[0])) + 0.02,
  ];
}

async function queryOverpass(statement: string, signal?: AbortSignal): Promise<OverpassResponse> {
  const configured = import.meta.env.VITE_OVERPASS_ENDPOINT as string | undefined;
  const endpoints = configured ? [configured] : DEFAULT_ENDPOINTS;
  let lastError: unknown;
  for (const endpoint of endpoints) {
    try {
      const response = await fetch(endpoint, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8" },
        body: new URLSearchParams({ data: `[out:json][timeout:120];${statement}` }),
        signal,
      });
      if (!response.ok) throw new Error(`Overpass ${response.status}`);
      return await response.json() as OverpassResponse;
    } catch (error) {
      if (signal?.aborted) throw error;
      lastError = error;
    }
  }
  throw lastError ?? new Error("Không tải được dữ liệu OpenStreetMap");
}

function toWaterwayFeature(element: OsmElement): Feature<LineString> | null {
  if (!element.geometry || element.geometry.length < 2) return null;
  return {
    type: "Feature", id: `osm-${element.type}-${element.id}`,
    properties: { name: element.tags?.name || element.tags?.["name:vi"] || "Chưa có tên", type: element.tags?.waterway, osmId: element.id, source: "OpenStreetMap" },
    geometry: { type: "LineString", coordinates: element.geometry.map(({ lon, lat }) => [lon, lat]) },
  };
}

function toRoadFeature(element: OsmElement): Feature<LineString> | null {
  if (!element.geometry || element.geometry.length < 2) return null;
  const tags = element.tags ?? {};
  const ref = tags.ref ?? "";
  const name = tags.name || tags["name:vi"] || ref || "Tuyến chưa đặt tên";
  return {
    type: "Feature", id: `osm-${element.type}-${element.id}`,
    properties: { name, ref, type: tags.highway, osmId: element.id, source: "OpenStreetMap" },
    geometry: { type: "LineString", coordinates: element.geometry.map(({ lon, lat }) => [lon, lat]) },
  };
}

function classifyRoad(element: OsmElement): "transport-expressways" | "transport-national-roads" | "transport-provincial-roads" | null {
  const tags = element.tags ?? {};
  const text = normalize(`${tags.ref ?? ""} ${tags.name ?? ""} ${tags["name:vi"] ?? ""}`);
  if (tags.highway === "motorway" || tags.highway === "motorway_link" || /(^|[;\s])ct[.\s-]?\d/.test(text) || /cao toc/.test(text)) return "transport-expressways";
  if (/(^|[;\s])ql[.\s-]?\d/.test(text) || /quoc lo/.test(text)) return "transport-national-roads";
  if (/(^|[;\s])(dt|tl)[.\s-]?\d/.test(text) || /duong tinh|tinh lo/.test(text)) return "transport-provincial-roads";
  return null;
}

function toWaterbodyFeature(element: OsmElement): Feature<Polygon | LineString> | null {
  if (!element.geometry || element.geometry.length < 2) return null;
  const waterType = element.tags?.water;
  if (["river", "canal", "dock"].includes(waterType ?? "")) return null;
  const coordinates = element.geometry.map(({ lon, lat }) => [lon, lat]);
  const closed = coordinates.length >= 4 && coordinates[0][0] === coordinates.at(-1)?.[0] && coordinates[0][1] === coordinates.at(-1)?.[1];
  return {
    type: "Feature", id: `osm-${element.type}-${element.id}`,
    properties: { name: element.tags?.name || element.tags?.["name:vi"] || waterbodyFallback(waterType), type: waterType || "water", osmId: element.id, source: "OpenStreetMap" },
    geometry: closed ? { type: "Polygon", coordinates: [coordinates] } : { type: "LineString", coordinates },
  };
}

function toFacilityFeature(element: OsmElement): Feature<Point> | null {
  const lon = element.lon ?? element.center?.lon;
  const lat = element.lat ?? element.center?.lat;
  if (lon === undefined || lat === undefined) return null;
  return {
    type: "Feature", id: `osm-${element.type}-${element.id}`,
    properties: {
      name: element.tags?.name || element.tags?.["name:vi"] || facilityFallback(element),
      type: element.tags?.amenity || element.tags?.government || "government",
      address: [element.tags?.["addr:housenumber"], element.tags?.["addr:street"]].filter(Boolean).join(" "),
      osmId: element.id, source: "OpenStreetMap", status: "active",
    },
    geometry: { type: "Point", coordinates: [lon, lat] },
  };
}

function classifyFacility(element: OsmElement): string {
  const tags = element.tags ?? {};
  const name = normalize(tags.name || tags["name:vi"] || "");
  if (tags.amenity === "police" || /cong an|canh sat/.test(name)) return "government-police";
  if (tags.amenity === "community_centre" || /nha van hoa|trung tam van hoa/.test(name)) return "government-culture";
  if (/mot cua|hanh chinh cong|dich vu su nghiep cong|dvsnc/.test(name)) return "government-one-stop";
  if (tags.amenity === "townhall" || /uy ban nhan dan|\bubnd\b/.test(name)) return "government-ubnd";
  if (/^so |ban quan ly|chi cuc|cuc |kho bac|toa an|vien kiem sat/.test(name)) return "government-departments";
  return "government-other";
}

function groupNamedWaterways(features: Feature<LineString>[], fallback: string): Feature<Geometry>[] {
  const named = new Map<string, Feature<LineString>[]>();
  const unnamed: Feature<LineString>[] = [];
  for (const item of features) {
    const name = String(item.properties?.name ?? "");
    if (!name || name === "Chưa có tên") unnamed.push(item);
    else named.set(normalize(name), [...(named.get(normalize(name)) ?? []), item]);
  }
  const grouped: Feature<Geometry>[] = [...named.values()].map((items) => ({
    type: "Feature", id: items[0].id, properties: items[0].properties,
    geometry: { type: "MultiLineString", coordinates: items.map((item) => item.geometry.coordinates) },
  }));
  return [...grouped, ...unnamed.map((item, index) => ({ ...item, properties: { ...item.properties, name: `${fallback} chưa đặt tên ${index + 1}` } }))];
}

function groupRoadSegments(features: Feature<LineString>[]): Feature<Geometry>[] {
  const grouped = new Map<string, Feature<LineString>[]>();
  for (const item of features) {
    const key = normalize(String(item.properties?.ref || item.properties?.name || item.id));
    grouped.set(key, [...(grouped.get(key) ?? []), item]);
  }
  return [...grouped.values()].map((items) => ({
    type: "Feature", id: items[0].id, properties: items[0].properties,
    geometry: { type: "MultiLineString", coordinates: items.map((item) => item.geometry.coordinates) },
  }));
}

function intersectsCity(item: Feature<Geometry>, boundaries: Feature<Geometry>[]): boolean {
  if (item.geometry.type === "Point") return boundaries.some((boundary) => booleanPointInPolygon(item as Feature<Point>, boundary as never));
  return boundaries.some((boundary) => {
    try { return booleanIntersects(item, boundary); } catch { return false; }
  });
}

function hydrateLayers(data: Record<string, GeoJSON.FeatureCollection>, requestedIds: string[], units: AdministrativeUnit[]): OperationalLayer[] {
  const requested = new Set(requestedIds);
  return sampleLayers.filter((layer) => layer.source === "openstreetmap" && requested.has(layer.id)).map((layer) => {
    const sourceCollection = data[layer.id] ?? { type: "FeatureCollection", features: [] };
    const collection = layer.id === "government-ubnd"
      ? enrichUbndAdministrativeTypes(sourceCollection, units)
      : sourceCollection;
    return { ...layer, data: collection, count: collection.features.length } as OperationalLayer;
  });
}

function enrichUbndAdministrativeTypes(collection: GeoJSON.FeatureCollection, units: AdministrativeUnit[]): GeoJSON.FeatureCollection {
  const unitByWardCode = new Map(units.map((unit) => [unit.wardCode, unit]));
  const boundaries = units.map((unit) => ({ unit, boundary: feature(unit.geometry) }));
  return {
    ...collection,
    features: collection.features.map((item) => {
      if (item.geometry.type !== "Point") return item;
      const wardCode = String(item.properties?.wardCode ?? "");
      const unit = unitByWardCode.get(wardCode)
        ?? boundaries.find(({ boundary }) => booleanPointInPolygon(item as Feature<Point>, boundary as never))?.unit;
      if (!unit) return item;
      return {
        ...item,
        properties: {
          ...item.properties,
          administrativeType: unit.type,
          administrativeName: unit.name,
        },
      };
    }),
  };
}

function readCache(): Record<string, GeoJSON.FeatureCollection> | null {
  try {
    const cached = JSON.parse(localStorage.getItem(CACHE_KEY) ?? "null") as { savedAt: number; data: Record<string, GeoJSON.FeatureCollection> } | null;
    return cached && Date.now() - cached.savedAt < CACHE_TTL ? cached.data : null;
  } catch { return null; }
}

function writeCache(data: Record<string, GeoJSON.FeatureCollection>) {
  try {
    const current = readCache() ?? {};
    localStorage.setItem(CACHE_KEY, JSON.stringify({ savedAt: Date.now(), data: { ...current, ...data } }));
  } catch { /* Dữ liệu lớn vẫn dùng được trong phiên hiện tại. */ }
}

function isFeature<T extends Geometry>(item: Feature<T> | null): item is Feature<T> { return item !== null; }
function waterbodyFallback(type?: string) { return type === "reservoir" ? "Hồ chứa" : type === "lake" ? "Hồ chưa đặt tên" : "Ao, hồ chưa đặt tên"; }
function facilityFallback(element: OsmElement) { return element.tags?.amenity === "police" ? "Cơ quan công an" : element.tags?.amenity === "community_centre" ? "Nhà văn hóa" : element.tags?.amenity === "townhall" ? "UBND" : "Cơ quan nhà nước"; }
