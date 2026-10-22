# CLAUDE.md — Bản đồ giám sát vận hành Hải Phòng (HNTH)

Trả lời người dùng bằng tiếng Việt. Comment trong code giữ phong cách hiện có (tiếng Việt hoặc tiếng Anh ngắn, giải thích *vì sao*).

## Hệ thống là gì

WebGIS cho trung tâm điều hành TP Hải Phòng. Trọng tâm hiện tại là **giám sát Hội nghị truyền hình (HNTH)**: Agent Windows trong LAN ping các điểm cầu, đẩy kết quả lên backend, bản đồ hiển thị trạng thái realtime.

```
Agent (Windows tray, Electron)  --HTTPS outbound, Bearer token-->  hnth-backend (Node http + Postgres)
        ping / ARP / SNMP                                               |  SSE /api/hnth/stream
        poll lệnh mỗi 3s  <-- bảng `commands` --                        v
                                                     apps/web (React 19 + MapLibre + Zustand)
```

| Thư mục | Vai trò | Ghi chú |
|---|---|---|
| `apps/web` | Frontend Vite/React/TS (strict) | Thành phần duy nhất có typecheck |
| `services/hnth-backend` | API + SSE. `src/server.mjs` (entry), `app.mjs` (ráp router), `routes/*.mjs` theo nhóm, `services/` (realtime/SSE, release), `auth.mjs`, `config.mjs`, `db.mjs` (migrate idempotent lúc khởi động) | Node ESM thuần, router tự viết, không framework; unit test ở `test/` |
| `services/hnth-agent` | Agent LAN: `src/index.mjs` (entry, chạy ngay khi import), `config`, `identity` (installationId/register/clone/heartbeat), `backend-client`, `probes/{ping,snmp,scan}`, `telemetry`, `monitor`, `commands`, `updater`; `desktop/main.cjs` (Electron tray, import `src/index.mjs`) | Build `.exe` bằng electron-builder; unit test ở `test/` (ngoài `src` để không bị đóng vào exe) |
| `packages/hnth-protocol` | Hợp đồng dùng chung (ESM thuần + `index.d.ts`): từ vựng trạng thái, `toConnectionStatus`, `classifyProbeResult`, `OPERATOR_COMMAND_TYPES`, `readExeVersion`, `compareVersions` | Web, backend, agent đều import. Bản exe Agent kèm package này qua `extraResources` trong `electron-builder.yml` — thêm file mới vào package thì kiểm tra filter ở đó |

README.md mô tả `packages/contracts`, `services/api`, `infra` — **không tồn tại**, đó là kế hoạch cũ. Tin code, không tin README.

Refactor module hóa 8 giai đoạn đã xong; lịch sử, cách kiểm chứng (exe Agent, giao diện cần đăng nhập) và quyết định chờ duyệt ở `docs/REFACTOR-HANDOFF.md`.

Bản đồ (`apps/web/src/features/map/`): `MapCanvas.tsx` chỉ ráp JSX; ref/state dùng chung ở `hooks/useMapScope.ts`, mỗi nhóm effect là một hook trong `hooks/` (thứ tự gọi hook có ý nghĩa: map dựng trước, lớp địa giới trước đồng bộ HNTH), hàm thao tác MapLibre/Terra Draw ở `lib/`. CSS: `styles/global.css` chỉ `@import` các file theo tính năng — **thứ tự import là thứ tự cascade**, thêm quy tắc vào đúng file thay vì đổi thứ tự.

## Lệnh (đã kiểm chứng trên Windows, pnpm 11, Node 25)

```bash
pnpm install                 # nếu báo ERR_PNPM_ABORTED_REMOVE_MODULES_DIR_NO_TTY: CI=true pnpm install --frozen-lockfile
pnpm lint                    # eslint toàn workspace (flat config ở eslint.config.mjs)
pnpm check                   # eslint + tsc -b apps/web + node --check mọi .mjs/.cjs trong services/ và scripts/ (~20s)
pnpm check:full              # như trên + unit test + vite build production (~50s)
pnpm test                    # unit test web (vitest) + hnth-protocol, backend, agent (node:test), ~5s
pnpm test:e2e                # e2e backend + agent thật trên schema Postgres riêng, cổng ngẫu nhiên (~20s); không có Postgres thì skip
pnpm dev                     # chỉ frontend, http://127.0.0.1:5173 (proxy /api -> 127.0.0.1:8788)
pnpm smoke:backend           # smoke test chỉ-đọc vào backend đang chạy (BACKEND_URL, SMOKE_USER/SMOKE_PASSWORD tùy chọn)
```

