import Foundation

internal struct NormalizedLiveTiming: Equatable, Sendable {
  let observedWallNow: SessionTimestamp
  let expectedWallNow: SessionTimestamp
  let normalizedDueInstant: SessionTimestamp
  let phaseOrBreakDeadline: SessionTimestamp?
  let scheduledCheckInAt: SessionTimestamp?
  let admissionAdjustment: ClockAdjustmentEvent?
  let nonBoundaryExitMaterialization: NonBoundaryExitMaterialization?
  let liveCommitMaterialization: LiveCommitMaterialization?

  init(
    observedWallNow: SessionTimestamp,
    expectedWallNow: SessionTimestamp,
    normalizedDueInstant: SessionTimestamp,
    phaseOrBreakDeadline: SessionTimestamp?,
    scheduledCheckInAt: SessionTimestamp?,
    admissionAdjustment: ClockAdjustmentEvent?,
    nonBoundaryExitMaterialization: NonBoundaryExitMaterialization? = nil,
    liveCommitMaterialization: LiveCommitMaterialization? = nil
  ) {
    self.observedWallNow = observedWallNow
    self.expectedWallNow = expectedWallNow
    self.normalizedDueInstant = normalizedDueInstant
    self.phaseOrBreakDeadline = phaseOrBreakDeadline
    self.scheduledCheckInAt = scheduledCheckInAt
    self.admissionAdjustment = admissionAdjustment
    self.nonBoundaryExitMaterialization = nonBoundaryExitMaterialization
    self.liveCommitMaterialization = liveCommitMaterialization
  }
}

/// Values copied verbatim when a reduction leaves a live state. Keeping these
/// here prevents the reducer from performing a second, potentially divergent,
/// wall/monotonic calculation.
internal enum NonBoundaryExitMaterialization: Equatable, Sendable {
  case focus(
    accumulatedFocusSeconds: UInt64,
    suspendedTiming: PausedTiming,
    scheduledCheckInRemaining: CheckInRemainingSeconds?
  )
  case breakState(accumulatedBreakSeconds: UInt64)
}

/// Values copied verbatim when a reduction commits and remains live.
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
  case scheduledCheckIn(accumulatedFocusSeconds: UInt64, suspendedTiming: PausedTiming)
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

internal struct ScheduledCheckInReplacementRequest: Equatable, Sendable {
  let sessionID: UUID
  let targetRevision: UInt64
  let nextBoundaryOccurrence: UInt64
  let wallAnchor: SessionTimestamp
  let schedule: CheckInSchedule
}

