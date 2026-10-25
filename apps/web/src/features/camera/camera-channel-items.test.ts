import { describe, expect, it } from "vitest";
import type { CameraDevice } from "../../core/store/camera";
import { cameraChannelItems } from "./camera-channel-items";

describe("cameraChannelItems", () => {
  it("shows a verified sparse P2P channel when total channels are unknown", () => {
    const device = {
      status: "online", channels: null, onlineChannels: 1,
      channelStates: [{ id: 2, name: "Kênh 2", online: true, stateSource: "rtsp-track-verified" }],
    } as unknown as CameraDevice;
    expect(cameraChannelItems(device)).toEqual(device.channelStates);
    expect(cameraChannelItems(device).filter((channel) => channel.online)).toHaveLength(1);
  });

  it("maps known channels by ID, not array position", () => {
    const device = {
      status: "online", channels: 3, onlineChannels: 1,
      channelStates: [{ id: 2, name: "Kênh 2", online: true }],
    } as CameraDevice;
    expect(cameraChannelItems(device).map((channel) => channel.id)).toEqual([1, 2, 3]);
    expect(cameraChannelItems(device)[1].name).toBe("Kênh 2");
  });
});
