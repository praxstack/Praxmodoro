// Living Companion field physics, ported from design-mocks/living-companion/companion-physics.js.
// Spring-damped breathing (exhale longer than inhale), non-repeating drift, a gentle
// pointer lean and damped acknowledgement pulses. CSS keyframes are the no-JS fallback.
// Never runs while motion is "still" (system Reduce Motion or the page's Motion switch),
// while the tab is hidden, or for fields that are off screen.

function spring(value, { omega = 2.2, zeta = 1 } = {}) {
  return {
    x: value,
    v: 0,
    target: value,
    omega,
    zeta,
    step(dt) {
      const k = this.omega * this.omega;
      const c = 2 * this.zeta * this.omega;
      this.v += (k * (this.target - this.x) - c * this.v) * dt;
      this.x += this.v * dt;
      return this.x;
    },
    kick(impulse) {
      this.v += impulse;
    }
  };
}

const smooth = (t) => t * t * (3 - 2 * t);

// Inhale 3.6 s · hold 1.2 s · exhale 5.4 s · rest 1.4 s. The long exhale reads as calm.
export const BREATH = [3.6, 1.2, 5.4, 1.4];
export const BREATH_TOTAL = BREATH.reduce((a, b) => a + b, 0);

function breathValue(t) {
  let phase = t % BREATH_TOTAL;
  if (phase < BREATH[0]) return smooth(phase / BREATH[0]);
  phase -= BREATH[0];
  if (phase < BREATH[1]) return 1;
  phase -= BREATH[1];
  if (phase < BREATH[2]) return 1 - smooth(phase / BREATH[2]);
  return 0;
}

function drift(t, seed) {
  return Math.sin(t * 0.083 + seed * 1.7) * 0.5 + Math.sin(t * 0.047 + seed * 3.1) * 0.32 + Math.sin(t * 0.121 + seed * 5.3) * 0.18;
}

const STATES = {
  gathering: { scale: 0.94, amp: 0.55, speed: 1.15, driftAmp: 1.15 },
  breathing: { scale: 1.0, amp: 1.0, speed: 1.0, driftAmp: 1.0 },
  held: { scale: 0.985, amp: 0.07, speed: 0.55, driftAmp: 0.35 },
  ripple: { scale: 1.0, amp: 0.8, speed: 1.0, driftAmp: 0.8 },
  expanded: { scale: 1.1, amp: 1.25, speed: 0.72, driftAmp: 0.9 },
  settled: { scale: 0.97, amp: 0.15, speed: 0.5, driftAmp: 0.3 }
};

const LAYERS = [
  { sel: ".field-a", gain: 1.0, phase: 0.0, wander: 1.0 },
  { sel: ".field-b", gain: 0.8, phase: 0.35, wander: 1.35 },
  { sel: ".field-c", gain: 0.65, phase: 0.62, wander: 1.7 },
  { sel: ".field-core", gain: 1.15, phase: 0.15, wander: 0.55 },
  { sel: ".field-ring", gain: 0.4, phase: 0.0, wander: 0.0 }
];

class Field {
  constructor(el, index) {
    this.el = el;
    this.seed = index + 1;
    this.onScreen = false;
    this.layers = LAYERS.map((cfg) => ({ cfg, el: el.querySelector(cfg.sel) })).filter((layer) => layer.el);
    this.scale = spring(1);
    this.amp = spring(1, { omega: 1.6 });
    this.speed = spring(1, { omega: 1.2 });
    this.driftAmp = spring(1, { omega: 1.2 });
    this.pulse = spring(0, { omega: 7, zeta: 0.34 });
    this.leanX = spring(0, { omega: 1.5 });
    this.leanY = spring(0, { omega: 1.5 });
    this.breathClock = Math.random() * BREATH_TOTAL;
    this.width = el.getBoundingClientRect().width || 300;
    this.applyState(el.dataset.state || "breathing", true);
  }

  applyState(name, immediate = false) {
    const s = STATES[name] || STATES.breathing;
    this.scale.target = s.scale;
    this.amp.target = s.amp;
    this.speed.target = s.speed;
    this.driftAmp.target = s.driftAmp;
    if (immediate) {
      this.scale.x = s.scale;
      this.amp.x = s.amp;
      this.speed.x = s.speed;
      this.driftAmp.x = s.driftAmp;
    } else {
      this.pulse.kick(0.55);
    }
  }

