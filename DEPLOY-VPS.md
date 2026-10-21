# Triển khai Map HNTH bằng Docker

## Kiến trúc

`frontend` là image Caddy phục vụ bản build Vite và chuyển tiếp `/api/*` tới `backend`. `backend` là Node.js API/realtime server. `postgres` lưu user, agent, endpoint, trạng thái giám sát và log. Agent HNTH vẫn chạy trong mạng LAN và chủ động kết nối outbound tới backend bằng `agentId` + token.

## Chạy local bằng Docker

Từ thư mục repo:

```powershell
Copy-Item .env.production.example .env.production
# sửa mật khẩu/token trong .env.production; giữ DOMAIN=:80 để chạy http://localhost
docker compose --env-file .env.production -f docker-compose.production.yml up -d --build
docker compose --env-file .env.production -f docker-compose.production.yml ps
```

Mở `http://localhost`. Xem log:

```powershell
docker compose --env-file .env.production -f docker-compose.production.yml logs -f backend
docker compose --env-file .env.production -f docker-compose.production.yml logs -f frontend
```

Dừng hệ thống nhưng giữ database:

```powershell
docker compose --env-file .env.production -f docker-compose.production.yml down
```

Không dùng `down -v` trừ khi muốn xóa vĩnh viễn volume PostgreSQL.

## Đưa lên VPS

1. Cài Docker Engine và Docker Compose plugin trên VPS.
2. Trỏ DNS `A` của tên miền vào IP VPS.
3. Clone repo, tạo `.env.production` từ mẫu.
4. Đổi `DOMAIN` thành tên miền thật và `WEB_ORIGIN` thành `https://<tên-miền>`.
5. Đổi toàn bộ `POSTGRES_PASSWORD`, `JWT_SECRET`, `ADMIN_PASSWORD`, `HNTH_AGENT_TOKEN`.
6. Mở TCP 80/443 trên firewall VPS rồi chạy:

```bash
docker compose --env-file .env.production -f docker-compose.production.yml up -d --build
```

Caddy tự xin và gia hạn chứng chỉ HTTPS. Không expose PostgreSQL ra Internet; database chỉ nằm trong Docker network.

## Chạy Agent trong mạng HNTH

Tạo `services/hnth-agent/config.json` từ `config.production.example.json`, thay `backendUrl` bằng URL HTTPS thật và token phải trùng `HNTH_AGENT_TOKEN` của backend:

```powershell
pnpm install
pnpm --filter @haiphong-ops/hnth-agent start
```

Agent cần máy LAN truy cập được HTTPS tới VPS. Nếu firewall chặn outbound, cho phép TCP 443. Agent không cần mở port inbound.

## Kiểm tra vận hành

```bash
curl https://<tên-miền>/health
docker compose --env-file .env.production -f docker-compose.production.yml ps
docker compose --env-file .env.production -f docker-compose.production.yml logs --tail=100 backend
```

Đăng nhập tài khoản admin được seed lần đầu từ `ADMIN_USERNAME`/`ADMIN_PASSWORD`. Sau khi đăng nhập, đổi mật khẩu trong giao diện và tạo tài khoản Guest/Operator tại phần quản trị user.

## Sao lưu PostgreSQL

```bash
docker compose --env-file .env.production -f docker-compose.production.yml exec -T postgres \
  pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" > hnth-$(date +%F).sql
```

Lưu file dump ngoài VPS hoặc trong kho sao lưu riêng. Khi khôi phục, dừng backend trước và dùng `psql` nạp lại vào database.

