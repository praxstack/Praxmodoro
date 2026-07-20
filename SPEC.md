# Praxodoro Native App Completion Contract

- Status: implementation candidate; requires plan/council gate before application code
- Date: 2026-07-20
- Active OpenSpec change: `build-native-praxodoro`
- Platform: macOS 26+, Xcode 26.6, Swift 6.3
- Editions: Lite, Pro, Enterprise from one codebase
- Visual direction: Hallmark “Liquid Instrument”

## Objective

Build and verify a locally runnable native macOS focus timer and non-clinical ADHD-aware focus coach. The first completed product slice must support the full offline initiation → focus → optional check-in/detour → break/re-entry → review loop from the main window and menu bar, survive sleep/relaunch/clock changes, honor macOS accessibility, and establish explicit Lite/Pro/Enterprise capability boundaries without requiring cloud services.

## Product promise

Praxodoro helps a person start, orient, continue, recover, and stop with less cognitive overhead. It adapts only from explicit input and session events, explains suggestions, preserves user choice, and uses descriptive rather than judgmental feedback.

It is not a medical device, diagnostic system, treatment, surveillance product, employer productivity monitor, or substitute for professional care.

## Source hierarchy

1. This global completion contract and the original user request.
2. `openspec/changes/build-native-praxodoro/` proposal, six capability specs, design, and tasks.
3. `BLUEPRINT.md`, `prd.json`, and the dated implementation plan.
4. Current code, tests, build logs, smoke evidence, and Git history.
5. `research/pomodoro-landscape-20260720/` and `design-mocks/hallmark/` as product/design evidence, not runtime proof.

## Assumptions

- **A-001:** “Lite Prope Enterprise” means Lite, Pro, and Enterprise editions.
- **A-002:** macOS 26+ is the initial deployment target; backward compatibility is a later change.
- **A-003:** The latest instruction to begin autonomously approves implementation from the Liquid Instrument direction, but native design QA may correct browser-specific values.
- **A-004:** Timed phases continue through Mac sleep; waking after a deadline stops at a user decision rather than auto-chaining phases.
- **A-005:** Capacity is optional, defaults to unspecified, and is never inferred.
- **A-006:** Capacity/check-in answers are session-only unless the user explicitly enables bounded private history in a later implemented control.
- **A-007:** Deterministic/manual first-action help is canonical; optional on-device AI is a later enhancement.
- **A-008:** Both semantic light and dark appearances ship; the nocturnal cobalt treatment is the flagship dark appearance.
- **A-009:** All four timing presets, accessibility, data export/delete, and the complete recovery loop remain in Lite.
- **A-010:** Enterprise scaffolding means verified capability/licensing and managed privacy/configuration interfaces, not a speculative tenant/server/admin product.
- **A-011:** Adults are the current evidence-backed audience; minors require a separate safety/privacy review.
- **A-012:** Public remote creation, push, signing, notarization, distribution, cloud backends, commerce, and release are outside the current local completion claim.

## Hard constraints

- Native SwiftUI application; no web wrapper.
- One app codebase and one deep internal core package; no edition forks.
- One canonical actor-isolated session runtime; no per-screen or per-scene timers.
- Pure testable reducer; atomic persistence before state publication or external effects.
- UTC anchors/deadlines plus monotonic live projection; no per-second persistence.
- Local authoritative active state; zero-network Lite baseline with network features disabled.
- Apple platform rendering first; no third-party runtime effects package or remote font in the first slice.
- Full keyboard, VoiceOver, Reduce Motion, Reduce Transparency, Increase Contrast, Differentiate Without Color, low-power, resizable, light/dark, and low-cognitive-load paths.
- No passive app/browser observation, screenshots, keystrokes, clipboard, microphone, camera, location, Health data, advertising, or employer behavior reporting.
- Test-first behavior changes, exact-version/provenance logging, strict OpenSpec validation, secret scan, clean builds, isolated smoke, independent validator.

## Edition contract

| Capability class | Lite | Pro | Enterprise |
|---|---|---|---|
| Complete local focus/recovery loop | Required | Required | Required |
| All timing presets and manual/configurable coach | Required | Required | Required |
| Accessibility, low-cognitive-load, privacy, export/delete | Required | Required | Required |
| Basic local history and descriptive counts | Required | Required | Required |
| Main window, menu bar, compact surface | Required | Required | Required |
| Saved advanced recipes, richer local insights, automated exports | — | Allowed | Allowed |
| Opt-in iCloud history/settings and EventKit/App Intents | — | Allowed later | Policy-controlled later |
| Optional on-device AI enhancement | — | Experimental later | Policy-controlled later |
| Signed offline license, MDM/update/privacy configuration | — | — | Scaffold/later implementation |
| Manager-visible personal behavior | Forbidden | Forbidden | Forbidden |
| Privileged blocking | Separate later add-on | Separate later add-on | Separate later add-on |

