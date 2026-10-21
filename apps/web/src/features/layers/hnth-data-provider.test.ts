import { describe, expect, it } from "vitest";
import type { OperationalLayer } from "../../core/types";
import { applyHnthPointOverrides, HNTH_LAYER_ID, HNTH_STATUS_LABELS, normalizeHnthStatus, type HnthPointOverride } from "./hnth-data-provider";

function hnthLayer(): OperationalLayer {
  return {
    id: HNTH_LAYER_ID, name: "HNTH", category: "network", group: "monitoring", color: "#fff", icon: "radio", visible: true, count: 2, source: "derived",
    data: {
      type: "FeatureCollection",
      features: [
        { type: "Feature", id: "hnth-a", geometry: { type: "Point", coordinates: [106, 20] }, properties: { pointId: "hnth-a", ipAddress: "10.0.0.1", gateway: "10.0.0.254", status: "unknown" } },
        { type: "Feature", id: "hnth-b", geometry: { type: "Point", coordinates: [106, 21] }, properties: { pointId: "hnth-b", ipAddress: "10.0.0.2", gateway: "10.0.0.254", status: "unknown" } },
      ],
    },
  };
}

const override = (patch: Partial<HnthPointOverride>): HnthPointOverride => ({ ipAddress: "10.0.0.9", gateway: "", model: "", status: "unknown", ...patch });

describe("normalizeHnthStatus", () => {
  it("giữ nguyên 4 trạng thái hợp lệ", () => {
    for (const status of ["unknown", "unconnected", "connected", "lost"] as const) expect(normalizeHnthStatus(status)).toBe(status);
  });
  it("đổi trạng thái cũ disconnected thành lost", () => {
    expect(normalizeHnthStatus("disconnected")).toBe("lost");
  });
  it("giá trị lạ thành unknown", () => {
    for (const value of ["online", "", null, undefined, 1]) expect(normalizeHnthStatus(value)).toBe("unknown");
  });
});

describe("applyHnthPointOverrides", () => {
  it("không có override thì trả lại đúng object cũ", () => {
    const layer = hnthLayer();
    expect(applyHnthPointOverrides(layer, {})).toBe(layer);
  });

  it("trim IP, giữ gateway cũ khi override rỗng, gắn nhãn trạng thái", () => {
    const layer = hnthLayer();
    const result = applyHnthPointOverrides(layer, { "hnth-a": override({ ipAddress: "  10.0.0.9 ", gateway: "  ", status: "connected" }) });
    const props = result.data.features[0].properties!;
    expect(props.ipAddress).toBe("10.0.0.9");
    expect(props.gateway).toBe("10.0.0.254");
    expect(props.status).toBe("connected");
    expect(props.statusLabel).toBe(HNTH_STATUS_LABELS.connected);
    // Điểm không có override giữ nguyên tham chiếu.
    expect(result.data.features[1]).toBe(layer.data.features[1]);
  });

  it("trạng thái unknown thì bỏ statusLabel, IP rỗng vẫn hợp lệ", () => {
    const result = applyHnthPointOverrides(hnthLayer(), { "hnth-b": override({ ipAddress: "", gateway: "192.168.1.1", status: "unknown" }) });
    const props = result.data.features[1].properties!;
    expect(props.ipAddress).toBe("");
    expect(props.gateway).toBe("192.168.1.1");
    expect(props.statusLabel).toBeUndefined();
  });
});
