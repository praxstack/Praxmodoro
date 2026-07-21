# Praxodoro Session Domain Contract

Status: normative candidate for the pre-Atom-3.1 semantic gate
Version: 2
Owner atoms: 3.1, 3.2, 3.3, 4.1
Higher authority: `SPEC.md` and the active OpenSpec capability requirements

This contract closes the session value model, defaults, lifecycle, timing, events, effects, results,
and failures. Code may organize declarations differently, but it SHALL preserve the public meanings,
validation, ordering, and ownership below. A discovered contradiction with a higher-ranked source
blocks implementation until the artifacts are reconciled; “stricter” is not a substitute for the
source precedence in `SPEC.md`.

## 1. Scope and atom ownership

| Atom | Owns in this contract | Does not own |
|---|---|---|
| 3.1 | immutable values including boundary/cadence token declarations, explicit constructors, kind projections, exact presets/defaults, event/effect shapes, result/error vocabulary, invariant validator, projection data shape and error vocabulary | reducer behavior, token publication/admission, callable projection, live time arithmetic, persistence |
| 3.3 | pure projector/time-kernel algorithms, boundary/cadence token construction and admission decisions, clock recovery decisions; implemented immediately after 3.1 | reducer matrix, event envelopes, actor serialization, persistence adapters |
| 3.2 | pure non-throwing reducer built on the accepted 3.3 time kernel, exhaustive state/intent behavior, pre-normalization duplicate/stale token classification, all coach suggestion values/errors/API/behavior, ordered reduction events/effects | new wall/monotonic algorithms, repository commits |
| 4.1 | actor command serialization, revision gate, atomic repository transaction, publication/effect order | SwiftData schema, platform effect implementation |

Important boundary:

- `SessionSnapshot` is canonical session truth.
- `SessionProjection` is derived display truth and is never persisted.
- `SessionEvent` is a minimal factual audit record, not a second snapshot or a source of diagnosis.
- `SessionEffect` is a best-effort request and cannot change a committed revision.
- App settings, retention, notifications, rendering, and paid-service adapters have later owner atoms.
  Only values required to make the session domain deterministic appear here.

## 2. Construction and normalization contract

All canonical public domain values SHALL conform to `Equatable` and `Sendable`. Identifier/key values
SHALL also conform to `Hashable`. The raw, deliberately untrusted `SessionInstant`,
`LiveProjectionObservation`, `ReductionContext`, and `LiveEntryRequest` inputs conform to `Sendable`
but not `Equatable`:
they accept NaN/infinite `Date` probes, for which Foundation equality is not reflexive. Runtime
monotonic elapsed values are `Duration` values supplied by the engine and are never persisted.

Every stored/canonical timestamp uses a `SessionTimestamp`, which exposes its UTC Foundation `Date`
for platform/UI adapters but owns lawful equality for malformed internal fixtures:

~~~swift
public struct SessionTimestamp: Equatable, Hashable, Sendable {
  public let date: Date

  internal init(unchecked date: Date)

  public static func == (lhs: SessionTimestamp, rhs: SessionTimestamp) -> Bool {
    let left = lhs.date.timeIntervalSinceReferenceDate
    let right = rhs.date.timeIntervalSinceReferenceDate
    if left.isFinite && right.isFinite { return left == right }
    return left.bitPattern == right.bitPattern
  }

  public func hash(into hasher: inout Hasher) {
    let value = date.timeIntervalSinceReferenceDate
    if value.isFinite { hasher.combine(value) } else { hasher.combine(value.bitPattern) }
  }
}
~~~

The unchecked initializer exists only for reducer construction, validator fixtures, and the future
validated persistence decoder; public clients cannot inject a stored timestamp. Bit-pattern equality
makes identical NaN probes reflexive and hash-consistent. Valid canonical values are finite integral
seconds and therefore have ordinary numeric equality as well.

The persisted/reduced timing quantum is exactly one second. The internal
`canonicalSecond(_ date: Date) -> SessionTimestamp?` helper returns nil unless
`date.timeIntervalSinceReferenceDate` is finite; otherwise it floors that value to an integral second
and creates the corresponding `SessionTimestamp`. Reducer/projector call sites perform their
contract-specific precedence checks before unwrapping this helper, so nil maps to the named
reduction/projection error rather than becoming a stored value. All snapshot anchors/deadlines, `startedAt`, state-transition dates,
`lastWallObservationAt`, summary dates, and event `occurredAt` values are canonical seconds. Reducer
arithmetic, drift, and due admission use these canonical values. Fractional raw wall/monotonic values
may drive a display projection but never enter canonical state, so reanchoring cannot extend or
shorten a timed boundary by a fractional remainder.

Live projected elapsed is never derived from the monotonic duration in isolation. It is the paired canonical delta
`canonicalPairedElapsedSeconds(rawAnchor, elapsed) = seconds(canonicalSecond(rawAnchor + elapsed) - canonicalSecond(rawAnchor))`,
after checking that the raw anchor is finite, elapsed is nonnegative, the date addition is finite,
and the result fits `UInt64`. This paired definition is the only projected-elapsed definition used by
in-process display, materialization, wake, pause, and boundary admission. Relaunch has no monotonic
pair and instead uses the exact difference between canonical persisted/current wall seconds. The paired definition preserves the
fractional part sampled with the continuous-clock anchor without persisting that fraction.

### 2.1 Public construction

- User-created values (`SessionPlan`, `SessionDraft`, `CheckInSchedule`, `BreakChoice`) SHALL expose
  explicit public initializers or factories.
- A constrained public initializer SHALL throw `DomainValidationError`; invalid constrained values
  SHALL not be constructible.
- Canonical snapshot/state payload initializers SHALL be internal to `PraxodoroCore`. Public clients
  read them but create changes through `SessionCommand`.
- Tests use `@testable import PraxodoroCore` to build state fixtures. “Public memberwise initializer”
  is not an Atom 3.1 requirement.

The two internal minute-to-second initializers accept already-validated `CheckInMinutes` or
`BreakMinutes`; their complete input ranges map inside the destination type's range, so they neither
throw nor expose an unchecked scalar constructor. Atom 3.3 implements and tests these conversions.

### 2.2 Text normalization

Before scalar counting, every user string is normalized with
`trimmingCharacters(in: .whitespacesAndNewlines)`. The normalized value is stored.

| Field | Prepared-state rule | Transition rule |
|---|---|---|
| task | 0...500 Unicode scalars | 1...500 before `start` or replacement acceptance |
| first/revised action | 0...500 | 1...500 before `start` or `acceptRevisedAction` |
| parked thought | not applicable | 1...2,000 |
| detour note | not applicable | `nil` or 1...2,000; normalized empty becomes `nil` |
| reflection | not applicable | `nil` or 1...2,000; normalized empty becomes `nil` |

A snapshot holds at most 1,000 parked thoughts. Thought identifiers are unique, and array order is
ascending `createdAt`, then UUID string as a deterministic tie-breaker.

## 3. Closed value vocabulary

### 3.1 Draft, plan, configuration, and defaults

~~~swift
public struct SessionDraft: Equatable, Sendable {
  public let plan: SessionPlan
  public let configuration: SessionConfiguration

  public init(
    plan: SessionPlan,
    configuration: SessionConfiguration = .defaults
  )
}

public struct SessionPlan: Equatable, Sendable {
  public let task: String
  public let firstAction: String
  public let capacity: Capacity?
  public let timingPolicy: TimingPolicy

  public init(
    task: String,
    firstAction: String,
    capacity: Capacity?,
    timingPolicy: TimingPolicy
  ) throws
}

public enum Capacity: String, CaseIterable, Equatable, Sendable {
  case foggy
  case steady
  case restless
  case charged
}

public struct SessionConfiguration: Equatable, Sendable {
  public let checkInSchedule: CheckInSchedule
  public let breakSuggestionsEnabled: Bool
  public let lowCognitiveLoadEnabled: Bool
  public let reflectionPromptEnabled: Bool

  public init(
    checkInSchedule: CheckInSchedule,
    breakSuggestionsEnabled: Bool,
    lowCognitiveLoadEnabled: Bool,
    reflectionPromptEnabled: Bool
  )

  public static let defaults = SessionConfiguration(
    checkInSchedule: .every15Minutes,
    breakSuggestionsEnabled: true,
    lowCognitiveLoadEnabled: false,
    reflectionPromptEnabled: true
  )
}

public enum CheckInSchedule: Equatable, Sendable {
  case manualOnly
  case interval(CheckInMinutes)

  public static let every15Minutes = CheckInSchedule.interval(.fifteen)
}

public struct CheckInMinutes: Equatable, Hashable, Sendable {
  public let value: UInt16
  public init(_ value: UInt16) throws  // valid range: 5...120
  public static let fifteen: CheckInMinutes
}

public struct CheckInRemainingSeconds: Equatable, Hashable, Sendable {
  public let value: UInt32
  public init(_ value: UInt32) throws  // valid range: 1...7_200
  internal init(fullInterval: CheckInMinutes)  // exact validated minutes * 60, implemented by 3.3
}

public struct ScheduledCheckInBoundary: Equatable, Sendable {
  public let token: BoundaryToken
  public let dueAt: SessionTimestamp
  public let trustedRemaining: CheckInRemainingSeconds
}

public enum SessionDefaults {
  public static let selectedPolicy: TimingPolicyID = .gentleStart
  public static let wallMonotonicDriftTolerance: Duration = .seconds(2)
  public static let visualProjectionCadence: Duration = .seconds(1)
  public static let askBeforeAnotherBlock = true
  public static let maximumParkedThoughts = 1_000
}

public enum SessionConfigurationIssue: Equatable, Sendable {
  case invalidResolvedCadence(actualMinutes: Int)
}

public struct SessionConfigurationResolution: Equatable, Sendable {
  public let configuration: SessionConfiguration
  public let issues: [SessionConfigurationIssue]
}

public enum SessionConfigurationResolver {
  public static func resolveSchedule(
    base: SessionConfiguration,
    explicitSchedule: CheckInSchedule?,
    resolvedPreferenceMinutes: Int?
  ) -> SessionConfigurationResolution
}
~~~

`CheckInMinutes` throws `intervalOutOfRange`; `CheckInRemainingSeconds` throws
`checkInRemainingOutOfRange`; `BreakMinutes` throws `breakDurationOutOfRange`; and `PhaseSeconds`
throws `phaseDurationOutOfRange`, each preserving the exact rejected input and allowed range.

`nil` capacity means “Not specified.” Capacity is never inferred or preselected. Manual check-in is
always available. `manualOnly` disables scheduled occurrences without disabling manual check-in.
Starting the first focus phase with an interval schedule publishes the first scheduled boundary at
the start commit, anchored to that commit's `wallNow` plus the full interval.
Changing schedule while focusing schedules the next occurrence from the configuration commit time;
changing it while suspended applies a full new interval on the next focus resume.

`SessionDraft.configuration.checkInSchedule` is the sole committed cadence owner. Existing product
preference cadence is untrusted adapter input, not session truth. At draft creation, an explicit
schedule (including `manualOnly`) wins; otherwise a resolved integer in `5...120` becomes a validated
interval, nil preserves `base`, and any other integer falls back to `.every15Minutes` with exactly one
`invalidResolvedCadence` issue. No managed/entitlement value can override an explicit personal
schedule. Atom 5.3 owns wiring this resolver to app preferences; Atom 3.1 owns its pure value tests.

### 3.2 Exact V1 timing policies

~~~swift
public enum TimingPolicyID: String, CaseIterable, Equatable, Hashable, Sendable {
  case gentleStart
  case classic
  case flow
  case recoveryFirst
}

public struct TimingPolicy: Equatable, Sendable {
  public let id: TimingPolicyID
  public let phases: [SessionPhaseDescriptor]
  public let suggestedBreak: BreakDuration?

  public static let gentleStart: TimingPolicy
  public static let classic: TimingPolicy
  public static let flow: TimingPolicy
  public static let recoveryFirst: TimingPolicy
  public static let allV1: [TimingPolicy]
}

public struct SessionPhaseDescriptor: Equatable, Hashable, Sendable {
  public let id: SessionPhaseID
  public let ordinal: UInt16
  public let duration: PhaseDuration
}

public enum SessionPhaseID: String, Equatable, Hashable, Sendable {
  case entry
  case focus
  case flow
  case recoveryRamp
}

public enum PhaseDuration: Equatable, Hashable, Sendable {
  case timed(PhaseSeconds)
  case openEnded
}

public struct PhaseSeconds: Equatable, Hashable, Sendable {
  public let value: UInt32
  public init(_ value: UInt32) throws  // valid range: 1...86_400
  internal init(fullBreakMinutes: BreakMinutes)  // exact validated minutes * 60, implemented by 3.3
}

public enum BreakDuration: Equatable, Hashable, Sendable {
  case openEnded
  case timed(BreakMinutes)
}

public struct BreakMinutes: Equatable, Hashable, Sendable {
  public let value: UInt16
  public init(_ value: UInt16) throws  // valid range: 1...120
  public static let five: BreakMinutes
}

extension TimingPolicyID {
  public var requiredLiteFeature: RequiredLiteFeature { get }
}
~~~

`TimingPolicy` and `SessionPhaseDescriptor` use internal initializers in V1. Public construction is
through the four static presets; custom Pro recipes require a later capability contract.

| Policy | Exact `phases` value | Suggested break | Phase-boundary Continue |
|---|---|---|---|
| Gentle Start | `[entry(ordinal:0,timed:300), focus(ordinal:1,timed:1,200)]` | timed 5 min | entry starts focus; focus repeats focus as a new explicit block |
| Classic | `[focus(ordinal:0,timed:1,500)]` | timed 5 min | repeats focus as a new explicit block |
| Flow | `[flow(ordinal:0,openEnded)]` | `nil` | no automatic phase boundary exists |
| Recovery First | `[recoveryRamp(ordinal:0,timed:600), focus(ordinal:1,openEnded)]` | timed 5 min | ramp starts open-ended focus; open-ended focus has no boundary |

Every policy ID is unique. Phase ordinals start at zero, are unique, and are contiguous. A timed
duration is in `1...86_400` seconds. `requiredLiteFeature` maps the four cases exhaustively to
`.gentleStart`, `.classic`, `.flow`, and `.recoveryFirst`, respectively. No policy auto-starts the
next phase or session. `allV1` order is exactly Gentle Start, Classic, Flow, Recovery First.

### 3.3 Boundary, pause, and suspension values

~~~swift
public enum BoundaryKind: String, Equatable, Hashable, Sendable {
  case phase
  case scheduledCheckIn
  case breakEnd
}

public struct BoundaryToken: Equatable, Hashable, Sendable {
  public let sessionID: UUID
  public let kind: BoundaryKind
  public let phaseID: SessionPhaseID?
  public let sourceRevision: UInt64
  public let occurrence: UInt64
}

public enum PausedTiming: Equatable, Sendable {
  case timed(remaining: PhaseSeconds)
  case openEnded
}

public enum ResumeDisposition: String, Equatable, Sendable {
  case focusing
  case paused
}

public struct SuspendedFocusState: Equatable, Sendable {
  public let phase: SessionPhaseDescriptor
  public let timing: PausedTiming
  public let resumeDisposition: ResumeDisposition
  public let scheduledCheckInRemaining: CheckInRemainingSeconds?
}
~~~

A timed phase uses `.timed`; an open-ended phase uses `.openEnded`. Converting a live focus or break
to a suspended target first commits the projected elapsed seconds into the matching snapshot total,
then stores only future resumable timing: a positive timed remainder or the marker `.openEnded`.
The suspended value never repeats elapsed time already present in an accumulator. Check-in, break,
re-entry, pause, and review never retain a live projection token or stale wall deadline.

`CheckInState` has two disjoint valid shapes. `.resumeSuspended` requires a non-nil `suspended`, a
non-phase trigger, and nil `phaseBoundaryScheduledCheckInRemaining`. `.startPhase(next)` requires nil
`suspended`, a `.phaseBoundary` trigger for the just-consumed phase, and a next/repeated phase equal to
the exact policy continuation. This exhausted-boundary shape stores no fabricated zero or positive
remainder for the elapsed phase. Its optional phase-boundary cadence remainder is non-nil only when a
configured scheduled check-in was still strictly future at the normalized admission observation.

