// Checks on the built static site: public/ matches src/pages/, and every page
// keeps the rules the CSP and the accessibility work depend on.
import { test } from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { OUTPUTS, buildAll, loadConfig } from "../scripts/build.mjs";
import { HARDEST_MAX, MAC_CHOICES } from "../src/lib/validate.js";

const publicDir = fileURLToPath(new URL("../public/", import.meta.url));
const read = (path) => readFileSync(join(publicDir, path), "utf8");
const htmlPages = Object.values(OUTPUTS).filter((out) => out.endsWith(".html"));
const redirects = read("_redirects")
  .split("\n")
  .filter((line) => line.trim() && !line.startsWith("#"))
  .map((line) => line.trim().split(/\s+/)[0]);

function walk(dir) {
  return readdirSync(dir).flatMap((name) => {
    const full = join(dir, name);
    return statSync(full).isDirectory() ? walk(full) : [full];
  });
}

function tags(html, name) {
  return [...html.matchAll(new RegExp(`<${name}\\b[^>]*>`, "gi"))].map((m) => m[0]);
}

function attr(tag, name) {
  const match = new RegExp(`\\s${name}="([^"]*)"`, "i").exec(tag);
  return match ? match[1] : null;
}

/** Turn an internal URL into the file Cloudflare Pages would serve, or null if it is not a file path. */
function resolveInternal(url) {
  if (!url.startsWith("/") || url.startsWith("//")) return null;
  const path = url.split(/[?#]/)[0];
  if (path.startsWith("/api/") || redirects.includes(path)) return null;
  return path.endsWith("/") ? `${path}index.html` : path;
}

test("public/ is exactly what src/pages/ builds (run `npm run build` after editing a page)", () => {
  const built = buildAll();
  for (const [out, content] of Object.entries(built)) {
    assert.equal(read(out), content, `public/${out} is out of date`);
    assert.ok(!content.includes("{{"), `public/${out} has an unresolved template tag`);
  }
});

test("changing the domain in site.config.json reaches every canonical and social URL", () => {
  const config = { ...loadConfig(), siteUrl: "https://praxmodoro.com", contactEmail: "hello@praxmodoro.com" };
  const built = buildAll(config);
  assert.match(built["index.html"], /<link rel="canonical" href="https:\/\/praxmodoro\.com\/">/);
  assert.match(built["index.html"], /<meta property="og:image" content="https:\/\/praxmodoro\.com\/og\.jpg">/);
  assert.match(built["sitemap.xml"], /<loc>https:\/\/praxmodoro\.com\/<\/loc>/);
  assert.match(built["robots.txt"], /Sitemap: https:\/\/praxmodoro\.com\/sitemap\.xml/);
  for (const content of Object.values(built)) assert.doesNotMatch(content, /pages\.dev/);
});

for (const page of htmlPages) {
  test(`${page}: structure, CSP and accessibility basics`, () => {
    const html = read(page);
    assert.match(html, /^<!doctype html>\s*<html lang="en">/i);
    assert.equal(tags(html, "title").length, 1);
    assert.equal(tags(html, "h1").length, 1, "exactly one h1");
    assert.equal(tags(html, "main").length, 1, "exactly one main");

    // The CSP allows no inline code or styles.
    assert.doesNotMatch(html, /\sstyle="/i, "no inline style attributes");
    assert.doesNotMatch(html, /\son[a-z]+="/i, "no inline event handlers");
    assert.doesNotMatch(html, /<style\b/i, "no style elements");
    for (const script of tags(html, "script")) assert.ok(attr(script, "src"), `inline script found: ${script}`);
    assert.doesNotMatch(html, /href="javascript:/i);

    for (const img of tags(html, "img")) {
      assert.ok(attr(img, "alt") !== null, `img without alt: ${img}`);
      assert.match(attr(img, "width") || "", /^\d+$/, `img without width: ${img}`);
      assert.match(attr(img, "height") || "", /^\d+$/, `img without height: ${img}`);
    }

    const ids = [...html.matchAll(/\sid="([^"]+)"/g)].map((m) => m[1]);
    assert.equal(new Set(ids).size, ids.length, `duplicate ids: ${ids.filter((id, i) => ids.indexOf(id) !== i)}`);
    const idSet = new Set(ids);
    for (const m of html.matchAll(/\s(?:for|aria-labelledby|aria-describedby|aria-controls)="([^"]+)"/g)) {
      for (const ref of m[1].split(/\s+/)) assert.ok(idSet.has(ref), `reference to missing id "${ref}"`);
    }
    for (const m of html.matchAll(/\shref="#([^"]+)"/g)) assert.ok(idSet.has(m[1]), `in-page link to missing #${m[1]}`);

    for (const input of tags(html, "input")) {
      const type = attr(input, "type");
      if (["hidden", "submit", "button"].includes(type)) continue;
      const id = attr(input, "id");
      const labelled = (id && html.includes(`for="${id}"`)) || attr(input, "aria-label") || attr(input, "aria-labelledby");
      const wrapped = type === "checkbox" || type === "radio";
      assert.ok(labelled || wrapped, `input without a label: ${input}`);
    }
  });

  test(`${page}: every internal link and asset exists`, () => {
    const html = read(page);
    const urls = [
      ...[...html.matchAll(/\s(?:href|src)="([^"]+)"/g)].map((m) => m[1]),
      ...[...html.matchAll(/\ssrcset="([^"]+)"/g)].flatMap((m) => m[1].split(",").map((part) => part.trim().split(/\s+/)[0]))
    ];
    for (const url of urls) {
      const file = resolveInternal(url);
      if (file) assert.ok(existsSync(join(publicDir, file)), `${page} links to missing ${url}`);
    }
    const index = read("index.html");
    for (const m of html.matchAll(/\shref="\/#([^"]+)"/g)) assert.ok(index.includes(`id="${m[1]}"`), `link to missing /#${m[1]}`);
  });
}

test("the waitlist forms send exactly what the API reads", () => {
  const html = read("index.html");
  const forms = [...html.matchAll(/<form\b[^>]*data-waitlist-form[^>]*>([\s\S]*?)<\/form>/g)];
  assert.equal(forms.length, 2, "hero form and join form");
  for (const [tag, body] of forms) {
    assert.equal(attr(tag, "action"), "/api/waitlist");
    assert.equal(attr(tag, "method"), "post");
    const names = new Set([...body.matchAll(/\sname="([^"]+)"/g)].map((m) => m[1]));
    for (const name of ["email", "consent", "website", "source", "utm_source", "utm_medium", "utm_campaign", "referrer"]) {
      assert.ok(names.has(name), `${attr(tag, "data-source")} form is missing ${name}`);
    }
    assert.match(body, /type="checkbox" name="consent"[^>]*required/, "consent must be an unticked, required checkbox");
    assert.doesNotMatch(body, /name="consent"[^>]*checked/);
  }
  const join = forms.find(([tag]) => attr(tag, "data-source") === "join")[1];
  const macValues = [...join.matchAll(/name="mac" value="([^"]+)"/g)].map((m) => m[1]);
  assert.deepEqual(macValues, MAC_CHOICES);
  assert.match(join, new RegExp(`<textarea[^>]*name="hardest"[^>]*maxlength="${HARDEST_MAX}"`));
});

test("copy rules: disclaimer on every page, AI only as planned and opt-in, no personal address", () => {
  for (const page of htmlPages) {
    assert.match(read(page), /not a medical device/, `${page} is missing the disclaimer`);
  }
  const index = read("index.html");
  assert.match(index, /planned, opt-in/i);
  assert.doesNotMatch(index, /\bAI-powered\b/i);
  for (const file of walk(publicDir).filter((f) => /\.(html|txt|xml|webmanifest|js|css)$/.test(f))) {
    const text = readFileSync(file, "utf8");
    assert.doesNotMatch(text, /@gmail\.com/i, `${relative(publicDir, file)} contains a personal address`);
  }
});
