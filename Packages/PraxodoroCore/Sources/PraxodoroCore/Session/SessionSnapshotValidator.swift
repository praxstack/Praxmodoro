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
    validateState(
      candidate.state,
      plan: candidate.plan,
      lastWallObservationAt: candidate.lastWallObservationAt,
      sessionID: candidate.sessionID,
      nextBoundaryOccurrence: candidate.nextBoundaryOccurrence,
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
    if candidate.state.kind != .idle {
      if candidate.sessionID == nil || (previous.sessionID != nil && candidate.sessionID != previous.sessionID) {
        violations.insert(.invalidIdentity)
      }
      let expectedObservation = canonicalSecond(context.instant.wallNow)
      if candidate.lastWallObservationAt != expectedObservation {
        violations.insert(.invalidWallObservation)
      }
    }
    let expectedSequence = previous.eventSequence.addingReportingOverflow(UInt64(emittedEvents.count))
    if expectedSequence.overflow || candidate.eventSequence != expectedSequence.partialValue {
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
    }
    _ = command
    return violations
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
        into: &violations
      )
      validateBoundaryToken(
        value.phaseBoundaryToken,
        sessionID: sessionID,
        nextBoundaryOccurrence: nextBoundaryOccurrence,
        into: &violations
      )
      if plan == nil { violations.insert(.missingPlan) }
    case let .paused(value):
      validate(value.pausedAt, as: .pausedAt, into: &violations)
      validatePausedPhase(phase: value.phase, timing: value.timing, into: &violations)
      if plan == nil { violations.insert(.missingPlan) }
    case .checkingIn:
      if plan == nil { violations.insert(.missingPlan) }
    case let .breaking(value):
      validate(value.wallAnchor, as: .breakWallAnchor, into: &violations)
      validate(value.endsAt, as: .breakDeadline, into: &violations)
      if lastWallObservationAt != value.wallAnchor { violations.insert(.invalidWallObservation) }
      validateLiveBreak(choice: value.choice, timing: value.timingAtAnchor, deadline: value.endsAt, into: &violations)
      validateBoundaryToken(
        value.boundaryToken,
        sessionID: sessionID,
        nextBoundaryOccurrence: nextBoundaryOccurrence,
        into: &violations
      )
      if plan == nil { violations.insert(.missingPlan) }
    case let .reentering(value):
      validate(value.enteredAt, as: .reentryEnteredAt, into: &violations)
      if plan == nil { violations.insert(.missingPlan) }
    case let .reviewing(value):
      validate(value.draft.endedAt, as: .reviewEndedAt, into: &violations)
      if plan == nil { violations.insert(.missingPlan) }
    case let .completed(value):
      if plan != nil { violations.insert(.unexpectedPlan) }
      validate(value.summary.startedAt, as: .summaryStartedAt, into: &violations)
      validate(value.summary.endedAt, as: .summaryEndedAt, into: &violations)
    case .recoveryNeeded:
      if plan == nil { violations.insert(.missingPlan) }
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
  }

  private static func validateLiveBreak(
    choice: BreakChoice,
    timing: PausedTiming,
    deadline: SessionTimestamp?,
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
