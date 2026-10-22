# Hướng dẫn triển khai trên máy mới (Windows)

Mục tiêu: clone repo về một máy Windows khác (ví dụ máy ở cơ quan), chạy được backend +
frontend giống máy phát triển hiện tại, có sẵn dữ liệu điểm cầu, và tiếp tục sửa code.

Môi trường máy gốc (đã kiểm chứng): Windows 11, Node.js 25, pnpm 11.25.0, PostgreSQL 18.6
(cài bằng bộ cài Windows, chạy như dịch vụ `postgresql-x64-18`), backend chạy bằng Node trực
tiếp (không cần Docker).

```
Agent HNTH (.exe, khay hệ thống) --HTTP--> Backend :8788 (Node) --> PostgreSQL :5432
                                              ^
Trình duyệt --> Frontend Vite :5173 --/api (proxy)--+
```

---

## 1. Phần mềm cần cài

| Phần mềm | Phiên bản | Tải ở đâu | Ghi chú |
|---|---|---|---|
| Git | mới nhất | https://git-scm.com/download/win | Cài kèm Git Bash |
| Node.js | 25.x (tối thiểu 22) | https://nodejs.org | Chọn bản "Current" |
| pnpm | 11.25.0 | qua corepack (bên dưới) | Trùng `packageManager` trong `package.json` |
| PostgreSQL | **18.x** | https://www.postgresql.org/download/windows/ | Bộ cài EDB; nhớ mật khẩu user `postgres` đặt lúc cài. Bản 18 cần cho file sao lưu `data/db/hnth-full.sql` |
| GitHub CLI | mới nhất | https://cli.github.com | Để đăng nhập repo private và tải bản Agent |
| VS Code | tùy chọn | https://code.visualstudio.com | Sửa code |
| Docker Desktop | tùy chọn | https://www.docker.com/products/docker-desktop | Chỉ khi muốn chạy cả stack bằng Docker (mục 9) |

Sau khi cài Node.js, mở **PowerShell** và bật pnpm đúng phiên bản:

```bash
corepack enable
corepack prepare pnpm@11.25.0 --activate
pnpm -v
```

Thêm thư mục công cụ PostgreSQL vào PATH để gõ được `psql` (đổi `18` nếu cài bản khác):

```bash
[Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path", "User") + ";C:\Program Files\PostgreSQL\18\bin", "User")
```

Mở lại PowerShell rồi kiểm tra `psql --version`.

## 2. Lấy code về

Repo là **private**: đăng nhập GitHub trước.

```bash
gh auth login
```

```bash
git clone https://github.com/trinhkhuyen/haiphong-operations-map-v2.git
```

```bash
cd haiphong-operations-map-v2
```

```bash
pnpm install
```

Nếu `pnpm install` báo `ERR_PNPM_ABORTED_REMOVE_MODULES_DIR_NO_TTY`, chạy:

```bash
$env:CI="true"; pnpm install --frozen-lockfile
```

## 3. Tạo database

Mở PowerShell, đăng nhập bằng user quản trị `postgres` (mật khẩu đặt lúc cài PostgreSQL):

```bash
psql -U postgres -h 127.0.0.1 -c "CREATE ROLE hnth LOGIN PASSWORD 'hnth_local_password';"
```

```bash
psql -U postgres -h 127.0.0.1 -c "CREATE DATABASE hnth OWNER hnth;"
```

`hnth` / `hnth_local_password` / database `hnth` là giá trị mặc định khi chạy dev (xem mục 6).
Muốn dùng mật khẩu khác thì đổi ở đây và đặt `DATABASE_URL` tương ứng.

## 4. Nạp dữ liệu — chọn MỘT trong hai cách

### Cách A — Toàn bộ database giống máy gốc (khuyến nghị)

File `data/db/hnth-full.sql` là bản sao lưu đầy đủ (tài khoản, Agent, endpoint, dữ liệu chủ
điểm cầu, danh sách phiên họp, lịch sử log giám sát). Không gồm phiên đăng nhập
(`refresh_tokens`) và hàng đợi lệnh Agent (`commands`).

