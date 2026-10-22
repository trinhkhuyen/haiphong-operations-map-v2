import { useCallback, useEffect, useState } from "react";
import { Database, ListChecks, Pencil, Plus, Trash2 } from "lucide-react";
import { hnthCatalogApi, rostersApi } from "../../core/api/clients";
import { useHnthLiveStore, type HnthRosterPoint } from "../../core/realtime/hnth-live-store";
import { HnthCatalogEditor, type CatalogDraft } from "./HnthCatalogEditor";
import { HnthRosterEditor, type RosterDraft } from "./HnthRosterEditor";
import type { WardRef } from "./hnth-roster";

type RosterSummary = { id: string; name: string; pointCount: number; updatedAt?: string };
const errorOf = async (response: Response, fallback: string) => ((await response.json().catch(() => ({}))) as { error?: string }).error || `${fallback} (HTTP ${response.status})`;

/**
 * Dưới Import/Export: chọn danh sách phiên họp đang áp dụng, sửa/tạo danh sách (chọn điểm từ
 * dữ liệu chủ) và mở dữ liệu chủ điểm cầu. `catalogDraft` do HnthPanel đặt khi Import file.
 * `fallbackCatalog` = 115 điểm mặc định khi chưa từng Import. `onApplied(points)` để HnthPanel
 * gửi lại lệnh Giám sát liên tục theo điểm của phiên mới (null = 115 điểm mặc định).
 */
