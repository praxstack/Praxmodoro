import { test } from "node:test";
import assert from "node:assert/strict";
import { onRequestGet as exportGet, onRequest as exportAny } from "../functions/api/waitlist/export.js";
import { onRequestPost as joinPost } from "../functions/api/waitlist.js";
import { onRequest as health } from "../functions/api/health.js";
import { createEnv, context, jsonRequest, valid, ORIGIN } from "./helpers.js";

const exportUrl = `${ORIGIN}/api/waitlist/export`;
const get = (headers = {}) => new Request(exportUrl, { headers });

test("export without a token is a 401", async () => {
  const env = createEnv();
  const response = await exportGet(context(get(), env));
  assert.equal(response.status, 401);
  assert.equal(response.headers.get("cache-control"), "no-store");
  assert.match(response.headers.get("www-authenticate"), /Bearer/);
});

test("export with a wrong token, or with no ADMIN_TOKEN configured, is a 401", async () => {
  const env = createEnv();
  assert.equal((await exportGet(context(get({ authorization: "Bearer nope" }), env))).status, 401);
  assert.equal((await exportGet(context(get({ authorization: env.ADMIN_TOKEN }), env))).status, 401, "scheme is required");
  const unset = createEnv({ ADMIN_TOKEN: undefined });
  assert.equal((await exportGet(context(get({ authorization: "Bearer " }), unset))).status, 401);
  assert.equal((await exportGet(context(get({ authorization: "Bearer undefined" }), unset))).status, 401);
});

test("export with the token returns a CSV with formula-safe cells", async () => {
  const env = createEnv();
  await joinPost(context(jsonRequest({ ...valid, mac: "intel", hardest: "=HYPERLINK(\"x\") the first email" }), env));
  await joinPost(context(jsonRequest({ ...valid, email: "second@mail.com", source: "@evil", utm_source: "-x" }), env));
  const response = await exportGet(context(get({ authorization: `Bearer ${env.ADMIN_TOKEN}` }), env));
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type"), /text\/csv/);
  assert.match(response.headers.get("content-disposition"), /attachment; filename="praxmodoro-waitlist-\d{4}-\d\d-\d\d\.csv"/);
  assert.equal(response.headers.get("cache-control"), "no-store");
  const csv = await response.text();
  const lines = csv.trim().split("\r\n");
  assert.equal(lines[0], "email,created_at,fields,source,utm");
  assert.equal(lines.length, 3);
  assert.match(lines[1], /^asha\.rao@proton\.me,/);
  assert.match(lines[1], /""hardest"":""=HYPERLINK/, "JSON cell is quoted; it starts with { so it is not a formula");
  assert.match(lines[2], /,'@evil,/, "a source starting with @ is neutralised");
});

test("export refuses other methods", async () => {
  const env = createEnv();
  const response = await exportAny(context(new Request(exportUrl, { method: "POST", headers: { authorization: `Bearer ${env.ADMIN_TOKEN}` } }), env));
  assert.equal(response.status, 405);
  assert.equal(response.headers.get("allow"), "GET");
});

test("health answers ok", async () => {
  const response = await health(context(new Request(`${ORIGIN}/api/health`), createEnv()));
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { ok: true });
  assert.equal(response.headers.get("cache-control"), "no-store");
});
