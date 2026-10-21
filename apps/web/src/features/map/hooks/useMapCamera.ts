// Camera: Home, tổng quan Hải Phòng, khung nhìn mặc định khi mở trang, phím tắt, tìm địa điểm.
import { useCallback, useEffect } from "react";
import maplibregl from "maplibre-gl";
import { bbox } from "@turf/turf";
import { useAppStore } from "../../../core/store";
import { unitsToFeatureCollection } from "../../administrative/data-provider";
import { onAppEvent } from "../../../core/events";
import { HOME_CITY_TRANSITION_DURATION_MS, HOME_CITY_PAUSE_MS, REGIONAL_OPERATIONAL_BOUNDS, setMobileHomePanBounds, MOBILE_HOME_ZOOM_OUT_LEVELS, MOBILE_HOME_PAN_DOWN_PX, fitMobileHomeOverview, getHaiphongOverviewBounds, HAIPHONG_OVERVIEW_PADDING, HAIPHONG_MOBILE_OVERVIEW_PADDING, getHaiphongOverviewPadding, fitHaiphongOverview } from "../lib/viewport";
import type { MapScope } from "./useMapScope";

export function useMapCamera(context: MapScope) {
  const { mapRef, drawSearchMarkerRef, hasSetInitialViewportRef, homeTransitionTimeoutRef, isHomeTransitionActiveRef, isMapReady, isInitialRegionalMapReady } = context;
  const administrativeUnits = useAppStore((state) => state.administrativeUnits);
  const administrativeStatus = useAppStore((state) => state.administrativeStatus);
  const defaultViewportEnabled = useAppStore((state) => state.defaultViewportEnabled);
  const defaultViewport = useAppStore((state) => state.defaultViewport);
  const defaultViewportSaveRequest = useAppStore((state) => state.defaultViewportSaveRequest);
  const defaultAdministrativeIds = useAppStore((state) => state.defaultAdministrativeIds);
  const defaultAdministrativeSaveRequest = useAppStore((state) => state.defaultAdministrativeSaveRequest);
  const drawSearchTarget = useAppStore((state) => state.drawSearchTarget);
  const goHome = useCallback(() => {
    const map = mapRef.current;
    if (!map) return;
    const state = useAppStore.getState();

    if (homeTransitionTimeoutRef.current !== null) {
      window.clearTimeout(homeTransitionTimeoutRef.current);
      homeTransitionTimeoutRef.current = null;
    }
    isHomeTransitionActiveRef.current = false;

    if (state.defaultViewportEnabled && state.defaultViewport) {
      if (state.defaultAdministrativeIds.length > 0) {
        setMobileHomePanBounds(map, state.administrativeUnits);
        if (window.matchMedia("(max-width: 760px)").matches) {
          fitMobileHomeOverview(map, state.administrativeUnits, HOME_CITY_TRANSITION_DURATION_MS);
          return;
        }
        isHomeTransitionActiveRef.current = true;
        fitHaiphongOverview(map, state.administrativeUnits, HOME_CITY_TRANSITION_DURATION_MS);
        homeTransitionTimeoutRef.current = window.setTimeout(() => {
          homeTransitionTimeoutRef.current = null;
          const latestState = useAppStore.getState();
          isHomeTransitionActiveRef.current = false;
          if (!latestState.defaultViewportEnabled || !latestState.defaultViewport || latestState.defaultAdministrativeIds.length === 0) return;
          map.easeTo({ ...latestState.defaultViewport, duration: HOME_CITY_TRANSITION_DURATION_MS });
        }, HOME_CITY_TRANSITION_DURATION_MS + HOME_CITY_PAUSE_MS);
        return;
      }
      map.setMaxBounds(REGIONAL_OPERATIONAL_BOUNDS);
      map.easeTo({ ...state.defaultViewport, duration: 800 });
      return;
    }
    setMobileHomePanBounds(map, state.administrativeUnits);
    fitHaiphongOverview(map, state.administrativeUnits, HOME_CITY_TRANSITION_DURATION_MS);
  }, []);

  const goHomeTilted = useCallback(() => {
    const map = mapRef.current;
    if (!map) return;
    const state = useAppStore.getState();
    const isMobile = window.matchMedia("(max-width: 760px)").matches;

    if (isMobile && state.defaultAdministrativeIds.length > 0) {
      // Tính camera Home trước, sau đó đặt pitch trong cùng một transition.
      // Không gọi goHome() trước để tránh camera bị fitBounds ghi đè rồi mới nghiêng.
      const bounds = getHaiphongOverviewBounds(state.administrativeUnits);
      const homeCamera = map.cameraForBounds(bounds, {
        padding: HAIPHONG_MOBILE_OVERVIEW_PADDING,
        bearing: 0,
        pitch: 0,
      });
      if (!homeCamera?.center) return;
      map.stop();
      map.setMaxBounds(null);
      const zoom = Math.max(map.getMinZoom(), (homeCamera.zoom ?? map.getZoom()) - MOBILE_HOME_ZOOM_OUT_LEVELS);
      const projectedCenter = map.project(homeCamera.center);
      const shiftedCenter = map.unproject([projectedCenter.x, projectedCenter.y + MOBILE_HOME_PAN_DOWN_PX]);
      map.easeTo({ center: shiftedCenter, zoom, pitch: map.getMaxPitch(), bearing: 0, duration: HOME_CITY_TRANSITION_DURATION_MS });
      return;
    }

    if (state.defaultViewport) {
      map.easeTo({ ...state.defaultViewport, pitch: map.getMaxPitch(), bearing: 0, duration: HOME_CITY_TRANSITION_DURATION_MS });
      return;
    }

    const bounds = getHaiphongOverviewBounds(state.administrativeUnits);
    const homeCamera = map.cameraForBounds(bounds, { padding: HAIPHONG_OVERVIEW_PADDING, bearing: 0, pitch: 0 });
    if (homeCamera?.center) map.easeTo({ ...homeCamera, pitch: map.getMaxPitch(), bearing: 0, duration: HOME_CITY_TRANSITION_DURATION_MS });
  }, []);

  useEffect(() => {
    const fitCityOverview = () => {
      const map = mapRef.current;
      if (!map) return;

      if (homeTransitionTimeoutRef.current !== null) {
        window.clearTimeout(homeTransitionTimeoutRef.current);
        homeTransitionTimeoutRef.current = null;
      }
      isHomeTransitionActiveRef.current = false;

      // Menu có thể vừa mở rộng từ trạng thái thu gọn; resize trước để bounds
      // được tính theo đúng kích thước canvas hiện tại.
      map.resize();
      setMobileHomePanBounds(map, useAppStore.getState().administrativeUnits);
      fitHaiphongOverview(map, useAppStore.getState().administrativeUnits, HOME_CITY_TRANSITION_DURATION_MS);
    };

    return onAppEvent("map:fit-haiphong-overview", fitCityOverview);
  }, []);

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement | null;
      if (target?.isContentEditable || target?.tagName === "INPUT" || target?.tagName === "TEXTAREA" || target?.tagName === "SELECT") return;
      if (event.key === "Home" || event.key === "0") {
        event.preventDefault();
        goHome();
        return;
      }
      if (event.key === "2" || event.key === "3") {
        event.preventDefault();
        useAppStore.getState().setBaseMapMode(event.key === "2" ? "satellite" : "standard");
        return;
      }
      if (event.key === "4" || event.key === "5" || event.key === "6") {
        event.preventDefault();
        const state = useAppStore.getState();
        if (event.key === "4") state.setHnthLineVisible(!state.hnthLineVisible);
        if (event.key === "5") state.setHnthAreaVisible(!state.hnthAreaVisible);
        if (event.key === "6") state.setHnthPointVisible(!state.hnthPointVisible);
        return;
      }
      if (event.key === "1") {
        event.preventDefault();
        goHomeTilted();
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [goHome, goHomeTilted]);

  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !isInitialRegionalMapReady || !map || hasSetInitialViewportRef.current) return;

    if (defaultViewportEnabled && defaultViewport) {
      // Chờ dữ liệu địa giới để khung trung gian dùng đúng bounds Hải Phòng.
      // Chỉ dùng bounds dự phòng nếu nguồn địa giới thực sự bị lỗi.
      if (defaultAdministrativeIds.length > 0 && administrativeUnits.length === 0 && administrativeStatus !== "error") return;
      hasSetInitialViewportRef.current = true;
      useAppStore.getState().setInitialViewportReady(true);

      if (defaultAdministrativeIds.length > 0) {
        // Khi khởi động với địa giới/cụm địa giới mặc định, luôn cho người dùng
        // thấy toàn Hải Phòng trong khoảng HOME_CITY_PAUSE_MS trước khi zoom vào khung đã lưu.
        // Chỉ bắt đầu đếm sau sự kiện `idle`: lúc đó bản đồ nền và địa giới ở
        // khung toàn thành phố đã render xong, nên thời gian chờ là thời gian
        // người dùng thực sự nhìn thấy chứ không bị tiêu hao trong lúc reload.
        isHomeTransitionActiveRef.current = true;
        setMobileHomePanBounds(map, administrativeUnits);
        if (window.matchMedia("(max-width: 760px)").matches) {
          fitMobileHomeOverview(map, administrativeUnits, 0);
          isHomeTransitionActiveRef.current = false;
          map.triggerRepaint();
          return;
        }
        fitHaiphongOverview(map, administrativeUnits, 0);
        map.once("idle", () => {
          if (mapRef.current !== map) return;
          homeTransitionTimeoutRef.current = window.setTimeout(() => {
            homeTransitionTimeoutRef.current = null;
            const latestState = useAppStore.getState();
            isHomeTransitionActiveRef.current = false;
            if (!latestState.defaultViewportEnabled || !latestState.defaultViewport || latestState.defaultAdministrativeIds.length === 0) return;
            map.easeTo({ ...latestState.defaultViewport, duration: HOME_CITY_TRANSITION_DURATION_MS });
          }, HOME_CITY_PAUSE_MS);
        });
        map.triggerRepaint();
      } else {
        map.jumpTo(defaultViewport);
      }
      return;
    }

    if (administrativeUnits.length > 0) {
      setMobileHomePanBounds(map, administrativeUnits);
      if (window.matchMedia("(max-width: 760px)").matches) {
        fitMobileHomeOverview(map, administrativeUnits, 0);
      } else {
        fitHaiphongOverview(map, administrativeUnits, 0);
      }
      hasSetInitialViewportRef.current = true;
      useAppStore.getState().setInitialViewportReady(true);
      return;
    }

    if (administrativeStatus === "error") {
      // Fallback khi dịch vụ địa giới tạm lỗi; không chặn vĩnh viễn các lớp đã lưu.
      if (window.matchMedia("(max-width: 760px)").matches) {
        fitMobileHomeOverview(map, [], 0);
      } else {
        fitHaiphongOverview(map, [], 0);
      }
      hasSetInitialViewportRef.current = true;
      useAppStore.getState().setInitialViewportReady(true);
    }
  }, [administrativeUnits, administrativeStatus, defaultAdministrativeIds, defaultViewport, defaultViewportEnabled, isInitialRegionalMapReady, isMapReady]);

  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map || defaultViewportSaveRequest === 0) return;

    // Chỉ chụp khung hình tại đúng thời điểm người dùng bấm nút lưu.
    // Pan/zoom sau đó không được tự động ghi đè khung hình mặc định này.
    const center = map.getCenter();
    useAppStore.getState().setDefaultViewport({
      center: [Number(center.lng.toFixed(6)), Number(center.lat.toFixed(6))],
      zoom: Number(map.getZoom().toFixed(3)),
      bearing: Number(map.getBearing().toFixed(2)),
      pitch: Number(map.getPitch().toFixed(2)),
    });
  }, [defaultViewportSaveRequest, isMapReady]);

  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map || !defaultAdministrativeSaveRequest) return;
    const units = administrativeUnits.filter((candidate) => defaultAdministrativeSaveRequest.ids.includes(candidate.id));
    if (units.length === 0) return;

    const unitBounds = bbox(unitsToFeatureCollection(units));
    map.setBearing(0);
    map.setPitch(0);
    map.fitBounds([[unitBounds[0], unitBounds[1]], [unitBounds[2], unitBounds[3]]], {
      padding: { top: 72, right: 72, bottom: 72, left: 72 },
      maxZoom: 14,
      duration: 0,
    });
    const center = map.getCenter();
    useAppStore.getState().setDefaultAdministrativeViewport(units.map((unit) => unit.id), {
      center: [Number(center.lng.toFixed(6)), Number(center.lat.toFixed(6))],
      zoom: Number(map.getZoom().toFixed(3)),
      bearing: 0,
      pitch: 0,
    });
  }, [administrativeUnits, defaultAdministrativeSaveRequest, isMapReady]);

  useEffect(() => {
    const map = mapRef.current;
    drawSearchMarkerRef.current?.remove();
    drawSearchMarkerRef.current = null;
    if (!map || !drawSearchTarget) return;

    const element = document.createElement("div");
    element.className = "draw-search-map-marker";
    const pin = document.createElement("i");
    pin.setAttribute("aria-hidden", "true");
    const label = document.createElement("span");
    label.textContent = drawSearchTarget.name;
    element.append(pin, label);
    drawSearchMarkerRef.current = new maplibregl.Marker({ element, anchor: "bottom" })
      .setLngLat(drawSearchTarget.coordinates)
      .addTo(map);

    const bounds = drawSearchTarget.bbox;
    if (bounds && Math.abs(bounds[2] - bounds[0]) + Math.abs(bounds[3] - bounds[1]) > 0.0001) {
      map.fitBounds([[bounds[0], bounds[1]], [bounds[2], bounds[3]]], { padding: 110, maxZoom: 17, duration: 850 });
    } else {
      map.flyTo({ center: drawSearchTarget.coordinates, zoom: 16, duration: 850, essential: true });
    }
  }, [drawSearchTarget]);

  // Trên màn hình nhỏ không cho người dùng zoom ra ngoài khung toàn thành phố.
  // Desktop giữ nguyên hành vi MapLibre mặc định.
  useEffect(() => {
    const map = mapRef.current;
    if (!isMapReady || !map) return;
    const mobileQuery = window.matchMedia("(max-width: 760px)");
    const syncMobileMinZoom = () => {
      if (!mobileQuery.matches) { map.setMinZoom(0); return; }
      const overviewCamera = map.cameraForBounds(getHaiphongOverviewBounds(administrativeUnits), { padding: getHaiphongOverviewPadding() });
      map.setMinZoom(Math.max(0, (overviewCamera?.zoom ?? 0) - MOBILE_HOME_ZOOM_OUT_LEVELS));
    };
    syncMobileMinZoom();
    mobileQuery.addEventListener("change", syncMobileMinZoom);
    window.addEventListener("resize", syncMobileMinZoom);
    return () => {
      mobileQuery.removeEventListener("change", syncMobileMinZoom);
      window.removeEventListener("resize", syncMobileMinZoom);
      map.setMinZoom(0);
    };
  }, [administrativeUnits, isMapReady]);
  return { goHome };
}