export function HnthRosterControl({ readOnly, wards, fallbackCatalog, catalogDraft, setCatalogDraft, onApplied }: {
  readOnly: boolean;
  wards: WardRef[];
  fallbackCatalog: HnthRosterPoint[];
  catalogDraft: CatalogDraft | null;
  setCatalogDraft: (draft: CatalogDraft | null) => void;
  onApplied: (points: HnthRosterPoint[] | null) => Promise<void>;
}) {
  const [rosters, setRosters] = useState<RosterSummary[]>([]);
  const [rosterDraft, setRosterDraft] = useState<RosterDraft | null>(null);
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);
  const catalog = useHnthLiveStore((state) => state.catalog);
  const activeRoster = useHnthLiveStore((state) => state.activeRoster);
  const monitoring = useHnthLiveStore((state) => state.monitoring.enabled);
  const activeId = activeRoster?.id ?? "default";
  const catalogPoints = catalog?.points.length ? catalog.points : fallbackCatalog;

  const load = useCallback(async () => {
    try {
      const response = await rostersApi.list();
      if (response.ok) setRosters(((await response.json()) as { rosters: RosterSummary[] }).rosters);
    } catch { /* backend chưa sẵn sàng */ }
  }, []);
  useEffect(() => { if (!readOnly) void load(); }, [load, readOnly, activeRoster?.updatedAt, catalog?.updatedAt]);

  const activate = async (id: string, skipConfirm = false) => {
    const label = id === "default" ? "Tất cả điểm cầu" : rosters.find((item) => item.id === id)?.name ?? "";
    if (monitoring && !skipConfirm && !window.confirm(`Đang Giám sát liên tục. Áp dụng danh sách "${label}" sẽ bắt đầu lại giám sát theo danh sách mới. Tiếp tục?`)) return;
    setBusy(true); setMessage("");
    try {
      const response = await rostersApi.activate(id);
      if (!response.ok) throw new Error(await errorOf(response, "Không áp dụng được danh sách"));
      const result = await response.json() as { monitoring: boolean; points: HnthRosterPoint[] | null };
      if (result.monitoring) await onApplied(result.points);
    } catch (error) { setMessage(error instanceof Error ? error.message : "Không áp dụng được danh sách"); }
    finally { setBusy(false); }
  };

  // Chưa từng Import: lưu 115 điểm mặc định làm dữ liệu chủ trước khi tạo danh sách đầu tiên.
  const ensureCatalog = async () => {
    if (catalog?.points.length) return null;
    const response = await hnthCatalogApi.save(fallbackCatalog);
    return response.ok ? null : await errorOf(response, "Không lưu được dữ liệu điểm cầu");
  };

  const editActive = async () => {
    setMessage("");
    const response = await rostersApi.get(activeId);
    if (!response.ok) { setMessage(await errorOf(response, "Không đọc được danh sách")); return; }
    const roster = await response.json() as { id: string; name: string; pointIds: string[] };
    setRosterDraft({ id: roster.id, name: roster.name, pointIds: roster.pointIds });
  };

  const deleteRoster = async (id: string) => {
    const target = rosters.find((item) => item.id === id);
    if (!target || !window.confirm(`Xóa danh sách "${target.name}"?`)) return;
    const response = await rostersApi.remove(id);
    if (!response.ok) setMessage(await errorOf(response, "Không xóa được danh sách"));
    await load();
  };

  const saveRoster = async (next: RosterDraft, apply: boolean): Promise<string | null> => {
    try {
      const catalogError = await ensureCatalog();
      if (catalogError) return catalogError;
      const body = { name: next.name, pointIds: next.pointIds };
      const response = next.id ? await rostersApi.update(next.id, body) : await rostersApi.create(body);
      if (!response.ok) return await errorOf(response, "Không lưu được danh sách");
      const saved = await response.json() as { id: string };
      await load();
      setRosterDraft(null);
      // Sửa đúng danh sách đang áp dụng: backend đã đồng bộ Agent; giám sát cần chạy lại theo điểm mới.
      if (next.id && next.id === activeId) {
        if (monitoring) await onApplied(catalogPoints.filter((point) => next.pointIds.includes(point.pointId)));
      } else if (apply) await activate(saved.id);
      return null;
    } catch (error) { return error instanceof Error ? error.message : "Không lưu được danh sách"; }
  };

  const saveCatalog = async (points: HnthRosterPoint[]): Promise<string | null> => {
    try {
      const response = await hnthCatalogApi.save(points);
      if (!response.ok) return await errorOf(response, "Không lưu được dữ liệu điểm cầu");
      const result = await response.json() as { pointCount: number; prunedRosters: string[] };
      setCatalogDraft(null);
      setMessage(result.prunedRosters.length ? `Đã lưu ${result.pointCount} điểm. Các danh sách bị bỏ bớt điểm không còn trong dữ liệu: ${result.prunedRosters.join(", ")}.` : "");
      await load();
      // Dữ liệu chủ đổi IP/điểm: giám sát chạy lại theo điểm của phiên hiện tại.
      if (monitoring) {
        const ids = activeRoster ? new Set(activeRoster.pointIds) : null;
        await onApplied(points.filter((point) => !ids || ids.has(point.pointId)));
      }
      return null;
    } catch (error) { return error instanceof Error ? error.message : "Không lưu được dữ liệu điểm cầu"; }
  };

  if (readOnly) return null;
  return <div className="hnth-roster-control">
    <label><ListChecks size={14}/><span>Danh sách điểm cầu của phiên</span></label>
    <div className="hnth-roster-row">
      <select value={activeId} disabled={busy} onChange={(event) => void activate(event.target.value)} aria-label="Danh sách điểm cầu của phiên họp">
        <option value="default">Tất cả điểm cầu ({catalogPoints.length})</option>
        {rosters.map((roster) => <option key={roster.id} value={roster.id}>{roster.name} ({roster.pointCount} điểm)</option>)}
      </select>
      <button type="button" className="icon-button" onClick={() => void editActive()} disabled={busy || activeId === "default"} title="Sửa tên và các điểm của danh sách đang chọn"><Pencil size={14}/></button>
      <button type="button" className="icon-button" onClick={() => setRosterDraft({ id: null, name: "", pointIds: [] })} disabled={busy} title="Tạo danh sách mới từ dữ liệu điểm cầu"><Plus size={14}/></button>
      <button type="button" className="icon-button" onClick={() => setCatalogDraft({ points: catalogPoints })} disabled={busy} title="Dữ liệu điểm cầu (dữ liệu chủ từ Import)"><Database size={14}/></button>
    </div>
    {rosters.some((roster) => roster.id !== activeId) && <details className="hnth-roster-others">
      <summary>Quản lý {rosters.length} danh sách đã lưu</summary>
      {rosters.filter((roster) => roster.id !== activeId).map((roster) => <div key={roster.id}><span>{roster.name} · {roster.pointCount} điểm</span><button type="button" onClick={() => void deleteRoster(roster.id)} title="Xóa danh sách"><Trash2 size={13}/></button></div>)}
    </details>}
    {message && <p className="hnth-roster-message" role="alert">{message}</p>}
    {rosterDraft && <HnthRosterEditor draft={rosterDraft} catalog={catalogPoints} onSave={saveRoster} onClose={() => setRosterDraft(null)} />}
    {catalogDraft && <HnthCatalogEditor draft={catalogDraft} wards={wards} onSave={saveCatalog} onClose={() => setCatalogDraft(null)} />}
  </div>;
}