```bash
psql -U hnth -h 127.0.0.1 -d hnth -v ON_ERROR_STOP=1 -f data/db/hnth-full.sql
```

Nhập mật khẩu `hnth_local_password`. Đăng nhập web bằng **đúng tài khoản/mật khẩu như máy gốc**.

### Cách B — Database mới + dữ liệu điểm cầu

File `data/hnth/hnth-points.json` chỉ gồm dữ liệu chủ điểm cầu (126 điểm: Trung tâm, xã/phường,
Sở/Ban/Ngành, kèm IP/Gateway/Model) và các danh sách phiên họp.

1. Chạy backend một lần (mục 5) để tự tạo bảng (migration) và tài khoản `admin`.
2. Dừng backend (Ctrl+C) hoặc để nguyên, rồi chạy:

```bash
pnpm --filter @haiphong-ops/hnth-backend data:import
```

Đăng nhập lần đầu: `admin` / `admin123!` (đổi ngay trong menu tài khoản).

## 5. Chạy hệ thống

Mở **hai** cửa sổ PowerShell trong thư mục repo.

Cửa sổ 1 — Backend (cổng 8788, tự chạy lại khi sửa code):

```bash
pnpm --filter @haiphong-ops/hnth-backend dev
```

Thấy `HNTH Backend listening on :8788` là xong. Kiểm tra: mở http://127.0.0.1:8788/health.

Cửa sổ 2 — Frontend (cổng 5173):

```bash
pnpm dev
```

Mở http://127.0.0.1:5173 . Frontend gọi backend qua `/api` (Vite tự chuyển tiếp sang 8788).

Cho máy khác trong LAN (điện thoại, máy trình chiếu) mở được giao diện:

```bash
pnpm --filter @haiphong-ops/web exec vite --host 0.0.0.0
```

Rồi mở `http://<IP-máy-này>:5173`. Có thể phải cho phép cổng 5173 và 8788 trong Windows Firewall.

## 6. Khóa, token, mật khẩu — giá trị mặc định và chỗ đổi

Khi chạy dev **không cần file `.env`**: backend dùng giá trị mặc định dưới đây (đúng như máy gốc).
Muốn đổi thì đặt biến môi trường **trước khi** chạy backend trong cùng cửa sổ PowerShell, ví dụ
`$env:JWT_SECRET="chuoi-bi-mat-moi"`.

| Biến môi trường | Mặc định khi chạy dev | Khai báo ở | Ý nghĩa |
|---|---|---|---|
| `DATABASE_URL` | `postgres://hnth:hnth_local_password@127.0.0.1:5432/hnth` | `services/hnth-backend/src/db.mjs` | Kết nối PostgreSQL |
| `JWT_SECRET` | `local-only-change-this-jwt-secret` | `services/hnth-backend/src/config.mjs` | Ký phiên đăng nhập. Đổi thì mọi người phải đăng nhập lại |
| `HNTH_AGENT_TOKEN` | `local-hnth-test-7f3c9a2e5d1b` | `services/hnth-backend/src/config.mjs` | Token chung cho Agent (mở khóa mọi agentId) |
| `ADMIN_USERNAME` / `ADMIN_PASSWORD` | `admin` / `admin123!` | `services/hnth-backend/src/config.mjs` | Chỉ dùng để tạo admin khi DB chưa có user nào |
| `PORT` | `8788` | `config.mjs` | Cổng backend |
| `WEB_ORIGIN` | `http://127.0.0.1:5173` | `config.mjs` | CORS khi web gọi backend khác origin |
| `HNTH_DEFAULT_AGENT_ID` | `agent-demo` | `config.mjs` | Agent mặc định khi chưa chọn |
| `VITE_PROXY_TARGET` | `http://127.0.0.1:8788` | `apps/web/vite.config.ts` | Frontend dev chuyển tiếp `/api` tới đâu |
| `E2E_DATABASE_URL` | như `DATABASE_URL` | `scripts/e2e/helpers.mjs` | DB cho `pnpm test:e2e` (tạo schema riêng, không đụng dữ liệu) |

