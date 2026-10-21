# HNTH Source + Docker development bundle

Đây là bộ mã nguồn dùng để phát triển và chỉnh sửa bằng Codex/AI. PostgreSQL,
backend và frontend chạy trong Docker; mã nguồn được mount từ thư mục hiện tại
vào container nên sửa file trên Windows sẽ được Vite và Node watch cập nhật.

## Chạy lần đầu trên Windows

1. Cài Docker Desktop và bật WSL2/Windows containers theo yêu cầu của Docker.
2. Giải nén bộ ZIP vào một thư mục làm việc.
3. Mở PowerShell tại thư mục đó và chạy:

```powershell
Copy-Item .env.source.example .env.source
docker compose --env-file .env.source -f docker-compose.source.yml up -d --build
```

Mở frontend tại `http://localhost:5173`. Backend kiểm tra tại
`http://localhost:8788/health`.

## Chỉnh sửa bằng Codex

Mở chính thư mục đã giải nén trong Codex. Codex chỉnh trực tiếp các file trong
`apps`, `packages` và `services`. Frontend tự reload khi sửa code; backend dùng
Node watch. Nếu thay đổi `package.json`, `pnpm-lock.yaml` hoặc thêm dependency,
chạy lại:

```powershell
docker compose --env-file .env.source -f docker-compose.source.yml up -d --build
```

Xem log:

```powershell
docker compose --env-file .env.source -f docker-compose.source.yml logs -f frontend backend
```

Dừng hệ thống:

```powershell
docker compose --env-file .env.source -f docker-compose.source.yml down
```

Lệnh `down` không xóa dữ liệu PostgreSQL. Muốn xóa cả database phát triển mới
chạy thêm `docker compose ... down -v`.

## Agent Windows

Agent tray vẫn là file `HNTH-Agent-0.1.0-Windows-Tray.exe` trong bộ demo. Khi
chạy ở máy cơ quan, đặt file `config.json` cạnh file EXE, đổi `baseUrl` thành
địa chỉ máy chạy Docker, ví dụ `http://192.168.1.20:8788`, và dùng token trong
`.env.source`. `relayUrl` phải trỏ cùng backend (cổng `8788`); không dùng cổng
`8787` của relay cũ. Không cần copy `node_modules` của Agent.

Luôn truyền `--env-file .env.source` cho các lệnh Compose. Nếu bỏ tùy chọn này,
Compose sẽ dùng giá trị mặc định trong file YAML và có thể làm Agent/backend lệch
token hoặc tên agent.

Nếu muốn Codex sửa cả Agent, mã nguồn Agent nằm trong `services/hnth-agent`;
build EXE cần Node.js/pnpm trên máy build hoặc có thể bổ sung một service Docker
riêng sau khi thay đổi Agent.

## Dữ liệu demo

Nếu ZIP có kèm `hnth-demo-data.sql`, có thể nạp dữ liệu vào database source sau
khi container đã chạy:

```powershell
Get-Content .\hnth-demo-data.sql | docker compose --env-file .env.source -f docker-compose.source.yml exec -T postgres psql -U hnth -d hnth
```

Lệnh này dùng tài khoản mặc định trong `.env.source.example`; nếu đổi mật khẩu,
dùng đúng giá trị trong file `.env.source`.

