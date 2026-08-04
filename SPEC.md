# SPEC.md — Praxmodoro completion contract

The durable definition of done. The independent validator checks work against this file, not against session claims. Detailed binary requirements live in the OpenSpec capability specs; this file states the contract's shape and the global gates.

## Product

Praxmodoro: native macOS focus timer and non-clinical ADHD-aware focus coach. macOS 26+, Swift 6.3, SwiftUI, local-first. Editions Lite/Pro/Enterprise share one codebase behind explicit capability gates; initiation help, check-ins, adaptive breaks, accessibility, and low-cognitive-load modes are Lite, always.

Visual direction: **Living Companion** (approved 2026-07-30; binding reference `design-mocks/living-companion/`, physics contract `companion-physics.js`). Evidence roots: `research/pomodoro-landscape-20260720/` for product claims, the mocks for visual decisions.

## Milestone M1 — app scaffold + core loop (COMPLETE 2026-07-31)

Governed by OpenSpec change `add-app-scaffold-core-loop` (archived `2026-07-31-add-app-scaffold-core-loop`). Independent fresh-context validation confirmed all seven gates PASS at `d56949d`. M1 was complete when, and only when:

1. Every EARS scenario in `openspec/changes/add-app-scaffold-core-loop/specs/{app-scaffold,timer-engine,focus-loop-ui,session-persistence}/spec.md` is covered by an automated test that passes.
2. Every task in that change's `tasks.md` is checked, each with its red-then-green evidence recorded in `prd.json` and `progress.txt`.
3. A clean clone builds, tests, and runs with only the README-documented commands.
4. The timer survives sleep/wake and relaunch with remaining time exactly derived from canonical timestamps (zero tick drift).
5. Reduce Motion / "Motion: still" produces the total physics standdown; Reduce Transparency and Increase Contrast alternates render; the full keyboard loop and VoiceOver labels pass.
6. The copy-tone lint (no medical/diagnostic/judgment claims), no-network harness, and never-paywalled-set validation all pass.
7. `npm run spec:validate` passes strict, and an independent validator session confirms 1–6 from a fresh context using only this file, the change artifacts, and the repo.

## Milestone M2 — companion surfaces (in progress, one gate blocked 2026-08-04)

Governed by OpenSpec change `add-companion-surfaces`. M2 is complete when, and only when:

1. Every EARS scenario in `openspec/changes/add-companion-surfaces/specs/{companion-surfaces,focus-loop-ui,session-persistence,app-scaffold}/spec.md` is covered by an automated test that passes.
2. The menu-bar popover, floating focus capsule, and return overlay all render one canonical engine-derived session state; no surface counts time, proven behaviorally (a frozen input must produce an unchanged rendering after real time passes), not only by source scanning.
3. The four M1 hardening follow-ups are closed: render-level Reduce-Transparency/Increase-Contrast verification; two-configuration schema parity against live containers; keyboard UI coverage for ⌘K, check-in 1–4, `R`, ⌘N and the capsule toggle as real key events; a launch-time first-run assertion.
4. Complete accessibility alternates ship in the same change: Reduce Motion standdown proven on every companion surface in both directions, VoiceOver labels, full keyboard paths.
5. `./scripts/verify-project.sh` exits 0 and `./scripts/smoke.sh` exits 0.
6. `npm run spec:validate` passes strict, and an independent validator session confirms 1–5 from a fresh context.

**Status 2026-08-04.** Gates 1 and 4 are met. Gate 3 is met for its two unit-level follow-ups. Gate 2 is met by the current defense but has a history worth knowing: five independent validators each defeated the no-second-clock guard with a real, compiling, drifting counterexample, and each defeat was closed. The current defense — rasterizing held surfaces and comparing renders, so `body` is in scope — has **not yet itself faced an independent attack**, and the test states its own residual limit (a beat slower than the 2.5s window evades it).

Gates 3 (UI half), 5 and 6 are **blocked by the host, not the code**: XCUITest cannot initialize while the Mac's screen is locked (`LocalAuthentication -4`, `CGSSessionScreenIsLocked = true`), so `KeyboardLoopUITests` has never executed and `verify-project.sh` stops at its final stage. Everything upstream passes: staleness gate, PraxmodoroCore 12/12, PraxmodoroStore 7/7, strict format lint, build, 73 app unit tests in 23 suites, `spec:validate` 5/5, `smoke.sh`, and `** TEST BUILD SUCCEEDED **` for the UI target.

**Unblock: unlock the Mac and run `./scripts/verify-project.sh`.** M2 is not complete until that exits 0 and an independent validator confirms gates 1–5 against the result.

## Later milestones (not yet specified)

M3 staged integrations (EventKit import, App Intents, richer local analytics) · M4 optional sync (CloudKit history, never live ticks) · M5 edition content (Pro insights/automations, Enterprise policy boundaries — cloud/team services are separate deliverables). Each arrives as its own OpenSpec change; nothing in this list is promised behavior until specified.

## Global invariants (hold at every milestone)

- Deterministic timing from canonical wall-clock timestamps; ticks are presentation only.
- Local-first: no network, account, or telemetry without a spec'd, explicit, optional, edition-gated opt-in.
- Non-medical positioning in every string; no punitive mechanics (streak loss, forced breaks, urgency, judgment of activity).
- Accessibility alternates are architecture, not polish; they ship in the same change as the feature they serve.
- One independently testable atom per commit; conventional commits; never weaken a test to go green.
