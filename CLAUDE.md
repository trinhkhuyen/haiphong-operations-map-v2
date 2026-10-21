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
| `services/hnth-backend` | API + SSE, `src/server.mjs` (1 file, route dạng if-chain), `src/db.mjs` (migrate idempotent lúc khởi động) | Node ESM thuần, không framework, không test |
| `services/hnth-agent` | Agent LAN: `src/agent.mjs` (logic), `desktop/main.cjs` (Electron tray + tự cập nhật) | Build `.exe` bằng electron-builder |
| `services/hnth-relay` | Relay in-memory cũ (cổng 8787) | **Lỗi thời** — backend 8788 đã thay thế. Không phát triển thêm |
| `packages/hnth-protocol` | Type dùng chung | Gần như không được dùng; backend/agent không import |

README.md mô tả `packages/contracts`, `services/api`, `infra` — **không tồn tại**, đó là kế hoạch cũ. Tin code, không tin README.

## Lệnh (đã kiểm chứng trên Windows, pnpm 11, Node 25)

```bash
pnpm install                 # nếu báo ERR_PNPM_ABORTED_REMOVE_MODULES_DIR_NO_TTY: CI=true pnpm install --frozen-lockfile
pnpm check                   # tsc -b apps/web + node --check mọi .mjs/.cjs trong services/ và scripts/ (~15s)
pnpm check:full              # như trên + vite build production (~45s)
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

Không có test tự động nào. "Xong" nghĩa là tối thiểu `pnpm check` đạt; thay đổi UI thì mở app kiểm tra bằng mắt; thay đổi backend thì chạy stack + `pnpm smoke:backend`.

## Harness đã cài (`.claude/`)

- `hooks/guard-paths.mjs` (PreToolUse): chặn sửa `.codex_tmp/`, `outputs/`, `artifacts/`, `dist/`, `node_modules/`, `pnpm-lock.yaml`, `.env.production|source|demo`.
- `hooks/post-edit-check.mjs` (PostToolUse): sửa `.ts/.tsx` trong `apps/web/src` → chạy `tsc -b`; sửa `.mjs/.cjs` → `node --check`. Lỗi được trả lại ngay — sửa trước khi làm tiếp.
- `settings.json`: allow lệnh kiểm tra/đọc git; hỏi trước commit/push/thêm dependency; cấm force-push, `reset --hard`, `down -v`, đọc file env thật.

## Quy ước & bẫy cần biết

**Trạng thái HNTH có hai từ vựng khác nhau** — đừng trộn:
- Agent/backend: `online | offline | unknown` (4/4 gói ping = online, ≥50% = unknown, còn lại = offline — xem `ping()` trong `agent.mjs`).
- Frontend (`HnthConnectionStatus`): `unknown | unconnected | connected | lost`, nhãn trong `HNTH_STATUS_LABELS`. Ánh xạ: không có IP → `unknown`; `online` → `unconnected` ("Chờ kết nối"); `offline` → `lost`. `connected` chỉ đặt thủ công. Ánh xạ này đang bị **lặp 4 chỗ** (`HnthPanel.tsx` ×3, `HnthStatusMetrics.tsx`) — nếu sửa thì sửa hết hoặc gom về `hnth-data-provider.ts`.
- IP rỗng luôn là `unknown`, kể cả khi payload nói khác (backend ép ở `/api/telemetry/ping-results`).

**Giao tiếp giữa module frontend bằng `window` CustomEvent**, không qua store: `hnth:layer-ready`, `hnth:agent-status`, `hnth:auth-expired`, `hnth:open-login`, `hnth:focus`, `hnth:test-point`, `hnth:monitor-batch`, `hnth:continuous-monitoring`, `hnth:open-point-log`, cùng các hằng `*_EVENT` trong `features/map/map-events.ts`. Grep tên event trước khi đổi.

**State**: `core/store.ts` (Zustand + `persist` vào localStorage). Thêm field bền vững → kiểm tra `partialize`/migrate để không làm hỏng state người dùng đã lưu.

**Gọi API từ web**: dùng `hnthFetch` (`core/hnth-api.ts`) — tự gắn Bearer, `no-store`, tự refresh khi 401. Base URL rỗng = same-origin `/api` (bắt buộc cho điện thoại trong LAN; đừng hardcode `localhost`).

**Backend `server.mjs`**:
- Thứ tự route quan trọng: mọi route đặt **trước** dòng `const user = await auth(req)` là công khai (live-view cho Guest + endpoint của Agent). Các bản sao `/api/hnth/status|monitor-state|discovered-ips|monitor-log|endpoints` đặt sau dòng đó là **code chết**.
- Agent xác thực bằng token chung `HNTH_AGENT_TOKEN` (mở khóa *mọi* agentId) hoặc token riêng hash trong `agents.token_hash`.
- Đổi schema: thêm `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` vào cuối `migrate()` trong `db.mjs`; không có hệ thống migration riêng.
- Lệnh tới Agent = INSERT vào `commands`; Agent claim từng lệnh `pending` mỗi 3s. Các loại hợp lệ nằm trong set `allowed` của `POST /api/agents/:id/commands`.

**Agent**:
- `config.json` cạnh exe (hoặc `%APPDATA%\HNTH Agent\`) là nguồn sự thật về token, agentId và installationId. Agent ghi lại file này khi nhận `agent-config` hoặc khi enroll.
- Định danh = `installationId` (MachineGuid + thư mục chứa config); bảng `agents` có unique index trên cột này. `register` trả 409 khi agentId đã thuộc bản cài khác, khi đó Agent gọi `/api/agents/clone` để lấy id/token riêng.
- Cập nhật từ xa dùng `src/apply-update.ps1`, không dùng Electron, vì thư mục tạm của bản portable bị xóa khi thoát. **Không** đặt `ELECTRON_RUN_AS_NODE` trong process cha.
- Không commit `services/hnth-agent/config.json`. Chi tiết luồng xem `services/hnth-agent/README.md`.

**Phong cách code hiện có**: nhiều logic bị nén trên một dòng rất dài (route backend, `UserAdminPanel.tsx`, `auth.ts`). Khi sửa một đoạn, được phép tách dòng đoạn đó cho dễ đọc, nhưng đừng reformat cả file trong cùng thay đổi.

## Không được làm

- Không sửa/đọc `.codex_tmp/` (Chrome profile của AI trước, có cookie/Login Data), `outputs/`, `artifacts/`, `services/hnth-agent/outputs/` — là rác/bản build.
- Không đưa bí mật vào code hoặc file `*.example`. Mặc định yếu đang tồn tại (`admin123`, `change-this-*`, fallback `JWT_SECRET` trong `server.mjs`) — đừng nhân bản thêm.
- Không thêm dependency, không đổi `packageManager`/lockfile mà không hỏi.
- Không commit/push khi chưa được yêu cầu. Nhánh làm việc mặc định là `main` với nhiều thay đổi chưa commit của người dùng — không `stash`/`reset`/`checkout --` lên chúng.

## Nợ kỹ thuật đã biết (chưa xử lý — hỏi trước khi sửa)

1. **Repo cũ**: từ 2026-10-21 làm việc trên `origin` = `trinhkhuyen/haiphong-operations-map-v2` (lịch sử sạch, bắt đầu từ `d8337c4`). Repo cũ `haiphong-operations-map` đã archive (chỉ đọc) trên GitHub và vẫn chứa `.codex_tmp/` trong lịch sử. Bản sao cục bộ cũ (`Documents\Map`, nhánh `legacy-main`, `.codex_tmp/`, `artifacts/`, exe 0.1.x) đã bị xóa.
2. Backend: không rate-limit `/api/auth/login`; cookie refresh thiếu `Secure`; `JWT_SECRET`/`HNTH_AGENT_TOKEN` có giá trị fallback cứng nếu thiếu env; `json()` không truyền `req` ở nhiều route nên CORS trả về origin đầu tiên; message lỗi 500 trả nguyên `error.message`.
3. Agent: lệnh `test-point` chuyển `ipAddress` chưa kiểm tra thẳng vào `ping.exe` (không qua shell, nhưng có thể chèn tham số như `-t`).
4. Web: `UserAdminPanel` reset mật khẩu về chuỗi cứng; `xlsx@0.18.5` (bản npm đã ngừng, có CVE); `MapCanvas.tsx` ~2.900 dòng; bundle `index`/`map` >900 kB.
5. Không có test, lint, CI (TASKLIST M0 vẫn mở).
