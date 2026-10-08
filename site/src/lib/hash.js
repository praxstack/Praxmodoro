// Hashing helpers built on Web Crypto (available in Workers and Node 22).

const encoder = new TextEncoder();

export async function sha256Bytes(text) {
  return new Uint8Array(await crypto.subtle.digest("SHA-256", encoder.encode(String(text))));
}

export async function sha256Hex(text) {
  const bytes = await sha256Bytes(text);
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

/** Salted SHA-256 of an IP address. The raw address is never stored or logged. */
export async function hashIp(ip, salt) {
  return sha256Hex(`${salt}:${ip}`);
}

/**
 * Constant-time comparison for secrets of any length: both sides are hashed
 * first, so the comparison loop always runs over 32 bytes and length is not leaked.
 */
export async function timingSafeEqual(a, b) {
  if (typeof a !== "string" || typeof b !== "string" || a.length === 0 || b.length === 0) return false;
  const [left, right] = await Promise.all([sha256Bytes(a), sha256Bytes(b)]);
  let diff = 0;
  for (let i = 0; i < left.length; i += 1) diff |= left[i] ^ right[i];
  return diff === 0;
}
