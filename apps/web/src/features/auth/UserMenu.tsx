import { UserRound } from "lucide-react";
import type { AuthController } from "./useAuth";

/** Chip người dùng trên thanh tiêu đề và menu tài khoản thả xuống. */
export function UserMenu({ auth }: { auth: AuthController }) {
  const { user, roleLabel } = auth;
  return <>
    <button className="user-chip" onClick={auth.toggleUserMenu} aria-label="Tài khoản người dùng"><span><UserRound size={17}/></span><div><strong>{user?.displayName || "Guest"}</strong><small>{roleLabel}</small></div></button>
    {auth.userMenuOpen && <div className="user-menu">
      <strong>{user?.displayName || "Guest"}</strong>
      <small>{user ? `${user.username} · ${roleLabel}` : "Bạn đang sử dụng với quyền Guest"}</small>
      {user && <>
        <small>Đơn vị: {user.department || "Chưa cập nhật"} · SĐT: {user.phone || "Chưa cập nhật"}</small>
        <button onClick={auth.openProfile}>Chỉnh sửa thông tin</button>
        <button onClick={auth.openPassword}>Đổi mật khẩu</button>
        <button onClick={auth.signOut}>Đăng xuất</button>
      </>}
      {!user && <button onClick={auth.openLogin}>Đăng nhập</button>}
    </div>}
  </>;
}
