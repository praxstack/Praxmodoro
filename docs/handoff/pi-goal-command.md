# /goal command for Pi

> **Superseded 2026-08-04.** The plan changed: M2 was not handed to Pi. It was
> executed in this repository directly, as OpenSpec change
> `add-companion-surfaces` on branch `feat/m2-companion-surfaces`. This document
> is kept as the record of the state M2 started from — its §2 facts were accurate
> at `79914e1`. For current status see `SPEC.md` and `progress.txt`.
>
> Note also that the local folder has since been renamed from
> `~/Developer/Praxodoro` to `~/Developer/Praxomodoro`; the paths below are stale.

Paste the block below as a single message in a Pi session opened at `/Users/prax/Developer/Praxodoro`. It is authored from [2026-07-31-pi-m2.md](./2026-07-31-pi-m2.md) — read that handoff first; re-verify its §2 facts before trusting them.

---

/goal Deliver Praxmodoro milestone M2 — companion surfaces (menu-bar popover, floating focus capsule, return overlay) plus the recorded M1 hardening follow-ups — as OpenSpec change `add-companion-surfaces`, spec-first and test-first, on a feature branch off main (repo: /Users/prax/Developer/Praxodoro, origin praxstack/Praxmodoro).

Context of record: docs/handoff/2026-07-31-pi-m2.md (read fully; §2 lists solved toolchain traps — generated .xcodeproj, ad-hoc signing with hardened runtime off for test targets, hermetic UI tests via -praxmodoro-ephemeral-store, SwiftUI dropping identifiers on merged a11y elements). Binding contracts: AGENTS.md, SPEC.md, openspec/config.yaml. Design truth: design-mocks/living-companion (physics contract companion-physics.js; reuse FieldPhysics/FieldModel — no new animation systems).

Success criteria:
1. OpenSpec change `add-companion-surfaces` authored (proposal, EARS capability specs, design with argued alternatives, TDD tasks) and passing `npm run spec:validate` strict.
2. Menu-bar popover, floating capsule, and return overlay implemented; all three render the ONE canonical engine-derived session state — remaining time is always f(transitions, now), never a counted tick.
3. M1 hardening follow-ups closed: render-level Reduce-Transparency/Increase-Contrast verification, two-configuration schema-parity test, keyboard UI coverage for check-in 1–4 / R / ⌘N as real key events, launch-time first-run assertion.
4. Complete accessibility alternates ship in the same change (Reduce Motion total standdown on every new surface; VoiceOver labels; full keyboard paths).
5. `./scripts/verify-project.sh` exits 0 (format lint, package tests, build, full signed suite incl. UI tests); every atom lands as one conventional commit with red-then-green evidence in prd.json + progress.txt.
6. An independent fresh-context validator maps every criterion to pass/fail/blocked and returns COMPLETE before the change is archived and merged to main.

Constraints (not authorized): no force-pushes; no pushes to the `legacy` remote; no network/cloud/sync/analytics; no medical or treatment claims in copy; initiation, check-ins, breaks, and accessibility stay un-paywalled; never edit generated files (.xcodeproj, BuildProvenance.swift) directly.

---

Notes for Pi: no `.agent-stack/project.yaml` exists yet — per the goal protocol, anchor the ledger to the git working tree and bind verification scopes to the repository's real commands (`./scripts/verify-project.sh`, `npm run spec:validate`, `swift test --package-path app/Packages/PraxmodoroCore`, same for PraxmodoroStore); recommending `agent-stack init` is fine, skipping it must not stop the goal.

