import Foundation

/// Pure display projection entry point. Time-bearing states require a matching
/// live observation; static states deliberately ignore one.
public enum SessionProjector {
  public static func project(
    snapshot: SessionSnapshot,
    instant: SessionInstant
  ) throws(ProjectionError) -> SessionProjection {
    let violations = SessionSnapshotValidator.validateCandidate(snapshot)
    guard violations.isEmpty else {
      throw .invalidSnapshot(violations)
    }

    switch snapshot.state {
    case let .focusing(focus):
      return try liveFocusProjection(snapshot: snapshot, focus: focus, instant: instant)
    case let .breaking(breakState):
      return try liveBreakProjection(snapshot: snapshot, breakState: breakState, instant: instant)
    default:
      return staticProjection(snapshot)
    }
  }

  private static func liveFocusProjection(
    snapshot: SessionSnapshot,
    focus: FocusState,
    instant: SessionInstant
  ) throws(ProjectionError) -> SessionProjection {
    let elapsed = try pairedElapsedSeconds(
      instant: instant,
      expectedToken: focus.projectionToken,
      wallAnchor: focus.wallAnchor
    )
    let projected = try projectedTiming(
      accumulated: snapshot.accumulatedFocusSeconds,
      elapsedBeforeAnchor: focus.elapsedBeforeAnchorSeconds,
      timing: focus.timingAtAnchor,
      pairedElapsed: elapsed
    )
    return SessionProjection(
      sourceRevision: snapshot.revision,
      sessionID: snapshot.sessionID,
      state: .focusing,
      task: snapshot.plan?.task,
      firstAction: snapshot.plan?.firstAction,
      timingPolicy: snapshot.plan?.timingPolicy.id,
      phase: focus.phase.id,
      focusedSeconds: projected.total,
      breakSeconds: snapshot.accumulatedBreakSeconds,
      remainingSeconds: projected.remaining,
      isPaused: false,
      isBoundaryAwaitingDecision: false,
      nextScheduledCheckInAt: snapshot.nextScheduledCheckIn?.dueAt,
      parkedThoughtCount: UInt64(snapshot.parkedThoughts.count),
      lowCognitiveLoadEnabled: snapshot.configuration.lowCognitiveLoadEnabled
    )
  }

  private static func liveBreakProjection(
    snapshot: SessionSnapshot,
    breakState: BreakState,
    instant: SessionInstant
  ) throws(ProjectionError) -> SessionProjection {
    let elapsed = try pairedElapsedSeconds(
      instant: instant,
      expectedToken: breakState.projectionToken,
      wallAnchor: breakState.wallAnchor
    )
    let projected = try projectedTiming(
      accumulated: snapshot.accumulatedBreakSeconds,
      elapsedBeforeAnchor: breakState.elapsedBeforeAnchorSeconds,
      timing: breakState.timingAtAnchor,
      pairedElapsed: elapsed
    )
    return SessionProjection(
      sourceRevision: snapshot.revision,
      sessionID: snapshot.sessionID,
      state: .breaking,
      task: snapshot.plan?.task,
      firstAction: snapshot.plan?.firstAction,
      timingPolicy: snapshot.plan?.timingPolicy.id,
      phase: breakState.resumeTarget.phase.id,
      focusedSeconds: snapshot.accumulatedFocusSeconds,
      breakSeconds: projected.total,
      remainingSeconds: projected.remaining,
      isPaused: false,
      isBoundaryAwaitingDecision: false,
      nextScheduledCheckInAt: nil,
      parkedThoughtCount: UInt64(snapshot.parkedThoughts.count),
      lowCognitiveLoadEnabled: snapshot.configuration.lowCognitiveLoadEnabled
    )
  }

  private static func pairedElapsedSeconds(
    instant: SessionInstant,
    expectedToken: UUID,
    wallAnchor: SessionTimestamp
  ) throws(ProjectionError) -> UInt64 {
    guard canonicalSecond(instant.wallNow) != nil else { throw .arithmeticOverflow }
    guard let live = instant.liveProjection else { throw .missingLiveProjection }
    guard live.projectionToken == expectedToken else {
      throw .staleProjectionToken(expected: expectedToken, actual: live.projectionToken)
    }
    guard let actualAnchor = canonicalSecond(live.rawWallAtProjectionAnchor) else {
      throw .arithmeticOverflow
    }
    guard actualAnchor == wallAnchor else {
      throw .inconsistentProjectionAnchor(
        expectedCanonical: wallAnchor, actualCanonical: actualAnchor)
    }
    guard live.monotonicElapsedSinceAnchor >= .zero else { throw .negativeMonotonicElapsed }
    let components = live.monotonicElapsedSinceAnchor.components
    let seconds =
      Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
    guard seconds.isFinite else { throw .arithmeticOverflow }
    let rawAnchor = live.rawWallAtProjectionAnchor.timeIntervalSinceReferenceDate
    let pairedEnd = rawAnchor + seconds
    guard pairedEnd.isFinite,
      let canonicalEnd = canonicalSecond(Date(timeIntervalSinceReferenceDate: pairedEnd))
    else { throw .arithmeticOverflow }
    let elapsed =
      canonicalEnd.date.timeIntervalSinceReferenceDate
      - wallAnchor.date.timeIntervalSinceReferenceDate
    guard elapsed.isFinite, elapsed >= 0, elapsed <= Double(UInt64.max) else {
      throw .arithmeticOverflow
    }
    return UInt64(elapsed)
  }

