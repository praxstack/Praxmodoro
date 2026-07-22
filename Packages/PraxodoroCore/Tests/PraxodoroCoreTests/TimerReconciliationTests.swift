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

  @Test("open-ended break entry has no deadline or boundary token")
  func openEndedBreakEntryHasNoBoundary() {
    let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    let projectionToken = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
    let decision = SessionTimeKernel.materializeLiveEntry(
      .breakState(
        sessionID: sessionID,
        targetRevision: 4,
        nextBoundaryOccurrence: 7,
        wallNow: Date(timeIntervalSinceReferenceDate: 250),
        projectionToken: projectionToken,
        timing: .choice(.openEnded)
      )
    )

    #expect(
      decision
        == .materialized(
          .breakState(
            BreakEntryMaterialization(
              wallAnchor: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 250)),
              timingAtAnchor: .openEnded,
              projectionToken: projectionToken,
              endsAt: nil,
              boundaryToken: nil,
              nextBoundaryOccurrence: 7
            )
          )
        )
    )
  }

  @Test("live reconciliation retains expected timing within two seconds of drift")
  func liveReconciliationRetainsExpectedTimingWithinTolerance() throws {
    let sessionID = UUID()
    let anchor = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100))
    let projectionToken = UUID()
    let snapshot = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 2,
      eventSequence: 2,
      nextBoundaryOccurrence: 1,
      state: .focusing(
        FocusState(
          phase: TimingPolicy.classic.phases[0],
          timingAtAnchor: .timed(remaining: try PhaseSeconds(300)),
          wallAnchor: anchor,
          phaseEndsAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 400)),
          elapsedBeforeAnchorSeconds: 0,
          projectionToken: projectionToken,
          phaseBoundaryToken: BoundaryToken(
            sessionID: sessionID, kind: .phase, phaseID: .focus, sourceRevision: 2, occurrence: 0
          )
        )),
      plan: try SessionPlan(
        task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic),
      configuration: SessionConfiguration(
        checkInSchedule: .manualOnly,
        breakSuggestionsEnabled: true,
        lowCognitiveLoadEnabled: false,
        reflectionPromptEnabled: true
      ),
      parkedThoughts: [],
      startedAt: anchor,
      accumulatedFocusSeconds: 0,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: anchor,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )

    let decision = SessionTimeKernel.reconcileLive(
      snapshot: snapshot,
      instant: SessionInstant(
        wallNow: Date(timeIntervalSinceReferenceDate: 111),
        liveProjection: LiveProjectionObservation(
          projectionToken: projectionToken,
          rawWallAtProjectionAnchor: anchor.date,
          monotonicElapsedSinceAnchor: .seconds(10)
        )
      )
    )

    #expect(
      decision
        == .normalized(
          NormalizedLiveTiming(
            observedWallNow: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 111)),
            expectedWallNow: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 110)),
            normalizedDueInstant: SessionTimestamp(
              unchecked: Date(timeIntervalSinceReferenceDate: 110)),
            phaseOrBreakDeadline: SessionTimestamp(
              unchecked: Date(timeIntervalSinceReferenceDate: 400)),
            scheduledCheckInAt: nil,
            admissionAdjustment: nil,
            nonBoundaryExitMaterialization: .focus(
              accumulatedFocusSeconds: 10,
              suspendedTiming: .timed(remaining: try PhaseSeconds(290)),
              scheduledCheckInRemaining: nil
            ),
            liveCommitMaterialization: LiveCommitMaterialization(
              wallAnchor: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 111)),
              elapsedBeforeAnchorSeconds: 10,
              timingAtAnchor: .timed(remaining: try PhaseSeconds(290)),
              phaseOrBreakDeadline: SessionTimestamp(
                unchecked: Date(timeIntervalSinceReferenceDate: 401)),
              scheduledCheckInAt: nil,
              scheduledCheckInRemaining: nil,
              adjustment: ClockAdjustmentEvent(
                previousPhaseOrBreakDeadline: SessionTimestamp(
                  unchecked: Date(timeIntervalSinceReferenceDate: 400)),
                newPhaseOrBreakDeadline: SessionTimestamp(
                  unchecked: Date(timeIntervalSinceReferenceDate: 401)),
                previousScheduledCheckInAt: nil,
                newScheduledCheckInAt: nil,
                drift: .seconds(1)
              )
            )
          )
        )
    )
  }

  @Test("phase admission materializes at its deadline instead of a later observation")
  func phaseAdmissionMaterializesAtDeadline() throws {
    let sessionID = UUID()
    let phaseToken = BoundaryToken(
      sessionID: sessionID, kind: .phase, phaseID: .focus, sourceRevision: 2, occurrence: 0
    )
    let anchor = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100))
    let snapshot = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 2,
      eventSequence: 2,
      nextBoundaryOccurrence: 1,
      state: .focusing(
        FocusState(
          phase: TimingPolicy.classic.phases[0],
          timingAtAnchor: .timed(remaining: try PhaseSeconds(300)),
          wallAnchor: anchor,
          phaseEndsAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 400)),
          elapsedBeforeAnchorSeconds: 5,
          projectionToken: UUID(),
          phaseBoundaryToken: phaseToken
        )),
      plan: try SessionPlan(
        task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic),
      configuration: SessionConfiguration(
        checkInSchedule: .manualOnly,
        breakSuggestionsEnabled: true,
        lowCognitiveLoadEnabled: false,
        reflectionPromptEnabled: true
      ),
      parkedThoughts: [],
      startedAt: anchor,
      accumulatedFocusSeconds: 11,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: anchor,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )
    let deadline = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 400))
    let decision = SessionTimeKernel.admitBoundary(
      snapshot: snapshot,
      timing: NormalizedLiveTiming(
        observedWallNow: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 700)),
        expectedWallNow: deadline,
        normalizedDueInstant: SessionTimestamp(
          unchecked: Date(timeIntervalSinceReferenceDate: 700)),
        phaseOrBreakDeadline: deadline,
        scheduledCheckInAt: nil,
        admissionAdjustment: nil
      ),
      observedToken: phaseToken
    )

    #expect(
      decision
        == .winner(
          BoundaryWinnerDecision(
            token: phaseToken,
            dueAt: deadline,
            exitMaterialization: .phase(accumulatedFocusSeconds: 316),
            scheduledCadence: .manualOnly
          )
        )
    )
  }

  @Test("equal phase and scheduled boundaries select phase and reset cadence")
  func equalFocusBoundariesSelectPhase() throws {
    let sessionID = UUID()
    let anchor = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100))
    let due = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 400))
    let phaseToken = BoundaryToken(
      sessionID: sessionID, kind: .phase, phaseID: .focus, sourceRevision: 2, occurrence: 0)
    let scheduledToken = BoundaryToken(
      sessionID: sessionID, kind: .scheduledCheckIn, phaseID: nil, sourceRevision: 2, occurrence: 1)
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
          phaseEndsAt: due,
          elapsedBeforeAnchorSeconds: 0,
          projectionToken: UUID(),
          phaseBoundaryToken: phaseToken
        )),
      plan: try SessionPlan(
        task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic),
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: anchor,
      accumulatedFocusSeconds: 4,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: anchor,
      nextScheduledCheckIn: ScheduledCheckInBoundary(
        token: scheduledToken, dueAt: due, trustedRemaining: try CheckInRemainingSeconds(300)),
      lastConsumedBoundaryToken: nil
    )

    let decision = SessionTimeKernel.admitBoundary(
      snapshot: snapshot,
      timing: NormalizedLiveTiming(
        observedWallNow: due,
        expectedWallNow: due,
        normalizedDueInstant: due,
        phaseOrBreakDeadline: due,
        scheduledCheckInAt: due,
        admissionAdjustment: nil
      ),
      observedToken: phaseToken
    )

    #expect(
      decision
        == .winner(
          BoundaryWinnerDecision(
            token: phaseToken,
            dueAt: due,
            exitMaterialization: .phase(accumulatedFocusSeconds: 304),
            scheduledCadence: .resetAfterPhaseCollision
          )
        )
    )
  }

  @Test("scheduled check-in wins before a later phase deadline")
  func scheduledCheckInWinsBeforeLaterPhaseDeadline() throws {
    let sessionID = UUID()
    let phaseToken = BoundaryToken(
      sessionID: sessionID, kind: .phase, phaseID: .focus, sourceRevision: 2, occurrence: 0
    )
    let scheduledToken = BoundaryToken(
      sessionID: sessionID, kind: .scheduledCheckIn, phaseID: nil, sourceRevision: 2, occurrence: 1
    )
    let anchor = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100))
    let snapshot = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 2,
      eventSequence: 2,
      nextBoundaryOccurrence: 2,
      state: .focusing(
        FocusState(
          phase: TimingPolicy.classic.phases[0],
          timingAtAnchor: .timed(remaining: try PhaseSeconds(400)),
          wallAnchor: anchor,
          phaseEndsAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 500)),
          elapsedBeforeAnchorSeconds: 0,
          projectionToken: UUID(),
          phaseBoundaryToken: phaseToken
        )),
      plan: try SessionPlan(
        task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic),
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: anchor,
      accumulatedFocusSeconds: 8,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: anchor,
      nextScheduledCheckIn: ScheduledCheckInBoundary(
        token: scheduledToken,
        dueAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 300)),
        trustedRemaining: try CheckInRemainingSeconds(200)
      ),
      lastConsumedBoundaryToken: nil
    )
    let decision = SessionTimeKernel.admitBoundary(
      snapshot: snapshot,
      timing: NormalizedLiveTiming(
        observedWallNow: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 600)),
        expectedWallNow: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 600)),
        normalizedDueInstant: SessionTimestamp(
          unchecked: Date(timeIntervalSinceReferenceDate: 600)),
        phaseOrBreakDeadline: SessionTimestamp(
          unchecked: Date(timeIntervalSinceReferenceDate: 500)),
        scheduledCheckInAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 300)),
        admissionAdjustment: nil
      ),
      observedToken: scheduledToken
    )

    #expect(
      decision
        == .winner(
          BoundaryWinnerDecision(
            token: scheduledToken,
            dueAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 300)),
            exitMaterialization: .scheduledCheckIn(
              accumulatedFocusSeconds: 208,
              suspendedTiming: .timed(remaining: try PhaseSeconds(200))
            ),
            scheduledCadence: .resetAfterScheduledOccurrence
          )
        )
    )
  }

  @Test("break end admission materializes only break time at its deadline")
  func breakEndAdmissionMaterializesBreakTime() throws {
    let sessionID = UUID()
    let anchor = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100))
    let token = BoundaryToken(
      sessionID: sessionID, kind: .breakEnd, phaseID: nil, sourceRevision: 3, occurrence: 0
    )
    let resumeTarget = SuspendedFocusState(
      phase: TimingPolicy.classic.phases[0],
      timing: .timed(remaining: try PhaseSeconds(300)),
      resumeDisposition: .focusing,
      scheduledCheckInRemaining: nil
    )
    let snapshot = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 3,
      eventSequence: 3,
      nextBoundaryOccurrence: 1,
      state: .breaking(
        BreakState(
          choice: BreakChoice(kind: .quiet, duration: .timed(.five)),
          timingAtAnchor: .timed(remaining: try PhaseSeconds(300)),
          wallAnchor: anchor,
          endsAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 400)),
          elapsedBeforeAnchorSeconds: 0,
          projectionToken: UUID(),
          boundaryToken: token,
          resumeTarget: resumeTarget,
          proposedAction: "Return"
        )),
      plan: try SessionPlan(
        task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic),
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: anchor,
      accumulatedFocusSeconds: 12,
      accumulatedBreakSeconds: 9,
      lastWallObservationAt: anchor,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )
    let deadline = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 400))
    let decision = SessionTimeKernel.admitBoundary(
      snapshot: snapshot,
      timing: NormalizedLiveTiming(
        observedWallNow: deadline,
        expectedWallNow: deadline,
        normalizedDueInstant: deadline,
        phaseOrBreakDeadline: deadline,
        scheduledCheckInAt: nil,
        admissionAdjustment: nil
      ),
      observedToken: token
    )

    #expect(
      decision
        == .winner(
          BoundaryWinnerDecision(
            token: token,
            dueAt: deadline,
            exitMaterialization: .breakEnd(accumulatedBreakSeconds: 309),
            scheduledCadence: .notApplicable
          )
        )
    )
  }

  @Test("scheduled replacement allocates only a new scheduled token")
  func scheduledReplacementAllocatesOnlyScheduledToken() {
    let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
    let anchor = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100))
    let decision = SessionTimeKernel.replaceScheduledCheckIn(
      ScheduledCheckInReplacementRequest(
        sessionID: sessionID,
        targetRevision: 4,
        nextBoundaryOccurrence: 9,
        wallAnchor: anchor,
        schedule: .interval(try! CheckInMinutes(5))
      )
    )

    #expect(
      decision
        == .materialized(
          boundary: ScheduledCheckInBoundary(
            token: BoundaryToken(
              sessionID: sessionID,
              kind: .scheduledCheckIn,
              phaseID: nil,
              sourceRevision: 4,
              occurrence: 9
            ),
            dueAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 400)),
            trustedRemaining: try! CheckInRemainingSeconds(300)
          ),
          nextBoundaryOccurrence: 10
        )
    )
  }
}
