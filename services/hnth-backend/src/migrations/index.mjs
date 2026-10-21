// Danh sách migration theo thứ tự version. Thêm thay đổi schema = thêm file
// NNN-ten.mjs (export up(client)) và một dòng ở đây; không sửa migration đã phát hành.
import * as baseline from "./001-baseline.mjs";
import * as monitorLease from "./002-monitor-lease.mjs";

export const MIGRATIONS = [
  { version: 1, name: "baseline", up: baseline.up },
  { version: 2, name: "monitor-lease", up: monitorLease.up },
];
