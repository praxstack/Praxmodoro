## ADDED Requirements

### Requirement: Closed-window observation is model-owned and edge-scheduled

The menu-bar item's label SHALL NOT host a `TimelineView` or any other beat. While every window is closed, the app model SHALL keep observing the session by asking an injected scheduler to wake it at the next canonical engine edge (gentle-start promotion, block expiry, or break end), and SHALL run root observation at its injected clock when woken.

#### Scenario: Launch never loops the status item

- **WHEN** the app launches with the menu-bar capability available
- **THEN** the menu-bar label SHALL contain no timeline, and launch SHALL complete with the main thread idle in the event loop

#### Scenario: Expiry and auto-return materialize with every window closed

- **WHEN** no window, popover, or capsule is mounted and a block expires with behaviour "offered default" and auto-return on
- **THEN** a scheduled wake SHALL record the break at the canonical expiry instant, the next wake SHALL record the return at the canonical break-end instant, and the model SHALL then ask for a wake at the following expiry

#### Scenario: Wake re-arms a passed edge

- **WHEN** the Mac wakes, or the system clock changes, after a scheduled edge has passed
- **THEN** the scheduler SHALL fire on the next run-loop turn, after `handleSystemWake()` has run, and reconciliation SHALL backdate every transition to its canonical instant without replaying a past block-start cue

#### Scenario: Nothing pending, nothing scheduled

- **WHEN** there is no session, the block is held, or the policy is open-ended flow
- **THEN** the model SHALL cancel any pending wake and SHALL NOT poll
