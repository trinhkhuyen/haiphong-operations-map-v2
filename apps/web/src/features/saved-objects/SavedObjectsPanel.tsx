import { Circle, Eye, EyeOff, LocateFixed, MapPin, Route, Save, Shapes, TextCursorInput, Trash2 } from "lucide-react";
import type { SavedObjectKind } from "../../core/types";
import { useAppStore } from "../../core/store";
import { mapIconByKey } from "../../core/map-icons";

interface SavedObjectRow {
  kind: SavedObjectKind;
  id: string;
  name: string;
  visible: boolean;
  detail: string;
  icon: typeof Shapes;
}

export function SavedObjectsPanel() {
  const store = useAppStore();
  const rows: SavedObjectRow[] = [
    ...store.savedDrawFeatures.map((item) => ({
      kind: "geometry" as const,
      id: item.id,
      name: item.name,
      visible: item.visible,
      detail: geometryLabel(item.feature.properties?.mode, item.feature.geometry.type),
      icon: item.feature.geometry.type === "LineString" ? Route : item.feature.properties?.mode === "circle" ? Circle : Shapes,
    })),
    ...store.textAnnotations.filter((item) => item.saved).map((item) => ({
      kind: "text" as const,
      id: item.id,
      name: item.name || item.text,
      visible: item.visible !== false,
      detail: "Nhãn chữ",
      icon: TextCursorInput,
    })),
    ...store.iconAnnotations.filter((item) => item.saved).map((item) => ({
      kind: "icon" as const,
      id: item.id,
      name: item.name || mapIconByKey[item.icon].label,
      visible: item.visible !== false,
      detail: `Icon · ${mapIconByKey[item.icon].label}`,
      icon: MapPin,
    })),
  ];

  return (
    <section className="panel-section saved-objects-panel">
      <div className="section-heading">
        <div><span className="eyebrow">BỘ SƯU TẬP</span><h2>Đối tượng đã lưu</h2></div>
        <span className="status-live">{rows.length} đối tượng</span>
      </div>
      <p className="muted">Bật/tắt như một lớp riêng, đổi tên hoặc định vị lại các hình, đường, Text và Icon đã lưu.</p>

      {rows.length === 0 ? (
        <div className="saved-objects-empty">
          <Save size={24}/>
          <strong>Chưa có đối tượng đã lưu</strong>
          <small>Chọn một đối tượng trong Khoanh vùng / Tự vẽ, đặt tên rồi bấm Lưu đối tượng.</small>
        </div>
      ) : (
        <div className="saved-objects-list">
          {rows.map(({ kind, id, name, visible, detail, icon: Icon }) => (
            <article className={`saved-object-row${visible ? "" : " hidden"}`} key={`${kind}-${id}`}>
              <button className="saved-object-visibility" onClick={() => store.toggleSavedObject(kind, id)} title={visible ? "Ẩn khỏi bản đồ" : "Hiện trên bản đồ"}>
                {visible ? <Eye size={16}/> : <EyeOff size={16}/>}
              </button>
              <span className="saved-object-symbol"><Icon size={17}/></span>
              <label>
                <input
                  defaultValue={name}
                  key={name}
                  maxLength={80}
                  aria-label="Tên đối tượng"
                  onBlur={(event) => store.renameSavedObject(kind, id, event.target.value)}
                  onKeyDown={(event) => { if (event.key === "Enter") event.currentTarget.blur(); }}
                />
                <small>{detail}</small>
              </label>
              <button onClick={() => store.requestFocusSavedObject(kind, id)} title="Định vị trên bản đồ" aria-label={`Định vị ${name}`}><LocateFixed size={15}/></button>
              <button className="saved-object-delete" onClick={() => store.deleteSavedObject(kind, id)} title="Xóa đối tượng đã lưu" aria-label={`Xóa ${name}`}><Trash2 size={15}/></button>
            </article>
          ))}
        </div>
      )}
    </section>
  );
}

function geometryLabel(mode: unknown, geometryType: string) {
  if (mode === "circle") return "Đường tròn";
  if (mode === "rectangle") return "Hình chữ nhật";
  if (mode === "multilinestring") return "Multi Line";
  if (geometryType === "LineString") return "Đường thẳng";
  return "Đa giác";
}
