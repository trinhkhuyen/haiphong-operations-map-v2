// Chạy migration theo version. Mỗi migration trong một transaction; khóa advisory
// để hai tiến trình backend khởi động cùng lúc không chạy chồng nhau.
const MIGRATION_LOCK_ID = 872_430_001;

export async function runMigrations(pool, migrations, log = console.log) {
  const versions = migrations.map((item) => item.version);
  if (versions.some((version, index) => index > 0 && version <= versions[index - 1])) throw new Error("Migration versions must be strictly increasing");
  const client = await pool.connect();
  try {
    await client.query("SELECT pg_advisory_lock($1)", [MIGRATION_LOCK_ID]);
    await client.query("CREATE TABLE IF NOT EXISTS schema_migrations (version INTEGER PRIMARY KEY, name TEXT NOT NULL, applied_at TIMESTAMPTZ NOT NULL DEFAULT now())");
    const applied = new Set((await client.query("SELECT version FROM schema_migrations")).rows.map((row) => Number(row.version)));
    const pending = migrations.filter((item) => !applied.has(item.version));
    for (const migration of pending) {
      await client.query("BEGIN");
      try {
        await migration.up(client);
        await client.query("INSERT INTO schema_migrations(version,name) VALUES($1,$2)", [migration.version, migration.name]);
        await client.query("COMMIT");
        log(`Applied migration ${migration.version}-${migration.name}`);
      } catch (error) {
        await client.query("ROLLBACK");
        throw new Error(`Migration ${migration.version}-${migration.name} failed: ${error.message}`);
      }
    }
    return pending.map((item) => item.version);
  } finally {
    await client.query("SELECT pg_advisory_unlock($1)", [MIGRATION_LOCK_ID]).catch(() => {});
    client.release();
  }
}
