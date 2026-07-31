import Foundation

public enum ProductRules {
  public static let requiredLiteFeatures = Set(RequiredLiteFeature.allCases)

  public static let descriptors: [ProductCapability: CapabilityDescriptor] = [
    .advancedRecipes: CapabilityDescriptor(
      minimumTier: .pro,
      authorizations: [],
      platformEligibility: [],
      distribution: [.mainApplication],
      dataAccess: .localConfiguration,
      downgrade: .sessionBoundaryIfCommitted,
      implementation: .futureAdapter
    ),
    .richLocalAnalytics: CapabilityDescriptor(
      minimumTier: .pro,
      authorizations: [],
      platformEligibility: [],
      distribution: [.mainApplication],
      dataAccess: .localAggregates,
      downgrade: .immediate,
      implementation: .futureAdapter
    ),
    .automatedExports: CapabilityDescriptor(
      minimumTier: .pro,
      authorizations: [],
      platformEligibility: [],
      distribution: [.mainApplication],
      dataAccess: .localUserContent,
      downgrade: .immediate,
      implementation: .futureAdapter
    ),
    .iCloudSync: CapabilityDescriptor(
      minimumTier: .pro,
      authorizations: [],
      platformEligibility: [.iCloudAccount],
      distribution: [.mainApplication],
      dataAccess: .futureCloudUserContent,
      downgrade: .immediate,
      implementation: .futureAdapter
    ),
    .calendarIntegration: CapabilityDescriptor(
      minimumTier: .pro,
      authorizations: [.calendar],
      platformEligibility: [],
      distribution: [.mainApplication],
      dataAccess: .futureExternalMetadata,
      downgrade: .immediate,
      implementation: .futureAdapter
    ),
    .appIntents: CapabilityDescriptor(
      minimumTier: .pro,
      authorizations: [],
      platformEligibility: [.appIntentsAvailability],
      distribution: [.mainApplication],
      dataAccess: .futureSystemAutomation,
      downgrade: .immediate,
      implementation: .futureAdapter
    ),
    .onDeviceAI: CapabilityDescriptor(
      minimumTier: .pro,
      authorizations: [],
      platformEligibility: [.onDeviceModelEligibility],
      distribution: [.mainApplication],
      dataAccess: .localSensitiveContent,
      downgrade: .sessionBoundaryIfCommitted,
      implementation: .futureAdapter
    ),
    .enterpriseOfflineLicense: CapabilityDescriptor(
      minimumTier: .enterprise,
      authorizations: [],
      platformEligibility: [],
      distribution: [.signedEnterpriseLicense],
      dataAccess: .licenseMetadataOnly,
      downgrade: .immediate,
      implementation: .futureAdapter
    ),
    .managedPrivacyPolicy: CapabilityDescriptor(
      minimumTier: .enterprise,
      authorizations: [],
      platformEligibility: [.enterpriseManagement],
      distribution: [.enterpriseManagement],
      dataAccess: .managedConfigurationOnly,
      downgrade: .immediate,
      implementation: .futureAdapter
    ),
    .managedDefaults: CapabilityDescriptor(
      minimumTier: .enterprise,
      authorizations: [],
      platformEligibility: [.enterpriseManagement],
      distribution: [.enterpriseManagement],
      dataAccess: .managedConfigurationOnly,
      downgrade: .immediate,
      implementation: .futureAdapter
    ),
    .managedUpdates: CapabilityDescriptor(
      minimumTier: .enterprise,
      authorizations: [],
      platformEligibility: [.enterpriseManagement],
      distribution: [.enterpriseManagement],
      dataAccess: .versionMetadataOnly,
      downgrade: .immediate,
      implementation: .futureAdapter
    ),
    .configurationAudit: CapabilityDescriptor(
      minimumTier: .enterprise,
      authorizations: [],
      platformEligibility: [.enterpriseManagement],
      distribution: [.enterpriseManagement],
      dataAccess: .managedConfigurationOnly,
      downgrade: .immediate,
      implementation: .futureAdapter
    ),
  ]

  public static func eligibleCapabilities(for tier: ProductTier) -> Set<ProductCapability> {
    Set(
      descriptors.compactMap { capability, descriptor in
        tier.includes(descriptor.minimumTier) ? capability : nil
      }
    )
  }
}

