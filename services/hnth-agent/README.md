# HNTH Agent

Agent chạy trong mạng LAN, chủ động kết nối outbound tới relay hoặc Backend.

- Giữ `backendUrl` rỗng để chạy tương thích relay cũ.
- Đặt `backendUrl` thành `http://127.0.0.1:8788` để dùng Backend PostgreSQL mới. Agent sẽ tự đăng ký, lấy command và gửi telemetry bằng agent token.
- Không đặt JWT người dùng vào Agent; Agent chỉ dùng `token` riêng.

## Giám sát nâng cao

Agent hỗ trợ các nhóm cấu hình sau trong `config.json`:

- Ping ICMP nhiều lần cho mỗi điểm, lưu `latencyMs`, `packetLossPct` và `jitterMs`.
- Giới hạn scan bằng `scanConcurrency` và `scanDelayMs`; đặt `scanScheduleSeconds` lớn hơn 0 để tự lập lịch scan.
- SNMP v2c qua `snmpTargets`, gồm `host`, `port`, `community` và danh sách OID.
- Báo cáo `version` khi đăng ký/heartbeat. Lệnh `agent-update` chỉ nhận file `.exe`, giới hạn kích thước 250 MB, tải về và kiểm tra SHA-256 trước khi staged. Một tiến trình updater riêng sẽ chờ Agent thoát, sao lưu file cũ, thay thế file, tự khởi động lại Agent và gửi kết quả thành công/thất bại về Backend.

Ví dụ cấu hình đầy đủ nằm trong `config.example.json`. Không nên dùng community SNMP `public` trong mạng thật; hãy đặt community riêng và giới hạn quyền chỉ đọc.
## Bản Windows có icon system tray

Để chạy bản desktop trong môi trường phát triển:

```powershell
pnpm --filter @haiphong-ops/hnth-agent desktop
```

Để đóng gói thành file portable `.exe`:

```powershell
pnpm --filter @haiphong-ops/hnth-agent build:windows
```

File sẽ nằm trong `outputs/hnth-agent`. Khi chạy, Agent hoạt động nền và hiển thị biểu tượng HNTH ở system tray; nhấp phải biểu tượng để mở cấu hình hoặc thoát.

## Cập nhật từ giao diện Web

Trong menu **Agents → sửa Agent → Cấu hình nâng cao → Phiên bản & cập nhật**, Admin chọn version mới và file `.exe`, sau đó bấm **Phát hành & cập nhật Agent**. Backend lưu file trong `agent-releases`, tính SHA-256 và gửi command cho đúng Agent.

Nếu Agent chạy trên máy khác, URL tải update phải là địa chỉ mà máy đó truy cập được, không dùng `127.0.0.1`/`localhost`. Khi chạy frontend dev, đặt ví dụ:

```powershell
$env:VITE_AGENT_BACKEND_URL = "http://192.168.1.2:8788"
pnpm --filter @haiphong-ops/web dev --host 0.0.0.0
```
