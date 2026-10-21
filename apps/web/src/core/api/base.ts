// Gốc URL duy nhất cho mọi lời gọi backend. Rỗng (mặc định) = same-origin `/api`:
// Vite proxy ở dev, Caddy ở production. Bắt buộc cho điện thoại trong LAN, vì
// 127.0.0.1 của điện thoại là chính nó chứ không phải máy chủ. Đừng hardcode localhost.
export const API_BASE = ((import.meta.env.VITE_HNTH_BACKEND_URL as string | undefined)
  || (import.meta.env.VITE_HNTH_RELAY_URL as string | undefined)
  || "").replace(/\/$/, "");

export const apiUrl = (path: string) => `${API_BASE}${path}`;
