# Blueprint ứng dụng WebGIS giám sát TP Hải Phòng

## 1. Định hướng sản phẩm

Đây là một ứng dụng WebGIS giám sát vận hành, không phải bản sao trình dựng video MapEffect. Trọng tâm là quản lý dữ liệu không gian, vùng giám sát, định tuyến, camera và cảnh báo trên bản đồ.

Mục tiêu MVP:

- Hiển thị bản đồ nền và nhiều lớp dữ liệu nghiệp vụ.
- Thêm, sửa, xóa, nhập và xuất đối tượng địa lý.
- Khoanh nhiều vùng theo địa giới, bán kính hoặc đa giác tự vẽ.
- Tìm đường giữa hai hay nhiều điểm.
- Gắn camera lên bản đồ, xem trạng thái và luồng trực tiếp nếu có.
- Chạy nội bộ, không có thanh toán.

## 2. Phạm vi chức năng

### 2.1 Bản đồ và lớp dữ liệu

- Bản đồ nền đường phố, vệ tinh hoặc nền nội bộ.
- Cây lớp dữ liệu: bật/tắt, đổi thứ tự, chỉnh độ trong suốt và ký hiệu.
- Các kiểu hình học:
  - Điểm: camera, bến xe, cơ quan nhà nước, trạm quan trắc.
  - Đường: sông/ngòi, tuyến giao thông, tuyến tuần tra.
  - Vùng: địa giới, vùng cấm, khu công nghiệp, vùng ngập.
- Lọc theo loại, trạng thái, đơn vị quản lý và phạm vi bản đồ.
- Gom cụm điểm khi thu nhỏ; nhãn và popup chi tiết khi phóng to.
- CRUD trực tiếp trên bản đồ.
- Nhập GeoJSON, CSV có tọa độ và KML; xuất GeoJSON/CSV.

### 2.2 Vùng giám sát

- Chọn địa giới hành chính từ dữ liệu đã nhập và được kiểm duyệt.
- Tạo vùng bán kính từ một tâm, nhập bán kính bằng mét/kilômét.
- Vẽ tự do polygon, rectangle và circle.
- Lưu đồng thời nhiều vùng; đặt tên, màu, loại và thời gian hiệu lực.
- Kiểm tra đối tượng nằm trong/ngoài vùng.
- Giai đoạn sau: hợp, giao, trừ vùng; cảnh báo vào/ra vùng; vùng theo thời gian.

### 2.3 Định tuyến

- Chọn điểm đầu, điểm cuối và nhiều điểm dừng trên bản đồ.
- Hồ sơ ô tô, xe máy (cần cấu hình riêng), đi bộ và xe đạp.
- Trả về hình tuyến, quãng đường, thời gian dự kiến và chỉ dẫn.
- Kéo điểm để tính lại tuyến.
- Giai đoạn sau: tránh vùng cấm, đóng đường, tối ưu thứ tự nhiều điểm.

### 2.4 Camera

- Camera là một lớp điểm có tọa độ, tên, đơn vị quản lý, trạng thái và URL luồng.
- Popup xem nhanh; màn hình lưới để xem nhiều camera.
- Gateway chuyển RTSP của camera sang WebRTC hoặc HLS cho trình duyệt.
- Kiểm tra online/offline và lưu lịch sử trạng thái.
- Tùy chọn giai đoạn sau: PTZ, ghi hình, ảnh chụp nhanh, cảnh báo AI và liên kết sự kiện với vùng.

### 2.5 Quản trị

- Người dùng, vai trò và phạm vi dữ liệu được phép xem/sửa.
- Nhật ký thao tác và lịch sử chỉnh sửa đối tượng.
- Phân quyền tối thiểu: quản trị, biên tập dữ liệu, trực vận hành, chỉ xem.

## 3. Kiến trúc đề xuất

```text
Trình duyệt
  React + TypeScript
  MapLibre GL JS + Terra Draw + Turf.js
        |
        +---- API nghiệp vụ (NestJS/Fastify)
        |       |
        |       +---- PostgreSQL + PostGIS
        |       +---- Redis (tùy chọn: cache/trạng thái realtime)
        |
        +---- Martin ---- PostGIS / PMTiles / MBTiles
        |
        +---- OSRM hoặc Valhalla (định tuyến nội bộ)
        |
        +---- MediaMTX (RTSP -> WebRTC/HLS)
```

