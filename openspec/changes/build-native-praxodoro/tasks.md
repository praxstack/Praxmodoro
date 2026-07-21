## 1. Reproducible native scaffold

- [x] 1.1 Pin XcodeGen 2.46.0 and create the generated macOS project plus internal Swift package.
  - **Files:** create `.xcodegen-version`, `scripts/bootstrap-xcodegen.sh`, `scripts/verify-scaffold.sh`, `scripts/run-app-tests.sh`, `scripts/smoke-scaffold.sh`, `project.yml`, `Packages/PraxodoroCore/Package.swift`, `Packages/PraxodoroCore/Sources/PraxodoroCore/PraxodoroCore.swift`, `Packages/PraxodoroCore/Tests/PraxodoroCoreTests/ScaffoldTests.swift`, `PraxodoroApp/PraxodoroApp.swift`, `PraxodoroApp/Platform/AppPaths.swift`, `PraxodoroApp/Features/FocusLoop/InitiateView.swift`, `PraxodoroTests/ScaffoldIntegrationTests.swift`, `PraxodoroUITests/PraxodoroLaunchUITests.swift`; generate `Praxodoro.xcodeproj/`.
  - **RED:** write `scripts/verify-scaffold.sh`, run `bash scripts/verify-scaffold.sh`, and observe failure naming the missing `project.yml`/project/targets.
  - **Minimal implementation:** bootstrap the archive- and executable-checksum-verified official XcodeGen 2.46.0 release into ignored repo-local tooling, revalidate cached executables before invocation, confine interrupted-download cleanup to the exact temporary directory, define macOS 26 app/test targets and the strict Swift package, generate the project, and render an adaptive semantic initiation placeholder with no behavior claim.
  - **GREEN:** run the scaffold verifier, warnings-as-errors package tests, unsigned app build, then build and execute app-unit/UI tests through the normal local test-signing path with retained `.xcresult` evidence.
  - **Smoke:** launch the exact Debug binary with unique `CFFIXED_USER_HOME`, `TMPDIR`, and app-state roots, verify liveness/fatal-log cleanliness, and use the UI test to prove the initiation heading before deterministic termination.
  - **Commit:** `chore: scaffold native macOS app`.

- [x] 1.2 Add project-wide formatting, strict-concurrency, dependency-provenance, and regeneration gates.
  - **Files:** create `.swift-format`, `docs/engineering/dependencies.md`, `scripts/verify-project-generation.sh`; modify `project.yml`, `README.md`.
  - **RED:** run `bash scripts/verify-project-generation.sh` before the version/provenance and no-diff checks exist; expect a missing provenance or regeneration mismatch failure.
  - **Minimal implementation:** enable Swift 6 strict concurrency and warnings-as-errors for project code, record XcodeGen source/tag commit/archive and executable checksums/license/removal path, verify the actual toolchain, and compare a pre-generation project snapshot with regenerated output recursively.
  - **GREEN:** lint only the package manifest/sources/tests and app/test sources with explicit configuration, run the regeneration verifier, warnings-as-errors package tests, unsigned build, and executed app-unit/UI tests.
  - **Smoke:** open the generated scheme inventory with `xcodebuild -list -json -project Praxodoro.xcodeproj` and verify app, unit-test, and UI-test targets.
  - **Commit:** `chore: enforce native project quality gates`.

## 2. Edition capability foundation

- [x] 2.1 Implement the product capability registry and Lite/Pro/Enterprise matrices.
  - **Files:** create `Packages/PraxodoroCore/Sources/PraxodoroCore/Entitlements/ProductCapability.swift`, `ProductRules.swift`; create `Packages/PraxodoroCore/Tests/PraxodoroCoreTests/ProductRulesTests.swift`.
  - **RED:** run `swift test --package-path Packages/PraxodoroCore --filter ProductRulesTests`; expect compile failure because `ProductCapability` and `ProductRules` do not exist.
  - **Minimal implementation:** define an exhaustive ungateable Lite-feature inventory plus optional Pro/Enterprise capability descriptors with explicit authorization, platform eligibility, distribution, downgrade, data-access, and adapter-availability decisions; exclude privileged blocking pending its separate add-on spec.
  - **GREEN:** rerun the focused test and then all package tests with zero failures/warnings.
  - **Smoke:** print the deterministic Lite capability count from a test fixture and verify every core-loop/accessibility/privacy identifier is present.
  - **Commit:** `feat: define safe edition access catalog`.

