import { useEffect, useMemo, useState } from "react";
import { createPortal } from "react-dom";
import { Database, Plus, Search, Trash2, X } from "lucide-react";
import type { HnthRosterPoint } from "../../core/realtime/hnth-live-store";
import { normalizeSearchText } from "./hnth-focus";
import { extraPointId, ROSTER_KIND_LABELS, rosterRowErrors, type RosterImportReport, type WardRef } from "./hnth-roster";

export type CatalogDraft = { points: HnthRosterPoint[]; report?: RosterImportReport };

const KIND_ORDER = { hub: 0, ward: 1, extra: 2 } as const;

/**
 * Popup rộng sửa dữ liệu chủ điểm cầu (mở khi Import hoặc bấm "Dữ liệu điểm cầu"): thêm/bớt
 * xã/phường và Sở/Ban/Ngành, sửa IP/Gateway/Model từng điểm. Tên xã/phường và Trung tâm cố định;
 * chỉ tên Sở/Ban/Ngành sửa được. Các danh sách phiên họp chọn điểm từ dữ liệu này.
 */
export function HnthCatalogEditor({ draft, wards, onSave, onClose }: {
  draft: CatalogDraft;
  wards: WardRef[];
  onSave: (points: HnthRosterPoint[]) => Promise<string | null>;
  onClose: () => void;
}) {
  const [points, setPoints] = useState<HnthRosterPoint[]>(() => [...draft.points].sort((a, b) => KIND_ORDER[a.kind] - KIND_ORDER[b.kind]));
  const [filter, setFilter] = useState("");
  // Dòng Sở/Ban/Ngành thêm mới trong popup: mã sinh lại theo tên khi lưu. Điểm có sẵn giữ mã
  // dù đổi tên, để các danh sách phiên họp đang chọn điểm đó không bị mất.
  const [newIds, setNewIds] = useState<Set<string>>(() => new Set());
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const errors = useMemo(() => rosterRowErrors(points), [points]);
  const missingWards = useMemo(() => {
    const present = new Set(points.map((point) => point.pointId));
    return wards.filter((ward) => !present.has(ward.pointId)).sort((a, b) => a.name.localeCompare(b.name, "vi"));
  }, [points, wards]);
  const counts = { ward: points.filter((point) => point.kind === "ward").length, hub: points.some((point) => point.kind === "hub"), extra: points.filter((point) => point.kind === "extra").length };
  const query = normalizeSearchText(filter);
  const visible = points.filter((point) => !query || normalizeSearchText(`${point.name} ${point.ipAddress}`).includes(query));

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => { if (event.key === "Escape" && !busy) onClose(); };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [busy, onClose]);

  const update = (pointId: string, patch: Partial<HnthRosterPoint>) => setPoints((current) => current.map((point) => point.pointId === pointId ? { ...point, ...patch } : point));
  const remove = (pointId: string) => setPoints((current) => current.filter((point) => point.pointId !== pointId));
  const addExtra = () => {
    const taken = new Set(points.map((point) => point.pointId));
    const label = `Sở/Ban/Ngành ${counts.extra + 1}`;
    const pointId = extraPointId(label, taken);
    setNewIds((current) => new Set(current).add(pointId));
    setPoints((current) => [...current, { pointId, kind: "extra", name: label, ipAddress: "", gateway: "", modelVendor: "" }]);
  };
  const addWards = (items: WardRef[]) => setPoints((current) => [...current, ...items.map((ward) => ({ pointId: ward.pointId, kind: "ward" as const, name: ward.name, ipAddress: "", gateway: "", modelVendor: "" }))].sort((a, b) => KIND_ORDER[a.kind] - KIND_ORDER[b.kind]));
  const addHub = () => setPoints((current) => [{ pointId: "hnth-hub", kind: "hub", name: "Trung tâm Chính trị - Hành chính", ipAddress: "", gateway: "", modelVendor: "" }, ...current]);

  const save = async () => {
    if (!points.length) { setError("Dữ liệu điểm cầu phải có ít nhất 1 điểm."); return; }
    if (errors.size) { setError("Còn dòng lỗi (tô đỏ), hãy sửa trước khi lưu."); return; }
    setBusy(true); setError("");
    const taken = new Set(points.filter((point) => !newIds.has(point.pointId)).map((point) => point.pointId));
    const normalized = points.map((point) => newIds.has(point.pointId) ? { ...point, name: point.name.trim(), pointId: extraPointId(point.name.trim(), taken) } : { ...point, name: point.name.trim() });
    const message = await onSave(normalized);
    setBusy(false);
    if (message) setError(message);
  };

  return createPortal(<div className="hnth-modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget && !busy) onClose(); }}>
    <section className="hnth-modal hnth-roster-editor" role="dialog" aria-modal="true" aria-label="Dữ liệu điểm cầu">
      <header><span><Database size={17}/><strong>{draft.report ? "Import dữ liệu điểm cầu" : "Dữ liệu điểm cầu"}</strong></span><button onClick={onClose} disabled={busy} aria-label="Đóng"><X size={18}/></button></header>
      <div className="hnth-roster-editor-body">
        <p className="hnth-roster-summary">
          <b>{points.length}</b> điểm: {counts.hub ? "Trung tâm · " : "chưa có Trung tâm · "}{counts.ward} xã/phường · {counts.extra} Sở/Ban/Ngành
          {missingWards.length > 0 && <> · <em>{missingWards.length} xã/phường không có trong dữ liệu</em></>}
        </p>
        {draft.report && <p className="hnth-roster-report">
          Đã đọc file: {draft.report.hub ? "có điểm Trung tâm, " : "không có điểm Trung tâm, "}{draft.report.wards} xã/phường khớp, {draft.report.extras.length} Sở/Ban/Ngành mới
          {draft.report.duplicates.length > 0 && <>; bỏ {draft.report.duplicates.length} dòng trùng ({draft.report.duplicates.slice(0, 5).join(", ")}{draft.report.duplicates.length > 5 ? "…" : ""})</>}.
        </p>}
        <div className="hnth-roster-tools">
          <label className="hnth-roster-filter"><Search size={14}/><input value={filter} onChange={(event) => setFilter(event.target.value)} placeholder="Lọc theo tên hoặc IP" /></label>
          <button type="button" onClick={addExtra}><Plus size={14}/> Sở/Ban/Ngành</button>
          {!counts.hub && <button type="button" onClick={addHub}><Plus size={14}/> Trung tâm</button>}
          {missingWards.length > 0 && <select value="" onChange={(event) => { const ward = missingWards.find((item) => item.pointId === event.target.value); if (ward) addWards([ward]); }}>
            <option value="">+ Thêm xã/phường…</option>
            {missingWards.map((ward) => <option key={ward.pointId} value={ward.pointId}>{ward.name}</option>)}
          </select>}
          {missingWards.length > 0 && <button type="button" onClick={() => addWards(missingWards)}>Thêm đủ {missingWards.length} xã/phường</button>}
        </div>
        <div className="hnth-roster-table-wrap">
          <table className="hnth-roster-table">
            <thead><tr><th>#</th><th>Loại</th><th>Tên điểm</th><th>IP</th><th>Gateway</th><th>Model/Vendor</th><th aria-label="Xóa"/></tr></thead>
            <tbody>
              {visible.map((point) => {
                const rowError = errors.get(point.pointId);
                return <tr key={point.pointId} className={rowError ? "has-error" : undefined} title={rowError}>
                  <td>{points.indexOf(point) + 1}</td>
                  <td><span className={`hnth-roster-kind ${point.kind}`}>{ROSTER_KIND_LABELS[point.kind]}</span></td>
                  <td>{point.kind === "extra" ? <input value={point.name} onChange={(event) => update(point.pointId, { name: event.target.value })} /> : <span className="hnth-roster-fixed-name">{point.name}</span>}</td>
                  <td><input value={point.ipAddress} onChange={(event) => update(point.pointId, { ipAddress: event.target.value })} placeholder="Chưa có IP" spellCheck={false} /></td>
                  <td><input value={point.gateway ?? ""} onChange={(event) => update(point.pointId, { gateway: event.target.value })} spellCheck={false} /></td>
                  <td><input value={point.modelVendor ?? ""} onChange={(event) => update(point.pointId, { modelVendor: event.target.value })} /></td>
                  <td><button type="button" className="icon-button" onClick={() => remove(point.pointId)} title="Xóa điểm khỏi dữ liệu"><Trash2 size={14}/></button></td>
                </tr>;
              })}
              {!visible.length && <tr><td colSpan={7} className="hnth-roster-empty">Không có điểm phù hợp.</td></tr>}
            </tbody>
          </table>
        </div>
        {error && <div className="hnth-roster-error" role="alert">{error}</div>}
        <footer>
          <small>Đây là dữ liệu chủ: các danh sách phiên họp chọn điểm từ đây. Lưu sẽ thay toàn bộ dữ liệu cũ; điểm bị bỏ cũng bị bỏ khỏi các danh sách.</small>
          <button className="secondary-button" type="button" onClick={onClose} disabled={busy}>Hủy</button>
          <button className="primary-button" type="button" onClick={() => void save()} disabled={busy}>{busy ? "Đang lưu…" : "Lưu dữ liệu"}</button>
        </footer>
      </div>
    </section>
  </div>, document.body);
}
