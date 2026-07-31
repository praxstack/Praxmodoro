import Testing

@testable import PraxodoroCore

@Suite
struct ProductRulesTests {
  @Test
  func requiredLiteInventoryIsExactAndUngateable() {
    let expected: Set<RequiredLiteFeature> = [
      .editableInitiation,
      .focusPauseResume,
      .gentleStart,
      .classic,
      .flow,
      .recoveryFirst,
      .deterministicBreakdown,
      .configurableCheckIns,
      .adaptiveExplainableBreaks,
      .detourRecovery,
      .reentryOrientation,
      .thoughtParking,
      .lowCognitiveLoad,
      .descriptiveReview,
      .localHistory,
      .localNotifications,
      .keyboardNavigation,
      .voiceOver,
      .reduceMotion,
      .reduceTransparency,
      .increaseContrast,
      .differentiateWithoutColor,
      .lowPowerFallback,
      .privacyControls,
      .dataExport,
      .dataDeletion,
      .mainWindow,
      .menuBar,
      .compactSurface,
    ]

    #expect(Set(RequiredLiteFeature.allCases) == expected)
    #expect(ProductRules.requiredLiteFeatures == expected)
  }

  @Test
  func everyOptionalCapabilityHasOneCompleteDescriptor() {
    let expected: [ProductCapability: CapabilityDescriptor] = [
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

    #expect(Set(ProductRules.descriptors.keys) == Set(ProductCapability.allCases))
    #expect(ProductRules.descriptors == expected)
  }

  @Test
  func editionEligibilityIsExact() {
    let expectedPro: Set<ProductCapability> = [
      .advancedRecipes,
      .richLocalAnalytics,
      .automatedExports,
      .iCloudSync,
      .calendarIntegration,
      .appIntents,
      .onDeviceAI,
    ]
    let expectedEnterpriseAdditions: Set<ProductCapability> = [
      .enterpriseOfflineLicense,
      .managedPrivacyPolicy,
      .managedDefaults,
      .managedUpdates,
      .configurationAudit,
    ]

    #expect(ProductRules.eligibleCapabilities(for: .lite).isEmpty)
    #expect(ProductRules.eligibleCapabilities(for: .pro) == expectedPro)
    #expect(
      ProductRules.eligibleCapabilities(for: .enterprise)
        == expectedPro.union(expectedEnterpriseAdditions)
    )
  }

  @Test
  func prerequisiteDimensionsRemainIndependent() throws {
    let calendar = try #require(ProductRules.descriptors[.calendarIntegration])
    #expect(calendar.authorizations == [.calendar])
    #expect(calendar.platformEligibility.isEmpty)
    #expect(calendar.distribution == [.mainApplication])

    let cloud = try #require(ProductRules.descriptors[.iCloudSync])
    #expect(cloud.authorizations.isEmpty)
    #expect(cloud.platformEligibility == [.iCloudAccount])

    let model = try #require(ProductRules.descriptors[.onDeviceAI])
    #expect(model.authorizations.isEmpty)
    #expect(model.platformEligibility == [.onDeviceModelEligibility])
  }

  @Test
  func blockerIsNotImpliedByAnyTier() {
    #expect(!ProductCapability.allCases.map(\.rawValue).contains("blockerExtension"))
  }

  @Test
  func enterpriseDataAccessIsConfigurationOnly() throws {
    for capability in ProductRules.eligibleCapabilities(for: .enterprise)
      .subtracting(ProductRules.eligibleCapabilities(for: .pro))
    {
      let descriptor = try #require(ProductRules.descriptors[capability])
      #expect(
        [
          DataAccessDecision.licenseMetadataOnly,
          .managedConfigurationOnly,
          .versionMetadataOnly,
        ].contains(descriptor.dataAccess)
      )
    }
  }
}
