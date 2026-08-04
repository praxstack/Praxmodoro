# Proposal: add-companion-surfaces

## Why

M1 delivered one complete loop inside one window. That window is the whole product surface today: to see how long is left, or to hold the timer, or to find the way back after a break, the user must find and front the app. For the audience this product is built for, that is exactly the wrong shape — the research's initiation finding is that the cost of *reaching* the tool is a real part of the cost of the task (research w1-user-friction-004), and the recovery finding is that the return from a break fails when the next action has to be remembered rather than read (research w2-breaks-adhd-falsification-004).

This change gives the session three ambient surfaces — a menu-bar popover, a floating focus capsule, and a return overlay — so the session is reachable and legible without hunting for a window. It also closes the four hardening follow-ups the independent M1 validator recorded, which were deferred into this milestone rather than waived.

## Goals, non-goals, assumptions

**Goals:** three new surfaces that are *views* of the existing session and never a second source of truth; one canonical engine-derived snapshot every surface renders; a re-entry path that shows the exact next action at the moment of return; render-level (not source-level) proof of the Reduce Transparency and Increase Contrast alternates; real keyboard coverage of the whole loop as key events; genuine two-configuration schema parity; a launch-time first-run assertion.

**Non-goals (explicitly deferred):** global system hotkeys or any Accessibility/Input-Monitoring entitlement; notifications of any kind; EventKit or Reminders import; App Intents; Shortcuts; CloudKit sync; a Dock-less/agent-only app mode; Pro/Enterprise feature content; any network, account, or analytics capability. None of the new surfaces introduces a new persisted field or a new event kind.

**Assumptions:** macOS 26 SwiftUI `MenuBarExtra`, scene-level `windowLevel(_:)`, and `defaultLaunchBehavior(_:)` are available and sufficient — no `NSWindow` subclassing or AppKit window plumbing is required (design decision 2 records the fallback). `ImageRenderer` gives deterministic offscreen rasterization for the render-level accessibility assertions.

**Edition impact:** everything here ships in Lite. The menu-bar popover, the capsule, and the return overlay all carry initiation, hold/resume, check-in entry and accessibility behavior, so all three fall inside the never-paywalled set and the capability registry's startup validation covers them.

**User value:** the session stays visible and operable from the menu bar or a small always-on-top capsule without fronting the app; after a break the exact next action is presented rather than recalled; and a keyboard-only or Reduce-Motion/Reduce-Transparency/Increase-Contrast user gets the same complete product, verified by rendering rather than by inspection.

**Measurable success:** every EARS scenario in this change is covered by a passing automated test; the three surfaces produce byte-identical remaining-time text from one snapshot at one instant; no surface source constructs a countdown; `./scripts/verify-project.sh` exits 0 including the signed UI suite; `npm run spec:validate` passes strict.

## What Changes

- **New `SessionSnapshot` value and `AppModel.snapshot(at:)`** — the single canonical projection of engine state into everything a surface can render (phase, task line, next action, remaining interval, remaining text, status line, VoiceOver summary). Existing surfaces are migrated onto it, so the rule is enforced by construction rather than by convention.
- **New menu-bar popover** (`MenuBarExtra`, window style): status line, remaining time, current task, and the loop entry points — begin, hold/resume, check in, open the main window.
- **New floating focus capsule**: a small always-on-top window with the task line, remaining time, and hold/resume; opened and closed from a menu command; suppressed at launch.
- **New return overlay**: presented over the focus surface the moment a break ends, carrying the exact next action, dismissed by ⏎ or its button. In-memory presentation state only — no new persisted field, no new event kind.
- **New user-initiated check-in** (⌘K) so the check-in surface has a keyboard path of its own, which the loop previously reached only on a due timer.
- **New surface palette** (`SurfacePalette`) with an explicit Reduce Transparency branch and an Increase Contrast branch, used by the new surfaces and probed at render level by tests.
- **Hardening:** render-level transparency/contrast tests via `ImageRenderer` pixel probes; a two-configuration (in-memory vs on-disk) schema-parity test against live `ModelContainer` schemas; UI tests that press check-in 1–4, `R`, and ⌘N as real key events; a launch-time first-run UI assertion.
- **New `scripts/focused.sh`** (fast app unit suite) and **`scripts/smoke.sh`** (build, launch with an ephemeral store, confirm the window, quit) so the per-atom and changed-surface checks are documented commands rather than ad-hoc invocations.

## Capabilities

### New Capabilities

- `companion-surfaces`: the menu-bar popover, floating focus capsule, and return overlay; the single-canonical-state rule that binds them to the engine; their non-scoring, un-paywalled, and accessibility guarantees.

### Modified Capabilities

- `focus-loop-ui`: "Complete accessibility alternates" gains render-level verification of the Reduce Transparency and Increase Contrast alternates and extends the keyboard scenario to the whole loop as real key events.
- `session-persistence`: "Edition-neutral storage" gains a two-configuration parity scenario against live container schemas.
- `app-scaffold`: "App lifecycle restores state" gains a launch-time first-run assertion.
