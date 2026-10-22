import { useEffect, useMemo, useState } from "react";
import { createPortal } from "react-dom";
import { ListChecks, Search, X } from "lucide-react";
import type { HnthRosterPoint, HnthRosterPointKind } from "../../core/realtime/hnth-live-store";
import { normalizeSearchText } from "./hnth-focus";
import { ROSTER_KIND_LABELS } from "./hnth-roster";

export type RosterDraft = { id: string | null; name: string; pointIds: string[] };

const KINDS: HnthRosterPointKind[] = ["hub", "ward", "extra"];

/**
 * Popup rộng sửa một danh sách phiên họp: đặt/sửa tên và đánh dấu các điểm cầu lấy từ dữ liệu
 * chủ. Agent chỉ ping các điểm được chọn ở danh sách đang áp dụng.
 */
export function HnthRosterEditor({ draft, catalog, onSave, onClose }: {
  draft: RosterDraft;
  catalog: HnthRosterPoint[];
  onSave: (draft: RosterDraft, apply: boolean) => Promise<string | null>;
  onClose: () => void;
}) {
  const [name, setName] = useState(draft.name);
  const [selected, setSelected] = useState(() => new Set(draft.pointIds.filter((id) => catalog.some((point) => point.pointId === id))));
  const [filter, setFilter] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const query = normalizeSearchText(filter);
  const visible = useMemo(() => catalog.filter((point) => !query || normalizeSearchText(`${point.name} ${point.ipAddress}`).includes(query)), [catalog, query]);

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => { if (event.key === "Escape" && !busy) onClose(); };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [busy, onClose]);

  const toggle = (pointId: string) => setSelected((current) => {
    const next = new Set(current);
    if (next.has(pointId)) next.delete(pointId); else next.add(pointId);
    return next;
  });
  // Chọn/bỏ cả nhóm theo các dòng đang hiển thị (tôn trọng ô lọc).
  const setGroup = (kind: HnthRosterPointKind | "all", value: boolean) => setSelected((current) => {
    const next = new Set(current);
    for (const point of visible) if (kind === "all" || point.kind === kind) { if (value) next.add(point.pointId); else next.delete(point.pointId); }
    return next;
  });
  const countOf = (kind: HnthRosterPointKind) => catalog.filter((point) => point.kind === kind && selected.has(point.pointId)).length;
  const totalOf = (kind: HnthRosterPointKind) => catalog.filter((point) => point.kind === kind).length;
  const withoutIp = catalog.filter((point) => selected.has(point.pointId) && !point.ipAddress.trim()).length;

  const save = async (apply: boolean) => {
    if (!name.trim()) { setError("Hãy đặt tên cho danh sách."); return; }
    if (!selected.size) { setError("Hãy chọn ít nhất 1 điểm cầu."); return; }
    setBusy(true); setError("");
    // Giữ thứ tự theo dữ liệu chủ.
    const message = await onSave({ ...draft, name: name.trim(), pointIds: catalog.filter((point) => selected.has(point.pointId)).map((point) => point.pointId) }, apply);
    setBusy(false);
    if (message) setError(message);
  };

  return createPortal(<div className="hnth-modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget && !busy) onClose(); }}>
    <section className="hnth-modal hnth-roster-editor" role="dialog" aria-modal="true" aria-label="Danh sách phiên họp">
      <header><span><ListChecks size={17}/><strong>{draft.id ? "Sửa danh sách phiên họp" : "Danh sách phiên họp mới"}</strong></span><button onClick={onClose} disabled={busy} aria-label="Đóng"><X size={18}/></button></header>
      <div className="hnth-roster-editor-body">
        <label className="hnth-roster-name">Tên danh sách<input value={name} onChange={(event) => setName(event.target.value)} placeholder="Ví dụ: Họp toàn TP, Họp khối Sở" autoFocus /></label>
        <p className="hnth-roster-summary">
          Đã chọn <b>{selected.size}</b>/{catalog.length} điểm: {KINDS.map((kind) => `${countOf(kind)}/${totalOf(kind)} ${ROSTER_KIND_LABELS[kind].toLowerCase()}`).join(" · ")}
          {withoutIp > 0 && <> · <em>{withoutIp} điểm chưa có IP (không ping)</em></>}
        </p>
        <div className="hnth-roster-tools">
          <label className="hnth-roster-filter"><Search size={14}/><input value={filter} onChange={(event) => setFilter(event.target.value)} placeholder="Lọc theo tên hoặc IP" /></label>
          <button type="button" onClick={() => setGroup("all", true)}>Chọn tất cả</button>
          <button type="button" onClick={() => setGroup("all", false)}>Bỏ chọn tất cả</button>
          <button type="button" onClick={() => setGroup("ward", true)}>+ Xã/phường</button>
          <button type="button" onClick={() => setGroup("extra", true)}>+ Sở/Ban/Ngành</button>
        </div>
        <div className="hnth-roster-table-wrap">
          <table className="hnth-roster-table is-select">
            <thead><tr><th aria-label="Chọn"/><th>Loại</th><th>Tên điểm</th><th>IP</th></tr></thead>
            <tbody>
              {visible.map((point) => <tr key={point.pointId} className={selected.has(point.pointId) ? "is-checked" : undefined} onClick={() => toggle(point.pointId)}>
                <td><input type="checkbox" checked={selected.has(point.pointId)} onChange={() => toggle(point.pointId)} onClick={(event) => event.stopPropagation()} aria-label={`Chọn ${point.name}`} /></td>
                <td><span className={`hnth-roster-kind ${point.kind}`}>{ROSTER_KIND_LABELS[point.kind]}</span></td>
                <td>{point.name}</td>
                <td className="hnth-roster-ip">{point.ipAddress || "Chưa có IP"}</td>
              </tr>)}
              {!visible.length && <tr><td colSpan={4} className="hnth-roster-empty">Không có điểm phù hợp.</td></tr>}
            </tbody>
          </table>
        </div>
        {error && <div className="hnth-roster-error" role="alert">{error}</div>}
        <footer>
          <small>Agent chỉ ping các điểm được chọn của danh sách đang áp dụng. Xã/phường không được chọn sẽ không hiển thị, không đếm.</small>
          <button className="secondary-button" type="button" onClick={onClose} disabled={busy}>Hủy</button>
          <button className="secondary-button" type="button" onClick={() => void save(false)} disabled={busy}>Lưu</button>
          <button className="primary-button" type="button" onClick={() => void save(true)} disabled={busy}>{busy ? "Đang lưu…" : "Lưu & áp dụng"}</button>
        </footer>
      </div>
    </section>
  </div>, document.body);
}
