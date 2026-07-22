import Foundation
import Testing

@testable import PraxodoroCore

@Suite("Deterministic session coach")
struct CoachSuggestionTests {
  @Test("make smaller preserves the current action and availability is explicit")
  func makeSmallerIsExact() throws {
    let prepared = try snapshot(state: .prepared, policy: .classic, capacity: nil)
    let projection = project(prepared, focusedSeconds: 0)
    #expect(
      try SessionCoach.suggest(.makeSmaller, snapshot: prepared, projection: projection)
        == .editAction(
          EditActionSuggestion(
            proposedAction: "Open the document",
            prompt: .smallestVisibleStep,
            reasons: [.userRequestedMakeSmaller]
          )))

    let checkingIn = try snapshot(state: .checkingIn, policy: .classic, capacity: nil)
    #expect(
      try SessionCoach.suggest(
        .makeSmaller,
        snapshot: checkingIn,
        projection: project(checkingIn, focusedSeconds: 300)
      )
        == .editAction(
          EditActionSuggestion(
            proposedAction: "Open the document",
            prompt: .smallestVisibleStep,
            reasons: [.userRequestedMakeSmaller]
          )))

    let idle = SessionSnapshot.canonicalIdle
    #expect(throws: SessionCoachError.unavailable(state: .idle, request: .makeSmaller)) {
      try SessionCoach.suggest(
        .makeSmaller,
        snapshot: idle,
        projection: project(idle, focusedSeconds: 0)
      )
    }
  }

  @Test("break help has exact options and only recommends the restless threshold")
  func breakHelpIsExact() throws {
    let focusing = try snapshot(state: .focusing, policy: .flow, capacity: .restless)
    let suggestion = try SessionCoach.suggest(
      .breakHelp,
      snapshot: focusing,
      projection: project(focusing, focusedSeconds: 1_200)
    )
    let duration = BreakDuration.timed(.five)
    let move = BreakChoice(kind: .move, duration: duration)
    #expect(
      suggestion
        == .breakOptions(
          BreakOptionsSuggestion(
            recommended: move,
            options: [
              move,
              BreakChoice(kind: .quiet, duration: duration),
              BreakChoice(kind: .breathe, duration: duration),
              BreakChoice(kind: .custom, duration: .openEnded),
            ],
            reasons: [
              .userRequestedBreakHelp,
              .explicitCapacity(.restless),
              .projectedFocusAtLeast(seconds: 1_200),
            ]
          )))

    let below = try SessionCoach.suggest(
      .breakHelp,
      snapshot: focusing,
      projection: project(focusing, focusedSeconds: 1_199)
    )
    guard case let .breakOptions(belowOptions) = below else {
      Issue.record("expected break options")
      return
    }
    #expect(belowOptions.recommended == nil)
    #expect(belowOptions.reasons == [.userRequestedBreakHelp])
    #expect(focusing.configuration.breakSuggestionsEnabled == false)

    for state in [SessionStateKind.paused, .checkingIn] {
      let eligible = try snapshot(state: state, policy: .classic, capacity: nil)
      guard
        case let .breakOptions(options) = try SessionCoach.suggest(
          .breakHelp,
          snapshot: eligible,
          projection: project(eligible, focusedSeconds: 1_500)
        )
      else {
        Issue.record("expected break options for \(state)")
        continue
      }
      #expect(options.recommended == nil)
      #expect(options.options.map(\.duration) == [duration, duration, duration, .openEnded])
      #expect(options.reasons == [.userRequestedBreakHelp])
    }

    for capacity in [Capacity?.none, .some(.foggy), .some(.steady), .some(.charged)] {
      let notRestless = try snapshot(state: .focusing, policy: .classic, capacity: capacity)
      guard
        case let .breakOptions(options) = try SessionCoach.suggest(
          .breakHelp,
          snapshot: notRestless,
          projection: project(notRestless, focusedSeconds: 1_200)
        )
      else {
        Issue.record("expected non-restless break options")
        continue
      }
      #expect(options.recommended == nil)
      #expect(options.reasons == [.userRequestedBreakHelp])
    }

    let idle = SessionSnapshot.canonicalIdle
    #expect(throws: SessionCoachError.unavailable(state: .idle, request: .breakHelp)) {
      try SessionCoach.suggest(
        .breakHelp,
        snapshot: idle,
        projection: project(idle, focusedSeconds: 0)
      )
    }
  }

  @Test("detour help exposes declaration order without raw note text")
  func detourHelpIsExact() throws {
    let checkingIn = try snapshot(state: .checkingIn, policy: .recoveryFirst, capacity: .foggy)
    for hasNote in [false, true] {
      #expect(
        try SessionCoach.suggest(
          .detourHelp(hasNote: hasNote),
          snapshot: checkingIn,
          projection: project(checkingIn, focusedSeconds: 300)
        )
          == .detourRecovery(
            DetourRecoverySuggestion(
              options: [.resume, .makeSmaller, .parkDetour, .takeBreak, .intentionalStop],
              reasons: [
                .userReportedDetour(hasNote: hasNote),
                .timingPolicy(.recoveryFirst),
              ]
            ))
      )
    }
    let idle = SessionSnapshot.canonicalIdle
    let request = CoachSuggestionRequest.detourHelp(hasNote: false)
    #expect(throws: SessionCoachError.unavailable(state: .idle, request: request)) {
      try SessionCoach.suggest(
        request,
        snapshot: idle,
        projection: project(idle, focusedSeconds: 0)
      )
    }
  }

  @Test("stale projection wins before request availability")
  func staleProjectionPrecedenceIsExact() {
    let idle = SessionSnapshot.canonicalIdle
    let stale = SessionProjection(
      sourceRevision: 1,
      sessionID: nil,
      state: .idle,
      task: nil,
      firstAction: nil,
      timingPolicy: nil,
      phase: nil,
      focusedSeconds: 0,
      breakSeconds: 0,
      remainingSeconds: nil,
      isPaused: false,
      isBoundaryAwaitingDecision: false,
      nextScheduledCheckInAt: nil,
      parkedThoughtCount: 0,
      lowCognitiveLoadEnabled: false
    )
    #expect(throws: SessionCoachError.staleProjection(expectedRevision: 0, actualRevision: 1)) {
      try SessionCoach.suggest(.breakHelp, snapshot: idle, projection: stale)
    }
  }

  private func snapshot(
    state: SessionStateKind,
    policy: TimingPolicy,
    capacity: Capacity?
  ) throws -> SessionSnapshot {
    let sessionID = UUID()
    let wall = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 100))
    let plan = try SessionPlan(
      task: "Draft report",
      firstAction: "Open the document",
      capacity: capacity,
      timingPolicy: policy
    )
    let configuration = SessionConfiguration(
      checkInSchedule: .every15Minutes,
      breakSuggestionsEnabled: false,
      lowCognitiveLoadEnabled: true,
      reflectionPromptEnabled: true
    )
    let phase = policy.phases[0]
    let sessionState: SessionState =
      switch state {
      case .prepared:
        .prepared(PreparedState(preparedAt: wall))
      case .focusing:
        .focusing(
          FocusState(
            phase: phase,
            timingAtAnchor: .openEnded,
            wallAnchor: wall,
            phaseEndsAt: nil,
            elapsedBeforeAnchorSeconds: 0,
            projectionToken: UUID(),
            phaseBoundaryToken: nil
          ))
      case .paused:
        .paused(
          PausedState(
            phase: phase,
            timing: .openEnded,
            pausedAt: wall,
            scheduledCheckInRemaining: try CheckInRemainingSeconds(900)
          ))
      case .checkingIn:
        .checkingIn(
          CheckInState(
            suspended: SuspendedFocusState(
              phase: phase,
              timing: .openEnded,
              resumeDisposition: .focusing,
              scheduledCheckInRemaining: try CheckInRemainingSeconds(900)
            ),
            trigger: .manual,
            continuation: .resumeSuspended,
            phaseBoundaryScheduledCheckInRemaining: nil
          ))
      default:
        throw SessionCoachError.unavailable(state: state, request: .makeSmaller)
      }
    return SessionSnapshot(
      schemaVersion: 1,
      sessionID: sessionID,
      revision: 4,
      eventSequence: 4,
      nextBoundaryOccurrence: 0,
      state: sessionState,
      plan: plan,
      configuration: configuration,
      parkedThoughts: [],
      startedAt: state == .prepared ? nil : wall,
      accumulatedFocusSeconds: 0,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: wall,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )
  }

  private func project(_ snapshot: SessionSnapshot, focusedSeconds: UInt64) -> SessionProjection {
    SessionProjection(
      sourceRevision: snapshot.revision,
      sessionID: snapshot.sessionID,
      state: snapshot.state.kind,
      task: snapshot.plan?.task,
      firstAction: snapshot.plan?.firstAction,
      timingPolicy: snapshot.plan?.timingPolicy.id,
      phase: snapshot.plan?.timingPolicy.phases.first?.id,
      focusedSeconds: focusedSeconds,
      breakSeconds: snapshot.accumulatedBreakSeconds,
      remainingSeconds: nil,
      isPaused: snapshot.state.kind != .focusing,
      isBoundaryAwaitingDecision: snapshot.state.kind == .checkingIn,
      nextScheduledCheckInAt: nil,
      parkedThoughtCount: UInt64(snapshot.parkedThoughts.count),
      lowCognitiveLoadEnabled: snapshot.configuration.lowCognitiveLoadEnabled
    )
  }
}
