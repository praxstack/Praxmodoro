// QA screenshots: desktop and phone, light and dark, plus a horizontal-scroll check.
//   NODE_PATH="$(npm root -g)" node scripts/screenshots.mjs [baseUrl] [outDir]
// Default base URL is the local `npm run dev` server.
import { mkdirSync } from "node:fs";
import { join } from "node:path";
import { launch } from "./lib/browser.mjs";

const base = process.argv[2] || "http://localhost:8788";
const outDir = process.argv[3] || "screenshots";
mkdirSync(outDir, { recursive: true });

const RUNS = [
  { name: "desktop-light", viewport: { width: 1440, height: 900 }, colorScheme: "light" },
  { name: "desktop-dark", viewport: { width: 1440, height: 900 }, colorScheme: "dark" },
  { name: "mobile-light", viewport: { width: 390, height: 844 }, colorScheme: "light", isMobile: true, hasTouch: true, deviceScaleFactor: 2 },
  { name: "mobile-dark", viewport: { width: 390, height: 844 }, colorScheme: "dark", isMobile: true, hasTouch: true, deviceScaleFactor: 2 }
];

const paths = (process.env.SHOT_PATHS || "/").split(",");
const browser = await launch();
let failed = false;
try {
  for (const run of RUNS) {
    const context = await browser.newContext({
      viewport: run.viewport,
      colorScheme: run.colorScheme,
      deviceScaleFactor: run.deviceScaleFactor || 1,
      isMobile: Boolean(run.isMobile),
      hasTouch: Boolean(run.hasTouch),
      reducedMotion: process.env.REDUCED_MOTION ? "reduce" : "no-preference"
    });
    const page = await context.newPage();
    const errors = [];
    page.on("pageerror", (error) => errors.push(String(error)));
    page.on("console", (msg) => {
      if (msg.type() === "error") errors.push(msg.text());
    });
    for (const path of paths) {
      await page.goto(new URL(path, base).href, { waitUntil: "networkidle" });
      await page.evaluate(() => document.fonts.ready);
      // Walk the page so lazy images load, then return to the top.
      await page.evaluate(async () => {
        for (let y = 0; y < document.body.scrollHeight; y += 500) {
          window.scrollTo(0, y);
          await new Promise((r) => setTimeout(r, 60));
        }
        window.scrollTo(0, 0);
      });
      // Full-page captures can skip lazy images that have not decoded yet.
      await page.evaluate(async () => {
        const images = [...document.images];
        images.forEach((img) => {
          img.loading = "eager";
          img.decoding = "sync";
        });
        await Promise.all(images.map((img) => (img.complete ? Promise.resolve() : new Promise((r) => img.addEventListener("load", r, { once: true })))));
        await Promise.all(images.map((img) => img.decode().catch(() => {})));
      });
      await page.waitForTimeout(1600);
      const { scrollWidth, innerWidth } = await page.evaluate(() => ({ scrollWidth: document.documentElement.scrollWidth, innerWidth: window.innerWidth }));
      const slug = path === "/" ? "home" : path.replaceAll("/", "").replace(".html", "");
      const file = join(outDir, `${slug}-${run.name}.png`);
      await page.screenshot({ path: join(outDir, `${slug}-${run.name}-fold.png`) });
      // The room gradient is fixed to the viewport. A full-page capture keeps the
      // first viewport's size for it, which leaves a hard band, so let it scroll
      // with the page for this capture only.
      await page.evaluate(() => (document.body.style.backgroundAttachment = "scroll"));
      await page.screenshot({ path: file, fullPage: true });
      await page.evaluate(() => (document.body.style.backgroundAttachment = ""));
      const ok = scrollWidth <= innerWidth;
      if (!ok) failed = true;
      console.log(`${ok ? "ok  " : "FAIL"} ${file}  scrollWidth=${scrollWidth} viewport=${innerWidth}`);
    }
    if (errors.length) {
      failed = true;
      console.log(`console errors in ${run.name}:\n  ${errors.join("\n  ")}`);
    }
    await context.close();
  }
} finally {
  await browser.close();
}
process.exit(failed ? 1 : 0);
