// Unit test cho phần không cần database: router, config, CORS, quyền truy cập của app.
import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { createRouter } from "../src/router.mjs";
import { loadConfig } from "../src/config.mjs";
import { createCors, readCookie } from "../src/http.mjs";
import { createApp } from "../src/app.mjs";
import { isAgentOnline } from "../src/services/realtime.mjs";
import { safeReleaseFileName, safeReleaseVersion } from "../src/services/releases.mjs";
import { normalizeRosterPointIds, normalizeRosterPoints, rosterAgentPoints } from "../src/services/rosters.mjs";

describe("router", () => {
  const router = createRouter()
    .add("GET", "/api/agents", () => "list")
    .add("POST", "/api/agents/register", () => "register", { public: true })
    .add("POST", "/api/agents/:agentId/commands", () => "commands")
    .add("PATCH", "/api/agents/:agentId", () => "patch");

  it("khớp chính xác method và số đoạn", () => {
    assert.equal(router.match("GET", "/api/agents").route.handler(), "list");
    assert.equal(router.match("POST", "/api/agents"), null);
    assert.equal(router.match("GET", "/api/agents/x"), null);
  });
  it("ưu tiên đoạn cố định theo thứ tự đăng ký, giữ cờ public", () => {
    const match = router.match("POST", "/api/agents/register");
    assert.equal(match.route.handler(), "register");
    assert.equal(match.route.public, true);
  });
  it("giải mã tham số; tham số lỗi thì không khớp", () => {
    assert.deepEqual(router.match("POST", "/api/agents/agent%20a/commands").params, { agentId: "agent a" });
    assert.equal(router.match("PATCH", "/api/agents/%E0%A4%A"), null);
  });
  it("bỏ qua dấu / thừa", () => {
    assert.ok(router.match("GET", "/api/agents/"));
  });
});

describe("config", () => {
  it("dev: có giá trị mặc định", () => {
    const config = loadConfig({});
    assert.equal(config.production, false);
    assert.equal(config.port, 8788);
    assert.ok(config.jwtSecret && config.agentToken);
    assert.deepEqual(config.webOrigins, ["http://127.0.0.1:5173"]);
  });
  it("production: thiếu JWT_SECRET hoặc HNTH_AGENT_TOKEN thì dừng", () => {
    assert.throws(() => loadConfig({ NODE_ENV: "production", JWT_SECRET: "x" }), /HNTH_AGENT_TOKEN/);
    assert.throws(() => loadConfig({ NODE_ENV: "production", HNTH_AGENT_TOKEN: " " }), /JWT_SECRET/);
    assert.equal(loadConfig({ NODE_ENV: "production", JWT_SECRET: "a", HNTH_AGENT_TOKEN: "b" }).jwtSecret, "a");
  });
  it("WEB_ORIGIN nhiều giá trị", () => {
    assert.deepEqual(loadConfig({ WEB_ORIGIN: "http://a, http://b ,," }).webOrigins, ["http://a", "http://b"]);
  });
});

describe("http", () => {
  it("CORS: phản hồi đúng origin hợp lệ, còn lại trả origin đầu tiên", () => {
    const cors = createCors(["http://a", "http://b"]);
    assert.equal(cors({ headers: { origin: "http://b" } }), "http://b");
    assert.equal(cors({ headers: { origin: "http://evil" } }), "http://a");
    assert.equal(createCors(["*"])({ headers: { origin: "http://x" } }), "http://x");
  });
  it("đọc cookie theo tên", () => {
    assert.equal(readCookie({ headers: { cookie: "a=1; hnth_refresh=abc; b=2" } }, "hnth_refresh"), "abc");
    assert.equal(readCookie({ headers: {} }, "hnth_refresh"), undefined);
  });
});

describe("services", () => {
  it("agent online trong 30 giây", () => {
    const now = Date.parse("2026-10-21T00:00:30Z");
    assert.equal(isAgentOnline("2026-10-21T00:00:01Z", now), true);
    assert.equal(isAgentOnline("2026-10-21T00:00:00Z", now), false);
    assert.equal(isAgentOnline(null, now), false);
  });
  it("tên/version release an toàn", () => {
    assert.equal(safeReleaseVersion(" 0.2.4 "), "0.2.4");
    assert.equal(safeReleaseVersion("../x"), null);
    assert.equal(safeReleaseFileName("..\\..\\a b.exe"), "a_b.exe");
  });
});

