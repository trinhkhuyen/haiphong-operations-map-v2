import { beforeEach, describe, expect, it, vi } from "vitest";
import type { OperationalLayer } from "./types";

// Store dùng persist; zustand 5 mặc định đọc `window.localStorage` và nếu không có
// thì tắt hẳn persist (không gắn useAppStore.persist). Cấp bản giả trước khi import
// để persist hoạt động như trên trình duyệt.
const memory = new Map<string, string>();
const localStorageStub = {
  getItem: (key: string) => memory.get(key) ?? null,
  setItem: (key: string, value: string) => { memory.set(key, value); },
  removeItem: (key: string) => { memory.delete(key); },
  clear: () => memory.clear(),
};
vi.stubGlobal("localStorage", localStorageStub);
vi.stubGlobal("window", { localStorage: localStorageStub });
const { useAppStore } = await import("./store");
const { HNTH_LAYER_ID, HNTH_STATUS_LABELS } = await import("../features/layers/hnth-data-provider");

const initialState = useAppStore.getState();
const hnthFeature = (pointId: string, properties: Record<string, unknown> = {}) => ({ type: "Feature" as const, id: pointId, geometry: { type: "Point" as const, coordinates: [106, 20] }, properties: { pointId, ...properties } });

function withHnthFeatures(features: ReturnType<typeof hnthFeature>[]) {
  useAppStore.setState((state) => ({ layers: state.layers.map((layer) => layer.id === HNTH_LAYER_ID ? { ...layer, data: { type: "FeatureCollection", features } } : layer) }));
}
const hnthLayer = () => useAppStore.getState().layers.find((layer) => layer.id === HNTH_LAYER_ID)!;

beforeEach(() => {
  useAppStore.setState(initialState, true);
  memory.clear();
});

describe("persist — hình dạng dữ liệu đã lưu (khóa trước khi tách store)", () => {
  const options = useAppStore.persist.getOptions();

  it("giữ nguyên tên key và version", () => {
    expect(options.name).toBe("haiphong-map-display-preferences");
    expect(options.version).toBe(4);
  });

  it("chỉ lưu đúng các trường này", () => {
    expect(Object.keys(options.partialize!(useAppStore.getState()) as object).sort()).toEqual([
      "administrativeFillColor", "administrativeFillOpacity", "administrativeOutlineColor", "baseMapMode", "clusterLevel",
      "defaultAdministrativeIds", "defaultViewport", "defaultViewportEnabled", "dimOutsideHaiphong",
      "drawFillColor", "drawFillOpacity", "drawOutlineColor",
      "hnthAreaStyles", "hnthAreaVisible", "hnthLineStyles", "hnthLineVisible", "hnthPointOverrides",
      "iconAnnotations", "layerVisibility", "savedDrawFeatures", "textAnnotations",
    ]);
  });

  it("chỉ lưu chú thích chữ/biểu tượng đã bấm lưu", () => {
    useAppStore.setState({
      textAnnotations: [{ id: "t1", text: "A", coordinates: [0, 0], color: "#fff", saved: true }, { id: "t2", text: "B", coordinates: [0, 0], color: "#fff" }],
      iconAnnotations: [{ id: "i1", icon: "police", coordinates: [0, 0], color: "#fff" }],
    });
    const saved = options.partialize!(useAppStore.getState()) as { textAnnotations: { id: string }[]; iconAnnotations: unknown[] };
    expect(saved.textAnnotations.map((item) => item.id)).toEqual(["t1"]);
    expect(saved.iconAnnotations).toEqual([]);
  });

  it("migrate v1: bật lại nền tối ngoài Hải Phòng", () => {
    expect((options.migrate!({ dimOutsideHaiphong: false }, 1) as { dimOutsideHaiphong: boolean }).dimOutsideHaiphong).toBe(true);
    expect((options.migrate!({ dimOutsideHaiphong: false }, 2) as { dimOutsideHaiphong: boolean }).dimOutsideHaiphong).toBe(false);
  });

  it("migrate < v4: mọi điểm HNTH đã lưu về unknown, giữ IP", () => {
    const migrated = options.migrate!({ hnthPointOverrides: { p1: { ipAddress: "10.0.0.1", gateway: "", model: "", status: "disconnected" } } }, 2) as { hnthPointOverrides: Record<string, { ipAddress: string; status: string }> };
    expect(migrated.hnthPointOverrides.p1).toMatchObject({ ipAddress: "10.0.0.1", status: "unknown" });
  });
});

