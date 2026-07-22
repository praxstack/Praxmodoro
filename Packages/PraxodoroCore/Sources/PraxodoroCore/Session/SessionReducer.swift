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
    case .prepared:
      return reducePrepared(snapshot: snapshot, command: command, context: context)
    case .focusing, .paused, .checkingIn, .breaking, .reentering, .reviewing, .completed,
      .recoveryNeeded:
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

  private static func reducePrepared(
    snapshot: SessionSnapshot,
    command: SessionCommand,
    context: ReductionContext
  ) -> ReductionOutcome {
    switch command.intent {
    case let .updatePrepared(draft):
      return updatePrepared(snapshot: snapshot, draft: draft, context: context)
    case .start:
      return startPrepared(snapshot: snapshot, context: context)
    case .reconcileTime:
      return .noChange(snapshot: snapshot, reason: .observationIrrelevant)
    default:
      return invalidTransition(snapshot: snapshot, intent: command.intent)
    }
  }

  private static func updatePrepared(
    snapshot: SessionSnapshot,
    draft: SessionDraft,
    context: ReductionContext
  ) -> ReductionOutcome {
    guard let currentPlan = snapshot.plan else {
      return invalidTransition(snapshot: snapshot, intent: .updatePrepared(draft))
    }
    let planFields = changedPlanFields(from: currentPlan, to: draft.plan)
    let configurationFields = changedConfigurationFields(
      from: snapshot.configuration,
      to: draft.configuration
    )
    guard !planFields.isEmpty || !configurationFields.isEmpty else {
      return .noChange(snapshot: snapshot, reason: .alreadyInRequestedState)
    }
    guard let occurredAt = canonicalSecond(context.instant.wallNow) else {
      return .failed(snapshot: snapshot, reason: .nonFiniteWallObservation)
    }
    let nextRevision = snapshot.revision.addingReportingOverflow(1)
    guard !nextRevision.overflow else {
      return .failed(snapshot: snapshot, reason: .revisionExhausted)
    }
    let eventCount = UInt64((planFields.isEmpty ? 0 : 1) + (configurationFields.isEmpty ? 0 : 1))
    let remainingCapacity = UInt64.max - snapshot.eventSequence
    guard eventCount <= remainingCapacity else {
      return .failed(
        snapshot: snapshot,
        reason: .eventSequenceExhausted(
          requiredAdditionalEvents: eventCount,
          remainingCapacity: remainingCapacity
        ))
    }
    guard let sessionID = snapshot.sessionID else {
      return invalidTransition(snapshot: snapshot, intent: .updatePrepared(draft))
    }

    var payloads: [SessionEventPayload] = []
    if let fields = SessionPlanFieldChanges(planFields) {
      payloads.append(.planUpdated(fields: fields))
    }
    if let fields = SessionConfigurationFieldChanges(configurationFields) {
      payloads.append(.configurationChanged(fields: fields))
    }
    let events = payloads.enumerated().map { offset, payload in
      SessionEvent(
        sessionID: sessionID,
        sequence: snapshot.eventSequence + UInt64(offset) + 1,
        occurredAt: occurredAt,
        payload: payload
      )
    }
    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision.partialValue,
      eventSequence: snapshot.eventSequence + eventCount,
      nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
      state: snapshot.state,
      plan: draft.plan,
      configuration: draft.configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: snapshot.startedAt,
      accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: occurredAt,
      nextScheduledCheckIn: snapshot.nextScheduledCheckIn,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    return .transition(Reduction(snapshot: candidate, events: events, effects: []))
  }

  private static func startPrepared(
    snapshot: SessionSnapshot,
    context: ReductionContext
  ) -> ReductionOutcome {
    guard let plan = snapshot.plan else {
      return invalidTransition(snapshot: snapshot, intent: .start)
    }
    var invalidFields: Set<SessionPlanField> = []
    if plan.task.isEmpty { invalidFields.insert(.task) }
    if plan.firstAction.isEmpty { invalidFields.insert(.firstAction) }
    guard invalidFields.isEmpty else {
      return .rejected(snapshot: snapshot, reason: .invalidPlan(fields: invalidFields))
    }
    guard canonicalSecond(context.instant.wallNow) != nil else {
      return .failed(snapshot: snapshot, reason: .nonFiniteWallObservation)
    }
    let nextRevision = snapshot.revision.addingReportingOverflow(1)
    guard !nextRevision.overflow else {
      return .failed(snapshot: snapshot, reason: .revisionExhausted)
    }
    let eventCount: UInt64 = 2
    let remainingCapacity = UInt64.max - snapshot.eventSequence
    guard eventCount <= remainingCapacity else {
      return .failed(
        snapshot: snapshot,
        reason: .eventSequenceExhausted(
          requiredAdditionalEvents: eventCount,
          remainingCapacity: remainingCapacity
        ))
    }
    guard let sessionID = snapshot.sessionID, let phase = plan.timingPolicy.phases.first else {
      return invalidTransition(snapshot: snapshot, intent: .start)
    }
    let timing: PausedTiming =
      switch phase.duration {
      case let .timed(seconds): .timed(remaining: seconds)
      case .openEnded: .openEnded
      }
    let cadence: ScheduledCadenceSeed =
      switch snapshot.configuration.checkInSchedule {
      case .manualOnly: .manualOnly
      case let .interval(minutes): .fullInterval(minutes)
      }
    let entry = SessionTimeKernel.materializeLiveEntry(
      .focus(
        sessionID: sessionID,
        targetRevision: nextRevision.partialValue,
        nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
        wallNow: context.instant.wallNow,
        projectionToken: context.generatedProjectionToken,
        phaseID: phase.id,
        timing: timing,
        cadence: cadence
      ))
    let materialization: FocusEntryMaterialization
    switch entry {
    case let .materialized(.focus(value)):
      materialization = value
    case .materialized(.breakState):
      return .failed(snapshot: snapshot, reason: .arithmeticOverflow)
    case let .failure(reason):
      return .failed(snapshot: snapshot, reason: reason)
    }

    let focus = FocusState(
      phase: phase,
      timingAtAnchor: materialization.timingAtAnchor,
      wallAnchor: materialization.wallAnchor,
      phaseEndsAt: materialization.phaseEndsAt,
      elapsedBeforeAnchorSeconds: 0,
      projectionToken: materialization.projectionToken,
      phaseBoundaryToken: materialization.phaseBoundaryToken
    )
    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision.partialValue,
      eventSequence: snapshot.eventSequence + eventCount,
      nextBoundaryOccurrence: materialization.nextBoundaryOccurrence,
      state: .focusing(focus),
      plan: plan,
      configuration: snapshot.configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: materialization.wallAnchor,
      accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: materialization.wallAnchor,
      nextScheduledCheckIn: materialization.scheduledCheckIn,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    let events = [
      SessionEvent(
        sessionID: sessionID,
        sequence: snapshot.eventSequence + 1,
        occurredAt: materialization.wallAnchor,
        payload: .sessionStarted
      ),
      SessionEvent(
        sessionID: sessionID,
        sequence: snapshot.eventSequence + 2,
        occurredAt: materialization.wallAnchor,
        payload: .phaseStarted(phase: phase, endsAt: materialization.phaseEndsAt)
      ),
    ]
    var effects: [SessionEffect] = []
    if let winner = notificationWinner(in: candidate) {
      effects.append(
        .scheduleNotification(
          SessionNotificationRequest(boundaryToken: winner.token, fireAt: winner.dueAt)))
    }
    effects.append(.announceAccessibility(.focusStarted))
    effects.append(.invalidateDisplayProjection(projectionToken: materialization.projectionToken))
    return .transition(Reduction(snapshot: candidate, events: events, effects: effects))
  }

  private static func notificationWinner(
    in snapshot: SessionSnapshot
  ) -> (token: BoundaryToken, dueAt: SessionTimestamp)? {
    var candidates: [(token: BoundaryToken, dueAt: SessionTimestamp, rank: Int)] = []
    if case let .focusing(focus) = snapshot.state,
      let token = focus.phaseBoundaryToken,
      let dueAt = focus.phaseEndsAt
    {
      candidates.append((token, dueAt, 0))
    }
    if let scheduled = snapshot.nextScheduledCheckIn {
      candidates.append((scheduled.token, scheduled.dueAt, 1))
    }
    if case let .breaking(breakState) = snapshot.state,
      let token = breakState.boundaryToken,
      let dueAt = breakState.endsAt
    {
      candidates.append((token, dueAt, 2))
    }
    return candidates.min {
      if $0.dueAt != $1.dueAt { return $0.dueAt.date < $1.dueAt.date }
      if $0.rank != $1.rank { return $0.rank < $1.rank }
      return $0.token.occurrence < $1.token.occurrence
    }.map { ($0.token, $0.dueAt) }
  }

  private static func changedPlanFields(
    from old: SessionPlan,
    to new: SessionPlan
  ) -> Set<SessionPlanField> {
    var fields: Set<SessionPlanField> = []
    if old.task != new.task { fields.insert(.task) }
    if old.firstAction != new.firstAction { fields.insert(.firstAction) }
    if old.capacity != new.capacity { fields.insert(.capacity) }
    if old.timingPolicy != new.timingPolicy { fields.insert(.timingPolicy) }
    return fields
  }

  private static func changedConfigurationFields(
    from old: SessionConfiguration,
    to new: SessionConfiguration
  ) -> Set<SessionConfigurationField> {
    var fields: Set<SessionConfigurationField> = []
    if old.checkInSchedule != new.checkInSchedule { fields.insert(.checkInSchedule) }
    if old.breakSuggestionsEnabled != new.breakSuggestionsEnabled {
      fields.insert(.breakSuggestionsEnabled)
    }
    if old.lowCognitiveLoadEnabled != new.lowCognitiveLoadEnabled {
      fields.insert(.lowCognitiveLoadEnabled)
    }
    if old.reflectionPromptEnabled != new.reflectionPromptEnabled {
      fields.insert(.reflectionPromptEnabled)
    }
    return fields
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
