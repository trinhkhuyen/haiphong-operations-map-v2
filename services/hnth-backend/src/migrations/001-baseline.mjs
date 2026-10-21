// Lược đồ ban đầu: nguyên văn script idempotent `migrate()` cũ trong db.mjs
// (CREATE/ALTER ... IF NOT EXISTS). Chạy trên DB đã có dữ liệu thì không đổi gì,
// chỉ được ghi nhận là version 1.
export async function up(client) {
  await client.query(`
    CREATE EXTENSION IF NOT EXISTS pgcrypto;
    CREATE TABLE IF NOT EXISTS users (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      username TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      display_name TEXT NOT NULL,
      role TEXT NOT NULL CHECK (role IN ('admin', 'operator', 'viewer')),
      menu_permissions JSONB NOT NULL DEFAULT '["layers","zones","saved","routing","conference","agents"]'::jsonb,
      is_active BOOLEAN NOT NULL DEFAULT TRUE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE TABLE IF NOT EXISTS refresh_tokens (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      token_hash TEXT NOT NULL,
      expires_at TIMESTAMPTZ NOT NULL,
      revoked_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE TABLE IF NOT EXISTS agents (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      agent_id TEXT UNIQUE NOT NULL,
      name TEXT NOT NULL,
      machine_id TEXT,
      token_hash TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'offline',
      last_seen_at TIMESTAMPTZ,
      version TEXT,
      monitor_config JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE TABLE IF NOT EXISTS endpoints (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      endpoint_id TEXT UNIQUE NOT NULL,
      name TEXT NOT NULL,
      ip_address INET,
      model_vendor TEXT,
      status TEXT NOT NULL DEFAULT 'unknown',
      checked_at TIMESTAMPTZ,
      packet_loss_pct NUMERIC,
      jitter_ms NUMERIC,
      enabled BOOLEAN NOT NULL DEFAULT TRUE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE TABLE IF NOT EXISTS commands (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      agent_id TEXT NOT NULL,
      type TEXT NOT NULL,
      payload JSONB NOT NULL DEFAULT '{}'::jsonb,
      status TEXT NOT NULL DEFAULT 'pending',
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      claimed_at TIMESTAMPTZ
    );
    CREATE TABLE IF NOT EXISTS agent_releases (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      version TEXT UNIQUE NOT NULL,
      file_name TEXT NOT NULL,
      file_path TEXT NOT NULL,
      sha256 TEXT NOT NULL,
      size_bytes BIGINT NOT NULL,
      created_by UUID REFERENCES users(id) ON DELETE SET NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE TABLE IF NOT EXISTS agent_update_events (
      id BIGSERIAL PRIMARY KEY,
      agent_id TEXT NOT NULL,
      version TEXT NOT NULL,
      status TEXT NOT NULL,
      detail TEXT,
      reported_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE TABLE IF NOT EXISTS monitor_logs (
      id BIGSERIAL PRIMARY KEY,
      agent_id TEXT NOT NULL,
      endpoint_id TEXT NOT NULL,
      ip_address INET,
      status TEXT NOT NULL,
      latency_ms INTEGER,
      packet_loss_pct NUMERIC,
      jitter_ms NUMERIC,
      checked_at TIMESTAMPTZ NOT NULL,
      received_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE TABLE IF NOT EXISTS discovered_ips (
      agent_id TEXT NOT NULL,
      ip_address INET NOT NULL,
      status TEXT NOT NULL DEFAULT 'online',
      mac_address TEXT,
      model_vendor TEXT,
      discovered_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (agent_id, ip_address)
    );
    CREATE TABLE IF NOT EXISTS snmp_results (
      id BIGSERIAL PRIMARY KEY,
      agent_id TEXT NOT NULL,
      target_id TEXT NOT NULL,
      host INET NOT NULL,
      oid TEXT NOT NULL,
      value TEXT,
      value_type TEXT,
      checked_at TIMESTAMPTZ NOT NULL,
      received_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE TABLE IF NOT EXISTS audit_logs (
      id BIGSERIAL PRIMARY KEY,
      user_id UUID REFERENCES users(id) ON DELETE SET NULL,
      action TEXT NOT NULL,
      resource TEXT,
      metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE TABLE IF NOT EXISTS monitor_state (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      enabled BOOLEAN NOT NULL DEFAULT FALSE,
      agent_id TEXT NOT NULL DEFAULT 'agent-demo',
      concurrency INTEGER NOT NULL DEFAULT 1,
      wait_seconds INTEGER NOT NULL DEFAULT 3,
      session_id UUID NOT NULL DEFAULT gen_random_uuid(),
      started_at TIMESTAMPTZ,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      revision BIGINT NOT NULL DEFAULT 0
    );
  `);
  await client.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS menu_permissions JSONB NOT NULL DEFAULT '["layers","zones","saved","routing","conference","agents"]'::jsonb`);
  await client.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS department TEXT NOT NULL DEFAULT ''`);
  await client.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS phone TEXT NOT NULL DEFAULT ''`);
  await client.query(`ALTER TABLE agents ADD COLUMN IF NOT EXISTS heartbeat_seconds INTEGER NOT NULL DEFAULT 30`);
  await client.query(`ALTER TABLE agents ADD COLUMN IF NOT EXISTS machine_id TEXT`);
  await client.query(`ALTER TABLE endpoints ADD COLUMN IF NOT EXISTS latency_ms INTEGER`);
  await client.query(`ALTER TABLE agents ADD COLUMN IF NOT EXISTS monitor_config JSONB NOT NULL DEFAULT '{}'::jsonb`);
  await client.query(`ALTER TABLE endpoints ADD COLUMN IF NOT EXISTS packet_loss_pct NUMERIC`);
  await client.query(`ALTER TABLE endpoints ADD COLUMN IF NOT EXISTS jitter_ms NUMERIC`);
  await client.query(`ALTER TABLE monitor_logs ADD COLUMN IF NOT EXISTS packet_loss_pct NUMERIC`);
  await client.query(`ALTER TABLE monitor_logs ADD COLUMN IF NOT EXISTS jitter_ms NUMERIC`);
  // Mỗi bản cài Agent (máy + thư mục chứa config) có một installation_id riêng.
  // Một agent_id chỉ thuộc về đúng một bản cài; bản copy sẽ được cấp id mới.
  await client.query(`ALTER TABLE agents ADD COLUMN IF NOT EXISTS installation_id TEXT`);
  await client.query(`CREATE UNIQUE INDEX IF NOT EXISTS agents_installation_id_key ON agents(installation_id) WHERE installation_id IS NOT NULL`);
  await client.query(`INSERT INTO monitor_state(id,agent_id) VALUES(1,$1) ON CONFLICT(id) DO NOTHING`, [process.env.HNTH_DEFAULT_AGENT_ID || "agent-demo"]);
}
