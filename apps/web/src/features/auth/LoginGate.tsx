import { useEffect } from "react";
import { backendEnabled, refresh } from "../../core/auth";

/** Thử khôi phục phiên đăng nhập (refresh cookie) một lần khi mở trang. */
export function LoginGate({ children }: { children: React.ReactNode }) {
  useEffect(() => {
    if (backendEnabled) void refresh();
  }, []);
  return <>{children}</>;
}
