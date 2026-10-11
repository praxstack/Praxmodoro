import { test } from "node:test";
import assert from "node:assert/strict";
import { onRequestPost, onRequest } from "../functions/api/waitlist.js";
import { handleWaitlist } from "../src/lib/waitlist.js";
import { createEnv, context, jsonRequest, formRequest, valid, freshIp, ORIGIN } from "./helpers.js";

async function post(env, body, options) {
  const response = await onRequestPost(context(jsonRequest(body, options), env));
  return { response, body: await response.json() };
}

test("a valid JSON signup is stored once, normalised, with consent time and hashed IP", async () => {
  const env = createEnv();
  const { response, body } = await post(env, { ...valid, mac: "apple-silicon", hardest: "Opening the tax folder", utm_source: "newsletter", referrer: "https://example.net/post" }, { ip: "198.51.100.23" });
  assert.equal(response.status, 200);
  assert.deepEqual(body, { ok: true });
  assert.equal(response.headers.get("cache-control"), "no-store");
  assert.match(response.headers.get("content-type"), /application\/json/);

  const rows = env.DB.rows();
  assert.equal(rows.length, 1);
  const [row] = rows;
  assert.equal(row.email, "asha.rao@proton.me");
  assert.equal(row.product, "praxmodoro");
  assert.equal(row.source, "hero");
  assert.deepEqual(JSON.parse(row.fields), { mac: "apple-silicon", hardest: "Opening the tax folder" });
  assert.deepEqual(JSON.parse(row.utm), { utm_source: "newsletter", referrer: "https://example.net/post" });
  assert.match(row.consent_at, /^\d{4}-\d\d-\d\dT/);
  assert.match(row.created_at, /^\d{4}-\d\d-\d\dT/);
  assert.match(row.ip_hash, /^[0-9a-f]{64}$/);
  assert.equal(JSON.stringify(rows).includes("198.51.100.23"), false, "raw IP never stored");
});

test("a duplicate email answers already:true and stores nothing new", async () => {
  const env = createEnv();
  await post(env, valid);
  const { response, body } = await post(env, { ...valid, email: "ASHA.RAO@proton.me", mac: "intel" });
  assert.equal(response.status, 200);
  assert.deepEqual(body, { ok: true, already: true });
  const rows = env.DB.rows();
  assert.equal(rows.length, 1);
  assert.deepEqual(JSON.parse(rows[0].fields), {}, "first answers are kept, nothing leaks or changes");
});

test("the honeypot answers ok and stores nothing", async () => {
  const env = createEnv();
  const { response, body } = await post(env, { ...valid, website: "https://spam.example" });
  assert.equal(response.status, 200);
  assert.deepEqual(body, { ok: true });
  assert.equal(env.DB.rows().length, 0);
  assert.equal(env.DB.rows("SELECT * FROM rate_limits").length, 0, "bots do not even touch the rate-limit table");
});

test("a bad email is a 400 with a sentence the page can show", async () => {
  const env = createEnv();
  const { response, body } = await post(env, { ...valid, email: "not-an-email" });
  assert.equal(response.status, 400);
  assert.equal(body.ok, false);
  assert.match(body.error, /^[A-Z].*\.$/);
  assert.equal(env.DB.rows().length, 0);
});

test("missing consent is a 400", async () => {
  const env = createEnv();
  const { response, body } = await post(env, { email: "a@mail.com", consent: false });
  assert.equal(response.status, 400);
  assert.match(body.error, /box/);
});

test("an over-long hardest-to-start answer is a 400; an unknown Mac is a 400", async () => {
  const env = createEnv();
  assert.equal((await post(env, { ...valid, hardest: "x".repeat(281) })).response.status, 400);
  assert.equal((await post(env, { ...valid, mac: "commodore" })).response.status, 400);
  assert.equal(env.DB.rows().length, 0);
});

test("unreadable JSON is a 400, not a 500", async () => {
  const env = createEnv();
  const { response, body } = await post(env, "{not json");
  assert.equal(response.status, 400);
  assert.equal(body.ok, false);
});

test("the sixth submission from one IP inside ten minutes is a 429", async () => {
  const env = createEnv();
  const ip = freshIp();
  const statuses = [];
  for (let i = 0; i < 6; i += 1) {
    const { response } = await post(env, { ...valid, email: `person${i}@mail.com` }, { ip });
    statuses.push(response.status);
  }
  assert.deepEqual(statuses, [200, 200, 200, 200, 200, 429]);
  const sixth = await post(env, { ...valid, email: "person9@mail.com" }, { ip });
  assert.equal(sixth.response.status, 429);
  assert.match(sixth.body.error, /few minutes/);
  assert.ok(Number(sixth.response.headers.get("retry-after")) > 0);
  assert.equal(env.DB.rows().length, 5);
  const other = await post(env, { ...valid, email: "someone.else@mail.com" });
  assert.equal(other.response.status, 200, "other IPs are unaffected");
});

test("the rate limit resets in the next window and old windows are pruned", async () => {
  const env = createEnv();
  const ip = freshIp();
  const start = Date.parse("2026-10-08T10:00:00Z");
  const at = (ms) => ({ now: () => new Date(start + ms) });
  for (let i = 0; i < 5; i += 1) {
    await handleWaitlist(context(jsonRequest({ ...valid, email: `w${i}@mail.com` }, { ip }), env), at(i * 1000));
  }
  const blocked = await handleWaitlist(context(jsonRequest({ ...valid, email: "w6@mail.com" }, { ip }), env), at(60_000));
  assert.equal(blocked.status, 429);
  const later = await handleWaitlist(context(jsonRequest({ ...valid, email: "w7@mail.com" }, { ip }), env), at(11 * 60_000));
  assert.equal(later.status, 200);
  await handleWaitlist(context(jsonRequest({ ...valid, email: "w8@mail.com" }, { ip: freshIp() }), env), at(26 * 60 * 60_000));
  const windows = env.DB.rows("SELECT window_start FROM rate_limits").map((r) => r.window_start);
  assert.ok(windows.every((w) => w >= start + 25 * 60 * 60_000), "windows older than a day are deleted");
});

