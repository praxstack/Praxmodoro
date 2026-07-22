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
    case .focusing:
      return reduceFocusing(snapshot: snapshot, command: command, context: context)
    case .paused:
      return reducePaused(snapshot: snapshot, command: command, context: context)
    case .checkingIn:
      return reduceCheckingIn(snapshot: snapshot, command: command, context: context)
    case .breaking, .reentering, .reviewing, .completed, .recoveryNeeded:
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

  private static func reduceFocusing(
    snapshot: SessionSnapshot,
    command: SessionCommand,
    context: ReductionContext
  ) -> ReductionOutcome {
    switch command.intent {
    case .pause:
      return pauseFocus(snapshot: snapshot, command: command, context: context)
    default:
      return invalidTransition(snapshot: snapshot, intent: command.intent)
    }
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
    switch command.intent {
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
    switch command.intent {
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
      return resolveRestoringCheckIn(
        snapshot: snapshot,
        response: response,
        context: context
      )
    case .reconcileTime:
      return .noChange(snapshot: snapshot, reason: .observationIrrelevant)
    default:
      return invalidTransition(snapshot: snapshot, intent: command.intent)
    }
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
