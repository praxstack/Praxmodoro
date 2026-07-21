import Foundation

public enum EntitlementEvidenceSource: String, CaseIterable, Hashable, Sendable {
  case none
  case storeKit
  case signedEnterpriseLicense
  case staticDevelopment
}

public enum EntitlementFallbackReason: String, Hashable, Sendable {
  case verifierUnavailable
  case expired
  case invalidEvidence
}

public enum EntitlementResolutionStatus: Equatable, Sendable {
  case liteBaseline
  case verified
  case development
  case fallback(EntitlementFallbackReason)
}

public struct UntrustedEntitlementClaim: Equatable, Sendable {
  public let requestedTier: ProductTier
  public let source: EntitlementEvidenceSource
  public let issuedAt: Date?
  public let expiresAt: Date?

  public init(
    requestedTier: ProductTier,
    source: EntitlementEvidenceSource,
    issuedAt: Date?,
    expiresAt: Date?
  ) {
    self.requestedTier = requestedTier
    self.source = source
    self.issuedAt = issuedAt
    self.expiresAt = expiresAt
  }
}

struct VerifiedGrant: Equatable, Sendable {
  let tier: ProductTier
  let source: EntitlementEvidenceSource
  let issuedAt: Date
  let expiresAt: Date
  let limits: EntitlementLimits

  #if DEBUG
    static func validatedForTesting(
      tier: ProductTier,
      source: EntitlementEvidenceSource,
      issuedAt: Date,
      expiresAt: Date,
      verifiedAt: Date,
      limits: EntitlementLimits = .none
    ) -> VerifiedGrant? {
      guard issuedAt <= verifiedAt, verifiedAt < expiresAt else { return nil }

      let sourceMatchesTier =
        switch (source, tier) {
        case (.storeKit, .pro), (.signedEnterpriseLicense, .enterprise):
          true
        case (.staticDevelopment, .pro), (.staticDevelopment, .enterprise):
          true
        case (.none, _), (.storeKit, _), (.signedEnterpriseLicense, _),
          (.staticDevelopment, .lite):
          false
        }

      guard sourceMatchesTier else { return nil }
      return VerifiedGrant(
        tier: tier,
        source: source,
        issuedAt: issuedAt,
        expiresAt: expiresAt,
        limits: limits
      )
    }
  #endif

  private init(
    tier: ProductTier,
    source: EntitlementEvidenceSource,
    issuedAt: Date,
    expiresAt: Date,
    limits: EntitlementLimits
  ) {
    self.tier = tier
    self.source = source
    self.issuedAt = issuedAt
    self.expiresAt = expiresAt
    self.limits = limits
  }
}

public struct EntitlementLimits: Equatable, Sendable {
  public let maximumCounts: [ProductCapability: Int]

  public init(maximumCounts: [ProductCapability: Int] = [:]) {
    self.maximumCounts = maximumCounts
  }

  public static let none = EntitlementLimits()
}

public enum UnavailableCapabilityReason: Hashable, Sendable {
  case notImplemented
  case runtimeUnavailable
  case missingAuthorization(AuthorizationPrerequisite)
  case missingPlatformEligibility(PlatformEligibilityPrerequisite)
  case missingDistribution(DistributionPrerequisite)
  case disabledByPolicy(ManagedConfigurationField)
}

public struct CapabilityEnvironment: Equatable, Sendable {
  public let authorizations: Set<AuthorizationPrerequisite>
  public let platformEligibility: Set<PlatformEligibilityPrerequisite>
  public let distribution: Set<DistributionPrerequisite>
  public let implementedCapabilities: Set<ProductCapability>
  public let runtimeAvailableCapabilities: Set<ProductCapability>

  public init(
    authorizations: Set<AuthorizationPrerequisite>,
    platformEligibility: Set<PlatformEligibilityPrerequisite>,
    distribution: Set<DistributionPrerequisite>,
    implementedCapabilities: Set<ProductCapability>,
    runtimeAvailableCapabilities: Set<ProductCapability>
  ) {
    self.authorizations = authorizations
    self.platformEligibility = platformEligibility
    self.distribution = distribution
    self.implementedCapabilities = implementedCapabilities
    self.runtimeAvailableCapabilities = runtimeAvailableCapabilities
  }

  public static let unavailable = CapabilityEnvironment(
    authorizations: [],
    platformEligibility: [],
    distribution: [],
    implementedCapabilities: [],
    runtimeAvailableCapabilities: []
  )
}

