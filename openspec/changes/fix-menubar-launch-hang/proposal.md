# Proposal: fix-menubar-launch-hang

## Why

On macOS 27 with Xcode 27, the app built from `main` (3531d6a) hangs at launch and never opens a window. The main thread loops in SwiftUI's `MenuBarExtraController.init → updateConfiguration → ViewGraphRootValueUpdater.invalidateProperties`. The trigger is the once-per-second `TimelineView(.periodic(from: .now, by: 1))` that commit 0223062 placed in the `.background` of the `MenuBarExtra` label to keep date-edge observation alive with every window closed. Re-rendering the status item's label on a beat loops the status-item update.

The hang also blocks the hosted app unit suite: the test host is the app, so `xcodebuild test` is killed before bootstrapping (exit 65 locally and in CI on `main`).

Removing the label timeline makes launch work, but on its own it silently drops the guarantee the timeline provided: with every window closed, block expiry, auto-return, and the presentation resync that follows them (sound, notifications, return overlay) would wait until a window reopens.

## Goals, non-goals, assumptions

**Goals:** remove every beat from the menu-bar label; keep closed-window observation by having the model ask to be woken at the next canonical engine edge instead of polling; keep the wake-notification wiring; keep the module-wide no-second-clock guard as strict as before, with exactly one reviewed, engine-dated timer added to its allowlist.

**Non-goals:** changing the main window, popover, or capsule render timelines; changing transition, sound, or notification policy; new settings; state-restoration or window-launch behaviour.

**Assumptions:** the next instant at which reconciliation or the derived phase can change is always one of Core's canonical instants: gentle-start promotion, block expiry, or break end. Run-loop timers do not age during sleep, so wake and system-clock changes re-arm the pending instant.

**Product/capability impact:** none added or removed; the one product keeps every capability. No network, data, or persistence change.

**Measurable success:** an unpatched `main` build launched from a shell keeps its main thread in `MenuBarExtraController.updateConfiguration`, while the fixed build's main thread idles in the event loop; the hosted app unit suite bootstraps and passes; unit tests prove each scheduled wake materializes the canonical transition and arms the next edge with no view mounted, including a late (post-sleep) wake and a real-time run on the production scheduler; the source guard proves the label has no timeline; `npm run spec:validate`, both package suites, the app unit suite, and `swift format lint --strict` exit 0.

## What Changes

- **Core:** `Session.nextEdgeInstant(after:cadence:)`, the earliest future promotion, expiry, or break-end instant.
- **App seam:** `ObservationScheduling` with an inert default (tests, previews) and `EdgeObservationScheduler`, a single non-repeating wall-clock-dated `Timer` on the main run loop in common modes that re-arms on `NSWorkspace.didWakeNotification` and `NSSystemClockDidChange`.
- **AppModel:** after every sync, ask the scheduler for a wake at Core's next edge; on wake, run `observeDerivedPhase(at:)` at the injected clock.
- **App scenes:** remove the label `TimelineView`; inject `EdgeObservationScheduler` on both launch paths.
- **Guards:** the module-wide beat scan becomes line-level with an explicit two-line allowlist for the scheduler; a new source guard forbids any timeline in the menu-bar label.
- **Pre-existing test defects on `main`, hidden by the hang:** the wake-handler source pin is updated to the body commit 0223062 introduced, and two relaunch tests share their defaults with the relaunched model as their own setup intended.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `companion-surfaces`: gains a requirement that the menu-bar label stays beat-free while closed-window observation is model-owned and edge-scheduled.
