/// The complete persisted lifecycle vocabulary for a focus session.
public enum SessionStateKind: String, CaseIterable, Equatable, Hashable, Sendable {
  case idle
  case prepared
  case focusing
  case paused
  case checkingIn
  case breaking
  case reentering
  case reviewing
  case completed
  case recoveryNeeded
}

/// The four immutable timing presets shipped in the first release.
public enum TimingPolicyID: String, CaseIterable, Equatable, Hashable, Sendable {
  case gentleStart
  case classic
  case flow
  case recoveryFirst
}

extension TimingPolicyID {
  public var requiredLiteFeature: RequiredLiteFeature {
    switch self {
    case .gentleStart: .gentleStart
    case .classic: .classic
    case .flow: .flow
    case .recoveryFirst: .recoveryFirst
    }
  }
}

public enum SessionTextField: String, Hashable, Sendable {
  case task, firstAction, revisedAction, thought, detourNote, reflection
}

public enum DomainValidationError: Error, Equatable, Sendable {
  case textTooLong(field: SessionTextField, maximumScalars: UInt16)
  case intervalOutOfRange(actual: UInt16, allowed: ClosedRange<UInt16>)
  case checkInRemainingOutOfRange(actual: UInt32, allowed: ClosedRange<UInt32>)
  case breakDurationOutOfRange(actual: UInt16, allowed: ClosedRange<UInt16>)
  case phaseDurationOutOfRange(actual: UInt32, allowed: ClosedRange<UInt32>)
  case invalidPolicyDefinition(TimingPolicyID)
}

public struct CheckInMinutes: Equatable, Hashable, Sendable {
  public let value: UInt16

  public init(_ value: UInt16) throws {
    let allowed: ClosedRange<UInt16> = 5...120
    guard allowed.contains(value) else {
      throw DomainValidationError.intervalOutOfRange(actual: value, allowed: allowed)
    }
    self.value = value
  }

  public static let fifteen = try! CheckInMinutes(15)
}

public struct CheckInRemainingSeconds: Equatable, Hashable, Sendable {
  public let value: UInt32

  public init(_ value: UInt32) throws {
    let allowed: ClosedRange<UInt32> = 1...7_200
    guard allowed.contains(value) else {
      throw DomainValidationError.checkInRemainingOutOfRange(actual: value, allowed: allowed)
    }
    self.value = value
  }
}

public enum CheckInSchedule: Equatable, Sendable {
  case manualOnly
  case interval(CheckInMinutes)

  public static let every15Minutes = CheckInSchedule.interval(.fifteen)
}

public struct SessionConfiguration: Equatable, Sendable {
  public let checkInSchedule: CheckInSchedule
  public let breakSuggestionsEnabled: Bool
  public let lowCognitiveLoadEnabled: Bool
  public let reflectionPromptEnabled: Bool

  public init(
    checkInSchedule: CheckInSchedule,
    breakSuggestionsEnabled: Bool,
    lowCognitiveLoadEnabled: Bool,
    reflectionPromptEnabled: Bool
  ) {
    self.checkInSchedule = checkInSchedule
    self.breakSuggestionsEnabled = breakSuggestionsEnabled
    self.lowCognitiveLoadEnabled = lowCognitiveLoadEnabled
    self.reflectionPromptEnabled = reflectionPromptEnabled
  }

  public static let defaults = SessionConfiguration(
    checkInSchedule: .every15Minutes,
    breakSuggestionsEnabled: true,
    lowCognitiveLoadEnabled: false,
    reflectionPromptEnabled: true
  )
}

public enum SessionConfigurationIssue: Equatable, Sendable {
  case invalidResolvedCadence(actualMinutes: Int)
}

public struct SessionConfigurationResolution: Equatable, Sendable {
  public let configuration: SessionConfiguration
  public let issues: [SessionConfigurationIssue]
}

public enum SessionConfigurationResolver {
  public static func resolveSchedule(
    base: SessionConfiguration,
    explicitSchedule: CheckInSchedule?,
    resolvedPreferenceMinutes: Int?
  ) -> SessionConfigurationResolution {
    if let explicitSchedule {
      return SessionConfigurationResolution(
        configuration: replacingSchedule(base, with: explicitSchedule),
        issues: []
      )
    }
    guard let resolvedPreferenceMinutes else {
      return SessionConfigurationResolution(configuration: base, issues: [])
    }
    guard let minutes = try? CheckInMinutes(UInt16(exactly: resolvedPreferenceMinutes) ?? 0) else {
      return SessionConfigurationResolution(
        configuration: replacingSchedule(base, with: .every15Minutes),
        issues: [.invalidResolvedCadence(actualMinutes: resolvedPreferenceMinutes)]
      )
    }
    return SessionConfigurationResolution(
      configuration: replacingSchedule(base, with: .interval(minutes)),
      issues: []
    )
  }

  private static func replacingSchedule(
    _ configuration: SessionConfiguration,
    with schedule: CheckInSchedule
  ) -> SessionConfiguration {
    SessionConfiguration(
      checkInSchedule: schedule,
      breakSuggestionsEnabled: configuration.breakSuggestionsEnabled,
      lowCognitiveLoadEnabled: configuration.lowCognitiveLoadEnabled,
      reflectionPromptEnabled: configuration.reflectionPromptEnabled
    )
  }
}

