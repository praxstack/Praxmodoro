import Foundation

/// Pure session state-machine entry point. Each lifecycle family is implemented
/// as a closed dispatch so unlisted state/intent pairs reject deterministically.
public enum SessionReducer {
  private enum ReviewEntryRequest {
    case stop(SessionStopChoice)
    case replacement(SessionDraft)

    var stopReason: SessionStopReason {
      switch self {
      case .stop(.completed): .completed
      case .stop(.intentionalStop): .intentionalStop
      case .replacement: .replacedByAnotherSession
      }
    }

    var replacementDraft: SessionDraft? {
      if case let .replacement(draft) = self { return draft }
      return nil
    }

    var firstEvent: SessionEventPayload {
      switch self {
      case .stop: .sessionStopRequested(reason: stopReason)
      case .replacement: .sessionReplacementRequested
      }
    }
  }

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

    if activeSessionConflictState(snapshot.state.kind) {
      switch command.intent {
      case .prepare, .start:
        return .rejected(snapshot: snapshot, reason: .activeSessionExists)
      case let .resolveActiveSessionConflict(choice, replacement):
        return resolveActiveSessionConflict(
          snapshot: snapshot,
          choice: choice,
          replacement: replacement,
          context: context
        )
      default:
        break
      }
    }

    switch snapshot.state {
    case .idle:
      return reduceIdle(snapshot: snapshot, command: command, context: context)
    case .prepared:
      return reducePrepared(snapshot: snapshot, command: command, context: context)
    case .focusing:
      return reduceFocusing(snapshot: snapshot, command: command, context: context)
    case .paused:
      return reducePaused(snapshot: snapshot, command: command, context: context)
    case .checkingIn:
      return reduceCheckingIn(snapshot: snapshot, command: command, context: context)
    case .reentering:
      return reduceReentering(snapshot: snapshot, command: command, context: context)
    case .reviewing:
      return reduceReviewing(snapshot: snapshot, command: command, context: context)
    case .breaking:
      return reduceBreaking(snapshot: snapshot, command: command, context: context)
    case .completed, .recoveryNeeded:
      return invalidTransition(snapshot: snapshot, intent: command.intent)
    }
  }

  private static func activeSessionConflictState(_ state: SessionStateKind) -> Bool {
    switch state {
    case .focusing, .paused, .checkingIn, .breaking, .reentering, .reviewing, .recoveryNeeded:
      true
    case .idle, .prepared, .completed:
      false
    }
  }

  private static func resolveActiveSessionConflict(
    snapshot: SessionSnapshot,
    choice: ActiveSessionConflictChoice,
    replacement: SessionDraft?,
    context: ReductionContext
  ) -> ReductionOutcome {
    switch choice {
    case .resumeCurrent:
      guard replacement == nil else {
        return .rejected(snapshot: snapshot, reason: .replacementDraftNotAllowed)
      }
      return .noChange(snapshot: snapshot, reason: .resumeCurrentSelected)
    case .cancel:
      guard replacement == nil else {
        return .rejected(snapshot: snapshot, reason: .replacementDraftNotAllowed)
      }
      return .noChange(snapshot: snapshot, reason: .conflictCancelled)
    case .replaceAndReview:
      guard let replacement else {
        return .rejected(snapshot: snapshot, reason: .replacementDraftRequired)
      }
      var invalidFields: Set<SessionPlanField> = []
      if replacement.plan.task.isEmpty { invalidFields.insert(.task) }
      if replacement.plan.firstAction.isEmpty { invalidFields.insert(.firstAction) }
      guard invalidFields.isEmpty else {
        return .rejected(snapshot: snapshot, reason: .invalidPlan(fields: invalidFields))
      }
      if case .reviewing = snapshot.state {
        return replacePendingDraftInReview(
          snapshot: snapshot,
          replacement: replacement,
          context: context
        )
      }
      if snapshot.state.kind == .focusing || snapshot.state.kind == .breaking {
        return enterReviewFromLive(
          snapshot: snapshot,
          request: .replacement(replacement),
          context: context
        )
      }
      return enterReviewFromNonLive(
        snapshot: snapshot,
        request: .replacement(replacement),
        context: context
      )
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
    if let configuration = requestedConfiguration(
      for: command.intent,
      current: snapshot.configuration
    ) {
      guard let plan = snapshot.plan else {
        return invalidTransition(snapshot: snapshot, intent: command.intent)
      }
      return updatePrepared(
        snapshot: snapshot,
        draft: SessionDraft(plan: plan, configuration: configuration),
        context: context
      )
    }
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
    return .transition(
      Reduction(
        snapshot: candidate,
        events: events,
        effects: [.invalidateDisplayProjection(projectionToken: nil)]
      ))
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

  private static func reduceFocusing(
    snapshot: SessionSnapshot,
    command: SessionCommand,
    context: ReductionContext
  ) -> ReductionOutcome {
    if case let .stop(choice) = command.intent {
      return enterReviewFromLive(
        snapshot: snapshot,
        request: .stop(choice),
        context: context
      )
    }
    if let configuration = requestedConfiguration(
      for: command.intent,
      current: snapshot.configuration
    ) {
      return updateLiveFocusConfiguration(
        snapshot: snapshot,
        intent: command.intent,
        configuration: configuration,
        context: context
      )
    }
    switch command.intent {
    case .pause:
      return pauseFocus(snapshot: snapshot, command: command, context: context)
    default:
      return invalidTransition(snapshot: snapshot, intent: command.intent)
    }
  }

  private static func updateLiveFocusConfiguration(
    snapshot: SessionSnapshot,
    intent: SessionIntent,
    configuration: SessionConfiguration,
    context: ReductionContext
  ) -> ReductionOutcome {
    let timingDecision = SessionTimeKernel.reconcileLive(
      snapshot: snapshot,
      instant: context.instant
    )
    let timing: NormalizedLiveTiming
    switch timingDecision {
    case let .normalized(value):
      timing = value
    case let .failure(reason):
      return .failed(snapshot: snapshot, reason: reason)
    case let .recovery(reason):
      return focusRecoveryTransition(
        snapshot: snapshot,
        reason: reason,
        context: context
      )
    }
    let admission = SessionTimeKernel.admitBoundary(
      snapshot: snapshot,
      timing: timing,
      observedToken: nil
    )
    if case let .winner(winner) = admission {
      return focusBoundaryTransition(snapshot: snapshot, timing: timing, winner: winner)
    }
    if case let .recovery(reason) = admission {
      return focusRecoveryTransition(
        snapshot: snapshot,
        reason: reason,
        context: context
      )
    }
    guard admission == .noneDue else {
      return invalidTransition(snapshot: snapshot, intent: intent)
    }
    let fields = changedConfigurationFields(
      from: snapshot.configuration,
      to: configuration
    )
    guard let changes = SessionConfigurationFieldChanges(fields) else {
      return .noChange(snapshot: snapshot, reason: .alreadyInRequestedState)
    }
    guard case let .focusing(focus) = snapshot.state,
      let materialization = timing.liveCommitMaterialization,
      let sessionID = snapshot.sessionID
    else {
      return .failed(snapshot: snapshot, reason: .arithmeticOverflow)
    }
    let nextRevision = snapshot.revision.addingReportingOverflow(1)
    guard !nextRevision.overflow else {
      return .failed(snapshot: snapshot, reason: .revisionExhausted)
    }
    let eventCount: UInt64 = materialization.adjustment == nil ? 1 : 2
    let remainingCapacity = UInt64.max - snapshot.eventSequence
    guard eventCount <= remainingCapacity else {
      return .failed(
        snapshot: snapshot,
        reason: .eventSequenceExhausted(
          requiredAdditionalEvents: eventCount,
          remainingCapacity: remainingCapacity
        ))
    }

    let scheduleChanged = fields.contains(.checkInSchedule)
    let scheduled: ScheduledCheckInBoundary?
    let nextBoundaryOccurrence: UInt64
    if scheduleChanged {
      switch SessionTimeKernel.replaceScheduledCheckIn(
        ScheduledCheckInReplacementRequest(
          sessionID: sessionID,
          targetRevision: nextRevision.partialValue,
          nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
          wallAnchor: materialization.wallAnchor,
          schedule: configuration.checkInSchedule
        ))
      {
      case let .materialized(boundary, occurrence):
        scheduled = boundary
        nextBoundaryOccurrence = occurrence
      case let .failure(reason):
        return .failed(snapshot: snapshot, reason: reason)
      }
    } else {
      if let previous = snapshot.nextScheduledCheckIn,
        let dueAt = materialization.scheduledCheckInAt,
        let remaining = materialization.scheduledCheckInRemaining
      {
        scheduled = ScheduledCheckInBoundary(
          token: previous.token,
          dueAt: dueAt,
          trustedRemaining: remaining
        )
      } else {
        scheduled = nil
      }
      nextBoundaryOccurrence = snapshot.nextBoundaryOccurrence
    }

    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision.partialValue,
      eventSequence: snapshot.eventSequence + eventCount,
      nextBoundaryOccurrence: nextBoundaryOccurrence,
      state: .focusing(
        FocusState(
          phase: focus.phase,
          timingAtAnchor: materialization.timingAtAnchor,
          wallAnchor: materialization.wallAnchor,
          phaseEndsAt: materialization.phaseOrBreakDeadline,
          elapsedBeforeAnchorSeconds: materialization.elapsedBeforeAnchorSeconds,
          projectionToken: focus.projectionToken,
          phaseBoundaryToken: focus.phaseBoundaryToken
        )),
      plan: snapshot.plan,
      configuration: configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: snapshot.startedAt,
      accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: timing.observedWallNow,
      nextScheduledCheckIn: scheduled,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    var payloads: [SessionEventPayload] = []
    if let adjustment = materialization.adjustment {
      payloads.append(.clockAdjusted(adjustment))
    }
    payloads.append(.configurationChanged(fields: changes))
    let events = payloads.enumerated().map { offset, payload in
      SessionEvent(
        sessionID: sessionID,
        sequence: snapshot.eventSequence + UInt64(offset) + 1,
        occurredAt: timing.observedWallNow,
        payload: payload
      )
    }
    var effects = notificationReplacementEffects(from: snapshot, to: candidate)
    effects.append(.invalidateDisplayProjection(projectionToken: focus.projectionToken))
    return .transition(Reduction(snapshot: candidate, events: events, effects: effects))
  }

  private static func focusRecoveryTransition(
    snapshot: SessionSnapshot,
    reason: RecoveryReason,
    context: ReductionContext
  ) -> ReductionOutcome {
    guard case let .focusing(focus) = snapshot.state,
      let sessionID = snapshot.sessionID,
      let observedAt = canonicalSecond(context.instant.wallNow)
    else {
      return .failed(snapshot: snapshot, reason: .nonFiniteWallObservation)
    }
    let nextRevision = snapshot.revision.addingReportingOverflow(1)
    guard !nextRevision.overflow else {
      return .failed(snapshot: snapshot, reason: .revisionExhausted)
    }
    guard snapshot.eventSequence < UInt64.max else {
      return .failed(
        snapshot: snapshot,
        reason: .eventSequenceExhausted(
          requiredAdditionalEvents: 1,
          remainingCapacity: 0
        ))
    }
    let accumulated = snapshot.accumulatedFocusSeconds.addingReportingOverflow(
      focus.elapsedBeforeAnchorSeconds)
    guard !accumulated.overflow else {
      return .failed(snapshot: snapshot, reason: .arithmeticOverflow)
    }
    let trustworthy = SuspendedFocusState(
      phase: focus.phase,
      timing: focus.timingAtAnchor,
      resumeDisposition: .focusing,
      scheduledCheckInRemaining: snapshot.nextScheduledCheckIn?.trustedRemaining
    )
    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision.partialValue,
      eventSequence: snapshot.eventSequence + 1,
      nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
      state: .recoveryNeeded(
        RecoveryState(
          reason: reason,
          lastTrustworthyState: .focus(trustworthy),
          safeChoices: Set(ClockRecoveryChoice.allCases)
        )),
      plan: snapshot.plan,
      configuration: snapshot.configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: snapshot.startedAt,
      accumulatedFocusSeconds: accumulated.partialValue,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: observedAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    let event = SessionEvent(
      sessionID: sessionID,
      sequence: snapshot.eventSequence + 1,
      occurredAt: observedAt,
      payload: .clockRecoveryNeeded(reason: reason)
    )
    var effects: [SessionEffect] = []
    if let previousWinner = notificationWinner(in: snapshot) {
      effects.append(
        .cancelNotification(SessionNotificationID(boundaryToken: previousWinner.token)))
    }
    effects.append(.invalidateDisplayProjection(projectionToken: nil))
    return .transition(Reduction(snapshot: candidate, events: [event], effects: effects))
  }

  private static func notificationReplacementEffects(
    from previous: SessionSnapshot,
    to candidate: SessionSnapshot
  ) -> [SessionEffect] {
    let oldWinner = notificationWinner(in: previous)
    let newWinner = notificationWinner(in: candidate)
    let unchanged = oldWinner?.token == newWinner?.token && oldWinner?.dueAt == newWinner?.dueAt
    guard !unchanged else { return [] }
    var effects: [SessionEffect] = []
    if let oldWinner {
      effects.append(
        .cancelNotification(SessionNotificationID(boundaryToken: oldWinner.token)))
    }
    if let newWinner {
      effects.append(
        .scheduleNotification(
          SessionNotificationRequest(
            boundaryToken: newWinner.token,
            fireAt: newWinner.dueAt
          )))
    }
    return effects
  }

  private static func reduceBreaking(
    snapshot: SessionSnapshot,
    command: SessionCommand,
    context: ReductionContext
  ) -> ReductionOutcome {
    if case let .stop(choice) = command.intent {
      return enterReviewFromLive(
        snapshot: snapshot,
        request: .stop(choice),
        context: context
      )
    }
    if case .endBreak = command.intent {
      return endLiveBreak(snapshot: snapshot, intent: command.intent, context: context)
    }
    guard
      let configuration = requestedConfiguration(
        for: command.intent,
        current: snapshot.configuration
      )
    else {
      return invalidTransition(snapshot: snapshot, intent: command.intent)
    }
    return updateLiveBreakConfiguration(
      snapshot: snapshot,
      intent: command.intent,
      configuration: configuration,
      context: context
    )
  }

  private static func endLiveBreak(
    snapshot: SessionSnapshot,
    intent: SessionIntent,
    context: ReductionContext
  ) -> ReductionOutcome {
    let timingDecision = SessionTimeKernel.reconcileLive(
      snapshot: snapshot,
      instant: context.instant
    )
    let timing: NormalizedLiveTiming
    switch timingDecision {
    case let .normalized(value):
      timing = value
    case let .failure(reason):
      return .failed(snapshot: snapshot, reason: reason)
    case let .recovery(reason):
      return breakRecoveryTransition(snapshot: snapshot, reason: reason, context: context)
    }
    let admission = SessionTimeKernel.admitBoundary(
      snapshot: snapshot,
      timing: timing,
      observedToken: nil
    )
    if case let .winner(winner) = admission {
      return breakBoundaryTransition(snapshot: snapshot, timing: timing, winner: winner)
    }
    if case let .recovery(reason) = admission {
      return breakRecoveryTransition(snapshot: snapshot, reason: reason, context: context)
    }
    guard admission == .noneDue,
      case let .breaking(breakState) = snapshot.state,
      case let .breakState(accumulatedBreakSeconds) = timing.nonBoundaryExitMaterialization,
      let sessionID = snapshot.sessionID
    else {
      return invalidTransition(snapshot: snapshot, intent: intent)
    }
    let nextRevision = snapshot.revision.addingReportingOverflow(1)
    guard !nextRevision.overflow else {
      return .failed(snapshot: snapshot, reason: .revisionExhausted)
    }
    let eventCount = UInt64(2 + (timing.admissionAdjustment == nil ? 0 : 1))
    let remainingCapacity = UInt64.max - snapshot.eventSequence
    guard eventCount <= remainingCapacity else {
      return .failed(
        snapshot: snapshot,
        reason: .eventSequenceExhausted(
          requiredAdditionalEvents: eventCount,
          remainingCapacity: remainingCapacity
        ))
    }
    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision.partialValue,
      eventSequence: snapshot.eventSequence + eventCount,
      nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
      state: .reentering(
        ReentryState(
          resumeTarget: breakState.resumeTarget,
          proposedAction: breakState.proposedAction,
          enteredAt: timing.expectedWallNow
        )),
      plan: snapshot.plan,
      configuration: snapshot.configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: snapshot.startedAt,
      accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: accumulatedBreakSeconds,
      lastWallObservationAt: timing.observedWallNow,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    var payloads: [SessionEventPayload] = []
    if let adjustment = timing.admissionAdjustment {
      payloads.append(.clockAdjusted(adjustment))
    }
    payloads.append(.breakEnded)
    payloads.append(.reentryPresented)
    let events = payloads.enumerated().map { offset, payload in
      SessionEvent(
        sessionID: sessionID,
        sequence: snapshot.eventSequence + UInt64(offset) + 1,
        occurredAt: timing.observedWallNow,
        payload: payload
      )
    }
    var effects = notificationReplacementEffects(from: snapshot, to: candidate)
    effects.append(.announceAccessibility(.reentryPresented))
    effects.append(.invalidateDisplayProjection(projectionToken: nil))
    return .transition(Reduction(snapshot: candidate, events: events, effects: effects))
  }

  private static func updateLiveBreakConfiguration(
    snapshot: SessionSnapshot,
    intent: SessionIntent,
    configuration: SessionConfiguration,
    context: ReductionContext
  ) -> ReductionOutcome {
    let timingDecision = SessionTimeKernel.reconcileLive(
      snapshot: snapshot,
      instant: context.instant
    )
    let timing: NormalizedLiveTiming
    switch timingDecision {
    case let .normalized(value):
      timing = value
    case let .failure(reason):
      return .failed(snapshot: snapshot, reason: reason)
    case let .recovery(reason):
      return breakRecoveryTransition(snapshot: snapshot, reason: reason, context: context)
    }
    let admission = SessionTimeKernel.admitBoundary(
      snapshot: snapshot,
      timing: timing,
      observedToken: nil
    )
    if case let .winner(winner) = admission {
      return breakBoundaryTransition(snapshot: snapshot, timing: timing, winner: winner)
    }
    if case let .recovery(reason) = admission {
      return breakRecoveryTransition(snapshot: snapshot, reason: reason, context: context)
    }
    guard admission == .noneDue else {
      return invalidTransition(snapshot: snapshot, intent: intent)
    }
    let fields = changedConfigurationFields(
      from: snapshot.configuration,
      to: configuration
    )
    guard let changes = SessionConfigurationFieldChanges(fields) else {
      return .noChange(snapshot: snapshot, reason: .alreadyInRequestedState)
    }
    guard case let .breaking(breakState) = snapshot.state,
      let materialization = timing.liveCommitMaterialization,
      let sessionID = snapshot.sessionID
    else {
      return .failed(snapshot: snapshot, reason: .arithmeticOverflow)
    }
    let nextRevision = snapshot.revision.addingReportingOverflow(1)
    guard !nextRevision.overflow else {
      return .failed(snapshot: snapshot, reason: .revisionExhausted)
    }
    let eventCount: UInt64 = materialization.adjustment == nil ? 1 : 2
    let remainingCapacity = UInt64.max - snapshot.eventSequence
    guard eventCount <= remainingCapacity else {
      return .failed(
        snapshot: snapshot,
        reason: .eventSequenceExhausted(
          requiredAdditionalEvents: eventCount,
          remainingCapacity: remainingCapacity
        ))
    }
    let target = breakState.resumeTarget
    let cadence =
      fields.contains(.checkInSchedule)
      ? SessionTimeKernel.materializeScheduledRemainder(configuration.checkInSchedule)
      : target.scheduledCheckInRemaining
    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision.partialValue,
      eventSequence: snapshot.eventSequence + eventCount,
      nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
      state: .breaking(
        BreakState(
          choice: breakState.choice,
          timingAtAnchor: materialization.timingAtAnchor,
          wallAnchor: materialization.wallAnchor,
          endsAt: materialization.phaseOrBreakDeadline,
          elapsedBeforeAnchorSeconds: materialization.elapsedBeforeAnchorSeconds,
          projectionToken: breakState.projectionToken,
          boundaryToken: breakState.boundaryToken,
          resumeTarget: SuspendedFocusState(
            phase: target.phase,
            timing: target.timing,
            resumeDisposition: target.resumeDisposition,
            scheduledCheckInRemaining: cadence
          ),
          proposedAction: breakState.proposedAction
        )),
      plan: snapshot.plan,
      configuration: configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: snapshot.startedAt,
      accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: timing.observedWallNow,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    var payloads: [SessionEventPayload] = []
    if let adjustment = materialization.adjustment {
      payloads.append(.clockAdjusted(adjustment))
    }
    payloads.append(.configurationChanged(fields: changes))
    let events = payloads.enumerated().map { offset, payload in
      SessionEvent(
        sessionID: sessionID,
        sequence: snapshot.eventSequence + UInt64(offset) + 1,
        occurredAt: timing.observedWallNow,
        payload: payload
      )
    }
    var effects = notificationReplacementEffects(from: snapshot, to: candidate)
    effects.append(.invalidateDisplayProjection(projectionToken: breakState.projectionToken))
    return .transition(Reduction(snapshot: candidate, events: events, effects: effects))
  }

  private static func breakBoundaryTransition(
    snapshot: SessionSnapshot,
    timing: NormalizedLiveTiming,
    winner: BoundaryWinnerDecision
  ) -> ReductionOutcome {
    guard case let .breaking(breakState) = snapshot.state,
      case let .breakEnd(accumulatedBreakSeconds) = winner.exitMaterialization,
      winner.token.kind == .breakEnd,
      let sessionID = snapshot.sessionID
    else {
      return .failed(snapshot: snapshot, reason: .arithmeticOverflow)
    }
    let nextRevision = snapshot.revision.addingReportingOverflow(1)
    guard !nextRevision.overflow else {
      return .failed(snapshot: snapshot, reason: .revisionExhausted)
    }
    let eventCount = UInt64(2 + (timing.admissionAdjustment == nil ? 0 : 1))
    let remainingCapacity = UInt64.max - snapshot.eventSequence
    guard eventCount <= remainingCapacity else {
      return .failed(
        snapshot: snapshot,
        reason: .eventSequenceExhausted(
          requiredAdditionalEvents: eventCount,
          remainingCapacity: remainingCapacity
        ))
    }
    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision.partialValue,
      eventSequence: snapshot.eventSequence + eventCount,
      nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
      state: .reentering(
        ReentryState(
          resumeTarget: breakState.resumeTarget,
          proposedAction: breakState.proposedAction,
          enteredAt: timing.expectedWallNow
        )),
      plan: snapshot.plan,
      configuration: snapshot.configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: snapshot.startedAt,
      accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: accumulatedBreakSeconds,
      lastWallObservationAt: timing.observedWallNow,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: winner.token
    )
    var payloads: [SessionEventPayload] = []
    if let adjustment = timing.admissionAdjustment {
      payloads.append(.clockAdjusted(adjustment))
    }
    payloads.append(.breakEnded)
    payloads.append(.reentryPresented)
    let events = payloads.enumerated().map { offset, payload in
      SessionEvent(
        sessionID: sessionID,
        sequence: snapshot.eventSequence + UInt64(offset) + 1,
        occurredAt: timing.observedWallNow,
        payload: payload
      )
    }
    var effects: [SessionEffect] = []
    if let previousWinner = notificationWinner(in: snapshot) {
      effects.append(
        .cancelNotification(SessionNotificationID(boundaryToken: previousWinner.token)))
    }
    effects.append(.playSound(.breakComplete))
    effects.append(.announceAccessibility(.reentryPresented))
    effects.append(.invalidateDisplayProjection(projectionToken: nil))
    return .transition(Reduction(snapshot: candidate, events: events, effects: effects))
  }

  private static func breakRecoveryTransition(
    snapshot: SessionSnapshot,
    reason: RecoveryReason,
    context: ReductionContext
  ) -> ReductionOutcome {
    guard case let .breaking(breakState) = snapshot.state,
      let sessionID = snapshot.sessionID,
      let observedAt = canonicalSecond(context.instant.wallNow)
    else {
      return .failed(snapshot: snapshot, reason: .nonFiniteWallObservation)
    }
    let nextRevision = snapshot.revision.addingReportingOverflow(1)
    guard !nextRevision.overflow else {
      return .failed(snapshot: snapshot, reason: .revisionExhausted)
    }
    guard snapshot.eventSequence < UInt64.max else {
      return .failed(
        snapshot: snapshot,
        reason: .eventSequenceExhausted(
          requiredAdditionalEvents: 1,
          remainingCapacity: 0
        ))
    }
    let accumulated = snapshot.accumulatedBreakSeconds.addingReportingOverflow(
      breakState.elapsedBeforeAnchorSeconds)
    guard !accumulated.overflow else {
      return .failed(snapshot: snapshot, reason: .arithmeticOverflow)
    }
    let trustworthy = SuspendedBreakState(
      choice: breakState.choice,
      timing: breakState.timingAtAnchor,
      resumeTarget: breakState.resumeTarget,
      proposedAction: breakState.proposedAction
    )
    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision.partialValue,
      eventSequence: snapshot.eventSequence + 1,
      nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
      state: .recoveryNeeded(
        RecoveryState(
          reason: reason,
          lastTrustworthyState: .breakState(trustworthy),
          safeChoices: Set(ClockRecoveryChoice.allCases)
        )),
      plan: snapshot.plan,
      configuration: snapshot.configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: snapshot.startedAt,
      accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: accumulated.partialValue,
      lastWallObservationAt: observedAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    let event = SessionEvent(
      sessionID: sessionID,
      sequence: snapshot.eventSequence + 1,
      occurredAt: observedAt,
      payload: .clockRecoveryNeeded(reason: reason)
    )
    var effects: [SessionEffect] = []
    if let previousWinner = notificationWinner(in: snapshot) {
      effects.append(
        .cancelNotification(SessionNotificationID(boundaryToken: previousWinner.token)))
    }
    effects.append(.invalidateDisplayProjection(projectionToken: nil))
    return .transition(Reduction(snapshot: candidate, events: [event], effects: effects))
  }

  private static func pauseFocus(
    snapshot: SessionSnapshot,
    command: SessionCommand,
    context: ReductionContext
  ) -> ReductionOutcome {
    let timingDecision = SessionTimeKernel.reconcileLive(
      snapshot: snapshot,
      instant: context.instant
    )
    let timing: NormalizedLiveTiming
    switch timingDecision {
    case let .normalized(value):
      timing = value
    case let .failure(reason):
      return .failed(snapshot: snapshot, reason: reason)
    case .recovery:
      return invalidTransition(snapshot: snapshot, intent: command.intent)
    }
    let admission = SessionTimeKernel.admitBoundary(
      snapshot: snapshot,
      timing: timing,
      observedToken: nil
    )
    if case let .winner(winner) = admission {
      return focusBoundaryTransition(snapshot: snapshot, timing: timing, winner: winner)
    }
    guard admission == .noneDue else {
      return invalidTransition(snapshot: snapshot, intent: command.intent)
    }
    guard case let .focusing(focus) = snapshot.state,
      case let .focus(accumulatedFocusSeconds, suspendedTiming, scheduledRemaining) =
        timing.nonBoundaryExitMaterialization,
      let sessionID = snapshot.sessionID
    else {
      return .failed(snapshot: snapshot, reason: .arithmeticOverflow)
    }
    let nextRevision = snapshot.revision.addingReportingOverflow(1)
    guard !nextRevision.overflow else {
      return .failed(snapshot: snapshot, reason: .revisionExhausted)
    }
    let remainingCapacity = UInt64.max - snapshot.eventSequence
    guard remainingCapacity >= 1 else {
      return .failed(
        snapshot: snapshot,
        reason: .eventSequenceExhausted(
          requiredAdditionalEvents: 1,
          remainingCapacity: remainingCapacity
        ))
    }
    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision.partialValue,
      eventSequence: snapshot.eventSequence + 1,
      nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
      state: .paused(
        PausedState(
          phase: focus.phase,
          timing: suspendedTiming,
          pausedAt: timing.expectedWallNow,
          scheduledCheckInRemaining: scheduledRemaining
        )),
      plan: snapshot.plan,
      configuration: snapshot.configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: snapshot.startedAt,
      accumulatedFocusSeconds: accumulatedFocusSeconds,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: timing.observedWallNow,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    let event = SessionEvent(
      sessionID: sessionID,
      sequence: snapshot.eventSequence + 1,
      occurredAt: timing.observedWallNow,
      payload: .phasePaused(timing: suspendedTiming)
    )
    var effects: [SessionEffect] = []
    if let previousWinner = notificationWinner(in: snapshot) {
      effects.append(
        .cancelNotification(SessionNotificationID(boundaryToken: previousWinner.token)))
    }
    effects.append(.invalidateDisplayProjection(projectionToken: nil))
    return .transition(Reduction(snapshot: candidate, events: [event], effects: effects))
  }

  private static func focusBoundaryTransition(
    snapshot: SessionSnapshot,
    timing: NormalizedLiveTiming,
    winner: BoundaryWinnerDecision
  ) -> ReductionOutcome {
    guard case let .focusing(focus) = snapshot.state,
      let sessionID = snapshot.sessionID
    else {
      return .failed(snapshot: snapshot, reason: .arithmeticOverflow)
    }
    let checkingIn: CheckInState
    let accumulatedFocusSeconds: UInt64
    let payloads: [SessionEventPayload]
    switch winner.exitMaterialization {
    case let .scheduledCheckIn(total, suspendedTiming):
      guard winner.token.kind == .scheduledCheckIn else {
        return .failed(snapshot: snapshot, reason: .arithmeticOverflow)
      }
      accumulatedFocusSeconds = total
      checkingIn = CheckInState(
        suspended: SuspendedFocusState(
          phase: focus.phase,
          timing: suspendedTiming,
          resumeDisposition: .focusing,
          scheduledCheckInRemaining: nil
        ),
        trigger: .scheduled(winner.token),
        continuation: .resumeSuspended,
        phaseBoundaryScheduledCheckInRemaining: nil
      )
      payloads = [
        .checkInOpened(trigger: .scheduled(winner.token), continuation: .resumeSuspended)
      ]
    case let .phase(total):
      guard winner.token.kind == .phase,
        let plan = snapshot.plan,
        let continuation = phaseContinuation(after: focus.phase, in: plan.timingPolicy)
      else {
        return .failed(snapshot: snapshot, reason: .arithmeticOverflow)
      }
      let cadenceRemainder: CheckInRemainingSeconds? =
        switch winner.scheduledCadence {
        case let .preserve(remaining): remaining
        case .manualOnly, .resetAfterPhaseCollision, .resetAfterSupersededScheduledOccurrence: nil
        case .resetAfterScheduledOccurrence, .notApplicable: nil
        }
      accumulatedFocusSeconds = total
      checkingIn = CheckInState(
        suspended: nil,
        trigger: .phaseBoundary(winner.token),
        continuation: .startPhase(continuation),
        phaseBoundaryScheduledCheckInRemaining: cadenceRemainder
      )
      payloads = [
        .phaseElapsed(token: winner.token),
        .checkInOpened(
          trigger: .phaseBoundary(winner.token), continuation: .startPhase(continuation)),
      ]
    case .breakEnd:
      return .failed(snapshot: snapshot, reason: .arithmeticOverflow)
    }
    let nextRevision = snapshot.revision.addingReportingOverflow(1)
    guard !nextRevision.overflow else {
      return .failed(snapshot: snapshot, reason: .revisionExhausted)
    }
    let eventCount = UInt64(payloads.count + (timing.admissionAdjustment == nil ? 0 : 1))
    let remainingCapacity = UInt64.max - snapshot.eventSequence
    guard eventCount <= remainingCapacity else {
      return .failed(
        snapshot: snapshot,
        reason: .eventSequenceExhausted(
          requiredAdditionalEvents: eventCount,
          remainingCapacity: remainingCapacity
        ))
    }
    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision.partialValue,
      eventSequence: snapshot.eventSequence + eventCount,
      nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
      state: .checkingIn(checkingIn),
      plan: snapshot.plan,
      configuration: snapshot.configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: snapshot.startedAt,
      accumulatedFocusSeconds: accumulatedFocusSeconds,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: timing.observedWallNow,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: winner.token
    )
    var orderedPayloads: [SessionEventPayload] = []
    if let adjustment = timing.admissionAdjustment {
      orderedPayloads.append(.clockAdjusted(adjustment))
    }
    orderedPayloads.append(contentsOf: payloads)
    let events = orderedPayloads.enumerated().map { offset, payload in
      SessionEvent(
        sessionID: sessionID,
        sequence: snapshot.eventSequence + UInt64(offset) + 1,
        occurredAt: timing.observedWallNow,
        payload: payload
      )
    }
    var effects: [SessionEffect] = []
    if let previousWinner = notificationWinner(in: snapshot) {
      effects.append(
        .cancelNotification(SessionNotificationID(boundaryToken: previousWinner.token)))
    }
    if winner.token.kind == .phase {
      effects.append(.playSound(.gentleBoundary))
      effects.append(.playHaptic(.gentleBoundary))
    }
    effects.append(.announceAccessibility(.checkInPresented))
    effects.append(.invalidateDisplayProjection(projectionToken: nil))
    return .transition(Reduction(snapshot: candidate, events: events, effects: effects))
  }

  private static func phaseContinuation(
    after elapsed: SessionPhaseDescriptor,
    in policy: TimingPolicy
  ) -> SessionPhaseDescriptor? {
    guard case .timed = elapsed.duration,
      let index = policy.phases.firstIndex(where: { $0.id == elapsed.id })
    else { return nil }
    let next = policy.phases.index(after: index)
    return next < policy.phases.endIndex ? policy.phases[next] : elapsed
  }

  private static func reducePaused(
    snapshot: SessionSnapshot,
    command: SessionCommand,
    context: ReductionContext
  ) -> ReductionOutcome {
    if let configuration = requestedConfiguration(
      for: command.intent,
      current: snapshot.configuration
    ) {
      return updatePausedConfiguration(
        snapshot: snapshot,
        intent: command.intent,
        configuration: configuration,
        context: context
      )
    }
    switch command.intent {
    case let .stop(choice):
      return enterReviewFromNonLive(
        snapshot: snapshot,
        request: .stop(choice),
        context: context
      )
    case .resume:
      return resumePaused(snapshot: snapshot, context: context)
    case let .openCheckIn(trigger):
      return openCheckInFromPaused(
        snapshot: snapshot,
        trigger: trigger,
        context: context
      )
    case let .requestBreak(choice):
      return startBreakFromPaused(
        snapshot: snapshot,
        choice: choice,
        context: context
      )
    case let .parkThought(text):
      return parkThoughtInNonLiveState(
        snapshot: snapshot,
        text: text,
        context: context
      )
    case .reconcileTime:
      return .noChange(snapshot: snapshot, reason: .observationIrrelevant)
    default:
      return invalidTransition(snapshot: snapshot, intent: command.intent)
    }
  }

  private static func updatePausedConfiguration(
    snapshot: SessionSnapshot,
    intent: SessionIntent,
    configuration: SessionConfiguration,
    context: ReductionContext
  ) -> ReductionOutcome {
    guard case let .paused(paused) = snapshot.state,
      let sessionID = snapshot.sessionID
    else {
      return invalidTransition(snapshot: snapshot, intent: intent)
    }
    let fields = changedConfigurationFields(
      from: snapshot.configuration,
      to: configuration
    )
    guard let changes = SessionConfigurationFieldChanges(fields) else {
      return .noChange(snapshot: snapshot, reason: .alreadyInRequestedState)
    }
    guard let observedAt = canonicalSecond(context.instant.wallNow) else {
      return .failed(snapshot: snapshot, reason: .nonFiniteWallObservation)
    }
    let nextRevision = snapshot.revision.addingReportingOverflow(1)
    guard !nextRevision.overflow else {
      return .failed(snapshot: snapshot, reason: .revisionExhausted)
    }
    let remainingCapacity = UInt64.max - snapshot.eventSequence
    guard remainingCapacity >= 1 else {
      return .failed(
        snapshot: snapshot,
        reason: .eventSequenceExhausted(
          requiredAdditionalEvents: 1,
          remainingCapacity: remainingCapacity
        ))
    }
    let cadence =
      fields.contains(.checkInSchedule)
      ? SessionTimeKernel.materializeScheduledRemainder(configuration.checkInSchedule)
      : paused.scheduledCheckInRemaining
    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision.partialValue,
      eventSequence: snapshot.eventSequence + 1,
      nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
      state: .paused(
        PausedState(
          phase: paused.phase,
          timing: paused.timing,
          pausedAt: paused.pausedAt,
          scheduledCheckInRemaining: cadence
        )),
      plan: snapshot.plan,
      configuration: configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: snapshot.startedAt,
      accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: observedAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    let event = SessionEvent(
      sessionID: sessionID,
      sequence: snapshot.eventSequence + 1,
      occurredAt: observedAt,
      payload: .configurationChanged(fields: changes)
    )
    return .transition(
      Reduction(
        snapshot: candidate,
        events: [event],
        effects: [.invalidateDisplayProjection(projectionToken: nil)]
      ))
  }

  private static func openCheckInFromPaused(
    snapshot: SessionSnapshot,
    trigger: CheckInTrigger,
    context: ReductionContext
  ) -> ReductionOutcome {
    guard trigger == .manual || trigger == .pauseOffer else {
      return invalidTransition(snapshot: snapshot, intent: .openCheckIn(trigger))
    }
    guard case let .paused(paused) = snapshot.state,
      let sessionID = snapshot.sessionID
    else {
      return invalidTransition(snapshot: snapshot, intent: .openCheckIn(trigger))
    }
    guard let observedAt = canonicalSecond(context.instant.wallNow) else {
      return .failed(snapshot: snapshot, reason: .nonFiniteWallObservation)
    }
    let nextRevision = snapshot.revision.addingReportingOverflow(1)
    guard !nextRevision.overflow else {
      return .failed(snapshot: snapshot, reason: .revisionExhausted)
    }
    let remainingCapacity = UInt64.max - snapshot.eventSequence
    guard remainingCapacity >= 1 else {
      return .failed(
        snapshot: snapshot,
        reason: .eventSequenceExhausted(
          requiredAdditionalEvents: 1,
          remainingCapacity: remainingCapacity
        ))
    }
    let suspended = SuspendedFocusState(
      phase: paused.phase,
      timing: paused.timing,
      resumeDisposition: .paused,
      scheduledCheckInRemaining: paused.scheduledCheckInRemaining
    )
    let continuation = CheckInContinuation.resumeSuspended
    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision.partialValue,
      eventSequence: snapshot.eventSequence + 1,
      nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
      state: .checkingIn(
        CheckInState(
          suspended: suspended,
          trigger: trigger,
          continuation: continuation,
          phaseBoundaryScheduledCheckInRemaining: nil
        )),
      plan: snapshot.plan,
      configuration: snapshot.configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: snapshot.startedAt,
      accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: observedAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    let event = SessionEvent(
      sessionID: sessionID,
      sequence: snapshot.eventSequence + 1,
      occurredAt: observedAt,
      payload: .checkInOpened(trigger: trigger, continuation: continuation)
    )
    return .transition(
      Reduction(
        snapshot: candidate,
        events: [event],
        effects: [
          .announceAccessibility(.checkInPresented),
          .invalidateDisplayProjection(projectionToken: nil),
        ]
      ))
  }

  private static func resumePaused(
    snapshot: SessionSnapshot,
    context: ReductionContext
  ) -> ReductionOutcome {
    guard case let .paused(paused) = snapshot.state,
      let sessionID = snapshot.sessionID
    else {
      return invalidTransition(snapshot: snapshot, intent: .resume)
    }
    guard canonicalSecond(context.instant.wallNow) != nil else {
      return .failed(snapshot: snapshot, reason: .nonFiniteWallObservation)
    }
    let nextRevision = snapshot.revision.addingReportingOverflow(1)
    guard !nextRevision.overflow else {
      return .failed(snapshot: snapshot, reason: .revisionExhausted)
    }
    let remainingCapacity = UInt64.max - snapshot.eventSequence
    guard remainingCapacity >= 1 else {
      return .failed(
        snapshot: snapshot,
        reason: .eventSequenceExhausted(
          requiredAdditionalEvents: 1,
          remainingCapacity: remainingCapacity
        ))
    }
    let cadence: ScheduledCadenceSeed =
      paused.scheduledCheckInRemaining.map {
        .captured($0)
      } ?? .manualOnly
    let entry = SessionTimeKernel.materializeLiveEntry(
      .focus(
        sessionID: sessionID,
        targetRevision: nextRevision.partialValue,
        nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
        wallNow: context.instant.wallNow,
        projectionToken: context.generatedProjectionToken,
        phaseID: paused.phase.id,
        timing: paused.timing,
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
    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision.partialValue,
      eventSequence: snapshot.eventSequence + 1,
      nextBoundaryOccurrence: materialization.nextBoundaryOccurrence,
      state: .focusing(
        FocusState(
          phase: paused.phase,
          timingAtAnchor: materialization.timingAtAnchor,
          wallAnchor: materialization.wallAnchor,
          phaseEndsAt: materialization.phaseEndsAt,
          elapsedBeforeAnchorSeconds: 0,
          projectionToken: materialization.projectionToken,
          phaseBoundaryToken: materialization.phaseBoundaryToken
        )),
      plan: snapshot.plan,
      configuration: snapshot.configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: snapshot.startedAt,
      accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: materialization.wallAnchor,
      nextScheduledCheckIn: materialization.scheduledCheckIn,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    let event = SessionEvent(
      sessionID: sessionID,
      sequence: snapshot.eventSequence + 1,
      occurredAt: materialization.wallAnchor,
      payload: .phaseResumed(phase: paused.phase, endsAt: materialization.phaseEndsAt)
    )
    var effects: [SessionEffect] = []
    if let winner = notificationWinner(in: candidate) {
      effects.append(
        .scheduleNotification(
          SessionNotificationRequest(boundaryToken: winner.token, fireAt: winner.dueAt)))
    }
    effects.append(.announceAccessibility(.focusStarted))
    effects.append(.invalidateDisplayProjection(projectionToken: materialization.projectionToken))
    return .transition(Reduction(snapshot: candidate, events: [event], effects: effects))
  }

  private static func startBreakFromPaused(
    snapshot: SessionSnapshot,
    choice: BreakChoice,
    context: ReductionContext
  ) -> ReductionOutcome {
    guard case let .paused(paused) = snapshot.state,
      let sessionID = snapshot.sessionID,
      let plan = snapshot.plan
    else {
      return invalidTransition(snapshot: snapshot, intent: .requestBreak(choice))
    }
    guard canonicalSecond(context.instant.wallNow) != nil else {
      return .failed(snapshot: snapshot, reason: .nonFiniteWallObservation)
    }
    let nextRevision = snapshot.revision.addingReportingOverflow(1)
    guard !nextRevision.overflow else {
      return .failed(snapshot: snapshot, reason: .revisionExhausted)
    }
    let remainingCapacity = UInt64.max - snapshot.eventSequence
    guard remainingCapacity >= 1 else {
      return .failed(
        snapshot: snapshot,
        reason: .eventSequenceExhausted(
          requiredAdditionalEvents: 1,
          remainingCapacity: remainingCapacity
        ))
    }
    let entry = SessionTimeKernel.materializeLiveEntry(
      .breakState(
        sessionID: sessionID,
        targetRevision: nextRevision.partialValue,
        nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
        wallNow: context.instant.wallNow,
        projectionToken: context.generatedProjectionToken,
        timing: .choice(choice.duration)
      ))
    let materialization: BreakEntryMaterialization
    switch entry {
    case let .materialized(.breakState(value)):
      materialization = value
    case .materialized(.focus):
      return .failed(snapshot: snapshot, reason: .arithmeticOverflow)
    case let .failure(reason):
      return .failed(snapshot: snapshot, reason: reason)
    }
    let resumeTarget = SuspendedFocusState(
      phase: paused.phase,
      timing: paused.timing,
      resumeDisposition: .paused,
      scheduledCheckInRemaining: paused.scheduledCheckInRemaining
    )
    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision.partialValue,
      eventSequence: snapshot.eventSequence + 1,
      nextBoundaryOccurrence: materialization.nextBoundaryOccurrence,
      state: .breaking(
        BreakState(
          choice: choice,
          timingAtAnchor: materialization.timingAtAnchor,
          wallAnchor: materialization.wallAnchor,
          endsAt: materialization.endsAt,
          elapsedBeforeAnchorSeconds: 0,
          projectionToken: materialization.projectionToken,
          boundaryToken: materialization.boundaryToken,
          resumeTarget: resumeTarget,
          proposedAction: plan.firstAction
        )),
      plan: plan,
      configuration: snapshot.configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: snapshot.startedAt,
      accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: materialization.wallAnchor,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    let event = SessionEvent(
      sessionID: sessionID,
      sequence: snapshot.eventSequence + 1,
      occurredAt: materialization.wallAnchor,
      payload: .breakStarted(
        kind: choice.kind,
        duration: choice.duration,
        endsAt: materialization.endsAt
      )
    )
    var effects: [SessionEffect] = []
    if let boundaryToken = materialization.boundaryToken,
      let endsAt = materialization.endsAt
    {
      effects.append(
        .scheduleNotification(
          SessionNotificationRequest(boundaryToken: boundaryToken, fireAt: endsAt)))
    }
    effects.append(.announceAccessibility(.breakStarted))
    effects.append(
      .invalidateDisplayProjection(projectionToken: materialization.projectionToken))
    return .transition(Reduction(snapshot: candidate, events: [event], effects: effects))
  }

  private static func parkThoughtInNonLiveState(
    snapshot: SessionSnapshot,
    text: String,
    context: ReductionContext
  ) -> ReductionOutcome {
    let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty, normalized.unicodeScalars.count <= 2_000 else {
      return .rejected(snapshot: snapshot, reason: .invalidText(.thought))
    }
    guard snapshot.parkedThoughts.count < SessionDefaults.maximumParkedThoughts else {
      return .rejected(
        snapshot: snapshot,
        reason: .thoughtLimitReached(maximum: UInt16(SessionDefaults.maximumParkedThoughts))
      )
    }
    guard let sessionID = snapshot.sessionID else {
      return invalidTransition(snapshot: snapshot, intent: .parkThought(text))
    }
    guard let observedAt = canonicalSecond(context.instant.wallNow) else {
      return .failed(snapshot: snapshot, reason: .nonFiniteWallObservation)
    }
    let nextRevision = snapshot.revision.addingReportingOverflow(1)
    guard !nextRevision.overflow else {
      return .failed(snapshot: snapshot, reason: .revisionExhausted)
    }
    let remainingCapacity = UInt64.max - snapshot.eventSequence
    guard remainingCapacity >= 1 else {
      return .failed(
        snapshot: snapshot,
        reason: .eventSequenceExhausted(
          requiredAdditionalEvents: 1,
          remainingCapacity: remainingCapacity
        ))
    }
    let thought = ParkedThought(
      id: context.generatedThoughtID,
      text: normalized,
      createdAt: observedAt
    )
    let thoughts = (snapshot.parkedThoughts + [thought]).sorted { left, right in
      if left.createdAt != right.createdAt {
        return left.createdAt.date < right.createdAt.date
      }
      return left.id.uuidString < right.id.uuidString
    }
    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision.partialValue,
      eventSequence: snapshot.eventSequence + 1,
      nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
      state: snapshot.state,
      plan: snapshot.plan,
      configuration: snapshot.configuration,
      parkedThoughts: thoughts,
      startedAt: snapshot.startedAt,
      accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: observedAt,
      nextScheduledCheckIn: snapshot.nextScheduledCheckIn,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    let event = SessionEvent(
      sessionID: sessionID,
      sequence: snapshot.eventSequence + 1,
      occurredAt: observedAt,
      payload: .thoughtParked(id: thought.id)
    )
    return .transition(
      Reduction(
        snapshot: candidate,
        events: [event],
        effects: [.invalidateDisplayProjection(projectionToken: nil)]
      ))
  }

  private static func reduceCheckingIn(
    snapshot: SessionSnapshot,
    command: SessionCommand,
    context: ReductionContext
  ) -> ReductionOutcome {
    if let configuration = requestedConfiguration(
      for: command.intent,
      current: snapshot.configuration
    ) {
      return updateCheckingInConfiguration(
        snapshot: snapshot,
        intent: command.intent,
        configuration: configuration,
        context: context
      )
    }
    switch command.intent {
    case let .stop(choice):
      return enterReviewFromNonLive(
        snapshot: snapshot,
        request: .stop(choice),
        context: context
      )
    case let .respondToCheckIn(response):
      if response == .makeSmaller {
        return presentReentryFromCheckIn(snapshot: snapshot, context: context)
      }
      if case let .detour(note) = response {
        return reportDetourFromCheckIn(
          snapshot: snapshot,
          note: note,
          context: context
        )
      }
      if case let .takeBreak(choice) = response {
        return startBreakFromCheckIn(
          snapshot: snapshot,
          choice: choice,
          context: context
        )
      }
      if case let .checkingIn(checkIn) = snapshot.state,
        case .startPhase = checkIn.continuation,
        response == .continueFocus || response == .skip || response == .dismiss
      {
        return resolvePhaseCheckIn(
          snapshot: snapshot,
          response: response,
          context: context
        )
      }
      return resolveRestoringCheckIn(
        snapshot: snapshot,
        response: response,
        context: context
      )
    case let .parkThought(text):
      return parkThoughtInNonLiveState(
        snapshot: snapshot,
        text: text,
        context: context
      )
    case .reconcileTime:
      return .noChange(snapshot: snapshot, reason: .observationIrrelevant)
    default:
      return invalidTransition(snapshot: snapshot, intent: command.intent)
    }
  }

  private static func updateCheckingInConfiguration(
    snapshot: SessionSnapshot,
    intent: SessionIntent,
    configuration: SessionConfiguration,
    context: ReductionContext
  ) -> ReductionOutcome {
    guard case let .checkingIn(checkIn) = snapshot.state,
      let sessionID = snapshot.sessionID
    else {
      return invalidTransition(snapshot: snapshot, intent: intent)
    }
    let fields = changedConfigurationFields(
      from: snapshot.configuration,
      to: configuration
    )
    guard let changes = SessionConfigurationFieldChanges(fields) else {
      return .noChange(snapshot: snapshot, reason: .alreadyInRequestedState)
    }
    guard let observedAt = canonicalSecond(context.instant.wallNow) else {
      return .failed(snapshot: snapshot, reason: .nonFiniteWallObservation)
    }
    let nextRevision = snapshot.revision.addingReportingOverflow(1)
    guard !nextRevision.overflow else {
      return .failed(snapshot: snapshot, reason: .revisionExhausted)
    }
    guard snapshot.eventSequence < UInt64.max else {
      return .failed(
        snapshot: snapshot,
        reason: .eventSequenceExhausted(
          requiredAdditionalEvents: 1,
          remainingCapacity: 0
        ))
    }

    let scheduleChanged = fields.contains(.checkInSchedule)
    let cadence = SessionTimeKernel.materializeScheduledRemainder(
      configuration.checkInSchedule)
    let updatedCheckIn: CheckInState
    switch checkIn.continuation {
    case .resumeSuspended:
      guard let suspended = checkIn.suspended else {
        return invalidTransition(snapshot: snapshot, intent: intent)
      }
      updatedCheckIn = CheckInState(
        suspended: SuspendedFocusState(
          phase: suspended.phase,
          timing: suspended.timing,
          resumeDisposition: suspended.resumeDisposition,
          scheduledCheckInRemaining: scheduleChanged
            ? cadence : suspended.scheduledCheckInRemaining
        ),
        trigger: checkIn.trigger,
        continuation: checkIn.continuation,
        phaseBoundaryScheduledCheckInRemaining: nil
      )
    case .startPhase:
      updatedCheckIn = CheckInState(
        suspended: nil,
        trigger: checkIn.trigger,
        continuation: checkIn.continuation,
        phaseBoundaryScheduledCheckInRemaining: scheduleChanged
          ? nil : checkIn.phaseBoundaryScheduledCheckInRemaining
      )
    }

    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision.partialValue,
      eventSequence: snapshot.eventSequence + 1,
      nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
      state: .checkingIn(updatedCheckIn),
      plan: snapshot.plan,
      configuration: configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: snapshot.startedAt,
      accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: observedAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    return .transition(
      Reduction(
        snapshot: candidate,
        events: [
          SessionEvent(
            sessionID: sessionID,
            sequence: snapshot.eventSequence + 1,
            occurredAt: observedAt,
            payload: .configurationChanged(fields: changes)
          )
        ],
        effects: [.invalidateDisplayProjection(projectionToken: nil)]
      ))
  }

  private static func reduceReentering(
    snapshot: SessionSnapshot,
    command: SessionCommand,
    context: ReductionContext
  ) -> ReductionOutcome {
    if case let .stop(choice) = command.intent {
      return enterReviewFromNonLive(
        snapshot: snapshot,
        request: .stop(choice),
        context: context
      )
    }
    if case let .acceptRevisedAction(action) = command.intent {
      return acceptRevisedAction(
        snapshot: snapshot,
        action: action,
        context: context
      )
    }
    guard
      let configuration = requestedConfiguration(
        for: command.intent,
        current: snapshot.configuration
      )
    else {
      if case .reconcileTime = command.intent {
        return .noChange(snapshot: snapshot, reason: .observationIrrelevant)
      }
      return invalidTransition(snapshot: snapshot, intent: command.intent)
    }
    return updateReentryConfiguration(
      snapshot: snapshot,
      intent: command.intent,
      configuration: configuration,
      context: context
    )
  }

  private static func acceptRevisedAction(
    snapshot: SessionSnapshot,
    action: String,
    context: ReductionContext
  ) -> ReductionOutcome {
    let normalized = action.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty, normalized.unicodeScalars.count <= 500 else {
      return .rejected(snapshot: snapshot, reason: .invalidText(.revisedAction))
    }
    guard case let .reentering(reentry) = snapshot.state,
      let plan = snapshot.plan,
      let sessionID = snapshot.sessionID
    else {
      return invalidTransition(snapshot: snapshot, intent: .acceptRevisedAction(action))
    }
    guard let observedAt = canonicalSecond(context.instant.wallNow) else {
      return .failed(snapshot: snapshot, reason: .nonFiniteWallObservation)
    }
    let nextRevision = snapshot.revision.addingReportingOverflow(1)
    guard !nextRevision.overflow else {
      return .failed(snapshot: snapshot, reason: .revisionExhausted)
    }
    let changed = normalized != plan.firstAction
    let updatedPlan: SessionPlan
    do {
      updatedPlan = try SessionPlan(
        task: plan.task,
        firstAction: normalized,
        capacity: plan.capacity,
        timingPolicy: plan.timingPolicy
      )
    } catch {
      return .rejected(snapshot: snapshot, reason: .invalidText(.revisedAction))
    }
    switch reentry.resumeTarget.resumeDisposition {
    case .focusing:
      return resumeReentryToFocus(
        snapshot: snapshot,
        reentry: reentry,
        plan: updatedPlan,
        actionChanged: changed,
        sessionID: sessionID,
        observedAt: observedAt,
        nextRevision: nextRevision.partialValue,
        context: context
      )
    case .paused:
      let eventCount: UInt64 = changed ? 1 : 0
      let remainingCapacity = UInt64.max - snapshot.eventSequence
      guard eventCount <= remainingCapacity else {
        return .failed(
          snapshot: snapshot,
          reason: .eventSequenceExhausted(
            requiredAdditionalEvents: eventCount,
            remainingCapacity: remainingCapacity
          ))
      }
      let target = reentry.resumeTarget
      let candidate = SessionSnapshot(
        schemaVersion: snapshot.schemaVersion,
        sessionID: sessionID,
        revision: nextRevision.partialValue,
        eventSequence: snapshot.eventSequence + eventCount,
        nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
        state: .paused(
          PausedState(
            phase: target.phase,
            timing: target.timing,
            pausedAt: observedAt,
            scheduledCheckInRemaining: target.scheduledCheckInRemaining
          )),
        plan: updatedPlan,
        configuration: snapshot.configuration,
        parkedThoughts: snapshot.parkedThoughts,
        startedAt: snapshot.startedAt,
        accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
        accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
        lastWallObservationAt: observedAt,
        nextScheduledCheckIn: nil,
        lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
      )
      let events =
        changed
        ? [
          SessionEvent(
            sessionID: sessionID,
            sequence: snapshot.eventSequence + 1,
            occurredAt: observedAt,
            payload: .actionRevised
          )
        ] : []
      return .transition(
        Reduction(
          snapshot: candidate,
          events: events,
          effects: [.invalidateDisplayProjection(projectionToken: nil)]
        ))
    }
  }

  private static func resumeReentryToFocus(
    snapshot: SessionSnapshot,
    reentry: ReentryState,
    plan: SessionPlan,
    actionChanged: Bool,
    sessionID: UUID,
    observedAt: SessionTimestamp,
    nextRevision: UInt64,
    context: ReductionContext
  ) -> ReductionOutcome {
    let target = reentry.resumeTarget
    let cadence: ScheduledCadenceSeed =
      target.scheduledCheckInRemaining.map {
        .captured($0)
      } ?? .manualOnly
    let eventCount: UInt64 = actionChanged ? 2 : 1
    let remainingCapacity = UInt64.max - snapshot.eventSequence
    guard eventCount <= remainingCapacity else {
      return .failed(
        snapshot: snapshot,
        reason: .eventSequenceExhausted(
          requiredAdditionalEvents: eventCount,
          remainingCapacity: remainingCapacity
        ))
    }
    let entry = SessionTimeKernel.materializeLiveEntry(
      .focus(
        sessionID: sessionID,
        targetRevision: nextRevision,
        nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
        wallNow: observedAt.date,
        projectionToken: context.generatedProjectionToken,
        phaseID: target.phase.id,
        timing: target.timing,
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
    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision,
      eventSequence: snapshot.eventSequence + eventCount,
      nextBoundaryOccurrence: materialization.nextBoundaryOccurrence,
      state: .focusing(
        FocusState(
          phase: target.phase,
          timingAtAnchor: materialization.timingAtAnchor,
          wallAnchor: materialization.wallAnchor,
          phaseEndsAt: materialization.phaseEndsAt,
          elapsedBeforeAnchorSeconds: 0,
          projectionToken: materialization.projectionToken,
          phaseBoundaryToken: materialization.phaseBoundaryToken
        )),
      plan: plan,
      configuration: snapshot.configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: snapshot.startedAt,
      accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: materialization.wallAnchor,
      nextScheduledCheckIn: materialization.scheduledCheckIn,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    var payloads: [SessionEventPayload] = []
    if actionChanged { payloads.append(.actionRevised) }
    payloads.append(.phaseResumed(phase: target.phase, endsAt: materialization.phaseEndsAt))
    let events = payloads.enumerated().map { offset, payload in
      SessionEvent(
        sessionID: sessionID,
        sequence: snapshot.eventSequence + UInt64(offset) + 1,
        occurredAt: materialization.wallAnchor,
        payload: payload
      )
    }
    var effects: [SessionEffect] = []
    if let winner = notificationWinner(in: candidate) {
      effects.append(
        .scheduleNotification(
          SessionNotificationRequest(boundaryToken: winner.token, fireAt: winner.dueAt)))
    }
    effects.append(.announceAccessibility(.focusStarted))
    effects.append(
      .invalidateDisplayProjection(projectionToken: materialization.projectionToken))
    return .transition(Reduction(snapshot: candidate, events: events, effects: effects))
  }

  private static func updateReentryConfiguration(
    snapshot: SessionSnapshot,
    intent: SessionIntent,
    configuration: SessionConfiguration,
    context: ReductionContext
  ) -> ReductionOutcome {
    guard case let .reentering(reentry) = snapshot.state,
      let sessionID = snapshot.sessionID
    else {
      return invalidTransition(snapshot: snapshot, intent: intent)
    }
    let fields = changedConfigurationFields(
      from: snapshot.configuration,
      to: configuration
    )
    guard let changes = SessionConfigurationFieldChanges(fields) else {
      return .noChange(snapshot: snapshot, reason: .alreadyInRequestedState)
    }
    guard let observedAt = canonicalSecond(context.instant.wallNow) else {
      return .failed(snapshot: snapshot, reason: .nonFiniteWallObservation)
    }
    let nextRevision = snapshot.revision.addingReportingOverflow(1)
    guard !nextRevision.overflow else {
      return .failed(snapshot: snapshot, reason: .revisionExhausted)
    }
    guard snapshot.eventSequence < UInt64.max else {
      return .failed(
        snapshot: snapshot,
        reason: .eventSequenceExhausted(
          requiredAdditionalEvents: 1,
          remainingCapacity: 0
        ))
    }
    let target = reentry.resumeTarget
    let cadence =
      fields.contains(.checkInSchedule)
      ? SessionTimeKernel.materializeScheduledRemainder(configuration.checkInSchedule)
      : target.scheduledCheckInRemaining
    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision.partialValue,
      eventSequence: snapshot.eventSequence + 1,
      nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
      state: .reentering(
        ReentryState(
          resumeTarget: SuspendedFocusState(
            phase: target.phase,
            timing: target.timing,
            resumeDisposition: target.resumeDisposition,
            scheduledCheckInRemaining: cadence
          ),
          proposedAction: reentry.proposedAction,
          enteredAt: reentry.enteredAt
        )),
      plan: snapshot.plan,
      configuration: configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: snapshot.startedAt,
      accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: observedAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    return .transition(
      Reduction(
        snapshot: candidate,
        events: [
          SessionEvent(
            sessionID: sessionID,
            sequence: snapshot.eventSequence + 1,
            occurredAt: observedAt,
            payload: .configurationChanged(fields: changes)
          )
        ],
        effects: [.invalidateDisplayProjection(projectionToken: nil)]
      ))
  }

  private static func reduceReviewing(
    snapshot: SessionSnapshot,
    command: SessionCommand,
    context: ReductionContext
  ) -> ReductionOutcome {
    switch command.intent {
    case let .updateReviewReflection(reflection):
      return updateReviewReflection(
        snapshot: snapshot,
        reflection: reflection,
        context: context
      )
    case .finalizeReview:
      return finalizeReview(snapshot: snapshot, context: context)
    default:
      break
    }
    guard
      let configuration = requestedConfiguration(
        for: command.intent,
        current: snapshot.configuration
      )
    else {
      if case .reconcileTime = command.intent {
        return .noChange(snapshot: snapshot, reason: .observationIrrelevant)
      }
      return invalidTransition(snapshot: snapshot, intent: command.intent)
    }
    guard case .reviewing = snapshot.state, let sessionID = snapshot.sessionID else {
      return invalidTransition(snapshot: snapshot, intent: command.intent)
    }
    let fields = changedConfigurationFields(
      from: snapshot.configuration,
      to: configuration
    )
    guard let changes = SessionConfigurationFieldChanges(fields) else {
      return .noChange(snapshot: snapshot, reason: .alreadyInRequestedState)
    }
    guard let observedAt = canonicalSecond(context.instant.wallNow) else {
      return .failed(snapshot: snapshot, reason: .nonFiniteWallObservation)
    }
    let nextRevision = snapshot.revision.addingReportingOverflow(1)
    guard !nextRevision.overflow else {
      return .failed(snapshot: snapshot, reason: .revisionExhausted)
    }
    guard snapshot.eventSequence < UInt64.max else {
      return .failed(
        snapshot: snapshot,
        reason: .eventSequenceExhausted(
          requiredAdditionalEvents: 1,
          remainingCapacity: 0
        ))
    }
    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision.partialValue,
      eventSequence: snapshot.eventSequence + 1,
      nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
      state: snapshot.state,
      plan: snapshot.plan,
      configuration: configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: snapshot.startedAt,
      accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: observedAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    return .transition(
      Reduction(
        snapshot: candidate,
        events: [
          SessionEvent(
            sessionID: sessionID,
            sequence: snapshot.eventSequence + 1,
            occurredAt: observedAt,
            payload: .configurationChanged(fields: changes)
          )
        ],
        effects: [.invalidateDisplayProjection(projectionToken: nil)]
      ))
  }

  private static func reviewEntryIntent(_ request: ReviewEntryRequest) -> SessionIntent {
    switch request {
    case let .stop(choice): .stop(choice)
    case let .replacement(draft):
      .resolveActiveSessionConflict(choice: .replaceAndReview, replacement: draft)
    }
  }

  private static func replacePendingDraftInReview(
    snapshot: SessionSnapshot,
    replacement: SessionDraft,
    context: ReductionContext
  ) -> ReductionOutcome {
    guard case let .reviewing(review) = snapshot.state,
      let sessionID = snapshot.sessionID
    else {
      return invalidTransition(
        snapshot: snapshot,
        intent: .resolveActiveSessionConflict(
          choice: .replaceAndReview,
          replacement: replacement
        )
      )
    }
    guard let observedAt = canonicalSecond(context.instant.wallNow) else {
      return .failed(snapshot: snapshot, reason: .nonFiniteWallObservation)
    }
    let nextRevision = snapshot.revision.addingReportingOverflow(1)
    guard !nextRevision.overflow else {
      return .failed(snapshot: snapshot, reason: .revisionExhausted)
    }
    guard snapshot.eventSequence < UInt64.max else {
      return .failed(
        snapshot: snapshot,
        reason: .eventSequenceExhausted(
          requiredAdditionalEvents: 1,
          remainingCapacity: 0
        ))
    }
    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision.partialValue,
      eventSequence: snapshot.eventSequence + 1,
      nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
      state: .reviewing(
        ReviewState(
          draft: review.draft,
          stopReason: review.stopReason,
          replacementDraft: replacement
        )),
      plan: snapshot.plan,
      configuration: snapshot.configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: snapshot.startedAt,
      accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: observedAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    return .transition(
      Reduction(
        snapshot: candidate,
        events: [
          SessionEvent(
            sessionID: sessionID,
            sequence: snapshot.eventSequence + 1,
            occurredAt: observedAt,
            payload: .sessionReplacementRequested
          )
        ],
        effects: [.invalidateDisplayProjection(projectionToken: nil)]
      ))
  }

  private static func enterReviewFromNonLive(
    snapshot: SessionSnapshot,
    request: ReviewEntryRequest,
    context: ReductionContext
  ) -> ReductionOutcome {
    guard
      snapshot.state.kind == .paused || snapshot.state.kind == .checkingIn
        || snapshot.state.kind == .reentering || snapshot.state.kind == .recoveryNeeded,
      let sessionID = snapshot.sessionID,
      let startedAt = snapshot.startedAt,
      canonicalSecond(context.instant.wallNow) != nil
    else {
      if canonicalSecond(context.instant.wallNow) == nil {
        return .failed(snapshot: snapshot, reason: .nonFiniteWallObservation)
      }
      return invalidTransition(snapshot: snapshot, intent: reviewEntryIntent(request))
    }
    let observedAt = canonicalSecond(context.instant.wallNow)!
    let nextRevision = snapshot.revision.addingReportingOverflow(1)
    guard !nextRevision.overflow else {
      return .failed(snapshot: snapshot, reason: .revisionExhausted)
    }
    let remainingCapacity = UInt64.max - snapshot.eventSequence
    guard remainingCapacity >= 2 else {
      return .failed(
        snapshot: snapshot,
        reason: .eventSequenceExhausted(
          requiredAdditionalEvents: 2,
          remainingCapacity: remainingCapacity
        ))
    }
    let stopReason = request.stopReason
    let endedAt = observedAt.date >= startedAt.date ? observedAt : startedAt
    let thoughtCount = UInt64(snapshot.parkedThoughts.count)
    let draft = SessionSummaryDraft(
      endedAt: endedAt,
      focusedSeconds: snapshot.accumulatedFocusSeconds,
      breakSeconds: snapshot.accumulatedBreakSeconds,
      parkedThoughtCount: thoughtCount,
      optionalReflection: nil
    )
    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision.partialValue,
      eventSequence: snapshot.eventSequence + 2,
      nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
      state: .reviewing(
        ReviewState(
          draft: draft,
          stopReason: stopReason,
          replacementDraft: request.replacementDraft
        )),
      plan: snapshot.plan,
      configuration: snapshot.configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: startedAt,
      accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: observedAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    let reviewEvent = SessionReviewEvent(
      focusedSeconds: draft.focusedSeconds,
      breakSeconds: draft.breakSeconds,
      stopReason: stopReason,
      parkedThoughtCount: thoughtCount,
      hasReflection: false
    )
    let events = [
      SessionEvent(
        sessionID: sessionID,
        sequence: snapshot.eventSequence + 1,
        occurredAt: observedAt,
        payload: request.firstEvent
      ),
      SessionEvent(
        sessionID: sessionID,
        sequence: snapshot.eventSequence + 2,
        occurredAt: observedAt,
        payload: .reviewStarted(reviewEvent)
      ),
    ]
    return .transition(
      Reduction(
        snapshot: candidate,
        events: events,
        effects: [
          .announceAccessibility(.reviewPresented),
          .invalidateDisplayProjection(projectionToken: nil),
        ]
      ))
  }

  private static func enterReviewFromLive(
    snapshot: SessionSnapshot,
    request: ReviewEntryRequest,
    context: ReductionContext
  ) -> ReductionOutcome {
    let timingDecision = SessionTimeKernel.reconcileLive(
      snapshot: snapshot,
      instant: context.instant
    )
    let timing: NormalizedLiveTiming
    switch timingDecision {
    case let .normalized(value):
      timing = value
    case let .failure(reason):
      return .failed(snapshot: snapshot, reason: reason)
    case let .recovery(reason):
      switch snapshot.state {
      case .focusing:
        return focusRecoveryTransition(snapshot: snapshot, reason: reason, context: context)
      case .breaking:
        return breakRecoveryTransition(snapshot: snapshot, reason: reason, context: context)
      default:
        return invalidTransition(snapshot: snapshot, intent: reviewEntryIntent(request))
      }
    }
    let admission = SessionTimeKernel.admitBoundary(
      snapshot: snapshot,
      timing: timing,
      observedToken: nil
    )
    if case let .recovery(reason) = admission {
      switch snapshot.state {
      case .focusing:
        return focusRecoveryTransition(snapshot: snapshot, reason: reason, context: context)
      case .breaking:
        return breakRecoveryTransition(snapshot: snapshot, reason: reason, context: context)
      default:
        return invalidTransition(snapshot: snapshot, intent: reviewEntryIntent(request))
      }
    }
    let focusedSeconds: UInt64
    let breakSeconds: UInt64
    switch admission {
    case let .winner(winner):
      switch winner.exitMaterialization {
      case let .phase(total), let .scheduledCheckIn(total, _):
        focusedSeconds = total
        breakSeconds = snapshot.accumulatedBreakSeconds
      case let .breakEnd(total):
        focusedSeconds = snapshot.accumulatedFocusSeconds
        breakSeconds = total
      }
    case .noneDue:
      switch timing.nonBoundaryExitMaterialization {
      case let .focus(total, _, _):
        focusedSeconds = total
        breakSeconds = snapshot.accumulatedBreakSeconds
      case let .breakState(total):
        focusedSeconds = snapshot.accumulatedFocusSeconds
        breakSeconds = total
      case nil:
        return .failed(snapshot: snapshot, reason: .arithmeticOverflow)
      }
    case .boundaryNotDue, .earlierBoundaryPending, .recovery:
      return invalidTransition(snapshot: snapshot, intent: reviewEntryIntent(request))
    }
    guard let sessionID = snapshot.sessionID,
      let startedAt = snapshot.startedAt
    else {
      return invalidTransition(snapshot: snapshot, intent: reviewEntryIntent(request))
    }
    let nextRevision = snapshot.revision.addingReportingOverflow(1)
    guard !nextRevision.overflow else {
      return .failed(snapshot: snapshot, reason: .revisionExhausted)
    }
    let eventCount = UInt64(2 + (timing.admissionAdjustment == nil ? 0 : 1))
    let remainingCapacity = UInt64.max - snapshot.eventSequence
    guard eventCount <= remainingCapacity else {
      return .failed(
        snapshot: snapshot,
        reason: .eventSequenceExhausted(
          requiredAdditionalEvents: eventCount,
          remainingCapacity: remainingCapacity
        ))
    }
    let stopReason = request.stopReason
    let endedAt =
      timing.expectedWallNow.date >= startedAt.date
      ? timing.expectedWallNow : startedAt
    let thoughtCount = UInt64(snapshot.parkedThoughts.count)
    let draft = SessionSummaryDraft(
      endedAt: endedAt,
      focusedSeconds: focusedSeconds,
      breakSeconds: breakSeconds,
      parkedThoughtCount: thoughtCount,
      optionalReflection: nil
    )
    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision.partialValue,
      eventSequence: snapshot.eventSequence + eventCount,
      nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
      state: .reviewing(
        ReviewState(
          draft: draft,
          stopReason: stopReason,
          replacementDraft: request.replacementDraft
        )),
      plan: snapshot.plan,
      configuration: snapshot.configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: startedAt,
      accumulatedFocusSeconds: focusedSeconds,
      accumulatedBreakSeconds: breakSeconds,
      lastWallObservationAt: timing.observedWallNow,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    var payloads: [SessionEventPayload] = []
    if let adjustment = timing.admissionAdjustment {
      payloads.append(.clockAdjusted(adjustment))
    }
    payloads.append(request.firstEvent)
    payloads.append(
      .reviewStarted(
        SessionReviewEvent(
          focusedSeconds: focusedSeconds,
          breakSeconds: breakSeconds,
          stopReason: stopReason,
          parkedThoughtCount: thoughtCount,
          hasReflection: false
        )))
    let events = payloads.enumerated().map { offset, payload in
      SessionEvent(
        sessionID: sessionID,
        sequence: snapshot.eventSequence + UInt64(offset) + 1,
        occurredAt: timing.observedWallNow,
        payload: payload
      )
    }
    var effects = notificationReplacementEffects(from: snapshot, to: candidate)
    effects.append(.announceAccessibility(.reviewPresented))
    effects.append(.invalidateDisplayProjection(projectionToken: nil))
    return .transition(Reduction(snapshot: candidate, events: events, effects: effects))
  }

  private static func updateReviewReflection(
    snapshot: SessionSnapshot,
    reflection: String?,
    context: ReductionContext
  ) -> ReductionOutcome {
    guard case let .reviewing(review) = snapshot.state,
      let sessionID = snapshot.sessionID
    else {
      return invalidTransition(
        snapshot: snapshot,
        intent: .updateReviewReflection(reflection)
      )
    }
    let trimmed = reflection?.trimmingCharacters(in: .whitespacesAndNewlines)
    let normalized = trimmed.flatMap { $0.isEmpty ? nil : $0 }
    if let normalized, normalized.unicodeScalars.count > 2_000 {
      return .rejected(snapshot: snapshot, reason: .invalidText(.reflection))
    }
    guard normalized != review.draft.optionalReflection else {
      return .noChange(snapshot: snapshot, reason: .alreadyInRequestedState)
    }
    guard let observedAt = canonicalSecond(context.instant.wallNow) else {
      return .failed(snapshot: snapshot, reason: .nonFiniteWallObservation)
    }
    let nextRevision = snapshot.revision.addingReportingOverflow(1)
    guard !nextRevision.overflow else {
      return .failed(snapshot: snapshot, reason: .revisionExhausted)
    }
    guard snapshot.eventSequence < UInt64.max else {
      return .failed(
        snapshot: snapshot,
        reason: .eventSequenceExhausted(
          requiredAdditionalEvents: 1,
          remainingCapacity: 0
        ))
    }
    let draft = SessionSummaryDraft(
      endedAt: review.draft.endedAt,
      focusedSeconds: review.draft.focusedSeconds,
      breakSeconds: review.draft.breakSeconds,
      parkedThoughtCount: review.draft.parkedThoughtCount,
      optionalReflection: normalized
    )
    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision.partialValue,
      eventSequence: snapshot.eventSequence + 1,
      nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
      state: .reviewing(
        ReviewState(
          draft: draft,
          stopReason: review.stopReason,
          replacementDraft: review.replacementDraft
        )),
      plan: snapshot.plan,
      configuration: snapshot.configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: snapshot.startedAt,
      accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: observedAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    let event = SessionEvent(
      sessionID: sessionID,
      sequence: snapshot.eventSequence + 1,
      occurredAt: observedAt,
      payload: .reviewReflectionUpdated(hasReflection: normalized != nil)
    )
    return .transition(
      Reduction(
        snapshot: candidate,
        events: [event],
        effects: [.invalidateDisplayProjection(projectionToken: nil)]
      ))
  }

  private static func finalizeReview(
    snapshot: SessionSnapshot,
    context: ReductionContext
  ) -> ReductionOutcome {
    guard case let .reviewing(review) = snapshot.state,
      let sessionID = snapshot.sessionID,
      let plan = snapshot.plan,
      let startedAt = snapshot.startedAt
    else {
      return invalidTransition(snapshot: snapshot, intent: .finalizeReview)
    }
    guard let observedAt = canonicalSecond(context.instant.wallNow) else {
      return .failed(snapshot: snapshot, reason: .nonFiniteWallObservation)
    }
    let nextRevision = snapshot.revision.addingReportingOverflow(1)
    guard !nextRevision.overflow else {
      return .failed(snapshot: snapshot, reason: .revisionExhausted)
    }
    guard snapshot.eventSequence < UInt64.max else {
      return .failed(
        snapshot: snapshot,
        reason: .eventSequenceExhausted(
          requiredAdditionalEvents: 1,
          remainingCapacity: 0
        ))
    }
    let summary = SessionSummary(
      sessionID: sessionID,
      task: plan.task,
      finalAction: plan.firstAction,
      startedAt: startedAt,
      endedAt: review.draft.endedAt,
      focusedSeconds: review.draft.focusedSeconds,
      breakSeconds: review.draft.breakSeconds,
      stopReason: review.stopReason,
      parkedThoughtCount: review.draft.parkedThoughtCount,
      optionalReflection: review.draft.optionalReflection
    )
    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision.partialValue,
      eventSequence: snapshot.eventSequence + 1,
      nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
      state: .completed(
        CompletedState(
          summary: summary,
          pendingReplacementDraft: review.replacementDraft
        )),
      plan: nil,
      configuration: snapshot.configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: startedAt,
      accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: observedAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    let summaryEvent = SessionSummaryEvent(
      focusedSeconds: summary.focusedSeconds,
      breakSeconds: summary.breakSeconds,
      stopReason: summary.stopReason,
      parkedThoughtCount: summary.parkedThoughtCount,
      hasReflection: summary.optionalReflection != nil
    )
    let event = SessionEvent(
      sessionID: sessionID,
      sequence: snapshot.eventSequence + 1,
      occurredAt: observedAt,
      payload: .sessionCompleted(summary: summaryEvent)
    )
    return .transition(
      Reduction(
        snapshot: candidate,
        events: [event],
        effects: [.invalidateDisplayProjection(projectionToken: nil)]
      ))
  }

  private static func resolvePhaseCheckIn(
    snapshot: SessionSnapshot,
    response: CheckInResponse,
    context: ReductionContext
  ) -> ReductionOutcome {
    guard case let .checkingIn(checkIn) = snapshot.state,
      case let .startPhase(phase) = checkIn.continuation,
      case .phaseBoundary = checkIn.trigger,
      let sessionID = snapshot.sessionID
    else {
      return invalidTransition(snapshot: snapshot, intent: .respondToCheckIn(response))
    }
    let timing: PausedTiming =
      switch phase.duration {
      case let .timed(seconds): .timed(remaining: seconds)
      case .openEnded: .openEnded
      }
    let resolvedCadence =
      checkIn.phaseBoundaryScheduledCheckInRemaining
      ?? SessionTimeKernel.materializeScheduledRemainder(
        snapshot.configuration.checkInSchedule)
    guard let observedAt = canonicalSecond(context.instant.wallNow) else {
      return .failed(snapshot: snapshot, reason: .nonFiniteWallObservation)
    }
    let nextRevision = snapshot.revision.addingReportingOverflow(1)
    guard !nextRevision.overflow else {
      return .failed(snapshot: snapshot, reason: .revisionExhausted)
    }
    let remainingCapacity = UInt64.max - snapshot.eventSequence
    guard remainingCapacity >= 2 else {
      return .failed(
        snapshot: snapshot,
        reason: .eventSequenceExhausted(
          requiredAdditionalEvents: 2,
          remainingCapacity: remainingCapacity
        ))
    }
    if response == .continueFocus {
      return startPhaseFromCheckIn(
        snapshot: snapshot,
        sessionID: sessionID,
        phase: phase,
        timing: timing,
        resolvedCadence: resolvedCadence,
        observedAt: observedAt,
        nextRevision: nextRevision.partialValue,
        context: context
      )
    }
    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision.partialValue,
      eventSequence: snapshot.eventSequence + 2,
      nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
      state: .paused(
        PausedState(
          phase: phase,
          timing: timing,
          pausedAt: observedAt,
          scheduledCheckInRemaining: resolvedCadence
        )),
      plan: snapshot.plan,
      configuration: snapshot.configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: snapshot.startedAt,
      accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: observedAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    let events = [
      SessionEvent(
        sessionID: sessionID,
        sequence: snapshot.eventSequence + 1,
        occurredAt: observedAt,
        payload: .checkInResolved
      ),
      SessionEvent(
        sessionID: sessionID,
        sequence: snapshot.eventSequence + 2,
        occurredAt: observedAt,
        payload: .phasePaused(timing: timing)
      ),
    ]
    return .transition(
      Reduction(
        snapshot: candidate,
        events: events,
        effects: [.invalidateDisplayProjection(projectionToken: nil)]
      ))
  }

  private static func startPhaseFromCheckIn(
    snapshot: SessionSnapshot,
    sessionID: UUID,
    phase: SessionPhaseDescriptor,
    timing: PausedTiming,
    resolvedCadence: CheckInRemainingSeconds?,
    observedAt: SessionTimestamp,
    nextRevision: UInt64,
    context: ReductionContext
  ) -> ReductionOutcome {
    let cadence: ScheduledCadenceSeed =
      resolvedCadence.map { .captured($0) } ?? .manualOnly
    let entry = SessionTimeKernel.materializeLiveEntry(
      .focus(
        sessionID: sessionID,
        targetRevision: nextRevision,
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
    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision,
      eventSequence: snapshot.eventSequence + 2,
      nextBoundaryOccurrence: materialization.nextBoundaryOccurrence,
      state: .focusing(
        FocusState(
          phase: phase,
          timingAtAnchor: materialization.timingAtAnchor,
          wallAnchor: materialization.wallAnchor,
          phaseEndsAt: materialization.phaseEndsAt,
          elapsedBeforeAnchorSeconds: 0,
          projectionToken: materialization.projectionToken,
          phaseBoundaryToken: materialization.phaseBoundaryToken
        )),
      plan: snapshot.plan,
      configuration: snapshot.configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: snapshot.startedAt,
      accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: observedAt,
      nextScheduledCheckIn: materialization.scheduledCheckIn,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    let events = [
      SessionEvent(
        sessionID: sessionID,
        sequence: snapshot.eventSequence + 1,
        occurredAt: observedAt,
        payload: .checkInResolved
      ),
      SessionEvent(
        sessionID: sessionID,
        sequence: snapshot.eventSequence + 2,
        occurredAt: observedAt,
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
    effects.append(
      .invalidateDisplayProjection(projectionToken: materialization.projectionToken))
    return .transition(Reduction(snapshot: candidate, events: events, effects: effects))
  }

  private static func startBreakFromCheckIn(
    snapshot: SessionSnapshot,
    choice: BreakChoice,
    context: ReductionContext
  ) -> ReductionOutcome {
    guard case let .checkingIn(checkIn) = snapshot.state,
      let sessionID = snapshot.sessionID,
      let plan = snapshot.plan
    else {
      return invalidTransition(
        snapshot: snapshot,
        intent: .respondToCheckIn(.takeBreak(choice))
      )
    }
    let resumeTarget: SuspendedFocusState
    switch checkIn.continuation {
    case .resumeSuspended:
      guard let suspended = checkIn.suspended else {
        return invalidTransition(
          snapshot: snapshot,
          intent: .respondToCheckIn(.takeBreak(choice))
        )
      }
      let cadence: CheckInRemainingSeconds?
      switch checkIn.trigger {
      case .manual, .pauseOffer:
        cadence = suspended.scheduledCheckInRemaining
      case .scheduled:
        cadence = SessionTimeKernel.materializeScheduledRemainder(
          snapshot.configuration.checkInSchedule)
      case .phaseBoundary:
        return invalidTransition(
          snapshot: snapshot,
          intent: .respondToCheckIn(.takeBreak(choice))
        )
      }
      resumeTarget = SuspendedFocusState(
        phase: suspended.phase,
        timing: suspended.timing,
        resumeDisposition: suspended.resumeDisposition,
        scheduledCheckInRemaining: cadence
      )
    case let .startPhase(phase):
      guard case .phaseBoundary = checkIn.trigger else {
        return invalidTransition(
          snapshot: snapshot,
          intent: .respondToCheckIn(.takeBreak(choice))
        )
      }
      let timing: PausedTiming =
        switch phase.duration {
        case let .timed(seconds): .timed(remaining: seconds)
        case .openEnded: .openEnded
        }
      let cadence =
        checkIn.phaseBoundaryScheduledCheckInRemaining
        ?? SessionTimeKernel.materializeScheduledRemainder(
          snapshot.configuration.checkInSchedule)
      resumeTarget = SuspendedFocusState(
        phase: phase,
        timing: timing,
        resumeDisposition: .paused,
        scheduledCheckInRemaining: cadence
      )
    }
    guard canonicalSecond(context.instant.wallNow) != nil else {
      return .failed(snapshot: snapshot, reason: .nonFiniteWallObservation)
    }
    let nextRevision = snapshot.revision.addingReportingOverflow(1)
    guard !nextRevision.overflow else {
      return .failed(snapshot: snapshot, reason: .revisionExhausted)
    }
    let remainingCapacity = UInt64.max - snapshot.eventSequence
    guard remainingCapacity >= 2 else {
      return .failed(
        snapshot: snapshot,
        reason: .eventSequenceExhausted(
          requiredAdditionalEvents: 2,
          remainingCapacity: remainingCapacity
        ))
    }
    let entry = SessionTimeKernel.materializeLiveEntry(
      .breakState(
        sessionID: sessionID,
        targetRevision: nextRevision.partialValue,
        nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
        wallNow: context.instant.wallNow,
        projectionToken: context.generatedProjectionToken,
        timing: .choice(choice.duration)
      ))
    let materialization: BreakEntryMaterialization
    switch entry {
    case let .materialized(.breakState(value)):
      materialization = value
    case .materialized(.focus):
      return .failed(snapshot: snapshot, reason: .arithmeticOverflow)
    case let .failure(reason):
      return .failed(snapshot: snapshot, reason: reason)
    }
    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision.partialValue,
      eventSequence: snapshot.eventSequence + 2,
      nextBoundaryOccurrence: materialization.nextBoundaryOccurrence,
      state: .breaking(
        BreakState(
          choice: choice,
          timingAtAnchor: materialization.timingAtAnchor,
          wallAnchor: materialization.wallAnchor,
          endsAt: materialization.endsAt,
          elapsedBeforeAnchorSeconds: 0,
          projectionToken: materialization.projectionToken,
          boundaryToken: materialization.boundaryToken,
          resumeTarget: resumeTarget,
          proposedAction: plan.firstAction
        )),
      plan: plan,
      configuration: snapshot.configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: snapshot.startedAt,
      accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: materialization.wallAnchor,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    let events = [
      SessionEvent(
        sessionID: sessionID,
        sequence: snapshot.eventSequence + 1,
        occurredAt: materialization.wallAnchor,
        payload: .checkInResolved
      ),
      SessionEvent(
        sessionID: sessionID,
        sequence: snapshot.eventSequence + 2,
        occurredAt: materialization.wallAnchor,
        payload: .breakStarted(
          kind: choice.kind,
          duration: choice.duration,
          endsAt: materialization.endsAt
        )
      ),
    ]
    var effects: [SessionEffect] = []
    if let boundaryToken = materialization.boundaryToken,
      let endsAt = materialization.endsAt
    {
      effects.append(
        .scheduleNotification(
          SessionNotificationRequest(boundaryToken: boundaryToken, fireAt: endsAt)))
    }
    effects.append(.announceAccessibility(.breakStarted))
    effects.append(
      .invalidateDisplayProjection(projectionToken: materialization.projectionToken))
    return .transition(Reduction(snapshot: candidate, events: events, effects: effects))
  }

  private static func reportDetourFromCheckIn(
    snapshot: SessionSnapshot,
    note: String?,
    context: ReductionContext
  ) -> ReductionOutcome {
    guard case .checkingIn = snapshot.state,
      let sessionID = snapshot.sessionID
    else {
      return invalidTransition(
        snapshot: snapshot,
        intent: .respondToCheckIn(.detour(note: note))
      )
    }
    let normalizedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
    let meaningfulNote = normalizedNote.flatMap { $0.isEmpty ? nil : $0 }
    if let meaningfulNote, meaningfulNote.unicodeScalars.count > 2_000 {
      return .rejected(snapshot: snapshot, reason: .invalidText(.detourNote))
    }
    if meaningfulNote != nil,
      snapshot.parkedThoughts.count >= SessionDefaults.maximumParkedThoughts
    {
      return .rejected(
        snapshot: snapshot,
        reason: .thoughtLimitReached(maximum: UInt16(SessionDefaults.maximumParkedThoughts))
      )
    }
    guard let observedAt = canonicalSecond(context.instant.wallNow) else {
      return .failed(snapshot: snapshot, reason: .nonFiniteWallObservation)
    }
    let nextRevision = snapshot.revision.addingReportingOverflow(1)
    guard !nextRevision.overflow else {
      return .failed(snapshot: snapshot, reason: .revisionExhausted)
    }
    let requiredEvents: UInt64 = meaningfulNote == nil ? 1 : 2
    let remainingCapacity = UInt64.max - snapshot.eventSequence
    guard remainingCapacity >= requiredEvents else {
      return .failed(
        snapshot: snapshot,
        reason: .eventSequenceExhausted(
          requiredAdditionalEvents: requiredEvents,
          remainingCapacity: remainingCapacity
        ))
    }
    var thoughts = snapshot.parkedThoughts
    if let meaningfulNote {
      thoughts.append(
        ParkedThought(
          id: context.generatedThoughtID,
          text: meaningfulNote,
          createdAt: observedAt
        ))
      thoughts.sort { left, right in
        if left.createdAt != right.createdAt {
          return left.createdAt.date < right.createdAt.date
        }
        return left.id.uuidString < right.id.uuidString
      }
    }
    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision.partialValue,
      eventSequence: snapshot.eventSequence + requiredEvents,
      nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
      state: snapshot.state,
      plan: snapshot.plan,
      configuration: snapshot.configuration,
      parkedThoughts: thoughts,
      startedAt: snapshot.startedAt,
      accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: observedAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    var events = [
      SessionEvent(
        sessionID: sessionID,
        sequence: snapshot.eventSequence + 1,
        occurredAt: observedAt,
        payload: .detourReported(hasNote: meaningfulNote != nil)
      )
    ]
    if meaningfulNote != nil {
      events.append(
        SessionEvent(
          sessionID: sessionID,
          sequence: snapshot.eventSequence + 2,
          occurredAt: observedAt,
          payload: .thoughtParked(id: context.generatedThoughtID)
        ))
    }
    return .transition(
      Reduction(
        snapshot: candidate,
        events: events,
        effects: [.invalidateDisplayProjection(projectionToken: nil)]
      ))
  }

  private static func presentReentryFromCheckIn(
    snapshot: SessionSnapshot,
    context: ReductionContext
  ) -> ReductionOutcome {
    guard case let .checkingIn(checkIn) = snapshot.state,
      let sessionID = snapshot.sessionID,
      let plan = snapshot.plan
    else {
      return invalidTransition(snapshot: snapshot, intent: .respondToCheckIn(.makeSmaller))
    }
    let resumeTarget: SuspendedFocusState
    switch checkIn.continuation {
    case .resumeSuspended:
      guard let suspended = checkIn.suspended else {
        return invalidTransition(snapshot: snapshot, intent: .respondToCheckIn(.makeSmaller))
      }
      let cadence: CheckInRemainingSeconds?
      switch checkIn.trigger {
      case .manual, .pauseOffer:
        cadence = suspended.scheduledCheckInRemaining
      case .scheduled:
        cadence = SessionTimeKernel.materializeScheduledRemainder(
          snapshot.configuration.checkInSchedule)
      case .phaseBoundary:
        return invalidTransition(snapshot: snapshot, intent: .respondToCheckIn(.makeSmaller))
      }
      resumeTarget = SuspendedFocusState(
        phase: suspended.phase,
        timing: suspended.timing,
        resumeDisposition: suspended.resumeDisposition,
        scheduledCheckInRemaining: cadence
      )
    case let .startPhase(phase):
      guard case .phaseBoundary = checkIn.trigger else {
        return invalidTransition(snapshot: snapshot, intent: .respondToCheckIn(.makeSmaller))
      }
      let timing: PausedTiming =
        switch phase.duration {
        case let .timed(seconds): .timed(remaining: seconds)
        case .openEnded: .openEnded
        }
      let cadence =
        checkIn.phaseBoundaryScheduledCheckInRemaining
        ?? SessionTimeKernel.materializeScheduledRemainder(
          snapshot.configuration.checkInSchedule)
      resumeTarget = SuspendedFocusState(
        phase: phase,
        timing: timing,
        resumeDisposition: .paused,
        scheduledCheckInRemaining: cadence
      )
    }
    guard let observedAt = canonicalSecond(context.instant.wallNow) else {
      return .failed(snapshot: snapshot, reason: .nonFiniteWallObservation)
    }
    let nextRevision = snapshot.revision.addingReportingOverflow(1)
    guard !nextRevision.overflow else {
      return .failed(snapshot: snapshot, reason: .revisionExhausted)
    }
    let remainingCapacity = UInt64.max - snapshot.eventSequence
    guard remainingCapacity >= 2 else {
      return .failed(
        snapshot: snapshot,
        reason: .eventSequenceExhausted(
          requiredAdditionalEvents: 2,
          remainingCapacity: remainingCapacity
        ))
    }
    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision.partialValue,
      eventSequence: snapshot.eventSequence + 2,
      nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
      state: .reentering(
        ReentryState(
          resumeTarget: resumeTarget,
          proposedAction: plan.firstAction,
          enteredAt: observedAt
        )),
      plan: plan,
      configuration: snapshot.configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: snapshot.startedAt,
      accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: observedAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    let events = [
      SessionEvent(
        sessionID: sessionID,
        sequence: snapshot.eventSequence + 1,
        occurredAt: observedAt,
        payload: .checkInResolved
      ),
      SessionEvent(
        sessionID: sessionID,
        sequence: snapshot.eventSequence + 2,
        occurredAt: observedAt,
        payload: .reentryPresented
      ),
    ]
    return .transition(
      Reduction(
        snapshot: candidate,
        events: events,
        effects: [
          .announceAccessibility(.reentryPresented),
          .invalidateDisplayProjection(projectionToken: nil),
        ]
      ))
  }

  private static func resolveRestoringCheckIn(
    snapshot: SessionSnapshot,
    response: CheckInResponse,
    context: ReductionContext
  ) -> ReductionOutcome {
    guard response == .continueFocus || response == .skip || response == .dismiss else {
      return invalidTransition(snapshot: snapshot, intent: .respondToCheckIn(response))
    }
    guard case let .checkingIn(checkIn) = snapshot.state,
      checkIn.continuation == .resumeSuspended,
      let suspended = checkIn.suspended,
      let sessionID = snapshot.sessionID
    else {
      return invalidTransition(snapshot: snapshot, intent: .respondToCheckIn(response))
    }
    let resolvedCadence: CheckInRemainingSeconds?
    switch checkIn.trigger {
    case .manual, .pauseOffer:
      resolvedCadence = suspended.scheduledCheckInRemaining
    case .scheduled:
      resolvedCadence = SessionTimeKernel.materializeScheduledRemainder(
        snapshot.configuration.checkInSchedule)
    case .phaseBoundary:
      return invalidTransition(snapshot: snapshot, intent: .respondToCheckIn(response))
    }
    guard let observedAt = canonicalSecond(context.instant.wallNow) else {
      return .failed(snapshot: snapshot, reason: .nonFiniteWallObservation)
    }
    let nextRevision = snapshot.revision.addingReportingOverflow(1)
    guard !nextRevision.overflow else {
      return .failed(snapshot: snapshot, reason: .revisionExhausted)
    }
    let requiredEvents: UInt64 = suspended.resumeDisposition == .focusing ? 2 : 1
    let remainingCapacity = UInt64.max - snapshot.eventSequence
    guard remainingCapacity >= requiredEvents else {
      return .failed(
        snapshot: snapshot,
        reason: .eventSequenceExhausted(
          requiredAdditionalEvents: requiredEvents,
          remainingCapacity: remainingCapacity
        ))
    }
    if suspended.resumeDisposition == .focusing {
      return restoreLiveFocusFromCheckIn(
        snapshot: snapshot,
        sessionID: sessionID,
        suspended: suspended,
        resolvedCadence: resolvedCadence,
        observedAt: observedAt,
        nextRevision: nextRevision.partialValue,
        context: context
      )
    }
    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision.partialValue,
      eventSequence: snapshot.eventSequence + 1,
      nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
      state: .paused(
        PausedState(
          phase: suspended.phase,
          timing: suspended.timing,
          pausedAt: observedAt,
          scheduledCheckInRemaining: resolvedCadence
        )),
      plan: snapshot.plan,
      configuration: snapshot.configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: snapshot.startedAt,
      accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: observedAt,
      nextScheduledCheckIn: nil,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    let event = SessionEvent(
      sessionID: sessionID,
      sequence: snapshot.eventSequence + 1,
      occurredAt: observedAt,
      payload: .checkInResolved
    )
    return .transition(
      Reduction(
        snapshot: candidate,
        events: [event],
        effects: [.invalidateDisplayProjection(projectionToken: nil)]
      ))
  }

  private static func restoreLiveFocusFromCheckIn(
    snapshot: SessionSnapshot,
    sessionID: UUID,
    suspended: SuspendedFocusState,
    resolvedCadence: CheckInRemainingSeconds?,
    observedAt: SessionTimestamp,
    nextRevision: UInt64,
    context: ReductionContext
  ) -> ReductionOutcome {
    let cadence: ScheduledCadenceSeed =
      resolvedCadence.map { .captured($0) } ?? .manualOnly
    let entry = SessionTimeKernel.materializeLiveEntry(
      .focus(
        sessionID: sessionID,
        targetRevision: nextRevision,
        nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
        wallNow: context.instant.wallNow,
        projectionToken: context.generatedProjectionToken,
        phaseID: suspended.phase.id,
        timing: suspended.timing,
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
    let candidate = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: sessionID,
      revision: nextRevision,
      eventSequence: snapshot.eventSequence + 2,
      nextBoundaryOccurrence: materialization.nextBoundaryOccurrence,
      state: .focusing(
        FocusState(
          phase: suspended.phase,
          timingAtAnchor: materialization.timingAtAnchor,
          wallAnchor: materialization.wallAnchor,
          phaseEndsAt: materialization.phaseEndsAt,
          elapsedBeforeAnchorSeconds: 0,
          projectionToken: materialization.projectionToken,
          phaseBoundaryToken: materialization.phaseBoundaryToken
        )),
      plan: snapshot.plan,
      configuration: snapshot.configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: snapshot.startedAt,
      accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: observedAt,
      nextScheduledCheckIn: materialization.scheduledCheckIn,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )
    let events = [
      SessionEvent(
        sessionID: sessionID,
        sequence: snapshot.eventSequence + 1,
        occurredAt: observedAt,
        payload: .checkInResolved
      ),
      SessionEvent(
        sessionID: sessionID,
        sequence: snapshot.eventSequence + 2,
        occurredAt: observedAt,
        payload: .phaseResumed(
          phase: suspended.phase,
          endsAt: materialization.phaseEndsAt
        )
      ),
    ]
    var effects: [SessionEffect] = []
    if let winner = notificationWinner(in: candidate) {
      effects.append(
        .scheduleNotification(
          SessionNotificationRequest(boundaryToken: winner.token, fireAt: winner.dueAt)))
    }
    effects.append(.announceAccessibility(.focusStarted))
    effects.append(
      .invalidateDisplayProjection(projectionToken: materialization.projectionToken))
    return .transition(Reduction(snapshot: candidate, events: events, effects: effects))
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

  private static func requestedConfiguration(
    for intent: SessionIntent,
    current: SessionConfiguration
  ) -> SessionConfiguration? {
    switch intent {
    case let .setCheckInSchedule(schedule):
      SessionConfiguration(
        checkInSchedule: schedule,
        breakSuggestionsEnabled: current.breakSuggestionsEnabled,
        lowCognitiveLoadEnabled: current.lowCognitiveLoadEnabled,
        reflectionPromptEnabled: current.reflectionPromptEnabled
      )
    case let .setBreakSuggestionsEnabled(enabled):
      SessionConfiguration(
        checkInSchedule: current.checkInSchedule,
        breakSuggestionsEnabled: enabled,
        lowCognitiveLoadEnabled: current.lowCognitiveLoadEnabled,
        reflectionPromptEnabled: current.reflectionPromptEnabled
      )
    case let .setLowCognitiveLoadEnabled(enabled):
      SessionConfiguration(
        checkInSchedule: current.checkInSchedule,
        breakSuggestionsEnabled: current.breakSuggestionsEnabled,
        lowCognitiveLoadEnabled: enabled,
        reflectionPromptEnabled: current.reflectionPromptEnabled
      )
    case let .setReflectionPromptEnabled(enabled):
      SessionConfiguration(
        checkInSchedule: current.checkInSchedule,
        breakSuggestionsEnabled: current.breakSuggestionsEnabled,
        lowCognitiveLoadEnabled: current.lowCognitiveLoadEnabled,
        reflectionPromptEnabled: enabled
      )
    default:
      nil
    }
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
