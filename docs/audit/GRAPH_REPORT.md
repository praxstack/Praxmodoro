# Graph Report - Praxmodoro  (2026-10-03)

## Corpus Check
- 229 files · ~1,472,007 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 18 file(s) not represented in the graph (top: .log 5, .css 4, .ndjson 3)

## Summary
- 2349 nodes · 4467 edges · 168 communities (117 shown, 51 thin omitted)
- Extraction: 78% EXTRACTED · 22% INFERRED · 0% AMBIGUOUS · INFERRED: 981 edges (avg confidence: 0.86)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `3531d6a0`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- .begin
- SettingsSceneTests
- AppModel
- PreferencesTests
- Session
- companion-physics.js
- Requirement: Autostart behaviour is the user's choice
- ADDED Requirements
- RhythmPreferences
- Equatable
- Praxodoro Adhd-Aware Macos Focus Coach, Premium Pomodoro Landscape, Liquid-Glass Skeuomorphic Ux, And Implementation Feasibility
- KeyboardLoopUITests
- CompanionSurfaceTests
- RhythmPane
- Requirement: User-steerable timing policies
- Requirements
- SPEC.md — Praxmodoro completion contract
- FocusSurface
- ADDED Requirements
- .snapshot
- View
- Requirements
- build-docs.mjs
- TimingPolicy
- Foundation
- ADDED Requirements
- .running
- MotionPreferenceTests
- generate-design-tokens.mjs
- .endBreak
- Praxodoro Adhd-Aware Macos Focus Coach, Premium Pomodoro Landscape, Liquid-Glass Skeuomorphic Ux, And Implementation Feasibility
- living-companion/app-mocks.js
- .openCheckin
- SessionReplay
- ADDED Requirements
- Requirements
- export-field-goldens.mjs
- .beginNextSession
- AudioCueScheduler
- MenuBarPopover
- Architecture stabilization and milestone close-out plan
- Requirements
- LifecycleTests
- focus-observatory/app-mocks.js
- Runtime contract foundation implementation plan
- ADDED Requirements
- Global Synthesis
- FieldPhysics
- LocalStore
- PraxmodoroStore
- DesignTokenParityTests
- StoredEventKind
- String
- SwiftUI
- ReturnOverlay
- CueRecorder
- hallmark/app-mocks.js
- ADDED Requirements
- app-scaffold
- FeatureKey
- add-session-settings fresh-validation remediation plan
- Tasks: add-companion-surfaces
- Requirement: Complete accessibility alternates
- Findings
- Open Questions
- LongBreakCadence
- CapabilityRegistry
- FieldModel
- .restore
- Double
- SessionSnapshot
- CueRecorder
- package.json
- .modelOnBreak
- Design: stabilize-runtime-contracts
- RecoveryNotice
- 3. Persistence (PraxmodoroStore)
- FocusCapsule
- InertSoundScheduler
- openspec-explore/SKILL.md
- Praxmodoro Hallmark Mock Dossier
- Requirement: User-steerable timing policies
- Decisions
- SoundCue
- CheckinAnswer
- Design: add-companion-surfaces
- Praxmodoro approved backlog: direct DMG release
- Proposal: add-app-scaffold-core-loop
- Requirement: Break end has one canonical derivation
- Praxmodoro — every open blocker, one shot
- Praxodoro autonomous bootstrap session
- Issue tracker: GitHub
- .validate
- Complete mocked flow
- Enterprise-grade pass: CEO review plan
- Proposal: add-companion-surfaces
- Requirement: Configuration-neutral storage
- Design: add-session-settings
- Requirement: Store-to-Core replay is pure and deterministic
- Research Plan
- Session: M3 closeout — add-session-settings (2026-08-21)
- Architecture review session
- .primaryText
- FocusCapsuleTests
- NetworkSilenceTests.swift
- Proposal: stabilize-runtime-contracts
- Praxmodoro approved backlog and direct-DMG guide
- Praxmodoro
- Source Digest
- Sources
- Wave 1 Plan
- Comparisons
- Methods
- Overview
- Surface
- Provenance
- SurfaceTests.swift
- Domain Docs
- Plan: settings & rhythm parity — proposed change `add-session-settings`
- timer-engine
- Wave 2 Plan
- FieldPhysicsGoldenTests.swift
- AppModel.swift
- HardeningTests.swift
- Decision: visual direction re-affirmed — Living Companion
- Requirement: Accessibility alternates on every companion surface
- Requirement: Accessibility alternates on every companion surface
- scripts
- Run Brief
- Praxmodoro — approve the base visual direction
- PackageDescription
- ModuleIsolationTests.swift
- PraxmodoroCoreTests/ModuleTests.swift
- AppSmokeTests.swift
- OneProductContractTests.swift
- Praxmodoro
- smoke.sh
- triage-labels.md
- praxmodoro-decision-checkpoint.md
- Executive Summary
- Wave 1: w1-user-friction
- Wave 1: w1-adhd-research
- Wave 1: w1-macos-visual-tech
- Wave 2: w2-breaks-adhd-falsification
- Wave 2: w2-platform-feasibility
- Wave 2: w2-effects-dependency-audit
- Wave 2: w2-product-scope-adjudication
- Overview
- Wave 1: w1-user-friction
- Wave 1: w1-adhd-research
- Wave 1: w1-macos-visual-tech
- Wave 2: w2-breaks-adhd-falsification
- Wave 2: w2-platform-feasibility
- Wave 2: w2-effects-dependency-audit
- Wave 2: w2-product-scope-adjudication
- merge-w1-adhd-research.md
- merge-w1-competitor-official.md
- merge-w1-macos-visual-tech.md
- merge-w1-user-friction.md
- merge-w2-breaks-adhd-falsification.md
- merge-w2-effects-dependency-audit.md
- merge-w2-platform-feasibility.md
- merge-w2-product-scope-adjudication.md
- focused.sh
- generate.sh
- run.sh
- verify-project.sh

