import { ArrowDown, Car, LocateFixed, Navigation, Plus, Route } from "lucide-react";

export function RoutingPanel() {
  return (
    <section className="panel-section">
      <div className="section-heading"><div><span className="eyebrow">ĐIỀU PHỐI</span><h2>Định tuyến</h2></div><Route size={20} /></div>
      <div className="profile-tabs"><button className="active"><Car size={16}/> Ô tô</button><button>Đi bộ</button><button>Xe đạp</button></div>
      <div className="route-inputs">
        <label><span className="route-dot start"/><input defaultValue="Trung tâm hành chính Hải Phòng"/><LocateFixed size={16}/></label>
        <ArrowDown size={15} className="route-arrow" />
        <label><span className="route-dot end"/><input placeholder="Chọn điểm đến trên bản đồ"/><LocateFixed size={16}/></label>
      </div>
      <button className="text-button"><Plus size={15}/> Thêm điểm dừng</button>
      <div className="route-summary"><div><small>Quãng đường</small><strong>—</strong></div><div><small>Thời gian</small><strong>—</strong></div></div>
      <button className="primary-button"><Navigation size={16}/> Tìm đường</button>
      <p className="hint">Dịch vụ OSRM sẽ được nối ở milestone M4.</p>
    </section>
  );
}
