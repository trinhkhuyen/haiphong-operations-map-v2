// Trạng thái để khay hệ thống (desktop/main.cjs) đổi màu icon. Agent và tray chạy
// chung một tiến trình Electron nên báo qua sự kiện của `process`, không cần IPC.
export const AGENT_STATE_EVENT = "hnth-agent-state";
const state = { backend: "unknown", monitoring: false, scanning: 0 };

export function setAgentState(patch) {
  Object.assign(state, patch);
  process.emit(AGENT_STATE_EVENT, { ...state });
}
export const getAgentState = () => ({ ...state });
