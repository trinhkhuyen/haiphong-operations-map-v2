import React, { useEffect, useState } from "react";
import { Activity, Bell, FolderOpen, Layers3, MapPinned, Menu, Pentagon, RadioTower, Route, Search, ShieldCheck, UserRound, Server } from "lucide-react";
import { useAppStore } from "../core/store";
import { LayerPanel } from "../features/layers/LayerPanel";
import { MapCanvas } from "../features/map/MapCanvas";
import { RoutingPanel } from "../features/routing/RoutingPanel";
import { ZonePanel } from "../features/zones/ZonePanel";
import { SavedObjectsPanel } from "../features/saved-objects/SavedObjectsPanel";
import { loadAdministrativeUnits } from "../features/administrative/data-provider";
import { loadOsmOperationalLayers } from "../features/layers/osm-data-provider";
import { loadBundledOperationalLayers } from "../features/layers/sample-data";
import { applyHnthPointOverrides, HNTH_LAYER_ID, loadHnthDemoLayer } from "../features/layers/hnth-data-provider";
import { HnthPanel } from "../features/conference/HnthPanel";
import { HnthStatusMetrics } from "../features/conference/HnthStatusMetrics";
import { emitAppEvent, onAppEvent } from "../core/events";
import { subscribeHnthSnapshots } from "../core/realtime/hnth-realtime";
import { useHnthLiveStore } from "../core/realtime/hnth-live-store";
import type { OperationalLayer } from "../core/types";
import { backendEnabled, changePassword, getCurrentUser, login, logout, refresh, updateProfile, type AuthUser } from "../core/auth";
import { UserAdminPanel } from "../features/admin/UserAdminPanel";
import { AgentsPanel } from "../features/agents/AgentsPanel";
import { searchHaiphongPlaces, type PlaceSearchResult } from "../features/search/geocoding-provider";

type PanelErrorBoundaryProps = { children: React.ReactNode };
type PanelErrorBoundaryState = { error: Error | null };

class PanelErrorBoundary extends React.Component<PanelErrorBoundaryProps, PanelErrorBoundaryState> {
  state: PanelErrorBoundaryState = { error: null };

  static getDerivedStateFromError(error: Error): PanelErrorBoundaryState {
    return { error };
  }

  componentDidCatch(error: Error) {
    console.error("Panel render error", error);
  }

  render() {
    if (this.state.error) {
          return <section className="panel-section agent-error" style={{ position: "absolute", inset: 16, zIndex: 20, overflow: "auto" }}>
        <strong>Không thể mở mục này</strong>
            <pre style={{ whiteSpace: "pre-wrap", overflowWrap: "anywhere", margin: "12px 0", color: "#ffd6d6" }}>{this.state.error.stack || this.state.error.message || "Lỗi render không xác định"}</pre>
        <button className="secondary-button" onClick={() => this.setState({ error: null })}>Thử lại</button>
      </section>;
    }
    return this.props.children;
  }
}

function LoginGate({ children }: { children: React.ReactNode }) {
  useEffect(() => {
    if (backendEnabled) void refresh();
  }, []);
  return <>{children}</>;
}

