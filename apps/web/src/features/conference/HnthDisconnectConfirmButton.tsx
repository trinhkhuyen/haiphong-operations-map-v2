import { useEffect, useState, type ReactNode } from "react";
import { createPortal } from "react-dom";
import { TriangleAlert, Unplug, X } from "lucide-react";

export function HnthDisconnectConfirmButton({
  pointName,
  onConfirm,
  className = "disconnect",
  children,
  disabled = false,
}: {
  pointName: string;
  onConfirm: () => void;
  className?: string;
  children?: ReactNode;
  disabled?: boolean;
}) {
  const [isOpen, setIsOpen] = useState(false);

  useEffect(() => {
    if (!isOpen) return;
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key !== "Escape") return;
      // Chỉ đóng popup xác nhận trên cùng, không đóng đồng thời bảng chi tiết phía sau.
      event.stopImmediatePropagation();
      setIsOpen(false);
    };
    window.addEventListener("keydown", closeOnEscape, true);
    return () => window.removeEventListener("keydown", closeOnEscape, true);
  }, [isOpen]);

  const confirmDisconnect = () => {
    onConfirm();
    setIsOpen(false);
  };

  return <>
    <button className={className} type="button" disabled={disabled} onClick={() => setIsOpen(true)}>
      {children ?? <><Unplug size={13}/> Ngắt</>}
    </button>
    {isOpen && createPortal(
      <div className="hnth-modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) setIsOpen(false); }}>
        {/* Popup Xác nhận ngắt kết nối: dùng chung cho mọi nút Ngắt của HNTH. */}
        <section className="hnth-modal hnth-disconnect-confirm" role="alertdialog" aria-modal="true" aria-label="Popup Xác nhận ngắt kết nối">
          <header><span><TriangleAlert size={17}/><strong>Xác nhận ngắt kết nối</strong></span><button onClick={() => setIsOpen(false)} aria-label="Đóng Popup Xác nhận ngắt kết nối"><X size={18}/></button></header>
          <div className="hnth-confirm-content">
            <span><Unplug size={22}/></span>
            <div><strong>Ngắt kết nối điểm này?</strong><p>{pointName}</p><small>Trạng thái điểm sẽ chuyển thành “Chưa kết nối”.</small></div>
          </div>
          <div className="hnth-confirm-actions">
            <button type="button" className="cancel" onClick={() => setIsOpen(false)}>Hủy</button>
            <button type="button" className="disconnect" onClick={confirmDisconnect}><Unplug size={14}/> Xác nhận ngắt</button>
          </div>
        </section>
      </div>,
      document.body,
    )}
  </>;
}
