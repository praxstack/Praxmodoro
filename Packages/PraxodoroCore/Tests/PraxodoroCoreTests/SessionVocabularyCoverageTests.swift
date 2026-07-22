import Testing
@testable import PraxodoroCore

@Suite("Session vocabulary coverage")
struct SessionVocabularyCoverageTests {
  @Test("closed scalar vocabularies preserve their V1 cases and raw values")
  func closedScalarVocabularies() {
    #expect(SessionStateKind.allCases == [
      .idle, .prepared, .focusing, .paused, .checkingIn,
      .breaking, .reentering, .reviewing, .completed, .recoveryNeeded,
    ])
    #expect(SessionStateKind.allCases.count == 10)
    #expect(SessionStateKind.focusing.rawValue == "focusing")

    #expect(SessionIntentKind.allCases == [
      .prepare, .updatePrepared, .start, .pause, .resume, .openCheckIn,
      .respondToCheckIn, .acceptRevisedAction, .requestBreak, .endBreak,
      .parkThought, .setCheckInSchedule, .setBreakSuggestionsEnabled,
      .setLowCognitiveLoadEnabled, .setReflectionPromptEnabled, .stop,
      .updateReviewReflection, .finalizeReview, .resolveActiveSessionConflict,
      .reconcileTime, .recoverClock,
    ])
    #expect(SessionIntentKind.allCases.count == 21)
    #expect(SessionIntentKind.recoverClock.rawValue == "recoverClock")

    #expect(SessionEventKind.allCases.count == 25)
    #expect(SessionEventKind.sessionPrepared.rawValue == "sessionPrepared")
    #expect(SessionEventKind.sessionCompleted.rawValue == "sessionCompleted")

    #expect(SessionEffectKind.allCases == [
      .scheduleNotification, .cancelNotification, .playSound, .playHaptic,
      .announceAccessibility, .invalidateDisplayProjection,
    ])
    #expect(SessionEffectKind.allCases.count == 6)
    #expect(SessionEffectKind.playHaptic.rawValue == "playHaptic")

    #expect(CheckInResponseKind.allCases == [
      .continueFocus, .makeSmaller, .detour, .takeBreak, .skip, .dismiss,
    ])
    #expect(CheckInResponseKind.allCases.count == 6)
    #expect(CheckInResponseKind.continueFocus == .continueFocus)

    #expect(RecoveryReason.allCases == [
      .missingLiveProjection, .staleLiveProjection, .inconsistentLiveProjectionAnchor,
      .negativeMonotonicElapsed, .wallClockAmbiguousAfterRelaunch, .arithmeticOverflow,
    ])
    #expect(RecoveryReason.allCases.count == 6)
    #expect(RecoveryReason.staleLiveProjection.rawValue == "staleLiveProjection")

    #expect(RepositoryFailureKind.allCases == [
      .unavailable, .readFailed, .writeFailed, .validationFailed, .migrationFailed,
    ])
    #expect(RepositoryFailureKind.allCases.count == 5)
    #expect(RepositoryFailureKind.writeFailed == .writeFailed)

    #expect(PlatformStatus.allCases == [
      .notificationPermissionDenied, .notificationSchedulingFailed, .soundUnavailable,
      .hapticUnavailable, .accessibilityAnnouncementUnavailable, .adapterUnavailable,
      .runtimeUnavailable,
    ])
    #expect(PlatformStatus.allCases.count == 7)
    #expect(PlatformStatus.runtimeUnavailable.rawValue == "runtimeUnavailable")
  }

  @Test("non-CaseIterable scalar vocabularies retain their closed cases")
  func nonCaseIterableScalarVocabularies() {
    let stopReasons: [SessionStopReason] = [
      .completed, .intentionalStop, .replacedByAnotherSession,
      .clockRecoveryReview, .clockRecoveryEnd,
    ]
    #expect(stopReasons.count == 5)
    #expect(stopReasons[2] == .replacedByAnotherSession)
    #expect(SessionStopReason.clockRecoveryEnd.rawValue == "clockRecoveryEnd")

    let noChangeReasons: [NoChangeReason] = [
      .alreadyInRequestedState, .resumeCurrentSelected, .conflictCancelled,
      .observationIrrelevant, .earlierBoundaryPending,
    ]
    #expect(noChangeReasons.count == 5)
    #expect(noChangeReasons[4] == .earlierBoundaryPending)
    #expect(NoChangeReason.conflictCancelled.rawValue == "conflictCancelled")
  }

  @Test("failure and rejection vocabularies construct and compare structurally")
  func failureAndRejectionVocabularies() {
    let reduction = ReductionFailure.eventSequenceExhausted(
      requiredAdditionalEvents: 2,
      remainingCapacity: 1
    )
    #expect(reduction == .eventSequenceExhausted(requiredAdditionalEvents: 2, remainingCapacity: 1))
    #expect(reduction != .eventSequenceExhausted(requiredAdditionalEvents: 1, remainingCapacity: 1))
    #expect(ReductionFailure.nonFiniteWallObservation == .nonFiniteWallObservation)

    let rejection = SessionRejection.invalidTransition(state: .paused, intent: .start)
    #expect(rejection == .invalidTransition(state: .paused, intent: .start))
    #expect(rejection != .invalidTransition(state: .focusing, intent: .start))
    #expect(SessionRejection.staleRevision(expected: 4, actual: 3) == .staleRevision(expected: 4, actual: 3))

    let engineFailure = SessionEngineFailure.repositoryCommitFailed(.writeFailed)
    #expect(engineFailure == .repositoryCommitFailed(.writeFailed))
    #expect(engineFailure != .repositoryCommitFailed(.readFailed))
    #expect(SessionEngineFailure.unsupportedSnapshotSchema(found: 2) == .unsupportedSnapshotSchema(found: 2))
  }
}
