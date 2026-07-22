import Foundation

public enum BoundaryKind: String, Equatable, Hashable, Sendable {
  case phase
  case scheduledCheckIn
  case breakEnd
}

public struct BoundaryToken: Equatable, Hashable, Sendable {
  public let sessionID: UUID
  public let kind: BoundaryKind
  public let phaseID: SessionPhaseID?
  public let sourceRevision: UInt64
  public let occurrence: UInt64

  internal init(
    sessionID: UUID,
    kind: BoundaryKind,
    phaseID: SessionPhaseID?,
    sourceRevision: UInt64,
    occurrence: UInt64
  ) {
    self.sessionID = sessionID
    self.kind = kind
    self.phaseID = phaseID
    self.sourceRevision = sourceRevision
    self.occurrence = occurrence
  }
}

public enum CheckInTrigger: Equatable, Sendable {
  case manual
  case scheduled(BoundaryToken)
  case phaseBoundary(BoundaryToken)
  case pauseOffer
}

public enum BreakKind: String, CaseIterable, Equatable, Sendable {
  case quiet
  case breathe
  case move
  case custom
}

public struct BreakChoice: Equatable, Sendable {
  public let kind: BreakKind
  public let duration: BreakDuration

  public init(kind: BreakKind, duration: BreakDuration) {
    self.kind = kind
    self.duration = duration
  }
}

public enum CheckInResponse: Equatable, Sendable {
  case continueFocus
  case makeSmaller
  case detour(note: String?)
  case takeBreak(BreakChoice)
  case skip
  case dismiss
}

public enum SessionStopChoice: String, Equatable, Sendable {
  case completed
  case intentionalStop
}

public enum ActiveSessionConflictChoice: String, Equatable, Sendable {
  case resumeCurrent
  case replaceAndReview
  case cancel
}

public enum ClockRecoveryChoice: String, CaseIterable, Hashable, Sendable {
  case resumeSavedRemainder
  case reviewSession
  case endSession
}

public enum TimeObservation: Equatable, Sendable {
  case live
  case deadlineFired(token: BoundaryToken)
  case wake
  case relaunch
}

/// Raw engine inputs. These deliberately retain non-finite and negative probes
/// so the reducer/projector can classify clock corruption instead of hiding it.
public struct SessionInstant: Sendable {
  public let wallNow: Date
  public let liveProjection: LiveProjectionObservation?

  public init(wallNow: Date, liveProjection: LiveProjectionObservation?) {
    self.wallNow = wallNow
    self.liveProjection = liveProjection
  }
}

public struct LiveProjectionObservation: Sendable {
  public let projectionToken: UUID
  public let rawWallAtProjectionAnchor: Date
  public let monotonicElapsedSinceAnchor: Duration

  public init(
    projectionToken: UUID,
    rawWallAtProjectionAnchor: Date,
    monotonicElapsedSinceAnchor: Duration
  ) {
    self.projectionToken = projectionToken
    self.rawWallAtProjectionAnchor = rawWallAtProjectionAnchor
    self.monotonicElapsedSinceAnchor = monotonicElapsedSinceAnchor
  }
}

public struct ReductionContext: Sendable {
  public let instant: SessionInstant
  public let generatedSessionID: UUID
  public let generatedThoughtID: UUID
  public let generatedProjectionToken: UUID

  public init(
    instant: SessionInstant,
    generatedSessionID: UUID,
    generatedThoughtID: UUID,
    generatedProjectionToken: UUID
  ) {
    self.instant = instant
    self.generatedSessionID = generatedSessionID
    self.generatedThoughtID = generatedThoughtID
    self.generatedProjectionToken = generatedProjectionToken
  }
}

public struct SessionCommand: Equatable, Sendable {
  public let expectedRevision: UInt64
  public let intent: SessionIntent

  public init(expectedRevision: UInt64, intent: SessionIntent) {
    self.expectedRevision = expectedRevision
    self.intent = intent
  }
}

public enum SessionIntent: Equatable, Sendable {
  case prepare(SessionDraft)
  case updatePrepared(SessionDraft)
  case start
  case pause
  case resume
  case openCheckIn(CheckInTrigger)
  case respondToCheckIn(CheckInResponse)
  case acceptRevisedAction(String)
  case requestBreak(BreakChoice)
  case endBreak
  case parkThought(String)
  case setCheckInSchedule(CheckInSchedule)
  case setBreakSuggestionsEnabled(Bool)
  case setLowCognitiveLoadEnabled(Bool)
  case setReflectionPromptEnabled(Bool)
  case stop(SessionStopChoice)
  case updateReviewReflection(String?)
  case finalizeReview
  case resolveActiveSessionConflict(
    choice: ActiveSessionConflictChoice,
    replacement: SessionDraft?
  )
  case reconcileTime(TimeObservation)
  case recoverClock(ClockRecoveryChoice)
}

public enum SessionIntentKind: String, CaseIterable, Equatable, Hashable, Sendable {
  case prepare, updatePrepared, start, pause, resume, openCheckIn, respondToCheckIn
  case acceptRevisedAction, requestBreak, endBreak, parkThought
  case setCheckInSchedule, setBreakSuggestionsEnabled, setLowCognitiveLoadEnabled
  case setReflectionPromptEnabled, stop, updateReviewReflection, finalizeReview
  case resolveActiveSessionConflict, reconcileTime, recoverClock
}

extension SessionIntent {
  public var kind: SessionIntentKind {
    switch self {
    case .prepare: .prepare
    case .updatePrepared: .updatePrepared
    case .start: .start
    case .pause: .pause
    case .resume: .resume
    case .openCheckIn: .openCheckIn
    case .respondToCheckIn: .respondToCheckIn
    case .acceptRevisedAction: .acceptRevisedAction
    case .requestBreak: .requestBreak
    case .endBreak: .endBreak
    case .parkThought: .parkThought
    case .setCheckInSchedule: .setCheckInSchedule
    case .setBreakSuggestionsEnabled: .setBreakSuggestionsEnabled
    case .setLowCognitiveLoadEnabled: .setLowCognitiveLoadEnabled
    case .setReflectionPromptEnabled: .setReflectionPromptEnabled
    case .stop: .stop
    case .updateReviewReflection: .updateReviewReflection
    case .finalizeReview: .finalizeReview
    case .resolveActiveSessionConflict: .resolveActiveSessionConflict
    case .reconcileTime: .reconcileTime
    case .recoverClock: .recoverClock
    }
  }
}