describe("lớp dữ liệu", () => {
  it("toggleLayer bật/tắt và ghi layerVisibility; id lạ không đổi gì", () => {
    const before = useAppStore.getState();
    useAppStore.getState().toggleLayer("khong-ton-tai");
    expect(useAppStore.getState()).toBe(before);
    useAppStore.getState().toggleLayer("hydro-rivers");
    expect(useAppStore.getState().layers.find((layer) => layer.id === "hydro-rivers")?.visible).toBe(true);
    expect(useAppStore.getState().layerVisibility["hydro-rivers"]).toBe(true);
  });

  it("markLayersLoading gộp trùng; markLayersFailed gỡ ra và báo lỗi", () => {
    const { markLayersLoading, markLayersFailed } = useAppStore.getState();
    markLayersLoading(["a", "b"]);
    markLayersLoading(["b", "c"]);
    expect(useAppStore.getState().loadingLayerIds).toEqual(["a", "b", "c"]);
    expect(useAppStore.getState().operationalDataStatus).toBe("loading");
    markLayersFailed(["b"]);
    expect(useAppStore.getState().loadingLayerIds).toEqual(["a", "c"]);
    expect(useAppStore.getState().operationalDataStatus).toBe("error");
  });

  it("mergeOperationalLayers thay dữ liệu nhưng giữ trạng thái bật/tắt của người dùng", () => {
    useAppStore.getState().markLayersLoading(["hydro-rivers"]);
    const current = useAppStore.getState().layers.find((layer) => layer.id === "hydro-rivers")!;
    const incoming: OperationalLayer = { ...current, visible: true, count: 1, data: { type: "FeatureCollection", features: [{ type: "Feature", geometry: { type: "Point", coordinates: [0, 0] }, properties: {} }] } };
    useAppStore.getState().mergeOperationalLayers([incoming]);
    const state = useAppStore.getState();
    const merged = state.layers.find((layer) => layer.id === "hydro-rivers")!;
    expect(merged.count).toBe(1);
    expect(merged.visible).toBe(false);
    expect(state.loadedLayerIds).toContain("hydro-rivers");
    expect(state.loadingLayerIds).toEqual([]);
    expect(state.operationalDataStatus).toBe("ready");
  });
});

describe("địa giới", () => {
  it("toggle / remove bỏ focus của đơn vị bị gỡ", () => {
    const { toggleAdministrativeUnit, removeAdministrativeUnit } = useAppStore.getState();
    toggleAdministrativeUnit(1);
    toggleAdministrativeUnit(2);
    useAppStore.setState({ focusedAdministrativeId: 2 });
    removeAdministrativeUnit(2);
    expect(useAppStore.getState().selectedAdministrativeIds).toEqual([1]);
    expect(useAppStore.getState().focusedAdministrativeId).toBeNull();
    toggleAdministrativeUnit(1);
    expect(useAppStore.getState().selectedAdministrativeIds).toEqual([]);
  });

  it("cycleAdministrativeUnit: chọn → focus → bỏ chọn", () => {
    const cycle = useAppStore.getState().cycleAdministrativeUnit;
    cycle(5);
    expect(useAppStore.getState()).toMatchObject({ selectedAdministrativeIds: [5], focusedAdministrativeId: null });
    cycle(5);
    expect(useAppStore.getState()).toMatchObject({ selectedAdministrativeIds: [5], focusedAdministrativeId: 5 });
    cycle(5);
    expect(useAppStore.getState()).toMatchObject({ selectedAdministrativeIds: [], focusedAdministrativeId: null });
  });
});

describe("điểm HNTH", () => {
  it("updateHnthPoint tạo override từ thuộc tính điểm, gateway mặc định, gắn nhãn", () => {
    withHnthFeatures([hnthFeature("p1", { ipAddress: "10.0.0.1", status: "unknown" })]);
    useAppStore.getState().updateHnthPoint("p1", { status: "lost" });
    expect(useAppStore.getState().hnthPointOverrides.p1).toEqual({ ipAddress: "10.0.0.1", gateway: "192.168.1.1", model: "", status: "lost" });
    expect(hnthLayer().data.features[0].properties).toMatchObject({ status: "lost", statusLabel: HNTH_STATUS_LABELS.lost });
  });

  it("updateHnthPoints không đổi gì thì giữ nguyên state (tránh render lại bản đồ)", () => {
    withHnthFeatures([hnthFeature("p1", { ipAddress: "10.0.0.1", gateway: "192.168.1.1", model: "", status: "unknown" })]);
    const before = useAppStore.getState();
    useAppStore.getState().updateHnthPoints({ p1: { status: "unknown" }, "  ": { status: "lost" } });
    expect(useAppStore.getState()).toBe(before);
  });

  it("updateHnthPoints cập nhật nhiều điểm một lần", () => {
    withHnthFeatures([hnthFeature("p1", { ipAddress: "10.0.0.1" }), hnthFeature("p2", { ipAddress: "10.0.0.2" })]);
    useAppStore.getState().updateHnthPoints({ p1: { status: "unconnected" }, p2: { status: "lost" } });
    const state = useAppStore.getState();
    expect(state.hnthPointOverrides.p1.status).toBe("unconnected");
    expect(state.hnthPointOverrides.p2.status).toBe("lost");
    expect(hnthLayer().data.features.map((feature) => feature.properties?.status)).toEqual(["unconnected", "lost"]);
  });
});
