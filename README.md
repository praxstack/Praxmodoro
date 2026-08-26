# Praxmodoro

Praxmodoro is a native macOS focus timer and non-clinical ADHD-aware focus coach. It combines low-friction task initiation, gentle check-ins, adaptive breaks, and local-first review with the “Living Companion” visual language approved on 2026-07-30 (`design-mocks/living-companion/`).

## Current state

Research is complete, **Living Companion** is the approved base direction (2026-07-30), and **milestone M1 — app scaffold + complete core loop — is implemented and independently validated** (2026-07-31; change archived as `2026-07-31-add-app-scaffold-core-loop`, 27 requirements synced to `openspec/specs/`). The native app runs the full loop: initiate → focus (physics-driven companion field) → check-in → break → review, local-first with no account.

M2 companion surfaces, runtime-contract stabilization, and session settings are implemented, independently reviewed, and archived as `2026-08-26-add-companion-surfaces`, `2026-08-26-stabilize-runtime-contracts`, and `2026-08-26-add-session-settings`. There are no active OpenSpec changes. The post-archive gate passed Core 46/46, Store 8/8, build, signed UI 237/237, smoke, strict canonical OpenSpec 6/6, and documentation/integrity checks. This branch has not been merged, pushed, packaged, or released.

## One product

Praxmodoro is one complete app. Every capability ships to every user; capability keys remain internal provenance checks and cannot withhold behavior. Any future network, sync, analytics, or AI work requires its own explicit optional specification.

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

`SPEC.md` is the completion contract, `prd.json` is atom state, archived changes live under `openspec/changes/archive/`, and dated execution plans live under `docs/plans/`. `BLUEPRINT.md` was never created and is not part of the workflow.

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
