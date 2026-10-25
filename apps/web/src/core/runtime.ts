/** Runtime flags shared by the browser-only GitHub Pages demo. */
export const demoMode = import.meta.env.VITE_DEMO_MODE === "true";

/** Resolve a file from `public/` correctly for both `/` and GitHub Pages subpaths. */
export function publicAsset(path: string) {
  return `${import.meta.env.BASE_URL}${path.replace(/^\/+/, "")}`;
}
