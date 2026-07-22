import Foundation

public struct SessionNotificationID: Equatable, Hashable, Sendable {
  public let value: String

  internal init(boundaryToken: BoundaryToken) {
    value =
      "praxodoro.\(boundaryToken.sessionID.uuidString).\(boundaryToken.kind.rawValue).\(boundaryToken.occurrence)"
  }
}

public enum SessionNotificationKind: String, Equatable, Sendable {
  case phaseBoundary, scheduledCheckIn, breakEnd
}

public enum NotificationContentPolicy: String, Equatable, Sendable { case privateGeneric }
public enum SessionSoundCue: String, Equatable, Sendable { case gentleBoundary, breakComplete }
public enum SessionHapticCue: String, Equatable, Sendable { case gentleBoundary }
public enum SessionAnnouncementCue: String, Equatable, Sendable {
  case focusStarted, checkInPresented, breakStarted, reentryPresented, reviewPresented
}

public struct SessionNotificationRequest: Equatable, Sendable {
  public let id: SessionNotificationID
  public let fireAt: SessionTimestamp
  public let kind: SessionNotificationKind
  public let boundaryToken: BoundaryToken
  public let contentPolicy: NotificationContentPolicy

  internal init(boundaryToken: BoundaryToken, fireAt: SessionTimestamp) {
    self.id = SessionNotificationID(boundaryToken: boundaryToken)
    self.fireAt = fireAt
    self.kind =
      switch boundaryToken.kind {
      case .phase: .phaseBoundary
      case .scheduledCheckIn: .scheduledCheckIn
      case .breakEnd: .breakEnd
      }
    self.boundaryToken = boundaryToken
    self.contentPolicy = .privateGeneric
  }
}

public enum SessionEffect: Equatable, Sendable {
  case scheduleNotification(SessionNotificationRequest)
  case cancelNotification(SessionNotificationID)
  case playSound(SessionSoundCue)
  case playHaptic(SessionHapticCue)
  case announceAccessibility(SessionAnnouncementCue)
  case invalidateDisplayProjection(projectionToken: UUID?)
}

public enum SessionEffectKind: String, CaseIterable, Equatable, Hashable, Sendable {
  case scheduleNotification, cancelNotification, playSound, playHaptic
  case announceAccessibility, invalidateDisplayProjection
}

extension SessionEffect {
  public var kind: SessionEffectKind {
    switch self {
    case .scheduleNotification: .scheduleNotification
    case .cancelNotification: .cancelNotification
    case .playSound: .playSound
    case .playHaptic: .playHaptic
    case .announceAccessibility: .announceAccessibility
    case .invalidateDisplayProjection: .invalidateDisplayProjection
    }
  }
}

public enum CheckInResponseKind: String, CaseIterable, Equatable, Hashable, Sendable {
  case continueFocus, makeSmaller, detour, takeBreak, skip, dismiss
}

extension CheckInResponse {
  public var kind: CheckInResponseKind {
    switch self {
    case .continueFocus: .continueFocus
    case .makeSmaller: .makeSmaller
    case .detour: .detour
    case .takeBreak: .takeBreak
    case .skip: .skip
    case .dismiss: .dismiss
    }
  }
}

public enum ReductionFailure: Equatable, Sendable {
  case revisionExhausted
  case eventSequenceExhausted(requiredAdditionalEvents: UInt64, remainingCapacity: UInt64)
  case boundaryOccurrenceExhausted
  case arithmeticOverflow
  case nonFiniteWallObservation
}

public enum RepositoryFailureKind: String, CaseIterable, Error, Equatable, Sendable {
  case unavailable, readFailed, writeFailed, validationFailed, migrationFailed
}

public enum SessionRepositoryError: Error, Equatable, Sendable {
  case conflict(actualRevision: UInt64)
  case failure(RepositoryFailureKind)
}

public enum PlatformStatus: String, CaseIterable, Equatable, Sendable {
  case notificationPermissionDenied, notificationSchedulingFailed, soundUnavailable,
    hapticUnavailable
  case accessibilityAnnouncementUnavailable, adapterUnavailable, runtimeUnavailable
}

public enum EffectStatus: Equatable, Sendable {
  case succeeded(SessionEffectKind)
  case failed(SessionEffectKind, PlatformStatus)
}

public enum SessionRejection: Equatable, Sendable {
  case invalidTransition(state: SessionStateKind, intent: SessionIntentKind)
  case invalidPlan(fields: Set<SessionPlanField>)
  case invalidText(SessionTextField)
  case activeSessionExists
  case replacementDraftRequired
  case replacementDraftNotAllowed
  case invalidRecoveryChoice(ClockRecoveryChoice)
  case staleRevision(expected: UInt64, actual: UInt64)
  case duplicateBoundary(BoundaryToken)
  case staleBoundary(BoundaryToken)
  case boundaryNotDue(token: BoundaryToken, dueAt: SessionTimestamp, observedAt: SessionTimestamp)
  case thoughtLimitReached(maximum: UInt16)
}

public enum NoChangeReason: String, Equatable, Sendable {
  case alreadyInRequestedState, resumeCurrentSelected, conflictCancelled
  case observationIrrelevant, earlierBoundaryPending
}

public enum SessionEngineFailure: Error, Equatable, Sendable {
  case repositoryLoadFailed(RepositoryFailureKind)
  case repositoryCommitFailed(RepositoryFailureKind)
  case unsupportedSnapshotSchema(found: UInt16)
  case corruptSnapshot(Set<SnapshotInvariantViolation>)
  case revisionExhausted
  case eventSequenceExhausted
  case boundaryOccurrenceExhausted
  case arithmeticOverflow
  case nonFiniteWallObservation
}

public struct Reduction: Equatable, Sendable {
  public let snapshot: SessionSnapshot
  public let events: [SessionEvent]
  public let effects: [SessionEffect]
}

public enum ReductionOutcome: Equatable, Sendable {
  case transition(Reduction)
  case noChange(snapshot: SessionSnapshot, reason: NoChangeReason)
  case rejected(snapshot: SessionSnapshot, reason: SessionRejection)
  case failed(snapshot: SessionSnapshot, reason: ReductionFailure)
}

public enum SessionResult: Equatable, Sendable {
  case committed(snapshot: SessionSnapshot, effects: [EffectStatus])
  case noChange(snapshot: SessionSnapshot, reason: NoChangeReason)
  case rejected(snapshot: SessionSnapshot, reason: SessionRejection)
}