## EARS acceptance criteria

### Specification and workflow

- **S-001:** WHEN a clean checkout installs Node dependencies, the system SHALL resolve OpenSpec exactly to 1.6.0 with the recorded official integrity.
- **S-002:** WHEN the active change is strictly validated, OpenSpec SHALL report proposal, six specs, design, and tasks valid with zero issues.
- **S-003:** WHEN a fresh agent starts, the repository SHALL identify the exact active change, 21 atoms, next unfinished atom, prior failures, and verification commands without chat context.

### Session engine

- **E-001:** WHEN no session exists and a user starts offline with a task/action, the system SHALL commit exactly one focusing session without account, paywall, permission, capacity, or network prerequisites.
- **E-002:** WHEN concurrent native surfaces send intents, the engine SHALL serialize them into one revision-ordered state without duplicate transitions.
- **E-003:** WHEN an intent is invalid for the current state, the engine SHALL return an explicit rejection and persist no mutation.
- **E-004:** WHEN a timed phase renders, the system SHALL derive time from canonical anchors and SHALL persist no ordinary per-second ticks.
- **E-005:** WHEN wall time changes while the process runs, monotonic remaining time SHALL not jump and the wall deadline SHALL rebase with a factual clock-adjusted event.
- **E-006:** WHEN the Mac wakes before/after a deadline, the system SHALL reconcile the remaining time or one elapsed boundary and SHALL NOT auto-chain overdue phases.
- **E-007:** WHEN relaunch data is valid, the system SHALL restore the active task/action/policy/timeline/time; WHEN it is impossible, it SHALL offer safe recovery rather than invent elapsed focus.
- **E-008:** WHEN multiple callbacks report the same boundary, the system SHALL commit exactly one phase transition.
- **E-009:** WHEN a second session is requested, the system SHALL require Resume Current, Replace and Review, or Cancel and SHALL NOT silently overwrite.
- **E-010:** WHEN persistence fails, no new state SHALL publish and no effect SHALL fire; WHEN an effect fails after commit, canonical state SHALL remain valid.

### ADHD-aware coach

- **C-001:** WHERE capacity is not explicitly selected, the system SHALL store `nil`, display Not Specified, and make no capacity-derived suggestion.
- **C-002:** WHEN initiation help is requested, the system SHALL provide an editable deterministic/manual path even if AI is disabled, unavailable, or fails.
- **C-003:** WHEN a check-in is due, the system SHALL offer Continue, Make Smaller, Detour, Break, Skip, and Dismiss with exposed semantics and no score.
- **C-004:** WHEN a check-in is ignored/dismissed, the system SHALL create no streak loss, diagnosis, guilt, escalation, or duplicate prompt.
- **C-005:** WHEN a break is suggested, the system SHALL cite only explicit inputs, offer alternatives/quiet/disable/skip, and permit early end without penalty.
- **C-006:** WHEN returning from check-in/break, the system SHALL restore task, accepted/editable action, parked thoughts, and orientation before resuming.
- **C-007:** WHILE low-cognitive-load mode is enabled, the system SHALL show only task, action, optional timer, primary control, thought capture, and escape hatch and SHALL hide analytics/ambient motion/history/upgrades.
- **C-008:** WHEN fewer than five relevant observations across three days exist, review SHALL show counts/denominators only; eligible later patterns SHALL show counts and uncertainty and SHALL NOT auto-change defaults.
- **C-009:** WHILE a focus-loop/recovery state is active, the system SHALL show no blocking purchase prompt.
- **C-010:** The system SHALL NOT diagnose, treat, score symptoms, claim surveillance-derived drift, or use punitive/coercive copy.

### Editions

- **G-001:** WHEN Lite capabilities are enumerated, the full differentiated core, all presets, accessibility, privacy, export/delete, and local surfaces SHALL be present.
- **G-002:** WHEN verified Pro is active, its capability set SHALL be a superset of Lite; unavailable/denied paid services SHALL preserve Lite fallbacks.
- **G-003:** WHEN Enterprise schemas are inspected, they SHALL contain only license/version/update/deployment/allowed privacy-config metadata and no personal behavior fields.
- **G-004:** WHEN paid evidence is unverified/expired, the system SHALL fail closed to Lite without deleting, hiding, or making local data unexportable.
- **G-005:** WHEN paid evidence expires mid-session, the active session SHALL finish with its committed policy and gating SHALL apply at the next boundary.
- **G-006:** WHEN a capability is added, the registry SHALL require explicit edition, permission, distribution, downgrade, and data-access decisions.

### Liquid Instrument UI

