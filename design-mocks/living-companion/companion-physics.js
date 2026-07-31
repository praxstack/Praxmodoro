/* Living Companion · physics layer.
 * Spring-damper motion for the companion fields: asymmetric calm breathing
 * (exhale longer than inhale), non-repeating drift, gentle pointer lean, and
 * damped acknowledgement pulses. CSS keyframes remain the no-JS / reduced
 * fallback; this layer takes over by tagging each field `is-physics`.
 * Never runs under prefers-reduced-motion or the "Motion: still" toggle.
 */
(() => {
  /* ---------- primitives ---------- */

  // Critically-damped-by-default spring integrator.
  function spring(value, { omega = 2.2, zeta = 1 } = {}) {
    return {
      x: value, v: 0, target: value, omega, zeta,
      step(dt) {
        const k = this.omega * this.omega;
        const c = 2 * this.zeta * this.omega;
        this.v += (k * (this.target - this.x) - c * this.v) * dt;
        this.x += this.v * dt;
        return this.x;
      },
      kick(impulse) { this.v += impulse; }
    };
  }

  const smooth = (t) => t * t * (3 - 2 * t);

  // Asymmetric breath: inhale 3.6s · hold 1.2s · exhale 5.4s · rest 1.4s.
  // The long exhale is what reads as calming. Returns 0..1.
  const BREATH = [3.6, 1.2, 5.4, 1.4];
  const BREATH_TOTAL = BREATH.reduce((a, b) => a + b, 0);
  function breathValue(t) {
    let phase = t % BREATH_TOTAL;
    if (phase < BREATH[0]) return smooth(phase / BREATH[0]);
    phase -= BREATH[0];
    if (phase < BREATH[1]) return 1;
    phase -= BREATH[1];
    if (phase < BREATH[2]) return 1 - smooth(phase / BREATH[2]);
    return 0;
  }

  // Non-repeating wander: incommensurate sine stack, unit output.
  function drift(t, seed) {
    return (
      Math.sin(t * 0.083 + seed * 1.7) * 0.5 +
      Math.sin(t * 0.047 + seed * 3.1) * 0.32 +
      Math.sin(t * 0.121 + seed * 5.3) * 0.18
    );
  }

  /* ---------- state vocabulary ---------- */

  const STATES = {
    gathering: { scale: 0.94, amp: 0.55, speed: 1.15, driftAmp: 1.15 },
    breathing: { scale: 1.0, amp: 1.0, speed: 1.0, driftAmp: 1.0 },
    held:      { scale: 0.985, amp: 0.07, speed: 0.55, driftAmp: 0.35 },
    ripple:    { scale: 1.0, amp: 0.8, speed: 1.0, driftAmp: 0.8 },
    expanded:  { scale: 1.1, amp: 1.25, speed: 0.72, driftAmp: 0.9 },
    settled:   { scale: 0.97, amp: 0.15, speed: 0.5, driftAmp: 0.3 }
  };

  // Per-layer character: breath gain, phase offset, drift gain.
  const LAYERS = [
    { sel: ".field-a", gain: 1.0, phase: 0.0, wander: 1.0 },
    { sel: ".field-b", gain: 0.8, phase: 0.35, wander: 1.35 },
    { sel: ".field-c", gain: 0.65, phase: 0.62, wander: 1.7 },
    { sel: ".field-core", gain: 1.15, phase: 0.15, wander: 0.55 },
    { sel: ".field-ring", gain: 0.4, phase: 0.0, wander: 0.0 }
  ];

  /* Pure-core export seam: under Node (golden-value generation for the native
   * port) expose the math and stop; in the browser this block is inert and
   * behavior is unchanged. The values below ARE the design contract. */
  if (typeof module !== "undefined" && module.exports) {
    module.exports = { spring, smooth, breathValue, drift, BREATH, BREATH_TOTAL, STATES, LAYERS };
    return;
  }

  const reducedQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
  const shell = document.querySelector("#prototypeShell");
  if (!shell) return;

  /* ---------- field ---------- */

  class Field {
    constructor(el, index) {
      this.el = el;
      this.seed = index + 1;
      this.layers = LAYERS
        .map((cfg) => ({ cfg, el: el.querySelector(cfg.sel) }))
        .filter((l) => l.el);
      this.scale = spring(1);
      this.amp = spring(1, { omega: 1.6 });
      this.speed = spring(1, { omega: 1.2 });
      this.driftAmp = spring(1, { omega: 1.2 });
      this.pulse = spring(0, { omega: 7, zeta: 0.34 }); // soft one-overshoot bloom
      this.leanX = spring(0, { omega: 1.5 });
      this.leanY = spring(0, { omega: 1.5 });
      this.breathClock = Math.random() * BREATH_TOTAL;
      this.applyState(el.dataset.state || "breathing", true);
    }
    applyState(name, immediate = false) {
      const s = STATES[name] || STATES.breathing;
      this.scale.target = s.scale;
      this.amp.target = s.amp;
      this.speed.target = s.speed;
      this.driftAmp.target = s.driftAmp;
      if (immediate) {
        this.scale.x = s.scale; this.amp.x = s.amp;
        this.speed.x = s.speed; this.driftAmp.x = s.driftAmp;
      } else {
        this.pulse.kick(0.55); // acknowledge the change physically
      }
    }
    visible() {
      const screen = this.el.closest(".screen");
      return !screen || screen.classList.contains("is-current");
    }
    step(dt) {
      this.scale.step(dt); this.amp.step(dt);
      this.speed.step(dt); this.driftAmp.step(dt);
      this.pulse.step(dt); this.pulse.target = 0;
      this.leanX.step(dt); this.leanY.step(dt);
      this.breathClock += dt * this.speed.x;
      if (!this.visible()) return;

      const rect = this.el.getBoundingClientRect();
      const unit = Math.max(rect.width, 120) * 0.028; // drift range scales with field
      const breathBase = this.breathClock;

      for (const { cfg, el } of this.layers) {
        const b = breathValue(breathBase + cfg.phase * BREATH_TOTAL);
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
      const cx = rect.left + rect.width / 2;
      const cy = rect.top + rect.height / 2;
      const clamp = (v) => Math.max(-7, Math.min(7, v));
      this.leanX.target = clamp((px - cx) * 0.012);
      this.leanY.target = clamp((py - cy) * 0.012);
    }
    rest() { this.leanX.target = 0; this.leanY.target = 0; }
    clear() {
      for (const { el } of this.layers) el.style.transform = "";
    }
  }

  /* ---------- engine ---------- */

  const fields = [...document.querySelectorAll(".companion-field")].map((el, i) => new Field(el, i));
  if (!fields.length) return;

  let raf = null;
  let last = null;

  function active() {
    return !reducedQuery.matches && shell.dataset.effects !== "reduced" && !document.hidden;
  }

  function frame(now) {
    raf = null;
    if (!active()) return stop();
    const dt = Math.min(0.05, last ? (now - last) / 1000 : 0.016);
    last = now;
    for (const f of fields) f.step(dt);
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
    fields.forEach((f) => { f.el.classList.remove("is-physics"); f.clear(); });
  }

  /* ---------- wiring ---------- */

  new MutationObserver((muts) => {
    for (const m of muts) {
      const field = fields.find((f) => f.el === m.target);
      if (field) field.applyState(m.target.dataset.state);
      if (m.target === shell) (active() ? start : stop)();
    }
  }).observe(document.body, { subtree: true, attributes: true, attributeFilter: ["data-state", "data-effects"] });

  document.addEventListener("visibilitychange", () => (active() ? start() : stop()));
  reducedQuery.addEventListener?.("change", () => (active() ? start() : stop()));

  window.addEventListener("pointermove", (e) => {
    for (const f of fields) if (f.visible()) f.lean(e.clientX, e.clientY);
  }, { passive: true });
  window.addEventListener("pointerleave", () => fields.forEach((f) => f.rest()));

  // Acknowledgement pulses: choices and the timer toggle bloom the nearest field.
  document.addEventListener("click", (e) => {
    const button = e.target.closest(".checkin-option, .break-action, .begin-control, #timerToggle, .pill-chip");
    if (!button || !active()) return;
    const field = fields.find((f) => f.visible());
    field?.pulse.kick(button.id === "timerToggle" ? 0.4 : 0.75);
  });

  start();
})();
