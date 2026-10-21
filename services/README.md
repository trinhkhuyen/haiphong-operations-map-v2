# HNTH live monitoring

## Chạy relay server local

```powershell
$env:HNTH_AGENT_TOKEN = "local-hnth-test-7f3c9a2e5d1b"
$env:HNTH_DEFAULT_AGENT_ID = "agent-demo"
pnpm --filter @haiphong-ops/hnth-relay start
```

Relay cung cấp `GET /api/hnth/status`, `GET /api/hnth/stream` và nhận dữ liệu tại `POST /api/telemetry/ping-results`.

## Chạy local agent

Tệp `hnth-agent/config.json` đã được tạo sẵn cho local với token thử nghiệm. Khi đổi token, phải đổi đồng thời biến `HNTH_AGENT_TOKEN` của relay và trường `token` trong tệp này.

Danh sách subnet có thể nhập trực tiếp tại ô **Subnet LAN** phía dưới khung **Cấu hình điểm**, phân tách bằng dấu phẩy. Với mạng hiện tại, nhập `192.168.1.0/24`. Agent quét theo lô 32 địa chỉ để hoàn tất nhanh hơn.

Chạy agent:

```powershell
pnpm --filter @haiphong-ops/hnth-agent start
```

Agent chỉ tạo kết nối đi ra relay; không mở cổng inbound trong mạng HNTH.

## Chạy web local

Mở terminal thứ ba:

```powershell
pnpm dev
```

Mở `http://127.0.0.1:5173`. Vite đã cấu hình proxy `/api` sang relay local ở cổng `8787`.

Thứ tự chạy đầy đủ là: **relay → agent → web**. Sau đó vào Menu HNTH, nhập subnet LAN và bấm **Scan mạng LAN**.

## Kết nối frontend public sau này

Khi relay dùng domain riêng, build frontend với:

```powershell
$env:VITE_HNTH_RELAY_URL = "https://relay.example.vn"
pnpm --filter @haiphong-ops/web build
```

Nếu chưa có relay hoặc relay không trả dữ liệu, frontend tự giữ dữ liệu demo.
