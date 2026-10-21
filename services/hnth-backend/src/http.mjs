// Tiện ích HTTP không phụ thuộc nghiệp vụ.

export function createCors(allowedOrigins) {
  // Trả origin của request nếu nằm trong danh sách (cookie refresh cần đúng origin);
  // ngược lại trả origin đầu tiên để trình duyệt chặn.
  return function corsOrigin(req) {
    const origin = String(req?.headers?.origin || "");
    if (allowedOrigins.includes("*")) return origin || "*";
    return allowedOrigins.includes(origin) ? origin : allowedOrigins[0];
  };
}

export function sendJson(res, status, body, headers, corsOrigin) {
  res.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store, no-cache, must-revalidate",
    "pragma": "no-cache",
    "access-control-allow-origin": corsOrigin,
    "access-control-allow-credentials": "true",
    "access-control-allow-headers": "content-type, authorization, x-agent-id",
    "access-control-allow-methods": "GET,POST,PUT,PATCH,DELETE,OPTIONS",
    "vary": "Origin",
    ...headers,
  });
  res.end(JSON.stringify(body));
}

const MAX_JSON_BYTES = 2_000_000;
export function readJson(req) {
  return new Promise((resolve, reject) => {
    let raw = "";
    req.on("data", (chunk) => { raw += chunk; if (raw.length > MAX_JSON_BYTES) reject(new Error("body too large")); });
    req.on("end", () => { try { resolve(raw ? JSON.parse(raw) : {}); } catch { reject(new Error("invalid json")); } });
    req.on("error", reject);
  });
}

/**
 * IP của client. Sau reverse proxy (Caddy) chỉ tin X-Forwarded-For khi trustProxy,
 * vì nếu backend lộ cổng trực tiếp, client tự đặt được header này.
 */
export function clientIp(req, trustProxy) {
  const forwarded = trustProxy ? String(req.headers["x-forwarded-for"] || "").split(",")[0].trim() : "";
  return forwarded || req.socket?.remoteAddress || "unknown";
}

/** Request đi tới qua HTTPS (trực tiếp, hoặc proxy báo X-Forwarded-Proto khi trustProxy). */
export function isSecureRequest(req, trustProxy) {
  if (req.socket?.encrypted) return true;
  return trustProxy && String(req.headers["x-forwarded-proto"] || "").split(",")[0].trim() === "https";
}

export function readCookie(req, name) {
  const match = String(req.headers.cookie || "").match(new RegExp(`(?:^|;)\\s*${name}=([^;]+)`));
  return match?.[1];
}
