import Foundation

/// Validation is intentionally pure. Additional lifecycle-specific invariants
/// are added alongside each immutable state fixture before reducer work begins.
internal enum SessionSnapshotValidator {
  static func validateCandidate(_ candidate: SessionSnapshot) -> Set<SnapshotInvariantViolation> {
    var violations = Set<SnapshotInvariantViolation>()

    if candidate.schemaVersion != 1 {
      violations.insert(.unsupportedSchema(found: candidate.schemaVersion))
    }

    validateIdleBaseline(candidate, into: &violations)
    validateRootTimestamps(candidate, into: &violations)
    validateScheduledCheckIn(
      candidate.nextScheduledCheckIn,
      schedule: candidate.configuration.checkInSchedule,
      into: &violations
    )
    validateIdentityAndStartTime(candidate, into: &violations)
    validateState(
      candidate.state,
      plan: candidate.plan,
      lastWallObservationAt: candidate.lastWallObservationAt,
      sessionID: candidate.sessionID,
      nextBoundaryOccurrence: candidate.nextBoundaryOccurrence,
      startedAt: candidate.startedAt,
      accumulatedFocusSeconds: candidate.accumulatedFocusSeconds,
      accumulatedBreakSeconds: candidate.accumulatedBreakSeconds,
      scheduledCheckIn: candidate.nextScheduledCheckIn,
      checkInSchedule: candidate.configuration.checkInSchedule,
      into: &violations
    )
    validateBoundaryToken(
      candidate.lastConsumedBoundaryToken,
      sessionID: candidate.sessionID,
      nextBoundaryOccurrence: candidate.nextBoundaryOccurrence,
      into: &violations
    )
    validateBoundaryToken(
      candidate.nextScheduledCheckIn?.token,
      sessionID: candidate.sessionID,
      nextBoundaryOccurrence: candidate.nextBoundaryOccurrence,
      into: &violations
    )
    validateThoughts(candidate.parkedThoughts, into: &violations)
    for thought in candidate.parkedThoughts {
      validate(thought.createdAt, as: .thoughtCreatedAt, into: &violations)
    }
    return violations
  }

  private static func validateIdentityAndStartTime(
    _ candidate: SessionSnapshot,
    into violations: inout Set<SnapshotInvariantViolation>
  ) {
    switch candidate.state {
    case .idle:
      break
    case .prepared:
      if candidate.sessionID == nil { violations.insert(.invalidIdentity) }
    case .focusing, .paused, .checkingIn, .breaking, .reentering, .reviewing, .completed, .recoveryNeeded:
      if candidate.sessionID == nil { violations.insert(.invalidIdentity) }
      if candidate.startedAt == nil { violations.insert(.invalidStartTimestamp) }
    }
  }

  private static func validateScheduledCheckIn(
    _ boundary: ScheduledCheckInBoundary?,
    schedule: CheckInSchedule,
    into violations: inout Set<SnapshotInvariantViolation>
  ) {
    switch (schedule, boundary) {
    case (.manualOnly, .some):
      violations.insert(.invalidScheduledCheckIn)
    case let (.interval(minutes), .some(boundary)):
      let maximum = UInt32(minutes.value) * 60
      if boundary.trustedRemaining.value > maximum || boundary.token.kind != .scheduledCheckIn {
        violations.insert(.invalidScheduledCheckIn)
      }
    case (.manualOnly, nil), (.interval, nil):
      break
    }
  }

  private static func validateThoughts(
    _ thoughts: [ParkedThought],
    into violations: inout Set<SnapshotInvariantViolation>
  ) {
    if thoughts.count > SessionDefaults.maximumParkedThoughts {
      violations.insert(.thoughtLimitExceeded)
    }
    if Set(thoughts.map(\.id)).count != thoughts.count {
      violations.insert(.duplicateThoughtID)
    }
    for thought in thoughts {
      let normalized = thought.text.trimmingCharacters(in: .whitespacesAndNewlines)
      if normalized.isEmpty || normalized.unicodeScalars.count > 2_000 {
        violations.insert(.invalidText(.thought))
      }
    }
    let expectedOrder = thoughts.sorted { lhs, rhs in
      let left = lhs.createdAt.date.timeIntervalSinceReferenceDate
      let right = rhs.createdAt.date.timeIntervalSinceReferenceDate
      if left != right { return left < right }
      return lhs.id.uuidString < rhs.id.uuidString
    }
    if thoughts != expectedOrder {
      violations.insert(.invalidText(.thought))
    }
  }

