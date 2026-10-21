// Lease giám sát liên tục: phiên chỉ sống khi giao diện Operator còn gia hạn.
// Phiên đang bật lúc nâng cấp được cấp một lease mới để trang đang mở kịp gia hạn.
import { MONITOR_LEASE_SECONDS } from "@haiphong-ops/hnth-protocol";

export async function up(client) {
  await client.query("ALTER TABLE monitor_state ADD COLUMN IF NOT EXISTS lease_expires_at TIMESTAMPTZ");
  await client.query("UPDATE monitor_state SET lease_expires_at=now() + make_interval(secs => $1) WHERE enabled", [MONITOR_LEASE_SECONDS]);
}
