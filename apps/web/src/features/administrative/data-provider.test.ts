import { describe, expect, it } from "vitest";
import type { AdministrativeUnit } from "../../core/types";
import { unitsToFeatureCollection } from "./data-provider";

describe("unitsToFeatureCollection", () => {
  it("giữ id, tên, loại, mã xã và geometry", () => {
    const geometry: GeoJSON.Polygon = { type: "Polygon", coordinates: [[[106, 20], [106.1, 20], [106.1, 20.1], [106, 20]]] };
    const units: AdministrativeUnit[] = [{ id: 7, wardCode: "31234", name: "Đồ Sơn", type: "phường", coordinates: [106.05, 20.05], geometry }];
    expect(unitsToFeatureCollection(units)).toEqual({
      type: "FeatureCollection",
      features: [{ type: "Feature", id: 7, properties: { id: 7, name: "Đồ Sơn", type: "phường", wardCode: "31234" }, geometry }],
    });
  });

  it("danh sách rỗng cho FeatureCollection rỗng", () => {
    expect(unitsToFeatureCollection([]).features).toEqual([]);
  });
});
