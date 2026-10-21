// Thẻ thông tin cố định trên bản đồ (địa giới, điểm HNTH).
import { Cable, FileText, X, Zap } from "lucide-react";
import { area as turfArea, feature, point } from "@turf/turf";
import { useAppStore } from "../../core/store";
import type { AdministrativeUnit } from "../../core/types";
import { HNTH_STATUS_LABELS, normalizeHnthStatus, type HnthConnectionStatus } from "../layers/hnth-data-provider";
import { HnthDisconnectConfirmButton } from "../conference/HnthDisconnectConfirmButton";
import { emitAppEvent } from "../../core/events";
import { formatSummaryArea } from "./lib/drawing";

export function AdministrativeFixedInfoCard({
  unit,
  includeConnectionPoint,
  onClose,
}: {
  unit: AdministrativeUnit;
  includeConnectionPoint: boolean;
  onClose: () => void;
}) {
  const areaSquareMeters = turfArea(feature(unit.geometry));
  const estimatedPopulation = Math.round((areaSquareMeters / 1_000_000) * 1450);
  return (
    <aside className="map-fixed-info-card" aria-label={`Thông tin địa giới ${unit.name}`}>
      <button className="map-fixed-info-close" type="button" onClick={onClose} aria-label="Đóng thông tin địa giới"><X size={15}/></button>
      <span>THÔNG TIN ĐỊA GIỚI</span>
      <strong>{unit.type} {unit.name}</strong>
      <small>Mã đơn vị: {unit.wardCode}</small>
      <dl>
        <dt>Diện tích</dt><dd>{formatSummaryArea(areaSquareMeters)}</dd>
        <dt>Dân số (ước tính)</dt><dd>≈ {new Intl.NumberFormat("vi-VN").format(estimatedPopulation)} người</dd>
        {includeConnectionPoint && <><dt>Điểm kết nối</dt><dd>UBND {unit.type} {unit.name}</dd></>}
      </dl>
    </aside>
  );
}

export function HnthFixedInfoCard({ properties, onClose }: { properties: Record<string, unknown>; onClose: () => void }) {
  const status = normalizeHnthStatus(properties.status);
  const pointId = String(properties.pointId ?? "");
  const pointName = String(properties.name ?? "Điểm nhánh HNTH");
  const updateHnthPoint = useAppStore((state) => state.updateHnthPoint);
  const setConnectionStatus = (nextStatus: HnthConnectionStatus) => {
    if (pointId) updateHnthPoint(pointId, { status: nextStatus });
  };
  return (
    <aside className="map-fixed-info-card hnth" aria-label={`Thông tin Endpoint ${String(properties.name ?? "Điểm nhánh")}`}>
      <button className="map-fixed-info-close" type="button" onClick={onClose} aria-label="Đóng thông tin Endpoint"><X size={15}/></button>
      <span>THÔNG TIN ENDPOINT</span>
      <strong>{pointName}</strong>
      <small>{String(properties.roleLabel ?? "Điểm nhánh HNTH")}</small>
      <dl>
        <dt>IP</dt><dd>{String(properties.ipAddress ?? "Chưa cấu hình")}</dd>
        <dt>Gateway</dt><dd>{String(properties.gateway ?? "Chưa cấu hình")}</dd>
        <dt>Model/Vendor</dt><dd>{String(properties.model ?? "Chưa cấu hình")}</dd>
        {status !== "unknown" && <><dt>Trạng thái</dt><dd className={`hnth-status ${status}`}>{HNTH_STATUS_LABELS[status]}</dd></>}
        <dt>Nguồn</dt><dd>{String(properties.source ?? "Dữ liệu vận hành")}</dd>
      </dl>
      <div className="hnth-popup-actions">
        <button
          type="button"
          onClick={() => {
            if (!pointId) return;
            emitAppEvent("hnth:test-point", { pointId, ipAddress: String(properties.ipAddress ?? ""), runId: Date.now() });
          }}
        ><Zap size={13}/> Test</button>
        <button
          className="log"
          type="button"
          onClick={() => {
            if (!pointId) return;
            emitAppEvent("hnth:open-point-log", { pointId });
          }}
        ><FileText size={13}/> Log</button>
        {status === "connected"
          ? <HnthDisconnectConfirmButton pointName={pointName} onConfirm={() => setConnectionStatus("unconnected")} />
          : <button className="connect" type="button" onClick={() => setConnectionStatus("connected")}><Cable size={13}/> Kết nối</button>}
      </div>
    </aside>
  );
}
