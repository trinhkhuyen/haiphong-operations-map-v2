// Yêu cầu MapCanvas đưa camera về khung tổng quan toàn Thành phố Hải Phòng.
// Dùng sự kiện riêng để thao tác này không bị lẫn với nút Home (có thể đi tới
// khung địa giới mặc định mà người dùng đã lưu).
export const FIT_HAIPHONG_OVERVIEW_EVENT = "map:fit-haiphong-overview";

// Mở thẻ thông tin cố định và đường viền kiểm tra trên bản đồ mà không thay đổi
// camera. Dùng chung cho thao tác click trực tiếp trên bản đồ và các danh sách
// nghiệp vụ (ví dụ Popup Chi tiết trạng thái HNTH).
export const MAP_CONTEXT_INFO_EVENT = "map:context-info";

// Chỉ chạy hiệu ứng nhận diện viền địa giới, không mở popup và không đổi camera.
// Dùng cho các thao tác phụ như Test/Ping tại Popup Chi tiết Mất kết nối.
export const MAP_ADMINISTRATIVE_PULSE_EVENT = "map:administrative-pulse";

// Yêu cầu chụp đúng một khung hình nền bản đồ. MapCanvas xử lý trong lúc
// render để không phải giữ drawing buffer trong toàn bộ vòng đời bản đồ.
export const MAP_CAPTURE_BACKGROUND_EVENT = "map:capture-background";

// Cung cấp hình học đã chiếu theo camera hiện tại cho cửa sổ trình chiếu.
// Cửa sổ trình chiếu dùng dữ liệu này để tự vẽ line và nền HNTH, không phụ
// thuộc vào việc tab chính còn được trình duyệt cho phép render hay không.
export const MAP_PRESENTATION_GEOMETRY_EVENT = "map:presentation-geometry";