Boundary discriminants are closed across all construction and persistence paths. A `.phase` token
requires a non-nil `phaseID` equal to the current `FocusState.phase.id`; after consumption into a
phase-boundary `CheckInState`, it must equal the predecessor phase derived from the active policy and
the `.startPhase(next)` continuation, and the trigger token must equal
`SessionSnapshot.lastConsumedBoundaryToken`. A `.scheduledCheckIn` or `.breakEnd` token requires `phaseID == nil`.
`FocusState.phaseBoundaryToken` accepts only the matching phase token,
`BreakState.boundaryToken` accepts only a break-end token, and the snapshot scheduled token accepts
only a scheduled-check-in token. `CheckInTrigger.scheduled(token)` requires
`token.kind == .scheduledCheckIn`; after admission that trigger token must equal
`SessionSnapshot.lastConsumedBoundaryToken`. `phaseBoundary(token)` requires `token.kind == .phase` and the
matching current live phase ID before admission or the policy-derived predecessor ID after admission.
A mismatched command trigger/token is rejected as
`.staleBoundary(token)` before installed-token/due-time arbitration; a persisted mismatch is
`invalidBoundaryToken`.

A captured scheduled-check-in remainder is nil when cadence is manual-only or the suspension has no
pending scheduled occurrence. Otherwise it is a validated `CheckInRemainingSeconds` in
`1...(UInt32(activeInterval.value) * 60)`; the global construction ceiling is 7,200
seconds. Zero, a value beyond the active configured interval, or a non-nil value under manual-only is
`invalidScheduledCheckIn`.

`ScheduledCheckInBoundary.trustedRemaining` is the most recently committed remainder derived from a
valid observation. Creation/start stores the full configured interval; resume stores the captured
remainder; a valid live reconciliation or relaunch refreshes it with the exact positive integral
canonical-second difference of the normalized due interval. A wall rebase shifts `dueAt` but does not itself change that normalized
remainder. This value is the recovery oracle when a later live observation is missing, stale, or
negative; it is not recomputed from the focus phase anchor.

### 3.4 Snapshot and lifecycle states

~~~swift
public struct SessionSnapshot: Equatable, Sendable {
  public let schemaVersion: UInt16               // exactly 1
  public let sessionID: UUID?
  public let revision: UInt64                    // repository-global
  public let eventSequence: UInt64               // session-local
  public let nextBoundaryOccurrence: UInt64
  public let state: SessionState
  public let plan: SessionPlan?
  public let configuration: SessionConfiguration
  public let parkedThoughts: [ParkedThought]
  public let startedAt: SessionTimestamp?
  public let accumulatedFocusSeconds: UInt64
  public let accumulatedBreakSeconds: UInt64
  public let lastWallObservationAt: SessionTimestamp?
  public let nextScheduledCheckIn: ScheduledCheckInBoundary?
  public let lastConsumedBoundaryToken: BoundaryToken?
}

public enum SessionState: Equatable, Sendable {
  case idle
  case prepared(PreparedState)
  case focusing(FocusState)
  case paused(PausedState)
  case checkingIn(CheckInState)
  case breaking(BreakState)
  case reentering(ReentryState)
  case reviewing(ReviewState)
  case completed(CompletedState)
  case recoveryNeeded(RecoveryState)
}

public struct PreparedState: Equatable, Sendable {
  public let preparedAt: SessionTimestamp
}

public struct FocusState: Equatable, Sendable {
  public let phase: SessionPhaseDescriptor
  public let timingAtAnchor: PausedTiming
  public let wallAnchor: SessionTimestamp
  public let phaseEndsAt: SessionTimestamp?
  public let elapsedBeforeAnchorSeconds: UInt64
  public let projectionToken: UUID
  public let phaseBoundaryToken: BoundaryToken?
}

public struct PausedState: Equatable, Sendable {
  public let phase: SessionPhaseDescriptor
  public let timing: PausedTiming
  public let pausedAt: SessionTimestamp
  public let scheduledCheckInRemaining: CheckInRemainingSeconds?
}

public enum CheckInContinuation: Equatable, Sendable {
  case resumeSuspended
  case startPhase(SessionPhaseDescriptor)
}

public struct CheckInState: Equatable, Sendable {
  public let suspended: SuspendedFocusState?
  public let trigger: CheckInTrigger
  public let continuation: CheckInContinuation
  public let phaseBoundaryScheduledCheckInRemaining: CheckInRemainingSeconds?
}

public struct BreakState: Equatable, Sendable {
  public let choice: BreakChoice
  public let timingAtAnchor: PausedTiming
  public let wallAnchor: SessionTimestamp
  public let endsAt: SessionTimestamp?
  public let elapsedBeforeAnchorSeconds: UInt64
  public let projectionToken: UUID
  public let boundaryToken: BoundaryToken?
  public let resumeTarget: SuspendedFocusState
  public let proposedAction: String
}

public struct ReentryState: Equatable, Sendable {
  public let resumeTarget: SuspendedFocusState
  public let proposedAction: String
  public let enteredAt: SessionTimestamp
}

public struct ReviewState: Equatable, Sendable {
  public let draft: SessionSummaryDraft
  public let stopReason: SessionStopReason
  public let replacementDraft: SessionDraft?
}

public struct CompletedState: Equatable, Sendable {
  public let summary: SessionSummary
  public let pendingReplacementDraft: SessionDraft?
}

public struct RecoveryState: Equatable, Sendable {
  public let reason: RecoveryReason
  public let lastTrustworthyState: RecoverableSessionState
  public let safeChoices: Set<ClockRecoveryChoice>
}

public enum RecoverableSessionState: Equatable, Sendable {
  case focus(SuspendedFocusState)
  case breakState(SuspendedBreakState)
  case checkingIn(CheckInState)
  case reentering(ReentryState)
}

public struct SuspendedBreakState: Equatable, Sendable {
  public let choice: BreakChoice
  public let timing: PausedTiming
  public let resumeTarget: SuspendedFocusState
  public let proposedAction: String
}
~~~

~~~swift
public struct ParkedThought: Equatable, Sendable {
  public let id: UUID
  public let text: String
  public let createdAt: SessionTimestamp
}

public struct SessionSummaryDraft: Equatable, Sendable {
  public let endedAt: SessionTimestamp
  public let focusedSeconds: UInt64
  public let breakSeconds: UInt64
  public let parkedThoughtCount: UInt64
  public let optionalReflection: String?
}

public struct SessionSummary: Equatable, Sendable {
  public let sessionID: UUID
  public let task: String
  public let finalAction: String
  public let startedAt: SessionTimestamp
  public let endedAt: SessionTimestamp
  public let focusedSeconds: UInt64
  public let breakSeconds: UInt64
  public let stopReason: SessionStopReason
  public let parkedThoughtCount: UInt64
  public let optionalReflection: String?
}
~~~

When a transition first enters review, `SessionSummaryDraft.endedAt` is a logical metadata timestamp,
not an elapsed-time source. Leaving a live state uses the paired expected canonical wall instant;
leaving a non-live state uses `canonicalSecond(context.instant.wallNow)`. The stored value is the
one whose finite underlying reference-date seconds are later, between that instant and `startedAt`,
so no `Comparable` conformance is implied for malformed `SessionTimestamp` fixtures and a finite wall
rollback cannot create a negative summary
interval. This explicit lower bound credits no focus/break seconds; accumulators remain the sole
duration truth. The event envelope still records the raw canonical current-wall observation, which
may be earlier and provides factual clock-adjustment context.

`ReviewState.draft.endedAt` is frozen when review is first entered. Reflection edits and other
review-state commits never move it, and `finalizeReview` copies that exact value into
`SessionSummary.endedAt`; completion time is therefore not confused with the time focus/break work
stopped.

Every other canonical transition timestamp has one exact source:

| Stored field | Creation path | Exact timestamp source and update rule |
|---|---|---|
| `PreparedState.preparedAt` | `prepare` from idle/completed | `canonicalSecond(context.instant.wallNow)`; `updatePrepared` retains the original value |
| `SessionSnapshot.startedAt` | prepared `start` | `FocusEntryMaterialization.wallAnchor`; frozen for the session and copied to the final summary |
| `PausedState.pausedAt` | live focus `pause` | `NormalizedLiveTiming.expectedWallNow` |
| `PausedState.pausedAt` | phase-boundary response, re-entry acceptance, recovery, or resolution of a resume-suspended check-in back to paused creates paused | `canonicalSecond(context.instant.wallNow)`; a check-in never restores an older pre-check-in `pausedAt` |
| `ReentryState.enteredAt` | leaving a live break | `NormalizedLiveTiming.expectedWallNow` |
| `ReentryState.enteredAt` | a non-live check-in response creates re-entry | `canonicalSecond(context.instant.wallNow)` |
| `ParkedThought.createdAt` | every accepted thought/detour note | `canonicalSecond(context.instant.wallNow)`, including a live rebase or due-boundary transaction |
| `ReviewState.draft.endedAt` | first review entry | the live/non-live logical value and `startedAt` lower bound defined above |
| `SessionSummary.startedAt` / `endedAt` | `finalizeReview` | exact copies of snapshot `startedAt` and frozen review-draft `endedAt` |
| `SessionEvent.occurredAt` / `lastWallObservationAt` | every successful non-idle commit | `canonicalSecond(context.instant.wallNow)` as defined by the relational invariant |

The paired-expected sources never use the winning boundary's earlier due date; they record the
logical transition observation while accumulators alone stop at the winner. The observed sources are
factual metadata and may move backward where Section 4 permits. Atom 3.2 copies the named kernel or
canonical value and never chooses among observed, expected, or winner time.

Completed snapshots have `plan == nil`. The summary may retain task, final action, totals, and the
optional reflection as documented local history; it never retains capacity or check-in answers.
`pendingReplacementDraft` belongs to the next workflow and survives relaunch until a separate
`prepare` command creates a new session. That command may use the pending draft or a newly edited
draft; the completed summary never absorbs replacement content.

### 3.5 Commands, intents, and input values

~~~swift
public struct SessionCommand: Equatable, Sendable {
  public let expectedRevision: UInt64
  public let intent: SessionIntent

  public init(expectedRevision: UInt64, intent: SessionIntent)
}

public enum SessionIntent: Equatable, Sendable {
  case prepare(SessionDraft)
  case updatePrepared(SessionDraft)
  case start
  case pause
  case resume
  case openCheckIn(CheckInTrigger)
  case respondToCheckIn(CheckInResponse)
  case acceptRevisedAction(String)
  case requestBreak(BreakChoice)
  case endBreak
  case parkThought(String)
  case setCheckInSchedule(CheckInSchedule)
  case setBreakSuggestionsEnabled(Bool)
  case setLowCognitiveLoadEnabled(Bool)
  case setReflectionPromptEnabled(Bool)
  case stop(SessionStopChoice)
  case updateReviewReflection(String?)
  case finalizeReview
  case resolveActiveSessionConflict(
    choice: ActiveSessionConflictChoice,
    replacement: SessionDraft?
  )
  case reconcileTime(TimeObservation)
  case recoverClock(ClockRecoveryChoice)
}

public enum CheckInTrigger: Equatable, Sendable {
  case manual
  case scheduled(BoundaryToken)
  case phaseBoundary(BoundaryToken)
  case pauseOffer
}

public enum CheckInResponse: Equatable, Sendable {
  case continueFocus
  case makeSmaller
  case detour(note: String?)
  case takeBreak(BreakChoice)
  case skip
  case dismiss
}

public enum BreakKind: String, CaseIterable, Equatable, Sendable {
  case quiet
  case breathe
  case move
  case custom
}

public struct BreakChoice: Equatable, Sendable {
  public let kind: BreakKind
  public let duration: BreakDuration
  public init(kind: BreakKind, duration: BreakDuration)
}

public enum SessionStopChoice: String, Equatable, Sendable {
  case completed
  case intentionalStop
}

public enum SessionStopReason: String, Equatable, Sendable {
  case completed
  case intentionalStop
  case replacedByAnotherSession
  case clockRecoveryReview
  case clockRecoveryEnd
}

public enum ActiveSessionConflictChoice: String, Equatable, Sendable {
  case resumeCurrent
  case replaceAndReview
  case cancel
}

public enum ClockRecoveryChoice: String, CaseIterable, Hashable, Sendable {
  case resumeSavedRemainder
  case reviewSession
  case endSession
}
~~~

`resumeCurrent` and `cancel` require `replacement == nil`. `replaceAndReview` requires a non-nil
draft whose task and action satisfy start validation. `stop` never accepts replacement as a reason;
replacement is only the typed conflict-resolution path.

### 3.6 Deterministic reducer context and time observations

~~~swift
public struct SessionInstant: Sendable {
  public let wallNow: Date  // untrusted raw input; reducer uses canonicalSecond(wallNow)
  public let liveProjection: LiveProjectionObservation?

  public init(wallNow: Date, liveProjection: LiveProjectionObservation?)
}

public struct LiveProjectionObservation: Sendable {
  public let projectionToken: UUID
  public let rawWallAtProjectionAnchor: Date
  public let monotonicElapsedSinceAnchor: Duration  // must be >= .zero

  public init(
    projectionToken: UUID,
    rawWallAtProjectionAnchor: Date,
    monotonicElapsedSinceAnchor: Duration
  )
}

public struct ReductionContext: Sendable {
  public let instant: SessionInstant
  public let generatedSessionID: UUID
  public let generatedThoughtID: UUID
  public let generatedProjectionToken: UUID

  public init(
    instant: SessionInstant,
    generatedSessionID: UUID,
    generatedThoughtID: UUID,
    generatedProjectionToken: UUID
  )
}

public enum TimeObservation: Equatable, Sendable {
  case live
  case deadlineFired(token: BoundaryToken)
  case wake
  case relaunch
}
~~~

The engine allocates all nondeterministic identifiers before reduction. The reducer never calls
`UUID()`, `Date()`, a clock, a repository, or a platform API. Unused generated identifiers are
ignored; supplying them unconditionally keeps the reducer signature deterministic. `TimeObservation`
describes the system occurrence only; `context.instant` is the single wall/monotonic observation,
so conflicting duplicate time inputs are unrepresentable. `LiveProjectionObservation` is explicitly
untrusted clock input: its non-throwing initializer intentionally permits a negative duration so the
reducer/projector can return the named recovery/error instead of hiding clock corruption at
construction. The engine samples `rawWallAtProjectionAnchor` together with the continuous-clock
anchor that owns the projection token. Its canonical second must equal the live state's persisted
`wallAnchor`; mismatch is an inconsistent live projection, not wall drift. Finiteness of the current
wall observation and paired raw anchor is checked before either value is canonicalized, so a NaN or
infinite `Date` never appears inside an associated error value.

### 3.7 Projection value

~~~swift
public struct SessionProjection: Equatable, Sendable {
  public let sourceRevision: UInt64
  public let sessionID: UUID?
  public let state: SessionStateKind
  public let task: String?
  public let firstAction: String?
  public let timingPolicy: TimingPolicyID?
  public let phase: SessionPhaseID?
  public let focusedSeconds: UInt64
  public let breakSeconds: UInt64
  public let remainingSeconds: UInt64?
  public let isPaused: Bool
  public let isBoundaryAwaitingDecision: Bool
  public let nextScheduledCheckInAt: SessionTimestamp?
  public let parkedThoughtCount: UInt64
  public let lowCognitiveLoadEnabled: Bool
}

public enum ProjectionError: Error, Equatable, Sendable {
  case missingLiveProjection
  case staleProjectionToken(expected: UUID, actual: UUID)
  case inconsistentProjectionAnchor(
    expectedCanonical: SessionTimestamp,
    actualCanonical: SessionTimestamp
  )
  case negativeMonotonicElapsed
  case arithmeticOverflow
  case invalidSnapshot(Set<SnapshotInvariantViolation>)
}
~~~

Projection is a pure function of snapshot plus an optional matching live observation. Idle and
completed projections have no active phase or remaining time. Idle has nil task/action/policy;
completed projects task and final action from its summary and has nil policy. Open-ended focus/break
projections have `remainingSeconds == nil`. Ordinary one-second projection performs zero repository
writes, emits no events, and does not change revision.

