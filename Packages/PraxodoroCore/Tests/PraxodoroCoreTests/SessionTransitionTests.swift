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

  @Test("due phase boundary supersedes pause with exact policy continuation")
  func duePhaseBoundarySupersedesPauseWithContinuation() throws {
    let sessionID = UUID()
    let projectionToken = UUID()
    let plan = try SessionPlan(
      task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .gentleStart)
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
      case let .focusing(focus) = started.snapshot.state,
      let phaseToken = focus.phaseBoundaryToken,
      let phaseDue = focus.phaseEndsAt
    else {
      Issue.record("expected a timed Gentle Start fixture")
      return
    }
    let outcome = SessionReducer.reduce(
      snapshot: started.snapshot,
      command: SessionCommand(expectedRevision: 2, intent: .pause),
      context: ReductionContext(
        instant: SessionInstant(
          wallNow: phaseDue.date,
          liveProjection: LiveProjectionObservation(
            projectionToken: projectionToken,
            rawWallAtProjectionAnchor: Date(timeIntervalSinceReferenceDate: 100),
            monotonicElapsedSinceAnchor: .seconds(300)
          )),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: UUID()
      )
    )
    guard case let .transition(reduction) = outcome else {
      Issue.record("expected the phase winner to supersede pause")
      return
    }
    let nextPhase = TimingPolicy.gentleStart.phases[1]

    #expect(reduction.snapshot.revision == 3)
    #expect(reduction.snapshot.eventSequence == 5)
    #expect(reduction.snapshot.accumulatedFocusSeconds == 300)
    #expect(reduction.snapshot.lastConsumedBoundaryToken == phaseToken)
    #expect(reduction.snapshot.nextScheduledCheckIn == nil)
    #expect(
      reduction.snapshot.state
        == .checkingIn(
          CheckInState(
            suspended: nil,
            trigger: .phaseBoundary(phaseToken),
            continuation: .startPhase(nextPhase),
            phaseBoundaryScheduledCheckInRemaining: try CheckInRemainingSeconds(600)
          ))
    )
    #expect(
      reduction.events.map(\.payload)
        == [
          .phaseElapsed(token: phaseToken),
          .checkInOpened(
            trigger: .phaseBoundary(phaseToken), continuation: .startPhase(nextPhase)),
        ]
    )
    #expect(
      reduction.effects
        == [
          .cancelNotification(SessionNotificationID(boundaryToken: phaseToken)),
          .playSound(.gentleBoundary),
          .playHaptic(.gentleBoundary),
          .announceAccessibility(.checkInPresented),
          .invalidateDisplayProjection(projectionToken: nil),
        ]
    )
  }

  @Test("paused resume reanchors saved timing without accruing focus")
  func pausedResumeReanchorsSavedTiming() throws {
    let sessionID = UUID()
    let firstProjectionToken = UUID()
    let resumedProjectionToken = UUID()
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
          generatedProjectionToken: firstProjectionToken
        )),
      case let .transition(paused) = SessionReducer.reduce(
        snapshot: started.snapshot,
        command: SessionCommand(expectedRevision: 2, intent: .pause),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: 110),
            liveProjection: LiveProjectionObservation(
              projectionToken: firstProjectionToken,
              rawWallAtProjectionAnchor: Date(timeIntervalSinceReferenceDate: 100),
              monotonicElapsedSinceAnchor: .seconds(10)
            )),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: UUID()
        ))
    else {
      Issue.record("expected a paused fixture")
      return
    }
    let resumedAt = SessionTimestamp(
      unchecked: Date(timeIntervalSinceReferenceDate: 200))
    let outcome = SessionReducer.reduce(
      snapshot: paused.snapshot,
      command: SessionCommand(expectedRevision: 3, intent: .resume),
      context: ReductionContext(
        instant: SessionInstant(wallNow: resumedAt.date, liveProjection: nil),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: resumedProjectionToken
      )
    )
    guard case let .transition(reduction) = outcome else {
      Issue.record("expected resume transition")
      return
    }
    let phaseDeadline = SessionTimestamp(
      unchecked: Date(timeIntervalSinceReferenceDate: 1_690))
    let scheduledDeadline = SessionTimestamp(
      unchecked: Date(timeIntervalSinceReferenceDate: 1_090))

    #expect(reduction.snapshot.revision == 4)
    #expect(reduction.snapshot.eventSequence == 5)
    #expect(reduction.snapshot.nextBoundaryOccurrence == 4)
    #expect(reduction.snapshot.accumulatedFocusSeconds == 10)
    #expect(reduction.snapshot.startedAt?.date.timeIntervalSinceReferenceDate == 100)
    #expect(
      reduction.snapshot.state
        == .focusing(
          FocusState(
            phase: TimingPolicy.classic.phases[0],
            timingAtAnchor: .timed(remaining: try PhaseSeconds(1_490)),
            wallAnchor: resumedAt,
            phaseEndsAt: phaseDeadline,
            elapsedBeforeAnchorSeconds: 0,
            projectionToken: resumedProjectionToken,
            phaseBoundaryToken: BoundaryToken(
              sessionID: sessionID,
              kind: .phase,
              phaseID: .focus,
              sourceRevision: 4,
              occurrence: 2
            )
          ))
    )
    let scheduled = try #require(reduction.snapshot.nextScheduledCheckIn)
    let expectedScheduledRemaining = try CheckInRemainingSeconds(890)
    #expect(scheduled.dueAt == scheduledDeadline)
    #expect(scheduled.trustedRemaining == expectedScheduledRemaining)
    #expect(scheduled.token.occurrence == 3)
    #expect(
      reduction.events.map(\.payload)
        == [.phaseResumed(phase: TimingPolicy.classic.phases[0], endsAt: phaseDeadline)])
    #expect(
      reduction.effects
        == [
          .scheduleNotification(
            SessionNotificationRequest(
              boundaryToken: scheduled.token, fireAt: scheduledDeadline)),
          .announceAccessibility(.focusStarted),
          .invalidateDisplayProjection(projectionToken: resumedProjectionToken),
        ]
    )
  }

  @Test(
    "paused check-in preserves frozen resume disposition",
    arguments: [CheckInTrigger.manual, .pauseOffer]
  )
  func pausedCheckInPreservesFrozenResumeDisposition(trigger: CheckInTrigger) throws {
    let sessionID = UUID()
    let plan = try SessionPlan(
      task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic)
    let pausedAt = SessionTimestamp(
      unchecked: Date(timeIntervalSinceReferenceDate: 110))
    let observedAt = SessionTimestamp(
      unchecked: Date(timeIntervalSinceReferenceDate: 300))
    let snapshot = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 3,
      eventSequence: 4,
      nextBoundaryOccurrence: 2,
      state: .paused(
        PausedState(
          phase: TimingPolicy.classic.phases[0],
          timing: .timed(remaining: try PhaseSeconds(1_490)),
          pausedAt: pausedAt,
          scheduledCheckInRemaining: try CheckInRemainingSeconds(890)
        )),
      plan: plan,
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: SessionTimestamp(
        unchecked: Date(timeIntervalSinceReferenceDate: 100)),
      accumulatedFocusSeconds: 10,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: pausedAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )

    let outcome = SessionReducer.reduce(
      snapshot: snapshot,
      command: SessionCommand(expectedRevision: 3, intent: .openCheckIn(trigger)),
      context: ReductionContext(
        instant: SessionInstant(wallNow: observedAt.date, liveProjection: nil),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: UUID()
      )
    )
    guard case let .transition(reduction) = outcome else {
      Issue.record("expected paused check-in transition")
      return
    }
    let suspended = SuspendedFocusState(
      phase: TimingPolicy.classic.phases[0],
      timing: .timed(remaining: try PhaseSeconds(1_490)),
      resumeDisposition: .paused,
      scheduledCheckInRemaining: try CheckInRemainingSeconds(890)
    )

    #expect(reduction.snapshot.revision == 4)
    #expect(reduction.snapshot.eventSequence == 5)
    #expect(reduction.snapshot.accumulatedFocusSeconds == 10)
    #expect(reduction.snapshot.lastWallObservationAt == observedAt)
    #expect(SessionSnapshotValidator.validateCandidate(reduction.snapshot).isEmpty)
    #expect(
      reduction.snapshot.state
        == .checkingIn(
          CheckInState(
            suspended: suspended,
            trigger: trigger,
            continuation: .resumeSuspended,
            phaseBoundaryScheduledCheckInRemaining: nil
          ))
    )
    #expect(
      reduction.events.map(\.payload)
        == [.checkInOpened(trigger: trigger, continuation: .resumeSuspended)])
    #expect(reduction.events[0].occurredAt == observedAt)
    #expect(
      reduction.effects
        == [
          .announceAccessibility(.checkInPresented),
          .invalidateDisplayProjection(projectionToken: nil),
        ]
    )
  }

  @Test("paused break starts from the frozen focus target")
  func pausedBreakStartsFromFrozenFocusTarget() throws {
    let sessionID = UUID()
    let projectionToken = UUID()
    let plan = try SessionPlan(
      task: "Task", firstAction: "Return here", capacity: nil, timingPolicy: .classic)
    let pausedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 110))
    let observedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 300))
    let choice = BreakChoice(kind: .move, duration: .timed(.five))
    let snapshot = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 3,
      eventSequence: 4,
      nextBoundaryOccurrence: 2,
      state: .paused(
        PausedState(
          phase: TimingPolicy.classic.phases[0],
          timing: .timed(remaining: try PhaseSeconds(1_490)),
          pausedAt: pausedAt,
          scheduledCheckInRemaining: try CheckInRemainingSeconds(890)
        )),
      plan: plan,
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100)),
      accumulatedFocusSeconds: 10,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: pausedAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )

    let outcome = SessionReducer.reduce(
      snapshot: snapshot,
      command: SessionCommand(expectedRevision: 3, intent: .requestBreak(choice)),
      context: ReductionContext(
        instant: SessionInstant(wallNow: observedAt.date, liveProjection: nil),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: projectionToken
      )
    )
    guard case let .transition(reduction) = outcome else {
      Issue.record("expected paused break transition")
      return
    }
    let boundaryToken = BoundaryToken(
      sessionID: sessionID,
      kind: .breakEnd,
      phaseID: nil,
      sourceRevision: 4,
      occurrence: 2
    )
    let endsAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 600))
    let resumeTarget = SuspendedFocusState(
      phase: TimingPolicy.classic.phases[0],
      timing: .timed(remaining: try PhaseSeconds(1_490)),
      resumeDisposition: .paused,
      scheduledCheckInRemaining: try CheckInRemainingSeconds(890)
    )

    #expect(reduction.snapshot.revision == 4)
    #expect(reduction.snapshot.eventSequence == 5)
    #expect(reduction.snapshot.nextBoundaryOccurrence == 3)
    #expect(reduction.snapshot.accumulatedFocusSeconds == 10)
    #expect(reduction.snapshot.lastWallObservationAt == observedAt)
    #expect(SessionSnapshotValidator.validateCandidate(reduction.snapshot).isEmpty)
    #expect(
      reduction.snapshot.state
        == .breaking(
          BreakState(
            choice: choice,
            timingAtAnchor: .timed(remaining: try PhaseSeconds(300)),
            wallAnchor: observedAt,
            endsAt: endsAt,
            elapsedBeforeAnchorSeconds: 0,
            projectionToken: projectionToken,
            boundaryToken: boundaryToken,
            resumeTarget: resumeTarget,
            proposedAction: "Return here"
          ))
    )
    #expect(
      reduction.events.map(\.payload)
        == [.breakStarted(kind: .move, duration: .timed(.five), endsAt: endsAt)])
    #expect(reduction.events[0].occurredAt == observedAt)
    #expect(
      reduction.effects
        == [
          .scheduleNotification(
            SessionNotificationRequest(boundaryToken: boundaryToken, fireAt: endsAt)),
          .announceAccessibility(.breakStarted),
          .invalidateDisplayProjection(projectionToken: projectionToken),
        ]
    )
  }

  @Test("paused thought parking normalizes text and preserves deterministic order")
  func pausedThoughtParkingNormalizesTextAndPreservesDeterministicOrder() throws {
    let sessionID = UUID()
    let thoughtID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let laterThoughtID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let pausedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 110))
    let observedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 300))
    let laterAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 301))
    let snapshot = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 3,
      eventSequence: 4,
      nextBoundaryOccurrence: 2,
      state: .paused(
        PausedState(
          phase: TimingPolicy.classic.phases[0],
          timing: .timed(remaining: try PhaseSeconds(1_490)),
          pausedAt: pausedAt,
          scheduledCheckInRemaining: try CheckInRemainingSeconds(890)
        )),
      plan: try SessionPlan(
        task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic),
      configuration: .defaults,
      parkedThoughts: [
        ParkedThought(id: laterThoughtID, text: "Later", createdAt: laterAt)
      ],
      startedAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100)),
      accumulatedFocusSeconds: 10,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: pausedAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )

    #expect(
      SessionReducer.reduce(
        snapshot: snapshot,
        command: SessionCommand(expectedRevision: 3, intent: .parkThought(" \n ")),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: .nan), liveProjection: nil),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: UUID()
        )
      )
        == .rejected(snapshot: snapshot, reason: .invalidText(.thought))
    )

    let outcome = SessionReducer.reduce(
      snapshot: snapshot,
      command: SessionCommand(expectedRevision: 3, intent: .parkThought("  Capture this  \n")),
      context: ReductionContext(
        instant: SessionInstant(wallNow: observedAt.date, liveProjection: nil),
        generatedSessionID: UUID(),
        generatedThoughtID: thoughtID,
        generatedProjectionToken: UUID()
      )
    )
    guard case let .transition(reduction) = outcome else {
      Issue.record("expected paused thought transition")
      return
    }

    #expect(reduction.snapshot.revision == 4)
    #expect(reduction.snapshot.eventSequence == 5)
    #expect(reduction.snapshot.state == snapshot.state)
    #expect(reduction.snapshot.lastWallObservationAt == observedAt)
    #expect(
      reduction.snapshot.parkedThoughts
        == [
          ParkedThought(id: thoughtID, text: "Capture this", createdAt: observedAt),
          ParkedThought(id: laterThoughtID, text: "Later", createdAt: laterAt),
        ])
    #expect(SessionSnapshotValidator.validateCandidate(reduction.snapshot).isEmpty)
    #expect(reduction.events.map(\.payload) == [.thoughtParked(id: thoughtID)])
    #expect(reduction.events[0].occurredAt == observedAt)
    #expect(reduction.effects == [.invalidateDisplayProjection(projectionToken: nil)])
  }

  @Test(
    "paused check-in resolutions restore paused focus without auto-resume",
    arguments: [
      CheckInResponse.continueFocus,
      .skip,
      .dismiss,
    ]
  )
  func pausedCheckInResolutionsRestorePausedFocus(response: CheckInResponse) throws {
    let sessionID = UUID()
    let openedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 300))
    let resolvedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 450))
    let suspended = SuspendedFocusState(
      phase: TimingPolicy.classic.phases[0],
      timing: .timed(remaining: try PhaseSeconds(1_490)),
      resumeDisposition: .paused,
      scheduledCheckInRemaining: try CheckInRemainingSeconds(890)
    )
    let snapshot = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 4,
      eventSequence: 5,
      nextBoundaryOccurrence: 2,
      state: .checkingIn(
        CheckInState(
          suspended: suspended,
          trigger: .manual,
          continuation: .resumeSuspended,
          phaseBoundaryScheduledCheckInRemaining: nil
        )),
      plan: try SessionPlan(
        task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic),
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100)),
      accumulatedFocusSeconds: 10,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: openedAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )

    let outcome = SessionReducer.reduce(
      snapshot: snapshot,
      command: SessionCommand(expectedRevision: 4, intent: .respondToCheckIn(response)),
      context: ReductionContext(
        instant: SessionInstant(wallNow: resolvedAt.date, liveProjection: nil),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: UUID()
      )
    )
    guard case let .transition(reduction) = outcome else {
      Issue.record("expected paused check-in resolution")
      return
    }

    #expect(reduction.snapshot.revision == 5)
    #expect(reduction.snapshot.eventSequence == 6)
    #expect(reduction.snapshot.nextBoundaryOccurrence == 2)
    #expect(reduction.snapshot.accumulatedFocusSeconds == 10)
    #expect(reduction.snapshot.lastWallObservationAt == resolvedAt)
    #expect(
      reduction.snapshot.state
        == .paused(
          PausedState(
            phase: suspended.phase,
            timing: suspended.timing,
            pausedAt: resolvedAt,
            scheduledCheckInRemaining: suspended.scheduledCheckInRemaining
          )))
    #expect(SessionSnapshotValidator.validateCandidate(reduction.snapshot).isEmpty)
    #expect(reduction.events.map(\.payload) == [.checkInResolved])
    #expect(reduction.events[0].occurredAt == resolvedAt)
    #expect(reduction.effects == [.invalidateDisplayProjection(projectionToken: nil)])
  }

  @Test(
    "live check-in resolutions reanchor focus and captured cadence",
    arguments: [
      CheckInResponse.continueFocus,
      .skip,
      .dismiss,
    ]
  )
  func liveCheckInResolutionsReanchorFocusAndCapturedCadence(response: CheckInResponse) throws {
    let sessionID = UUID()
    let projectionToken = UUID()
    let openedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 300))
    let resolvedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 450))
    let suspended = SuspendedFocusState(
      phase: TimingPolicy.classic.phases[0],
      timing: .timed(remaining: try PhaseSeconds(1_490)),
      resumeDisposition: .focusing,
      scheduledCheckInRemaining: try CheckInRemainingSeconds(890)
    )
    let snapshot = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 4,
      eventSequence: 5,
      nextBoundaryOccurrence: 2,
      state: .checkingIn(
        CheckInState(
          suspended: suspended,
          trigger: .manual,
          continuation: .resumeSuspended,
          phaseBoundaryScheduledCheckInRemaining: nil
        )),
      plan: try SessionPlan(
        task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic),
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100)),
      accumulatedFocusSeconds: 10,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: openedAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )

    let outcome = SessionReducer.reduce(
      snapshot: snapshot,
      command: SessionCommand(expectedRevision: 4, intent: .respondToCheckIn(response)),
      context: ReductionContext(
        instant: SessionInstant(wallNow: resolvedAt.date, liveProjection: nil),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: projectionToken
      )
    )
    guard case let .transition(reduction) = outcome else {
      Issue.record("expected live check-in resolution")
      return
    }
    let phaseDeadline = SessionTimestamp(
      unchecked: Date(timeIntervalSinceReferenceDate: 1_940))
    let scheduledDeadline = SessionTimestamp(
      unchecked: Date(timeIntervalSinceReferenceDate: 1_340))
    let phaseToken = BoundaryToken(
      sessionID: sessionID,
      kind: .phase,
      phaseID: .focus,
      sourceRevision: 5,
      occurrence: 2
    )
    let scheduledToken = BoundaryToken(
      sessionID: sessionID,
      kind: .scheduledCheckIn,
      phaseID: nil,
      sourceRevision: 5,
      occurrence: 3
    )

    #expect(reduction.snapshot.revision == 5)
    #expect(reduction.snapshot.eventSequence == 7)
    #expect(reduction.snapshot.nextBoundaryOccurrence == 4)
    #expect(reduction.snapshot.accumulatedFocusSeconds == 10)
    #expect(reduction.snapshot.lastWallObservationAt == resolvedAt)
    #expect(
      reduction.snapshot.state
        == .focusing(
          FocusState(
            phase: suspended.phase,
            timingAtAnchor: suspended.timing,
            wallAnchor: resolvedAt,
            phaseEndsAt: phaseDeadline,
            elapsedBeforeAnchorSeconds: 0,
            projectionToken: projectionToken,
            phaseBoundaryToken: phaseToken
          )))
    #expect(
      reduction.snapshot.nextScheduledCheckIn
        == ScheduledCheckInBoundary(
          token: scheduledToken,
          dueAt: scheduledDeadline,
          trustedRemaining: try CheckInRemainingSeconds(890)
        ))
    #expect(SessionSnapshotValidator.validateCandidate(reduction.snapshot).isEmpty)
    #expect(
      reduction.events.map(\.payload)
        == [
          .checkInResolved,
          .phaseResumed(phase: suspended.phase, endsAt: phaseDeadline),
        ])
    #expect(reduction.events.map(\.occurredAt) == [resolvedAt, resolvedAt])
    #expect(
      reduction.effects
        == [
          .scheduleNotification(
            SessionNotificationRequest(
              boundaryToken: scheduledToken, fireAt: scheduledDeadline)),
          .announceAccessibility(.focusStarted),
          .invalidateDisplayProjection(projectionToken: projectionToken),
        ])
  }

  @Test("scheduled check-in resolution resets cadence to the full configured interval")
  func scheduledCheckInResolutionResetsCadence() throws {
    let sessionID = UUID()
    let projectionToken = UUID()
    let resolvedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 450))
    let consumedToken = BoundaryToken(
      sessionID: sessionID,
      kind: .scheduledCheckIn,
      phaseID: nil,
      sourceRevision: 3,
      occurrence: 2
    )
    let suspended = SuspendedFocusState(
      phase: TimingPolicy.classic.phases[0],
      timing: .timed(remaining: try PhaseSeconds(1_490)),
      resumeDisposition: .focusing,
      scheduledCheckInRemaining: nil
    )
    let snapshot = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 4,
      eventSequence: 5,
      nextBoundaryOccurrence: 3,
      state: .checkingIn(
        CheckInState(
          suspended: suspended,
          trigger: .scheduled(consumedToken),
          continuation: .resumeSuspended,
          phaseBoundaryScheduledCheckInRemaining: nil
        )),
      plan: try SessionPlan(
        task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic),
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100)),
      accumulatedFocusSeconds: 10,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: SessionTimestamp(
        unchecked: Date(timeIntervalSinceReferenceDate: 300)),
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: consumedToken
    )

    let outcome = SessionReducer.reduce(
      snapshot: snapshot,
      command: SessionCommand(expectedRevision: 4, intent: .respondToCheckIn(.continueFocus)),
      context: ReductionContext(
        instant: SessionInstant(wallNow: resolvedAt.date, liveProjection: nil),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: projectionToken
      )
    )
    guard case let .transition(reduction) = outcome else {
      Issue.record("expected scheduled check-in resolution")
      return
    }
    let scheduled = try #require(reduction.snapshot.nextScheduledCheckIn)
    let fullCadence = try CheckInRemainingSeconds(900)

    #expect(scheduled.trustedRemaining == fullCadence)
    #expect(
      scheduled.dueAt
        == SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 1_350)))
    #expect(scheduled.token.occurrence == 4)
    #expect(scheduled.token.sourceRevision == 5)
    #expect(reduction.snapshot.nextBoundaryOccurrence == 5)
    #expect(reduction.snapshot.lastConsumedBoundaryToken == consumedToken)
    #expect(SessionSnapshotValidator.validateCandidate(reduction.snapshot).isEmpty)
  }

  @Test("make smaller presents re-entry with the exact suspended focus target")
  func makeSmallerPresentsReentryForSuspendedFocus() throws {
    let sessionID = UUID()
    let consumedToken = BoundaryToken(
      sessionID: sessionID,
      kind: .scheduledCheckIn,
      phaseID: nil,
      sourceRevision: 3,
      occurrence: 2
    )
    let suspended = SuspendedFocusState(
      phase: TimingPolicy.classic.phases[0],
      timing: .timed(remaining: try PhaseSeconds(1_490)),
      resumeDisposition: .focusing,
      scheduledCheckInRemaining: nil
    )
    let openedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 300))
    let resolvedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 450))
    let plan = try SessionPlan(
      task: "Task", firstAction: "Open the outline", capacity: nil, timingPolicy: .classic)
    let snapshot = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 4,
      eventSequence: 5,
      nextBoundaryOccurrence: 3,
      state: .checkingIn(
        CheckInState(
          suspended: suspended,
          trigger: .scheduled(consumedToken),
          continuation: .resumeSuspended,
          phaseBoundaryScheduledCheckInRemaining: nil
        )),
      plan: plan,
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100)),
      accumulatedFocusSeconds: 10,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: openedAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: consumedToken
    )

    let outcome = SessionReducer.reduce(
      snapshot: snapshot,
      command: SessionCommand(expectedRevision: 4, intent: .respondToCheckIn(.makeSmaller)),
      context: ReductionContext(
        instant: SessionInstant(wallNow: resolvedAt.date, liveProjection: nil),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: UUID()
      )
    )
    guard case let .transition(reduction) = outcome else {
      Issue.record("expected make-smaller re-entry transition")
      return
    }
    let resumeTarget = SuspendedFocusState(
      phase: suspended.phase,
      timing: suspended.timing,
      resumeDisposition: .focusing,
      scheduledCheckInRemaining: try CheckInRemainingSeconds(900)
    )

    #expect(reduction.snapshot.revision == 5)
    #expect(reduction.snapshot.eventSequence == 7)
    #expect(reduction.snapshot.nextBoundaryOccurrence == 3)
    #expect(reduction.snapshot.accumulatedFocusSeconds == 10)
    #expect(
      reduction.snapshot.state
        == .reentering(
          ReentryState(
            resumeTarget: resumeTarget,
            proposedAction: "Open the outline",
            enteredAt: resolvedAt
          )))
    #expect(reduction.snapshot.lastConsumedBoundaryToken == consumedToken)
    #expect(SessionSnapshotValidator.validateCandidate(reduction.snapshot).isEmpty)
    #expect(
      reduction.events.map(\.payload)
        == [.checkInResolved, .reentryPresented])
    #expect(reduction.events.map(\.occurredAt) == [resolvedAt, resolvedAt])
    #expect(
      reduction.effects
        == [
          .announceAccessibility(.reentryPresented),
          .invalidateDisplayProjection(projectionToken: nil),
        ])
  }

  @Test("make smaller after a phase boundary uses the full next phase")
  func makeSmallerAfterPhaseBoundaryUsesFullNextPhase() throws {
    let sessionID = UUID()
    let token = BoundaryToken(
      sessionID: sessionID,
      kind: .phase,
      phaseID: .entry,
      sourceRevision: 3,
      occurrence: 1
    )
    let nextPhase = TimingPolicy.gentleStart.phases[1]
    let cadence = try CheckInRemainingSeconds(400)
    let resolvedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 450))
    let snapshot = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 4,
      eventSequence: 6,
      nextBoundaryOccurrence: 2,
      state: .checkingIn(
        CheckInState(
          suspended: nil,
          trigger: .phaseBoundary(token),
          continuation: .startPhase(nextPhase),
          phaseBoundaryScheduledCheckInRemaining: cadence
        )),
      plan: try SessionPlan(
        task: "Task", firstAction: "Open the outline", capacity: nil,
        timingPolicy: .gentleStart),
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100)),
      accumulatedFocusSeconds: 300,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: SessionTimestamp(
        unchecked: Date(timeIntervalSinceReferenceDate: 400)),
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: token
    )

    let outcome = SessionReducer.reduce(
      snapshot: snapshot,
      command: SessionCommand(expectedRevision: 4, intent: .respondToCheckIn(.makeSmaller)),
      context: ReductionContext(
        instant: SessionInstant(wallNow: resolvedAt.date, liveProjection: nil),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: UUID()
      )
    )
    guard case let .transition(reduction) = outcome else {
      Issue.record("expected phase-boundary make-smaller transition")
      return
    }
    let expectedTarget = SuspendedFocusState(
      phase: nextPhase,
      timing: .timed(remaining: try PhaseSeconds(1_200)),
      resumeDisposition: .paused,
      scheduledCheckInRemaining: cadence
    )

    guard case let .reentering(reentry) = reduction.snapshot.state else {
      Issue.record("expected re-entry state")
      return
    }
    #expect(reentry.resumeTarget == expectedTarget)
    #expect(reentry.proposedAction == "Open the outline")
    #expect(reentry.enteredAt == resolvedAt)
    #expect(reduction.snapshot.eventSequence == 8)
    #expect(reduction.snapshot.lastConsumedBoundaryToken == token)
    #expect(SessionSnapshotValidator.validateCandidate(reduction.snapshot).isEmpty)
    #expect(reduction.events.map(\.payload) == [.checkInResolved, .reentryPresented])
  }

  @Test("detour reporting stays in check-in and only parks a meaningful note")
  func detourReportingStaysInCheckInAndParksMeaningfulNote() throws {
    let sessionID = UUID()
    let thoughtID = UUID()
    let observedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 450))
    let checkIn = CheckInState(
      suspended: SuspendedFocusState(
        phase: TimingPolicy.classic.phases[0],
        timing: .timed(remaining: try PhaseSeconds(1_490)),
        resumeDisposition: .focusing,
        scheduledCheckInRemaining: try CheckInRemainingSeconds(890)
      ),
      trigger: .manual,
      continuation: .resumeSuspended,
      phaseBoundaryScheduledCheckInRemaining: nil
    )
    let snapshot = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 4,
      eventSequence: 5,
      nextBoundaryOccurrence: 2,
      state: .checkingIn(checkIn),
      plan: try SessionPlan(
        task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic),
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100)),
      accumulatedFocusSeconds: 10,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: SessionTimestamp(
        unchecked: Date(timeIntervalSinceReferenceDate: 300)),
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )
    let context = ReductionContext(
      instant: SessionInstant(wallNow: observedAt.date, liveProjection: nil),
      generatedSessionID: UUID(),
      generatedThoughtID: thoughtID,
      generatedProjectionToken: UUID()
    )

    let oversized = String(repeating: "x", count: 2_001)
    #expect(
      SessionReducer.reduce(
        snapshot: snapshot,
        command: SessionCommand(
          expectedRevision: 4,
          intent: .respondToCheckIn(.detour(note: oversized))
        ),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: .nan), liveProjection: nil),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: UUID()
        )
      )
        == .rejected(snapshot: snapshot, reason: .invalidText(.detourNote))
    )

    for note in [String?.none, " \n "] {
      let outcome = SessionReducer.reduce(
        snapshot: snapshot,
        command: SessionCommand(
          expectedRevision: 4, intent: .respondToCheckIn(.detour(note: note))),
        context: context
      )
      guard case let .transition(reduction) = outcome else {
        Issue.record("expected note-free detour transition")
        continue
      }
      #expect(reduction.snapshot.state == .checkingIn(checkIn))
      #expect(reduction.snapshot.parkedThoughts.isEmpty)
      #expect(reduction.snapshot.eventSequence == 6)
      #expect(reduction.events.map(\.payload) == [.detourReported(hasNote: false)])
      #expect(reduction.effects == [.invalidateDisplayProjection(projectionToken: nil)])
    }

    let notedOutcome = SessionReducer.reduce(
      snapshot: snapshot,
      command: SessionCommand(
        expectedRevision: 4,
        intent: .respondToCheckIn(.detour(note: "  Check messages later  \n"))
      ),
      context: context
    )
    guard case let .transition(noted) = notedOutcome else {
      Issue.record("expected noted detour transition")
      return
    }
    #expect(noted.snapshot.state == .checkingIn(checkIn))
    #expect(
      noted.snapshot.parkedThoughts
        == [ParkedThought(id: thoughtID, text: "Check messages later", createdAt: observedAt)])
    #expect(noted.snapshot.eventSequence == 7)
    #expect(
      noted.events.map(\.payload)
        == [.detourReported(hasNote: true), .thoughtParked(id: thoughtID)])
    #expect(SessionSnapshotValidator.validateCandidate(noted.snapshot).isEmpty)
    #expect(noted.effects == [.invalidateDisplayProjection(projectionToken: nil)])
  }

  @Test("taking a break from check-in preserves the exact resume target")
  func takingBreakFromCheckInPreservesResumeTarget() throws {
    let sessionID = UUID()
    let projectionToken = UUID()
    let consumedToken = BoundaryToken(
      sessionID: sessionID,
      kind: .scheduledCheckIn,
      phaseID: nil,
      sourceRevision: 3,
      occurrence: 2
    )
    let suspended = SuspendedFocusState(
      phase: TimingPolicy.classic.phases[0],
      timing: .timed(remaining: try PhaseSeconds(1_490)),
      resumeDisposition: .focusing,
      scheduledCheckInRemaining: nil
    )
    let observedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 450))
    let choice = BreakChoice(kind: .breathe, duration: .timed(.five))
    let snapshot = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 4,
      eventSequence: 5,
      nextBoundaryOccurrence: 3,
      state: .checkingIn(
        CheckInState(
          suspended: suspended,
          trigger: .scheduled(consumedToken),
          continuation: .resumeSuspended,
          phaseBoundaryScheduledCheckInRemaining: nil
        )),
      plan: try SessionPlan(
        task: "Task", firstAction: "Open the outline", capacity: nil, timingPolicy: .classic),
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100)),
      accumulatedFocusSeconds: 10,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: SessionTimestamp(
        unchecked: Date(timeIntervalSinceReferenceDate: 300)),
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: consumedToken
    )

    let outcome = SessionReducer.reduce(
      snapshot: snapshot,
      command: SessionCommand(
        expectedRevision: 4,
        intent: .respondToCheckIn(.takeBreak(choice))
      ),
      context: ReductionContext(
        instant: SessionInstant(wallNow: observedAt.date, liveProjection: nil),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: projectionToken
      )
    )
    guard case let .transition(reduction) = outcome else {
      Issue.record("expected take-break transition")
      return
    }
    let endsAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 750))
    let breakToken = BoundaryToken(
      sessionID: sessionID,
      kind: .breakEnd,
      phaseID: nil,
      sourceRevision: 5,
      occurrence: 3
    )
    let resumeTarget = SuspendedFocusState(
      phase: suspended.phase,
      timing: suspended.timing,
      resumeDisposition: .focusing,
      scheduledCheckInRemaining: try CheckInRemainingSeconds(900)
    )

    #expect(
      reduction.snapshot.state
        == .breaking(
          BreakState(
            choice: choice,
            timingAtAnchor: .timed(remaining: try PhaseSeconds(300)),
            wallAnchor: observedAt,
            endsAt: endsAt,
            elapsedBeforeAnchorSeconds: 0,
            projectionToken: projectionToken,
            boundaryToken: breakToken,
            resumeTarget: resumeTarget,
            proposedAction: "Open the outline"
          )))
    #expect(reduction.snapshot.eventSequence == 7)
    #expect(reduction.snapshot.nextBoundaryOccurrence == 4)
    #expect(reduction.snapshot.lastConsumedBoundaryToken == consumedToken)
    #expect(SessionSnapshotValidator.validateCandidate(reduction.snapshot).isEmpty)
    #expect(
      reduction.events.map(\.payload)
        == [
          .checkInResolved,
          .breakStarted(kind: .breathe, duration: .timed(.five), endsAt: endsAt),
        ])
    #expect(
      reduction.effects
        == [
          .scheduleNotification(
            SessionNotificationRequest(boundaryToken: breakToken, fireAt: endsAt)),
          .announceAccessibility(.breakStarted),
          .invalidateDisplayProjection(projectionToken: projectionToken),
        ])
  }
}
