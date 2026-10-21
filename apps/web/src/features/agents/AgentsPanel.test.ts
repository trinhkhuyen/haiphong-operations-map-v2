import { describe, expect, it } from "vitest";
import { compareVersions, readExeVersion } from "./AgentsPanel";

// Dựng một "file .exe" giả có resource VS_VERSIONINFO tối giản: khóa
// "ProductVersion\0" (UTF-16LE), căn 4 byte, rồi chuỗi version kết thúc bằng \0.
function fakeExe(version: string | null, keyOffset = 1000): File {
  const utf16 = (text: string) => { const bytes = new Uint8Array(text.length * 2); [...text].forEach((char, index) => { bytes[index * 2] = char.charCodeAt(0); }); return bytes; };
  const buffer = new Uint8Array(4096);
  if (version !== null) {
    const key = utf16("ProductVersion\0");
    buffer.set(key, keyOffset);
    let cursor = keyOffset + key.length;
    cursor += (4 - (cursor % 4)) % 4;
    buffer.set(utf16(`${version}\0`), cursor);
  }
  return new File([buffer], "Agent.exe");
}

describe("readExeVersion", () => {
  it("đọc ProductVersion", async () => {
    expect(await readExeVersion(fakeExe("0.2.4"))).toBe("0.2.4");
  });
  it("đọc được khi khóa nằm ở offset không chia hết cho 4", async () => {
    expect(await readExeVersion(fakeExe("1.10.3", 1002))).toBe("1.10.3");
  });
  it("giữ hậu tố pre-release", async () => {
    expect(await readExeVersion(fakeExe("0.3.0-beta.1"))).toBe("0.3.0-beta.1");
  });
  it("không có ProductVersion thì trả null", async () => {
    expect(await readExeVersion(fakeExe(null))).toBeNull();
  });
  it("giá trị không giống version thì trả null", async () => {
    expect(await readExeVersion(fakeExe("Agent HNTH"))).toBeNull();
  });
});

describe("compareVersions", () => {
  it("so sánh theo số, không theo chuỗi", () => {
    expect(compareVersions("0.2.10", "0.2.9")).toBeGreaterThan(0);
    expect(compareVersions("0.2.0", "0.2.4")).toBeLessThan(0);
  });
  it("bằng nhau, kể cả khác số phần", () => {
    expect(compareVersions("0.2.4", "0.2.4")).toBe(0);
    expect(compareVersions("1.0", "1.0.0")).toBe(0);
  });
});
