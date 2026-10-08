// Small HTTP helpers shared by the Pages Functions.
import { API_HEADERS, pageSecurityHeaders } from "./security-headers.js";

export const BODY_LIMIT_BYTES = 16 * 1024;

export class BadRequest extends Error {}

export function json(data, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8", ...API_HEADERS, ...extraHeaders }
  });
}

export function methodNotAllowed(allowed, message) {
  return json({ ok: false, error: message }, 405, { Allow: allowed.join(", ") });
}

/** Browser form posts without JavaScript ask for HTML; fetch() and curl get JSON. */
export function wantsJson(request) {
  const type = (request.headers.get("content-type") || "").toLowerCase();
  const accept = (request.headers.get("accept") || "").toLowerCase();
  if (type.includes("application/json") || accept.includes("application/json")) return true;
  return !accept.includes("text/html");
}

const LOCAL_HOSTS = new Set(["localhost", "127.0.0.1", "[::1]", "::1"]);

/**
 * Same-origin check. Requests without an Origin header (curl, some older
 * browsers on same-origin form posts) are allowed; the rate limit still applies.
 * In local development any localhost origin may talk to a localhost server.
 */
export function isAllowedOrigin(request) {
  const origin = request.headers.get("origin");
  if (origin === null || origin === undefined || origin === "") return true;
  let from;
  try {
    from = new URL(origin);
  } catch {
    return false;
  }
  const to = new URL(request.url);
  if (from.host === to.host) return true;
  return LOCAL_HOSTS.has(from.hostname) && LOCAL_HOSTS.has(to.hostname);
}

export function clientIp(request) {
  const direct = request.headers.get("cf-connecting-ip") || request.headers.get("x-real-ip");
  if (direct) return direct.trim();
  const forwarded = request.headers.get("x-forwarded-for");
  if (forwarded) return forwarded.split(",")[0].trim();
  return "unknown";
}

function pickStrings(entries) {
  const out = {};
  for (const [key, value] of entries) {
    if (typeof value === "string" && !(key in out)) out[key] = value;
  }
  return out;
}

/** Decode a JSON, urlencoded or multipart body into a flat object of strings/booleans. */
export async function readBody(request) {
  const type = (request.headers.get("content-type") || "").toLowerCase();
  const declared = Number(request.headers.get("content-length") || 0);
  if (declared > BODY_LIMIT_BYTES) throw new BadRequest("too large");

  if (type.includes("multipart/form-data")) {
    const form = await request.formData();
    return pickStrings(form.entries());
  }

  const text = await request.text();
  if (text.length > BODY_LIMIT_BYTES) throw new BadRequest("too large");

  if (type.includes("application/x-www-form-urlencoded")) {
    return pickStrings(new URLSearchParams(text).entries());
  }
  if (type.includes("application/json") || type === "") {
    let data;
    try {
      data = JSON.parse(text);
    } catch {
      throw new BadRequest("bad json");
    }
    if (!data || typeof data !== "object" || Array.isArray(data)) throw new BadRequest("not an object");
    return data;
  }
  throw new BadRequest("unsupported type");
}

export function escapeHtml(text) {
  return String(text)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

/** A tiny, styled page for visitors whose browser posted the form without JavaScript. */
export function htmlMessage(status, heading, message, extraHeaders = {}) {
  const body = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>${escapeHtml(heading)} · Praxmodoro</title>
<link rel="stylesheet" href="/assets/css/site.css">
</head>
<body class="plain-page">
<main class="notice" id="main">
<p class="quiet-label">Praxmodoro beta waitlist</p>
<h1>${escapeHtml(heading)}</h1>
<p>${escapeHtml(message)}</p>
<p><a class="button button-primary" href="/#join">Back to the form</a></p>
</main>
</body>
</html>
`;
  return new Response(body, {
    status,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store",
      ...pageSecurityHeaders(),
      ...extraHeaders
    }
  });
}