Chạy cả stack (cần Docker Desktop đang chạy và file `.env.source` copy từ `.env.source.example`):

```bash
docker compose --env-file .env.source -f docker-compose.source.yml up -d --build
```

- **Luôn** truyền `--env-file`; thiếu nó Compose dùng default trong YAML → token Agent lệch backend.
- **Không bao giờ** `down -v` (xóa volume Postgres).
- Backend cần Postgres; không có Docker thì chỉ chạy được frontend — frontend tự rơi về dữ liệu demo khi backend offline.
- Trong Claude desktop: `.claude/launch.json` có `web-running` (gắn vào server đã chạy sẵn ở 5173), `web` (tự chạy Vite) và `stack-docker`. Trên máy dev hiện tại thường đã có sẵn node:5173 + node:8788 + postgres:5432 đang chạy — kiểm tra `netstat -ano | grep 5173` trước khi khởi động thêm.
- `pnpm smoke:backend` trỏ thẳng vào 8788 (hoặc domain Caddy), không trỏ vào Vite 5173 vì Vite chỉ proxy `/api`.

"Xong" nghĩa là `pnpm check` (đã gồm eslint) và `pnpm test` đạt; đụng backend hoặc agent thì thêm `pnpm test:e2e`; thay đổi UI thì mở app kiểm tra bằng mắt.

- Test là test đặc tả (characterization): ghi lại hành vi hiện tại làm mốc cho refactor. Test đỏ sau khi refactor nghĩa là hành vi đã đổi, cần sửa code chứ không sửa test, trừ khi thay đổi hành vi là chủ ý.
- Unit test đặt cạnh file nguồn (`*.test.ts`), chạy môi trường node; store test phải stub `window.localStorage`, vì thiếu nó thì zustand persist tắt hẳn.
- E2E ở `scripts/e2e/` (`helpers.mjs` dựng Postgres schema `hnth_e2e_<pid>`, backend và agent node); `E2E_DATABASE_URL` để đổi DB. Test không đụng backend 8788 hay dữ liệu thật.

## Harness đã cài (`.claude/`)

- `hooks/guard-paths.mjs` (PreToolUse): chặn sửa `.codex_tmp/`, `outputs/`, `artifacts/`, `dist/`, `node_modules/`, `pnpm-lock.yaml`, `.env.production|source|demo`.
- `hooks/post-edit-check.mjs` (PostToolUse): sửa `.ts/.tsx` trong `apps/web/src` → chạy `tsc -b`; sửa `.mjs/.cjs` → `node --check`. Lỗi được trả lại ngay — sửa trước khi làm tiếp.
- `settings.json`: allow lệnh kiểm tra/đọc git; hỏi trước commit/push/thêm dependency; cấm force-push, `reset --hard`, `down -v`, đọc file env thật.

## Quy ước & bẫy cần biết

**Trạng thái HNTH có hai từ vựng khác nhau** — đừng trộn:
- Agent/backend: `online | offline | unknown` (4/4 gói ping = online, ≥50% = unknown, còn lại = offline — `classifyProbeResult` trong `hnth-protocol`).
- Frontend (`HnthConnectionStatus` = `ConnectionStatus`): `unknown | unconnected | connected | lost`, nhãn trong `HNTH_STATUS_LABELS`. Ánh xạ duy nhất ở `toConnectionStatus(agentStatus, hasIp)` trong `hnth-protocol`: không có IP → `unknown`; `online` → `unconnected` ("Chờ kết nối"); `offline` → `lost`. `connected` chỉ đặt thủ công.
- IP rỗng luôn là `unknown`, kể cả khi payload nói khác (backend ép ở `/api/telemetry/ping-results`).

**Lệnh giữa module frontend** (điều khiển bản đồ, mở popup/đăng nhập) đi qua `core/events.ts`: `emitAppEvent(name, detail)` / `onAppEvent(name, handler)` (trả hàm hủy), kiểu detail khai báo trong `AppEventMap`. Bên dưới vẫn là `window` CustomEvent với tên cũ (`hnth:*`, `map:*`). Thêm lệnh mới = thêm vào `AppEventMap`, không `window.dispatchEvent` tay.

