// Hợp đồng dùng chung giữa agent, backend và web. ESM thuần, không phụ thuộc
// Node hay DOM: backend/agent import trực tiếp (không có bước build), web dùng
// qua Vite với kiểu trong index.d.ts.

/** Trạng thái agent đo được (ping): agent gửi, backend lưu. */
export const AGENT_STATUSES = Object.freeze(["online", "offline", "unknown"]);

/**
 * Lease giám sát liên tục: phiên giám sát chỉ sống khi còn giao diện Operator
 * đang mở gia hạn định kỳ. Hết hạn thì backend tắt cờ và gửi monitor-stop.
 */
export const MONITOR_LEASE_SECONDS = 120;
export const MONITOR_LEASE_RENEW_SECONDS = 30;
/** Agent tự dừng giám sát khi không liên lạc được backend quá ngần này giây. */
export const AGENT_BACKEND_LOSS_STOP_SECONDS = 60;

/** Trạng thái hiển thị trên bản đồ HNTH (frontend). */
export const CONNECTION_STATUSES = Object.freeze(["unknown", "unconnected", "connected", "lost"]);

/**
 * Ánh xạ kết quả agent sang trạng thái hiển thị. Không có IP luôn là unknown,
 * bất kể payload nói gì. `connected` chỉ đặt thủ công, không bao giờ từ ping:
 * ping chỉ chứng minh thiết bị reachable (Chờ kết nối), chưa chứng minh đang họp.
 */
export function toConnectionStatus(agentStatus, hasIp) {
  if (!hasIp) return "unknown";
  if (agentStatus === "online") return "unconnected";
  if (agentStatus === "offline") return "lost";
  return "unknown";
}

/**
 * Phân loại một lượt ping nhiều gói. Một gói trả lời chưa đủ để coi là online:
 * với 4 gói mặc định, 4/4 là online, 2–3/4 là unknown, 0–1/4 là offline.
 */
export function classifyProbeResult(successful, total) {
  if (successful === total) return "online";
  if (successful * 2 >= total) return "unknown";
  return "offline";
}

/** Các lệnh Operator/Admin được phép gửi qua POST /api/agents/:id/commands. */
export const OPERATOR_COMMAND_TYPES = Object.freeze(["scan-local-network", "test-point", "point-config", "monitor-start", "monitor-stop", "camera-probe", "camera-stream-start", "camera-stream-stop", "agent-update"]);

/** Resource VS_VERSIONINFO của launcher portable nằm trong vài trăm KB đầu file. */
export const EXE_VERSION_SCAN_BYTES = 2 * 1024 * 1024;

const PRODUCT_VERSION_KEY = Array.from("ProductVersion\0").flatMap((char) => [char.charCodeAt(0), 0]);
const VERSION_PATTERN = /^\d+\.\d+\.\d+(?:[-.][0-9A-Za-z.-]+)?/;

/**
 * Đọc chuỗi ProductVersion (UTF-16LE) do electron-builder ghi vào file .exe.
 * `bytes` là phần đầu file (tối đa EXE_VERSION_SCAN_BYTES). Trả null nếu không có
 * hoặc giá trị không giống version.
 */
export function readExeVersion(bytes) {
  const keyLength = PRODUCT_VERSION_KEY.length;
  search: for (let index = 0; index + keyLength <= bytes.length; index += 1) {
    for (let offset = 0; offset < keyLength; offset += 1) if (bytes[index + offset] !== PRODUCT_VERSION_KEY[offset]) continue search;
    let cursor = index + keyLength;
    cursor += (4 - (cursor % 4)) % 4;
    let value = "";
    for (; cursor + 1 < bytes.length; cursor += 2) {
      const code = bytes[cursor] | (bytes[cursor + 1] << 8);
      if (!code) break;
      value += String.fromCharCode(code);
    }
    const match = value.trim().match(VERSION_PATTERN);
    if (match) return match[0];
  }
  return null;
}

/** So sánh version theo số từng phần (0.2.10 > 0.2.9). Âm/0/dương như sort. */
export function compareVersions(a, b) {
  const left = String(a).split(/[.-]/).map(Number);
  const right = String(b).split(/[.-]/).map(Number);
  for (let index = 0; index < Math.max(left.length, right.length); index += 1) {
    const diff = (left[index] || 0) - (right[index] || 0);
    if (diff) return diff;
  }
  return 0;
}
