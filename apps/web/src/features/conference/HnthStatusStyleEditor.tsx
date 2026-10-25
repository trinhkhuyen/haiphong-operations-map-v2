import { Cable, Map } from "lucide-react";
import { HNTH_STATUS_LABELS, type HnthConnectionStatus, type HnthStatusStyles } from "../layers/hnth-data-provider";

const statusOrder: HnthConnectionStatus[] = ["unconnected", "connected", "lost"];

/** Bật/tắt và chọn màu theo trạng thái cho đường kết nối hoặc nền địa giới HNTH. */
export function HnthStatusStyleEditor({ title, styles, onChange, icon, signalStatuses = false }: {
  title: string;
  styles: HnthStatusStyles;
  onChange: (status: HnthConnectionStatus, update: Partial<HnthStatusStyles[HnthConnectionStatus]>) => void;
  icon?: "map";
  /** Chỉ bật trong editor màu đường kết nối; vùng địa giới không có tín hiệu chạy. */
  signalStatuses?: boolean;
}) {
  return <details className="hnth-style-editor">
    <summary>{icon === "map" ? <Map size={14}/> : <Cable size={14}/>}<span>{title}</span></summary>
    <div>
      {statusOrder.map((status) => <label key={status}>
        <input type="checkbox" checked={styles[status].visible} onChange={(event) => onChange(status, { visible: event.target.checked })}/>
        <span>{HNTH_STATUS_LABELS[status]}</span>
        {signalStatuses && (status !== "lost" ? <span className="hnth-signal-toggle" title="Bật chấm tín hiệu chạy dọc nét đứt">
          <input type="checkbox" checked={Boolean(styles[status].signal)} onChange={(event) => onChange(status, { signal: event.target.checked })}/>
          <small>Tín hiệu</small>
        </span> : <span aria-hidden="true" />)}
        <input type="color" value={styles[status].color} onChange={(event) => onChange(status, { color: event.target.value })} aria-label={`Màu ${HNTH_STATUS_LABELS[status]}`}/>
        <code>{styles[status].visible ? styles[status].color.toUpperCase() : "ẨN"}</code>
      </label>)}
    </div>
  </details>;
}