internal enum ScheduledCheckInReplacementDecision: Equatable, Sendable {
  case materialized(boundary: ScheduledCheckInBoundary?, nextBoundaryOccurrence: UInt64)
  case failure(ReductionFailure)
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

internal enum BreakEntryTimingSeed: Equatable, Sendable {
  case choice(BreakDuration)
  case saved(PausedTiming)
}

internal struct BreakEntryMaterialization: Equatable, Sendable {
  let wallAnchor: SessionTimestamp
  let timingAtAnchor: PausedTiming
  let projectionToken: UUID
  let endsAt: SessionTimestamp?
  let boundaryToken: BoundaryToken?
  let nextBoundaryOccurrence: UInt64
}

internal enum SessionTimeKernel {
  static func reconcileLive(
    snapshot: SessionSnapshot,
    instant: SessionInstant
  ) -> LiveTimeDecision {
    guard canonicalSecond(instant.wallNow) != nil else {
      return .failure(.nonFiniteWallObservation)
    }
    guard let live = instant.liveProjection else { return .recovery(.missingLiveProjection) }
    let liveValues: (token: UUID, anchor: SessionTimestamp, deadline: SessionTimestamp?)
    switch snapshot.state {
    case let .focusing(focus):
      liveValues = (focus.projectionToken, focus.wallAnchor, focus.phaseEndsAt)
    case let .breaking(breakState):
      liveValues = (breakState.projectionToken, breakState.wallAnchor, breakState.endsAt)
    default:
      return .recovery(.missingLiveProjection)
    }
    guard live.projectionToken == liveValues.token else { return .recovery(.staleLiveProjection) }
    guard let rawAnchor = canonicalSecond(live.rawWallAtProjectionAnchor),
      rawAnchor == liveValues.anchor
    else { return .recovery(.inconsistentLiveProjectionAnchor) }
    guard live.monotonicElapsedSinceAnchor >= .zero else {
      return .recovery(.negativeMonotonicElapsed)
    }
    guard
      let expectedWallNow = canonicalDateAfter(
        live.rawWallAtProjectionAnchor,
        duration: live.monotonicElapsedSinceAnchor
      ), let observedWallNow = canonicalSecond(instant.wallNow)
    else { return .recovery(.arithmeticOverflow) }
    let drift =
      observedWallNow.date.timeIntervalSinceReferenceDate
      - expectedWallNow.date.timeIntervalSinceReferenceDate
    guard drift.isFinite else { return .recovery(.arithmeticOverflow) }
    let rebase = abs(drift) > 2
    let normalizedDeadline = rebase ? shifted(liveValues.deadline, by: drift) : liveValues.deadline
    let oldScheduled = snapshot.nextScheduledCheckIn?.dueAt
    let normalizedScheduled = rebase ? shifted(oldScheduled, by: drift) : oldScheduled
    guard (!rebase || (liveValues.deadline == nil || normalizedDeadline != nil)),
      (!rebase || (oldScheduled == nil || normalizedScheduled != nil))
    else { return .recovery(.arithmeticOverflow) }
    let adjustment =
      rebase
      ? ClockAdjustmentEvent(
        previousPhaseOrBreakDeadline: liveValues.deadline,
        newPhaseOrBreakDeadline: normalizedDeadline,
        previousScheduledCheckInAt: oldScheduled,
        newScheduledCheckInAt: normalizedScheduled,
        drift: .seconds(drift)
      ) : nil
    let base = NormalizedLiveTiming(
      observedWallNow: observedWallNow,
      expectedWallNow: expectedWallNow,
      normalizedDueInstant: rebase ? observedWallNow : expectedWallNow,
      phaseOrBreakDeadline: normalizedDeadline,
      scheduledCheckInAt: normalizedScheduled,
      admissionAdjustment: adjustment
    )
    guard !hasDueBoundary(snapshot: snapshot, timing: base) else { return .normalized(base) }
    guard
      let materialized = liveMaterializations(
        snapshot: snapshot,
        elapsedSinceAnchor: pairedElapsedSeconds(
          rawAnchor: live.rawWallAtProjectionAnchor,
          expectedWallNow: expectedWallNow
        ),
        expectedWallNow: expectedWallNow,
        commitAnchor: observedWallNow,
        deadline: commitDeadline(
          oldDeadline: liveValues.deadline,
          expectedWallNow: expectedWallNow,
          observedWallNow: observedWallNow
        ),
        scheduledAt: commitDeadline(
          oldDeadline: oldScheduled,
          expectedWallNow: expectedWallNow,
          observedWallNow: observedWallNow
        ),
        commitAdjustment: liveCommitAdjustment(
          deadline: liveValues.deadline,
          scheduledAt: oldScheduled,
          commitDeadline: commitDeadline(
            oldDeadline: liveValues.deadline,
            expectedWallNow: expectedWallNow,
            observedWallNow: observedWallNow
          ),
          commitScheduledAt: commitDeadline(
            oldDeadline: oldScheduled,
            expectedWallNow: expectedWallNow,
            observedWallNow: observedWallNow
          ),
          drift: drift
        )
      )
    else { return .recovery(.arithmeticOverflow) }
    return .normalized(
      NormalizedLiveTiming(
        observedWallNow: base.observedWallNow,
        expectedWallNow: base.expectedWallNow,
        normalizedDueInstant: base.normalizedDueInstant,
        phaseOrBreakDeadline: base.phaseOrBreakDeadline,
        scheduledCheckInAt: base.scheduledCheckInAt,
        admissionAdjustment: base.admissionAdjustment,
        nonBoundaryExitMaterialization: materialized.exit,
        liveCommitMaterialization: materialized.commit
      )
    )
  }

