// Danh sách điểm cầu theo phiên họp: phân loại dòng Import (xã/phường, Trung tâm,
// Sở/Ban/Ngành), sinh mã cho Sở/Ban/Ngành và chuyển lớp HNTH hiện tại thành bản nháp.
// Hàm thuần, không gọi API, để unit test.
import type { HnthRosterPoint, HnthRosterPointKind } from "../../core/realtime/hnth-live-store";
import { HNTH_HUB_NAME } from "../layers/hnth-data-provider";
import type { HnthImportRow } from "./hnth-import-export";
import type { HnthPointFeature } from "./hnth-types";
import { normalizeSearchText } from "./hnth-focus";

export type WardRef = { pointId: string; name: string };
export type RosterImportReport = { wards: number; hub: boolean; extras: string[]; duplicates: string[]; absentWards: number };

export const ROSTER_KIND_LABELS: Record<HnthRosterPointKind, string> = { hub: "Trung tâm", ward: "Xã/phường", extra: "Sở/Ban/Ngành" };
const IPV4 = /^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$/;
export const isValidIpv4 = (value: string) => IPV4.test(value.trim());

/** "UBND Ái Quốc", "Xã Ái Quốc", "Ái Quốc" -> "ái quốc" (giữ dấu để không nhầm xã khác tên chỉ khác dấu). */
function wardKey(name: string) {
  return name.normalize("NFC").toLocaleLowerCase("vi")
    .replace(/^\s*(ubnd|ủy ban nhân dân|uỷ ban nhân dân)\s+/u, "")
    .replace(/^\s*(xã|phường|đặc khu|thị trấn|x\.|p\.)\s*/u, "")
    .replace(/\s+/g, " ").trim();
}

const isHubName = (name: string) => normalizeSearchText(name).includes("trung tam chinh tri");

/** Mã ổn định theo tên: cùng một Sở ở phiên sau vẫn cùng mã, giữ được lịch sử log. */
export function extraPointId(name: string, taken: Set<string>) {
  const slug = normalizeSearchText(name).replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 60) || "diem";
  let id = `hnth-extra-${slug}`;
  for (let index = 2; taken.has(id); index += 1) id = `hnth-extra-${slug}-${index}`;
  taken.add(id);
  return id;
}

/** Phân loại các dòng Import thành danh sách phiên họp + báo cáo khớp. */
export function classifyImportRows(rows: HnthImportRow[], wards: WardRef[]): { points: HnthRosterPoint[]; report: RosterImportReport } {
  const exact = new Map(wards.map((ward) => [wardKey(ward.name), ward]));
  // Khớp không dấu chỉ dùng khi không mơ hồ (một khóa không dấu ứng với đúng một xã/phường).
  const loose = new Map<string, WardRef | null>();
  for (const ward of wards) {
    const key = normalizeSearchText(wardKey(ward.name));
    loose.set(key, loose.has(key) ? null : ward);
  }
  const points: HnthRosterPoint[] = [];
  const usedIds = new Set<string>();
  const report: RosterImportReport = { wards: 0, hub: false, extras: [], duplicates: [], absentWards: 0 };
  for (const row of rows) {
    const name = row.name.trim();
    if (!name) continue;
    const base = { ipAddress: row.ipAddress.trim(), gateway: row.gateway.trim(), modelVendor: row.modelVendor.trim() };
    let point: HnthRosterPoint;
    if (isHubName(name)) point = { pointId: "hnth-hub", kind: "hub", name: HNTH_HUB_NAME, ...base };
    else {
      const ward = exact.get(wardKey(name)) ?? loose.get(normalizeSearchText(wardKey(name))) ?? null;
      point = ward ? { pointId: ward.pointId, kind: "ward", name: ward.name, ...base } : { pointId: extraPointId(name, new Set(usedIds)), kind: "extra", name, ...base };
    }
    if (usedIds.has(point.pointId)) { report.duplicates.push(name); continue; }
    usedIds.add(point.pointId);
    points.push(point);
    if (point.kind === "hub") report.hub = true;
    else if (point.kind === "ward") report.wards += 1;
    else report.extras.push(point.name);
  }
  report.absentWards = wards.length - report.wards;
  return { points, report };
}

/** Bản nháp từ các điểm đang hiển thị (để lưu danh sách hiện tại thành danh sách mới). */
export function rosterFromLayerPoints(points: HnthPointFeature[]): HnthRosterPoint[] {
  const kindOf = (role: unknown): HnthRosterPointKind => role === "hub" ? "hub" : role === "extra" ? "extra" : "ward";
  return points.map((item) => ({
    pointId: String(item.properties?.pointId ?? item.id ?? ""),
    kind: kindOf(item.properties?.role),
    name: String(item.properties?.name ?? ""),
    ipAddress: String(item.properties?.ipAddress ?? "").trim(),
    gateway: String(item.properties?.gateway ?? "").trim(),
    modelVendor: String(item.properties?.model ?? item.properties?.modelVendor ?? "").trim(),
  })).filter((point) => point.pointId);
}

/** Lỗi theo từng dòng để tô đỏ trong popup sửa danh sách (backend kiểm tra lại khi lưu). */
export function rosterRowErrors(points: HnthRosterPoint[]): Map<string, string> {
  const errors = new Map<string, string>();
  const ips = new Map<string, string>();
  for (const point of points) {
    const ip = point.ipAddress.trim();
    if (!point.name.trim()) errors.set(point.pointId, "Thiếu tên điểm");
    else if (ip && !isValidIpv4(ip)) errors.set(point.pointId, "IP không hợp lệ");
    else if (ip && ips.has(ip)) errors.set(point.pointId, `Trùng IP với "${ips.get(ip)}"`);
    if (ip) ips.set(ip, point.name);
  }
  return errors;
}
