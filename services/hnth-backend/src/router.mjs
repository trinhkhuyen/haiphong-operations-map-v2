// Router tối giản: khớp method + đường dẫn theo từng đoạn, ":ten" là tham số.
// Route `public: true` chạy không cần đăng nhập (live-view cho Guest và API của Agent,
// tự xác thực bằng token agent); còn lại app.mjs xác thực người dùng trước.
export function createRouter() {
  const routes = [];
  const compile = (pattern) => pattern.split("/").filter(Boolean);
  return {
    add(method, pattern, handler, options = {}) {
      routes.push({ method, segments: compile(pattern), handler, public: Boolean(options.public) });
      return this;
    },
    match(method, pathname) {
      const parts = pathname.split("/").filter(Boolean);
      for (const route of routes) {
        if (route.method !== method || route.segments.length !== parts.length) continue;
        const params = {};
        let ok = true;
        for (let index = 0; index < parts.length; index += 1) {
          const segment = route.segments[index];
          if (segment.startsWith(":")) {
            try { params[segment.slice(1)] = decodeURIComponent(parts[index]); } catch { ok = false; break; }
          } else if (segment !== parts[index]) { ok = false; break; }
        }
        if (ok) return { route, params };
      }
      return null;
    },
  };
}
