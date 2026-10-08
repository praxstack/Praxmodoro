import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { decoratePage, turnstileEnabled } from "../src/lib/page.js";
import { buildCsp, pageSecurityHeaders } from "../src/lib/security-headers.js";
import { onRequest as middleware } from "../functions/_middleware.js";

const html = () => new Response("<html><head></head><body>hi</body></html>", { headers: { "content-type": "text/html; charset=utf-8" } });
const ctx = (env = {}, url = "https://praxmodoro.pages.dev/") => ({ request: new Request(url), env });

test("HTML pages get the security headers; Turnstile origin only when configured", () => {
  const plain = decoratePage(html(), ctx());
  assert.equal(plain.headers.get("content-security-policy"), buildCsp());
  assert.equal(plain.headers.get("x-frame-options"), "DENY");
  assert.doesNotMatch(plain.headers.get("content-security-policy"), /challenges\.cloudflare\.com/);

  const withKey = decoratePage(html(), ctx({ TURNSTILE_SITE_KEY: "1x00000000000000000000AA" }));
  assert.match(withKey.headers.get("content-security-policy"), /script-src 'self' https:\/\/challenges\.cloudflare\.com/);
  assert.match(withKey.headers.get("content-security-policy"), /frame-src https:\/\/challenges\.cloudflare\.com/);
});

test("non-HTML responses pass through untouched", () => {
  const original = new Response("{}", { headers: { "content-type": "application/json" } });
  assert.equal(decoratePage(original, ctx()), original);
});

test("turnstileEnabled needs a non-empty site key", () => {
  assert.equal(turnstileEnabled({}), false);
  assert.equal(turnstileEnabled({ TURNSTILE_SITE_KEY: "  " }), false);
  assert.equal(turnstileEnabled({ TURNSTILE_SITE_KEY: "key" }), true);
});

test("middleware never breaks the page", async () => {
  const response = await middleware({ request: new Request("https://praxmodoro.pages.dev/"), env: {}, next: async () => html() });
  assert.equal(response.status, 200);
  assert.match(await response.text(), /hi/);
});

test("public/_headers carries exactly the shared security headers", () => {
  const file = readFileSync(new URL("../public/_headers", import.meta.url), "utf8");
  for (const [name, value] of Object.entries(pageSecurityHeaders())) {
    assert.ok(file.includes(`  ${name}: ${value}\n`), `${name} matches src/lib/security-headers.js`);
  }
});

test("public/_routes.json only sends / and /api/* to Functions", () => {
  const routes = JSON.parse(readFileSync(new URL("../public/_routes.json", import.meta.url), "utf8"));
  assert.deepEqual(routes, { version: 1, include: ["/", "/api/*"], exclude: [] });
});
