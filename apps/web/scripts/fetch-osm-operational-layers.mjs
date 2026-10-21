import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, unlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { booleanIntersects, booleanPointInPolygon, feature } from "@turf/turf";

const root = new URL("../", import.meta.url);
const outputPath = new URL("public/data/osm-operational-layers.json", root);
const layerOutputDirectory = new URL("public/data/osm-layers/", root);
const tempPath = join(tmpdir(), "hp-ops-osm-cache");
mkdirSync(tempPath, { recursive: true });

const bbox = "20.50,106.05,21.30,107.20";
const reuseExisting = process.env.OSM_REUSE_EXISTING === "1" && existsSync(outputPath);
const endpoints = [
  "https://lz4.overpass-api.de/api/interpreter",
  "https://z.overpass-api.de/api/interpreter",
  "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
  "https://overpass.private.coffee/api/interpreter",
];

const queries = reuseExisting ? {
  roads: [`[out:json][timeout:240];way["highway"~"^(motorway|motorway_link|trunk|primary|secondary)$"](${bbox});out tags geom;`],
} : {
  rivers: [`[out:json][timeout:240];way["waterway"="river"](${bbox});out tags geom;`],
  streams: [`[out:json][timeout:240];way["waterway"="stream"](${bbox});out tags geom;`],
  waters: gridQueries('way["natural"="water"]', 8, 8),
  roads: [`[out:json][timeout:240];way["highway"~"^(motorway|motorway_link|trunk|primary|secondary)$"](${bbox});out tags geom;`],
  facilities: process.env.OSM_FETCH_FACILITIES === "1"
    ? [`[out:json][timeout:240];(nwr["amenity"~"^(police|community_centre|townhall)$"](${bbox});nwr["office"="government"](${bbox}););out tags center;`]
    : [],
};

{
  console.log("Đang tải địa giới chính thức Hải Phòng...");
  const geometryFile = join(tempPath, "geometry.json");
  const mappingFile = join(tempPath, "mapping.json");
  download("https://bandoso.haiphong.gov.vn/data_geometry/geometry_4.json", geometryFile);
  download("https://bandoso.haiphong.gov.vn/data_geometry/mapping_4.json", mappingFile);
  const boundaries = JSON.parse(readFileSync(geometryFile, "utf8")).map((item) => {
    const boundary = feature(item.geometry);
    return { boundary, extent: geometryExtent(boundary.geometry) };
  });
  const administrativeUnits = JSON.parse(readFileSync(mappingFile, "utf8"));

  const responses = {};
  for (const [name, queryParts] of Object.entries(queries)) {
    console.log(`Đang tải lớp ${name} từ OpenStreetMap...`);
    if (name === "waters" && process.env.OSM_RECOVERED_WATER) {
      responses[name] = JSON.parse(readFileSync(process.env.OSM_RECOVERED_WATER, "utf8"));
      continue;
    }
    const elements = [];
    try {
      for (const [index, query] of queryParts.entries()) {
        const cacheVersion = name === "waters" ? "water-v2" : "global-v1";
        const file = join(tempPath, `${cacheVersion}-${name}-${index}.json`);
        let response;
        if (existsSync(file)) {
          try { response = JSON.parse(readFileSync(file, "utf8")); } catch { unlinkSync(file); }
        }
        if (!response) {
          postOverpass(query, file);
          response = JSON.parse(readFileSync(file, "utf8"));
        }
        elements.push(...response.elements);
      }
    } catch (error) {
      if (name !== "facilities") throw error;
      console.warn("Nguồn cơ quan OSM tạm thời không phản hồi; vẫn dùng 114 điểm UBND chính thức.");
    }
    responses[name] = { elements: dedupeElements(elements) };
  }

  const layers = reuseExisting ? {
    ...JSON.parse(readFileSync(outputPath, "utf8")).layers,
    "transport-expressways": collection([]),
    "transport-national-roads": collection([]),
    "transport-provincial-roads": collection([]),
  } : {
    "transport-expressways": collection([]),
    "transport-national-roads": collection([]),
    "transport-provincial-roads": collection([]),
    "hydro-rivers": collection(groupNamedWaterways(responses.rivers.elements.map(toWaterwayFeature).filter(Boolean).filter((item) => intersectsCity(item, boundaries)), "Sông")),
    "hydro-streams": collection(groupNamedWaterways(responses.streams.elements.map(toWaterwayFeature).filter(Boolean).filter((item) => intersectsCity(item, boundaries)), "Suối")),
    "hydro-waterbodies": collection(responses.waters.elements.map(toWaterbodyFeature).filter(Boolean).filter((item) => intersectsCity(item, boundaries))),
    "government-ubnd": collection([]),
    "government-culture": collection([]),
    "government-one-stop": collection([]),
    "government-police": collection([]),
    "government-departments": collection([]),
    "government-other": collection([]),
  };

  for (const element of responses.roads.elements) {
    const layerId = classifyRoad(element);
    const item = toRoadFeature(element);
    if (layerId && item && intersectsCity(item, boundaries)) layers[layerId].features.push(item);
  }
  for (const id of ["transport-expressways", "transport-national-roads", "transport-provincial-roads"]) {
    layers[id].features = groupRoadSegments(layers[id].features);
  }

  if (!reuseExisting) layers["government-ubnd"].features.push(...administrativeUnits.map((unit) => ({
    type: "Feature",
    id: `hp-ubnd-${unit.id}`,
    properties: {
      name: `UBND ${unit.tenhc}`,
      type: "townhall",
      wardCode: unit.wardCode,
      source: "Dữ liệu địa giới chính thức Hải Phòng",
      status: "active",
    },
    geometry: { type: "Point", coordinates: unit.coordinates.map(Number) },
  })));

  const seenFacilities = new Set();
  for (const element of responses.facilities?.elements ?? []) {
    const item = toFacilityFeature(element);
    if (!item || !intersectsCity(item, boundaries)) continue;
    const coordinates = item.geometry.coordinates;
    const key = `${normalize(item.properties.name)}:${coordinates.map((value) => value.toFixed(4)).join(":")}`;
    if (seenFacilities.has(key)) continue;
    seenFacilities.add(key);
    layers[classifyFacility(element)].features.push(item);
  }

  mkdirSync(new URL("public/data/", root), { recursive: true });
  const payload = { generatedAt: new Date().toISOString(), source: "OpenStreetMap", layers };
  writeFileSync(outputPath, JSON.stringify(payload));
  mkdirSync(layerOutputDirectory, { recursive: true });
  for (const [id, data] of Object.entries(layers)) {
    writeFileSync(new URL(`${id}.json`, layerOutputDirectory), JSON.stringify(data));
  }
  console.log(`Đã ghi ${outputPath.pathname}`);
  for (const [id, data] of Object.entries(layers)) console.log(`${id}: ${data.features.length}`);
}

