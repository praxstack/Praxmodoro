# Architecture review session

- Started: `2026-08-23T14:21:50Z`
- Actor: `/root` (Codex desktop)
- Baseline: `a78e0e04cbf5cfe75582e50bfd0ec6b2afb0a4e7`
- Branch: `prax/architecture-review-2026-08-23`
- Working tree at baseline: clean
- Objective: verify the current Praxmodoro architecture, create and review implementation-grade OpenSpec artifacts, derive implementation tickets, implement only after the specification gate passes, close every review finding, run every project quality gate, and commit delivery-ready work.

## Binding constraints

- Preserve `SPEC.md`, `prd.json`, the active OpenSpec change, and the original baseline as separate sources of truth with explicit reconciliation.
- Do not edit or cite a nonexistent `BLUEPRINT.md`.
- Do not implement before specification and planning reviews pass.
- Use one observed failing test before each behavior change.
- Do not weaken tests or acceptance criteria.
- Do not commit until code-review findings are addressed and fresh verification passes.
- Keep network, sync, analytics, and AI capabilities explicit, optional, capability-scoped, and documented; the owner-authorized one-product contract has no tier or edition gate.
- Preserve unrelated work and do not edit `research/skill-sources/` or `research/library-sources/`.

## Skill discovery

Loaded: `using-superpowers`, `brainstorming`, `writing-plans`, `dispatching-parallel-agents`, `subagent-driven-development`, `test-driven-development`, `verification-before-completion`, `using-git-worktrees`, `finishing-a-development-branch`, `spec-creator`, `research`, `llm-council`, `council`, `to-spec`, `to-tickets`, `implement`, `code-review`, `stop-slop`, `autonomous-agent`, `autonomous-orchestrion-v6`, `apex-autonomous-mode`, `hermes-agent`, `grok`, and `codex`.

Also loaded: `plan-ceo-review`, `plan-eng-review`, `plan-design-review`, `plan-devex-review`, and the complete `spec-creator` quality bar, domain, template, and self-review references.

Requested capability not installed: `/moa`. No matching skill, CLI, deferred tool, or recommended plugin exists. The review will therefore use an explicitly labelled MOA-equivalent: independent bounded reviewers followed by root synthesis through the installed `llm-council`/`council` workflow. This is not represented as the unavailable named skill.

## Frozen baseline evidence

- Baseline commit: `a78e0e04cbf5cfe75582e50bfd0ec6b2afb0a4e7`.
- Fresh `./scripts/verify-project.sh`: exit `0`, final line `verify-project: OK`.
- Independent architecture mapper: Core 41 tests passed, Store 8 tests passed, focused checks passed, and strict OpenSpec validation passed 6/6.
- OpenSpec state: `add-companion-surfaces` 18/18 implementation tasks but not archived; `add-session-settings` 34/36 with full-gate and fresh-validation tasks open.
- Rollback pointer: baseline commit above; governing criteria remain `SPEC.md`, `prd.json`, and their owner-approved amendments. This run may amend candidate artifacts but will not weaken their acceptance gates.

## Verified architecture findings

- The Foundation-only Core timestamp engine remains the correct deterministic authority; no timer rewrite is justified.
- `AppModel` is the mutable runtime owner and currently crosses presentation, persistence, session orchestration, preferences, and recovery concerns.
- Persistence is optional at runtime, startup failures and `RecoveryNotice` are discarded, and several mutations update memory before durable writes.
- Event vocabulary is duplicated as bare payload strings; unknown restored transitions currently fall through to `.running`.
- Break-end derivation is duplicated across sound, notification, and reconstruction paths.
- SwiftData uses an unversioned schema, and event order allocation fetches/counts prior events.
- Status artifacts disagree about M2/M3 closure, active change, one-product wording, settings sound defaults, and newer issue dependencies.
- The smallest architecture prerequisite already exists as issues `#51`, `#52`, and `#53`; creating a parallel framework or rewriting Core would duplicate existing work.

## Timeline

