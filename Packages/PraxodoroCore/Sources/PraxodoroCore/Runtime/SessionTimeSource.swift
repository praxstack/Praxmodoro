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
    case .focusing, .breaking:
      throw .missingLiveProjection
    default:
      return staticProjection(snapshot)
    }
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
