# Bàn giao refactor module hóa — đã xong 8 giai đoạn (2026-10-21)

Tài liệu cho phiên làm việc tiếp theo. Đọc cùng `CLAUDE.md` (quy ước, lệnh, bẫy). GĐ0–3 đã có trên `origin/main` của `trinhkhuyen/haiphong-operations-map-v2`; từ GĐ4 trở đi là commit cục bộ cho tới khi người dùng bảo push (`git status -sb` để xem).

## Cách bắt đầu phiên mới

Gửi cho Claude:

> Đọc `CLAUDE.md` và `docs/REFACTOR-HANDOFF.md`. Refactor module hóa đã xong; chọn việc tiếp theo trong mục "Việc tiếp theo đề xuất".

Trước mỗi thay đổi: `pnpm check && pnpm test && pnpm test:e2e` phải đạt (mốc xanh hiện tại: web 57, protocol 8, backend 23, agent 19 unit test; e2e 9/9; eslint sạch).

## Nguyên tắc đã thống nhất (người dùng đã duyệt)

- Mỗi giai đoạn **không đổi hành vi** (API, giao diện, dữ liệu người dùng đã lưu). Thay đổi có chủ ý phải ghi rõ trong commit.
- Mỗi giai đoạn một commit (hoặc chuỗi commit nhỏ) kiểm tra và hoàn tác riêng được. Lập kế hoạch, làm, rồi commit; **push chỉ khi người dùng bảo**.
- Test là test đặc tả: test đỏ sau refactor nghĩa là sửa code, không sửa test.
- Thứ tự: GĐ0 → 1 → 2 → **3 → 4 → 5 → 7 → 6 → 8** (MapCanvas để gần cuối).

## Đã xong

