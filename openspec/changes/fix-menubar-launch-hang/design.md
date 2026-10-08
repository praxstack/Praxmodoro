# Design: fix-menubar-launch-hang

## Context

Root observation (`observeDerivedPhase(at:)`) materializes canonical transitions and then aligns sound and notifications. Visible scenes drive it from their own `TimelineView`s. With every window closed, commit 0223062 kept it alive with a per-second `TimelineView` in the `MenuBarExtra` label's background. On macOS 27 that label timeline loops the status-item update during `MenuBarExtraController.init`, so launch never completes.

## Decision

The model owns closed-window observation, scheduled at the next canonical engine edge.

1. Core derives `nextEdgeInstant(after:cadence:)` from instants it already owns (`promotionInstant`, `expiryInstant`, `breakEndInstant`). No new arithmetic.
2. `AppModel.syncObservation(at:)` runs at the end of every `syncSound(at:)`. That is the same hand-off after every intent, restore, settings change, and observation. It asks the scheduler for a wake at the reconciled session's next edge, and does nothing when the instant is unchanged.
3. On wake the model reads its injected clock and runs `observeDerivedPhase(at:)`, which materializes, resyncs, and re-arms. If the store write fails, it still re-arms.
4. `EdgeObservationScheduler` holds one non-repeating `Timer(fire:)` dated at the engine instant. It never reads the clock. Wake and clock-change notifications re-arm the same instant, so an instant that passed during sleep fires on the next run-loop turn. Because that turn comes after the wake notification's synchronous observers, `handleSystemWake()` (wired by the label's `onReceive`) has already cancelled expired chimes and marked the retro block-start skip before the resync.

## Alternatives considered

- **Delete the label timeline only** (the footage workaround). Rejected: expiry and auto-return would not materialize, and their presentation would not resync, until a window reopens.
- **Model-owned 1 Hz loop.** Rejected: it polls 86,400 times a day to catch a handful of edges, and adds a second clock that the guards would have to tolerate.
- **Keep a `TimelineView` in the label with an `.explicit` edge schedule.** Rejected: it still re-renders the status-item label, which is the failure surface, and its schedule would be frozen at render time.
- **Evade the beat guard with an unlisted primitive** (`DispatchSource.makeTimerSource`, a `Task` loop). Rejected: the guard's own history records each such evasion as a defeat. The timer is listed line by line instead.

## Data boundaries and dependencies

No persistence, network, or package change. The timer carries only an instant derived from the engine.

## Rollback

Revert the change's commit. The label timeline returns, and so does the macOS 27 hang.

## Verification

Red: on unpatched `main`, a shell launch keeps the main thread in `MenuBarExtraController.updateConfiguration` (sampled), and the hosted unit suite never bootstraps. Green: Core `nextEdgeInstant` tests; `ScheduledObservationTests` (edge arming, no re-arm at an unchanged edge, a whole cycle carried by wakes alone, a late wake backdated with the retro block-start suppressed, held stops, the production scheduler firing past instants and re-arming on wake and clock change, a real-time cycle with no view mounted, and label and injection source guards); the full app unit suite; both package suites; strict lint; strict spec validation; a sampled launch of the fixed build idling in the event loop.
