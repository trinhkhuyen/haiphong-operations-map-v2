import { describe, expect, it } from "vitest";
import { parseCsv, parseHnthCsv } from "./HnthPanel";

describe("parseCsv", () => {
  it("tách ô, xử lý ngoặc kép, dấu phẩy và ngoặc kép lồng", () => {
    expect(parseCsv('a,"b,c","d ""x"""\r\n1,2,3')).toEqual([["a", "b,c", 'd "x"'], ["1", "2", "3"]]);
  });
  it("bỏ dòng trống, giữ dòng cuối không có xuống dòng", () => {
    expect(parseCsv("a,b\n\n , \nc,d")).toEqual([["a", "b"], ["c", "d"]]);
  });
  it("cho phép xuống dòng trong ô có ngoặc kép", () => {
    expect(parseCsv('"dòng 1\ndòng 2",x')).toEqual([["dòng 1\ndòng 2", "x"]]);
  });
});

describe("parseHnthCsv", () => {
  it("nhận header tiếng Việt có dấu và BOM", () => {
    const csv = "﻿Tên điểm,Địa chỉ IP,Gateway,Model/Vendor\nUBND Đồ Sơn,10.0.0.5,10.0.0.1,Cisco\n";
    expect(parseHnthCsv(csv)).toEqual([{ name: "UBND Đồ Sơn", ipAddress: "10.0.0.5", gateway: "10.0.0.1", modelVendor: "Cisco" }]);
  });
  it("header tiếng Anh, thiếu cột gateway thì mặc định 192.168.1.1, trim giá trị", () => {
    expect(parseHnthCsv("name,ip\n  Điểm A  , 10.0.0.9 \n")).toEqual([{ name: "Điểm A", ipAddress: "10.0.0.9", gateway: "192.168.1.1", modelVendor: "" }]);
  });
  it("bỏ dòng không có tên điểm", () => {
    expect(parseHnthCsv("Tên điểm,IP\n,10.0.0.1\nB,\n")).toEqual([{ name: "B", ipAddress: "", gateway: "192.168.1.1", modelVendor: "" }]);
  });
  it("chỉ có header thì trả rỗng", () => {
    expect(parseHnthCsv("Tên điểm,IP\n")).toEqual([]);
  });
  it("thiếu cột Tên điểm thì báo lỗi", () => {
    expect(() => parseHnthCsv("IP,Gateway\n10.0.0.1,10.0.0.254\n")).toThrow("CSV phải có cột Tên điểm");
  });
});
