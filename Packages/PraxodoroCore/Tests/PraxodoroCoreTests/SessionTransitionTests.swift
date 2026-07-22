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
    #expect(changed.effects == [.invalidateDisplayProjection(projectionToken: nil)])
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

  @Test("prepared configuration setters change one field or no-op identically")
  func preparedConfigurationSettersAreExact() throws {
    let sessionID = UUID()
    let preparedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 10))
    let changedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 20))
    let plan = try SessionPlan(
      task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic)
    let snapshot = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 1,
      eventSequence: 1,
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
    let thirty = try CheckInMinutes(30)
    let cases: [(SessionIntent, SessionConfiguration, SessionConfigurationField)] = [
      (
        .setCheckInSchedule(.interval(thirty)),
        SessionConfiguration(
          checkInSchedule: .interval(thirty),
          breakSuggestionsEnabled: true,
          lowCognitiveLoadEnabled: false,
          reflectionPromptEnabled: true),
        .checkInSchedule
      ),
      (
        .setBreakSuggestionsEnabled(false),
        SessionConfiguration(
          checkInSchedule: .every15Minutes,
          breakSuggestionsEnabled: false,
          lowCognitiveLoadEnabled: false,
          reflectionPromptEnabled: true),
        .breakSuggestionsEnabled
      ),
      (
        .setLowCognitiveLoadEnabled(true),
        SessionConfiguration(
          checkInSchedule: .every15Minutes,
          breakSuggestionsEnabled: true,
          lowCognitiveLoadEnabled: true,
          reflectionPromptEnabled: true),
        .lowCognitiveLoadEnabled
      ),
      (
        .setReflectionPromptEnabled(false),
        SessionConfiguration(
          checkInSchedule: .every15Minutes,
          breakSuggestionsEnabled: true,
          lowCognitiveLoadEnabled: false,
          reflectionPromptEnabled: false),
        .reflectionPromptEnabled
      ),
    ]
    let context = ReductionContext(
      instant: SessionInstant(wallNow: changedAt.date, liveProjection: nil),
      generatedSessionID: UUID(),
      generatedThoughtID: UUID(),
      generatedProjectionToken: UUID()
    )

    for (intent, expectedConfiguration, field) in cases {
      let outcome = SessionReducer.reduce(
        snapshot: snapshot,
        command: SessionCommand(expectedRevision: 1, intent: intent),
        context: context
      )
      guard case let .transition(reduction) = outcome else {
        Issue.record("expected prepared configuration transition for \(field)")
        continue
      }
      #expect(reduction.snapshot.configuration == expectedConfiguration)
      #expect(reduction.snapshot.plan == plan)
      #expect(reduction.snapshot.revision == 2)
      #expect(reduction.snapshot.eventSequence == 2)
      #expect(
        reduction.events.map(\.payload)
          == [
            .configurationChanged(
              fields: SessionConfigurationFieldChanges([field])!)
          ])
      #expect(reduction.effects == [.invalidateDisplayProjection(projectionToken: nil)])
    }

    let identical: [SessionIntent] = [
      .setCheckInSchedule(.every15Minutes),
      .setBreakSuggestionsEnabled(true),
      .setLowCognitiveLoadEnabled(false),
      .setReflectionPromptEnabled(true),
    ]
    let nonFiniteContext = ReductionContext(
      instant: SessionInstant(
        wallNow: Date(timeIntervalSinceReferenceDate: .nan), liveProjection: nil),
      generatedSessionID: UUID(),
      generatedThoughtID: UUID(),
      generatedProjectionToken: UUID()
    )
    for intent in identical {
      #expect(
        SessionReducer.reduce(
          snapshot: snapshot,
          command: SessionCommand(expectedRevision: 1, intent: intent),
          context: nonFiniteContext
        )
          == .noChange(snapshot: snapshot, reason: .alreadyInRequestedState)
      )
    }
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

    let restoredProjection = UUID()
    let restored = SessionReducer.reduce(
      snapshot: reduction.snapshot,
      command: SessionCommand(expectedRevision: 4, intent: .reconcileTime(.relaunch)),
      context: ReductionContext(
        instant: SessionInstant(
          wallNow: Date(timeIntervalSinceReferenceDate: 400), liveProjection: nil),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: restoredProjection
      )
    )
    guard case let .transition(restoredReduction) = restored,
      case let .breaking(restoredBreak) = restoredReduction.snapshot.state
    else {
      Issue.record("expected restored live break")
      return
    }
    #expect(
      restoredBreak.wallAnchor
        == SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 400)))
    #expect(restoredBreak.elapsedBeforeAnchorSeconds == 100)
    #expect(restoredBreak.timingAtAnchor == .timed(remaining: try PhaseSeconds(200)))
    #expect(restoredBreak.endsAt == endsAt)
    #expect(restoredBreak.projectionToken == restoredProjection)
    #expect(restoredReduction.snapshot.accumulatedBreakSeconds == 0)
    #expect(restoredReduction.events.map(\.payload.kind) == [.liveProjectionRestored])
    #expect(
      restoredReduction.effects == [
        .invalidateDisplayProjection(projectionToken: restoredProjection)
      ])
    #expect(SessionSnapshotValidator.validateCandidate(restoredReduction.snapshot).isEmpty)

    let due = SessionReducer.reduce(
      snapshot: reduction.snapshot,
      command: SessionCommand(expectedRevision: 4, intent: .reconcileTime(.relaunch)),
      context: ReductionContext(
        instant: SessionInstant(wallNow: endsAt.date, liveProjection: nil),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: UUID()
      )
    )
    guard case let .transition(dueReduction) = due else {
      Issue.record("expected due break relaunch transition")
      return
    }
    #expect(dueReduction.snapshot.state.kind == .reentering)
    #expect(dueReduction.snapshot.accumulatedBreakSeconds == 300)
    #expect(dueReduction.snapshot.lastConsumedBoundaryToken == boundaryToken)
    #expect(dueReduction.events.map(\.payload.kind) == [.breakEnded, .reentryPresented])
    #expect(dueReduction.effects.contains(.playSound(.breakComplete)))
    #expect(SessionSnapshotValidator.validateCandidate(dueReduction.snapshot).isEmpty)
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

  @Test(
    "phase-boundary skip and dismiss pause the full continuation phase",
    arguments: [CheckInResponse.skip, .dismiss]
  )
  func phaseBoundarySkipAndDismissPauseFullContinuation(response: CheckInResponse) throws {
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
    let observedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 450))
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
        task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .gentleStart),
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
      command: SessionCommand(expectedRevision: 4, intent: .respondToCheckIn(response)),
      context: ReductionContext(
        instant: SessionInstant(wallNow: observedAt.date, liveProjection: nil),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: UUID()
      )
    )
    guard case let .transition(reduction) = outcome else {
      Issue.record("expected phase-boundary paused resolution")
      return
    }
    let fullTiming = PausedTiming.timed(remaining: try PhaseSeconds(1_200))

    #expect(
      reduction.snapshot.state
        == .paused(
          PausedState(
            phase: nextPhase,
            timing: fullTiming,
            pausedAt: observedAt,
            scheduledCheckInRemaining: cadence
          )))
    #expect(reduction.snapshot.revision == 5)
    #expect(reduction.snapshot.eventSequence == 8)
    #expect(reduction.snapshot.nextBoundaryOccurrence == 2)
    #expect(reduction.snapshot.lastConsumedBoundaryToken == token)
    #expect(SessionSnapshotValidator.validateCandidate(reduction.snapshot).isEmpty)
    #expect(
      reduction.events.map(\.payload)
        == [.checkInResolved, .phasePaused(timing: fullTiming)])
    #expect(reduction.events.map(\.occurredAt) == [observedAt, observedAt])
    #expect(reduction.effects == [.invalidateDisplayProjection(projectionToken: nil)])
  }

  @Test("phase-boundary continue starts the exact continuation phase")
  func phaseBoundaryContinueStartsExactContinuation() throws {
    let sessionID = UUID()
    let projectionToken = UUID()
    let token = BoundaryToken(
      sessionID: sessionID,
      kind: .phase,
      phaseID: .entry,
      sourceRevision: 3,
      occurrence: 1
    )
    let nextPhase = TimingPolicy.gentleStart.phases[1]
    let cadence = try CheckInRemainingSeconds(400)
    let observedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 450))
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
        task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .gentleStart),
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
      command: SessionCommand(
        expectedRevision: 4, intent: .respondToCheckIn(.continueFocus)),
      context: ReductionContext(
        instant: SessionInstant(wallNow: observedAt.date, liveProjection: nil),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: projectionToken
      )
    )
    guard case let .transition(reduction) = outcome else {
      Issue.record("expected phase-boundary continue transition")
      return
    }
    let phaseEndsAt = SessionTimestamp(
      unchecked: Date(timeIntervalSinceReferenceDate: 1_650))
    let scheduledAt = SessionTimestamp(
      unchecked: Date(timeIntervalSinceReferenceDate: 850))
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

    guard case let .focusing(focus) = reduction.snapshot.state else {
      Issue.record("expected focusing continuation")
      return
    }
    #expect(focus.phase == nextPhase)
    #expect(focus.timingAtAnchor == .timed(remaining: try PhaseSeconds(1_200)))
    #expect(focus.phaseEndsAt == phaseEndsAt)
    #expect(focus.phaseBoundaryToken == phaseToken)
    #expect(focus.projectionToken == projectionToken)
    #expect(
      reduction.snapshot.nextScheduledCheckIn
        == ScheduledCheckInBoundary(
          token: scheduledToken,
          dueAt: scheduledAt,
          trustedRemaining: cadence
        ))
    #expect(reduction.snapshot.eventSequence == 8)
    #expect(reduction.snapshot.nextBoundaryOccurrence == 4)
    #expect(SessionSnapshotValidator.validateCandidate(reduction.snapshot).isEmpty)
    #expect(
      reduction.events.map(\.payload)
        == [
          .checkInResolved,
          .phaseStarted(phase: nextPhase, endsAt: phaseEndsAt),
        ])
    #expect(
      reduction.effects
        == [
          .scheduleNotification(
            SessionNotificationRequest(
              boundaryToken: scheduledToken, fireAt: scheduledAt)),
          .announceAccessibility(.focusStarted),
          .invalidateDisplayProjection(projectionToken: projectionToken),
        ])
  }

  @Test("direct thought parking preserves the unresolved check-in")
  func directThoughtParkingPreservesCheckIn() throws {
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

    let outcome = SessionReducer.reduce(
      snapshot: snapshot,
      command: SessionCommand(expectedRevision: 4, intent: .parkThought("  Later idea  ")),
      context: ReductionContext(
        instant: SessionInstant(wallNow: observedAt.date, liveProjection: nil),
        generatedSessionID: UUID(),
        generatedThoughtID: thoughtID,
        generatedProjectionToken: UUID()
      )
    )
    guard case let .transition(reduction) = outcome else {
      Issue.record("expected checking-in thought transition")
      return
    }

    #expect(reduction.snapshot.state == .checkingIn(checkIn))
    #expect(
      reduction.snapshot.parkedThoughts
        == [ParkedThought(id: thoughtID, text: "Later idea", createdAt: observedAt)])
    #expect(reduction.snapshot.revision == 5)
    #expect(reduction.snapshot.eventSequence == 6)
    #expect(SessionSnapshotValidator.validateCandidate(reduction.snapshot).isEmpty)
    #expect(reduction.events.map(\.payload) == [.thoughtParked(id: thoughtID)])
    #expect(reduction.effects == [.invalidateDisplayProjection(projectionToken: nil)])
  }

  @Test("phase-boundary take-break preserves an open-ended continuation target")
  func phaseBoundaryTakeBreakPreservesOpenEndedContinuation() throws {
    let sessionID = UUID()
    let projectionToken = UUID()
    let token = BoundaryToken(
      sessionID: sessionID,
      kind: .phase,
      phaseID: .recoveryRamp,
      sourceRevision: 3,
      occurrence: 1
    )
    let nextPhase = TimingPolicy.recoveryFirst.phases[1]
    let cadence = try CheckInRemainingSeconds(400)
    let observedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 750))
    let choice = BreakChoice(kind: .quiet, duration: .openEnded)
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
        task: "Task", firstAction: "Action", capacity: nil,
        timingPolicy: .recoveryFirst),
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100)),
      accumulatedFocusSeconds: 600,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: SessionTimestamp(
        unchecked: Date(timeIntervalSinceReferenceDate: 700)),
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: token
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
      Issue.record("expected phase-boundary open break transition")
      return
    }
    let resumeTarget = SuspendedFocusState(
      phase: nextPhase,
      timing: .openEnded,
      resumeDisposition: .paused,
      scheduledCheckInRemaining: cadence
    )

    #expect(
      reduction.snapshot.state
        == .breaking(
          BreakState(
            choice: choice,
            timingAtAnchor: .openEnded,
            wallAnchor: observedAt,
            endsAt: nil,
            elapsedBeforeAnchorSeconds: 0,
            projectionToken: projectionToken,
            boundaryToken: nil,
            resumeTarget: resumeTarget,
            proposedAction: "Action"
          )))
    #expect(reduction.snapshot.eventSequence == 8)
    #expect(reduction.snapshot.nextBoundaryOccurrence == 2)
    #expect(reduction.snapshot.lastConsumedBoundaryToken == token)
    #expect(SessionSnapshotValidator.validateCandidate(reduction.snapshot).isEmpty)
    #expect(
      reduction.events.map(\.payload)
        == [
          .checkInResolved,
          .breakStarted(kind: .quiet, duration: .openEnded, endsAt: nil),
        ])
    #expect(
      reduction.effects
        == [
          .announceAccessibility(.breakStarted),
          .invalidateDisplayProjection(projectionToken: projectionToken),
        ])
  }

  @Test("check-in response failures preserve wall and counter precedence")
  func checkInResponseFailurePrecedence() throws {
    let sessionID = UUID()
    let observedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 450))
    func snapshot(revision: UInt64, eventSequence: UInt64) throws -> SessionSnapshot {
      SessionSnapshot(
        schemaVersion: 1,
        sessionID: sessionID,
        revision: revision,
        eventSequence: eventSequence,
        nextBoundaryOccurrence: 2,
        state: .checkingIn(
          CheckInState(
            suspended: SuspendedFocusState(
              phase: TimingPolicy.classic.phases[0],
              timing: .timed(remaining: try PhaseSeconds(1_490)),
              resumeDisposition: .paused,
              scheduledCheckInRemaining: try CheckInRemainingSeconds(890)
            ),
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
        lastWallObservationAt: SessionTimestamp(
          unchecked: Date(timeIntervalSinceReferenceDate: 300)),
        nextScheduledCheckIn: nil,
        lastConsumedBoundaryToken: nil
      )
    }
    let exhausted = try snapshot(revision: .max, eventSequence: .max)
    let finiteContext = ReductionContext(
      instant: SessionInstant(wallNow: observedAt.date, liveProjection: nil),
      generatedSessionID: UUID(),
      generatedThoughtID: UUID(),
      generatedProjectionToken: UUID()
    )
    let nonFiniteContext = ReductionContext(
      instant: SessionInstant(
        wallNow: Date(timeIntervalSinceReferenceDate: .nan), liveProjection: nil),
      generatedSessionID: UUID(),
      generatedThoughtID: UUID(),
      generatedProjectionToken: UUID()
    )

    #expect(
      SessionReducer.reduce(
        snapshot: exhausted,
        command: SessionCommand(
          expectedRevision: .max, intent: .respondToCheckIn(.continueFocus)),
        context: nonFiniteContext
      )
        == .failed(snapshot: exhausted, reason: .nonFiniteWallObservation)
    )
    #expect(
      SessionReducer.reduce(
        snapshot: exhausted,
        command: SessionCommand(
          expectedRevision: .max, intent: .respondToCheckIn(.continueFocus)),
        context: finiteContext
      )
        == .failed(snapshot: exhausted, reason: .revisionExhausted)
    )
    let eventExhausted = try snapshot(revision: 4, eventSequence: .max)
    #expect(
      SessionReducer.reduce(
        snapshot: eventExhausted,
        command: SessionCommand(
          expectedRevision: 4, intent: .respondToCheckIn(.continueFocus)),
        context: finiteContext
      )
        == .failed(
          snapshot: eventExhausted,
          reason: .eventSequenceExhausted(
            requiredAdditionalEvents: 1,
            remainingCapacity: 0
          ))
    )
  }

  @Test("paused configuration changes replace cadence only for schedule updates")
  func pausedConfigurationChangesAreExact() throws {
    let sessionID = UUID()
    let pausedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 300))
    let changedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 450))
    let originalCadence = try CheckInRemainingSeconds(890)
    let paused = PausedState(
      phase: TimingPolicy.classic.phases[0],
      timing: .timed(remaining: try PhaseSeconds(1_490)),
      pausedAt: pausedAt,
      scheduledCheckInRemaining: originalCadence
    )
    let snapshot = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 4,
      eventSequence: 5,
      nextBoundaryOccurrence: 2,
      state: .paused(paused),
      plan: try SessionPlan(
        task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic),
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100)),
      accumulatedFocusSeconds: 10,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: pausedAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )
    let thirty = try CheckInMinutes(30)
    let fullThirty = try CheckInRemainingSeconds(1_800)
    let cases: [(SessionIntent, SessionConfigurationField, CheckInRemainingSeconds?)] = [
      (.setCheckInSchedule(.manualOnly), .checkInSchedule, nil),
      (.setCheckInSchedule(.interval(thirty)), .checkInSchedule, fullThirty),
      (.setBreakSuggestionsEnabled(false), .breakSuggestionsEnabled, originalCadence),
      (.setLowCognitiveLoadEnabled(true), .lowCognitiveLoadEnabled, originalCadence),
      (.setReflectionPromptEnabled(false), .reflectionPromptEnabled, originalCadence),
    ]
    let context = ReductionContext(
      instant: SessionInstant(wallNow: changedAt.date, liveProjection: nil),
      generatedSessionID: UUID(),
      generatedThoughtID: UUID(),
      generatedProjectionToken: UUID()
    )

    for (intent, field, expectedCadence) in cases {
      let outcome = SessionReducer.reduce(
        snapshot: snapshot,
        command: SessionCommand(expectedRevision: 4, intent: intent),
        context: context
      )
      guard case let .transition(reduction) = outcome,
        case let .paused(candidate) = reduction.snapshot.state
      else {
        Issue.record("expected paused configuration transition for \(field)")
        continue
      }
      #expect(candidate.phase == paused.phase)
      #expect(candidate.timing == paused.timing)
      #expect(candidate.pausedAt == pausedAt)
      #expect(candidate.scheduledCheckInRemaining == expectedCadence)
      #expect(reduction.snapshot.lastWallObservationAt == changedAt)
      #expect(reduction.snapshot.eventSequence == 6)
      #expect(
        reduction.events.map(\.payload)
          == [
            .configurationChanged(
              fields: SessionConfigurationFieldChanges([field])!)
          ])
      #expect(reduction.effects == [.invalidateDisplayProjection(projectionToken: nil)])
      #expect(SessionSnapshotValidator.validateCandidate(reduction.snapshot).isEmpty)
    }

    #expect(
      SessionReducer.reduce(
        snapshot: snapshot,
        command: SessionCommand(
          expectedRevision: 4,
          intent: .setBreakSuggestionsEnabled(true)
        ),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: .nan), liveProjection: nil),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: UUID()
        )
      )
        == .noChange(snapshot: snapshot, reason: .alreadyInRequestedState)
    )
  }

  @Test("check-in configuration changes update only the relevant suspended cadence")
  func checkingInConfigurationChangesAreExact() throws {
    let sessionID = UUID()
    let observedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 450))
    let originalCadence = try CheckInRemainingSeconds(890)
    let suspended = SuspendedFocusState(
      phase: TimingPolicy.classic.phases[0],
      timing: .timed(remaining: try PhaseSeconds(1_490)),
      resumeDisposition: .focusing,
      scheduledCheckInRemaining: originalCadence
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
      lastWallObservationAt: SessionTimestamp(
        unchecked: Date(timeIntervalSinceReferenceDate: 300)),
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )
    let thirty = try CheckInMinutes(30)
    let cases: [(SessionIntent, CheckInRemainingSeconds?)] = [
      (.setCheckInSchedule(.manualOnly), nil),
      (.setCheckInSchedule(.interval(thirty)), try CheckInRemainingSeconds(1_800)),
      (.setLowCognitiveLoadEnabled(true), originalCadence),
    ]
    let context = ReductionContext(
      instant: SessionInstant(wallNow: observedAt.date, liveProjection: nil),
      generatedSessionID: UUID(),
      generatedThoughtID: UUID(),
      generatedProjectionToken: UUID()
    )

    for (intent, expectedCadence) in cases {
      guard
        case let .transition(reduction) = SessionReducer.reduce(
          snapshot: snapshot,
          command: SessionCommand(expectedRevision: 4, intent: intent),
          context: context
        ), case let .checkingIn(candidate) = reduction.snapshot.state
      else {
        Issue.record("expected checking-in configuration transition")
        continue
      }
      #expect(candidate.suspended?.scheduledCheckInRemaining == expectedCadence)
      #expect(candidate.suspended?.phase == suspended.phase)
      #expect(candidate.suspended?.timing == suspended.timing)
      #expect(candidate.suspended?.resumeDisposition == suspended.resumeDisposition)
      #expect(candidate.trigger == .manual)
      #expect(candidate.continuation == .resumeSuspended)
      #expect(reduction.snapshot.revision == 5)
      #expect(reduction.snapshot.eventSequence == 6)
      #expect(reduction.events.count == 1)
      #expect(reduction.effects == [.invalidateDisplayProjection(projectionToken: nil)])
      #expect(SessionSnapshotValidator.validateCandidate(reduction.snapshot).isEmpty)
    }

    #expect(
      SessionReducer.reduce(
        snapshot: snapshot,
        command: SessionCommand(
          expectedRevision: 4,
          intent: .setBreakSuggestionsEnabled(true)
        ),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: .nan), liveProjection: nil),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: UUID()
        )
      ) == .noChange(snapshot: snapshot, reason: .alreadyInRequestedState)
    )
  }

  @Test("phase-boundary schedule changes discard the captured old cadence")
  func phaseBoundaryConfigurationChangesAreExact() throws {
    let sessionID = UUID()
    let token = BoundaryToken(
      sessionID: sessionID,
      kind: .phase,
      phaseID: .entry,
      sourceRevision: 3,
      occurrence: 1
    )
    let cadence = try CheckInRemainingSeconds(400)
    let checkIn = CheckInState(
      suspended: nil,
      trigger: .phaseBoundary(token),
      continuation: .startPhase(TimingPolicy.gentleStart.phases[1]),
      phaseBoundaryScheduledCheckInRemaining: cadence
    )
    let snapshot = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 4,
      eventSequence: 6,
      nextBoundaryOccurrence: 2,
      state: .checkingIn(checkIn),
      plan: try SessionPlan(
        task: "Task", firstAction: "Action", capacity: nil,
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
    let context = ReductionContext(
      instant: SessionInstant(
        wallNow: Date(timeIntervalSinceReferenceDate: 450), liveProjection: nil),
      generatedSessionID: UUID(),
      generatedThoughtID: UUID(),
      generatedProjectionToken: UUID()
    )

    for (intent, expectedCadence) in [
      (SessionIntent.setCheckInSchedule(.manualOnly), nil),
      (SessionIntent.setReflectionPromptEnabled(false), cadence),
    ] {
      guard
        case let .transition(reduction) = SessionReducer.reduce(
          snapshot: snapshot,
          command: SessionCommand(expectedRevision: 4, intent: intent),
          context: context
        ), case let .checkingIn(candidate) = reduction.snapshot.state
      else {
        Issue.record("expected phase-boundary configuration transition")
        continue
      }
      #expect(candidate.phaseBoundaryScheduledCheckInRemaining == expectedCadence)
      #expect(candidate.trigger == checkIn.trigger)
      #expect(candidate.continuation == checkIn.continuation)
      #expect(SessionSnapshotValidator.validateCandidate(reduction.snapshot).isEmpty)
    }
  }

  @Test("re-entry configuration changes preserve coaching context and replace cadence")
  func reentryConfigurationChangesAreExact() throws {
    let sessionID = UUID()
    let enteredAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 400))
    let observedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 450))
    let originalCadence = try CheckInRemainingSeconds(890)
    let target = SuspendedFocusState(
      phase: TimingPolicy.classic.phases[0],
      timing: .timed(remaining: try PhaseSeconds(1_490)),
      resumeDisposition: .focusing,
      scheduledCheckInRemaining: originalCadence
    )
    let reentry = ReentryState(
      resumeTarget: target,
      proposedAction: "Open the outline",
      enteredAt: enteredAt
    )
    let snapshot = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 4,
      eventSequence: 6,
      nextBoundaryOccurrence: 2,
      state: .reentering(reentry),
      plan: try SessionPlan(
        task: "Task", firstAction: "Open the outline", capacity: nil,
        timingPolicy: .classic),
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100)),
      accumulatedFocusSeconds: 10,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: enteredAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )
    let context = ReductionContext(
      instant: SessionInstant(wallNow: observedAt.date, liveProjection: nil),
      generatedSessionID: UUID(),
      generatedThoughtID: UUID(),
      generatedProjectionToken: UUID()
    )

    for (intent, expectedCadence) in [
      (SessionIntent.setCheckInSchedule(.manualOnly), nil),
      (SessionIntent.setBreakSuggestionsEnabled(false), originalCadence),
    ] {
      guard
        case let .transition(reduction) = SessionReducer.reduce(
          snapshot: snapshot,
          command: SessionCommand(expectedRevision: 4, intent: intent),
          context: context
        ), case let .reentering(candidate) = reduction.snapshot.state
      else {
        Issue.record("expected re-entry configuration transition")
        continue
      }
      #expect(candidate.resumeTarget.phase == target.phase)
      #expect(candidate.resumeTarget.timing == target.timing)
      #expect(candidate.resumeTarget.resumeDisposition == target.resumeDisposition)
      #expect(candidate.resumeTarget.scheduledCheckInRemaining == expectedCadence)
      #expect(candidate.proposedAction == reentry.proposedAction)
      #expect(candidate.enteredAt == enteredAt)
      #expect(reduction.snapshot.revision == 5)
      #expect(reduction.snapshot.eventSequence == 7)
      #expect(reduction.snapshot.lastWallObservationAt == observedAt)
      #expect(reduction.events.count == 1)
      #expect(reduction.effects == [.invalidateDisplayProjection(projectionToken: nil)])
      #expect(SessionSnapshotValidator.validateCandidate(reduction.snapshot).isEmpty)
    }

    #expect(
      SessionReducer.reduce(
        snapshot: snapshot,
        command: SessionCommand(
          expectedRevision: 4,
          intent: .setReflectionPromptEnabled(true)
        ),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: .nan), liveProjection: nil),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: UUID()
        )
      ) == .noChange(snapshot: snapshot, reason: .alreadyInRequestedState)
    )
  }

  @Test("review configuration changes preserve the entire summary draft")
  func reviewConfigurationChangesAreExact() throws {
    let sessionID = UUID()
    let endedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 400))
    let observedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 450))
    let review = ReviewState(
      draft: SessionSummaryDraft(
        endedAt: endedAt,
        focusedSeconds: 1_200,
        breakSeconds: 300,
        parkedThoughtCount: 1,
        optionalReflection: nil
      ),
      stopReason: .completed,
      replacementDraft: nil
    )
    let snapshot = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 4,
      eventSequence: 6,
      nextBoundaryOccurrence: 2,
      state: .reviewing(review),
      plan: try SessionPlan(
        task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic),
      configuration: .defaults,
      parkedThoughts: [
        ParkedThought(id: UUID(), text: "Later", createdAt: endedAt)
      ],
      startedAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100)),
      accumulatedFocusSeconds: 1_200,
      accumulatedBreakSeconds: 300,
      lastWallObservationAt: endedAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )
    let context = ReductionContext(
      instant: SessionInstant(wallNow: observedAt.date, liveProjection: nil),
      generatedSessionID: UUID(),
      generatedThoughtID: UUID(),
      generatedProjectionToken: UUID()
    )

    guard
      case let .transition(reduction) = SessionReducer.reduce(
        snapshot: snapshot,
        command: SessionCommand(
          expectedRevision: 4,
          intent: .setReflectionPromptEnabled(false)
        ),
        context: context
      )
    else {
      Issue.record("expected review configuration transition")
      return
    }
    #expect(reduction.snapshot.state == .reviewing(review))
    #expect(reduction.snapshot.parkedThoughts == snapshot.parkedThoughts)
    #expect(reduction.snapshot.revision == 5)
    #expect(reduction.snapshot.eventSequence == 7)
    #expect(reduction.snapshot.lastWallObservationAt == observedAt)
    #expect(
      reduction.events.map(\.payload)
        == [
          .configurationChanged(
            fields: SessionConfigurationFieldChanges([.reflectionPromptEnabled])!)
        ])
    #expect(reduction.effects == [.invalidateDisplayProjection(projectionToken: nil)])
    #expect(SessionSnapshotValidator.validateCandidate(reduction.snapshot).isEmpty)

    #expect(
      SessionReducer.reduce(
        snapshot: snapshot,
        command: SessionCommand(
          expectedRevision: 4,
          intent: .setCheckInSchedule(.interval(try CheckInMinutes(15)))
        ),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: .nan), liveProjection: nil),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: UUID()
        )
      ) == .noChange(snapshot: snapshot, reason: .alreadyInRequestedState)
    )
  }

  @Test("live focus schedule changes reanchor timing and replace the notification winner")
  func liveFocusScheduleChangesAreExact() throws {
    let sessionID = UUID()
    let projectionToken = UUID()
    let plan = try SessionPlan(
      task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic)
    guard
      case let .transition(prepared) = SessionReducer.reduce(
        snapshot: .canonicalIdle,
        command: SessionCommand(
          expectedRevision: 0,
          intent: .prepare(SessionDraft(plan: plan))
        ),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: 10), liveProjection: nil),
          generatedSessionID: sessionID,
          generatedThoughtID: UUID(),
          generatedProjectionToken: UUID()
        )
      ),
      case let .transition(started) = SessionReducer.reduce(
        snapshot: prepared.snapshot,
        command: SessionCommand(expectedRevision: 1, intent: .start),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: 100), liveProjection: nil),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: projectionToken
        )
      ), case let .focusing(originalFocus) = started.snapshot.state,
      let originalWinner = started.snapshot.nextScheduledCheckIn
    else {
      Issue.record("expected live focus fixture")
      return
    }
    let observedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 200))
    let schedule = CheckInSchedule.interval(try CheckInMinutes(30))
    let fullThirtyMinutes = try CheckInRemainingSeconds(1_800)
    let outcome = SessionReducer.reduce(
      snapshot: started.snapshot,
      command: SessionCommand(
        expectedRevision: 2,
        intent: .setCheckInSchedule(schedule)
      ),
      context: ReductionContext(
        instant: SessionInstant(
          wallNow: observedAt.date,
          liveProjection: LiveProjectionObservation(
            projectionToken: projectionToken,
            rawWallAtProjectionAnchor: Date(timeIntervalSinceReferenceDate: 100),
            monotonicElapsedSinceAnchor: .seconds(100)
          )),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: UUID()
      )
    )
    guard case let .transition(reduction) = outcome,
      case let .focusing(focus) = reduction.snapshot.state,
      let replacement = reduction.snapshot.nextScheduledCheckIn,
      let phaseToken = focus.phaseBoundaryToken,
      let phaseEndsAt = focus.phaseEndsAt
    else {
      Issue.record("expected live configuration transition")
      return
    }

    #expect(reduction.snapshot.configuration.checkInSchedule == schedule)
    #expect(reduction.snapshot.revision == 3)
    #expect(reduction.snapshot.eventSequence == 4)
    #expect(reduction.snapshot.nextBoundaryOccurrence == 3)
    #expect(reduction.snapshot.lastWallObservationAt == observedAt)
    #expect(focus.phase == originalFocus.phase)
    #expect(focus.timingAtAnchor == .timed(remaining: try PhaseSeconds(1_400)))
    #expect(focus.wallAnchor == observedAt)
    #expect(focus.elapsedBeforeAnchorSeconds == 100)
    #expect(focus.projectionToken == projectionToken)
    #expect(replacement.token.sourceRevision == 3)
    #expect(replacement.token.occurrence == 2)
    #expect(replacement.dueAt.date.timeIntervalSinceReferenceDate == 2_000)
    #expect(replacement.trustedRemaining == fullThirtyMinutes)
    #expect(
      reduction.events.map(\.payload)
        == [
          .configurationChanged(
            fields: SessionConfigurationFieldChanges([.checkInSchedule])!)
        ])
    #expect(
      reduction.effects
        == [
          .cancelNotification(SessionNotificationID(boundaryToken: originalWinner.token)),
          .scheduleNotification(
            SessionNotificationRequest(boundaryToken: phaseToken, fireAt: phaseEndsAt)),
          .invalidateDisplayProjection(projectionToken: projectionToken),
        ])
    #expect(SessionSnapshotValidator.validateCandidate(reduction.snapshot).isEmpty)
  }

  @Test("due focus boundary supersedes a configuration request")
  func dueFocusBoundarySupersedesConfiguration() throws {
    let sessionID = UUID()
    let projectionToken = UUID()
    let plan = try SessionPlan(
      task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic)
    guard
      case let .transition(prepared) = SessionReducer.reduce(
        snapshot: .canonicalIdle,
        command: SessionCommand(
          expectedRevision: 0,
          intent: .prepare(SessionDraft(plan: plan))
        ),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: 10), liveProjection: nil),
          generatedSessionID: sessionID,
          generatedThoughtID: UUID(),
          generatedProjectionToken: UUID()
        )
      ),
      case let .transition(started) = SessionReducer.reduce(
        snapshot: prepared.snapshot,
        command: SessionCommand(expectedRevision: 1, intent: .start),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: 100), liveProjection: nil),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: projectionToken
        )
      ), let scheduled = started.snapshot.nextScheduledCheckIn
    else {
      Issue.record("expected scheduled live focus fixture")
      return
    }

    let outcome = SessionReducer.reduce(
      snapshot: started.snapshot,
      command: SessionCommand(
        expectedRevision: 2,
        intent: .setLowCognitiveLoadEnabled(true)
      ),
      context: ReductionContext(
        instant: SessionInstant(
          wallNow: scheduled.dueAt.date,
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
      Issue.record("expected due boundary transition")
      return
    }
    #expect(reduction.snapshot.configuration == .defaults)
    #expect(reduction.snapshot.lastConsumedBoundaryToken == scheduled.token)
    #expect(
      reduction.events.map(\.payload)
        == [
          .checkInOpened(
            trigger: .scheduled(scheduled.token), continuation: .resumeSuspended)
        ])
    #expect(
      !reduction.events.contains {
        if case .configurationChanged = $0.payload { return true }
        return false
      })
    #expect(SessionSnapshotValidator.validateCandidate(reduction.snapshot).isEmpty)
  }

  @Test("invalid live focus observations enter recovery without applying configuration")
  func liveFocusConfigurationEntersRecovery() throws {
    let sessionID = UUID()
    let projectionToken = UUID()
    let plan = try SessionPlan(
      task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic)
    guard
      case let .transition(prepared) = SessionReducer.reduce(
        snapshot: .canonicalIdle,
        command: SessionCommand(
          expectedRevision: 0,
          intent: .prepare(SessionDraft(plan: plan))
        ),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: 10), liveProjection: nil),
          generatedSessionID: sessionID,
          generatedThoughtID: UUID(),
          generatedProjectionToken: UUID()
        )
      ),
      case let .transition(started) = SessionReducer.reduce(
        snapshot: prepared.snapshot,
        command: SessionCommand(expectedRevision: 1, intent: .start),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: 100), liveProjection: nil),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: projectionToken
        )
      ), case let .focusing(focus) = started.snapshot.state,
      let scheduled = started.snapshot.nextScheduledCheckIn
    else {
      Issue.record("expected live focus fixture")
      return
    }
    let observedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 200))
    let cases: [(LiveProjectionObservation?, RecoveryReason)] = [
      (nil, .missingLiveProjection),
      (
        LiveProjectionObservation(
          projectionToken: UUID(),
          rawWallAtProjectionAnchor: focus.wallAnchor.date,
          monotonicElapsedSinceAnchor: .seconds(100)
        ),
        .staleLiveProjection
      ),
    ]
    var recoveryFixture: SessionSnapshot?

    for (observation, reason) in cases {
      let outcome = SessionReducer.reduce(
        snapshot: started.snapshot,
        command: SessionCommand(
          expectedRevision: 2,
          intent: .setLowCognitiveLoadEnabled(true)
        ),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: observedAt.date,
            liveProjection: observation
          ),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: UUID()
        )
      )
      guard case let .transition(reduction) = outcome else {
        Issue.record("expected recovery transition for \(reason)")
        continue
      }
      let trustworthy = SuspendedFocusState(
        phase: focus.phase,
        timing: focus.timingAtAnchor,
        resumeDisposition: .focusing,
        scheduledCheckInRemaining: scheduled.trustedRemaining
      )
      #expect(
        reduction.snapshot.state
          == .recoveryNeeded(
            RecoveryState(
              reason: reason,
              lastTrustworthyState: .focus(trustworthy),
              safeChoices: Set(ClockRecoveryChoice.allCases)
            )))
      #expect(reduction.snapshot.configuration == .defaults)
      #expect(reduction.snapshot.nextScheduledCheckIn == nil)
      #expect(reduction.snapshot.lastConsumedBoundaryToken == nil)
      #expect(reduction.snapshot.lastWallObservationAt == observedAt)
      #expect(reduction.events.map(\.payload) == [.clockRecoveryNeeded(reason: reason)])
      #expect(
        reduction.effects
          == [
            .cancelNotification(SessionNotificationID(boundaryToken: scheduled.token)),
            .invalidateDisplayProjection(projectionToken: nil),
          ])
      #expect(SessionSnapshotValidator.validateCandidate(reduction.snapshot).isEmpty)
      if reason == .missingLiveProjection { recoveryFixture = reduction.snapshot }
    }

    let recoverySnapshot = try #require(recoveryFixture)
    let recoveredProjection = UUID()
    let resumed = SessionReducer.reduce(
      snapshot: recoverySnapshot,
      command: SessionCommand(
        expectedRevision: 3,
        intent: .recoverClock(.resumeSavedRemainder)
      ),
      context: ReductionContext(
        instant: SessionInstant(
          wallNow: Date(timeIntervalSinceReferenceDate: 300), liveProjection: nil),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: recoveredProjection
      )
    )
    guard case let .transition(resumedReduction) = resumed,
      case let .focusing(resumedFocus) = resumedReduction.snapshot.state
    else {
      Issue.record("expected saved focus recovery")
      return
    }
    #expect(resumedFocus.timingAtAnchor == focus.timingAtAnchor)
    #expect(
      resumedFocus.wallAnchor
        == SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 300)))
    #expect(resumedFocus.elapsedBeforeAnchorSeconds == 0)
    #expect(resumedFocus.projectionToken == recoveredProjection)
    #expect(
      resumedReduction.events.map(\.payload) == [.clockRecovered(choice: .resumeSavedRemainder)])
    #expect(SessionSnapshotValidator.validateCandidate(resumedReduction.snapshot).isEmpty)

    for (choice, reason) in [
      (ClockRecoveryChoice.reviewSession, SessionStopReason.clockRecoveryReview),
      (.endSession, .clockRecoveryEnd),
    ] {
      let outcome = SessionReducer.reduce(
        snapshot: recoverySnapshot,
        command: SessionCommand(expectedRevision: 3, intent: .recoverClock(choice)),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: 300), liveProjection: nil),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: UUID()
        )
      )
      guard case let .transition(reduction) = outcome,
        case let .reviewing(review) = reduction.snapshot.state
      else {
        Issue.record("expected recovery review for \(choice)")
        continue
      }
      #expect(review.stopReason == reason)
      #expect(
        reduction.events.map(\.payload.kind) == [.clockRecovered, .reviewStarted])
      #expect(
        reduction.effects == [
          .announceAccessibility(.reviewPresented),
          .invalidateDisplayProjection(projectionToken: nil),
        ])
      #expect(SessionSnapshotValidator.validateCandidate(reduction.snapshot).isEmpty)
    }
  }

  @Test("live configuration event exhaustion precedes boundary allocation exhaustion")
  func liveConfigurationFailurePrecedenceIsExact() throws {
    let sessionID = UUID()
    let projectionToken = UUID()
    let phase = TimingPolicy.classic.phases[0]
    let wall = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100))
    let phaseToken = BoundaryToken(
      sessionID: sessionID,
      kind: .phase,
      phaseID: phase.id,
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
    let snapshot = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 2,
      eventSequence: UInt64.max,
      nextBoundaryOccurrence: UInt64.max,
      state: .focusing(
        FocusState(
          phase: phase,
          timingAtAnchor: .timed(remaining: try PhaseSeconds(1_500)),
          wallAnchor: wall,
          phaseEndsAt: SessionTimestamp(
            unchecked: Date(timeIntervalSinceReferenceDate: 1_600)),
          elapsedBeforeAnchorSeconds: 0,
          projectionToken: projectionToken,
          phaseBoundaryToken: phaseToken
        )),
      plan: try SessionPlan(
        task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic),
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: wall,
      accumulatedFocusSeconds: 0,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: wall,
      nextScheduledCheckIn: ScheduledCheckInBoundary(
        token: scheduledToken,
        dueAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 1_000)),
        trustedRemaining: try CheckInRemainingSeconds(900)
      ),
      lastConsumedBoundaryToken: nil
    )
    let outcome = SessionReducer.reduce(
      snapshot: snapshot,
      command: SessionCommand(
        expectedRevision: 2,
        intent: .setCheckInSchedule(.interval(try CheckInMinutes(30)))
      ),
      context: ReductionContext(
        instant: SessionInstant(
          wallNow: Date(timeIntervalSinceReferenceDate: 200),
          liveProjection: LiveProjectionObservation(
            projectionToken: projectionToken,
            rawWallAtProjectionAnchor: wall.date,
            monotonicElapsedSinceAnchor: .seconds(100)
          )),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: UUID()
      )
    )
    #expect(
      outcome
        == .failed(
          snapshot: snapshot,
          reason: .eventSequenceExhausted(
            requiredAdditionalEvents: 1,
            remainingCapacity: 0
          ))
    )
  }

  @Test("live break configuration preserves the break and obeys boundary and recovery preflight")
  func liveBreakConfigurationIsExact() throws {
    let sessionID = UUID()
    let projectionToken = UUID()
    let choice = BreakChoice(kind: .move, duration: .timed(.five))
    let pausedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 110))
    let breakStartedAt = SessionTimestamp(
      unchecked: Date(timeIntervalSinceReferenceDate: 300))
    let paused = SessionSnapshot(
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
        task: "Task", firstAction: "Return here", capacity: nil,
        timingPolicy: .classic),
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100)),
      accumulatedFocusSeconds: 10,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: pausedAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )
    guard
      case let .transition(started) = SessionReducer.reduce(
        snapshot: paused,
        command: SessionCommand(expectedRevision: 3, intent: .requestBreak(choice)),
        context: ReductionContext(
          instant: SessionInstant(wallNow: breakStartedAt.date, liveProjection: nil),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: projectionToken
        )
      ), case let .breaking(originalBreak) = started.snapshot.state,
      let boundaryToken = originalBreak.boundaryToken,
      let endsAt = originalBreak.endsAt
    else {
      Issue.record("expected live break fixture")
      return
    }

    let changedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 400))
    let schedule = CheckInSchedule.interval(try CheckInMinutes(30))
    let fullThirtyMinutes = try CheckInRemainingSeconds(1_800)
    let changed = SessionReducer.reduce(
      snapshot: started.snapshot,
      command: SessionCommand(
        expectedRevision: 4,
        intent: .setCheckInSchedule(schedule)
      ),
      context: ReductionContext(
        instant: SessionInstant(
          wallNow: changedAt.date,
          liveProjection: LiveProjectionObservation(
            projectionToken: projectionToken,
            rawWallAtProjectionAnchor: breakStartedAt.date,
            monotonicElapsedSinceAnchor: .seconds(100)
          )),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: UUID()
      )
    )
    guard case let .transition(changeReduction) = changed,
      case let .breaking(changedBreak) = changeReduction.snapshot.state
    else {
      Issue.record("expected live break configuration transition")
      return
    }
    #expect(changeReduction.snapshot.configuration.checkInSchedule == schedule)
    #expect(changedBreak.choice == originalBreak.choice)
    #expect(changedBreak.timingAtAnchor == .timed(remaining: try PhaseSeconds(200)))
    #expect(changedBreak.wallAnchor == changedAt)
    #expect(changedBreak.endsAt == endsAt)
    #expect(changedBreak.elapsedBeforeAnchorSeconds == 100)
    #expect(changedBreak.projectionToken == projectionToken)
    #expect(changedBreak.boundaryToken == boundaryToken)
    #expect(
      changedBreak.resumeTarget.scheduledCheckInRemaining
        == fullThirtyMinutes)
    #expect(changeReduction.events.map(\.payload).count == 1)
    #expect(
      changeReduction.effects
        == [.invalidateDisplayProjection(projectionToken: projectionToken)])
    #expect(SessionSnapshotValidator.validateCandidate(changeReduction.snapshot).isEmpty)

    let due = SessionReducer.reduce(
      snapshot: started.snapshot,
      command: SessionCommand(
        expectedRevision: 4,
        intent: .setLowCognitiveLoadEnabled(true)
      ),
      context: ReductionContext(
        instant: SessionInstant(
          wallNow: endsAt.date,
          liveProjection: LiveProjectionObservation(
            projectionToken: projectionToken,
            rawWallAtProjectionAnchor: breakStartedAt.date,
            monotonicElapsedSinceAnchor: .seconds(300)
          )),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: UUID()
      )
    )
    guard case let .transition(dueReduction) = due,
      case let .reentering(reentry) = dueReduction.snapshot.state
    else {
      Issue.record("expected automatic break boundary transition")
      return
    }
    #expect(dueReduction.snapshot.configuration == .defaults)
    #expect(dueReduction.snapshot.accumulatedBreakSeconds == 300)
    #expect(dueReduction.snapshot.lastConsumedBoundaryToken == boundaryToken)
    #expect(reentry.resumeTarget == originalBreak.resumeTarget)
    #expect(reentry.proposedAction == originalBreak.proposedAction)
    #expect(reentry.enteredAt == endsAt)
    #expect(dueReduction.events.map(\.payload) == [.breakEnded, .reentryPresented])
    #expect(
      dueReduction.effects
        == [
          .cancelNotification(SessionNotificationID(boundaryToken: boundaryToken)),
          .playSound(.breakComplete),
          .announceAccessibility(.reentryPresented),
          .invalidateDisplayProjection(projectionToken: nil),
        ])
    #expect(SessionSnapshotValidator.validateCandidate(dueReduction.snapshot).isEmpty)

    let recovery = SessionReducer.reduce(
      snapshot: started.snapshot,
      command: SessionCommand(
        expectedRevision: 4,
        intent: .setBreakSuggestionsEnabled(false)
      ),
      context: ReductionContext(
        instant: SessionInstant(wallNow: changedAt.date, liveProjection: nil),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: UUID()
      )
    )
    guard case let .transition(recoveryReduction) = recovery else {
      Issue.record("expected break recovery transition")
      return
    }
    let trustworthy = SuspendedBreakState(
      choice: originalBreak.choice,
      timing: originalBreak.timingAtAnchor,
      resumeTarget: originalBreak.resumeTarget,
      proposedAction: originalBreak.proposedAction
    )
    #expect(
      recoveryReduction.snapshot.state
        == .recoveryNeeded(
          RecoveryState(
            reason: .missingLiveProjection,
            lastTrustworthyState: .breakState(trustworthy),
            safeChoices: Set(ClockRecoveryChoice.allCases)
          )))
    #expect(recoveryReduction.snapshot.configuration == .defaults)
    #expect(
      recoveryReduction.events.map(\.payload)
        == [.clockRecoveryNeeded(reason: .missingLiveProjection)])
    #expect(
      recoveryReduction.effects
        == [
          .cancelNotification(SessionNotificationID(boundaryToken: boundaryToken)),
          .invalidateDisplayProjection(projectionToken: nil),
        ])
    #expect(SessionSnapshotValidator.validateCandidate(recoveryReduction.snapshot).isEmpty)
  }

  @Test("ending a break early is silent and revised action returns to paused focus")
  func earlyBreakEndAndPausedReentryAreExact() throws {
    let sessionID = UUID()
    let projectionToken = UUID()
    let choice = BreakChoice(kind: .move, duration: .timed(.five))
    let pausedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 110))
    let breakStartedAt = SessionTimestamp(
      unchecked: Date(timeIntervalSinceReferenceDate: 300))
    let paused = SessionSnapshot(
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
        task: "Task", firstAction: "Return here", capacity: nil,
        timingPolicy: .classic),
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100)),
      accumulatedFocusSeconds: 10,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: pausedAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )
    guard
      case let .transition(started) = SessionReducer.reduce(
        snapshot: paused,
        command: SessionCommand(expectedRevision: 3, intent: .requestBreak(choice)),
        context: ReductionContext(
          instant: SessionInstant(wallNow: breakStartedAt.date, liveProjection: nil),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: projectionToken
        )
      ), case let .breaking(liveBreak) = started.snapshot.state,
      let boundaryToken = liveBreak.boundaryToken
    else {
      Issue.record("expected live break fixture")
      return
    }
    let endedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 400))
    let ended = SessionReducer.reduce(
      snapshot: started.snapshot,
      command: SessionCommand(expectedRevision: 4, intent: .endBreak),
      context: ReductionContext(
        instant: SessionInstant(
          wallNow: endedAt.date,
          liveProjection: LiveProjectionObservation(
            projectionToken: projectionToken,
            rawWallAtProjectionAnchor: breakStartedAt.date,
            monotonicElapsedSinceAnchor: .seconds(100)
          )),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: UUID()
      )
    )
    guard case let .transition(endReduction) = ended,
      case let .reentering(reentry) = endReduction.snapshot.state
    else {
      Issue.record("expected early break re-entry")
      return
    }
    #expect(endReduction.snapshot.accumulatedBreakSeconds == 100)
    #expect(endReduction.snapshot.lastConsumedBoundaryToken == nil)
    #expect(reentry.resumeTarget == liveBreak.resumeTarget)
    #expect(reentry.enteredAt == endedAt)
    #expect(endReduction.events.map(\.payload) == [.breakEnded, .reentryPresented])
    #expect(
      endReduction.effects
        == [
          .cancelNotification(SessionNotificationID(boundaryToken: boundaryToken)),
          .announceAccessibility(.reentryPresented),
          .invalidateDisplayProjection(projectionToken: nil),
        ])
    #expect(!endReduction.effects.contains(.playSound(.breakComplete)))
    #expect(SessionSnapshotValidator.validateCandidate(endReduction.snapshot).isEmpty)

    let driftedObservedAt = SessionTimestamp(
      unchecked: Date(timeIntervalSinceReferenceDate: 402))
    let drifted = SessionReducer.reduce(
      snapshot: started.snapshot,
      command: SessionCommand(expectedRevision: 4, intent: .endBreak),
      context: ReductionContext(
        instant: SessionInstant(
          wallNow: driftedObservedAt.date,
          liveProjection: LiveProjectionObservation(
            projectionToken: projectionToken,
            rawWallAtProjectionAnchor: breakStartedAt.date,
            monotonicElapsedSinceAnchor: .seconds(100)
          )),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: UUID()
      )
    )
    guard case let .transition(driftedReduction) = drifted,
      case let .reentering(driftedReentry) = driftedReduction.snapshot.state
    else {
      Issue.record("expected drifted early break re-entry")
      return
    }
    #expect(driftedReentry.enteredAt == endedAt)
    #expect(driftedReduction.snapshot.lastWallObservationAt == driftedObservedAt)
    #expect(driftedReduction.events.allSatisfy { $0.occurredAt == driftedObservedAt })
    #expect(SessionSnapshotValidator.validateCandidate(driftedReduction.snapshot).isEmpty)

    let acceptedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 450))
    let accepted = SessionReducer.reduce(
      snapshot: endReduction.snapshot,
      command: SessionCommand(
        expectedRevision: 5,
        intent: .acceptRevisedAction("  Open the next paragraph  ")
      ),
      context: ReductionContext(
        instant: SessionInstant(wallNow: acceptedAt.date, liveProjection: nil),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: UUID()
      )
    )
    guard case let .transition(acceptReduction) = accepted,
      case let .paused(restored) = acceptReduction.snapshot.state
    else {
      Issue.record("expected paused re-entry acceptance")
      return
    }
    #expect(acceptReduction.snapshot.plan?.firstAction == "Open the next paragraph")
    #expect(restored.phase == reentry.resumeTarget.phase)
    #expect(restored.timing == reentry.resumeTarget.timing)
    #expect(restored.scheduledCheckInRemaining == reentry.resumeTarget.scheduledCheckInRemaining)
    #expect(restored.pausedAt == acceptedAt)
    #expect(acceptReduction.events.map(\.payload) == [.actionRevised])
    #expect(
      acceptReduction.effects == [.invalidateDisplayProjection(projectionToken: nil)])
    #expect(SessionSnapshotValidator.validateCandidate(acceptReduction.snapshot).isEmpty)

    let unchanged = SessionReducer.reduce(
      snapshot: endReduction.snapshot,
      command: SessionCommand(
        expectedRevision: 5,
        intent: .acceptRevisedAction(" Return here ")
      ),
      context: ReductionContext(
        instant: SessionInstant(wallNow: acceptedAt.date, liveProjection: nil),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: UUID()
      )
    )
    guard case let .transition(unchangedReduction) = unchanged,
      case let .paused(unchangedPaused) = unchangedReduction.snapshot.state
    else {
      Issue.record("expected unchanged paused re-entry acceptance")
      return
    }
    #expect(unchangedReduction.snapshot.plan?.firstAction == "Return here")
    #expect(unchangedReduction.snapshot.eventSequence == endReduction.snapshot.eventSequence)
    #expect(unchangedReduction.events.isEmpty)
    #expect(unchangedPaused.pausedAt == acceptedAt)
    #expect(SessionSnapshotValidator.validateCandidate(unchangedReduction.snapshot).isEmpty)
  }

  @Test("accepting a revised action restores a focusing re-entry target")
  func focusingReentryAcceptanceIsExact() throws {
    let sessionID = UUID()
    let projectionToken = UUID()
    let enteredAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 400))
    let acceptedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 450))
    let target = SuspendedFocusState(
      phase: TimingPolicy.classic.phases[0],
      timing: .timed(remaining: try PhaseSeconds(1_490)),
      resumeDisposition: .focusing,
      scheduledCheckInRemaining: try CheckInRemainingSeconds(890)
    )
    let snapshot = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 4,
      eventSequence: 6,
      nextBoundaryOccurrence: 2,
      state: .reentering(
        ReentryState(
          resumeTarget: target,
          proposedAction: "Open the outline",
          enteredAt: enteredAt
        )),
      plan: try SessionPlan(
        task: "Task", firstAction: "Open the outline", capacity: nil,
        timingPolicy: .classic),
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100)),
      accumulatedFocusSeconds: 10,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: enteredAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )
    let outcome = SessionReducer.reduce(
      snapshot: snapshot,
      command: SessionCommand(
        expectedRevision: 4,
        intent: .acceptRevisedAction("Open the first paragraph")
      ),
      context: ReductionContext(
        instant: SessionInstant(wallNow: acceptedAt.date, liveProjection: nil),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: projectionToken
      )
    )
    guard case let .transition(reduction) = outcome,
      case let .focusing(focus) = reduction.snapshot.state,
      let scheduled = reduction.snapshot.nextScheduledCheckIn,
      let phaseEndsAt = focus.phaseEndsAt
    else {
      Issue.record("expected focusing re-entry acceptance")
      return
    }
    #expect(reduction.snapshot.plan?.firstAction == "Open the first paragraph")
    #expect(focus.phase == target.phase)
    #expect(focus.timingAtAnchor == target.timing)
    #expect(focus.wallAnchor == acceptedAt)
    #expect(focus.elapsedBeforeAnchorSeconds == 0)
    #expect(focus.projectionToken == projectionToken)
    #expect(scheduled.trustedRemaining == target.scheduledCheckInRemaining)
    #expect(
      reduction.events.map(\.payload) == [
        .actionRevised,
        .phaseResumed(phase: target.phase, endsAt: phaseEndsAt),
      ])
    #expect(
      reduction.effects
        == [
          .scheduleNotification(
            SessionNotificationRequest(
              boundaryToken: scheduled.token,
              fireAt: scheduled.dueAt
            )),
          .announceAccessibility(.focusStarted),
          .invalidateDisplayProjection(projectionToken: projectionToken),
        ])
    #expect(SessionSnapshotValidator.validateCandidate(reduction.snapshot).isEmpty)
  }

  @Test("non-live stop enters review with exact reason and rollback-safe end time")
  func nonLiveStopEntersReviewExactly() throws {
    let sessionID = UUID()
    let startedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100))
    let pausedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 150))
    let observedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 90))
    let thought = ParkedThought(id: UUID(), text: "Later", createdAt: pausedAt)
    let target = SuspendedFocusState(
      phase: TimingPolicy.classic.phases[0],
      timing: .timed(remaining: try PhaseSeconds(1_490)),
      resumeDisposition: .paused,
      scheduledCheckInRemaining: try CheckInRemainingSeconds(890)
    )
    let states: [SessionState] = [
      .paused(
        PausedState(
          phase: target.phase,
          timing: target.timing,
          pausedAt: pausedAt,
          scheduledCheckInRemaining: target.scheduledCheckInRemaining
        )),
      .checkingIn(
        CheckInState(
          suspended: target,
          trigger: .manual,
          continuation: .resumeSuspended,
          phaseBoundaryScheduledCheckInRemaining: nil
        )),
      .reentering(
        ReentryState(
          resumeTarget: target,
          proposedAction: "Old action",
          enteredAt: pausedAt
        )),
    ]
    let cases: [(SessionStopChoice, SessionStopReason)] = [
      (.completed, .completed),
      (.intentionalStop, .intentionalStop),
    ]

    for state in states {
      let snapshot = SessionSnapshot(
        schemaVersion: 1,
        sessionID: sessionID,
        revision: 4,
        eventSequence: 6,
        nextBoundaryOccurrence: 2,
        state: state,
        plan: try SessionPlan(
          task: "Old task", firstAction: "Old action", capacity: nil,
          timingPolicy: .classic),
        configuration: .defaults,
        parkedThoughts: [thought],
        startedAt: startedAt,
        accumulatedFocusSeconds: 10,
        accumulatedBreakSeconds: 5,
        lastWallObservationAt: pausedAt,
        nextScheduledCheckIn: nil,
        lastConsumedBoundaryToken: nil
      )
      #expect(SessionSnapshotValidator.validateCandidate(snapshot).isEmpty)
      for (choice, reason) in cases {
        let outcome = SessionReducer.reduce(
          snapshot: snapshot,
          command: SessionCommand(expectedRevision: 4, intent: .stop(choice)),
          context: ReductionContext(
            instant: SessionInstant(wallNow: observedAt.date, liveProjection: nil),
            generatedSessionID: UUID(),
            generatedThoughtID: UUID(),
            generatedProjectionToken: UUID()
          )
        )
        guard case let .transition(reduction) = outcome,
          case let .reviewing(review) = reduction.snapshot.state
        else {
          Issue.record("expected non-live stop review for \(state.kind) / \(reason)")
          continue
        }
        let expectedDraft = SessionSummaryDraft(
          endedAt: startedAt,
          focusedSeconds: 10,
          breakSeconds: 5,
          parkedThoughtCount: 1,
          optionalReflection: nil
        )
        let expectedReviewEvent = SessionReviewEvent(
          focusedSeconds: 10,
          breakSeconds: 5,
          stopReason: reason,
          parkedThoughtCount: 1,
          hasReflection: false
        )
        #expect(review.draft == expectedDraft)
        #expect(review.stopReason == reason)
        #expect(review.replacementDraft == nil)
        #expect(reduction.snapshot.lastWallObservationAt == observedAt)
        #expect(reduction.snapshot.parkedThoughts == [thought])
        #expect(reduction.events.map(\.occurredAt) == [observedAt, observedAt])
        #expect(
          reduction.events.map(\.payload)
            == [
              .sessionStopRequested(reason: reason),
              .reviewStarted(expectedReviewEvent),
            ])
        #expect(
          reduction.effects
            == [
              .announceAccessibility(.reviewPresented),
              .invalidateDisplayProjection(projectionToken: nil),
            ])
        #expect(SessionSnapshotValidator.validateCandidate(reduction.snapshot).isEmpty)
      }
    }
  }

  @Test("prepared stop remains a wall-independent invalid transition")
  func preparedStopIsInvalidWithoutClockUse() throws {
    let sessionID = UUID()
    let preparedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 10))
    let snapshot = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 1,
      eventSequence: 1,
      nextBoundaryOccurrence: 0,
      state: .prepared(PreparedState(preparedAt: preparedAt)),
      plan: try SessionPlan(
        task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic),
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
      instant: SessionInstant(
        wallNow: Date(timeIntervalSinceReferenceDate: .nan), liveProjection: nil),
      generatedSessionID: UUID(),
      generatedThoughtID: UUID(),
      generatedProjectionToken: UUID()
    )
    for choice in [SessionStopChoice.completed, .intentionalStop] {
      #expect(
        SessionReducer.reduce(
          snapshot: snapshot,
          command: SessionCommand(expectedRevision: 1, intent: .stop(choice)),
          context: context
        )
          == .rejected(
            snapshot: snapshot,
            reason: .invalidTransition(state: .prepared, intent: .stop)
          ))
    }
  }

  @Test("reflection edits preserve the frozen review and finalization uses old-session truth")
  func reviewReflectionAndFinalizationAreExact() throws {
    let sessionID = UUID()
    let startedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100))
    let endedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 400))
    let thought = ParkedThought(id: UUID(), text: "Later", createdAt: endedAt)
    let replacement = SessionDraft(
      plan: try SessionPlan(
        task: "Replacement task", firstAction: "Replacement action", capacity: nil,
        timingPolicy: .gentleStart)
    )
    let review = ReviewState(
      draft: SessionSummaryDraft(
        endedAt: endedAt,
        focusedSeconds: 1_200,
        breakSeconds: 300,
        parkedThoughtCount: 1,
        optionalReflection: nil
      ),
      stopReason: .intentionalStop,
      replacementDraft: replacement
    )
    let snapshot = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 5,
      eventSequence: 8,
      nextBoundaryOccurrence: 3,
      state: .reviewing(review),
      plan: try SessionPlan(
        task: "Old task", firstAction: "Old final action", capacity: nil,
        timingPolicy: .classic),
      configuration: .defaults,
      parkedThoughts: [thought],
      startedAt: startedAt,
      accumulatedFocusSeconds: 1_200,
      accumulatedBreakSeconds: 300,
      lastWallObservationAt: endedAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )
    let editedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 450))
    let editContext = ReductionContext(
      instant: SessionInstant(wallNow: editedAt.date, liveProjection: nil),
      generatedSessionID: UUID(),
      generatedThoughtID: UUID(),
      generatedProjectionToken: UUID()
    )
    let edited = SessionReducer.reduce(
      snapshot: snapshot,
      command: SessionCommand(
        expectedRevision: 5,
        intent: .updateReviewReflection("  I found a clean stopping point.  ")
      ),
      context: editContext
    )
    guard case let .transition(editReduction) = edited,
      case let .reviewing(editedReview) = editReduction.snapshot.state
    else {
      Issue.record("expected reflection edit")
      return
    }
    #expect(editedReview.draft.endedAt == endedAt)
    #expect(editedReview.draft.focusedSeconds == 1_200)
    #expect(editedReview.draft.breakSeconds == 300)
    #expect(editedReview.draft.optionalReflection == "I found a clean stopping point.")
    #expect(editedReview.stopReason == .intentionalStop)
    #expect(editedReview.replacementDraft == replacement)
    #expect(
      editReduction.events.map(\.payload)
        == [.reviewReflectionUpdated(hasReflection: true)])
    #expect(editReduction.effects == [.invalidateDisplayProjection(projectionToken: nil)])
    #expect(SessionSnapshotValidator.validateCandidate(editReduction.snapshot).isEmpty)

    #expect(
      SessionReducer.reduce(
        snapshot: editReduction.snapshot,
        command: SessionCommand(
          expectedRevision: 6,
          intent: .updateReviewReflection("I found a clean stopping point.")
        ),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: .nan), liveProjection: nil),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: UUID()
        )
      )
        == .noChange(
          snapshot: editReduction.snapshot,
          reason: .alreadyInRequestedState
        ))

    let clearedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 460))
    let cleared = SessionReducer.reduce(
      snapshot: editReduction.snapshot,
      command: SessionCommand(
        expectedRevision: 6,
        intent: .updateReviewReflection("  \n\t  ")
      ),
      context: ReductionContext(
        instant: SessionInstant(wallNow: clearedAt.date, liveProjection: nil),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: UUID()
      )
    )
    guard case let .transition(clearReduction) = cleared,
      case let .reviewing(clearedReview) = clearReduction.snapshot.state
    else {
      Issue.record("expected whitespace reflection clear")
      return
    }
    #expect(clearedReview.draft.optionalReflection == nil)
    #expect(clearedReview.draft.endedAt == endedAt)
    #expect(
      clearReduction.events.map(\.payload)
        == [.reviewReflectionUpdated(hasReflection: false)])
    #expect(
      SessionReducer.reduce(
        snapshot: clearReduction.snapshot,
        command: SessionCommand(
          expectedRevision: 7,
          intent: .updateReviewReflection(nil)
        ),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: .nan), liveProjection: nil),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: UUID()
        )
      )
        == .noChange(
          snapshot: clearReduction.snapshot,
          reason: .alreadyInRequestedState
        ))

    #expect(
      SessionReducer.reduce(
        snapshot: snapshot,
        command: SessionCommand(
          expectedRevision: 5,
          intent: .updateReviewReflection(String(repeating: "x", count: 2_001))
        ),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: .nan), liveProjection: nil),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: UUID()
        )
      ) == .rejected(snapshot: snapshot, reason: .invalidText(.reflection))
    )

    let finalizedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 500))
    let finalized = SessionReducer.reduce(
      snapshot: editReduction.snapshot,
      command: SessionCommand(expectedRevision: 6, intent: .finalizeReview),
      context: ReductionContext(
        instant: SessionInstant(wallNow: finalizedAt.date, liveProjection: nil),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: UUID()
      )
    )
    guard case let .transition(finalReduction) = finalized,
      case let .completed(completed) = finalReduction.snapshot.state
    else {
      Issue.record("expected review finalization")
      return
    }
    let summary = completed.summary
    #expect(summary.sessionID == sessionID)
    #expect(summary.task == "Old task")
    #expect(summary.finalAction == "Old final action")
    #expect(summary.startedAt == startedAt)
    #expect(summary.endedAt == endedAt)
    #expect(summary.focusedSeconds == 1_200)
    #expect(summary.breakSeconds == 300)
    #expect(summary.stopReason == .intentionalStop)
    #expect(summary.parkedThoughtCount == 1)
    #expect(summary.optionalReflection == "I found a clean stopping point.")
    #expect(completed.pendingReplacementDraft == replacement)
    #expect(finalReduction.snapshot.plan == nil)
    #expect(finalReduction.snapshot.parkedThoughts == [thought])
    #expect(finalReduction.snapshot.lastWallObservationAt == finalizedAt)
    #expect(
      finalReduction.events.map(\.payload)
        == [
          .sessionCompleted(
            summary: SessionSummaryEvent(
              focusedSeconds: 1_200,
              breakSeconds: 300,
              stopReason: .intentionalStop,
              parkedThoughtCount: 1,
              hasReflection: true
            ))
        ])
    #expect(finalReduction.effects == [.invalidateDisplayProjection(projectionToken: nil)])
    #expect(SessionSnapshotValidator.validateCandidate(finalReduction.snapshot).isEmpty)
  }

  @Test("live relaunch restores fresh focus projection or enters typed recovery")
  func liveFocusRelaunchIsExact() throws {
    let sessionID = UUID()
    let originalProjection = UUID()
    let restoredProjection = UUID()
    let plan = try SessionPlan(
      task: "Relaunch task", firstAction: "Restore safely", capacity: nil,
      timingPolicy: .classic)
    guard
      case let .transition(prepared) = SessionReducer.reduce(
        snapshot: .canonicalIdle,
        command: SessionCommand(
          expectedRevision: 0, intent: .prepare(SessionDraft(plan: plan))),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: 10), liveProjection: nil),
          generatedSessionID: sessionID,
          generatedThoughtID: UUID(),
          generatedProjectionToken: UUID()
        )
      ),
      case let .transition(started) = SessionReducer.reduce(
        snapshot: prepared.snapshot,
        command: SessionCommand(expectedRevision: 1, intent: .start),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: 100), liveProjection: nil),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: originalProjection
        )
      )
    else {
      Issue.record("expected relaunch fixture")
      return
    }
    let restored = SessionReducer.reduce(
      snapshot: started.snapshot,
      command: SessionCommand(expectedRevision: 2, intent: .reconcileTime(.relaunch)),
      context: ReductionContext(
        instant: SessionInstant(
          wallNow: Date(timeIntervalSinceReferenceDate: 200), liveProjection: nil),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: restoredProjection
      )
    )
    guard case let .transition(reduction) = restored,
      case let .focusing(focus) = reduction.snapshot.state
    else {
      Issue.record("expected restored live focus")
      return
    }
    #expect(
      focus.wallAnchor == SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 200)))
    #expect(focus.elapsedBeforeAnchorSeconds == 100)
    #expect(focus.timingAtAnchor == .timed(remaining: try PhaseSeconds(1_400)))
    #expect(focus.projectionToken == restoredProjection)
    #expect(reduction.snapshot.accumulatedFocusSeconds == 0)
    let expectedCadence = try CheckInRemainingSeconds(800)
    #expect(reduction.snapshot.nextScheduledCheckIn?.trustedRemaining == expectedCadence)
    #expect(reduction.events.map(\.payload.kind) == [.liveProjectionRestored])
    #expect(
      reduction.effects == [
        .invalidateDisplayProjection(projectionToken: restoredProjection)
      ])
    #expect(SessionSnapshotValidator.validateCandidate(reduction.snapshot).isEmpty)

    let ambiguous = SessionReducer.reduce(
      snapshot: started.snapshot,
      command: SessionCommand(expectedRevision: 2, intent: .reconcileTime(.relaunch)),
      context: ReductionContext(
        instant: SessionInstant(
          wallNow: Date(timeIntervalSinceReferenceDate: 97), liveProjection: nil),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: UUID()
      )
    )
    guard case let .transition(recovery) = ambiguous else {
      Issue.record("expected relaunch recovery")
      return
    }
    #expect(recovery.snapshot.state.kind == .recoveryNeeded)
    #expect(
      recovery.events.map(\.payload) == [
        .clockRecoveryNeeded(reason: .wallClockAmbiguousAfterRelaunch)
      ])
    #expect(
      SessionReducer.reduce(
        snapshot: started.snapshot,
        command: SessionCommand(expectedRevision: 2, intent: .reconcileTime(.relaunch)),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: .nan), liveProjection: nil),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: UUID()
        )
      ) == .failed(snapshot: started.snapshot, reason: .nonFiniteWallObservation)
    )

    let scheduled = try #require(started.snapshot.nextScheduledCheckIn)
    let earlyContext = ReductionContext(
      instant: SessionInstant(
        wallNow: Date(timeIntervalSinceReferenceDate: 200),
        liveProjection: LiveProjectionObservation(
          projectionToken: originalProjection,
          rawWallAtProjectionAnchor: Date(timeIntervalSinceReferenceDate: 100),
          monotonicElapsedSinceAnchor: .seconds(100)
        )),
      generatedSessionID: UUID(),
      generatedThoughtID: UUID(),
      generatedProjectionToken: UUID()
    )
    #expect(
      SessionReducer.reduce(
        snapshot: started.snapshot,
        command: SessionCommand(
          expectedRevision: 2,
          intent: .reconcileTime(.deadlineFired(token: scheduled.token))
        ),
        context: earlyContext
      )
        == .rejected(
          snapshot: started.snapshot,
          reason: .boundaryNotDue(
            token: scheduled.token,
            dueAt: scheduled.dueAt,
            observedAt: SessionTimestamp(
              unchecked: Date(timeIntervalSinceReferenceDate: 200))
          ))
    )

    let rebasedEarly = SessionReducer.reduce(
      snapshot: started.snapshot,
      command: SessionCommand(
        expectedRevision: 2,
        intent: .reconcileTime(.deadlineFired(token: scheduled.token))
      ),
      context: ReductionContext(
        instant: SessionInstant(
          wallNow: Date(timeIntervalSinceReferenceDate: 210),
          liveProjection: LiveProjectionObservation(
            projectionToken: originalProjection,
            rawWallAtProjectionAnchor: Date(timeIntervalSinceReferenceDate: 100),
            monotonicElapsedSinceAnchor: .seconds(100)
          )),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: UUID()
      )
    )
    guard case let .transition(rebasedReduction) = rebasedEarly,
      case let .focusing(rebasedFocus) = rebasedReduction.snapshot.state,
      let rebasedScheduled = rebasedReduction.snapshot.nextScheduledCheckIn
    else {
      Issue.record("expected adjustment-only early callback")
      return
    }
    #expect(rebasedReduction.snapshot.revision == 3)
    #expect(rebasedReduction.events.map(\.payload.kind) == [.clockAdjusted])
    #expect(rebasedScheduled.token == scheduled.token)
    #expect(rebasedReduction.snapshot.lastConsumedBoundaryToken == nil)
    #expect(rebasedFocus.projectionToken == originalProjection)
    #expect(
      rebasedReduction.effects == [
        .cancelNotification(SessionNotificationID(boundaryToken: scheduled.token)),
        .scheduleNotification(
          SessionNotificationRequest(
            boundaryToken: rebasedScheduled.token,
            fireAt: rebasedScheduled.dueAt
          )),
        .invalidateDisplayProjection(projectionToken: originalProjection),
      ])
    #expect(SessionSnapshotValidator.validateCandidate(rebasedReduction.snapshot).isEmpty)

    let due = SessionReducer.reduce(
      snapshot: started.snapshot,
      command: SessionCommand(
        expectedRevision: 2,
        intent: .reconcileTime(.deadlineFired(token: scheduled.token))
      ),
      context: ReductionContext(
        instant: SessionInstant(
          wallNow: scheduled.dueAt.date,
          liveProjection: LiveProjectionObservation(
            projectionToken: originalProjection,
            rawWallAtProjectionAnchor: Date(timeIntervalSinceReferenceDate: 100),
            monotonicElapsedSinceAnchor: .seconds(900)
          )),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: UUID()
      )
    )
    guard case let .transition(dueReduction) = due else {
      Issue.record("expected due callback transition")
      return
    }
    #expect(dueReduction.snapshot.state.kind == .checkingIn)
    #expect(dueReduction.snapshot.lastConsumedBoundaryToken == scheduled.token)
    #expect(dueReduction.events.map(\.payload.kind) == [.checkInOpened])
    let callbackClassificationContext = ReductionContext(
      instant: SessionInstant(
        wallNow: Date(timeIntervalSinceReferenceDate: .nan), liveProjection: nil),
      generatedSessionID: UUID(),
      generatedThoughtID: UUID(),
      generatedProjectionToken: UUID()
    )
    #expect(
      SessionReducer.reduce(
        snapshot: dueReduction.snapshot,
        command: SessionCommand(
          expectedRevision: 3,
          intent: .reconcileTime(.deadlineFired(token: scheduled.token))
        ),
        context: callbackClassificationContext
      )
        == .rejected(
          snapshot: dueReduction.snapshot,
          reason: .duplicateBoundary(scheduled.token)
        )
    )

    let staleToken = BoundaryToken(
      sessionID: sessionID,
      kind: .scheduledCheckIn,
      phaseID: nil,
      sourceRevision: 2,
      occurrence: scheduled.token.occurrence + 10
    )
    #expect(
      SessionReducer.reduce(
        snapshot: started.snapshot,
        command: SessionCommand(
          expectedRevision: 2,
          intent: .reconcileTime(.deadlineFired(token: staleToken))
        ),
        context: callbackClassificationContext
      ) == .rejected(snapshot: started.snapshot, reason: .staleBoundary(staleToken))
    )

    #expect(
      SessionReducer.reduce(
        snapshot: started.snapshot,
        command: SessionCommand(expectedRevision: 2, intent: .reconcileTime(.wake)),
        context: earlyContext
      ) == .noChange(snapshot: started.snapshot, reason: .observationIrrelevant)
    )
  }

  @Test("active-session conflict choices preserve old-session truth and replacement intent")
  func activeSessionConflictIsExact() throws {
    let sessionID = UUID()
    let projectionToken = UUID()
    let plan = try SessionPlan(
      task: "Current task", firstAction: "Current action", capacity: nil, timingPolicy: .classic)
    let replacementPlan = try SessionPlan(
      task: "Next task", firstAction: "Next action", capacity: nil, timingPolicy: .flow)
    let replacement = SessionDraft(plan: replacementPlan)
    guard
      case let .transition(prepared) = SessionReducer.reduce(
        snapshot: .canonicalIdle,
        command: SessionCommand(
          expectedRevision: 0,
          intent: .prepare(SessionDraft(plan: plan))
        ),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: 10), liveProjection: nil),
          generatedSessionID: sessionID,
          generatedThoughtID: UUID(),
          generatedProjectionToken: UUID()
        )
      ),
      case let .transition(started) = SessionReducer.reduce(
        snapshot: prepared.snapshot,
        command: SessionCommand(expectedRevision: 1, intent: .start),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: 100), liveProjection: nil),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: projectionToken
        )
      ), let scheduled = started.snapshot.nextScheduledCheckIn
    else {
      Issue.record("expected conflict fixture")
      return
    }
    let wallIndependentContext = ReductionContext(
      instant: SessionInstant(
        wallNow: Date(timeIntervalSinceReferenceDate: .nan), liveProjection: nil),
      generatedSessionID: UUID(),
      generatedThoughtID: UUID(),
      generatedProjectionToken: UUID()
    )
    #expect(
      SessionReducer.reduce(
        snapshot: started.snapshot,
        command: SessionCommand(
          expectedRevision: 2,
          intent: .resolveActiveSessionConflict(choice: .resumeCurrent, replacement: nil)
        ),
        context: wallIndependentContext
      ) == .noChange(snapshot: started.snapshot, reason: .resumeCurrentSelected)
    )
    #expect(
      SessionReducer.reduce(
        snapshot: started.snapshot,
        command: SessionCommand(
          expectedRevision: 2,
          intent: .resolveActiveSessionConflict(choice: .cancel, replacement: nil)
        ),
        context: wallIndependentContext
      ) == .noChange(snapshot: started.snapshot, reason: .conflictCancelled)
    )
    for choice in [ActiveSessionConflictChoice.resumeCurrent, .cancel] {
      #expect(
        SessionReducer.reduce(
          snapshot: started.snapshot,
          command: SessionCommand(
            expectedRevision: 2,
            intent: .resolveActiveSessionConflict(choice: choice, replacement: replacement)
          ),
          context: wallIndependentContext
        ) == .rejected(snapshot: started.snapshot, reason: .replacementDraftNotAllowed)
      )
    }
    #expect(
      SessionReducer.reduce(
        snapshot: started.snapshot,
        command: SessionCommand(
          expectedRevision: 2,
          intent: .resolveActiveSessionConflict(choice: .replaceAndReview, replacement: nil)
        ),
        context: wallIndependentContext
      ) == .rejected(snapshot: started.snapshot, reason: .replacementDraftRequired)
    )

    let dueContext = ReductionContext(
      instant: SessionInstant(
        wallNow: scheduled.dueAt.date,
        liveProjection: LiveProjectionObservation(
          projectionToken: projectionToken,
          rawWallAtProjectionAnchor: Date(timeIntervalSinceReferenceDate: 100),
          monotonicElapsedSinceAnchor: .seconds(900)
        )),
      generatedSessionID: UUID(),
      generatedThoughtID: UUID(),
      generatedProjectionToken: UUID()
    )
    let replaced = SessionReducer.reduce(
      snapshot: started.snapshot,
      command: SessionCommand(
        expectedRevision: 2,
        intent: .resolveActiveSessionConflict(
          choice: .replaceAndReview,
          replacement: replacement
        )
      ),
      context: dueContext
    )
    guard case let .transition(replacedReduction) = replaced,
      case let .reviewing(review) = replacedReduction.snapshot.state
    else {
      Issue.record("expected replace-and-review transition")
      return
    }
    #expect(review.stopReason == .replacedByAnotherSession)
    #expect(review.replacementDraft == replacement)
    #expect(review.draft.focusedSeconds == 900)
    #expect(replacedReduction.snapshot.lastConsumedBoundaryToken == nil)
    #expect(
      replacedReduction.events.map(\.payload.kind) == [
        .sessionReplacementRequested, .reviewStarted,
      ])
    #expect(
      !replacedReduction.events.contains {
        $0.payload.kind == .phaseElapsed || $0.payload.kind == .checkInOpened
      })

    let laterPlan = try SessionPlan(
      task: "Later task", firstAction: "Later action", capacity: nil, timingPolicy: .classic)
    let laterReplacement = SessionDraft(plan: laterPlan)
    let updated = SessionReducer.reduce(
      snapshot: replacedReduction.snapshot,
      command: SessionCommand(
        expectedRevision: 3,
        intent: .resolveActiveSessionConflict(
          choice: .replaceAndReview,
          replacement: laterReplacement
        )
      ),
      context: ReductionContext(
        instant: SessionInstant(
          wallNow: Date(timeIntervalSinceReferenceDate: 1_100), liveProjection: nil),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: UUID()
      )
    )
    guard case let .transition(updatedReduction) = updated,
      case let .reviewing(updatedReview) = updatedReduction.snapshot.state
    else {
      Issue.record("expected replacement draft update")
      return
    }
    #expect(updatedReview.draft == review.draft)
    #expect(updatedReview.stopReason == .replacedByAnotherSession)
    #expect(updatedReview.replacementDraft == laterReplacement)
    #expect(updatedReduction.events.map(\.payload) == [.sessionReplacementRequested])
    #expect(updatedReduction.effects == [.invalidateDisplayProjection(projectionToken: nil)])
  }

  @Test("live focus stop preserves the terminal request before and at a due boundary")
  func liveFocusStopIsExact() throws {
    let sessionID = UUID()
    let projectionToken = UUID()
    let plan = try SessionPlan(
      task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic)
    guard
      case let .transition(prepared) = SessionReducer.reduce(
        snapshot: .canonicalIdle,
        command: SessionCommand(
          expectedRevision: 0,
          intent: .prepare(SessionDraft(plan: plan))
        ),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: 10), liveProjection: nil),
          generatedSessionID: sessionID,
          generatedThoughtID: UUID(),
          generatedProjectionToken: UUID()
        )
      ),
      case let .transition(started) = SessionReducer.reduce(
        snapshot: prepared.snapshot,
        command: SessionCommand(expectedRevision: 1, intent: .start),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: 100), liveProjection: nil),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: projectionToken
        )
      ), let scheduled = started.snapshot.nextScheduledCheckIn
    else {
      Issue.record("expected live focus fixture")
      return
    }
    #expect(
      SessionReducer.reduce(
        snapshot: started.snapshot,
        command: SessionCommand(
          expectedRevision: 2,
          intent: .prepare(SessionDraft(plan: plan))
        ),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: .nan), liveProjection: nil),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: UUID()
        )
      ) == .rejected(snapshot: started.snapshot, reason: .activeSessionExists)
    )
    #expect(
      SessionReducer.reduce(
        snapshot: started.snapshot,
        command: SessionCommand(expectedRevision: 2, intent: .start),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: .nan), liveProjection: nil),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: UUID()
        )
      ) == .rejected(snapshot: started.snapshot, reason: .activeSessionExists)
    )
    let cases: [(SessionTimestamp, Duration, SessionStopChoice, UInt64)] = [
      (
        SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 200)),
        .seconds(100),
        .intentionalStop,
        100
      ),
      (scheduled.dueAt, .seconds(900), .completed, 900),
    ]

    for (observedAt, elapsed, choice, expectedFocus) in cases {
      let outcome = SessionReducer.reduce(
        snapshot: started.snapshot,
        command: SessionCommand(expectedRevision: 2, intent: .stop(choice)),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: observedAt.date,
            liveProjection: LiveProjectionObservation(
              projectionToken: projectionToken,
              rawWallAtProjectionAnchor: Date(timeIntervalSinceReferenceDate: 100),
              monotonicElapsedSinceAnchor: elapsed
            )),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: UUID()
        )
      )
      guard case let .transition(reduction) = outcome,
        case let .reviewing(review) = reduction.snapshot.state
      else {
        Issue.record("expected live focus review")
        continue
      }
      let reason: SessionStopReason = choice == .completed ? .completed : .intentionalStop
      #expect(review.draft.endedAt == observedAt)
      #expect(review.draft.focusedSeconds == expectedFocus)
      #expect(review.draft.breakSeconds == 0)
      #expect(review.stopReason == reason)
      #expect(reduction.snapshot.accumulatedFocusSeconds == expectedFocus)
      #expect(reduction.snapshot.lastConsumedBoundaryToken == nil)
      #expect(reduction.snapshot.nextBoundaryOccurrence == started.snapshot.nextBoundaryOccurrence)
      #expect(reduction.snapshot.plan == started.snapshot.plan)
      #expect(reduction.snapshot.configuration == started.snapshot.configuration)
      #expect(
        reduction.events.map(\.payload) == [
          .sessionStopRequested(reason: reason),
          .reviewStarted(
            SessionReviewEvent(
              focusedSeconds: expectedFocus,
              breakSeconds: 0,
              stopReason: reason,
              parkedThoughtCount: 0,
              hasReflection: false
            )),
        ])
      #expect(
        !reduction.events.contains {
          $0.payload.kind == .phaseElapsed || $0.payload.kind == .checkInOpened
        })
      #expect(
        reduction.effects
          == [
            .cancelNotification(SessionNotificationID(boundaryToken: scheduled.token)),
            .announceAccessibility(.reviewPresented),
            .invalidateDisplayProjection(projectionToken: nil),
          ])
      #expect(SessionSnapshotValidator.validateCandidate(reduction.snapshot).isEmpty)
    }

    let driftedObservedAt = SessionTimestamp(
      unchecked: Date(timeIntervalSinceReferenceDate: 210))
    let driftContext = ReductionContext(
      instant: SessionInstant(
        wallNow: driftedObservedAt.date,
        liveProjection: LiveProjectionObservation(
          projectionToken: projectionToken,
          rawWallAtProjectionAnchor: Date(timeIntervalSinceReferenceDate: 100),
          monotonicElapsedSinceAnchor: .seconds(100)
        )),
      generatedSessionID: UUID(),
      generatedThoughtID: UUID(),
      generatedProjectionToken: UUID()
    )
    let drifted = SessionReducer.reduce(
      snapshot: started.snapshot,
      command: SessionCommand(expectedRevision: 2, intent: .stop(.intentionalStop)),
      context: driftContext
    )
    guard case let .transition(driftReduction) = drifted,
      case let .reviewing(driftReview) = driftReduction.snapshot.state
    else {
      Issue.record("expected drifted live stop review")
      return
    }
    let expectedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 200))
    #expect(driftReview.draft.endedAt == expectedAt)
    #expect(driftReduction.snapshot.lastWallObservationAt == driftedObservedAt)
    #expect(
      driftReduction.events.map(\.payload.kind) == [
        .clockAdjusted, .sessionStopRequested, .reviewStarted,
      ])
    #expect(driftReduction.events.allSatisfy { $0.occurredAt == driftedObservedAt })

    let constrained = SessionSnapshot(
      schemaVersion: started.snapshot.schemaVersion,
      sessionID: started.snapshot.sessionID,
      revision: started.snapshot.revision,
      eventSequence: UInt64.max - 2,
      nextBoundaryOccurrence: started.snapshot.nextBoundaryOccurrence,
      state: started.snapshot.state,
      plan: started.snapshot.plan,
      configuration: started.snapshot.configuration,
      parkedThoughts: started.snapshot.parkedThoughts,
      startedAt: started.snapshot.startedAt,
      accumulatedFocusSeconds: started.snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: started.snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: started.snapshot.lastWallObservationAt,
      nextScheduledCheckIn: started.snapshot.nextScheduledCheckIn,
      lastConsumedBoundaryToken: started.snapshot.lastConsumedBoundaryToken
    )
    #expect(
      SessionReducer.reduce(
        snapshot: constrained,
        command: SessionCommand(expectedRevision: 2, intent: .stop(.completed)),
        context: driftContext
      )
        == .failed(
          snapshot: constrained,
          reason: .eventSequenceExhausted(
            requiredAdditionalEvents: 3,
            remainingCapacity: 2
          )))

    let unadjustedConstrained = SessionSnapshot(
      schemaVersion: started.snapshot.schemaVersion,
      sessionID: started.snapshot.sessionID,
      revision: started.snapshot.revision,
      eventSequence: UInt64.max - 1,
      nextBoundaryOccurrence: started.snapshot.nextBoundaryOccurrence,
      state: started.snapshot.state,
      plan: started.snapshot.plan,
      configuration: started.snapshot.configuration,
      parkedThoughts: started.snapshot.parkedThoughts,
      startedAt: started.snapshot.startedAt,
      accumulatedFocusSeconds: started.snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: started.snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: started.snapshot.lastWallObservationAt,
      nextScheduledCheckIn: started.snapshot.nextScheduledCheckIn,
      lastConsumedBoundaryToken: started.snapshot.lastConsumedBoundaryToken
    )
    #expect(
      SessionReducer.reduce(
        snapshot: unadjustedConstrained,
        command: SessionCommand(expectedRevision: 2, intent: .stop(.completed)),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: 200),
            liveProjection: LiveProjectionObservation(
              projectionToken: projectionToken,
              rawWallAtProjectionAnchor: Date(timeIntervalSinceReferenceDate: 100),
              monotonicElapsedSinceAnchor: .seconds(100)
            )),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: UUID()
        )
      )
        == .failed(
          snapshot: unadjustedConstrained,
          reason: .eventSequenceExhausted(
            requiredAdditionalEvents: 2,
            remainingCapacity: 1
          )))

    let recovery = SessionReducer.reduce(
      snapshot: started.snapshot,
      command: SessionCommand(expectedRevision: 2, intent: .stop(.completed)),
      context: ReductionContext(
        instant: SessionInstant(
          wallNow: Date(timeIntervalSinceReferenceDate: 200), liveProjection: nil),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: UUID()
      )
    )
    guard case let .transition(recoveryReduction) = recovery else {
      Issue.record("expected live stop recovery")
      return
    }
    #expect(recoveryReduction.snapshot.state.kind == .recoveryNeeded)
    #expect(recoveryReduction.events.map(\.payload.kind) == [.clockRecoveryNeeded])
    #expect(!recoveryReduction.effects.contains(.announceAccessibility(.reviewPresented)))
    #expect(
      SessionReducer.reduce(
        snapshot: started.snapshot,
        command: SessionCommand(expectedRevision: 2, intent: .stop(.completed)),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: .nan), liveProjection: nil),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: UUID()
        )
      ) == .failed(snapshot: started.snapshot, reason: .nonFiniteWallObservation)
    )

    let manualConfiguration = SessionConfiguration(
      checkInSchedule: .manualOnly,
      breakSuggestionsEnabled: true,
      lowCognitiveLoadEnabled: false,
      reflectionPromptEnabled: true
    )
    guard
      case let .transition(manualPrepared) = SessionReducer.reduce(
        snapshot: .canonicalIdle,
        command: SessionCommand(
          expectedRevision: 0,
          intent: .prepare(SessionDraft(plan: plan, configuration: manualConfiguration))
        ),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: 10), liveProjection: nil),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: UUID()
        )
      ),
      case let .transition(manualStarted) = SessionReducer.reduce(
        snapshot: manualPrepared.snapshot,
        command: SessionCommand(expectedRevision: 1, intent: .start),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: Date(timeIntervalSinceReferenceDate: 100), liveProjection: nil),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: projectionToken
        )
      ), case let .focusing(manualFocus) = manualStarted.snapshot.state,
      let phaseToken = manualFocus.phaseBoundaryToken,
      let phaseEndsAt = manualFocus.phaseEndsAt
    else {
      Issue.record("expected manual-only focus fixture")
      return
    }
    let phaseStop = SessionReducer.reduce(
      snapshot: manualStarted.snapshot,
      command: SessionCommand(expectedRevision: 2, intent: .stop(.completed)),
      context: ReductionContext(
        instant: SessionInstant(
          wallNow: phaseEndsAt.date,
          liveProjection: LiveProjectionObservation(
            projectionToken: projectionToken,
            rawWallAtProjectionAnchor: Date(timeIntervalSinceReferenceDate: 100),
            monotonicElapsedSinceAnchor: .seconds(1_500)
          )),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: UUID()
      )
    )
    guard case let .transition(phaseReduction) = phaseStop,
      case let .reviewing(phaseReview) = phaseReduction.snapshot.state
    else {
      Issue.record("expected phase-winner terminal review")
      return
    }
    #expect(phaseReview.draft.focusedSeconds == 1_500)
    #expect(phaseReduction.snapshot.lastConsumedBoundaryToken == nil)
    #expect(
      phaseReduction.events.map(\.payload.kind) == [
        .sessionStopRequested, .reviewStarted,
      ])
    #expect(
      phaseReduction.effects
        == [
          .cancelNotification(SessionNotificationID(boundaryToken: phaseToken)),
          .announceAccessibility(.reviewPresented),
          .invalidateDisplayProjection(projectionToken: nil),
        ])
    #expect(!phaseReduction.effects.contains(.playSound(.gentleBoundary)))
    #expect(!phaseReduction.effects.contains(.playHaptic(.gentleBoundary)))
    #expect(SessionSnapshotValidator.validateCandidate(phaseReduction.snapshot).isEmpty)
  }

  @Test("live break stop enters review without break completion flow")
  func liveBreakStopIsExact() throws {
    let sessionID = UUID()
    let projectionToken = UUID()
    let pausedAt = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 110))
    let breakStartedAt = SessionTimestamp(
      unchecked: Date(timeIntervalSinceReferenceDate: 300))
    let paused = SessionSnapshot(
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
        task: "Task", firstAction: "Return here", capacity: nil,
        timingPolicy: .classic),
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100)),
      accumulatedFocusSeconds: 10,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: pausedAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )
    let choice = BreakChoice(kind: .move, duration: .timed(.five))
    guard
      case let .transition(started) = SessionReducer.reduce(
        snapshot: paused,
        command: SessionCommand(expectedRevision: 3, intent: .requestBreak(choice)),
        context: ReductionContext(
          instant: SessionInstant(wallNow: breakStartedAt.date, liveProjection: nil),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: projectionToken
        )
      ), case let .breaking(liveBreak) = started.snapshot.state,
      let boundaryToken = liveBreak.boundaryToken,
      let endsAt = liveBreak.endsAt
    else {
      Issue.record("expected live break fixture")
      return
    }
    let cases: [(SessionTimestamp, Duration, SessionStopChoice, UInt64)] = [
      (
        SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 400)),
        .seconds(100),
        .intentionalStop,
        100
      ),
      (endsAt, .seconds(300), .completed, 300),
    ]

    for (observedAt, elapsed, stopChoice, expectedBreak) in cases {
      let outcome = SessionReducer.reduce(
        snapshot: started.snapshot,
        command: SessionCommand(expectedRevision: 4, intent: .stop(stopChoice)),
        context: ReductionContext(
          instant: SessionInstant(
            wallNow: observedAt.date,
            liveProjection: LiveProjectionObservation(
              projectionToken: projectionToken,
              rawWallAtProjectionAnchor: breakStartedAt.date,
              monotonicElapsedSinceAnchor: elapsed
            )),
          generatedSessionID: UUID(),
          generatedThoughtID: UUID(),
          generatedProjectionToken: UUID()
        )
      )
      guard case let .transition(reduction) = outcome,
        case let .reviewing(review) = reduction.snapshot.state
      else {
        Issue.record("expected live break review")
        continue
      }
      let reason: SessionStopReason = stopChoice == .completed ? .completed : .intentionalStop
      #expect(review.draft.focusedSeconds == 10)
      #expect(review.draft.breakSeconds == expectedBreak)
      #expect(review.draft.endedAt == observedAt)
      #expect(reduction.snapshot.accumulatedBreakSeconds == expectedBreak)
      #expect(reduction.snapshot.lastConsumedBoundaryToken == nil)
      #expect(
        reduction.events.map(\.payload) == [
          .sessionStopRequested(reason: reason),
          .reviewStarted(
            SessionReviewEvent(
              focusedSeconds: 10,
              breakSeconds: expectedBreak,
              stopReason: reason,
              parkedThoughtCount: 0,
              hasReflection: false
            )),
        ])
      #expect(
        !reduction.events.contains {
          $0.payload.kind == .breakEnded || $0.payload.kind == .reentryPresented
        })
      #expect(!reduction.effects.contains(.playSound(.breakComplete)))
      #expect(
        reduction.effects
          == [
            .cancelNotification(SessionNotificationID(boundaryToken: boundaryToken)),
            .announceAccessibility(.reviewPresented),
            .invalidateDisplayProjection(projectionToken: nil),
          ])
      #expect(SessionSnapshotValidator.validateCandidate(reduction.snapshot).isEmpty)
    }

    let recovery = SessionReducer.reduce(
      snapshot: started.snapshot,
      command: SessionCommand(expectedRevision: 4, intent: .stop(.completed)),
      context: ReductionContext(
        instant: SessionInstant(
          wallNow: Date(timeIntervalSinceReferenceDate: 400), liveProjection: nil),
        generatedSessionID: UUID(),
        generatedThoughtID: UUID(),
        generatedProjectionToken: UUID()
      )
    )
    guard case let .transition(recoveryReduction) = recovery else {
      Issue.record("expected live break stop recovery")
      return
    }
    #expect(recoveryReduction.snapshot.state.kind == .recoveryNeeded)
    #expect(recoveryReduction.events.map(\.payload.kind) == [.clockRecoveryNeeded])
    #expect(!recoveryReduction.effects.contains(.announceAccessibility(.reviewPresented)))
  }
}
