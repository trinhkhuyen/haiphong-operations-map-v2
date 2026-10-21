import { Cable, Map } from "lucide-react";
import { HNTH_STATUS_LABELS, type HnthConnectionStatus, type HnthStatusStyles } from "../layers/hnth-data-provider";

const statusOrder: HnthConnectionStatus[] = ["unconnected", "connected", "lost"];

/** Bật/tắt và chọn màu theo trạng thái cho đường kết nối hoặc nền địa giới HNTH. */
export function HnthStatusStyleEditor({ title, styles, onChange, icon }: {
  title: string;
  styles: HnthStatusStyles;
  onChange: (status: HnthConnectionStatus, update: Partial<HnthStatusStyles[HnthConnectionStatus]>) => void;
  icon?: "map";
}) {
  return <details className="hnth-style-editor">
    <summary>{icon === "map" ? <Map size={14}/> : <Cable size={14}/>}<span>{title}</span></summary>
    <div>
      {statusOrder.map((status) => <label key={status}>
        <input type="checkbox" checked={styles[status].visible} onChange={(event) => onChange(status, { visible: event.target.checked })}/>
        <span>{HNTH_STATUS_LABELS[status]}</span>
        <input type="color" value={styles[status].color} onChange={(event) => onChange(status, { color: event.target.value })} aria-label={`Màu ${HNTH_STATUS_LABELS[status]}`}/>
        <code>{styles[status].visible ? styles[status].color.toUpperCase() : "ẨN"}</code>
      </label>)}
    </div>
  </details>;
}
