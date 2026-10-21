export type AgentStatus = "online" | "offline" | "unknown";
export type ConnectionStatus = "unknown" | "unconnected" | "connected" | "lost";
export type OperatorCommandType = "scan-local-network" | "test-point" | "point-config" | "monitor-start" | "monitor-stop" | "agent-update";

export declare const AGENT_STATUSES: readonly AgentStatus[];
export declare const CONNECTION_STATUSES: readonly ConnectionStatus[];
export declare const OPERATOR_COMMAND_TYPES: readonly OperatorCommandType[];
export declare const EXE_VERSION_SCAN_BYTES: number;

export declare function toConnectionStatus(agentStatus: unknown, hasIp: boolean): ConnectionStatus;
export declare function classifyProbeResult(successful: number, total: number): AgentStatus;
export declare function readExeVersion(bytes: Uint8Array): string | null;
export declare function compareVersions(a: string, b: string): number;

/** @deprecated Dùng AgentStatus. */
export type LiveStatus = AgentStatus;

export interface PingResult {
  pointId: string;
  ipAddress: string;
  status: AgentStatus;
  latencyMs: number | null;
  packetLossPct?: number;
  jitterMs?: number;
  checkedAt: string;
}
