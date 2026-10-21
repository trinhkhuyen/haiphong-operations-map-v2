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

Trong menu **Agents → sửa Agent → Cấu hình nâng cao → Phiên bản & cập nhật**, Admin chọn file `.exe` rồi bấm **Cập nhật**. Không cần nhập version: giao diện và backend đều tự đọc `ProductVersion` mà electron-builder ghi vào file. Popup cũng hiện kết quả của lần cập nhật gần nhất, kèm lý do nếu thất bại. Có thể cài bản mới hơn, cài lại đúng bản đang chạy, hoặc hạ cấp về bản cũ; với hai trường hợp sau giao diện chỉ hiện thông báo, không chặn. Hạ cấp xuống dưới 0.2.2 thì các lần cập nhật từ xa sau đó dùng updater cũ, dễ lỗi; hạ xuống 0.1.x thì không cập nhật từ xa được nữa.

1. Backend lưu file vào `agent-releases` (Docker: volume `agent_releases`), đọc version từ file và tính SHA-256.
2. Backend tạo lệnh `agent-update` gồm version, SHA-256 và **đường dẫn tương đối** `/api/agent-releases/<version>?agentId=…`. Agent ghép đường dẫn này với `backendUrl` của chính nó, nên máy ở LAN nào tải được backend thì tải được bản cập nhật.
3. Agent tải file, kiểm tra SHA-256, chép `apply-update.ps1` ra thư mục `updates\` cạnh config, khởi chạy script này ở chế độ ẩn rồi thoát.
4. Script chờ Agent thoát rồi đổi tên exe cũ thành `<exe>.previous`; bước đổi tên chỉ thành công khi launcher portable đã nhả file. Sau đó script ghi exe mới thành một file mới và khởi động lại Agent. Mọi thao tác file đều tự thử lại, vì Windows Defender thường khóa exe trong chốc lát để quét. Nếu lỗi, script khôi phục bản cũ và vẫn khởi động lại.
5. Agent mới đọc `update-result.json` và báo kết quả cho Backend; phiên bản mới hiện trong menu Agents sau khoảng 1 phút.

Lưu ý: updater nằm trong chính bản Agent đang chạy. Bản **0.1.x** hỏng hẳn ở bước này; bản **0.2.0–0.2.1** hay thất bại khi Defender quét file. Mỗi máy cần cài tay bản **0.2.2** trở lên một lần, sau đó mới cập nhật từ xa ổn định.