  static func validate(
    previous: SessionSnapshot?,
    command: SessionCommand,
    candidate: SessionSnapshot,
    emittedEvents: [SessionEvent],
    context: ReductionContext
  ) -> Set<SnapshotInvariantViolation> {
    var violations = validateCandidate(candidate)
    if previous == nil {
      if candidate.state.kind != .idle || candidate.revision != 0 || !emittedEvents.isEmpty {
        violations.insert(.invalidIdleBaseline)
      }
      return violations
    }

    let previous = previous!
    let expectedRevision = previous.revision == UInt64.max ? UInt64.max : previous.revision + 1
    if candidate.revision != expectedRevision {
      violations.insert(.invalidRevision(expected: expectedRevision, actual: candidate.revision))
    }
    if candidate.accumulatedFocusSeconds < previous.accumulatedFocusSeconds
      || candidate.accumulatedBreakSeconds < previous.accumulatedBreakSeconds
    {
      violations.insert(.counterRegression)
    }
    if candidate.nextBoundaryOccurrence < previous.nextBoundaryOccurrence {
      violations.insert(.invalidBoundaryOccurrence)
    }
    if candidate.state.kind != .idle {
      if candidate.sessionID == nil || (previous.sessionID != nil && candidate.sessionID != previous.sessionID) {
        violations.insert(.invalidIdentity)
      }
      let expectedObservation = canonicalSecond(context.instant.wallNow)
      if candidate.lastWallObservationAt != expectedObservation {
        violations.insert(.invalidWallObservation)
      }
    }
    let isNewSessionPreparation = isPrepareReset(from: previous, command: command)
    validatePrepareReset(
      from: previous,
      command: command,
      candidate: candidate,
      emittedEvents: emittedEvents,
      context: context,
      into: &violations
    )
    let eventSequenceIsValid: Bool
    if isNewSessionPreparation {
      eventSequenceIsValid = candidate.eventSequence == 1
    } else {
      let expectedSequence = previous.eventSequence.addingReportingOverflow(UInt64(emittedEvents.count))
      eventSequenceIsValid = !expectedSequence.overflow
        && candidate.eventSequence == expectedSequence.partialValue
    }
    if !eventSequenceIsValid {
      violations.insert(.invalidEventSequence)
    }
    let expectedWall = canonicalSecond(context.instant.wallNow)
    for (offset, event) in emittedEvents.enumerated() {
      let expectedEventSequence = previous.eventSequence.addingReportingOverflow(UInt64(offset + 1))
      if expectedEventSequence.overflow || event.sequence != expectedEventSequence.partialValue
        || event.sessionID != candidate.sessionID || event.occurredAt != expectedWall
      {
        violations.insert(.invalidEventEnvelope)
      }
      validateEventPayloadTimestamps(event.payload, into: &violations)
    }
    return violations
  }

  private static func isPrepareReset(from previous: SessionSnapshot, command: SessionCommand) -> Bool {
    guard case .prepare = command.intent else { return false }
    return previous.state.kind == .idle || previous.state.kind == .completed
  }

