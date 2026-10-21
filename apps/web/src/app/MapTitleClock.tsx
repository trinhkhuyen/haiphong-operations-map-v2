import { useEffect, useState } from "react";

const WEEKDAYS = ["Chủ Nhật", "Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy"];
const pad = (value: number) => String(value).padStart(2, "0");

/** Đồng hồ 24h bên phải card Bản đồ vận hành: "14:05:09" và "Thứ Tư - 21/10/2026". */
export function MapTitleClock() {
  const [now, setNow] = useState(() => new Date());
  useEffect(() => {
    // Căn theo đầu mỗi giây để giây hiển thị không lệch so với đồng hồ hệ thống.
    let timer = window.setTimeout(function tick() {
      setNow(new Date());
      timer = window.setTimeout(tick, 1000 - (Date.now() % 1000));
    }, 1000 - (Date.now() % 1000));
    return () => window.clearTimeout(timer);
  }, []);
  return <div className="map-title-clock" aria-label="Thời gian hiện tại">
    <b>{pad(now.getHours())}:{pad(now.getMinutes())}:{pad(now.getSeconds())}</b>
    <em>{WEEKDAYS[now.getDay()]} - {pad(now.getDate())}/{pad(now.getMonth() + 1)}/{now.getFullYear()}</em>
  </div>;
}
