// Kiểm tra dữ liệu chủ điểm cầu (Import) và danh sách mã điểm của phiên họp. Hàm thuần để unit test.
import { isIP } from "node:net";

export const ROSTER_POINT_KINDS = Object.freeze(["hub", "ward", "extra"]);
const POINT_ID_BY_KIND = { hub: /^hnth-hub$/, ward: /^hnth-branch-\d+$/, extra: /^hnth-extra-[a-z0-9-]{1,80}$/ };
const MAX_POINTS = 400;

/** Dữ liệu chủ: trả { points } đã chuẩn hóa hoặc { error } (thông báo tiếng Việt cho người dùng). */
export function normalizeRosterPoints(input) {
  if (!Array.isArray(input)) return { error: "points phải là một mảng" };
  if (input.length > MAX_POINTS) return { error: `Danh sách tối đa ${MAX_POINTS} điểm` };
  const points = [];
  const seenIds = new Set();
  const seenIps = new Map();
  for (const [index, raw] of input.entries()) {
    const row = `Dòng ${index + 1}`;
    const kind = String(raw?.kind ?? "");
    const pointId = String(raw?.pointId ?? "").trim();
    const name = String(raw?.name ?? "").trim().slice(0, 160);
    const ipAddress = String(raw?.ipAddress ?? "").trim();
    if (!ROSTER_POINT_KINDS.includes(kind)) return { error: `${row}: loại điểm không hợp lệ` };
    if (!POINT_ID_BY_KIND[kind].test(pointId)) return { error: `${row}: mã điểm không hợp lệ` };
    if (!name) return { error: `${row}: thiếu tên điểm` };
    if (seenIds.has(pointId)) return { error: `${row}: điểm "${name}" bị trùng` };
    if (ipAddress && !isIP(ipAddress)) return { error: `${row}: IP "${ipAddress}" không hợp lệ` };
    if (ipAddress && seenIps.has(ipAddress)) return { error: `${row}: IP ${ipAddress} trùng với "${seenIps.get(ipAddress)}"` };
    seenIds.add(pointId);
    if (ipAddress) seenIps.set(ipAddress, name);
    points.push({ pointId, kind, name, ipAddress, gateway: String(raw?.gateway ?? "").trim().slice(0, 64), modelVendor: String(raw?.modelVendor ?? "").trim().slice(0, 120) });
  }
  return { points };
}

/** Điểm giao cho Agent: các điểm của phiên có IP (Agent chỉ cần pointId + IP, tên để in log). */
export const rosterAgentPoints = (points) => points.filter((point) => point.ipAddress).map((point) => ({ pointId: point.pointId, name: point.name, ipAddress: point.ipAddress, modelVendor: point.modelVendor || undefined }));

/** Danh sách phiên họp: mã điểm không trùng, đều có trong dữ liệu chủ. */
export function normalizeRosterPointIds(input, catalogIds) {
  if (!Array.isArray(input)) return { error: "pointIds phải là một mảng" };
  if (!catalogIds.size) return { error: "Chưa có dữ liệu điểm cầu, hãy Import trước" };
  const pointIds = [...new Set(input.map((id) => String(id ?? "").trim()).filter(Boolean))];
  const missing = pointIds.filter((id) => !catalogIds.has(id));
  if (missing.length) return { error: `${missing.length} điểm không có trong dữ liệu điểm cầu` };
  if (!pointIds.length) return { error: "Danh sách phải có ít nhất 1 điểm" };
  return { pointIds };
}