  static func replaceScheduledCheckIn(
    _ request: ScheduledCheckInReplacementRequest
  ) -> ScheduledCheckInReplacementDecision {
    guard let remaining = materializeScheduledRemainder(request.schedule) else {
      return .materialized(
        boundary: nil,
        nextBoundaryOccurrence: request.nextBoundaryOccurrence
      )
    }
    let occurrence = request.nextBoundaryOccurrence.addingReportingOverflow(1)
    guard !occurrence.overflow else { return .failure(.boundaryOccurrenceExhausted) }
    guard let dueAt = deadline(anchor: request.wallAnchor, seconds: UInt64(remaining.value)) else {
      return .failure(.arithmeticOverflow)
    }
    return .materialized(
      boundary: ScheduledCheckInBoundary(
        token: BoundaryToken(
          sessionID: request.sessionID,
          kind: .scheduledCheckIn,
          phaseID: nil,
          sourceRevision: request.targetRevision,
          occurrence: request.nextBoundaryOccurrence
        ),
        dueAt: dueAt,
        trustedRemaining: remaining
      ),
      nextBoundaryOccurrence: occurrence.partialValue
    )
  }

  static func reconcileRelaunch(
    snapshot: SessionSnapshot,
    wallNow: Date
  ) -> LiveTimeDecision {
    guard let observed = canonicalSecond(wallNow) else {
      return .failure(.nonFiniteWallObservation)
    }
    let values: (anchor: SessionTimestamp, deadline: SessionTimestamp?)
    switch snapshot.state {
    case let .focusing(focus):
      values = (focus.wallAnchor, focus.phaseEndsAt)
    case let .breaking(breakState):
      values = (breakState.wallAnchor, breakState.endsAt)
    case .idle, .prepared, .paused, .checkingIn, .reentering, .reviewing, .completed,
      .recoveryNeeded:
      return .normalized(
        NormalizedLiveTiming(
          observedWallNow: observed,
          expectedWallNow: observed,
          normalizedDueInstant: observed,
          phaseOrBreakDeadline: nil,
          scheduledCheckInAt: nil,
          admissionAdjustment: nil
        )
      )
    }
    guard observed.date >= values.anchor.date else {
      return .recovery(.wallClockAmbiguousAfterRelaunch)
    }
    let base = NormalizedLiveTiming(
      observedWallNow: observed,
      expectedWallNow: observed,
      normalizedDueInstant: observed,
      phaseOrBreakDeadline: values.deadline,
      scheduledCheckInAt: snapshot.nextScheduledCheckIn?.dueAt,
      admissionAdjustment: nil
    )
    guard !hasDueBoundary(snapshot: snapshot, timing: base) else { return .normalized(base) }
    let elapsed = secondsBetween(observed, values.anchor)
    guard let elapsed,
      let materialized = liveMaterializations(
        snapshot: snapshot,
        elapsedSinceAnchor: elapsed,
        expectedWallNow: observed,
        commitAnchor: observed,
        deadline: values.deadline,
        scheduledAt: snapshot.nextScheduledCheckIn?.dueAt,
        commitAdjustment: nil
      )
    else { return .recovery(.arithmeticOverflow) }
    return .normalized(
      NormalizedLiveTiming(
        observedWallNow: base.observedWallNow,
        expectedWallNow: base.expectedWallNow,
        normalizedDueInstant: base.normalizedDueInstant,
        phaseOrBreakDeadline: base.phaseOrBreakDeadline,
        scheduledCheckInAt: base.scheduledCheckInAt,
        admissionAdjustment: nil,
        nonBoundaryExitMaterialization: materialized.exit,
        liveCommitMaterialization: materialized.commit
      )
    )
  }