- [x] 2.2 Implement entitlement evidence, policy precedence, expiry, and downgrade behavior.
  - **Files:** create `Packages/PraxodoroCore/Sources/PraxodoroCore/Entitlements/EntitlementSnapshot.swift`; extend `ProductRules.swift`; create `EntitlementSnapshotTests.swift`.
  - **RED:** run `swift test --package-path Packages/PraxodoroCore --filter EntitlementSnapshotTests`; expect missing-type failures for verified evidence and policy resolution.
  - **Minimal implementation:** separate public untrusted claims from privately constructed interval-valid grants; keep production paid resolution Lite-only until a verifier exists; record implementation and runtime availability independently alongside every other concurrent failure, evidence/issue/expiry/limits, meaningful reevaluation boundaries, one exhaustive consent-safe managed-policy schema with no personal cadence, and opaque session-ID/revision/commit-time/full-snapshot-bound leases whose transition requires the expired resolution of the same grant plus matching complete contexts, rejecting claim loss/logout/verifier failure without StoreKit/network code. This atom proves fail-closed access and active-session policy only; downgrade readability/exportability remains owned by 6.3.
  - **GREEN:** run focused and full package tests.
  - **Smoke:** cover Lite, verified Pro, expired Pro, unverified Enterprise, and managed diagnostics-disabled fixtures in the edition matrix.
  - **Commit:** `feat: resolve validated product access`.

## 3. Pure focus-session domain

Execution order is `3.1 → 3.3 → 3.2`: the pure tested time kernel must exist before the exhaustive
reducer integrates live rows. Numeric labels preserve criterion/history identity, not execution order.

- [ ] 3.1 Define session state, intents, events, projections, and four data-defined timing presets.
  - **Files:** create `Packages/PraxodoroCore/Sources/PraxodoroCore/Session/SessionState.swift`, `SessionIntent.swift`, `SessionEvent.swift`, `SessionProjection.swift`, `TimingPolicy.swift`; create `SessionModelTests.swift`.
  - **RED:** run `swift test --package-path Packages/PraxodoroCore --filter SessionModelTests`; expect missing closed session model, exact default manifest, invariant, error-taxonomy, and preset symbols.
  - **Minimal implementation:** implement the Sendable closed value vocabulary, ten lifecycle states including re-entry, exact events/effects/results/errors, snapshot invariants, and the four exact timing policies/defaults from `docs/specification/session-domain-contract.md`.
  - **GREEN:** run focused and full package tests.
  - **Smoke:** construct and validate one fixture for every lifecycle state, every named error class, and every default; verify all four presets are granted by Lite rules. Codable round trips remain owned by persistence atom 4.2.
  - **Commit:** `feat: model focus session lifecycle`.

- [ ] 3.2 Implement the exhaustive pure reducer and invalid-transition contract.
  - **Depends on:** accepted atoms 3.1 and 3.3.
  - **Files:** create `Packages/PraxodoroCore/Sources/PraxodoroCore/Session/SessionReducer.swift`, `CoachSuggestion.swift`; create `SessionTransitionTests.swift`, `CoachTransitionTests.swift`.
  - **RED:** run `swift test --package-path Packages/PraxodoroCore --filter SessionTransitionTests`; expect missing `SessionReducer.reduce` and invalid-transition results.
  - **Minimal implementation:** implement every row and every default rejection in the normative state-by-intent matrix, copy every accepted 3.3 live entry/scheduled replacement/scheduled remainder, live/relaunch/admission, non-boundary focus/break exit, and winner-time boundary-exit materialization into exact candidates and events without clock arithmetic, classify duplicate/stale boundary inputs before timing admission, and implement conflict choices, thought parking, check-ins, breaks/re-entry, completion/review, optional capacity, and deterministic first-action help.
  - **GREEN:** run focused transition/coach tests and the full package suite, including exact interval/manual schedule changes for paused, resume-suspended check-in, live break resume-target, phase-boundary check-in, and re-entry; exact observed-wall `pausedAt` when a resume-suspended check-in resolves back to paused; due-boundary supersession for open-check-in/request-break/end-break; due/no-due Stop/Replace-and-Review terminal materialization with exact events/totals plus expected-versus-observed review timestamp separation; every canonical transition timestamp source; and revised-action persistence into the plan/final summary.
  - **Smoke:** generate a transition-matrix report proving no unhandled state/intent pair and execute one full initiate→focus→check-in→break→re-enter→review fixture.
  - **Commit:** `feat: implement deterministic focus reducer`.