## God Nodes (most connected - your core abstractions)
1. `AppModel` - 148 edges
2. `LocalStore` - 66 edges
3. `Session` - 63 edges
4. `Testing` - 50 edges
5. `Praxodoro Adhd-Aware Macos Focus Coach, Premium Pomodoro Landscape, Liquid-Glass Skeuomorphic Ux, And Implementation Feasibility` - 49 edges
6. `SoundCue` - 38 edges
7. `FocusCapsule` - 34 edges
8. `PraxmodoroStore` - 32 edges
9. `MenuBarPopover` - 32 edges
10. `TimingPolicy` - 31 edges

## Surprising Connections (you probably didn't know these)
- `1. Engine: custom policies and cadence (Core)` --references--> `TimingPolicy`  [INFERRED]
  openspec/changes/archive/2026-08-26-add-session-settings/tasks.md → app/Packages/PraxmodoroCore/Sources/PraxmodoroCore/TimingPolicy.swift
- `NOT in scope` --references--> `AppModel`  [INFERRED]
  docs/plans/2026-08-23-architecture-stabilization.md → app/Sources/AppModel.swift
- `Alternative A: Inline patch` --references--> `AppModel`  [INFERRED]
  docs/plans/2026-08-23-runtime-contract-foundation.md → app/Sources/AppModel.swift
- `Alternative C: Controller decomposition` --references--> `AppModel`  [INFERRED]
  docs/plans/2026-08-23-runtime-contract-foundation.md → app/Sources/AppModel.swift
- `Approach C: App architecture rewrite` --references--> `AppModel`  [INFERRED]
  openspec/changes/archive/2026-08-26-stabilize-runtime-contracts/design.md → app/Sources/AppModel.swift

## Import Cycles
- None detected.

## Communities (168 total, 51 thin omitted)

### Community 0 - ".begin"
Cohesion: 0.06
Nodes (9): .companionActions, NotificationDirectorTests, PulseWiringTests, SoundDirectorTests, Ticker, NotificationRecorder, Ticker, ValidatorFindingsTests (+1 more)

### Community 1 - "SettingsSceneTests"
Cohesion: 0.08
Nodes (6): Pixel, .luminance, RenderAccessibilityTests, .fixedDisplay, SettingsSceneTests, 3. Surface palette and render-level accessibility

### Community 2 - "AppModel"
Cohesion: 0.08
Nodes (20): AppModel, .breakSuggestion, .breakSuggestionProvenance, .isHeld, .longBreakMinutesDueNow, .motionToggleLabel, .reentryStep, .reviewInsight (+12 more)

### Community 3 - "PreferencesTests"
Cohesion: 0.06
Nodes (9): LocalNotificationRequest, LocalNotificationScheduler, NotificationAvailability, available, denied, NotificationScheduling, NotificationRecorder, PreferencesTests (+1 more)

### Community 4 - "Session"
Cohesion: 0.11
Nodes (13): Session, .adjustments, .anomalies, AdjustmentTests, BlockScopedRemainingTests, BlockEndBehaviourFindingsTests, HoldResumeTests, SessionReconstructionTests (+5 more)

### Community 5 - "companion-physics.js"
Cohesion: 0.06
Nodes (33): Dark, DesignTokens, Duration, Light, Radius, Spacing, active(), breathValue() (+25 more)

### Community 6 - "Requirement: Autostart behaviour is the user's choice"
Cohesion: 0.04
Nodes (45): Purpose, Requirement: Autostart behaviour is the user's choice, Requirement: Custom rhythm durations, Requirement: Local notifications with honest text, Requirement: Rewind and forward as recorded adjustments, Requirement: Settings accessibility alternates are complete, Requirement: Settings scene, Requirement: Settings ship in the one product (+37 more)

### Community 7 - "ADDED Requirements"
Cohesion: 0.04
Nodes (44): ADDED Requirements, Requirement: Autostart behaviour is the user's choice, Requirement: Custom rhythm durations, Requirement: Local notifications with honest text, Requirement: Rewind and forward as recorded adjustments, Requirement: Settings accessibility alternates are complete, Requirement: Settings scene, Requirement: Settings ship in the one product (+36 more)

### Community 8 - "RhythmPreferences"
Cohesion: 0.07
Nodes (28): CodingKeys, blockStart, breakEndChime, breakTick, focusEndChime, focusTick, masterVolume, tickLoop (+20 more)

### Community 9 - "Equatable"
Cohesion: 0.09
Nodes (28): AdjustmentRecord, SessionError, invalidAdjustment, invalidTransition, SessionIntent, begin, close, endBreak (+20 more)

