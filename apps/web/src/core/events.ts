// Event bus có kiểu cho *lệnh* giữa các module (điều khiển bản đồ, mở popup,
// đăng nhập...). Vẫn là window CustomEvent với tên cũ, nên listener viết tay
// còn sót vẫn nhận được. Dữ liệu dùng chung (trạng thái agent/giám sát, batch
// giám sát) không đi qua đây mà qua `core/realtime`.
import type { FixedMapInfo } from "../features/map/map-events";

export type HnthFocusDetail = {
  coordinates?: [number, number];
  preserveZoom?: boolean;
  zoomFraction?: number;
  targetZoom?: number;
  administrativeId?: number;
  boundaryWidthMultiplier?: number;
};

export type AdministrativePulseDetail = {
  administrativeId?: number;
  administrativeIds?: number[];
  cycles?: number;
  boundaryWidthMultiplier?: number;
  durationMs?: number;
  animate?: boolean;
};

export type AppEventMap = {
  /** Refresh token thất bại; App đưa người dùng về Khách. */
  "hnth:auth-expired": undefined;
  "hnth:open-login": undefined;
  /** Layer HNTH vừa nạp xong vào store; HnthPanel replay snapshot mới nhất. */
  "hnth:layer-ready": undefined;
  /** Đưa camera tới một điểm HNTH (và khoanh địa giới của nó). */
  "hnth:focus": HnthFocusDetail;
  /** Chọn điểm Sở/Ban/Ngành (không có vị trí trên bản đồ): card của điểm đó nhấp nháy viền. */
  "hnth:extra-focus": { pointId: string };
  /** Mở popup Test/Ping và gửi lệnh test-point tới Agent. */
  "hnth:test-point": { pointId?: string; ipAddress?: string; runId?: number };
  "hnth:open-point-log": { pointId?: string };
  // Đưa camera về khung tổng quan toàn Thành phố Hải Phòng. Tách khỏi nút Home
  // (có thể đi tới khung địa giới mặc định mà người dùng đã lưu).
  "map:fit-haiphong-overview": undefined;
  /** Về Home như phím 0 (lần lẻ); `then` chạy khi camera đã tới nơi. */
  "map:go-home": { then?: () => void };
  // Mở thẻ thông tin cố định và đường viền kiểm tra mà không đổi camera. Dùng
  // chung cho click trên bản đồ và các danh sách nghiệp vụ (Popup Chi tiết HNTH).
  "map:context-info": FixedMapInfo;
  // Chỉ chạy hiệu ứng nhận diện viền địa giới, không mở popup, không đổi camera.
  "map:administrative-pulse": AdministrativePulseDetail;
  // Chụp đúng một khung hình nền bản đồ. MapCanvas xử lý trong lúc render để
  // không phải giữ drawing buffer trong toàn bộ vòng đời bản đồ.
  "map:capture-background": { resolve?: (dataUrl: string | null) => void; staticOnly?: boolean };
  // Hình học đã chiếu theo camera hiện tại cho cửa sổ trình chiếu, để cửa sổ đó
  // tự vẽ line/nền HNTH kể cả khi tab chính bị trình duyệt ngừng render.
  "map:presentation-geometry": { resolve?: (value: unknown) => void };
};

export type AppEventName = keyof AppEventMap;

export function emitAppEvent<K extends AppEventName>(
  name: K,
  ...detail: AppEventMap[K] extends undefined ? [] : [AppEventMap[K]]
) {
  window.dispatchEvent(new CustomEvent(name, { detail: detail[0] }));
}

/** Đăng ký listener; trả hàm hủy để dùng thẳng làm cleanup của useEffect. */
export function onAppEvent<K extends AppEventName>(name: K, handler: (detail: AppEventMap[K]) => void) {
  const listener = (event: Event) => handler((event as CustomEvent<AppEventMap[K]>).detail);
  window.addEventListener(name, listener);
  return () => window.removeEventListener(name, listener);
}