Chạy production (`NODE_ENV=production`) thì **bắt buộc** đặt `JWT_SECRET` và `HNTH_AGENT_TOKEN`
riêng (backend dừng nếu thiếu). Không ghi giá trị thật vào code hay file `*.example`.

### Token của Agent

Agent đọc `config.json` đặt **cạnh file .exe** (hoặc `%APPDATA%\HNTH Agent\config.json`):

```json
{
  "agentId": "agent-demo",
  "agentName": "Agent HNTH",
  "backendUrl": "http://<IP-máy-chạy-backend>:8788",
  "token": "local-hnth-test-7f3c9a2e5d1b"
}
```

- `backendUrl`: địa chỉ máy chạy backend (dùng IP LAN, không dùng 127.0.0.1 nếu Agent ở máy khác).
- `token`: dùng token chung `HNTH_AGENT_TOKEN` ở trên. Sau lần kết nối đầu Agent có thể được cấp
  token riêng (lưu dạng băm trong bảng `agents`); đổi token riêng trong web: **Agents → ✎ →
  Cấu hình nâng cao → Token Agent**.
- Agent ghi lại `config.json` khi nhận cấu hình từ backend; mẫu đầy đủ ở
  `services/hnth-agent/config.example.json`. Không commit `config.json` thật.

## 7. Agent HNTH (.exe)

Bản dựng sẵn mới nhất nằm ở **GitHub Releases** của repo (tag `agent-v0.2.6`, gồm 0.2.5 và 0.2.6):

```bash
gh release download agent-v0.2.6 --repo trinhkhuyen/haiphong-operations-map-v2 --dir agent-exe
```

Chạy file `Agent-HNTH-v0.2.6-Windows-Tray.exe`, sửa `config.json` cạnh exe như mục 6. Icon khay:
xanh = bình thường, đỏ = đang giám sát/quét, vàng = mất kết nối backend.

Tự dựng exe từ code (cần quyền ghi `outputs/`):

```bash
pnpm --filter @haiphong-ops/hnth-agent build:windows
```

Tăng `version` trong `services/hnth-agent/package.json` trước khi dựng bản mới để cập nhật từ xa
(web: **Agents → ✎ → Cấu hình nâng cao → Phiên bản & cập nhật**).

## 8. Kiểm tra sau khi sửa code

```bash
pnpm check
```

```bash
pnpm test
```

```bash
pnpm test:e2e
```

`pnpm check` = eslint + typecheck + cú pháp; `pnpm test:e2e` cần PostgreSQL đang chạy.
Quy ước làm việc chi tiết: `CLAUDE.md`, lịch sử refactor: `docs/REFACTOR-HANDOFF.md`.

## 9. (Tùy chọn) Chạy cả stack bằng Docker

```bash
copy .env.source.example .env.source
```

Sửa mật khẩu/khóa trong `.env.source`, rồi:

```bash
docker compose --env-file .env.source -f docker-compose.source.yml up -d --build
```

Luôn truyền `--env-file`; **không bao giờ** chạy `down -v` (xóa volume database).

## 10. Mang dữ liệu mới lên GitHub (từ máy đang dùng)

Xuất dữ liệu điểm cầu ra `data/hnth/hnth-points.json`:

```bash
pnpm --filter @haiphong-ops/hnth-backend data:export
```

Sao lưu toàn bộ database ra `data/db/hnth-full.sql`:

```bash
pg_dump -h 127.0.0.1 -U hnth -d hnth --no-owner --no-privileges --clean --if-exists --exclude-table-data=refresh_tokens --exclude-table-data=commands -f data/db/hnth-full.sql
```

Rồi commit và push hai file trên.

## Lưu ý bảo mật

- Repo đang để **private**. `data/db/hnth-full.sql` có mã băm mật khẩu tài khoản và mã băm token
  Agent; `data/hnth/hnth-points.json` có IP nội bộ các điểm cầu. **Không** chuyển repo sang public.
- Các giá trị mặc định ở mục 6 chỉ dành cho máy dev trong LAN. Triển khai thật cần đặt khóa riêng.
