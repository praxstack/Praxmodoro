import Foundation

public enum PausedTiming: Equatable, Sendable {
  case timed(remaining: PhaseSeconds)
  case openEnded
}

public enum ResumeDisposition: String, Equatable, Sendable {
  case focusing, paused
}

public struct SuspendedFocusState: Equatable, Sendable {
  public let phase: SessionPhaseDescriptor
  public let timing: PausedTiming
  public let resumeDisposition: ResumeDisposition
  public let scheduledCheckInRemaining: CheckInRemainingSeconds?
}

public struct ScheduledCheckInBoundary: Equatable, Sendable {
  public let token: BoundaryToken
  public let dueAt: SessionTimestamp
  public let trustedRemaining: CheckInRemainingSeconds
}

public enum SessionStopReason: String, Equatable, Sendable {
  case completed, intentionalStop, replacedByAnotherSession, clockRecoveryReview, clockRecoveryEnd
}

public enum RecoveryReason: String, CaseIterable, Equatable, Sendable {
  case missingLiveProjection, staleLiveProjection, inconsistentLiveProjectionAnchor
  case negativeMonotonicElapsed, wallClockAmbiguousAfterRelaunch, arithmeticOverflow
}

public struct ParkedThought: Equatable, Sendable {
  public let id: UUID
  public let text: String
  public let createdAt: SessionTimestamp
}

public struct SessionSummaryDraft: Equatable, Sendable {
  public let endedAt: SessionTimestamp
  public let focusedSeconds: UInt64
  public let breakSeconds: UInt64
  public let parkedThoughtCount: UInt64
  public let optionalReflection: String?
}

public struct SessionSummary: Equatable, Sendable {
  public let sessionID: UUID
  public let task: String
  public let finalAction: String
  public let startedAt: SessionTimestamp
  public let endedAt: SessionTimestamp
  public let focusedSeconds: UInt64
  public let breakSeconds: UInt64
  public let stopReason: SessionStopReason
  public let parkedThoughtCount: UInt64
  public let optionalReflection: String?
}

public struct PreparedState: Equatable, Sendable { public let preparedAt: SessionTimestamp }

public struct FocusState: Equatable, Sendable {
  public let phase: SessionPhaseDescriptor
  public let timingAtAnchor: PausedTiming
  public let wallAnchor: SessionTimestamp
  public let phaseEndsAt: SessionTimestamp?
  public let elapsedBeforeAnchorSeconds: UInt64
  public let projectionToken: UUID
  public let phaseBoundaryToken: BoundaryToken?
}

public struct PausedState: Equatable, Sendable {
  public let phase: SessionPhaseDescriptor
  public let timing: PausedTiming
  public let pausedAt: SessionTimestamp
  public let scheduledCheckInRemaining: CheckInRemainingSeconds?
}

public enum CheckInContinuation: Equatable, Sendable {
  case resumeSuspended
  case startPhase(SessionPhaseDescriptor)
}

public struct CheckInState: Equatable, Sendable {
  public let suspended: SuspendedFocusState?
  public let trigger: CheckInTrigger
  public let continuation: CheckInContinuation
  public let phaseBoundaryScheduledCheckInRemaining: CheckInRemainingSeconds?
}

public struct BreakState: Equatable, Sendable {
  public let choice: BreakChoice
  public let timingAtAnchor: PausedTiming
  public let wallAnchor: SessionTimestamp
  public let endsAt: SessionTimestamp?
  public let elapsedBeforeAnchorSeconds: UInt64
  public let projectionToken: UUID
  public let boundaryToken: BoundaryToken?
  public let resumeTarget: SuspendedFocusState
  public let proposedAction: String
}

public struct ReentryState: Equatable, Sendable {
  public let resumeTarget: SuspendedFocusState
  public let proposedAction: String
  public let enteredAt: SessionTimestamp
}

public struct ReviewState: Equatable, Sendable {
  public let draft: SessionSummaryDraft
  public let stopReason: SessionStopReason
  public let replacementDraft: SessionDraft?
}

public struct CompletedState: Equatable, Sendable {
  public let summary: SessionSummary
  public let pendingReplacementDraft: SessionDraft?
}

public struct SuspendedBreakState: Equatable, Sendable {
  public let choice: BreakChoice
  public let timing: PausedTiming
  public let resumeTarget: SuspendedFocusState
  public let proposedAction: String
}

public enum RecoverableSessionState: Equatable, Sendable {
  case focus(SuspendedFocusState)
  case breakState(SuspendedBreakState)
  case checkingIn(CheckInState)
  case reentering(ReentryState)
}

public struct RecoveryState: Equatable, Sendable {
  public let reason: RecoveryReason
  public let lastTrustworthyState: RecoverableSessionState
  public let safeChoices: Set<ClockRecoveryChoice>
}

public enum SessionState: Equatable, Sendable {
  case idle
  case prepared(PreparedState)
  case focusing(FocusState)
  case paused(PausedState)
  case checkingIn(CheckInState)
  case breaking(BreakState)
  case reentering(ReentryState)
  case reviewing(ReviewState)
  case completed(CompletedState)
  case recoveryNeeded(RecoveryState)
}

extension SessionState {
  public var kind: SessionStateKind {
    switch self {
    case .idle: .idle
    case .prepared: .prepared
    case .focusing: .focusing
    case .paused: .paused
    case .checkingIn: .checkingIn
    case .breaking: .breaking
    case .reentering: .reentering
    case .reviewing: .reviewing
    case .completed: .completed
    case .recoveryNeeded: .recoveryNeeded
    }
  }
}

public struct SessionSnapshot: Equatable, Sendable {
  public let schemaVersion: UInt16
  public let sessionID: UUID?
  public let revision: UInt64
  public let eventSequence: UInt64
  public let nextBoundaryOccurrence: UInt64
  public let state: SessionState
  public let plan: SessionPlan?
  public let configuration: SessionConfiguration
  public let parkedThoughts: [ParkedThought]
  public let startedAt: SessionTimestamp?
  public let accumulatedFocusSeconds: UInt64
  public let accumulatedBreakSeconds: UInt64
  public let lastWallObservationAt: SessionTimestamp?
  public let nextScheduledCheckIn: ScheduledCheckInBoundary?
  public let lastConsumedBoundaryToken: BoundaryToken?
}
