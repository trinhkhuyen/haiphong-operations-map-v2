import type { FeatureCollection, Geometry } from "geojson";
import type { GeoJSONStoreFeatures } from "terra-draw";

export type LayerCategory = "camera" | "facility" | "transport" | "hydrology" | "network";
export type LayerGroup = "monitoring" | "government" | "transport" | "hydrology";

export interface OperationalLayer {
  id: string;
  name: string;
  category: LayerCategory;
  group: LayerGroup;
  color: string;
  icon: string;
  visible: boolean;
  count: number;
  data: FeatureCollection<Geometry>;
  geometryMode?: "point" | "line";
  source?: "demo" | "openstreetmap" | "derived";
}

export type DrawMode = "select" | "polygon" | "rectangle" | "circle" | "linestring" | "multilinestring" | "text" | "icon" | null;

export type ZoneMode = "administrative" | "draw" | "info";

export type BaseMapMode = "standard" | "satellite" | "terrain";

export interface DrawFeatureInfo {
  id: string | number;
  kind: "polygon" | "rectangle" | "circle" | "line" | "multiline";
  areaSquareMeters?: number;
  perimeterMeters: number;
  radiusMeters?: number;
  center: [number, number];
}

export interface TextAnnotation {
  id: string;
  text: string;
  coordinates: [number, number];
  color: string;
  name?: string;
  visible?: boolean;
  saved?: boolean;
}

export type MapIconKey = "government" | "place" | "tourism" | "temple" | "police" | "stadium" | "hospital" | "school" | "airport" | "port";

export interface IconAnnotation {
  id: string;
  icon: MapIconKey;
  coordinates: [number, number];
  color: string;
  name?: string;
  visible?: boolean;
  saved?: boolean;
}

export interface SavedDrawFeature {
  id: string;
  featureId: string | number;
  name: string;
  visible: boolean;
  feature: GeoJSONStoreFeatures;
  createdAt: number;
  updatedAt: number;
}

export type SavedObjectKind = "geometry" | "text" | "icon";

export interface MapSearchTarget {
  id: string;
  name: string;
  detail: string;
  coordinates: [number, number];
  bbox?: [number, number, number, number];
}

export interface SavedMapViewport {
  center: [number, number];
  zoom: number;
  bearing: number;
  pitch: number;
}

export interface AdministrativeUnit {
  id: number;
  wardCode: string;
  name: string;
  type: "xã" | "phường" | "đặc khu";
  coordinates: [number, number];
  geometry: GeoJSON.Geometry;
}