The Atom 3.3 projector uses this exact precedence: validate the snapshot; return the static projection
for a non-live state and ignore the instant; require finite `instant.wallNow`; require a live
observation; require its projection token to match; require a finite raw paired anchor; compare its
canonical second with the persisted wall anchor; reject negative monotonic elapsed; then perform all
checked pair/date/total arithmetic. The two non-finite checks and checked arithmetic failure return
`arithmeticOverflow`; the other failures return their corresponding `ProjectionError`. A finite
paired raw anchor whose canonical second differs from the snapshot anchor produces
`inconsistentProjectionAnchor`. Non-live states ignore a supplied live observation because an already
queued display tick cannot mutate or invalidate canonical state.
Atom 3.1 owns only `SessionProjection`, `ProjectionError`, and internal fixture construction. Atom 3.3
introduces the concrete `SessionProjector.project` declaration and its complete implementation; Atom
3.1 SHALL NOT add a stub or partial callable projector.

| State | Task/action source | Phase/remaining | Flags and cadence |
|---|---|---|---|
| idle | nil/nil | nil/nil | paused false; boundary false; next check-in nil |
| prepared | plan | nil/nil | paused false; boundary false; next check-in nil |
| focusing | plan | focus phase; timed projected remainder or nil when open-ended | paused false; boundary false; committed next check-in |
| paused | plan | paused phase; timed stored remainder or nil when open-ended | paused true; boundary false; next check-in nil |
| checkingIn | plan | resume continuation projects suspended phase/timing; phase-boundary continuation projects the exact next/repeated phase with its full configured remainder | paused true; boundary true; next check-in nil |
| breaking | plan | resume-target phase; projected break remainder | paused false; boundary false; next check-in nil |
| reentering | plan/proposed action | resume-target phase/timing | paused true; boundary true; next check-in nil |
| reviewing | plan | nil/nil | paused false; boundary false; next check-in nil |
| completed | summary task/final action | nil/nil | paused false; boundary false; next check-in nil |
| recoveryNeeded | plan | trustworthy frozen phase/timing | paused true; boundary true; next check-in nil |

Non-live focused/break totals equal committed accumulators. Live totals add the exact projected paired
canonical elapsed from Sections 2 and 8.1. Every state copies revision/session ID, thought count, and low-load setting
from canonical snapshot/configuration (completed thought count comes from its summary). Atom 3.1 owns
the non-live/static rows; Atom 3.3 owns live arithmetic.

### 3.8 Deterministic coach suggestions

Every declaration and behavior in Section 3.8 is introduced and owned by Atom 3.2 in
`CoachSuggestion.swift`; Atom 3.1 neither declares a partial coach API nor tests these values.

~~~swift
public enum CoachSuggestionRequest: Equatable, Sendable {
  case makeSmaller
  case breakHelp
  case detourHelp(hasNote: Bool)
}

public enum CoachSuggestion: Equatable, Sendable {
  case editAction(EditActionSuggestion)
  case breakOptions(BreakOptionsSuggestion)
  case detourRecovery(DetourRecoverySuggestion)
}

public struct EditActionSuggestion: Equatable, Sendable {
  public let proposedAction: String
  public let prompt: ActionEditPrompt
  public let reasons: [CoachSuggestionReason]
}

public enum ActionEditPrompt: String, Equatable, Sendable {
  case smallestVisibleStep
}

public struct BreakOptionsSuggestion: Equatable, Sendable {
  public let recommended: BreakChoice?
  public let options: [BreakChoice]
  public let reasons: [CoachSuggestionReason]
}

public struct DetourRecoverySuggestion: Equatable, Sendable {
  public let options: [DetourRecoveryOption]
  public let reasons: [CoachSuggestionReason]
}

public enum DetourRecoveryOption: String, CaseIterable, Equatable, Sendable {
  case resume
  case makeSmaller
  case parkDetour
  case takeBreak
  case intentionalStop
}

public enum CoachSuggestionReason: Equatable, Sendable {
  case userRequestedMakeSmaller
  case userRequestedBreakHelp
  case userReportedDetour(hasNote: Bool)
  case timingPolicy(TimingPolicyID)
  case explicitCapacity(Capacity)
  case projectedFocusAtLeast(seconds: UInt64)
}

public enum SessionCoachError: Error, Equatable, Sendable {
  case unavailable(state: SessionStateKind, request: CoachSuggestionRequest)
  case staleProjection(expectedRevision: UInt64, actualRevision: UInt64)
}

public enum SessionCoach {
  public static func suggest(
    _ request: CoachSuggestionRequest,
    snapshot: SessionSnapshot,
    projection: SessionProjection
  ) throws(SessionCoachError) -> CoachSuggestion
}
~~~

`makeSmaller` is valid while prepared or checking in. It returns the normalized current action
unchanged as the editable proposal, `.smallestVisibleStep`, and only
`.userRequestedMakeSmaller`; V1 never invents task text. In prepared state this is initiation help:
it neither starts nor blocks the session, and the edited result is accepted only through
`updatePrepared`. `breakHelp` is valid while focusing, paused, or checking in. Its options are exactly move,
quiet, and breathe using the policy's suggested duration or 5 minutes when the policy has none, plus
custom open-ended. It recommends move only when capacity is explicitly `.restless` and projected
focus is at least 1,200 seconds; the reasons are then `.userRequestedBreakHelp`,
`.explicitCapacity(.restless)`, and `.projectedFocusAtLeast(seconds: 1_200)` in that order. Otherwise
`recommended == nil` and the only reason is `.userRequestedBreakHelp`.

`detourHelp` is valid only while checking in and is itself the explicit report/request. It returns
all `DetourRecoveryOption.allCases` in declaration order and exactly two reasons:
`.userReportedDetour(hasNote:)` and `.timingPolicy(currentPolicyID)`. The Boolean records only whether
the person supplied a note; no note text enters the suggestion reason.

The projection revision must equal the snapshot revision. V1 makes no unsolicited coach suggestion;
`breakSuggestionsEnabled == false` suppresses future presentation entry points but never disables an
explicit `breakHelp` request. Suggestion reasons are typed, contain no raw user text, and are never
written to `SessionEvent`.

## 4. Snapshot invariants

Every candidate is validated before repository commit. The validator returns the complete set of
`SnapshotInvariantViolation` values; it does not stop at the first error.

| Area | Required invariant |
|---|---|
| schema | `schemaVersion == 1` |
| identity | idle has nil session ID; every other state has one stable non-nil ID |
| revision | idle baseline begins at 0; repository revision increases by exactly one per successful commit and never resets between sessions |
| event sequence | idle is 0; a new prepared session commits `sessionPrepared` at sequence 1; within the same session the value increases by the exact emitted-event count; it resets only when a new session ID is prepared |
| boundary occurrence | idle is 0; a new prepared session resets it to 0; a published token takes the current value and checked-increments the counter, so the first token occurrence is 0 |
| plan | idle/completed have nil plan; prepared/focusing/paused/checking-in/breaking/re-entering/reviewing/recovery have one plan |
| start time | idle/prepared have nil `startedAt`; every started/review/completed/recovery state has non-nil `startedAt` |
| timestamp quantum | every stored state/snapshot/thought/summary `SessionTimestamp.date` is finite and equals its `canonicalSecond`; event timestamps satisfy the same rule in relational validation |
| wall observation | initial idle has nil `lastWallObservationAt`; every successful non-idle commit stores exactly `canonicalSecond(context.instant.wallNow)`; every live focus/break candidate has `wallAnchor == lastWallObservationAt`; backward observations are allowed for non-live/fresh-anchor or within-tolerance live-exit cases and otherwise require the explicit clock-adjustment/recovery rules |
| totals | totals use checked `UInt64` addition and never decrease within a session |
| prepared input | task/action are normalized and each has at most 500 scalars; start/replacement additionally require each non-empty |
| configuration | check-in interval is 5...120; manual-only creates no scheduled boundary |
| focus timing | `timingAtAnchor` shape matches the phase; timed remaining is positive, `elapsedBeforeAnchorSeconds + remaining <= phase duration`, deadline equals wall anchor plus that remaining, and a phase token exists; open-ended focus has nil deadline/token; every focus has one projection token |
| paused timing | timed phase uses a remainder in `1...phase duration`; open-ended phase uses the marker `.openEnded`; paused has no live projection |
| suspended timing | timing shape matches the phase; no live deadline/projection is retained |
| check-in continuation | resume continuation has one valid suspended target and no phase-boundary cadence field; phase-boundary continuation has no suspended target, its consumed token identifies the exact predecessor of the next/repeated policy phase, and its optional scheduled remainder is positive and strictly future at admission |
| break timing | `timingAtAnchor` shape matches the break; timed remaining is positive, `elapsedBeforeAnchorSeconds + remaining <= break duration`, and deadline/token equal anchor plus remaining; open-ended break has nil deadline/token; every break has one projection token and a normalized non-empty proposed re-entry action |
| scheduled check-in | the optional boundary owns its date/token/trusted remainder atomically; in live focus `dueAt == wallAnchor + trustedRemaining.value` seconds; token belongs to current session and kind `.scheduledCheckIn`; trusted/captured remainders are in `1...configured interval seconds`, and manual-only has none |
| boundary token | installed/trigger tokens satisfy the owner/phase rules in Section 3.3; `lastConsumedBoundaryToken` satisfies the historical-token exception below; every token matches the session, has occurrence less than `nextBoundaryOccurrence`, and retains its publishing source revision |
| thoughts | normalized non-empty text <=2,000 scalars; count <=1,000; IDs unique; deterministic order |
| review | reviewing is the only route to completed; summary end is >= start; summary totals equal the committed accumulators |
| completed privacy | completed plan is nil; summary contains no capacity or check-in response; replacement draft is separate from old summary |
| recovery | last trustworthy state contains only frozen timing, never a live anchor/deadline/projection; safe choices are exactly those allowed by Section 9; recovery never jumps directly to completed |

### 4.1 Invariant types

~~~swift
public enum SnapshotInvariantViolation: Hashable, Sendable {
  case unsupportedSchema(found: UInt16)
  case invalidIdentity
  case invalidRevision(expected: UInt64, actual: UInt64)
  case invalidEventSequence
  case invalidBoundaryOccurrence
  case missingPlan
  case unexpectedPlan
  case invalidStartTimestamp
  case nonCanonicalTimestamp(SessionTimestampField)
  case invalidWallObservation
  case counterRegression
  case invalidEventEnvelope
  case invalidText(SessionTextField)
  case invalidConfiguration(SessionConfigurationField)
  case timingShapeMismatch
  case invalidDeadline
  case invalidProjectionToken
  case invalidBoundaryToken
  case invalidScheduledCheckIn
  case duplicateThoughtID
  case thoughtLimitExceeded
  case invalidSummary
  case invalidRecoveryChoices
}

public enum DomainValidationError: Error, Equatable, Sendable {
  case textTooLong(field: SessionTextField, maximumScalars: UInt16)
  case intervalOutOfRange(actual: UInt16, allowed: ClosedRange<UInt16>)
  case checkInRemainingOutOfRange(actual: UInt32, allowed: ClosedRange<UInt32>)
  case breakDurationOutOfRange(actual: UInt16, allowed: ClosedRange<UInt16>)
  case phaseDurationOutOfRange(actual: UInt32, allowed: ClosedRange<UInt32>)
  case invalidPolicyDefinition(TimingPolicyID)
}

public enum SessionTextField: String, Hashable, Sendable {
  case task
  case firstAction
  case revisedAction
  case thought
  case detourNote
  case reflection
}

public enum SessionTimestampField: String, Hashable, Sendable {
  case preparedAt
  case focusWallAnchor
  case focusDeadline
  case pausedAt
  case breakWallAnchor
  case breakDeadline
  case reentryEnteredAt
  case thoughtCreatedAt
  case startedAt
  case lastWallObservationAt
  case scheduledCheckInDueAt
  case reviewEndedAt
  case summaryStartedAt
  case summaryEndedAt
  case eventOccurredAt
  case eventPhaseStartedEndsAt
  case eventPhaseResumedEndsAt
  case eventLiveProjectionRestoredWallAnchor
  case eventLiveProjectionRestoredEndsAt
  case eventBreakStartedEndsAt
  case clockAdjustmentPreviousPhaseOrBreakDeadline
  case clockAdjustmentNewPhaseOrBreakDeadline
  case clockAdjustmentPreviousScheduledCheckInAt
  case clockAdjustmentNewScheduledCheckInAt
}
~~~

Every Section 4 invariant row has this exact violation mapping; a validator SHALL not overload a
different case merely because it is nearby:

Timestamp-quantum validation visits every date field named by `SessionTimestampField`, including each
thought, summary, event-envelope, event-payload, and nested clock-adjustment date. Optional event
payload dates are visited when present. A timestamp is valid only when its underlying
`date.timeIntervalSinceReferenceDate.isFinite`
and equals its floored integral-second value; NaN, infinity, and any fractional second return the
field-specific `nonCanonicalTimestamp` violation.

| Invariant row | Violation case(s) |
|---|---|
| schema | `unsupportedSchema` |
| identity | `invalidIdentity` |
| revision | `invalidRevision` |
| event sequence | `invalidEventSequence`, or `invalidEventEnvelope` for an envelope-field mismatch |
| boundary occurrence | `invalidBoundaryOccurrence` |
| plan | `missingPlan` or `unexpectedPlan` |
| start time | `invalidStartTimestamp` |
| timestamp quantum | `nonCanonicalTimestamp` |
| wall observation | `invalidWallObservation` |
| totals | `counterRegression` |
| prepared input | `invalidText` |
| configuration | `invalidConfiguration` or `invalidScheduledCheckIn` |
| focus timing | `timingShapeMismatch`, `invalidDeadline`, `invalidProjectionToken`, or `invalidBoundaryToken` |
| paused timing | `timingShapeMismatch` or `invalidDeadline` |
| suspended timing | `timingShapeMismatch`, `invalidDeadline`, or `invalidProjectionToken` |
| check-in continuation | `timingShapeMismatch`, `invalidBoundaryToken`, or `invalidScheduledCheckIn` |
| break timing | `timingShapeMismatch`, `invalidDeadline`, `invalidProjectionToken`, `invalidBoundaryToken`, or `invalidText(.revisedAction)` |
| scheduled check-in | `invalidScheduledCheckIn` or `invalidBoundaryToken` |
| boundary token | `invalidBoundaryToken` |
| thoughts | `invalidText(.thought)`, `duplicateThoughtID`, or `thoughtLimitExceeded` |
| review | `invalidSummary` |
| completed privacy | `unexpectedPlan` or `invalidSummary` |
| recovery | `timingShapeMismatch`, `invalidProjectionToken`, `invalidDeadline`, or `invalidRecoveryChoices` |

### 4.2 Validator API and test construction

~~~swift
internal enum SessionSnapshotValidator {
  static func validateCandidate(
    _ candidate: SessionSnapshot
  ) -> Set<SnapshotInvariantViolation>

  static func validate(
    previous: SessionSnapshot?,
    candidate: SessionSnapshot,
    emittedEvents: [SessionEvent],
    context: ReductionContext
  ) -> Set<SnapshotInvariantViolation>
}
~~~

Candidate-local rules validate the candidate alone. Revision increment, stable identity, event
sequence/count, counter non-regression, newly published token revision, reviewing-only completion,
and the exact successful-commit wall observation compare `previous`, `candidate`, `emittedEvents`,
and `context`. For every non-idle transition candidate,
`candidate.lastWallObservationAt == canonicalSecond(context.instant.wallNow)`, including a transition that emits no
action-revision or resume event. This raw factual observation is not a globally monotonic session
timestamp. It may move backward without `clockAdjusted` when the previous state is non-live because
no time accrues there, when a non-live state establishes a fresh live anchor, or when a transition
leaves live state within the exact ±2-second tolerance. A larger live drift uses the Section 8.2
adjustment/recovery path.

Independently of transition context, candidate-local validation requires every focusing or breaking
snapshot's `lastWallObservationAt` to be non-nil and exactly equal to that live state's `wallAnchor`.
This closes persisted bootstrap bytes: a mismatched live anchor is `invalidWallObservation`, never a
second elapsed-time baseline that relaunch may trust. `previous == nil` is valid only for the initial idle revision-0
snapshot with zero events. Every ordinary commit supplies a previous snapshot and its reduction
context.

