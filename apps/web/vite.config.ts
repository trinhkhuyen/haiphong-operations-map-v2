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
    // Chunk "map" là maplibre-gl (~1 MB, file dist đã minify sẵn, không tree-shake
    // được); các chunk khác đều dưới 500 kB. Ngưỡng này chỉ để không cảnh báo thừa.
    chunkSizeWarningLimit: 1100,
    rollupOptions: {
      output: {
        // Thư viện lớn tách chunk riêng để trình duyệt cache lâu giữa các lần deploy.
        manualChunks(id) {
          if (!id.includes("node_modules")) return undefined;
          if (id.includes("/maplibre-gl/")) return "map";
          if (id.includes("/terra-draw")) return "drawing";
          if (/\/(react|react-dom|scheduler|zustand)\//.test(id)) return "vendor";
          if (/\/(@turf|polyclip-ts|splaytree-ts|robust-predicates|bignumber\.js|rbush|quickselect|sweepline-intersections|concaveman|point-in-polygon-hao)\//.test(id)) return "geo";
          return undefined;
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
