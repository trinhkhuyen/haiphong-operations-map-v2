import { useState } from "react";
import { BusFront, Camera, ChevronDown, ChevronRight, Eye, EyeOff, Landmark, Layers3, RadioTower, Route, Shield, Waves } from "lucide-react";
import { useAppStore } from "../../core/store";
import type { LayerGroup, OperationalLayer } from "../../core/types";
import { HNTH_LAYER_ID } from "./hnth-data-provider";

const icons = { camera: Camera, landmark: Landmark, bus: BusFront, route: Route, waves: Waves, shield: Shield, radio: RadioTower };
const groupMeta: Record<LayerGroup, { label: string; description: string; icon: typeof Layers3 }> = {
  monitoring: { label: "Giám sát", description: "Thiết bị và cảm biến", icon: Camera },
  transport: { label: "Giao thông", description: "Bến xe và mạng lưới đường bộ", icon: BusFront },
  hydrology: { label: "Thủy hệ", description: "Sông, suối, ao hồ thực tế", icon: Waves },
  government: { label: "Cơ quan nhà nước", description: "Hành chính và dịch vụ công", icon: Landmark },
};
const groupOrder: LayerGroup[] = ["monitoring", "transport", "hydrology", "government"];

export function LayerPanel() {
  const layers = useAppStore((state) => state.layers);
  const catalogLayers = layers.filter((layer) => layer.id !== HNTH_LAYER_ID);
  const status = useAppStore((state) => state.operationalDataStatus);
  const loadedLayerIds = useAppStore((state) => state.loadedLayerIds);
  const loadingLayerIds = useAppStore((state) => state.loadingLayerIds);
  const clusterLevel = useAppStore((state) => state.clusterLevel);
  const toggleLayer = useAppStore((state) => state.toggleLayer);
  const setClusterLevel = useAppStore((state) => state.setClusterLevel);
  const [expanded, setExpanded] = useState<LayerGroup[]>(["monitoring", "transport", "hydrology", "government"]);

  const toggleGroup = (group: LayerGroup) => setExpanded((current) => current.includes(group)
    ? current.filter((item) => item !== group)
    : [...current, group]);
  const setGroupVisibility = (items: OperationalLayer[]) => {
    const nextVisible = !items.every((item) => item.visible);
    items.forEach((item) => { if (item.visible !== nextVisible) toggleLayer(item.id); });
  };

  return (
    <section className="panel-section">
      <div className="section-heading">
        <div><span className="eyebrow">DỮ LIỆU VẬN HÀNH</span><h2>Lớp đối tượng</h2></div>
        <span className="count-chip">{catalogLayers.length} lớp</span>
      </div>
      <div className={`live-data-state ${status}`}>
        <span className="live-data-dot" />
        <div><strong>{status === "idle" ? "Chưa bật lớp dữ liệu" : status === "loading" ? "Đang tải các lớp đã bật" : status === "error" ? "Chưa tải được dữ liệu thực" : "Đã tải các lớp được bật"}</strong><small>OpenStreetMap + dữ liệu Hải Phòng</small></div>
      </div>
      <div className="cluster-control">
        <div className="cluster-control-head">
          <span><strong>Mức độ gộp</strong><small>Điều chỉnh khoảng cách gom các điểm cùng lớp</small></span>
          <b>{clusterLevel}/10</b>
        </div>
        <input
          aria-label="Mức độ gộp đối tượng"
          type="range"
          min="1"
          max="10"
          step="1"
          value={clusterLevel}
          onChange={(event) => setClusterLevel(Number(event.target.value))}
        />
        <div className="cluster-control-scale"><span>1 · Mặc định</span><span>10 · Gộp sớm</span></div>
      </div>
      <div className="layer-groups">
        {groupOrder.map((group) => {
          const items = catalogLayers.filter((layer) => layer.group === group);
          if (!items.length) return null;
          const meta = groupMeta[group];
          const GroupIcon = meta.icon;
          const isExpanded = expanded.includes(group) || items.length === 1;
          const allVisible = items.every((item) => item.visible);
          const visibleCount = items.filter((item) => item.visible).length;
          return (
            <section className="layer-group" key={group}>
              <div className="layer-group-head">
                <button className="layer-group-expand" onClick={() => items.length > 1 && toggleGroup(group)} aria-expanded={isExpanded}>
                  {items.length > 1 ? (isExpanded ? <ChevronDown size={14} /> : <ChevronRight size={14} />) : <GroupIcon size={14} />}
                  <span><strong>{meta.label}</strong><small>{meta.description}</small></span>
                </button>
                <button className={allVisible ? "group-visibility active" : "group-visibility"} onClick={() => setGroupVisibility(items)} title="Bật/tắt cả nhóm">
                  <b>{visibleCount}/{items.length}</b>{allVisible ? <Eye size={14} /> : <EyeOff size={14} />}
                </button>
              </div>
              {isExpanded && <div className="layer-list nested">
                {items.map((layer) => {
                  const Icon = icons[layer.icon as keyof typeof icons] ?? Layers3;
                  const isLoading = loadingLayerIds.includes(layer.id);
                  const isLoaded = loadedLayerIds.includes(layer.id);
                  return (
                    <button className={`layer-row ${layer.visible ? "is-visible" : ""}`} key={layer.id} onClick={() => toggleLayer(layer.id)}>
                      <span className="layer-icon" style={{ color: layer.color, background: `${layer.color}18` }}><Icon size={16} /></span>
                      <span className="layer-copy"><strong>{layer.name}</strong><small>{isLoading ? "Đang tải..." : layer.visible && !isLoaded ? "Chờ tải..." : isLoaded ? `${layer.count.toLocaleString("vi-VN")} đối tượng` : "Chưa tải"}</small></span>
                      {layer.visible ? <Eye size={16} /> : <EyeOff size={16} />}
                    </button>
                  );
                })}
              </div>}
            </section>
          );
        })}
      </div>
      <p className="layer-source-note">© OpenStreetMap contributors · Snapshot đã lọc theo 114 địa giới</p>
      <button className="secondary-button"><Layers3 size={16} /> Thêm lớp dữ liệu</button>
    </section>
  );
}
