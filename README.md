# Praxmodoro

Praxmodoro is a native macOS focus timer and non-clinical ADHD-aware focus coach. It combines low-friction task initiation, gentle check-ins, adaptive breaks, and local-first review with the “Living Companion” visual language approved on 2026-07-30 (`design-mocks/living-companion/`).

## Current state

Research is complete, **Living Companion** is the approved base direction (2026-07-30), and **milestone M1 — app scaffold + complete core loop — is implemented and independently validated** (2026-07-31; change archived as `2026-07-31-add-app-scaffold-core-loop`, 27 requirements synced to `openspec/specs/`). The native app runs the full loop: initiate → focus (physics-driven companion field) → check-in → break → review, local-first with no account.

**Milestone M2 (companion surfaces) is implemented on `feat/m2-companion-surfaces`** — menu-bar popover, floating focus capsule, return overlay, and the four M1 hardening follow-ups, as OpenSpec change `add-companion-surfaces`. One gate is outstanding and it is environmental: the UI test suite cannot run while the Mac's screen is locked, so `./scripts/verify-project.sh` stops at its final stage. Unlock and re-run it to close M2. See `SPEC.md` for the gate list and status. No shipping release or Enterprise service is claimed yet.

## Editions

- **Lite:** complete local focus loop, initiation support, check-ins, adaptive breaks, accessibility modes, menu-bar controls, and local review.
- **Pro:** advanced local insights, richer automations/integrations, optional sync, and deeper customization.
- **Enterprise:** the same native client with managed policy, audit/export, deployment, and identity integration boundaries. Team/cloud services are separate deliverables, not hidden inside the scaffold.

Core accessibility and ADHD-aware focus support are not paywalled.

## Repository map

- `research/pomodoro-landscape-20260720/` — sourced product and platform research.
- `design-mocks/living-companion/` — the approved direction: interactive mocks and the companion-field physics contract.
- `design-mocks/hallmark/`, `design-mocks/focus-observatory/` — comparative direction records (A and C).
- `design-mocks/direction-gate/` — side-by-side comparison and the recorded direction decision.
- `openspec/specs/` — canonical capability specs (authoritative); `openspec/changes/` — change lifecycle artifacts.
- `app/` — the native macOS app: XcodeGen project, PraxmodoroCore/PraxmodoroStore packages, surfaces, tests.
- `docs/handoff/` — cross-agent handoffs (current: M2 → Pi).
- `.agent/sessions/` — continuous autonomous build audit trail.
- `progress.txt` — append-only execution log.

`SPEC.md` (completion contract) and `prd.json` (atom state) now exist and govern milestone M1. `BLUEPRINT.md` remains a planned artifact for the implementation phase.

## Specification commands

```bash
npm install
npm run spec:list
npm run spec:validate
```

OpenSpec is pinned to 1.6.0.

## Native app commands

Requires Xcode 26.6+ and XcodeGen (`brew install xcodegen`). The `.xcodeproj` is generated — edit `app/project.yml`, never the project file.

```bash
./scripts/generate.sh
```

```bash
./scripts/verify-project.sh
```

```bash
swift test --package-path app/Packages/PraxmodoroCore
```

```bash
xcodebuild -project app/Praxmodoro.xcodeproj -scheme Praxmodoro -destination 'platform=macOS' build
```

```bash
./scripts/run.sh
```

```bash
./scripts/focused.sh
```

```bash
./scripts/smoke.sh
```

`verify-project.sh` is the scaffold gate: it fails if the generated project is missing or stale, then runs the package tests, the strict format lint, a full build, and the complete signed test suite including UI tests.

`focused.sh` is the fast inner loop — the app unit suite only — used per implementation atom. `smoke.sh` is the changed-surface check: it builds, verifies the signature, launches the app against an in-memory store, and confirms it registers with the window server and stays alive. It proves the artifact launches, not that any surface renders; the UI tests inside `verify-project.sh` cover that.
