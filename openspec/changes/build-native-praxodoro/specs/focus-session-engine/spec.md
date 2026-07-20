## ADDED Requirements

### Requirement: One canonical active session
The system SHALL maintain at most one canonical active session and SHALL serialize all state-changing intents before publishing a committed snapshot.

#### Scenario: First session starts
- **WHEN** no active session exists and the user starts a prepared task
- **THEN** the system commits exactly one active session and publishes its focusing snapshot

#### Scenario: Concurrent surface commands
- **WHEN** the main window and menu-bar surface submit state-changing intents concurrently
- **THEN** the engine serializes them and publishes one revision-ordered result without duplicate transitions

### Requirement: Offline no-prerequisite start
The system SHALL let a Lite user begin a local session with a task and editable first action without an account, payment, capacity answer, network connection, notification permission, or onboarding configuration.

#### Scenario: Clean offline launch
- **WHEN** a clean Lite installation is launched with network access unavailable and the user enters a task and first action
- **THEN** the system starts the focus phase without presenting an account, paywall, permission request, or configuration gate

### Requirement: Explicit lifecycle state machine
The system SHALL model idle, prepared, focusing, paused, checking-in, breaking, reviewing, completed, and recovery-needed states and SHALL reject intents that are invalid for the current state.

#### Scenario: Invalid resume intent
- **WHEN** a resume intent is sent while the canonical state is idle
- **THEN** the system returns an explicit invalid-transition result and leaves the persisted state unchanged

#### Scenario: Completion enters review
- **WHEN** the user completes or intentionally stops an active session
- **THEN** the system commits a reviewing state with a descriptive summary draft before final completion

### Requirement: Data-defined timing policies
The system SHALL represent Gentle Start, Classic, Flow, and Recovery First as data-defined timing policies rather than separate engines, and all four presets SHALL be available in Lite.

#### Scenario: Policy selection
- **WHEN** a Lite user selects any shipped timing preset before starting
- **THEN** the engine uses that policy's phases, duration semantics, check-in rules, and transition rules without changing the canonical state model

#### Scenario: Open-ended Flow policy
- **WHEN** Flow begins without a fixed phase deadline
- **THEN** the engine tracks elapsed time from canonical anchors and waits for an explicit stop, pause, check-in, or break intent

### Requirement: Canonical timestamp projection
The system SHALL persist UTC phase anchors, optional deadlines, paused remaining duration, and a state revision, and SHALL treat UI ticks only as projections of that canonical state.

#### Scenario: Countdown rendering
- **WHEN** a timed phase is active
- **THEN** the displayed remaining time is derived from the committed anchor/deadline and an injected clock without persisting a record every second

#### Scenario: Pause snapshot
- **WHEN** the user pauses a timed focus phase
- **THEN** the system commits the remaining duration and no active deadline before publishing the paused snapshot

### Requirement: Exactly-once phase boundary
The system SHALL commit at most one phase-boundary transition for a state revision even when redraw, notification, wake, and deadline callbacks arrive together.

#### Scenario: Duplicate completion signals
- **WHEN** multiple callbacks report that the same focus deadline has elapsed
- **THEN** the system commits one boundary event and ignores or deduplicates the remaining callbacks

### Requirement: Sleep and wake reconciliation
The system SHALL let an active countdown continue through Mac sleep using its persisted wall deadline and SHALL reconcile immediately on wake without auto-chaining multiple overdue phases.

#### Scenario: Wake before deadline
- **WHEN** the Mac wakes before the committed phase deadline
- **THEN** the system resumes projection from the canonical deadline with the correct remaining duration

#### Scenario: Wake after deadline
- **WHEN** the Mac wakes after the committed phase deadline
- **THEN** the system commits one elapsed-phase event and enters a user decision, check-in, or recovery-needed state instead of silently starting and completing later phases

### Requirement: Relaunch recovery
The system SHALL persist checkpoints on start, pause, resume, sleep, wake, phase transition, and termination so an interrupted app can recover one active session.

#### Scenario: Relaunch during focus
- **WHEN** Praxodoro relaunches with a valid active-session snapshot whose deadline has not passed
- **THEN** the system restores the task, first action, policy, timeline, and correct projected remaining time

#### Scenario: Impossible post-restart clock value
- **WHEN** relaunch reconciliation yields an impossible or out-of-policy elapsed value
- **THEN** the system clamps no silent result, records a clock anomaly, and asks the user to resume with a safe remaining value or end/review the session

### Requirement: In-process wall-clock adjustment
The system SHALL use a monotonic clock for in-process elapsed projection and SHALL rebase the persisted wall deadline when wall and monotonic clocks diverge materially.

#### Scenario: Manual clock change while running
- **WHEN** the wall clock moves forward or backward while the process remains active
- **THEN** the visible countdown remains monotonic, the engine appends a nonjudgmental clock-adjusted event, and the new wall deadline preserves the same remaining duration

### Requirement: Active-session conflict resolution
The system SHALL never silently replace an active session.

#### Scenario: Second start request
- **WHEN** a start intent arrives while another session is active
- **THEN** the system offers Resume Current, Replace and Review, or Cancel and waits for an explicit choice

#### Scenario: Replace and review
- **WHEN** the user chooses Replace and Review
- **THEN** the system closes the previous session with an intentional-replacement event before creating the new prepared session

### Requirement: Thought parking without focus loss
The system SHALL let the user capture a short interruption thought during focus without changing the running phase.

#### Scenario: Park a thought
- **WHEN** the user submits thought text while focusing
- **THEN** the system atomically appends the thought to the current session timeline and leaves the phase deadline unchanged

### Requirement: Atomic commit before effects
The system SHALL atomically commit the candidate snapshot and timeline events before publishing state or attempting notifications, sounds, haptics, or visual effects.

#### Scenario: Persistence failure
- **WHEN** the repository cannot commit a candidate transition
- **THEN** the engine publishes no new canonical snapshot, reports a recoverable save error, and leaves external effects unscheduled

#### Scenario: Notification failure after commit
- **WHEN** a phase transition commits but supplemental notification scheduling fails
- **THEN** the committed session state remains valid and the user receives a non-blocking notification-status explanation

### Requirement: Shared multi-surface projection
The main window, menu-bar surface, and later compact surface SHALL render from the same engine snapshot and SHALL not maintain independent timers.

#### Scenario: Pause from menu bar
- **WHEN** the user pauses from the menu-bar surface
- **THEN** the main window reflects the same committed paused revision without a second timer or polling store
