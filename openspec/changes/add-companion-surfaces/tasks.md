# Tasks: add-companion-surfaces

Every task follows AGENTS.md TDD law: write the named failing test, observe the expected red, implement minimally, verify green plus the smoke command, commit conventionally with only the slice's files. Every completed group leaves the repo runnable. Per-atom check: `./scripts/focused.sh`.

## 1. Verification commands

- [ ] 1.1 Add `scripts/focused.sh` (app unit suite only) and `scripts/smoke.sh` (build, launch with `-praxmodoro-ephemeral-store`, confirm the window, quit); document both in README next to the existing commands. Red: both scripts absent, `./scripts/focused.sh` exits 127. Green: both exit 0 and the README commands run verbatim. Files: `scripts/focused.sh`, `scripts/smoke.sh`, `README.md`.

## 2. One canonical session state

- [ ] 2.1 `SessionSnapshot` value + `AppModel.snapshot(at:)` projecting phase, task line, next action, remaining interval, remaining text, status line and VoiceOver summary; migrate `FocusSurface` and `fieldAccessibilitySummary(at:)` onto it. Red: `SnapshotTests.testSnapshotDerivesRemainingFromTransitions`, `testSnapshotOpenEndedBlockHasNoRemaining` (no `SessionSnapshot` type — compile failure). Green: both pass and every M1 test still passes. Files: `app/Sources/SessionSnapshot.swift`, `app/Sources/AppModel.swift`, `app/Sources/Surfaces/FocusSurface.swift`, `app/Tests/PraxmodoroTests/SnapshotTests.swift`.
- [ ] 2.2 Structural single-clock gate. Red: `SnapshotTests.testNoSurfaceCountsTime` fails while any surface formats remaining time locally. Green: the scan finds no `Timer(`, `Timer.publish`, `scheduledTimer`, or stored elapsed counter in `app/Sources`, and every rendered remaining time comes from `snapshot(at:)`. Files: `app/Tests/PraxmodoroTests/SnapshotTests.swift`.
- [ ] 2.3 Sleep/relaunch snapshot fidelity. Red: `SnapshotTests.testSnapshotAfterSleepHasNoDrift` before the snapshot routes through `reconciled(at:)`. Green: snapshot remaining equals the canonical-timestamp value across a simulated multi-hour gap. Files: `app/Tests/PraxmodoroTests/SnapshotTests.swift`.

## 3. Surface palette and render-level accessibility

- [ ] 3.1 `SurfacePalette` with an explicit Reduce Transparency background branch and an Increase Contrast primary-text branch. Red: `RenderAccessibilityTests.testReduceTransparencyBackgroundIsOpaque` (no `SurfacePalette`). Green: rasterizing the background over a red backdrop with Reduce Transparency on shows no backdrop trace, and differs from the same background with it off. Files: `app/Sources/SurfacePalette.swift`, `app/Tests/PraxmodoroTests/RenderAccessibilityTests.swift`.
- [ ] 3.2 Render-level contrast measurement. Red: `RenderAccessibilityTests.testIncreaseContrastRaisesMeasuredRatio`. Green: WCAG ratio computed from rasterized pixels is ≥ 4.5:1 standard and strictly greater under increased contrast. Files: `app/Tests/PraxmodoroTests/RenderAccessibilityTests.swift`.

## 4. Menu-bar popover

- [ ] 4.1 `MenuBarPopover` view + `MenuBarExtra` scene rendering the snapshot with phase-appropriate controls. Red: `CompanionSurfaceTests.testPopoverShowsHeldStateAndOffersResume`, `testPopoverWithoutSessionOffersBeginAndNoTime`. Green: both pass. Files: `app/Sources/Surfaces/MenuBarPopover.swift`, `app/Sources/PraxmodoroApp.swift`, `app/Tests/PraxmodoroTests/CompanionSurfaceTests.swift`.
- [ ] 4.2 Popover non-scoring and never-paywalled guarantees. Red: `CompanionSurfaceTests.testPopoverCarriesNoScoringOrUpsell`, `testCompanionSurfaceKeysAreNeverPaywalled`. Green: both pass; new feature keys join the never-paywalled set and registry validation covers them. Files: `app/Sources/CapabilityRegistry.swift`, `app/Tests/PraxmodoroTests/CompanionSurfaceTests.swift`.

## 5. Floating focus capsule

