// Báo cáo PDF Giám sát HNTH: trang 1 là ảnh bản đồ + tổng hợp, các trang sau
// liệt kê endpoint theo trạng thái. PDF tự dựng từ ảnh JPEG của canvas (không
// cần thư viện PDF); tiếng Việt nằm trong ảnh nên hiển thị đúng ở mọi viewer.
import { emitAppEvent } from "../../core/events";
import { normalizeHnthStatus, type HnthConnectionStatus } from "../layers/hnth-data-provider";
import type { HnthPointFeature } from "./hnth-types";

type HnthReportPoint = { name: string; ipAddress: string; status: HnthConnectionStatus };

function dataUrlBytes(dataUrl: string) {
  const encoded = dataUrl.split(",", 2)[1] ?? "";
  const binary = atob(encoded);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
  return bytes;
}

async function captureMapBackground(staticOnly = false): Promise<HTMLImageElement | null> {
  // Chỉ yêu cầu MapCanvas chụp một frame khi xuất báo cáo; không giữ
  // preserveDrawingBuffer trong suốt thời gian người dùng thao tác bản đồ.
  const composedDataUrl = await new Promise<string | null>((resolve) => {
    emitAppEvent("map:capture-background", { resolve, staticOnly });
    window.setTimeout(() => resolve(null), 2000);
  });
  if (!composedDataUrl) return null;
  const result = new Image();
  result.src = composedDataUrl;
  await new Promise<void>((resolve) => { result.onload = () => resolve(); result.onerror = () => resolve(); });
  return result.naturalWidth ? result : null;
}

function pdfBytes(chunks: Uint8Array[]) {
  const total = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
  const result = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) { result.set(chunk, offset); offset += chunk.length; }
  return result;
}

function buildImagePdf(pages: Array<{ dataUrl: string; width: number; height: number }>) {
  const encoder = new TextEncoder();
  const objects: Uint8Array[] = [];
  const pageObjectNumbers: number[] = [];
  const pageContentNumbers: number[] = [];
  const imageObjectNumbers: number[] = [];
  let nextObject = 4;
  for (const _page of pages) {
    imageObjectNumbers.push(nextObject++);
    pageObjectNumbers.push(nextObject++);
    pageContentNumbers.push(nextObject++);
  }
  const objectCount = nextObject - 1;
  const putObject = (number: number, body: Uint8Array) => {
    objects[number] = pdfBytes([encoder.encode(`${number} 0 obj\n`), body, encoder.encode("\nendobj\n")]);
  };
  putObject(1, encoder.encode("<< /Type /Catalog /Pages 2 0 R >>"));
  putObject(2, encoder.encode(`<< /Type /Pages /Kids [${pageObjectNumbers.map((number) => `${number} 0 R`).join(" ")}] /Count ${pageObjectNumbers.length} >>`));
  putObject(3, encoder.encode("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"));
  pages.forEach((page, index) => {
    const imageBytes = dataUrlBytes(page.dataUrl);
    const imageObject = imageObjectNumbers[index];
    const pageObject = pageObjectNumbers[index];
    const contentObject = pageContentNumbers[index];
    putObject(imageObject, pdfBytes([
      encoder.encode(`<< /Type /XObject /Subtype /Image /Width ${page.width} /Height ${page.height} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length ${imageBytes.length} >>\nstream\n`),
      imageBytes,
      encoder.encode("\nendstream"),
    ]));
    // A page content object must be a PDF stream.  Writing the drawing
    // commands directly as the object body produces a malformed PDF which
    // some viewers open as a blank document.
    const content = encoder.encode(`q 595 0 0 842 0 0 cm /Im${index + 1} Do Q`);
    putObject(contentObject, pdfBytes([
      encoder.encode(`<< /Length ${content.length} >>\nstream\n`),
      content,
      encoder.encode("\nendstream"),
    ]));
    putObject(pageObject, encoder.encode(`<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /XObject << /Im${index + 1} ${imageObject} 0 R >> >> /Contents ${contentObject} 0 R >>`));
  });
  const header = encoder.encode("%PDF-1.4\n%\xFF\xFF\xFF\xFF\n");
  const chunks: Uint8Array[] = [header];
  const offsets = new Array<number>(objectCount + 1).fill(0);
  let offset = header.length;
  for (let number = 1; number <= objectCount; number += 1) {
    offsets[number] = offset;
    chunks.push(objects[number]);
    offset += objects[number].length;
  }
  const xrefOffset = offset;
  chunks.push(encoder.encode(`xref\n0 ${objectCount + 1}\n0000000000 65535 f \n${offsets.slice(1).map((item) => `${String(item).padStart(10, "0")} 00000 n \n`).join("")}trailer\n<< /Size ${objectCount + 1} /Root 1 0 R >>\nstartxref\n${xrefOffset}\n%%EOF`));
  return pdfBytes(chunks);
}

