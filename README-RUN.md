# HNTH Source Docker Full

## Chạy trên Windows

1. Cài Docker Desktop và bật WSL2.
2. Mở PowerShell tại thư mục này.
3. Tạo file cấu hình:

```powershell
Copy-Item .env.source.example .env.source
```

4. Nếu có file cache, nạp image:

```powershell
docker load -i .\hnth-source-images.tar
```

5. Khởi động:

```powershell
docker compose --env-file .env.source -f docker-compose.source.yml up -d
```

Nếu source đã sửa hoặc chưa nạp cache, thêm `--build` vào lệnh trên.

Frontend: `http://127.0.0.1:5173`  
Backend health: `http://127.0.0.1:8788/health`

## Agent Windows

Chạy `agent\HNTH-Agent-0.1.0-Windows-Tray.exe`. File `agent\config.json` mặc
định dùng `agent-demo`, tên hiển thị `agent-HNTH`, backend `127.0.0.1:8788` và
token phải khớp `HNTH_AGENT_TOKEN` trong `.env.source`.

Khi chạy Agent trên máy khác trong LAN, đổi `backendUrl` thành địa chỉ LAN của
máy Docker, ví dụ `http://192.168.1.20:8788`, và mở TCP 8788 trên firewall.

## Chẩn đoán

```powershell
docker compose --env-file .env.source -f docker-compose.source.yml ps
docker compose --env-file .env.source -f docker-compose.source.yml logs -f backend frontend
Invoke-RestMethod http://127.0.0.1:8788/health
Invoke-RestMethod http://127.0.0.1:8788/api/agent-status
```

Luôn dùng `--env-file .env.source`; nếu bỏ qua, Compose có thể dùng token mặc
định khác với Agent. `docker compose ... down` giữ lại dữ liệu PostgreSQL.
