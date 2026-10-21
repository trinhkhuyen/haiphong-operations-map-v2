import type { MapSearchTarget } from "../../core/types";

interface NominatimSearchResult {
  place_id: number;
  display_name: string;
  lat: string;
  lon: string;
  boundingbox?: [string, string, string, string];
  category?: string;
  type?: string;
}

export interface PlaceSearchResult extends MapSearchTarget {
  category: string;
}

const cache = new Map<string, PlaceSearchResult[]>();
let lastRequestAt = 0;

const categoryLabels: Record<string, string> = {
  amenity: "Địa điểm",
  building: "Công trình",
  highway: "Tuyến đường",
  historic: "Di tích",
  leisure: "Giải trí",
  natural: "Tự nhiên",
  place: "Địa danh",
  railway: "Đường sắt",
  shop: "Cửa hàng",
  tourism: "Du lịch",
  waterway: "Sông ngòi",
};

export async function searchHaiphongPlaces(query: string, signal?: AbortSignal): Promise<PlaceSearchResult[]> {
  const normalizedQuery = query.trim().replace(/\s+/g, " ");
  const cacheKey = normalizedQuery.toLocaleLowerCase("vi-VN");
  const cached = cache.get(cacheKey);
  if (cached) return cached;

  // The public Nominatim service permits a maximum of one request per second.
  // Searching is submit-only (not autocomplete) and cached in memory.
  const waitTime = Math.max(0, 1000 - (Date.now() - lastRequestAt));
  if (waitTime > 0) await abortableDelay(waitTime, signal);

  const endpoint = import.meta.env.VITE_GEOCODING_ENDPOINT ?? "https://nominatim.openstreetmap.org/search";
  const url = new URL(endpoint);
  url.searchParams.set("q", normalizedQuery);
  url.searchParams.set("format", "jsonv2");
  url.searchParams.set("addressdetails", "1");
  url.searchParams.set("accept-language", "vi");
  url.searchParams.set("countrycodes", "vn");
  url.searchParams.set("limit", "8");
  // Covers the expanded Hải Phòng area and keeps similarly named places in
  // other provinces out of the result list.
  url.searchParams.set("viewbox", "105.75,21.30,107.25,20.45");
  url.searchParams.set("bounded", "1");

  lastRequestAt = Date.now();
  const response = await fetch(url, { signal });
  if (!response.ok) throw new Error(`Geocoding failed with status ${response.status}`);
  const payload = await response.json() as NominatimSearchResult[];
  const results = payload.map(toPlaceSearchResult).filter((result): result is PlaceSearchResult => result !== null);
  cache.set(cacheKey, results);
  return results;
}

function toPlaceSearchResult(result: NominatimSearchResult): PlaceSearchResult | null {
  const longitude = Number(result.lon);
  const latitude = Number(result.lat);
  if (!Number.isFinite(longitude) || !Number.isFinite(latitude)) return null;

  const parts = result.display_name.split(",").map((part) => part.trim()).filter(Boolean);
  const name = parts.shift() ?? result.display_name;
  const bounds = result.boundingbox?.map(Number);
  const bbox = bounds?.length === 4 && bounds.every(Number.isFinite)
    ? [bounds[2], bounds[0], bounds[3], bounds[1]] as [number, number, number, number]
    : undefined;

  return {
    id: String(result.place_id),
    name,
    detail: parts.join(", "),
    coordinates: [longitude, latitude],
    bbox,
    category: categoryLabels[result.category ?? ""] ?? humanizeType(result.type),
  };
}

function humanizeType(type?: string) {
  if (!type) return "Địa điểm";
  return type.replaceAll("_", " ");
}

function abortableDelay(milliseconds: number, signal?: AbortSignal) {
  return new Promise<void>((resolve, reject) => {
    const timeout = window.setTimeout(resolve, milliseconds);
    signal?.addEventListener("abort", () => {
      window.clearTimeout(timeout);
      reject(new DOMException("Aborted", "AbortError"));
    }, { once: true });
  });
}