test("a no-JS form post is redirected back to the page with joined=1", async () => {
  const env = createEnv();
  const response = await onRequestPost(context(formRequest({ email: "form.user@mail.com", consent: "on", source: "join", mac: "not-sure", hardest: "", website: "" }), env));
  assert.equal(response.status, 303);
  assert.equal(response.headers.get("location"), "/?joined=1#join");
  assert.equal(env.DB.rows().length, 1);
});

test("a no-JS form post with an error gets a small readable HTML page", async () => {
  const env = createEnv();
  const response = await onRequestPost(context(formRequest({ email: "nope", consent: "on" }), env));
  assert.equal(response.status, 400);
  assert.match(response.headers.get("content-type"), /text\/html/);
  const html = await response.text();
  assert.match(html, /<h1[^>]*>/);
  assert.match(html, /href="\/#join"/);
  assert.equal(response.headers.get("cache-control"), "no-store");
});

test("a cross-site origin is refused; same host and localhost dev are allowed", async () => {
  const env = createEnv();
  const cross = await post(env, valid, { origin: "https://evil.example" });
  assert.equal(cross.response.status, 403);
  assert.equal(env.DB.rows().length, 0);

  const sameHost = await post(env, { ...valid, email: "same@mail.com" }, { origin: ORIGIN });
  assert.equal(sameHost.response.status, 200);

  const devRequest = jsonRequest({ ...valid, email: "dev@mail.com" }, { origin: "http://localhost:8788", url: "http://localhost:8788/api/waitlist" });
  assert.equal((await onRequestPost(context(devRequest, env))).status, 200);

  const devOtherPort = jsonRequest({ ...valid, email: "dev2@mail.com" }, { origin: "http://127.0.0.1:3000", url: "http://localhost:8788/api/waitlist" });
  assert.equal((await onRequestPost(context(devOtherPort, env))).status, 200);

  const noOrigin = await post(env, { ...valid, email: "curl@mail.com" }, { origin: null });
  assert.equal(noOrigin.response.status, 200, "requests without Origin (curl, some form posts) are allowed");
});

test("wrong methods are a 405 with Allow: POST", async () => {
  const env = createEnv();
  for (const method of ["GET", "PUT", "DELETE"]) {
    const response = await onRequest(context(jsonRequest(null, { method }), env));
    assert.equal(response.status, 405, method);
    assert.equal(response.headers.get("allow"), "POST");
    assert.equal((await response.json()).ok, false);
  }
  const viaGeneric = await onRequest(context(jsonRequest(valid), env));
  assert.equal(viaGeneric.status, 200, "onRequest also routes POST");
});

test("a database failure is a generic 500", async () => {
  const env = createEnv({ DB: { prepare() { throw new Error("D1 is down"); } } });
  const { response, body } = await post(env, valid);
  assert.equal(response.status, 500);
  assert.equal(body.ok, false);
  assert.equal(body.error.includes("D1"), false, "internals are not leaked");
});

test("Turnstile is skipped without a secret and enforced with one", async () => {
  const calls = [];
  const fakeFetch = async (url, init) => {
    calls.push({ url: String(url), body: init.body.toString() });
    const token = new URLSearchParams(init.body.toString()).get("response");
    return new Response(JSON.stringify({ success: token === "good-token" }), { headers: { "content-type": "application/json" } });
  };
  const env = createEnv({ TURNSTILE_SECRET: "secret-key" });
  const missing = await handleWaitlist(context(jsonRequest({ ...valid, email: "t1@mail.com" }), env), { fetchImpl: fakeFetch });
  assert.equal(missing.status, 400);
  assert.equal(calls.length, 0, "no token, no network call");

  const bad = await handleWaitlist(context(jsonRequest({ ...valid, email: "t2@mail.com", "cf-turnstile-response": "bad-token" }), env), { fetchImpl: fakeFetch });
  assert.equal(bad.status, 400);

  const good = await handleWaitlist(context(jsonRequest({ ...valid, email: "t3@mail.com", "cf-turnstile-response": "good-token" }), env), { fetchImpl: fakeFetch });
  assert.equal(good.status, 200);
  assert.match(calls.at(-1).url, /challenges\.cloudflare\.com\/turnstile\/v0\/siteverify/);
  assert.match(calls.at(-1).body, /secret=secret-key/);
  assert.equal(env.DB.rows().length, 1);

  const noSecretEnv = createEnv();
  const skipped = await handleWaitlist(context(jsonRequest({ ...valid, email: "t4@mail.com" }), noSecretEnv), { fetchImpl: () => { throw new Error("must not be called"); } });
  assert.equal(skipped.status, 200);
});

test("without IP_HASH_SALT the handler still works and still hashes", async () => {
  const env = createEnv({ IP_HASH_SALT: undefined });
  const { response } = await post(env, valid, { ip: "192.0.2.55" });
  assert.equal(response.status, 200);
  assert.match(env.DB.rows()[0].ip_hash, /^[0-9a-f]{64}$/);
});
