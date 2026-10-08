// Renders the approved Living Companion app mocks (design-mocks/living-companion)
// into the product images used on the site, in light and dark, as WebP.
// The design-review feedback bar is hidden; nothing else about the mock changes.
//   NODE_PATH="$(npm root -g)" npm run render:mocks
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { launch, pngToWebp } from "./lib/browser.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const site = join(here, "..");
const mockDir = join(site, "..", "design-mocks", "living-companion");
const fontDir = join(site, "public", "assets", "fonts");
const outDir = join(site, "public", "assets", "img");
mkdirSync(outDir, { recursive: true });

const SCREENS = ["initiate", "focus", "checkin", "break", "review"];
const VIEWPORT = { width: 1280, height: 800 };
const WIDTHS = [880, 1600];

// Serve the self-hosted fonts in place of the Google Fonts import in tokens.css.
const FONT_CSS = `
@font-face { font-family: "Gabarito"; font-weight: 400 900; src: url(https://fonts.local/gabarito-latin-wght.woff2) format("woff2"); }
@font-face { font-family: "Hanken Grotesk"; font-weight: 100 900; src: url(https://fonts.local/hanken-grotesk-latin-wght.woff2) format("woff2"); }
@font-face { font-family: "Sono"; font-weight: 200 800; src: url(https://fonts.local/sono-latin-wght.woff2) format("woff2"); }`;

const HIDE_REVIEW_CHROME = ".prototype-feedback { display: none !important; }";

const browser = await launch();
try {
  for (const theme of ["light", "dark"]) {
    const context = await browser.newContext({ viewport: VIEWPORT, deviceScaleFactor: 2, colorScheme: theme, reducedMotion: "no-preference" });
    await context.route("https://fonts.googleapis.com/**", (route) => route.fulfill({ contentType: "text/css", body: FONT_CSS }));
    await context.route("https://fonts.local/**", (route) => {
      const file = new URL(route.request().url()).pathname.slice(1);
      route.fulfill({ contentType: "font/woff2", body: readFileSync(join(fontDir, file)) });
    });
    for (const screen of SCREENS) {
      const page = await context.newPage();
      const url = `${pathToFileURL(join(mockDir, "app-mocks.html")).href}?screen=${screen}`;
      await page.goto(url, { waitUntil: "load" });
      await page.addStyleTag({ content: HIDE_REVIEW_CHROME });
      if (theme === "dark") {
        await page.addStyleTag({ content: readFileSync(join(mockDir, "tokens-dark.css"), "utf8") + ":root { color-scheme: dark; }" });
      }
      await page.evaluate(() => document.fonts.ready);
      await page.mouse.move(VIEWPORT.width * 0.5, VIEWPORT.height * 0.55);
      await page.waitForTimeout(2200); // let the companion field settle into its breathing
      const png = await page.screenshot({ type: "png" });
      for (const image of await pngToWebp(browser, png, WIDTHS)) {
        const name = `app-${screen}-${theme}-${image.width}.webp`;
        writeFileSync(join(outDir, name), image.buffer);
        console.log(`${name}  ${image.width}x${image.height}  ${(image.buffer.length / 1024).toFixed(0)} KB`);
      }
      await page.close();
    }
    await context.close();
  }
} finally {
  await browser.close();
}