- [ ] 3.3 Implement canonical time projection and reconciliation.
  - **Depends on:** accepted atom 3.1; this atom creates no reducer stub or event envelope.
  - **Files:** create `Packages/PraxodoroCore/Sources/PraxodoroCore/Runtime/SessionTimeSource.swift`, `PhaseEndScheduling.swift`; extend `SessionProjection.swift`; create `TimerReconciliationTests.swift`.
  - **RED:** run `swift test --package-path Packages/PraxodoroCore --filter TimerReconciliationTests`; expect missing manual clock/projection/reconciliation APIs.
  - **Minimal implementation:** implement the callable projector plus pure internal live/relaunch reconciliation, typed live-entry and scheduled-replacement decisions, exact non-boundary exit/live-commit and winner-time boundary-exit materialization values, installed-boundary cadence/admission decisions, and token-allocation decisions from the paired canonical raw-wall/monotonic anchor; persist no values directly, separate ±2 admission tolerance from any-nonzero live-commit rebasing, do not compute irrelevant observation-based totals when a boundary is due, recover on any future relaunch anchor, return non-finite current wall as a typed zero-write decision, continue through sleep, and return the named recovery/failure decisions for impossible observations and new-entry construction. Duplicate/stale preclassification belongs to Atom 3.2.
  - **GREEN:** run focused and full package tests with exact wall-100 phase-300/cadence-900 entry deadlines and ordered tokens, saved/open-ended focus and break entries, schedule replacement plus manual/5/120-minute remainder values, non-finite/date/occurrence entry failures, fractional-boundary paired elapsed, NaN/infinite precedence, ±1-hour clock decisions, exact ±1/±2 admission-versus-live-commit outputs, exact non-boundary focus timing/cadence and break accumulation, future-cadence preserve/equal-collision reset/overdue-later-scheduled reset/scheduled reset decisions, scheduled-earlier/phase-later/both-overdue exact winner-time suspension despite irrelevant observation-total overflow, winner-total overflow recovery, sleep before/after deadline, equal/future relaunch anchors, timezone/DST, zero boundary, Flow, token arbitration, and pure one-winner admission; reducer candidates/events and pause/resume integration remain Atom 3.2 work.
  - **Smoke:** assert ordinary countdown projection performs zero repository writes.
  - **Commit:** `feat: reconcile canonical session time`.

## 4. Actor runtime and local persistence

- [ ] 4.1 Implement the actor-isolated engine and in-memory atomic repository.
  - **Files:** create `Packages/PraxodoroCore/Sources/PraxodoroCore/Runtime/SessionEngine.swift`, `SessionRepository.swift`; create `SessionEngineTests.swift`, `InMemorySessionRepositoryTests.swift`.
  - **RED:** run `swift test --package-path Packages/PraxodoroCore --filter SessionEngineTests`; expect missing `SessionRunning`, snapshot stream, and repository commit contract.
  - **Minimal implementation:** serialize intents, enforce expected revision, atomically commit snapshot/events, map all five reduction failures to same-named zero-write engine failures, publish only committed revisions through independent replay-latest broadcast streams, and perform effects after commit.
  - **GREEN:** run focused tests, Swift concurrency stress fixtures, Thread Sanitizer test configuration where supported, and all package tests; all five failure mappings pass, two subscribers receive identical current/later revision sequences, and cancelling one does not affect the other.
  - **Smoke:** issue concurrent main/menu-bar intents and verify one ordered result; inject save and notification failures and verify state guarantees.
  - **Commit:** `feat: add atomic session runtime`.

- [ ] 4.2 Add SwiftData V1 models and repository adapter behind the shared contract.
  - **Files:** create `PraxodoroApp/Persistence/PraxodoroSchemaV1.swift`, `SwiftDataSessionRepository.swift`, `InMemorySessionRepository.swift`; create `PraxodoroTests/Persistence/RepositoryContractTests.swift`, `SwiftDataSessionRepositoryTests.swift`.
  - **RED:** run the repository test target; expect missing V1 schema and adapter failures.
  - **Minimal implementation:** add zero-or-one active snapshot, session/event/thought/retention records, atomic revision commit, duplicate/conflict recovery, versioned schema, and temporary-store test support.
  - **GREEN:** run repository contracts against in-memory and temporary SwiftData plus the full app test suite.
  - **Smoke:** recover fixtures from every lifecycle state after container recreation and prove migration failure leaves the prior test store recoverable.
  - **Commit:** `feat: persist local focus sessions`.

