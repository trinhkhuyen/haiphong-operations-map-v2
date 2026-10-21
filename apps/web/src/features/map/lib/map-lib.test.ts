import { describe, expect, it } from "vitest";
import type { AdministrativeUnit } from "../../../core/types";
import { DEFAULT_HNTH_AREA_STYLES, DEFAULT_HNTH_LINE_STYLES } from "../../layers/hnth-data-provider";
import { buildOfficialAdministrativeLabelPoints, officialAdministrativeLabelsVisible } from "./administrative";
import { featureColor, featureNumber, formatMapRadius, formatSummaryArea, isValidLngLat } from "./drawing";
import { hnthFeatureId, hnthStatusColorExpression, normalizedHnthProperties } from "./hnth-layer";
import { buildOperationalPopupHtml, clusterRadiusForLevel, escapeHtml } from "./operational-layers";

describe("map/lib: lớp vận hành", () => {
  it("bán kính gom cụm 8-42 px theo mức 1-10, giới hạn ngoài khoảng", () => {
    expect([0, 1, 5, 10, 11].map(clusterRadiusForLevel)).toEqual([8, 8, 23, 42, 42]);
  });
  it("escape HTML cho popup", () => {
    expect(escapeHtml(`<a href="x">'&`)).toBe("&lt;a href=&quot;x&quot;&gt;&#39;&amp;");
  });
  it("popup: tên, các dòng chi tiết có giá trị, nguồn mặc định; nội dung được escape", () => {
    expect(buildOperationalPopupHtml("Camera <1>", { name: "Cam <A>", ipAddress: "10.0.0.1", status: "online" }))
      .toBe('<div class="map-popup"><span>Camera &lt;1&gt;</span><strong>Cam &lt;A&gt;</strong><small>IP: 10.0.0.1</small><small>Trạng thái: online</small><small>Nguồn: Dữ liệu vận hành</small></div>');
    expect(buildOperationalPopupHtml("UBND", null)).toContain("<strong>Đối tượng</strong>");
  });
});

describe("map/lib: vẽ vùng", () => {
  it("định dạng bán kính và diện tích kiểu vi-VN", () => {
    expect(formatMapRadius(950)).toBe("950 m");
    expect(formatMapRadius(1500)).toBe("1,5 km");
    expect(formatSummaryArea(637_300_000)).toBe("637,3 km²");
  });
  it("lấy màu/độ đục riêng của hình, sai kiểu thì dùng mặc định", () => {
    expect(featureColor("fillColor", "#000000")({ properties: { fillColor: "#ff0000" } })).toBe("#ff0000");
    expect(featureColor("fillColor", "#000000")({ properties: { fillColor: "red" } })).toBe("#000000");
    expect(featureNumber("fillOpacity", 0.42)({ properties: { fillOpacity: 0.2 } })).toBe(0.2);
    expect(featureNumber("fillOpacity", 0.42)({})).toBe(0.42);
  });
  it("kiểm tra tọa độ hợp lệ", () => {
    expect(isValidLngLat([106.6, 20.8])).toBe(true);
    expect(isValidLngLat([106.6, Number.NaN])).toBe(false);
    expect(isValidLngLat([106.6])).toBe(false);
    expect(isValidLngLat("106,20")).toBe(false);
  });
});

describe("map/lib: HNTH và địa giới", () => {
  it("biểu thức màu theo feature-state; trạng thái bị ẩn thành trong suốt", () => {
    const styles = { ...DEFAULT_HNTH_LINE_STYLES, lost: { ...DEFAULT_HNTH_LINE_STYLES.lost, visible: false } };
    const expression = hnthStatusColorExpression(styles) as unknown[];
    expect(expression.slice(0, 2)).toEqual(["match", ["feature-state", "hnthStatus"]]);
    expect(expression[expression.indexOf("lost") + 1]).toBe("transparent");
    expect(expression[expression.indexOf("connected") + 1]).toBe(DEFAULT_HNTH_LINE_STYLES.connected.color);
    expect(expression.at(-1)).toBe("transparent");
    expect(hnthStatusColorExpression(DEFAULT_HNTH_AREA_STYLES)).toHaveLength(9);
  });
  it("id feature HNTH: id, nếu không có thì pointId; bỏ thuộc tính undefined", () => {
    expect(hnthFeatureId({ type: "Feature", id: 7, geometry: null as never, properties: {} })).toBe(7);
    expect(hnthFeatureId({ type: "Feature", geometry: null as never, properties: { pointId: "p1" } })).toBe("p1");
    expect(hnthFeatureId({ type: "Feature", geometry: null as never, properties: {} })).toBeNull();
    expect(normalizedHnthProperties({ a: 1, b: undefined, c: null })).toEqual({ a: 1, c: null });
  });
  it("nhãn địa giới chính thức: viết tắt loại, ưu tiên các tên dễ bị che; chỉ hiện trên nền vệ tinh", () => {
    const unit = (id: number, name: string, type: string) => ({ id, name, type, coordinates: [106.7, 20.8] }) as unknown as AdministrativeUnit;
    const labels = buildOfficialAdministrativeLabelPoints([unit(1, "Đồ Sơn", "phường"), unit(2, "An Lão", "xã"), unit(3, "Bạch Long Vĩ", "đặc khu")]);
    expect(labels.features.map((item) => [item.properties?.shortType, item.properties?.priority])).toEqual([["P", true], ["X", false], ["ĐK", true]]);
    expect(officialAdministrativeLabelsVisible("satellite")).toBe(true);
    expect(officialAdministrativeLabelsVisible("standard")).toBe(false);
  });
});
