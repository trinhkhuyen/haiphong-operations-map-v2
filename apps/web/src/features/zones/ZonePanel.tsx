import { useEffect, useMemo, useRef, useState, type FormEvent } from "react";
import { Check, Circle, Info, LoaderCircle, MapPin, Minus, MousePointer2, Palette, Pentagon, RectangleHorizontal, Route, Save, Search, Shapes, SmilePlus, TextCursorInput, Trash2, X } from "lucide-react";
import { booleanPointInPolygon, feature, point } from "@turf/turf";
import type { DrawMode, ZoneMode } from "../../core/types";
import { useAppStore } from "../../core/store";
import { mapIconOptions } from "../../core/map-icons";
import { loadAdministrativeUnits } from "../administrative/data-provider";
import { searchHaiphongPlaces, type PlaceSearchResult } from "../search/geocoding-provider";

const drawTools: { mode: DrawMode; label: string; icon: typeof Pentagon }[] = [
  { mode: "select", label: "Chọn / sửa", icon: MousePointer2 },
  { mode: "polygon", label: "Đa giác", icon: Pentagon },
  { mode: "rectangle", label: "Chữ nhật", icon: RectangleHorizontal },
  { mode: "circle", label: "Đường tròn", icon: Circle },
  { mode: "linestring", label: "Đường thẳng", icon: Minus },
  { mode: "multilinestring", label: "Multi Line", icon: Route },
  { mode: "text", label: "Text", icon: TextCursorInput },
  { mode: "icon", label: "Icon", icon: SmilePlus },
];

const zoneColorPresets = [
  { name: "Vàng", fill: "#fde68a", outline: "#d97706" },
  { name: "Xanh ngọc", fill: "#99f6e4", outline: "#0f766e" },
  { name: "Xanh biển", fill: "#bae6fd", outline: "#0369a1" },
  { name: "Chàm", fill: "#c7d2fe", outline: "#4338ca" },
  { name: "Tím", fill: "#ddd6fe", outline: "#6d28d9" },
  { name: "Đỏ", fill: "#fecdd3", outline: "#be123c" },
] as const;

const placeIndex = [
  { name: "Nhà hát thành phố Hải Phòng", detail: "Hoàng Văn Thụ, Hồng Bàng", coordinates: [106.6821, 20.8572] as [number, number] },
  { name: "Cầu Rào", detail: "Lạch Tray, Hải Phòng", coordinates: [106.7008, 20.8255] as [number, number] },
  { name: "Bến xe Vĩnh Niệm", detail: "Vĩnh Niệm, Lê Chân", coordinates: [106.6768, 20.8192] as [number, number] },
  { name: "Cảng hàng không quốc tế Cát Bi", detail: "Hải An, Hải Phòng", coordinates: [106.7248, 20.8194] as [number, number] },
  { name: "Trung tâm hành chính Hải Phòng", detail: "Thủy Nguyên, Hải Phòng", coordinates: [106.7095, 20.9462] as [number, number] },
];

const normalize = (value: string) => value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
const formatRadius = (meters: number) => meters >= 1000
  ? `${new Intl.NumberFormat("vi-VN", { maximumFractionDigits: 1 }).format(meters / 1000)} km`
  : `${meters} m`;
const formatArea = (squareMeters: number) => squareMeters >= 1_000_000
  ? `${new Intl.NumberFormat("vi-VN", { maximumFractionDigits: 2 }).format(squareMeters / 1_000_000)} km²`
  : `${new Intl.NumberFormat("vi-VN", { maximumFractionDigits: 0 }).format(squareMeters)} m²`;

