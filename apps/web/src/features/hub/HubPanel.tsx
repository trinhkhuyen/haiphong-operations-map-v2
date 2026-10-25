import { Compass, Eye, EyeOff, Gauge, SlidersHorizontal } from "lucide-react";
import { useAppStore } from "../../core/store";

export function HubPanel() {
  const enabled = useAppStore((state) => state.hubEnabled);
  const glass = useAppStore((state) => state.hubGlassmorphism);
  const opacity = useAppStore((state) => state.hubOpacity);
  const setEnabled = useAppStore((state) => state.setHubEnabled);
  const setGlass = useAppStore((state) => state.setHubGlassmorphism);
  const setOpacity = useAppStore((state) => state.setHubOpacity);

  return <section className="hub-panel">
    <div className="panel-heading"><div><span>GIAO DIỆN BẢN ĐỒ</span><h2>HUB điều hành</h2></div><Compass size={21} /></div>
    <p className="hub-intro">Thanh thông tin cố định ở cạnh dưới bản đồ, chia thành ba khu vực để bổ sung dữ liệu vận hành về sau.</p>
    <button className={`hub-toggle ${enabled ? "active" : ""}`} type="button" onClick={() => setEnabled(!enabled)}>
      {enabled ? <Eye size={16} /> : <EyeOff size={16} />}<span><strong>{enabled ? "HUB đang hiển thị" : "HUB đang tắt"}</strong><small>Bật / tắt toàn bộ thanh HUB</small></span><i />
    </button>
    <div className="hub-setting-group"><span className="hub-label"><SlidersHorizontal size={14} /> HIỂN THỊ</span>
      <div className="hub-choice-row">
        <button className={glass ? "active" : ""} type="button" onClick={() => setGlass(true)}><strong>Kính mờ</strong><small>Glassmorphism</small></button>
        <button className={!glass ? "active" : ""} type="button" onClick={() => setGlass(false)}><strong>Hiển thị rõ</strong><small>Nền đặc</small></button>
      </div>
      <label className="hub-range"><span>Độ trong suốt</span><b>{Math.round(opacity * 100)}%</b><input type="range" min="25" max="100" value={Math.round(opacity * 100)} onChange={(event) => setOpacity(Number(event.target.value) / 100)} /></label>
    </div>
    <div className="hub-layout-preview"><span>QUY ƯỚC BỐ CỤC</span><div><b>HUB TRÁI</b><b>HUB TRUNG TÂM</b><b>HUB PHẢI</b></div><small>Trái và phải: tối đa 3 đồng hồ mỗi vùng · Trung tâm: thông tin chính</small></div>
    <div className="hub-coming"><Gauge size={15} /><span><strong>Đồng hồ đang dùng</strong><small>HUB phải · tốc độ / độ cao</small></span></div>
  </section>;
}
