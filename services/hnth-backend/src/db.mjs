import pg from "pg";
import { MIGRATIONS } from "./migrations/index.mjs";
import { runMigrations } from "./migrator.mjs";

const { Pool } = pg;
export const pool = new Pool({
  connectionString: process.env.DATABASE_URL || "postgres://hnth:hnth_local_password@127.0.0.1:5432/hnth",
});

/** Đưa schema lên version mới nhất (src/migrations). Gọi một lần lúc khởi động. */
export async function migrate() {
  return runMigrations(pool, MIGRATIONS);
}