function download(url, destination) {
  execFileSync("curl.exe", ["-L", "--fail", "--silent", "--show-error", "--retry", "3", "--retry-delay", "4", "--max-time", "240", url, "-o", destination], { stdio: "inherit" });
}

function postOverpass(query, destination) {
  let lastError;
  for (const endpoint of endpoints) {
    try {
      execFileSync("curl.exe", ["-L", "--fail", "--silent", "--show-error", "--max-time", "180", "-A", "HaiPhong-Operations-Map/0.1", "--get", "--data-urlencode", `data=${query}`, endpoint, "-o", destination], { stdio: "inherit" });
      return;
    } catch (error) { lastError = error; }
  }
  throw lastError;
}

function collection(features) { return { type: "FeatureCollection", features }; }
function dedupeElements(elements) { return [...new Map(elements.map((item) => [`${item.type}-${item.id}`, item])).values()]; }
function gridQueries(selector, rows, columns) {
  const south = 20.50, west = 106.05, north = 21.30, east = 107.20;
  const result = [];
  for (let row = 0; row < rows; row += 1) for (let column = 0; column < columns; column += 1) {
    const box = [
      south + (north - south) * row / rows,
      west + (east - west) * column / columns,
      south + (north - south) * (row + 1) / rows,
      west + (east - west) * (column + 1) / columns,
    ].map((value) => value.toFixed(5)).join(",");
    result.push(`[out:json][timeout:120];${selector}(${box});out tags geom;`);
  }
  return result;
}
function normalize(value = "") { return value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/đ/g, "d").toLowerCase(); }

function toWaterwayFeature(element) {
  if (!element.geometry || element.geometry.length < 2) return null;
  return {
    type: "Feature", id: `osm-${element.type}-${element.id}`,
    properties: { name: element.tags?.name || element.tags?.["name:vi"] || "Chưa có tên", type: element.tags?.waterway, osmId: element.id, source: "OpenStreetMap" },
    geometry: { type: "LineString", coordinates: element.geometry.map(({ lon, lat }) => [lon, lat]) },
  };
}

