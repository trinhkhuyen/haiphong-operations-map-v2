// Danh sách điểm cầu theo phiên họp (xã/phường + Trung tâm + Sở/Ban/Ngành).
// monitor_state.active_roster_id = danh sách đang áp dụng; NULL = toàn bộ điểm mặc định.
export async function up(client) {
  await client.query(`
    CREATE TABLE IF NOT EXISTS hnth_rosters (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      name TEXT NOT NULL UNIQUE,
      points JSONB NOT NULL DEFAULT '[]'::jsonb,
      created_by UUID REFERENCES users(id) ON DELETE SET NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    ALTER TABLE monitor_state ADD COLUMN IF NOT EXISTS active_roster_id UUID REFERENCES hnth_rosters(id) ON DELETE SET NULL;
  `);
}
