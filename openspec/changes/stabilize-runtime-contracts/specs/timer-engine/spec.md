## ADDED Requirements

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
