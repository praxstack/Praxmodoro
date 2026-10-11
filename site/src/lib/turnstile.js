// Optional Cloudflare Turnstile verification. Fails closed on any error.

export const TURNSTILE_VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify";

export async function verifyTurnstile({ secret, token, ip, fetchImpl = globalThis.fetch }) {
  if (!secret || !token) return false;
  const body = new URLSearchParams({ secret, response: token });
  if (ip && ip !== "unknown") body.set("remoteip", ip);
  try {
    const response = await fetchImpl(TURNSTILE_VERIFY_URL, { method: "POST", body });
    if (!response.ok) return false;
    const data = await response.json();
    return data?.success === true;
  } catch {
    return false;
  }
}