  private static func validatePrepareReset(
    from previous: SessionSnapshot,
    command: SessionCommand,
    candidate: SessionSnapshot,
    emittedEvents: [SessionEvent],
    context: ReductionContext,
    into violations: inout Set<SnapshotInvariantViolation>
  ) {
    let priorAllowsPreparation = previous.state.kind == .idle || previous.state.kind == .completed
    guard case let .prepare(draft) = command.intent else {
      if priorAllowsPreparation && candidate.state.kind == .prepared {
        violations.insert(.invalidSessionReset)
      }
      return
    }

    guard priorAllowsPreparation else {
      violations.insert(.invalidSessionReset)
      return
    }

    let expectedWall = canonicalSecond(context.instant.wallNow)
    let expectedPayload = SessionEventPayload.sessionPrepared(
      policy: draft.plan.timingPolicy.id,
      capacitySpecified: draft.plan.capacity != nil
    )
    let stateMatches: Bool
    if case let .prepared(prepared) = candidate.state {
      stateMatches = prepared.preparedAt == expectedWall
    } else {
      stateMatches = false
    }
    let eventMatches = emittedEvents.count == 1
      && emittedEvents.first?.payload == expectedPayload
    let resetMatches = candidate.sessionID == context.generatedSessionID
      && candidate.sessionID != previous.sessionID
      && candidate.eventSequence == 1
      && candidate.nextBoundaryOccurrence == 0
      && stateMatches
      && candidate.plan == draft.plan
      && candidate.configuration == draft.configuration
      && candidate.parkedThoughts.isEmpty
      && candidate.startedAt == nil
      && candidate.accumulatedFocusSeconds == 0
      && candidate.accumulatedBreakSeconds == 0
      && candidate.lastWallObservationAt == expectedWall
      && candidate.nextScheduledCheckIn == nil
      && candidate.lastConsumedBoundaryToken == nil
      && eventMatches
    if !resetMatches {
      violations.insert(.invalidSessionReset)
    }
  }

  private static func validateEventPayloadTimestamps(
    _ payload: SessionEventPayload,
    into violations: inout Set<SnapshotInvariantViolation>
  ) {
    switch payload {
    case let .phaseStarted(_, endsAt):
      validate(endsAt, as: .eventPhaseStartedEndsAt, into: &violations)
    case let .phaseResumed(_, endsAt):
      validate(endsAt, as: .eventPhaseResumedEndsAt, into: &violations)
    case let .liveProjectionRestored(_, wallAnchor, endsAt):
      validate(wallAnchor, as: .eventLiveProjectionRestoredWallAnchor, into: &violations)
      validate(endsAt, as: .eventLiveProjectionRestoredEndsAt, into: &violations)
    case let .breakStarted(_, _, endsAt):
      validate(endsAt, as: .eventBreakStartedEndsAt, into: &violations)
    case let .clockAdjusted(event):
      validate(event.previousPhaseOrBreakDeadline, as: .clockAdjustmentPreviousPhaseOrBreakDeadline, into: &violations)
      validate(event.newPhaseOrBreakDeadline, as: .clockAdjustmentNewPhaseOrBreakDeadline, into: &violations)
      validate(event.previousScheduledCheckInAt, as: .clockAdjustmentPreviousScheduledCheckInAt, into: &violations)
      validate(event.newScheduledCheckInAt, as: .clockAdjustmentNewScheduledCheckInAt, into: &violations)
    case .sessionPrepared, .planUpdated, .sessionStarted, .phasePaused, .checkInOpened,
        .checkInResolved, .detourReported, .actionRevised, .configurationChanged,
        .breakEnded, .reentryPresented, .thoughtParked, .phaseElapsed, .clockRecoveryNeeded,
        .clockRecovered, .sessionStopRequested, .sessionReplacementRequested, .reviewStarted,
        .reviewReflectionUpdated, .sessionCompleted:
      break
    }
  }

  private static func validateIdleBaseline(
    _ candidate: SessionSnapshot,
    into violations: inout Set<SnapshotInvariantViolation>
  ) {
    guard candidate.state.kind == .idle else { return }
    let isCanonical = candidate.sessionID == nil
      && candidate.revision == 0
      && candidate.eventSequence == 0
      && candidate.nextBoundaryOccurrence == 0
      && candidate.plan == nil
      && candidate.configuration == .defaults
      && candidate.parkedThoughts.isEmpty
      && candidate.startedAt == nil
      && candidate.accumulatedFocusSeconds == 0
      && candidate.accumulatedBreakSeconds == 0
      && candidate.lastWallObservationAt == nil
      && candidate.nextScheduledCheckIn == nil
      && candidate.lastConsumedBoundaryToken == nil
    if !isCanonical { violations.insert(.invalidIdleBaseline) }
  }

