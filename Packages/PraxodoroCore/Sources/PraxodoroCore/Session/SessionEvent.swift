import Foundation

public enum SessionPlanField: String, Hashable, Sendable {
  case task, firstAction, capacity, timingPolicy
}

public struct SessionPlanFieldChanges: Equatable, Sendable {
  public let values: Set<SessionPlanField>

  internal init?(_ values: Set<SessionPlanField>) {
    guard !values.isEmpty else { return nil }
    self.values = values
  }
}

public struct SessionConfigurationFieldChanges: Equatable, Sendable {
  public let values: Set<SessionConfigurationField>

  internal init?(_ values: Set<SessionConfigurationField>) {
    guard !values.isEmpty else { return nil }
    self.values = values
  }
}

public struct SessionEvent: Equatable, Sendable {
  public let eventVersion: UInt16
  public let sessionID: UUID
  public let sequence: UInt64
  public let occurredAt: SessionTimestamp
  public let payload: SessionEventPayload

  internal init(sessionID: UUID, sequence: UInt64, occurredAt: SessionTimestamp, payload: SessionEventPayload) {
    self.eventVersion = 1
    self.sessionID = sessionID
    self.sequence = sequence
    self.occurredAt = occurredAt
    self.payload = payload
  }
}

public struct SessionReviewEvent: Equatable, Sendable {
  public let focusedSeconds: UInt64
  public let breakSeconds: UInt64
  public let stopReason: SessionStopReason
  public let parkedThoughtCount: UInt64
  public let hasReflection: Bool
}

public struct ClockAdjustmentEvent: Equatable, Sendable {
  public let previousPhaseOrBreakDeadline: SessionTimestamp?
  public let newPhaseOrBreakDeadline: SessionTimestamp?
  public let previousScheduledCheckInAt: SessionTimestamp?
  public let newScheduledCheckInAt: SessionTimestamp?
  public let drift: Duration
}

public struct SessionSummaryEvent: Equatable, Sendable {
  public let focusedSeconds: UInt64
  public let breakSeconds: UInt64
  public let stopReason: SessionStopReason
  public let parkedThoughtCount: UInt64
  public let hasReflection: Bool
}

public enum SessionEventPayload: Equatable, Sendable {
  case sessionPrepared(policy: TimingPolicyID, capacitySpecified: Bool)
  case planUpdated(fields: SessionPlanFieldChanges)
  case sessionStarted
  case phaseStarted(phase: SessionPhaseDescriptor, endsAt: SessionTimestamp?)
  case phasePaused(timing: PausedTiming)
  case phaseResumed(phase: SessionPhaseDescriptor, endsAt: SessionTimestamp?)
  case liveProjectionRestored(phase: SessionPhaseDescriptor, wallAnchor: SessionTimestamp, endsAt: SessionTimestamp?)
  case checkInOpened(trigger: CheckInTrigger, continuation: CheckInContinuation)
  case checkInResolved
  case detourReported(hasNote: Bool)
  case actionRevised
  case configurationChanged(fields: SessionConfigurationFieldChanges)
  case breakStarted(kind: BreakKind, duration: BreakDuration, endsAt: SessionTimestamp?)
  case breakEnded
  case reentryPresented
  case thoughtParked(id: UUID)
  case phaseElapsed(token: BoundaryToken)
  case clockAdjusted(ClockAdjustmentEvent)
  case clockRecoveryNeeded(reason: RecoveryReason)
  case clockRecovered(choice: ClockRecoveryChoice)
  case sessionStopRequested(reason: SessionStopReason)
  case sessionReplacementRequested
  case reviewStarted(SessionReviewEvent)
  case reviewReflectionUpdated(hasReflection: Bool)
  case sessionCompleted(summary: SessionSummaryEvent)
}

public enum SessionEventKind: String, CaseIterable, Equatable, Hashable, Sendable {
  case sessionPrepared, planUpdated, sessionStarted, phaseStarted, phasePaused, phaseResumed
  case liveProjectionRestored, checkInOpened, checkInResolved, detourReported, actionRevised
  case configurationChanged, breakStarted, breakEnded, reentryPresented, thoughtParked, phaseElapsed
  case clockAdjusted, clockRecoveryNeeded, clockRecovered, sessionStopRequested
  case sessionReplacementRequested, reviewStarted, reviewReflectionUpdated, sessionCompleted
}

extension SessionEventPayload {
  public var kind: SessionEventKind {
    switch self {
    case .sessionPrepared: .sessionPrepared
    case .planUpdated: .planUpdated
    case .sessionStarted: .sessionStarted
    case .phaseStarted: .phaseStarted
    case .phasePaused: .phasePaused
    case .phaseResumed: .phaseResumed
    case .liveProjectionRestored: .liveProjectionRestored
    case .checkInOpened: .checkInOpened
    case .checkInResolved: .checkInResolved
    case .detourReported: .detourReported
    case .actionRevised: .actionRevised
    case .configurationChanged: .configurationChanged
    case .breakStarted: .breakStarted
    case .breakEnded: .breakEnded
    case .reentryPresented: .reentryPresented
    case .thoughtParked: .thoughtParked
    case .phaseElapsed: .phaseElapsed
    case .clockAdjusted: .clockAdjusted
    case .clockRecoveryNeeded: .clockRecoveryNeeded
    case .clockRecovered: .clockRecovered
    case .sessionStopRequested: .sessionStopRequested
    case .sessionReplacementRequested: .sessionReplacementRequested
    case .reviewStarted: .reviewStarted
    case .reviewReflectionUpdated: .reviewReflectionUpdated
    case .sessionCompleted: .sessionCompleted
    }
  }
}

extension SessionEvent {
  public var kind: SessionEventKind { payload.kind }
}
