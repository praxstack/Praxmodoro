# session-persistence Specification

## Purpose
What is stored, and what is deliberately not. Local SwiftData models with an append-only event log, no network and no account, data minimisation, graceful degradation when the store cannot be opened, and storage whose shape is identical across editions and store configurations.
## Requirements
### Requirement: Local SwiftData models
The persistence layer SHALL store tasks, sessions, session events (transitions, check-in answers, parked thoughts, breaks, clock anomalies), and self-reported capacity as SwiftData models in the app's local container.

#### Scenario: A session round-trips completely
- **WHEN** a session runs begin → check-in ("smaller") → break → close
- **THEN** reloading the store SHALL reproduce the full ordered event list with canonical timestamps

### Requirement: Event log is append-only
Session events SHALL be appended, never mutated or deleted by the app; corrections SHALL be recorded as new events referencing the original.

#### Scenario: No silent rewrites
- **WHEN** a user edits a parked thought's text
- **THEN** the store SHALL contain both the original capture event and an edit event referencing it

### Requirement: No network, no account
The persistence module SHALL have no networking imports and no code path that transmits data off-device; no feature in this change SHALL require or offer account creation (research w2-product-scope-adjudication-005).

#### Scenario: Structural no-network guarantee
- **WHEN** the persistence module's dependency test runs
- **THEN** it SHALL verify no Network, URLSession, or CloudKit symbols are linked from the module

#### Scenario: First run asks for nothing
- **WHEN** the app launches for the first time
- **THEN** no sign-in, email, or sync prompt SHALL appear

### Requirement: Data minimization
The store SHALL record only what the user explicitly entered or chose plus engine transition timestamps, and SHALL NOT record app usage of other applications, window titles, URLs, or any passive observation.

#### Scenario: Nothing passive in the store
- **WHEN** the store schema audit test runs
- **THEN** no model field SHALL exist for foreign-app activity, screen content, or inferred physiological state

### Requirement: Store corruption degrades gracefully
IF the local store fails to open or migrate, the app SHALL start with a fresh store, preserve the unreadable store file under a recovery name, and tell the user plainly what happened without blame.

#### Scenario: Corrupt store on launch
- **WHEN** the store file is unreadable at launch
- **THEN** the app SHALL still reach the initiate surface, and a notice SHALL name the preserved recovery file location

### Requirement: Edition-neutral storage
Stored data SHALL be identical in shape across editions; no field SHALL exist solely to enforce or upsell editions.

#### Scenario: Schema parity
- **WHEN** the schema is generated under Lite and Pro flags
- **THEN** the schemas SHALL be identical

