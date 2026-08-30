# timer-engine Specification

## Purpose
The deterministic heart of the product. A session is a state machine over canonical wall-clock timestamps: remaining time is always a pure function of the recorded transitions and the current instant, never a counted tick. Covers the transition table, timestamp arithmetic, sleep/wake and relaunch recovery, hold semantics, user-steerable timing policies, and the engine's independence from UI and app-layer capability provenance.

## Requirements

### Requirement: Session state machine
The engine SHALL model a session as the states `idle`, `running`, `held`, `break`, and `closed`, with transitions only via explicit user intents (begin, hold, resume, startBreak, endBreak, close) or policy expiry, and SHALL reject invalid transitions with a typed error.

#### Scenario: Valid lifecycle
- **WHEN** a session receives begin → hold → resume → startBreak → endBreak → close
- **THEN** each transition succeeds and the state history records all six states in order

#### Scenario: Invalid transition is an error, not a crash
- **WHEN** `startBreak` is sent to an `idle` session
- **THEN** the engine SHALL return a typed invalid-transition error and the state SHALL remain `idle`

### Requirement: Canonical timestamp arithmetic
The engine SHALL compute all elapsed and remaining durations from stored wall-clock timestamps of transition events, and SHALL NOT accumulate elapsed time from timer ticks.

#### Scenario: Remaining time is derived, not counted
- **WHEN** a 25-minute block began at T and the current wall clock reads T+10:00
- **THEN** remaining time SHALL equal 15:00 regardless of how many render ticks occurred

#### Scenario: Backwards clock adjustment
- **IF** the wall clock moves backwards while a session is `running`
- **THEN** the engine SHALL clamp remaining time to at most the policy duration and record a clock-anomaly event

### Requirement: Sleep, wake, and relaunch recovery
The engine SHALL reconstruct the exact session state from persisted timestamps after process relaunch or system sleep/wake, with zero drift relative to wall-clock truth.

#### Scenario: Mac sleeps during a block
- **WHEN** the Mac sleeps 8 minutes into a 25-minute block and wakes 5 minutes later
- **THEN** the engine SHALL show 12 minutes remaining and no accumulated drift

#### Scenario: App relaunch during a held session
- **WHEN** the app is quit while a session is `held` and relaunched later
- **THEN** the session SHALL be restored as `held` with the same remaining duration it had when held

#### Scenario: Block expired while asleep
- **WHEN** the Mac wakes after the block's end timestamp has passed
- **THEN** the engine SHALL transition to the break-pending state and record the expiry at its canonical timestamp, not at wake time

### Requirement: Hold preserves the place
WHILE a session is `held`, the engine SHALL freeze remaining duration by recording the hold timestamp and excluding held intervals from elapsed time.

#### Scenario: Hold then resume
- **WHEN** a block is held at 17:26 remaining and resumed 4 minutes later
- **THEN** remaining time at resume SHALL be exactly 17:26

### Requirement: User-steerable timing policies
The engine SHALL support the four session policies from the approved mocks (gentle start 5+20, classic 25+5, flow open-ended, recovery-first) as data, SHALL additionally accept user-constructed policies (custom focus and break durations, long-break cadence), and SHALL NOT claim or encode any policy as optimal (research w2-breaks-adhd-falsification-001). The engine SHALL support a recorded adjustment transition (±60 seconds) while a block is running, an autostart transition recorded at the canonical expiry instant when the active block-end behaviour calls for it, and an auto-return transition recorded at the canonical break-end instant when auto-return is enabled. Policy changes SHALL never mutate history, and remaining time SHALL stay a pure function of recorded transitions and the current instant.

#### Scenario: Gentle start promotes without judgment
- **WHEN** a gentle-start 5-minute arrival period ends
- **THEN** the engine SHALL continue seamlessly into the main block and record the promotion as an ordinary event

#### Scenario: Flow policy has no forced end
- **WHILE** a flow session is `running`
- **THEN** the engine SHALL never auto-transition to break — including when autostart is enabled; only user intent or hold applies

#### Scenario: Custom policy is pure data
- **WHEN** a session runs under a user-constructed 40/8 policy
- **THEN** reconstruction from persisted transitions SHALL yield identical remaining time on relaunch

#### Scenario: Adjustment is a first-class transition
- **WHEN** an adjustment of +60 seconds is applied and the Mac then sleeps through the (shifted) expiry
- **THEN** wake SHALL backdate the expiry using the adjusted derivation, with no drift

#### Scenario: Autostart records at the canonical instant
- **WHEN** autostart applies and the app was not running at expiry
- **THEN** relaunch reconstruction SHALL place the break transition exactly at the expiry instant, not at wake or launch time

#### Scenario: Auto-return records at the canonical break-end instant
- **WHEN** auto-return is enabled and the chosen break length elapses while the app process remains active, including across system sleep
- **THEN** wake reconciliation SHALL record the return-to-focus transition at the canonical break-end instant, never at wake time, when that instant is later than the process's live-observation start; with auto-return disabled breaks SHALL stay open-ended

#### Scenario: Relaunch does not invent unattended focus blocks
- **WHEN** the app relaunches after being absent across a break end
- **THEN** restore SHALL reconstruct recorded history with auto-return disabled, seed the new process's live-observation boundary, leave the break open, and SHALL NOT synthesize that return-to-focus transition on the first or any later observation

### Requirement: Engine is UI-free and capability-registry-independent
The timer engine SHALL be a pure Swift module with no SwiftUI, AppKit, or network imports, and SHALL NOT import or consult the app-layer capability registry; timing behavior SHALL be identical regardless of app-layer feature-key configuration.

#### Scenario: Module isolation is testable
- **WHEN** the engine test target builds
- **THEN** it SHALL link only Foundation and the persistence protocol, and all scenarios above SHALL run headlessly with an injected clock

### Requirement: Break end has one canonical derivation

The engine SHALL expose `breakEndInstant(cadence:)` as the sole derivation of the current break's end, using the final break transition timestamp plus the cadence-aware suggested break length, and SHALL return no instant when the session is not currently on break.

#### Scenario: Ordinary break end

- **WHEN** a classic session enters break at T and no long-break cadence applies
- **THEN** `breakEndInstant(cadence:)` SHALL equal T plus the policy's ordinary suggested break length

#### Scenario: Long-break cadence boundary

- **WHEN** the current break is the Nth break selected by a valid long-break cadence
- **THEN** `breakEndInstant(cadence:)` SHALL equal the break transition timestamp plus the cadence's long-break length

#### Scenario: No active break

- **WHEN** the final session state is idle, running, held, or closed
- **THEN** `breakEndInstant(cadence:)` SHALL return `nil`

#### Scenario: Every consumer agrees

- **WHEN** auto-return, the break-end sound cue, and the break-end notification are enabled for the same session and cadence
- **THEN** the Core return transition, sound request, and notification request SHALL use exactly the same `breakEndInstant(cadence:)` value

#### Scenario: Auto-return is an explicit gate, not a duration

- **WHEN** auto-return is true for a custom policy whose ordinary suggested break is seven minutes
- **THEN** reconciliation SHALL return at `breakEndInstant(cadence:)`, seven minutes after the break transition, with no second caller-supplied duration

#### Scenario: Auto-return honors the process-live boundary

- **WHEN** auto-return is true with `autoReturnAfter` set to the current process's live-observation start
- **THEN** reconciliation SHALL append a return only when `breakEndInstant(cadence:)` is later than that boundary; an older break SHALL remain open on every later reconciliation, while a process that was live before the edge SHALL materialize it after wake
