import { clearAccessToken, getAccessToken, refresh } from "./auth";

export async function hnthFetch(input: RequestInfo | URL, init: RequestInit = {}, retry = true): Promise<Response> {
  const headers = new Headers(init.headers);
  const accessToken = getAccessToken();
  if (accessToken) headers.set("authorization", `Bearer ${accessToken}`);
  // Live HNTH state must never be served from a browser/proxy cache. Without
  // this, a Guest opening the page after the first monitoring round can receive
  // the initial empty/stale snapshot instead of the current backend state.
  const response = await fetch(input, { ...init, cache: "no-store", headers, credentials: "include" });
  if (response.status !== 401 || !retry) return response;

  const refreshed = await refresh();
  if (refreshed) return hnthFetch(input, init, false);

  clearAccessToken();
  window.dispatchEvent(new Event("hnth:auth-expired"));
  return response;
}