public enum PolicyValueSource: String, CaseIterable, Hashable, Sendable {
  case osSafety
  case enforcedManaged
  case user
  case recommendedManaged
  case appDefault
}

public struct ResolvedPolicyValue<Value: Equatable & Sendable>: Equatable, Sendable {
  public let value: Value
  public let source: PolicyValueSource

  public init(value: Value, source: PolicyValueSource) {
    self.value = value
    self.source = source
  }
}

public struct OSSafetyRestrictions: Equatable, Sendable {
  public let diagnosticsAllowed: Bool?
  public let outboundSyncAllowed: Bool?

  public init(diagnosticsAllowed: Bool? = nil, outboundSyncAllowed: Bool? = nil) {
    self.diagnosticsAllowed = diagnosticsAllowed
    self.outboundSyncAllowed = outboundSyncAllowed
  }
}

public struct UserProductPreferences: Equatable, Sendable {
  public let diagnosticsEnabled: Bool?
  public let outboundSyncEnabled: Bool?
  public let coachCadenceMinutes: Int?

  public init(
    diagnosticsEnabled: Bool? = nil,
    outboundSyncEnabled: Bool? = nil,
    coachCadenceMinutes: Int? = nil
  ) {
    self.diagnosticsEnabled = diagnosticsEnabled
    self.outboundSyncEnabled = outboundSyncEnabled
    self.coachCadenceMinutes = coachCadenceMinutes
  }
}

public struct ProductPolicyDefaults: Equatable, Sendable {
  public let coachCadenceMinutes: Int

  public init(coachCadenceMinutes: Int = 15) {
    self.coachCadenceMinutes = coachCadenceMinutes
  }
}

public struct ResolvedProductPolicy: Equatable, Sendable {
  public let diagnosticsEnabled: ResolvedPolicyValue<Bool>
  public let outboundSyncEnabled: ResolvedPolicyValue<Bool>
  public let coachCadenceMinutes: ResolvedPolicyValue<Int>
}

public enum ManagedConfigurationField: String, CaseIterable, Hashable, Sendable {
  case diagnosticsAllowed
  case outboundSyncAllowed
  case recommendedDiagnosticsEnabled
  case recommendedOutboundSyncEnabled
  case updateChannel
  case configurationVersion
}

public enum ManagedUpdateChannel: String, CaseIterable, Hashable, Sendable {
  case stable
  case preview
}

public struct ManagedConfiguration: Equatable, Sendable {
  public let diagnosticsAllowed: Bool?
  public let outboundSyncAllowed: Bool?
  public let recommendedDiagnosticsEnabled: Bool?
  public let recommendedOutboundSyncEnabled: Bool?
  public let updateChannel: ManagedUpdateChannel?
  public let configurationVersion: UInt?

  public init(
    diagnosticsAllowed: Bool? = nil,
    outboundSyncAllowed: Bool? = nil,
    recommendedDiagnosticsEnabled: Bool? = nil,
    recommendedOutboundSyncEnabled: Bool? = nil,
    updateChannel: ManagedUpdateChannel? = nil,
    configurationVersion: UInt? = nil
  ) {
    self.diagnosticsAllowed = diagnosticsAllowed
    self.outboundSyncAllowed = outboundSyncAllowed
    self.recommendedDiagnosticsEnabled = recommendedDiagnosticsEnabled
    self.recommendedOutboundSyncEnabled = recommendedOutboundSyncEnabled
    self.updateChannel = updateChannel
    self.configurationVersion = configurationVersion
  }

  public var populatedFields: Set<ManagedConfigurationField> {
    var fields: Set<ManagedConfigurationField> = []
    if diagnosticsAllowed != nil { fields.insert(.diagnosticsAllowed) }
    if outboundSyncAllowed != nil { fields.insert(.outboundSyncAllowed) }
    if recommendedDiagnosticsEnabled != nil { fields.insert(.recommendedDiagnosticsEnabled) }
    if recommendedOutboundSyncEnabled != nil { fields.insert(.recommendedOutboundSyncEnabled) }
    if updateChannel != nil { fields.insert(.updateChannel) }
    if configurationVersion != nil { fields.insert(.configurationVersion) }
    return fields
  }
}

public enum ConfigurationAuditField: String, CaseIterable, Hashable, Sendable {
  case configurationKey
  case resolvedSource
  case timestamp
  case configurationVersion
}

