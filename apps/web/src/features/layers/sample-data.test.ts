import { describe, expect, it } from "vitest";
import { createLayerCatalog, loadBundledOperationalLayers, sampleLayers } from "./sample-data";

describe("createLayerCatalog", () => {
  it("trả đủ các lớp, tất cả tắt, chưa có dữ liệu", () => {
    const catalog = createLayerCatalog();
    expect(catalog.map((layer) => layer.id)).toEqual(sampleLayers.map((layer) => layer.id));
    for (const layer of catalog) {
      expect(layer.visible).toBe(false);
      expect(layer.count).toBe(0);
      expect(layer.data.features).toEqual([]);
    }
  });
});

describe("loadBundledOperationalLayers", () => {
  it("chỉ trả lớp demo được yêu cầu", () => {
    const demoIds = sampleLayers.filter((layer) => layer.source === "demo").map((layer) => layer.id);
    const otherIds = sampleLayers.filter((layer) => layer.source !== "demo").map((layer) => layer.id);
    const result = loadBundledOperationalLayers([...demoIds.slice(0, 1), ...otherIds, "khong-ton-tai"]);
    expect(result.map((layer) => layer.id)).toEqual(demoIds.slice(0, 1));
  });

  it("clone sâu dữ liệu, sửa kết quả không ảnh hưởng dữ liệu gốc", () => {
    const demo = sampleLayers.find((layer) => layer.source === "demo");
    if (!demo) return;
    const [copy] = loadBundledOperationalLayers([demo.id]);
    expect(copy.data).toEqual(demo.data);
    expect(copy.data).not.toBe(demo.data);
    copy.data.features.push({ type: "Feature", geometry: { type: "Point", coordinates: [0, 0] }, properties: {} });
    expect(demo.data.features.length).toBe(copy.data.features.length - 1);
  });
});
