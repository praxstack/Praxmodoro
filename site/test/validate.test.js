import { test } from "node:test";
import assert from "node:assert/strict";
import {
  validateEmail,
  isConsentGiven,
  cleanText,
  validateFields,
  parseSubmission,
  HARDEST_MAX
} from "../src/lib/validate.js";

test("email is trimmed and lower-cased", () => {
  assert.deepEqual(validateEmail("  Asha.Rao@Proton.ME "), { ok: true, email: "asha.rao@proton.me" });
});

test("ordinary addresses pass", () => {
  for (const email of ["a@b.co", "first.last+focus@example-mail.in", "x_y@sub.domain.org", "o'neil@mail.ie", "user@xn--80ak6aa92e.com"]) {
    assert.equal(validateEmail(email).ok, true, email);
  }
});

test("missing or malformed addresses fail with a plain sentence", () => {
  const cases = ["", "   ", "plainaddress", "@no-local.com", "no-at.com", "two@@at.com", "a@b", "a@localhost", "a@-bad.com", "a@bad-.com",
    "a@b.c", "a b@c.com", "a@b..com", ".a@b.com", "a.@b.com", "a..b@c.com", "a@b.123", "<a@b.com>", "a@b.com,c@d.com", "ünïcode@mail.com"];
  for (const email of cases) {
    const result = validateEmail(email);
    assert.equal(result.ok, false, `should reject ${JSON.stringify(email)}`);
    assert.match(result.error, /^[A-Z].*\.$/, "error is a sentence");
  }
});

test("non-string input is rejected, not thrown", () => {
  for (const value of [undefined, null, 42, {}, []]) assert.equal(validateEmail(value).ok, false);
});

test("addresses longer than 254 characters fail", () => {
  const local = "a".repeat(64);
  const domain = `${"b".repeat(63)}.${"c".repeat(63)}.${"d".repeat(63)}.com`;
  assert.equal(validateEmail(`${local}@${domain}`).ok, false);
  assert.equal(validateEmail(`${"a".repeat(65)}@mail.com`).ok, false, "local part over 64");
});

test("reserved and disposable domains are refused", () => {
  for (const email of ["a@example.com", "a@example.org", "a@mail.test", "a@x.invalid", "a@host.local", "a@mailinator.com", "a@inbox.mailinator.com", "a@yopmail.com", "a@guerrillamail.com", "a@10minutemail.com"]) {
    assert.equal(validateEmail(email).ok, false, email);
  }
  assert.match(validateEmail("a@mailinator.com").error, /still have/);
});

test("consent accepts checkbox and JSON truthy values only", () => {
  for (const value of [true, "true", "on", "yes", "1", "ON"]) assert.equal(isConsentGiven(value), true, String(value));
  for (const value of [false, "false", "off", "", "0", undefined, null, "no"]) assert.equal(isConsentGiven(value), false, String(value));
});

test("cleanText trims, strips control characters and truncates", () => {
  assert.equal(cleanText("  hello\u0000\u0007 world  ", 200), "hello world");
  assert.equal(cleanText("x".repeat(500), 200).length, 200);
  assert.equal(cleanText(undefined, 200), "");
  assert.equal(cleanText(42, 200), "");
});

test("optional fields: mac choice and hardest-to-start answer", () => {
  assert.deepEqual(validateFields({}), { ok: true, fields: {} });
  assert.deepEqual(validateFields({ mac: "apple-silicon", hardest: "  Replying to email  " }), { ok: true, fields: { mac: "apple-silicon", hardest: "Replying to email" } });
  assert.deepEqual(validateFields({ mac: "intel" }), { ok: true, fields: { mac: "intel" } });
  assert.deepEqual(validateFields({ mac: "not-sure", hardest: "" }), { ok: true, fields: { mac: "not-sure" } });
  assert.equal(validateFields({ mac: "windows" }).ok, false);
  assert.equal(validateFields({ hardest: "x".repeat(HARDEST_MAX) }).ok, true);
  const tooLong = validateFields({ hardest: "x".repeat(HARDEST_MAX + 1) });
  assert.equal(tooLong.ok, false);
  assert.match(tooLong.error, /280/);
});

test("parseSubmission collects utm, referrer and source, each capped at 200", () => {
  const result = parseSubmission({
    email: "A@Mail.com",
    consent: "on",
    source: "hero",
    utm_source: "s".repeat(300),
    utm_medium: "social",
    utm_campaign: "",
    referrer: "https://news.ycombinator.com/item?id=1",
    mac: "intel"
  });
  assert.equal(result.ok, true);
  assert.equal(result.value.email, "a@mail.com");
  assert.equal(result.value.source, "hero");
  assert.equal(result.value.utm.utm_source.length, 200);
  assert.equal(result.value.utm.utm_medium, "social");
  assert.equal("utm_campaign" in result.value.utm, false, "empty values are dropped");
  assert.equal(result.value.utm.referrer, "https://news.ycombinator.com/item?id=1");
  assert.deepEqual(result.value.fields, { mac: "intel" });
});

test("parseSubmission requires consent", () => {
  const result = parseSubmission({ email: "a@mail.com" });
  assert.equal(result.ok, false);
  assert.match(result.error, /box/);
});
