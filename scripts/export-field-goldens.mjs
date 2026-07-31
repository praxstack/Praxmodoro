#!/usr/bin/env node
// Export golden values from the Living Companion physics contract
// (design-mocks/living-companion/companion-physics.js) for the native port's
// FieldPhysicsGoldenTests. Deterministic: same input file -> same JSON.
import { createRequire } from "node:module";
import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const here = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const physics = require(path.join(here, "../design-mocks/living-companion/companion-physics.js"));

const { spring, breathValue, drift, BREATH, BREATH_TOTAL, STATES, LAYERS } = physics;

const breathSamples = [0, 0.5, 1.8, 3.6, 4.0, 4.79, 4.8, 6.0, 8.5, 10.19, 10.2, 11.0, 11.59, 11.6, 13.0, 23.2, 37.7]
  .map((t) => ({ t, value: breathValue(t) }));

const driftSamples = [
  [0, 1], [1.5, 2.35], [10, 3.7], [123.45, 1.55], [600, 4.05], [37, 2.0],
].map(([t, seed]) => ({ t, seed, value: drift(t, seed) }));

function springTrace({ omega, zeta, start, target, kick = 0, steps, dt, every }) {
  const s = spring(start, { omega, zeta });
  s.target = target;
  if (kick) s.kick(kick);
  const trace = [];
  for (let i = 1; i <= steps; i++) {
    s.step(dt);
    if (i % every === 0) trace.push({ step: i, x: s.x, v: s.v });
  }
  return { omega, zeta, start, target, kick, dt, trace };
}

const springs = [
  springTrace({ omega: 2.2, zeta: 1, start: 1.0, target: 0.94, steps: 120, dt: 1 / 60, every: 10 }),
  springTrace({ omega: 1.6, zeta: 1, start: 1.0, target: 0.07, steps: 240, dt: 1 / 60, every: 20 }),
  springTrace({ omega: 7, zeta: 0.34, start: 0, target: 0, kick: 0.55, steps: 90, dt: 1 / 60, every: 5 }),
  springTrace({ omega: 1.5, zeta: 1, start: 0, target: 7, steps: 60, dt: 1 / 50, every: 6 }),
];

const golden = {
  source: "design-mocks/living-companion/companion-physics.js",
  breath: { segments: BREATH, total: BREATH_TOTAL, samples: breathSamples },
  drift: driftSamples,
  springs,
  states: STATES,
  layers: LAYERS.map(({ sel, gain, phase, wander }) => ({ sel, gain, phase, wander })),
};

const out = path.join(here, "../app/Tests/PraxmodoroTests/field-physics-golden.json");
writeFileSync(out, JSON.stringify(golden, null, 2) + "\n");
console.log("wrote", out);
