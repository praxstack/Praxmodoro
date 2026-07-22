import Foundation
import Testing
@testable import PraxodoroCore

@Suite("Session domain model")
struct SessionModelTests {
  @Test("the lifecycle vocabulary is closed")
  func lifecycleVocabularyIsClosed() {
    #expect(SessionStateKind.allCases == [
      .idle, .prepared, .focusing, .paused, .checkingIn,
      .breaking, .reentering, .reviewing, .completed, .recoveryNeeded,
    ])
  }

  @Test("the V1 timing policy vocabulary is closed")
  func timingPolicyVocabularyIsClosed() {
    #expect(TimingPolicyID.allCases == [
      .gentleStart, .classic, .flow, .recoveryFirst,
    ])
  }

  @Test("timestamps retain lawful equality for non-finite fixture values")
  func timestampEqualityIsLawfulForFixtures() {
    let finite = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 42))
    let sameFinite = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 42))

    #expect(finite == sameFinite)
    #expect(Set([finite, sameFinite]).count == 1)
  }

  @Test("timestamps preserve bit-pattern identity for malformed fixtures")
  func timestampEqualityRemainsHashLawfulForMalformedValues() {
    let nanBits: UInt64 = 0x7FF8_0000_0000_0001
    let sameNaN = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: Double(bitPattern: nanBits)))
    let duplicateNaN = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: Double(bitPattern: nanBits)))
    let distinctNaN = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: Double(bitPattern: 0x7FF8_0000_0000_0002)))
    let positiveInfinity = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: .infinity))
    let negativeZero = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: -0.0))
    let positiveZero = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 0.0))

    #expect(sameNaN == duplicateNaN)
    #expect(sameNaN != distinctNaN)
    #expect(Set([sameNaN, duplicateNaN]).count == 1)
    #expect(positiveInfinity == positiveInfinity)
    #expect(negativeZero == positiveZero)
  }

  @Test("canonical seconds reject non-finite clock input and floor finite values")
  func canonicalSecondIsDeterministic() {
    #expect(canonicalSecond(Date(timeIntervalSinceReferenceDate: 7.9)) ==
      SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 7)))
    #expect(canonicalSecond(Date(timeIntervalSinceReferenceDate: -.infinity)) == nil)
  }

  @Test("the default configuration is ADHD-aware but low-load is opt-in")
  func defaultConfigurationIsExact() {
    #expect(SessionConfiguration.defaults == SessionConfiguration(
      checkInSchedule: .every15Minutes,
      breakSuggestionsEnabled: true,
      lowCognitiveLoadEnabled: false,
      reflectionPromptEnabled: true
    ))
  }

  @Test("the immutable presets have their specified timing shapes")
  func timingPolicyShapesAreExact() {
    #expect(TimingPolicy.allV1 == [
      .gentleStart, .classic, .flow, .recoveryFirst,
    ])
    #expect(TimingPolicy.gentleStart.phases.map(\.duration) == [
      .timed(try! PhaseSeconds(300)), .timed(try! PhaseSeconds(1_200)),
    ])
    #expect(TimingPolicy.flow.suggestedBreak == nil)
    #expect(TimingPolicy.recoveryFirst.phases.map(\.duration) == [
      .timed(try! PhaseSeconds(600)), .openEnded,
    ])
  }

  @Test("each V1 timing preset has its exact phase identity and feature gate")
  func timingPolicyDefinitionsAreExact() {
    #expect(TimingPolicy.gentleStart.phases.map(\.id) == [.entry, .focus])
    #expect(TimingPolicy.gentleStart.phases.map(\.ordinal) == [0, 1])
    #expect(TimingPolicy.classic.phases.map(\.id) == [.focus])
    #expect(TimingPolicy.classic.phases.map(\.ordinal) == [0])
    #expect(TimingPolicy.flow.phases.map(\.id) == [.flow])
    #expect(TimingPolicy.flow.phases.map(\.ordinal) == [0])
    #expect(TimingPolicy.recoveryFirst.phases.map(\.id) == [.recoveryRamp, .focus])
    #expect(TimingPolicy.recoveryFirst.phases.map(\.ordinal) == [0, 1])
    #expect(TimingPolicy.gentleStart.suggestedBreak == .timed(.five))
    #expect(TimingPolicyID.gentleStart.requiredLiteFeature == .gentleStart)
    #expect(TimingPolicyID.classic.requiredLiteFeature == .classic)
    #expect(TimingPolicyID.flow.requiredLiteFeature == .flow)
    #expect(TimingPolicyID.recoveryFirst.requiredLiteFeature == .recoveryFirst)
  }

  @Test("a session plan preserves deliberate capacity and normalizes input")
  func sessionPlanPreservesCapacityAndNormalizesInput() throws {
    let plan = try SessionPlan(
      task: "  Write the outline  ",
      firstAction: "  Open the brief  ",
      capacity: .foggy,
      timingPolicy: .gentleStart
    )

    #expect(plan.task == "Write the outline")
    #expect(plan.firstAction == "Open the brief")
    #expect(plan.capacity == .foggy)
  }

  @Test("prepared plan fields allow empty values but reject more than 500 scalars")
  func sessionPlanTextBoundsAreExact() throws {
    let empty = try SessionPlan(task: "   ", firstAction: "\n", capacity: nil, timingPolicy: .flow)
    #expect(empty.task.isEmpty)
    #expect(empty.firstAction.isEmpty)

    let tooLong = String(repeating: "a", count: 501)
    #expect(throws: DomainValidationError.textTooLong(field: .task, maximumScalars: 500)) {
      _ = try SessionPlan(task: tooLong, firstAction: "Action", capacity: nil, timingPolicy: .classic)
    }
    #expect(throws: DomainValidationError.textTooLong(field: .firstAction, maximumScalars: 500)) {
      _ = try SessionPlan(task: "Task", firstAction: tooLong, capacity: nil, timingPolicy: .classic)
    }
  }

  @Test("constrained minute values retain their exact rejected range")
  func constrainedMinuteValuesRejectOutOfRangeInput() {
    #expect(throws: DomainValidationError.intervalOutOfRange(actual: 4, allowed: 5...120)) {
      _ = try CheckInMinutes(4)
    }
    #expect(throws: DomainValidationError.breakDurationOutOfRange(actual: 121, allowed: 1...120)) {
      _ = try BreakMinutes(121)
    }
  }

  @Test("all persisted timing scalar boundaries are exact")
  func timingScalarBoundariesAreExact() throws {
    #expect(try CheckInMinutes(5).value == 5)
    #expect(try CheckInMinutes(120).value == 120)
    #expect(throws: DomainValidationError.intervalOutOfRange(actual: 121, allowed: 5...120)) {
      _ = try CheckInMinutes(121)
    }
    #expect(try CheckInRemainingSeconds(1).value == 1)
    #expect(try CheckInRemainingSeconds(7_200).value == 7_200)
    #expect(throws: DomainValidationError.checkInRemainingOutOfRange(actual: 0, allowed: 1...7_200)) {
      _ = try CheckInRemainingSeconds(0)
    }
    #expect(try PhaseSeconds(1).value == 1)
    #expect(try PhaseSeconds(86_400).value == 86_400)
    #expect(throws: DomainValidationError.phaseDurationOutOfRange(actual: 86_401, allowed: 1...86_400)) {
      _ = try PhaseSeconds(86_401)
    }
  }

  @Test("an explicit cadence always wins over an adapter preference")
  func explicitScheduleWinsDuringResolution() throws {
    let explicit = CheckInSchedule.interval(try CheckInMinutes(20))
    let resolved = SessionConfigurationResolver.resolveSchedule(
      base: .defaults,
      explicitSchedule: explicit,
      resolvedPreferenceMinutes: 45
    )

    #expect(resolved.configuration.checkInSchedule == explicit)
    #expect(resolved.issues.isEmpty)
  }

  @Test("an invalid adapter cadence falls back predictably")
  func invalidResolvedCadenceFallsBackToDefaultInterval() {
    let resolved = SessionConfigurationResolver.resolveSchedule(
      base: .defaults,
      explicitSchedule: nil,
      resolvedPreferenceMinutes: 121
    )

    #expect(resolved.configuration.checkInSchedule == .every15Minutes)
    #expect(resolved.issues == [.invalidResolvedCadence(actualMinutes: 121)])
  }

  @Test("each command intent maps to its closed persisted kind")
  func intentKindsAreExhaustive() {
    #expect(SessionIntentKind.allCases.count == 21)
    #expect(SessionIntent.start.kind == .start)
    #expect(SessionIntent.pause.kind == .pause)
    #expect(SessionIntent.setLowCognitiveLoadEnabled(true).kind == .setLowCognitiveLoadEnabled)
    #expect(SessionIntent.recoverClock(.reviewSession).kind == .recoverClock)
  }

  @Test("the session defaults establish the deterministic engine contract")
  func sessionDefaultsAreExact() {
    #expect(SessionDefaults.selectedPolicy == .gentleStart)
    #expect(SessionDefaults.wallMonotonicDriftTolerance == .seconds(2))
    #expect(SessionDefaults.visualProjectionCadence == .seconds(1))
    #expect(SessionDefaults.askBeforeAnotherBlock)
    #expect(SessionDefaults.maximumParkedThoughts == 1_000)
  }

  @Test("the projection value preserves its complete display contract")
  func projectionVocabularyConstructsExactly() {
    let projection = SessionProjection(
      sourceRevision: 7,
      sessionID: nil,
      state: .idle,
      task: nil,
      firstAction: nil,
      timingPolicy: nil,
      phase: nil,
      focusedSeconds: 0,
      breakSeconds: 0,
      remainingSeconds: nil,
      isPaused: false,
      isBoundaryAwaitingDecision: false,
      nextScheduledCheckInAt: nil,
      parkedThoughtCount: 0,
      lowCognitiveLoadEnabled: false
    )

    #expect(projection.state == .idle)
    #expect(projection.remainingSeconds == nil)
    #expect(projection.timingPolicy == nil)
  }

  @Test("projection errors retain typed snapshot failures")
  func projectionErrorsRetainTypedSnapshotFailures() {
    #expect(ProjectionError.invalidSnapshot([.invalidIdleBaseline]) ==
      .invalidSnapshot([.invalidIdleBaseline]))
  }

  @Test("state kinds map exhaustively without a default case")
  func stateKindMappingsCoverStaticStates() {
    #expect(SessionState.idle.kind == .idle)
  }

  @Test("event change sets reject empty payloads")
  func emptyEventChangeSetsAreUnconstructable() {
    #expect(SessionPlanFieldChanges([]) == nil)
    #expect(SessionConfigurationFieldChanges([]) == nil)
  }

  @Test("effects and check-in responses map to closed kinds")
  func effectAndResponseKindsAreExhaustive() {
    #expect(SessionEffect.playHaptic(.gentleBoundary).kind == .playHaptic)
    #expect(CheckInResponse.dismiss.kind == .dismiss)
    #expect(SessionEffectKind.allCases.count == 6)
    #expect(CheckInResponseKind.allCases.count == 6)
  }

  @Test("the canonical idle snapshot validates without repair")
  func canonicalIdleSnapshotIsValid() {
    #expect(SessionSnapshotValidator.validateCandidate(.canonicalIdle).isEmpty)
  }

  @Test("a malformed persisted timestamp identifies its exact field")
  func malformedTimestampUsesFieldSpecificViolation() {
    var snapshot = SessionSnapshot.canonicalIdle
    snapshot = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: snapshot.sessionID,
      revision: snapshot.revision,
      eventSequence: snapshot.eventSequence,
      nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
      state: snapshot.state,
      plan: snapshot.plan,
      configuration: snapshot.configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 2.5)),
      accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: snapshot.lastWallObservationAt,
      nextScheduledCheckIn: snapshot.nextScheduledCheckIn,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )

    #expect(SessionSnapshotValidator.validateCandidate(snapshot).contains(.nonCanonicalTimestamp(.startedAt)))
  }

  @Test("result vocabulary retains snapshots and typed failure reasons")
  func resultVocabularyIsClosed() {
    let result = SessionResult.noChange(snapshot: .canonicalIdle, reason: .observationIrrelevant)
    #expect(result == .noChange(snapshot: .canonicalIdle, reason: .observationIrrelevant))
    #expect(SessionEngineFailure.corruptSnapshot([.invalidIdleBaseline]) ==
      .corruptSnapshot([.invalidIdleBaseline]))
  }

  @Test("prepared candidates require a session plan")
  func preparedCandidateRequiresPlan() {
    let preparedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 10))
    let candidate = SessionSnapshot(
      schemaVersion: 1,
      sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000001"),
      revision: 1,
      eventSequence: 1,
      nextBoundaryOccurrence: 0,
      state: .prepared(PreparedState(preparedAt: preparedAt)),
      plan: nil,
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: nil,
      accumulatedFocusSeconds: 0,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: preparedAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )

    #expect(SessionSnapshotValidator.validateCandidate(candidate).contains(.missingPlan))
  }

  @Test("relational validation requires exactly one revision increment")
  func transitionRevisionMustIncrementExactlyOnce() {
    let candidate = SessionSnapshot.canonicalIdle
    let context = ReductionContext(
      instant: SessionInstant(wallNow: Date(timeIntervalSinceReferenceDate: 0), liveProjection: nil),
      generatedSessionID: UUID(),
      generatedThoughtID: UUID(),
      generatedProjectionToken: UUID()
    )
    let violations = SessionSnapshotValidator.validate(
      previous: .canonicalIdle,
      command: SessionCommand(expectedRevision: 0, intent: .start),
      candidate: candidate,
      emittedEvents: [],
      context: context
    )

    #expect(violations.contains(.invalidRevision(expected: 1, actual: 0)))
  }

  @Test("non-idle commits record the context's canonical wall observation")
  func nonIdleCommitRequiresExactWallObservation() throws {
    let plan = try SessionPlan(task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic)
    let preparedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 10))
    let candidate = SessionSnapshot(
      schemaVersion: 1,
      sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000001"),
      revision: 1,
      eventSequence: 0,
      nextBoundaryOccurrence: 0,
      state: .prepared(PreparedState(preparedAt: preparedAt)),
      plan: plan,
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: nil,
      accumulatedFocusSeconds: 0,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: preparedAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )
    let context = ReductionContext(
      instant: SessionInstant(wallNow: Date(timeIntervalSinceReferenceDate: 11), liveProjection: nil),
      generatedSessionID: UUID(),
      generatedThoughtID: UUID(),
      generatedProjectionToken: UUID()
    )
    let violations = SessionSnapshotValidator.validate(
      previous: .canonicalIdle,
      command: SessionCommand(expectedRevision: 0, intent: .prepare(SessionDraft(plan: plan))),
      candidate: candidate,
      emittedEvents: [],
      context: context
    )

    #expect(violations.contains(.invalidWallObservation))
  }

  @Test("preparing a new session requires the complete closed reset")
  func prepareResetIsCompleteAndSessionLocal() throws {
    let plan = try SessionPlan(task: "Task", firstAction: "Action", capacity: .steady, timingPolicy: .classic)
    let draft = SessionDraft(plan: plan)
    let previous = SessionSnapshot.canonicalIdle
    let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
    let wall = Date(timeIntervalSinceReferenceDate: 10)
    let timestamp = SessionTimestamp(unchecked: wall)
    let candidate = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 1,
      eventSequence: 1,
      nextBoundaryOccurrence: 0,
      state: .prepared(PreparedState(preparedAt: timestamp)),
      plan: plan,
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: nil,
      accumulatedFocusSeconds: 0,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: timestamp,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )
    let context = ReductionContext(
      instant: SessionInstant(wallNow: wall, liveProjection: nil),
      generatedSessionID: sessionID,
      generatedThoughtID: UUID(),
      generatedProjectionToken: UUID()
    )
    let event = SessionEvent(
      sessionID: sessionID,
      sequence: 1,
      occurredAt: timestamp,
      payload: .sessionPrepared(policy: .classic, capacitySpecified: true)
    )

    #expect(SessionSnapshotValidator.validate(
      previous: previous,
      command: SessionCommand(expectedRevision: 0, intent: .prepare(draft)),
      candidate: candidate,
      emittedEvents: [event],
      context: context
    ).isEmpty)

    let leakingCandidate = SessionSnapshot(
      schemaVersion: candidate.schemaVersion,
      sessionID: candidate.sessionID,
      revision: candidate.revision,
      eventSequence: candidate.eventSequence,
      nextBoundaryOccurrence: 1,
      state: candidate.state,
      plan: candidate.plan,
      configuration: candidate.configuration,
      parkedThoughts: candidate.parkedThoughts,
      startedAt: candidate.startedAt,
      accumulatedFocusSeconds: candidate.accumulatedFocusSeconds,
      accumulatedBreakSeconds: candidate.accumulatedBreakSeconds,
      lastWallObservationAt: candidate.lastWallObservationAt,
      nextScheduledCheckIn: candidate.nextScheduledCheckIn,
      lastConsumedBoundaryToken: candidate.lastConsumedBoundaryToken
    )
    #expect(SessionSnapshotValidator.validate(
      previous: previous,
      command: SessionCommand(expectedRevision: 0, intent: .prepare(draft)),
      candidate: leakingCandidate,
      emittedEvents: [event],
      context: context
    ).contains(.invalidSessionReset))
  }

  @Test("timed focus candidates require both a matching live anchor and deadline")
  func timedFocusCandidateRequiresConsistentLiveShape() throws {
    let plan = try SessionPlan(task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic)
    let anchor = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 20))
    let focus = FocusState(
      phase: TimingPolicy.classic.phases[0],
      timingAtAnchor: .timed(remaining: try PhaseSeconds(300)),
      wallAnchor: anchor,
      phaseEndsAt: nil,
      elapsedBeforeAnchorSeconds: 0,
      projectionToken: UUID(),
      phaseBoundaryToken: nil
    )
    let candidate = SessionSnapshot(
      schemaVersion: 1,
      sessionID: UUID(),
      revision: 1,
      eventSequence: 1,
      nextBoundaryOccurrence: 0,
      state: .focusing(focus),
      plan: plan,
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: anchor,
      accumulatedFocusSeconds: 0,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 21)),
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )

    let violations = SessionSnapshotValidator.validateCandidate(candidate)
    #expect(violations.contains(.invalidDeadline))
    #expect(violations.contains(.invalidWallObservation))
  }

  @Test("timed focus candidates cannot exceed their configured phase budget")
  func timedFocusCandidateCannotExceedPhaseBudget() throws {
    let plan = try SessionPlan(task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic)
    let anchor = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 20))
    let focus = FocusState(
      phase: TimingPolicy.classic.phases[0],
      timingAtAnchor: .timed(remaining: try PhaseSeconds(1)),
      wallAnchor: anchor,
      phaseEndsAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 21)),
      elapsedBeforeAnchorSeconds: 1_500,
      projectionToken: UUID(),
      phaseBoundaryToken: nil
    )
    let candidate = SessionSnapshot(
      schemaVersion: 1,
      sessionID: UUID(),
      revision: 1,
      eventSequence: 1,
      nextBoundaryOccurrence: 0,
      state: .focusing(focus),
      plan: plan,
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: anchor,
      accumulatedFocusSeconds: 0,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: anchor,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )

    #expect(SessionSnapshotValidator.validateCandidate(candidate).contains(.timingShapeMismatch))
  }

  @Test("live timing boundaries retain their owned token and exact scheduled deadline")
  func liveTimingBoundariesAreAtomic() throws {
    let plan = try SessionPlan(task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic)
    let sessionID = UUID()
    let anchor = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100))
    let phaseToken = BoundaryToken(
      sessionID: sessionID, kind: .phase, phaseID: .focus, sourceRevision: 2, occurrence: 0
    )
    let scheduledToken = BoundaryToken(
      sessionID: sessionID, kind: .scheduledCheckIn, phaseID: nil, sourceRevision: 2, occurrence: 1
    )
    let focus = FocusState(
      phase: TimingPolicy.classic.phases[0],
      timingAtAnchor: .timed(remaining: try PhaseSeconds(300)),
      wallAnchor: anchor,
      phaseEndsAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 400)),
      elapsedBeforeAnchorSeconds: 0,
      projectionToken: UUID(),
      phaseBoundaryToken: phaseToken
    )
    let candidate = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 2,
      eventSequence: 2,
      nextBoundaryOccurrence: 2,
      state: .focusing(focus),
      plan: plan,
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: anchor,
      accumulatedFocusSeconds: 0,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: anchor,
      nextScheduledCheckIn: ScheduledCheckInBoundary(
        token: scheduledToken,
        dueAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 1_001)),
        trustedRemaining: try CheckInRemainingSeconds(900)
      ),
      lastConsumedBoundaryToken: nil
    )

    #expect(SessionSnapshotValidator.validateCandidate(candidate).contains(.invalidScheduledCheckIn))
  }

  @Test("suspended focus cannot preserve cadence when configuration is manual-only")
  func suspendedFocusCannotRetainManualOnlyCadence() throws {
    let plan = try SessionPlan(task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic)
    let timestamp = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100))
    let candidate = SessionSnapshot(
      schemaVersion: 1,
      sessionID: UUID(),
      revision: 2,
      eventSequence: 2,
      nextBoundaryOccurrence: 0,
      state: .paused(PausedState(
        phase: TimingPolicy.classic.phases[0],
        timing: .timed(remaining: try PhaseSeconds(300)),
        pausedAt: timestamp,
        scheduledCheckInRemaining: try CheckInRemainingSeconds(60)
      )),
      plan: plan,
      configuration: SessionConfiguration(
        checkInSchedule: .manualOnly,
        breakSuggestionsEnabled: true,
        lowCognitiveLoadEnabled: false,
        reflectionPromptEnabled: true
      ),
      parkedThoughts: [],
      startedAt: timestamp,
      accumulatedFocusSeconds: 0,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: timestamp,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )

    #expect(SessionSnapshotValidator.validateCandidate(candidate).contains(.invalidScheduledCheckIn))
  }

  @Test("boundary tokens require an owned discriminant and published occurrence")
  func boundaryTokenMustBeWellFormedAndPublished() throws {
    let plan = try SessionPlan(task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic)
    let timestamp = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 30))
    let sessionID = UUID()
    let malformedToken = BoundaryToken(
      sessionID: sessionID,
      kind: .phase,
      phaseID: nil,
      sourceRevision: 1,
      occurrence: 0
    )
    let candidate = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 1,
      eventSequence: 1,
      nextBoundaryOccurrence: 0,
      state: .prepared(PreparedState(preparedAt: timestamp)),
      plan: plan,
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: nil,
      accumulatedFocusSeconds: 0,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: timestamp,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: malformedToken
    )

    #expect(SessionSnapshotValidator.validateCandidate(candidate).contains(.invalidBoundaryToken))
  }

  @Test("parked thoughts must be normalized, unique, and deterministically ordered")
  func parkedThoughtsRequireCanonicalContentAndOrder() {
    let timestamp = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 40))
    let thought = ParkedThought(id: UUID(), text: "   ", createdAt: timestamp)
    let candidate = SessionSnapshot(
      schemaVersion: 1,
      sessionID: nil,
      revision: 0,
      eventSequence: 0,
      nextBoundaryOccurrence: 0,
      state: .idle,
      plan: nil,
      configuration: .defaults,
      parkedThoughts: [thought],
      startedAt: nil,
      accumulatedFocusSeconds: 0,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: nil,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )

    let violations = SessionSnapshotValidator.validateCandidate(candidate)
    #expect(violations.contains(.invalidText(.thought)))
    #expect(violations.contains(.invalidIdleBaseline))
  }

  @Test("completed summaries must mirror totals and keep reflection normalized")
  func completedSummaryRequiresConsistentPrivacySafeValues() {
    let startedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 50))
    let endedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 51))
    let summary = SessionSummary(
      sessionID: UUID(),
      task: "Task",
      finalAction: "Action",
      startedAt: startedAt,
      endedAt: endedAt,
      focusedSeconds: 10,
      breakSeconds: 0,
      stopReason: .completed,
      parkedThoughtCount: 0,
      optionalReflection: "   "
    )
    let candidate = SessionSnapshot(
      schemaVersion: 1,
      sessionID: summary.sessionID,
      revision: 2,
      eventSequence: 2,
      nextBoundaryOccurrence: 0,
      state: .completed(CompletedState(summary: summary, pendingReplacementDraft: nil)),
      plan: nil,
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: startedAt,
      accumulatedFocusSeconds: 9,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: endedAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )

    let violations = SessionSnapshotValidator.validateCandidate(candidate)
    #expect(violations.contains(.invalidSummary))
    #expect(violations.contains(.invalidText(.reflection)))
  }

  @Test("review drafts freeze the current totals and parked-thought count")
  func reviewDraftRequiresCurrentSummaryValues() throws {
    let timestamp = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 70))
    let plan = try SessionPlan(task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic)
    let draft = SessionSummaryDraft(
      endedAt: timestamp,
      focusedSeconds: 9,
      breakSeconds: 2,
      parkedThoughtCount: 1,
      optionalReflection: nil
    )
    let candidate = SessionSnapshot(
      schemaVersion: 1,
      sessionID: UUID(),
      revision: 2,
      eventSequence: 2,
      nextBoundaryOccurrence: 0,
      state: .reviewing(ReviewState(draft: draft, stopReason: .completed, replacementDraft: nil)),
      plan: plan,
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: timestamp,
      accumulatedFocusSeconds: 10,
      accumulatedBreakSeconds: 2,
      lastWallObservationAt: timestamp,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )

    #expect(SessionSnapshotValidator.validateCandidate(candidate).contains(.invalidSummary))
  }

  @Test("manual-only configuration cannot carry a scheduled check-in")
  func manualOnlyScheduleRejectsPersistedBoundary() {
    let timestamp = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 60))
    let sessionID = UUID()
    let token = BoundaryToken(
      sessionID: sessionID,
      kind: .scheduledCheckIn,
      phaseID: nil,
      sourceRevision: 1,
      occurrence: 0
    )
    let candidate = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 1,
      eventSequence: 1,
      nextBoundaryOccurrence: 1,
      state: .prepared(PreparedState(preparedAt: timestamp)),
      plan: try! SessionPlan(task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic),
      configuration: SessionConfiguration(
        checkInSchedule: .manualOnly,
        breakSuggestionsEnabled: true,
        lowCognitiveLoadEnabled: false,
        reflectionPromptEnabled: true
      ),
      parkedThoughts: [],
      startedAt: nil,
      accumulatedFocusSeconds: 0,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: timestamp,
      nextScheduledCheckIn: ScheduledCheckInBoundary(
        token: token,
        dueAt: timestamp,
        trustedRemaining: try! CheckInRemainingSeconds(1)
      ),
      lastConsumedBoundaryToken: nil
    )

    #expect(SessionSnapshotValidator.validateCandidate(candidate).contains(.invalidScheduledCheckIn))
  }

  @Test("recovery states expose the complete safe-choice set")
  func recoveryStateRequiresAllSafeChoices() throws {
    let plan = try SessionPlan(task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic)
    let recovery = RecoveryState(
      reason: .negativeMonotonicElapsed,
      lastTrustworthyState: .focus(SuspendedFocusState(
        phase: TimingPolicy.classic.phases[0],
        timing: .timed(remaining: try PhaseSeconds(300)),
        resumeDisposition: .focusing,
        scheduledCheckInRemaining: nil
      )),
      safeChoices: [.reviewSession]
    )
    let candidate = SessionSnapshot(
      schemaVersion: 1,
      sessionID: UUID(),
      revision: 1,
      eventSequence: 1,
      nextBoundaryOccurrence: 0,
      state: .recoveryNeeded(recovery),
      plan: plan,
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: nil,
      accumulatedFocusSeconds: 0,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 70)),
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )

    #expect(SessionSnapshotValidator.validateCandidate(candidate).contains(.invalidRecoveryChoices))
  }

  @Test("notification requests derive kind and private content from boundary tokens")
  func notificationRequestsAreTokenDerivedAndPrivate() {
    let token = BoundaryToken(
      sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
      kind: .breakEnd,
      phaseID: nil,
      sourceRevision: 4,
      occurrence: 2
    )
    let request = SessionNotificationRequest(
      boundaryToken: token,
      fireAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 80))
    )

    #expect(request.kind == .breakEnd)
    #expect(request.contentPolicy == .privateGeneric)
    #expect(request.id.value.contains("breakEnd"))
    #expect(request.id.value.hasSuffix(".2"))
  }

  @Test("nested event payload timestamps retain field-specific validation")
  func eventPayloadTimestampUsesSpecificViolation() throws {
    let plan = try SessionPlan(task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic)
    let sessionID = UUID()
    let wall = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 90))
    let candidate = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 1,
      eventSequence: 1,
      nextBoundaryOccurrence: 0,
      state: .prepared(PreparedState(preparedAt: wall)),
      plan: plan,
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: nil,
      accumulatedFocusSeconds: 0,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: wall,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )
    let event = SessionEvent(
      sessionID: sessionID,
      sequence: 1,
      occurredAt: wall,
      payload: .phaseStarted(
        phase: TimingPolicy.classic.phases[0],
        endsAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 90.5))
      )
    )
    let context = ReductionContext(
      instant: SessionInstant(wallNow: wall.date, liveProjection: nil),
      generatedSessionID: UUID(),
      generatedThoughtID: UUID(),
      generatedProjectionToken: UUID()
    )

    let violations = SessionSnapshotValidator.validate(
      previous: .canonicalIdle,
      command: SessionCommand(expectedRevision: 0, intent: .prepare(SessionDraft(plan: plan))),
      candidate: candidate,
      emittedEvents: [event],
      context: context
    )
    #expect(violations.contains(.nonCanonicalTimestamp(.eventPhaseStartedEndsAt)))
  }

  @Test("post-start lifecycle snapshots retain identity and start timestamp")
  func postStartStateRequiresIdentityAndStartTimestamp() throws {
    let plan = try SessionPlan(task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic)
    let anchor = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100))
    let focus = FocusState(
      phase: TimingPolicy.classic.phases[0],
      timingAtAnchor: .timed(remaining: try PhaseSeconds(300)),
      wallAnchor: anchor,
      phaseEndsAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 400)),
      elapsedBeforeAnchorSeconds: 0,
      projectionToken: UUID(),
      phaseBoundaryToken: nil
    )
    let candidate = SessionSnapshot(
      schemaVersion: 1,
      sessionID: nil,
      revision: 1,
      eventSequence: 1,
      nextBoundaryOccurrence: 0,
      state: .focusing(focus),
      plan: plan,
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: nil,
      accumulatedFocusSeconds: 0,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: anchor,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )

    let violations = SessionSnapshotValidator.validateCandidate(candidate)
    #expect(violations.contains(.invalidIdentity))
    #expect(violations.contains(.invalidStartTimestamp))
  }

  @Test("check-in continuations cannot mix suspended and phase-boundary shapes")
  func checkInContinuationShapesAreDisjoint() throws {
    let plan = try SessionPlan(task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic)
    let timestamp = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 110))
    let state = CheckInState(
      suspended: nil,
      trigger: .manual,
      continuation: .resumeSuspended,
      phaseBoundaryScheduledCheckInRemaining: try CheckInRemainingSeconds(1)
    )
    let candidate = SessionSnapshot(
      schemaVersion: 1,
      sessionID: UUID(),
      revision: 2,
      eventSequence: 2,
      nextBoundaryOccurrence: 0,
      state: .checkingIn(state),
      plan: plan,
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: timestamp,
      accumulatedFocusSeconds: 0,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: timestamp,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )

    let violations = SessionSnapshotValidator.validateCandidate(candidate)
    #expect(violations.contains(.timingShapeMismatch))
    #expect(violations.contains(.invalidScheduledCheckIn))
  }

  @Test("relational candidates cannot regress totals or boundary occurrence")
  func relationalCountersNeverRegress() {
    let previous = SessionSnapshot(
      schemaVersion: 1,
      sessionID: nil,
      revision: 2,
      eventSequence: 0,
      nextBoundaryOccurrence: 5,
      state: .idle,
      plan: nil,
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: nil,
      accumulatedFocusSeconds: 10,
      accumulatedBreakSeconds: 3,
      lastWallObservationAt: nil,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )
    let candidate = SessionSnapshot(
      schemaVersion: 1,
      sessionID: nil,
      revision: 3,
      eventSequence: 0,
      nextBoundaryOccurrence: 4,
      state: .idle,
      plan: nil,
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: nil,
      accumulatedFocusSeconds: 9,
      accumulatedBreakSeconds: 2,
      lastWallObservationAt: nil,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )
    let context = ReductionContext(
      instant: SessionInstant(wallNow: Date(timeIntervalSinceReferenceDate: 0), liveProjection: nil),
      generatedSessionID: UUID(),
      generatedThoughtID: UUID(),
      generatedProjectionToken: UUID()
    )

    let violations = SessionSnapshotValidator.validate(
      previous: previous,
      command: SessionCommand(expectedRevision: 2, intent: .start),
      candidate: candidate,
      emittedEvents: [],
      context: context
    )
    #expect(violations.contains(.counterRegression))
    #expect(violations.contains(.invalidBoundaryOccurrence))
  }

  @Test("break snapshots require a normalized proposed re-entry action")
  func breakStateRequiresProposedAction() throws {
    let plan = try SessionPlan(task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic)
    let anchor = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 120))
    let suspended = SuspendedFocusState(
      phase: TimingPolicy.classic.phases[0],
      timing: .timed(remaining: try PhaseSeconds(300)),
      resumeDisposition: .focusing,
      scheduledCheckInRemaining: nil
    )
    let state = BreakState(
      choice: BreakChoice(kind: .quiet, duration: .openEnded),
      timingAtAnchor: .openEnded,
      wallAnchor: anchor,
      endsAt: nil,
      elapsedBeforeAnchorSeconds: 0,
      projectionToken: UUID(),
      boundaryToken: nil,
      resumeTarget: suspended,
      proposedAction: "  "
    )
    let candidate = SessionSnapshot(
      schemaVersion: 1,
      sessionID: UUID(),
      revision: 2,
      eventSequence: 2,
      nextBoundaryOccurrence: 0,
      state: .breaking(state),
      plan: plan,
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: anchor,
      accumulatedFocusSeconds: 0,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: anchor,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )

    #expect(SessionSnapshotValidator.validateCandidate(candidate).contains(.invalidText(.revisedAction)))
  }

  @Test("every lifecycle state has a constructible internal fixture and exact kind")
  func lifecycleFixturesCoverEveryState() throws {
    let timestamp = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 130))
    let sessionID = UUID()
    let plan = try SessionPlan(task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic)
    let phase = TimingPolicy.classic.phases[0]
    let suspended = SuspendedFocusState(
      phase: phase,
      timing: .timed(remaining: try PhaseSeconds(300)),
      resumeDisposition: .focusing,
      scheduledCheckInRemaining: nil
    )
    let reviewDraft = SessionSummaryDraft(
      endedAt: timestamp,
      focusedSeconds: 1,
      breakSeconds: 0,
      parkedThoughtCount: 0,
      optionalReflection: nil
    )
    let summary = SessionSummary(
      sessionID: sessionID,
      task: "Task",
      finalAction: "Action",
      startedAt: timestamp,
      endedAt: timestamp,
      focusedSeconds: 1,
      breakSeconds: 0,
      stopReason: .completed,
      parkedThoughtCount: 0,
      optionalReflection: nil
    )
    let states: [SessionState] = [
      .idle,
      .prepared(PreparedState(preparedAt: timestamp)),
      .focusing(FocusState(
        phase: phase, timingAtAnchor: .timed(remaining: try PhaseSeconds(300)),
        wallAnchor: timestamp, phaseEndsAt: timestamp, elapsedBeforeAnchorSeconds: 0,
        projectionToken: UUID(), phaseBoundaryToken: nil
      )),
      .paused(PausedState(
        phase: phase, timing: .timed(remaining: try PhaseSeconds(300)), pausedAt: timestamp,
        scheduledCheckInRemaining: nil
      )),
      .checkingIn(CheckInState(
        suspended: suspended, trigger: .manual, continuation: .resumeSuspended,
        phaseBoundaryScheduledCheckInRemaining: nil
      )),
      .breaking(BreakState(
        choice: BreakChoice(kind: .quiet, duration: .openEnded), timingAtAnchor: .openEnded,
        wallAnchor: timestamp, endsAt: nil, elapsedBeforeAnchorSeconds: 0,
        projectionToken: UUID(), boundaryToken: nil, resumeTarget: suspended, proposedAction: "Return"
      )),
      .reentering(ReentryState(resumeTarget: suspended, proposedAction: "Return", enteredAt: timestamp)),
      .reviewing(ReviewState(draft: reviewDraft, stopReason: .completed, replacementDraft: nil)),
      .completed(CompletedState(summary: summary, pendingReplacementDraft: nil)),
      .recoveryNeeded(RecoveryState(
        reason: .missingLiveProjection, lastTrustworthyState: .focus(suspended),
        safeChoices: Set(ClockRecoveryChoice.allCases)
      )),
    ]

    #expect(states.map(\.kind) == SessionStateKind.allCases)
    #expect(plan.timingPolicy.id == .classic)
  }
}
