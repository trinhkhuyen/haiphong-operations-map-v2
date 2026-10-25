import type { CameraDevice } from "../../core/store/camera";

/** Preserve agent channel IDs even when the recorder's total is unknown. */
export function cameraChannelItems(device: CameraDevice | null): NonNullable<CameraDevice["channelStates"]> {
  if (!device) return [];
  const states = device.channelStates || [];
  if (typeof device.channels !== "number" || device.channels <= 0) return states;
  const byId = new Map(states.map((channel) => [channel.id, channel]));
  return Array.from({ length: device.channels }, (_, index) => byId.get(index + 1) || { id: index + 1, online: device.status === "online" && index < (device.onlineChannels || 0) });
}
