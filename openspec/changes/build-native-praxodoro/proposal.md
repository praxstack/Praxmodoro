## Why

Praxodoro has a sourced product strategy and an advanced visual prototype, but it is not yet a runnable macOS application. The first implementation must prove that a native timer can reduce initiation friction and support user-steerable focus without turning ADHD language into diagnosis, surveillance, shame, or a premium lock on essential support.

## What Changes

- Create a native macOS 26+ application that runs the first complete local loop: name one task, choose or edit a tiny first action, start, pause/resume, request or receive a gentle check-in, take or skip a break, re-enter, and complete or stop.
- Make timer state deterministic across sleep, wake, relaunch, and wall-clock changes by deriving remaining time from canonical timestamps rather than UI ticks.
- Add an ADHD-aware coach driven only by explicit user input and session events, with optional capacity, configurable cadence, dismissible check-ins, deterministic/manual task breakdown, and a low-cognitive-load focus mode.
- Establish one-codebase Lite, Pro, and Enterprise capability gates. Lite retains the full core loop, all accessibility paths, privacy/export/delete controls, basic local history, and deterministic initiation help.
- Implement the “Liquid Instrument” design language with layered native glass, controlled skeuomorphic depth, keyboard-first interaction, VoiceOver semantics, and automatic Reduce Motion, Reduce Transparency, and Increase Contrast fallbacks.
- Define local-first data categories, retention, export/delete semantics, safe notification previews, and a zero-network Lite baseline when integrations, sync, diagnostics, and licensing services are disabled.
- Add reproducible build, test, strict OpenSpec validation, secret scanning, and CI workflows so every implementation atom has machine-verifiable evidence.
- Scaffold Pro extension points for opt-in sync, integrations, advanced insights, and on-device AI enhancement without implementing hidden network services; privileged blocking is absent pending a separate approved add-on specification.
- Scaffold Enterprise extension points for licensing, deployment, managed privacy restrictions, update channels, and configuration audit while forbidding manager-visible personal behavior.

## Goals

- Produce a locally runnable and testable native application, not only mocks or documentation.
- Preserve the research-backed nonjudgmental loop and make every adaptive behavior explainable and user-steerable.
- Give future Pro and Enterprise work stable interfaces without complicating or degrading the Lite runtime.
- Keep visual ambition compatible with macOS accessibility, energy, and performance expectations.

## Non-goals

- No diagnostic, treatment, prevention, symptom-scoring, or clinical-efficacy claims.
- No passive app/website surveillance, screenshots, keystroke collection, clipboard harvesting, physiological inference, or employer productivity scoring.
- No production cloud/team backend, account system, payments, App Store submission, notarized release, or public deployment in this change.
- No system-wide blocking extension implementation until a separate distribution, privacy, failure-mode, and entitlement spec is approved.
- No cross-device live timer control or social/body-doubling service in this change.

## Assumptions

- “Lite Prope Enterprise” means Lite, Pro, and Enterprise editions.
- Capacity is optional and defaults to unspecified; the app stores no inferred capacity value.
- The deterministic/manual first-action path is the baseline. On-device AI can enhance it later but can never be required for the core loop.
- “Drift” means only an explicit pause, detour report, missed scheduled event, or user request, never observed application or browser activity.
- Capacity/check-in answers are session-only by default; an explicit private-history setting may retain them for a bounded period in a later atom.
- Adults are the initial audience represented by the current evidence; minors require a separate safety and privacy review.

## Measurable Success

- A clean checkout can install spec tooling, strictly validate the active change, build the macOS app, and run the full test suite with documented commands.
- A fresh Lite install can start and complete the core loop offline without an account, payment, permission prompt, capacity answer, or outbound app request.
- Automated tests prove canonical-timestamp behavior for pause/resume, sleep/wake simulation, relaunch recovery, and forward/backward wall-clock changes.
- Automated state-machine tests prove every check-in, break, re-entry, conflict, entitlement, and downgrade transition without punitive or destructive side effects.
- Accessibility QA proves keyboard and VoiceOver reachability, programmatic selection state, non-chatty timer announcements, readable chart alternatives, and all three system effect fallbacks.
- A fresh-context validator maps every completed task and test result back to the original global and OpenSpec acceptance criteria.

## Capabilities

### New Capabilities

- `focus-session-engine`: Canonical session state, timing policies, pause/resume, sleep/wake and relaunch recovery, conflicts, completion, and interruption capture.
- `adhd-aware-coach`: Optional capacity, editable first-action help, user-steerable check-ins, adaptive but explainable breaks, detour recovery, low-cognitive-load mode, and nonjudgmental review.
- `edition-capabilities`: Lite, Pro, and Enterprise capability contracts, entitlement transitions, expiry/downgrade behavior, and non-paywall invariants.
- `liquid-instrument-experience`: Native window/surface hierarchy, visual tokens, glass and skeuomorphic rendering, input semantics, accessibility fallbacks, and performance budgets.
- `local-data-control`: Data categories, retention, zero-network baseline, notifications, export/delete, diagnostics boundaries, and future sync consent contracts.
- `macos-app-delivery`: Reproducible project scaffold, dependency policy, build/test/CI workflows, app launch smoke test, and local developer documentation.

### Modified Capabilities

- None. This is the first canonical Praxodoro specification set.

## Impact

- Adds the native application, shared domain modules, tests, assets, project configuration, and CI workflow.
- Adds canonical OpenSpec capability specifications plus global `SPEC.md`, `BLUEPRINT.md`, `prd.json`, and a dated implementation plan.
- Uses Apple platform frameworks first. Any third-party rendering dependency requires a separate provenance, license, maintenance, performance, and fallback decision before adoption.
- Keeps research clones excluded from Git while retaining the curated claim/source ledgers, reports, Hallmark dossier, and final screenshots as design evidence.
- Leaves public repository creation, remote push, signing, notarization, release distribution, cloud services, and commerce outside this change.