export function App() {
  // Trình chiếu là một client bản đồ độc lập. Nó dùng chính App/MapCanvas và
  // cùng luồng realtime như Guest, thay vì nhận ảnh chụp từ tab điều khiển.
  const presentationRequested = new URLSearchParams(window.location.search).get("presentation") === "1";
  // Presentation windows are desktop-only. Require the popup opener as well,
  // so a copied/stale presentation URL can never hide the normal app shell.
  const isMobileDevice = /Android|iPhone|iPad|iPod/i.test(navigator.userAgent)
    || window.matchMedia("(max-width: 760px)").matches;
  const isPresentationMode = presentationRequested && Boolean(window.opener) && !isMobileDevice;
  const [isSidebarCollapsed, setIsSidebarCollapsed] = useState(() => window.matchMedia("(max-width: 760px)").matches);
  const [showUserAdmin, setShowUserAdmin] = useState(false);
  const [userMenuOpen, setUserMenuOpen] = useState(false);
  const [user, setUser] = useState<AuthUser | null>(getCurrentUser());
  const [authModal, setAuthModal] = useState<"login" | "password" | "profile" | null>(null);
  const [authError, setAuthError] = useState("");
  const [authFields, setAuthFields] = useState({ username: "admin", password: "", currentPassword: "", newPassword: "", displayName: "", department: "", phone: "" });
  // Trạng thái Backend và Agent đang chọn cho HNTH do core/realtime cập nhật
  // từ snapshot monitor-state và SSE (một nguồn cho cả trang).
  const backendState = useHnthLiveStore((state) => state.backend);
  const backendCheckedAtMs = useHnthLiveStore((state) => state.backendCheckedAt);
  const agentState = useHnthLiveStore((state) => state.agent.state);
  const agentCheckedAtMs = useHnthLiveStore((state) => state.agent.checkedAt);
  const agentDisplayName = useHnthLiveStore((state) => state.agent.name);
  const backendCheckedAt = backendCheckedAtMs ? new Date(backendCheckedAtMs) : null;
  const agentCheckedAt = agentCheckedAtMs ? new Date(agentCheckedAtMs) : null;
  const [searchResults, setSearchResults] = useState<PlaceSearchResult[]>([]);
  const [searching, setSearching] = useState(false);
  const [searchOpen, setSearchOpen] = useState(false);
  const [searchError, setSearchError] = useState("");
  const activePanel = useAppStore((state) => state.activePanel);
  const setActivePanel = useAppStore((state) => state.setActivePanel);
  const setSearch = useAppStore((state) => state.setSearch);
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
  const administrativeUnits = useAppStore((state) => state.administrativeUnits);
  const defaultViewportEnabled = useAppStore((state) => state.defaultViewportEnabled);
  const defaultAdministrativeIds = useAppStore((state) => state.defaultAdministrativeIds);
  const onlineCameras = 6;
  const defaultAdministrativeUnit = defaultAdministrativeIds.length === 1
    ? administrativeUnits.find((unit) => unit.id === defaultAdministrativeIds[0])
    : undefined;
  const mapOperationTitle = !defaultViewportEnabled || defaultAdministrativeIds.length === 0
    ? "Thành phố Hải Phòng"
    : defaultAdministrativeIds.length > 1
      ? `Cụm ${defaultAdministrativeIds.length} địa giới`
      : defaultAdministrativeUnit
        ? `${defaultAdministrativeUnit.type.charAt(0).toLocaleUpperCase("vi")}${defaultAdministrativeUnit.type.slice(1)} ${defaultAdministrativeUnit.name}`
        : "Thành phố Hải Phòng";

  const searchValue = useAppStore((state) => state.search);
  const runGlobalSearch = async () => {
    const query = searchValue.trim();
    if (!query) { setSearchResults([]); setSearchOpen(false); return; }
    setSearching(true); setSearchError(""); setSearchOpen(true);
    try {
      setSearchResults(await searchHaiphongPlaces(query));
    } catch (error) {
      if ((error as DOMException)?.name !== "AbortError") setSearchError(error instanceof Error ? error.message : "Không tìm được địa điểm");
    } finally { setSearching(false); }
  };

  useEffect(() => {
    if (!isPresentationMode) return;
    setActivePanel("conference");
    setIsSidebarCollapsed(true);
    const timers = [350, 900].map((delay) => window.setTimeout(() => {
      emitAppEvent("map:fit-haiphong-overview");
      window.dispatchEvent(new Event("resize"));
    }, delay));
    return () => timers.forEach((timer) => window.clearTimeout(timer));
  }, [isPresentationMode, setActivePanel]);

  useEffect(() => onAppEvent("hnth:auth-expired", () => setUser(null)), []);
  useEffect(() => onAppEvent("hnth:open-login", () => { setUserMenuOpen(false); setAuthError(""); setAuthModal("login"); }), []);
  const roleLabel = user?.role === "admin" ? "Quản trị hệ thống" : user?.role === "operator" ? "Vận hành" : user ? "Chỉ xem" : "Khách truy cập";
  const canSeeMenu = (menu: string) => !user || user.role !== "viewer" || (user.menuPermissions || []).includes(menu);
  const submitLogin = async (event: React.FormEvent) => { event.preventDefault(); try { const result = await login(authFields.username, authFields.password); setUser(result.user); setAuthModal(null); setAuthError(""); } catch (error) { setAuthError(error instanceof Error ? error.message : "Đăng nhập thất bại"); } };
  const submitProfile = async (event: React.FormEvent) => { event.preventDefault(); try { const updated = await updateProfile({ displayName: authFields.displayName, department: authFields.department, phone: authFields.phone }); setUser(updated); setAuthModal(null); setAuthError(""); } catch (error) { setAuthError(error instanceof Error ? error.message : "Cập nhật thất bại"); } };
  const submitPassword = async (event: React.FormEvent) => { event.preventDefault(); try { await changePassword(authFields.currentPassword, authFields.newPassword); setAuthModal(null); setAuthError(""); window.alert("Đã đổi mật khẩu"); } catch (error) { setAuthError(error instanceof Error ? error.message : "Không đổi được mật khẩu"); } };

  // Status bar cần snapshot ít nhất mỗi 10 giây kể cả khi HnthPanel chưa có điểm.
  useEffect(() => subscribeHnthSnapshots(10000, () => undefined), []);

  const openSidebarPanel = (panel?: "layers" | "zones" | "saved" | "routing" | "conference" | "agents") => {
    if (panel) setActivePanel(panel);
    setIsSidebarCollapsed(false);

    if (panel === "layers" || panel === "conference") {
      // Phát từ chính thao tác click để vẫn hoạt động khi người dùng bấm lại
      // menu đang mở. Chờ một frame để panel mở rộng xong trước khi MapLibre fit.
      window.requestAnimationFrame(() => emitAppEvent("map:fit-haiphong-overview"));
    }
  };

  useEffect(() => {
    // Báo cho MapLibre tính lại kích thước canvas sau khi cột panel đóng/mở.
    const frameId = window.requestAnimationFrame(() => window.dispatchEvent(new Event("resize")));
    return () => window.cancelAnimationFrame(frameId);
  }, [isSidebarCollapsed]);

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
          ? [applyHnthPointOverrides(await loadHnthDemoLayer(), useAppStore.getState().hnthPointOverrides)]
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

  return <LoginGate><main className={`app-shell${isSidebarCollapsed ? " sidebar-collapsed" : ""}${isPresentationMode ? " presentation-client" : ""}`}>
      <header className="topbar">
        <div className="brand"><div className="brand-mark"><MapPinned size={22}/></div><div><strong>BẢN ĐỒ GIÁM SÁT TP HẢI PHÒNG</strong><span>Trung tâm điều hành</span></div></div>
        <div className={`global-search${searchOpen ? " is-open" : ""}`}>
          <Search size={18}/>
          <input value={searchValue} onChange={(event) => { setSearch(event.target.value); setSearchOpen(false); }} onKeyDown={(event) => { if (event.key === "Enter") { event.preventDefault(); void runGlobalSearch(); } if (event.key === "Escape") setSearchOpen(false); }} onFocus={() => { if (searchResults.length || searchError) setSearchOpen(true); }} placeholder="Tìm địa điểm, camera, cơ quan..." aria-label="Tìm địa điểm, camera, cơ quan" />
          <button className="global-search-submit" type="button" onClick={() => void runGlobalSearch()} aria-label="Tìm kiếm"><Search size={15}/></button>
          <kbd>⌘ K</kbd>
          {searchOpen && <div className="global-search-results">
            {searching && <p>Đang tìm kiếm…</p>}
            {!searching && searchError && <p className="error">Không thể tìm kiếm lúc này.</p>}
            {!searching && !searchError && searchResults.length === 0 && <p>Không có kết quả phù hợp.</p>}
            {!searching && searchResults.map((place) => <button key={place.id} type="button" onClick={() => { useAppStore.getState().setDrawSearchTarget(place); setSearchOpen(false); }}><strong>{place.name}</strong><small>{place.category} · {place.detail}</small></button>)}
          </div>}
        </div>
        <div className={`system-state ${backendState}`} title="Trạng thái kết nối Backend"><span className="pulse"/><div><strong>{backendState === "online" ? "Backend đang hoạt động" : backendState === "offline" ? "Backend mất kết nối" : "Đang kiểm tra Backend"}</strong><small>{backendCheckedAt ? `Kiểm tra ${backendCheckedAt.toLocaleTimeString("vi-VN", { hour: "2-digit", minute: "2-digit" })}` : "Chưa có kết quả kiểm tra"}</small></div></div>
        <div className={`system-state agent-state ${agentState}`} title={`Trạng thái ${agentDisplayName}`}><span className="pulse"/><div><strong>{agentState === "online" ? `${agentDisplayName} đang hoạt động` : agentState === "offline" ? `${agentDisplayName} mất kết nối` : `Đang kiểm tra ${agentDisplayName}`}</strong><small>{agentCheckedAt ? `Kiểm tra ${agentCheckedAt.toLocaleTimeString("vi-VN", { hour: "2-digit", minute: "2-digit" })}` : "Chưa có kết quả kiểm tra"}</small></div></div>
        <button className="icon-button"><Bell size={19}/><i/></button>
        <button className="user-chip" onClick={() => setUserMenuOpen((open) => !open)} aria-label="Tài khoản người dùng"><span><UserRound size={17}/></span><div><strong>{user?.displayName || "Guest"}</strong><small>{roleLabel}</small></div></button>
        {userMenuOpen && <div className="user-menu"><strong>{user?.displayName || "Guest"}</strong><small>{user ? `${user.username} · ${roleLabel}` : "Bạn đang sử dụng với quyền Guest"}</small>{user && <><small>Đơn vị: {user.department || "Chưa cập nhật"} · SĐT: {user.phone || "Chưa cập nhật"}</small><button onClick={() => { setUserMenuOpen(false); setAuthFields({ ...authFields, displayName: user.displayName, department: user.department || "", phone: user.phone || "" }); setAuthModal("profile"); setAuthError(""); }}>Chỉnh sửa thông tin</button><button onClick={() => { setUserMenuOpen(false); setAuthModal("password"); setAuthError(""); }}>Đổi mật khẩu</button><button onClick={() => { void logout(); setUser(null); setUserMenuOpen(false); }}>Đăng xuất</button></>}{!user && <button onClick={() => { setUserMenuOpen(false); setAuthModal("login"); setAuthError(""); }}>Đăng nhập</button>}</div>}
      </header>

      <aside className="rail">
        <button
          className="rail-menu"
          onClick={() => setIsSidebarCollapsed((collapsed) => !collapsed)}
          aria-label={isSidebarCollapsed ? "Mở rộng menu" : "Thu gọn menu"}
          aria-expanded={!isSidebarCollapsed}
          title={isSidebarCollapsed ? "Mở rộng menu" : "Thu gọn menu"}
        ><Menu size={21}/></button>
        <nav>
          {canSeeMenu("layers") && <button className={activePanel === "layers" ? "active" : ""} onClick={() => openSidebarPanel("layers")} aria-label="Lớp dữ liệu" title="Lớp dữ liệu"><Layers3 size={20}/></button>}
          {canSeeMenu("zones") && <button className={activePanel === "zones" ? "active" : ""} onClick={() => openSidebarPanel("zones")} aria-label="Khoanh vùng" title="Khoanh vùng"><Pentagon size={20}/></button>}
          {canSeeMenu("saved") && <button className={activePanel === "saved" ? "active" : ""} onClick={() => openSidebarPanel("saved")} aria-label="Đối tượng đã lưu" title="Đối tượng đã lưu"><FolderOpen size={20}/></button>}
          {canSeeMenu("routing") && <button className={activePanel === "routing" ? "active" : ""} onClick={() => openSidebarPanel("routing")} aria-label="Định tuyến" title="Định tuyến"><Route size={20}/></button>}
          {canSeeMenu("conference") && <button className={activePanel === "conference" ? "active" : ""} onClick={() => openSidebarPanel("conference")} aria-label="Hội nghị truyền hình" title="Hội nghị truyền hình"><RadioTower size={20}/></button>}
          {canSeeMenu("agents") && <button className={activePanel === "agents" ? "active" : ""} onClick={() => openSidebarPanel("agents")} aria-label="Quản lý Agents" title="Quản lý Agents"><Server size={20}/></button>}
        </nav>
        {user?.role === "admin" && <button className="rail-shield" onClick={() => setShowUserAdmin(true)} aria-label="Quản trị tài khoản" title="Quản trị tài khoản"><ShieldCheck size={20}/></button>}
      </aside>

      <aside className="side-panel" aria-hidden={isSidebarCollapsed}>
        {activePanel === "layers" && <LayerPanel />}
        {activePanel === "zones" && <ZonePanel />}
        {activePanel === "saved" && <SavedObjectsPanel />}
        {activePanel === "routing" && <RoutingPanel />}
        <div style={{ display: activePanel === "conference" || isPresentationMode ? undefined : "none" }}><HnthPanel readOnly={isPresentationMode || !user || user.role === "viewer"} /></div>
        {activePanel === "agents" && <PanelErrorBoundary><AgentsPanel /></PanelErrorBoundary>}
      </aside>

      <section className="map-area">
        <PanelErrorBoundary><MapCanvas /></PanelErrorBoundary>
        <div className="map-title-card"><span>BẢN ĐỒ VẬN HÀNH</span><strong>{mapOperationTitle}</strong><small>20.8449° N, 106.6881° E</small></div>
        <HnthStatusMetrics />
        {false && <div className="metric-strip">
          <div><span className="metric-icon teal"><Activity size={17}/></span><p><small>CAMERA HOẠT ĐỘNG</small><strong>{onlineCameras}<em>/ 8</em></strong></p></div>
          <div><span className="metric-icon blue"><Pentagon size={17}/></span><p><small>VÙNG GIÁM SÁT</small><strong>2<em> vùng</em></strong></p></div>
          <div><span className="metric-icon amber"><Bell size={17}/></span><p><small>CẢNH BÁO</small><strong>1<em> mới</em></strong></p></div>
        </div>}
        {showUserAdmin && <UserAdminPanel onClose={() => setShowUserAdmin(false)} />}
        {authModal && <div className="auth-overlay"><form className="auth-card" onSubmit={authModal === "login" ? submitLogin : authModal === "profile" ? submitProfile : submitPassword}><h2>{authModal === "login" ? "Đăng nhập" : authModal === "profile" ? "Thông tin tài khoản" : "Đổi mật khẩu"}</h2>{authModal === "login" ? <><input value={authFields.username} onChange={(e) => setAuthFields({ ...authFields, username: e.target.value })} placeholder="Tên đăng nhập" autoComplete="username"/><input value={authFields.password} onChange={(e) => setAuthFields({ ...authFields, password: e.target.value })} placeholder="Mật khẩu" type="password" autoComplete="current-password"/></> : authModal === "profile" ? <><input value={authFields.displayName} onChange={(e) => setAuthFields({ ...authFields, displayName: e.target.value })} placeholder="Họ và tên" required/><input value={user?.username || ""} disabled placeholder="Username"/><input value={authFields.department} onChange={(e) => setAuthFields({ ...authFields, department: e.target.value })} placeholder="Đơn vị"/><input value={authFields.phone} onChange={(e) => setAuthFields({ ...authFields, phone: e.target.value })} placeholder="Số điện thoại"/></> : <><input value={authFields.currentPassword} onChange={(e) => setAuthFields({ ...authFields, currentPassword: e.target.value })} placeholder="Mật khẩu hiện tại" type="password"/><input value={authFields.newPassword} onChange={(e) => setAuthFields({ ...authFields, newPassword: e.target.value })} placeholder="Mật khẩu mới (tối thiểu 8 ký tự)" type="password"/></>}<div className="auth-actions"><button type="button" onClick={() => setAuthModal(null)}>Hủy</button><button className="primary-button" type="submit">{authModal === "login" ? "Đăng nhập" : authModal === "profile" ? "Cập nhật" : "Lưu mật khẩu"}</button></div>{authError && <small className="auth-error">{authError}</small>}</form></div>}
      </section>
    </main></LoginGate>;
}
