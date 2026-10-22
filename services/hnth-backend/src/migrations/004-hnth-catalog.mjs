// Tách dữ liệu chủ khỏi danh sách phiên họp: hnth_catalog giữ toàn bộ điểm cầu đã Import
// (tên, IP, Gateway, Model); hnth_rosters chỉ còn danh sách mã điểm chọn từ dữ liệu chủ.
// Danh sách tạo ở 003 (lưu cả thông tin điểm) được gộp vào dữ liệu chủ rồi đổi sang mã điểm.
export async function up(client) {
  await client.query(`
    CREATE TABLE IF NOT EXISTS hnth_catalog (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      points JSONB NOT NULL DEFAULT '[]'::jsonb,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    ALTER TABLE hnth_rosters ADD COLUMN IF NOT EXISTS point_ids JSONB NOT NULL DEFAULT '[]'::jsonb;
  `);
  const rosters = (await client.query("SELECT id,points FROM hnth_rosters ORDER BY updated_at")).rows;
  const catalog = new Map();
  for (const roster of rosters) {
    const points = Array.isArray(roster.points) ? roster.points : [];
    for (const point of points) if (point?.pointId) catalog.set(point.pointId, point);
    await client.query("UPDATE hnth_rosters SET point_ids=$2 WHERE id=$1", [roster.id, JSON.stringify(points.map((point) => point.pointId).filter(Boolean))]);
  }
  if (catalog.size) await client.query("INSERT INTO hnth_catalog(id,points) VALUES(1,$1) ON CONFLICT(id) DO NOTHING", [JSON.stringify([...catalog.values()])]);
  await client.query("ALTER TABLE hnth_rosters DROP COLUMN IF EXISTS points");
}
