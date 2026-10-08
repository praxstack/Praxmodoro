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
const fontDir = join(site, "scripts", "mock-fonts"); // the app's typefaces; the website uses its own
const outDir = join(site, "public", "assets", "img");
mkdirSync(outDir, { recursive: true });

const SCREENS = ["initiate", "focus", "checkin", "break", "review"];
const VIEWPORT = { width: 1280, height: 800 };
// Each screen is laid out at 1280x800 and then cropped so the bottom edge falls
// between lines of text, never through one, at the same height in light and dark.
// The script stops if a crop would cut text. After changing a crop, set the
// image height in src/pages/index.html to 1.25 x the crop; `npm test` checks it.
const CROP_HEIGHT = { initiate: 724, focus: 800, checkin: 716, break: 800, review: 744 };
const CROP_MARGIN = 4; // keep this much clear space between the edge and any line of text
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
      const crop = CROP_HEIGHT[screen];
      const cut = await page.evaluate(({ crop, margin }) => {
        const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
        while (walker.nextNode()) {
          const node = walker.currentNode;
          const el = node.parentElement;
          if (!node.textContent.trim() || el.closest(".sr-only, [hidden]") || getComputedStyle(el).visibility === "hidden") continue;
          const range = document.createRange();
          range.selectNodeContents(node);
          for (const rect of range.getClientRects()) {
            if (rect.height >= 2 && rect.top < crop + margin && rect.bottom > crop - margin) return node.textContent.trim();
          }
        }
        return null;
      }, { crop, margin: CROP_MARGIN });
      if (cut) throw new Error(`${screen} (${theme}): a crop at ${crop}px cuts through "${cut.slice(0, 40)}". Pick another CROP_HEIGHT.`);
      const png = await page.screenshot({ type: "png", clip: { x: 0, y: 0, width: VIEWPORT.width, height: crop } });
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
