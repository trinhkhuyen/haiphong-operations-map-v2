import { useEffect, useLayoutEffect, useState } from "react";
import { useAppStore } from "../../core/store";
import { HNTH_STATUS_LABELS, normalizeHnthStatus } from "../layers/hnth-data-provider";

const AUTO_HIDE_MS = 5000;

/**
 * Popup Chi tiết Endpoint gọn: tên điểm, IP, trạng thái trên 3 dòng. Nằm ở đầu thanh trạng
 * thái HNTH (bên trái ô Chưa xác định), cao bằng thanh; kiểu thường/trong suốt theo log hiện tại.
 * Mỗi lần chọn điểm (`selection` đổi) hiện lại và tự tắt sau 5 giây nếu không chọn điểm khác.
 */
export function HnthEndpointCard({ properties, selection }: { properties: Record<string, unknown> | undefined; selection: unknown }) {
  const transparent = useAppStore((state) => state.hnthTransparentPopups);
  const [visible, setVisible] = useState(false);
  const [box, setBox] = useState<{ right: number; top: number; height: number } | null>(null);

  useEffect(() => {
    if (!selection) { setVisible(false); return; }
    setVisible(true);
    const timer = window.setTimeout(() => setVisible(false), AUTO_HIDE_MS);
    return () => window.clearTimeout(timer);
  }, [selection]);

  // Đo thanh trạng thái (vị trí phụ thuộc bề rộng bản đồ và menu trái đóng/mở).
  useLayoutEffect(() => {
    if (!visible) return;
    const measure = () => {
      const strip = document.querySelector(".hnth-metric-strip")?.getBoundingClientRect();
      const area = document.querySelector(".map-area")?.getBoundingClientRect();
      // Thanh trạng thái bị ẩn (màn hình hẹp): dùng vị trí mặc định trong CSS.
      if (!strip?.width || !area) { setBox(null); return; }
      setBox({ right: area.right - strip.left + 8, top: strip.top - area.top, height: strip.height });
    };
    measure();
    window.addEventListener("resize", measure);
    return () => window.removeEventListener("resize", measure);
  }, [visible]);

  if (!visible || !properties) return null;
  const status = normalizeHnthStatus(properties.status);
  const ip = String(properties.ipAddress ?? "").trim();
  return <aside
    className={`hnth-endpoint-card ${status}${transparent ? " is-overlay" : ""}`}
    style={box ? { right: box.right, top: box.top, height: box.height } : undefined}
    aria-live="polite"
    aria-label={`Chi tiết Endpoint ${String(properties.name ?? "")}`}
  >
    <strong>{String(properties.name ?? "Điểm HNTH")}</strong>
    <small>{ip || "Chưa có IP"}</small>
    <em><i/>{HNTH_STATUS_LABELS[status]}</em>
  </aside>;
}
