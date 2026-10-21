// Unit test: giới hạn đăng nhập, IP/HTTPS sau proxy, cấu hình cookie, runner migration.
import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { loadConfig } from "../src/config.mjs";
import { clientIp, isSecureRequest } from "../src/http.mjs";
import { runMigrations } from "../src/migrator.mjs";
import { createLoginLimiter } from "../src/services/login-limiter.mjs";

describe("login limiter", () => {
  it("khóa (IP + tài khoản) sau 5 lần sai; hết cửa sổ thì mở lại", () => {
    let time = 0;
    const limiter = createLoginLimiter({ maxPerAccount: 5, maxPerIp: 100, windowMs: 60_000, now: () => time });
    for (let i = 0; i < 5; i++) { assert.equal(limiter.check("1.1.1.1", "admin").allowed, true); limiter.recordFailure("1.1.1.1", "Admin"); }
    assert.deepEqual(limiter.check("1.1.1.1", "ADMIN "), { allowed: false, retryAfterSeconds: 60 });
    assert.equal(limiter.check("2.2.2.2", "admin").allowed, true, "IP khác không bị khóa theo tài khoản");
    assert.equal(limiter.check("1.1.1.1", "viewer").allowed, true, "tài khoản khác cùng IP chưa bị khóa");
    time = 30_000;
    assert.equal(limiter.check("1.1.1.1", "admin").retryAfterSeconds, 30);
    time = 60_001;
    assert.equal(limiter.check("1.1.1.1", "admin").allowed, true);
  });
  it("đăng nhập đúng xóa bộ đếm của tài khoản", () => {
    const limiter = createLoginLimiter({ maxPerAccount: 2, maxPerIp: 100 });
    limiter.recordFailure("ip", "a");
    limiter.recordSuccess("ip", "a");
    limiter.recordFailure("ip", "a");
    assert.equal(limiter.check("ip", "a").allowed, true);
  });
  it("khóa theo IP khi dò nhiều tài khoản", () => {
    const limiter = createLoginLimiter({ maxPerAccount: 100, maxPerIp: 3 });
    for (const name of ["a", "b", "c"]) limiter.recordFailure("9.9.9.9", name);
    assert.equal(limiter.check("9.9.9.9", "d").allowed, false);
  });
});

describe("proxy headers", () => {
  const req = (headers, remoteAddress = "10.0.0.2", encrypted = false) => ({ headers, socket: { remoteAddress, encrypted } });
  it("chỉ tin X-Forwarded-For khi trustProxy", () => {
    assert.equal(clientIp(req({ "x-forwarded-for": "203.0.113.5, 10.0.0.1" }), true), "203.0.113.5");
    assert.equal(clientIp(req({ "x-forwarded-for": "203.0.113.5" }), false), "10.0.0.2");
  });
  it("HTTPS: socket mã hóa, hoặc X-Forwarded-Proto khi trustProxy", () => {
    assert.equal(isSecureRequest(req({}, "x", true), false), true);
    assert.equal(isSecureRequest(req({ "x-forwarded-proto": "https" }), true), true);
    assert.equal(isSecureRequest(req({ "x-forwarded-proto": "https" }), false), false);
    assert.equal(isSecureRequest(req({ "x-forwarded-proto": "http" }), true), false);
  });
  it("mặc định: production tin proxy, dev không; COOKIE_SECURE ép được", () => {
    const prod = { NODE_ENV: "production", JWT_SECRET: "s", HNTH_AGENT_TOKEN: "t" };
    assert.equal(loadConfig(prod).trustProxy, true);
    assert.equal(loadConfig({}).trustProxy, false);
    assert.equal(loadConfig({ TRUST_PROXY: "true" }).trustProxy, true);
    assert.equal(loadConfig(prod).cookieSecure, "auto");
    assert.equal(loadConfig({ COOKIE_SECURE: "true" }).cookieSecure, true);
    assert.equal(loadConfig({ COOKIE_SECURE: "false" }).cookieSecure, false);
  });
});

describe("runMigrations", () => {
  function fakePool(appliedVersions = [], failOn = null) {
    const queries = [];
    const client = {
      async query(sql, params) {
        queries.push(params ? [sql, params] : sql);
        if (sql === failOn) throw new Error("boom");
        if (sql.startsWith("SELECT version FROM schema_migrations")) return { rows: appliedVersions.map((version) => ({ version })) };
        return { rows: [] };
      },
      release() { queries.push("release"); },
    };
    return { pool: { connect: async () => client }, queries };
  }
  const migrations = [
    { version: 1, name: "one", up: (client) => client.query("UP 1") },
    { version: 2, name: "two", up: (client) => client.query("UP 2") },
  ];

  it("chỉ chạy migration chưa áp dụng, mỗi cái trong transaction, có khóa", async () => {
    const { pool, queries } = fakePool([1]);
    assert.deepEqual(await runMigrations(pool, migrations, () => {}), [2]);
    const plain = queries.map((item) => Array.isArray(item) ? item[0] : item);
    assert.equal(plain[0], "SELECT pg_advisory_lock($1)");
    assert.ok(!plain.includes("UP 1"));
    assert.deepEqual(plain.slice(plain.indexOf("BEGIN"), plain.indexOf("COMMIT") + 1), ["BEGIN", "UP 2", "INSERT INTO schema_migrations(version,name) VALUES($1,$2)", "COMMIT"]);
    assert.deepEqual(plain.slice(-2), ["SELECT pg_advisory_unlock($1)", "release"]);
  });
  it("lỗi thì ROLLBACK, không ghi version, vẫn nhả khóa", async () => {
    const { pool, queries } = fakePool([], "UP 2");
    await assert.rejects(runMigrations(pool, migrations, () => {}), /Migration 2-two failed: boom/);
    const plain = queries.map((item) => Array.isArray(item) ? item[0] : item);
    assert.equal(plain.filter((sql) => sql.startsWith("INSERT INTO schema_migrations")).length, 1);
    assert.ok(plain.includes("ROLLBACK"));
    assert.deepEqual(plain.slice(-2), ["SELECT pg_advisory_unlock($1)", "release"]);
  });
  it("version phải tăng dần", async () => {
    const { pool } = fakePool();
    await assert.rejects(runMigrations(pool, [migrations[1], migrations[0]]), /strictly increasing/);
  });
});
