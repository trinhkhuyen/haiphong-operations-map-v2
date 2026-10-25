import { useEffect, useRef, useState } from "react";
import { Cable, Camera, Download, FileSpreadsheet, MapPin, Pencil, Plus, QrCode, Trash2, Upload, X } from "lucide-react";
import { useAppStore } from "../../core/store";
import { agentsApi, cameraApi } from "../../core/api/clients";
import type { CameraDevice, CameraStatus } from "../../core/store/camera";
import { emitAppEvent, onAppEvent } from "../../core/events";
import { subscribeCameraResults } from "../../core/realtime/camera-realtime";
import { exportCameraDevicesXlsx, readCameraImportFile } from "./camera-import-export";
import { loadGovernmentUbndPoints, type UbndPoint } from "../administrative/data-provider";

type CameraForm = Omit<CameraDevice, "id" | "channels" | "status" | "updatedAt" | "lastError" | "checkedAt" | "password"> & { password: string };

const emptyForm = (): CameraForm => ({
  name: "", serialNumber: "", username: "admin", password: "", ipAddress: "", vendor: "hikvision", model: "", devicePort: 8000, httpPort: 80, streamPort: 554, connectionMethod: "lan",
  autoConnect: false,
  administrativeId: null, longitude: null, latitude: null,
});

const labels: Record<CameraStatus, string> = { online: "Đang kết nối", offline: "Mất kết nối", unknown: "Chưa kiểm tra", unsupported: "Chưa có adapter", credentials_required: "Sai thông tin đăng nhập" };

const fromApi = (raw: Record<string, unknown>, password = ""): CameraDevice => ({
  id: String(raw.id), name: String(raw.name || ""), serialNumber: String(raw.serialNumber || ""), username: String(raw.username || "admin"), password,
  model: raw.model ? String(raw.model) : null, devicePort: typeof raw.devicePort === "number" ? raw.devicePort : 8000, httpPort: typeof raw.httpPort === "number" ? raw.httpPort : 80, streamPort: typeof raw.streamPort === "number" ? raw.streamPort : 554,
  channels: typeof raw.channels === "number" ? raw.channels : null, onlineChannels: typeof raw.onlineChannels === "number" ? raw.onlineChannels : null, channelStates: Array.isArray(raw.channelStates) ? raw.channelStates as CameraDevice["channelStates"] : [], channelNames: raw.channelNames && typeof raw.channelNames === "object" && !Array.isArray(raw.channelNames) ? raw.channelNames as Record<string, string> : {}, latencyMs: typeof raw.latencyMs === "number" ? raw.latencyMs : null, status: (raw.status as CameraStatus) || "unknown",
  administrativeId: raw.administrativeId === null || raw.administrativeId === undefined || raw.administrativeId === "" ? null : String(raw.administrativeId), longitude: typeof raw.longitude === "number" ? raw.longitude : null,
  latitude: typeof raw.latitude === "number" ? raw.latitude : null, ipAddress: String(raw.ipAddress || ""), vendor: String(raw.vendor || ""),
  connectionMethod: String(raw.connectionMethod || "auto"), autoConnect: raw.autoConnect === true, lastError: raw.lastError ? String(raw.lastError) : null, checkedAt: raw.checkedAt ? String(raw.checkedAt) : null,
  updatedAt: String(raw.updatedAt || new Date().toISOString()),
});