  private static func validateRootTimestamps(
    _ candidate: SessionSnapshot,
    into violations: inout Set<SnapshotInvariantViolation>
  ) {
    validate(candidate.startedAt, as: .startedAt, into: &violations)
    validate(candidate.lastWallObservationAt, as: .lastWallObservationAt, into: &violations)
    validate(candidate.nextScheduledCheckIn?.dueAt, as: .scheduledCheckInDueAt, into: &violations)
  }

  private static func validateState(
    _ state: SessionState,
    plan: SessionPlan?,
    lastWallObservationAt: SessionTimestamp?,
    sessionID: UUID?,
    nextBoundaryOccurrence: UInt64,
    startedAt: SessionTimestamp?,
    accumulatedFocusSeconds: UInt64,
    accumulatedBreakSeconds: UInt64,
    scheduledCheckIn: ScheduledCheckInBoundary?,
    checkInSchedule: CheckInSchedule,
    into violations: inout Set<SnapshotInvariantViolation>
  ) {
    switch state {
    case .idle:
      break
    case let .prepared(value):
      validate(value.preparedAt, as: .preparedAt, into: &violations)
      if plan == nil { violations.insert(.missingPlan) }
    case let .focusing(value):
      validate(value.wallAnchor, as: .focusWallAnchor, into: &violations)
      validate(value.phaseEndsAt, as: .focusDeadline, into: &violations)
      if lastWallObservationAt != value.wallAnchor { violations.insert(.invalidWallObservation) }
      validateLivePhase(
        phase: value.phase,
        timing: value.timingAtAnchor,
        deadline: value.phaseEndsAt,
        wallAnchor: value.wallAnchor,
        elapsedBeforeAnchorSeconds: value.elapsedBeforeAnchorSeconds,
        into: &violations
      )
      validateBoundaryToken(
        value.phaseBoundaryToken,
        sessionID: sessionID,
        nextBoundaryOccurrence: nextBoundaryOccurrence,
        into: &violations
      )
      validateFocusBoundaryToken(
        value.phaseBoundaryToken,
        phase: value.phase,
        timing: value.timingAtAnchor,
        into: &violations
      )
      validateScheduledDeadline(
        scheduledCheckIn,
        wallAnchor: value.wallAnchor,
        into: &violations
      )
      if plan == nil { violations.insert(.missingPlan) }
    case let .paused(value):
      validate(value.pausedAt, as: .pausedAt, into: &violations)
      validateSuspendedFocus(
        phase: value.phase,
        timing: value.timing,
        scheduledCheckInRemaining: value.scheduledCheckInRemaining,
        schedule: checkInSchedule,
        into: &violations
      )
      if plan == nil { violations.insert(.missingPlan) }
    case let .checkingIn(value):
      validateCheckIn(value, schedule: checkInSchedule, into: &violations)
      if plan == nil { violations.insert(.missingPlan) }
    case let .breaking(value):
      validate(value.wallAnchor, as: .breakWallAnchor, into: &violations)
      validate(value.endsAt, as: .breakDeadline, into: &violations)
      if lastWallObservationAt != value.wallAnchor { violations.insert(.invalidWallObservation) }
      validateLiveBreak(
        choice: value.choice,
        timing: value.timingAtAnchor,
        deadline: value.endsAt,
        wallAnchor: value.wallAnchor,
        elapsedBeforeAnchorSeconds: value.elapsedBeforeAnchorSeconds,
        into: &violations
      )
      validateBoundaryToken(
        value.boundaryToken,
        sessionID: sessionID,
        nextBoundaryOccurrence: nextBoundaryOccurrence,
        into: &violations
      )
      validateBreakBoundaryToken(value.boundaryToken, timing: value.timingAtAnchor, into: &violations)
      validateAction(value.proposedAction, into: &violations)
      validateSuspendedFocus(
        phase: value.resumeTarget.phase,
        timing: value.resumeTarget.timing,
        scheduledCheckInRemaining: value.resumeTarget.scheduledCheckInRemaining,
        schedule: checkInSchedule,
        into: &violations
      )
      if plan == nil { violations.insert(.missingPlan) }
    case let .reentering(value):
      validate(value.enteredAt, as: .reentryEnteredAt, into: &violations)
      validateAction(value.proposedAction, into: &violations)
      validateSuspendedFocus(
        phase: value.resumeTarget.phase,
        timing: value.resumeTarget.timing,
        scheduledCheckInRemaining: value.resumeTarget.scheduledCheckInRemaining,
        schedule: checkInSchedule,
        into: &violations
      )
      if plan == nil { violations.insert(.missingPlan) }
    case let .reviewing(value):
      validate(value.draft.endedAt, as: .reviewEndedAt, into: &violations)
      if plan == nil { violations.insert(.missingPlan) }
    case let .completed(value):
      if plan != nil { violations.insert(.unexpectedPlan) }
      validate(value.summary.startedAt, as: .summaryStartedAt, into: &violations)
      validate(value.summary.endedAt, as: .summaryEndedAt, into: &violations)
      validateSummary(
        value.summary,
        startedAt: startedAt,
        accumulatedFocusSeconds: accumulatedFocusSeconds,
        accumulatedBreakSeconds: accumulatedBreakSeconds,
        into: &violations
      )
    case let .recoveryNeeded(value):
      if plan == nil { violations.insert(.missingPlan) }
      if value.safeChoices != Set(ClockRecoveryChoice.allCases) {
        violations.insert(.invalidRecoveryChoices)
      }
      validateRecoverableState(value.lastTrustworthyState, schedule: checkInSchedule, into: &violations)
    }
  }

