/** `seq` tăng dần trong phiên trình duyệt: khóa React ổn định khi log bị cắt bớt dòng cũ. */
export type MonitorLogEntry = { pointId: string; name: string; ip: string; status: string; time: string; timestamp: number; seq?: number };
export type MonitorLogApiEntry = { pointId?: string; ipAddress?: string | null; status?: string; latencyMs?: number | null; checkedAt?: string; receivedAt?: string };
