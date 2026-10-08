// Praxmodoro website behaviour. Progressive enhancement only: every form works
// without this file, and nothing here sends data anywhere except the waitlist
// form to /api/waitlist on this same site. The breathing light is pure CSS; this
// file only lets visitors hold it still.

const root = document.documentElement;
const MOTION_KEY = "praxmodoro:motion";

/* ---------- motion: system Reduce Motion, or the page's own switch ---------- */

const reduceQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
let motionChoice = null;
try {
  motionChoice = window.localStorage.getItem(MOTION_KEY);
} catch {
  motionChoice = null;
}

const isStill = () => reduceQuery.matches || motionChoice === "still";

function applyMotion() {
  const still = isStill();
  root.dataset.motion = still ? "still" : "gentle";
  for (const toggle of document.querySelectorAll("[data-motion-toggle]")) {
    // With system Reduce Motion the hero's own pause button has nothing to do, so it stays away.
    toggle.hidden = reduceQuery.matches && toggle.hasAttribute("data-system-hides");
    const label = toggle.querySelector("[data-motion-label]");
    const gentleLabel = toggle.dataset.labelGentle || "Motion: gentle";
    const stillLabel = toggle.dataset.labelStill || "Motion: still";
    if (label) label.textContent = still ? stillLabel : gentleLabel;
    if (reduceQuery.matches) {
      toggle.setAttribute("aria-disabled", "true");
      toggle.title = "Reduce Motion is on in your system settings, so this page stays still.";
    } else {
      toggle.removeAttribute("aria-disabled");
      toggle.title = still ? "Let the light breathe again" : "Hold the breathing light still";
    }
  }
}

document.addEventListener("click", (event) => {
  const toggle = event.target.closest("[data-motion-toggle]");
  if (!toggle || reduceQuery.matches) return;
  motionChoice = isStill() ? "gentle" : "still";
  try {
    window.localStorage.setItem(MOTION_KEY, motionChoice);
  } catch {
    /* private mode: the choice lasts for this visit */
  }
  applyMotion();
});
reduceQuery.addEventListener?.("change", applyMotion);

applyMotion();

/* ---------- try the first step: runs entirely in this page ---------- */

function setupTry() {
  const form = document.querySelector("[data-try]");
  const held = document.querySelector("[data-try-held]");
  if (!form || !held) return;
  const task = form.querySelector("#try-task");
  const step = form.querySelector("#try-step");
  const outStep = held.querySelector("[data-try-step]");
  const outTask = held.querySelector("[data-try-task]");
  const announce = document.querySelector("[data-try-announce]");
  form.hidden = false;

  form.addEventListener("submit", (event) => {
    event.preventDefault();
    const taskText = task.value.trim() || task.placeholder;
    const stepText = step.value.trim() || step.placeholder;
    outStep.textContent = stepText;
    outTask.textContent = `For: ${taskText}`;
    form.hidden = true;
    held.hidden = false;
    held.focus({ preventScroll: true });
    if (announce) announce.textContent = `Holding your step: ${stepText}.`;
  });

  held.querySelector("[data-try-reset]")?.addEventListener("click", () => {
    held.hidden = true;
    form.hidden = false;
    step.focus();
    step.select();
    if (announce) announce.textContent = "";
  });
}

setupTry();

/* ---------- waitlist forms ---------- */

const EMAIL_SHAPE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

function fillAttribution(form) {
  const params = new URLSearchParams(window.location.search);
  for (const key of ["utm_source", "utm_medium", "utm_campaign"]) {
    const input = form.querySelector(`input[name="${key}"]`);
    if (input && params.get(key)) input.value = params.get(key).slice(0, 200);
  }
  const referrer = form.querySelector('input[name="referrer"]');
  if (referrer && document.referrer) {
    try {
      const ref = new URL(document.referrer);
      if (ref.origin !== window.location.origin) referrer.value = `${ref.origin}${ref.pathname}`.slice(0, 200);
    } catch {
      /* ignore malformed referrers */
    }
  }
}

