# HNTH live monitoring

Ba thành phần: **hnth-backend** (API + SSE, Postgres) ← **hnth-agent** (ping/scan trong LAN, chỉ kết nối đi ra) → **web** (bản đồ).

## Chạy backend local

Cần Postgres (mặc định `postgres://hnth:hnth_local_password@127.0.0.1:5432/hnth`, đổi bằng `DATABASE_URL`). Schema được tạo/nâng cấp tự động lúc khởi động (`src/migrations/`).

```powershell
pnpm --filter @haiphong-ops/hnth-backend dev
```

Backend lắng nghe cổng `8788`. Khi chưa đặt `HNTH_AGENT_TOKEN`/`JWT_SECRET`, chế độ dev dùng giá trị local trong `src/config.mjs` (production bắt buộc đặt).

## Chạy local agent

Tệp `hnth-agent/config.json` (không commit) chứa `backendUrl` (`http://127.0.0.1:8788`), `agentId` và `token`. Token phải khớp `HNTH_AGENT_TOKEN` của backend hoặc là token riêng của agent đó.

Danh sách subnet nhập ở ô **Subnet LAN** trong menu HNTH, phân tách bằng dấu phẩy (vd `192.168.1.0/24`).

```powershell
pnpm --filter @haiphong-ops/hnth-agent start
```

Agent chỉ tạo kết nối đi ra backend; không mở cổng inbound trong mạng HNTH.

## Chạy web local

```powershell
pnpm dev
```

Mở `http://127.0.0.1:5173`. Vite proxy `/api` sang backend `127.0.0.1:8788` (đổi bằng `VITE_PROXY_TARGET`).

Thứ tự chạy: **backend → agent → web**. Nếu backend không trả dữ liệu, frontend tự giữ dữ liệu demo.

## Frontend dùng backend ở domain khác

Mặc định frontend gọi same-origin `/api` (bắt buộc cho điện thoại trong LAN). Chỉ khi backend ở domain riêng mới build với:

```powershell
$env:VITE_HNTH_BACKEND_URL = "https://backend.example.vn"
pnpm --filter @haiphong-ops/web build
```
