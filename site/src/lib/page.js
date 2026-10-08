// Server-side touches for the HTML landing page, applied by functions/_middleware.js
// (which public/_routes.json limits to "/" and "/api/*").
//   1. Security headers, with the Turnstile origin allowed only when Turnstile is configured.
//   2. With TURNSTILE_SITE_KEY set: the Turnstile script and one widget per waitlist form.
//   3. After a no-JavaScript sign-up (/?joined=1): show the success note instead of the form.
import { escapeHtml } from "./http.js";
import { pageSecurityHeaders, TURNSTILE_ORIGIN } from "./security-headers.js";

export function turnstileEnabled(env = {}) {
  return typeof env.TURNSTILE_SITE_KEY === "string" && env.TURNSTILE_SITE_KEY.trim() !== "";
}

export function isHtml(response) {
  return (response.headers.get("content-type") || "").toLowerCase().includes("text/html");
}

export function decoratePage(response, { request, env }) {
  if (!isHtml(response)) return response;
  const turnstile = turnstileEnabled(env);
  const headers = new Headers(response.headers);
  for (const [name, value] of Object.entries(pageSecurityHeaders({ turnstile }))) headers.set(name, value);
  let decorated = new Response(response.body, { status: response.status, statusText: response.statusText, headers });

  const url = new URL(request.url);
  const joined = url.pathname === "/" && url.searchParams.get("joined") === "1";
  if ((!turnstile && !joined) || typeof HTMLRewriter === "undefined") return decorated;

  let rewriter = new HTMLRewriter();
  if (turnstile) {
    const siteKey = escapeHtml(env.TURNSTILE_SITE_KEY.trim());
    rewriter = rewriter
      .on("head", {
        element(head) {
          head.append(`<script src="${TURNSTILE_ORIGIN}/turnstile/v0/api.js" async defer></script>`, { html: true });
        }
      })
      .on("[data-turnstile-slot]", {
        element(slot) {
          slot.removeAttribute("hidden");
          slot.setInnerContent(`<div class="cf-turnstile" data-sitekey="${siteKey}" data-theme="auto" data-size="flexible"></div>`, { html: true });
        }
      });
  }
  if (joined) {
    rewriter = rewriter
      .on("[data-join-success]", { element(el) { el.removeAttribute("hidden"); } })
      .on("[data-join-form]", { element(el) { el.setAttribute("hidden", ""); } });
  }
  decorated = rewriter.transform(decorated);
  return decorated;
}
