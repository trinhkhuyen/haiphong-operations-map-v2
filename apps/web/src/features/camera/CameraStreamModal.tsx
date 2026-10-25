import { useEffect, useState } from "react";
import { LoaderCircle, X } from "lucide-react";
import { cameraApi } from "../../core/api/clients";
import { onAppEvent } from "../../core/events";
import type { CameraDevice } from "../../core/store/camera";

type StreamResponse = { sessionId: string; status: string; channel: number; profile: string; webrtcUrl?: string; hlsUrl?: string; error?: string | null; expiresAt?: string };

export function CameraStreamModal({ device, channel, onClose }: { device: CameraDevice; channel: number; onClose: () => void }) {
  const [session, setSession] = useState<StreamResponse | null>(null);
  const [message, setMessage] = useState("Đang yêu cầu Camera-Agent mở luồng…");
  const [fallback, setFallback] = useState(false);
  const channelName = device.channelStates?.find((item) => item.id === channel)?.name?.trim() || `Kênh ${channel}`;

  useEffect(() => onAppEvent("camera:close-overlays", onClose), [onClose]);

  useEffect(() => {
    let stopped = false;
    let sessionId = "";
    const run = async () => {
      const response = await cameraApi.openStream(device.id, { channel, profile: "sub" });
      if (!response.ok) { setMessage((await response.json().catch(() => ({}))).error || "Không tạo được phiên xem camera"); return; }
      const created = await response.json() as StreamResponse;
      sessionId = created.sessionId;
      if (stopped) { void cameraApi.closeStream(sessionId); return; }
      // P2P can take longer than LAN to establish. Wait for the agent's result
      // instead of declaring failure after the old 14-second polling window.
      const deadline = Date.now() + 120_000;
      while (Date.now() < deadline && !stopped) {
        const statusResponse = await cameraApi.stream(sessionId);
        if (!statusResponse.ok) break;
        const current = await statusResponse.json() as StreamResponse;
        if (stopped) return;
        setSession(current);
        if (current.status === "ready") { setMessage("Đang phát luồng camera"); return; }
        if (current.status === "error") { setMessage(current.error || "Agent không mở được luồng camera"); return; }
        if (current.status === "closed") { setMessage("Phiên xem camera đã đóng"); return; }
        await new Promise((resolve) => window.setTimeout(resolve, 700));
      }
      if (!stopped) setMessage("Agent không phản hồi mở luồng trong thời gian chờ");
    };
    // React StrictMode mounts effects twice in development. Defer the POST so
    // its first setup is cancelled before it can create a duplicate P2P tunnel.
    const timer = window.setTimeout(() => void run().catch((error) => {
      if (!stopped) setMessage(error instanceof Error ? error.message : "Không kết nối được backend");
    }), 0);
    return () => { stopped = true; window.clearTimeout(timer); if (sessionId) void cameraApi.closeStream(sessionId); };
  }, [channel, device.id]);

  return <div className="camera-stream-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}>
    <section className="camera-stream-modal" role="dialog" aria-modal="true" aria-label={`${device.name} - ${channelName}`}>
      <header><div><span className="eyebrow">GIÁM SÁT TRỰC TUYẾN</span><h3>{device.name} · {channelName}</h3><small>Kênh {channel} · {device.ipAddress || "Thiết bị P2P"} · {session?.profile === "main" ? "Main stream" : "Sub stream"}</small></div><button type="button" onClick={onClose} aria-label="Đóng"><X size={18} /></button></header>
      <div className="camera-stream-stage">{session?.status === "ready" && !fallback && session.webrtcUrl ? <iframe title={`Luồng camera ${device.name} - ${channelName}`} src={session.webrtcUrl} allow="autoplay; fullscreen" /> : session?.status === "ready" && fallback && session.hlsUrl ? <video src={session.hlsUrl} autoPlay muted playsInline controls /> : <div className="camera-stream-wait"><LoaderCircle size={25} className="spin" /><span>{message}</span></div>}</div>
      <footer><span className={session?.status === "ready" ? "ready" : ""}>{message}</span>{session?.status === "ready" && session.hlsUrl && <button type="button" onClick={() => setFallback((value) => !value)}>{fallback ? "WebRTC" : "HLS dự phòng"}</button>}<button type="button" onClick={onClose}>Đóng</button></footer>
    </section>
  </div>;
}
