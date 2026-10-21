/// <reference types="vitest/config" />
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      "/hp-official": {
        target: "https://bandoso.haiphong.gov.vn",
        changeOrigin: true,
        secure: false,
        rewrite: (path) => path.replace(/^\/hp-official/, ""),
      },
      "/overpass": {
        target: "https://overpass-api.de",
        changeOrigin: true,
        secure: true,
        rewrite: (path) => path.replace(/^\/overpass/, ""),
      },
      "/api": {
        target: process.env.VITE_PROXY_TARGET || "http://127.0.0.1:8788",
        changeOrigin: true,
      },
    },
  },
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          map: ["maplibre-gl"],
          drawing: ["terra-draw", "terra-draw-maplibre-gl-adapter"],
          vendor: ["react", "react-dom", "zustand"],
        },
      },
    },
  },
  // Unit test cho hàm thuần và store; không cần DOM nên chạy môi trường node.
  test: {
    environment: "node",
    include: ["src/**/*.test.ts"],
  },
});
