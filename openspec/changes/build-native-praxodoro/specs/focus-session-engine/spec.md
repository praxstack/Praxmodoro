## ADDED Requirements

### Requirement: One canonical active session
The system SHALL maintain at most one canonical active session and SHALL serialize all state-changing intents before publishing a committed snapshot.

#### Scenario: [FSE-S001] First session starts
- **WHEN** no active session exists and the user starts a prepared task
- **THEN** the system commits exactly one active session and publishes its focusing snapshot

#### Scenario: [FSE-S002] Concurrent surface commands
- **WHEN** the main window and menu-bar surface submit state-changing intents concurrently
- **THEN** the engine serializes them and publishes one revision-ordered result without duplicate transitions

### Requirement: Offline no-prerequisite start
The system SHALL let a Lite user begin a local session with a task and editable first action without an account, payment, capacity answer, network connection, notification permission, or onboarding configuration.

#### Scenario: [FSE-S003] Clean offline launch
- **WHEN** a clean Lite installation is launched with network access unavailable and the user enters a task and first action
- **THEN** the system starts the focus phase without presenting an account, paywall, permission request, or configuration gate

### Requirement: Explicit lifecycle state machine
The system SHALL model idle, prepared, focusing, paused, checking-in, breaking, re-entering, reviewing, completed, and recovery-needed states and SHALL reject intents that are invalid for the current state.

#### Scenario: [FSE-S004] Invalid resume intent
- **WHEN** a resume intent is sent while the canonical state is idle
- **THEN** the system returns an explicit invalid-transition result and leaves the persisted state unchanged

#### Scenario: [FSE-S005] Completion enters review
- **WHEN** the user completes or intentionally stops an active session
- **THEN** the system commits a reviewing state with a descriptive summary draft before final completion

#### Scenario: [FSE-S006] Break ends in explicit re-entry
- **WHEN** a break completes or the user ends it early
- **THEN** the system enters re-entering with the prior task, action, and parked thoughts and does not resume focus until the user accepts or edits the action

### Requirement: Closed typed domain contract
The system SHALL implement the closed state, intent, event, effect, invariant, default, and error vocabulary in `docs/specification/session-domain-contract.md` and SHALL NOT use stringly typed or implicit transition behavior.

#### Scenario: [FSE-S007] Exhaustive state and intent behavior
- **WHEN** tests enumerate every closed session state and intent pair
- **THEN** every pair has the specified transition or returns typed invalid-transition rejection with no event, effect, publication, or persistence mutation

#### Scenario: [FSE-S008] Exact default manifest
- **WHEN** tests inspect the four timing policies and global focus defaults
- **THEN** they match the exact durations, check-in cadence, three `SessionConfiguration` Boolean defaults, the global `askBeforeAnotherBlock` Boolean default, validation bounds, Lite mappings, and no-auto-chain rules in the session domain contract without claiming later data/platform defaults

#### Scenario: [FSE-S009] Error classification
- **WHEN** an invalid command, repository failure, effect failure, or clock anomaly occurs
- **THEN** the system returns the corresponding named rejection, engine failure, effect status, or recovery reason without collapsing the classes or mutating canonical state incorrectly

### Requirement: Data-defined timing policies
The system SHALL represent Gentle Start (5-minute entry then 20-minute focus), Classic (25-minute focus), Flow (open-ended focus), and Recovery First (10-minute recovery ramp followed only by explicit Continue into open-ended focus) as data-defined timing policies rather than separate engines. Gentle Start, Classic, and Recovery First each suggest an optional 5-minute break; Flow has no default break. All four presets SHALL be available in Lite.

#### Scenario: [FSE-S010] Policy selection
- **WHEN** a Lite user selects any shipped timing preset before starting
- **THEN** the engine uses that policy's phases, duration semantics, check-in rules, and transition rules without changing the canonical state model

#### Scenario: [FSE-S011] Open-ended Flow policy
- **WHEN** Flow begins without a fixed phase deadline
- **THEN** the engine tracks elapsed time from canonical anchors and waits for an explicit stop, pause, check-in, or break intent

### Requirement: Canonical timestamp projection
The system SHALL persist UTC phase anchors, optional deadlines, paused remaining duration, and a state revision, and SHALL treat UI ticks only as projections of that canonical state.

#### Scenario: [FSE-S012] Countdown rendering
- **WHEN** a timed phase is active
- **THEN** the displayed remaining time is derived from the committed anchor/deadline and an injected clock without persisting a record every second

#### Scenario: [FSE-S013] Pause snapshot
- **WHEN** the user pauses a timed focus phase
- **THEN** the system commits the remaining duration and no active deadline before publishing the paused snapshot

