// Builds the static pages in public/ from src/pages/ and site.config.json.
//
// The output is committed, so public/ deploys as-is. Run this only after you
// change site.config.json (for example the domain or contact address) or edit
// a page in src/pages/. `npm test` fails if public/ and src/pages/ drift apart.
//
// Templates use two tiny conventions:
//   {{> name}}          includes src/pages/partials/name.html
//   {{KEY}}             inserts a value (see variables() below)
// and each HTML page starts with  <!-- @page {"title": "...", "description": "...", "path": "/x/"} -->
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const site = join(dirname(fileURLToPath(import.meta.url)), "..");
const pagesDir = join(site, "src", "pages");
const publicDir = join(site, "public");

// Template file -> output path in public/.
export const OUTPUTS = Object.freeze({
  "index.html": "index.html",
  "privacy.html": "privacy/index.html",
  "terms.html": "terms/index.html",
  "404.html": "404.html",
  "robots.txt": "robots.txt",
  "sitemap.xml": "sitemap.xml",
  "site.webmanifest": "site.webmanifest"
});

export function loadConfig() {
  const config = JSON.parse(readFileSync(join(site, "site.config.json"), "utf8"));
  const url = new URL(config.siteUrl);
  if (url.protocol !== "https:" || url.pathname !== "/") throw new Error("siteUrl must look like https://example.com (no path)");
  if (!/^[^\s@]+@[^\s@]+\.[a-z]{2,}$/i.test(config.contactEmail)) throw new Error("contactEmail is not an email address");
  return config;
}

function variables(config, page) {
  const siteUrl = config.siteUrl.replace(/\/$/, "");
  return {
    SITE_URL: siteUrl,
    SITE_HOST: new URL(siteUrl).host,
    CONTACT_EMAIL: config.contactEmail,
    COPYRIGHT_YEAR: config.copyrightYear,
    LEGAL_UPDATED: config.legalUpdated,
    PAGE_TITLE: escapeAttr(page.title ?? "Praxmodoro"),
    PAGE_DESCRIPTION: escapeAttr(page.description ?? ""),
    PAGE_PATH: page.path ?? "/"
  };
}

function escapeAttr(text) {
  return String(text).replaceAll("&", "&amp;").replaceAll('"', "&quot;").replaceAll("<", "&lt;");
}

function includePartials(source, depth = 0) {
  if (depth > 4) throw new Error("partials nested too deeply");
  return source.replace(/\{\{>\s*([\w-]+)\s*\}\}/g, (_, name) =>
    includePartials(readFileSync(join(pagesDir, "partials", `${name}.html`), "utf8").replace(/\n$/, ""), depth + 1)
  );
}

export function renderTemplate(file, config) {
  let source = readFileSync(join(pagesDir, file), "utf8");
  let page = {};
  const meta = /^<!--\s*@page\s+(\{[\s\S]*?\})\s*-->\n?/.exec(source);
  if (meta) {
    page = JSON.parse(meta[1]);
    source = source.slice(meta[0].length);
  }
  const values = variables(config, page);
  const output = includePartials(source).replace(/\{\{\s*([A-Z_]+)\s*\}\}/g, (match, key) => {
    if (!(key in values)) throw new Error(`${file}: unknown variable ${match}`);
    return values[key];
  });
  if (output.includes("{{")) throw new Error(`${file}: unresolved template tag`);
  return output;
}

export function buildAll(config = loadConfig()) {
  return Object.fromEntries(Object.entries(OUTPUTS).map(([file, out]) => [out, renderTemplate(file, config)]));
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const files = buildAll();
  for (const [out, content] of Object.entries(files)) {
    const target = join(publicDir, out);
    mkdirSync(dirname(target), { recursive: true });
    writeFileSync(target, content);
    console.log(`built public/${out}`);
  }
}