Internal canonical state/snapshot initializers intentionally permit malformed fixtures so the
validator and future persistence decoder can be tested; they are unavailable to package clients.
Public constrained values remain impossible to construct invalidly and use constructor-negative
tests instead of impossible snapshot fixtures. The validator returns every applicable violation in
one set and never repairs or clamps the candidate.

## 5. Events and effects

### 5.1 Versioned factual events

~~~swift
public struct SessionEvent: Equatable, Sendable {
  public let eventVersion: UInt16       // exactly 1
  public let sessionID: UUID
  public let sequence: UInt64           // starts at 1 per session
  public let occurredAt: SessionTimestamp
  public let payload: SessionEventPayload

  internal init(
    sessionID: UUID,
    sequence: UInt64,
    occurredAt: SessionTimestamp,
    payload: SessionEventPayload
  )  // always assigns eventVersion = 1
}

public enum SessionEventPayload: Equatable, Sendable {
  case sessionPrepared(policy: TimingPolicyID, capacitySpecified: Bool)
  case planUpdated(fields: SessionPlanFieldChanges)
  case sessionStarted
  case phaseStarted(phase: SessionPhaseDescriptor, endsAt: SessionTimestamp?)
  case phasePaused(timing: PausedTiming)
  case phaseResumed(phase: SessionPhaseDescriptor, endsAt: SessionTimestamp?)
  case liveProjectionRestored(
    phase: SessionPhaseDescriptor,
    wallAnchor: SessionTimestamp,
    endsAt: SessionTimestamp?
  )
  case checkInOpened(trigger: CheckInTrigger, continuation: CheckInContinuation)
  case checkInResolved
  case detourReported(hasNote: Bool)
  case actionRevised
  case configurationChanged(fields: SessionConfigurationFieldChanges)
  case breakStarted(kind: BreakKind, duration: BreakDuration, endsAt: SessionTimestamp?)
  case breakEnded
  case reentryPresented
  case thoughtParked(id: UUID)
  case phaseElapsed(token: BoundaryToken)
  case clockAdjusted(ClockAdjustmentEvent)
  case clockRecoveryNeeded(reason: RecoveryReason)
  case clockRecovered(choice: ClockRecoveryChoice)
  case sessionStopRequested(reason: SessionStopReason)
  case sessionReplacementRequested
  case reviewStarted(SessionReviewEvent)
  case reviewReflectionUpdated(hasReflection: Bool)
  case sessionCompleted(summary: SessionSummaryEvent)
}

public struct SessionReviewEvent: Equatable, Sendable {
  public let focusedSeconds: UInt64
  public let breakSeconds: UInt64
  public let stopReason: SessionStopReason
  public let parkedThoughtCount: UInt64
  public let hasReflection: Bool
}

public struct ClockAdjustmentEvent: Equatable, Sendable {
  public let previousPhaseOrBreakDeadline: SessionTimestamp?
  public let newPhaseOrBreakDeadline: SessionTimestamp?
  public let previousScheduledCheckInAt: SessionTimestamp?
  public let newScheduledCheckInAt: SessionTimestamp?
  public let drift: Duration
}

public struct SessionSummaryEvent: Equatable, Sendable {
  public let focusedSeconds: UInt64
  public let breakSeconds: UInt64
  public let stopReason: SessionStopReason
  public let parkedThoughtCount: UInt64
  public let hasReflection: Bool
}

public enum CheckInResponseKind: String, CaseIterable, Equatable, Hashable, Sendable {
  case continueFocus
  case makeSmaller
  case detour
  case takeBreak
  case skip
  case dismiss
}

public enum SessionPlanField: String, Hashable, Sendable {
  case task
  case firstAction
  case capacity
  case timingPolicy
}

public struct SessionPlanFieldChanges: Equatable, Sendable {
  public let values: Set<SessionPlanField>
  internal init?(_ values: Set<SessionPlanField>)  // nil when empty
}

public enum SessionConfigurationField: String, Hashable, Sendable {
  case checkInSchedule
  case breakSuggestionsEnabled
  case lowCognitiveLoadEnabled
  case reflectionPromptEnabled
}

public struct SessionConfigurationFieldChanges: Equatable, Sendable {
  public let values: Set<SessionConfigurationField>
  internal init?(_ values: Set<SessionConfigurationField>)  // nil when empty
}
~~~

All events emitted by one reduction share
`occurredAt == canonicalSecond(context.instant.wallNow)`. Every non-nil `SessionTimestamp` nested in an event
payload or `ClockAdjustmentEvent` is also a canonical second and is recursively validated through its
exact `SessionTimestampField`; payload dates never receive the generic envelope violation. Their array order
is their sequence order. Events intentionally omit task/action/thought/detour/reflection text and raw
capacity/check-in answers. Active snapshot content remains canonical; completed history ownership is
defined by the later data contract.

`checkInResolved` records only that the occurrence was consumed; it does not retain which response
the person chose. The following state-transition events express the factual result without storing a
raw answer. `SessionReviewEvent` mirrors summary totals and booleans only and cannot contain reflection
text. Event payload and envelope construction is internal; empty change sets and a non-v1 envelope
are therefore unconstructable.

### 5.2 Typed best-effort effects

~~~swift
public enum SessionEffect: Equatable, Sendable {
  case scheduleNotification(SessionNotificationRequest)
  case cancelNotification(SessionNotificationID)
  case playSound(SessionSoundCue)
  case playHaptic(SessionHapticCue)
  case announceAccessibility(SessionAnnouncementCue)
  case invalidateDisplayProjection(projectionToken: UUID?)
}

public struct SessionNotificationID: Equatable, Hashable, Sendable {
  public let value: String
  internal init(boundaryToken: BoundaryToken)
}

public struct SessionNotificationRequest: Equatable, Sendable {
  public let id: SessionNotificationID
  public let fireAt: SessionTimestamp
  public let kind: SessionNotificationKind
  public let boundaryToken: BoundaryToken
  public let contentPolicy: NotificationContentPolicy

  internal init(boundaryToken: BoundaryToken, fireAt: SessionTimestamp)
}

public enum SessionNotificationKind: String, Equatable, Sendable {
  case phaseBoundary
  case scheduledCheckIn
  case breakEnd
}

public enum NotificationContentPolicy: String, Equatable, Sendable {
  case privateGeneric
}

public enum SessionSoundCue: String, Equatable, Sendable {
  case gentleBoundary
  case breakComplete
}

public enum SessionHapticCue: String, Equatable, Sendable {
  case gentleBoundary
}

public enum SessionAnnouncementCue: String, Equatable, Sendable {
  case focusStarted
  case checkInPresented
  case breakStarted
  case reentryPresented
  case reviewPresented
}
~~~

The domain never supplies task/action content to a notification effect. Platform permission denial,
quiet settings, unavailable haptics, or scheduling failure are effect statuses, not failed session
commits. The notification request initializer derives `id`, `kind`, and `.privateGeneric` content
from the token; a phase/scheduled-check-in/break-end token maps only to the corresponding
notification kind. Arbitrary IDs, token-kind mismatches, and non-private content are unconstructable.

## 6. Results and failure taxonomy

### 6.1 Pure reduction and engine result

~~~swift
public struct Reduction: Equatable, Sendable {
  public let snapshot: SessionSnapshot
  public let events: [SessionEvent]
  public let effects: [SessionEffect]
}

public enum ReductionFailure: Equatable, Sendable {
  case revisionExhausted
  case eventSequenceExhausted(requiredAdditionalEvents: UInt64, remainingCapacity: UInt64)
  case boundaryOccurrenceExhausted
  case arithmeticOverflow
  case nonFiniteWallObservation
}

public enum ReductionOutcome: Equatable, Sendable {
  case transition(Reduction)
  case noChange(snapshot: SessionSnapshot, reason: NoChangeReason)
  case rejected(snapshot: SessionSnapshot, reason: SessionRejection)
  case failed(snapshot: SessionSnapshot, reason: ReductionFailure)
}

public enum SessionResult: Equatable, Sendable {
  case committed(snapshot: SessionSnapshot, effects: [EffectStatus])
  case noChange(snapshot: SessionSnapshot, reason: NoChangeReason)
  case rejected(snapshot: SessionSnapshot, reason: SessionRejection)
}
~~~

`SessionReducer.reduce` is pure and non-throwing. After it has determined that a command would make a
transition and its exact ordered payload count, it checked-increments revision first and event
sequence second. An unavailable revision returns `.failed(.revisionExhausted)`; insufficient event
sequence capacity returns `.failed(.eventSequenceExhausted(requiredAdditionalEvents:remainingCapacity:))`.
If that otherwise valid transition must publish a boundary token and cannot increment
`nextBoundaryOccurrence`, it returns `.failed(.boundaryOccurrenceExhausted)`. Checked finite-wall
date/duration arithmetic that cannot construct a new live entry or scheduled replacement returns
`.failed(.arithmeticOverflow)`; overflow encountered while measuring an already-live session instead
uses the recoverable Section 9 path.
No envelope, candidate, effect, or write is produced. No-change/rejected commands do not consume a
counter and remain classifiable even when a counter is at `UInt64.max`. `SessionRunning.send` maps
the five reduction failures to the same-named `SessionEngineFailure` and may throw only
`SessionEngineFailure` at the actor/repository boundary.

`nonFiniteWallObservation` is the sole reduction failure that occurs before transition construction.
Every command that would otherwise transition checks `context.instant.wallNow` for finiteness before
counter allocation, candidate creation, or event creation; a live command that needs time admission
performs the same check in its earlier live preflight. A non-finite value cannot create canonical
candidate/event timestamps, so the reducer returns the current snapshot unchanged with zero event,
effect, publication, or write and consumes no counter. A deterministic rejection or no-change path
that neither measures live time nor constructs a transition may ignore the wall observation.

### 6.2 Rejections, no-change reasons, and engine failures

~~~swift
public enum SessionRejection: Equatable, Sendable {
  case invalidTransition(state: SessionStateKind, intent: SessionIntentKind)
  case invalidPlan(fields: Set<SessionPlanField>)
  case invalidText(SessionTextField)
  case activeSessionExists
  case replacementDraftRequired
  case replacementDraftNotAllowed
  case invalidRecoveryChoice(ClockRecoveryChoice)
  case staleRevision(expected: UInt64, actual: UInt64)
  case duplicateBoundary(BoundaryToken)
  case staleBoundary(BoundaryToken)
  case boundaryNotDue(
    token: BoundaryToken,
    dueAt: SessionTimestamp,
    observedAt: SessionTimestamp
  )
  case thoughtLimitReached(maximum: UInt16)
}

public enum NoChangeReason: String, Equatable, Sendable {
  case alreadyInRequestedState
  case resumeCurrentSelected
  case conflictCancelled
  case observationIrrelevant
  case earlierBoundaryPending
}

public enum SessionEngineFailure: Error, Equatable, Sendable {
  case repositoryLoadFailed(RepositoryFailureKind)
  case repositoryCommitFailed(RepositoryFailureKind)
  case unsupportedSnapshotSchema(found: UInt16)
  case corruptSnapshot(Set<SnapshotInvariantViolation>)
  case revisionExhausted
  case eventSequenceExhausted
  case boundaryOccurrenceExhausted
  case arithmeticOverflow
  case nonFiniteWallObservation
}

public enum RepositoryFailureKind: String, CaseIterable, Error, Equatable, Sendable {
  case unavailable
  case readFailed
  case writeFailed
  case validationFailed
  case migrationFailed
}

public enum SessionRepositoryError: Error, Equatable, Sendable {
  case conflict(actualRevision: UInt64)
  case failure(RepositoryFailureKind)
}

public enum RecoveryReason: String, CaseIterable, Equatable, Sendable {
  case missingLiveProjection
  case staleLiveProjection
  case inconsistentLiveProjectionAnchor
  case negativeMonotonicElapsed
  case wallClockAmbiguousAfterRelaunch
  case arithmeticOverflow
}

public enum EffectStatus: Equatable, Sendable {
  case succeeded(SessionEffectKind)
  case failed(SessionEffectKind, PlatformStatus)
}

public enum SessionEffectKind: String, CaseIterable, Equatable, Hashable, Sendable {
  case scheduleNotification
  case cancelNotification
  case playSound
  case playHaptic
  case announceAccessibility
  case invalidateDisplayProjection
}

public enum PlatformStatus: String, CaseIterable, Equatable, Sendable {
  case notificationPermissionDenied
  case notificationSchedulingFailed
  case soundUnavailable
  case hapticUnavailable
  case accessibilityAnnouncementUnavailable
  case adapterUnavailable
  case runtimeUnavailable
}

public enum SessionStateKind: String, CaseIterable, Equatable, Hashable, Sendable {
  case idle, prepared, focusing, paused, checkingIn, breaking, reentering
  case reviewing, completed, recoveryNeeded
}

public enum SessionIntentKind: String, CaseIterable, Equatable, Hashable, Sendable {
  case prepare, updatePrepared, start, pause, resume, openCheckIn, respondToCheckIn
  case acceptRevisedAction, requestBreak, endBreak, parkThought
  case setCheckInSchedule, setBreakSuggestionsEnabled, setLowCognitiveLoadEnabled
  case setReflectionPromptEnabled, stop, updateReviewReflection, finalizeReview
  case resolveActiveSessionConflict, reconcileTime, recoverClock
}

public enum SessionEventKind: String, CaseIterable, Equatable, Hashable, Sendable {
  case sessionPrepared, planUpdated, sessionStarted, phaseStarted, phasePaused, phaseResumed
  case liveProjectionRestored
  case checkInOpened, checkInResolved, detourReported, actionRevised, configurationChanged
  case breakStarted, breakEnded, reentryPresented, thoughtParked, phaseElapsed, clockAdjusted
  case clockRecoveryNeeded, clockRecovered, sessionStopRequested, sessionReplacementRequested
  case reviewStarted, reviewReflectionUpdated, sessionCompleted
}

extension SessionState { public var kind: SessionStateKind { get } }
extension SessionIntent { public var kind: SessionIntentKind { get } }
extension SessionEventPayload { public var kind: SessionEventKind { get } }
extension SessionEvent { public var kind: SessionEventKind { get } }
extension SessionEffect { public var kind: SessionEffectKind { get } }
extension CheckInResponse { public var kind: CheckInResponseKind { get } }
~~~

Every `kind` getter is an exhaustive switch with no `default`. The corresponding kind enum has one
case per source enum case, and tests compare both `allCases` counts and each explicit mapping.

Every enum case has a producer:

| Result/error | Producer and recovery |
|---|---|
| invalidTransition | any unlisted state/intent pair; keep current snapshot |
| invalidPlan | start or replacement with empty task/action; edit named fields |
| invalidText | invalid thought/revised action/detour/reflection; keep editor value outside canonical state |
| activeSessionExists | prepare/start while an unfinished session exists; show three conflict choices |
| replacementDraftRequired / NotAllowed | conflict payload mismatch; resubmit a valid shape |
| invalidRecoveryChoice | choice outside `safeChoices`; keep recovery state |
| staleRevision | command revision differs before reduction; reload latest snapshot |
| duplicateBoundary | token equals last consumed token; no write |
| staleBoundary | token session/revision/occurrence is obsolete; no write |
| boundaryNotDue | installed token arrived before its persisted due date; preserve both tokens and dates with no write |
| thoughtLimitReached | 1,000 thoughts already stored; preserve current state and offer review/export later |
| repositoryLoadFailed / repositoryCommitFailed | typed adapter failure before publication; preserve the last committed snapshot and fire no effect |
| SessionRepositoryError.conflict | internal adapter signal translated to staleRevision after one reload; never exposed as an active-session conflict |
| alreadyInRequestedState | identical prepared/config/reflection update; no event/effect/write |
| resumeCurrentSelected / conflictCancelled | exact active-session choices with nil replacement; no event/effect/write |
| observationIrrelevant | non-live or within-tolerance time observation; no event/effect/write |
| earlierBoundaryPending | a later/tie-lower boundary callback arrived before the winning callback; keep all tokens |
| unsupportedSnapshotSchema / corruptSnapshot | bootstrap schema/candidate validation failure; publish nothing |
| revisionExhausted / eventSequenceExhausted / boundaryOccurrenceExhausted | reducer returns the matching typed `ReductionFailure` when an otherwise valid transition cannot checked-increment its required counter; actor throws the matching engine failure; publish and fire nothing |
| arithmeticOverflow | checked finite-wall arithmetic cannot construct a new live entry/scheduled replacement, or live measurement/relaunch cannot preserve a trustworthy result; a new-entry/replacement failure is zero-write, while an already-live measurement enters typed recovery |
| nonFiniteWallObservation | any otherwise transitioning reduction, or any live measurement/relaunch, has a NaN or infinite current wall; reducer and actor return the matching typed failure before canonicalization with zero write/publication/effect |
| notificationPermissionDenied / notificationSchedulingFailed | notification adapter denial or request failure after commit |
| soundUnavailable / hapticUnavailable / accessibilityAnnouncementUnavailable | the matching optional platform cue cannot execute after commit |
| adapterUnavailable / runtimeUnavailable | selected effect adapter is missing or becomes unusable after commit |
| effect failure | return failed effect status after commit; never roll back canonical state |