### Requirement: Exactly-once phase boundary
The system SHALL commit at most one phase-boundary transition for a state revision even when redraw, notification, wake, and deadline callbacks arrive together.

#### Scenario: [FSE-S014] Duplicate completion signals
- **WHEN** multiple callbacks report that the same focus deadline has elapsed
- **THEN** the system commits one boundary event and ignores or deduplicates the remaining callbacks

### Requirement: Sleep and wake reconciliation
The system SHALL let an active countdown continue through Mac sleep using its persisted wall deadline and SHALL reconcile immediately on wake without auto-chaining multiple overdue phases.

#### Scenario: [FSE-S015] Wake before deadline
- **WHEN** the Mac wakes before the committed phase deadline
- **THEN** the system resumes projection from the canonical deadline with the correct remaining duration

#### Scenario: [FSE-S016] Wake after deadline
- **WHEN** the Mac wakes after the committed phase deadline, clocks reconcile validly, and that phase boundary is the earliest installed boundary due at the normalized wake observation
- **THEN** the system commits exactly one elapsed-phase event and enters the phase-boundary check-in decision instead of silently starting and completing later phases

### Requirement: Relaunch recovery
The system SHALL atomically persist every accepted start, pause, resume, wake, phase, check-in, break, re-entry, review, and configuration transition so an interrupted app can recover one canonical session. Termination SHALL cancel runtime tasks but require no extra state write because no published transition is uncommitted.

#### Scenario: [FSE-S017] Relaunch during focus
- **WHEN** Praxodoro relaunches with a valid active-session snapshot whose deadline has not passed
- **THEN** the system restores the task, first action, policy, timeline, and correct projected remaining time

#### Scenario: [FSE-S018] Impossible post-restart clock value
- **WHEN** relaunch has a finite current wall observation but the stored/current clock relationship yields an impossible or out-of-policy elapsed value
- **THEN** the system clamps no silent result, records a clock anomaly, and asks the user to resume with a safe remaining value or end/review the session

A non-finite current wall observation is not stored relaunch data and cannot timestamp an anomaly;
the engine SHALL return a typed zero-write failure and allow a fresh observation instead of creating
an invalid recovery record.

### Requirement: In-process wall-clock adjustment
The system SHALL use a monotonic clock for in-process elapsed projection and SHALL rebase the persisted wall deadline when wall and monotonic clocks diverge materially.

#### Scenario: [FSE-S019] Manual clock change while running
- **WHEN** the wall clock moves forward or backward far enough that wall and monotonic observations diverge beyond the declared tolerance while the process remains active
- **THEN** the visible countdown remains monotonic, the engine appends a nonjudgmental clock-adjusted event, and the new wall deadline preserves the same remaining duration

### Requirement: Active-session conflict resolution
The system SHALL never silently replace an active session.

#### Scenario: [FSE-S020] Second start request
- **WHEN** a start intent arrives while another session is active
- **THEN** the system offers Resume Current, Replace and Review, or Cancel and waits for an explicit choice

#### Scenario: [FSE-S021] Replace and review
- **WHEN** the user chooses Replace and Review
- **THEN** the system enters review for the previous session with the validated replacement draft preserved, requires review finalization, and creates the new prepared session only through a later explicit prepare command

### Requirement: Thought parking without focus loss
The system SHALL let the user capture a short interruption thought during focus without losing valid focus time, while preserving ordinary clock and due-boundary reconciliation in the same atomic transaction.

#### Scenario: [FSE-S022] Park a thought
- **WHEN** the user submits thought text while focusing
- **THEN** the system atomically appends the thought; when no normalized boundary is due it preserves the same logical remaining phase budget even if clock normalization rebases the stored deadline, and when a boundary is due it then commits exactly the earliest winning boundary

### Requirement: Atomic commit before effects
The system SHALL atomically commit the candidate snapshot and timeline events before publishing state or attempting notifications, sounds, haptics, or visual effects.

#### Scenario: [FSE-S023] Persistence failure
- **WHEN** the repository cannot commit a candidate transition
- **THEN** the engine publishes no new canonical snapshot, reports a recoverable save error, and leaves external effects unscheduled

#### Scenario: [FSE-S024] Notification failure after commit
- **WHEN** a phase transition commits but supplemental notification scheduling fails
- **THEN** the committed session state remains valid and the user receives a non-blocking notification-status explanation

### Requirement: Shared multi-surface projection
The main window, menu-bar surface, and later compact surface SHALL render from the same engine snapshot and SHALL not maintain independent timers.

#### Scenario: [FSE-S025] Pause from menu bar
- **WHEN** the user pauses from the menu-bar surface
- **THEN** the main window reflects the same committed paused revision without a second timer or polling store
