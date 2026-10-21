import type { AuthController } from "./useAuth";

const titles = { login: "Đăng nhập", profile: "Thông tin tài khoản", password: "Đổi mật khẩu" };
const submitLabels = { login: "Đăng nhập", profile: "Cập nhật", password: "Lưu mật khẩu" };

/** Modal Đăng nhập / Thông tin tài khoản / Đổi mật khẩu. */
export function AuthModal({ auth }: { auth: AuthController }) {
  const { authModal, authFields, setAuthFields, authError, user } = auth;
  if (!authModal) return null;
  const field = (key: keyof typeof authFields) => ({ value: authFields[key], onChange: (event: React.ChangeEvent<HTMLInputElement>) => setAuthFields({ ...authFields, [key]: event.target.value }) });
  return <div className="auth-overlay">
    <form className="auth-card" onSubmit={(event) => { event.preventDefault(); void auth.submit(); }}>
      <h2>{titles[authModal]}</h2>
      {authModal === "login" && <>
        <input {...field("username")} placeholder="Tên đăng nhập" autoComplete="username"/>
        <input {...field("password")} placeholder="Mật khẩu" type="password" autoComplete="current-password"/>
      </>}
      {authModal === "profile" && <>
        <input {...field("displayName")} placeholder="Họ và tên" required/>
        <input value={user?.username || ""} disabled placeholder="Username"/>
        <input {...field("department")} placeholder="Đơn vị"/>
        <input {...field("phone")} placeholder="Số điện thoại"/>
      </>}
      {authModal === "password" && <>
        <input {...field("currentPassword")} placeholder="Mật khẩu hiện tại" type="password"/>
        <input {...field("newPassword")} placeholder="Mật khẩu mới (tối thiểu 8 ký tự)" type="password"/>
      </>}
      <div className="auth-actions"><button type="button" onClick={auth.closeModal}>Hủy</button><button className="primary-button" type="submit">{submitLabels[authModal]}</button></div>
      {authError && <small className="auth-error">{authError}</small>}
    </form>
  </div>;
}
