import { apiUrl } from "./api/base";
import { demoMode } from "./runtime";
// GitHub Pages is a static host. Keep the normal same-origin API behaviour for
// the full deployment, but never attempt relative /api calls in the demo build.
export const backendEnabled = !demoMode;
export type AuthUser = { id: string; username: string; displayName: string; role: "admin" | "operator" | "viewer"; department?: string; phone?: string; menuPermissions?: string[] };
// Không có sessionStorage khi chạy unit test trên Node < 25 (module được import gián
// tiếp qua api/http.ts); trên trình duyệt luôn có nên hành vi không đổi.
const session: Pick<Storage, "getItem" | "setItem" | "removeItem"> = typeof sessionStorage === "undefined"
  ? { getItem: () => null, setItem: () => undefined, removeItem: () => undefined }
  : sessionStorage;
let accessToken = session.getItem("hnth_access_token") || "";
let currentUser: AuthUser | null = JSON.parse(session.getItem("hnth_user") || "null");
export function getAccessToken() { return accessToken; }
export function getCurrentUser() { return currentUser; }
export function setCurrentUser(user: AuthUser | null) { currentUser = user; if (user) session.setItem("hnth_user", JSON.stringify(user)); else session.removeItem("hnth_user"); }
export function clearAccessToken() { accessToken = ""; session.removeItem("hnth_access_token"); setCurrentUser(null); }
export async function login(username: string, password: string) {
  if (!backendEnabled) throw new Error("Bản demo tĩnh không có Backend đăng nhập");
  const response = await fetch(apiUrl(`/api/auth/login`), { method: "POST", credentials: "include", headers: { "content-type": "application/json" }, body: JSON.stringify({ username, password }) });
  if (!response.ok) throw new Error("Tên đăng nhập hoặc mật khẩu không đúng");
  const payload = await response.json() as { accessToken: string; user: AuthUser };
  accessToken = payload.accessToken; session.setItem("hnth_access_token", accessToken); setCurrentUser(payload.user); return payload;
}
export async function refresh() {
  if (!backendEnabled) return false;
  const response = await fetch(apiUrl(`/api/auth/refresh`), { method: "POST", credentials: "include" });
  if (!response.ok) return false;
  const payload = await response.json() as { accessToken: string; user?: AuthUser };
  accessToken = payload.accessToken; session.setItem("hnth_access_token", accessToken); if (payload.user) setCurrentUser(payload.user); return true;
}
export async function logout() { if (backendEnabled) await fetch(apiUrl(`/api/auth/logout`), { method: "POST", credentials: "include", headers: accessToken ? { authorization: `Bearer ${accessToken}` } : undefined }); clearAccessToken(); }
export async function changePassword(currentPassword: string, newPassword: string) { if (!backendEnabled) throw new Error("Bản demo tĩnh không có Backend"); const response = await fetch(apiUrl(`/api/auth/change-password`), { method: "POST", credentials: "include", headers: { "content-type": "application/json", ...(accessToken ? { authorization: `Bearer ${accessToken}` } : {}) }, body: JSON.stringify({ currentPassword, newPassword }) }); if (!response.ok) { const body = await response.json().catch(() => ({})); throw new Error(body.error || "Không đổi được mật khẩu"); } }
export async function updateProfile(profile: { displayName: string; department: string; phone: string }) { if (!backendEnabled) throw new Error("Bản demo tĩnh không có Backend"); const response = await fetch(apiUrl(`/api/auth/profile`), { method: "PUT", credentials: "include", headers: { "content-type": "application/json", ...(accessToken ? { authorization: `Bearer ${accessToken}` } : {}) }, body: JSON.stringify(profile) }); const body = await response.json().catch(() => ({})); if (!response.ok) throw new Error(body.error || "Không cập nhật được thông tin"); setCurrentUser(body.user); return body.user as AuthUser; }
