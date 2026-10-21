import { useEffect } from "react";
import { CircleOff, Info, RadioTower, X } from "lucide-react";

const deviceCards = [
  { image: "/assets/hnth/vcs-terminal.svg", title: "Thiết bị đầu cuối VCS", model: "Cisco Webex Room Kit", detail: "SIP/H.323 · 4K UHD · Camera PTZ" },
  { image: "/assets/hnth/mixer.svg", title: "Bộ trộn âm thanh", model: "Yamaha MG10XU", detail: "10 kênh · USB Audio · DSP FX" },
  { image: "/assets/hnth/microphone.svg", title: "Hệ thống micro", model: "Shure MX418", detail: "Micro cổ ngỗng · Cardioid" },
  { image: "/assets/hnth/speaker.svg", title: "Hệ thống loa", model: "JBL Control 25-1", detail: "2 loa toàn dải · 200 W" },
];

/** Popup thiết bị điểm nhánh (ảnh và cấu hình minh họa). Đóng bằng Esc hoặc bấm nền. */
export function HnthDeviceInfoModal({ name, ipAddress, gateway, onClose }: { name: string; ipAddress: string; gateway: string; onClose: () => void }) {
  useEffect(() => {
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };
    window.addEventListener("keydown", closeOnEscape);
    return () => window.removeEventListener("keydown", closeOnEscape);
  }, [onClose]);

  return <div className="hnth-modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}>
    <section className="hnth-modal info" role="dialog" aria-modal="true" aria-label="Thiết bị điểm nhánh">
      <header><span><Info size={17}/><strong>Thiết bị điểm nhánh</strong></span><button onClick={onClose} aria-label="Đóng cửa sổ"><X size={18}/></button></header>
      <div className="hnth-modal-site"><RadioTower size={16}/><div><strong>{name}</strong><small>{ipAddress} · Gateway {gateway}</small></div></div>
      <div className="hnth-device-grid">
        {deviceCards.map((device) => <article key={device.title}><img src={device.image} alt={`Ảnh minh họa ${device.title}`}/><div><span>{device.title}</span><strong>{device.model}</strong><small>{device.detail}</small><em><CircleOff size={10}/> Ảnh và cấu hình minh họa</em></div></article>)}
      </div>
    </section>
  </div>;
}
