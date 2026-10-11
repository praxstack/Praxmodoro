// One source of truth for the page security headers. public/_headers carries
// the same values for static files (a test keeps the two in sync); the
// middleware reuses them for "/" so it can widen the CSP for Turnstile only
// when Turnstile is actually configured.

export const TURNSTILE_ORIGIN = "https://challenges.cloudflare.com";

export function buildCsp({ turnstile = false } = {}) {
  return [
    "default-src 'self'",
    turnstile ? `script-src 'self' ${TURNSTILE_ORIGIN}` : "script-src 'self'",
    "style-src 'self'",
    "img-src 'self' data:",
    "font-src 'self'",
    "connect-src 'self'",
    turnstile ? `frame-src ${TURNSTILE_ORIGIN}` : "frame-src 'none'",
    "frame-ancestors 'none'",
    "base-uri 'self'",
    "form-action 'self'",
    "object-src 'none'",
    "manifest-src 'self'"
  ].join("; ");
}

export const PERMISSIONS_POLICY = "camera=(), microphone=(), geolocation=(), payment=(), usb=(), browsing-topics=()";

export function pageSecurityHeaders({ turnstile = false } = {}) {
  return {
    "Content-Security-Policy": buildCsp({ turnstile }),
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "strict-origin-when-cross-origin",
    "Permissions-Policy": PERMISSIONS_POLICY,
    "X-Frame-Options": "DENY",
    "Cross-Origin-Opener-Policy": "same-origin"
  };
}

/** Headers for API responses: nothing to render, nothing to cache. */
export const API_HEADERS = Object.freeze({
  "Cache-Control": "no-store",
  "Content-Security-Policy": "default-src 'none'; frame-ancestors 'none'",
  "X-Content-Type-Options": "nosniff",
  "Referrer-Policy": "strict-origin-when-cross-origin"
});
