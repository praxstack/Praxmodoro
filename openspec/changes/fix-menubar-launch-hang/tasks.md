# Tasks: fix-menubar-launch-hang

## 1. Core edge

- [x] 1.1 **Red:** `testNextEdgeIsTheEarliestFutureCanonicalInstant` in `app/Packages/PraxmodoroCore/Tests/PraxmodoroCoreTests/SessionReconstructionTests.swift`; `swift test --package-path app/Packages/PraxmodoroCore` fails with `value of type 'Session' has no member 'nextEdgeInstant'`.
- [x] 1.2 **Green:** add `Session.nextEdgeInstant(after:cadence:)` to `SessionReconstruction.swift`; the Core suite passes.

## 2. Model-owned observation

- [x] 2.1 **Red:** add `app/Tests/PraxmodoroTests/ScheduledObservationTests.swift`. Before the fix the hosted suite cannot bootstrap (app hangs at launch, xcodebuild exit 65), and the new tests cannot compile without `ObservationScheduling`.
- [x] 2.2 **Green:** add `app/Sources/ObservationScheduler.swift`; wire `observationScheduler` and `syncObservation(at:)` into `app/Sources/AppModel.swift`; remove the label `TimelineView` and inject `EdgeObservationScheduler()` on both launch paths in `app/Sources/PraxmodoroApp.swift`.
- [x] 2.3 **Guard:** make the module-wide beat scan in `SnapshotTests.swift` line-level with a two-line allowlist for the scheduler's timer.

## 3. Pre-existing red tests on main

- [x] 3.1 `SoundDirectorTests.testAppWakeWiringCancelsOnlyAndLeavesResyncToTheNextDateEdge` pins the wake body including the skip flag from 0223062.
- [x] 3.2 `BlockEndFlowTests` relaunch tests pass the shared `defaults` to the relaunched model, as their setup intended.

## 4. Verification

- [x] 4.1 `npm run spec:validate`, Core and Store package suites, `./scripts/focused.sh`, and `swift format lint --strict` on the gated trees.
- [x] 4.2 Launch evidence: an unpatched `main` main thread sampled in `MenuBarExtraController.updateConfiguration`; the fixed build idles in `nextEventMatchingMask` and stays alive with no window open.
