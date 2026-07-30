# Proposal: add-app-scaffold-core-loop

## Why

Praxodoro has a validated research corpus, an approved visual direction (Living Companion, chosen 2026-07-30 over two mocked alternatives), and zero native code. The research's central finding is that the smallest differentiated product is not a shorter feature list but one complete low-friction execution-and-recovery loop (research claim w2-product-scope-adjudication-001). This change creates the native macOS app and that complete loop, so every later change extends a runnable, testable product instead of a scaffold-in-waiting.

## Goals, non-goals, assumptions

**Goals:** a buildable, testable macOS 26+ SwiftUI app; a deterministic timer engine immune to sleep/wake/relaunch drift; the five-surface core loop (initiate → focus → check-in → break → review) in the Living Companion language; local-first session records; complete accessibility alternates.

**Non-goals (explicitly deferred to later changes):** menu-bar popover and floating capsule surfaces, calendar/reminders import, CloudKit sync, App Intents, analytics beyond the local review surface, automations, any blocking, any AI task breakdown, Pro/Enterprise capability content (only the gating seam ships now), and any cloud or team backend — those are separate deliverables per the edition boundary.

**Assumptions:** Xcode 26.6 / Swift 6.3 available (verified in bootstrap recon); XcodeGen acceptable for project generation (design.md decides); the Living Companion browser mocks are the binding visual/behavioral reference including the physics contract and its reduced-motion standdown.

**Edition impact:** everything in this change ships in Lite. The change introduces the capability-gate seam but gates nothing behind it yet — core ADHD/accessibility behavior is never paywalled.

**User value:** an adult who struggles with task initiation can open the app, name one task and one tiny first action, start a gentle block, be checked on without judgment, rest without losing their place, and see a descriptive record — entirely offline, no account.

**Measurable success:** all EARS scenarios in the four capability specs pass as automated tests; the app builds and runs from a clean clone with the documented commands; timer state survives a simulated sleep/wake and a relaunch with zero drift beyond wall-clock truth; every surface passes the accessibility scenario set (Reduce Motion, Reduce Transparency, Increase Contrast, VoiceOver labels, full keyboard path).

## What Changes

- New Xcode project (XcodeGen-managed) with app target, unit-test target, and UI-test target; build/test commands land in README and CI-ready scripts.
- New deterministic timer engine: session state machine driven by canonical wall-clock timestamps, with monotonic rendering interpolation; sleep/wake and relaunch reconstruct state from timestamps, never from elapsed ticks.
- New five-surface core loop UI per the Living Companion mocks: one-task initiate (task + first action + capacity + policy), breathing-field focus, four-option no-failure-state check-in, user-steerable break with re-entry card, descriptive review timeline.
- New companion field implementation: SwiftUI-rendered breathing field with the spring/asymmetric-breath physics contract from `companion-physics.js`, plus a complete static calm alternate for Reduce Motion / "Motion: still".
- New local persistence: SwiftData models for tasks, sessions, session events, and self-reported capacity; everything on-device.
- New edition-gate seam: a capability registry all features consult; Lite grants everything in this change.

## Capabilities

### New Capabilities

- `app-scaffold`: project generation, app lifecycle, edition-gate seam, build/test entry points.
- `timer-engine`: deterministic session state machine — states, transitions, canonical-timestamp arithmetic, sleep/wake/relaunch recovery, drift bounds.
- `focus-loop-ui`: the five core surfaces, their copy tone rules, the companion-field physics and its accessibility alternates, keyboard and VoiceOver behavior.
- `session-persistence`: local-first SwiftData records, event log, data minimization, no-network guarantee.

### Modified Capabilities

_None — this is the first change; no main specs exist yet._

## Impact

- New code only; no existing runtime code exists. New top-level `app/` directory (project.yml, sources, tests).
- New dev dependency: XcodeGen (design.md records the decision and alternatives).
- No third-party runtime dependencies — the companion field is pure SwiftUI/Metal per the effects-dependency audit (w2-effects-dependency-audit-004).
- README build/test commands section gains real content; progress.txt and prd.json begin tracking implementation atoms.
