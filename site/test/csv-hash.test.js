import { test } from "node:test";
import assert from "node:assert/strict";
import { csvCell, toCsv } from "../src/lib/csv.js";
import { sha256Hex, hashIp, timingSafeEqual } from "../src/lib/hash.js";

test("csv cells are quoted only when needed", () => {
  assert.equal(csvCell("plain"), "plain");
  assert.equal(csvCell("a,b"), '"a,b"');
  assert.equal(csvCell('say "hi"'), '"say ""hi"""');
  assert.equal(csvCell("line\nbreak"), '"line\nbreak"');
  assert.equal(csvCell(null), "");
  assert.equal(csvCell(undefined), "");
  assert.equal(csvCell(7), "7");
});

test("csv cells that a spreadsheet would run as a formula are neutralised", () => {
  for (const evil of ["=HYPERLINK(\"http://x\")", "+1+1", "-2+3", "@SUM(A1)", "\tTAB", "\rCR"]) {
    const cell = csvCell(evil);
    const unquoted = cell.startsWith('"') ? cell.slice(1, -1).replaceAll('""', '"') : cell;
    assert.equal(unquoted[0], "'", `${JSON.stringify(evil)} -> ${cell}`);
  }
  assert.equal(csvCell("=1,2"), "\"'=1,2\"");
});

test("toCsv joins header and rows with CRLF", () => {
  const csv = toCsv(["email", "note"], [["a@b.co", "x,y"], ["c@d.co", "=cmd"]]);
  assert.equal(csv, "email,note\r\na@b.co,\"x,y\"\r\nc@d.co,'=cmd\r\n");
});

test("sha256Hex matches a known vector", async () => {
  assert.equal(await sha256Hex("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
});

test("ip hashes are salted, stable and never the raw address", async () => {
  const a = await hashIp("203.0.113.7", "salt-one");
  const b = await hashIp("203.0.113.7", "salt-one");
  const c = await hashIp("203.0.113.7", "salt-two");
  assert.equal(a, b);
  assert.notEqual(a, c);
  assert.match(a, /^[0-9a-f]{64}$/);
  assert.equal(a.includes("203.0.113.7"), false);
});

test("timingSafeEqual compares secrets of any length", async () => {
  assert.equal(await timingSafeEqual("token-123", "token-123"), true);
  assert.equal(await timingSafeEqual("token-123", "token-124"), false);
  assert.equal(await timingSafeEqual("short", "much-longer-token"), false);
  assert.equal(await timingSafeEqual("", ""), false, "empty secrets never match");
  assert.equal(await timingSafeEqual(undefined, "x"), false);
});
