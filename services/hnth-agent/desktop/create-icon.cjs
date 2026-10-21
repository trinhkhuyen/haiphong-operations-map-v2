const { app, nativeImage } = require("electron");
const fs = require("node:fs");
const path = require("node:path");

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <rect x="2" y="2" width="60" height="60" rx="16" fill="#12313a" stroke="#2dd4bf" stroke-width="4"/>
  <path d="M32 12v34M23 52h18M27 46l-6 8M37 46l6 8" fill="none" stroke="#67e8d3" stroke-width="4" stroke-linecap="round"/>
  <circle cx="32" cy="12" r="4" fill="#67e8d3"/>
  <path d="M22 22a14 14 0 0 0-6 11M42 22a14 14 0 0 1 6 11M16 16a22 22 0 0 0-9 17M48 16a22 22 0 0 1 9 17" fill="none" stroke="#67e8d3" stroke-width="3" stroke-linecap="round"/>
</svg>`;

app.whenReady().then(() => {
  const image = nativeImage.createFromDataURL(
    `data:image/svg+xml;base64,${Buffer.from(svg).toString("base64")}`,
  );
  fs.writeFileSync(path.join(__dirname, "hnth-agent.png"), image.resize({ width: 64, height: 64 }).toPNG());
  app.quit();
});
