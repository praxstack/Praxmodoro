public enum CoachSuggestionRequest: Equatable, Sendable {
  case makeSmaller
  case breakHelp
  case detourHelp(hasNote: Bool)
}

public enum CoachSuggestion: Equatable, Sendable {
  case editAction(EditActionSuggestion)
  case breakOptions(BreakOptionsSuggestion)
  case detourRecovery(DetourRecoverySuggestion)
}

public struct EditActionSuggestion: Equatable, Sendable {
  public let proposedAction: String
  public let prompt: ActionEditPrompt
  public let reasons: [CoachSuggestionReason]
}

public enum ActionEditPrompt: String, Equatable, Sendable {
  case smallestVisibleStep
}

public struct BreakOptionsSuggestion: Equatable, Sendable {
  public let recommended: BreakChoice?
  public let options: [BreakChoice]
  public let reasons: [CoachSuggestionReason]
}

public struct DetourRecoverySuggestion: Equatable, Sendable {
  public let options: [DetourRecoveryOption]
  public let reasons: [CoachSuggestionReason]
}

public enum DetourRecoveryOption: String, CaseIterable, Equatable, Sendable {
  case resume
  case makeSmaller
  case parkDetour
  case takeBreak
  case intentionalStop
}

public enum CoachSuggestionReason: Equatable, Sendable {
  case userRequestedMakeSmaller
  case userRequestedBreakHelp
  case userReportedDetour(hasNote: Bool)
  case timingPolicy(TimingPolicyID)
  case explicitCapacity(Capacity)
  case projectedFocusAtLeast(seconds: UInt64)
}

public enum SessionCoachError: Error, Equatable, Sendable {
  case unavailable(state: SessionStateKind, request: CoachSuggestionRequest)
  case staleProjection(expectedRevision: UInt64, actualRevision: UInt64)
}

public enum SessionCoach {
  public static func suggest(
    _ request: CoachSuggestionRequest,
    snapshot: SessionSnapshot,
    projection: SessionProjection
  ) throws(SessionCoachError) -> CoachSuggestion {
    guard projection.sourceRevision == snapshot.revision else {
      throw .staleProjection(
        expectedRevision: snapshot.revision,
        actualRevision: projection.sourceRevision
      )
    }
    switch request {
    case .makeSmaller:
      guard snapshot.state.kind == .prepared || snapshot.state.kind == .checkingIn,
        let action = snapshot.plan?.firstAction
      else {
        throw .unavailable(state: snapshot.state.kind, request: request)
      }
      return .editAction(
        EditActionSuggestion(
          proposedAction: action,
          prompt: .smallestVisibleStep,
          reasons: [.userRequestedMakeSmaller]
        ))
    case .breakHelp:
      guard
        snapshot.state.kind == .focusing || snapshot.state.kind == .paused
          || snapshot.state.kind == .checkingIn,
        let plan = snapshot.plan
      else {
        throw .unavailable(state: snapshot.state.kind, request: request)
      }
      let duration = plan.timingPolicy.suggestedBreak ?? .timed(.five)
      let move = BreakChoice(kind: .move, duration: duration)
      let options = [
        move,
        BreakChoice(kind: .quiet, duration: duration),
        BreakChoice(kind: .breathe, duration: duration),
        BreakChoice(kind: .custom, duration: .openEnded),
      ]
      if plan.capacity == .restless, projection.focusedSeconds >= 1_200 {
        return .breakOptions(
          BreakOptionsSuggestion(
            recommended: move,
            options: options,
            reasons: [
              .userRequestedBreakHelp,
              .explicitCapacity(.restless),
              .projectedFocusAtLeast(seconds: 1_200),
            ]
          ))
      }
      return .breakOptions(
        BreakOptionsSuggestion(
          recommended: nil,
          options: options,
          reasons: [.userRequestedBreakHelp]
        ))
    case let .detourHelp(hasNote):
      guard snapshot.state.kind == .checkingIn,
        let policy = snapshot.plan?.timingPolicy.id
      else {
        throw .unavailable(state: snapshot.state.kind, request: request)
      }
      return .detourRecovery(
        DetourRecoverySuggestion(
          options: DetourRecoveryOption.allCases,
          reasons: [
            .userReportedDetour(hasNote: hasNote),
            .timingPolicy(policy),
          ]
        ))
    }
  }
}
