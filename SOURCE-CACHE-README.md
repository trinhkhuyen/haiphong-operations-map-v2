# HNTH Source Docker bundle with image cache

Bộ này kèm `hnth-source-images.tar`, chứa image dev của HNTH cùng image nền
Node.js và PostgreSQL. Trên máy mới có thể nạp image trước khi chạy:

```powershell
docker load -i .\hnth-source-images.tar
Copy-Item .env.source.example .env.source
docker compose --env-file .env.source -f docker-compose.source.yml up -d
```

Nếu muốn Docker kiểm tra và cập nhật lại image từ source, dùng thêm `--build`.
Sau khi giải nén, mở thư mục này trong Codex để chỉnh sửa trực tiếp source.

Compose dùng tag cố định cho image backend/frontend nên cache đã load có thể
dùng lại trên máy mới. PostgreSQL dùng image `postgres:17-alpine`. Nếu source
đã được chỉnh sửa, chạy `up -d --build` một lần để build lại hai image ứng dụng.