| GĐ | Commit | Nội dung |
|---|---|---|
| — | `54fb7b6`, `e062984`, `8d22616` | Tính năng trước refactor: cập nhật Agent từ xa (updater PowerShell, đọc version từ exe, cài lại/hạ cấp), định danh bản cài (installationId, bản copy tự xin id), version trên tray, chọn agent cho HNTH (lưu ở `monitor_state`) |
| 0 | `2b21e2e` | Lưới an toàn: vitest cho web (hàm thuần, store + hình dạng persist, CSV, version exe); `scripts/e2e/` chạy backend + agent thật trên schema Postgres riêng |
| 1 | `0e7bc94` | `packages/hnth-protocol` (ESM + `.d.ts`): `toConnectionStatus`, `classifyProbeResult`, `OPERATOR_COMMAND_TYPES`, `readExeVersion`, `compareVersions`. Web, backend, agent đều import; exe Agent kèm package qua `extraResources` |
| 2 | `71dcfa8` | Backend tách `config/http/router/auth/app`, `services/{realtime,releases}`, `routes/{auth,users,agent-api,agents,telemetry,hnth}`. Bỏ 6 route chết; production bắt buộc `JWT_SECRET`/`HNTH_AGENT_TOKEN`; CORS trả đúng origin cho mọi route |
| 3 | `65d8866` | Agent: `agent.mjs` → `src/index.mjs` (entry) + `config`, `identity`, `backend-client`, `probes/{ping,snmp,scan}`, `telemetry`, `monitor`, `commands`, `updater`, `util`. 19 unit test ở `services/hnth-agent/test/`. Thay đổi có chủ ý duy nhất: `pingHost` chỉ gọi `ping.exe` với literal IP; chuỗi khác (kể cả tên máy, trước đây ping được qua `test-point`) bị coi là mất gói → `offline`. Điểm cấu hình qua backend vốn đã là `inet` nên không ảnh hưởng. Đã kiểm chứng exe đóng gói thật (đăng ký, ping, test-point, cập nhật từ xa 0.2.4→0.2.5) với backend tạm |
| 4 | `8656c94` | Web: `core/api/` (`API_BASE` duy nhất, `hnthFetch`, client `hnthApi`/`agentsApi`), `core/realtime/` (một SSE + một vòng poll `monitor-state` cho cả trang, `useHnthLiveStore` cho backend/agent/cờ giám sát, `subscribeMonitorBatches`), `core/events.ts` (event bus có kiểu, giữ tên event cũ). Bỏ event `hnth:agent-status`, `hnth:continuous-monitoring`, `hnth:monitor-batch` và các hằng `*_EVENT`. 8 unit test mới. Thay đổi có chủ ý: (1) status bar dùng chung snapshot nên làm mới mỗi 2–5 s thay vì 10 s, và số request `monitor-state` giảm từ 3 nguồn còn 1; (2) `auth.ts`, `HnthStatusMetrics`, `UserAdminPanel`, `AgentsPanel` nay cũng dùng `API_BASE` (trước đây bỏ qua `VITE_HNTH_RELAY_URL`, riêng `AgentsPanel` bỏ qua cả `VITE_HNTH_BACKEND_URL`) — chỉ khác khi đặt biến này khác rỗng |
| 5 | `227756f` | `core/store.ts` chỉ ráp slice + persist; slice trong `core/store/`: `ui`, `layers`, `map`, `administrative`, `drawing`, `annotations` (kèm thao tác Đối tượng đã lưu), `hnth`; `persist.ts` giữ nguyên key, version 4, `migrate`, `partialize` (21 trường), `merge`. Thuộc tính được chép nguyên văn theo tên khóa bằng script. Test mới: không slice nào trùng khóa, đủ 113 trường. Không đổi hành vi |
| 7 | `1953faa`, `04ac392` | `HnthPanel` 1.094 → 429 dòng: `useHnthLiveSync` (effect đồng bộ realtime, chép nguyên văn cùng deps), `HnthPointConfigForm`, `HnthAgentSelector`, `HnthPointList`, `HnthStatusStyleEditor`, `HnthDeviceInfoModal`, `hnth-import-export.ts`, `hnth-report.ts`, `hnth-types.ts`. `HnthStatusMetrics`: `HnthMonitorLogPopup`, `HnthPointLogPopup` + `useHnthPointLog`. `App.tsx` 318 → 132: `features/auth/` (`useAuth`, `UserMenu`, `AuthModal`, `LoginGate`), `SystemStatusBar`, `GlobalSearch`, `PanelErrorBoundary`, `useOperationalLayerLoader`. `UserAdminPanel` viết lại cho đọc được, dùng `usersApi`. `xlsx` chỉ còn import ở `core/spreadsheet.ts`. Bỏ code chết (`csvEscape`, `pdfText`, khối thống kê camera `{false && …}`). Thay đổi có chủ ý (người dùng chọn): Reset MK không còn đặt về `rgb@2026` mà mở hộp thoại cho Admin nhập mật khẩu mới ≥ 8 ký tự. Đã kiểm chứng trên app thật (Khách) và trên backend tạm có đăng nhập Admin (tạo tài khoản, reset MK: MK cũ/`rgb@2026` → 401, MK mới → 200) |

| 6 | `3bfcdf1`, `b4bc9e7`, `7144ffc` | `MapCanvas.tsx` 2.881 → 119 dòng. Bước A: 80 khai báo cấp module → `features/map/lib/{base-style,viewport,administrative,drawing,annotations,operational-layers,hnth-layer}` + `MapInfoCards.tsx`. Bước B: `useMapScope()` tạo ref/state dùng chung; 11 hook trong `features/map/hooks/` (`useMapInspection`, `useMapInstance`, `useMapCamera`, `useOperationalLayersSync`, `useDrawingSync`, `useAdministrativeLayers`, `useHnthMapSync`, `useAdministrativeSelection`, `useVietnamProvinceBoundaries`, `useHnthHubPulse`, `usePresentationBridge`). Effect/callback chép nguyên văn cùng deps (script so từng khoảng dòng); thứ tự gọi hook giữ ràng buộc: map dựng trước, lớp địa giới trước đồng bộ HNTH và viền kiểm tra. 9 test cho hàm thuần `map/lib`. Không đổi hành vi; đã thử trên app (fit ban đầu, HNTH, phím tắt, click địa giới, Esc, khoanh vùng, Home, vẽ + Delete) |
| 8 | `afea38e` | `styles/global.css` chỉ còn font + `@import` theo thứ tự: `base`, `layout`, `topbar`, `panels`, `map`, `zones`, `responsive`, `saved-objects`, `map-overlays`, `hnth`, `layers`, `agents`, `topbar-state`, `hnth-monitor`, `admin-users`, `map-mobile`, `auth`, `user-menu`. Chỉ gom lại các đoạn không dùng chung class (script kiểm tra); bản build có cùng 871 quy tắc. **Thứ tự import là thứ tự cascade — đừng đổi tùy ý** |