extension ProductRules {
  public static func resolveProduction(
    claim: UntrustedEntitlementClaim?,
    environment: CapabilityEnvironment = .unavailable,
    osSafety: OSSafetyRestrictions = OSSafetyRestrictions(),
    user: UserProductPreferences = UserProductPreferences(),
    managed: ManagedConfiguration = ManagedConfiguration(),
    defaults: ProductPolicyDefaults = ProductPolicyDefaults(),
    now: Date
  ) -> EntitlementSnapshot {
    let resolvedPolicy = resolvePolicy(
      osSafety: osSafety,
      user: user,
      managed: managed,
      defaults: defaults
    )
    let resolutionContext = CapabilityResolutionContext(
      environment: environment,
      osSafety: osSafety,
      managed: managed
    )
    guard let claim else {
      return liteSnapshot(
        status: .liteBaseline,
        policy: resolvedPolicy,
        resolutionContext: resolutionContext
      )
    }

    return liteSnapshot(
      status: .fallback(.verifierUnavailable),
      evidenceSource: claim.source,
      issuedAt: claim.issuedAt,
      expiresAt: claim.expiresAt,
      policy: resolvedPolicy,
      resolutionContext: resolutionContext
    )
  }

  static func resolveValidatedForTesting(
    grant: VerifiedGrant,
    environment: CapabilityEnvironment = .unavailable,
    osSafety: OSSafetyRestrictions = OSSafetyRestrictions(),
    user: UserProductPreferences = UserProductPreferences(),
    managed: ManagedConfiguration = ManagedConfiguration(),
    defaults: ProductPolicyDefaults = ProductPolicyDefaults(),
    now: Date
  ) -> EntitlementSnapshot {
    let resolvedPolicy = resolvePolicy(
      osSafety: osSafety,
      user: user,
      managed: managed,
      defaults: defaults
    )
    let resolutionContext = CapabilityResolutionContext(
      environment: environment,
      osSafety: osSafety,
      managed: managed
    )
    guard grant.issuedAt <= now else {
      return liteSnapshot(
        status: .fallback(.invalidEvidence),
        evidenceSource: grant.source,
        issuedAt: grant.issuedAt,
        expiresAt: grant.expiresAt,
        limits: grant.limits,
        policy: resolvedPolicy,
        resolutionContext: resolutionContext,
        nextReevaluationAt: grant.issuedAt
      )
    }
    guard now < grant.expiresAt else {
      return liteSnapshot(
        status: .fallback(.expired),
        evidenceSource: grant.source,
        issuedAt: grant.issuedAt,
        expiresAt: grant.expiresAt,
        limits: grant.limits,
        policy: resolvedPolicy,
        resolutionContext: resolutionContext
      )
    }

    let granted = eligibleCapabilities(for: grant.tier)
    var available: Set<ProductCapability> = []
    var unavailable: [ProductCapability: Set<UnavailableCapabilityReason>] = [:]

    for capability in granted {
      guard let descriptor = descriptors[capability] else {
        unavailable[capability] = [.notImplemented]
        continue
      }

      var reasons: Set<UnavailableCapabilityReason> = []
      if !environment.implementedCapabilities.contains(capability) {
        reasons.insert(.notImplemented)
      }
      if !environment.runtimeAvailableCapabilities.contains(capability) {
        reasons.insert(.runtimeUnavailable)
      }
      for missing in descriptor.authorizations.subtracting(environment.authorizations) {
        reasons.insert(.missingAuthorization(missing))
      }
      for missing in descriptor.platformEligibility.subtracting(environment.platformEligibility) {
        reasons.insert(.missingPlatformEligibility(missing))
      }
      for missing in descriptor.distribution.subtracting(environment.distribution) {
        reasons.insert(.missingDistribution(missing))
      }
      if capability == .iCloudSync && !resolvedPolicy.outboundSyncEnabled.value {
        reasons.insert(.disabledByPolicy(.outboundSyncAllowed))
      }

      if reasons.isEmpty {
        available.insert(capability)
      } else {
        unavailable[capability] = reasons
      }
    }

    return EntitlementSnapshot(
      grantedCapabilities: granted,
      availableCapabilities: available,
      unavailableCapabilities: unavailable,
      status: grant.source == .staticDevelopment ? .development : .verified,
      evidenceSource: grant.source,
      issuedAt: grant.issuedAt,
      expiresAt: grant.expiresAt,
      limits: grant.limits,
      policy: resolvedPolicy,
      resolutionContext: resolutionContext,
      nextReevaluationAt: grant.expiresAt
    )
  }

