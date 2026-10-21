# Bộ demo HNTH chạy bằng Docker

Máy mới chỉ cần cài Docker Desktop for Windows; không cần cài Python hoặc Node.js.

## Khởi động

Copy `.env.demo.example` thành `.env.demo`, sửa `WEB_ORIGIN` thành IP LAN của máy chạy Docker và đổi các mật khẩu/token. Sau đó chạy:

```powershell
docker load -i hnth-demo-images.tar
docker compose --env-file .env.demo -f docker-compose.demo.yml up -d
```

Nếu muốn dùng dữ liệu/tài khoản hiện tại, chờ PostgreSQL healthy rồi nạp backup:

```powershell
Get-Content .\hnth-demo-data.sql | docker compose --env-file .env.demo -f docker-compose.demo.yml exec -T postgres psql -U hnth -d hnth
docker compose --env-file .env.demo -f docker-compose.demo.yml restart backend
```

Mở `http://localhost` trên máy chủ hoặc `http://IP-MAY-CHAY-DOCKER` từ máy khác.

## Agent Windows

Copy cả `HNTH-Agent-0.1.0-Windows-Tray.exe` và `agent-config.json` sang máy Agent, đặt cùng thư mục. Sửa `backendUrl`, `token` và `scanSubnets` trong `agent-config.json`, rồi chạy `.exe`. Không cần cài Node.js.

## Kiểm tra / dừng

```powershell
docker compose --env-file .env.demo -f docker-compose.demo.yml ps
docker compose --env-file .env.demo -f docker-compose.demo.yml logs -f backend
docker compose --env-file .env.demo -f docker-compose.demo.yml down
```

Không dùng `down -v` vì sẽ xóa database demo.
