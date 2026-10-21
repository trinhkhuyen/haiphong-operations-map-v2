import crypto from "node:crypto";
import path from "node:path";
import { createWriteStream } from "node:fs";
import { open, unlink } from "node:fs/promises";
import { once } from "node:events";
import { EXE_VERSION_SCAN_BYTES, readExeVersion } from "@haiphong-ops/hnth-protocol";

export const MAX_RELEASE_BYTES = 250 * 1024 * 1024;
export const safeReleaseVersion = (value) => String(value || "").trim().match(/^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/)?.[0] || null;
// path.win32.basename tách theo cả "/" và "\\": tên file gửi từ Windows (C:\...\a.exe)
// cũng chỉ còn phần tên khi backend chạy trên Linux (Docker).
export const safeReleaseFileName = (value) => path.win32.basename(String(value || "agent.exe")).replace(/[^A-Za-z0-9._-]/g, "_");

/** Ghi body request ra file (không ghi đè), tính SHA-256; lỗi thì xóa file dở. */
export async function writeRelease(req, filePath) {
  const output = createWriteStream(filePath, { flags: "wx" });
  const digest = crypto.createHash("sha256");
  let size = 0;
  try {
    for await (const chunk of req) {
      size += chunk.length;
      if (size > MAX_RELEASE_BYTES) throw new Error("release file is too large (max 250 MB)");
      digest.update(chunk);
      if (!output.write(chunk)) await once(output, "drain");
    }
    output.end();
    await once(output, "close");
    return { size, sha256: digest.digest("hex") };
  } catch (error) {
    output.destroy();
    await unlink(filePath).catch(() => {});
    throw error;
  }
}

/** Version ghi trong file .exe (ProductVersion); chỉ cần đọc phần đầu file. */
export async function readExeFileVersion(filePath) {
  const handle = await open(filePath, "r");
  try {
    const { buffer, bytesRead } = await handle.read(Buffer.alloc(EXE_VERSION_SCAN_BYTES), 0, EXE_VERSION_SCAN_BYTES, 0);
    return readExeVersion(buffer.subarray(0, bytesRead));
  } finally { await handle.close(); }
}