### 6.3 Exact effect derivation

~~~swift
internal enum SessionEffectPlanner {
  static func effects(
    previous: SessionSnapshot,
    command: SessionCommand,
    candidate: SessionSnapshot,
    events: [SessionEvent]
  ) -> [SessionEffect]
}
~~~

The reducer uses this pure planner only for a transition. No-change, rejection, and failure outcomes
have an empty effect array. The ordered result is:

1. Derive at most one notification winner for each snapshot: choose its earliest installed boundary
   date; equal dates rank phase before scheduled check-in before break-end, then occurrence. Tokens
   remain installed for core arbitration even when they are not the notification winner.
2. If the previous winner is absent from or differs in token/date from the candidate winner, cancel
   the previous winner. If the candidate winner is absent from or differs from the previous winner,
   schedule the candidate winner. Thus a snapshot has at most one pending system boundary
   notification and equal-time phase/check-in boundaries schedule only the phase winner.
3. If `phaseElapsed` is present, append `playSound(.gentleBoundary)` then
   `playHaptic(.gentleBoundary)`. If an automatic break deadline produced `breakEnded`, append
   `playSound(.breakComplete)`; a user-requested early end is silent.
4. Append at most one accessibility announcement from the resulting transition: entering focus,
   check-in, break, re-entry, or review maps to the same-named cue. Event order cannot create two
   announcements for one candidate.
5. Append exactly one `invalidateDisplayProjection`, using the candidate focus/break projection
   token or `nil` for non-live states.

An unchanged notification winner is not resubmitted. A wall-clock rebase changes its fire date and
therefore produces cancel-then-schedule with the same token-derived ID. When consuming the current
winner exposes a later installed candidate in the same live state, that later candidate becomes the
next winner and is scheduled by the same comparison. Core effect execution retries zero times;
platform-specific retry policy requires a later adapter contract.

## 7. Exhaustive reducer contract

The intent enum is closed. Each table row names one result and one ordered event suffix after the
shared live preflight. When Section 8.2 rebases in the same transition, exactly one `clockAdjusted`
event prefixes that listed suffix; without a rebase, the listed array is the complete array. Any pair
not listed SHALL return `rejected(.invalidTransition)` with zero event, effect, publication, or write.
The command revision gate runs before this matrix: mismatch returns `rejected(.staleRevision)`.
After revision but before state/intent dispatch, a boundary-bearing `openCheckIn` or `deadlineFired`
first enforces trigger/token discriminant congruence, then returns `duplicateBoundary` or
`staleBoundary` for a consumed/non-installed token in every state. Only an installed, congruent live
token proceeds to due-time arbitration. This precedence makes queued platform callbacks classify
consistently after pause or another boundary transition.

A focusing `pause` has an additional due-boundary preflight using the command's same
normalized live instant from Section 8.2. If any installed phase or scheduled-check-in boundary is
due after monotonic reconciliation, the earliest tie-ranked boundary wins exactly as in Section 8.5
and the command produces that boundary's check-in transition instead of a paused state. Only when no
boundary is due may pause freeze a timed remainder, which is therefore always at least one second. A
deadline callback racing the pause produces the same canonical outcome regardless of actor arrival
order; changing the wall clock alone cannot make the pause preflight due.

The same supersession rule applies to every valid non-terminal live intent that would otherwise
leave live: a manual focus `openCheckIn`, focus `requestBreak`, or break `endBreak` produces the
earliest winning Section 8.5 boundary transition when one is due. A boundary-bearing `openCheckIn`
continues to obey callback identity: its winning token commits, while a later/lower installed token
returns `earlierBoundaryPending` and leaves the actual winner installed. A due automatic break end
therefore retains its automatic completion cue even when `endBreak` was the arriving command.
Configuration uses the next paragraph; thought parking uses its input-preserving rule below.
Terminal review intents use the separate logical-winner materialization rule below rather than
opening an intermediate check-in or re-entry flow.

Every configuration intent in focusing/breaking uses the same normalized due-boundary preflight. If a
phase, scheduled check-in, or break-end boundary is due, the winning boundary transition supersedes
the configuration command: the configuration is not changed, no `configurationChanged` event is
emitted, and the exact boundary suffix (optionally after `clockAdjusted`) commits. Only when no
boundary is due does the configuration suffix run and leave a positive live remainder.

Any command that must measure or leave a live state runs the live-observation preflight after revision
and boundary-token shape/duplicate/stale classification but before due-time or matrix behavior. This
includes focus `pause`, valid `openCheckIn`, `requestBreak`, `parkThought`, `stop`, and `reconcileTime`, plus break
`endBreak`, `parkThought`, `stop`, and `reconcileTime`; every configuration intent in a live focus or break also
normalizes before it derives any replacement schedule. For `reconcileTime`, this preflight applies only to `.live`,
`.wake`, and `.deadlineFired`; `.relaunch` explicitly bypasses monotonic preflight and uses only the
persisted Section 8.3 recovery algorithm. For a live state, a non-finite
`context.instant.wallNow` returns `.failed(.nonFiniteWallObservation)` before canonicalization,
creates no candidate/event/effect, and the actor maps it to the same-named engine failure with zero
writes. With a finite current wall, missing observation enters
`recoveryNeeded(.missingLiveProjection)`; a mismatched projection token enters
`recoveryNeeded(.staleLiveProjection)`; a non-finite raw projection anchor enters
`recoveryNeeded(.arithmeticOverflow)` before anchor canonicalization; a finite raw projection anchor
whose canonical second differs from the live state's wall anchor enters
`recoveryNeeded(.inconsistentLiveProjectionAnchor)`; negative elapsed enters
`recoveryNeeded(.negativeMonotonicElapsed)`; checked date/duration/total overflow enters
`recoveryNeeded(.arithmeticOverflow)`. The requested intent is not also applied. The transition emits
only `clockRecoveryNeeded(reason)`, clears live boundary/date/projection values, cancels the prior
notification winner, and stores the last trustworthy frozen timing as described in Section 9.

A live `parkThought` first validates/normalizes the text and thought limit, then runs that same
preflight. With no due boundary it appends the thought, copies the returned live-commit
materialization, and remains live. If a boundary is due, the one commit appends the thought and then applies the winning Section
8.5 transition; after any `clockAdjusted` prefix, event order is `thoughtParked` followed by the
winner's ordinary suffix. A recovery decision does not append the thought. This preserves user input
without allowing a due live state or clock jump to be committed behind an unchanged deadline.

A valid explicit terminal intent—`stop(choice)` or
`resolveActiveSessionConflict(.replaceAndReview, validDraft)`—is never discarded merely because a
live boundary is due. With no due boundary it copies `NonBoundaryExitMaterialization` and enters
review. With a due boundary it uses `admitBoundary` only to select the earliest logical winner and
copies that winner's focus/break accumulator from `BoundaryExitMaterialization`; it does not construct
the winner's check-in/re-entry state, consume it into `lastConsumedBoundaryToken`, or emit
`phaseElapsed`, `checkInOpened`, `breakEnded`, or `reentryPresented`. It clears every live
deadline/token/projection as part of review, and the ordinary terminal suffix is complete:
`sessionStopRequested, reviewStarted` or `sessionReplacementRequested, reviewStarted`, after any
`clockAdjusted` prefix. As required by the canonical review rule, draft `endedAt` is the later of
`startedAt` and `NormalizedLiveTiming.expectedWallNow`; event envelopes separately use
`observedWallNow`. Focused/break totals stop at the logical winning due instant. A winner-time
recovery decision still enters recovery and does not apply the terminal intent. Invalid replacement
payloads and resume/cancel conflict choices remain deterministic rejection/no-change paths and do
not measure live time.

### 7.1 Primary lifecycle matrix

| State | Intent | Exact outcome | Ordered event payload cases |
|---|---|---|---|
| idle | prepare(valid draft) | prepared; new session ID; event sequence 1 | sessionPrepared |
| idle | reconcileTime | noChange observationIrrelevant | none |
| prepared | updatePrepared(changed valid draft) | prepared | planUpdated, configurationChanged when applicable |
| prepared | updatePrepared(identical draft) | noChange alreadyInRequestedState | none |
| prepared | start(valid non-empty plan) | focusing first policy phase | sessionStarted, phaseStarted |
| prepared | start(invalid task/action) | rejected invalidPlan | none |
| prepared | reconcileTime | noChange observationIrrelevant; relaunch restores unchanged | none |
| focusing | pause, no boundary due | paused after accruing live focus with positive timed remainder or `.openEnded` | phasePaused |
| focusing | pause, boundary due | winning phase/scheduled boundary check-in; pause is superseded | same events as the winning Section 8.5 boundary |
| focusing | openCheckIn(manual), no boundary due | checkingIn with `.resumeSuspended` | checkInOpened |
| focusing | openCheckIn(valid scheduled token that wins) | checkingIn with `.resumeSuspended` | checkInOpened |
| focusing | openCheckIn(valid phase token that wins) | checkingIn with `.startPhase(exact continuation)` | phaseElapsed, checkInOpened |
| focusing | openCheckIn(valid later/lower installed token while an earlier boundary is due) | noChange earlierBoundaryPending; all tokens remain installed | none |
| focusing | manual openCheckIn/requestBreak, boundary due | winning phase/scheduled boundary check-in; arriving intent is superseded | same events as the winning Section 8.5 boundary |
| focusing | requestBreak, no boundary due | breaking after freezing focus | breakStarted |
| focusing | parkThought(valid), no boundary due | focusing after live preflight | thoughtParked |
| focusing | parkThought(valid), boundary due | thought appended, then winning phase/scheduled check-in | thoughtParked, then the winning Section 8.5 events |
| focusing | stop(choice), no boundary due | reviewing from non-boundary exit materialization | sessionStopRequested, reviewStarted |
| focusing | stop(choice), boundary due | reviewing with totals stopped at logical winner; no boundary-flow event | sessionStopRequested, reviewStarted |
| focusing | reconcileTime | Section 8 projection/reconciliation outcome | Section 8 |
| paused | resume | focusing from stored positive timed remainder or fresh open-ended anchor; elapsed was already committed | phaseResumed |
| paused | openCheckIn(manual/pauseOffer) | checkingIn with paused disposition | checkInOpened |
| paused | openCheckIn(scheduled/phaseBoundary) | rejected duplicateBoundary or staleBoundary by token precedence | none |
| paused | requestBreak | breaking with paused resume target | breakStarted |
| paused | parkThought(valid) | paused | thoughtParked |
| paused | stop(choice) | reviewing | sessionStopRequested, reviewStarted |
| paused | reconcileTime | noChange observationIrrelevant; non-live relaunch restores unchanged | none |
| checkingIn | respondToCheckIn | exact response matrix in Section 7.3 | Section 7.3 |
| checkingIn | parkThought(valid) | checkingIn | thoughtParked |
| checkingIn | stop(choice) | reviewing | sessionStopRequested, reviewStarted |
| checkingIn | reconcileTime | noChange observationIrrelevant; suspended time never advances and relaunch restores unchanged | none |
| breaking | endBreak, no boundary due | reentering after accruing break; early completion is silent | breakEnded, reentryPresented |
| breaking | endBreak, boundary due | reentering from automatic break winner | breakEnded, reentryPresented |
| breaking | parkThought(valid), no boundary due | breaking after live preflight | thoughtParked |
| breaking | parkThought(valid), boundary due | thought appended, then reentering | thoughtParked, breakEnded, reentryPresented |
| breaking | stop(choice), no boundary due | reviewing after non-boundary break accumulation | sessionStopRequested, reviewStarted |
| breaking | stop(choice), boundary due | reviewing with break total stopped at logical winner; no boundary-flow event | sessionStopRequested, reviewStarted |
| breaking | reconcileTime(deadline due) | reentering | breakEnded, reentryPresented |
| breaking | reconcileTime(not due) | Section 8 outcome | clockAdjusted or noChange |
| reentering | acceptRevisedAction(valid) | focusing or paused by stored disposition | actionRevised only if changed; phaseResumed only when focusing |
| reentering | acceptRevisedAction(invalid) | rejected invalidText(first/revised action) | none |
| reentering | requestBreak | breaking | breakStarted |
| reentering | parkThought(valid) | reentering | thoughtParked |
| reentering | stop(choice) | reviewing | sessionStopRequested, reviewStarted |
| reentering | reconcileTime | noChange observationIrrelevant; non-live relaunch restores unchanged | none |
| reviewing | updateReviewReflection(changed valid value) | reviewing | reviewReflectionUpdated |
| reviewing | updateReviewReflection(same normalized value) | noChange alreadyInRequestedState | none |
| reviewing | updateReviewReflection(invalid) | rejected invalidText(reflection) | none |
| reviewing | finalizeReview | completed; plan cleared; replacement preserved separately; summary copies the frozen review-draft `endedAt` | sessionCompleted |
| reviewing | reconcileTime | noChange observationIrrelevant | none |
| completed | prepare(valid draft) | prepared with new session ID and event sequence 1 | sessionPrepared |
| completed | reconcileTime | noChange observationIrrelevant | none |
| recoveryNeeded | recoverClock(valid choice) | Section 9 outcome | clockRecovered plus reviewStarted when applicable |
| recoveryNeeded | recoverClock(invalid choice) | rejected invalidRecoveryChoice | none |
| recoveryNeeded | stop(choice) | reviewing | sessionStopRequested, reviewStarted |
| recoveryNeeded | reconcileTime | noChange observationIrrelevant | none |

`acceptRevisedAction(input)` normalizes and validates `input`, then replaces
`SessionSnapshot.plan.firstAction` with that exact normalized value before constructing the resumed
focus or paused candidate. It emits `actionRevised` if and only if the normalized value differs from
the previous `plan.firstAction`; the privacy-safe event carries no text. The accepted proposal is not
retained as a second source of truth after leaving re-entry. When `finalizeReview` clears the plan,
`SessionSummary.task` and `SessionSummary.finalAction` copy the reviewing snapshot's exact normalized
`plan.task` and latest `plan.firstAction`, respectively; a pending replacement draft never supplies
either field for the old summary.

### 7.2 Cross-state configuration and conflict rules

Configuration intents are allowed in prepared, focusing, paused, checking-in, breaking,
re-entering, and reviewing. A changed value commits the same lifecycle state and emits one
`configurationChanged` event. An identical value returns `noChange(.alreadyInRequestedState)`.
The shared live-boundary supersession rule above precedes both changed/identical classification.
They are invalid in idle/completed/recovery. A schedule change while focusing first performs the
Section 8.2 live normalization, then replaces the next scheduled boundary from the normalized commit
time with the full interval as `trustedRemaining`; while suspended it clears the boundary and applies
the full interval on resume. If normalization rebases, event order is `clockAdjusted`, then
`configurationChanged`; the effect planner compares the original previous winner directly with the
final replacement boundary, so it never schedules an intermediate rebased boundary.

“While suspended” covers every non-live holder of cadence state. Paused, resume-suspended check-in,
break resume-target, and re-entry resume-target values replace their captured remainder with the full
new interval returned by `SessionTimeKernel.materializeScheduledRemainder`, or nil for `manualOnly`.
A live break changes only the cadence inside its already-frozen `resumeTarget` through that same
value and keeps its break deadline/token. A phase-boundary `.startPhase` check-in has `suspended == nil`:
its schedule change always clears `phaseBoundaryScheduledCheckInRemaining`. On resolution, nil plus
the current interval schedule installs one full new interval; nil plus `manualOnly` installs none.
Thus an old-policy remainder can never survive a schedule change or violate the new interval bound.

