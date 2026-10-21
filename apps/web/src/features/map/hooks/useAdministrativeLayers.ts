// Thêm source/layer địa giới (nền, viền, nhãn, nền tối) và tương tác click/hover.
import { useEffect } from "react";
import type { GeoJSONSource } from "maplibre-gl";
import { bbox, featureCollection } from "@turf/turf";
import type { MultiPolygon, Polygon } from "geojson";
import { useAppStore } from "../../../core/store";
import { unitsToFeatureCollection } from "../../administrative/data-provider";
import { HNTH_LAYER_ID } from "../../layers/hnth-data-provider";
import { SELECTED_ZONE_FILL_OPACITY, OFFICIAL_ADMINISTRATIVE_LABEL_SOURCE_ID, OFFICIAL_ADMINISTRATIVE_LABEL_LAYER_ID, PRIORITY_ADMINISTRATIVE_LABEL_LAYER_ID, buildOfficialAdministrativeLabelPoints, officialAdministrativeLabelsVisible, showAdministrativeConnection, clearAdministrativeConnection, buildOutsideMask } from "../lib/administrative";
import { hasHnthPointAt, showHnthPointPopup } from "../lib/hnth-layer";
import { UBND_POINT_COLORS, raiseOperationalLayers, hasInspectableOperationalFeatureAt } from "../lib/operational-layers";
import { REGIONAL_OPERATIONAL_BOUNDS, restoreHaiphongOverviewIfZoomedOut } from "../lib/viewport";
import type { MapScope } from "./useMapScope";

