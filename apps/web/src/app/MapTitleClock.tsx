import { useEffect, useState } from "react";

const WEEKDAYS = ["Chủ Nhật", "Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy"];
const pad = (value: number) => String(value).padStart(2, "0");
export const formatClockTime = (date: Date) => `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;

export function useCurrentTime() {
  const [now, setNow] = useState(() => new Date());
  useEffect(() => {
    let timer = window.setTimeout(function tick() {
      setNow(new Date());
      timer = window.setTimeout(tick, 1000 - (Date.now() % 1000));
    }, 1000 - (Date.now() % 1000));
    return () => window.clearTimeout(timer);
  }, []);
  return now;
}

/** Đồng hồ 24h bên phải card Bản đồ vận hành: "14:05:09" và "Thứ Tư - 21/10/2026". */
export function MapTitleClock() {
  const now = useCurrentTime();
  return <div className="map-title-clock" aria-label="Thời gian hiện tại">
    <b>{formatClockTime(now)}</b>
    <em>{WEEKDAYS[now.getDay()]} - {pad(now.getDate())}/{pad(now.getMonth() + 1)}/{now.getFullYear()}</em>
  </div>;
}