`prepare` or `start` in focusing, paused, checking-in, breaking, re-entering, reviewing, or recovery
returns `rejected(.activeSessionExists)`. `prepare` carries the attempted draft; `start` carries no
replacement and therefore requires a valid replacement draft only if the later choice is
`replaceAndReview`. Conflict resolution is valid only in those states:

| Choice | Replacement | Outcome | Events |
|---|---|---|---|
| resumeCurrent | nil | noChange resumeCurrentSelected | none |
| resumeCurrent | non-nil | rejected replacementDraftNotAllowed | none |
| cancel | nil | noChange conflictCancelled | none |
| cancel | non-nil | rejected replacementDraftNotAllowed | none |
| replaceAndReview | nil | rejected replacementDraftRequired | none |
| replaceAndReview | invalid draft | rejected invalidPlan | none |
| replaceAndReview | valid draft, not already reviewing | reviewing old session with replacement draft; live sources use the exact terminal due/no-due rule above | sessionReplacementRequested, reviewStarted |
| replaceAndReview | valid draft, already reviewing | reviewing with replacement draft replaced | sessionReplacementRequested |

Finalizing the old review always commits `completed`. The UI or app model then submits a separate
`prepare(pendingReplacementDraft)` command. That command produces a new session ID, revision, and
session-local event sequence; no reducer transition completes and prepares in one transaction.

### 7.3 Check-in response matrix

Every check-in freezes focus first. It never retains an expired live deadline.

| Continuation | Response | Outcome | Ordered events |
|---|---|---|---|
| resumeSuspended | continueFocus | restore stored focusing/paused disposition | checkInResolved, phaseResumed only when focusing |
| resumeSuspended | skip | restore stored disposition; resolve occurrence without penalty | checkInResolved, phaseResumed only when focusing |
| resumeSuspended | dismiss | restore stored disposition; resolve occurrence without penalty | checkInResolved, phaseResumed only when focusing |
| resumeSuspended | makeSmaller | reentering with deterministic editable proposal | checkInResolved, reentryPresented |
| resumeSuspended | detour(nil) | remain checkingIn | detourReported |
| resumeSuspended | detour(valid note) | append note as parked thought; remain checkingIn | detourReported, thoughtParked |
| resumeSuspended | takeBreak | breaking with suspended target | checkInResolved, breakStarted |
| startPhase(next) | continueFocus | focusing next/repeated exact phase | checkInResolved, phaseStarted |
| startPhase(next) | skip | paused at full next phase; no automatic focus | checkInResolved, phasePaused |
| startPhase(next) | dismiss | paused at full next phase; no automatic focus | checkInResolved, phasePaused |
| startPhase(next) | makeSmaller | reentering with paused full next phase | checkInResolved, reentryPresented |
| startPhase(next) | detour(nil) | remain checkingIn | detourReported |
| startPhase(next) | detour(valid note) | append note as parked thought; remain checkingIn | detourReported, thoughtParked |
| startPhase(next) | takeBreak | breaking with paused full next phase | checkInResolved, breakStarted |

For a scheduled occurrence, Continue/Skip/Dismiss schedule the next full configured interval after
focus resumes. A manual occurrence preserves the captured remaining scheduled interval. Manual
check-in never resets cadence. For a phase-boundary occurrence, admission captures a strictly future
scheduled check-in as `phaseBoundaryScheduledCheckInRemaining`; every response that creates a
next-phase resume/paused/re-entry/break target preserves that exact remainder. If phase and scheduled
boundaries are due at the same instant, phase wins, the captured field is nil, the scheduled token is
cleared as irrelevant, and resolving to an interval-cadence target installs one full configured
interval. If the phase boundary is earlier but observation occurs after the later scheduled check-in
is also due, phase still wins, the overdue scheduled occurrence is cleared, and resolution likewise
installs one full configured interval. Under `manualOnly`, nil installs nothing. Detour responses that
remain checking-in preserve the same field. Thus no phase-boundary path needs a zero cadence remainder,
silently loses a future scheduled occurrence, or fabricates a positive remainder for an occurrence
that is already due.

An invalid detour note returns `invalidText(.detourNote)`. A valid non-nil note consumes
`context.generatedThoughtID`, obeys the same 1,000-thought limit and deterministic ordering as
`parkThought`, and remains visible through break/re-entry. Every break captures the current proposed
action; ending a break creates `ReentryState` with that exact action, including when the break began
from an existing re-entry flow.

## 8. Timing, accumulation, and reconciliation

### 8.1 Accumulation

- While focusing, display focus total is committed `accumulatedFocusSeconds` plus
  `elapsedBeforeAnchorSeconds` plus the paired canonical elapsed since anchor defined in Section 2;
  only the since-anchor
  increment is capped by the current positive `timingAtAnchor` budget rather than the policy's
  original duration.
- While breaking, display break total is committed `accumulatedBreakSeconds` plus
  `elapsedBeforeAnchorSeconds` plus the same paired canonical elapsed since anchor; only the since-anchor
  increment is capped by the current positive break `timingAtAnchor` budget.
- Pause, check-in, re-entry, review, completed, and recovery accrue neither focus nor break time.
- Any non-boundary committed transition out of focusing/breaking first adds the observation-projected
  elapsed exactly once with checked `UInt64` addition, then removes the live projection token. A due
  boundary instead copies the kernel's exact winner-time exit materialization.
- Resuming a suspended open-ended focus/break starts with `elapsedBeforeAnchorSeconds == 0` at the
  new anchor because all pre-suspension elapsed is already in the committed accumulator. Resuming a
  timed value likewise uses only its stored positive remainder; neither path re-adds suspended time.
- A stored timed remainder is the exact positive integral budget left after subtracting the paired
  canonical elapsed. It and the accumulated elapsed use the same canonical-second interval, so
  materialization cannot disagree with the installed deadline.
- A phase/deadline boundary adds exactly the remaining timed duration, consumes its token, and emits
  one boundary event. A scheduled check-in that wins before a later phase adds elapsed only through
  its own due instant and suspends the timed phase with the exact positive difference, even when the
  later phase is also overdue at observation. It never invents multiple overdue phases.

Scheduled check-in suspension uses the same exact positive canonical-second difference. Pause,
check-in, break, and re-entry retain
the captured remaining scheduled seconds but no live check-in date/token. Resuming focus after a
manual occurrence or ordinary suspension reinstalls that remainder; resolving a scheduled occurrence
or changing cadence installs one full configured interval. `manualOnly` installs nothing.

### 8.2 In-process wall/monotonic reconciliation

Atom 3.3 is executed before Atom 3.2. It introduces the callable projector and an internal pure time
kernel that can be tested without a reducer stub:

~~~swift
public enum SessionProjector {
  public static func project(
    snapshot: SessionSnapshot,
    instant: SessionInstant
  ) throws(ProjectionError) -> SessionProjection
}

internal struct NormalizedLiveTiming: Equatable, Sendable {
  let observedWallNow: SessionTimestamp
  let expectedWallNow: SessionTimestamp
  let normalizedDueInstant: SessionTimestamp
  let phaseOrBreakDeadline: SessionTimestamp?
  let scheduledCheckInAt: SessionTimestamp?
  let admissionAdjustment: ClockAdjustmentEvent?
  let nonBoundaryExitMaterialization: NonBoundaryExitMaterialization?
  let liveCommitMaterialization: LiveCommitMaterialization?
}

internal enum NonBoundaryExitMaterialization: Equatable, Sendable {
  case focus(
    accumulatedFocusSeconds: UInt64,
    suspendedTiming: PausedTiming,
    scheduledCheckInRemaining: CheckInRemainingSeconds?
  )
  case breakState(accumulatedBreakSeconds: UInt64)
}

internal struct LiveCommitMaterialization: Equatable, Sendable {
  let wallAnchor: SessionTimestamp
  let elapsedBeforeAnchorSeconds: UInt64
  let timingAtAnchor: PausedTiming
  let phaseOrBreakDeadline: SessionTimestamp?
  let scheduledCheckInAt: SessionTimestamp?
  let scheduledCheckInRemaining: CheckInRemainingSeconds?
  let adjustment: ClockAdjustmentEvent?
}

internal enum LiveTimeDecision: Equatable, Sendable {
  case normalized(NormalizedLiveTiming)
  case recovery(RecoveryReason)
  case failure(ReductionFailure)
}

internal enum BoundaryAdmissionDecision: Equatable, Sendable {
  case noneDue
  case boundaryNotDue(token: BoundaryToken, dueAt: SessionTimestamp, observedAt: SessionTimestamp)
  case earlierBoundaryPending
  case winner(BoundaryWinnerDecision)
  case recovery(RecoveryReason)
}

internal struct BoundaryWinnerDecision: Equatable, Sendable {
  let token: BoundaryToken
  let dueAt: SessionTimestamp
  let exitMaterialization: BoundaryExitMaterialization
  let scheduledCadence: ScheduledCadenceAdmission
}

internal enum BoundaryExitMaterialization: Equatable, Sendable {
  case phase(accumulatedFocusSeconds: UInt64)
  case scheduledCheckIn(
    accumulatedFocusSeconds: UInt64,
    suspendedTiming: PausedTiming
  )
  case breakEnd(accumulatedBreakSeconds: UInt64)
}

internal enum ScheduledCadenceAdmission: Equatable, Sendable {
  case notApplicable
  case manualOnly
  case preserve(CheckInRemainingSeconds)
  case resetAfterPhaseCollision
  case resetAfterSupersededScheduledOccurrence
  case resetAfterScheduledOccurrence
}

internal enum ScheduledCadenceSeed: Equatable, Sendable {
  case manualOnly
  case fullInterval(CheckInMinutes)
  case captured(CheckInRemainingSeconds)
}

internal enum BreakEntryTimingSeed: Equatable, Sendable {
  case choice(BreakDuration)
  case saved(PausedTiming)
}

internal enum LiveEntryRequest: Sendable {
  case focus(
    sessionID: UUID,
    targetRevision: UInt64,
    nextBoundaryOccurrence: UInt64,
    wallNow: Date,
    projectionToken: UUID,
    phaseID: SessionPhaseID,
    timing: PausedTiming,
    cadence: ScheduledCadenceSeed
  )
  case breakState(
    sessionID: UUID,
    targetRevision: UInt64,
    nextBoundaryOccurrence: UInt64,
    wallNow: Date,
    projectionToken: UUID,
    timing: BreakEntryTimingSeed
  )
}

internal enum LiveEntryDecision: Equatable, Sendable {
  case materialized(LiveEntryMaterialization)
  case failure(ReductionFailure)
}

internal enum LiveEntryMaterialization: Equatable, Sendable {
  case focus(FocusEntryMaterialization)
  case breakState(BreakEntryMaterialization)
}

internal struct FocusEntryMaterialization: Equatable, Sendable {
  let wallAnchor: SessionTimestamp
  let timingAtAnchor: PausedTiming
  let projectionToken: UUID
  let phaseEndsAt: SessionTimestamp?
  let phaseBoundaryToken: BoundaryToken?
  let scheduledCheckIn: ScheduledCheckInBoundary?
  let nextBoundaryOccurrence: UInt64
}

internal struct BreakEntryMaterialization: Equatable, Sendable {
  let wallAnchor: SessionTimestamp
  let timingAtAnchor: PausedTiming
  let projectionToken: UUID
  let endsAt: SessionTimestamp?
  let boundaryToken: BoundaryToken?
  let nextBoundaryOccurrence: UInt64
}

internal struct ScheduledCheckInReplacementRequest: Equatable, Sendable {
  let sessionID: UUID
  let targetRevision: UInt64
  let nextBoundaryOccurrence: UInt64
  let wallAnchor: SessionTimestamp
  let schedule: CheckInSchedule
}

internal enum ScheduledCheckInReplacementDecision: Equatable, Sendable {
  case materialized(
    boundary: ScheduledCheckInBoundary?,
    nextBoundaryOccurrence: UInt64
  )
  case failure(ReductionFailure)
}

internal enum SessionTimeKernel {
  static func reconcileLive(
    snapshot: SessionSnapshot,
    instant: SessionInstant
  ) -> LiveTimeDecision

  static func reconcileRelaunch(
    snapshot: SessionSnapshot,
    wallNow: Date
  ) -> LiveTimeDecision

  static func admitBoundary(
    snapshot: SessionSnapshot,
    timing: NormalizedLiveTiming,
    observedToken: BoundaryToken?
  ) -> BoundaryAdmissionDecision

  static func materializeLiveEntry(
    _ request: LiveEntryRequest
  ) -> LiveEntryDecision

  static func replaceScheduledCheckIn(
    _ request: ScheduledCheckInReplacementRequest
  ) -> ScheduledCheckInReplacementDecision

  static func materializeScheduledRemainder(
    _ schedule: CheckInSchedule
  ) -> CheckInRemainingSeconds?
}
~~~

The kernel validates/reconciles live and relaunch clocks, computes normalized due values, selects a boundary decision,
and returns both admission-only and live-commit materialization values. It creates no candidate snapshot, event envelope,
effect, publication, or write. Atom 3.2 consumes these decisions and remains the sole owner of matrix
dispatch and ordered reduction events/effects. Token allocation helpers owned by 3.3 are likewise
pure value functions over the supplied session/revision/occurrence inputs. New live-entry and
live-schedule replacement arithmetic is exposed through the typed decisions above; it is not prose-only
work left for Atom 3.2.

`admissionAdjustment` is non-nil only when absolute drift exceeds two seconds; it governs no-change,
leaving-live, and boundary admission. `nonBoundaryExitMaterialization` and
`liveCommitMaterialization` are non-nil only when no installed boundary is due. The former contains
the exact checked observation-based accumulator for a command that leaves live. Its `.focus` case
also contains the positive/open-ended suspended phase timing and exact positive scheduled cadence
remainder (or nil for manual-only); its `.breakState` case contains the break accumulator because the
existing break resume target already owns its frozen focus timing/cadence. The
latter exists when the state can lawfully remain live and contains every value Atom 3.2 needs to
construct that candidate without date/duration subtraction: the observed canonical anchor, checked
projected/commit timing, positive/open-ended remainder, shifted deadline, scheduled date/remainder, and a
factual adjustment. Its adjustment is non-nil for every nonzero integral drift, including ±1 and ±2,
and nil only at zero drift. Atom 3.2 selects this value for a command that commits and remains live;
it never recomputes drift or remaining time.
Checked overflow while constructing either normalized or materialization values returns
`.recovery(.arithmeticOverflow)` for a finite live observation; it never masquerades as a nil
materialization. Both materialization fields being nil means only that a due boundary must be
handled; the later observation's accumulator is deliberately not computed and cannot preempt a
valid earlier winner with an irrelevant overflow.

`BoundaryWinnerDecision.exitMaterialization` is calculated at the winning boundary's normalized
`dueAt`, never at the later observation. A phase winner returns `.phase` with the focus accumulator
advanced exactly through phase exhaustion. A break winner returns `.breakEnd` with the break
accumulator advanced exactly through break exhaustion. A scheduled-check-in winner returns
`.scheduledCheckIn` with focus accumulated only through its due instant and `.timed(exactPositiveRemainder)`
when a later timed phase boundary exists, or `.openEnded` for open-ended focus. This remains true when
observation/relaunch occurs after both the scheduled and later phase deadlines. The materialization
case must match `token.kind`; Atom 3.2 copies it and performs no timestamp or duration subtraction.
Checked accumulator, duration, or canonical-date overflow while constructing the winner returns
`.recovery(.arithmeticOverflow)` from boundary admission and produces no partial winner.

`BoundaryWinnerDecision.scheduledCadence` is exhaustive: break-end uses `.notApplicable`; a phase
winner under manual cadence uses `.manualOnly`; a phase winner whose later scheduled due date is
still strictly later than `normalizedDueInstant` uses `.preserve(exactPositiveRemainder)`; an
equal-time phase/scheduled collision uses `.resetAfterPhaseCollision`; a phase winner whose strictly
later scheduled occurrence is already due at `normalizedDueInstant` uses
`.resetAfterSupersededScheduledOccurrence`; and a scheduled-check-in winner uses
`.resetAfterScheduledOccurrence`. Thus Atom 3.2 can populate/clear the phase-boundary cadence field
without subtracting timestamps. Every reset case installs the then-current full interval only when
the later response returns to an interval-cadence focus target; manual-only installs nothing.

