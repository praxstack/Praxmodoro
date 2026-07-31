# Tasks: add-app-scaffold-core-loop

Every task follows AGENTS.md TDD law: write the named failing test, observe the expected red, implement minimally, verify green plus the smoke command, commit conventionally with only the slice's files. Every completed group leaves the repo runnable.

## 1. Scaffold

- [x] 1.1 Create `app/project.yml` (app + PraxmodoroTests + PraxmodoroUITests targets, macOS 26, Swift 6.3) and `scripts/generate.sh`; red: `scripts/verify-project.sh` fails absent; green: `xcodegen generate` + build succeeds; smoke: app launches to an empty window.
- [x] 1.2 Create SwiftPM packages `app/Packages/PraxmodoroCore` and `app/Packages/PraxmodoroStore` wired into the app target; red: `swift test --package-path app/Packages/PraxmodoroCore` has no tests; green: placeholder test passes headless.
- [x] 1.3 Add `scripts/verify-project.sh` (regenerate + git-diff clean + build + both test targets) and document generate/build/test/run commands in README; smoke: every documented command exits 0 verbatim.

## 2. Timer engine (PraxmodoroCore)

- [x] 2.1 `SessionStateMachine` states + intents; red: `SessionStateMachineTests.testValidLifecycle` and `testInvalidTransitionReturnsTypedError`; files: `Sources/PraxmodoroCore/SessionStateMachine.swift`.
- [x] 2.2 Canonical timestamp arithmetic with injected `ClockProviding`; red: `testRemainingDerivedNotCounted`, `testBackwardsClockClampsAndLogsAnomaly`; files: `SessionTimeline.swift`.
- [x] 2.3 Hold/resume place-keeping; red: `testHoldFreezesRemainingExactly`; same files.
- [x] 2.4 Sleep/wake/relaunch reconstruction from persisted transitions; red: `testWakeAfterSleepShowsTrueRemaining`, `testRelaunchRestoresHeldState`, `testExpiryWhileAsleepBackdated`; files: `SessionReconstruction.swift`.
- [x] 2.5 Timing policies as data (gentle/classic/flow/recovery-first), flow never auto-ends; red: `testGentleStartPromotesSeamlessly`, `testFlowNeverAutoTransitions`; files: `TimingPolicy.swift`.
- [x] 2.6 Module purity gate; red: `ModuleIsolationTests.testCoreLinksOnlyFoundation`; smoke: `swift test` headless on a machine without Xcode GUI.

## 3. Persistence (PraxmodoroStore)

- [x] 3.1 SwiftData models `TaskRecord`, `Session`, `SessionEvent`, `CapacityReport` behind `SessionStoring` protocol; red: `StoreRoundTripTests.testFullSessionRoundTrip`.
- [x] 3.2 Append-only event log with referencing edit events; red: `testEditCreatesReferencingEventNotMutation`.
- [x] 3.3 No-network/no-passive-data structural tests; red: `StoreAuditTests.testNoNetworkSymbolsLinked`, `testNoPassiveObservationFields`.
- [x] 3.4 Corrupt-store recovery path (fresh store + preserved recovery file + plain notice); red: `testCorruptStoreStillReachesInitiate`.

## 4. Companion field physics

- [x] 4.1 Port `FieldPhysics` value type from `design-mocks/living-companion/companion-physics.js` (springs, asymmetric breath 3.6/1.2/5.4/1.4, state targets, pulse); red: `FieldPhysicsGoldenTests.testTransformsMatchJSContractAtFixedTimestamps` against exported JS values; files: `app/Sources/CompanionField/FieldPhysics.swift`.
- [x] 4.2 Canvas/TimelineView renderer with layered radial gradients; smoke: visual side-by-side with mock at breathing/held/expanded.
- [x] 4.3 Total reduced-motion standdown (static alternate view, physics never instantiated); red: `testReduceMotionNeverInstantiatesPhysics`.

## 5. Core loop surfaces

- [x] 5.1 Initiate surface (one task, first action, capacity, policy, ⌘↩ begin, nothing else on path); red: `InitiateSurfaceTests.testStartPathContainsOnlyLoopControls`; files: `app/Sources/Surfaces/InitiateSurface.swift`.
- [x] 5.2 Focus surface (task+time legible, thought parking without context loss, no scoring elements); red: `testThoughtParkingKeepsFocusActive`, `testNoScoringElementsPresent`.
- [x] 5.3 Check-in surface (four answers, timer held, non-grading responses, waits for field blur mid-keystroke); red: `testFourAnswersNoFailureState`, `testCheckinDefersWhileTyping`.
- [x] 5.4 Break surface (user-steerable suggestions with provenance disclosure, re-entry card, early end is ordinary); red: `testEarlyEndHasNoPenaltyPath`, `testSuggestionDisclosesProvenance`.
- [x] 5.5 Review surface (timeline from event log, uncertainty-aware insight copy); red: `testSingleDayInsightStatesLimits`.
- [x] 5.6 App lifecycle restore (relaunch lands on the live surface from persisted state); red: `LifecycleTests.testRelaunchIntoRunningBlockShowsFocus`.

## 6. Cross-cutting gates

- [x] 6.1 `CapabilityRegistry` + startup validation of the never-paywalled set; red: `testLiteGrantIsTotal`, `testCorePaywallAttemptFailsValidation`.
- [x] 6.2 Copy-tone lint test over the strings catalog vs banned-claims lexicon; red: `CopyToneTests.testNoMedicalOrJudgmentClaims`.
- [x] 6.3 Accessibility scenario suite (keyboard loop, VoiceOver field summary, Reduce Transparency solid alternates, Increase Contrast ratios); red: `AccessibilityTests` per focus-loop-ui spec scenarios.
- [x] 6.4 Network-silence harness over a full loop run; red: `testFullLoopMakesZeroOutboundConnections`.
- [x] 6.5 Provenance About surface (version, SHA, edition); red: `testAboutShowsProvenance`.
- [x] 6.6 Full gauntlet: fresh focused tests, full suite, build, lint/format, smoke QA of the five-surface loop, `npm run spec:validate`, independent validator pass against SPEC.md; update `prd.json` + `progress.txt` with evidence.