  public static func resolvePolicy(
    osSafety: OSSafetyRestrictions = OSSafetyRestrictions(),
    user: UserProductPreferences = UserProductPreferences(),
    managed: ManagedConfiguration = ManagedConfiguration(),
    defaults: ProductPolicyDefaults = ProductPolicyDefaults()
  ) -> ResolvedProductPolicy {
    ResolvedProductPolicy(
      diagnosticsEnabled: resolveConsentBoundBoolean(
        osAllowed: osSafety.diagnosticsAllowed,
        managedAllowed: managed.diagnosticsAllowed,
        userEnabled: user.diagnosticsEnabled,
        recommendedEnabled: managed.recommendedDiagnosticsEnabled,
        defaultValue: false
      ),
      outboundSyncEnabled: resolveConsentBoundBoolean(
        osAllowed: osSafety.outboundSyncAllowed,
        managedAllowed: managed.outboundSyncAllowed,
        userEnabled: user.outboundSyncEnabled,
        recommendedEnabled: managed.recommendedOutboundSyncEnabled,
        defaultValue: false
      ),
      coachCadenceMinutes: resolveCadence(
        userValue: user.coachCadenceMinutes,
        defaultValue: defaults.coachCadenceMinutes
      )
    )
  }

  static func transition(
    from previous: EntitlementSnapshot,
    to next: EntitlementSnapshot,
    now: Date,
    activeCommit: SessionStartCommitReceipt?,
    activeLease: SessionCapabilityLease?
  ) -> CapabilityTransition {
    guard previous.status == .verified || previous.status == .development,
      previous.expiresAt.map({ $0 <= now }) ?? false,
      next.status == .fallback(.expired),
      next.evidenceSource == previous.evidenceSource,
      next.issuedAt == previous.issuedAt,
      next.expiresAt == previous.expiresAt,
      next.limits == previous.limits,
      next.grantedCapabilities.isEmpty,
      next.availableCapabilities.isEmpty,
      previous.resolutionContext == next.resolutionContext,
      previous.policy == next.policy,
      let activeCommit,
      let activeLease,
      activeLease.matches(activeCommit: activeCommit, previousSnapshot: previous)
    else {
      return CapabilityTransition(
        activeSessionCapabilities: next.availableCapabilities,
        nextOperationCapabilities: next.availableCapabilities
      )
    }

    let preserved: Set<ProductCapability> = Set(
      activeLease.capabilities.compactMap { capability in
        guard previous.availableCapabilities.contains(capability),
          descriptors[capability]?.downgrade == .sessionBoundaryIfCommitted
        else {
          return nil
        }
        return capability
      }
    )

    return CapabilityTransition(
      activeSessionCapabilities: next.availableCapabilities.union(preserved),
      nextOperationCapabilities: next.availableCapabilities
    )
  }

  private static func liteSnapshot(
    status: EntitlementResolutionStatus,
    evidenceSource: EntitlementEvidenceSource = .none,
    issuedAt: Date? = nil,
    expiresAt: Date? = nil,
    limits: EntitlementLimits = .none,
    policy: ResolvedProductPolicy,
    resolutionContext: CapabilityResolutionContext,
    nextReevaluationAt: Date? = nil
  ) -> EntitlementSnapshot {
    EntitlementSnapshot(
      grantedCapabilities: [],
      availableCapabilities: [],
      unavailableCapabilities: [:],
      status: status,
      evidenceSource: evidenceSource,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      limits: limits,
      policy: policy,
      resolutionContext: resolutionContext,
      nextReevaluationAt: nextReevaluationAt
    )
  }

  private static func resolveConsentBoundBoolean(
    osAllowed: Bool?,
    managedAllowed: Bool?,
    userEnabled: Bool?,
    recommendedEnabled: Bool?,
    defaultValue: Bool
  ) -> ResolvedPolicyValue<Bool> {
    if osAllowed == false {
      return ResolvedPolicyValue(value: false, source: .osSafety)
    }
    if managedAllowed == false {
      return ResolvedPolicyValue(value: false, source: .enforcedManaged)
    }
    if let userEnabled {
      return ResolvedPolicyValue(value: userEnabled, source: .user)
    }
    if recommendedEnabled == false {
      return ResolvedPolicyValue(value: false, source: .recommendedManaged)
    }
    return ResolvedPolicyValue(value: defaultValue, source: .appDefault)
  }

  private static func resolveCadence(
    userValue: Int?,
    defaultValue: Int
  ) -> ResolvedPolicyValue<Int> {
    if let userValue {
      return ResolvedPolicyValue(value: userValue, source: .user)
    }
    return ResolvedPolicyValue(value: defaultValue, source: .appDefault)
  }
}
