import { subscribeHnthStream, type HnthLivePayload } from "./hnth-realtime";

export type CameraProbeResult = {
  cameraId?: string;
  status?: string;
  channels?: number | null;
  onlineChannels?: number | null;
  channelStates?: Array<{ id: number; name?: string; online?: boolean }>;
  latencyMs?: number | null;
  reason?: string | null;
  checkedAt?: string;
  vendor?: string | null;
  model?: string | null;
};

/** Camera có listener riêng; transport SSE dùng chung với backend hiện tại. */
export function subscribeCameraResults(listener: (results: CameraProbeResult[]) => void) {
  return subscribeHnthStream((payload: HnthLivePayload) => {
    if (payload.type !== "camera-results" || !Array.isArray(payload.results)) return;
    listener(payload.results as CameraProbeResult[]);
  });
}
