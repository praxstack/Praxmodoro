// POST /api/waitlist: the whole request flow, kept free of Pages specifics so
// it can be tested with a plain Request and an in-memory D1.
import { cleanText, parseSubmission } from "./validate.js";
import { hashIp } from "./hash.js";
import { hitRateLimit } from "./ratelimit.js";
import { verifyTurnstile } from "./turnstile.js";
import { BadRequest, clientIp, htmlMessage, isAllowedOrigin, json, methodNotAllowed, readBody, wantsJson } from "./http.js";

export const PRODUCT = "praxmodoro";
export const JOINED_REDIRECT = "/?joined=1#join";
// Used only when IP_HASH_SALT is not configured, so local development works.
// Production must set IP_HASH_SALT (see README); without it hashes are guessable.
const FALLBACK_SALT = "praxmodoro-local-development-salt";

export const API_MESSAGES = Object.freeze({
  method: "Use POST to join the waitlist.",
  origin: "This form only accepts sign-ups from the Praxmodoro website.",
  unreadable: "We couldn't read that sign-up. Please try again.",
  rateLimited: "Too many tries from this connection. Wait a few minutes and try again.",
  turnstile: "We couldn't confirm this came from a person. Reload the page and try again.",
  server: "Something went wrong on our side. Please try again in a minute."
});

const INSERT_SQL = `INSERT INTO waitlist (email, product, fields, source, utm, consent_at, created_at, ip_hash)
  VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  ON CONFLICT (email) DO NOTHING`;

export async function handleWaitlist(context, { now = () => new Date(), fetchImpl = globalThis.fetch } = {}) {
  const { request, env } = context;
  if (request.method !== "POST") return methodNotAllowed(["POST"], API_MESSAGES.method);

  const asJson = wantsJson(request);
  const fail = (status, error, headers = {}) =>
    asJson ? json({ ok: false, error }, status, headers) : htmlMessage(status, "That didn't go through.", error, headers);
  const succeed = (data) =>
    asJson ? json(data) : new Response(null, { status: 303, headers: { Location: JOINED_REDIRECT, "Cache-Control": "no-store" } });

  if (!isAllowedOrigin(request)) return fail(403, API_MESSAGES.origin);

  let body;
  try {
    body = await readBody(request);
  } catch (error) {
    if (error instanceof BadRequest) return fail(400, API_MESSAGES.unreadable);
    throw error;
  }

  // Honeypot: people never see the "website" field, so anything in it is a bot.
  // Answer exactly like a success and store nothing.
  if (cleanText(body.website, 500)) return succeed({ ok: true });

  try {
    const current = now();
    const ip = clientIp(request);
    const ipHash = await hashIp(ip, env.IP_HASH_SALT || FALLBACK_SALT);

    const limit = await hitRateLimit(env.DB, ipHash, current.getTime());
    if (!limit.allowed) return fail(429, API_MESSAGES.rateLimited, { "Retry-After": String(limit.retryAfterSeconds) });

    if (env.TURNSTILE_SECRET) {
      const token = cleanText(body["cf-turnstile-response"], 4096);
      const human = await verifyTurnstile({ secret: env.TURNSTILE_SECRET, token, ip, fetchImpl });
      if (!human) return fail(400, API_MESSAGES.turnstile);
    }

    const parsed = parseSubmission(body);
    if (!parsed.ok) return fail(400, parsed.error);
    const { email, fields, utm, source } = parsed.value;
    const stamp = current.toISOString();

    const result = await env.DB.prepare(INSERT_SQL)
      .bind(email, PRODUCT, JSON.stringify(fields), source, JSON.stringify(utm), stamp, stamp, ipHash)
      .run();
    const inserted = Number(result?.meta?.changes ?? 0) > 0;
    // Duplicate: say so, and nothing else (no dates, no stored answers).
    return succeed(inserted ? { ok: true } : { ok: true, already: true });
  } catch (error) {
    console.error("waitlist: unexpected error:", error instanceof Error ? error.message : String(error));
    return fail(500, API_MESSAGES.server);
  }
}
