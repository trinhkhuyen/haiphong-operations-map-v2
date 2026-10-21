// Nhập/xuất danh sách điểm HNTH (Tên điểm, IP, Gateway, Model/Vendor) dạng CSV/XLSX.
import { downloadWorkbook, readFirstSheetRows } from "../../core/spreadsheet";
import type { HnthPointFeature } from "./hnth-types";

export type HnthImportRow = { name: string; ipAddress: string; gateway: string; modelVendor: string };

export function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let value = "";
  let quoted = false;
  for (let index = 0; index < text.length; index += 1) {
    const character = text[index];
    const next = text[index + 1];
    if (character === '"') {
      if (quoted && next === '"') { value += '"'; index += 1; }
      else quoted = !quoted;
    } else if (character === "," && !quoted) {
      row.push(value); value = "";
    } else if ((character === "\n" || character === "\r") && !quoted) {
      if (character === "\r" && next === "\n") index += 1;
      row.push(value); value = "";
      if (row.some((cell) => cell.trim())) rows.push(row);
      row = [];
    } else value += character;
  }
  if (value || row.length) { row.push(value); if (row.some((cell) => cell.trim())) rows.push(row); }
  return rows;
}

function normalizeCsvHeader(value: string) {
  return value.replace(/^﻿/, "").trim().toLocaleLowerCase("vi").normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[đĐ]/g, "d").replace(/[\s_/-]+/g, "");
}

export function parseHnthCsv(text: string): HnthImportRow[] {
  const rows = parseCsv(text);
  if (rows.length < 2) return [];
  const headers = rows[0].map(normalizeCsvHeader);
  const findColumn = (...names: string[]) => headers.findIndex((header) => names.includes(header));
  const nameIndex = findColumn("tendiem", "name");
  const ipIndex = findColumn("ip", "địachỉip", "diachiip", "ipaddress");
  const gatewayIndex = findColumn("gateway", "congmacdinh");
  const modelIndex = findColumn("modelvendor", "model", "vendor", "modelvender");
  if (nameIndex < 0) throw new Error("CSV phải có cột Tên điểm");
  return rows.slice(1).map((row) => ({
    name: String(row[nameIndex] ?? "").trim(),
    ipAddress: String(ipIndex >= 0 ? row[ipIndex] ?? "" : "").trim(),
    gateway: String(gatewayIndex >= 0 ? row[gatewayIndex] ?? "" : "192.168.1.1").trim() || "192.168.1.1",
    modelVendor: String(modelIndex >= 0 ? row[modelIndex] ?? "" : "").trim(),
  })).filter((row) => row.name);
}

/** Đọc file .xlsx (cột cố định A-D, bỏ dòng tiêu đề) hoặc CSV (tìm cột theo tiêu đề). */
export async function readHnthImportFile(file: File): Promise<HnthImportRow[]> {
  if (!file.name.toLocaleLowerCase().endsWith(".xlsx")) return parseHnthCsv(await file.text());
  const rows = await readFirstSheetRows(file);
  return rows.slice(1).filter((row) => String(row[0] ?? "").trim()).map((row) => ({
    name: String(row[0] ?? "").trim(),
    ipAddress: String(row[1] ?? "").trim(),
    gateway: String(row[2] ?? "").trim(),
    modelVendor: String(row[3] ?? "").trim(),
  }));
}

export async function exportHnthPointsXlsx(points: HnthPointFeature[]) {
  const header = ["Tên điểm", "IP", "Gateway", "Model/Vendor"];
  const rows = points.map((point) => [
    String(point.properties?.name ?? ""),
    String(point.properties?.ipAddress ?? ""),
    String(point.properties?.gateway || "192.168.1.1"),
    String(point.properties?.model || point.properties?.modelVendor || ""),
  ]);
  await downloadWorkbook(`hnth-danh-sach-diem-${new Date().toISOString().slice(0, 10)}.xlsx`, [
    { name: "Danh sach HNTH", rows: [header, ...rows], columnWidths: [44, 18, 18, 22], boldHeader: true },
  ]);
}
