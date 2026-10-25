import type { AppSlice } from "./types";

export type CameraStatus = "unknown" | "online" | "offline" | "unsupported" | "credentials_required";

export type CameraDevice = {
  id: string;
  name: string;
  serialNumber: string;
  username: string;
  password?: string;
  ipAddress?: string | null;
  vendor?: string | null;
  model?: string | null;
  devicePort?: number | null;
  httpPort?: number | null;
  streamPort?: number | null;
  connectionMethod?: string;
  autoConnect?: boolean;
  lastError?: string | null;
  checkedAt?: string | null;
  channels: number | null;
  onlineChannels?: number | null;
  channelStates?: Array<{ id: number; name?: string; online?: boolean }>;
  channelNames?: Record<string, string>;
  latencyMs?: number | null;
  status: CameraStatus;
  /** Mã wardCode của mốc UBND; giữ tên API cũ để tương thích payload. */
  administrativeId: string | null;
  longitude: number | null;
  latitude: number | null;
  updatedAt: string;
};

export type CameraLog = {
  id: string;
  deviceId: string;
  message: string;
  level: "info" | "success" | "error";
  createdAt: string;
};

export type CameraSlice = {
  cameraDevices: CameraDevice[];
  selectedCameraId: string | null;
  cameraLogs: CameraLog[];
  setCameraDevices: (devices: CameraDevice[]) => void;
  upsertCameraDevice: (device: CameraDevice) => void;
  removeCameraDevice: (id: string) => void;
  selectCamera: (id: string | null) => void;
  updateCameraDevice: (id: string, patch: Partial<CameraDevice>) => void;
  appendCameraLog: (deviceId: string, message: string, level?: CameraLog["level"]) => void;
};

export const createCameraSlice: AppSlice<CameraSlice> = (set) => ({
  cameraDevices: [],
  selectedCameraId: null,
  cameraLogs: [],
  setCameraDevices: (cameraDevices) => set({ cameraDevices }),
  upsertCameraDevice: (device) => set((state) => ({
    cameraDevices: [device, ...state.cameraDevices.filter((item) => item.id !== device.id)],
  })),
  removeCameraDevice: (id) => set((state) => ({
    cameraDevices: state.cameraDevices.filter((item) => item.id !== id),
    selectedCameraId: state.selectedCameraId === id ? null : state.selectedCameraId,
    cameraLogs: state.cameraLogs.filter((item) => item.deviceId !== id),
  })),
  selectCamera: (selectedCameraId) => set({ selectedCameraId }),
  updateCameraDevice: (id, patch) => set((state) => ({
    cameraDevices: state.cameraDevices.map((item) => item.id === id ? { ...item, ...patch } : item),
  })),
  appendCameraLog: (deviceId, message, level = "info") => set((state) => ({
    cameraLogs: [{ id: `camera-log-${Date.now()}`, deviceId, message, level, createdAt: new Date().toISOString() }, ...state.cameraLogs].slice(0, 300),
  })),
});
