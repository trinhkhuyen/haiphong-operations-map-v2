// Nạp dữ liệu nền theo trình tự cố định khi mở/reload trang: địa giới hành chính
// -> camera fit toàn Hải Phòng (initialViewportReady) -> các lớp nghiệp vụ đã bật.
import { useEffect } from "react";
import { useAppStore } from "../core/store";
import { emitAppEvent } from "../core/events";
import type { OperationalLayer } from "../core/types";
import { loadAdministrativeUnits } from "../features/administrative/data-provider";
import { composeHnthLayer, HNTH_LAYER_ID, loadHnthDemoLayer } from "../features/layers/hnth-data-provider";
import { useHnthLiveStore } from "../core/realtime/hnth-live-store";
import { loadOsmOperationalLayers } from "../features/layers/osm-data-provider";
import { loadBundledOperationalLayers } from "../features/layers/sample-data";

export function useOperationalLayerLoader() {
  const enabledLayerKey = useAppStore((state) => Object.entries(state.layerVisibility)
    .filter(([, visible]) => visible)
    .map(([id]) => id)
    .sort()
    .join("|"));
  const contextualAdministrativeKey = useAppStore((state) => [...new Set([
    ...state.selectedAdministrativeIds,
    ...(state.defaultViewportEnabled ? state.defaultAdministrativeIds : []),
  ])].sort((a, b) => a - b).join("|"));
  const initialViewportReady = useAppStore((state) => state.initialViewportReady);

  useEffect(() => {
    const loadCityBoundary = async () => {
      const state = useAppStore.getState();
      if (state.administrativeUnits.length || state.administrativeStatus !== "idle") return;

      state.setAdministrativeStatus("loading");
      try {
        const units = await loadAdministrativeUnits();
        useAppStore.getState().setAdministrativeUnits(units);
      } catch {
        useAppStore.getState().setAdministrativeStatus("error");
      }
    };
    void loadCityBoundary();
  }, []);

  useEffect(() => {
    // Chỉ tải các lớp nghiệp vụ sau khi bản đồ đã fit toàn bộ Hải Phòng.
    // Nhờ vậy lần reload luôn có cùng trình tự: địa giới -> camera/la bàn -> lớp đã lưu.
    if (!initialViewportReady) return;

    const load = async () => {
      const state = useAppStore.getState();
      // UBND là lớp ngữ cảnh của thao tác khoanh địa giới: tự tải khi có vùng
      // được chọn nhưng không ghi đè cấu hình bật/tắt lớp đã lưu của người dùng.
      const hasContextualAdministrativeUnits = state.selectedAdministrativeIds.length > 0
        || (state.defaultViewportEnabled && state.defaultAdministrativeIds.length > 0);
      const contextualIds = hasContextualAdministrativeUnits ? ["government-ubnd"] : [];
      const enabledIds = [...new Set([
        ...state.layers.filter((layer) => state.layerVisibility[layer.id]).map((layer) => layer.id),
        ...contextualIds,
      ])];
      const pendingIds = enabledIds.filter((id) => !state.loadedLayerIds.includes(id) && !state.loadingLayerIds.includes(id));
      if (!pendingIds.length) {
        if (!state.loadingLayerIds.length) state.setOperationalDataStatus(enabledIds.length ? "ready" : "idle");
        return;
      }

      state.markLayersLoading(pendingIds);
      try {
        const bundledLayers = loadBundledOperationalLayers(pendingIds);
        const osmIds = pendingIds.filter((id) => state.layers.find((layer) => layer.id === id)?.source === "openstreetmap");
        let osmLayers: OperationalLayer[] = [];
        if (osmIds.length) {
          let units = useAppStore.getState().administrativeUnits;
          if (!units.length) {
            if (useAppStore.getState().administrativeStatus === "idle") useAppStore.getState().setAdministrativeStatus("loading");
            units = await loadAdministrativeUnits();
            useAppStore.getState().setAdministrativeUnits(units);
          }
          osmLayers = await loadOsmOperationalLayers(units, osmIds);
        }
        const derivedLayers = pendingIds.includes(HNTH_LAYER_ID)
          ? [composeHnthLayer(await loadHnthDemoLayer(), useAppStore.getState().hnthPointOverrides, useHnthLiveStore.getState().catalog, useHnthLiveStore.getState().activeRoster)]
          : [];
        useAppStore.getState().mergeOperationalLayers([...bundledLayers, ...osmLayers, ...derivedLayers]);
        // HnthPanel có thể đã nhận snapshot backend trước khi lớp HNTH được
        // nạp xong. Báo hiệu để panel replay snapshot mới nhất sau lần merge
        // này, tránh F5/reload bị quay lại trạng thái demo/unknown.
        if (pendingIds.includes(HNTH_LAYER_ID)) emitAppEvent("hnth:layer-ready");

        // MapLibre đôi khi nhận source mới trước khi style hoàn tất vòng cập nhật đầu
        // tiên: UI báo layer đang bật nhưng canvas chưa vẽ. Thực hiện đúng chu kỳ
        // tắt -> bật như thao tác thủ công, song chỉ ở runtime nên không đổi cấu hình.
        window.setTimeout(() => {
          const refreshedState = useAppStore.getState();
          // HNTH có snapshot realtime riêng từ backend. Không được tắt/bật
          // lại layer này sau khi snapshot đã được áp dụng, vì thao tác đó
          // tạo lại source GeoJSON và làm mất feature-state line/fill vừa
          // hydrate sau F5. Các layer nền khác vẫn giữ cơ chế refresh cũ.
          const idsToRefresh = pendingIds.filter((id) => id !== HNTH_LAYER_ID && refreshedState.layerVisibility[id]);
          if (!idsToRefresh.length) return;

          // Thực hiện đúng cùng một action với thao tác bấm tắt trên menu. Một
          // số source GeoJSON chỉ bắt đầu render ổn định sau lần đổi state này.
          idsToRefresh.forEach((id) => useAppStore.getState().toggleLayer(id));
          window.setTimeout(() => {
            for (const id of idsToRefresh) {
              const latestState = useAppStore.getState();
              if (!latestState.layerVisibility[id]) latestState.toggleLayer(id);
            }
          }, 120);
        }, 500);
      } catch {
        useAppStore.getState().markLayersFailed(pendingIds);
      }
    };
    void load();
  }, [enabledLayerKey, contextualAdministrativeKey, initialViewportReady]);
}
