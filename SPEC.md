# SPEC.md — Praxodoro completion contract

The durable definition of done. The independent validator checks work against this file, not against session claims. Detailed binary requirements live in the OpenSpec capability specs; this file states the contract's shape and the global gates.

## Product

Praxodoro: native macOS focus timer and non-clinical ADHD-aware focus coach. macOS 26+, Swift 6.3, SwiftUI, local-first. Editions Lite/Pro/Enterprise share one codebase behind explicit capability gates; initiation help, check-ins, adaptive breaks, accessibility, and low-cognitive-load modes are Lite, always.

Visual direction: **Living Companion** (approved 2026-07-30; binding reference `design-mocks/living-companion/`, physics contract `companion-physics.js`). Evidence roots: `research/pomodoro-landscape-20260720/` for product claims, the mocks for visual decisions.

## Milestone M1 — app scaffold + core loop (active)

Governed by OpenSpec change `add-app-scaffold-core-loop`. M1 is complete when, and only when:

1. Every EARS scenario in `openspec/changes/add-app-scaffold-core-loop/specs/{app-scaffold,timer-engine,focus-loop-ui,session-persistence}/spec.md` is covered by an automated test that passes.
2. Every task in that change's `tasks.md` is checked, each with its red-then-green evidence recorded in `prd.json` and `progress.txt`.
3. A clean clone builds, tests, and runs with only the README-documented commands.
4. The timer survives sleep/wake and relaunch with remaining time exactly derived from canonical timestamps (zero tick drift).
5. Reduce Motion / "Motion: still" produces the total physics standdown; Reduce Transparency and Increase Contrast alternates render; the full keyboard loop and VoiceOver labels pass.
6. The copy-tone lint (no medical/diagnostic/judgment claims), no-network harness, and never-paywalled-set validation all pass.
7. `npm run spec:validate` passes strict, and an independent validator session confirms 1–6 from a fresh context using only this file, the change artifacts, and the repo.

## Later milestones (not yet specified)

M2 companion surfaces (menu-bar popover, floating capsule, return overlay) · M3 staged integrations (EventKit import, App Intents, richer local analytics) · M4 optional sync (CloudKit history, never live ticks) · M5 edition content (Pro insights/automations, Enterprise policy boundaries — cloud/team services are separate deliverables). Each arrives as its own OpenSpec change; nothing in this list is promised behavior until specified.

## Global invariants (hold at every milestone)

- Deterministic timing from canonical wall-clock timestamps; ticks are presentation only.
- Local-first: no network, account, or telemetry without a spec'd, explicit, optional, edition-gated opt-in.
- Non-medical positioning in every string; no punitive mechanics (streak loss, forced breaks, urgency, judgment of activity).
- Accessibility alternates are architecture, not polish; they ship in the same change as the feature they serve.
- One independently testable atom per commit; conventional commits; never weaken a test to go green.
