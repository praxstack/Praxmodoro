import Foundation
import Testing

@testable import PraxodoroCore

@Suite("Session transitions")
struct SessionTransitionTests {
  @Test("idle preparation creates the complete first session revision")
  func idlePreparationCreatesFirstRevision() throws {
    let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
    let wall = Date(timeIntervalSinceReferenceDate: 10)
    let timestamp = SessionTimestamp(unchecked: wall)
    let plan = try SessionPlan(
      task: "  Write report  ",
      firstAction: "  Open notes  ",
      capacity: .steady,
      timingPolicy: .classic
    )
    let draft = SessionDraft(plan: plan)
    let context = ReductionContext(
      instant: SessionInstant(wallNow: wall, liveProjection: nil),
      generatedSessionID: sessionID,
      generatedThoughtID: UUID(),
      generatedProjectionToken: UUID()
    )

    let outcome = SessionReducer.reduce(
      snapshot: .canonicalIdle,
      command: SessionCommand(expectedRevision: 0, intent: .prepare(draft)),
      context: context
    )

    let expectedSnapshot = SessionSnapshot(
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
    let expectedEvent = SessionEvent(
      sessionID: sessionID,
      sequence: 1,
      occurredAt: timestamp,
      payload: .sessionPrepared(policy: .classic, capacitySpecified: true)
    )
    #expect(
      outcome
        == .transition(
          Reduction(snapshot: expectedSnapshot, events: [expectedEvent], effects: []))
    )
  }

