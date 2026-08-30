# companion-surfaces Specification

## Purpose
Ambient views of one running session: the menu-bar popover, the floating focus capsule, and the return overlay. Visual and behavioral truth traces to `design-mocks/living-companion/` (physics contract: `companion-physics.js`). These surfaces present the session; they never own it.

## Requirements

### Requirement: One canonical session state for every surface
For each render pass, every surface SHALL render from exactly one engine-derived snapshot produced by the app model for that scene's supplied instant, and no surface SHALL hold, count, or decrement its own copy of the remaining time. Separate live scenes MAY receive different current instants from their own platform timelines; when given a common instant they SHALL agree. Remaining time SHALL remain a pure function of the recorded transitions and the supplied instant.

#### Scenario: Surfaces agree at one instant
- **WHEN** the focus surface, the menu-bar popover, and the floating capsule are rendered from the same instant
- **THEN** the remaining-time text, task line, and status line SHALL be identical across all three

#### Scenario: Main-window layers share one render snapshot
- **WHEN** the main-window route, focus surface, and return overlay run in one root timeline pass
- **THEN** all three SHALL consume the same immutable snapshot captured once from that timeline context, and no second snapshot or wall-clock read SHALL occur in the pass

#### Scenario: No surface counts time
- **WHEN** the surface sources are scanned for timer construction, scheduled decrements, or stored elapsed counters
- **THEN** no companion surface SHALL contain one, and the snapshot accessor SHALL be the only source of the rendered remaining time

#### Scenario: Snapshot survives sleep and relaunch
- **WHEN** a snapshot is taken after an interval during which the app was not running
- **THEN** its remaining time SHALL equal the value derived from canonical timestamps, with no accumulated tick drift

### Requirement: Menu-bar popover operates the loop
The app SHALL provide a menu-bar item whose popover shows the current status line, remaining time, and task, and SHALL offer the loop entry points available in the current phase — begin, hold or resume, check in, and open the main window.

#### Scenario: Popover reflects the live phase
- **WHEN** the session is held
- **THEN** the popover status line SHALL say the place is held and its primary control SHALL offer resume rather than hold

#### Scenario: Popover with no session
- **WHEN** no session is running
- **THEN** the popover SHALL offer beginning one and SHALL NOT display a remaining time

#### Scenario: Popover carries no scoring
- **WHEN** the popover renders in any phase
- **THEN** it SHALL NOT display streaks, grades, completion percentages, comparative judgments, or an upsell

### Requirement: Floating focus capsule stays above other windows
The app SHALL provide a small floating capsule window carrying the task line, remaining time, and hold/resume, SHALL keep it above ordinary windows while it is open, SHALL NOT open it automatically at launch, and SHALL let the user open and close it from a keyboard-reachable command.

#### Scenario: Capsule is suppressed at launch
- **WHEN** the app launches
- **THEN** the capsule window SHALL NOT be shown until the user opens it

#### Scenario: Capsule toggles from the keyboard
- **WHEN** the user invokes the capsule command from the keyboard
- **THEN** the capsule window SHALL open, and invoking the command again SHALL close it

#### Scenario: Capsule shows the same time as the main window
- **WHEN** the capsule and the focus surface are rendered from one instant
- **THEN** both SHALL display the same remaining-time text derived from the same snapshot

### Requirement: Return overlay presents the exact next action
WHEN a break ends, the app SHALL present a return overlay over the focus surface carrying the exact next action recorded at initiation, SHALL keep it visible until the user acknowledges it, and SHALL dismiss it on ⏎ or its primary control without altering the session state.

#### Scenario: Ending a break raises the overlay
- **WHEN** the user ends a break
- **THEN** the return overlay SHALL be presented over the focus surface with the recorded next action as its subject

#### Scenario: Acknowledgement returns to focus
- **WHEN** the user acknowledges the return overlay and no check-in is waiting
- **THEN** the overlay SHALL be dismissed, the focus surface SHALL be active, and the session phase SHALL be unchanged by the acknowledgement

#### Scenario: A check-in waits behind the return
- **WHEN** a check-in is requested while the return overlay is pending
- **THEN** the app SHALL hold the session and remember the check-in without replacing or dismissing the return overlay, and acknowledgement SHALL then route to the waiting check-in without itself changing session phase

#### Scenario: No next action recorded
- **IF** no next action was recorded at initiation
- **THEN** the overlay SHALL present the task itself as the way back rather than an empty card

#### Scenario: Return is not a verdict
- **WHEN** the return overlay renders
- **THEN** it SHALL NOT display break duration judgments, streaks, or any evaluation of the break that just ended

### Requirement: Companion surfaces ship in the one product
Every companion surface SHALL consult the internal capability-provenance registry, and the keys backing them SHALL resolve as available in the sole product configuration; initiation, check-in entry, hold/resume, and accessibility behavior reached through these surfaces SHALL be impossible to withhold.

#### Scenario: The product includes every companion surface
- **WHEN** the registry resolves the companion-surface feature keys
- **THEN** every key SHALL resolve to available and no surface SHALL render an upsell or tier message

#### Scenario: Companion surface keys cannot be withheld
- **WHEN** a hostile registry fixture omits a companion-surface key
- **THEN** registry validation SHALL fail and runtime lookup SHALL still resolve the omitted key as available

### Requirement: Accessibility alternates on every companion surface
Every companion surface SHALL ship its accessibility alternates in this change: Reduce Motion or "Motion: still" SHALL stop the physics engine on that surface entirely, Reduce Transparency SHALL render an opaque background instead of a translucent one, Increase Contrast SHALL raise the text-to-background contrast, every control SHALL be keyboard-reachable, and every surface SHALL carry VoiceOver labels.

#### Scenario: Reduce Motion standdown on the new surfaces
- **WHEN** Reduce Motion is on and the popover or capsule renders a companion field
- **THEN** the physics model SHALL NOT be instantiated and the static alternate SHALL render

#### Scenario: Reduce Transparency renders opaque
- **WHEN** a companion surface background is rasterized with Reduce Transparency on over a known backdrop
- **THEN** the backdrop SHALL NOT be visible through the rendered background

#### Scenario: Increase Contrast raises the measured ratio
- **WHEN** the actual `MenuBarPopover`, `FocusCapsule`, and `ReturnOverlay` are rasterized from fixed content under standard and increased `colorSchemeContrast`
- **THEN** each surface's changed primary-text pixels SHALL match the standard and increased `SurfacePalette.primaryText` branches, its opaque background SHALL remain unchanged, and its measured increased text-to-background ratio SHALL be strictly higher and at least 7:1

#### Scenario: VoiceOver reads each companion surface
- **WHEN** VoiceOver focuses the popover, the capsule, or the return overlay
- **THEN** each SHALL expose a concise label naming the surface and the current session state
