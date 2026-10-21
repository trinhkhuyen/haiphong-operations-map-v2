import React from "react";

type PanelErrorBoundaryProps = { children: React.ReactNode };
type PanelErrorBoundaryState = { error: Error | null };

/** Lỗi render của một panel/bản đồ chỉ hiện trong khung đó, không làm trắng cả trang. */
export class PanelErrorBoundary extends React.Component<PanelErrorBoundaryProps, PanelErrorBoundaryState> {
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
