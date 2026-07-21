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