### Community 10 - "Praxodoro Adhd-Aware Macos Focus Coach, Premium Pomodoro Landscape, Liquid-Glass Skeuomorphic Ux, And Implementation Feasibility"
Cohesion: 0.05
Nodes (40): Claim and Evidence Register, Comparisons, Contradictions, Contradictions, Contradictions, Contradictions, Coverage Summary, Findings (+32 more)

### Community 11 - "KeyboardLoopUITests"
Cohesion: 0.11
Nodes (12): Approved architecture closeout session, Audit log, Fixed scope and acceptance criteria, Live baseline, Skills loaded, User authorization, KeyboardLoopUITests, XCUIElement (+4 more)

### Community 12 - "CompanionSurfaceTests"
Cohesion: 0.12
Nodes (4): CompanionSurfaceTests, PureSurfaces, .strings, 4. Menu-bar popover

### Community 13 - "RhythmPane"
Cohesion: 0.11
Nodes (12): RhythmPane, .autoReturn, .blockEnd, .cadenceBlocks, .cadenceEnabled, .cadenceMinutes, .presetHelp, SettingsSurface (+4 more)

### Community 14 - "Requirement: User-steerable timing policies"
Cohesion: 0.06
Nodes (32): Purpose, Requirement: Break end has one canonical derivation, Requirement: Canonical timestamp arithmetic, Requirement: Engine is UI-free and capability-registry-independent, Requirement: Hold preserves the place, Requirement: Session state machine, Requirement: Sleep, wake, and relaunch recovery, Requirement: User-steerable timing policies (+24 more)

### Community 15 - "Requirements"
Cohesion: 0.06
Nodes (31): focus-loop-ui Specification, Purpose, Requirement: Break with a held place and re-entry card, Requirement: Capability provenance without gated behavior, Requirement: Check-in with no failure state, Requirement: Companion field physics, Requirement: Complete accessibility alternates, Requirement: Focus surface keeps task and time legible (+23 more)

### Community 16 - "SPEC.md — Praxmodoro completion contract"
Cohesion: 0.07
Nodes (26): Agent skills, Domain docs, Git safety, Issue tracker, Praxmodoro agent contract, Product constraints, Skill discovery, Source of truth (+18 more)

### Community 17 - "FocusSurface"
Cohesion: 0.09
Nodes (14): BreakSurface, .checkinResponseText, FocusSurface, .checkinResponseText, .fieldState, .nextActionText, .remainingReadout, .showsBlockEndPrompt (+6 more)

### Community 18 - "ADDED Requirements"
Cohesion: 0.07
Nodes (27): ADDED Requirements, focus-loop-ui, Requirement: Break with a held place and re-entry card, Requirement: Check-in with no failure state, Requirement: Companion field physics, Requirement: Complete accessibility alternates, Requirement: Edition gating seam without gated behavior, Requirement: Focus surface keeps task and time legible (+19 more)

### Community 20 - "View"
Cohesion: 0.14
Nodes (11): AnimatedCompanionField, .body, CompanionFieldView, .body, FieldCanvas, .body, FieldPalette, StaticCompanionField (+3 more)

### Community 21 - "Requirements"
Cohesion: 0.08
Nodes (25): companion-surfaces Specification, Purpose, Requirement: Companion surfaces ship in the one product, Requirement: Floating focus capsule stays above other windows, Requirement: Menu-bar popover operates the loop, Requirement: One canonical session state for every surface, Requirement: Return overlay presents the exact next action, Requirements (+17 more)

### Community 22 - "build-docs.mjs"
Cohesion: 0.11
Nodes (22): BESPOKE, counts, CSS, docs, esc(), groups, index, markdownPaths (+14 more)

### Community 23 - "TimingPolicy"
Cohesion: 0.13
Nodes (7): TimingPolicy, CustomPolicyTests, .availablePolicies, InitiateSurface, .body, .policies, .id

### Community 24 - "Foundation"
Cohesion: 0.21
Nodes (3): Foundation, PraxmodoroCore, Testing

### Community 25 - "ADDED Requirements"
Cohesion: 0.08
Nodes (24): ADDED Requirements, companion-surfaces, Requirement: Companion surfaces ship in the one product, Requirement: Floating focus capsule stays above other windows, Requirement: Menu-bar popover operates the loop, Requirement: One canonical session state for every surface, Requirement: Return overlay presents the exact next action, Scenario: A check-in waits behind the return (+16 more)

### Community 26 - ".running"
Cohesion: 0.13
Nodes (14): BlockEndBehaviourTests, Goals, non-goals, assumptions, Requirement: Lifecycle payloads have one strict app-boundary vocabulary, Scenario: Every transition write uses the vocabulary, Scenario: Known historical payloads remain compatible, Scenario: Synthetic idle cannot be persisted, Scenario: Unknown history remains visible in review, Scenario: Unknown transition is rejected (+6 more)

### Community 27 - "MotionPreferenceTests"
Cohesion: 0.12
Nodes (6): KeyboardMap, AccessibilityTests, CopyToneTests, MotionPreferenceTests, ProvenanceTests, 6. Cross-cutting gates

### Community 28 - "generate-design-tokens.mjs"
Cohesion: 0.10
Nodes (19): clampNotes, colourLines(), dark, darkColours, darkCSS, durationLines, light, lightColours (+11 more)

