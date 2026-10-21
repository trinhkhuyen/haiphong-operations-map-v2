export type MonitorLogEntry = { pointId: string; name: string; ip: string; status: string; time: string; timestamp: number };
export type MonitorLogApiEntry = { pointId?: string; ipAddress?: string | null; status?: string; latencyMs?: number | null; checkedAt?: string; receivedAt?: string };
