import Foundation

internal struct NormalizedLiveTiming: Equatable, Sendable {
  let observedWallNow: SessionTimestamp
  let expectedWallNow: SessionTimestamp
  let normalizedDueInstant: SessionTimestamp
  let phaseOrBreakDeadline: SessionTimestamp?
  let scheduledCheckInAt: SessionTimestamp?
  let admissionAdjustment: ClockAdjustmentEvent?
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
    return .normalized(
      NormalizedLiveTiming(
        observedWallNow: observedWallNow,
        expectedWallNow: expectedWallNow,
        normalizedDueInstant: rebase ? observedWallNow : expectedWallNow,
        phaseOrBreakDeadline: normalizedDeadline,
        scheduledCheckInAt: normalizedScheduled,
        admissionAdjustment: adjustment
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
      guard let token = focus.phaseBoundaryToken,
        let dueAt = timing.phaseOrBreakDeadline
      else { return .noneDue }
      guard dueAt.date <= timing.normalizedDueInstant.date else {
        return observedToken.map {
          .boundaryNotDue(token: $0, dueAt: dueAt, observedAt: timing.normalizedDueInstant)
        } ?? .noneDue
      }
      guard observedToken == nil || observedToken == token else { return .earlierBoundaryPending }
      guard case let .timed(remaining) = focus.timingAtAnchor else {
        return .recovery(.arithmeticOverflow)
      }
      let carry = focus.elapsedBeforeAnchorSeconds.addingReportingOverflow(UInt64(remaining.value))
      guard !carry.overflow else { return .recovery(.arithmeticOverflow) }
      let total = snapshot.accumulatedFocusSeconds.addingReportingOverflow(carry.partialValue)
      guard !total.overflow else { return .recovery(.arithmeticOverflow) }
      return .winner(
        BoundaryWinnerDecision(
          token: token,
          dueAt: dueAt,
          exitMaterialization: .phase(accumulatedFocusSeconds: total.partialValue),
          scheduledCadence: cadenceAfterPhase(snapshot.configuration.checkInSchedule)
        )
      )
    case .idle, .prepared, .paused, .checkingIn, .breaking, .reentering, .reviewing, .completed,
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