### Cách kiểm chứng giao diện cần đăng nhập
- Không dùng tài khoản thật. Dựng backend tạm như e2e (`scripts/e2e/helpers.mjs`: schema Postgres riêng, admin có mật khẩu sinh ngẫu nhiên) ở một cổng riêng, và một Vite phụ (`VITE_PROXY_TARGET=http://127.0.0.1:<cổng>`, `--port 5174`) chạy qua một cấu hình tạm trong `.claude/launch.json`. Xong thì gỡ cấu hình và `DROP SCHEMA` (dừng preview là kill thẳng, script không kịp dọn).

### Cách kiểm chứng exe Agent (dùng lại khi đổi agent)
- Build ra scratchpad bằng bản sao `electron-builder.yml` chỉ đổi `directories.output` và nguồn `config.json` (dùng config giả, tránh nhúng token thật): `electron-builder --win portable --config <copy> -c.extraMetadata.version=<x>`.
- Đặt `config.json` (backendUrl = backend tạm) **cạnh exe**, không dùng env `HNTH_AGENT_CONFIG`: updater khởi động lại exe qua WMI nên không kế thừa env.
- Dọn: chỉ dừng tiến trình có `ExecutablePath` trong thư mục thử cùng cây con của chúng — **người dùng chạy Agent thật cùng tên `Agent HNTH`**.

## Việc tiếp theo đề xuất (chưa làm)

- Đã làm sau refactor (2026-10-21): xóa `services/hnth-relay`; backend: giới hạn đăng nhập, cookie `Secure` theo HTTPS, lỗi 500 không lộ chi tiết, kiểm tra mật khẩu khi `PUT /api/users/:id` và IP của `/api/hnth/test`, migration theo version (`src/migrations/`, `schema_migrations`); web: lazy-load `xlsx`/panel/báo cáo (JS ban đầu ~2,2 MB → ~1,7 MB, chunk `index` 960 → 194 kB); ESLint + GitHub Actions CI.
- Thay `xlsx@0.18.5` khi người dùng đồng ý (chỉ sửa `core/spreadsheet.ts`).
- Nếu chạy nhiều tiến trình backend: chuyển bộ giới hạn đăng nhập sang Postgres/Redis.
- Hai CSS file lớn nhất còn dòng dài (`zones.css`, `hnth.css`): có thể tách dòng cho dễ đọc, giữ nguyên thứ tự quy tắc.

## Quyết định còn chờ người dùng

1. ~~Xóa `services/hnth-relay`~~ — đã xóa theo yêu cầu người dùng.
2. Thay `xlsx@0.18.5` (có CVE): người dùng chọn **để sau**; mọi chỗ dùng đã gom vào `core/spreadsheet.ts`, khi thay chỉ sửa file đó.
3. ~~Migration theo phiên bản~~ — người dùng chọn runner tự viết; đã làm (`src/migrator.mjs`).

## Trạng thái môi trường máy dev (lúc bàn giao)

- Backend `pnpm --filter @haiphong-ops/hnth-backend dev` (8788, chế độ `--watch`, env dev) và frontend Vite (5173, `--host 0.0.0.0`) chạy trong hai tab Terminal của app Claude. **Backend tự nạp lại khi sửa file** — sửa backend là ảnh hưởng ngay phiên giám sát thật; chạy `pnpm smoke:backend` sau mỗi lần lưu.
- Postgres local 5432 (`hnth`/`hnth_local_password`), không có Docker Desktop chạy.
- Người dùng đang chạy Agent 0.2.x thật và một phiên Giám sát liên tục; e2e và các bài thử dùng schema/cổng riêng, không đụng dữ liệu thật.
- Agent build thử ở `outputs/hnth-agent-v0.2.x/` (bị git bỏ qua).