  static func admitBoundary(
    snapshot: SessionSnapshot,
    timing: NormalizedLiveTiming,
    observedToken: BoundaryToken?
  ) -> BoundaryAdmissionDecision {
    switch snapshot.state {
    case let .focusing(focus):
      return admitFocusBoundary(
        snapshot: snapshot,
        focus: focus,
        timing: timing,
        observedToken: observedToken
      )
    case let .breaking(breakState):
      return admitBreakBoundary(
        snapshot: snapshot,
        breakState: breakState,
        timing: timing,
        observedToken: observedToken
      )
    case .idle, .prepared, .paused, .checkingIn, .reentering, .reviewing, .completed,
      .recoveryNeeded:
      return .noneDue
    }
  }

  static func materializeLiveEntry(_ request: LiveEntryRequest) -> LiveEntryDecision {
    switch request {
    case let .focus(
      sessionID,
      targetRevision,
      nextBoundaryOccurrence,
      wallNow,
      projectionToken,
      phaseID,
      timing,
      cadence
    ):
      return materializeFocusEntry(
        sessionID: sessionID,
        targetRevision: targetRevision,
        nextBoundaryOccurrence: nextBoundaryOccurrence,
        wallNow: wallNow,
        projectionToken: projectionToken,
        phaseID: phaseID,
        timing: timing,
        cadence: cadence
      )
    case let .breakState(
      sessionID,
      targetRevision,
      nextBoundaryOccurrence,
      wallNow,
      projectionToken,
      timing
    ):
      return materializeBreakEntry(
        sessionID: sessionID,
        targetRevision: targetRevision,
        nextBoundaryOccurrence: nextBoundaryOccurrence,
        wallNow: wallNow,
        projectionToken: projectionToken,
        timing: timing
      )
    }
  }

  static func materializeScheduledRemainder(
    _ schedule: CheckInSchedule
  ) -> CheckInRemainingSeconds? {
    switch schedule {
    case .manualOnly: nil
    case let .interval(minutes):
      try? CheckInRemainingSeconds(UInt32(minutes.value) * 60)
    }
  }

  private static func materializeFocusEntry(
    sessionID: UUID,
    targetRevision: UInt64,
    nextBoundaryOccurrence: UInt64,
    wallNow: Date,
    projectionToken: UUID,
    phaseID: SessionPhaseID,
    timing: PausedTiming,
    cadence: ScheduledCadenceSeed
  ) -> LiveEntryDecision {
    guard let wallAnchor = canonicalSecond(wallNow) else {
      return .failure(.nonFiniteWallObservation)
    }
    let requiresPhaseToken = timing.requiresBoundary
    let cadenceSeconds = cadence.seconds
    let tokenCount = UInt64(requiresPhaseToken ? 1 : 0) + UInt64(cadenceSeconds == nil ? 0 : 1)
    let nextOccurrence = nextBoundaryOccurrence.addingReportingOverflow(tokenCount)
    guard !nextOccurrence.overflow else { return .failure(.boundaryOccurrenceExhausted) }

    let phaseDeadline = deadline(anchor: wallAnchor, seconds: timing.seconds)
    let scheduledDeadline = deadline(anchor: wallAnchor, seconds: cadenceSeconds)
    guard (timing.seconds == nil || phaseDeadline != nil),
      (cadenceSeconds == nil || scheduledDeadline != nil)
    else { return .failure(.arithmeticOverflow) }

    var occurrence = nextBoundaryOccurrence
    let phaseToken: BoundaryToken?
    if requiresPhaseToken {
      phaseToken = BoundaryToken(
        sessionID: sessionID,
        kind: .phase,
        phaseID: phaseID,
        sourceRevision: targetRevision,
        occurrence: occurrence
      )
      occurrence += 1
    } else {
      phaseToken = nil
    }

    let scheduledCheckIn: ScheduledCheckInBoundary?
    if let cadenceSeconds, let scheduledDeadline,
      let remaining = try? CheckInRemainingSeconds(UInt32(cadenceSeconds))
    {
      let token = BoundaryToken(
        sessionID: sessionID,
        kind: .scheduledCheckIn,
        phaseID: nil,
        sourceRevision: targetRevision,
        occurrence: occurrence
      )
      scheduledCheckIn = ScheduledCheckInBoundary(
        token: token,
        dueAt: scheduledDeadline,
        trustedRemaining: remaining
      )
    } else {
      scheduledCheckIn = nil
    }

    return .materialized(
      .focus(
        FocusEntryMaterialization(
          wallAnchor: wallAnchor,
          timingAtAnchor: timing,
          projectionToken: projectionToken,
          phaseEndsAt: phaseDeadline,
          phaseBoundaryToken: phaseToken,
          scheduledCheckIn: scheduledCheckIn,
          nextBoundaryOccurrence: nextOccurrence.partialValue
        )
      )
    )
  }

