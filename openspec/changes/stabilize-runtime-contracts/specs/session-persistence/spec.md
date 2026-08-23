## ADDED Requirements

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
