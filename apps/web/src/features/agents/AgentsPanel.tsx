import { useCallback, useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { Activity, Check, KeyRound, Network, Pencil, RadioTower, RefreshCw, Settings2, Trash2, Wifi, WifiOff, X } from "lucide-react";
import { compareVersions, EXE_VERSION_SCAN_BYTES, readExeVersion as readExeVersionBytes } from "@haiphong-ops/hnth-protocol";
import { agentsApi } from "../../core/api/clients";
import { emitAppEvent } from "../../core/events";

type SnmpTarget = { targetId?: string; host?: string; port?: number; community?: string; version?: string; oids?: string[] };
type Agent = {
  agentId: string; name: string; status: string; lastSeenAt?: string | null; version?: string | null; heartbeatSeconds?: number;
  lastUpdate?: { version: string; status: "success" | "failed"; detail?: string | null; reportedAt: string } | null;
  monitorConfig?: { scanConcurrency?: number; scanDelayMs?: number; scanScheduleSeconds?: number; probeCount?: number; probeIntervalMs?: number; snmpTargets?: SnmpTarget[] };
};

// Đọc version ngay khi chọn file, cùng thuật toán backend dùng khi nhận upload.
export async function readExeVersion(file: File): Promise<string | null> {
  return readExeVersionBytes(new Uint8Array(await file.slice(0, EXE_VERSION_SCAN_BYTES).arrayBuffer()));
}

// Chỉ dùng để hiện thông báo hạ cấp/cài lại, không chặn thao tác.
export { compareVersions };

export function AgentsPanel() {
  const [agents, setAgents] = useState<Agent[]>([]);
  const [editing, setEditing] = useState<Agent | null>(null);
  const [advanced, setAdvanced] = useState(false);
  const [name, setName] = useState("");
  const [tokenDraft, setTokenDraft] = useState("");
  const [tokenBusy, setTokenBusy] = useState(false);
  const [tokenMessage, setTokenMessage] = useState("");
  const [heartbeatSeconds, setHeartbeatSeconds] = useState(30);
  const [scanConcurrency, setScanConcurrency] = useState(32);
  const [scanDelayMs, setScanDelayMs] = useState(0);
  const [scanScheduleSeconds, setScanScheduleSeconds] = useState(0);
  const [probeCount, setProbeCount] = useState(4);
  const [probeIntervalMs, setProbeIntervalMs] = useState(250);
  const [snmpTargetsText, setSnmpTargetsText] = useState("[]");
  const [releaseVersion, setReleaseVersion] = useState("");
  const [releaseFile, setReleaseFile] = useState<File | null>(null);
  const [releaseBusy, setReleaseBusy] = useState(false);
  const [releaseMessage, setReleaseMessage] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [requiresLogin, setRequiresLogin] = useState(false);

  const load = useCallback(async () => {
    const controller = new AbortController();
    const timeout = window.setTimeout(() => controller.abort(), 8000);
    setLoading(true); setError(""); setRequiresLogin(false);
    try {
      const response = await agentsApi.list({ signal: controller.signal });
      if (response.status === 401 || response.status === 403) { setRequiresLogin(true); setError("Cần đăng nhập bằng tài khoản Operator hoặc Admin để quản lý Agent."); return; }
      if (!response.ok) { const payload = await response.json().catch(() => ({})) as { error?: string }; throw new Error(payload.error || `Backend trả về HTTP ${response.status}`); }
      const payload = await response.json() as unknown;
      if (!Array.isArray(payload)) throw new Error("Backend trả về danh sách Agent không hợp lệ.");
      setAgents(payload as Agent[]);
    } catch (loadError) {
      if (loadError instanceof DOMException && loadError.name === "AbortError") setError("Không nhận được phản hồi từ Backend sau 8 giây.");
      else setError(loadError instanceof Error ? loadError.message : "Không tải được danh sách Agent.");
    } finally { window.clearTimeout(timeout); setLoading(false); }
  }, []);

  useEffect(() => { void load(); const timer = window.setInterval(() => void load(), 10000); return () => window.clearInterval(timer); }, [load]);

  const removeAgent = async (agent: Agent) => {
    if (agent.status === "online") { setError(`Agent "${agent.name}" đang online. Tắt Agent trên máy trước khi xóa, nếu không nó sẽ tự đăng ký lại.`); return; }
    if (!window.confirm(`Xóa Agent "${agent.name}" (${agent.agentId}) khỏi danh sách?
Lịch sử log giám sát vẫn được giữ lại.`)) return;
    setError("");
    try {
      const response = await agentsApi.remove(agent.agentId);
      if (response.status === 401 || response.status === 403) { setRequiresLogin(true); setError("Chỉ tài khoản Admin được xóa Agent."); return; }
      if (!response.ok && response.status !== 404) { const payload = await response.json().catch(() => ({})) as { error?: string }; throw new Error(payload.error || `Không xóa được Agent (HTTP ${response.status})`); }
      await load();
    } catch (removeError) { setError(removeError instanceof Error ? removeError.message : "Không xóa được Agent."); }
  };

  const openEditor = (agent: Agent) => {
    const cfg = agent.monitorConfig || {};
    setEditing(agent); setAdvanced(false); setError(""); setName(agent.name); setTokenDraft(""); setTokenMessage(""); setTokenBusy(false);
    setHeartbeatSeconds(agent.heartbeatSeconds || 30); setProbeCount(cfg.probeCount || 4); setProbeIntervalMs(cfg.probeIntervalMs || 250);
    setScanConcurrency(cfg.scanConcurrency || 32); setScanDelayMs(cfg.scanDelayMs || 0); setScanScheduleSeconds(cfg.scanScheduleSeconds || 0);
    setSnmpTargetsText(JSON.stringify(cfg.snmpTargets || [], null, 2));
    setReleaseVersion(""); setReleaseFile(null); setReleaseBusy(false); setReleaseMessage("");
  };

  const generateToken = () => {
    const bytes = new Uint8Array(32);
    crypto.getRandomValues(bytes);
    setTokenDraft(Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join(""));
    setTokenMessage("Đã tạo token mới trong ô nhập. Bấm Đổi để áp dụng cho Agent.");
  };

  const changeToken = async () => {
    if (!editing || !tokenDraft.trim()) { setTokenMessage("Hãy tạo hoặc nhập token trước khi đổi."); return; }
    setTokenBusy(true); setTokenMessage("");
    try {
      const response = await agentsApi.setToken(editing.agentId, tokenDraft.trim());
      const payload = await response.json().catch(() => ({})) as { error?: string };
      if (response.status === 401 || response.status === 403) { setRequiresLogin(true); throw new Error("Phiên đăng nhập không có quyền đổi token Agent."); }
      if (!response.ok) throw new Error(payload.error || `Không gửi được token mới (HTTP ${response.status})`);
      setTokenDraft("");
      setTokenMessage("Đã gửi lệnh đổi token. Agent sẽ nhận token mới ở heartbeat kế tiếp.");
    } catch (tokenError) { setTokenMessage(tokenError instanceof Error ? tokenError.message : "Đổi token thất bại."); }
    finally { setTokenBusy(false); }
  };

  const selectReleaseFile = async (file: File | null) => {
    setReleaseFile(file); setReleaseVersion(""); setReleaseMessage("");
    if (!file) return;
    if (!file.name.toLowerCase().endsWith(".exe")) { setReleaseMessage("Chỉ chấp nhận file Agent dạng .exe."); return; }
    const version = await readExeVersion(file).catch(() => null);
    if (!version) { setReleaseMessage("Không đọc được version trong file này. Hãy chọn file Agent build bằng electron-builder."); return; }
    setReleaseVersion(version);
    // Cho phép cả hạ cấp và cài lại đúng bản đang chạy: chỉ thông báo, không chặn.
    if (editing?.version === version) setReleaseMessage(`Agent đang chạy bản ${version}; bấm Cập nhật để cài lại đúng bản này.`);
    else if (editing?.version && compareVersions(version, editing.version) < 0) setReleaseMessage(`Bản ${version} cũ hơn bản đang chạy (${editing.version}); bấm Cập nhật để hạ cấp.`);
  };

  const deployUpdate = async () => {
    if (!editing || !releaseFile || !releaseVersion) { setReleaseMessage("Chọn file Agent .exe hợp lệ trước khi cập nhật."); return; }
    setReleaseBusy(true); setReleaseMessage("");
    try {
      const upload = await agentsApi.uploadRelease(releaseFile, { version: releaseVersion, fileName: releaseFile.name });
      const uploaded = await upload.json().catch(() => ({})) as { version?: string; sha256?: string; error?: string };
      if (!upload.ok || !uploaded.sha256) throw new Error(uploaded.error || `Không tải được bản cập nhật (HTTP ${upload.status})`);
      // Backend tự điền đường dẫn tải và SHA-256 từ bản release vừa lưu; Agent ghép
      // đường dẫn đó với backendUrl của chính nó nên không phụ thuộc địa chỉ trình duyệt.
      const command = await agentsApi.sendCommand(editing.agentId, { type: "agent-update", version: uploaded.version || releaseVersion });
      const payload = await command.json().catch(() => ({})) as { error?: string };
      if (!command.ok) throw new Error(payload.error || `Không gửi được lệnh cập nhật (HTTP ${command.status})`);
      setReleaseMessage(`Đã gửi bản ${uploaded.version || releaseVersion} cho Agent. Agent sẽ tự thoát, cập nhật và khởi động lại; phiên bản mới hiện ở đây sau khoảng 1 phút.`);
      setReleaseFile(null);
    } catch (updateError) { setReleaseMessage(updateError instanceof Error ? updateError.message : "Cập nhật Agent thất bại."); }
    finally { setReleaseBusy(false); }
  };

  const save = async () => {
    if (!editing) return;
    let snmpTargets: SnmpTarget[] = [];
    try {
      const parsed = JSON.parse(snmpTargetsText || "[]") as unknown;
      if (!Array.isArray(parsed)) throw new Error("SNMP targets phải là một mảng JSON.");
      snmpTargets = parsed as SnmpTarget[];
    } catch (parseError) { setError(parseError instanceof Error ? parseError.message : "Cấu hình SNMP không hợp lệ."); setAdvanced(true); return; }
    setError("");
    try {
      const response = await agentsApi.update(editing.agentId, { name, heartbeatSeconds, monitorConfig: { scanConcurrency, scanDelayMs, scanScheduleSeconds, probeCount, probeIntervalMs, snmpTargets } });
      if (response.status === 401 || response.status === 403) { setRequiresLogin(true); setError("Phiên đăng nhập không có quyền cập nhật Agent."); return; }
      if (!response.ok) { const payload = await response.json().catch(() => ({})) as { error?: string }; throw new Error(payload.error || `Không lưu được Agent (HTTP ${response.status})`); }
      setEditing(null); await load();
    } catch (saveError) { setError(saveError instanceof Error ? saveError.message : "Không lưu được cấu hình Agent."); }
  };

  return <section className="panel-section agents-panel">
    <div className="section-heading"><div><span className="eyebrow">HẠ TẦNG KẾT NỐI</span><h2>Agents</h2><span className="count-chip">{agents.length} agent</span></div></div>
    <p className="panel-help">Quản lý các Agent đang kết nối từ những mạng LAN khác nhau. Tên Agent sẽ xuất hiện khi chọn nguồn Scan trong menu HNTH.</p>
    <div className="agent-list" aria-busy={loading}>
      {loading && <div className="hnth-loading"><RadioTower size={20}/><span>Đang tải danh sách Agent...</span></div>}
      {error && !editing && <div className="agent-error"><span>{error}</span><div className="agent-error-actions"><button className="secondary-button" onClick={() => void load()}>Thử lại</button>{requiresLogin && <button className="primary-button" onClick={() => emitAppEvent("hnth:open-login")}>Đăng nhập</button>}</div></div>}
      {!loading && !error && agents.length === 0 && <div className="hnth-loading"><RadioTower size={20}/><span>Chưa có Agent đăng ký</span></div>}
      {agents.map((agent) => <article className="agent-card" key={agent.agentId}>
        <div className="agent-status">{agent.status === "online" ? <Wifi size={17}/> : <WifiOff size={17}/>}</div>
        <div className="agent-info"><strong>{agent.name}</strong><small>{agent.agentId}</small><em className={agent.status}>{agent.status === "online" ? "Đang online" : "Offline"}{agent.lastSeenAt ? ` · ${new Date(agent.lastSeenAt).toLocaleString("vi-VN")}` : ""} · Heartbeat {agent.heartbeatSeconds || 30}s{agent.version ? ` · v${agent.version}` : ""}</em></div>
        <button className="icon-button" onClick={() => openEditor(agent)} title="Đổi tên và cấu hình Agent"><Pencil size={15}/></button>
        <button className="icon-button agent-delete-button" onClick={() => void removeAgent(agent)} disabled={agent.status === "online"} title={agent.status === "online" ? "Agent đang online — tắt Agent trước khi xóa" : "Xóa Agent khỏi danh sách"} aria-label={`Xóa Agent ${agent.name}`}><Trash2 size={15}/></button>
      </article>)}
    </div>
    {/* Portal ra body: .side-panel có z-index tạo stacking context, modal để bên trong sẽ nằm dưới các popup trên bản đồ. */}
    {editing && createPortal(<div className="hnth-modal-backdrop agent-modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) setEditing(null); }}>
      <section className="hnth-modal agent-config-modal" role="dialog" aria-modal="true" aria-label={`Cấu hình Agent ${editing.name}`}>
        <header><span><Settings2 size={17}/><strong>Cấu hình Agent</strong></span><button onClick={() => setEditing(null)} aria-label="Đóng cửa sổ"><X size={18}/></button></header>
        <div className="agent-modal-content">
          <div className="agent-modal-identity"><div className="agent-status">{editing.status === "online" ? <Wifi size={22}/> : <WifiOff size={22}/>}</div><div><strong>{editing.agentId}</strong><small>{editing.status === "online" ? "Đang online" : "Offline"} · Phiên bản {editing.version || "chưa báo"}</small></div></div>
          <div className="agent-form-grid"><label>Tên hiển thị<input value={name} onChange={(event) => setName(event.target.value)} autoFocus /></label><label>Heartbeat (giây)<input type="number" min="5" max="30" value={heartbeatSeconds} onChange={(event) => setHeartbeatSeconds(Number(event.target.value))} /></label></div>
          <button className="agent-advanced-toggle" type="button" onClick={() => setAdvanced((value) => !value)}><Settings2 size={15}/><span>Cấu hình nâng cao</span><strong>{advanced ? "Thu gọn" : "Mở rộng"}</strong></button>
          {advanced && <div className="agent-advanced-content">
            <section className="agent-config-group agent-token-group"><h3><KeyRound size={16}/>Token Agent</h3><div className="agent-token-row"><input type="text" value={tokenDraft} onChange={(event) => setTokenDraft(event.target.value)} placeholder="Tạo hoặc nhập token mới" autoComplete="off" spellCheck={false} /><button type="button" onClick={generateToken} disabled={tokenBusy}>Tạo</button><button type="button" onClick={() => void changeToken()} disabled={tokenBusy || !tokenDraft.trim()}>Đổi</button></div><p>“Tạo” chỉ điền token vào ô nhập. Chỉ nút “Đổi” mới gửi token xuống Agent.</p>{tokenMessage && <p className="agent-token-message">{tokenMessage}</p>}</section>
            <section className="agent-config-group"><h3><Activity size={16}/>Giám sát mạng</h3><div className="agent-form-grid agent-form-grid-3"><label>Số ping mỗi điểm<input type="number" min="1" max="10" value={probeCount} onChange={(event) => setProbeCount(Number(event.target.value))} /></label><label>Khoảng cách ping (ms)<input type="number" min="0" value={probeIntervalMs} onChange={(event) => setProbeIntervalMs(Number(event.target.value))} /></label><label>Song song khi scan<input type="number" min="1" max="128" value={scanConcurrency} onChange={(event) => setScanConcurrency(Number(event.target.value))} /></label><label>Nghỉ giữa batch (ms)<input type="number" min="0" value={scanDelayMs} onChange={(event) => setScanDelayMs(Number(event.target.value))} /></label><label>Lịch scan (giây, 0=tắt)<input type="number" min="0" value={scanScheduleSeconds} onChange={(event) => setScanScheduleSeconds(Number(event.target.value))} /></label></div><p>Agent sẽ gửi latency, packet loss và jitter về Backend sau mỗi vòng kiểm tra.</p></section>
            <section className="agent-config-group"><h3><Network size={16}/>SNMP v2c</h3><p>Khai báo dạng JSON. Mỗi target gồm host, port, community, version và danh sách OID.</p><textarea value={snmpTargetsText} onChange={(event) => setSnmpTargetsText(event.target.value)} spellCheck={false} rows={8} placeholder={'[{"targetId":"switch-core","host":"10.0.0.1","port":161,"community":"readonly","version":"2c","oids":["1.3.6.1.2.1.1.3.0"]}]'} /></section>
            <section className="agent-config-group agent-version-group"><h3><RefreshCw size={16}/>Phiên bản & cập nhật</h3><div><span>Phiên bản hiện tại</span><strong>{editing.version || "Chưa báo phiên bản"}</strong></div><div className="agent-update-fields"><label>File Agent (.exe)<input type="file" accept=".exe,application/vnd.microsoft.portable-executable" onChange={(event) => void selectReleaseFile(event.target.files?.[0] || null)} /></label><div><span>Version trong file</span><strong>{releaseVersion || "—"}</strong></div><button className="primary-button" type="button" disabled={releaseBusy || !releaseVersion} onClick={() => void deployUpdate()}><RefreshCw size={15}/> {releaseBusy ? "Đang cập nhật…" : "Cập nhật"}</button></div>{releaseMessage && <p className="agent-update-message">{releaseMessage}</p>}{editing.lastUpdate && <p className="agent-update-message">Lần cập nhật gần nhất ({new Date(editing.lastUpdate.reportedAt).toLocaleString("vi-VN")}): bản {editing.lastUpdate.version} — {editing.lastUpdate.status === "success" ? "thành công" : `thất bại: ${editing.lastUpdate.detail || "không rõ lý do"}`}</p>}<p>Chỉ khi bấm “Cập nhật”, Backend mới phát hành file và gửi lệnh cập nhật cho Agent. Agent xác minh SHA-256 trước khi thay thế file đang chạy.</p></section>
          </div>}
          {error && <div className="agent-modal-error">{error}</div>}
          <footer><button className="secondary-button" onClick={() => setEditing(null)}>Hủy</button><button className="primary-button" onClick={() => void save()}><Check size={15}/>Lưu cấu hình</button></footer>
        </div>
      </section>
    </div>, document.body)}
  </section>;
}