- `2026-08-23T14:17:17Z` `PHASE_ENTER` Bootstrap and skill discovery.
- `2026-08-23T14:21:07Z` `BASELINE` Verified normal checkout on `main`, clean at baseline SHA; two unarchived OpenSpec changes found.
- `2026-08-23T14:21:27Z` `SPAWN` Read-only runtime architecture mapper dispatched.
- `2026-08-23T14:21:38Z` `SPAWN` Read-only source-of-truth/status auditor dispatched.
- `2026-08-23T14:21:46Z` `DECISION` Created feature branch `prax/architecture-review-2026-08-23` because project rules prohibit feature work directly on `main`.
- `2026-08-23T14:27:16Z` `AUDIT` Runtime architecture mapper completed; no files modified.
- `2026-08-23T14:27:21Z` `VERIFY` Fresh project verification passed.
- `2026-08-23T14:30:11Z` `CAPABILITY` Exhaustive installed-capability search confirmed `/moa` is unavailable; selected the bounded multi-agent council fallback without claiming named-skill execution.
- `2026-08-23T15:36:54Z` `PLAN_REVIEW` CEO and engineering reviews each found only the explicit historical-commit governance decision; design and DevEx reviews were clean at 9/10 with no unresolved finding.
- `2026-08-23T15:44:00Z` `RECONCILE` Updated `SPEC.md`, `prd.json`, `progress.txt`, and README to name all three active changes and distinguish historical evidence from pending remediation; no production work or completion claim.
- `2026-08-23T16:00:00Z` `REVIEW` Grok full review rejected contradictory snapshot, contrast, hostile-registry, and configuration wording; all findings were amended, and the targeted recheck returned CLEAR.
- `2026-08-23T16:10:33Z` `REVIEW` Independent specification-integrity rerun returned CLEAR with strict validation 7/7, clean diff check, and valid JSON.
- `2026-08-23T16:16:00Z` `REVIEW` Final Codex audit exposed a phase-equality auto-return defect: sleep can span focus→break→focus, while a first post-relaunch render can catch up an absent break.
- `2026-08-23T16:20:10Z` `REPAIR` Replaced phase-only observation with root context-date observation and specified Core's required `autoReturnAfter` process-live boundary; reordered runtime #52 before settings auto-return and archives to M2 → runtime → settings.
- `2026-08-23T16:20:10Z` `VERIFY` Global strict validation passed for all three active changes, repository strict validation passed 7/7, `jq empty prd.json` passed, and `git diff --check` was clean.
- `2026-08-23T16:21:24Z` `DOCS` Documentation build completed: 66 generated plus 2 hand-authored pages.
- `2026-08-23T16:44:13Z` `VERIFY` All three change-specific strict validators, repository strict validation 7/7, `git diff --check`, and `jq empty prd.json` passed after the observer-ownership repair.
- `2026-08-23T16:47:22Z` `REVIEW` Independent specification-integrity recheck returned CLEAR: M2 owns one-snapshot propagation, runtime C2 owns Core/AppModel primitives, and settings 10.7 alone owns date-edge observation behavior and wiring.
- `2026-08-23T16:52:44Z` `REVIEW` Targeted Codex recheck found three remaining documentation defects: two older runtime-ownership overclaims and generated pages that predated the corrected Markdown.
- `2026-08-23T16:54:07Z` `REPAIR` Narrowed the historical settings and runtime-plan claims, rebuilt the site from the complete candidate Markdown set, and generated 77 pages plus 2 hand-authored pages.
- `2026-08-23T16:58:10Z` `REVIEW` Final targeted Codex recheck returned CLEAR. It verified byte-for-byte rendered article parity for 32 changed generated pages and reran all requested validators successfully.
- `2026-08-23T17:03:14Z` `REVIEW` Final plan-gate recheck returned CLEAR after removing a stale pre-reconciliation row and a premature delivery-readiness claim.
- `2026-08-23T17:04:53Z` `DECISION_REQUIRED` The explicit owner prompt about immutable grouped settings commits and missing contemporaneous red receipts returned no selection for the second time. No approval was inferred; production/test edits, ticket conversion, implementation, and commits remain blocked.
- `2026-08-23T17:15:07Z` `OWNER_DECISION` The active completion goal explicitly declares the project specifications pre-approved and requires uninterrupted specification-driven completion. This accepts the documented grouped-commit/missing-receipt deviation without rewriting history or inventing evidence; all new atoms retain red-first, review, isolated-commit, and fresh-gate requirements.
- `2026-08-23T17:15:07Z` `REVIEW_POLICY` Future Grok/OpenCode/model availability failures are non-blocking; the owner directed replacement with a Codex Luna XHigh review. Existing Grok review evidence remains valid and clear.
- `2026-08-23T19:13:04Z` `TDD` A3 keyboard remediation observed compile red for the unavailable public macOS focus property, identifier red for all four break choices, and signed traversal red where native Tab skipped buttons under the host's keyboard-navigation mode.
- `2026-08-23T19:13:05Z` `REPAIR` Reused native controls: exposed stable accessibility children, made existing hold/break buttons focusable, retained Space and Return behavior, and added only surface-local 1-4 shortcuts after the signed traversal red proved the buttons otherwise unreachable.
- `2026-08-23T19:13:06Z` `VERIFY` The isolated signed whole-loop test passed; the full KeyboardLoopUITests class passed 4/4, focused companion/break suites passed 21/21, the persisted timeline exposed `Break: water`, formatting and diff checks passed, and `./scripts/focused.sh` exited 0.
- `2026-08-23T19:43:00Z` `TDD` B1 preset tests first failed with 13 missing-seam compiler errors. The pane source test then reported eight absent accessibility requirements, real-pane contrast renders exposed zero changed/background pixels, and Reduce Transparency renders exposed neither opaque pane background nor backdrop sensitivity.
- `2026-08-23T19:43:01Z` `REPAIR` Added only the shared RhythmPreferences commit validator, editable existing rows, complete preset-pair generation through AppModel, and direct existing SurfacePalette wiring. Reused each pane's first section title as the raster-visible token witness; added no token, dependency, snapshot framework, or private production environment key.
- `2026-08-23T19:43:17Z` `VERIFY` PreferencesTests, SettingsSceneTests, and RenderAccessibilityTests passed 34 tests across three suites, including exact real-pane contrast and transparency rasters. Formatting, JSON parsing, and diff checks passed; tasks 10.1-10.3 and prd atom B1 now truthfully read implemented-uncommitted.
- `2026-08-23T19:44:10Z` `SPEC_GATE` Reconciled runtime tasks 1.1-1.3 with the already-recorded clear Codex, Grok, MOA-equivalent, independent, CEO, engineering, design, DevEx, and spec-creator reviews. Fresh strict validation reported `stabilize-runtime-contracts` valid; runtime production work is unblocked.
- `2026-08-23T19:45:00Z` `TDD` B2's deferred availability report arrived after one notification request existed and failed with recorder.cancels equal to zero, directly reproducing the denial race.
- `2026-08-23T19:45:01Z` `REPAIR` The existing availability callback now invokes the existing synchronization seam after updating denial state; that one-line behavior change cancels pending work without scheduling a replacement.
- `2026-08-23T19:45:21Z` `VERIFY` NotificationDirectorTests passed 10 tests, independent Sol review returned CLEAR, strict formatting/diff checks passed after one mechanical import-order correction, and the full focused app test script reported TEST SUCCEEDED. Task 10.4 and prd atom B2 now read implemented-uncommitted.
- `2026-08-23T19:55:00Z` `TDD` C1's attributable focused red failed on the missing SessionReplayError after C3's independent compiler red was cleared. C3 separately produced two source-boundary failures and a missing beginNextSession compiler error.
- `2026-08-23T19:55:02Z` `REPAIR` C1 added one strict app-boundary codec/replay file, one encode-before-store helper, atomic restore application, codec-owned review labels, and unconditional project regeneration. C3 added only private(set) routing plus a one-line model intent and replaced the two external writes.
- `2026-08-23T19:55:10Z` `VERIFY` C1 focused tests, C3 targeted 3/3 and combined 8/8 regressions, product build, strict formatting/diff checks, sole-append and no-surface-write source guards, and a shared signed smoke all passed. Runtime atoms C1 and C3 now read implemented-uncommitted; their commit tasks remain open for the post-review isolated-staging gate.
- `2026-08-23T20:00:00Z` `TDD` C2's Core red failed on the missing canonical break-end API, the obsolete duration-shaped auto-return argument, and missing process boundary; the app red independently failed all five source guards against duplicated scheduling arithmetic and old restore/live plumbing.
- `2026-08-23T20:00:53Z` `VERIFY` The minimum shared repair made Core authoritative and process-bounded. Core passed 46 tests, the focused app suite passed, exact two-consumer/no-duplicate guards and strict formatting/diff checks passed, and signed smoke exited 0. C2 now reads implemented-uncommitted; task 3.5 remains open for the post-review isolated-staging gate.
- `2026-08-23T20:03:08Z` `TDD` B3 task 10.5 failed on the absent fifth preference and decoder contract; task 10.6 then failed on the absent cue and preview API; task 10.7 failed on the absent live observer. Each red was captured before its production slice.
- `2026-08-23T20:10:20Z` `VERIFY` Legacy/factory preferences, five preview cases, transition-specific block starts, persisted same-phase live auto-return, and post-relaunch non-catch-up all passed their targeted suites. Review tightened the observer to persistence-first throwing behavior and added stored-event idempotence evidence.
- `2026-08-23T20:11:38Z` `TDD` B3 task 10.8 unit red exposed the absent source/bundle resource and all missing pane controls. Three signed UI attempts failed inside macOS automation initialization before the test body (two timeouts and one authentication cancellation), so no product UI result is recorded yet.
- `2026-08-23T20:18:50Z` `TDD` B3 task 10.9 failed on the absent retention predicate, pending-player timestamp, wake cancellation protocol, AppModel intent, and native app wiring.
- `2026-08-23T20:20:32Z` `VERIFY` The generated fifth WAV, exact sample controls, copy-tone test, focused suite, and 55-test sound/snapshot/wiring selection passed. Wake cancellation retains only future players and performs no resync. Tasks 10.5-10.7 and 10.9 are checked; 10.8 remains open solely for a signed test-body result, and independent review is in flight.
- `2026-08-23T20:31:57Z` `REVIEW_FIX_RED` Independent sound review found two untested defects: rhythm edits retained stale break-end scheduling, and master-volume edits did not update the tracked chime or active tick loop. Three new regressions reproduced both defects in a targeted exit-65 run.
- `2026-08-23T20:33:54Z` `REVIEW_FIX_GREEN` The minimum repair reuses the existing synchronization and scheduling seams. Rhythm changes now resynchronize sound and notifications; master-volume changes replace the tracked chime and update active tick players. The targeted selection and full focused suite passed, strict source/test formatting and diff checks passed, and re-review is in flight.
- `2026-08-23T20:37:55Z` `REVIEW_FIX_RED` Re-review showed that broad volume-change cancellation stopped the just-fired block-start cue or an active sample, then recreated only the tracked end chime. A pending-player recorder exposed the loss and the SoundDirector suite exited 65.
- `2026-08-23T20:40:36Z` `REVIEW_CLEAR` The scheduler now updates every pending one-shot player's volume in place and keeps the active tick update on its existing seam. The targeted 70-test selection and full focused suite passed, strict formatting/diff checks passed, and independent sound re-review returned CLEAR.
- `2026-08-23T21:00:04Z` `UI_FIX_RED` Signed execution finally reached the sample and first-run bodies. It exposed saved-window-state leakage and then app/helper connection loss across sequential class launches; individual sample, first-run, and whole-loop behavior otherwise exercised the expected controls.
- `2026-08-23T21:17:16Z` `UI_GREEN` The shared launcher now uses Apple's persistence-ignore argument and explicit before/after termination. Fresh signed first-run, five-sample traversal/labels/activation, whole-loop, and complete KeyboardLoopUITests 5/5 runs passed. Task 10.8 is checked and B3 is implemented-uncommitted.
- `2026-08-23T21:36:51Z` `REVIEW_FIX_GREEN` Whole-diff review exposed main-window-only ownership of derived-phase and wake observation. The new companion-scene regression failed before wiring. A permanent menu-label TimelineView was tried and rejected because it kept hosted tests alive; the retained repair reuses the capsule and menu popover timelines with their own canonical snapshot instant, date-edge materialization, and native wake cleanup. CompanionSurfaceTests passed 15/15, including single-snapshot, drift, and no-second-clock guards; independent re-review is in flight.
- `2026-08-23T21:47:54Z` `FULL_GATE_RED` Fresh verify-project passed Core 46/46, Store 8/8, strict format, and product build, then failed four signed UI tests. XCResult hierarchies showed disabled keyboard-test applications and legacy launch-test processes with no window; the two UI classes had drifted launch contracts.
- `2026-08-23T21:51:08Z` `FULL_UI_GREEN` A single shared launcher now gives both UI classes persistence-ignore and hermetic-store arguments, terminate-before, explicit activation, and teardown termination. The complete signed UI target passed 7/7 in 94.9 seconds: KeyboardLoopUITests 5/5 and LaunchUITests 2/2. Full verify-project rerun remains pending review.
- `2026-08-23T21:52:18Z` `REVIEW_CLEAR` Independent whole-diff re-review cleared the companion-scene lifecycle repair; a separate targeted review cleared the shared UI launcher. No production or test finding remains open.
- `2026-08-23T21:54:23Z` `FULL_GATE_GREEN` Fresh `./scripts/verify-project.sh` exited 0: Core 46/46, Store 8/8, signed build green, signed Xcode result 230/230 including UI 7/7.
- `2026-08-23T21:55:58Z` `CLOSEOUT_GATES_GREEN` Fresh smoke, focused app 223/223, strict OpenSpec 7/7, changed-file formatting, diff/JSON integrity, product-vocabulary, sole-transition-write, and private-surface guards all exited 0.
- `2026-08-23T23:04:42Z` `IMPLEMENTATION_COMMITTED` Ten independently testable implementation atoms were committed after exact staged-tree checks: A0 `aaaaecef077a`, A1 `f6df42674dfc`, A2 `8191ad22ba2d`, A3 `04b80dc500c0`, B1 `11e8dbc6f769`, B2 `913722b64dc4`, C1 `9f9c8dbeb551`, C2 `3d3474972b56`, C3 `66fb629aee71`, and B3 `ecc814ef72fe`. Every residual-patch SHA remained byte-identical to the frozen reviewed candidate.
- `2026-08-23T23:05:40Z` `SPECIFICATIONS_COMMITTED` The reviewed architecture specifications and dated implementation plans were committed as `b84b19e`; strict OpenSpec validation remained 7/7.
- `2026-08-23T23:10:49Z` `POST_COMMIT_VERIFY` Core 46/46, Store 8/8, strict format, signed build, app 223/223, smoke, and strict OpenSpec 7/7 passed. Two UI retries stopped before test execution in the macOS automation host; the committed app tree `1eb06e8992e087e2769e60d62f925d6ffee179e3` exactly matches the frozen app tree that passed 230/230 including UI 7/7 at 21:54:23Z.
- `2026-08-23T23:44:39Z` `REVIEW_FIX_RED` A new sound regression proved that replacing one derived focus-end expiry broadly cancelled an unrelated block-start and same-cue preview. The targeted SoundDirector run failed as expected.
- `2026-08-23T23:45:38Z` `REVIEW_FIX_GREEN` AppModel now cancels only its tracked cue/instant pair. SoundDirectorTests passed 24/24, including real pending-player isolation; independent review returned CLEAR.
- `2026-08-23T23:56:34Z` `REVIEW_FIX_RED` Literal EARS validation found the status line was not visibly canonical on focus and capsule. The strengthened capsule test failed compilation at the missing `statusText` seam.
- `2026-08-23T23:57:27Z` `REVIEW_FIX_GREEN` Focus and capsule now visibly reuse the canonical snapshot status; focus, popover, and capsule task/time/status are compared at one instant. FocusCapsuleTests passed 5/5 and two independent rechecks returned CLEAR/CLOSED.
- `2026-08-24T00:02:11Z` `REPAIR_COMMITS` Three reviewed exact staged trees passed `./scripts/focused.sh` before commits `d4da3004529f` (surface status), `8eac35aa368d` (selective chime cancellation), and `a62d5afee1f7` (composed transparency evidence).
- `2026-08-24T00:03:28Z` `CURRENT_NON_UI_GATES` Current Core 46/46, Store 8/8, app 228/228, strict source formatting, product build, signed smoke, strict OpenSpec 7/7, diff/JSON integrity, and UI test-bundle compilation all passed.
- `2026-08-24T00:05:05Z` `CURRENT_UI_HOST_BLOCK` The signed capsule/settings selection failed before either test body because macOS timed out enabling automation mode. The reviewed UI evidence remains uncommitted; no product failure or green result is inferred.
- `2026-08-24T00:13:49Z` `UI_EVIDENCE_RED` Literal review found “Settings open by keyboard from any surface” was proved only from the main WindowGroup. The extended three-scene-root test initially failed compilation because its XCUI clock helper lacked MainActor isolation.
- `2026-08-24T00:15:16Z` `UI_BUILD_GREEN_REVIEW_CLEAR` The one-line isolation fix restored TEST BUILD SUCCEEDED. Independent review cleared the main WindowGroup, capsule Window, and MenuBarExtra command origins plus their state/countdown assertions. Signed execution remains pending.
- `2026-08-24T00:26:08Z` `AUTH_PATH_EXHAUSTED` `/usr/bin/automationmodetool` reports Automation Mode disabled and requiring user authentication; `sudo -n` has no cached credential. Local and official Apple research found no supported xcodebuild flag or noninteractive grant from this state. No TCC/security database, private entitlement, credential, or LocalAuthentication bypass was attempted.
- `2026-08-24T00:35:57Z` `ARCHIVE_REHEARSAL_RED` Dependency-ordered disposable archives reproduced docs source discovery failure after Git moves, then independent reviews exposed same-section title collisions, stale canonical/source terminology, OpenSpec 1.6 TBD Purposes, archive-added EOF whitespace, and one obsolete edition-shaped parity test already superseded by live two-container evidence.
- `2026-08-24T00:47:41Z` `ARCHIVE_CLOSEOUT_COMMIT` The minimum archive-closeout repair landed as `4417c3506f7b`. Both re-reviews returned CLEAR. The exact staged tree passed Core 46/46, app 227/227, docs build, strict OpenSpec 7/7, formatting, diff, and secret checks; a duplicate-title negative control failed through the permanent guard. Its exact M2 → runtime → settings rehearsal produced 81 pages, strict OpenSpec 6/6, correct canonical Purposes, unique outputs, and clean stale-term scans.
- `2026-08-24T00:50:15Z` `POST_R5_NON_UI_GATES` Store passed 8/8, the current UI target reported TEST BUILD SUCCEEDED with the uncommitted scene-root cases, signed smoke passed, strict UI-test formatting passed, strict OpenSpec remained 7/7, and diff/JSON integrity passed. Current signed UI execution remains the only runtime test gate not reached.
- `2026-08-24T01:03:45Z` `VALIDATOR_INCOMPLETE` A fresh independent validator mapped all 97 active EARS scenarios and found no product, specification, test-candidate, or archive-closeout defect. Core 46/46, Store 8/8, app 227/227, smoke/build/format/diff/JSON, and strict OpenSpec 7/7 passed. `verify-project.sh` exited 65 only at UI-runner initialization with `Authentication canceled. System authentication is running`; its xcresult contains zero UI test bodies, so the verdict remains INCOMPLETE and archive remains closed.
- `2026-08-24T01:04:53Z` `EXTERNAL_AUTH_IMPASSE` A third consecutive goal-turn audit still reports Automation Mode disabled, administrator authentication required, and no cached sudo credential. All safe supported paths are exhausted. The reviewed UI candidate and closeout evidence remain preserved uncommitted; no archive, final commit, push, or issue mutation was performed.

## Current gate

- Specifications passed the final Codex, Grok, MOA-equivalent, and targeted independent reviews; current strict OpenSpec validation is 7/7.
- Ten planned implementation atoms, three implementation review-repair atoms, and the archive-closeout repair are committed. A fresh independent validator found no defect and mapped all 97 active EARS scenarios, but returned INCOMPLETE because the new capsule/settings UI paths have not executed: macOS authentication stopped the UI runner before any body. Their commit, a fresh COMPLETE verdict, and actual dependency-ordered archive remain pending.
- Historical grouped commits remain immutable and missing contemporaneous red receipts remain explicitly missing; owner pre-approval removed only the governance hold.
