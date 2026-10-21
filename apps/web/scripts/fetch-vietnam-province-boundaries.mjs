import { writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { featureCollection, point, pointOnFeature, simplify } from "@turf/turf";

const SOURCE_URL = new URL(
  "https://raw.githubusercontent.com/adminvsrm/GISData/main/Vietnam Administrative Divisions (Post-2025) - Đơn vị hành chính Việt Nam (Từ 2025)/Provinces.geojson",
).toString();

// Giữ nhãn ba tỉnh lân cận ở vị trí dễ đọc trong khung mặc định Hải Phòng.
// Các tỉnh/thành còn lại tự lấy một điểm nằm bên trong địa giới.
const LABEL_COORDINATE_OVERRIDES = new Map([
  ["Bắc Ninh", [106.205, 21.115]],
  ["Hưng Yên", [106.205, 20.695]],
  ["Quảng Ninh", [106.92, 21.08]],
  // Đặt nhãn hai địa phương trên phần đất liền; các quần đảo đã có nhãn riêng.
  ["Đà Nẵng", [108.205, 16.055]],
  ["Khánh Hòa", [109.045, 12.35]],
]);

// Nhãn hai quần đảo dùng cách ghi trên bản đồ chính thức của Việt Nam.
// Hình học các đảo đã nằm trong địa giới Đà Nẵng và Khánh Hòa của nguồn dữ liệu;
// các điểm dưới đây chỉ đặt nhãn, không biểu diễn đường biên hay phạm vi vùng biển.
const ARCHIPELAGO_LABELS = [
  {
    name: "QĐ. Hoàng Sa\n(Đà Nẵng - Việt Nam)",
    coordinates: [112.02, 16.38],
  },
  {
    name: "QĐ. Trường Sa\n(Khánh Hòa - Việt Nam)",
    coordinates: [114.55, 9.72],
  },
];

// Nguồn hiện gắn nhầm tên "Lạng Sơn" cho mã 31; mã này là Đồng Tháp.
const PROVINCE_NAME_CORRECTIONS = new Map([["31", "Đồng Tháp"]]);

const response = await fetch(SOURCE_URL);
if (!response.ok) {
  throw new Error(`Không tải được dữ liệu tỉnh/thành (${response.status}).`);
}

const source = await response.json();
const boundaries = source.features
  .filter((item) => item.properties?.TinhThanh !== "Hải Phòng")
  .map((item) => {
    const name = PROVINCE_NAME_CORRECTIONS.get(String(item.properties.Ma)) ?? item.properties.TinhThanh;
    const simplified = simplify(item, { tolerance: 0.001, highQuality: true, mutate: false });
    simplified.properties = { name, kind: "boundary" };
    return simplified;
  });

const expectedProvinceCount = source.features.length - 1;
if (boundaries.length !== expectedProvinceCount) {
  throw new Error(`Chỉ tìm thấy ${boundaries.length}/${expectedProvinceCount} tỉnh/thành ngoài Hải Phòng.`);
}

const labels = boundaries.map((boundary) => {
  const name = boundary.properties.name;
  const override = LABEL_COORDINATE_OVERRIDES.get(name);
  if (override) return point(override, { name, kind: "label" });
  const label = pointOnFeature(boundary);
  label.properties = { name, kind: "label" };
  return label;
});

const archipelagoLabels = ARCHIPELAGO_LABELS.map(({ name, coordinates }) =>
  point(coordinates, { name, kind: "archipelago-label" }),
);

const output = {
  ...featureCollection([...boundaries, ...labels, ...archipelagoLabels]),
  metadata: {
    source: SOURCE_URL,
    dataset: "GISData - Vietnam Administrative Divisions (Post-2025)",
    generatedAt: new Date().toISOString(),
    simplificationTolerance: 0.001,
  },
};

const destination = fileURLToPath(new URL("../public/data/vietnam-provinces.geojson", import.meta.url));
await writeFile(destination, `${JSON.stringify(output)}\n`, "utf8");
console.log(
  `Đã tạo ${destination} với ${boundaries.length} đường biên, ${labels.length} nhãn tỉnh/thành và ${archipelagoLabels.length} nhãn quần đảo.`,
);