  private static func materializeBreakEntry(
    sessionID: UUID,
    targetRevision: UInt64,
    nextBoundaryOccurrence: UInt64,
    wallNow: Date,
    projectionToken: UUID,
    timing seed: BreakEntryTimingSeed
  ) -> LiveEntryDecision {
    guard let wallAnchor = canonicalSecond(wallNow) else {
      return .failure(.nonFiniteWallObservation)
    }
    let timing = seed.timing
    let nextOccurrence = nextBoundaryOccurrence.addingReportingOverflow(
      timing.requiresBoundary ? 1 : 0)
    guard !nextOccurrence.overflow else { return .failure(.boundaryOccurrenceExhausted) }
    let deadline = deadline(anchor: wallAnchor, seconds: timing.seconds)
    guard timing.seconds == nil || deadline != nil else { return .failure(.arithmeticOverflow) }
    let token =
      timing.requiresBoundary
      ? BoundaryToken(
        sessionID: sessionID,
        kind: .breakEnd,
        phaseID: nil,
        sourceRevision: targetRevision,
        occurrence: nextBoundaryOccurrence
      ) : nil
    return .materialized(
      .breakState(
        BreakEntryMaterialization(
          wallAnchor: wallAnchor,
          timingAtAnchor: timing,
          projectionToken: projectionToken,
          endsAt: deadline,
          boundaryToken: token,
          nextBoundaryOccurrence: nextOccurrence.partialValue
        )
      )
    )
  }

  private static func deadline(
    anchor: SessionTimestamp,
    seconds: UInt64?
  ) -> SessionTimestamp? {
    guard let seconds else { return nil }
    let base = anchor.date.timeIntervalSinceReferenceDate
    let deadline = base + Double(seconds)
    guard deadline.isFinite else { return nil }
    return canonicalSecond(Date(timeIntervalSinceReferenceDate: deadline))
  }

  private static func hasDueBoundary(
    snapshot: SessionSnapshot,
    timing: NormalizedLiveTiming
  ) -> Bool {
    switch snapshot.state {
    case let .focusing(focus):
      let phaseDue =
        focus.phaseBoundaryToken != nil
        && timing.phaseOrBreakDeadline.map {
          $0.date <= timing.normalizedDueInstant.date
        } == true
      let scheduledDue =
        snapshot.nextScheduledCheckIn != nil
        && timing.scheduledCheckInAt.map {
          $0.date <= timing.normalizedDueInstant.date
        } == true
      return phaseDue || scheduledDue
    case let .breaking(breakState):
      return breakState.boundaryToken != nil
        && timing.phaseOrBreakDeadline.map {
          $0.date <= timing.normalizedDueInstant.date
        } == true
    case .idle, .prepared, .paused, .checkingIn, .reentering, .reviewing, .completed,
      .recoveryNeeded:
      return false
    }
  }

  private static func pairedElapsedSeconds(
    rawAnchor: Date,
    expectedWallNow: SessionTimestamp
  ) -> UInt64? {
    guard let canonicalAnchor = canonicalSecond(rawAnchor) else { return nil }
    return secondsBetween(expectedWallNow, canonicalAnchor)
  }

