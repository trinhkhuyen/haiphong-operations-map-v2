// ESLint cho cả workspace: web (TypeScript + React hooks) và các service Node (ESM/CJS).
import js from "@eslint/js";
import globals from "globals";
import reactHooks from "eslint-plugin-react-hooks";
import tseslint from "typescript-eslint";

export default tseslint.config(
  {
    ignores: [
      "**/node_modules/**",
      "**/dist/**",
      "outputs/**",
      "artifacts/**",
      ".codex_tmp/**",
      "services/hnth-agent/outputs/**",
      "services/hnth-backend/agent-releases/**",
      "apps/web/public/**",
    ],
  },
  {
    files: ["apps/web/src/**/*.{ts,tsx}"],
    extends: [js.configs.recommended, ...tseslint.configs.recommended],
    languageOptions: { globals: globals.browser },
    plugins: { "react-hooks": reactHooks },
    rules: {
      "react-hooks/rules-of-hooks": "error",
      // Nhiều effect cố ý bỏ dependency (chạy một lần, đọc state mới nhất qua
      // useAppStore.getState()/ref). Bật rule này sẽ đẩy tới việc "sửa" thành vòng
      // lặp effect; giữ tắt và ghi lý do bằng comment tại effect.
      "react-hooks/exhaustive-deps": "off",
      "@typescript-eslint/no-unused-vars": ["error", { argsIgnorePattern: "^_", varsIgnorePattern: "^_", caughtErrors: "none" }],
    },
  },
  {
    files: ["**/*.{mjs,js}"],
    extends: [js.configs.recommended],
    languageOptions: { globals: { ...globals.node }, sourceType: "module" },
    rules: {
      "no-unused-vars": ["error", { argsIgnorePattern: "^_", varsIgnorePattern: "^_", caughtErrors: "none" }],
    },
  },
  {
    files: ["**/*.cjs"],
    extends: [js.configs.recommended],
    languageOptions: { globals: { ...globals.node }, sourceType: "commonjs" },
  },
  {
    // Script chạy trong trình duyệt/fetch dữ liệu của web.
    files: ["apps/web/scripts/**/*.mjs"],
    languageOptions: { globals: { ...globals.node, ...globals.browser } },
  },
);
