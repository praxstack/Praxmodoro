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
The engine SHALL support the four session policies from the approved mocks (gentle start 5+20, classic 25+5, flow open-ended, recovery-first) as data, and SHALL NOT claim or encode any policy as optimal (research w2-breaks-adhd-falsification-001).

#### Scenario: Gentle start promotes without judgment
- **WHEN** a gentle-start 5-minute arrival period ends
- **THEN** the engine SHALL continue seamlessly into the main block and record the promotion as an ordinary event

#### Scenario: Flow policy has no forced end
- **WHILE** a flow session is `running`
- **THEN** the engine SHALL never auto-transition to break; only user intent or hold applies

### Requirement: Engine is UI-free and edition-free
The timer engine SHALL be a pure Swift module with no SwiftUI, AppKit, or network imports, and SHALL NOT consult the edition gate — timing behavior is identical in every edition.

#### Scenario: Module isolation is testable
- **WHEN** the engine test target builds
- **THEN** it SHALL link only Foundation and the persistence protocol, and all scenarios above SHALL run headlessly with an injected clock
