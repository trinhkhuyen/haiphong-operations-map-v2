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

## Config và định danh mỗi bản cài

- Bản `.exe` portable đọc `config.json` **cạnh file .exe**. Nếu chưa có, lần chạy đầu tiên Agent tạo file này từ bản mẫu đóng gói sẵn. Nếu thư mục đó không ghi được, Agent dùng `%APPDATA%\HNTH Agent\config.json`.
- Mỗi bản cài có `installationId` = băm của MachineGuid của máy + đường dẫn thư mục chứa config, được lưu vào config sau lần đăng ký đầu tiên.
- Khi **copy** Agent (cả thư mục, kể cả `config.json`) sang máy khác hoặc sang thư mục khác, `installationId` không khớp nên Agent tự gọi `/api/agents/clone` để nhận `agentId` và token **riêng**, rồi ghi đè vào config của bản copy. Bản gốc giữ nguyên id.
- Nhiều máy dùng chung một file mẫu có cùng `agentId`: máy đăng ký trước giữ id đó; các máy sau nhận HTTP 409 và tự xin id mới. Không cần sửa tay `agentId` cho từng máy.
- Token dùng chung (`HNTH_AGENT_TOKEN`) chỉ cần cho lần enroll đầu tiên; sau đó mỗi Agent dùng token riêng.

## Cập nhật từ giao diện Web

Trong menu **Agents → sửa Agent → Cấu hình nâng cao → Phiên bản & cập nhật**, Admin nhập version mới, chọn file `.exe` rồi bấm **Cập nhật**:

1. Backend lưu file vào `agent-releases` (Docker: volume `agent_releases`) và tính SHA-256.
2. Backend tạo lệnh `agent-update` gồm version, SHA-256 và **đường dẫn tương đối** `/api/agent-releases/<version>?agentId=…`. Agent ghép đường dẫn này với `backendUrl` của chính nó, nên máy ở LAN nào tải được backend thì tải được bản cập nhật.
3. Agent tải file, kiểm tra SHA-256, chép `apply-update.ps1` ra thư mục `updates\` cạnh config, khởi chạy script này ở chế độ ẩn rồi thoát.
4. Script chờ Agent và launcher portable nhả file, sao lưu `<exe>.previous`, thay file, rồi khởi động lại Agent. Nếu lỗi, script khôi phục bản cũ và vẫn khởi động lại.
5. Agent mới đọc `update-result.json` và báo kết quả cho Backend; phiên bản mới hiện trong menu Agents sau khoảng 1 phút.

Lưu ý: các bản **0.1.x** có lỗi ở bước updater (Agent thoát nhưng không bao giờ được thay file và khởi động lại), nên chỉ cập nhật từ xa được sau khi mỗi máy đã được cài tay bản **0.2.0** trở lên một lần.
