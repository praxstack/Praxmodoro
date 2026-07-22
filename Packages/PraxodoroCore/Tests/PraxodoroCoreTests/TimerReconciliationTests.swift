import Foundation
import Testing

@testable import PraxodoroCore

@Suite("Timer reconciliation")
struct TimerReconciliationTests {
  @Test("idle projection is static and ignores a live observation")
  func idleProjectionIsStatic() throws {
    let projection = try SessionProjector.project(
      snapshot: .canonicalIdle,
      instant: SessionInstant(
        wallNow: Date(timeIntervalSinceReferenceDate: 100.75),
        liveProjection: LiveProjectionObservation(
          projectionToken: UUID(),
          rawWallAtProjectionAnchor: Date(timeIntervalSinceReferenceDate: .infinity),
          monotonicElapsedSinceAnchor: .seconds(-1)
        )
      )
    )

    #expect(projection.sourceRevision == 0)
    #expect(projection.sessionID == nil)
    #expect(projection.state == .idle)
    #expect(projection.task == nil)
    #expect(projection.firstAction == nil)
    #expect(projection.timingPolicy == nil)
    #expect(projection.phase == nil)
    #expect(projection.focusedSeconds == 0)
    #expect(projection.breakSeconds == 0)
    #expect(projection.remainingSeconds == nil)
    #expect(!projection.isPaused)
    #expect(!projection.isBoundaryAwaitingDecision)
    #expect(projection.nextScheduledCheckInAt == nil)
    #expect(projection.parkedThoughtCount == 0)
    #expect(!projection.lowCognitiveLoadEnabled)
  }

  @Test("live focus projection uses paired elapsed time without writing state")
  func liveFocusProjectionUsesPairedElapsedTime() throws {
    let sessionID = UUID()
    let anchor = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100))
    let phaseToken = BoundaryToken(
      sessionID: sessionID, kind: .phase, phaseID: .focus, sourceRevision: 2, occurrence: 0
    )
    let scheduledToken = BoundaryToken(
      sessionID: sessionID, kind: .scheduledCheckIn, phaseID: nil, sourceRevision: 2, occurrence: 1
    )
    let snapshot = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 2,
      eventSequence: 2,
      nextBoundaryOccurrence: 2,
      state: .focusing(
        FocusState(
          phase: TimingPolicy.classic.phases[0],
          timingAtAnchor: .timed(remaining: try PhaseSeconds(300)),
          wallAnchor: anchor,
          phaseEndsAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 400)),
          elapsedBeforeAnchorSeconds: 0,
          projectionToken: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
          phaseBoundaryToken: phaseToken
        )),
      plan: try SessionPlan(
        task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic),
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: anchor,
      accumulatedFocusSeconds: 12,
      accumulatedBreakSeconds: 3,
      lastWallObservationAt: anchor,
      nextScheduledCheckIn: ScheduledCheckInBoundary(
        token: scheduledToken,
        dueAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 1_000)),
        trustedRemaining: try CheckInRemainingSeconds(900)
      ),
      lastConsumedBoundaryToken: nil
    )
    let projection = try SessionProjector.project(
      snapshot: snapshot,
      instant: SessionInstant(
        wallNow: Date(timeIntervalSinceReferenceDate: 110),
        liveProjection: LiveProjectionObservation(
          projectionToken: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
          rawWallAtProjectionAnchor: anchor.date,
          monotonicElapsedSinceAnchor: .seconds(10)
        )
      )
    )

    #expect(projection.sourceRevision == snapshot.revision)
    #expect(projection.state == .focusing)
    #expect(projection.focusedSeconds == 22)
    #expect(projection.breakSeconds == 3)
    #expect(projection.remainingSeconds == 290)
    #expect(projection.nextScheduledCheckInAt == snapshot.nextScheduledCheckIn?.dueAt)
  }

  @Test("focus entry materializes exact deadlines and ordered tokens")
  func focusEntryMaterializesExactDeadlinesAndOrderedTokens() {
    let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let projectionToken = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let decision = SessionTimeKernel.materializeLiveEntry(
      .focus(
        sessionID: sessionID,
        targetRevision: 2,
        nextBoundaryOccurrence: 0,
        wallNow: Date(timeIntervalSinceReferenceDate: 100),
        projectionToken: projectionToken,
        phaseID: .focus,
        timing: .timed(remaining: try! PhaseSeconds(300)),
        cadence: .fullInterval(.fifteen)
      )
    )

    let expectedPhaseToken = BoundaryToken(
      sessionID: sessionID, kind: .phase, phaseID: .focus, sourceRevision: 2, occurrence: 0
    )
    let expectedScheduledToken = BoundaryToken(
      sessionID: sessionID, kind: .scheduledCheckIn, phaseID: nil, sourceRevision: 2, occurrence: 1
    )
    #expect(
      decision
        == .materialized(
          .focus(
            FocusEntryMaterialization(
              wallAnchor: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100)),
              timingAtAnchor: .timed(remaining: try! PhaseSeconds(300)),
              projectionToken: projectionToken,
              phaseEndsAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 400)),
              phaseBoundaryToken: expectedPhaseToken,
              scheduledCheckIn: ScheduledCheckInBoundary(
                token: expectedScheduledToken,
                dueAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 1_000)),
                trustedRemaining: try! CheckInRemainingSeconds(900)
              ),
              nextBoundaryOccurrence: 2
            )
          )
        )
    )
  }
}