  private static func secondsBetween(
    _ later: SessionTimestamp,
    _ earlier: SessionTimestamp
  ) -> UInt64? {
    let delta =
      later.date.timeIntervalSinceReferenceDate
      - earlier.date.timeIntervalSinceReferenceDate
    guard delta.isFinite, delta >= 0, delta <= Double(UInt64.max), delta.rounded() == delta else {
      return nil
    }
    return UInt64(delta)
  }

  private static func commitDeadline(
    oldDeadline: SessionTimestamp?,
    expectedWallNow: SessionTimestamp,
    observedWallNow: SessionTimestamp
  ) -> SessionTimestamp? {
    guard let oldDeadline else { return nil }
    let drift =
      observedWallNow.date.timeIntervalSinceReferenceDate
      - expectedWallNow.date.timeIntervalSinceReferenceDate
    return shifted(oldDeadline, by: drift)
  }

  private static func liveCommitAdjustment(
    deadline: SessionTimestamp?,
    scheduledAt: SessionTimestamp?,
    commitDeadline: SessionTimestamp?,
    commitScheduledAt: SessionTimestamp?,
    drift: Double
  ) -> ClockAdjustmentEvent? {
    guard drift != 0 else { return nil }
    return ClockAdjustmentEvent(
      previousPhaseOrBreakDeadline: deadline,
      newPhaseOrBreakDeadline: commitDeadline,
      previousScheduledCheckInAt: scheduledAt,
      newScheduledCheckInAt: commitScheduledAt,
      drift: .seconds(drift)
    )
  }

  private static func liveMaterializations(
    snapshot: SessionSnapshot,
    elapsedSinceAnchor: UInt64?,
    expectedWallNow: SessionTimestamp,
    commitAnchor: SessionTimestamp,
    deadline: SessionTimestamp?,
    scheduledAt: SessionTimestamp?,
    commitAdjustment: ClockAdjustmentEvent?
  ) -> (exit: NonBoundaryExitMaterialization, commit: LiveCommitMaterialization)? {
    guard let elapsedSinceAnchor else { return nil }
    switch snapshot.state {
    case let .focusing(focus):
      guard let timing = reducedTiming(focus.timingAtAnchor, by: elapsedSinceAnchor),
        let elapsedBeforeAnchor = checkedAdd(focus.elapsedBeforeAnchorSeconds, elapsedSinceAnchor),
        let accumulated = checkedAdd(snapshot.accumulatedFocusSeconds, elapsedBeforeAnchor),
        let scheduledRemaining = scheduledRemainder(at: scheduledAt, from: expectedWallNow)
      else { return nil }
      return (
        .focus(
          accumulatedFocusSeconds: accumulated,
          suspendedTiming: timing,
          scheduledCheckInRemaining: scheduledRemaining
        ),
        LiveCommitMaterialization(
          wallAnchor: commitAnchor,
          elapsedBeforeAnchorSeconds: elapsedBeforeAnchor,
          timingAtAnchor: timing,
          phaseOrBreakDeadline: deadline,
          scheduledCheckInAt: scheduledAt,
          scheduledCheckInRemaining: scheduledRemaining,
          adjustment: commitAdjustment
        )
      )
    case let .breaking(breakState):
      guard let timing = reducedTiming(breakState.timingAtAnchor, by: elapsedSinceAnchor),
        let elapsedBeforeAnchor = checkedAdd(
          breakState.elapsedBeforeAnchorSeconds, elapsedSinceAnchor),
        let accumulated = checkedAdd(snapshot.accumulatedBreakSeconds, elapsedBeforeAnchor)
      else { return nil }
      return (
        .breakState(accumulatedBreakSeconds: accumulated),
        LiveCommitMaterialization(
          wallAnchor: commitAnchor,
          elapsedBeforeAnchorSeconds: elapsedBeforeAnchor,
          timingAtAnchor: timing,
          phaseOrBreakDeadline: deadline,
          scheduledCheckInAt: nil,
          scheduledCheckInRemaining: nil,
          adjustment: commitAdjustment
        )
      )
    case .idle, .prepared, .paused, .checkingIn, .reentering, .reviewing, .completed,
      .recoveryNeeded:
      return nil
    }
  }