export async function exportHnthReportPdf(points: HnthPointFeature[]) {
  const generatedAt = new Date();
  const generatedAtText = generatedAt.toLocaleString("vi-VN", { dateStyle: "full", timeStyle: "medium" });
  const reportPoints: HnthReportPoint[] = points.map((point) => ({
    name: String(point.properties?.name ?? "Điểm HNTH"),
    ipAddress: String(point.properties?.ipAddress ?? "").trim(),
    status: normalizeHnthStatus(point.properties?.status),
  }));
  const groups: Array<{ status: HnthConnectionStatus; title: string; color: string }> = [
    { status: "lost", title: "Mất kết nối", color: "#dc2626" },
    { status: "unconnected", title: "Chưa kết nối", color: "#ca8a04" },
    { status: "connected", title: "Đã kết nối", color: "#059669" },
    { status: "unknown", title: "Chưa xác định", color: "#64748b" },
  ];
  let mapImage: HTMLImageElement | null = null;
  try { mapImage = await captureMapBackground(); } catch { /* Vẫn xuất được báo cáo chữ nếu ảnh không chụp được. */ }
  const pageWidth = 1600;
  const pageHeight = 2200;
  const pages: Array<{ dataUrl: string; width: number; height: number }> = [];
  const drawPage = (pageNumber: number, drawBody: (ctx: CanvasRenderingContext2D) => void) => {
    const canvas = document.createElement("canvas");
    canvas.width = pageWidth;
    canvas.height = pageHeight;
    const context = canvas.getContext("2d");
    if (!context) return;
    context.fillStyle = "#ffffff";
    context.fillRect(0, 0, pageWidth, pageHeight);
    context.fillStyle = "#0f2935";
    context.font = "700 42px Segoe UI, Arial, sans-serif";
    context.fillText("BÁO CÁO GIÁM SÁT HỘI NGHỊ TRUYỀN HÌNH", 70, 85);
    context.fillStyle = "#52616b";
    context.font = "24px Segoe UI, Arial, sans-serif";
    context.fillText(`Thời gian xuất: ${generatedAtText}`, 70, 130);
    context.fillText(`Tổng số endpoint: ${reportPoints.length}`, 70, 168);
    drawBody(context);
    context.fillStyle = "#82909a";
    context.font = "18px Segoe UI, Arial, sans-serif";
    context.fillText(`Trang ${pageNumber}`, pageWidth - 160, pageHeight - 35);
    pages.push({ dataUrl: canvas.toDataURL("image/jpeg", 0.9), width: pageWidth, height: pageHeight });
  };
  drawPage(1, (context) => {
    let y = 220;
    if (mapImage) {
      const maxWidth = pageWidth - 140;
      const maxHeight = 760;
      const scale = Math.min(maxWidth / mapImage.naturalWidth, maxHeight / mapImage.naturalHeight);
      const width = Math.max(1, Math.round(mapImage.naturalWidth * scale));
      const height = Math.max(1, Math.round(mapImage.naturalHeight * scale));
      context.drawImage(mapImage, (pageWidth - width) / 2, y, width, height);
      y += height + 45;
    } else {
      context.fillStyle = "#f1f5f9";
      context.fillRect(70, y, pageWidth - 140, 180);
      context.fillStyle = "#52616b";
      context.font = "24px Segoe UI, Arial, sans-serif";
      context.fillText("Không thể chụp canvas bản đồ tại thời điểm xuất báo cáo.", 105, y + 100);
      y += 230;
    }
    context.fillStyle = "#0f2935";
    context.font = "700 28px Segoe UI, Arial, sans-serif";
    context.fillText("Tổng hợp trạng thái", 70, y);
    y += 54;
    groups.forEach((group, index) => {
      const count = reportPoints.filter((point) => point.status === group.status).length;
      const x = 70 + (index % 2) * 760;
      const rowY = y + Math.floor(index / 2) * 68;
      context.fillStyle = group.color;
      context.fillRect(x, rowY - 22, 20, 20);
      context.fillStyle = "#25343c";
      context.font = "24px Segoe UI, Arial, sans-serif";
      context.fillText(`${group.title}: ${count}`, x + 34, rowY);
    });
  });
  type ReportListRow = { heading?: string; left?: string; right?: string; blank?: boolean };
  const listRows: ReportListRow[] = [];
  for (const group of groups) {
    const groupPoints = reportPoints.filter((point) => point.status === group.status);
    listRows.push({ heading: `${group.title} (${groupPoints.length})` });
    // Nhóm dài hơn 10 dòng được dàn thành hai cột riêng của chính nhóm đó.
    // Các nhóm ngắn vẫn giữ một cột để dễ đọc.
    if (groupPoints.length > 10) {
      for (let index = 0; index < groupPoints.length; index += 2) {
        const left = groupPoints[index];
        const right = groupPoints[index + 1];
        listRows.push({
          left: `• ${left.name} — ${left.ipAddress || "Chưa cấu hình IP"}`,
          right: right ? `• ${right.name} — ${right.ipAddress || "Chưa cấu hình IP"}` : "",
        });
      }
    } else {
      for (const point of groupPoints) listRows.push({ left: `• ${point.name} — ${point.ipAddress || "Chưa cấu hình IP"}` });
    }
    listRows.push({ blank: true });
  }
  const rowsPerPage = 52;
  for (let start = 0; start < listRows.length; start += rowsPerPage) {
    const pageRows = listRows.slice(start, start + rowsPerPage);
    drawPage(pages.length + 1, (context) => {
      let y = 235;
      for (const row of pageRows) {
        if (row.blank) { y += 18; continue; }
        if (row.heading) {
          context.fillStyle = "#0f6674";
          context.font = "700 25px Segoe UI, Arial, sans-serif";
          context.fillText(row.heading, 80, y);
          y += 40;
          continue;
        }
        context.fillStyle = "#25343c";
        context.font = "21px Segoe UI, Arial, sans-serif";
        if (row.left) context.fillText(row.left, 80, y);
        if (row.right) context.fillText(row.right, 810, y);
        y += 32;
      }
    });
  }
  const pdf = buildImagePdf(pages);
  const url = URL.createObjectURL(new Blob([pdf], { type: "application/pdf" }));
  const link = document.createElement("a");
  link.href = url;
  link.download = `bao-cao-hnth-${generatedAt.toISOString().slice(0, 19).replaceAll(":", "-")}.pdf`;
  link.click();
  window.setTimeout(() => URL.revokeObjectURL(url), 1000);
}
