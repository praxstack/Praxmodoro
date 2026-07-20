# Praxodoro Native App Premortem

Assume the build failed or shipped an untrustworthy local app. These are the most plausible causes, how they become visible, and the rollback already available.

| Failure mode | Severity | Likelihood | Earliest signal | Mitigation | Rollback |
|---|---|---|---|---|---|
| UI ticks become timer truth and drift across sleep/relaunch | Critical | Medium | tests require real waiting; duplicate/negative remaining values | Build manual-clock projection before UI; prohibit per-second writes; revision-dedupe callbacks | revert UI/runtime atom to last green pure model |
| SwiftData leaks into views and commits partially | Critical | Medium | view tests need ModelContext; snapshot publishes before event save | repository contract, atomic save, app model façade, failure injection | keep in-memory engine; revert SwiftData adapter atom |
| Liquid effects make text unreadable or consume GPU when hidden | High | High | screenshots fail contrast; Instruments shows hidden display work | semantic surface roles, OS-derived render policy, no external effect package, hidden/low-power tests | disable ambient renderer through render policy; retain opaque surfaces |
| Lite becomes a generic timer because recovery/accessibility is paid | Critical | Medium | capability tests omit a core identifier; upgrade appears mid-flow | normative Lite matrix, superset tests, engine-side gating, no-commerce flow tests | revert entitlement change; fail closed to full Lite core |
| “Adaptive” behavior implies surveillance or clinical inference | Critical | Medium | copy mentions drift/helped without explicit input; new permissions/log fields appear | deterministic explicit-input reasons, prohibited permission/entitlement audit, privacy reviewer | disable offending suggestion path; retain manual coach |
| Scope explodes into CloudKit/StoreKit/Enterprise SaaS before a runnable loop | High | High | tenant/account/server types or product IDs appear before core smoke | explicit non-goals; capability interfaces only; task ordering; first checkpoint after pure core | revert speculative atom; leave interface decision in later OpenSpec change |
| XcodeGen or project file is not reproducible | High | Medium | regeneration changes UUID/settings; CI and local schemes differ | exact 2.46.0, committed project, no-diff generator gate, documented fallback | build committed project; revert generator update |
| macOS 26 Liquid Glass APIs compile but behave differently in test/CI | High | Medium | availability/compiler errors or missing macOS runner | macOS 26 deployment target, official APIs only, opaque fallback, local Xcode proof before CI | disable specific effect; keep semantic surface and core app |
| Accessibility promises rely on screenshots rather than operability | Critical | Medium | XCUITest passes visually but keyboard/VoiceOver cannot reach actions | accessibility IDs/semantics, keyboard flow, focused announcements, manual VoiceOver evidence | block surface atom; revert to accessible standard controls |
| Zero-network test reports green without observing all process traffic | High | Medium | script checks source code only or cannot attribute process connections | fail if capture unavailable; isolated process, DNS/socket observation, asset/entitlement audit | report unverified and keep local-first claim parked |
| Notification callbacks duplicate a phase transition | High | Medium | two timeline events at wake/deadline; duplicate alerts | event IDs + revision dedupe; notifications supplemental only | disable notification scheduling; engine clock remains authoritative |
| Delete All claims completion while backups/sync/export remain | Critical | Medium | local rows zero but UI says “everywhere” | category manifest, partial status, honest exported-file/backup copy, future tombstones | correct claim; keep local deletion status separate |
| Generated tasks are too large for fresh-context agents | Medium | High | implementer touches many responsibilities or cannot finish in one turn | dated implementation plans split each subsystem; task brief per atom; no parallel implementers | decompose atom without changing acceptance criteria; update DAG with rationale |
| Compact `NSPanel` destabilizes focus/Spaces/VoiceOver late in the build | High | High | activation bugs or stuck keyboard focus | implement after main/menu-bar; thin adapter; explicit disable; separate UI tests | revert compact atom and report it incomplete rather than weaken QA |
| Research or mock is treated as efficacy/release proof | High | Medium | docs say “proven for ADHD” or cite visual prototype as behavior | evidence hierarchy, non-clinical copy, independent validator | remove claim; require new research/change before reinstatement |

## Top five preemptive actions

1. Complete capabilities and pure session/time model before SwiftData or screens.
2. Make the first runnable checkpoint main-window-only if needed, but keep menu-bar/compact atoms visibly incomplete rather than collapsing requirements.
3. Require “cannot prove” to fail privacy/performance scripts; no source-inspection-only green claims.
4. Keep all paid/cloud/Enterprise adapters absent from the first core commits; capability value types are sufficient scaffolding.
5. Treat standard accessible controls and opaque surfaces as the default fallback, not a degraded afterthought.

## Mid-task council triggers

- Timer correctness has two plausible behaviors after sleep/relaunch anomaly.
- SwiftData cannot satisfy atomic snapshot/event commit without a design change.
- A native glass API fails an accessibility/performance floor and the alternative changes the visual hierarchy.
- A capability must move across edition boundaries.
- A task needs a new runtime dependency, permission, entitlement, network service, or distribution target.
- Two consecutive implementation attempts fail without ruling out a new cause.
