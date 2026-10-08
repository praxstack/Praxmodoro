// Renders the share image (public/og.jpg, 1200x630, under 300 KB so WhatsApp shows it) and the PNG icons from
// public/favicon.svg, using the site's own CSS and fonts.
//   NODE_PATH="$(npm root -g)" npm run render:brand
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { launch } from "./lib/browser.mjs";

const site = join(dirname(fileURLToPath(import.meta.url)), "..");
const pub = join(site, "public");
const svg = readFileSync(join(pub, "favicon.svg"), "utf8");

const ICONS = [
  { file: "favicon-32.png", size: 32, background: null },
  { file: "apple-touch-icon.png", size: 180, background: "#e4eef9", inset: 0.14 },
  { file: "icon-192.png", size: 192, background: "#e4eef9", inset: 0.14 },
  { file: "icon-512.png", size: 512, background: "#e4eef9", inset: 0.14 }
];

const browser = await launch();
try {
  const og = await browser.newPage({ viewport: { width: 1200, height: 630 }, deviceScaleFactor: 1, colorScheme: "light" });
  await og.goto(pathToFileURL(join(site, "scripts", "brand", "og.html")).href, { waitUntil: "load" });
  await og.evaluate(() => document.fonts.ready);
  await og.waitForTimeout(300);
  await og.screenshot({ path: join(pub, "og.jpg"), type: "jpeg", quality: 88 });
  console.log("public/og.jpg 1200x630");

  for (const icon of ICONS) {
    const page = await browser.newPage({ viewport: { width: icon.size, height: icon.size }, deviceScaleFactor: 1 });
    const pad = Math.round(icon.size * (icon.inset || 0));
    const bg = icon.background ? `background:${icon.background};` : "background:transparent;";
    await page.setContent(`<html><body style="margin:0;${bg}width:${icon.size}px;height:${icon.size}px;display:grid;place-items:center">
      <div style="width:${icon.size - pad * 2}px;height:${icon.size - pad * 2}px">${svg.replace("<svg ", '<svg width="100%" height="100%" ')}</div></body></html>`);
    await page.screenshot({ path: join(pub, icon.file), omitBackground: !icon.background });
    console.log(`public/${icon.file} ${icon.size}x${icon.size}`);
    await page.close();
  }
} finally {
  await browser.close();
}