export function ZonePanel() {
  const [showColorPresets, setShowColorPresets] = useState(false);
  const [drawPlaceQuery, setDrawPlaceQuery] = useState("");
  const [drawPlaceResults, setDrawPlaceResults] = useState<PlaceSearchResult[]>([]);
  const [drawPlaceSearchStatus, setDrawPlaceSearchStatus] = useState<"idle" | "loading" | "empty" | "error">("idle");
  const [savedObjectName, setSavedObjectName] = useState("");
  const drawPlaceSearchController = useRef<AbortController | null>(null);
  const store = useAppStore();
  const {
    zoneMode, drawMode, administrativeUnits, administrativeStatus, administrativeQuery,
    selectedAdministrativeIds, focusedAdministrativeId, dimOutsideHaiphong, defaultViewportEnabled, defaultViewport, defaultAdministrativeIds,
    administrativeFillColor, administrativeOutlineColor, administrativeFillOpacity,
    drawFillColor, drawOutlineColor, drawFillOpacity,
    selectedDrawFeatureId, selectedDrawFeatureInfo, textDraft, iconDraft,
    textAnnotations, iconAnnotations, selectedAnnotation, drawSearchTarget,
  } = store;
  const tabs: { mode: ZoneMode; label: string }[] = [
    { mode: "administrative", label: "Địa giới" },
    { mode: "draw", label: "Tự vẽ" },
    { mode: "info", label: "Thông tin" },
  ];

  useEffect(() => {
    if (administrativeStatus !== "idle") return;
    store.setAdministrativeStatus("loading");
    loadAdministrativeUnits().then(store.setAdministrativeUnits).catch(() => store.setAdministrativeStatus("error"));
  }, [administrativeStatus, store]);

  useEffect(() => () => drawPlaceSearchController.current?.abort(), []);

  const normalizedQuery = normalize(administrativeQuery.trim());
  const filteredUnits = useMemo(() => administrativeUnits.filter((unit) => {
    if (!normalizedQuery) return true;
    return normalize(`${unit.type} ${unit.name}`).includes(normalizedQuery);
  }), [administrativeUnits, normalizedQuery]);
  const matchingPlaces = normalizedQuery.length >= 2
    ? placeIndex.filter((place) => normalize(`${place.name} ${place.detail}`).includes(normalizedQuery))
    : [];
  const selectedUnits = administrativeUnits.filter((unit) => selectedAdministrativeIds.includes(unit.id));
  const defaultAdministrativeUnits = administrativeUnits.filter((unit) => defaultAdministrativeIds.includes(unit.id));
  const selectedText = selectedAnnotation?.kind === "text" ? textAnnotations.find((annotation) => annotation.id === selectedAnnotation.id) : undefined;
  const selectedIcon = selectedAnnotation?.kind === "icon" ? iconAnnotations.find((annotation) => annotation.id === selectedAnnotation.id) : undefined;
  const savedGeometry = selectedDrawFeatureId === null ? undefined : store.savedDrawFeatures.find((item) => item.featureId === selectedDrawFeatureId);
  const editingAdministrativeStyle = zoneMode === "administrative";
  const zoneFillColor = editingAdministrativeStyle ? administrativeFillColor : drawFillColor;
  const zoneOutlineColor = editingAdministrativeStyle ? administrativeOutlineColor : drawOutlineColor;
  const zoneFillOpacity = editingAdministrativeStyle ? administrativeFillOpacity : drawFillOpacity;
  const zoneTransparency = Math.round((1 - zoneFillOpacity) * 100);
  const setZoneFillColor = editingAdministrativeStyle ? store.setAdministrativeFillColor : store.setDrawFillColor;
  const setZoneOutlineColor = editingAdministrativeStyle ? store.setAdministrativeOutlineColor : store.setDrawOutlineColor;
  const setZoneFillOpacity = editingAdministrativeStyle ? store.setAdministrativeFillOpacity : store.setDrawFillOpacity;

  useEffect(() => {
    if (selectedText) {
      setSavedObjectName(selectedText.name || selectedText.text || "Nhãn chữ");
      return;
    }
    if (selectedIcon) {
      setSavedObjectName(selectedIcon.name || mapIconOptions.find((item) => item.key === selectedIcon.icon)?.label || "Icon bản đồ");
      return;
    }
    if (selectedDrawFeatureInfo) {
      const defaultName = selectedDrawFeatureInfo.kind === "circle" ? "Đường tròn"
        : selectedDrawFeatureInfo.kind === "rectangle" ? "Hình chữ nhật"
        : selectedDrawFeatureInfo.kind === "multiline" ? "Multi Line"
        : selectedDrawFeatureInfo.kind === "line" ? "Đường thẳng"
        : "Đa giác";
      setSavedObjectName(savedGeometry?.name || defaultName);
      return;
    }
    setSavedObjectName("");
  }, [selectedAnnotation?.kind, selectedAnnotation?.id, selectedDrawFeatureId]);


  const selectPlace = (coordinates: [number, number]) => {
    const location = point(coordinates);
    const containingUnit = administrativeUnits.find((unit) => {
      if (unit.geometry.type !== "Polygon" && unit.geometry.type !== "MultiPolygon") return false;
      return booleanPointInPolygon(location, feature(unit.geometry));
    });
    const nearestUnit = containingUnit ?? [...administrativeUnits].sort((first, second) => {
      const firstDistance = (first.coordinates[0] - coordinates[0]) ** 2 + (first.coordinates[1] - coordinates[1]) ** 2;
      const secondDistance = (second.coordinates[0] - coordinates[0]) ** 2 + (second.coordinates[1] - coordinates[1]) ** 2;
      return firstDistance - secondDistance;
    })[0];
    if (nearestUnit) store.selectAdministrativeUnit(nearestUnit.id);
  };

  const submitDrawPlaceSearch = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const query = drawPlaceQuery.trim();
    if (query.length < 2) {
      setDrawPlaceResults([]);
      setDrawPlaceSearchStatus("empty");
      return;
    }
    drawPlaceSearchController.current?.abort();
    const controller = new AbortController();
    drawPlaceSearchController.current = controller;
    setDrawPlaceSearchStatus("loading");
    try {
      const results = await searchHaiphongPlaces(query, controller.signal);
      setDrawPlaceResults(results);
      setDrawPlaceSearchStatus(results.length > 0 ? "idle" : "empty");
    } catch (error) {
      if ((error as DOMException).name !== "AbortError") {
        setDrawPlaceResults([]);
        setDrawPlaceSearchStatus("error");
      }
    }
  };

  const clearDrawPlaceSearch = () => {
    drawPlaceSearchController.current?.abort();
    setDrawPlaceQuery("");
    setDrawPlaceResults([]);
    setDrawPlaceSearchStatus("idle");
    store.setDrawSearchTarget(null);
  };

  return (
    <section className="panel-section zone-panel">
      <div className="section-heading">
        <div><span className="eyebrow">GEOFENCE</span><h2>Khoanh vùng</h2></div>
        <span className="status-live">{administrativeStatus === "ready" ? "114 đơn vị" : "Đang tải"}</span>
      </div>

      <div className="zone-tabs">
        {tabs.map((tab) => <button key={tab.mode} className={zoneMode === tab.mode ? "active" : ""} onClick={() => store.setZoneMode(tab.mode)}>{tab.label}</button>)}
      </div>

      <div className={`zone-color-controls ${showColorPresets ? "expanded" : ""}`}>
        <div className="zone-color-row">
          <button className="zone-color-toggle" type="button" aria-expanded={showColorPresets} onClick={() => setShowColorPresets((visible) => !visible)}>
            <Palette size={14}/> {editingAdministrativeStyle ? "Màu địa giới" : "Màu tự vẽ"}
          </button>
          <label>Nền <input type="color" value={zoneFillColor} onChange={(event) => setZoneFillColor(event.target.value)}/></label>
          <label>Viền <input type="color" value={zoneOutlineColor} onChange={(event) => setZoneOutlineColor(event.target.value)}/></label>
        </div>
        {showColorPresets && (
          <>
            <div className="zone-color-presets" aria-label="Màu vùng gợi ý">
              {zoneColorPresets.map((preset) => {
                const selected = zoneFillColor.toLowerCase() === preset.fill && zoneOutlineColor.toLowerCase() === preset.outline;
                return (
                  <button
                    key={preset.name}
                    type="button"
                    className={selected ? "active" : ""}
                    title={preset.name}
                    aria-label={`Chọn màu ${preset.name}`}
                    onClick={() => { setZoneFillColor(preset.fill); setZoneOutlineColor(preset.outline); }}
                  >
                    <span style={{ backgroundColor: preset.fill, borderColor: preset.outline }}/>
                  </button>
                );
              })}
            </div>
            <label className="zone-opacity-control">
              <span>Độ trong suốt</span>
              <input
                type="range"
                min="0"
                max="95"
                step="1"
                value={zoneTransparency}
                onChange={(event) => setZoneFillOpacity(1 - Number(event.target.value) / 100)}
              />
              <strong>{zoneTransparency}%</strong>
            </label>
          </>
        )}
      </div>

      {zoneMode === "administrative" && (
        <>
          <label className="outside-mask-toggle">
            <span><strong>Làm mờ ngoài Hải Phòng</strong><small>Tập trung hiển thị trong ranh giới thành phố</small></span>
            <input type="checkbox" checked={dimOutsideHaiphong} onChange={(event) => store.setDimOutsideHaiphong(event.target.checked)}/>
            <i aria-hidden="true"/>
          </label>
          <p className="muted">Chọn đồng thời nhiều xã, phường hoặc đặc khu để tạo vùng giám sát.</p>
          <label className="zone-search">
            <Search size={15}/>
            <input value={administrativeQuery} onChange={(event) => store.setAdministrativeQuery(event.target.value)} placeholder="Tìm địa điểm / đơn vị hành chính"/>
            {administrativeQuery && <button onClick={() => store.setAdministrativeQuery("")} aria-label="Xóa tìm kiếm"><X size={13}/></button>}
          </label>

          {matchingPlaces.length > 0 && (
            <div className="place-results">
              <span className="result-label">ĐỊA ĐIỂM</span>
              {matchingPlaces.map((place) => (
                <button key={place.name} onClick={() => selectPlace(place.coordinates)}>
                  <MapPin size={14}/><span><strong>{place.name}</strong><small>{place.detail}</small></span>
                </button>
              ))}
            </div>
          )}

          {selectedUnits.length > 0 && (
            <div className="selected-admin-units">
              <span>ĐÃ CHỌN · {selectedUnits.length}</span>
              <div>{selectedUnits.map((unit) => <button key={unit.id} onClick={() => store.removeAdministrativeUnit(unit.id)}>{unit.name}<X size={11}/></button>)}</div>
            </div>
          )}

          <div className="admin-list-head">
            <span>{filteredUnits.length} kết quả</span>
            {selectedAdministrativeIds.length > 0 && <button onClick={store.clearAdministrativeSelection}><Trash2 size={13}/> Xóa đã chọn ({selectedAdministrativeIds.length})</button>}
          </div>
          <div className="admin-list">
            {administrativeStatus === "loading" && <div className="panel-message">Đang tải ranh giới chính thức…</div>}
            {administrativeStatus === "error" && <div className="panel-message error">Không tải được dữ liệu. Kiểm tra kết nối nguồn bản đồ số Hải Phòng.</div>}
            {filteredUnits.map((unit) => {
              const selected = selectedAdministrativeIds.includes(unit.id);
              return (
                <button key={unit.id} className={`${selected ? "selected" : ""} ${focusedAdministrativeId === unit.id ? "focused" : ""}`} onClick={() => store.cycleAdministrativeUnit(unit.id)}>
                  <span className="admin-check">{selected && <Check size={12}/>}</span>
                  <span><strong>{unit.name}</strong><small>{unit.type}</small></span>
                </button>
              );
            })}
          </div>
          <button className="primary-button" disabled={selectedAdministrativeIds.length === 0}><Save size={16}/> Lưu {selectedAdministrativeIds.length || ""} vùng địa giới</button>
        </>
      )}

      {zoneMode === "draw" && (
        <>
          <p className="muted">Tìm địa điểm làm mốc, sau đó vẽ và hiệu chỉnh nhiều vùng trực tiếp trên bản đồ.</p>
          <form className="draw-place-search" onSubmit={submitDrawPlaceSearch}>
            <label>
              <Search size={15}/>
              <input
                value={drawPlaceQuery}
                onChange={(event) => setDrawPlaceQuery(event.target.value)}
                placeholder="Tìm địa danh, tuyến đường, địa điểm..."
                aria-label="Tìm địa điểm để bắt đầu vẽ"
              />
              {drawPlaceQuery && <button type="button" className="draw-search-clear" onClick={clearDrawPlaceSearch} aria-label="Xóa tìm kiếm"><X size={13}/></button>}
            </label>
            <button type="submit" className="draw-search-submit" disabled={drawPlaceSearchStatus === "loading"}>
              {drawPlaceSearchStatus === "loading" ? <LoaderCircle className="spin" size={14}/> : <Search size={14}/>} Tìm
            </button>
          </form>
          {drawPlaceSearchStatus === "empty" && <div className="draw-search-message">Không tìm thấy kết quả phù hợp trong phạm vi Hải Phòng.</div>}
          {drawPlaceSearchStatus === "error" && <div className="draw-search-message error">Không thể kết nối dịch vụ tìm kiếm. Vui lòng thử lại.</div>}
          {drawPlaceResults.length > 0 && (
            <div className="place-results draw-place-results">
              <span className="result-label">KẾT QUẢ TÌM KIẾM</span>
              {drawPlaceResults.map((place) => (
                <button key={place.id} type="button" className={drawSearchTarget?.id === place.id ? "active" : ""} onClick={() => store.setDrawSearchTarget(place)}>
                  <MapPin size={14}/>
                  <span><strong>{place.name}</strong><small><em>{place.category}</em>{place.detail}</small></span>
                </button>
              ))}
              <small className="search-attribution">Dữ liệu © OpenStreetMap contributors</small>
            </div>
          )}
          <div className="draw-grid">
            {drawTools.map(({ mode, label, icon: Icon }) => (
              <button key={mode} className={`draw-tool ${drawMode === mode ? "active" : ""}`} onClick={() => store.setDrawMode(drawMode === mode ? null : mode)}>
                <Icon size={20}/><span>{label}</span>
              </button>
            ))}
          </div>
          {drawMode === "multilinestring" && (
            <div className="instruction-card multiline-instruction"><Route size={18}/><div><strong>Vẽ tuyến nhiều đoạn</strong><small>Click lần lượt các đỉnh, nhấn Enter để hoàn tất. Sau đó kéo đường để di chuyển toàn tuyến hoặc kéo từng điểm trắng để hiệu chỉnh.</small></div></div>
          )}
          {drawMode === "text" && (
            <label className="text-draw-editor">
              <span>Nội dung nhãn</span>
              <input value={textDraft} maxLength={80} onChange={(event) => store.setTextDraft(event.target.value)} placeholder="Nhập nội dung rồi click lên bản đồ"/>
              <small>Click một vị trí trên bản đồ để đặt nhãn. Sau khi đặt, con trỏ tự trở về Chọn / sửa.</small>
            </label>
          )}
          {drawMode === "icon" && (
            <div className="icon-draw-editor">
              <span>CHỌN BIỂU TƯỢNG BẢN ĐỒ</span>
              <div className="map-icon-grid">
                {mapIconOptions.map(({ key, label, icon: Icon }) => (
                  <button key={key} className={iconDraft === key ? "active" : ""} onClick={() => store.setIconDraft(key)} title={label}>
                    <Icon size={18}/><small>{label}</small>
                  </button>
                ))}
              </div>
              <small>Chọn biểu tượng rồi click một vị trí trên bản đồ để đặt. Con trỏ sẽ tự trở về Chọn / sửa.</small>
            </div>
          )}
          {selectedAnnotation && (selectedText || selectedIcon) && (
            <div className="annotation-editor">
              <div className="annotation-editor-head">
                <span><MousePointer2 size={14}/> {selectedText ? "TEXT ĐANG CHỌN" : "ICON ĐANG CHỌN"}</span>
                <button type="button" onClick={store.deleteSelectedAnnotation} aria-label="Xóa nhãn hoặc icon đang chọn"><Trash2 size={14}/></button>
              </div>
              {selectedText && (
                <label>
                  <span>Nội dung</span>
                  <input value={selectedText.text} maxLength={80} onChange={(event) => store.updateSelectedAnnotationText(event.target.value)}/>
                </label>
              )}
              {selectedIcon && (
                <div className="map-icon-grid annotation-icon-grid">
                  {mapIconOptions.map(({ key, label, icon: Icon }) => (
                    <button key={key} className={selectedIcon.icon === key ? "active" : ""} onClick={() => store.updateSelectedAnnotationIcon(key)} title={label}>
                      <Icon size={17}/><small>{label}</small>
                    </button>
                  ))}
                </div>
              )}
              <label className="annotation-color">
                <span>Màu hiển thị</span>
                <input type="color" value={(selectedText ?? selectedIcon)?.color} onChange={(event) => store.updateSelectedAnnotationColor(event.target.value)}/>
              </label>
              <label className="saved-object-name-field">
                <span>Tên đối tượng</span>
                <input value={savedObjectName} maxLength={80} onChange={(event) => setSavedObjectName(event.target.value)} placeholder="Ví dụ: Điểm tập kết số 1"/>
              </label>
              <button className="primary-button" type="button" disabled={!savedObjectName.trim()} onClick={() => store.saveSelectedObject(savedObjectName)}><Save size={16}/> {selectedText?.saved || selectedIcon?.saved ? "Cập nhật đối tượng" : "Lưu đối tượng"}</button>
              <small>Kéo đối tượng trực tiếp trên bản đồ để thay đổi vị trí. Nhấn Delete để xóa.</small>
            </div>
          )}
          <div className="instruction-card"><Shapes size={18}/><div><strong>Cách vẽ vùng</strong><small>Chọn công cụ rồi vẽ trên bản đồ. Khi hoàn tất, bảng Thông tin sẽ tự mở để chỉnh sửa vùng vừa tạo.</small></div></div>
          <button className="danger-button" disabled={selectedDrawFeatureId === null && selectedAnnotation === null} onClick={selectedAnnotation ? store.deleteSelectedAnnotation : store.requestDeleteDrawFeature}><Trash2 size={15}/> Xóa đối tượng đang chọn</button>
          {!selectedAnnotation && <button className="primary-button" disabled={selectedDrawFeatureId === null} onClick={() => store.saveSelectedObject(savedObjectName)}><Save size={16}/> Lưu vùng hiện tại</button>}
        </>
      )}

      {zoneMode === "info" && selectedDrawFeatureId !== null && selectedDrawFeatureInfo && (
        <>
          <p className="muted">Thông tin và thuộc tính của đối tượng vừa vẽ. Màu nền và màu viền phía trên được áp dụng ngay cho riêng vùng này.</p>
          <div className="draw-info-card">
            <span><Info size={17}/> ĐỐI TƯỢNG ĐANG CHỌN</span>
            <strong>{selectedDrawFeatureInfo.kind === "circle" ? "Đường tròn" : selectedDrawFeatureInfo.kind === "rectangle" ? "Hình chữ nhật" : selectedDrawFeatureInfo.kind === "multiline" ? "Multi Line" : selectedDrawFeatureInfo.kind === "line" ? "Đường thẳng" : "Đa giác"}</strong>
            <dl>
              {selectedDrawFeatureInfo.radiusMeters !== undefined && <><dt>Bán kính</dt><dd>{formatRadius(selectedDrawFeatureInfo.radiusMeters)}</dd></>}
              {selectedDrawFeatureInfo.areaSquareMeters !== undefined && <><dt>Diện tích</dt><dd>{formatArea(selectedDrawFeatureInfo.areaSquareMeters)}</dd></>}
              <dt>{selectedDrawFeatureInfo.kind === "multiline" ? "Tổng chiều dài" : selectedDrawFeatureInfo.kind === "line" ? "Độ dài" : "Chu vi"}</dt><dd>{formatRadius(selectedDrawFeatureInfo.perimeterMeters)}</dd>
              <dt>Tâm</dt><dd>{selectedDrawFeatureInfo.center[1].toFixed(5)}, {selectedDrawFeatureInfo.center[0].toFixed(5)}</dd>
            </dl>
          </div>
          <label className="saved-object-name-field">
            <span>Tên đối tượng</span>
            <input value={savedObjectName} maxLength={80} onChange={(event) => setSavedObjectName(event.target.value)} placeholder="Ví dụ: Vùng giám sát trung tâm"/>
          </label>
          {selectedDrawFeatureInfo.kind === "circle" && selectedDrawFeatureInfo.radiusMeters !== undefined && (
            <div className="circle-radius-editor">
              <label className="radius-input"><span>Chỉnh bán kính</span><div><input type="number" min="0.1" max="100" step="0.1" value={Number((selectedDrawFeatureInfo.radiusMeters / 1000).toFixed(1))} onChange={(event) => store.setSelectedCircleRadius(Number(event.target.value) * 1000)}/><b>km</b></div></label>
              <input className="radius-slider" type="range" min="100" max="20000" step="100" value={Math.min(selectedDrawFeatureInfo.radiusMeters, 20000)} onChange={(event) => store.setSelectedCircleRadius(Number(event.target.value))}/>
              <div className="radius-presets">
                {[500, 1000, 2500, 5000].map((value) => <button key={value} className={Math.round(selectedDrawFeatureInfo.radiusMeters ?? 0) === value ? "active" : ""} onClick={() => store.setSelectedCircleRadius(value)}>{formatRadius(value)}</button>)}
              </div>
            </div>
          )}
          <div className="instruction-card"><MousePointer2 size={18}/><div><strong>Có thể chỉnh sửa hình dạng</strong><small>Quay lại Tự vẽ, dùng Chọn / sửa rồi kéo vùng hoặc các điểm điều khiển.</small></div></div>
          <button className="secondary-button" onClick={() => { store.setZoneMode("draw"); store.setDrawMode("select"); }}><MousePointer2 size={15}/> Chỉnh sửa trên bản đồ</button>
          <button className="danger-button" onClick={store.requestDeleteDrawFeature}><Trash2 size={15}/> Xóa đối tượng này</button>
          <button className="primary-button" disabled={!savedObjectName.trim()} onClick={() => store.saveSelectedObject(savedObjectName)}><Save size={16}/> {savedGeometry ? "Cập nhật đối tượng" : "Lưu đối tượng"}</button>
        </>
      )}

      {zoneMode === "info" && selectedDrawFeatureId === null && (
        <div className="panel-message"><Info size={18}/> Chọn một đa giác, chữ nhật, đường tròn, đường thẳng hoặc Multi Line trên bản đồ để xem và chỉnh sửa thông tin.</div>
      )}

      <div className="default-viewport-control">
        <label className="outside-mask-toggle default-viewport-toggle">
          <span><strong>Khung hình mặc định</strong><small>Dùng khung hình đã lưu khi tải lại</small></span>
          <input type="checkbox" checked={defaultViewportEnabled} onChange={(event) => store.setDefaultViewportEnabled(event.target.checked)}/>
          <i aria-hidden="true"/>
        </label>
        {defaultViewportEnabled && (
          <>
            <button className="save-viewport-button" type="button" onClick={store.requestDefaultViewportSave}>
              <Save size={14}/> Chọn khung hình hiện tại
            </button>
            <button
              className="save-viewport-button administrative-viewport-button"
              type="button"
              disabled={selectedUnits.length === 0}
              onClick={() => store.requestDefaultAdministrativeSave(selectedUnits.map((unit) => unit.id))}
              title={selectedUnits.length > 0 ? `Lưu ${selectedUnits.length} địa giới làm bản đồ mặc định` : "Chọn ít nhất một địa giới trước"}
            >
              <MapPin size={14}/> Chọn địa giới hiện tại{selectedUnits.length > 1 ? ` (${selectedUnits.length})` : ""}
            </button>
            <small className="saved-viewport-status">
              {defaultAdministrativeUnits.length > 0
                ? defaultAdministrativeUnits.length === 1
                  ? `Mặc định · ${defaultAdministrativeUnits[0].type} ${defaultAdministrativeUnits[0].name}`
                  : `Mặc định · ${defaultAdministrativeUnits.length} địa giới`
                : defaultViewport
                ? `Đã lưu · Zoom ${defaultViewport.zoom.toFixed(1)}`
                : "Chưa có khung hình được lưu"}
            </small>
          </>
        )}
      </div>
    </section>
  );
}
