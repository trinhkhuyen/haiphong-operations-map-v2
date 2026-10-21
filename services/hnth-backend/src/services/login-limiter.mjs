// Chặn dò mật khẩu ở /api/auth/login: đếm lần đăng nhập sai trong cửa sổ thời gian
// theo (IP + tài khoản) và theo IP. Lưu trong bộ nhớ: đủ cho một tiến trình backend;
// khởi động lại thì bộ đếm về 0.
export function createLoginLimiter({ maxPerAccount = 5, maxPerIp = 30, windowMs = 15 * 60_000, now = Date.now } = {}) {
  const buckets = new Map();
  const accountKey = (ip, username) => `account:${ip}|${String(username || "").trim().toLowerCase()}`;
  const ipKey = (ip) => `ip:${ip}`;

  function bucket(key) {
    const current = buckets.get(key);
    if (current && current.resetAt > now()) return current;
    buckets.delete(key);
    return null;
  }

  function prune() {
    if (buckets.size < 10_000) return;
    for (const [key, value] of buckets) if (value.resetAt <= now()) buckets.delete(key);
  }

  /** { allowed, retryAfterSeconds } — kiểm tra trước khi so mật khẩu. */
  function check(ip, username) {
    const blocked = [[bucket(accountKey(ip, username)), maxPerAccount], [bucket(ipKey(ip)), maxPerIp]]
      .filter(([value, limit]) => value && value.count >= limit)
      .map(([value]) => value.resetAt);
    if (!blocked.length) return { allowed: true, retryAfterSeconds: 0 };
    return { allowed: false, retryAfterSeconds: Math.max(1, Math.ceil((Math.max(...blocked) - now()) / 1000)) };
  }

  function recordFailure(ip, username) {
    prune();
    for (const key of [accountKey(ip, username), ipKey(ip)]) {
      const value = bucket(key) ?? { count: 0, resetAt: now() + windowMs };
      value.count += 1;
      buckets.set(key, value);
    }
  }

  /** Đăng nhập đúng thì xóa bộ đếm của tài khoản (bộ đếm theo IP giữ nguyên). */
  function recordSuccess(ip, username) {
    buckets.delete(accountKey(ip, username));
  }

  return { check, recordFailure, recordSuccess };
}
