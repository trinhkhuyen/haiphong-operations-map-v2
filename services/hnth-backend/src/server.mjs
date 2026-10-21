// Điểm khởi chạy hnth-backend: đọc cấu hình, migrate schema, seed admin, mở cổng.
// Route nằm trong routes/*.mjs, ráp ở app.mjs.
import http from "node:http";
import { createApp } from "./app.mjs";
import { loadConfig } from "./config.mjs";
import { migrate } from "./db.mjs";

try {
  const config = loadConfig();
  const app = createApp(config);
  await migrate();
  await app.auth.seedAdmin();
  http.createServer(app.handle).listen(config.port, "0.0.0.0", () => console.log(`HNTH Backend listening on :${config.port}`));
} catch (error) {
  console.error(`HNTH Backend startup failed: ${error.message}`);
  process.exitCode = 1;
}
