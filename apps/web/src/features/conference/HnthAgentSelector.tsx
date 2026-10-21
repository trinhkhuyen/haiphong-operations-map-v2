import { Zap } from "lucide-react";
import type { HnthLiveAgent } from "./hnth-types";

/** Chọn Agent dùng cho HNTH (lưu ở backend) và gửi lệnh quét subnet LAN. */
export function HnthAgentSelector({ liveAgents, selectedAgentId, readOnly, switchingAgent, continuousMonitoring, onChooseAgent, scanSubnets, onScanSubnetsChange, isScanning, onScan, error }: {
  liveAgents: HnthLiveAgent[];
  selectedAgentId: string;
  readOnly: boolean;
  switchingAgent: boolean;
  continuousMonitoring: boolean;
  onChooseAgent: (agentId: string) => void;
  scanSubnets: string;
  onScanSubnetsChange: (value: string) => void;
  isScanning: boolean;
  onScan: () => void;
  error: string;
}) {
  return <>
    <label className="hnth-scan-subnets hnth-agent-select"><span>Agent HNTH dùng cho Scan và Giám sát</span><select value={selectedAgentId} onChange={(event) => onChooseAgent(event.target.value)} disabled={!liveAgents.length || readOnly || switchingAgent}>
        {liveAgents.length ? liveAgents.map((agent) => <option key={agent.agentId} value={agent.agentId}>{agent.status === "online" ? "● " : "○ "}{agent.name}{agent.version ? ` · v${agent.version}` : ""} — {agent.status === "online" ? "online" : "mất kết nối"}</option>) : <option value={selectedAgentId}>{selectedAgentId}</option>}
      </select>
      <small>{switchingAgent ? "Đang chuyển agent…" : readOnly ? "Đăng nhập Operator/Admin để đổi Agent." : `${selectedAgentId}${continuousMonitoring ? " · đang Giám sát liên tục; chọn agent khác sẽ chuyển giám sát sang agent đó" : ""}`}</small>
    </label>
    <div className="hnth-scan-controls">
      <label className="hnth-scan-subnets"><span>Subnet LAN</span><input value={scanSubnets} onChange={(event) => onScanSubnetsChange(event.target.value)} placeholder="192.168.1.0/24" /></label>
      <button className="hnth-save" type="button" onClick={onScan} disabled={readOnly || isScanning} title="Gửi lệnh cho agent quét mạng LAN"><Zap size={14}/> {isScanning ? "Đang quét..." : "Scan"}</button>
    </div>
    {error && <p className="agent-error">{error}</p>}
  </>;
}
