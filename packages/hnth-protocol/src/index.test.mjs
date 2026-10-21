import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { classifyProbeResult, compareVersions, OPERATOR_COMMAND_TYPES, readExeVersion, toConnectionStatus } from "./index.mjs";

function exeBytes(version, keyOffset = 1000) {
  const bytes = new Uint8Array(4096);
  if (version === null) return bytes;
  const key = Buffer.from("ProductVersion\0", "utf16le");
  bytes.set(key, keyOffset);
  let cursor = keyOffset + key.length;
  cursor += (4 - (cursor % 4)) % 4;
  bytes.set(Buffer.from(`${version}\0`, "utf16le"), cursor);
  return bytes;
}

describe("toConnectionStatus", () => {
  it("không có IP luôn unknown", () => {
    for (const status of ["online", "offline", "unknown"]) assert.equal(toConnectionStatus(status, false), "unknown");
  });
  it("online → unconnected, offline → lost, khác → unknown", () => {
    assert.equal(toConnectionStatus("online", true), "unconnected");
    assert.equal(toConnectionStatus("offline", true), "lost");
    assert.equal(toConnectionStatus("unknown", true), "unknown");
    assert.equal(toConnectionStatus(undefined, true), "unknown");
  });
});

describe("classifyProbeResult", () => {
  it("ngưỡng với 4 gói", () => {
    assert.deepEqual([0, 1, 2, 3, 4].map((ok) => classifyProbeResult(ok, 4)), ["offline", "offline", "unknown", "unknown", "online"]);
  });
  it("1 gói: chỉ online hoặc offline", () => {
    assert.deepEqual([0, 1].map((ok) => classifyProbeResult(ok, 1)), ["offline", "online"]);
  });
});

describe("readExeVersion", () => {
  it("đọc ở offset chẵn và lẻ", () => {
    assert.equal(readExeVersion(exeBytes("0.2.4")), "0.2.4");
    assert.equal(readExeVersion(exeBytes("1.10.3", 1003)), "1.10.3");
  });
  it("không có khóa hoặc giá trị không phải version → null", () => {
    assert.equal(readExeVersion(exeBytes(null)), null);
    assert.equal(readExeVersion(exeBytes("Agent HNTH")), null);
  });
});

describe("compareVersions", () => {
  it("so theo số", () => {
    assert.ok(compareVersions("0.2.10", "0.2.9") > 0);
    assert.equal(compareVersions("1.0", "1.0.0"), 0);
  });
});

it("OPERATOR_COMMAND_TYPES không cho agent-config (chỉ backend tạo)", () => {
  assert.ok(!OPERATOR_COMMAND_TYPES.includes("agent-config"));
  assert.ok(Object.isFrozen(OPERATOR_COMMAND_TYPES));
});
