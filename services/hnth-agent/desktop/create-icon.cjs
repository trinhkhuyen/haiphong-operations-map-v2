// Sinh icon khay cho 3 trạng thái: hnth-agent.png (bình thường), -busy (đang giám
// sát/quét), -offline (mất backend). Chạy: npx electron desktop/create-icon.cjs
// nativeImage không dựng được SVG trên Windows nên vẽ qua canvas trong cửa sổ ẩn.
const { app, BrowserWindow } = require("electron");
const fs = require("node:fs");
const path = require("node:path");

const SIZE = 64;
const COLORS = { "": "#14b8a6", "-busy": "#ef4444", "-offline": "#eab308" };

// Mẫu "nút mạng": nút trên đặc, hai nút dưới rỗng; nền trong suốt, nét phủ hết khung.
// Đường nối dừng ở mép vòng tròn để phần rỗng không bị đường kẻ xuyên qua.
function iconSvg(color) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <g stroke="${color}" stroke-width="5" fill="none">
    <path d="M32 11 L15.3 44.4 M32 11 L48.7 44.4 M20 52 H44"/>
    <circle cx="11.5" cy="52" r="8.5"/>
    <circle cx="52.5" cy="52" r="8.5"/>
  </g>
  <circle cx="32" cy="11" r="10" fill="${color}"/>
</svg>`;
}

app.whenReady().then(async () => {
  const win = new BrowserWindow({ show: false, webPreferences: { offscreen: true } });
  await win.loadURL("data:text/html,<canvas></canvas>");
  for (const [suffix, color] of Object.entries(COLORS)) {
    const svg = Buffer.from(iconSvg(color)).toString("base64");
    const dataUrl = await win.webContents.executeJavaScript(`new Promise((resolve, reject) => {
      const image = new Image();
      image.onload = () => {
        const canvas = document.createElement("canvas");
        canvas.width = canvas.height = ${SIZE};
        canvas.getContext("2d").drawImage(image, 0, 0, ${SIZE}, ${SIZE});
        resolve(canvas.toDataURL("image/png"));
      };
      image.onerror = reject;
      image.src = "data:image/svg+xml;base64,${svg}";
    })`);
    fs.writeFileSync(path.join(__dirname, `hnth-agent${suffix}.png`), Buffer.from(dataUrl.split(",")[1], "base64"));
  }
  app.quit();
});
