// Nơi duy nhất dùng thư viện `xlsx`. Bản npm 0.18.5 đã ngừng cập nhật và có CVE;
// khi thay thư viện chỉ cần sửa file này (nhập/xuất Excel ở HNTH và Quản trị tài khoản).
import * as XLSX from "xlsx";

export type SheetSpec = {
  name: string;
  /** Dòng đầu là tiêu đề cột. */
  rows: unknown[][];
  columnWidths?: number[];
  boldHeader?: boolean;
  /** Ràng buộc danh sách giá trị cho một vùng ô (vd cột Quyền). */
  listValidation?: { sqref: string; formula1: string };
};

/** Tạo workbook từ các sheet và tải về trình duyệt. */
export function downloadWorkbook(fileName: string, sheets: SheetSpec[]) {
  const book = XLSX.utils.book_new();
  for (const spec of sheets) {
    const sheet = XLSX.utils.aoa_to_sheet(spec.rows);
    if (spec.columnWidths) sheet["!cols"] = spec.columnWidths.map((wch) => ({ wch }));
    if (spec.boldHeader) {
      for (let column = 0; column < (spec.rows[0]?.length ?? 0); column += 1) {
        const cell = sheet[XLSX.utils.encode_cell({ r: 0, c: column })];
        if (cell) cell.s = { font: { bold: true } };
      }
    }
    if (spec.listValidation) {
      (sheet as XLSX.WorkSheet & { "!dataValidation"?: unknown })["!dataValidation"] = [{ ...spec.listValidation, type: "list", allowBlank: true }];
    }
    XLSX.utils.book_append_sheet(book, sheet, spec.name);
  }
  XLSX.writeFile(book, fileName, { cellStyles: true });
}

async function firstSheet(file: File) {
  const workbook = XLSX.read(new Uint8Array(await file.arrayBuffer()), { type: "array" });
  return workbook.Sheets[workbook.SheetNames[0]];
}

/** Sheet đầu tiên dưới dạng mảng dòng (kể cả dòng tiêu đề), ô trống = "". */
export async function readFirstSheetRows(file: File) {
  return XLSX.utils.sheet_to_json<unknown[]>(await firstSheet(file), { header: 1, defval: "" });
}

/** Sheet đầu tiên dưới dạng object theo tên cột ở dòng tiêu đề, ô trống = "". */
export async function readFirstSheetObjects(file: File) {
  return XLSX.utils.sheet_to_json<Record<string, unknown>>(await firstSheet(file), { defval: "" });
}
