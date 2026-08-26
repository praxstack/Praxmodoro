# Design: stabilize-runtime-contracts

## Context

`PraxmodoroCore.Session` is a deterministic state machine over canonical timestamps. `PraxmodoroStore.LocalStore` is an append-only SwiftData adapter. The app target imports both packages and `AppModel` currently performs their translation inline.

The change keeps those package boundaries intact:

```text
user intent
    |
    v
surface -> AppModel -> TransitionPayload.encode -> LocalStore
              ^                                      |
              |                                      v
              +------- SessionReplay.replay <- StoredEvent[]
                              |
                              v
                        Core Session
                              |
                              +-> breakEndInstant(cadence:)
                                      |       |       |
                                      v       v       v
                                reconcile   sound   notification
```

## Goals / Non-Goals

**Goals:** make stored lifecycle vocabulary explicit and exhaustive; make replay pure and directly testable; keep one authority for break-end arithmetic; prevent views from bypassing the model's intent boundary.

**Non-goals:** introduce a repository protocol, coordinator, reducer, dependency-injection framework, new package, schema migration, general event serialization framework, or wholesale actions-struct migration.

## Approaches considered

### Approach A: Local substitutions

Replace each bare string with `SessionState.rawValue`, add guards inline in `AppModel.restore()`, and deduplicate the two presentation calculations with an app helper.

- Effort: small.
- Advantage: fewest new declarations.
- Rejected because: restore stays embedded in a 700-line controller; Store-to-Core translation remains untestable without constructing `AppModel`; Core reconciliation can still diverge from the app helper.

### Approach B: Narrow runtime contracts (selected)

Add one app-target replay/payload file, one Core derivation, and one model method plus structural guards.

- Effort: small to medium.
- Advantage: resolves all three existing prerequisite tickets at their shared boundaries without moving unrelated behavior.
- Cost: one new app source file and a typed replay result.

### Approach C: App architecture rewrite

Split `AppModel` into repository, session coordinator, router, presentation director, and surface action protocols.

- Effort: large.
- Rejected because: no current test or feature requires those abstractions; it would mix structural churn with behavior changes and duplicate the deferred main-surface actions migration recorded in #53.

## Decisions

### 1. The app target owns payload translation

`PraxmodoroStore` SHALL continue to expose plain `StoredEvent` values and SHALL NOT import Core. Core SHALL continue to know nothing about storage. A new `SessionReplay.swift` file in the app target SHALL contain:

- `TransitionPayload`, a namespace codec from Core's existing `SessionState` to the stored lifecycle values `running`, `held`, `break`, and `closed`, not a second state model;
- `SessionReplayError`, with `unsupportedTransitionState(SessionState)`, `unknownTransitionPayload(String)`, and `invalidAdjustmentPayload(String)` cases;
- `SessionReplay`, initialized with `LocalStore.SessionSummary` and exposing `replay(events:task:)`;
- `SessionReplay.Result`, containing the reconstructed `Session`, session identifier, task text, first action, and parked thoughts.

`TransitionPayload` SHALL provide `encode(_ state: SessionState) throws -> String`, `decode(_ payload: String) throws -> SessionState`, and a descriptive review-label function. Encoding `.idle` SHALL throw `unsupportedTransitionState(.idle)` because idle is the synthetic reconstruction seed, not an appended lifecycle event.

The concrete value contract is:

```text
TransitionPayload.encode/decode maps SessionState.running | held | onBreak(encoded as "break") | closed

SessionReplay.init(summary: LocalStore.SessionSummary)

SessionReplay.replay(
  events: [StoredEvent],
  task: (title: String, firstAction: String)?
) throws -> SessionReplay.Result

SessionReplay.Result:
  session: Session                         required
  sessionID: UUID                         required, copied from summary.id
  taskTitle: String                       required, default ""
  firstAction: String                     required, default ""
  parkedThoughts: [String]                required, default []
```

Known review labels are fixed: `running` → `Focus resumed`; `held` → `Held — place kept`; `break` → `Chose an intentional break`; `closed` → `Closed the session`.

### 2. Replay ordering is deterministic

`SessionReplay.replay(events:task:)` SHALL:

1. retain each event's input index;
2. select transition events;
3. decode every transition or throw `unknownTransitionPayload`;
4. order transitions by timestamp ascending, then input index ascending;
5. prepend the synthetic `.idle` record at `summary.startedAt`;
6. decode every adjustment as signed whole seconds or throw `invalidAdjustmentPayload`, then order adjustments by timestamp ascending and input index ascending;
7. construct the Core `Session` using `TimingPolicy.named(summary.policyName)`;
8. copy task values when present and use empty strings when absent;
9. preserve parked thoughts in store order.

Closed and idle replay results are valid translation results. To preserve current behavior, `AppModel.restore()` SHALL leave every pre-call model property unchanged when the valid replay result is closed; a fresh launch therefore remains on initiate without resurrecting the closed session. This is distinct from a failed replay: the pure replay succeeds and is directly testable.

