# Roadmap và tasklist

Quy ước: `[x]` hoàn thành, `[~]` đang thực hiện, `[ ]` chưa thực hiện.

## M0 — Nền tảng và kiến trúc module

- [x] Chốt kiến trúc WebGIS module hóa.
- [x] Khởi tạo pnpm workspace và ứng dụng React/TypeScript/Vite.
- [x] Tách module `map`, `layers`, `zones`, `routing`, `monitoring`.
- [x] Thiết lập theme dashboard và layout responsive ban đầu.
- [ ] Thiết lập CI, lint và test convention.

## M1 — Vertical slice chạy được

- [x] Bản đồ MapLibre tập trung tại Hải Phòng.
- [x] Bản đồ nền OSM và điều khiển zoom/toàn màn hình.
- [x] Các lớp mẫu: camera, cơ quan nhà nước, bến xe, sông ngòi.
- [x] Bật/tắt lớp và thống kê số đối tượng.
- [x] Popup chi tiết đối tượng, clustering camera.
- [x] Vẽ polygon, rectangle, circle và chọn/sửa vùng bằng Terra Draw.
- [x] Panel định tuyến ở mức giao diện/prototype.
- [ ] Lưu vùng vẽ vào local store và danh sách vùng.
- [x] Kiểm thử giao diện, chuyển module, hiển thị lớp và trạng thái công cụ vẽ trên trình duyệt.
- [ ] Kiểm thử thao tác vẽ hoàn chỉnh và lưu vùng sau khi bổ sung zone store.

## M2 — API và PostGIS

- [ ] Tạo service API theo module, OpenAPI và health check.
- [ ] Docker Compose: PostgreSQL/PostGIS.
- [ ] Migration: layers, features, administrative boundaries, zones, cameras, events.
- [ ] Spatial indexes và repository/service layer.
- [ ] CRUD layer/feature/zone; phân trang và lọc theo viewport.
- [ ] Nhập GeoJSON/CSV/KML và kiểm tra dữ liệu.
- [ ] Hợp đồng type dùng chung giữa API và web.

## M3 — Địa giới và vùng giám sát

- [~] Đã tích hợp danh sách và GeoJSON 114 đơn vị từ Bản đồ số Hải Phòng; còn bước đóng gói dữ liệu offline và quy trình kiểm duyệt/phiên bản.
- [x] Tìm kiếm và chọn đồng thời nhiều xã/phường/đặc khu để tạo vùng.
- [x] Tìm kiếm địa điểm mẫu và chuyển nhanh sang vùng bán kính tại vị trí đó.
- [x] Buffer theo bán kính; nhập km, preset, thanh kéo, đường đo và nhãn trực tiếp trên bản đồ.
- [ ] Truy vấn đối tượng trong/ngoài nhiều vùng.
- [ ] Union/intersection/difference và thống kê.
- [ ] Phiên bản hóa ranh giới và ngày hiệu lực.

## M4 — Định tuyến

- [ ] Docker service OSRM và bộ dữ liệu đường Hải Phòng.
- [ ] Chọn điểm đầu/cuối/nhiều điểm dừng trên bản đồ.
- [ ] Hồ sơ ô tô/đi bộ/xe đạp; nghiên cứu profile xe máy.
- [ ] Chỉ dẫn, quãng đường, thời gian và kéo điểm tính lại.
- [ ] Đường đóng/vùng tránh và tuyến thay thế.

## M5 — Camera và realtime

- [ ] Camera registry, trạng thái, thông tin kết nối mã hóa.
- [ ] MediaMTX: RTSP sang WebRTC/HLS.
- [ ] Popup video và màn hình lưới nhiều camera.
- [ ] Health polling, online/offline và lịch sử trạng thái.
- [ ] SSE/WebSocket cho trạng thái và cảnh báo.
- [ ] PTZ/ONVIF và ghi hình là extension, không ghép cứng vào lõi.

## M6 — Vận hành và bảo mật

- [ ] Đăng nhập, RBAC theo đơn vị và phạm vi dữ liệu.
- [ ] Audit log và lịch sử thay đổi hình học.
- [ ] Backup/restore và chính sách lưu trữ.
- [ ] Kiểm thử tải, bảo mật và quan sát hệ thống.
- [ ] Cấu hình mạng nội bộ/offline và tile nền tự host.
- [ ] Tài liệu triển khai, vận hành và bàn giao.

## Nguyên tắc module hóa

- Module giao tiếp qua type/interface công khai, không import state nội bộ của nhau.
- Map chỉ chịu trách nhiệm hiển thị; nghiệp vụ nằm trong feature module.
- Nhà cung cấp tile, routing và video nằm sau adapter để có thể thay thế.
- Dữ liệu giả chỉ đi qua cùng interface với API thật.
- Mọi hình học lưu chuẩn GeoJSON/WGS84 ở biên hệ thống; PostGIS là nguồn dữ liệu chuẩn.
