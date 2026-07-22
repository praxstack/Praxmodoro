import Foundation
import Testing
@testable import PraxodoroCore

@Suite("Session domain model")
struct SessionModelTests {
  @Test("the lifecycle vocabulary is closed")
  func lifecycleVocabularyIsClosed() {
    #expect(SessionStateKind.allCases == [
      .idle, .prepared, .focusing, .paused, .checkingIn,
      .breaking, .reentering, .reviewing, .completed, .recoveryNeeded,
    ])
  }

  @Test("the V1 timing policy vocabulary is closed")
  func timingPolicyVocabularyIsClosed() {
    #expect(TimingPolicyID.allCases == [
      .gentleStart, .classic, .flow, .recoveryFirst,
    ])
  }

  @Test("timestamps retain lawful equality for non-finite fixture values")
  func timestampEqualityIsLawfulForFixtures() {
    let finite = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 42))
    let sameFinite = SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 42))

    #expect(finite == sameFinite)
    #expect(Set([finite, sameFinite]).count == 1)
  }

  @Test("the default configuration is ADHD-aware but low-load is opt-in")
  func defaultConfigurationIsExact() {
    #expect(SessionConfiguration.defaults == SessionConfiguration(
      checkInSchedule: .every15Minutes,
      breakSuggestionsEnabled: true,
      lowCognitiveLoadEnabled: false,
      reflectionPromptEnabled: true
    ))
  }

  @Test("the immutable presets have their specified timing shapes")
  func timingPolicyShapesAreExact() {
    #expect(TimingPolicy.allV1 == [
      .gentleStart, .classic, .flow, .recoveryFirst,
    ])
    #expect(TimingPolicy.gentleStart.phases.map(\.duration) == [
      .timed(try! PhaseSeconds(300)), .timed(try! PhaseSeconds(1_200)),
    ])
    #expect(TimingPolicy.flow.suggestedBreak == nil)
    #expect(TimingPolicy.recoveryFirst.phases.map(\.duration) == [
      .timed(try! PhaseSeconds(600)), .openEnded,
    ])
  }

  @Test("a session plan preserves deliberate capacity and normalizes input")
  func sessionPlanPreservesCapacityAndNormalizesInput() throws {
    let plan = try SessionPlan(
      task: "  Write the outline  ",
      firstAction: "  Open the brief  ",
      capacity: .foggy,
      timingPolicy: .gentleStart
    )

    #expect(plan.task == "Write the outline")
    #expect(plan.firstAction == "Open the brief")
    #expect(plan.capacity == .foggy)
  }

  @Test("constrained minute values retain their exact rejected range")
  func constrainedMinuteValuesRejectOutOfRangeInput() {
    #expect(throws: DomainValidationError.intervalOutOfRange(actual: 4, allowed: 5...120)) {
      _ = try CheckInMinutes(4)
    }
    #expect(throws: DomainValidationError.breakDurationOutOfRange(actual: 121, allowed: 1...120)) {
      _ = try BreakMinutes(121)
    }
  }

  @Test("an explicit cadence always wins over an adapter preference")
  func explicitScheduleWinsDuringResolution() throws {
    let explicit = CheckInSchedule.interval(try CheckInMinutes(20))
    let resolved = SessionConfigurationResolver.resolveSchedule(
      base: .defaults,
      explicitSchedule: explicit,
      resolvedPreferenceMinutes: 45
    )

    #expect(resolved.configuration.checkInSchedule == explicit)
    #expect(resolved.issues.isEmpty)
  }

  @Test("an invalid adapter cadence falls back predictably")
  func invalidResolvedCadenceFallsBackToDefaultInterval() {
    let resolved = SessionConfigurationResolver.resolveSchedule(
      base: .defaults,
      explicitSchedule: nil,
      resolvedPreferenceMinutes: 121
    )

    #expect(resolved.configuration.checkInSchedule == .every15Minutes)
    #expect(resolved.issues == [.invalidResolvedCadence(actualMinutes: 121)])
  }

  @Test("each command intent maps to its closed persisted kind")
  func intentKindsAreExhaustive() {
    #expect(SessionIntentKind.allCases.count == 21)
    #expect(SessionIntent.start.kind == .start)
    #expect(SessionIntent.pause.kind == .pause)
    #expect(SessionIntent.setLowCognitiveLoadEnabled(true).kind == .setLowCognitiveLoadEnabled)
    #expect(SessionIntent.recoverClock(.reviewSession).kind == .recoverClock)
  }

  @Test("the session defaults establish the deterministic engine contract")
  func sessionDefaultsAreExact() {
    #expect(SessionDefaults.selectedPolicy == .gentleStart)
    #expect(SessionDefaults.wallMonotonicDriftTolerance == .seconds(2))
    #expect(SessionDefaults.visualProjectionCadence == .seconds(1))
    #expect(SessionDefaults.askBeforeAnotherBlock)
    #expect(SessionDefaults.maximumParkedThoughts == 1_000)
  }

  @Test("the projection value preserves its complete display contract")
  func projectionVocabularyConstructsExactly() {
    let projection = SessionProjection(
      sourceRevision: 7,
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

    #expect(projection.state == .idle)
    #expect(projection.remainingSeconds == nil)
    #expect(projection.timingPolicy == nil)
  }

  @Test("projection errors retain typed snapshot failures")
  func projectionErrorsRetainTypedSnapshotFailures() {
    #expect(ProjectionError.invalidSnapshot([.invalidIdleBaseline]) ==
      .invalidSnapshot([.invalidIdleBaseline]))
  }

  @Test("state kinds map exhaustively without a default case")
  func stateKindMappingsCoverStaticStates() {
    #expect(SessionState.idle.kind == .idle)
  }

  @Test("event change sets reject empty payloads")
  func emptyEventChangeSetsAreUnconstructable() {
    #expect(SessionPlanFieldChanges([]) == nil)
    #expect(SessionConfigurationFieldChanges([]) == nil)
  }

  @Test("effects and check-in responses map to closed kinds")
  func effectAndResponseKindsAreExhaustive() {
    #expect(SessionEffect.playHaptic(.gentleBoundary).kind == .playHaptic)
    #expect(CheckInResponse.dismiss.kind == .dismiss)
    #expect(SessionEffectKind.allCases.count == 6)
    #expect(CheckInResponseKind.allCases.count == 6)
  }

  @Test("the canonical idle snapshot validates without repair")
  func canonicalIdleSnapshotIsValid() {
    #expect(SessionSnapshotValidator.validateCandidate(.canonicalIdle).isEmpty)
  }

  @Test("a malformed persisted timestamp identifies its exact field")
  func malformedTimestampUsesFieldSpecificViolation() {
    var snapshot = SessionSnapshot.canonicalIdle
    snapshot = SessionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      sessionID: snapshot.sessionID,
      revision: snapshot.revision,
      eventSequence: snapshot.eventSequence,
      nextBoundaryOccurrence: snapshot.nextBoundaryOccurrence,
      state: snapshot.state,
      plan: snapshot.plan,
      configuration: snapshot.configuration,
      parkedThoughts: snapshot.parkedThoughts,
      startedAt: SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: 2.5)),
      accumulatedFocusSeconds: snapshot.accumulatedFocusSeconds,
      accumulatedBreakSeconds: snapshot.accumulatedBreakSeconds,
      lastWallObservationAt: snapshot.lastWallObservationAt,
      nextScheduledCheckIn: snapshot.nextScheduledCheckIn,
      lastConsumedBoundaryToken: snapshot.lastConsumedBoundaryToken
    )

    #expect(SessionSnapshotValidator.validateCandidate(snapshot).contains(.nonCanonicalTimestamp(.startedAt)))
  }
}
