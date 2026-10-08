// Praxmodoro website behaviour. Progressive enhancement only: every form works
// without this file, and nothing here sends data anywhere except the waitlist
// form to /api/waitlist on this same site.
import { startCompanions } from "./companion.js";

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
let companions = null;

function applyMotion() {
  const still = isStill();
  root.dataset.motion = still ? "still" : "gentle";
  for (const toggle of document.querySelectorAll("[data-motion-toggle]")) {
    toggle.hidden = false;
    const label = toggle.querySelector("[data-motion-label]");
    if (label) label.textContent = still ? "Motion: still" : "Motion: gentle";
    if (reduceQuery.matches) {
      toggle.setAttribute("aria-disabled", "true");
      toggle.title = "Reduce Motion is on in your system settings, so this page stays still.";
    } else {
      toggle.removeAttribute("aria-disabled");
      toggle.title = still ? "Let the companion field breathe" : "Hold the companion field still";
    }
  }
  companions?.sync();
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
companions = startCompanions({ isStill });

/* ---------- header gains a veil once the page scrolls ---------- */

const header = document.querySelector("[data-header]");
if (header) {
  let ticking = false;
  const update = () => {
    header.dataset.scrolled = String(window.scrollY > 8);
    ticking = false;
  };
  window.addEventListener(
    "scroll",
    () => {
      if (!ticking) {
        ticking = true;
        requestAnimationFrame(update);
      }
    },
    { passive: true }
  );
  update();
}

/* ---------- Begin demo: runs entirely in this page ---------- */

const FOCUS_SECONDS = 5 * 60;
const BREAK_SECONDS = 3 * 60;

function formatTime(totalSeconds) {
  const s = Math.max(0, totalSeconds);
  return `${String(Math.floor(s / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`;
}

/** A countdown derived from timestamps, so a hidden tab or a slow frame never drifts it. */
function countdown(seconds, onTick, onDone) {
  let endsAt = 0;
  let remaining = seconds;
  let interval = null;
  let lastShown = null;
  const left = () => (interval ? Math.max(0, Math.ceil((endsAt - Date.now()) / 1000)) : remaining);
  const tick = () => {
    const now = left();
    if (now !== lastShown) {
      lastShown = now;
      onTick(now);
    }
    if (interval && now <= 0) {
      api.hold();
      onDone();
    }
  };
  const api = {
    get running() {
      return interval !== null;
    },
    start() {
      if (interval) return;
      endsAt = Date.now() + remaining * 1000;
      interval = window.setInterval(tick, 250);
      tick();
    },
    hold() {
      if (!interval) return;
      remaining = left();
      window.clearInterval(interval);
      interval = null;
    },
    reset(next = seconds) {
      api.hold();
      remaining = next;
      lastShown = null;
      tick();
    }
  };
  return api;
}

function setupDemo() {
  const demo = document.querySelector("[data-demo]");
  const field = document.querySelector("[data-demo-field]");
  if (!demo || !field) return;

  const form = demo.querySelector("[data-demo-form]");
  const taskInput = demo.querySelector("#demo-task");
  const stepInput = demo.querySelector("#demo-step");
  const panels = Object.fromEntries([...demo.querySelectorAll("[data-panel]")].map((p) => [p.dataset.panel, p]));
  const announce = demo.querySelector("[data-announce]");
  const after = demo.querySelector("[data-demo-after]");
  const message = demo.querySelector("[data-message]");
  const focusTime = demo.querySelector("[data-focus-time]");
  const focusState = demo.querySelector("[data-focus-state]");
  const breakTime = demo.querySelector("[data-break-time]");
  const breakState = demo.querySelector("[data-break-state]");
  const holdLabel = demo.querySelector("[data-hold-label]");
  const holdButton = demo.querySelector('[data-action="hold"]');
  const beginTitle = demo.querySelector("[data-begin-title]");
  const beginSub = demo.querySelector("[data-begin-sub]");
  const stepHint = demo.querySelector("[data-step-hint]");

  let stage = "begin";
  let resuming = false;
  let finished = false;

  const say = (text) => {
    announce.textContent = "";
    window.setTimeout(() => (announce.textContent = text), 60);
  };

  const focusTimer = countdown(
    FOCUS_SECONDS,
    (left) => {
      focusTime.textContent = formatTime(left);
    },
    () => {
      finished = true;
      field.dataset.state = "settled";
      focusState.textContent = "Gentle start done";
      message.textContent = "In the app, the full block carries on from here, or you stop. Both count.";
      setHold(false, true);
      say("Gentle start done.");
    }
  );

  const breakTimer = countdown(
    BREAK_SECONDS,
    (left) => {
      breakTime.textContent = formatTime(left);
    },
    () => {
      breakState.textContent = "Break time is up. Come back when you're ready.";
      say("Break time is up.");
    }
  );

  function setHold(held, disabled = false) {
    holdLabel.textContent = held ? "Resume" : "Hold";
    holdButton.querySelector('[data-hold-icon="pause"]').hidden = held;
    holdButton.querySelector('[data-hold-icon="play"]').hidden = !held;
    holdButton.disabled = disabled;
  }

  function show(next, { focus = true } = {}) {
    stage = next;
    demo.dataset.stage = next;
    for (const [name, panel] of Object.entries(panels)) {
      const active = name === next;
      panel.hidden = !active;
      if (active) {
        panel.classList.remove("demo-enter");
        void panel.offsetWidth;
        panel.classList.add("demo-enter");
      }
    }
    if (focus) {
      const target = next === "begin" ? stepInput : panels[next];
      target?.focus({ preventScroll: true });
    }
  }

  function fill(selector, text) {
    for (const el of demo.querySelectorAll(selector)) el.textContent = text;
  }

  function beginFocus() {
    const task = taskInput.value.trim() || taskInput.placeholder;
    const step = stepInput.value.trim() || stepInput.placeholder;
    fill('[data-out="task"]', task);
    fill('[data-out="step"]', step);
    message.textContent = "";
    const wasResuming = resuming;
    if (!resuming) {
      finished = false;
      focusTimer.reset(FOCUS_SECONDS);
    }
    resuming = false;
    setHold(false);
    focusState.textContent = "Breathing with you";
    field.dataset.state = "breathing";
    show("focus");
    focusTimer.start();
    after.hidden = false;
    say(wasResuming ? `Back to focus. Next step: ${step}.` : `Focus started on ${task}. Next step: ${step}. A five-minute gentle start.`);
  }

  form.addEventListener("submit", (event) => {
    event.preventDefault();
    beginFocus();
  });

  form.addEventListener("keydown", (event) => {
    if (event.key === "Enter" && (event.metaKey || event.ctrlKey)) {
      event.preventDefault();
      beginFocus();
    }
  });

  demo.addEventListener("click", (event) => {
    const action = event.target.closest("[data-action]")?.dataset.action;
    const answer = event.target.closest("[data-answer]")?.dataset.answer;
    if (action === "hold") {
      if (finished) return;
      if (focusTimer.running) {
        focusTimer.hold();
        setHold(true);
        field.dataset.state = "held";
        focusState.textContent = "Held. Your place is kept.";
        say("Timer held.");
      } else {
        focusTimer.start();
        setHold(false);
        field.dataset.state = "breathing";
        focusState.textContent = "Breathing with you";
        say("Timer resumed.");
      }
    } else if (action === "checkin") {
      focusTimer.hold();
      field.dataset.state = "ripple";
      show("checkin");
      say("Check-in. How does the step fit right now?");
    } else if (action === "reset") {
      focusTimer.reset(FOCUS_SECONDS);
      breakTimer.reset(BREAK_SECONDS);
      finished = false;
      resuming = false;
      field.dataset.state = "gathering";
      beginTitle.textContent = "Begin gentle start";
      beginSub.textContent = "Five minutes to arrive. Nothing owed beyond them.";
      stepHint.textContent = "Concrete and about two minutes. Rough is fine.";
      show("begin");
      say("Back to the start.");
    } else if (action === "return") {
      breakTimer.hold();
      resumeFocus("Welcome back. The step is right where you left it.");
    } else if (answer) {
      answerCheckin(answer);
    }
  });

  function resumeFocus(note) {
    field.dataset.state = finished ? "settled" : "breathing";
    show("focus");
    message.textContent = note;
    if (!finished) {
      focusTimer.start();
      setHold(false);
      focusState.textContent = "Breathing with you";
    }
    say(note);
  }

  function answerCheckin(answer) {
    companions?.pulse(field, 0.75);
    if (answer === "fits") {
      resumeFocus("Kept as is. The block carries on.");
    } else if (answer === "detour") {
      resumeFocus("Detour noted, as information. Your task is still here.");
    } else if (answer === "smaller") {
      resuming = !finished;
      field.dataset.state = "gathering";
      beginTitle.textContent = "Back to focus";
      beginSub.textContent = "Same task, smaller step. The timer picks up where it held.";
      stepHint.textContent = "Make it smaller. One line is plenty.";
      show("begin");
      stepInput.select();
      say("Make the step smaller. Edit the step, then go back to focus.");
    } else if (answer === "break") {
      field.dataset.state = "expanded";
      breakTimer.reset(BREAK_SECONDS);
      breakState.textContent = "Ending early is fine";
      show("break");
      breakTimer.start();
      say("Break started. Three minutes, and ending early is fine.");
    }
  }

  demo.addEventListener("keydown", (event) => {
    if (stage !== "checkin" || event.metaKey || event.ctrlKey || event.altKey) return;
    const map = { 1: "fits", 2: "smaller", 3: "detour", 4: "break" };
    if (map[event.key]) {
      event.preventDefault();
      answerCheckin(map[event.key]);
    }
  });

  // Typing wakes the field a little: it gathers while you decide.
  let typingTimer = null;
  for (const input of [taskInput, stepInput]) {
    input.addEventListener("input", () => {
      if (stage !== "begin") return;
      window.clearTimeout(typingTimer);
      typingTimer = window.setTimeout(() => companions?.pulse(field, 0.25), 180);
    });
  }
}

setupDemo();

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

/* ---------- the loop ring follows the reader ---------- */

function setupLoopRing() {
  const ring = document.querySelector("[data-loop-ring]");
  const steps = [...document.querySelectorAll("[data-loop-step]")];
  if (!ring || !steps.length) return;
  const links = new Map([...ring.querySelectorAll("[data-loop-link]")].map((a) => [a.dataset.loopLink, a]));
  const order = ["begin", "focus", "checkin", "break", "review", "again"];

  const setCurrent = (name) => {
    const index = order.indexOf(name);
    if (index < 0) return;
    ring.style.setProperty("--ring-progress", String(Math.min(100, index * 20)));
    for (const [key, link] of links) {
      if (key === name || (name === "again" && key === "begin")) link.setAttribute("aria-current", "step");
      else link.removeAttribute("aria-current");
    }
  };

  const observer = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) if (entry.isIntersecting) setCurrent(entry.target.dataset.loopStep);
    },
    { rootMargin: "-45% 0px -45% 0px" }
  );
  steps.forEach((step) => observer.observe(step));
}

setupLoopRing();
