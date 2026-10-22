# Hải Phòng Operations Map

> **Cài đặt trên máy mới / chạy backend + frontend:** xem [docs/HUONG-DAN-TRIEN-KHAI.md](docs/HUONG-DAN-TRIEN-KHAI.md). Một số mục bên dưới (`packages/contracts`, `services/api`, `infra`) là kế hoạch cũ, chưa tồn tại.

Nền tảng WebGIS giám sát vận hành được tổ chức theo module để có thể mở rộng độc lập.

## Chạy local

```bash
pnpm install
pnpm dev
```

Ứng dụng web mặc định chạy tại `http://localhost:5173`.

Trong giai đoạn prototype, module địa giới đọc danh sách và ranh giới 114 xã/phường/đặc khu từ nguồn Bản đồ số Hải Phòng qua proxy phát triển. Khi triển khai nội bộ, thay adapter này bằng bản dữ liệu được kiểm duyệt và lưu trong mạng LAN; phần giao diện và nghiệp vụ không cần thay đổi.

## Dữ liệu thủy hệ và cơ quan

- Sông, suối, ao/hồ được lấy từ OpenStreetMap, lọc giao cắt với 114 địa giới Hải Phòng và đóng gói thành snapshot nội bộ tại `apps/web/public/data/osm-operational-layers.json`.
- 114 điểm UBND dùng tọa độ trung tâm hành chính từ bộ dữ liệu địa giới chính thức Hải Phòng.
- Chạy `pnpm --filter @haiphong-ops/web data:osm` để tạo lại snapshot. Có thể đặt biến `OSM_FETCH_FACILITIES=1` khi muốn nhập thêm các cơ quan đã được gắn thẻ trên OSM; dữ liệu nội bộ được kiểm duyệt có thể ghép vào các lớp độc lập mà không đổi phần bản đồ.

## Cấu trúc

- `apps/web`: giao diện WebGIS React + MapLibre.
- `packages/contracts`: hợp đồng dữ liệu dùng chung (mốc tiếp theo).
- `services/api`: API nghiệp vụ và PostGIS (mốc tiếp theo).
- `infra`: Docker Compose cho PostGIS, routing, tile và camera gateway (mốc tiếp theo).

Chi tiết kế hoạch: [TASKLIST.md](./TASKLIST.md) và [WEBGIS_HAIPHONG_PLAN.md](./WEBGIS_HAIPHONG_PLAN.md).

## Triển khai production bằng Docker

Bộ triển khai gồm frontend Caddy, backend Node.js và PostgreSQL. Hướng dẫn chạy local, đưa lên VPS, cấu hình Agent và sao lưu database nằm tại [DEPLOY-VPS.md](./DEPLOY-VPS.md).
