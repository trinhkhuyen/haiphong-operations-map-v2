import { Home, Layers3 } from "lucide-react";
import { useAppStore } from "../../core/store";
import { HNTH_LAYER_ID } from "../layers/hnth-data-provider";
import { AdministrativeFixedInfoCard } from "./MapInfoCards";
import { HnthEndpointCard } from "./HnthEndpointCard";
import { baseMapOptions } from "./lib/base-style";
import { formatSummaryArea } from "./lib/drawing";
import { useMapScope } from "./hooks/useMapScope";
import { useMapInspection } from "./hooks/useMapInspection";
import { useMapInstance } from "./hooks/useMapInstance";
import { useMapCamera } from "./hooks/useMapCamera";
import { useOperationalLayersSync } from "./hooks/useOperationalLayersSync";
import { useDrawingSync } from "./hooks/useDrawingSync";
import { useAdministrativeLayers } from "./hooks/useAdministrativeLayers";
import { useHnthMapSync } from "./hooks/useHnthMapSync";
import { useAdministrativeSelection } from "./hooks/useAdministrativeSelection";
import { useVietnamProvinceBoundaries } from "./hooks/useVietnamProvinceBoundaries";
import { useHnthHubPulse } from "./hooks/useHnthHubPulse";
import { usePresentationBridge } from "./hooks/usePresentationBridge";
import { HnthExtraCards } from "./HnthExtraCards";

export function MapCanvas() {
  const scope = useMapScope();
  const { containerRef, mapRef, isMapReady, isBaseMapMenuOpen, setIsBaseMapMenuOpen, fixedMapInfo, zoneSummary } = scope;
  const layers = useAppStore((state) => state.layers);
  const baseMapMode = useAppStore((state) => state.baseMapMode);
  const administrativeUnits = useAppStore((state) => state.administrativeUnits);
  const activePanel = useAppStore((state) => state.activePanel);

  const fixedAdministrativeUnit = fixedMapInfo?.kind === "administrative"
    ? administrativeUnits.find((unit) => unit.id === fixedMapInfo.unitId)
    : undefined;
  const fixedHnthProperties = fixedMapInfo?.kind === "hnth"
    ? layers.find((layer) => layer.id === HNTH_LAYER_ID)?.data.features.find((item) => (
        item.geometry.type === "Point" && String(item.properties?.pointId ?? item.id) === fixedMapInfo.pointId
      ))?.properties
    : undefined;

  const inspection = useMapInspection(scope);
  const { clearMapInspection } = inspection;
  useMapInstance({ ...scope, ...inspection });
  const { goHome } = useMapCamera({ ...scope, ...inspection });
  useOperationalLayersSync(scope);
  useDrawingSync(scope);
  useAdministrativeLayers(scope);
  useHnthMapSync(scope);
  useAdministrativeSelection({ ...scope, ...inspection });
  useVietnamProvinceBoundaries(scope);
  useHnthHubPulse(scope);
  usePresentationBridge(scope);

  return (
    <>
      <div ref={containerRef} className="map-canvas" aria-label="Bản đồ giám sát Hải Phòng" />
      <HnthExtraCards mapRef={mapRef} isMapReady={isMapReady} />
      <div className="map-navigation-tools" aria-label="Công cụ điều hướng bản đồ">
        {isBaseMapMenuOpen && (
          <div className="base-map-menu" role="menu" aria-label="Chế độ bản đồ">
            <span>CHẾ ĐỘ BẢN ĐỒ</span>
            {baseMapOptions.map((option) => {
              const Icon = option.icon;
              return (
                <button
                  key={option.id}
                  className={baseMapMode === option.id ? "active" : ""}
                  type="button"
                  role="menuitemradio"
                  aria-checked={baseMapMode === option.id}
                  onClick={() => {
                    useAppStore.getState().setBaseMapMode(option.id);
                    setIsBaseMapMenuOpen(false);
                  }}
                >
                  <Icon size={16}/><span><strong>{option.label}</strong><small>{option.description}</small></span>
                </button>
              );
            })}
          </div>
        )}
        <button
          className={isBaseMapMenuOpen ? "active" : ""}
          type="button"
          title="Chọn chế độ bản đồ"
          aria-label="Chọn chế độ bản đồ"
          aria-expanded={isBaseMapMenuOpen}
          onClick={() => setIsBaseMapMenuOpen((open) => !open)}
        ><Layers3 size={17}/></button>
        <button type="button" title="Về khung hình mặc định (Home)" aria-label="Go home về khung hình mặc định" onClick={goHome}><Home size={17}/></button>
      </div>
      {fixedAdministrativeUnit && fixedMapInfo?.kind === "administrative" && (
        <AdministrativeFixedInfoCard
          unit={fixedAdministrativeUnit}
          includeConnectionPoint={fixedMapInfo.includeConnectionPoint}
          onClose={() => {
            clearMapInspection();
            if (activePanel === "zones") useAppStore.getState().clearAdministrativeFocus();
          }}
        />
      )}
      {/* Chi tiết Endpoint gọn (tên, IP, trạng thái) dưới thanh trạng thái, tự tắt sau 5 giây. */}
      <HnthEndpointCard properties={fixedMapInfo?.kind === "hnth" ? fixedHnthProperties ?? undefined : undefined} selection={fixedMapInfo?.kind === "hnth" ? fixedMapInfo : null} />
      {activePanel === "zones" && zoneSummary.zoneCount > 0 && (
        <aside className="zone-summary-popup" aria-label="Thông tin tổng hợp đối tượng các lớp">
          <span>THÔNG TIN TỔNG HỢP</span>
          <strong>{zoneSummary.zoneCount} vùng đang bật</strong>
          <div>
            {zoneSummary.items.map((item) => (
              <p key={item.id}><i style={{ backgroundColor: item.color }}/><b>{item.count}</b> {item.label}</p>
            ))}
          </div>
          {zoneSummary.items.every((item) => item.count === 0) && <small>Chưa có đối tượng thuộc các lớp đang bật nằm trong vùng.</small>}
          <div className="zone-summary-totals">
            <p><span>Phân loại vùng</span><b>{zoneSummary.drawnZoneCount} vùng và {zoneSummary.administrativeZoneCount} địa giới</b></p>
            <p><span>Tổng diện tích</span><b>{formatSummaryArea(zoneSummary.totalAreaSquareMeters)}</b></p>
            <p><span>Tổng dân số <em>(ước tính)</em></span><b>≈ {new Intl.NumberFormat("vi-VN").format(zoneSummary.estimatedPopulation)} người</b></p>
          </div>
        </aside>
      )}
    </>
  );
}