`AppModel.restore()` SHALL fetch all inputs, obtain a complete replay result, and only then assign `session`, `sessionID`, `policy`, task text, first action, parked thoughts, and surface routing. A replay error SHALL leave every pre-call model property unchanged.

### 3. Unknown stored values never fabricate state

An unknown transition payload SHALL terminate replay with a typed error. It SHALL NOT fall back to `.running`, skip the record, or partially apply the replay result. A malformed adjustment SHALL follow the same all-or-nothing rule.

The review timeline SHALL render an explicit `Unknown state record: <payload>` label for an unknown transition because a historical review is descriptive and must not disappear. Startup user presentation for replay errors belongs to #35/#36 and is outside this change.

`AppModel` SHALL own one throwing helper, `appendTransition(_ state: SessionState, at: Date) throws`, which first encodes through `TransitionPayload` and only then calls the store. It contains the only direct `LocalStore.appendEvent(kind: .transition, ...)` call in the app model. Encoding failure therefore performs no write. A source test SHALL reject any second direct transition append or bare durable lifecycle literal on a write path.

### 4. Core owns the break-end instant

`Session.breakEndInstant(cadence:) -> Date?` SHALL return `nil` unless the session's final transition is `.onBreak`. Otherwise it SHALL return:

```text
last_break_transition.at + suggestedBreakLength(cadence: cadence)
```

`Session.reconciled`, `AppModel.syncSound`, and `AppModel.syncNotifications` SHALL consume this method. The current public Core argument `autoReturn: TimeInterval?` SHALL migrate to `autoReturn: Bool = false`; when true, reconciliation SHALL use `breakEndInstant(cadence:)` and no caller-supplied duration. Its required `autoReturnAfter: Date?` argument is temporal provenance, not another duration: Core appends the return only when the canonical break end is later than the supplied process-live boundary. Callers pass `nil` only with `autoReturn: false`; `AppModel` captures and passes a non-nil boundary once from its injected clock at initialization whenever auto-return is enabled. This prevents the first or any later render after relaunch from materializing a break end that occurred while the process was absent, while a process alive before sleep still catches the canonical edge on wake. Custom-policy and before/after-boundary regressions SHALL prove both rules.

### 5. Surfaces express intents

`AppModel.surface` SHALL become `private(set)`. `ReviewSurface` SHALL call `AppModel.beginNextSession()`. The method SHALL perform only the existing routing change to `.initiate`; it SHALL not reset task, history, or preferences. A source test SHALL also scan Swift source under `app/Sources/Surfaces/` and fail on direct `model.surface =` assignment so the intended boundary remains visible even though the compiler enforces it.

The broader migration of main surfaces to immutable display/actions values remains deferred until a concrete render-independent test needs it.

## Error contract

| Error | Trigger | State change | Caller behavior in this change |
|---|---|---|---|
| `unsupportedTransitionState(.idle)` | a writer attempts to persist synthetic idle as a transition | none | transition append propagates the error |
| `unknownTransitionPayload(value)` | transition payload is not one of the four durable values | none | `AppModel.restore()` propagates the error |
| `invalidAdjustmentPayload(value)` | adjustment payload is not a signed whole-second integer | none | `AppModel.restore()` propagates the error |
| existing store error | summary, events, or task fetch fails | existing concrete-store behavior is unchanged; no new atomicity claim | `AppModel.restore()` propagates the store error; injectable store-failure behavior remains #35/#36 |

No retry is added. Replay errors are deterministic local-data errors; retrying the same bytes cannot change the outcome. This change's executable all-or-nothing guarantee is scoped to a complete fetched input set that fails replay. A general injectable store-read/write failure seam and persist-before-mutate guarantee remain explicitly owned by #35/#36.

## Data boundaries

No SwiftData model, attribute, event kind, or stored payload value changes. Known existing records remain byte-for-byte readable. No new user data is collected. The app target remains the only layer importing both Store and Core.

## Dependency provenance

Foundation, `PraxmodoroCore`, and `PraxmodoroStore` are already present. No dependency is added.

## Rollback

The code change is additive except for call-site replacement. Reverting the change restores the old inline translation and duplicated arithmetic; no data migration or rollback transform is required. The rollback pointer for the complete run is baseline commit `a78e0e04cbf5cfe75582e50bfd0ec6b2afb0a4e7`.

## Verification strategy

Each behavior change starts with one observed failing test. Core derivation tests run with `swift test --package-path app/Packages/PraxmodoroCore`; app replay, presentation agreement, and source guards run with `./scripts/focused.sh`. Completion requires `./scripts/verify-project.sh`, `./scripts/smoke.sh`, strict OpenSpec validation, an independent spec validator, the named cross-model review lanes, and a final independent code review.
