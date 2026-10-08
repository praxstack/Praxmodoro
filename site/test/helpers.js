// Shared test helpers: an in-memory D1 stand-in backed by real SQLite
// (node:sqlite), loaded with the real migration, plus request builders.
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";

const MIGRATION = readFileSync(new URL("../migrations/0001_waitlist.sql", import.meta.url), "utf8");

export const ORIGIN = "https://praxmodoro.pages.dev";

/** Minimal D1Database lookalike: prepare().bind().first()/run()/all(), batch(). */
export function createD1() {
  const db = new DatabaseSync(":memory:");
  db.exec(MIGRATION);
  const prepare = (sql) => {
    let args = [];
    const statement = {
      bind(...values) {
        args = values.map((value) => (value === undefined ? null : value));
        return statement;
      },
      async first(column) {
        const row = db.prepare(sql).get(...args);
        if (!row) return null;
        const plain = { ...row };
        return column ? plain[column] : plain;
      },
      async run() {
        const info = db.prepare(sql).run(...args);
        return { success: true, results: [], meta: { changes: Number(info.changes), last_row_id: Number(info.lastInsertRowid) } };
      },
      async all() {
        const results = db.prepare(sql).all(...args).map((row) => ({ ...row }));
        return { success: true, results, meta: {} };
      }
    };
    return statement;
  };
  return {
    prepare,
    async batch(statements) {
      return Promise.all(statements.map((statement) => statement.run()));
    },
    rows(sql = "SELECT * FROM waitlist ORDER BY id") {
      return db.prepare(sql).all().map((row) => ({ ...row }));
    }
  };
}

export function createEnv(overrides = {}) {
  return {
    DB: createD1(),
    IP_HASH_SALT: "test-salt-please-ignore",
    ADMIN_TOKEN: "test-admin-token-0123456789abcdef",
    ...overrides
  };
}

export function context(request, env) {
  return { request, env, params: {}, data: {}, waitUntil() {}, next: async () => new Response("next") };
}

let ipCounter = 10;
/** A fresh documentation-range IP per call, so rate limits only bite when a test wants them to. */
export function freshIp() {
  ipCounter += 1;
  return `203.0.113.${ipCounter % 250}`;
}

export function jsonRequest(body, { ip = freshIp(), origin = ORIGIN, headers = {}, url = `${ORIGIN}/api/waitlist`, method = "POST" } = {}) {
  const init = {
    method,
    headers: {
      "content-type": "application/json",
      accept: "application/json",
      "cf-connecting-ip": ip,
      ...(origin ? { origin } : {}),
      ...headers
    }
  };
  if (method !== "GET" && method !== "HEAD") init.body = typeof body === "string" ? body : JSON.stringify(body);
  return new Request(url, init);
}

export function formRequest(fields, { ip = freshIp(), origin = ORIGIN, url = `${ORIGIN}/api/waitlist` } = {}) {
  return new Request(url, {
    method: "POST",
    headers: {
      "content-type": "application/x-www-form-urlencoded",
      accept: "text/html,application/xhtml+xml",
      "cf-connecting-ip": ip,
      ...(origin ? { origin } : {})
    },
    body: new URLSearchParams(fields).toString()
  });
}

export const valid = Object.freeze({ email: "Asha.Rao@Proton.me ", consent: true, source: "hero" });