- **U-001:** WHEN full effects are allowed, functional controls MAY use native glass while instrument/content roles SHALL preserve legibility and semantic hierarchy.
- **U-002:** WHEN Reduce Transparency is enabled, every translucent surface SHALL become opaque without lost actions.
- **U-003:** WHEN Reduce Motion is enabled, continuous/morphing/parallax/particle/blur motion SHALL stop and remaining transitions SHALL be immediate or ≤150 ms opacity.
- **U-004:** WHEN Increase Contrast or Differentiate Without Color is enabled, every state/control SHALL remain distinguishable without color alone.
- **U-005:** WHEN scenes are hidden or Low Power Mode is active, decorative continuous rendering SHALL stop while session correctness continues.
- **U-006:** WHEN the core loop is operated by keyboard/VoiceOver, every action SHALL be reachable/labeled, selection SHALL be exposed, screens SHALL announce once, and seconds SHALL not announce continuously.
- **U-007:** WHEN a chart is read without sight, the system SHALL expose ordered values, time context, and equivalent text.
- **U-008:** WHEN appearance, scale, or documented minimum size changes, required task/timer/escape controls SHALL remain readable/reachable without overlap.
- **U-009:** WHEN main/menu-bar/compact surfaces render the active session, they SHALL share one session ID/revision and no independent timer.
- **U-010:** WHEN runtime dependencies/assets are inspected, no third-party effects runtime or network font SHALL exist.

### Privacy and data

- **P-001:** WHEN the V1 schema is audited, every stored field SHALL map to a documented data category/purpose/default/retention/sync/export/delete behavior.
- **P-002:** WHILE optional network features are disabled, a Lite session SHALL originate no outbound request.
- **P-003:** WHEN a session completes with private coaching history disabled, raw capacity/check-in answers SHALL be removed.
- **P-004:** WHEN notification features are not enabled, the app SHALL NOT request permission; default previews SHALL omit sensitive content and events SHALL deduplicate.
- **P-005:** WHEN selected categories are exported, output SHALL contain exactly those documented fields and remain available after downgrade.
- **P-006:** WHEN Delete All completes locally, every local user category and notification SHALL be inaccessible; partial future sync deletion SHALL name the remaining category and retry state.
- **P-007:** WHEN diagnostics are recorded, they SHALL be content-free, bounded, opt-in, and contain no raw user text/answers or advertising identifiers.
- **P-008:** WHEN entitlements, permissions, logs, and network domains are audited, prohibited surveillance/advertising capabilities SHALL be absent.
- **P-009:** WHEN retention cleanup runs, it SHALL enforce the documented 24-hour/30-day/session/seven-day/90-day/ephemeral defaults and expose category failures honestly.
- **P-010:** Secrets SHALL use secure platform storage and schema migration failure SHALL leave the prior store recoverable.

### Build, test, and handoff

- **D-001:** WHEN XcodeGen 2.46.0 regenerates the project, the committed project SHALL have no unexplained diff.
- **D-002:** WHEN package and app targets build under Swift 6 strict concurrency, they SHALL produce zero errors and no new warnings.
- **D-003:** WHEN all tests run, core transition/time/capability/repository/app/UI/accessibility suites SHALL have zero failures and no weakened tests.
- **D-004:** WHEN the isolated smoke runs, the built app SHALL launch with isolated storage, expose initiation, stay alive for the probe, and terminate cleanly.
- **D-005:** WHEN verification runs, strict OpenSpec, format/static, tests, build, secret, zero-network/privacy, performance, and smoke gates SHALL all execute with no silently skipped mandatory check.
- **D-006:** WHEN a fresh-context validator compares the final tree to this original contract, every accepted criterion SHALL map to current evidence and every anomaly SHALL be explained.
- **D-007:** WHEN local completion is handed off, public remote, signing/notarization, distribution, cloud, commerce, and Enterprise service status SHALL be reported honestly as shipped or not performed.

## Definition of done

- All 21 accepted OpenSpec tasks are checked and have red/green/regression/smoke/commit evidence.
- `openspec validate --all --strict --no-interactive` passes.
- Full local verification, native build/test, isolated app launch, design/accessibility QA, privacy/secret checks, and performance/energy checks pass freshly.
- Independent validator passes this exact `SPEC.md`, not a rewritten summary.
- Every Major/Important review finding is fixed; any later-scope atom is explicit and not claimed complete.
- Git history contains clean slices; `main` remains protected until verified merge.
- Documentation, data dictionary, edition matrix, audit trail, prd/progress, and human-feedback ritual are current.
- No remote/public/release claim is made without direct evidence.

## Non-goal completion rule

Deferred cloud, integrations, commerce, signing, public repository, distribution, blocker, and Enterprise-service atoms do not prevent completion of the verified local native app change because they are explicit non-goals. Their interfaces may be scaffolded only where required by edition architecture; stubs are never described as shipped services.
