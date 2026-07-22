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

  @Test("non-live relaunch ignores an unusable wall observation")
  func nonLiveRelaunchIgnoresUnusableWallObservation() {
    let unchanged = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 0))
    #expect(
      SessionTimeKernel.reconcileRelaunch(
        snapshot: .canonicalIdle,
        wallNow: Date(timeIntervalSinceReferenceDate: .infinity)
      )
        == .normalized(
          NormalizedLiveTiming(
            observedWallNow: unchanged,
            expectedWallNow: unchanged,
            normalizedDueInstant: unchanged,
            phaseOrBreakDeadline: nil,
            scheduledCheckInAt: nil,
            admissionAdjustment: nil
          )
        )
    )
  }

  @Test("live focus projection uses fractional paired elapsed time without writing state")
  func liveFocusProjectionUsesFractionalPairedElapsedTime() throws {
    let sessionID = UUID()
    let anchor = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100))
    let focusProjectionToken = UUID(
      uuidString: "00000000-0000-0000-0000-000000000010")!
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
          projectionToken: focusProjectionToken,
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
        wallNow: Date(timeIntervalSinceReferenceDate: 101),
        liveProjection: LiveProjectionObservation(
          projectionToken: focusProjectionToken,
          rawWallAtProjectionAnchor: Date(timeIntervalSinceReferenceDate: 100.75),
          monotonicElapsedSinceAnchor: .milliseconds(250)
        )
      )
    )

    #expect(projection.sourceRevision == snapshot.revision)
    #expect(projection.state == .focusing)
    #expect(projection.focusedSeconds == 13)
    #expect(projection.breakSeconds == 3)
    #expect(projection.remainingSeconds == 299)
    #expect(projection.nextScheduledCheckInAt == snapshot.nextScheduledCheckIn?.dueAt)

    #expect(throws: ProjectionError.missingLiveProjection) {
      try SessionProjector.project(
        snapshot: snapshot,
        instant: SessionInstant(
          wallNow: Date(timeIntervalSinceReferenceDate: 101), liveProjection: nil))
    }

    let staleToken = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
    #expect(
      throws: ProjectionError.staleProjectionToken(
        expected: focusProjectionToken, actual: staleToken)
    ) {
      try SessionProjector.project(
        snapshot: snapshot,
        instant: SessionInstant(
          wallNow: Date(timeIntervalSinceReferenceDate: 101),
          liveProjection: LiveProjectionObservation(
            projectionToken: staleToken,
            rawWallAtProjectionAnchor: Date(timeIntervalSinceReferenceDate: 100),
            monotonicElapsedSinceAnchor: .seconds(1)
          )))
    }

    let inconsistentAnchor = SessionTimestamp(
      unchecked: Date(timeIntervalSinceReferenceDate: 101))
    #expect(
      throws: ProjectionError.inconsistentProjectionAnchor(
        expectedCanonical: anchor, actualCanonical: inconsistentAnchor)
    ) {
      try SessionProjector.project(
        snapshot: snapshot,
        instant: SessionInstant(
          wallNow: Date(timeIntervalSinceReferenceDate: 101),
          liveProjection: LiveProjectionObservation(
            projectionToken: focusProjectionToken,
            rawWallAtProjectionAnchor: inconsistentAnchor.date,
            monotonicElapsedSinceAnchor: .zero
          )))
    }

    #expect(throws: ProjectionError.negativeMonotonicElapsed) {
      try SessionProjector.project(
        snapshot: snapshot,
        instant: SessionInstant(
          wallNow: Date(timeIntervalSinceReferenceDate: 101),
          liveProjection: LiveProjectionObservation(
            projectionToken: focusProjectionToken,
            rawWallAtProjectionAnchor: anchor.date,
            monotonicElapsedSinceAnchor: .seconds(-1)
          )))
    }

    #expect(throws: ProjectionError.arithmeticOverflow) {
      try SessionProjector.project(
        snapshot: snapshot,
        instant: SessionInstant(
          wallNow: Date(timeIntervalSinceReferenceDate: .infinity), liveProjection: nil))
    }

    #expect(throws: ProjectionError.arithmeticOverflow) {
      try SessionProjector.project(
        snapshot: snapshot,
        instant: SessionInstant(
          wallNow: Date(timeIntervalSinceReferenceDate: 101),
          liveProjection: LiveProjectionObservation(
            projectionToken: focusProjectionToken,
            rawWallAtProjectionAnchor: Date(timeIntervalSinceReferenceDate: .infinity),
            monotonicElapsedSinceAnchor: .zero
          )))
    }
  }

  @Test("open-ended break projection advances only break time")
  func openEndedBreakProjectionAdvancesOnlyBreakTime() throws {
    let sessionID = UUID()
    let anchor = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 500))
    let projectionToken = UUID()
    let resumeTarget = SuspendedFocusState(
      phase: TimingPolicy.classic.phases[0],
      timing: .timed(remaining: try PhaseSeconds(240)),
      resumeDisposition: .focusing,
      scheduledCheckInRemaining: try CheckInRemainingSeconds(600)
    )
    let snapshot = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 7,
      eventSequence: 7,
      nextBoundaryOccurrence: 4,
      state: .breaking(
        BreakState(
          choice: BreakChoice(kind: .quiet, duration: .openEnded),
          timingAtAnchor: .openEnded,
          wallAnchor: anchor,
          endsAt: nil,
          elapsedBeforeAnchorSeconds: 5,
          projectionToken: projectionToken,
          boundaryToken: nil,
          resumeTarget: resumeTarget,
          proposedAction: "Return"
        )),
      plan: try SessionPlan(
        task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic),
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100)),
      accumulatedFocusSeconds: 120,
      accumulatedBreakSeconds: 9,
      lastWallObservationAt: anchor,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )

    let projection = try SessionProjector.project(
      snapshot: snapshot,
      instant: SessionInstant(
        wallNow: Date(timeIntervalSinceReferenceDate: 503),
        liveProjection: LiveProjectionObservation(
          projectionToken: projectionToken,
          rawWallAtProjectionAnchor: anchor.date,
          monotonicElapsedSinceAnchor: .seconds(3)
        )
      ))

    #expect(projection.sourceRevision == snapshot.revision)
    #expect(projection.state == .breaking)
    #expect(projection.phase == .focus)
    #expect(projection.focusedSeconds == 120)
    #expect(projection.breakSeconds == 17)
    #expect(projection.remainingSeconds == nil)
    #expect(projection.nextScheduledCheckInAt == nil)
  }

  @Test("live break reconciliation materializes only break progress")
  func liveBreakReconciliationMaterializesOnlyBreakProgress() throws {
    let sessionID = UUID()
    let anchor = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100))
    let deadline = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 400))
    let projectionToken = UUID()
    let boundaryToken = BoundaryToken(
      sessionID: sessionID,
      kind: .breakEnd,
      phaseID: nil,
      sourceRevision: 3,
      occurrence: 0
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
          endsAt: deadline,
          elapsedBeforeAnchorSeconds: 5,
          projectionToken: projectionToken,
          boundaryToken: boundaryToken,
          resumeTarget: SuspendedFocusState(
            phase: TimingPolicy.classic.phases[0],
            timing: .timed(remaining: try PhaseSeconds(240)),
            resumeDisposition: .focusing,
            scheduledCheckInRemaining: try CheckInRemainingSeconds(600)
          ),
          proposedAction: "Return"
        )),
      plan: try SessionPlan(
        task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .classic),
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: anchor,
      accumulatedFocusSeconds: 120,
      accumulatedBreakSeconds: 9,
      lastWallObservationAt: anchor,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )

    #expect(
      SessionTimeKernel.reconcileLive(
        snapshot: snapshot,
        instant: SessionInstant(
          wallNow: Date(timeIntervalSinceReferenceDate: 111),
          liveProjection: LiveProjectionObservation(
            projectionToken: projectionToken,
            rawWallAtProjectionAnchor: anchor.date,
            monotonicElapsedSinceAnchor: .seconds(10)
          )
        ))
        == .normalized(
          NormalizedLiveTiming(
            observedWallNow: SessionTimestamp(
              unchecked: Date(timeIntervalSinceReferenceDate: 111)),
            expectedWallNow: SessionTimestamp(
              unchecked: Date(timeIntervalSinceReferenceDate: 110)),
            normalizedDueInstant: SessionTimestamp(
              unchecked: Date(timeIntervalSinceReferenceDate: 110)),
            phaseOrBreakDeadline: deadline,
            scheduledCheckInAt: nil,
            admissionAdjustment: nil,
            nonBoundaryExitMaterialization: .breakState(
              accumulatedBreakSeconds: 24),
            liveCommitMaterialization: LiveCommitMaterialization(
              wallAnchor: SessionTimestamp(
                unchecked: Date(timeIntervalSinceReferenceDate: 111)),
              elapsedBeforeAnchorSeconds: 15,
              timingAtAnchor: .timed(remaining: try PhaseSeconds(290)),
              phaseOrBreakDeadline: SessionTimestamp(
                unchecked: Date(timeIntervalSinceReferenceDate: 401)),
              scheduledCheckInAt: nil,
              scheduledCheckInRemaining: nil,
              adjustment: ClockAdjustmentEvent(
                previousPhaseOrBreakDeadline: deadline,
                newPhaseOrBreakDeadline: SessionTimestamp(
                  unchecked: Date(timeIntervalSinceReferenceDate: 401)),
                previousScheduledCheckInAt: nil,
                newScheduledCheckInAt: nil,
                drift: .seconds(1)
              )
            )
          ))
    )
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

  @Test("open-ended focus installs only its captured scheduled boundary")
  func openEndedFocusEntryInstallsOnlyScheduledBoundary() throws {
    let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000006")!
    let projectionToken = UUID(uuidString: "00000000-0000-0000-0000-000000000007")!
    let cadence = try CheckInRemainingSeconds(300)
    let decision = SessionTimeKernel.materializeLiveEntry(
      .focus(
        sessionID: sessionID,
        targetRevision: 5,
        nextBoundaryOccurrence: 7,
        wallNow: Date(timeIntervalSinceReferenceDate: 100),
        projectionToken: projectionToken,
        phaseID: .focus,
        timing: .openEnded,
        cadence: .captured(cadence)
      )
    )

    #expect(
      decision
        == .materialized(
          .focus(
            FocusEntryMaterialization(
              wallAnchor: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100)),
              timingAtAnchor: .openEnded,
              projectionToken: projectionToken,
              phaseEndsAt: nil,
              phaseBoundaryToken: nil,
              scheduledCheckIn: ScheduledCheckInBoundary(
                token: BoundaryToken(
                  sessionID: sessionID,
                  kind: .scheduledCheckIn,
                  phaseID: nil,
                  sourceRevision: 5,
                  occurrence: 7
                ),
                dueAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 400)),
                trustedRemaining: cadence
              ),
              nextBoundaryOccurrence: 8
            )
          )
        )
    )
  }

  @Test("live entry rejects exhausted boundary occurrences before construction")
  func liveEntryRejectsExhaustedBoundaryOccurrences() throws {
    #expect(
      SessionTimeKernel.materializeLiveEntry(
        .focus(
          sessionID: UUID(),
          targetRevision: 1,
          nextBoundaryOccurrence: .max,
          wallNow: Date(timeIntervalSinceReferenceDate: 100),
          projectionToken: UUID(),
          phaseID: .focus,
          timing: .timed(remaining: try PhaseSeconds(1)),
          cadence: .manualOnly
        )
      ) == .failure(.boundaryOccurrenceExhausted)
    )

    #expect(
      SessionTimeKernel.materializeLiveEntry(
        .focus(
          sessionID: UUID(),
          targetRevision: 1,
          nextBoundaryOccurrence: .max - 1,
          wallNow: Date(timeIntervalSinceReferenceDate: 100),
          projectionToken: UUID(),
          phaseID: .focus,
          timing: .timed(remaining: try PhaseSeconds(1)),
          cadence: .fullInterval(try CheckInMinutes(5))
        )
      ) == .failure(.boundaryOccurrenceExhausted)
    )
  }

  @Test("live entry rejects non-finite wall input before token allocation")
  func liveEntryRejectsNonFiniteWallInput() throws {
    #expect(
      SessionTimeKernel.materializeLiveEntry(
        .focus(
          sessionID: UUID(),
          targetRevision: 1,
          nextBoundaryOccurrence: 0,
          wallNow: Date(timeIntervalSinceReferenceDate: .infinity),
          projectionToken: UUID(),
          phaseID: .focus,
          timing: .timed(remaining: try PhaseSeconds(1)),
          cadence: .fullInterval(.fifteen)
        )
      ) == .failure(.nonFiniteWallObservation)
    )
  }

  @Test("live entry rejects finite clocks that cannot represent an exact deadline")
  func liveEntryRejectsUnrepresentableFiniteDeadline() throws {
    #expect(
      SessionTimeKernel.materializeLiveEntry(
        .focus(
          sessionID: UUID(),
          targetRevision: 1,
          nextBoundaryOccurrence: 0,
          wallNow: Date(timeIntervalSinceReferenceDate: .greatestFiniteMagnitude),
          projectionToken: UUID(),
          phaseID: .focus,
          timing: .timed(remaining: try PhaseSeconds(300)),
          cadence: .manualOnly
        )
      ) == .failure(.arithmeticOverflow)
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

  @Test("saved timed break entry retains its exact remainder and break token")
  func savedTimedBreakEntryRetainsRemainder() throws {
    let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000008")!
    let projectionToken = UUID(uuidString: "00000000-0000-0000-0000-000000000009")!
    let remaining = try PhaseSeconds(120)
    let decision = SessionTimeKernel.materializeLiveEntry(
      .breakState(
        sessionID: sessionID,
        targetRevision: 6,
        nextBoundaryOccurrence: 4,
        wallNow: Date(timeIntervalSinceReferenceDate: 200),
        projectionToken: projectionToken,
        timing: .saved(.timed(remaining: remaining))
      )
    )
    #expect(
      decision
        == .materialized(
          .breakState(
            BreakEntryMaterialization(
              wallAnchor: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 200)),
              timingAtAnchor: .timed(remaining: remaining),
              projectionToken: projectionToken,
              endsAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 320)),
              boundaryToken: BoundaryToken(
                sessionID: sessionID,
                kind: .breakEnd,
                phaseID: nil,
                sourceRevision: 6,
                occurrence: 4
              ),
              nextBoundaryOccurrence: 5
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
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: anchor,
      accumulatedFocusSeconds: 0,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: anchor,
      nextScheduledCheckIn: ScheduledCheckInBoundary(
        token: BoundaryToken(
          sessionID: sessionID,
          kind: .scheduledCheckIn,
          phaseID: nil,
          sourceRevision: 2,
          occurrence: 1
        ),
        dueAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 1_000)),
        trustedRemaining: try CheckInRemainingSeconds(900)
      ),
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
            scheduledCheckInAt: SessionTimestamp(
              unchecked: Date(timeIntervalSinceReferenceDate: 1_000)),
            admissionAdjustment: nil,
            nonBoundaryExitMaterialization: .focus(
              accumulatedFocusSeconds: 10,
              suspendedTiming: .timed(remaining: try PhaseSeconds(290)),
              scheduledCheckInRemaining: try CheckInRemainingSeconds(890)
            ),
            liveCommitMaterialization: LiveCommitMaterialization(
              wallAnchor: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 111)),
              elapsedBeforeAnchorSeconds: 10,
              timingAtAnchor: .timed(remaining: try PhaseSeconds(290)),
              phaseOrBreakDeadline: SessionTimestamp(
                unchecked: Date(timeIntervalSinceReferenceDate: 401)),
              scheduledCheckInAt: SessionTimestamp(
                unchecked: Date(timeIntervalSinceReferenceDate: 1_001)),
              scheduledCheckInRemaining: try CheckInRemainingSeconds(890),
              adjustment: ClockAdjustmentEvent(
                previousPhaseOrBreakDeadline: SessionTimestamp(
                  unchecked: Date(timeIntervalSinceReferenceDate: 400)),
                newPhaseOrBreakDeadline: SessionTimestamp(
                  unchecked: Date(timeIntervalSinceReferenceDate: 401)),
                previousScheduledCheckInAt: SessionTimestamp(
                  unchecked: Date(timeIntervalSinceReferenceDate: 1_000)),
                newScheduledCheckInAt: SessionTimestamp(
                  unchecked: Date(timeIntervalSinceReferenceDate: 1_001)),
                drift: .seconds(1)
              )
            )
          )
        )
    )

    let exactToleranceDecision = SessionTimeKernel.reconcileLive(
      snapshot: snapshot,
      instant: SessionInstant(
        wallNow: Date(timeIntervalSinceReferenceDate: 112),
        liveProjection: LiveProjectionObservation(
          projectionToken: projectionToken,
          rawWallAtProjectionAnchor: anchor.date,
          monotonicElapsedSinceAnchor: .seconds(10)
        )
      )
    )
    guard case let .normalized(toleranceTiming) = exactToleranceDecision else {
      Issue.record("expected a normalized exact-tolerance decision")
      return
    }
    #expect(toleranceTiming.admissionAdjustment == nil)
    #expect(
      toleranceTiming.phaseOrBreakDeadline
        == SessionTimestamp(
          unchecked: Date(timeIntervalSinceReferenceDate: 400)))
    #expect(toleranceTiming.liveCommitMaterialization?.adjustment?.drift == .seconds(2))

    for drift in [-2.0, -1.0, 0.0] {
      let observed = 110 + drift
      let toleranceDecision = SessionTimeKernel.reconcileLive(
        snapshot: snapshot,
        instant: SessionInstant(
          wallNow: Date(timeIntervalSinceReferenceDate: observed),
          liveProjection: LiveProjectionObservation(
            projectionToken: projectionToken,
            rawWallAtProjectionAnchor: anchor.date,
            monotonicElapsedSinceAnchor: .seconds(10)
          )
        ))
      guard case let .normalized(timing) = toleranceDecision else {
        Issue.record("expected normalized timing within drift tolerance")
        continue
      }
      #expect(timing.admissionAdjustment == nil)
      #expect(timing.normalizedDueInstant.date.timeIntervalSinceReferenceDate == 110)
      #expect(
        timing.nonBoundaryExitMaterialization
          == .focus(
            accumulatedFocusSeconds: 10,
            suspendedTiming: .timed(remaining: try PhaseSeconds(290)),
            scheduledCheckInRemaining: try CheckInRemainingSeconds(890)
          ))
      #expect(
        timing.liveCommitMaterialization?.phaseOrBreakDeadline
          == SessionTimestamp(
            unchecked: Date(timeIntervalSinceReferenceDate: 400 + drift)))
      #expect(
        timing.liveCommitMaterialization?.scheduledCheckInAt
          == SessionTimestamp(
            unchecked: Date(timeIntervalSinceReferenceDate: 1_000 + drift)))
      if drift == 0 {
        #expect(timing.liveCommitMaterialization?.adjustment == nil)
      } else {
        #expect(timing.liveCommitMaterialization?.adjustment?.drift == .seconds(drift))
      }
    }

    #expect(
      SessionTimeKernel.reconcileLive(
        snapshot: snapshot,
        instant: SessionInstant(
          wallNow: Date(timeIntervalSinceReferenceDate: 111), liveProjection: nil)
      ) == .recovery(.missingLiveProjection)
    )
    #expect(
      SessionTimeKernel.reconcileLive(
        snapshot: snapshot,
        instant: SessionInstant(
          wallNow: Date(timeIntervalSinceReferenceDate: 111),
          liveProjection: LiveProjectionObservation(
            projectionToken: UUID(), rawWallAtProjectionAnchor: anchor.date,
            monotonicElapsedSinceAnchor: .seconds(10)
          )
        )
      ) == .recovery(.staleLiveProjection)
    )
    #expect(
      SessionTimeKernel.reconcileLive(
        snapshot: snapshot,
        instant: SessionInstant(
          wallNow: Date(timeIntervalSinceReferenceDate: 111),
          liveProjection: LiveProjectionObservation(
            projectionToken: projectionToken,
            rawWallAtProjectionAnchor: Date(timeIntervalSinceReferenceDate: 101),
            monotonicElapsedSinceAnchor: .seconds(10)
          )
        )
      ) == .recovery(.inconsistentLiveProjectionAnchor)
    )
    #expect(
      SessionTimeKernel.reconcileLive(
        snapshot: snapshot,
        instant: SessionInstant(
          wallNow: Date(timeIntervalSinceReferenceDate: 111),
          liveProjection: LiveProjectionObservation(
            projectionToken: projectionToken,
            rawWallAtProjectionAnchor: anchor.date,
            monotonicElapsedSinceAnchor: .seconds(-1)
          )
        )
      ) == .recovery(.negativeMonotonicElapsed)
    )
    #expect(
      SessionTimeKernel.reconcileLive(
        snapshot: snapshot,
        instant: SessionInstant(
          wallNow: Date(timeIntervalSinceReferenceDate: 111),
          liveProjection: LiveProjectionObservation(
            projectionToken: projectionToken,
            rawWallAtProjectionAnchor: Date(timeIntervalSinceReferenceDate: .infinity),
            monotonicElapsedSinceAnchor: .seconds(10)
          )
        )
      ) == .recovery(.arithmeticOverflow)
    )

    for (drift, observed, phaseDeadline, scheduledDeadline) in [
      (3_600.0, 3_710.0, 4_000.0, 4_600.0),
      (-3_600.0, -3_490.0, -3_200.0, -2_600.0),
    ] {
      let rebaseDecision = SessionTimeKernel.reconcileLive(
        snapshot: snapshot,
        instant: SessionInstant(
          wallNow: Date(timeIntervalSinceReferenceDate: observed),
          liveProjection: LiveProjectionObservation(
            projectionToken: projectionToken,
            rawWallAtProjectionAnchor: anchor.date,
            monotonicElapsedSinceAnchor: .seconds(10)
          )
        ))
      guard case let .normalized(rebased) = rebaseDecision else {
        Issue.record("expected a normalized one-hour clock rebase")
        continue
      }
      let expectedPhaseDeadline = SessionTimestamp(
        unchecked: Date(timeIntervalSinceReferenceDate: phaseDeadline))
      let expectedScheduledDeadline = SessionTimestamp(
        unchecked: Date(timeIntervalSinceReferenceDate: scheduledDeadline))
      #expect(rebased.normalizedDueInstant.date.timeIntervalSinceReferenceDate == observed)
      #expect(rebased.phaseOrBreakDeadline == expectedPhaseDeadline)
      #expect(rebased.scheduledCheckInAt == expectedScheduledDeadline)
      #expect(
        rebased.admissionAdjustment
          == ClockAdjustmentEvent(
            previousPhaseOrBreakDeadline: SessionTimestamp(
              unchecked: Date(timeIntervalSinceReferenceDate: 400)),
            newPhaseOrBreakDeadline: expectedPhaseDeadline,
            previousScheduledCheckInAt: SessionTimestamp(
              unchecked: Date(timeIntervalSinceReferenceDate: 1_000)),
            newScheduledCheckInAt: expectedScheduledDeadline,
            drift: .seconds(drift)
          ))
      guard
        case let .focus(accumulatedFocusSeconds, suspendedTiming, _) =
          rebased.nonBoundaryExitMaterialization
      else {
        Issue.record("expected focus materialization after a clock rebase")
        continue
      }
      #expect(accumulatedFocusSeconds == 10)
      #expect(suspendedTiming == .timed(remaining: try PhaseSeconds(290)))
    }

    let dueDecision = SessionTimeKernel.reconcileLive(
      snapshot: snapshot,
      instant: SessionInstant(
        wallNow: Date(timeIntervalSinceReferenceDate: 600),
        liveProjection: LiveProjectionObservation(
          projectionToken: projectionToken,
          rawWallAtProjectionAnchor: anchor.date,
          monotonicElapsedSinceAnchor: .seconds(500)
        )
      )
    )
    guard case let .normalized(dueTiming) = dueDecision else {
      Issue.record("expected due-boundary reconciliation to normalize")
      return
    }
    #expect(dueTiming.nonBoundaryExitMaterialization == nil)
    #expect(dueTiming.liveCommitMaterialization == nil)
  }

  @Test("relaunch carries canonical wall elapsed into a fresh live anchor")
  func relaunchCarriesElapsedIntoFreshAnchor() throws {
    let sessionID = UUID()
    let anchor = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100))
    let deadline = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 400))
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
          phaseEndsAt: deadline,
          elapsedBeforeAnchorSeconds: 0,
          projectionToken: UUID(),
          phaseBoundaryToken: BoundaryToken(
            sessionID: sessionID, kind: .phase, phaseID: .focus, sourceRevision: 2, occurrence: 0)
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
      accumulatedFocusSeconds: 12,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: anchor,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )
    let wallNow = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 110))

    let decision = SessionTimeKernel.reconcileRelaunch(snapshot: snapshot, wallNow: wallNow.date)

    #expect(
      decision
        == .normalized(
          NormalizedLiveTiming(
            observedWallNow: wallNow,
            expectedWallNow: wallNow,
            normalizedDueInstant: wallNow,
            phaseOrBreakDeadline: deadline,
            scheduledCheckInAt: nil,
            admissionAdjustment: nil,
            nonBoundaryExitMaterialization: .focus(
              accumulatedFocusSeconds: 22,
              suspendedTiming: .timed(remaining: try PhaseSeconds(290)),
              scheduledCheckInRemaining: nil
            ),
            liveCommitMaterialization: LiveCommitMaterialization(
              wallAnchor: wallNow,
              elapsedBeforeAnchorSeconds: 10,
              timingAtAnchor: .timed(remaining: try PhaseSeconds(290)),
              phaseOrBreakDeadline: deadline,
              scheduledCheckInAt: nil,
              scheduledCheckInRemaining: nil,
              adjustment: nil
            )
          )
        )
    )

    let exactAnchorDecision = LiveTimeDecision.normalized(
      NormalizedLiveTiming(
        observedWallNow: anchor,
        expectedWallNow: anchor,
        normalizedDueInstant: anchor,
        phaseOrBreakDeadline: deadline,
        scheduledCheckInAt: nil,
        admissionAdjustment: nil,
        nonBoundaryExitMaterialization: .focus(
          accumulatedFocusSeconds: 12,
          suspendedTiming: .timed(remaining: try PhaseSeconds(300)),
          scheduledCheckInRemaining: nil
        ),
        liveCommitMaterialization: LiveCommitMaterialization(
          wallAnchor: anchor,
          elapsedBeforeAnchorSeconds: 0,
          timingAtAnchor: .timed(remaining: try PhaseSeconds(300)),
          phaseOrBreakDeadline: deadline,
          scheduledCheckInAt: nil,
          scheduledCheckInRemaining: nil,
          adjustment: nil
        )
      ))
    #expect(
      SessionTimeKernel.reconcileRelaunch(snapshot: snapshot, wallNow: anchor.date)
        == exactAnchorDecision
    )

    let rollbackSnapshot = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: snapshot.sessionID,
      revision: snapshot.revision,
      eventSequence: snapshot.eventSequence,
      nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
      state: snapshot.state,
      plan: snapshot.plan,
      configuration: snapshot.configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: snapshot.startedAt,
      accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: SessionTimestamp(
        unchecked: Date(timeIntervalSinceReferenceDate: 102)),
      nextScheduledCheckIn: snapshot.nextScheduledCheckIn,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    #expect(
      SessionTimeKernel.reconcileRelaunch(snapshot: rollbackSnapshot, wallNow: anchor.date)
        == exactAnchorDecision
    )

    let afterDeadline = SessionTimestamp(
      unchecked: Date(timeIntervalSinceReferenceDate: 410))
    #expect(
      SessionTimeKernel.reconcileRelaunch(snapshot: snapshot, wallNow: afterDeadline.date)
        == .normalized(
          NormalizedLiveTiming(
            observedWallNow: afterDeadline,
            expectedWallNow: afterDeadline,
            normalizedDueInstant: afterDeadline,
            phaseOrBreakDeadline: deadline,
            scheduledCheckInAt: nil,
            admissionAdjustment: nil
          ))
    )

    #expect(
      SessionTimeKernel.reconcileRelaunch(
        snapshot: snapshot,
        wallNow: Date(timeIntervalSinceReferenceDate: 99)
      ) == .recovery(.wallClockAmbiguousAfterRelaunch)
    )
    #expect(
      SessionTimeKernel.reconcileRelaunch(
        snapshot: snapshot,
        wallNow: Date(timeIntervalSinceReferenceDate: .infinity)
      ) == .failure(.nonFiniteWallObservation)
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
    let dueTiming = NormalizedLiveTiming(
      observedWallNow: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 700)),
      expectedWallNow: deadline,
      normalizedDueInstant: SessionTimestamp(
        unchecked: Date(timeIntervalSinceReferenceDate: 700)),
      phaseOrBreakDeadline: deadline,
      scheduledCheckInAt: nil,
      admissionAdjustment: nil
    )
    let decision = SessionTimeKernel.admitBoundary(
      snapshot: snapshot,
      timing: dueTiming,
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

    let overflowingSnapshot = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: snapshot.sessionID,
      revision: snapshot.revision,
      eventSequence: snapshot.eventSequence,
      nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
      state: snapshot.state,
      plan: snapshot.plan,
      configuration: snapshot.configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: snapshot.startedAt,
      accumulatedFocusSeconds: .max,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: snapshot.lastWallObservationAt,
      nextScheduledCheckIn: snapshot.nextScheduledCheckIn,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    #expect(
      SessionTimeKernel.admitBoundary(
        snapshot: overflowingSnapshot,
        timing: dueTiming,
        observedToken: phaseToken
      ) == .recovery(.arithmeticOverflow)
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

  @Test("phase admission preserves a strictly later scheduled cadence")
  func phaseAdmissionPreservesFutureScheduledCadence() throws {
    let preservedRemainder = try CheckInRemainingSeconds(100)
    let sessionID = UUID()
    let anchor = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100))
    let phaseDue = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 400))
    let scheduledDue = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 500))
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
          phaseEndsAt: phaseDue,
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
        token: scheduledToken,
        dueAt: scheduledDue,
        trustedRemaining: try CheckInRemainingSeconds(400)
      ),
      lastConsumedBoundaryToken: nil
    )

    let decision = SessionTimeKernel.admitBoundary(
      snapshot: snapshot,
      timing: NormalizedLiveTiming(
        observedWallNow: phaseDue,
        expectedWallNow: phaseDue,
        normalizedDueInstant: phaseDue,
        phaseOrBreakDeadline: phaseDue,
        scheduledCheckInAt: scheduledDue,
        admissionAdjustment: nil
      ),
      observedToken: phaseToken
    )

    #expect(
      decision
        == .winner(
          BoundaryWinnerDecision(
            token: phaseToken,
            dueAt: phaseDue,
            exitMaterialization: .phase(accumulatedFocusSeconds: 304),
            scheduledCadence: .preserve(preservedRemainder)
          )
        )
    )

    let overdueDecision = SessionTimeKernel.admitBoundary(
      snapshot: snapshot,
      timing: NormalizedLiveTiming(
        observedWallNow: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 600)),
        expectedWallNow: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 600)),
        normalizedDueInstant: SessionTimestamp(
          unchecked: Date(timeIntervalSinceReferenceDate: 600)),
        phaseOrBreakDeadline: phaseDue,
        scheduledCheckInAt: scheduledDue,
        admissionAdjustment: nil
      ),
      observedToken: phaseToken
    )
    #expect(
      overdueDecision
        == .winner(
          BoundaryWinnerDecision(
            token: phaseToken,
            dueAt: phaseDue,
            exitMaterialization: .phase(accumulatedFocusSeconds: 304),
            scheduledCadence: .resetAfterSupersededScheduledOccurrence
          )
        )
    )

    #expect(
      SessionTimeKernel.admitBoundary(
        snapshot: snapshot,
        timing: NormalizedLiveTiming(
          observedWallNow: phaseDue,
          expectedWallNow: phaseDue,
          normalizedDueInstant: phaseDue,
          phaseOrBreakDeadline: phaseDue,
          scheduledCheckInAt: scheduledDue,
          admissionAdjustment: nil
        ),
        observedToken: scheduledToken
      ) == .earlierBoundaryPending
    )
  }

  @Test("scheduled check-in wins before a later phase deadline after a clock rebase")
  func scheduledCheckInWinsBeforeLaterPhaseDeadlineAfterRebase() throws {
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
        observedWallNow: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 4_200)),
        expectedWallNow: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 600)),
        normalizedDueInstant: SessionTimestamp(
          unchecked: Date(timeIntervalSinceReferenceDate: 4_200)),
        phaseOrBreakDeadline: SessionTimestamp(
          unchecked: Date(timeIntervalSinceReferenceDate: 4_100)),
        scheduledCheckInAt: SessionTimestamp(
          unchecked: Date(timeIntervalSinceReferenceDate: 3_900)),
        admissionAdjustment: ClockAdjustmentEvent(
          previousPhaseOrBreakDeadline: SessionTimestamp(
            unchecked: Date(timeIntervalSinceReferenceDate: 500)),
          newPhaseOrBreakDeadline: SessionTimestamp(
            unchecked: Date(timeIntervalSinceReferenceDate: 4_100)),
          previousScheduledCheckInAt: SessionTimestamp(
            unchecked: Date(timeIntervalSinceReferenceDate: 300)),
          newScheduledCheckInAt: SessionTimestamp(
            unchecked: Date(timeIntervalSinceReferenceDate: 3_900)),
          drift: .seconds(3_600)
        )
      ),
      observedToken: scheduledToken
    )

    #expect(
      decision
        == .winner(
          BoundaryWinnerDecision(
            token: scheduledToken,
            dueAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 3_900)),
            exitMaterialization: .scheduledCheckIn(
              accumulatedFocusSeconds: 208,
              suspendedTiming: .timed(remaining: try PhaseSeconds(200))
            ),
            scheduledCadence: .resetAfterScheduledOccurrence
          )
        )
    )

    let earlyDecision = SessionTimeKernel.admitBoundary(
      snapshot: snapshot,
      timing: NormalizedLiveTiming(
        observedWallNow: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 3_700)),
        expectedWallNow: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 3_700)),
        normalizedDueInstant: SessionTimestamp(
          unchecked: Date(timeIntervalSinceReferenceDate: 3_700)),
        phaseOrBreakDeadline: SessionTimestamp(
          unchecked: Date(timeIntervalSinceReferenceDate: 4_100)),
        scheduledCheckInAt: SessionTimestamp(
          unchecked: Date(timeIntervalSinceReferenceDate: 3_900)),
        admissionAdjustment: nil
      ),
      observedToken: scheduledToken
    )
    #expect(
      earlyDecision
        == .boundaryNotDue(
          token: scheduledToken,
          dueAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 3_900)),
          observedAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 3_700))
        )
    )
  }

  @Test("scheduled check-in suspends open-ended focus without a phase deadline")
  func scheduledCheckInSuspendsOpenEndedFocus() throws {
    let sessionID = UUID()
    let anchor = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100))
    let due = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 300))
    let scheduledToken = BoundaryToken(
      sessionID: sessionID,
      kind: .scheduledCheckIn,
      phaseID: nil,
      sourceRevision: 2,
      occurrence: 0
    )
    let snapshot = SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 2,
      eventSequence: 2,
      nextBoundaryOccurrence: 1,
      state: .focusing(
        FocusState(
          phase: TimingPolicy.flow.phases[0],
          timingAtAnchor: .openEnded,
          wallAnchor: anchor,
          phaseEndsAt: nil,
          elapsedBeforeAnchorSeconds: 5,
          projectionToken: UUID(),
          phaseBoundaryToken: nil
        )),
      plan: try SessionPlan(
        task: "Task", firstAction: "Action", capacity: nil, timingPolicy: .flow),
      configuration: .defaults,
      parkedThoughts: [],
      startedAt: anchor,
      accumulatedFocusSeconds: 8,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: anchor,
      nextScheduledCheckIn: ScheduledCheckInBoundary(
        token: scheduledToken,
        dueAt: due,
        trustedRemaining: try CheckInRemainingSeconds(200)
      ),
      lastConsumedBoundaryToken: nil
    )

    #expect(
      SessionTimeKernel.admitBoundary(
        snapshot: snapshot,
        timing: NormalizedLiveTiming(
          observedWallNow: due,
          expectedWallNow: due,
          normalizedDueInstant: due,
          phaseOrBreakDeadline: nil,
          scheduledCheckInAt: due,
          admissionAdjustment: nil
        ),
        observedToken: scheduledToken
      )
        == .winner(
          BoundaryWinnerDecision(
            token: scheduledToken,
            dueAt: due,
            exitMaterialization: .scheduledCheckIn(
              accumulatedFocusSeconds: 213,
              suspendedTiming: .openEnded
            ),
            scheduledCadence: .resetAfterScheduledOccurrence
          ))
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

    #expect(
      SessionTimeKernel.replaceScheduledCheckIn(
        ScheduledCheckInReplacementRequest(
          sessionID: sessionID,
          targetRevision: 4,
          nextBoundaryOccurrence: 10,
          wallAnchor: anchor,
          schedule: .manualOnly
        )
      ) == .materialized(boundary: nil, nextBoundaryOccurrence: 10)
    )

    #expect(
      SessionTimeKernel.replaceScheduledCheckIn(
        ScheduledCheckInReplacementRequest(
          sessionID: sessionID,
          targetRevision: 4,
          nextBoundaryOccurrence: .max,
          wallAnchor: anchor,
          schedule: .interval(try! CheckInMinutes(5))
        )
      ) == .failure(.boundaryOccurrenceExhausted)
    )

    #expect(
      SessionTimeKernel.replaceScheduledCheckIn(
        ScheduledCheckInReplacementRequest(
          sessionID: sessionID,
          targetRevision: 4,
          nextBoundaryOccurrence: 10,
          wallAnchor: SessionTimestamp(
            unchecked: Date(timeIntervalSinceReferenceDate: .greatestFiniteMagnitude)),
          schedule: .interval(try! CheckInMinutes(5))
        )
      ) == .failure(.arithmeticOverflow)
    )
  }

  @Test("scheduled cadence materializes no remainder or exact supported intervals")
  func scheduledCadenceRemaindersAreExact() throws {
    let fiveMinutes = try CheckInMinutes(5)
    let fiveMinuteRemainder = try CheckInRemainingSeconds(300)
    let maximumMinutes = try CheckInMinutes(120)
    let maximumRemainder = try CheckInRemainingSeconds(7_200)
    #expect(SessionTimeKernel.materializeScheduledRemainder(.manualOnly) == nil)
    #expect(
      SessionTimeKernel.materializeScheduledRemainder(.interval(fiveMinutes)) == fiveMinuteRemainder
    )
    #expect(
      SessionTimeKernel.materializeScheduledRemainder(.interval(maximumMinutes)) == maximumRemainder
    )
  }
}
