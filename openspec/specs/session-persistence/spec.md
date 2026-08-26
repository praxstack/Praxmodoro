# session-persistence Specification

## Purpose
What is stored, and what is deliberately not. Local SwiftData models with an append-only event log, no network and no account, data minimisation, graceful degradation when the store cannot be opened, and storage whose shape is identical across store configurations.

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

### Requirement: Configuration-neutral storage
Stored data SHALL be identical in shape across store configurations; no field SHALL encode an edition, tier, license, paywall, or upsell concept, and no store configuration SHALL produce a different entity or attribute set from any other.

#### Scenario: Schema parity
- **WHEN** the schema is generated for the sole product configuration
- **THEN** it SHALL contain no feature-availability branch or tier-shaped attribute

#### Scenario: Two-configuration parity against live containers
- **WHEN** one store is opened in memory and another is opened on disk, and each live container's schema is read back
- **THEN** the entity names, attribute names, and attribute value types SHALL be identical between the two containers

#### Scenario: No tier-shaped field
- **WHEN** every attribute name in the live container schema is inspected
- **THEN** none SHALL name an edition, tier, license, paywall, or upsell concept

### Requirement: Lifecycle payloads have one strict app-boundary vocabulary

The app integration layer SHALL encode and decode persisted lifecycle transitions through one exhaustive vocabulary containing `running`, `held`, `break`, and `closed`, and SHALL NOT infer a lifecycle state from any other payload.

#### Scenario: Every transition write uses the vocabulary

- **WHEN** the app records begin, hold, resume, break, auto-return, or close
- **THEN** the stored transition payload SHALL be produced by the shared lifecycle codec through the model's single transition-append helper and a source guard SHALL find exactly one direct transition-event append site

#### Scenario: Synthetic idle cannot be persisted

- **IF** a writer asks the lifecycle codec to encode Core state `idle`
- **THEN** encoding SHALL fail with `unsupportedTransitionState` and no event SHALL be appended

#### Scenario: Known historical payloads remain compatible

- **WHEN** a store contains any existing `running`, `held`, `break`, or `closed` transition
- **THEN** replay SHALL reconstruct the corresponding Core state without rewriting the stored record

#### Scenario: Unknown transition is rejected

- **IF** a stored transition payload is outside the lifecycle vocabulary
- **THEN** replay SHALL fail with `unknownTransitionPayload` and SHALL NOT substitute `running`, skip the record, or partially activate the session

#### Scenario: Unknown history remains visible in review

- **WHEN** a descriptive review timeline encounters an unknown transition payload
- **THEN** it SHALL render `Unknown state record: <payload>` and SHALL NOT relabel the record as a known state or omit it

### Requirement: Store-to-Core replay is pure and deterministic

The app integration layer SHALL reconstruct Core session state through `SessionReplay.replay(events:task:)`, with no store writes, clock reads, surface mutations, sound calls, or notification calls inside replay.

#### Scenario: Replay ordering is deterministic

- **WHEN** transition records arrive out of timestamp order or share a timestamp
- **THEN** replay SHALL order transitions and adjustments by timestamp ascending and then by their original input position before constructing the session

#### Scenario: Malformed adjustment is rejected

- **IF** an adjustment payload is not a signed whole-second integer
- **THEN** replay SHALL fail with `invalidAdjustmentPayload` and SHALL NOT silently discard the event

#### Scenario: Failed replay is atomic

- **IF** replay fails while `AppModel.restore()` is processing a stored session
- **THEN** the model SHALL preserve every property value from before the restore call and SHALL NOT apply a partial session, task, thought list, policy, identifier, or surface route

#### Scenario: Optional task is absent

- **WHEN** a valid session has no task record
- **THEN** replay SHALL reconstruct the session with empty task title and first-action strings and SHALL preserve all valid transitions and parked thoughts

#### Scenario: Closed history remains truthful

- **WHEN** replay reconstructs a session whose final transition is `closed`
- **THEN** replay SHALL return the closed Core session and `AppModel.restore()` SHALL leave its pre-call properties unchanged rather than activate or resurrect that session