public struct CapabilityResolutionContext: Equatable, Sendable {
  public let environment: CapabilityEnvironment
  public let osSafety: OSSafetyRestrictions
  public let managed: ManagedConfiguration
}

public struct EntitlementSnapshot: Equatable, Sendable {
  public let requiredLiteFeatures: Set<RequiredLiteFeature>
  public let grantedCapabilities: Set<ProductCapability>
  public let availableCapabilities: Set<ProductCapability>
  public let unavailableCapabilities: [ProductCapability: Set<UnavailableCapabilityReason>]
  public let status: EntitlementResolutionStatus
  public let evidenceSource: EntitlementEvidenceSource
  public let issuedAt: Date?
  public let expiresAt: Date?
  public let limits: EntitlementLimits
  public let policy: ResolvedProductPolicy
  public let resolutionContext: CapabilityResolutionContext
  public let nextReevaluationAt: Date?

  init(
    grantedCapabilities: Set<ProductCapability>,
    availableCapabilities: Set<ProductCapability>,
    unavailableCapabilities: [ProductCapability: Set<UnavailableCapabilityReason>],
    status: EntitlementResolutionStatus,
    evidenceSource: EntitlementEvidenceSource,
    issuedAt: Date?,
    expiresAt: Date?,
    limits: EntitlementLimits,
    policy: ResolvedProductPolicy,
    resolutionContext: CapabilityResolutionContext,
    nextReevaluationAt: Date?
  ) {
    requiredLiteFeatures = ProductRules.requiredLiteFeatures
    self.grantedCapabilities = grantedCapabilities
    self.availableCapabilities = availableCapabilities
    self.unavailableCapabilities = unavailableCapabilities
    self.status = status
    self.evidenceSource = evidenceSource
    self.issuedAt = issuedAt
    self.expiresAt = expiresAt
    self.limits = limits
    self.policy = policy
    self.resolutionContext = resolutionContext
    self.nextReevaluationAt = nextReevaluationAt
  }
}

struct SessionStartCommitReceipt: Equatable, Sendable {
  let sessionID: UUID
  let startRevision: UInt64
  let committedAt: Date

  #if DEBUG
    static func validatedForTesting(
      sessionID: UUID,
      startRevision: UInt64,
      committedAt: Date
    ) -> SessionStartCommitReceipt? {
      guard startRevision > 0 else { return nil }
      return SessionStartCommitReceipt(
        sessionID: sessionID,
        startRevision: startRevision,
        committedAt: committedAt
      )
    }
  #endif

  private init(sessionID: UUID, startRevision: UInt64, committedAt: Date) {
    self.sessionID = sessionID
    self.startRevision = startRevision
    self.committedAt = committedAt
  }
}

struct SessionCapabilityLease: Equatable, Sendable {
  private let commit: SessionStartCommitReceipt
  private let snapshot: EntitlementSnapshot
  let capabilities: Set<ProductCapability>

  var sessionID: UUID { commit.sessionID }
  var startRevision: UInt64 { commit.startRevision }
  var committedAt: Date { commit.committedAt }

  static func issue(
    commit: SessionStartCommitReceipt,
    snapshot: EntitlementSnapshot
  ) -> SessionCapabilityLease? {
    guard snapshot.status == .verified || snapshot.status == .development,
      snapshot.issuedAt.map({ $0 <= commit.committedAt }) ?? false,
      snapshot.expiresAt.map({ commit.committedAt < $0 }) ?? false
    else {
      return nil
    }

    let leased = snapshot.availableCapabilities.filter {
      ProductRules.descriptors[$0]?.downgrade == .sessionBoundaryIfCommitted
    }
    guard !leased.isEmpty else { return nil }

    return SessionCapabilityLease(
      commit: commit,
      snapshot: snapshot,
      capabilities: leased
    )
  }

  func matches(
    activeCommit: SessionStartCommitReceipt,
    previousSnapshot: EntitlementSnapshot
  ) -> Bool {
    commit == activeCommit && snapshot == previousSnapshot
  }

  private init(
    commit: SessionStartCommitReceipt,
    snapshot: EntitlementSnapshot,
    capabilities: Set<ProductCapability>
  ) {
    self.commit = commit
    self.snapshot = snapshot
    self.capabilities = capabilities
  }
}

public struct CapabilityTransition: Equatable, Sendable {
  public let activeSessionCapabilities: Set<ProductCapability>
  public let nextOperationCapabilities: Set<ProductCapability>
}