function toRoadFeature(element) {
  if (!element.geometry || element.geometry.length < 2) return null;
  const tags = element.tags ?? {};
  const ref = tags.ref ?? "";
  return {
    type: "Feature", id: `osm-${element.type}-${element.id}`,
    properties: { name: tags.name || tags["name:vi"] || ref || "Tuyến chưa đặt tên", ref, type: tags.highway, osmId: element.id, source: "OpenStreetMap" },
    geometry: { type: "LineString", coordinates: element.geometry.map(({ lon, lat }) => [lon, lat]) },
  };
}

function classifyRoad(element) {
  const tags = element.tags ?? {};
  const text = normalize(`${tags.ref ?? ""} ${tags.name ?? ""} ${tags["name:vi"] ?? ""}`);
  if (tags.highway === "motorway" || tags.highway === "motorway_link" || /(^|[;\s])ct[.\s-]?\d/.test(text) || /cao toc/.test(text)) return "transport-expressways";
  if (/(^|[;\s])ql[.\s-]?\d/.test(text) || /quoc lo/.test(text)) return "transport-national-roads";
  if (/(^|[;\s])(dt|tl)[.\s-]?\d/.test(text) || /duong tinh|tinh lo/.test(text)) return "transport-provincial-roads";
  return null;
}

function toWaterbodyFeature(element) {
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

function toFacilityFeature(element) {
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

function classifyFacility(element) {
  const tags = element.tags ?? {};
  const name = normalize(tags.name || tags["name:vi"] || "");
  if (tags.amenity === "police" || /cong an|canh sat/.test(name)) return "government-police";
  if (tags.amenity === "community_centre" || /nha van hoa|trung tam van hoa/.test(name)) return "government-culture";
  if (/mot cua|hanh chinh cong|dich vu su nghiep cong|dvsnc/.test(name)) return "government-one-stop";
  if (tags.amenity === "townhall" || /uy ban nhan dan|\bubnd\b/.test(name)) return "government-ubnd";
  if (/^so |ban quan ly|chi cuc|cuc |kho bac|toa an|vien kiem sat/.test(name)) return "government-departments";
  return "government-other";
}

function groupNamedWaterways(features, fallback) {
  const named = new Map();
  const unnamed = [];
  for (const item of features) {
    const name = String(item.properties?.name ?? "");
    if (!name || name === "Chưa có tên") unnamed.push(item);
    else named.set(normalize(name), [...(named.get(normalize(name)) ?? []), item]);
  }
  const grouped = [...named.values()].map((items) => ({
    type: "Feature", id: items[0].id, properties: items[0].properties,
    geometry: { type: "MultiLineString", coordinates: items.map((item) => item.geometry.coordinates) },
  }));
  return [...grouped, ...unnamed.map((item, index) => ({ ...item, properties: { ...item.properties, name: `${fallback} chưa đặt tên ${index + 1}` } }))];
}

function groupRoadSegments(features) {
  const grouped = new Map();
  for (const item of features) {
    const key = normalize(String(item.properties?.ref || item.properties?.name || item.id));
    grouped.set(key, [...(grouped.get(key) ?? []), item]);
  }
  return [...grouped.values()].map((items) => ({
    type: "Feature", id: items[0].id, properties: items[0].properties,
    geometry: { type: "MultiLineString", coordinates: items.map((item) => item.geometry.coordinates) },
  }));
}

function intersectsCity(item, boundaries) {
  const extent = geometryExtent(item.geometry);
  const candidates = boundaries.filter((entry) => extentsOverlap(extent, entry.extent));
  if (item.geometry.type === "Point") return candidates.some((entry) => booleanPointInPolygon(item, entry.boundary));
  return candidates.some((entry) => {
    try { return booleanIntersects(item, entry.boundary); } catch { return false; }
  });
}

function geometryExtent(geometry) {
  const points = [];
  const walk = (value) => {
    if (!Array.isArray(value)) return;
    if (typeof value[0] === "number" && typeof value[1] === "number") points.push(value);
    else value.forEach(walk);
  };
  walk(geometry.coordinates);
  return [Math.min(...points.map((point) => point[0])), Math.min(...points.map((point) => point[1])), Math.max(...points.map((point) => point[0])), Math.max(...points.map((point) => point[1]))];
}
function extentsOverlap(a, b) { return a[0] <= b[2] && a[2] >= b[0] && a[1] <= b[3] && a[3] >= b[1]; }

function waterbodyFallback(type) { return type === "reservoir" ? "Hồ chứa" : type === "lake" ? "Hồ chưa đặt tên" : "Ao, hồ chưa đặt tên"; }
function facilityFallback(element) { return element.tags?.amenity === "police" ? "Cơ quan công an" : element.tags?.amenity === "community_centre" ? "Nhà văn hóa" : element.tags?.amenity === "townhall" ? "UBND" : "Cơ quan nhà nước"; }