public enum SessionDefaults {
  public static let selectedPolicy: TimingPolicyID = .gentleStart
  public static let wallMonotonicDriftTolerance: Duration = .seconds(2)
  public static let visualProjectionCadence: Duration = .seconds(1)
  public static let askBeforeAnotherBlock = true
  public static let maximumParkedThoughts = 1_000
}

public enum Capacity: String, CaseIterable, Equatable, Sendable {
  case foggy, steady, restless, charged
}

public struct SessionPlan: Equatable, Sendable {
  public let task: String
  public let firstAction: String
  public let capacity: Capacity?
  public let timingPolicy: TimingPolicy

  public init(
    task: String,
    firstAction: String,
    capacity: Capacity?,
    timingPolicy: TimingPolicy
  ) throws {
    self.task = try Self.normalized(task, field: .task, minimumScalars: 0)
    self.firstAction = try Self.normalized(firstAction, field: .firstAction, minimumScalars: 0)
    self.capacity = capacity
    self.timingPolicy = timingPolicy
  }

  private static func normalized(
    _ value: String,
    field: SessionTextField,
    minimumScalars: Int
  ) throws -> String {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let count = normalized.unicodeScalars.count
    guard count >= minimumScalars, count <= 500 else {
      throw DomainValidationError.textTooLong(field: field, maximumScalars: 500)
    }
    return normalized
  }
}

public struct SessionDraft: Equatable, Sendable {
  public let plan: SessionPlan
  public let configuration: SessionConfiguration

  public init(plan: SessionPlan, configuration: SessionConfiguration = .defaults) {
    self.plan = plan
    self.configuration = configuration
  }
}

public struct PhaseSeconds: Equatable, Hashable, Sendable {
  public let value: UInt32

  public init(_ value: UInt32) throws {
    let allowed: ClosedRange<UInt32> = 1...86_400
    guard allowed.contains(value) else {
      throw DomainValidationError.phaseDurationOutOfRange(actual: value, allowed: allowed)
    }
    self.value = value
  }
}

public struct BreakMinutes: Equatable, Hashable, Sendable {
  public let value: UInt16

  public init(_ value: UInt16) throws {
    let allowed: ClosedRange<UInt16> = 1...120
    guard allowed.contains(value) else {
      throw DomainValidationError.breakDurationOutOfRange(actual: value, allowed: allowed)
    }
    self.value = value
  }

  public static let five = try! BreakMinutes(5)
}

public enum PhaseDuration: Equatable, Hashable, Sendable {
  case timed(PhaseSeconds)
  case openEnded
}

public enum BreakDuration: Equatable, Hashable, Sendable {
  case openEnded
  case timed(BreakMinutes)
}

public enum SessionPhaseID: String, Equatable, Hashable, Sendable {
  case entry, focus, flow, recoveryRamp
}

public struct SessionPhaseDescriptor: Equatable, Hashable, Sendable {
  public let id: SessionPhaseID
  public let ordinal: UInt16
  public let duration: PhaseDuration

  internal init(id: SessionPhaseID, ordinal: UInt16, duration: PhaseDuration) {
    self.id = id
    self.ordinal = ordinal
    self.duration = duration
  }
}

public struct TimingPolicy: Equatable, Sendable {
  public let id: TimingPolicyID
  public let phases: [SessionPhaseDescriptor]
  public let suggestedBreak: BreakDuration?

  internal init(id: TimingPolicyID, phases: [SessionPhaseDescriptor], suggestedBreak: BreakDuration?) {
    self.id = id
    self.phases = phases
    self.suggestedBreak = suggestedBreak
  }

  public static let gentleStart = TimingPolicy(
    id: .gentleStart,
    phases: [
      SessionPhaseDescriptor(id: .entry, ordinal: 0, duration: .timed(try! PhaseSeconds(300))),
      SessionPhaseDescriptor(id: .focus, ordinal: 1, duration: .timed(try! PhaseSeconds(1_200))),
    ],
    suggestedBreak: .timed(.five)
  )

  public static let classic = TimingPolicy(
    id: .classic,
    phases: [SessionPhaseDescriptor(id: .focus, ordinal: 0, duration: .timed(try! PhaseSeconds(1_500)))],
    suggestedBreak: .timed(.five)
  )

  public static let flow = TimingPolicy(
    id: .flow,
    phases: [SessionPhaseDescriptor(id: .flow, ordinal: 0, duration: .openEnded)],
    suggestedBreak: nil
  )

  public static let recoveryFirst = TimingPolicy(
    id: .recoveryFirst,
    phases: [
      SessionPhaseDescriptor(id: .recoveryRamp, ordinal: 0, duration: .timed(try! PhaseSeconds(600))),
      SessionPhaseDescriptor(id: .focus, ordinal: 1, duration: .openEnded),
    ],
    suggestedBreak: .timed(.five)
  )

  public static let allV1 = [gentleStart, classic, flow, recoveryFirst]
}