  @Test("revision and idle transition precedence consume no counters")
  func revisionAndIdleTransitionPrecedence() throws {
    let snapshot = SessionSnapshot.canonicalIdle
    let context = ReductionContext(
      instant: SessionInstant(
        wallNow: Date(timeIntervalSinceReferenceDate: .nan), liveProjection: nil),
      generatedSessionID: UUID(),
      generatedThoughtID: UUID(),
      generatedProjectionToken: UUID()
    )

    #expect(
      SessionReducer.reduce(
        snapshot: snapshot,
        command: SessionCommand(expectedRevision: 9, intent: .pause),
        context: context
      )
        == .rejected(
          snapshot: snapshot,
          reason: .staleRevision(expected: 9, actual: 0))
    )
    #expect(
      SessionReducer.reduce(
        snapshot: snapshot,
        command: SessionCommand(expectedRevision: 0, intent: .pause),
        context: context
      )
        == .rejected(
          snapshot: snapshot,
          reason: .invalidTransition(state: .idle, intent: .pause))
    )
    #expect(
      SessionReducer.reduce(
        snapshot: snapshot,
        command: SessionCommand(expectedRevision: 0, intent: .reconcileTime(.live)),
        context: context
      ) == .noChange(snapshot: snapshot, reason: .observationIrrelevant)
    )

    let plan = try SessionPlan(
      task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic)
    #expect(
      SessionReducer.reduce(
        snapshot: snapshot,
        command: SessionCommand(
          expectedRevision: 0,
          intent: .prepare(SessionDraft(plan: plan))
        ),
        context: context
      ) == .failed(snapshot: snapshot, reason: .nonFiniteWallObservation)
    )
  }

  @Test("prepared updates emit exact ordered field changes")
  func preparedUpdatesEmitExactOrderedFieldChanges() throws {
    let sessionID = UUID()
    let initialPlan = try SessionPlan(
      task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic)
    let initialContext = ReductionContext(
      instant: SessionInstant(
        wallNow: Date(timeIntervalSinceReferenceDate: 10), liveProjection: nil),
      generatedSessionID: sessionID,
      generatedThoughtID: UUID(),
      generatedProjectionToken: UUID()
    )
    let preparedOutcome = SessionReducer.reduce(
      snapshot: .canonicalIdle,
      command: SessionCommand(
        expectedRevision: 0,
        intent: .prepare(SessionDraft(plan: initialPlan))
      ),
      context: initialContext
    )
    guard case let .transition(preparation) = preparedOutcome else {
      Issue.record("expected preparation transition")
      return
    }

    #expect(
      SessionReducer.reduce(
        snapshot: preparation.snapshot,
        command: SessionCommand(
          expectedRevision: 1,
          intent: .updatePrepared(SessionDraft(plan: initialPlan))
        ),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: .nan), liveProjection: nil),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: UUID()
        )
      ) == .noChange(snapshot: preparation.snapshot, reason: .alreadyInRequestedState)
    )

    let changedPlan = try SessionPlan(
      task: "Revised task",
      firstAction: "Action",
      capacity: .steady,
      timingPolicy: .flow
    )
    let changedConfiguration = SessionConfiguration(
      checkInSchedule: .manualOnly,
      breakSuggestionsEnabled: false,
      lowCognitiveLoadEnabled: true,
      reflectionPromptEnabled: false
    )
    let changedDraft = SessionDraft(
      plan: changedPlan,
      configuration: changedConfiguration
    )
    let changedAt = SessionTimestamp(
      unchecked: Date(timeIntervalSinceReferenceDate: 20))
    let changedOutcome = SessionReducer.reduce(
      snapshot: preparation.snapshot,
      command: SessionCommand(
        expectedRevision: 1,
        intent: .updatePrepared(changedDraft)
      ),
      context: ReductionContext(
        instant: SessionInstant(wallNow: changedAt.date, liveProjection: nil),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: UUID()
      )
    )
    guard case let .transition(changed) = changedOutcome else {
      Issue.record("expected prepared update transition")
      return
    }

    #expect(changed.snapshot.revision == 2)
    #expect(changed.snapshot.eventSequence == 3)
    #expect(changed.snapshot.sessionID == sessionID)
    #expect(changed.snapshot.state == preparation.snapshot.state)
    #expect(changed.snapshot.plan == changedPlan)
    #expect(changed.snapshot.configuration == changedConfiguration)
    #expect(changed.snapshot.lastWallObservationAt == changedAt)
    #expect(changed.effects.isEmpty)
    #expect(changed.events.map(\.sequence) == [2, 3])
    #expect(changed.events.map(\.occurredAt) == [changedAt, changedAt])
    #expect(
      changed.events.map(\.payload)
        == [
          .planUpdated(
            fields: SessionPlanFieldChanges([.task, .capacity, .timingPolicy])!),
          .configurationChanged(
            fields: SessionConfigurationFieldChanges([
              .checkInSchedule,
              .breakSuggestionsEnabled,
              .lowCognitiveLoadEnabled,
              .reflectionPromptEnabled,
            ])!),
        ]
    )
  }

  @Test("prepared start installs exact live focus state and effects")
  func preparedStartInstallsExactLiveFocusStateAndEffects() throws {
    let sessionID = UUID()
    let projectionToken = UUID()
    let plan = try SessionPlan(
      task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic)
    let prepareContext = ReductionContext(
      instant: SessionInstant(
        wallNow: Date(timeIntervalSinceReferenceDate: 10), liveProjection: nil),
      generatedSessionID: sessionID,
      generatedThoughtID: UUID(),
      generatedProjectionToken: UUID()
    )
    guard
      case let .transition(preparation) = SessionReducer.reduce(
        snapshot: .canonicalIdle,
        command: SessionCommand(
          expectedRevision: 0,
          intent: .prepare(SessionDraft(plan: plan))
        ),
        context: prepareContext
      )
    else {
      Issue.record("expected preparation transition")
      return
    }

    let wall = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100))
    let outcome = SessionReducer.reduce(
      snapshot: preparation.snapshot,
      command: SessionCommand(expectedRevision: 1, intent: .start),
      context: ReductionContext(
        instant: SessionInstant(wallNow: wall.date, liveProjection: nil),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: projectionToken
      )
    )
    guard case let .transition(reduction) = outcome else {
      Issue.record("expected start transition")
      return
    }
    let phaseToken = BoundaryToken(
      sessionID: sessionID,
      kind: .phase,
      phaseID: .focus,
      sourceRevision: 2,
      occurrence: 0
    )
    let scheduledToken = BoundaryToken(
      sessionID: sessionID,
      kind: .scheduledCheckIn,
      phaseID: nil,
      sourceRevision: 2,
      occurrence: 1
    )
    let phaseDeadline = SessionTimestamp(
      unchecked: Date(timeIntervalSinceReferenceDate: 1_600))
    let scheduledDeadline = SessionTimestamp(
      unchecked: Date(timeIntervalSinceReferenceDate: 1_000))

    #expect(reduction.snapshot.revision == 2)
    #expect(reduction.snapshot.eventSequence == 3)
    #expect(reduction.snapshot.nextBoundaryOccurrence == 2)
    #expect(reduction.snapshot.startedAt == wall)
    #expect(reduction.snapshot.lastWallObservationAt == wall)
    #expect(
      reduction.snapshot.state
        == .focusing(
          FocusState(
            phase: TimingPolicy.classic.phases[0],
            timingAtAnchor: .timed(remaining: try PhaseSeconds(1_500)),
            wallAnchor: wall,
            phaseEndsAt: phaseDeadline,
            elapsedBeforeAnchorSeconds: 0,
            projectionToken: projectionToken,
            phaseBoundaryToken: phaseToken
          ))
    )
    #expect(
      reduction.snapshot.nextScheduledCheckIn
        == ScheduledCheckInBoundary(
          token: scheduledToken,
          dueAt: scheduledDeadline,
          trustedRemaining: try CheckInRemainingSeconds(900)
        ))
    #expect(reduction.events.map(\.sequence) == [2, 3])
    #expect(
      reduction.events.map(\.payload)
        == [
          .sessionStarted,
          .phaseStarted(phase: TimingPolicy.classic.phases[0], endsAt: phaseDeadline),
        ]
    )
    #expect(
      reduction.effects
        == [
          .scheduleNotification(
            SessionNotificationRequest(boundaryToken: scheduledToken, fireAt: scheduledDeadline)),
          .announceAccessibility(.focusStarted),
          .invalidateDisplayProjection(projectionToken: projectionToken),
        ]
    )
  }

  @Test("prepared start rejects empty task and action before clock use")
  func preparedStartRejectsInvalidPlanBeforeClockUse() throws {
    let invalidPlan = try SessionPlan(
      task: "", firstAction: "", capacity: nil, timingPolicy: .classic)
    let context = ReductionContext(
      instant: SessionInstant(
        wallNow: Date(timeIntervalSinceReferenceDate: 10), liveProjection: nil),
      generatedSessionID: UUID(),
      generatedThoughtID: UUID(),
      generatedProjectionToken: UUID()
    )
    guard
      case let .transition(preparation) = SessionReducer.reduce(
        snapshot: .canonicalIdle,
        command: SessionCommand(
          expectedRevision: 0,
          intent: .prepare(SessionDraft(plan: invalidPlan))
        ),
        context: context
      )
    else {
      Issue.record("expected preparation transition")
      return
    }

    #expect(
      SessionReducer.reduce(
        snapshot: preparation.snapshot,
        command: SessionCommand(expectedRevision: 1, intent: .start),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: .nan), liveProjection: nil),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: UUID()
        )
      )
        == .rejected(
          snapshot: preparation.snapshot,
          reason: .invalidPlan(fields: [.task, .firstAction]))
    )
  }

  @Test("focus pause freezes paired time and clears live boundaries")
  func focusPauseFreezesPairedTimeAndClearsLiveBoundaries() throws {
    let sessionID = UUID()
    let projectionToken = UUID()
    let plan = try SessionPlan(
      task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic)
    let prepareContext = ReductionContext(
      instant: SessionInstant(
        wallNow: Date(timeIntervalSinceReferenceDate: 10), liveProjection: nil),
      generatedSessionID: sessionID,
      generatedThoughtID: UUID(),
      generatedProjectionToken: UUID()
    )
    guard
      case let .transition(preparation) = SessionReducer.reduce(
        snapshot: .canonicalIdle,
        command: SessionCommand(
          expectedRevision: 0, intent: .prepare(SessionDraft(plan: plan))),
        context: prepareContext
      ),
      case let .transition(started) = SessionReducer.reduce(
        snapshot: preparation.snapshot,
        command: SessionCommand(expectedRevision: 1, intent: .start),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: 100), liveProjection: nil),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: projectionToken
        ))
    else {
      Issue.record("expected a live focus fixture")
      return
    }
    let previousWinner = try #require(started.snapshot.nextScheduledCheckIn)
    let observedWall = SessionTimestamp(
      unchecked: Date(timeIntervalSinceReferenceDate: 111))
    let expectedWall = SessionTimestamp(
      unchecked: Date(timeIntervalSinceReferenceDate: 110))

    let outcome = SessionReducer.reduce(
      snapshot: started.snapshot,
      command: SessionCommand(expectedRevision: 2, intent: .pause),
      context: ReductionContext(
        instant: SessionInstant(
          wallNow: observedWall.date,
          liveProjection: LiveProjectionObservation(
            projectionToken: projectionToken,
            rawWallAtProjectionAnchor: Date(timeIntervalSinceReferenceDate: 100),
            monotonicElapsedSinceAnchor: .seconds(10)
          )),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: UUID()
      )
    )
    guard case let .transition(reduction) = outcome else {
      Issue.record("expected pause transition")
      return
    }

    #expect(reduction.snapshot.revision == 3)
    #expect(reduction.snapshot.eventSequence == 4)
    #expect(reduction.snapshot.accumulatedFocusSeconds == 10)
    #expect(reduction.snapshot.accumulatedBreakSeconds == 0)
    #expect(reduction.snapshot.lastWallObservationAt == observedWall)
    #expect(reduction.snapshot.nextScheduledCheckIn == nil)
    #expect(
      reduction.snapshot.state
        == .paused(
          PausedState(
            phase: TimingPolicy.classic.phases[0],
            timing: .timed(remaining: try PhaseSeconds(1_490)),
            pausedAt: expectedWall,
            scheduledCheckInRemaining: try CheckInRemainingSeconds(890)
          ))
    )
    #expect(reduction.events.count == 1)
    #expect(reduction.events[0].sequence == 4)
    #expect(reduction.events[0].occurredAt == observedWall)
    #expect(
      reduction.events[0].payload
        == .phasePaused(timing: .timed(remaining: try PhaseSeconds(1_490))))
    #expect(
      reduction.effects
        == [
          .cancelNotification(SessionNotificationID(boundaryToken: previousWinner.token)),
          .invalidateDisplayProjection(projectionToken: nil),
        ]
    )
  }

  @Test("due scheduled check-in supersedes a racing pause")
  func dueScheduledCheckInSupersedesPause() throws {
    let sessionID = UUID()
    let projectionToken = UUID()
    let plan = try SessionPlan(
      task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic)
    let initialContext = ReductionContext(
      instant: SessionInstant(
        wallNow: Date(timeIntervalSinceReferenceDate: 10), liveProjection: nil),
      generatedSessionID: sessionID,
      generatedThoughtID: UUID(),
      generatedProjectionToken: UUID()
    )
    guard
      case let .transition(preparation) = SessionReducer.reduce(
        snapshot: .canonicalIdle,
        command: SessionCommand(
          expectedRevision: 0, intent: .prepare(SessionDraft(plan: plan))),
        context: initialContext
      ),
      case let .transition(started) = SessionReducer.reduce(
        snapshot: preparation.snapshot,
        command: SessionCommand(expectedRevision: 1, intent: .start),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: 100), liveProjection: nil),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: projectionToken
        )),
      let scheduled = started.snapshot.nextScheduledCheckIn
    else {
      Issue.record("expected a scheduled focus fixture")
      return
    }
    let dueAt = scheduled.dueAt
    let outcome = SessionReducer.reduce(
      snapshot: started.snapshot,
      command: SessionCommand(expectedRevision: 2, intent: .pause),
      context: ReductionContext(
        instant: SessionInstant(
          wallNow: dueAt.date,
          liveProjection: LiveProjectionObservation(
            projectionToken: projectionToken,
            rawWallAtProjectionAnchor: Date(timeIntervalSinceReferenceDate: 100),
            monotonicElapsedSinceAnchor: .seconds(900)
          )),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: UUID()
      )
    )
    guard case let .transition(reduction) = outcome else {
      Issue.record("expected the scheduled winner to supersede pause")
      return
    }

    #expect(reduction.snapshot.revision == 3)
    #expect(reduction.snapshot.eventSequence == 4)
    #expect(reduction.snapshot.accumulatedFocusSeconds == 900)
    #expect(reduction.snapshot.lastWallObservationAt == dueAt)
    #expect(reduction.snapshot.nextScheduledCheckIn == nil)
    #expect(reduction.snapshot.lastConsumedBoundaryToken == scheduled.token)
    #expect(
      reduction.snapshot.state
        == .checkingIn(
          CheckInState(
            suspended: SuspendedFocusState(
              phase: TimingPolicy.classic.phases[0],
              timing: .timed(remaining: try PhaseSeconds(600)),
              resumeDisposition: .focusing,
              scheduledCheckInRemaining: nil
            ),
            trigger: .scheduled(scheduled.token),
            continuation: .resumeSuspended,
            phaseBoundaryScheduledCheckInRemaining: nil
          ))
    )
    #expect(
      reduction.events.map(\.payload) == [
        .checkInOpened(trigger: .scheduled(scheduled.token), continuation: .resumeSuspended)
      ])
    #expect(reduction.events[0].occurredAt == dueAt)
    #expect(
      reduction.effects
        == [
          .cancelNotification(SessionNotificationID(boundaryToken: scheduled.token)),
          .announceAccessibility(.checkInPresented),
          .invalidateDisplayProjection(projectionToken: nil),
        ]
    )
  }
}