## 5. Liquid Instrument application surfaces

- [ ] 5.1 Implement semantic design tokens, surface roles, and accessibility/power render policy.
  - **Files:** create `PraxodoroApp/DesignSystem/DesignTokens.swift`, `RenderPolicy.swift`, `FunctionalGlassSurface.swift`, `InstrumentSurface.swift`, `TimerDial.swift`, `AmbientField.swift`; create `PraxodoroTests/DesignSystem/RenderPolicyTests.swift`.
  - **RED:** run the render-policy tests; expect missing policy/surface-role symbols and fallback mappings.
  - **Minimal implementation:** derive full, opaque, reduced-motion, high-contrast, non-color, low-power, and hidden-scene policies using native SwiftUI/macOS APIs and no third-party effects package.
  - **GREEN:** run focused tests, app tests, and unsigned build under both appearances.
  - **Smoke:** render initiation/focus fixtures for full effects and all OS fallback combinations; verify hidden/reduced/low-power fixtures have no active ambient loop.
  - **Commit:** `feat: add Liquid Instrument design system`.

- [ ] 5.2 Wire one app container, main window, and menu-bar surface to the same engine.
  - **Files:** create `PraxodoroApp/App/AppContainer.swift`, `AppModel.swift`, `CapabilitySnapshotSource.swift`, `PraxodoroApp/Scenes/MainWindowScene.swift`, `MenuBarScene.swift`; modify `PraxodoroApp/PraxodoroApp.swift`, `Packages/PraxodoroCore/Sources/PraxodoroCore/Entitlements/EntitlementSnapshot.swift`, and `ProductRules.swift`; create `PraxodoroTests/App/AppModelTests.swift` plus focused core facade tests.
  - **RED:** run `AppModelTests`; expect missing shared-container, independent session/capability subscriptions, and scene-command APIs.
  - **Minimal implementation:** instantiate one engine/repository/capability source, subscribe independently to session and capability changes, combine them into one observable app snapshot without coupling their emission cadence, add one public Core integration facade initialized from that same `SessionRunning` instance so it consumes committed start/boundary publications internally while Atom 2.2's receipt/lease constructors remain inaccessible, bind that facade's expiry-only transition to committed session boundaries, apply all non-expiry fallback immediately, and bind both native scenes to the result without injecting entitlements into the pure session engine or accepting a caller-supplied downgrade reason/lease.
  - **GREEN:** run focused/app/package tests and build, including two non-competing session subscribers for AppModel/coordinator, expiry-only mid-focus preservation until the next committed boundary, immediate verifier/logout/prerequisite fallback, and a capability-only publication fixture that leaves the session ID/revision unchanged.
  - **Smoke:** start/pause from the menu bar and verify the main window reports the same session ID/revision; expire an eligible leased capability and prove boundary gating in both scenes; then change a non-expiry prerequisite without a session transition and verify both scenes update immediately while the session ID/revision remain unchanged; close/reopen the window without restarting the timer.
  - **Commit:** `feat: share session state across Mac surfaces`.

- [ ] 5.3 Build the accessible Initiate and Focus vertical slice.
  - **Files:** implement `PraxodoroApp/Features/FocusLoop/InitiateView.swift`; create `FocusView.swift`, `ThoughtParkingView.swift`; create `PraxodoroUITests/InitiateFocusUITests.swift` and view-model tests.
  - **RED:** run focused UI/model tests; expect failures for offline no-prerequisite start, unspecified capacity, editable first action, keyboard order, and canonical focus controls.
  - **Minimal implementation:** translate Hallmark hierarchy into native semantic controls, four Lite policies, optional capacity, manual/deterministic action, timer dial, pause/resume, thought parking, and low-cognitive-load toggle.
  - **GREEN:** run UI/model/package tests and app build.
  - **Smoke:** use keyboard-only automation to start offline, pause/resume, park a thought, toggle low-cognitive-load mode, and relaunch into the same state.
  - **Commit:** `feat: build initiate and focus experience`.

