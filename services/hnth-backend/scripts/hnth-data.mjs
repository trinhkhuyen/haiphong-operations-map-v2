// Xuất/nhập dữ liệu điểm cầu HNTH (dữ liệu chủ + các danh sách phiên họp) dạng JSON để
// mang sang máy khác qua git mà không cần sao lưu cả database.
//   pnpm --filter @haiphong-ops/hnth-backend data:export [file]   (mặc định data/hnth/hnth-points.json)
//   pnpm --filter @haiphong-ops/hnth-backend data:import [file]
// Import ghi đè dữ liệu chủ và tạo/cập nhật danh sách theo tên; cần chạy backend ít nhất
// một lần trước để migration tạo bảng. Kết nối DB theo DATABASE_URL như backend (src/db.mjs).
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { pool } from "../src/db.mjs";
import { normalizeRosterPoints } from "../src/services/rosters.mjs";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");
const [command, fileArg] = process.argv.slice(2);
const file = path.resolve(repoRoot, fileArg || "data/hnth/hnth-points.json");

async function exportData() {
  const catalog = (await pool.query("SELECT points,updated_at FROM hnth_catalog WHERE id=1")).rows[0];
  const rosters = (await pool.query("SELECT name,point_ids FROM hnth_rosters ORDER BY name")).rows;
  const active = (await pool.query("SELECT r.name FROM monitor_state m JOIN hnth_rosters r ON r.id=m.active_roster_id WHERE m.id=1")).rows[0];
  const data = {
    exportedAt: new Date().toISOString(),
    catalog: catalog?.points ?? [],
    rosters: rosters.map((row) => ({ name: row.name, pointIds: row.point_ids })),
    activeRoster: active?.name ?? null,
  };
  await mkdir(path.dirname(file), { recursive: true });
  await writeFile(file, `${JSON.stringify(data, null, 2)}\n`, "utf8");
  console.log(`Đã xuất ${data.catalog.length} điểm cầu và ${data.rosters.length} danh sách ra ${path.relative(repoRoot, file)}`);
}

async function importData() {
  const data = JSON.parse(await readFile(file, "utf8"));
  const normalized = normalizeRosterPoints(data.catalog);
  if (normalized.error) throw new Error(`Dữ liệu điểm cầu không hợp lệ: ${normalized.error}`);
  const ids = new Set(normalized.points.map((point) => point.pointId));
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query("INSERT INTO hnth_catalog(id,points,updated_at) VALUES(1,$1,now()) ON CONFLICT(id) DO UPDATE SET points=excluded.points,updated_at=now()", [JSON.stringify(normalized.points)]);
    for (const roster of data.rosters ?? []) {
      const pointIds = (roster.pointIds ?? []).filter((id) => ids.has(id));
      await client.query("INSERT INTO hnth_rosters(name,point_ids) VALUES($1,$2) ON CONFLICT(name) DO UPDATE SET point_ids=excluded.point_ids,updated_at=now()", [roster.name, JSON.stringify(pointIds)]);
    }
    if (data.activeRoster) await client.query("UPDATE monitor_state SET active_roster_id=(SELECT id FROM hnth_rosters WHERE name=$1),updated_at=now(),revision=revision+1 WHERE id=1", [data.activeRoster]);
    await client.query("COMMIT");
  } catch (error) { await client.query("ROLLBACK"); throw error; }
  finally { client.release(); }
  console.log(`Đã nhập ${normalized.points.length} điểm cầu và ${(data.rosters ?? []).length} danh sách từ ${path.relative(repoRoot, file)}`);
}

try {
  if (command === "export") await exportData();
  else if (command === "import") await importData();
  else throw new Error("Dùng: hnth-data.mjs export|import [file]");
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
} finally {
  await pool.end();
}
