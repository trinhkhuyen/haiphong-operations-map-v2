# Bàn giao refactor module hóa — trạng thái ngày 2026-10-21

Tài liệu cho phiên làm việc tiếp theo. Đọc cùng `CLAUDE.md` (quy ước, lệnh, bẫy). Mọi thứ dưới đây đã có trên `origin/main` của `trinhkhuyen/haiphong-operations-map-v2`.

## Cách bắt đầu phiên mới

Gửi cho Claude:

> Đọc `CLAUDE.md` và `docs/REFACTOR-HANDOFF.md`, rồi lập kế hoạch và làm Giai đoạn 3 (tách module agent).

Trước mỗi giai đoạn: `pnpm check && pnpm test && pnpm test:e2e` phải đạt (mốc xanh hiện tại: web 39, protocol 8, backend 14 unit test; e2e 8/8).

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

## Còn lại

### GĐ3 — Agent tách module (`services/hnth-agent/src/agent.mjs`, 450 dòng)
- Hiện file chạy ngay khi import (đọc config ở top-level), nên chưa test được. Tách: `config`, `identity` (installationId, enroll/clone), `backend-client`, `probes/{ping,snmp,scan}`, `monitor` (vòng giám sát, xoay vòng, gửi thay đổi), `commands`, `updater`, `index.mjs` (khởi động).
- Unit test hàm thuần: `expandSubnet`, `vendorFromMac`, mã hóa/giải mã BER của SNMP, chọn điểm ưu tiên trong vòng giám sát.
- Sửa nợ: lệnh `test-point` đưa `ipAddress` chưa kiểm tra vào `ping.exe` — validate IPv4.
- **Bắt buộc kiểm chứng exe thật**: `desktop/main.cjs` import `src/agent.mjs` (đổi entry thì sửa cả đây); `electron-builder.yml` copy `src` → `resources/agent/src` và package protocol → `resources/agent/node_modules`. Build exe ra scratchpad, chạy với backend tạm (mẫu: dùng `scripts/e2e/helpers.mjs`), xác nhận đăng ký + ping + cập nhật. Khi dừng tiến trình thử chỉ dừng cây tiến trình xuất phát từ thư mục thử — **người dùng đang chạy Agent thật cùng tên tiến trình `Agent HNTH`**.

### GĐ4 — Web: tầng API và realtime
- `core/api/`: một base URL dùng chung (hiện tính lặp 8 chỗ từ `VITE_HNTH_BACKEND_URL`/`VITE_HNTH_RELAY_URL`), client có kiểu (`hnthApi`, `agentsApi`, `authApi`); bỏ 7 chỗ `fetch` thô.
- Một service realtime duy nhất (SSE + polling dự phòng) ghi snapshot vào store; hiện `HnthPanel` giữ SSE, `App.tsx` và `HnthStatusMetrics` tự poll riêng.
- `core/events.ts`: event bus có kiểu cho lệnh điều khiển bản đồ; event chỉ để chia sẻ dữ liệu (`hnth:agent-status`, `hnth:continuous-monitoring`, `hnth:monitor-batch`) chuyển sang store.

### GĐ5 — Tách store thành slice (`core/store.ts`, 604 dòng, 113 trường)
- Slice: `map`, `layers`, `administrative`, `drawing`, `annotations`, `hnth`, `ui`.
- **Giữ nguyên** key localStorage `haiphong-map-display-preferences`, version 4 và 21 trường persist — `store.test.ts` khóa điều này. Đổi hình dạng thì tăng version + migrate, test với snapshot localStorage thật.

### GĐ7 — Tách các panel
- `HnthPanel.tsx` (1.094 dòng): `HnthAgentSelector`, `HnthPointConfigForm`, `HnthPointList`, `useHnthMonitoring`, `hnth-import-export` (đã có test CSV).
- `HnthStatusMetrics.tsx`: popup log ra component riêng.
- `App.tsx`: `SystemStatusBar`, `features/auth/` (modal đăng nhập/hồ sơ/đổi mật khẩu), `useOperationalLayerLoader`.
- `UserAdminPanel.tsx`: 25 dòng nhưng dòng dài tới 2.600 ký tự — viết lại cho đọc được; bỏ reset mật khẩu về chuỗi cứng.

### GĐ6 — Tách `MapCanvas.tsx` (2.909 dòng, 37 `useEffect`) — rủi ro cao nhất
- `MapCanvas` chỉ tạo bản đồ + context; hook `useBaseMap`, `useInitialViewport`, `useAdministrativeLayers`, `useOperationalLayers`, `useHnthLayer`, `useDrawTools`, `useAnnotations`, `usePresentationBridge`; card thông tin ra file riêng; hàm thuần vào `map/lib/` kèm test.
- Mỗi hook một commit, kèm danh sách thao tác kiểm tra bằng mắt cho người dùng (không test tự động được phần vẽ).

### GĐ8 — CSS theo tính năng
- `styles/global.css` (83 KB, 359 dòng) tách theo feature, giữ nguyên tên class.

## Quyết định còn chờ người dùng

1. Xóa hẳn `services/hnth-relay` (relay cũ, backend đã thay thế)?
2. Thay `xlsx@0.18.5` (có CVE) khi làm GĐ7?
3. Migration theo phiên bản cho `db.mjs` (hiện là một script idempotent) — chưa làm, cần chọn cách trước.

## Trạng thái môi trường máy dev (lúc bàn giao)

- Backend `pnpm --filter @haiphong-ops/hnth-backend dev` (8788, chế độ `--watch`, env dev) và frontend Vite (5173, `--host 0.0.0.0`) chạy trong hai tab Terminal của app Claude. **Backend tự nạp lại khi sửa file** — sửa backend là ảnh hưởng ngay phiên giám sát thật; chạy `pnpm smoke:backend` sau mỗi lần lưu.
- Postgres local 5432 (`hnth`/`hnth_local_password`), không có Docker Desktop chạy.
- Người dùng đang chạy Agent 0.2.x thật và một phiên Giám sát liên tục; e2e và các bài thử dùng schema/cổng riêng, không đụng dữ liệu thật.
- Agent build thử ở `outputs/hnth-agent-v0.2.x/` (bị git bỏ qua).