### Frontend

- React, TypeScript, Vite.
- MapLibre GL JS để dựng bản đồ WebGL và các lớp vector/raster.
- Terra Draw cho point, line, polygon, rectangle, circle và chỉnh sửa hình học.
- Turf.js cho buffer, point-in-polygon, đo chiều dài/diện tích và phép toán vùng ở phía người dùng.
- Zustand cho trạng thái giao diện; TanStack Query cho dữ liệu máy chủ.

### Backend và dữ liệu

- NestJS chạy trên Fastify hoặc Fastify thuần cho API.
- PostgreSQL + PostGIS là nguồn dữ liệu chuẩn.
- Martin phát vector tile trực tiếp từ PostGIS khi dữ liệu lớn; dữ liệu nhỏ có thể trả GeoJSON.
- WebSocket/SSE để đẩy trạng thái camera và cảnh báo.
- Lưu tệp nhập/xuất, ảnh camera và bản ghi ở object storage nội bộ nếu cần.

### Dịch vụ bản đồ

- MVP có thể dùng bản đồ nền bên ngoài nếu chính sách mạng cho phép.
- Bản triển khai kín/offline cần tự host tile nền bằng PMTiles/MBTiles hoặc pipeline OpenMapTiles.
- Dữ liệu địa giới phải nhập từ nguồn chính thức, có trường phiên bản và ngày hiệu lực; không dùng kết quả geocoding làm nguồn chuẩn duy nhất.

## 4. Mô hình dữ liệu tối thiểu

### `layers`

- `id`, `name`, `code`, `geometry_type`, `style_json`, `visible_default`, `min_zoom`, `max_zoom`, `created_at`.

### `features`

- `id`, `layer_id`, `name`, `properties jsonb`, `geometry geometry(Geometry, 4326)`, `status`, `valid_from`, `valid_to`, `created_by`, `updated_at`.
- Spatial index GiST trên `geometry`.

### `administrative_boundaries`

- `id`, `code`, `name`, `level`, `parent_code`, `version`, `effective_from`, `effective_to`, `source`, `geometry geometry(MultiPolygon, 4326)`.

### `monitoring_zones`

- `id`, `name`, `zone_type`, `rule_json`, `geometry geometry(MultiPolygon, 4326)`, `style_json`, `active_from`, `active_to`, `owner_unit`.

### `cameras`

- `id`, `feature_id`, `stream_source`, `playback_url`, `protocol`, `online_status`, `last_seen_at`, `capabilities jsonb`.

Không trả trực tiếp tài khoản/mật khẩu RTSP cho trình duyệt; gateway giữ bí mật kết nối.

### `routes` và `events`

- Route lưu waypoints, profile, geometry, distance và duration.
- Event lưu loại cảnh báo, vị trí, vùng liên quan, camera liên quan, thời gian và trạng thái xử lý.

## 5. Luồng giao diện chính

- Thanh trên: tìm kiếm, chọn nền bản đồ, công cụ đo/vẽ, định tuyến, toàn màn hình.
- Panel trái: cây lớp, bộ lọc và danh sách đối tượng.
- Bản đồ trung tâm: lớp dữ liệu, vùng, tuyến và cụm camera.
- Panel phải: thuộc tính đối tượng, video camera, lịch sử/cảnh báo.
- Thanh trạng thái dưới: tọa độ, tỷ lệ, số đối tượng đang hiển thị và tình trạng kết nối.

## 6. Roadmap thực hiện

### Giai đoạn 0 — Chốt dữ liệu và yêu cầu (3-5 ngày)

- Chốt Hải Phòng theo địa giới hiện hành và bộ dữ liệu ranh giới được phép dùng.
- Kiểm kê nguồn camera: số lượng, RTSP/ONVIF/HLS, quyền truy cập và băng thông.
- Chốt môi trường online, mạng nội bộ có Internet, hay hoàn toàn offline.
- Chốt định tuyến chỉ cho ô tô hay có xe máy/đi bộ.

