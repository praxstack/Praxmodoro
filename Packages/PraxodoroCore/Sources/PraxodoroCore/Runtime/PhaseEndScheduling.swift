import Foundation

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
}

internal enum LiveEntryDecision: Equatable, Sendable {
  case materialized(LiveEntryMaterialization)
  case failure(ReductionFailure)
}

internal enum LiveEntryMaterialization: Equatable, Sendable {
  case focus(FocusEntryMaterialization)
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

internal enum SessionTimeKernel {
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