**Dữ liệu realtime HNTH** đi qua `core/realtime/`: `hnth-realtime.ts` giữ **một** EventSource `/api/hnth/stream` và **một** vòng poll `/api/hnth/monitor-state` cho cả trang (chu kỳ = ngắn nhất mà subscriber yêu cầu; `subscribeHnthSnapshots`, `subscribeHnthStream`, `subscribeMonitorBatches`, `refreshHnthSnapshot`). Trạng thái backend, agent đang chọn và cờ giám sát nằm ở `useHnthLiveStore` (không persist), được ghi **trước** khi gọi listener. Cần phản ứng đồng bộ (vd reset log trước batch đầu của phiên mới) thì dùng `useHnthLiveStore.subscribe`, không dùng effect theo render. Không còn event `hnth:agent-status`, `hnth:continuous-monitoring`, `hnth:monitor-batch`.

**State**: `core/store.ts` (Zustand + `persist` vào localStorage) ráp các slice trong `core/store/` (`ui`, `layers`, `map`, `administrative`, `drawing`, `annotations`, `hnth`). Thêm trường vào slice phù hợp; action được đọc/ghi trường slice khác qua `set`/`get`. Thêm field bền vững → sửa `core/store/persist.ts` (`partialize`/`merge`/migrate) để không làm hỏng state người dùng đã lưu.

**Gọi API từ web**: dùng client trong `core/api/clients.ts` (`hnthApi`, `agentsApi`), hoặc `hnthFetch(apiUrl(path))` (`core/api/http.ts`, `core/api/base.ts`) — tự gắn Bearer, `no-store`, tự refresh khi 401. `API_BASE` là nơi duy nhất đọc `VITE_HNTH_BACKEND_URL`; rỗng = same-origin `/api` (bắt buộc cho điện thoại trong LAN; đừng hardcode `localhost`). Riêng `core/auth.ts` gọi `fetch` thẳng (login/refresh không được tự refresh).

**Backend**:
- Thêm route: `router.add(method, "/api/x/:id", handler, { public })` trong `routes/<nhóm>.mjs`. Mặc định route **cần đăng nhập** (app.mjs xác thực JWT trước, gán `user`); `public: true` chỉ cho live-view của Guest và API của Agent (tự kiểm tra token agent bằng `auth.agentAuthorizedForId`). Đường dẫn không khớp: chưa đăng nhập → 401, đã đăng nhập → 404.
- Handler nhận `{ req, res, url, params, user, reply, readBody, corsOrigin }`; trả JSON bằng `reply(status, body, headers)`.
- `config.mjs`: production (`NODE_ENV=production`) dừng khởi động nếu thiếu `JWT_SECRET`/`HNTH_AGENT_TOKEN`; dev dùng giá trị local.
- Agent xác thực bằng token chung `HNTH_AGENT_TOKEN` (mở khóa *mọi* agentId) hoặc token riêng hash trong `agents.token_hash`.
- Đổi schema: thêm file `src/migrations/NNN-ten.mjs` (`export async function up(client)`) và một dòng trong `src/migrations/index.mjs`. `src/migrator.mjs` chạy các version chưa có trong bảng `schema_migrations` lúc khởi động, mỗi version một transaction, có khóa advisory. **Không sửa migration đã phát hành**; `001-baseline` là script idempotent cũ.
- Bảo mật: `/api/auth/login` giới hạn 5 lần sai / (IP + tài khoản) và 30 / IP trong 15 phút (`services/login-limiter.mjs`, bộ nhớ trong tiến trình). Cookie refresh có `Secure` khi request là HTTPS; `TRUST_PROXY` (mặc định bật ở production, backend nằm sau Caddy) quyết định có tin `X-Forwarded-For/-Proto`; `COOKIE_SECURE=true|false` để ép. Lỗi không bắt được trả `{"error":"internal error"}` (chi tiết chỉ ở log).
- **Lease giám sát**: bật giám sát cấp `monitor_state.lease_expires_at` (`MONITOR_LEASE_SECONDS`); trang Operator đang mở gọi `POST /api/hnth/monitor/lease` mỗi `MONITOR_LEASE_RENEW_SECONDS` (`HnthPanel`). Hết hạn → `realtime.expireMonitorLease` (khi đọc state + sweeper 15s) tắt cờ và gửi `monitor-stop` `reason: lease-expired`. Agent tự `stop()` khi không có phản hồi 2xx từ backend quá `AGENT_BACKEND_LOSS_STOP_SECONDS`, và không tự chạy lại.
- **Dữ liệu chủ điểm cầu + danh sách phiên họp**: `hnth_catalog` (migration 004, nạp bằng Import, có tên/IP/Gateway/Model của mọi điểm: xã/phường, Trung tâm, Sở/Ban/Ngành) và `hnth_rosters.point_ids` (danh sách chỉ chọn mã điểm từ dữ liệu chủ); `monitor_state.active_roster_id` NULL = toàn bộ dữ liệu chủ (chưa Import = 115 điểm mặc định). Route `routes/hnth-rosters.mjs`, kiểm tra `services/rosters.mjs`. Agent chỉ nhận điểm của phiên (`sessionPoints`). Snapshot công khai có `catalog` + `activeRoster` → web dựng lớp HNTH bằng `composeHnthLayer` (xã/phường ngoài phiên bị loại; Sở/Ban/Ngành là Point `role: "extra"` tại tọa độ Trung tâm, hiện bằng card `HnthExtraCards`). Import mở `HnthCatalogEditor` (bản nháp phân loại bởi `hnth-roster.ts`); chọn điểm cho danh sách ở `HnthRosterEditor`. Mã Sở/Ban/Ngành sinh từ tên khi tạo, giữ nguyên khi đổi tên.
- Lệnh tới Agent = INSERT vào `commands`; Agent claim từng lệnh `pending` mỗi 3s. Các loại Operator được gửi nằm trong `OPERATOR_COMMAND_TYPES` (`hnth-protocol`); `agent-config` chỉ backend tạo.

