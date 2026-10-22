import { describe, expect, it } from "vitest";
import { classifyImportRows, extraPointId, rosterRowErrors } from "./hnth-roster";

const wards = [
  { pointId: "hnth-branch-1", name: "UBND Ái Quốc" },
  { pointId: "hnth-branch-2", name: "UBND An Hưng" },
  { pointId: "hnth-branch-3", name: "UBND Chấn Hưng" },
];
const row = (name: string, ipAddress = "") => ({ name, ipAddress, gateway: "", modelVendor: "" });

describe("classifyImportRows", () => {
  it("nhận xã/phường theo nhiều cách viết, Trung tâm theo tên cũ/mới, còn lại là Sở/Ban/Ngành", () => {
    const { points, report } = classifyImportRows([
      row("Trung tâm Chính trị - Hành chính TP. Hải Phòng", "10.0.0.1"),
      row("Xã Ái Quốc", "10.0.0.2"),
      row("an hung"),
      row("Sở Y tế", "10.0.0.9"),
    ], wards);
    expect(points.map((point) => [point.kind, point.pointId, point.name])).toEqual([
      ["hub", "hnth-hub", "Trung tâm Chính trị - Hành chính"],
      ["ward", "hnth-branch-1", "UBND Ái Quốc"],
      ["ward", "hnth-branch-2", "UBND An Hưng"],
      ["extra", "hnth-extra-so-y-te", "Sở Y tế"],
    ]);
    expect(report).toEqual({ wards: 2, hub: true, extras: ["Sở Y tế"], duplicates: [], absentWards: 1 });
  });
  it("bỏ dòng trùng điểm và báo lại", () => {
    const { points, report } = classifyImportRows([row("UBND Ái Quốc"), row("Ái Quốc")], wards);
    expect(points).toHaveLength(1);
    expect(report.duplicates).toEqual(["Ái Quốc"]);
  });
});

describe("extraPointId / rosterRowErrors", () => {
  it("mã ổn định theo tên và tránh trùng", () => {
    const taken = new Set<string>();
    expect(extraPointId("Sở Tài nguyên & Môi trường", taken)).toBe("hnth-extra-so-tai-nguyen-moi-truong");
    expect(extraPointId("Sở Tài nguyên & Môi trường", taken)).toBe("hnth-extra-so-tai-nguyen-moi-truong-2");
  });
  it("báo IP sai và IP trùng", () => {
    const errors = rosterRowErrors([
      { pointId: "a", kind: "extra", name: "A", ipAddress: "10.0.0.1" },
      { pointId: "b", kind: "extra", name: "B", ipAddress: "10.0.0.1" },
      { pointId: "c", kind: "extra", name: "C", ipAddress: "10.0.0" },
    ]);
    expect([...errors.entries()]).toEqual([["b", 'Trùng IP với "A"'], ["c", "IP không hợp lệ"]]);
  });
});
