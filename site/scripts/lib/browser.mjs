// Shared Playwright loader for the image and screenshot scripts.
// Playwright is not a dependency of the site (nothing in public/ needs it);
// install it globally once and run the scripts with NODE_PATH, e.g.
//   npm i -g playwright && npx playwright install chromium
//   NODE_PATH="$(npm root -g)" npm run render:mocks
import { createRequire } from "node:module";
import { existsSync } from "node:fs";

const require = createRequire(import.meta.url);

export async function launch() {
  let playwright;
  try {
    playwright = require("playwright");
  } catch {
    throw new Error('Playwright not found. Run: npm i -g playwright && npx playwright install chromium, then prefix the command with NODE_PATH="$(npm root -g)".');
  }
  const executablePath = process.env.CHROMIUM_PATH || (existsSync("/opt/pw-browsers/chromium") ? "/opt/pw-browsers/chromium" : undefined);
  return playwright.chromium.launch(executablePath ? { executablePath } : {});
}

/** Encode a PNG buffer as WebP at the given widths using the browser's own encoder. */
export async function pngToWebp(browser, png, widths, quality = 0.82) {
  const page = await browser.newPage();
  const results = await page.evaluate(
    async ({ data, widths, quality }) => {
      const blob = await (await fetch(`data:image/png;base64,${data}`)).blob();
      const bitmap = await createImageBitmap(blob);
      const out = [];
      for (const width of widths) {
        const height = Math.round((bitmap.height * width) / bitmap.width);
        // Downscale in halving steps for a crisp result.
        let source = bitmap;
        let w = bitmap.width;
        let h = bitmap.height;
        while (w / 2 >= width) {
          const step = new OffscreenCanvas(Math.round(w / 2), Math.round(h / 2));
          const ctx = step.getContext("2d");
          ctx.imageSmoothingQuality = "high";
          ctx.drawImage(source, 0, 0, step.width, step.height);
          source = step;
          w = step.width;
          h = step.height;
        }
        const canvas = document.createElement("canvas");
        canvas.width = width;
        canvas.height = height;
        const ctx = canvas.getContext("2d");
        ctx.imageSmoothingQuality = "high";
        ctx.drawImage(source, 0, 0, width, height);
        out.push({ width, height, dataUrl: canvas.toDataURL("image/webp", quality) });
      }
      return out;
    },
    { data: png.toString("base64"), widths, quality }
  );
  await page.close();
  return results.map((r) => ({ width: r.width, height: r.height, buffer: Buffer.from(r.dataUrl.split(",")[1], "base64") }));
}
