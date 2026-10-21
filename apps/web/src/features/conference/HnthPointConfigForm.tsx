import { useRef } from "react";
import { Cable, Download, Info, Network, Save, Upload, Zap } from "lucide-react";
import { HNTH_STATUS_LABELS, type HnthConnectionStatus } from "../layers/hnth-data-provider";
import { HnthDisconnectConfirmButton } from "./HnthDisconnectConfirmButton";
import type { DiscoveredIp, HnthPointFeature } from "./hnth-types";

type Field = { value: string; onChange: (value: string) => void };

/** Thẻ Cấu hình điểm: IP (chọn từ IP đã quét hoặc nhập tay), Gateway, Model, các thao tác và Import/Export. */
export function HnthPointConfigForm({ point, status, readOnly, discoveredIps, assignedIps, ipAddress, gateway, model, onSave, onTest, onShowInfo, onImport, onExport }: {
  point: HnthPointFeature;
  status: HnthConnectionStatus;
  readOnly: boolean;
  discoveredIps: DiscoveredIp[];
  /** IP đã gán cho điểm khác (không được chọn lại). */
  assignedIps: Set<string>;
  ipAddress: Field;
  gateway: Field;
  model: Field;
  onSave: (status?: HnthConnectionStatus) => void;
  onTest: () => void;
  onShowInfo: () => void;
  onImport: (file: File) => Promise<void>;
  onExport: () => void;
}) {
  const importInputRef = useRef<HTMLInputElement>(null);
  const pointName = String(point.properties?.name ?? "Điểm HNTH");
  return <div className="hnth-config-card">
    <div className="hnth-config-head"><span><Network size={15}/><b>Cấu hình điểm</b></span><i className={status}>{HNTH_STATUS_LABELS[status]}</i></div>
    <strong>{pointName}</strong>
    <label><span>Địa chỉ IP</span>
      <div className="hnth-ip-fields">
        <select disabled={readOnly} value={discoveredIps.some((item) => item.ipAddress === ipAddress.value) ? ipAddress.value : ""} onChange={(event) => {
          const value = event.target.value;
          const found = discoveredIps.find((item) => item.ipAddress === value);
          ipAddress.onChange(value);
          if (found?.model || found?.vendor) model.onChange(found.model || found.vendor || "");
        }}>
          <option value="">Chọn IP đã quét...</option>
          {discoveredIps.map((item) => <option value={item.ipAddress} key={item.ipAddress} disabled={assignedIps.has(item.ipAddress) && item.ipAddress !== ipAddress.value}>{item.ipAddress}{assignedIps.has(item.ipAddress) ? " — Đã gán" : ""}{item.model || item.vendor || item.modelVendor ? ` — ${item.model || item.vendor || item.modelVendor}` : item.macAddress ? ` — Vendor chưa xác định · MAC ${item.macAddress}` : " — Vendor chưa xác định"}</option>)}
        </select>
        <input disabled={readOnly} className="hnth-manual-ip" value={ipAddress.value} onChange={(event) => ipAddress.onChange(event.target.value)} placeholder="Hoặc nhập IP thủ công" />
        {discoveredIps.length > 0 ? <small className="hnth-live-hint">Đã nhận {discoveredIps.length} IP từ LAN agent</small> : <small className="hnth-live-hint">Chưa có IP từ agent — hãy Scan mạng LAN</small>}
      </div>
    </label>
    <label><span>Gateway</span><input disabled={readOnly} value={gateway.value} onChange={(event) => gateway.onChange(event.target.value)} /></label>
    <label><span>Model/Vendor</span><input disabled={readOnly} value={model.value} onChange={(event) => model.onChange(event.target.value)} placeholder="Ví dụ: Cisco / Webex Room Kit" /></label>
    <button className="hnth-save" disabled={readOnly} onClick={() => onSave()}><Save size={14}/> Lưu cấu hình IP</button>
    <div className="hnth-actions">
      <button className="connect" disabled={readOnly} onClick={() => onSave("connected")}><Cable size={14}/> Kết nối</button>
      <HnthDisconnectConfirmButton disabled={readOnly} pointName={pointName} onConfirm={() => { if (!readOnly) onSave("unconnected"); }} />
      <button disabled={readOnly} onClick={() => { if (!readOnly) onTest(); }}><Zap size={14}/> Test</button>
      <button disabled={readOnly} onClick={onShowInfo}><Info size={14}/> Thông tin</button>
    </div>
    <div className="hnth-import-export">
      <input ref={importInputRef} type="file" accept=".csv,.xlsx,text/csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" hidden onChange={(event) => {
        const file = event.target.files?.[0];
        // Xóa giá trị sau khi nhập xong để chọn lại cùng file vẫn kích hoạt onChange.
        if (file) void onImport(file).finally(() => { if (importInputRef.current) importInputRef.current.value = ""; });
      }} />
      <button type="button" disabled={readOnly} onClick={() => importInputRef.current?.click()} title="Nhập danh sách Tên điểm, IP, Gateway, Model/Vendor"><Upload size={14}/> Import</button>
      <button type="button" disabled={readOnly} onClick={onExport} title="Xuất danh sách Tên điểm, IP, Gateway, Model/Vendor"><Download size={14}/> Export</button>
    </div>
  </div>;
}
