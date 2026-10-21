import { useEffect, useRef, useState } from "react";
import { usersApi } from "../../core/api/clients";
import { downloadWorkbook, readFirstSheetObjects } from "../../core/spreadsheet";

type Role = "admin" | "operator" | "viewer";
type User = { id: string; username: string; displayName: string; role: Role; isActive: boolean; department?: string; phone?: string; menuPermissions?: string[] };
type UserForm = { username: string; displayName: string; password: string; role: Role; department: string; phone: string; menuPermissions: string[] };

const menus = [
  { id: "layers", label: "Lớp dữ liệu" },
  { id: "zones", label: "Khoanh vùng" },
  { id: "saved", label: "Đối tượng đã lưu" },
  { id: "routing", label: "Định tuyến" },
  { id: "conference", label: "HNTH" },
  { id: "agents", label: "Agents" },
];
const allMenuIds = () => menus.map((menu) => menu.id);
const MIN_PASSWORD_LENGTH = 8;

const emptyForm = (): UserForm => ({ username: "", displayName: "", password: "", role: "viewer", department: "", phone: "", menuPermissions: allMenuIds() });

// Chuẩn hóa để so khớp tiêu đề cột/tìm kiếm: bỏ dấu, đ -> d, gộp khoảng trắng.
const norm = (value: unknown) => String(value ?? "").trim().toLocaleLowerCase("vi").normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/đ/g, "d").replace(/\s+/g, " ");
/** Giá trị ô theo một trong các tên cột (đã chuẩn hóa) của dòng Excel. */
const column = (row: Record<string, unknown>, names: string[]) => String(Object.entries(row).find(([key]) => names.includes(norm(key)))?.[1] ?? "").trim();
const parseRole = (value: string): Role => ["admin", "quan tri", "quan tri he thong"].includes(norm(value)) ? "admin" : ["operator", "van hanh"].includes(norm(value)) ? "operator" : "viewer";

/** Hồ sơ gửi kèm PUT: backend thay toàn bộ, nên luôn gửi đủ các trường hiện có. */
const profileOf = (user: User) => ({
  displayName: user.displayName || user.username,
  role: user.role,
  department: user.department || "",
  phone: user.phone || "",
  menuPermissions: user.menuPermissions || allMenuIds(),
  isActive: user.isActive,
});

