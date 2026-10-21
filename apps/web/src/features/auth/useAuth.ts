import { useEffect, useState } from "react";
import { changePassword, getCurrentUser, login, logout, updateProfile, type AuthUser } from "../../core/auth";
import { onAppEvent } from "../../core/events";

export type AuthModalMode = "login" | "password" | "profile";
export type AuthFields = { username: string; password: string; currentPassword: string; newPassword: string; displayName: string; department: string; phone: string };

const roleLabelOf = (user: AuthUser | null) => user?.role === "admin" ? "Quản trị hệ thống" : user?.role === "operator" ? "Vận hành" : user ? "Chỉ xem" : "Khách truy cập";

/**
 * Phiên đăng nhập của giao diện: người dùng hiện tại, modal Đăng nhập / Thông tin
 * tài khoản / Đổi mật khẩu và quyền xem menu. Các ô nhập giữ giá trị giữa các lần
 * mở modal trong cùng phiên.
 */
export function useAuth() {
  const [user, setUser] = useState<AuthUser | null>(getCurrentUser());
  const [userMenuOpen, setUserMenuOpen] = useState(false);
  const [authModal, setAuthModal] = useState<AuthModalMode | null>(null);
  const [authError, setAuthError] = useState("");
  const [authFields, setAuthFields] = useState<AuthFields>({ username: "admin", password: "", currentPassword: "", newPassword: "", displayName: "", department: "", phone: "" });

  useEffect(() => onAppEvent("hnth:auth-expired", () => setUser(null)), []);
  useEffect(() => onAppEvent("hnth:open-login", () => { setUserMenuOpen(false); setAuthError(""); setAuthModal("login"); }), []);

  const openModal = (mode: AuthModalMode) => { setUserMenuOpen(false); setAuthModal(mode); setAuthError(""); };
  const openProfile = () => {
    if (!user) return;
    setAuthFields({ ...authFields, displayName: user.displayName, department: user.department || "", phone: user.phone || "" });
    openModal("profile");
  };
  const signOut = () => { void logout(); setUser(null); setUserMenuOpen(false); };

  const submit = async () => {
    try {
      if (authModal === "login") {
        const result = await login(authFields.username, authFields.password);
        setUser(result.user);
      } else if (authModal === "profile") {
        setUser(await updateProfile({ displayName: authFields.displayName, department: authFields.department, phone: authFields.phone }));
      } else {
        await changePassword(authFields.currentPassword, authFields.newPassword);
      }
      const changedPassword = authModal === "password";
      setAuthModal(null);
      setAuthError("");
      if (changedPassword) window.alert("Đã đổi mật khẩu");
    } catch (error) {
      const fallback = authModal === "login" ? "Đăng nhập thất bại" : authModal === "profile" ? "Cập nhật thất bại" : "Không đổi được mật khẩu";
      setAuthError(error instanceof Error ? error.message : fallback);
    }
  };

  return {
    user,
    roleLabel: roleLabelOf(user),
    canSeeMenu: (menu: string) => !user || user.role !== "viewer" || (user.menuPermissions || []).includes(menu),
    userMenuOpen,
    toggleUserMenu: () => setUserMenuOpen((open) => !open),
    authModal,
    authError,
    authFields,
    setAuthFields,
    openLogin: () => openModal("login"),
    openPassword: () => openModal("password"),
    openProfile,
    closeModal: () => setAuthModal(null),
    submit,
    signOut,
  };
}

export type AuthController = ReturnType<typeof useAuth>;