- [ ] 5.4 Build accessible check-in, detour, break/re-entry, and descriptive review.
  - **Files:** create `PraxodoroApp/Features/FocusLoop/CheckInView.swift`, `BreakView.swift`, `ReviewView.swift`; create `PraxodoroUITests/CoachLoopUITests.swift`, `PraxodoroTests/Features/ReviewInsightTests.swift`.
  - **RED:** run focused tests; expect missing choice semantics, transition handling, early break end, context restoration, sparse-insight guard, and nonpunitive copy.
  - **Minimal implementation:** implement all check-in choices, detour/smaller-action flow, explainable break alternatives/quiet mode, early end, re-entry orientation, counts-only sparse review, and no upgrade takeover.
  - **GREEN:** run focused/full tests and build.
  - **Smoke:** drive the entire core loop by keyboard and VoiceOver identifiers with ignored/dismissed prompts and early stop fixtures.
  - **Commit:** `feat: complete ADHD-aware focus loop`.

- [ ] 5.5 Add the optional compact floating surface after AppKit and accessibility gates.
  - **Files:** create `PraxodoroApp/Scenes/FloatingPanelAdapter.swift`, `CompactFocusView.swift`; create `PraxodoroUITests/CompactSurfaceUITests.swift`.
  - **RED:** run compact-surface tests; expect missing activation/Spaces/focus/VoiceOver behavior and state-parity assertions.
  - **Minimal implementation:** add a thin `NSPanel` adapter over the same app snapshot with canonical controls, explicit enable/disable, and no independent timer.
  - **GREEN:** run focused/full UI tests and build.
  - **Smoke:** test normal/keyboard/VoiceOver behavior across window activation, Space change, fullscreen app, main-window close, and disable/re-enable.
  - **Commit:** `feat: add compact focus instrument`.

## 6. Privacy, retention, notifications, and data control

- [ ] 6.1 Implement V1 data dictionary, bounded retention, and session-only coaching defaults.
  - **Files:** create `docs/privacy/data-dictionary.md`, `PraxodoroApp/Persistence/RetentionPolicy.swift`, `RetentionCleaner.swift`; create `PraxodoroTests/Persistence/RetentionCleanerTests.swift`.
  - **RED:** run retention tests; expect missing category manifest, expiry calculations, cleanup results, and last-cleanup state.
  - **Minimal implementation:** encode the specified 24-hour/30-day/session/seven-day/90-day/ephemeral defaults, deterministic launch/daily cleanup, per-category failure reporting, and explicit private-history opt-in.
  - **GREEN:** run focused/full tests, build, and compare code categories with the data dictionary.
  - **Smoke:** seed every category around boundary timestamps and verify exact retained/deleted rows and user-visible cleanup state.
  - **Commit:** `feat: enforce local data retention`.

- [ ] 6.2 Implement privacy-safe local notifications as supplemental effects.
  - **Files:** create `PraxodoroApp/Platform/LocalNotificationScheduler.swift`, `PraxodoroApp/Features/Settings/NotificationSettingsView.swift`; create `PraxodoroTests/Platform/LocalNotificationSchedulerTests.swift`.
  - **RED:** run scheduler tests; expect missing opt-in permission timing, content minimization, event IDs, deduplication, cancellation, and denial fallback.
  - **Minimal implementation:** schedule phase/check-in notifications only after feature opt-in, omit sensitive previews by default, deduplicate one event, honor dismissal/system quiet behavior, and never request Critical Alerts.
  - **GREEN:** run focused/full tests and build.
  - **Smoke:** deny permission, grant permission, hide previews, duplicate callbacks, dismiss events, and verify timer correctness in every fixture.
  - **Commit:** `feat: add private focus notifications`.

- [ ] 6.3 Implement local export and honest Delete All behavior.
  - **Files:** create `PraxodoroApp/Persistence/DataExportService.swift`, `DataDeletionService.swift`, `PraxodoroApp/Features/Settings/DataControlView.swift`; create export/deletion tests.
  - **RED:** run focused tests; expect missing category selection, schema manifest, exact-field export, downgrade readability, notification cancellation, full local deletion, and partial-failure status.
  - **Minimal implementation:** keep local data reads and export independent of paid capability gates, export exactly selected V1 categories, delete every local category and queued notification, preserve retry status, and explain exported-file/device-backup limits.
  - **GREEN:** run focused/full tests, build, gitleaks, and content-field snapshot tests.
  - **Smoke:** seed every category under a Pro snapshot, downgrade to Lite/offline evidence, verify exact reads and export still succeed, then export minimal/all sets, delete all, and verify zero local queries plus honest remaining-copy messaging.
  - **Commit:** `feat: add local export and deletion controls`.

