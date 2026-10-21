export type LiveStatus = "online" | "offline" | "unknown";

export interface PingResult {
  pointId: string;
  ipAddress: string;
  status: LiveStatus;
  latencyMs: number | null;
  checkedAt: string;
}

export interface AgentSnapshot {
  agentId: string;
  timestamp: string;
  results: PingResult[];
}

export interface AgentHeartbeat {
  agentId: string;
  timestamp: string;
}