  private static func validateAction(_ action: String, into violations: inout Set<SnapshotInvariantViolation>) {
    let normalized = action.trimmingCharacters(in: .whitespacesAndNewlines)
    if normalized.isEmpty || normalized.unicodeScalars.count > 500 {
      violations.insert(.invalidText(.revisedAction))
    }
  }

  private static func validateCheckIn(
    _ checkIn: CheckInState,
    schedule: CheckInSchedule,
    into violations: inout Set<SnapshotInvariantViolation>
  ) {
    switch checkIn.continuation {
    case .resumeSuspended:
      if checkIn.suspended == nil { violations.insert(.timingShapeMismatch) }
      if case .phaseBoundary = checkIn.trigger { violations.insert(.invalidBoundaryToken) }
      if checkIn.phaseBoundaryScheduledCheckInRemaining != nil {
        violations.insert(.invalidScheduledCheckIn)
      }
      if let suspended = checkIn.suspended {
        validateSuspendedFocus(
          phase: suspended.phase,
          timing: suspended.timing,
          scheduledCheckInRemaining: suspended.scheduledCheckInRemaining,
          schedule: schedule,
          into: &violations
        )
      }
    case .startPhase:
      if checkIn.suspended != nil { violations.insert(.timingShapeMismatch) }
      if case .phaseBoundary = checkIn.trigger {
        break
      } else {
        violations.insert(.invalidBoundaryToken)
      }
      validateScheduledRemainder(
        checkIn.phaseBoundaryScheduledCheckInRemaining,
        schedule: schedule,
        into: &violations
      )
    }
  }

  private static func validateRecoverableState(
    _ state: RecoverableSessionState,
    schedule: CheckInSchedule,
    into violations: inout Set<SnapshotInvariantViolation>
  ) {
    switch state {
    case let .focus(suspended):
      validateSuspendedFocus(
        phase: suspended.phase,
        timing: suspended.timing,
        scheduledCheckInRemaining: suspended.scheduledCheckInRemaining,
        schedule: schedule,
        into: &violations
      )
    case let .breakState(suspended):
      validateSuspendedFocus(
        phase: suspended.resumeTarget.phase,
        timing: suspended.resumeTarget.timing,
        scheduledCheckInRemaining: suspended.resumeTarget.scheduledCheckInRemaining,
        schedule: schedule,
        into: &violations
      )
      validateAction(suspended.proposedAction, into: &violations)
    case let .checkingIn(checkIn):
      validateCheckIn(checkIn, schedule: schedule, into: &violations)
    case let .reentering(reentry):
      validateSuspendedFocus(
        phase: reentry.resumeTarget.phase,
        timing: reentry.resumeTarget.timing,
        scheduledCheckInRemaining: reentry.resumeTarget.scheduledCheckInRemaining,
        schedule: schedule,
        into: &violations
      )
      validateAction(reentry.proposedAction, into: &violations)
    }
  }