## 7. Accessibility, privacy, and performance QA

- [ ] 7.1 Complete the native accessibility matrix and visual regression dossier.
  - **Files:** create `PraxodoroUITests/AccessibilityUITests.swift`, `docs/design/native-visual-qa.md`; modify surface views and design-system files only for verified findings.
  - **RED:** run the accessibility suite and capture failures for any unreachable action, missing selection, chatty timer, nonfocusable transition, chart alternative, or fallback path.
  - **Minimal implementation:** fix all Critical/Important findings without weakening the Hallmark hierarchy or reducing Lite capability.
  - **GREEN:** run keyboard, VoiceOver identifiers, Reduce Motion, Reduce Transparency, Increase Contrast, Differentiate Without Color, large text, light/dark, and narrow-window tests.
  - **Smoke:** capture named native screenshots for Initiate, Focus, Check-in, Break, Review, Settings, menu bar, compact, and all reduced-effects paths into the QA dossier.
  - **Commit:** `fix: complete accessible Liquid Instrument paths`.

- [ ] 7.2 Prove zero-network, no-surveillance, energy, and hidden-scene behavior.
  - **Files:** create `scripts/verify-zero-network.sh`, `docs/verification/privacy-performance.md`; add performance signposts only if content-free.
  - **RED:** run the verification script before domain allowlist/isolated launch instrumentation exists; expect an inability-to-prove failure rather than a false pass.
  - **Minimal implementation:** capture outbound connections for the Lite smoke, audit entitlements/usage strings/log fields, measure CPU/GPU/writes during visible/hidden/low-power/reduced effects, and fail on prohibited activity.
  - **GREEN:** run zero-network, entitlement, log-content, no-per-second-write, hidden-renderer, and Instruments/energy checks with documented thresholds/evidence.
  - **Smoke:** complete a local session under network observation and hide all scenes for five minutes without app-originated requests or continuous decorative work.
  - **Commit:** `test: verify privacy and energy budgets`.

## 8. Verification workflow and handoff

- [ ] 8.1 Add macOS CI and a single local verification entry point.
  - **Files:** create `.github/workflows/ci.yml`, `scripts/verify.sh`, `scripts/smoke-app.sh`; modify `package.json`, `package-lock.json`, `docs/engineering/dependencies.md`, `README.md`, `AGENTS.md`.
  - **RED:** run `bash scripts/verify.sh`; expect a failing gate for each not-yet-wired spec/format/test/build/secret/smoke stage.
  - **Minimal implementation:** reconcile the canonical dependency document against the official OpenSpec repository and npm registry version/source/MIT license/integrity/development-only purpose/upgrade/removal record, then make that provenance check, strict OpenSpec validation, generation diff, Swift format/static checks, package/app tests, unsigned build, gitleaks, Atom 7.2's zero-network/privacy and energy/performance gates, and isolated app smoke mandatory locally and on a supported macOS CI runner.
  - **GREEN:** run `bash scripts/verify.sh` to exit 0 with exact test/build counts, explicit successful Atom 7.2 privacy/energy stages, and no skipped mandatory gate.
  - **Smoke:** execute `scripts/smoke-app.sh` from a clean DerivedData path and confirm the initiation accessibility element before clean termination.
  - **Commit:** `ci: verify native app end to end`.

- [ ] 8.2 Run fresh-context final validation, specialist reviews, docs reconciliation, and OpenSpec archive readiness.
  - **Files:** update `SPEC.md`, `BLUEPRINT.md`, `prd.json`, `progress.txt`, README, data/design/verification docs, session log, `.learnings/feedback/<run-id>.md`; create validator and review reports under `.agent/reviews/`.
  - **RED:** run the validator before reconciliation; any unmapped criterion, unexplained anomaly, failing test, stale task, or undocumented dependency keeps the atom red.
  - **Minimal implementation:** address every Major/Important finding, defer only explicit later-change scope with rationale, map every original/OpenSpec criterion to evidence, and prepare archive without skipping specs or validation.
  - **GREEN:** run full `scripts/verify.sh`, `npm run spec:validate`, independent fresh-context validator, design/privacy/security/performance reviews, and `openspec status --change build-native-praxodoro --json` with every accepted task complete.
  - **Smoke:** rerun the full offline focus loop from main window and menu bar on the final diff and inspect the generated `.app` with no development server.
  - **Commit:** `docs: close verified Praxodoro vertical slice`.