  private static func reducedTiming(_ timing: PausedTiming, by elapsed: UInt64) -> PausedTiming? {
    switch timing {
    case let .timed(remaining):
      let budget = UInt64(remaining.value)
      guard elapsed < budget, let reduced = try? PhaseSeconds(UInt32(budget - elapsed)) else {
        return nil
      }
      return .timed(remaining: reduced)
    case .openEnded:
      return .openEnded
    }
  }

  private static func checkedAdd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64? {
    let result = lhs.addingReportingOverflow(rhs)
    return result.overflow ? nil : result.partialValue
  }

  private static func scheduledRemainder(
    at scheduledAt: SessionTimestamp?,
    from instant: SessionTimestamp
  ) -> CheckInRemainingSeconds?? {
    guard let scheduledAt else { return .some(nil) }
    guard let seconds = secondsBetween(scheduledAt, instant), seconds > 0,
      let remaining = try? CheckInRemainingSeconds(UInt32(exactly: seconds) ?? 0)
    else { return nil }
    return .some(remaining)
  }

  private static func shifted(
    _ timestamp: SessionTimestamp?,
    by seconds: Double
  ) -> SessionTimestamp? {
    guard let timestamp else { return nil }
    let shifted = timestamp.date.timeIntervalSinceReferenceDate + seconds
    guard shifted.isFinite else { return nil }
    return canonicalSecond(Date(timeIntervalSinceReferenceDate: shifted))
  }

  private static func canonicalDateAfter(
    _ date: Date,
    duration: Duration
  ) -> SessionTimestamp? {
    let components = duration.components
    let seconds =
      Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
    let end = date.timeIntervalSinceReferenceDate + seconds
    guard seconds.isFinite, end.isFinite else { return nil }
    return canonicalSecond(Date(timeIntervalSinceReferenceDate: end))
  }

  private static func admitFocusBoundary(
    snapshot: SessionSnapshot,
    focus: FocusState,
    timing: NormalizedLiveTiming,
    observedToken: BoundaryToken?
  ) -> BoundaryAdmissionDecision {
    let phase = focus.phaseBoundaryToken.flatMap { token in
      timing.phaseOrBreakDeadline.map { (token: token, dueAt: $0) }
    }
    let scheduled = snapshot.nextScheduledCheckIn.flatMap { boundary in
      timing.scheduledCheckInAt.map { (token: boundary.token, dueAt: $0) }
    }
    let candidates = [phase, scheduled].compactMap { $0 }
    guard
      let winner = candidates.min(by: { left, right in
        if left.dueAt.date != right.dueAt.date { return left.dueAt.date < right.dueAt.date }
        return left.token.kind == .phase && right.token.kind != .phase
      })
    else { return .noneDue }
    guard winner.dueAt.date <= timing.normalizedDueInstant.date else {
      return observedToken.map {
        .boundaryNotDue(token: $0, dueAt: winner.dueAt, observedAt: timing.normalizedDueInstant)
      } ?? .noneDue
    }
    guard observedToken == nil || observedToken == winner.token else {
      return .earlierBoundaryPending
    }
    guard case let .timed(remaining) = focus.timingAtAnchor else {
      return .recovery(.arithmeticOverflow)
    }
    let budget = UInt64(remaining.value)
    let elapsed =
      winner.dueAt.date.timeIntervalSinceReferenceDate
      - focus.wallAnchor.date.timeIntervalSinceReferenceDate
    guard elapsed.isFinite, elapsed >= 0, elapsed <= Double(budget) else {
      return .recovery(.arithmeticOverflow)
    }
    let elapsedSeconds = UInt64(elapsed)
    let carry = focus.elapsedBeforeAnchorSeconds.addingReportingOverflow(elapsedSeconds)
    let total = snapshot.accumulatedFocusSeconds.addingReportingOverflow(carry.partialValue)
    guard !carry.overflow, !total.overflow else { return .recovery(.arithmeticOverflow) }
    switch winner.token.kind {
    case .phase:
      return .winner(
        BoundaryWinnerDecision(
          token: winner.token,
          dueAt: winner.dueAt,
          exitMaterialization: .phase(accumulatedFocusSeconds: total.partialValue),
          scheduledCadence: cadenceAfterPhase(snapshot.configuration.checkInSchedule)
        )
      )
    case .scheduledCheckIn:
      let remainingSeconds = budget - elapsedSeconds
      guard let suspended = try? PhaseSeconds(UInt32(remainingSeconds)) else {
        return .recovery(.arithmeticOverflow)
      }
      return .winner(
        BoundaryWinnerDecision(
          token: winner.token,
          dueAt: winner.dueAt,
          exitMaterialization: .scheduledCheckIn(
            accumulatedFocusSeconds: total.partialValue,
            suspendedTiming: .timed(remaining: suspended)
          ),
          scheduledCadence: .resetAfterScheduledOccurrence
        )
      )
    case .breakEnd:
      return .recovery(.arithmeticOverflow)
    }
  }