`reconcileRelaunch` implements Section 8.3 without requiring a reducer: it returns `.normalized`
with the canonical wall delta and preserved deadlines for a valid restore, `.recovery` for an
ambiguous/future anchor or checked wall-delta/date/total overflow, or
`.failure(.nonFiniteWallObservation)` only for a non-finite current wall. Atom 3.2 alone maps
that value plus `admitBoundary` into `liveProjectionRestored`, boundary, or recovery candidates and
event envelopes. A normalized relaunch sets observed/expected/normalized due instant to the current
canonical wall, has nil admission/materialization adjustment, and returns complete restore
materialization only when no boundary is due; relaunch never emits `clockAdjusted`.

~~~text
function reconcile_live(snapshot, context):
  require context.instant.wallNow is finite
  require context.instant.liveProjection is present
  live = context.instant.liveProjection
  require live.projectionToken == current live projection token
  require live.rawWallAtProjectionAnchor is finite
  require canonicalSecond(live.rawWallAtProjectionAnchor) == liveState.wallAnchor
  require live.monotonicElapsedSinceAnchor >= 0

  observedWallNow = canonicalSecond(context.instant.wallNow)
  expectedWallNow = canonicalSecond(
    live.rawWallAtProjectionAnchor + live.monotonicElapsedSinceAnchor
  )
  drift = observedWallNow - expectedWallNow

  if abs(drift) <= 2 seconds:
    normalizedDueInstant = expectedWallNow
    normalizedPhaseOrBreakDeadline = oldDeadline
    normalizedScheduledCheckInAt = oldScheduledCheckInAt
    admissionAdjustment = nil
  else:
    normalizedDueInstant = observedWallNow
    normalizedPhaseOrBreakDeadline = oldDeadline.map { $0 + drift }
    normalizedScheduledCheckInAt = oldScheduledCheckInAt.map { $0 + drift }
    admissionAdjustment = clockAdjusted(
      oldDeadline, normalizedPhaseOrBreakDeadline,
      oldScheduledCheckInAt, normalizedScheduledCheckInAt, drift
    )

  if any normalized installed boundary is due:
    return normalized pair plus admissionAdjustment,
           nil non-boundary exit, and nil live-commit materialization

  elapsedSeconds = canonicalPairedElapsedSeconds(
    live.rawWallAtProjectionAnchor,
    live.monotonicElapsedSinceAnchor
  )
  elapsedToCommitSeconds = checked(liveState.elapsedBeforeAnchorSeconds + elapsedSeconds)
  accumulatedSecondsAfterLeavingLive = checked(
    snapshot.activeAccumulator + elapsedToCommitSeconds
  )
  nonBoundaryExitMaterialization = checked_non_boundary_exit_values(
    snapshot,
    normalizedDueInstant,
    elapsedToCommitSeconds,
    accumulatedSecondsAfterLeavingLive
  )  // focus includes exact suspended timing/cadence; break includes its accumulator
  liveCommitMaterialization = checked_live_commit_values(
    observedWallNow,
    elapsedToCommitSeconds,
    oldTimingAndDeadlines,
    drift
  )  // adjustment is non-nil iff drift != 0
  return normalized pair plus admissionAdjustment and both exact non-boundary materializations

function admit_boundary(snapshot, normalized):
  dueCandidates = installed candidates with dueAt <= normalized.normalizedDueInstant
  if dueCandidates is empty:
    if observedToken exists: return boundaryNotDue(observedToken, its dueAt, normalizedDueInstant)
    return noneDue
  winner = earliest dueAt, ranking phase before scheduled check-in before break-end on equality
  if observedToken exists and observedToken != winner.token: return earlierBoundaryPending
  exitMaterialization = checked_boundary_exit_at_winner_due(snapshot, winner)
  scheduledCadence = checked_cadence_decision(snapshot, normalized, winner)
  if either checked calculation overflows: return recovery(arithmeticOverflow)
  return winner(token, dueAt, exitMaterialization, scheduledCadence)
~~~

Exactly +2 or -2 seconds is no rebase; only a greater absolute divergence rebases. In-process due
checks always use the returned normalized instant and dates, never raw `wallNow` against unreconciled
deadlines. If rebase accompanies another valid transition, `clockAdjusted` is the first event and the
requested transition continues in the same commit against rebased values. If a boundary callback is
not due after a required rebase, the transition commits only `clockAdjusted`, retains the boundary,
and reschedules the notification winner; without a rebase, the same early callback is rejected as
`boundaryNotDue`. A `reconcileTime(.live/.wake)` with rebase and no normalized due boundary commits
only `clockAdjusted`; if a normalized boundary is due, `clockAdjusted` prefixes the one winning
boundary transition in the same commit. Without a rebase and without a due boundary it is
`noChange(.observationIrrelevant)`.

Whenever a valid preflight command commits and leaves the candidate live, Atom 3.2 copies the
accepted `liveCommitMaterialization` before commit: its
checked elapsed total, observed wall anchor, positive/open-ended timing, deadline, and scheduled
date/remainder are already complete. The reducer only issues `context.generatedProjectionToken` and
copies those values; it performs no clock subtraction. Open-ended timing and nil deadline remain,
and a scheduled boundary exists only with the exact positive returned remainder.
The relational validator enforces the elapsed/remaining/deadline relationship. A non-boundary
transition that leaves focus copies the `.focus` accumulator, suspended timing, and captured
scheduled remainder; one that leaves break copies the `.breakState` accumulator and retains the
break's already-frozen resume target. Neither needs a new projection token. A boundary transition
instead copies its
`BoundaryExitMaterialization`, including a scheduled winner's exact positive suspended phase
remainder. The reducer adds/subtracts no elapsed or duration values itself. Thus any committed valid
observation becomes the next recovery baseline without accruing time past the logical winner;
recovery never discards progress that a prior rebase/configuration commit trusted.

If a command will commit and remain live, any nonzero integral drift is materialized as a rebase even
when its magnitude is within the ordinary two-second no-change tolerance. This emits the one
`liveCommitMaterialization.adjustment` as the one `clockAdjusted` prefix and synchronizes the fresh projection token's paired raw wall anchor with the
candidate's canonical wall anchor. The ±2-second tolerance applies only when returning no-change or
when leaving live state without installing a new projection baseline.

In that paragraph, every `wallNow` means `canonicalSecond(context.instant.wallNow)`. Because the old
anchor/deadline, elapsed increment, observed wall, and drift are all integral seconds, the canonical
candidate deadline rebuilt as `wallAnchor + remainingSeconds` is exactly the normalized old deadline
shifted by drift and exactly the `clockAdjusted.newPhaseOrBreakDeadline`. A scheduled boundary must
likewise satisfy `dueAt == wallAnchor + trustedRemaining.value` after materialization. Relaunch uses
the exact canonical-second wall difference, so preserving a normalized UTC deadline
and rebuilding from the canonical remaining value are identical operations.

Rebase never adds focus or break duration. It moves the phase/break deadline and scheduled check-in
date by the same drift while preserving their tokens. Negative monotonic elapsed, date/duration
overflow, or a missing/stale live projection enters the exact recovery path without silent clamping. A
persisted deadline before its anchor is an invalid snapshot and fails startup as
`corruptSnapshot(.invalidDeadline)`, not as a fabricated recovery state.

### 8.3 Wake and relaunch

- Wake with `normalizedDueInstant < normalizedDueAt` follows Section 8.2: it is no-change when no
  rebase is needed, or an adjustment-only materializing commit when rebase is needed. The continuous
  monotonic observation includes the sleep interval; raw UTC deadline comparison never decides it.
- Wake with `normalizedDueAt <= normalizedDueInstant` consumes at most one winning boundary token and
  opens a check-in/re-entry; when rebase is also needed, `clockAdjusted` prefixes those boundary
  events in the same commit. It never auto-chains additional phases.
- Relaunch validates the stored snapshot before time arithmetic. A non-live state restores without
  advancing time and ignores the supplied wall observation. For a live state, a non-finite `wallNow`
  returns `.failed(.nonFiniteWallObservation)` with zero events/effects/writes because no canonical
  recovery timestamp can be created. Otherwise, if `wallNow < lastWallObservationAt - 2 seconds` or
  the live state's persisted `wallAnchor > canonicalSecond(wallNow)` by any positive amount, enter
  `wallClockAmbiguousAfterRelaunch` and freeze at the last committed elapsed/remainder. There is no
  future-anchor tolerance. Otherwise, timed state uses the boundary-admission rule and open-ended
  state adds the exact nonnegative canonical wall delta. Arithmetic/date overflow enters
  `arithmeticOverflow`.
- A live relaunch before its winning boundary commits one `liveProjectionRestored` event: it moves
  the exact nonnegative canonical wall delta into `elapsedBeforeAnchorSeconds`, subtracts it from a timed
  `timingAtAnchor`, anchors at canonical `wallNow`, installs `context.generatedProjectionToken`,
  preserves the equivalent UTC deadlines and boundary tokens, refreshes a scheduled boundary's
  `trustedRemaining` from its exact positive normalized canonical-second difference, and increments revision once. It does not
  announce a new focus or add the elapsed to accumulated totals until the later transition out of that
  live phase/break.
- Timezone and DST changes do not affect UTC anchors.
- A token equal to `lastConsumedBoundaryToken` is duplicate. A token from another session, an
  obsolete occurrence, or one that is not byte-for-byte equal to the currently installed token for
  that boundary kind is stale. An installed token remains valid across unrelated later revisions;
  its `sourceRevision` continues to identify the revision that created it. Duplicate and stale
  observations both cause zero writes.
- `lastConsumedBoundaryToken` is historical and is exempt from installed-token current-phase
  equality. It must still match the current session, retain its valid occurrence/source revision,
  and obey its own discriminant (`phase` has a non-nil historical phase ID; scheduled-check-in and
  break-end have nil phase ID). It remains until the next boundary is consumed and replaces it, or a
  new session resets it. Continuing from an entry phase therefore does not invalidate the consumed
  entry token and a repeated callback remains duplicate rather than stale.

### 8.4 Cadence token derivation

When publishing a token at new revision `R`:

1. Determine the complete token set required by the candidate before allocating any occurrence.
   Allocation order is phase, scheduled check-in, then break-end; omitted kinds consume no value.
2. Preflight `requiredCount <= UInt64.max - nextBoundaryOccurrence`. Failure returns
   `.boundaryOccurrenceExhausted` before constructing any token/candidate/event/effect.
3. For each required token in that order, use the current `nextBoundaryOccurrence` as `occurrence`,
   set `sourceRevision = R` and the current session ID, then checked-increment the counter.
4. For a scheduled check-in, store token, due date, and validated `trustedRemaining` atomically in
   one `ScheduledCheckInBoundary`.
5. Consume a token only in the same transaction as its factual boundary/check-in event.

If the occurrence increment overflows, publish no token and return
`.failed(.boundaryOccurrenceExhausted)`; the actor throws the same-named `SessionEngineFailure` with
zero write/effect. It is not clock recovery because a resumed timed state would immediately require
another impossible token. Revision and event-sequence exhaustion use their corresponding failure path.

Every start, resume, live relaunch, or `resumeSavedRemainder` that produces a live candidate uses the
same construction rule. Except for live relaunch, which copies Section 8.3 materialization, Atom 3.2
must call `materializeLiveEntry` and copy its matching focus/break value: canonical wall anchor;
`elapsedBeforeAnchorSeconds == 0` when prior elapsed
was moved to the accumulator, otherwise the exactly materialized trusted elapsed; `timingAtAnchor`
equal to the originating full/captured/materialized budget; a fresh generated projection token;
positive timed deadline at anchor plus that remaining budget or nil for open-ended;
phase token only for timed focus; and scheduled boundary only for interval cadence, using the captured
remainder or one full interval as specified by the originating transition. When both phase and
scheduled tokens exist, phase always receives the lower occurrence.

`materializeLiveEntry` canonicalizes the request's raw `wallNow`, converts a timed `BreakDuration`
from minutes to seconds, adds all deadlines, builds the scheduled boundary atomically, allocates every
required boundary token in Section 8.4 order, and returns the final occurrence counter. Focus timing
is already a typed `PausedTiming`: Atom 3.2 maps a phase's `.timed(PhaseSeconds)`/`.openEnded` shape or
copies a saved value without numeric arithmetic. `.fullInterval(minutes)` converts to seconds inside
3.3; `.captured` preserves the supplied exact seconds; `.manualOnly` installs no scheduled token.
All entry materializations use the supplied `projectionToken` and set `elapsedBeforeAnchorSeconds` to
zero when Atom 3.2 copies them into a new live state.

For a live focusing `setCheckInSchedule` commit, Atom 3.2 first copies
`LiveCommitMaterialization`, retains its existing phase token, then calls
`replaceScheduledCheckIn` with that returned wall anchor. The helper clears cadence without
allocation for `manualOnly`, or returns one full-interval atomic scheduled boundary and exactly one
newly allocated scheduled token for `.interval`; it never reallocates the phase token. For live
breaking, Atom 3.2 copies the break `LiveCommitMaterialization`, retains the break token, and replaces
only `resumeTarget.scheduledCheckInRemaining` with `materializeScheduledRemainder(newSchedule)`.
The effect planner compares the original winner to the final candidate as specified in Section 7.2.

`materializeScheduledRemainder` is the single minutes-to-seconds conversion used by 3.3's full-interval
entry/replacement helpers and by Atom 3.2 for non-live cadence holders. It returns nil for
`.manualOnly`, exactly 300 for interval 5, exactly 7,200 for interval 120, and the validated product
for every intervening `CheckInMinutes`. It allocates no token, reads no clock, and cannot fail for a
valid constrained schedule.

`materializeLiveEntry` returns `.failure(.nonFiniteWallObservation)` before construction for a
non-finite raw entry wall. Both helpers return `.failure(.boundaryOccurrenceExhausted)` when the
complete required token set cannot be allocated, or `.failure(.arithmeticOverflow)` for checked
finite date/duration construction overflow; a malformed internal replacement anchor maps to the
same arithmetic failure.
Within a helper, finiteness is checked first, then the complete token count is preflighted, then date
arithmetic and value construction occur; occurrence exhaustion therefore precedes finite date
overflow. Atom 3.2 performs the same finiteness check before revision/event capacity as required by
Section 6, then preflights those counters and copies one successful helper value. The helper's own
finiteness branch remains independently testable and defensive. On helper failure no candidate,
event, effect, projection-token publication, or write is produced.

Notification IDs are a pure canonical UTF-8 string derived from the boundary token:
`praxodoro/v1/<lowercase-uuid>/<kind>/<occurrence>`. The platform adapter never invents an ID, and
the same logical boundary therefore schedules/cancels the same request after relaunch.

### 8.5 Boundary admission and phase continuation

For focusing, the installed boundary candidates are the phase token/deadline and scheduled check-in
token/date. For breaking, the only candidate is the break-end token/date. `openCheckIn`,
`deadlineFired`, and wake/relaunch use the same admission function. In-process focus/break admission
first performs Section 8.2 live validation/reconciliation; relaunch uses Section 8.3. The `dueAt` and
observation below are therefore the normalized pair, not raw wall time against an unreconciled date:

1. For `openCheckIn`, a trigger/token kind or phase-ID mismatch is `staleBoundary`; malformed
   persisted token/owner combinations fail snapshot validation as `invalidBoundaryToken`.
2. A consumed token is `duplicateBoundary`; a non-installed token is `staleBoundary`.
3. An installed token with `normalizedDueInstant < normalizedDueAt` is `boundaryNotDue`, except that
   a required rebase commits the adjustment-only result defined in Section 8.2.
4. Among installed candidates whose `normalizedDueAt <= normalizedDueInstant`, only the earliest due
   candidate may commit.
   Equal dates rank phase before scheduled check-in before break-end. A later/lower-ranked callback
   returns `noChange(.earlierBoundaryPending)` and leaves every token installed.
