import { lazy, Suspense, useEffect, useState } from "react";
import { Bell, FolderOpen, Layers3, MapPinned, Menu, Pentagon, RadioTower, Route, ShieldCheck, Server } from "lucide-react";
import { useAppStore } from "../core/store";
import { emitAppEvent } from "../core/events";
import { MapCanvas } from "../features/map/MapCanvas";
import { HnthPanel } from "../features/conference/HnthPanel";
import { HnthStatusMetrics } from "../features/conference/HnthStatusMetrics";
import { AuthModal } from "../features/auth/AuthModal";
import { LoginGate } from "../features/auth/LoginGate";
import { UserMenu } from "../features/auth/UserMenu";
import { useAuth } from "../features/auth/useAuth";
import { GlobalSearch } from "./GlobalSearch";
import { PanelErrorBoundary } from "./PanelErrorBoundary";
import { SystemStatusBar } from "./SystemStatusBar";
import { MapTitleClock } from "./MapTitleClock";
import { useOperationalLayerLoader } from "./useOperationalLayerLoader";

// Các panel không mở mặc định được tải khi mở lần đầu (HnthPanel luôn mount nên
// nằm trong bundle chính).
const LayerPanel = lazy(() => import("../features/layers/LayerPanel").then((module) => ({ default: module.LayerPanel })));
const ZonePanel = lazy(() => import("../features/zones/ZonePanel").then((module) => ({ default: module.ZonePanel })));
const SavedObjectsPanel = lazy(() => import("../features/saved-objects/SavedObjectsPanel").then((module) => ({ default: module.SavedObjectsPanel })));
const RoutingPanel = lazy(() => import("../features/routing/RoutingPanel").then((module) => ({ default: module.RoutingPanel })));
const AgentsPanel = lazy(() => import("../features/agents/AgentsPanel").then((module) => ({ default: module.AgentsPanel })));
const UserAdminPanel = lazy(() => import("../features/admin/UserAdminPanel").then((module) => ({ default: module.UserAdminPanel })));

type PanelId = "layers" | "zones" | "saved" | "routing" | "conference" | "agents";

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
  const auth = useAuth();
  const { user, canSeeMenu } = auth;
  const activePanel = useAppStore((state) => state.activePanel);
  const setActivePanel = useAppStore((state) => state.setActivePanel);
  const administrativeUnits = useAppStore((state) => state.administrativeUnits);
  const defaultViewportEnabled = useAppStore((state) => state.defaultViewportEnabled);
  const defaultAdministrativeIds = useAppStore((state) => state.defaultAdministrativeIds);
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

  const openSidebarPanel = (panel?: PanelId) => {
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

  // Phím 9: đóng/mở menu bên trái, giống nút ☰ trên thanh rail.
  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement | null;
      if (event.key !== "9" || target?.isContentEditable || target?.tagName === "INPUT" || target?.tagName === "TEXTAREA" || target?.tagName === "SELECT") return;
      event.preventDefault();
      setIsSidebarCollapsed((collapsed) => !collapsed);
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, []);

  useOperationalLayerLoader();

  const railButton = (panel: PanelId, label: string, icon: React.ReactNode) => canSeeMenu(panel)
    && <button className={activePanel === panel ? "active" : ""} onClick={() => openSidebarPanel(panel)} aria-label={label} title={label}>{icon}</button>;

  return <LoginGate><main className={`app-shell${isSidebarCollapsed ? " sidebar-collapsed" : ""}${isPresentationMode ? " presentation-client" : ""}`}>
      <header className="topbar">
        <div className="brand"><div className="brand-mark"><MapPinned size={22}/></div><div><strong>BẢN ĐỒ GIÁM SÁT TP HẢI PHÒNG</strong><span>Trung tâm điều hành</span></div></div>
        <GlobalSearch />
        <SystemStatusBar />
        <button className="icon-button"><Bell size={19}/><i/></button>
        <UserMenu auth={auth} />
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
          {railButton("layers", "Lớp dữ liệu", <Layers3 size={20}/>)}
          {railButton("zones", "Khoanh vùng", <Pentagon size={20}/>)}
          {railButton("saved", "Đối tượng đã lưu", <FolderOpen size={20}/>)}
          {railButton("routing", "Định tuyến", <Route size={20}/>)}
          {railButton("conference", "Hội nghị truyền hình", <RadioTower size={20}/>)}
          {railButton("agents", "Quản lý Agents", <Server size={20}/>)}
        </nav>
        {user?.role === "admin" && <button className="rail-shield" onClick={() => setShowUserAdmin(true)} aria-label="Quản trị tài khoản" title="Quản trị tài khoản"><ShieldCheck size={20}/></button>}
      </aside>

      <aside className="side-panel" aria-hidden={isSidebarCollapsed}>
        <Suspense fallback={null}>
          {activePanel === "layers" && <LayerPanel />}
          {activePanel === "zones" && <ZonePanel />}
          {activePanel === "saved" && <SavedObjectsPanel />}
          {activePanel === "routing" && <RoutingPanel />}
        </Suspense>
        <div style={{ display: activePanel === "conference" || isPresentationMode ? undefined : "none" }}><HnthPanel readOnly={isPresentationMode || !user || user.role === "viewer"} canRenewLease={Boolean(user) && user?.role !== "viewer"} /></div>
        {activePanel === "agents" && <PanelErrorBoundary><Suspense fallback={null}><AgentsPanel /></Suspense></PanelErrorBoundary>}
      </aside>

      <section className="map-area">
        <PanelErrorBoundary><MapCanvas /></PanelErrorBoundary>
        <div className="map-title-card"><div className="map-title-info"><span>BẢN ĐỒ VẬN HÀNH</span><strong>{mapOperationTitle}</strong><small>20.8449° N, 106.6881° E</small></div><MapTitleClock /></div>
        <HnthStatusMetrics />
        {showUserAdmin && <Suspense fallback={null}><UserAdminPanel onClose={() => setShowUserAdmin(false)} /></Suspense>}
        <AuthModal auth={auth} />
      </section>
    </main></LoginGate>;
}