// Không có Bearer token thì app trả 401 trước khi chạm database.
describe("app: quyền truy cập", () => {
  const { handle } = createApp(loadConfig({ WEB_ORIGIN: "http://web" }));
  const call = (method, url, headers = {}) => new Promise((resolve) => {
    const res = { status: 0, headers: {}, body: "", writeHead(status, h) { this.status = status; this.headers = h; }, end(body) { this.body = body; resolve(this); } };
    handle({ method, url, headers }, res);
  });

  it("route riêng tư và đường dẫn lạ: chưa đăng nhập → 401", async () => {
    assert.equal((await call("GET", "/api/users")).status, 401);
    assert.equal((await call("GET", "/api/khong-ton-tai")).status, 401);
  });
  it("các route chết đã bỏ cũng trả 401 như trước (không còn bản sao sau bước auth)", async () => {
    assert.equal((await call("POST", "/api/hnth/status")).status, 401);
  });
  it("OPTIONS: 204 kèm CORS đúng origin", async () => {
    const res = await call("OPTIONS", "/api/users", { origin: "http://web" });
    assert.equal(res.status, 204);
    assert.equal(res.headers["access-control-allow-origin"], "http://web");
  });
});

describe("danh sách điểm phiên họp", () => {
  const point = (patch) => ({ pointId: "hnth-branch-1", kind: "ward", name: "UBND Ái Quốc", ipAddress: "10.0.0.1", ...patch });
  it("chuẩn hóa và giữ đủ 3 loại điểm", () => {
    const { points, error } = normalizeRosterPoints([point({}), point({ pointId: "hnth-hub", kind: "hub", name: " Trung tâm Chính trị - Hành chính ", ipAddress: "" }), point({ pointId: "hnth-extra-so-y-te", kind: "extra", name: "Sở Y tế", ipAddress: "10.0.0.9", gateway: " 10.0.0.1 " })]);
    assert.equal(error, undefined);
    assert.deepEqual(points.map((item) => [item.kind, item.name, item.ipAddress, item.gateway]), [["ward", "UBND Ái Quốc", "10.0.0.1", ""], ["hub", "Trung tâm Chính trị - Hành chính", "", ""], ["extra", "Sở Y tế", "10.0.0.9", "10.0.0.1"]]);
  });
  it("từ chối mã sai loại, trùng điểm, IP sai hoặc trùng", () => {
    assert.match(normalizeRosterPoints([point({ kind: "extra" })]).error, /mã điểm/);
    assert.match(normalizeRosterPoints([point({}), point({ ipAddress: "10.0.0.2" })]).error, /trùng/);
    assert.match(normalizeRosterPoints([point({ ipAddress: "999.1.1.1" })]).error, /IP/);
    assert.match(normalizeRosterPoints([point({}), point({ pointId: "hnth-branch-2", name: "B" })]).error, /trùng với "UBND Ái Quốc"/);
    assert.match(normalizeRosterPoints("x").error, /mảng/);
  });
  it("danh sách phiên họp chỉ chứa mã điểm có trong dữ liệu chủ", () => {
    const catalog = new Set(["hnth-hub", "hnth-branch-1"]);
    assert.deepEqual(normalizeRosterPointIds(["hnth-hub", "hnth-hub", " hnth-branch-1 "], catalog).pointIds, ["hnth-hub", "hnth-branch-1"]);
    assert.match(normalizeRosterPointIds(["hnth-extra-x"], catalog).error, /không có trong dữ liệu/);
    assert.match(normalizeRosterPointIds([], catalog).error, /ít nhất 1/);
    assert.match(normalizeRosterPointIds(["hnth-hub"], new Set()).error, /Import trước/);
  });
  it("chỉ giao cho Agent các điểm có IP", () => {
    assert.deepEqual(rosterAgentPoints([point({}), point({ pointId: "hnth-hub", kind: "hub", ipAddress: "" })]).map((item) => item.pointId), ["hnth-branch-1"]);
  });
});