export function CameraPanel({ readOnly = false }: { readOnly?: boolean }) {
  const devices = useAppStore((state) => state.cameraDevices);
  const [ubndPoints, setUbndPoints] = useState<UbndPoint[]>([]);
  const setDevices = useAppStore((state) => state.setCameraDevices);
  const upsert = useAppStore((state) => state.upsertCameraDevice);
  const update = useAppStore((state) => state.updateCameraDevice);
  const remove = useAppStore((state) => state.removeCameraDevice);
  const [editing, setEditing] = useState<CameraDevice | null>(null);
  const [channelNames, setChannelNames] = useState<Record<number, string>>({});
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState<CameraForm>(emptyForm());
  const [message, setMessage] = useState("");
  const [notice, setNotice] = useState("");
  const [busy, setBusy] = useState(false);
  const fileRef = useRef<HTMLInputElement | null>(null);
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const streamRef = useRef<MediaStream | null>(null);

  useEffect(() => {
    if (readOnly) return;
    void cameraApi.list().then(async (response) => {
      if (response.ok) setDevices((await response.json()).map((item: Record<string, unknown>) => fromApi(item)));
    });
  }, [readOnly, setDevices]);

  useEffect(() => { void loadGovernmentUbndPoints().then(setUbndPoints).catch(() => setUbndPoints([])); }, []);

  useEffect(() => onAppEvent("camera:probe", (detail) => {
    const device = useAppStore.getState().cameraDevices.find((item) => item.id === detail.deviceId);
    if (device) void probeDevice(device);
  }), []);

  useEffect(() => onAppEvent("camera:disconnect", (detail) => {
    const device = useAppStore.getState().cameraDevices.find((item) => item.id === detail.deviceId);
    if (device) void disconnectDevice(device);
  }), []);

  useEffect(() => subscribeCameraResults((results) => {
    const state = useAppStore.getState();
    for (const result of results) {
      if (!result.cameraId) continue;
      const status = (result.status as CameraStatus) || "unknown";
      const reportedStates = Array.isArray(result.channelStates) ? result.channelStates : [];
      // Backend maps agent channel IDs to the persisted user labels before broadcasting.
      const channelStates = reportedStates;
      state.updateCameraDevice(result.cameraId, {
        status,
        channels: typeof result.channels === "number" ? result.channels : null,
        onlineChannels: typeof result.onlineChannels === "number" ? result.onlineChannels : null,
        channelStates,
        latencyMs: typeof result.latencyMs === "number" ? result.latencyMs : null,
        lastError: status === "online" ? null : (result.reason || null),
        checkedAt: result.checkedAt || new Date().toISOString(),
        vendor: result.vendor || undefined,
        model: result.model || undefined,
      });
      state.appendCameraLog(result.cameraId, status === "online" ? "Camera-Agent đã kiểm tra đầu ghi thành công" : (result.reason || "Kiểm tra đầu ghi thất bại"), status === "online" ? "success" : "error");
    }
  }), []);

  useEffect(() => () => streamRef.current?.getTracks().forEach((track) => track.stop()), []);

  const close = () => {
    setOpen(false); setEditing(null); streamRef.current?.getTracks().forEach((track) => track.stop()); streamRef.current = null;
  };

  const begin = (device?: CameraDevice) => {
    setEditing(device || null);
    setChannelNames(Object.fromEntries((device?.channelStates || []).filter((channel) => channel.online).map((channel) => [channel.id, channel.name || ""])));
    setForm(device ? {
      name: device.name, serialNumber: device.serialNumber, username: device.username, password: "", ipAddress: device.ipAddress || "", vendor: device.vendor || "",
      model: device.model || "", devicePort: device.devicePort || 8000, httpPort: device.httpPort || 80, streamPort: device.streamPort || 554, connectionMethod: device.connectionMethod || "lan", autoConnect: device.autoConnect === true, administrativeId: device.administrativeId, longitude: device.longitude, latitude: device.latitude,
    } : emptyForm());
    setMessage(""); setOpen(true);
  };

  const scanQr = async () => {
    const Detector = (globalThis as typeof globalThis & { BarcodeDetector?: new (options?: { formats?: string[] }) => { detect: (source: ImageBitmapSource) => Promise<Array<{ rawValue?: string }>> } }).BarcodeDetector;
    if (!Detector || !navigator.mediaDevices?.getUserMedia) return setMessage("Trình duyệt chưa hỗ trợ quét QR.");
    try {
      streamRef.current = await navigator.mediaDevices.getUserMedia({ video: true });
      if (videoRef.current) videoRef.current.srcObject = streamRef.current;
      const value = (await new Detector({ formats: ["qr_code"] }).detect(videoRef.current as HTMLVideoElement))[0]?.rawValue;
      if (value) setForm((current) => ({ ...current, serialNumber: value })); else setMessage("Chưa nhận diện được mã QR.");
    } catch { setMessage("Không thể đọc mã QR từ webcam."); }
    finally { streamRef.current?.getTracks().forEach((track) => track.stop()); streamRef.current = null; }
  };

  const save = async () => {
    const connectionMethod = String(form.connectionMethod || "lan").toLowerCase();
    const missingIdentity = connectionMethod === "p2p" ? !form.serialNumber.trim() : !String(form.ipAddress || "").trim();
    if (!form.name.trim()) return setMessage("Vui lòng nhập tên thiết bị.");
    if (missingIdentity) return setMessage(connectionMethod === "p2p" ? "P2P cần Mã P2P / Serial Number." : "LAN / ONVIF cần Địa chỉ LAN.");
    if (!form.administrativeId && (typeof form.longitude !== "number" || typeof form.latitude !== "number")) return setMessage("Thiết bị ngoài danh sách mốc UBND cần nhập kinh độ và vĩ độ.");
    if (!editing && !form.password.trim()) return setMessage("Vui lòng nhập mật khẩu thiết bị.");
    setBusy(true);
    try {
      const response = editing ? await cameraApi.update(editing.id, form) : await cameraApi.create(form);
      if (!response.ok) throw new Error((await response.json().catch(() => ({}))).error || "Không lưu được thiết bị");
      upsert(fromApi(await response.json(), form.password)); close();
    } catch (error) { setMessage(error instanceof Error ? error.message : "Không lưu được thiết bị"); }
    finally { setBusy(false); }
  };

  const probeDevice = async (device: CameraDevice) => {
    update(device.id, { status: "unknown", lastError: null });
    try {
      const response = await agentsApi.list(); const agents = response.ok ? await response.json() : [];
      const cameraAgents = agents.filter((item: { agentId?: string; name?: string }) => /camera/i.test(`${item.agentId || ""} ${item.name || ""}`));
      const agent = cameraAgents.find((item: { status?: string }) => item.status === "online") || cameraAgents[0];
      if (!agent) throw new Error("Chưa có Agent để kiểm tra");
      const result = await cameraApi.probe(device.id, agent.agentId); if (!result.ok) throw new Error("Không gửi được yêu cầu tới Agent");
      setNotice(`Đã gửi yêu cầu kiểm tra “${device.name}” tới Camera-Agent.`);
    } catch (error) { update(device.id, { status: "unknown", lastError: error instanceof Error ? error.message : "Probe thất bại" }); }
  };

  const disconnectDevice = async (device: CameraDevice) => {
    const response = await cameraApi.disconnect(device.id);
    if (!response.ok) { setNotice((await response.json().catch(() => ({}))).error || "Không thể ngắt kết nối thiết bị"); return; }
    update(device.id, { status: "unknown", onlineChannels: 0, channelStates: (device.channelStates || []).map((channel) => ({ ...channel, online: false })), lastError: "Đã ngắt kết nối theo yêu cầu người dùng", checkedAt: new Date().toISOString() });
    setNotice(`Đã ngắt kết nối “${device.name}”. Bấm Kết nối để kiểm tra lại.`);
  };

  const saveChannelName = async (device: CameraDevice, channelId: number, name: string) => {
    const response = await cameraApi.update(device.id, { channelId, channelName: name.trim() });
    if (!response.ok) { setNotice("Không lưu được tên kênh camera."); return; }
    const saved = await response.json().catch(() => ({})) as { channelStates?: CameraDevice["channelStates"]; channelNames?: CameraDevice["channelNames"] };
    const persistedStates = Array.isArray(saved.channelStates) ? saved.channelStates : [];
    update(device.id, { channelStates: persistedStates, channelNames: saved.channelNames });
    setEditing((current) => current?.id === device.id ? { ...current, channelStates: persistedStates } : current);
    setChannelNames((current) => ({ ...current, [channelId]: persistedStates.find((channel) => channel.id === channelId)?.name || name.trim() }));
    setNotice(`Đã lưu tên kênh ${channelId} vào cơ sở dữ liệu của “${device.name}”.`);
  };

  const setAutoConnect = async (device: CameraDevice, enabled: boolean) => {
    const response = await cameraApi.update(device.id, { autoConnect: enabled });
    if (!response.ok) { setNotice("Không lưu được cấu hình tự động kết nối."); return; }
    update(device.id, { autoConnect: enabled });
    setNotice(`${enabled ? "Đã bật" : "Đã tắt"} tự động kết nối cho “${device.name}”.`);
  };

  const importFile = async (file: File) => {
    try {
      const rows = await readCameraImportFile(file);
      rows.forEach((row, index) => upsert({ id: `camera-import-${Date.now()}-${index}`, ...row, channels: null, status: "unknown", updatedAt: new Date().toISOString() }));
      setNotice(`Đã nhập ${rows.length} thiết bị. Hãy bấm kiểm tra để tự dò kết nối và số kênh.`);
    } catch (error) { setNotice(error instanceof Error ? error.message : "Không đọc được file Camera"); }
  };

  const outsideBoundaryCount = devices.filter((device) => device.administrativeId === null).length;

  return <section className="panel-section camera-panel">
    <div className="section-heading camera-heading"><div><span className="eyebrow">THIẾT BỊ GIÁM SÁT</span><h2>Quản lý Camera</h2><span className="count-chip">{devices.length} đầu ghi</span></div></div>
    <div className="camera-intro"><Camera size={20} /><div><strong>Quản lý đầu ghi và camera</strong><p>Thêm thiết bị, gán vị trí trên bản đồ và kiểm tra qua Agent tại mạng nội bộ.</p></div></div>

    {!readOnly && <div className="camera-action-panel"><div className="camera-action-copy"><strong>Thao tác nhanh</strong><span>Nhập danh sách theo mẫu cùng các trường cấu hình đầu ghi.</span></div><div className="camera-toolbar">
      <input ref={fileRef} hidden type="file" accept=".csv,.xlsx" onChange={(event) => { const file = event.target.files?.[0]; if (file) void importFile(file); event.currentTarget.value = ""; }} />
      <button className="secondary-button" type="button" onClick={() => fileRef.current?.click()}><Upload size={14} /> Import</button><button className="secondary-button" type="button" onClick={() => void exportCameraDevicesXlsx(devices, ubndPoints)}><Download size={14} /> Export</button><button className="camera-add-button" type="button" onClick={() => begin()}><Plus size={15} /> Thêm thiết bị mới</button>
    </div></div>}

    {notice && <div className="camera-notice"><FileSpreadsheet size={14} /><span>{notice}</span><button type="button" onClick={() => setNotice("")} aria-label="Đóng thông báo"><X size={13} /></button></div>}
    <div className="camera-summary-row"><div><span>Tổng thiết bị</span><strong>{devices.length}</strong></div><div><span>Đang kết nối</span><strong className="online-text">{devices.filter((device) => device.status === "online").length}</strong></div><div><span>Ngoài địa giới</span><strong>{outsideBoundaryCount}</strong></div><div><span>Chưa dò kênh</span><strong>{devices.filter((device) => device.channels === null).length}</strong></div></div>

    <div className="camera-section-title"><div><span className="eyebrow">DANH SÁCH THIẾT BỊ</span><h3>Đầu ghi đã cấu hình</h3></div><span>{devices.length} thiết bị</span></div>
    {devices.length === 0 ? <div className="camera-empty"><Camera size={25} /><strong>Chưa có đầu ghi hoặc camera</strong><span>Thêm thiết bị mới hoặc import file danh sách để bắt đầu.</span>{!readOnly && <button className="primary-button" type="button" onClick={() => begin()}>Thêm thiết bị mới</button>}</div> : <div className="camera-device-list">{devices.map((device) => <article className="camera-device-card" key={device.id} onClick={() => { useAppStore.getState().selectCamera(device.id); emitAppEvent("map:context-info", { kind: "camera", deviceId: device.id }); }}>
      <div className="camera-device-main"><strong>{device.name}</strong><small>{device.model || device.vendor || "Thiết bị LAN"} · S/N: {device.serialNumber || "Không có (LAN)"}</small><small>{device.administrativeId ? ubndPoints.find((point) => point.wardCode === device.administrativeId)?.name || "Mốc UBND đã gán" : "Điểm ngoài danh sách mốc UBND"}</small><span className={`camera-status ${device.status}`}><i /> {labels[device.status]}</span>{device.lastError && <small>{device.lastError}</small>}{device.status === "online" && device.channels === null && <small>RTSP đã xác thực · Tổng số kênh chưa cập nhật</small>}{device.status === "online" && device.streamPort && <small>RTSP: {device.streamPort} · {device.latencyMs ?? "-"} ms</small>}</div><div className="camera-channel"><small>Kênh online / tổng</small><strong>{device.channels === null ? device.status === "online" ? `${device.onlineChannels ?? 0} / ?` : "Chưa dò" : `${device.onlineChannels ?? 0} / ${device.channels}`}</strong></div>
      {!readOnly && <div className="camera-card-actions"><label className="camera-auto-connect-toggle" onClick={(event) => event.stopPropagation()}><input type="checkbox" checked={device.autoConnect === true} onChange={(event) => void setAutoConnect(device, event.currentTarget.checked)} /><span>Tự động kết nối</span></label><button className={`camera-connect-action ${device.status === "online" ? "disconnect" : ""}`} type="button" title={device.status === "online" ? "Ngắt kết nối thiết bị" : "Gửi yêu cầu kết nối và kiểm tra kênh"} onClick={(event) => { event.stopPropagation(); void (device.status === "online" ? disconnectDevice(device) : probeDevice(device)); }}><Cable size={14} /><span>{device.status === "online" ? "Ngắt" : "Kết nối"}</span></button><button type="button" title="Chỉnh sửa" onClick={(event) => { event.stopPropagation(); begin(device); }}><Pencil size={14} /></button><button type="button" title="Xóa" onClick={async (event) => { event.stopPropagation(); if (window.confirm(`Xóa thiết bị "${device.name}"?`) && (await cameraApi.remove(device.id)).ok) remove(device.id); }}><Trash2 size={14} /></button></div>}
    </article>)}</div>}

    {open && <div className="camera-modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) close(); }}><section className="camera-modal" role="dialog" aria-modal="true">
      <header><div><span className="eyebrow">CẤU HÌNH ĐẦU GHI</span><h3>{editing ? "Chỉnh sửa thiết bị" : "Thêm thiết bị mới"}</h3></div><button type="button" onClick={close} aria-label="Đóng"><X size={18} /></button></header>
      <div className="camera-form">
        {editing?.status === "online" && (editing.channelStates || []).some((channel) => channel.online) && <div className="camera-form-group camera-channel-editor"><span className="camera-form-group-title">Đặt tên kênh online</span><small className="camera-channel-editor-hint">Tên kênh được lưu khi rời ô nhập hoặc nhấn Enter.</small>{(editing.channelStates || []).filter((channel) => channel.online).map((channel) => <label key={channel.id}>Kênh {channel.id}<input value={channelNames[channel.id] ?? channel.name ?? ""} placeholder={`Camera ${channel.id}`} onChange={(event) => setChannelNames((current) => ({ ...current, [channel.id]: event.target.value }))} onBlur={(event) => void saveChannelName(editing, channel.id, event.currentTarget.value)} onKeyDown={(event) => { if (event.key === "Enter") event.currentTarget.blur(); }} /></label>)}</div>}
        <div className="camera-form-group"><span className="camera-form-group-title">Thông tin thiết bị</span><label>Tên thiết bị<input autoFocus value={form.name} onChange={(event) => setForm({ ...form, name: event.target.value })} placeholder="VD: Đầu ghi kho hàng" /></label><label>Mã P2P / Serial Number <small>(chỉ bắt buộc khi chọn P2P)</small><div className="camera-serial-input"><input value={form.serialNumber} onChange={(event) => setForm({ ...form, serialNumber: event.target.value })} placeholder="LAN: có thể để trống · P2P: nhập S/N hoặc Cloud ID" /><button type="button" onClick={() => void scanQr()} title="Quét mã QR"><QrCode size={17} /></button></div></label><div className="camera-form-grid"><label>Tên đăng nhập<input value={form.username} onChange={(event) => setForm({ ...form, username: event.target.value })} placeholder="admin" /></label><label>Mật khẩu<input type="password" value={form.password} onChange={(event) => setForm({ ...form, password: event.target.value })} placeholder={editing ? "Để trống nếu không đổi" : "Mật khẩu kích hoạt đầu ghi"} /></label></div></div>
        <div className="camera-form-group"><span className="camera-form-group-title">Kết nối LAN</span><div className="camera-form-grid"><label>Địa chỉ LAN <input value={form.ipAddress || ""} onChange={(event) => setForm({ ...form, ipAddress: event.target.value })} placeholder="192.168.1.160" /></label><label>Hãng / adapter<select value={form.vendor || ""} onChange={(event) => setForm({ ...form, vendor: event.target.value })}><option value="hikvision">Hikvision</option><option value="dahua">Dahua / KBVision</option><option value="uniview">Uniview</option><option value="onvif">ONVIF</option><option value="">Tự nhận diện</option></select></label></div><div className="camera-form-grid"><label>Cổng SDK / thiết bị<input type="number" value={form.devicePort ?? 8000} onChange={(event) => setForm({ ...form, devicePort: Number(event.target.value) || 8000 })} /></label><label>Cổng HTTP <input type="number" value={form.httpPort ?? 80} onChange={(event) => setForm({ ...form, httpPort: Number(event.target.value) || 80 })} /></label></div><div className="camera-form-grid"><label>Cổng RTSP <input type="number" value={form.streamPort ?? 554} onChange={(event) => setForm({ ...form, streamPort: Number(event.target.value) || 554 })} /></label><label>Phương thức<select value={form.connectionMethod || "lan"} onChange={(event) => setForm({ ...form, connectionMethod: event.target.value })}><option value="lan">LAN / ONVIF</option><option value="auto">LAN trước, P2P sau</option><option value="p2p">P2P</option></select></label></div><label className="camera-auto-connect-form"><input type="checkbox" checked={form.autoConnect === true} onChange={(event) => setForm({ ...form, autoConnect: event.currentTarget.checked })} /><span><strong>Tự động kết nối</strong><small>Backend sẽ gửi lại yêu cầu kiểm tra tới Camera-Agent mỗi 1 phút khi đầu ghi chưa online.</small></span></label><div className="camera-auto-field"><span>Kết quả tự dò</span><strong>Ping, xác thực ISAPI/ONVIF, tổng kênh, kênh online và cổng RTSP</strong></div></div>
        <div className="camera-form-group"><span className="camera-form-group-title">Vị trí trên bản đồ</span><label>Gán vào mốc UBND xã/phường<select value={form.administrativeId ?? ""} onChange={(event) => setForm({ ...form, administrativeId: event.target.value || null })}><option value="">Điểm ngoài danh sách mốc UBND</option>{ubndPoints.map((point) => <option key={point.wardCode} value={point.wardCode}>{point.name}</option>)}</select></label>{form.administrativeId === null && <div className="camera-coordinates"><label>Kinh độ<input type="number" value={form.longitude ?? ""} onChange={(event) => setForm({ ...form, longitude: event.target.value ? Number(event.target.value) : null })} placeholder="106.68" /></label><label>Vĩ độ<input type="number" value={form.latitude ?? ""} onChange={(event) => setForm({ ...form, latitude: event.target.value ? Number(event.target.value) : null })} placeholder="20.86" /></label></div>}<small className="camera-help-text"><MapPin size={12} /> Camera được gán vào mốc UBND sẽ dùng đúng tọa độ điểm UBND trên lớp bản đồ. Camera ngoài danh sách cần có kinh độ và vĩ độ.</small></div>
        {message && <p className="camera-form-message">{message}</p>}<video ref={videoRef} hidden autoPlay muted playsInline />
      </div><footer><small>LAN/ONVIF cần IP; P2P cần S/N. Import/export dùng cùng các trường cấu hình ở form này.</small><button className="secondary-button" type="button" onClick={close}>Hủy</button><button className="primary-button" type="button" disabled={busy || !form.name.trim() || (String(form.connectionMethod || "lan").toLowerCase() === "p2p" ? !form.serialNumber.trim() : !String(form.ipAddress || "").trim()) || (!editing && !form.password.trim())} onClick={() => void save()}>{busy ? "Đang lưu…" : "Lưu thiết bị"}</button></footer>
    </section></div>}
  </section>;
}
