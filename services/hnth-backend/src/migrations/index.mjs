// Danh sách migration theo thứ tự version. Thêm thay đổi schema = thêm file
// NNN-ten.mjs (export up(client)) và một dòng ở đây; không sửa migration đã phát hành.
import * as baseline from "./001-baseline.mjs";
import * as monitorLease from "./002-monitor-lease.mjs";
import * as hnthRosters from "./003-hnth-rosters.mjs";
import * as hnthCatalog from "./004-hnth-catalog.mjs";

export const MIGRATIONS = [
  { version: 1, name: "baseline", up: baseline.up },
  { version: 2, name: "monitor-lease", up: monitorLease.up },
  { version: 3, name: "hnth-rosters", up: hnthRosters.up },
  { version: 4, name: "hnth-catalog", up: hnthCatalog.up },
];
