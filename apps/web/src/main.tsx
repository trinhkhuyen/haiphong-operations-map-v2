import React, { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "maplibre-gl/dist/maplibre-gl.css";
import "./styles/global.css";
import { App } from "./app/App";

class AppErrorBoundary extends React.Component<{ children: React.ReactNode }, { error: Error | null }> {
  state = { error: null as Error | null };
  static getDerivedStateFromError(error: Error) { return { error }; }
  componentDidCatch(error: Error) { console.error("Application render error", error); }
  render() {
    if (this.state.error) return <main style={{ padding: 32, color: "#e9f7ff", background: "#06131f", minHeight: "100vh", fontFamily: "sans-serif" }}><h1>Không thể tải giao diện</h1><p>{this.state.error.message}</p><button onClick={() => window.location.reload()}>Tải lại</button></main>;
    return this.props.children;
  }
}

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <AppErrorBoundary><App /></AppErrorBoundary>
  </StrictMode>,
);