**Agent**:
- `config.json` cạnh exe (hoặc `%APPDATA%\HNTH Agent\`) là nguồn sự thật về token, agentId và installationId. Agent ghi lại file này khi nhận `agent-config` hoặc khi enroll.
- Định danh = `installationId` (MachineGuid + thư mục chứa config); bảng `agents` có unique index trên cột này. `register` trả 409 khi agentId đã thuộc bản cài khác, khi đó Agent gọi `/api/agents/clone` để lấy id/token riêng.
- Cập nhật từ xa dùng `src/apply-update.ps1`, không dùng Electron, vì thư mục tạm của bản portable bị xóa khi thoát. **Không** đặt `ELECTRON_RUN_AS_NODE` trong process cha.
- Không commit `services/hnth-agent/config.json`. Chi tiết luồng xem `services/hnth-agent/README.md`.

**Phong cách code hiện có**: nhiều logic bị nén trên một dòng rất dài (route backend, `UserAdminPanel.tsx`, `auth.ts`). Khi sửa một đoạn, được phép tách dòng đoạn đó cho dễ đọc, nhưng đừng reformat cả file trong cùng thay đổi.

## Không được làm

- Không sửa/đọc `.codex_tmp/` (Chrome profile của AI trước, có cookie/Login Data), `outputs/`, `artifacts/`, `services/hnth-agent/outputs/` — là rác/bản build.
- Không đưa bí mật vào code hoặc file `*.example`. Mặc định yếu đang tồn tại (`admin123`, `change-this-*`, giá trị dev trong `config.mjs`) — đừng nhân bản thêm.
- Không thêm dependency, không đổi `packageManager`/lockfile mà không hỏi.
- Không commit/push khi chưa được yêu cầu. Nhánh làm việc mặc định là `main` với nhiều thay đổi chưa commit của người dùng — không `stash`/`reset`/`checkout --` lên chúng.

## Nợ kỹ thuật đã biết (hỏi trước khi sửa)

1. **Repo cũ**: từ 2026-10-21 làm việc trên `origin` = `trinhkhuyen/haiphong-operations-map-v2` (lịch sử sạch, bắt đầu từ `d8337c4`). Repo cũ `haiphong-operations-map` đã archive (chỉ đọc) trên GitHub và vẫn chứa `.codex_tmp/` trong lịch sử. Bản sao cục bộ cũ (`Documents\Map`, nhánh `legacy-main`, `.codex_tmp/`, `artifacts/`, exe 0.1.x) đã bị xóa.
2. Backend: bộ giới hạn đăng nhập nằm trong bộ nhớ (chạy nhiều tiến trình backend thì mỗi tiến trình đếm riêng); chưa có migration `down`.
3. Agent: khi `backendUrl` rỗng vẫn dùng `relayUrl` làm URL telemetry (relay cũ đã xóa; config mẫu trỏ `relayUrl` về backend).
4. Web: `xlsx@0.18.5` (bản npm đã ngừng, có CVE) — đã gom vào `core/spreadsheet.ts` và chỉ tải khi nhập/xuất Excel; người dùng chọn thay sau. Chunk `map` (maplibre-gl) ~1 MB là file dist sẵn, không giảm được.
5. CI (`.github/workflows/ci.yml`) chạy check --build, unit test và e2e trên Postgres; `react-hooks/exhaustive-deps` cố ý tắt.
