import type { Feature, Point } from "geojson";

export type HnthPointFeature = Feature<Point, Record<string, unknown>>;
/** Điểm được gán cho một Agent (agents.monitor_config.points). */
export type HnthAssignedPoint = { pointId: string; name?: string; ipAddress: string; modelVendor?: string };
export type HnthAgentRecord = { agentId: string; name: string; status: string; heartbeatSeconds?: number; monitorConfig?: { points?: HnthAssignedPoint[]; [key: string]: unknown } };
export type HnthLiveAgent = { agentId: string; name: string; status: string; version?: string };
export type DiscoveredIp = { ipAddress: string; model?: string; vendor?: string; modelVendor?: string; macAddress?: string };
