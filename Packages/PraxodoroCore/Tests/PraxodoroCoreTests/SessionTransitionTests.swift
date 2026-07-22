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
}