5. The winning commit freezes/accumulates the live state once and consumes that token. When phase
   wins, its `.phase` exit materialization supplies the exact exhausted-phase focus accumulator. When
   scheduled check-in wins, `.scheduledCheckIn` supplies the focus accumulator at that earlier due
   instant plus its positive timed or open-ended suspended timing; this applies even if a later phase
   is also due by observation. When break-end wins, `.breakEnd` supplies the exact exhausted-break
   accumulator. Atom 3.2 copies these values without timestamp/duration arithmetic. When phase
   wins, `.preserve(remainder)` copies that exact value into
   `phaseBoundaryScheduledCheckInRemaining`; `.resetAfterPhaseCollision`,
   `.resetAfterSupersededScheduledOccurrence`, or `.manualOnly` stores nil. The superseded reset is
   required when phase is earlier but the scheduled candidate is also due at the normalized
   observation; it must not be represented as a positive remainder. A scheduled winner returns
   `.resetAfterScheduledOccurrence`; a break-end winner returns `.notApplicable`. It then clears every
   other live boundary token/date before entering check-in/re-entry. Subsequent callbacks are stale.

This makes actor arrival order irrelevant, including a phase and scheduled check-in due at the same
instant. Paused, check-in, break-return targets, re-entry, review, and recovery contain no installed
live phase or scheduled-check-in token; a boundary-origin check-in retains its consumed trigger token
only as historical duplicate-classification evidence equal to `lastConsumedBoundaryToken`. Resume
always publishes fresh tokens.

For a phase boundary, continuation is the descriptor with `ordinal + 1` when that descriptor exists.
When the elapsed descriptor is the final timed descriptor, continuation is a new block using that
same descriptor. Open-ended descriptors never publish a phase token and cannot reach this rule.

## 9. Recovery choices

Recovery state always contains a valid active snapshot and one frozen trustworthy state. A live
focus is frozen to `SuspendedFocusState`; a live break is frozen to `SuspendedBreakState`; an
already-suspended check-in/re-entry is copied without a projection. Decode/schema or repository
corruption is `SessionEngineFailure`, not a fabricated `SessionSnapshot` recovery state. For every
listed reason, `safeChoices == Set(ClockRecoveryChoice.allCases)` exactly.

| Reason | Safe choices | Outcome |
|---|---|---|
| missingLiveProjection | resumeSavedRemainder, reviewSession, endSession | resume uses stored suspended/remaining value; others enter review |
| staleLiveProjection | resumeSavedRemainder, reviewSession, endSession | resume discards the mismatched observation and installs a fresh projection token from trusted timing |
| inconsistentLiveProjectionAnchor | resumeSavedRemainder, reviewSession, endSession | resume discards the unsynchronized observation pair and installs a fresh paired anchor/token from trusted timing |
| negativeMonotonicElapsed | resumeSavedRemainder, reviewSession, endSession | resume discards the invalid measurement and uses the last committed timing |
| wallClockAmbiguousAfterRelaunch | resumeSavedRemainder, reviewSession, endSession | resume uses saved timing with fresh anchors |
| arithmeticOverflow | resumeSavedRemainder, reviewSession, endSession | resume discards the overflowing calculation and uses the last committed timing |

`reviewSession` enters reviewing with stop reason `clockRecoveryReview`. `endSession` also enters
reviewing, with stop reason `clockRecoveryEnd`; it does not jump directly to completed.
`resumeSavedRemainder` restores focusing/paused, breaking, checking-in, or re-entering according to
the frozen trustworthy state and installs a fresh projection token only for live focus/break.
A choice outside the exact set is rejected.

For an invalid live observation, “last trustworthy” is mechanically derived without that observation.
For focus/break, move only the already committed `elapsedBeforeAnchorSeconds` into the corresponding
accumulator and copy the live state's `timingAtAnchor` exactly; a resumed partial phase/break therefore
keeps its saved partial budget rather than expanding to the policy's original duration. A pending
scheduled check-in copies `ScheduledCheckInBoundary.trustedRemaining` exactly. No remainder is
derived by subtracting a phase wall anchor from a deadline, and no unobserved elapsed is credited. If
the trusted timing shape is inconsistent with its deadline/descriptor, bootstrap/candidate validation
has already classified the snapshot as corrupt; recovery never repairs it. The recovery commit uses
`canonicalSecond(context.instant.wallNow)`, emits only its one recovery event, and consumes no
boundary token.

## 10. Actor, repository, publication, and effects order

~~~swift
public protocol SessionRunning: Sendable {
  func snapshots() async -> AsyncStream<SessionSnapshot>
  func send(_ command: SessionCommand) async throws(SessionEngineFailure) -> SessionResult
}

public protocol SessionRepository: Sendable {
  func loadCurrent() async throws(RepositoryFailureKind) -> SessionSnapshot
  func commit(
    expectedRevision: UInt64,
    snapshot: SessionSnapshot,
    events: [SessionEvent]
  ) async throws(SessionRepositoryError)
}

public enum SessionReducer {
  public static func reduce(
    snapshot: SessionSnapshot,
    command: SessionCommand,
    context: ReductionContext
  ) -> ReductionOutcome
}
~~~

The Atom 4.1 engine order is fixed:

1. Actor reads current canonical snapshot.
2. Actor compares `command.expectedRevision`; mismatch returns stale revision without reducing.
3. Reducer returns transition/no-change/rejection/failure.
4. Actor maps a reduction failure to the same-named `SessionEngineFailure` and performs no validation,
   write, publication, or effect.
5. For transition, validate the complete candidate invariant set with the exact reduction context.
6. Repository atomically commits snapshot plus ordered events at expected revision.
7. Actor publishes the committed snapshot.
8. Actor attempts effects and records each status.
9. Actor returns `SessionResult.committed` with the committed snapshot and effect statuses.

Repository creation installs the one canonical idle revision-0 snapshot, so `loadCurrent()` is never
optional and repository-global revision cannot reset when an active record is cleared. Engine
bootstrap loads once, checks schema, runs `validateCandidate`, and publishes nothing if either fails.
For a valid live snapshot it performs one internal `.relaunch` reconciliation before exposing the
initial stream value; for a valid non-live snapshot it exposes the loaded value unchanged.

`snapshots()` is a replay-latest broadcast, not a shared consuming sequence. Every awaited call
returns an independent unbounded ordered stream whose first element is the current post-bootstrap
committed snapshot; every later committed revision is yielded exactly once to every active
subscriber in revision order. Cancelling or terminating one stream removes only that continuation
and cannot finish, drain, or steal values from another subscriber. No-change, rejection, reduction
failure, repository failure, and effect-only status produce no snapshot publication. This contract
allows `AppModel`, the capability coordinator, menu/window adapters, and tests to observe one actor
without competing for a single `AsyncStream` iterator.

Shutdown accepts no domain transition: the actor stops its display/deadline tasks, allows an already
entered repository commit to finish, starts no new command, and performs no final state write because
every accepted command was committed before publication. Core repository/effect operations have no
automatic retry; the sole conflict reload described below is a classification step, not a retry.

A repository error publishes nothing and fires no effect. A repository conflict must report an
`actualRevision` different from `expectedRevision`; reporting the same revision is an adapter
contract violation translated to `repositoryCommitFailed(.validationFailed)`. For a valid conflict,
the actor reloads exactly once for classification and never publishes that reload. Reload failure is
`repositoryLoadFailed`; unsupported schema is `unsupportedSnapshotSchema`; candidate validation
failure is `corruptSnapshot`. Only a successfully schema-checked and `validateCandidate`-valid reload
whose revision equals the conflict's reported `actualRevision` returns
`rejected(.staleRevision(expected:actual:))`, using the reloaded snapshot and its actual revision; a
disagreement is `repositoryCommitFailed(.validationFailed)`. The stale pre-conflict in-memory value and unvalidated repository bytes are never returned
as the rejection snapshot. Effect statuses have the same count and order as the attempted effects.
An effect failure never invokes the reducer and never changes revision.

## 11. Exact validation ownership

### 11.1 Atom 3.1 model tests

- Explicit initializer/factory tests for every public user-created constrained value.
- Kind mapping tests covering all ten states, all intent cases, all event payload cases, all effect
  cases, and all check-in response cases.
- Explicit construction and coverage fixtures for every rejection, reduction failure, engine failure,
  recovery reason, repository failure, effect status, and platform status; these types have no implied
  `kind` API unless one is separately declared above.
- One valid internal fixture for every lifecycle state and every timing shape.
- One failing candidate/transition validator fixture for every constructible row in Section 4;
  constructor-negative tests for constrained values that cannot form an invalid snapshot. The wall-
  observation row includes focusing and breaking candidates whose `wallAnchor` differs from
  `lastWallObservationAt`; both return `invalidWallObservation` during bootstrap validation.
- Exact equality snapshots for the four V1 policies and `SessionConfiguration.defaults`.
- Boundary/check-in/break range edges: 4/5/120/121 minutes, 0/1/120/121 minutes, and phase
  seconds 0/1/86,400/86,401; captured check-in seconds 0/1/configured maximum/7,201 and a value
  above the active configured interval.
- Text normalization/scalar boundaries and 1,000/1,001 parked-thought bounds.
- Canonical timestamp fixtures for every `SessionTimestampField`, including fractional, NaN, and
  infinite underlying `Date` inputs in lawful `SessionTimestamp` wrappers; this includes every
  optional event-payload/nested clock-adjustment timestamp. Exact equality/hash tests cover finite,
  negative-zero, identical-NaN-bit-pattern, distinct-NaN-bit-pattern, and infinity probes.
- Event envelope sequence/version construction and recursive privacy payload inventory proving no raw
  user text or raw check-in/capacity answer exists in `SessionEventPayload` or nested event structs.
- Non-empty change-set factories; token-derived notification ID/kind/content construction; exact
  `TimingPolicyID.requiredLiteFeature` and cadence-resolution mappings.
- Projection value/error construction for idle, timed focus, open-ended Flow, paused, break, and
  completed; no callable projection or arithmetic test before Atom 3.3.

Atom 3.1 does not test transitions, time arithmetic, repository commits, or Codable round trips.

### 11.2 Atom 3.2 reducer tests

- Atom 3.2 begins only after the accepted Atom 3.3 time-kernel commit and integrates its decisions;
  it does not reimplement clock arithmetic.
- Generated assertion for every row in Sections 7.1-7.3.
- Explicit construction/coverage fixtures for every Section 3.8 coach value and error, followed by
  behavioral tests for every valid/unavailable request and reason order.
- Generated rejection assertion for every unlisted state/intent pair.
- Exact ordered event arrays and exact no-change/rejection behavior.
- Exact timestamp-source fixtures for prepared/start/live-pause/non-live-pause, paused -> check-in ->
  paused restoration, live-break-reentry/non-live-reentry/thought/review/summary paths under zero,
  within-tolerance, material drift, overdue winner, and permitted rollback observations.
- Pure-kernel integration for live pause/materialization, drift adjustment events, wake/boundary
  candidates, relaunch restore/recovery events, and duplicate/stale callback classification.
- Pause, manual check-in, request-break, and stop exits copy exact non-boundary focus accumulation,
  positive/open-ended suspended timing, and captured scheduled cadence; early-break/review exits copy
  the exact break accumulator. No reducer test recomputes a duration.
- Due focus `openCheckIn`/`requestBreak` and due break `endBreak` are superseded by the ordinary
  earliest boundary flow. Due live Stop/Replace-and-Review instead copy winner-time totals into review,
  clear live tokens, and emit only their terminal suffix after any adjustment; no check-in/re-entry
  event or terminal payload is lost. Their review `endedAt` copies the expected paired instant with
  the `startedAt` lower bound, while event envelopes copy the observed wall instant.
- Schedule changes in paused, resume-suspended check-in, live break resume-target, and re-entry copy
  the exact 3.3 materialized full remainder or nil; phase-boundary check-in clears its field and uses
  the same value only when resolution creates a paused/live target. Live break retains its break token.
- Live-preserving configuration/thought commits copy the kernel's ±1/±2 materialization values and
  adjustment verbatim; phase-boundary schedule changes clear the old captured remainder before
  resolution installs the current full interval or manual-only nil.
- Non-finite current wall returns `nonFiniteWallObservation` for every otherwise transitioning
  non-live matrix family before counters/candidate/events, while wall-independent rejection and
  no-change rows remain classifiable.
- Conflict payload matrix, reflection edit/finalize, replacement continuation, configuration changes,
  thought limits, deterministic Make Smaller, accepted revised-action plan replacement, exact final
  task/action summary sources, typed break reasons/options, exact effect derivation, and full
  initiate-to-review fixture.

### 11.3 Atom 3.3 timing tests

- Normal projection with zero writes; timed and open-ended projection/kernel decisions.
- Paired canonical elapsed at a fractional boundary (`rawAnchor = 100.9`, elapsed `0.2` yields one
  second), proving display plus live/relaunch kernel decisions use one definition.
- Drift at -1/+1/-2/+2 seconds returns nil `admissionAdjustment` but a non-nil exact
  `liveCommitMaterialization.adjustment`, observed anchor, exact `nonBoundaryExitMaterialization`,
  shifted deadlines, and positive remaining values; zero drift makes both adjustments nil; beyond
  ±2 both paths return the same adjustment. A due earlier winner leaves both non-boundary
  materializations nil, so an irrelevant observation-based overflow cannot preempt admission.
- Wake/relaunch before/at/after deadline; an anchor equal to current wall restores, while anchors one
  and two seconds in the future both recover; phase-earliest versus scheduled-earliest wake after
  both deadlines, timezone/DST, same-instant cadence collision, and one boundary maximum.
- Projector NaN/infinite current wall returns `arithmeticOverflow`; the time kernel returns
  `failure(.nonFiniteWallObservation)`. Current-wall failure wins over missing/stale/raw
  invalid observations; with finite wall, missing wins first, stale token wins over a non-finite raw
  anchor, and a matching token plus non-finite raw anchor returns projector `arithmeticOverflow` and
  kernel recovery `arithmeticOverflow` before canonical anchor comparison.
- Boundary admission decisions for installed tokens include exact future-cadence preservation,
  equal-time phase-collision reset, overdue-later-scheduled supersession reset,
  scheduled-occurrence reset, manual-only, and break-not-applicable values; cadence
  anchoring/reset/preservation; exact winner-time phase/scheduled/break exit materialization,
  including scheduled-earlier/phase-later/both-overdue positive suspended timing; token
  allocation exhaustion, live/relaunch normalization, an irrelevant observation-total overflow that
  still admits a valid earlier winner, and a winner-total overflow that returns exact admission
  recovery, all without constructing reducer events or candidates. Duplicate/stale preclassification, pause/resume
  candidates, and every event-envelope assertion remain Atom 3.2 work.
- Live-entry materialization at wall 100 with a 300-second phase and 900-second full cadence returns
  deadlines 400/1,000, phase-then-scheduled occurrences, the supplied projection token, and the final
  occurrence counter. Fixtures also cover open-ended/manual, open-ended/scheduled, saved focus,
  timed/open-ended/saved break, phase-boundary continuation, and `resumeSavedRemainder` inputs.
- Scheduled replacement preserves the current phase token, allocates only a new scheduled token for
  the Atom 3.2 candidate, while the helper itself returns only a new scheduled token for interval
  cadence and none for manual-only. Entry non-finite wall, entry/replacement complete-set occurrence
  exhaustion, and checked finite date overflow return the exact `ReductionFailure` with no partial
  materialization.
- Scheduled remainder materialization maps manual-only to nil and interval edges 5/120 minutes to
  exactly 300/7,200 seconds with zero clock read, token allocation, or failure.

### 11.4 Atom 4.1 engine tests

- Concurrent commands serialize by repository-global revision.
- Two independently created snapshot streams each replay the same current revision, each receive
  every later committed revision once and in order, and cancellation of one leaves the other live.
- Stale command and repository-conflict recovery never become active-session conflict.
- Commit failure publishes/fires nothing; effect failure preserves the committed revision.
- All five reduction failures map to same-named engine failures with zero write/publication/effect;
  this includes new-entry/scheduled-replacement `arithmeticOverflow`.
- `nonFiniteWallObservation` maps to the same-named engine failure with zero repository write,
  snapshot publication, effect attempt, or counter consumption.
- New session resets only session-local event sequence; repository revision remains monotonic.
- Published snapshot is byte-for-byte the committed candidate.

Codable/SwiftData round trips remain owned by Atom 4.2. No atom may claim this contract from type
existence alone; it must pass the tests assigned to that atom and its independent review gate.