export function UserAdminPanel({ onClose }: { onClose: () => void }) {
  const [users, setUsers] = useState<User[]>([]);
  const [form, setForm] = useState<UserForm>(emptyForm);
  const [editing, setEditing] = useState<User | null>(null);
  const [selected, setSelected] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [message, setMessage] = useState("");
  const [resetTarget, setResetTarget] = useState<User | null>(null);
  const [resetPassword, setResetPassword] = useState("");
  const [resetError, setResetError] = useState("");
  const importInput = useRef<HTMLInputElement>(null);

  const load = async () => {
    const response = await usersApi.list();
    if (!response.ok) throw new Error(response.status === 403 ? "Chỉ quản trị viên mới được quản lý tài khoản" : "Không tải được tài khoản");
    setUsers(await response.json());
  };
  useEffect(() => { void load().catch((error: Error) => setMessage(error.message)); }, []);

  const save = async (event: React.FormEvent) => {
    event.preventDefault();
    const body = { ...form, isActive: true };
    const response = editing ? await usersApi.update(editing.id, body) : await usersApi.create(body);
    const payload = await response.json();
    if (!response.ok) { setMessage(payload.error || "Không thể lưu"); return; }
    setMessage(editing ? "Đã cập nhật tài khoản" : "Đã thêm tài khoản");
    setEditing(null);
    setForm(emptyForm());
    void load();
  };

  const edit = (user: User) => {
    setEditing(user);
    setSelected(user.id);
    setForm({ username: user.username, displayName: user.displayName, password: "", role: user.role, department: user.department || "", phone: user.phone || "", menuPermissions: user.menuPermissions || allMenuIds() });
  };

  const remove = async (user: User) => {
    if (!window.confirm(`Vô hiệu hóa tài khoản ${user.username}?`)) return;
    const response = await usersApi.disable(user.id);
    if (response.ok) { setMessage("Đã vô hiệu hóa tài khoản"); void load(); }
  };

  // Admin tự nhập mật khẩu mới cho tài khoản (không còn mật khẩu reset cố định).
  const openReset = (user: User) => { setResetTarget(user); setResetPassword(""); setResetError(""); };
  const submitReset = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!resetTarget) return;
    if (resetPassword.length < MIN_PASSWORD_LENGTH) { setResetError(`Mật khẩu phải có ít nhất ${MIN_PASSWORD_LENGTH} ký tự`); return; }
    const response = await usersApi.update(resetTarget.id, { ...profileOf(resetTarget), password: resetPassword });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) { setResetError(payload.error || "Không thể đặt lại mật khẩu"); return; }
    setMessage(`Đã đặt mật khẩu mới cho ${resetTarget.username}`);
    setResetTarget(null);
    setResetPassword("");
  };

  const exportUsers = () => {
    const headers = ["STT", "Username", "Password", "Quyền", "Họ và tên", "Đơn vị", "Số điện thoại"];
    const rows = users.map((user, index) => [index + 1, user.username, "", user.role, user.displayName || user.username, user.department || "", user.phone || ""]);
    downloadWorkbook("tai-khoan.xlsx", [
      {
        name: "Tai khoan",
        rows: [headers, ...rows],
        columnWidths: [8, 22, 18, 14, 28, 32, 20],
        boldHeader: true,
        // Cột Quyền chọn từ danh sách ở sheet "Quyen".
        listValidation: { sqref: `D2:D${Math.max(rows.length + 1, 2)}`, formula1: "'Quyen'!$A$2:$A$4" },
      },
      { name: "Quyen", rows: [["Quyền"], ["admin"], ["operator"], ["viewer"]], columnWidths: [16] },
    ]);
    setMessage("Đã xuất tài khoản. Cột Password để trống vì không thể đọc lại mật khẩu.");
  };

  // Dòng có username đã tồn tại và Password trống: cập nhật Đơn vị/SĐT. Dòng mới:
  // phải có Password >= 8 ký tự. Dòng đã tồn tại nhưng có Password: bỏ qua.
  const importUsers = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) return;
    try {
      const rows = await readFirstSheetObjects(file);
      let created = 0;
      let updated = 0;
      const errors: string[] = [];
      for (const [index, row] of rows.entries()) {
        const line = index + 2;
        const username = column(row, ["username", "ten dang nhap", "tai khoan"]);
        const password = column(row, ["password", "mat khau", "pass"]);
        const existing = users.find((user) => user.username.toLowerCase() === username.toLowerCase());
        const department = column(row, ["don vi", "department"]);
        const phone = column(row, ["so dien thoai", "phone", "dien thoai"]);
        if (!username) { errors.push(`dòng ${line}: thiếu username`); continue; }
        if (existing && !password) {
          const response = await usersApi.update(existing.id, { ...profileOf(existing), department, phone });
          if (response.ok) updated++; else errors.push(`dòng ${line}: không thể cập nhật`);
          continue;
        }
        if (!password) { errors.push(`dòng ${line}: tài khoản mới phải có password`); continue; }
        if (password.length < MIN_PASSWORD_LENGTH) { errors.push(`dòng ${line}: mật khẩu phải có ít nhất 8 ký tự`); continue; }
        if (existing) { errors.push(`dòng ${line}: tài khoản đã tồn tại, để trống password để cập nhật thông tin`); continue; }
        const response = await usersApi.create({
          username,
          password,
          displayName: column(row, ["ten hien thi", "display name", "ho ten"]) || username,
          role: parseRole(column(row, ["quyen", "role"])),
          department,
          phone,
          isActive: true,
          menuPermissions: allMenuIds(),
        });
        if (response.ok) created++; else errors.push(`dòng ${line}: không thể tạo`);
      }
      await load();
      setMessage(`Đã tạo ${created}, cập nhật ${updated} tài khoản${errors.length ? `. Bỏ qua: ${errors.join("; ")}` : ""}`);
    } catch {
      setMessage("Không đọc được file XLSX");
    }
  };

  const shown = users.filter((user) => norm(`${user.username} ${user.displayName} ${user.department || ""} ${user.phone || ""}`).includes(norm(search)));
  const updateForm = (patch: Partial<UserForm>) => setForm({ ...form, ...patch });

  return <div className="admin-users-overlay">
    <section className="admin-users-card">
      <header><div><span>QUẢN TRỊ HỆ THỐNG</span><h2>Tài khoản người dùng</h2></div><button onClick={onClose}>×</button></header>
      <div className="admin-users-search"><input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Tìm username, tên, đơn vị, số điện thoại..."/></div>
      <form id="user-admin-form" onSubmit={save} className="admin-users-form">
        <input value={form.username} disabled={Boolean(editing)} onChange={(event) => updateForm({ username: event.target.value })} placeholder="Tên đăng nhập" required/>
        <input value={form.displayName} onChange={(event) => updateForm({ displayName: event.target.value })} placeholder="Tên hiển thị" required/>
        <input value={form.password} onChange={(event) => updateForm({ password: event.target.value })} placeholder={editing ? "Mật khẩu mới (bỏ trống nếu giữ nguyên)" : "Mật khẩu tối thiểu 8 ký tự"} type="password" required={!editing}/>
        <input value={form.department} onChange={(event) => updateForm({ department: event.target.value })} placeholder="Đơn vị"/>
        <input value={form.phone} onChange={(event) => updateForm({ phone: event.target.value })} placeholder="Số điện thoại"/>
        <select value={form.role} onChange={(event) => updateForm({ role: event.target.value as Role })}>
          <option value="viewer">Guest/Viewer — Chọn menu được phép</option>
          <option value="operator">Operator — Vận hành</option>
          <option value="admin">Admin — Quản trị</option>
        </select>
        {editing && <button type="button" onClick={() => { setEditing(null); setForm(emptyForm()); }}>Hủy</button>}
      </form>
      <div className="admin-users-toolbar">
        <button className="primary-button" type="submit" form="user-admin-form">{editing ? "Lưu thay đổi" : "Thêm tài khoản"}</button>
        <button type="button" onClick={() => importInput.current?.click()}>Import</button>
        <button type="button" onClick={exportUsers}>Export</button>
        <input ref={importInput} type="file" accept=".xlsx" hidden onChange={importUsers}/>
      </div>
      {message && <p className="panel-message">{message}</p>}
      <div className="admin-users-list">
        {shown.map((user) => <div className="admin-user-row" key={user.id}>
          <div className="admin-user-summary" onClick={() => setSelected(selected === user.id ? null : user.id)}>
            <strong>{user.displayName || user.username}</strong>
            <small>{user.username} · {user.role} · {user.isActive ? "Đang hoạt động" : "Đã vô hiệu hóa"}</small>
            {selected === user.id && <div className="admin-users-details">
              <span>Quyền: {user.role}</span>
              <span>Đơn vị: {user.department || "Chưa cập nhật"}</span>
              <span>Số điện thoại: {user.phone || "Chưa cập nhật"}</span>
            </div>}
          </div>
          <button onClick={() => edit(user)}>Sửa</button>
          <button onClick={() => openReset(user)}>Reset MK</button>
          <button onClick={() => void remove(user)}>Xóa</button>
        </div>)}
      </div>
    </section>
    {resetTarget && <div className="auth-overlay">
      <form className="auth-card" onSubmit={(event) => void submitReset(event)}>
        <h2>Đặt mật khẩu mới</h2>
        <small>Tài khoản <b>{resetTarget.username}</b>. Báo mật khẩu này cho người dùng; họ có thể tự đổi sau khi đăng nhập.</small>
        <input value={resetPassword} onChange={(event) => setResetPassword(event.target.value)} placeholder={`Mật khẩu mới (tối thiểu ${MIN_PASSWORD_LENGTH} ký tự)`} type="password" autoComplete="new-password" autoFocus/>
        <div className="auth-actions"><button type="button" onClick={() => setResetTarget(null)}>Hủy</button><button className="primary-button" type="submit">Lưu mật khẩu</button></div>
        {resetError && <small className="auth-error">{resetError}</small>}
      </form>
    </div>}
  </div>;
}