  private static func validateSuspendedFocus(
    phase: SessionPhaseDescriptor,
    timing: PausedTiming,
    scheduledCheckInRemaining: CheckInRemainingSeconds?,
    schedule: CheckInSchedule,
    into violations: inout Set<SnapshotInvariantViolation>
  ) {
    validatePausedPhase(phase: phase, timing: timing, into: &violations)
    validateScheduledRemainder(scheduledCheckInRemaining, schedule: schedule, into: &violations)
  }

  private static func validateScheduledRemainder(
    _ remaining: CheckInRemainingSeconds?,
    schedule: CheckInSchedule,
    into violations: inout Set<SnapshotInvariantViolation>
  ) {
    switch (schedule, remaining) {
    case (.manualOnly, .some):
      violations.insert(.invalidScheduledCheckIn)
    case let (.interval(minutes), .some(remaining)):
      if remaining.value > UInt32(minutes.value) * 60 {
        violations.insert(.invalidScheduledCheckIn)
      }
    case (.manualOnly, nil), (.interval, nil):
      break
    }
  }

  private static func validateSummary(
    _ summary: SessionSummary,
    startedAt: SessionTimestamp?,
    accumulatedFocusSeconds: UInt64,
    accumulatedBreakSeconds: UInt64,
    into violations: inout Set<SnapshotInvariantViolation>
  ) {
    if summary.startedAt != startedAt
      || summary.focusedSeconds != accumulatedFocusSeconds
      || summary.breakSeconds != accumulatedBreakSeconds
      || summary.endedAt.date.timeIntervalSinceReferenceDate < summary.startedAt.date.timeIntervalSinceReferenceDate
    {
      violations.insert(.invalidSummary)
    }
    if let reflection = summary.optionalReflection {
      let normalized = reflection.trimmingCharacters(in: .whitespacesAndNewlines)
      if normalized.isEmpty || normalized.unicodeScalars.count > 2_000 {
        violations.insert(.invalidText(.reflection))
      }
    }
  }

  private static func validateBoundaryToken(
    _ token: BoundaryToken?,
    sessionID: UUID?,
    nextBoundaryOccurrence: UInt64,
    into violations: inout Set<SnapshotInvariantViolation>
  ) {
    guard let token else { return }
    let discriminantIsValid = switch token.kind {
    case .phase: token.phaseID != nil
    case .scheduledCheckIn, .breakEnd: token.phaseID == nil
    }
    if !discriminantIsValid || token.sessionID != sessionID || token.occurrence >= nextBoundaryOccurrence {
      violations.insert(.invalidBoundaryToken)
    }
  }

  private static func validateLivePhase(
    phase: SessionPhaseDescriptor,
    timing: PausedTiming,
    deadline: SessionTimestamp?,
    wallAnchor: SessionTimestamp,
    elapsedBeforeAnchorSeconds: UInt64,
    into violations: inout Set<SnapshotInvariantViolation>
  ) {
    switch (phase.duration, timing, deadline) {
    case (.timed, .timed, .some):
      break
    case (.openEnded, .openEnded, nil):
      break
    case (.timed, .timed, nil), (.openEnded, .openEnded, .some):
      violations.insert(.invalidDeadline)
    default:
      violations.insert(.timingShapeMismatch)
    }
    validateTimedBudget(
      timing: timing,
      configuredDuration: phase.duration,
      elapsedBeforeAnchorSeconds: elapsedBeforeAnchorSeconds,
      wallAnchor: wallAnchor,
      deadline: deadline,
      into: &violations
    )
  }

  private static func validatePausedPhase(
    phase: SessionPhaseDescriptor,
    timing: PausedTiming,
    into violations: inout Set<SnapshotInvariantViolation>
  ) {
    switch (phase.duration, timing) {
    case (.timed, .timed), (.openEnded, .openEnded):
      break
    default:
      violations.insert(.timingShapeMismatch)
    }
    validateTimedBudget(
      timing: timing,
      configuredDuration: phase.duration,
      elapsedBeforeAnchorSeconds: 0,
      wallAnchor: nil,
      deadline: nil,
      into: &violations
    )
  }