  private static func projectedTiming(
    accumulated: UInt64,
    elapsedBeforeAnchor: UInt64,
    timing: PausedTiming,
    pairedElapsed: UInt64
  ) throws(ProjectionError) -> (total: UInt64, remaining: UInt64?) {
    let projectedIncrement: UInt64
    let remaining: UInt64?
    switch timing {
    case let .timed(remainingTiming):
      let budget = UInt64(remainingTiming.value)
      projectedIncrement = min(pairedElapsed, budget)
      remaining = budget - projectedIncrement
    case .openEnded:
      projectedIncrement = pairedElapsed
      remaining = nil
    }
    let withCarry = elapsedBeforeAnchor.addingReportingOverflow(projectedIncrement)
    let total = accumulated.addingReportingOverflow(withCarry.partialValue)
    guard !withCarry.overflow, !total.overflow else { throw .arithmeticOverflow }
    return (total.partialValue, remaining)
  }

  private static func staticProjection(_ snapshot: SessionSnapshot) -> SessionProjection {
    let plan = snapshot.plan
    let base = StaticProjectionFields(
      sourceRevision: snapshot.revision,
      sessionID: snapshot.sessionID,
      state: snapshot.state.kind,
      task: plan?.task,
      firstAction: plan?.firstAction,
      timingPolicy: plan?.timingPolicy.id,
      focusedSeconds: snapshot.accumulatedFocusSeconds,
      breakSeconds: snapshot.accumulatedBreakSeconds,
      parkedThoughtCount: UInt64(snapshot.parkedThoughts.count),
      lowCognitiveLoadEnabled: snapshot.configuration.lowCognitiveLoadEnabled
    )

    switch snapshot.state {
    case .idle:
      return base.projection()
    case .prepared, .reviewing, .recoveryNeeded:
      return base.projection()
    case let .paused(paused):
      return base.projection(
        phase: paused.phase.id,
        remainingSeconds: remainingSeconds(for: paused.timing),
        isPaused: true
      )
    case let .checkingIn(checkIn):
      let continuation = staticContinuation(checkIn)
      return base.projection(
        phase: continuation.phase.id,
        remainingSeconds: remainingSeconds(for: continuation.timing),
        isPaused: true,
        isBoundaryAwaitingDecision: true
      )
    case let .reentering(reentry):
      return base.projection(
        firstAction: reentry.proposedAction,
        phase: reentry.resumeTarget.phase.id,
        remainingSeconds: remainingSeconds(for: reentry.resumeTarget.timing),
        isPaused: true,
        isBoundaryAwaitingDecision: true
      )
    case let .completed(completed):
      return SessionProjection(
        sourceRevision: base.sourceRevision,
        sessionID: base.sessionID,
        state: base.state,
        task: completed.summary.task,
        firstAction: completed.summary.finalAction,
        timingPolicy: nil,
        phase: nil,
        focusedSeconds: base.focusedSeconds,
        breakSeconds: base.breakSeconds,
        remainingSeconds: nil,
        isPaused: false,
        isBoundaryAwaitingDecision: false,
        nextScheduledCheckInAt: nil,
        parkedThoughtCount: base.parkedThoughtCount,
        lowCognitiveLoadEnabled: base.lowCognitiveLoadEnabled
      )
    case .focusing, .breaking:
      preconditionFailure("live states are handled before static projection")
    }
  }

  private static func staticContinuation(
    _ checkIn: CheckInState
  ) -> (phase: SessionPhaseDescriptor, timing: PausedTiming) {
    if let suspended = checkIn.suspended {
      return (suspended.phase, suspended.timing)
    }
    guard case let .startPhase(phase) = checkIn.continuation else {
      preconditionFailure("validated check-in requires a continuation")
    }
    return (phase, timing(for: phase.duration))
  }

  private static func timing(for duration: PhaseDuration) -> PausedTiming {
    switch duration {
    case let .timed(seconds): .timed(remaining: seconds)
    case .openEnded: .openEnded
    }
  }

  private static func remainingSeconds(for timing: PausedTiming) -> UInt64? {
    switch timing {
    case let .timed(remaining): UInt64(remaining.value)
    case .openEnded: nil
    }
  }
}

private struct StaticProjectionFields {
  let sourceRevision: UInt64
  let sessionID: UUID?
  let state: SessionStateKind
  let task: String?
  let firstAction: String?
  let timingPolicy: TimingPolicyID?
  let focusedSeconds: UInt64
  let breakSeconds: UInt64
  let parkedThoughtCount: UInt64
  let lowCognitiveLoadEnabled: Bool

  func projection(
    task: String? = nil,
    firstAction: String? = nil,
    timingPolicy: TimingPolicyID? = nil,
    phase: SessionPhaseID? = nil,
    remainingSeconds: UInt64? = nil,
    isPaused: Bool = false,
    isBoundaryAwaitingDecision: Bool = false
  ) -> SessionProjection {
    SessionProjection(
      sourceRevision: sourceRevision,
      sessionID: sessionID,
      state: state,
      task: task ?? self.task,
      firstAction: firstAction ?? self.firstAction,
      timingPolicy: timingPolicy ?? self.timingPolicy,
      phase: phase,
      focusedSeconds: focusedSeconds,
      breakSeconds: breakSeconds,
      remainingSeconds: remainingSeconds,
      isPaused: isPaused,
      isBoundaryAwaitingDecision: isBoundaryAwaitingDecision,
      nextScheduledCheckInAt: nil,
      parkedThoughtCount: parkedThoughtCount,
      lowCognitiveLoadEnabled: lowCognitiveLoadEnabled
    )
  }
}