  private static func admitBreakBoundary(
    snapshot: SessionSnapshot,
    breakState: BreakState,
    timing: NormalizedLiveTiming,
    observedToken: BoundaryToken?
  ) -> BoundaryAdmissionDecision {
    guard let token = breakState.boundaryToken,
      let dueAt = timing.phaseOrBreakDeadline
    else { return .noneDue }
    guard dueAt.date <= timing.normalizedDueInstant.date else {
      return observedToken.map {
        .boundaryNotDue(token: $0, dueAt: dueAt, observedAt: timing.normalizedDueInstant)
      } ?? .noneDue
    }
    guard observedToken == nil || observedToken == token else { return .earlierBoundaryPending }
    guard case let .timed(remaining) = breakState.timingAtAnchor else {
      return .recovery(.arithmeticOverflow)
    }
    let carry = breakState.elapsedBeforeAnchorSeconds.addingReportingOverflow(
      UInt64(remaining.value))
    let total = snapshot.accumulatedBreakSeconds.addingReportingOverflow(carry.partialValue)
    guard !carry.overflow, !total.overflow else { return .recovery(.arithmeticOverflow) }
    return .winner(
      BoundaryWinnerDecision(
        token: token,
        dueAt: dueAt,
        exitMaterialization: .breakEnd(accumulatedBreakSeconds: total.partialValue),
        scheduledCadence: .notApplicable
      )
    )
  }

  private static func cadenceAfterPhase(
    _ schedule: CheckInSchedule
  ) -> ScheduledCadenceAdmission {
    switch schedule {
    case .manualOnly: .manualOnly
    case .interval: .resetAfterPhaseCollision
    }
  }
}

private extension PausedTiming {
  var seconds: UInt64? {
    switch self {
    case let .timed(remaining): UInt64(remaining.value)
    case .openEnded: nil
    }
  }

  var requiresBoundary: Bool {
    seconds != nil
  }
}

private extension ScheduledCadenceSeed {
  var seconds: UInt64? {
    switch self {
    case .manualOnly: nil
    case let .fullInterval(minutes): UInt64(minutes.value) * 60
    case let .captured(remaining): UInt64(remaining.value)
    }
  }
}

private extension BreakEntryTimingSeed {
  var timing: PausedTiming {
    switch self {
    case let .choice(duration):
      switch duration {
      case .openEnded: .openEnded
      case let .timed(minutes):
        .timed(remaining: try! PhaseSeconds(UInt32(minutes.value) * 60))
      }
    case let .saved(timing): timing
    }
  }
}