  step(dt) {
    this.scale.step(dt);
    this.amp.step(dt);
    this.speed.step(dt);
    this.driftAmp.step(dt);
    this.pulse.step(dt);
    this.pulse.target = 0;
    this.leanX.step(dt);
    this.leanY.step(dt);
    this.breathClock += dt * this.speed.x;
    if (!this.onScreen) return;

    const unit = Math.max(this.width, 120) * 0.028;
    for (const { cfg, el } of this.layers) {
      const b = breathValue(this.breathClock + cfg.phase * BREATH_TOTAL);
      const breathScale = 1 + (b - 0.5) * 0.075 * cfg.gain * this.amp.x;
      const s = this.scale.x * breathScale + this.pulse.x * 0.045 * cfg.gain;
      const dx = drift(this.breathClock, this.seed + cfg.wander) * unit * cfg.wander * this.driftAmp.x;
      const dy = drift(this.breathClock + 37, this.seed * 2 + cfg.wander) * unit * cfg.wander * this.driftAmp.x;
      const lx = this.leanX.x * (0.4 + cfg.gain * 0.35);
      const ly = this.leanY.x * (0.4 + cfg.gain * 0.35);
      el.style.transform = `translate3d(${(dx + lx).toFixed(2)}px, ${(dy + ly).toFixed(2)}px, 0) scale(${s.toFixed(4)})`;
    }
  }

  lean(px, py) {
    const rect = this.el.getBoundingClientRect();
    if (!rect.width) return;
    const clamp = (v) => Math.max(-7, Math.min(7, v));
    this.leanX.target = clamp((px - (rect.left + rect.width / 2)) * 0.012);
    this.leanY.target = clamp((py - (rect.top + rect.height / 2)) * 0.012);
  }

  rest() {
    this.leanX.target = 0;
    this.leanY.target = 0;
  }

  clear() {
    for (const { el } of this.layers) el.style.transform = "";
  }
}

export function startCompanions({ isStill }) {
  const fields = [...document.querySelectorAll(".companion-field")].map((el, i) => new Field(el, i));
  const byEl = new Map(fields.map((field) => [field.el, field]));
  let raf = null;
  let last = null;

  const active = () => !isStill() && !document.hidden && fields.some((f) => f.onScreen);

  function frame(now) {
    raf = null;
    if (!active()) {
      stop();
      return;
    }
    const dt = Math.min(0.05, last ? (now - last) / 1000 : 0.016);
    last = now;
    for (const field of fields) field.step(dt);
    raf = requestAnimationFrame(frame);
  }

  function start() {
    if (raf || !active()) return;
    last = null;
    fields.forEach((f) => f.el.classList.add("is-physics"));
    raf = requestAnimationFrame(frame);
  }

  function stop() {
    if (raf) cancelAnimationFrame(raf);
    raf = null;
    fields.forEach((f) => {
      f.el.classList.remove("is-physics");
      f.clear();
    });
  }

  const sync = () => (active() ? start() : stop());

  const visibility = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        const field = byEl.get(entry.target);
        if (!field) continue;
        field.onScreen = entry.isIntersecting;
        field.width = entry.boundingClientRect.width || field.width;
      }
      sync();
    },
    { rootMargin: "120px 0px" }
  );
  fields.forEach((f) => visibility.observe(f.el));

  new MutationObserver((mutations) => {
    for (const m of mutations) byEl.get(m.target)?.applyState(m.target.dataset.state);
  }).observe(document.body, { subtree: true, attributes: true, attributeFilter: ["data-state"] });

  document.addEventListener("visibilitychange", sync);

  window.addEventListener(
    "pointermove",
    (e) => {
      if (e.pointerType !== "mouse") return;
      for (const f of fields) if (f.onScreen) f.lean(e.clientX, e.clientY);
    },
    { passive: true }
  );
  document.documentElement.addEventListener("pointerleave", () => fields.forEach((f) => f.rest()));

  return {
    sync,
    /** A soft, damped bloom on the field that contains (or sits behind) an element. */
    pulse(el, strength = 0.75) {
      if (isStill()) return;
      const field = byEl.get(el);
      field?.pulse.kick(strength);
    }
  };
}