export function useAdministrativeLayers(context: MapScope) {
  const { mapRef, suppressNextAdministrativeSelectionFitRef, isMapReady, setInspectedAdministrativeId, setInspectedAdministrativeIds, setFixedMapInfo } = context;
  const administrativeUnits = useAppStore((state) => state.administrativeUnits);
  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map || administrativeUnits.length === 0) return;
    const data = unitsToFeatureCollection(administrativeUnits);
    if (!map.getSource("administrative-units")) {
      map.addSource("administrative-units", { type: "geojson", data });
    } else {
      (map.getSource("administrative-units") as GeoJSONSource).setData(data);
    }
    const officialLabelPoints = buildOfficialAdministrativeLabelPoints(administrativeUnits);
    if (!map.getSource(OFFICIAL_ADMINISTRATIVE_LABEL_SOURCE_ID)) {
      map.addSource(OFFICIAL_ADMINISTRATIVE_LABEL_SOURCE_ID, { type: "geojson", data: officialLabelPoints });
    } else {
      (map.getSource(OFFICIAL_ADMINISTRATIVE_LABEL_SOURCE_ID) as GeoJSONSource).setData(officialLabelPoints);
    }
    if (!map.getSource("haiphong-outside-mask")) {
      map.addSource("haiphong-outside-mask", { type: "geojson", data: buildOutsideMask(administrativeUnits) });
    } else {
      (map.getSource("haiphong-outside-mask") as GeoJSONSource).setData(buildOutsideMask(administrativeUnits));
    }
    if (!map.getLayer("haiphong-outside-mask")) {
      map.addLayer({ id: "haiphong-outside-mask", type: "fill", source: "haiphong-outside-mask", layout: { visibility: useAppStore.getState().dimOutsideHaiphong ? "visible" : "none" }, paint: { "fill-color": "#03101a", "fill-opacity": 0.64 } });
    }
    const shouldBindAdministrativeInteractions = !map.getLayer("administrative-fill");
    if (!map.getLayer("administrative-fill")) {
      map.addLayer({ id: "administrative-fill", type: "fill", source: "administrative-units", paint: { "fill-color": "#38bdf8", "fill-opacity": 0.045 } });
    }
    if (!map.getLayer("administrative-line")) {
      map.addLayer({ id: "administrative-line", type: "line", source: "administrative-units", paint: { "line-color": "#73a8bd", "line-width": 0.8, "line-opacity": 0.42 } });
    }
    const administrativeLabelVisibility = officialAdministrativeLabelsVisible(useAppStore.getState().baseMapMode) ? "visible" : "none";
    if (!map.getLayer(OFFICIAL_ADMINISTRATIVE_LABEL_LAYER_ID)) {
      map.addLayer({
        id: OFFICIAL_ADMINISTRATIVE_LABEL_LAYER_ID,
        type: "symbol",
        source: OFFICIAL_ADMINISTRATIVE_LABEL_SOURCE_ID,
        minzoom: 8,
        filter: ["==", ["get", "priority"], false],
        layout: {
          visibility: administrativeLabelVisibility,
          "text-field": ["concat", ["get", "shortType"], ". ", ["get", "name"]],
          "text-font": ["Noto Sans Regular"],
          "text-size": ["interpolate", ["linear"], ["zoom"], 8, 9.5, 11, 12],
          "text-offset": [0, 1.05],
          "text-anchor": "top",
          "text-max-width": 10,
          "text-allow-overlap": false,
          "text-ignore-placement": false,
        },
        paint: {
          "text-color": "#f8fafc",
          "text-halo-color": "#07131e",
          "text-halo-width": 1.6,
          "text-halo-blur": 0.4,
        },
      });
    }
    if (!map.getLayer(PRIORITY_ADMINISTRATIVE_LABEL_LAYER_ID)) {
      map.addLayer({
        id: PRIORITY_ADMINISTRATIVE_LABEL_LAYER_ID,
        type: "symbol",
        source: OFFICIAL_ADMINISTRATIVE_LABEL_SOURCE_ID,
        minzoom: 7.5,
        filter: ["==", ["get", "priority"], true],
        layout: {
          visibility: administrativeLabelVisibility,
          "text-field": ["concat", ["get", "shortType"], ". ", ["get", "name"]],
          "text-font": ["Noto Sans Regular"],
          "text-size": ["interpolate", ["linear"], ["zoom"], 7.5, 10, 11, 12.5],
          // Hai phường Đồ Sơn ở gần nhau: neo nhãn về hai phía đối diện để
          // cả Đồ Sơn và Nam Đồ Sơn luôn đọc được ở khung toàn thành phố.
          "text-anchor": [
            "match", ["get", "name"],
            "Nam Đồ Sơn", "bottom-right",
            "Đồ Sơn", "top-left",
            "top",
          ],
          "text-offset": [0, 0.8],
          "text-max-width": 12,
          "text-allow-overlap": true,
          "text-ignore-placement": false,
        },
        paint: {
          "text-color": "#ffffff",
          "text-halo-color": "#04111b",
          "text-halo-width": 2,
          "text-halo-blur": 0.45,
        },
      });
    }
    if (!map.getLayer("administrative-selected")) {
      const preferences = useAppStore.getState();
      map.addLayer({ id: "administrative-selected", type: "fill", source: "administrative-units", filter: ["==", ["get", "id"], -1], paint: { "fill-color": preferences.administrativeFillColor, "fill-opacity": preferences.administrativeFillOpacity, "fill-outline-color": preferences.administrativeOutlineColor } });
    }
    if (!map.getLayer("administrative-selected-line")) {
      map.addLayer({ id: "administrative-selected-line", type: "line", source: "administrative-units", filter: ["==", ["get", "id"], -1], paint: { "line-color": useAppStore.getState().administrativeOutlineColor, "line-width": 2.8, "line-opacity": 1, "line-dasharray": [3, 2] } });
    }
    if (!map.getLayer("administrative-focused")) {
      map.addLayer({ id: "administrative-focused", type: "fill", source: "administrative-units", filter: ["==", ["get", "id"], -1], paint: { "fill-color": "#ffffff", "fill-opacity": SELECTED_ZONE_FILL_OPACITY } });
    }
    if (!map.getLayer("administrative-focused-line")) {
      map.addLayer({ id: "administrative-focused-line", type: "line", source: "administrative-units", filter: ["==", ["get", "id"], -1], paint: { "line-color": "#ffffff", "line-width": 3.4, "line-opacity": 1, "line-dasharray": [3, 2] } });
    }
    if (!map.getLayer("administrative-inspected-line")) {
      // Viền xem địa giới dùng riêng cho menu Lớp đối tượng và HNTH. Đây là
      // đường trắng liền, mảnh và không thêm địa giới vào vùng của Khoanh vùng.
      map.addLayer({ id: "administrative-inspected-line", type: "line", source: "administrative-units", filter: ["==", ["get", "id"], -1], paint: { "line-color": "#ffffff", "line-width": 1.1, "line-opacity": 1 } });
    }
    if (!map.getLayer("administrative-hnth-hover-line")) {
      // Chỉ menu HNTH dùng lớp này: địa giới dưới con trỏ có viền trắng mảnh;
      // filter luôn chỉ chứa một id nên khi rê sang nơi khác, viền cũ tự mất.
      map.addLayer({ id: "administrative-hnth-hover-line", type: "line", source: "administrative-units", filter: ["==", ["get", "id"], -1], paint: { "line-color": "#ffffff", "line-width": 1.1, "line-opacity": 0.95 } });
    }
    if (!map.getSource("administrative-focus-connection")) {
      map.addSource("administrative-focus-connection", { type: "geojson", data: featureCollection([]) });
    }
    if (!map.getLayer("administrative-focus-connection-casing")) {
      map.addLayer({ id: "administrative-focus-connection-casing", type: "line", source: "administrative-focus-connection", filter: ["==", ["geometry-type"], "LineString"], paint: { "line-color": "#06131d", "line-width": 5.5, "line-opacity": 0.88 } });
    }
    if (!map.getLayer("administrative-focus-connection-line")) {
      map.addLayer({ id: "administrative-focus-connection-line", type: "line", source: "administrative-focus-connection", filter: ["==", ["geometry-type"], "LineString"], paint: { "line-color": "#2dd4bf", "line-width": 2.6, "line-opacity": 1 } });
    }
    if (!map.getLayer("administrative-focus-connection-point")) {
      map.addLayer({
        id: "administrative-focus-connection-point",
        type: "circle",
        source: "administrative-focus-connection",
        filter: ["==", ["geometry-type"], "Point"],
        paint: {
          "circle-radius": 5,
          // Đồng bộ màu điểm đại diện với lớp UBND: xã xanh ngọc, phường
          // xanh dương và đặc khu tím nhạt.
          "circle-color": [
            "match", ["get", "administrativeType"],
            "xã", UBND_POINT_COLORS.xã,
            "phường", UBND_POINT_COLORS.phường,
            "đặc khu", UBND_POINT_COLORS["đặc khu"],
            UBND_POINT_COLORS.xã,
          ],
          "circle-stroke-color": "#ffffff",
          "circle-stroke-width": 2.2,
        },
      });
    }
    if (shouldBindAdministrativeInteractions) {
      map.on("click", "administrative-fill", (event) => {
        const state = useAppStore.getState();
        const id = Number(event.features?.[0]?.properties?.id);
        if (!id) return;
        const clickedUnit = state.administrativeUnits.find((candidate) => candidate.id === id);
        const restoredCityOverview = clickedUnit?.name.trim().toLocaleLowerCase("vi") === "bạch long vĩ"
          ? false
          : restoreHaiphongOverviewIfZoomedOut(map);
        if (state.activePanel === "conference") {
          // Trên mobile, chạm vào địa giới là thao tác chọn/khoanh vùng trước
          // hết; không mở thẻ chi tiết endpoint che mất phần lớn bản đồ.
          if (window.matchMedia("(max-width: 760px)").matches && clickedUnit) {
            map.setMaxBounds(REGIONAL_OPERATIONAL_BOUNDS);
            setInspectedAdministrativeId(id);
            setInspectedAdministrativeIds([id]);
            // Mobile chỉ giữ viền khoanh vùng, không mở popup chi tiết kết nối.
            setFixedMapInfo(null);
            clearAdministrativeConnection(map);
            const unitBounds = bbox(clickedUnit.geometry as Polygon | MultiPolygon);
            map.fitBounds([[unitBounds[0], unitBounds[1]], [unitBounds[2], unitBounds[3]]], { padding: 56, maxZoom: 12, duration: 700 });
            return;
          }
          // Trong menu HNTH, toàn bộ mặt địa giới là vùng tương tác của điểm
          // nhánh. Nhờ vậy người dùng không cần bấm chính xác vào chấm tròn.
          // Nếu bấm ngay trên chấm thì để handler của chấm xử lý, tránh mở 2 popup.
          if (hasHnthPointAt(map, event.point)) return;
          const wardCode = String(event.features?.[0]?.properties?.wardCode ?? "");
          const hnthLayer = state.layers.find((item) => item.id === HNTH_LAYER_ID);
          const branch = hnthLayer?.data.features.find((item) => (
            item.geometry.type === "Point"
            && item.properties?.role === "branch"
            && String(item.properties?.wardCode ?? "") === wardCode
          ));
          if (branch?.geometry.type === "Point") {
            showHnthPointPopup(map, branch.geometry.coordinates as [number, number], branch.properties);
          }
          return;
        }
        if (state.activePanel === "zones" && state.zoneMode === "administrative") {
          // Khi click từ mức zoom-out rộng hơn thành phố, ưu tiên dừng ở khung
          // toàn Hải Phòng thay vì lập tức phóng tiếp vào riêng địa giới vừa chọn.
          suppressNextAdministrativeSelectionFitRef.current = restoredCityOverview && !window.matchMedia("(max-width: 760px)").matches;
          const wasFocused = state.focusedAdministrativeId === id;
          state.cycleAdministrativeUnit(id);
          if (wasFocused) {
            setFixedMapInfo(null);
            clearAdministrativeConnection(map);
            return;
          }
          const unit = clickedUnit;
          if (unit) {
            setFixedMapInfo({ kind: "administrative", unitId: unit.id, includeConnectionPoint: false });
            showAdministrativeConnection(map, unit);
          }
          return;
        }

        // Ở các menu còn lại, click vào phần nền của địa giới sẽ mở thông tin
        // xã/phường/đặc khu. Nếu đang click đúng một đối tượng nghiệp vụ thì để
        // popup của đối tượng đó xử lý, tránh hai popup xuất hiện cùng lúc.
        if (hasInspectableOperationalFeatureAt(map, event.point)) return;
        const unit = clickedUnit;
        if (!unit) return;
        if (state.activePanel === "layers") {
          setInspectedAdministrativeId(id);
          setInspectedAdministrativeIds([id]);
        }
        setFixedMapInfo({ kind: "administrative", unitId: unit.id, includeConnectionPoint: false });
        showAdministrativeConnection(map, unit);
      });
      map.on("mouseenter", "administrative-fill", () => {
        map.getCanvas().style.cursor = "pointer";
      });
      map.on("mousemove", "administrative-fill", (event) => {
        if (useAppStore.getState().activePanel !== "conference") return;
        const hoveredId = Number(event.features?.[0]?.properties?.id);
        if (!hoveredId || !map.getLayer("administrative-hnth-hover-line")) return;
        map.setFilter("administrative-hnth-hover-line", ["==", ["get", "id"], hoveredId]);
        map.moveLayer("administrative-hnth-hover-line");
      });
      map.on("mouseleave", "administrative-fill", () => {
        map.getCanvas().style.cursor = "";
        if (map.getLayer("administrative-hnth-hover-line")) {
          map.setFilter("administrative-hnth-hover-line", ["==", ["get", "id"], -1]);
        }
      });
    }
    // Hiệu ứng địa giới được tạo sau dữ liệu nghiệp vụ; đưa các lớp đang bật
    // trở lại trên cùng để đường/điểm không bị lớp làm mờ che khuất.
    if (map.getLayer("vietnam-province-boundaries")) map.moveLayer("vietnam-province-boundaries");
    raiseOperationalLayers(map, useAppStore.getState().layers);
    if (map.getLayer(OFFICIAL_ADMINISTRATIVE_LABEL_LAYER_ID)) map.moveLayer(OFFICIAL_ADMINISTRATIVE_LABEL_LAYER_ID);
    if (map.getLayer(PRIORITY_ADMINISTRATIVE_LABEL_LAYER_ID)) map.moveLayer(PRIORITY_ADMINISTRATIVE_LABEL_LAYER_ID);
  }, [administrativeUnits, isMapReady]);
}
