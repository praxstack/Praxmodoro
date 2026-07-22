import Foundation

public enum SessionTimestampField: String, Hashable, Sendable {
  case preparedAt, focusWallAnchor, focusDeadline, pausedAt, breakWallAnchor, breakDeadline
  case reentryEnteredAt, thoughtCreatedAt, startedAt, lastWallObservationAt
  case scheduledCheckInDueAt, reviewEndedAt, summaryStartedAt, summaryEndedAt
  case eventOccurredAt, eventPhaseStartedEndsAt, eventPhaseResumedEndsAt
  case eventLiveProjectionRestoredWallAnchor, eventLiveProjectionRestoredEndsAt
  case eventBreakStartedEndsAt
  case clockAdjustmentPreviousPhaseOrBreakDeadline, clockAdjustmentNewPhaseOrBreakDeadline
  case clockAdjustmentPreviousScheduledCheckInAt, clockAdjustmentNewScheduledCheckInAt
}

public enum SessionConfigurationField: String, Hashable, Sendable {
  case checkInSchedule, breakSuggestionsEnabled, lowCognitiveLoadEnabled, reflectionPromptEnabled
}

public enum SnapshotInvariantViolation: Hashable, Sendable {
  case unsupportedSchema(found: UInt16)
  case invalidIdleBaseline
  case invalidSessionReset
  case invalidIdentity
  case invalidRevision(expected: UInt64, actual: UInt64)
  case invalidEventSequence
  case invalidBoundaryOccurrence
  case missingPlan
  case unexpectedPlan
  case invalidStartTimestamp
  case nonCanonicalTimestamp(SessionTimestampField)
  case invalidWallObservation
  case counterRegression
  case invalidEventEnvelope
  case invalidText(SessionTextField)
  case invalidConfiguration(SessionConfigurationField)
  case timingShapeMismatch
  case invalidDeadline
  case invalidProjectionToken
  case invalidBoundaryToken
  case invalidScheduledCheckIn
  case duplicateThoughtID
  case thoughtLimitExceeded
  case invalidSummary
  case invalidRecoveryChoices
}

public struct SessionProjection: Equatable, Sendable {
  public let sourceRevision: UInt64
  public let sessionID: UUID?
  public let state: SessionStateKind
  public let task: String?
  public let firstAction: String?
  public let timingPolicy: TimingPolicyID?
  public let phase: SessionPhaseID?
  public let focusedSeconds: UInt64
  public let breakSeconds: UInt64
  public let remainingSeconds: UInt64?
  public let isPaused: Bool
  public let isBoundaryAwaitingDecision: Bool
  public let nextScheduledCheckInAt: SessionTimestamp?
  public let parkedThoughtCount: UInt64
  public let lowCognitiveLoadEnabled: Bool

  internal init(
    sourceRevision: UInt64,
    sessionID: UUID?,
    state: SessionStateKind,
    task: String?,
    firstAction: String?,
    timingPolicy: TimingPolicyID?,
    phase: SessionPhaseID?,
    focusedSeconds: UInt64,
    breakSeconds: UInt64,
    remainingSeconds: UInt64?,
    isPaused: Bool,
    isBoundaryAwaitingDecision: Bool,
    nextScheduledCheckInAt: SessionTimestamp?,
    parkedThoughtCount: UInt64,
    lowCognitiveLoadEnabled: Bool
  ) {
    self.sourceRevision = sourceRevision
    self.sessionID = sessionID
    self.state = state
    self.task = task
    self.firstAction = firstAction
    self.timingPolicy = timingPolicy
    self.phase = phase
    self.focusedSeconds = focusedSeconds
    self.breakSeconds = breakSeconds
    self.remainingSeconds = remainingSeconds
    self.isPaused = isPaused
    self.isBoundaryAwaitingDecision = isBoundaryAwaitingDecision
    self.nextScheduledCheckInAt = nextScheduledCheckInAt
    self.parkedThoughtCount = parkedThoughtCount
    self.lowCognitiveLoadEnabled = lowCognitiveLoadEnabled
  }
}

public enum ProjectionError: Error, Equatable, Sendable {
  case missingLiveProjection
  case staleProjectionToken(expected: UUID, actual: UUID)
  case inconsistentProjectionAnchor(
    expectedCanonical: SessionTimestamp,
    actualCanonical: SessionTimestamp
  )
  case negativeMonotonicElapsed
  case arithmeticOverflow
  case invalidSnapshot(Set<SnapshotInvariantViolation>)
}