  private static func validateLiveBreak(
    choice: BreakChoice,
    timing: PausedTiming,
    deadline: SessionTimestamp?,
    wallAnchor: SessionTimestamp,
    elapsedBeforeAnchorSeconds: UInt64,
    into violations: inout Set<SnapshotInvariantViolation>
  ) {
    switch (choice.duration, timing, deadline) {
    case (.timed, .timed, .some):
      break
    case (.openEnded, .openEnded, nil):
      break
    case (.timed, .timed, nil), (.openEnded, .openEnded, .some):
      violations.insert(.invalidDeadline)
    default:
      violations.insert(.timingShapeMismatch)
    }
    let configuredDuration: PhaseDuration = switch choice.duration {
    case .openEnded: .openEnded
    case let .timed(minutes): .timed(try! PhaseSeconds(UInt32(minutes.value) * 60))
    }
    validateTimedBudget(
      timing: timing,
      configuredDuration: configuredDuration,
      elapsedBeforeAnchorSeconds: elapsedBeforeAnchorSeconds,
      wallAnchor: wallAnchor,
      deadline: deadline,
      into: &violations
    )
  }

  private static func validateTimedBudget(
    timing: PausedTiming,
    configuredDuration: PhaseDuration,
    elapsedBeforeAnchorSeconds: UInt64,
    wallAnchor: SessionTimestamp?,
    deadline: SessionTimestamp?,
    into violations: inout Set<SnapshotInvariantViolation>
  ) {
    guard case let (.timed(remaining), .timed(duration)) = (timing, configuredDuration) else { return }
    let total = elapsedBeforeAnchorSeconds.addingReportingOverflow(UInt64(remaining.value))
    guard !total.overflow, total.partialValue <= UInt64(duration.value) else {
      violations.insert(.timingShapeMismatch)
      return
    }
    guard let wallAnchor, let deadline else { return }
    let expectedDeadline = wallAnchor.date.timeIntervalSinceReferenceDate + Double(remaining.value)
    if !expectedDeadline.isFinite || deadline.date.timeIntervalSinceReferenceDate != expectedDeadline {
      violations.insert(.invalidDeadline)
    }
  }

  private static func validateFocusBoundaryToken(
    _ token: BoundaryToken?,
    phase: SessionPhaseDescriptor,
    timing: PausedTiming,
    into violations: inout Set<SnapshotInvariantViolation>
  ) {
    switch (phase.duration, timing, token) {
    case (.timed, .timed, .some(let token)) where token.kind == .phase && token.phaseID == phase.id:
      break
    case (.openEnded, .openEnded, nil):
      break
    default:
      violations.insert(.invalidBoundaryToken)
    }
  }

  private static func validateBreakBoundaryToken(
    _ token: BoundaryToken?,
    timing: PausedTiming,
    into violations: inout Set<SnapshotInvariantViolation>
  ) {
    switch (timing, token) {
    case (.timed, .some(let token)) where token.kind == .breakEnd:
      break
    case (.openEnded, nil):
      break
    default:
      violations.insert(.invalidBoundaryToken)
    }
  }

  private static func validateScheduledDeadline(
    _ scheduled: ScheduledCheckInBoundary?,
    wallAnchor: SessionTimestamp,
    into violations: inout Set<SnapshotInvariantViolation>
  ) {
    guard let scheduled else { return }
    let expectedDueAt = wallAnchor.date.timeIntervalSinceReferenceDate
      + Double(scheduled.trustedRemaining.value)
    if !expectedDueAt.isFinite || scheduled.dueAt.date.timeIntervalSinceReferenceDate != expectedDueAt {
      violations.insert(.invalidScheduledCheckIn)
    }
  }

  private static func validate(
    _ timestamp: SessionTimestamp?,
    as field: SessionTimestampField,
    into violations: inout Set<SnapshotInvariantViolation>
  ) {
    guard let timestamp else { return }
    let interval = timestamp.date.timeIntervalSinceReferenceDate
    if !interval.isFinite || interval != interval.rounded(.down) {
      violations.insert(.nonCanonicalTimestamp(field))
    }
  }
}
