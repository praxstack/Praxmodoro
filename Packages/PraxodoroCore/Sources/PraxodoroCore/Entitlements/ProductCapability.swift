public enum ProductTier: String, CaseIterable, Hashable, Sendable {
  case lite
  case pro
  case enterprise

  func includes(_ minimumTier: ProductTier) -> Bool {
    switch (self, minimumTier) {
    case (_, .lite), (.pro, .pro), (.enterprise, .pro), (.enterprise, .enterprise):
      true
    case (.lite, .pro), (.lite, .enterprise), (.pro, .enterprise):
      false
    }
  }
}

public enum RequiredLiteFeature: String, CaseIterable, Hashable, Sendable {
  case editableInitiation
  case focusPauseResume
  case gentleStart
  case classic
  case flow
  case recoveryFirst
  case deterministicBreakdown
  case configurableCheckIns
  case adaptiveExplainableBreaks
  case detourRecovery
  case reentryOrientation
  case thoughtParking
  case lowCognitiveLoad
  case descriptiveReview
  case localHistory
  case localNotifications
  case keyboardNavigation
  case voiceOver
  case reduceMotion
  case reduceTransparency
  case increaseContrast
  case differentiateWithoutColor
  case lowPowerFallback
  case privacyControls
  case dataExport
  case dataDeletion
  case mainWindow
  case menuBar
  case compactSurface
}

public enum ProductCapability: String, CaseIterable, Hashable, Sendable {
  case advancedRecipes
  case richLocalAnalytics
  case automatedExports
  case iCloudSync
  case calendarIntegration
  case appIntents
  case onDeviceAI
  case enterpriseOfflineLicense
  case managedPrivacyPolicy
  case managedDefaults
  case managedUpdates
  case configurationAudit
}

public enum AuthorizationPrerequisite: String, Hashable, Sendable {
  case calendar
}

public enum PlatformEligibilityPrerequisite: String, Hashable, Sendable {
  case iCloudAccount
  case appIntentsAvailability
  case onDeviceModelEligibility
  case enterpriseManagement
}

public enum DistributionPrerequisite: String, Hashable, Sendable {
  case mainApplication
  case signedEnterpriseLicense
  case enterpriseManagement
}

public enum DataAccessDecision: String, Hashable, Sendable {
  case localConfiguration
  case localAggregates
  case localUserContent
  case futureCloudUserContent
  case futureExternalMetadata
  case futureSystemAutomation
  case localSensitiveContent
  case licenseMetadataOnly
  case managedConfigurationOnly
  case versionMetadataOnly
}

public enum CapabilityDowngradeBehavior: String, Hashable, Sendable {
  case immediate
  case sessionBoundaryIfCommitted
}

public enum CapabilityImplementation: String, Hashable, Sendable {
  case futureAdapter
}

public struct CapabilityDescriptor: Equatable, Sendable {
  public let minimumTier: ProductTier
  public let authorizations: Set<AuthorizationPrerequisite>
  public let platformEligibility: Set<PlatformEligibilityPrerequisite>
  public let distribution: Set<DistributionPrerequisite>
  public let dataAccess: DataAccessDecision
  public let downgrade: CapabilityDowngradeBehavior
  public let implementation: CapabilityImplementation

  public init(
    minimumTier: ProductTier,
    authorizations: Set<AuthorizationPrerequisite>,
    platformEligibility: Set<PlatformEligibilityPrerequisite>,
    distribution: Set<DistributionPrerequisite>,
    dataAccess: DataAccessDecision,
    downgrade: CapabilityDowngradeBehavior,
    implementation: CapabilityImplementation
  ) {
    self.minimumTier = minimumTier
    self.authorizations = authorizations
    self.platformEligibility = platformEligibility
    self.distribution = distribution
    self.dataAccess = dataAccess
    self.downgrade = downgrade
    self.implementation = implementation
  }
}
