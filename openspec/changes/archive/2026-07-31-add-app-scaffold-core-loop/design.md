# Design: add-app-scaffold-core-loop

## Context

Zero native code exists. Inputs are binding: the validated research corpus (scope, ADHD interaction constraints, platform feasibility), the approved Living Companion mocks (visual language, copy tone, physics contract in `companion-physics.js`), and the AGENTS.md engineering contract (spec-first, TDD, deterministic timing, local-first). Platform: macOS 26+, Xcode 26.6, Swift 6.3, SwiftUI.

## Goals / Non-Goals

**Goals:** module boundaries that keep the timer engine pure and testable; a physics implementation faithful to the mock contract with a total reduced-motion standdown; local-first persistence with structural no-network guarantees; a project layout later changes extend without rework.

**Non-Goals:** menu-bar/floating surfaces, sync, integrations, App Intents, analytics beyond review, blocking, AI, Pro/Enterprise feature content, cloud services (separate deliverables per edition boundary).

## Decisions

1. **XcodeGen over checked-in .xcodeproj or Tuist.** Deterministic, diff-able project generation from `project.yml`; agents and humans edit YAML, never the pbxproj. *Alternatives:* checked-in xcodeproj (merge-conflict-prone, opaque diffs — rejected); Tuist (more power than needed, heavier toolchain — rejected); SwiftPM-only app (macOS app targets + asset catalogs + UI tests still fit Xcode projects better — rejected for the app shell, but all logic lives in SwiftPM packages, below).

2. **Three-layer module layout: `PraxmodoroCore` (SwiftPM), `PraxmodoroStore` (SwiftPM), app shell (Xcode target).** Core holds the timer state machine with an injected `Clock` protocol — pure Foundation, headless-testable (spec: timer-engine "Engine is UI-free"). Store holds SwiftData models behind a protocol Core consumes. The app shell holds SwiftUI surfaces, the companion field, and DI wiring. *Alternative:* one flat app target — rejected; it makes the no-UI/no-network guarantees untestable.

3. **Canonical-timestamp state machine, presentation interpolation.** Every transition stores `Date` from the injected clock; remaining time is a pure function `f(transitions, now)`. A `TimelineView`/`DisplayLink` drives rendering only. Sleep/wake needs no special-casing: wake simply evaluates `f` at the new now; expiry-while-asleep back-dates the transition to its canonical time (spec: sleep/wake scenarios). *Alternative:* `Timer`-decremented counters — rejected as the classic drift bug the research explicitly warns against.

4. **Companion field: SwiftUI Canvas/TimelineView + spring integrators ported 1:1 from `companion-physics.js`.** The JS engine is the contract: same spring constants, same asymmetric breath segments (3.6/1.2/5.4/1.4), same state targets, same pulse damping. Port as a pure `FieldPhysics` value type (testable: given t, state, targets → transforms), rendered as blurred radial-gradient layers in a `Canvas`. Metal shader ambition deferred until a measured need. *Alternatives:* third-party effect packages — rejected per dependency audit (no reduce-motion policy, unneeded); direct Metal — premature.

5. **Reduce Motion = engine absent, not damped.** One boolean gate (`accessibilityReduceMotion || motionStillToggle`) selects an entirely separate static field view; the physics type is never instantiated. Mirrors the mock's total standdown and makes the accessibility scenario mechanically verifiable.

6. **SwiftData local container, append-only event log.** Models: `TaskRecord`, `Session`, `SessionEvent` (typed, timestamped, append-only), `CapacityReport`. Edits create referencing events (spec: no silent rewrites). No CloudKit entitlement in this change. *Alternative:* Core Data — SwiftData is the platform-current API on macOS 26 and the research already validated its constraints.

7. **Edition seam: `CapabilityRegistry` value resolved at startup.** Feature keys are string-typed constants; Lite grant enumerated in code; a startup validation asserts the never-paywalled set (initiation, check-ins, breaks, accessibility) is Lite-available, failing fast in debug and self-healing in release (spec: app-scaffold "Core support cannot be paywalled").

8. **Copy-tone enforcement as a test.** All user-facing strings live in a strings catalog; a unit test lints them against a banned-claims lexicon (medical/judgment terms) — turning the non-medical-language requirement into CI, not review vigilance.

## Risks / Trade-offs

- [SwiftData maturity on macOS 26 for append-only patterns] → keep the store behind a protocol; Core never imports SwiftData, so a Core Data fallback swaps one module.
- [Canvas-rendered field misses the mock's blur softness at 120 Hz] → benchmark early (research handoff item); a Metal layer can replace the Canvas renderer behind the same `FieldPhysics` contract.
- [XcodeGen adds a toolchain step new contributors may miss] → the verify script regenerates and diffs the project; README documents the one-command setup.
- [Porting physics constants by eye drifts from the approved feel] → golden tests assert transform values at fixed timestamps against values exported from the JS engine.

## Migration Plan

Greenfield; no migration. Rollback = revert the change branch. Each task lands as an independently revertable conventional commit per AGENTS.md.

## Open Questions

- Whether the review timeline virtualizes (only matters past ~1k events; defer until data exists).
- Exact strings-catalog structure for future localization (decide at first copy-freeze; not blocking).
