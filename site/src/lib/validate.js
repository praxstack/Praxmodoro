// Pure input validation for the waitlist. No I/O; every error is a plain
// sentence the page can show as-is.

export const EMAIL_MAX = 254;
export const FIELD_MAX = 200;
export const HARDEST_MAX = 280;
export const MAC_CHOICES = Object.freeze(["apple-silicon", "intel", "not-sure"]);
const UTM_KEYS = ["utm_source", "utm_medium", "utm_campaign", "referrer"];

export const MESSAGES = Object.freeze({
  emailMissing: "Enter your email address.",
  emailInvalid: "That email address doesn't look complete. Check it and try again.",
  emailTooLong: "That email address is too long.",
  emailDisposable: "Please use an email address you'll still have when the beta opens.",
  consent: "Tick the box so we can email you about the beta.",
  mac: "Choose Apple silicon, Intel or Not sure for your Mac.",
  hardest: `Keep the answer to ${HARDEST_MAX} characters or fewer.`
});

// RFC 2606 / 6761 reserved names: never a real inbox.
const RESERVED_TLDS = new Set(["test", "example", "invalid", "localhost", "local", "internal", "onion", "lan", "home", "corp"]);
const RESERVED_DOMAINS = new Set(["example.com", "example.net", "example.org"]);

// Common throwaway-inbox services. Not exhaustive; it only catches the obvious.
const DISPOSABLE_DOMAINS = new Set([
  "10minutemail.com", "10minutemail.net", "20minutemail.com", "burnermail.io", "discard.email", "dispostable.com",
  "emailondeck.com", "fakeinbox.com", "getnada.com", "grr.la", "guerrillamail.biz", "guerrillamail.com",
  "guerrillamail.de", "guerrillamail.info", "guerrillamail.net", "guerrillamail.org", "guerrillamailblock.com",
  "inboxkitten.com", "mailcatch.com", "maildrop.cc", "mailinator.com", "mailinator.net", "mailnesia.com",
  "mintemail.com", "moakt.com", "mohmal.com", "mytemp.email", "nada.email", "sharklasers.com", "spam4.me",
  "spamgourmet.com", "temp-mail.io", "temp-mail.org", "tempail.com", "tempmail.com", "tempmail.dev",
  "tempmailo.com", "tempr.email", "throwawaymail.com", "trashmail.com", "trashmail.de", "trashmail.net",
  "yopmail.com", "yopmail.fr", "yopmail.net"
]);

const LOCAL_PART = /^[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*$/;
const DOMAIN_LABEL = /^(?!-)[a-z0-9-]{1,63}(?<!-)$/;
const TLD = /^(?:[a-z]{2,63}|xn--[a-z0-9-]{2,59})$/;

function domainMatches(domain, set) {
  const labels = domain.split(".");
  for (let i = 0; i < labels.length - 1; i += 1) {
    if (set.has(labels.slice(i).join("."))) return true;
  }
  return false;
}

/** Trim + lower-case, then a sensible (not full RFC 5322) syntax check. */
export function validateEmail(raw) {
  if (typeof raw !== "string") return { ok: false, error: MESSAGES.emailMissing };
  const email = raw.trim().toLowerCase();
  if (!email) return { ok: false, error: MESSAGES.emailMissing };
  if (email.length > EMAIL_MAX) return { ok: false, error: MESSAGES.emailTooLong };

  const at = email.lastIndexOf("@");
  if (at < 1 || email.indexOf("@") !== at) return { ok: false, error: MESSAGES.emailInvalid };
  const local = email.slice(0, at);
  const domain = email.slice(at + 1);
  if (local.length > 64 || !LOCAL_PART.test(local)) return { ok: false, error: MESSAGES.emailInvalid };

  const labels = domain.split(".");
  if (labels.length < 2 || !labels.every((label) => DOMAIN_LABEL.test(label))) return { ok: false, error: MESSAGES.emailInvalid };
  const tld = labels.at(-1);
  if (!TLD.test(tld) || RESERVED_TLDS.has(tld) || RESERVED_DOMAINS.has(domain)) return { ok: false, error: MESSAGES.emailInvalid };
  if (domainMatches(domain, DISPOSABLE_DOMAINS)) return { ok: false, error: MESSAGES.emailDisposable };

  return { ok: true, email };
}

/** A checkbox posts "on"; JSON clients send true. Anything else is no consent. */
export function isConsentGiven(value) {
  if (value === true) return true;
  if (typeof value !== "string") return false;
  return ["true", "on", "yes", "1"].includes(value.trim().toLowerCase());
}

/** Trim, drop control characters, collapse runs of spaces, cap length. Non-strings become "". */
export function cleanText(value, max) {
  if (typeof value !== "string") return "";
  const cleaned = value
    .replace(/[\u0000-\u0008\u000b-\u001f\u007f]/g, "")
    .replace(/[ \t]{2,}/g, " ")
    .trim();
  return cleaned.slice(0, max);
}

/** Praxmodoro's optional questions: which Mac, and what's hardest to start. */
export function validateFields(input = {}) {
  const fields = {};
  const mac = cleanText(input.mac, 40);
  if (mac) {
    if (!MAC_CHOICES.includes(mac)) return { ok: false, error: MESSAGES.mac };
    fields.mac = mac;
  }
  const rawHardest = typeof input.hardest === "string" ? input.hardest.replace(/[\u0000-\u0008\u000b-\u001f\u007f]/g, "").trim() : "";
  if (rawHardest.length > HARDEST_MAX) return { ok: false, error: MESSAGES.hardest };
  if (rawHardest) fields.hardest = rawHardest;
  return { ok: true, fields };
}

/** Validate a decoded request body (honeypot and Turnstile are handled by the caller). */
export function parseSubmission(body = {}) {
  const email = validateEmail(body.email);
  if (!email.ok) return email;
  if (!isConsentGiven(body.consent)) return { ok: false, error: MESSAGES.consent };
  const fields = validateFields(body);
  if (!fields.ok) return fields;

  const utm = {};
  for (const key of UTM_KEYS) {
    const value = cleanText(body[key], FIELD_MAX);
    if (value) utm[key] = value;
  }
  const source = cleanText(body.source, FIELD_MAX) || null;

  return { ok: true, value: { email: email.email, fields: fields.fields, utm, source } };
}