### Community 29 - ".endBreak"
Cohesion: 0.22
Nodes (4): BreakPhaseControlTests, ReturnOverlayTests, 10. Fresh-validation remediation (2026-08-23), 6. Return overlay

### Community 30 - "Praxodoro Adhd-Aware Macos Focus Coach, Premium Pomodoro Landscape, Liquid-Glass Skeuomorphic Ux, And Implementation Feasibility"
Cohesion: 0.09
Nodes (22): Contradictions, Contradictions, Decision-Relevant Risks, Evidence Register, Key Takeaways, Next-Step Guidance, Next-Step Guidance, Praxodoro Adhd-Aware Macos Focus Coach, Premium Pomodoro Landscape, Liquid-Glass Skeuomorphic Ux, And Implementation Feasibility (+14 more)

### Community 31 - "living-companion/app-mocks.js"
Cohesion: 0.13
Nodes (19): adjustMinutes(), breakMessage, checkinMessage, focusField, focusScreenIsCurrent(), formatTime(), hudCenter, initiateMessage (+11 more)

### Community 32 - ".openCheckin"
Cohesion: 0.13
Nodes (10): CheckinTests, Delivery gate, Failure and test map, Frozen findings, Implementation order, Interaction decisions, M2 fresh-validation remediation plan, Objective (+2 more)

### Community 33 - "SessionReplay"
Cohesion: 0.18
Nodes (12): Result, SessionReplay, SessionReplayError, invalidAdjustmentPayload, unknownTransitionPayload, unsupportedTransitionState, TransitionPayload, 1. The app target owns payload translation (+4 more)

### Community 34 - "ADDED Requirements"
Cohesion: 0.10
Nodes (19): ADDED Requirements, Requirement: Canonical timestamp arithmetic, Requirement: Engine is UI-free and edition-free, Requirement: Hold preserves the place, Requirement: Session state machine, Requirement: Sleep, wake, and relaunch recovery, Requirement: User-steerable timing policies, Scenario: App relaunch during a held session (+11 more)

### Community 35 - "Requirements"
Cohesion: 0.10
Nodes (19): app-scaffold Specification, Purpose, Requirement: App lifecycle restores state, Requirement: Capability provenance registry, Requirement: Deterministic build provenance, Requirement: Documented build and test commands, Requirement: No hidden cloud dependency, Requirement: Reproducible project generation (+11 more)

### Community 36 - "export-field-goldens.mjs"
Cohesion: 0.11
Nodes (10): breathSamples, driftSamples, golden, here, out, physics, require, springs (+2 more)

