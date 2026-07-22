import Foundation

/// Pure session state-machine entry point. Each lifecycle family is implemented
/// as a closed dispatch so unlisted state/intent pairs reject deterministically.
public enum SessionReducer {
  public static func reduce(
    snapshot: SessionSnapshot,
    command: SessionCommand,
    context: ReductionContext
  ) -> ReductionOutcome {
    guard command.expectedRevision == snapshot.revision else {
      return .rejected(
        snapshot: snapshot,
        reason: .staleRevision(
          expected: command.expectedRevision,
          actual: snapshot.revision
        ))
    }

    switch snapshot.state {
    case .idle:
      return reduceIdle(snapshot: snapshot, command: command, context: context)
    case .prepared, .focusing, .paused, .checkingIn, .breaking, .reentering, .reviewing,
      .completed, .recoveryNeeded:
      return invalidTransition(snapshot: snapshot, intent: command.intent)
    }
  }

  private static func reduceIdle(
    snapshot: SessionSnapshot,
    command: SessionCommand,
    context: ReductionContext
  ) -> ReductionOutcome {
    switch command.intent {
    case let .prepare(draft):
      return prepare(snapshot: snapshot, draft: draft, context: context)
    case .reconcileTime:
      return .noChange(snapshot: snapshot, reason: .observationIrrelevant)
    default:
      return invalidTransition(snapshot: snapshot, intent: command.intent)
    }
  }

  private static func prepare(
    snapshot: SessionSnapshot,
    draft: SessionDraft,
    context: ReductionContext
  ) -> ReductionOutcome {
    guard let occurredAt = canonicalSecond(context.instant.wallNow) else {
      return .failed(snapshot: snapshot, reason: .nonFiniteWallObservation)
    }
    let nextRevision = snapshot.revision.addingReportingOverflow(1)
    guard !nextRevision.overflow else {
      return .failed(snapshot: snapshot, reason: .revisionExhausted)
    }

    let candidate = SessionSnapshot(
      schemaVersion: 1,
      sessionID: context.generatedSessionID,
      revision: nextRevision.partialValue,
      eventSequence: 1,
      nextBoundaryOccurrence: 0,
      state: .prepared(PreparedState(preparedAt: occurredAt)),
      plan: draft.plan,
      configuration: draft.configuration,
      parkedThoughts: [],
      startedAt: nil,
      accumulatedFocusSeconds: 0,
      accumulatedBreakSeconds: 0,
      lastWallObservationAt: occurredAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: nil
    )
    let event = SessionEvent(
      sessionID: context.generatedSessionID,
      sequence: 1,
      occurredAt: occurredAt,
      payload: .sessionPrepared(
        policy: draft.plan.timingPolicy.id,
        capacitySpecified: draft.plan.capacity != nil
      )
    )
    return .transition(Reduction(snapshot: candidate, events: [event], effects: []))
  }

  private static func invalidTransition(
    snapshot: SessionSnapshot,
    intent: SessionIntent
  ) -> ReductionOutcome {
    .rejected(
      snapshot: snapshot,
      reason: .invalidTransition(state: snapshot.state.kind, intent: intent.kind)
    )
  }
}