### Giai đoạn 1 — Nền WebGIS (2-3 tuần)

- Khung ứng dụng, đăng nhập và phân quyền cơ bản.
- MapLibre, bản đồ nền, cây lớp, popup, tìm kiếm.
- PostGIS, API layer/feature, CRUD và nhập GeoJSON/CSV/KML.
- Styling điểm/đường/vùng và clustering.

### Giai đoạn 2 — Vùng giám sát (1-2 tuần)

- Vẽ/chỉnh sửa nhiều vùng.
- Chọn theo địa giới và tạo buffer bán kính.
- Lưu vùng, truy vấn đối tượng trong vùng, thống kê cơ bản.

### Giai đoạn 3 — Định tuyến (1-2 tuần)

- Dựng OSRM và dữ liệu đường khu vực Hải Phòng.
- A-B, nhiều điểm dừng, hiển thị quãng đường/thời gian.
- Chuẩn bị mô hình tránh vùng cấm/đường đóng.

### Giai đoạn 4 — Camera và giám sát (2-3 tuần)

- Quản lý camera, trạng thái online/offline.
- Media gateway và xem WebRTC/HLS trong popup/lưới.
- WebSocket/SSE và nhật ký sự kiện.

### Giai đoạn 5 — Cứng hóa triển khai (1-2 tuần)

- Audit log, backup/restore, kiểm thử tải và bảo mật.
- Đóng gói Docker Compose; tài liệu vận hành.
- Nếu cần offline: tile nền, geocoder và routing đều self-host.

Ước lượng ban đầu: đội 2-3 người làm MVP khoảng 7-10 tuần; một người thường cần 10-14 tuần. Ước lượng sẽ thay đổi mạnh theo số camera, yêu cầu offline và chất lượng dữ liệu đầu vào.

## 7. Nên tái sử dụng hay tự xây

Không nên clone MapEffect cho bài toán này. Nên tự xây lớp nghiệp vụ và giao diện giám sát, đồng thời ghép các thành phần mã nguồn mở chuyên dụng:

- MapLibre GL JS: trình dựng bản đồ.
- Terra Draw: vẽ và sửa hình học.
- PostGIS: lưu trữ/truy vấn không gian.
- Martin: phát vector tiles.
- OSRM: routing nhanh; chuyển sang Valhalla nếu cần multimodal/phức tạp hơn.
- MediaMTX: gateway luồng camera.

Phương án này ít mã phải tự viết hơn, dễ kiểm soát dữ liệu nội bộ và phù hợp vận hành lâu dài hơn việc fork một ứng dụng GIS tổng quát rồi tháo bỏ các phần không cần thiết.

## 8. Công cụ phát triển cần bổ sung

- Docker Desktop hoặc Docker Engine + Compose.
- Node.js LTS và pnpm.
- PostgreSQL/PostGIS; QGIS để kiểm tra/chuyển đổi dữ liệu.
- GDAL/ogr2ogr để nhập Shapefile, GeoPackage, KML và đổi hệ tọa độ.
- FFmpeg để kiểm thử/chuyển mã luồng camera.
- Bruno/Postman cho API; Playwright cho kiểm thử end-to-end.
- Git và CI nội bộ.

Không cần bổ sung một “skill clone website” riêng. Công việc tiếp theo cần bộ dữ liệu mẫu, thông tin hạ tầng camera và quyết định online/offline hơn là thêm công cụ tự động hóa trình duyệt.

## 9. Tiêu chí nghiệm thu MVP

- Tải được bản đồ Hải Phòng và bật/tắt ít nhất 5 lớp dữ liệu.
- Nhập dữ liệu điểm/đường/vùng và sửa trực tiếp trên bản đồ.
- Tạo, lưu và hiển thị đồng thời nhiều vùng bằng cả ba cách: địa giới, bán kính, tự vẽ.
- Truy vấn và đếm đúng đối tượng nằm trong từng vùng.
- Tính tuyến A-B và nhiều điểm dừng; hiển thị khoảng cách/thời gian.
- Hiển thị camera theo cụm, trạng thái và xem được luồng mẫu trong trình duyệt.
- Phân quyền, audit log và chạy được bằng Docker Compose trong mạng nội bộ.