### Community 37 - ".beginNextSession"
Cohesion: 0.12
Nodes (15): ReviewSurface, .body, Phase 4: Surface intent boundary (#53), 5. Surfaces express intents, ADDED Requirements, Requirement: Surfaces express routing intents through the model, Scenario: Begin another session from review, Scenario: Direct routing writes are structurally rejected (+7 more)

### Community 38 - "AudioCueScheduler"
Cohesion: 0.18
Nodes (3): AudioCueScheduler, SoundCueScheduling, 10. Fresh-validation and owner-decision remediation (2026-08-23)

### Community 39 - "MenuBarPopover"
Cohesion: 0.15
Nodes (10): CompanionActions, MenuBarPopover, .accessibilityLabel, .body, .controls, .motionStilled, .primaryControlLabel, .statusText (+2 more)

### Community 40 - "Architecture stabilization and milestone close-out plan"
Cohesion: 0.11
Nodes (18): Architecture stabilization and milestone close-out plan, Commit and archive protocol, Design-complete interaction decisions, Error and recovery contract, GSTACK REVIEW REPORT, Implementation tickets, Lane A — M2 compliance repairs, Lane B — `add-session-settings` contract and validation repairs (+10 more)

### Community 41 - "Requirements"
Cohesion: 0.11
Nodes (18): Purpose, Requirement: Configuration-neutral storage, Requirement: Data minimization, Requirement: Event log is append-only, Requirement: Local SwiftData models, Requirement: No network, no account, Requirement: Store corruption degrades gracefully, Requirements (+10 more)

### Community 42 - "LifecycleTests"
Cohesion: 0.19
Nodes (3): LifecycleTests, ModelState, ReplayFixture

### Community 43 - "focus-observatory/app-mocks.js"
Cohesion: 0.12
Nodes (15): barNote, barTimer, checkinMessage, formatTime(), initiateMessage, meterFill, screenButtons, screenMeta (+7 more)

### Community 44 - "Runtime contract foundation implementation plan"
Cohesion: 0.11
Nodes (17): Alternative A: Inline patch, Alternative B: Narrow contracts (selected), Alternative C: Controller decomposition, Architecture after the change, Error and recovery map, GSTACK REVIEW REPORT, Implementation order, Objective (+9 more)

### Community 45 - "ADDED Requirements"
Cohesion: 0.11
Nodes (17): ADDED Requirements, app-scaffold, Requirement: App lifecycle restores state, Requirement: Deterministic versioning and provenance, Requirement: Documented build and test commands, Requirement: Edition capability registry, Requirement: No hidden cloud dependency, Requirement: Reproducible project generation (+9 more)

### Community 46 - "Global Synthesis"
Cohesion: 0.11
Nodes (17): Claims, Claims, Claims, Claims, Claims, Claims, Claims, Claims (+9 more)

### Community 47 - "FieldPhysics"
Cohesion: 0.15
Nodes (13): PraxmodoroCore, PraxmodoroStore, FieldPhysics, Frozen evidence, Context, Decisions, Design: add-app-scaffold-core-loop, Goals / Non-Goals (+5 more)

### Community 48 - "LocalStore"
Cohesion: 0.15
Nodes (6): LocalStore, .containerSchema, .schema, SessionSummary, HardeningTests, InitiateSurfaceTests

### Community 49 - "PraxmodoroStore"
Cohesion: 0.17
Nodes (3): ReviewTests, Praxmodoro, PraxmodoroStore

### Community 50 - "DesignTokenParityTests"
Cohesion: 0.25
Nodes (5): DarkMock, DesignTokenParityTests, LightMock, OKLCHToken, RGB

### Community 51 - "StoredEventKind"
Cohesion: 0.14
Nodes (13): StoredEvent, StoredEventKind, adjustment, breakChoice, capacityReport, checkinAnswer, clockAnomaly, edit (+5 more)

### Community 52 - "String"
Cohesion: 0.38
Nodes (4): CapacityReportModel, SessionEventModel, SessionRecordModel, TaskRecordModel

### Community 53 - "SwiftUI"
Cohesion: 0.13
Nodes (3): AppKit, CoreGraphics, SwiftUI

### Community 54 - "ReturnOverlay"
Cohesion: 0.18
Nodes (7): ReturnOverlay, .accessibilityLabel, .body, .motionStilled, .wayBack, CompanionAccessibilityTests, 7. Reduce Motion and VoiceOver on the new surfaces

### Community 56 - "hallmark/app-mocks.js"
Cohesion: 0.14
Nodes (13): checkinMessage, formatTime(), hudCenter, initiateMessage, screenButtons, screenMeta, screens, shell (+5 more)

### Community 57 - "ADDED Requirements"
Cohesion: 0.12
Nodes (15): ADDED Requirements, Requirement: Data minimization, Requirement: Edition-neutral storage, Requirement: Event log is append-only, Requirement: Local SwiftData models, Requirement: No network, no account, Requirement: Store corruption degrades gracefully, Scenario: A session round-trips completely (+7 more)

### Community 58 - "app-scaffold"
Cohesion: 0.12
Nodes (15): ADDED Requirements, app-scaffold, MODIFIED Requirements, REMOVED Requirements, Requirement: App lifecycle restores state, Requirement: Capability provenance registry, Requirement: Deterministic build provenance, Requirement: Deterministic versioning and provenance (+7 more)

### Community 59 - "FeatureKey"
Cohesion: 0.13
Nodes (15): FeatureKey, accessibilityModes, adaptiveBreaks, checkins, focusCapsule, focusLoop, initiation, localReview (+7 more)

### Community 60 - "add-session-settings fresh-validation remediation plan"
Cohesion: 0.13
Nodes (12): shouldRetainChime(), AVFoundation, add-session-settings fresh-validation remediation plan, Delivery gate, Failure map, Interaction-state table, Objective, Required repairs (+4 more)

### Community 61 - "Tasks: add-companion-surfaces"
Cohesion: 0.18
Nodes (6): SnapshotTests, 11. Remediation close-out, 1. Verification commands, 2. One canonical session state, 9. Close-out, Tasks: add-companion-surfaces

### Community 62 - "Requirement: Complete accessibility alternates"
Cohesion: 0.13
Nodes (14): ADDED Requirements, focus-loop-ui, MODIFIED Requirements, REMOVED Requirements, Requirement: Capability provenance without gated behavior, Requirement: Complete accessibility alternates, Requirement: Edition gating seam without gated behavior, Scenario: Full keyboard loop (+6 more)

### Community 63 - "Findings"
Cohesion: 0.13
Nodes (14): Contradictions, Current Synthesis, Findings, Next-Step Guidance, Strong Evidence, Wave 1: w1-adhd-research, Wave 1: w1-competitor-official, Wave 1: w1-macos-visual-tech (+6 more)

### Community 64 - "Open Questions"
Cohesion: 0.13
Nodes (14): Contradictions, Current Synthesis, Next-Step Guidance, Open Questions, Strong Evidence, Wave 1: w1-adhd-research, Wave 1: w1-competitor-official, Wave 1: w1-macos-visual-tech (+6 more)

### Community 66 - "CapabilityRegistry"
Cohesion: 0.24
Nodes (4): CapabilityRegistry, ValidationError, CapabilityTests, SessionSettingsRegistryTests

### Community 67 - "FieldModel"
Cohesion: 0.31
Nodes (3): FieldModel, CompanionFieldTests, FieldRendererSmokeTests

### Community 68 - ".restore"
Cohesion: 0.17
Nodes (7): ValidatorGapTests, Requirement: Store-to-Core replay is pure and deterministic, Scenario: Closed history remains truthful, Scenario: Failed replay is atomic, Scenario: Malformed adjustment is rejected, Scenario: Optional task is absent, Scenario: Replay ordering is deterministic

### Community 69 - "Double"
Cohesion: 0.27
Nodes (5): FieldBreath, FieldLayerSpec, FieldSpring, FieldStateParams, .hasKeyboardFocus

### Community 70 - "SessionSnapshot"
Cohesion: 0.24
Nodes (7): CompanionDisplay, .hasSession, SessionSnapshot, .display, .hasSession, Verified architecture, Decisions

### Community 72 - "package.json"
Cohesion: 0.15
Nodes (12): description, devDependencies, @fission-ai/openspec, marked, engines, node, name, packageManager (+4 more)

### Community 73 - ".modelOnBreak"
Cohesion: 0.26
Nodes (3): BreakTests, FocusSurfaceTests, 5. Core loop surfaces

### Community 74 - "Design: stabilize-runtime-contracts"
Cohesion: 0.17
Nodes (11): Approach A: Local substitutions, Approach B: Narrow runtime contracts (selected), Approach C: App architecture rewrite, Approaches considered, Context, Data boundaries, Design: stabilize-runtime-contracts, Error contract (+3 more)

### Community 75 - "RecoveryNotice"
Cohesion: 0.22
Nodes (3): Verified architecture findings, RecoveryNotice, StoreRecoveryTests

### Community 76 - "3. Persistence (PraxmodoroStore)"
Cohesion: 0.22
Nodes (6): StoreAuditTests, .sourceFiles, StoreRoundTripTests, 1. Scaffold, 3. Persistence (PraxmodoroStore), Tasks: add-app-scaffold-core-loop

### Community 77 - "FocusCapsule"
Cohesion: 0.20
Nodes (7): FocusCapsule, .controls, .motionStilled, .offersHold, .statusText, .taskText, .timeText

### Community 79 - "openspec-explore/SKILL.md"
Cohesion: 0.18
Nodes (10): Check for context, Ending Discovery, Guardrails, Handling Different Entry Points, OpenSpec Awareness, The Stance, What You Don't Have To Do, What You Might Do (+2 more)

### Community 80 - "Praxmodoro Hallmark Mock Dossier"
Cohesion: 0.18
Nodes (8): A. Liquid Instrument — recommended and mocked, Approval boundary, B. Living Companion, C. Focus Observatory, Hallmark assessment, Interaction coverage, Praxmodoro Hallmark Mock Dossier, Three product and visual approaches

### Community 81 - "Requirement: User-steerable timing policies"
Cohesion: 0.18
Nodes (10): MODIFIED Requirements, Requirement: User-steerable timing policies, Scenario: Adjustment is a first-class transition, Scenario: Auto-return records at the canonical break-end instant, Scenario: Autostart records at the canonical instant, Scenario: Custom policy is pure data, Scenario: Flow policy has no forced end, Scenario: Gentle start promotes without judgment (+2 more)

### Community 83 - "SoundCue"
Cohesion: 0.24
Nodes (7): SoundCue, blockStart, breakEnd, breakTick, focusEnd, focusTick, .resourceName

### Community 84 - "CheckinAnswer"
Cohesion: 0.20
Nodes (8): CheckinAnswer, .detail, drifted, .label, needBreak, .response, smallerStep, stillFits

### Community 85 - "Design: add-companion-surfaces"
Cohesion: 0.22
Nodes (7): NetworkSilenceTests, Data boundaries, Dependency provenance, Design: add-companion-surfaces, Goals / Non-Goals, Rollback, Verification strategy

### Community 86 - "Praxmodoro approved backlog: direct DMG release"
Cohesion: 0.22
Nodes (8): 01 — Merged baseline, 02 — Distribution method, 03 — Approved direct-DMG release lane, 04 — Approved open product backlog, 05 — Approved UI and UX improvements, 06 — Approval gate, Decisions (applied 2026-08-31T01:53:58.793Z · export `01M1AQV3FS2BFBZR1BCQ3E6FER`), Praxmodoro approved backlog: direct DMG release

### Community 87 - "Proposal: add-app-scaffold-core-loop"
Cohesion: 0.22
Nodes (8): Capabilities, Goals, non-goals, assumptions, Impact, Modified Capabilities, New Capabilities, Proposal: add-app-scaffold-core-loop, What Changes, Why

### Community 88 - "Requirement: Break end has one canonical derivation"
Cohesion: 0.22
Nodes (8): ADDED Requirements, Requirement: Break end has one canonical derivation, Scenario: Auto-return honors the process-live boundary, Scenario: Auto-return is an explicit gate, not a duration, Scenario: Every consumer agrees, Scenario: Long-break cadence boundary, Scenario: No active break, Scenario: Ordinary break end

### Community 89 - "Praxmodoro — every open blocker, one shot"
Cohesion: 0.22
Nodes (8): 00 / CARRIED FORWARD — Unresolved from previous docs, Decisions (applied 2026-08-12T13:41:39.963Z · export `01KZTPM2DDFA8Q5ZM76ES0JXEJ`), Design execution (lane 2), Operations, Praxmodoro — every open blocker, one shot, Sound & notifications, The gate, Timer rhythm

### Community 90 - "Praxodoro autonomous bootstrap session"
Cohesion: 0.25
Nodes (7): Bootstrap discovery, Phase gates, Praxodoro autonomous bootstrap session, Prior approved context, Skills loaded, Task verbatim, Tool calls and outcomes

### Community 91 - "Issue tracker: GitHub"
Cohesion: 0.25
Nodes (6): Conventions, Issue tracker: GitHub, Pull requests as a triage surface, Wayfinding operations, When a skill says "fetch the relevant ticket", When a skill says "publish to the issue tracker"

### Community 93 - "Complete mocked flow"
Cohesion: 0.25
Nodes (8): 1. Initiate, 2. Focus, 3. Coach check-in, 4. Adaptive break, 5. Review, 6. Settings, 7. Native Mac surfaces, Complete mocked flow

### Community 94 - "Enterprise-grade pass: CEO review plan"
Cohesion: 0.25
Nodes (7): Accepted scope (filed as tickets, ready-for-agent), Approaches considered, Deferred to future (not forgotten), Enterprise-grade pass: CEO review plan, Existing-code leverage (audit finding), Premise challenge, Verified non-problems (checked, not assumed)

### Community 95 - "Proposal: add-companion-surfaces"
Cohesion: 0.25
Nodes (7): Capabilities, Goals, non-goals, assumptions, Modified Capabilities, New Capabilities, Proposal: add-companion-surfaces, What Changes, Why

### Community 96 - "Requirement: Configuration-neutral storage"
Cohesion: 0.25
Nodes (7): MODIFIED Requirements, RENAMED Requirements, Requirement: Configuration-neutral storage, Scenario: No tier-shaped field, Scenario: Schema parity, Scenario: Two-configuration parity against live containers, session-persistence

### Community 97 - "Design: add-session-settings"
Cohesion: 0.25
Nodes (7): Context, Data boundaries, Dependency provenance, Design: add-session-settings, Goals / Non-Goals, Rollback, Verification strategy

### Community 98 - "Requirement: Store-to-Core replay is pure and deterministic"
Cohesion: 0.25
Nodes (7): ADDED Requirements, Requirement: Store-to-Core replay is pure and deterministic, Scenario: Closed history remains truthful, Scenario: Failed replay is atomic, Scenario: Malformed adjustment is rejected, Scenario: Optional task is absent, Scenario: Replay ordering is deterministic

### Community 99 - "Research Plan"
Cohesion: 0.25
Nodes (7): Mission, Questions, Research Plan, Shard Strategy, Source Priorities, Stop Conditions, Wave Strategy

### Community 100 - "Session: M3 closeout — add-session-settings (2026-08-21)"
Cohesion: 0.29
Nodes (6): Bootstrap, Parked atoms (physical/operator-impossibility), Session: M3 closeout — add-session-settings (2026-08-21), Skill setup results, Task verbatim, Work category (Q3)

### Community 101 - "Architecture review session"
Cohesion: 0.29
Nodes (6): Architecture review session, Binding constraints, Current gate, Frozen baseline evidence, Skill discovery, Timeline

### Community 102 - ".primaryText"
Cohesion: 0.43
Nodes (3): .accessibilityLabel, .body, .body

### Community 105 - "Proposal: stabilize-runtime-contracts"
Cohesion: 0.29
Nodes (6): Capabilities, Modified Capabilities, New Capabilities, Proposal: stabilize-runtime-contracts, What Changes, Why

### Community 106 - "Praxmodoro approved backlog and direct-DMG guide"
Cohesion: 0.29
Nodes (6): Apply an offline decision export, Approved UI and UX improvements, Direct-DMG build and publication sequence, Install Praxmodoro from the final direct DMG, Launch the DecisionCanvas HTML, Praxmodoro approved backlog and direct-DMG guide

### Community 107 - "Praxmodoro"
Cohesion: 0.29
Nodes (6): Current state, Native app commands, One product, Praxmodoro, Repository map, Specification commands

### Community 108 - "Source Digest"
Cohesion: 0.29
Nodes (7): community, interview, official-docs, paper, repo, Source Digest, video

### Community 109 - "Sources"
Cohesion: 0.29
Nodes (7): community, interview, official-docs, paper, repo, Sources, video

### Community 110 - "Wave 1 Plan"
Cohesion: 0.29
Nodes (6): Active Shards, Expected Gaps To Resolve, Objective, Success Condition, Wave 1 Plan, Worker Assignments

### Community 111 - "Comparisons"
Cohesion: 0.29
Nodes (6): Comparisons, Contradictions, Current Synthesis, Next-Step Guidance, Strong Evidence, Weak Evidence Or Gaps

### Community 112 - "Methods"
Cohesion: 0.29
Nodes (6): Contradictions, Current Synthesis, Methods, Next-Step Guidance, Strong Evidence, Weak Evidence Or Gaps

### Community 113 - "Overview"
Cohesion: 0.29
Nodes (6): Contradictions, Current Synthesis, Next-Step Guidance, Overview, Strong Evidence, Weak Evidence Or Gaps

### Community 114 - "Surface"
Cohesion: 0.33
Nodes (6): Surface, checkin, focus, initiate, onBreak, review

### Community 115 - "Provenance"
Cohesion: 0.33
Nodes (4): AboutView, .body, Provenance, .aboutText

### Community 117 - "Domain Docs"
Cohesion: 0.33
Nodes (5): Before exploring, read these, Domain Docs, File structure, Flag ADR conflicts, Use the glossary's vocabulary

### Community 118 - "Plan: settings & rhythm parity — proposed change `add-session-settings`"
Cohesion: 0.33
Nodes (5): GSTACK REVIEW REPORT, Plan: settings & rhythm parity — proposed change `add-session-settings`, Risks / open questions for review, The gap, measured, Where our invariants bend RoundPie's shape

### Community 119 - "timer-engine"
Cohesion: 0.33
Nodes (5): MODIFIED Requirements, RENAMED Requirements, Requirement: Engine is UI-free and capability-registry-independent, Scenario: Module isolation is testable, timer-engine

### Community 120 - "Wave 2 Plan"
Cohesion: 0.33
Nodes (5): Falsification Questions, Objective, Success Condition, Verification Shards, Wave 2 Plan

### Community 125 - "Decision: visual direction re-affirmed — Living Companion"
Cohesion: 0.40
Nodes (4): Decision: visual direction re-affirmed — Living Companion, Raw export, The decision, What this decision means, precisely

### Community 126 - "Requirement: Accessibility alternates on every companion surface"
Cohesion: 0.40
Nodes (5): Requirement: Accessibility alternates on every companion surface, Scenario: Increase Contrast raises the measured ratio, Scenario: Reduce Motion standdown on the new surfaces, Scenario: Reduce Transparency renders opaque, Scenario: VoiceOver reads each companion surface

### Community 127 - "Requirement: Accessibility alternates on every companion surface"
Cohesion: 0.40
Nodes (5): Requirement: Accessibility alternates on every companion surface, Scenario: Increase Contrast raises the measured ratio, Scenario: Reduce Motion standdown on the new surfaces, Scenario: Reduce Transparency renders opaque, Scenario: VoiceOver reads each companion surface

### Community 128 - "scripts"
Cohesion: 0.40
Nodes (5): scripts, docs:build, spec:list, spec:validate, tokens:build

### Community 129 - "Run Brief"
Cohesion: 0.40
Nodes (4): Notes, Run Brief, Seed Sources, Top-Level Questions

### Community 130 - "Praxmodoro — approve the base visual direction"
Cohesion: 0.50
Nodes (3): Base visual direction, Next step after approval, Praxmodoro — approve the base visual direction

## Knowledge Gaps
- **814 isolated node(s):** `idle`, `running`, `held`, `onBreak`, `closed` (+809 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1032 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **51 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AppModel` connect `AppModel` to `.begin`, `SettingsSceneTests`, `PreferencesTests`, `Session`, `RhythmPreferences`, `KeyboardLoopUITests`, `CompanionSurfaceTests`, `RhythmPane`, `FocusSurface`, `.snapshot`, `TimingPolicy`, `.running`, `MotionPreferenceTests`, `.endBreak`, `.openCheckin`, `SessionReplay`, `.beginNextSession`, `AudioCueScheduler`, `Architecture stabilization and milestone close-out plan`, `Runtime contract foundation implementation plan`, `FieldPhysics`, `LocalStore`, `Tasks: add-companion-surfaces`, `CapabilityRegistry`, `FieldModel`, `.restore`, `SessionSnapshot`, `.modelOnBreak`, `Design: stabilize-runtime-contracts`, `RecoveryNotice`, `Decisions`, `SoundCue`, `FocusCapsuleTests`, `Proposal: stabilize-runtime-contracts`, `Surface`, `AppModel.swift`, `.sentinelModel`?**
  _High betweenness centrality (0.267) - this node is a cross-community bridge._
- **Why does `SurfacePalette` connect `RhythmPreferences` to `SettingsSceneTests`, `companion-physics.js`, `SessionSnapshot`, `.primaryText`, `ADDED Requirements`, `Requirement: Autostart behaviour is the user's choice`, `Requirements`, `Decisions`, `SwiftUI`, `add-session-settings fresh-validation remediation plan`, `Requirement: Complete accessibility alternates`, `Proposal: add-companion-surfaces`?**
  _High betweenness centrality (0.072) - this node is a cross-community bridge._
- **Why does `Session` connect `Session` to `LongBreakCadence`, `AppModel`, `SessionReplay`, `Equatable`, `LifecycleTests`, `Design: stabilize-runtime-contracts`, `3. Persistence (PraxmodoroStore)`, `FieldPhysics`, `Decisions`, `TimingPolicy`, `.running`?**
  _High betweenness centrality (0.064) - this node is a cross-community bridge._
- **Are the 43 inferred relationships involving `AppModel` (e.g. with `Verified architecture findings` and `Audit log`) actually correct?**
  _`AppModel` has 43 INFERRED edges - model-reasoned connections that need verification._
- **Are the 43 inferred relationships involving `LocalStore` (e.g. with `.testEditCreatesReferencingEventNotMutation()` and `.testFullSessionRoundTrip()`) actually correct?**
  _`LocalStore` has 43 INFERRED edges - model-reasoned connections that need verification._
- **Are the 27 inferred relationships involving `Session` (e.g. with `.testAdjustmentRejectedAfterExpiry()` and `.testAdjustmentRejectedWhenNotRunning()`) actually correct?**
  _`Session` has 27 INFERRED edges - model-reasoned connections that need verification._
- **What connects `idle`, `running`, `held` to the rest of the system?**
  _814 weakly-connected nodes found - possible documentation gaps or missing edges._