function showSuccess(form, { already = false, focus = true } = {}) {
  const success = form.parentElement.querySelector("[data-success]");
  if (!success) return;
  const title = success.querySelector("[data-success-title]");
  const text = success.querySelector("[data-success-text]");
  if (already) {
    title.textContent = "You're already on the list.";
    text.textContent = "Nothing else to do. We'll email you when a beta spot opens.";
  }
  form.hidden = true;
  success.hidden = false;
  if (focus) success.focus({ preventScroll: false });
}

function setupForm(form) {
  form.noValidate = true;
  fillAttribution(form);
  const email = form.querySelector('input[name="email"]');
  const consent = form.querySelector('input[name="consent"]');
  const status = form.querySelector("[data-status]");
  const submit = form.querySelector("[data-submit]");
  const submitLabel = form.querySelector("[data-submit-label]");
  const idleLabel = submitLabel?.textContent ?? "";

  const setStatus = (text, tone = "") => {
    status.textContent = text;
    if (tone) status.dataset.tone = tone;
    else delete status.dataset.tone;
  };

  const clearInvalid = () => {
    email.removeAttribute("aria-invalid");
    consent.removeAttribute("aria-invalid");
  };
  email.addEventListener("input", clearInvalid);
  consent.addEventListener("change", clearInvalid);

  const textarea = form.querySelector("textarea[maxlength]");
  const counter = textarea && form.querySelector(`[data-counter-for="${textarea.id}"]`);
  if (textarea && counter) {
    const max = Number(textarea.getAttribute("maxlength"));
    const update = () => {
      counter.textContent = `${textarea.value.length} / ${max}`;
      counter.dataset.near = String(textarea.value.length > max - 20);
    };
    textarea.addEventListener("input", update);
    update();
  }

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (submit.getAttribute("aria-busy") === "true") return;
    clearInvalid();

    const value = email.value.trim();
    if (!value || !EMAIL_SHAPE.test(value)) {
      email.setAttribute("aria-invalid", "true");
      setStatus(value ? "That email address doesn't look complete. Check it and try again." : "Enter your email address.", "error");
      email.focus();
      return;
    }
    if (!consent.checked) {
      consent.setAttribute("aria-invalid", "true");
      setStatus("Tick the box so we can email you about the beta.", "error");
      consent.focus();
      return;
    }

    const data = Object.fromEntries(new FormData(form).entries());
    data.email = value;
    data.consent = true;

    submit.setAttribute("aria-busy", "true");
    if (submitLabel) submitLabel.textContent = "Joining…";
    setStatus("Sending…");

    try {
      const response = await fetch(form.action, {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify(data),
        credentials: "same-origin"
      });
      const body = await response.json().catch(() => ({}));
      if (response.ok && body.ok) {
        setStatus("");
        showSuccess(form, { already: Boolean(body.already) });
        return;
      }
      const fallback =
        response.status === 429 ? "Too many tries from this connection. Wait a few minutes and try again." : "Something went wrong on our side. Please try again in a minute.";
      setStatus(body.error || fallback, "error");
      if (/email/i.test(body.error || "")) {
        email.setAttribute("aria-invalid", "true");
        email.focus();
      }
      window.turnstile?.reset?.(form.querySelector(".cf-turnstile"));
    } catch {
      setStatus("We couldn't reach the server. Check your connection and try again.", "error");
    } finally {
      submit.removeAttribute("aria-busy");
      if (submitLabel) submitLabel.textContent = idleLabel;
    }
  });
}

document.querySelectorAll("[data-waitlist-form]").forEach(setupForm);

// After a sign-up without JavaScript the server redirects to /?joined=1#join.
// The middleware already swaps the form for the success note; this tidies the URL.
const params = new URLSearchParams(window.location.search);
if (params.get("joined") === "1") {
  const joinForm = document.querySelector("[data-join-form]");
  if (joinForm && !joinForm.hidden) showSuccess(joinForm, { focus: false });
  params.delete("joined");
  const query = params.toString();
  window.history.replaceState(null, "", `${window.location.pathname}${query ? `?${query}` : ""}${window.location.hash}`);
}