- [ ] 5.1 `FocusCapsule` view + floating `Window` scene, launch-suppressed, with the capsule command and its keyboard shortcut. Red: `CompanionSurfaceTests.testCapsuleRendersSameTextAsFocusSurface`, `testCapsuleCommandHasKeyboardPath`. Green: both pass. Files: `app/Sources/Surfaces/FocusCapsule.swift`, `app/Sources/PraxmodoroApp.swift`, `app/Sources/KeyboardMap.swift`, `app/Tests/PraxmodoroTests/CompanionSurfaceTests.swift`.
- [ ] 5.2 Three-surface agreement at one instant. Red: `CompanionSurfaceTests.testThreeSurfacesAgreeAtOneInstant`. Green: focus, popover, and capsule render identical remaining text, task line, and status line. Files: `app/Tests/PraxmodoroTests/CompanionSurfaceTests.swift`.

## 6. Return overlay

- [ ] 6.1 `AppModel.returnPending` / `acknowledgeReturn()` raised by `endBreak()`. Red: `ReturnOverlayTests.testEndingBreakRaisesReturnOverlay`, `testAcknowledgementLeavesPhaseUnchanged`. Green: both pass. Files: `app/Sources/AppModel.swift`, `app/Tests/PraxmodoroTests/ReturnOverlayTests.swift`.
- [ ] 6.2 `ReturnOverlay` view over the focus surface: exact next action, task fallback, ⏎ dismissal, no evaluation copy. Red: `ReturnOverlayTests.testOverlayShowsRecordedNextAction`, `testOverlayFallsBackToTaskWhenNoNextAction`, `testOverlayCarriesNoBreakVerdict`. Green: all pass. Files: `app/Sources/Surfaces/ReturnOverlay.swift`, `app/Sources/PraxmodoroApp.swift`, `app/Tests/PraxmodoroTests/ReturnOverlayTests.swift`.

## 7. Reduce Motion and VoiceOver on the new surfaces

- [ ] 7.1 Motion standdown and VoiceOver labels for popover, capsule, and overlay. Red: `CompanionSurfaceTests.testCompanionSurfacesStandDownUnderReduceMotion`, `testCompanionSurfacesCarryVoiceOverLabels`. Green: the physics model is nil on every companion surface under Reduce Motion and each surface exposes a concise label naming the surface and state. Files: `app/Sources/Surfaces/MenuBarPopover.swift`, `app/Sources/Surfaces/FocusCapsule.swift`, `app/Sources/Surfaces/ReturnOverlay.swift`, `app/Tests/PraxmodoroTests/CompanionSurfaceTests.swift`.

## 8. Hardening follow-ups from the M1 closeout

- [ ] 8.1 User-initiated check-in (⌘K) routed through `openCheckin()`. Red: `HardeningTests.testCheckinHasItsOwnKeyboardPath`. Green: the keyboard map and the command both carry it and the timer-held invariant is unchanged. Files: `app/Sources/KeyboardMap.swift`, `app/Sources/PraxmodoroApp.swift`, `app/Tests/PraxmodoroTests/HardeningTests.swift`.
- [ ] 8.2 Two-configuration schema parity against live containers. Red: `HardeningTests.testSchemaParityAcrossStoreConfigurations` (no `containerSchema`). Green: in-memory and on-disk containers expose identical entity names, attribute names, and attribute value types. Files: `app/Packages/PraxmodoroStore/Sources/PraxmodoroStore/LocalStore.swift`, `app/Tests/PraxmodoroTests/HardeningTests.swift`.
- [ ] 8.3 Keyboard UI coverage as real key events: begin, ⌘K, check-in `1`–`4`, `R`, ⌘N, capsule toggle. Red: `KeyboardLoopUITests.testWholeLoopByKeyboard` before the paths exist. Green: the UI test walks the loop with no pointer interaction. Files: `app/Tests/PraxmodoroUITests/KeyboardLoopUITests.swift`.
- [ ] 8.4 Launch-time first-run assertion. Red: `KeyboardLoopUITests.testFirstRunLaunchPresentsOnlyTheStartPath`. Green: start-path controls present, no running-session control, begin disabled until a task is named, no ambient surface self-opened. Files: `app/Tests/PraxmodoroUITests/KeyboardLoopUITests.swift`.

## 9. Close-out

- [ ] 9.1 Full gauntlet and independent validation: `./scripts/verify-project.sh` exit 0, `npm run spec:validate` strict, `./scripts/smoke.sh` exit 0, `prd.json` and `progress.txt` carrying per-atom red→green evidence, and an independent fresh-context validator mapping every SPEC.md-level criterion to pass/fail/blocked before the change is archived and merged.
