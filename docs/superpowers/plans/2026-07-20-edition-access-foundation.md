# Edition Access Foundation Plan

> **Required mode:** test-driven, subagent-driven, one reviewed atom per commit. This plan creates
> policy value types only; it does not add StoreKit, CloudKit, EventKit, App Intents, Foundation
> Models, MDM, a blocker, an account, a server, or commerce UI.

**Goal:** Make the complete Lite ADHD/accessibility/privacy experience unconditional while
cataloging optional Pro/Enterprise capabilities and proving production cannot self-assert paid
access before a real verifier exists.

**Architecture:** `RequiredLiteFeature` is an audit inventory, never an entitlement gate.
`ProductCapability` contains only optional future capabilities. Every optional descriptor records
edition, authorization, platform, distribution, data access, downgrade, and implementation
status. Public claims are untrusted; internal validated grants drive downstream resolution in
tests. A closed policy schema protects consent and records provenance.

---

## Task 1: OpenSpec 2.1 — Safe Lite Inventory and Optional Capability Catalog

**Create:**

- `Packages/PraxodoroCore/Sources/PraxodoroCore/Entitlements/ProductCapability.swift`
- `Packages/PraxodoroCore/Sources/PraxodoroCore/Entitlements/ProductRules.swift`
- `Packages/PraxodoroCore/Tests/PraxodoroCoreTests/ProductRulesTests.swift`

### Step 1: Write the failing catalog tests

Create `ProductRulesTests.swift`:

```swift
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
```

Run:

```bash
swift test --package-path Packages/PraxodoroCore --filter ProductRulesTests
```

Expected RED: missing `RequiredLiteFeature`, `ProductCapability`, descriptor, and `ProductRules`
symbols. A zero-selected-tests result is not accepted; output must name `ProductRulesTests`.

### Step 2: Implement the exhaustive value types

Create `ProductCapability.swift`:

```swift
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
```

### Step 3: Implement the explicit descriptor registry and derived edition sets

Create `ProductRules.swift`:

```swift
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
```

No `default` switch or fallback descriptor exists. The exact-key test fails whenever a new enum
case lacks a full descriptor. The blocker is absent because its add-on entitlement/distribution
model belongs to a separate future OpenSpec change.

### Step 4: Format and prove GREEN

```bash
xcrun swift-format format --configuration .swift-format --recursive --in-place \
  Packages/PraxodoroCore/Sources Packages/PraxodoroCore/Tests
swift test --package-path Packages/PraxodoroCore --filter ProductRulesTests
swift test --package-path Packages/PraxodoroCore
bash scripts/verify-project-generation.sh
xcodebuild \
  -project Praxodoro.xcodeproj \
  -scheme Praxodoro \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData \
  build CODE_SIGNING_ALLOWED=NO
bash scripts/run-app-tests.sh
```

Required GREEN: six named registry tests, all package tests, stable generation/format, unsigned
build, and executed app/UI regression suites. Record the exact `RequiredLiteFeature` count from
the test output/evidence rather than hard-coding a narrative count.

### Step 5: Commit

```bash
git add Packages/PraxodoroCore
git commit -m "feat: define safe edition access catalog"
```

---

## Task 2: OpenSpec 2.2 — Validated Grants, Typed Policy, and Scoped Downgrade

**Create:**

- `Packages/PraxodoroCore/Sources/PraxodoroCore/Entitlements/EntitlementSnapshot.swift`
- `Packages/PraxodoroCore/Tests/PraxodoroCoreTests/EntitlementSnapshotTests.swift`

**Modify:** `ProductRules.swift`.

### Step 1: Write the failing entitlement and policy tests

Create `EntitlementSnapshotTests.swift`:

```swift
import Foundation
import Testing

@testable import PraxodoroCore

@Suite
struct EntitlementSnapshotTests {
  private let issuedAt = Date(timeIntervalSince1970: 1_800_000_000)
  private let now = Date(timeIntervalSince1970: 1_800_003_600)
  private let expiresAt = Date(timeIntervalSince1970: 1_800_007_200)

  @Test
  func noClaimProducesTheUnconditionalLiteBaseline() {
    let snapshot = ProductRules.resolveProduction(claim: nil, now: now)

    #expect(snapshot.status == .liteBaseline)
    #expect(snapshot.requiredLiteFeatures == Set(RequiredLiteFeature.allCases))
    #expect(snapshot.grantedCapabilities.isEmpty)
    #expect(snapshot.availableCapabilities.isEmpty)
    #expect(snapshot.nextReevaluationAt == nil)
  }

  @Test(arguments: EntitlementEvidenceSource.allCases)
  func publicClaimsCannotSelfVerifyPaidAccess(source: EntitlementEvidenceSource) {
    let claim = UntrustedEntitlementClaim(
      requestedTier: source == .storeKit ? .pro : .enterprise,
      source: source,
      issuedAt: issuedAt,
      expiresAt: expiresAt
    )

    let snapshot = ProductRules.resolveProduction(claim: claim, now: now)

    #expect(snapshot.status == .fallback(.verifierUnavailable))
    #expect(snapshot.grantedCapabilities.isEmpty)
    #expect(snapshot.availableCapabilities.isEmpty)
    #expect(snapshot.nextReevaluationAt == nil)
  }

  @Test
  func testingValidatorRejectsImpossibleSourceTierAndDateStates() {
    #expect(
      VerifiedGrant.validatedForTesting(
        tier: .enterprise,
        source: .storeKit,
        issuedAt: issuedAt,
        expiresAt: expiresAt,
        verifiedAt: now
      ) == nil
    )
    #expect(
      VerifiedGrant.validatedForTesting(
        tier: .enterprise,
        source: .signedEnterpriseLicense,
        issuedAt: expiresAt,
        expiresAt: issuedAt,
        verifiedAt: now
      ) == nil
    )
    #expect(
      VerifiedGrant.validatedForTesting(
        tier: .pro,
        source: .storeKit,
        issuedAt: expiresAt,
        expiresAt: expiresAt.addingTimeInterval(3_600),
        verifiedAt: now
      ) == nil
    )
  }

  @Test
  func validatedGrantSeparatesGrantedFromAvailable() throws {
    let grant = try #require(
      VerifiedGrant.validatedForTesting(
        tier: .pro,
        source: .storeKit,
        issuedAt: issuedAt,
        expiresAt: expiresAt,
        verifiedAt: now
      )
    )
    let environment = CapabilityEnvironment(
      authorizations: [],
      platformEligibility: [],
      distribution: [.mainApplication],
      implementedCapabilities: [.advancedRecipes, .calendarIntegration],
      runtimeAvailableCapabilities: [.advancedRecipes, .calendarIntegration]
    )

    let snapshot = ProductRules.resolveValidatedForTesting(
      grant: grant,
      environment: environment,
      now: now
    )

    #expect(snapshot.status == .verified)
    #expect(snapshot.grantedCapabilities == ProductRules.eligibleCapabilities(for: .pro))
    #expect(snapshot.availableCapabilities == [.advancedRecipes])
    #expect(
      snapshot.unavailableCapabilities[.calendarIntegration]
        == [.missingAuthorization(.calendar)]
    )
    #expect(
      snapshot.unavailableCapabilities[.iCloudSync]
        == [
          .notImplemented,
          .runtimeUnavailable,
          .missingPlatformEligibility(.iCloudAccount),
          .disabledByPolicy(.outboundSyncAllowed),
        ]
    )
    #expect(snapshot.nextReevaluationAt == expiresAt)
  }

  @Test
  func unavailableCapabilitiesRetainEverySimultaneousReason() throws {
    let grant = try #require(
      VerifiedGrant.validatedForTesting(
        tier: .pro,
        source: .storeKit,
        issuedAt: issuedAt,
        expiresAt: expiresAt,
        verifiedAt: now
      )
    )

    let snapshot = ProductRules.resolveValidatedForTesting(
      grant: grant,
      environment: .unavailable,
      now: now
    )

    #expect(
      snapshot.unavailableCapabilities[.calendarIntegration]
        == [
          .notImplemented,
          .runtimeUnavailable,
          .missingAuthorization(.calendar),
          .missingDistribution(.mainApplication),
        ]
    )
    #expect(
      snapshot.unavailableCapabilities[.iCloudSync]
        == [
          .notImplemented,
          .runtimeUnavailable,
          .missingPlatformEligibility(.iCloudAccount),
          .missingDistribution(.mainApplication),
          .disabledByPolicy(.outboundSyncAllowed),
        ]
    )
  }

  @Test
  func implementedCapabilityStillRequiresIndependentRuntimeAvailability() throws {
    let grant = try #require(
      VerifiedGrant.validatedForTesting(
        tier: .pro,
        source: .storeKit,
        issuedAt: issuedAt,
        expiresAt: expiresAt,
        verifiedAt: now
      )
    )
    let environment = CapabilityEnvironment(
      authorizations: [],
      platformEligibility: [],
      distribution: [.mainApplication],
      implementedCapabilities: [.advancedRecipes],
      runtimeAvailableCapabilities: []
    )

    let snapshot = ProductRules.resolveValidatedForTesting(
      grant: grant,
      environment: environment,
      now: now
    )

    #expect(snapshot.availableCapabilities.isEmpty)
    #expect(snapshot.unavailableCapabilities[.advancedRecipes] == [.runtimeUnavailable])
  }

  @Test
  func expiredValidatedGrantFailsClosedWithoutWeakeningLite() throws {
    let grant = try #require(
      VerifiedGrant.validatedForTesting(
        tier: .pro,
        source: .storeKit,
        issuedAt: issuedAt,
        expiresAt: now,
        verifiedAt: issuedAt
      )
    )

    let snapshot = ProductRules.resolveValidatedForTesting(grant: grant, now: now)

    #expect(snapshot.status == .fallback(.expired))
    #expect(snapshot.requiredLiteFeatures == Set(RequiredLiteFeature.allCases))
    #expect(snapshot.grantedCapabilities.isEmpty)
    #expect(snapshot.nextReevaluationAt == nil)
  }

  @Test
  func resolverDefensivelyRejectsGrantBeforeItsIssueTime() throws {
    let grant = try #require(
      VerifiedGrant.validatedForTesting(
        tier: .pro,
        source: .storeKit,
        issuedAt: now,
        expiresAt: expiresAt,
        verifiedAt: now
      )
    )

    let snapshot = ProductRules.resolveValidatedForTesting(
      grant: grant,
      now: now.addingTimeInterval(-1)
    )

    #expect(snapshot.status == .fallback(.invalidEvidence))
    #expect(snapshot.grantedCapabilities.isEmpty)
    #expect(snapshot.nextReevaluationAt == now)
  }

  @Test
  func developmentGrantIsVisiblyNonProduction() throws {
    let grant = try #require(
      VerifiedGrant.validatedForTesting(
        tier: .enterprise,
        source: .staticDevelopment,
        issuedAt: issuedAt,
        expiresAt: expiresAt,
        verifiedAt: now
      )
    )

    let snapshot = ProductRules.resolveValidatedForTesting(grant: grant, now: now)
    #expect(snapshot.status == .development)
    #expect(snapshot.evidenceSource == .staticDevelopment)
  }

  @Test
  func privacyPolicyReturnsSourceAndNeverUsesRecommendationAsConsent() {
    let osRestricted = ProductRules.resolvePolicy(
      osSafety: OSSafetyRestrictions(diagnosticsAllowed: false),
      user: UserProductPreferences(diagnosticsEnabled: true),
      managed: ManagedConfiguration(
        diagnosticsAllowed: true,
        recommendedDiagnosticsEnabled: true
      )
    )
    #expect(osRestricted.diagnosticsEnabled == ResolvedPolicyValue(value: false, source: .osSafety))

    let managedRestricted = ProductRules.resolvePolicy(
      user: UserProductPreferences(diagnosticsEnabled: true),
      managed: ManagedConfiguration(diagnosticsAllowed: false)
    )
    #expect(
      managedRestricted.diagnosticsEnabled
        == ResolvedPolicyValue(value: false, source: .enforcedManaged)
    )

    let explicitUser = ProductRules.resolvePolicy(
      user: UserProductPreferences(diagnosticsEnabled: true),
      managed: ManagedConfiguration(recommendedDiagnosticsEnabled: false)
    )
    #expect(explicitUser.diagnosticsEnabled == ResolvedPolicyValue(value: true, source: .user))

    let recommendationCanOptOut = ProductRules.resolvePolicy(
      managed: ManagedConfiguration(recommendedDiagnosticsEnabled: false)
    )
    #expect(
      recommendationCanOptOut.diagnosticsEnabled
        == ResolvedPolicyValue(value: false, source: .recommendedManaged)
    )

    let recommendationCannotOptIn = ProductRules.resolvePolicy(
      managed: ManagedConfiguration(recommendedDiagnosticsEnabled: true)
    )
    #expect(
      recommendationCannotOptIn.diagnosticsEnabled
        == ResolvedPolicyValue(value: false, source: .appDefault)
    )

    let defaultsAreStructurallyConsentSafe = ProductRules.resolvePolicy(
      defaults: ProductPolicyDefaults(coachCadenceMinutes: 30)
    )
    #expect(defaultsAreStructurallyConsentSafe.diagnosticsEnabled.value == false)
    #expect(defaultsAreStructurallyConsentSafe.outboundSyncEnabled.value == false)
    #expect(
      Set(Mirror(reflecting: ProductPolicyDefaults()).children.compactMap(\.label))
        == ["coachCadenceMinutes"]
    )
  }

  @Test
  func cadenceRemainsPersonalAndAbsentFromManagedConfiguration() {
    let userChoice = ProductRules.resolvePolicy(
      user: UserProductPreferences(coachCadenceMinutes: 20)
    )
    #expect(userChoice.coachCadenceMinutes == ResolvedPolicyValue(value: 20, source: .user))

    let appDefault = ProductRules.resolvePolicy(
      defaults: ProductPolicyDefaults(coachCadenceMinutes: 15)
    )
    #expect(appDefault.coachCadenceMinutes == ResolvedPolicyValue(value: 15, source: .appDefault))
  }

  @Test
  func managedSchemasContainOnlyApprovedConfigurationMetadata() {
    let expectedFields: Set<ManagedConfigurationField> = [
      .diagnosticsAllowed,
      .outboundSyncAllowed,
      .recommendedDiagnosticsEnabled,
      .recommendedOutboundSyncEnabled,
      .updateChannel,
      .configurationVersion,
    ]
    let completeFixture = ManagedConfiguration(
      diagnosticsAllowed: false,
      outboundSyncAllowed: false,
      recommendedDiagnosticsEnabled: false,
      recommendedOutboundSyncEnabled: false,
      updateChannel: .stable,
      configurationVersion: 1
    )

    #expect(Set(ManagedConfigurationField.allCases) == expectedFields)
    #expect(completeFixture.populatedFields == expectedFields)
    #expect(
      Set(Mirror(reflecting: completeFixture).children.compactMap(\.label))
        == Set(expectedFields.map(\.rawValue))
    )
    #expect(
      Set(ConfigurationAuditField.allCases) == [
        .configurationKey,
        .resolvedSource,
        .timestamp,
        .configurationVersion,
      ]
    )
  }

  @Test
  func downgradePreservesOnlyCommittedSessionBoundaryCapabilities() throws {
    let grant = try #require(
      VerifiedGrant.validatedForTesting(
        tier: .pro,
        source: .storeKit,
        issuedAt: issuedAt,
        expiresAt: expiresAt,
        verifiedAt: now
      )
    )
    let environment = CapabilityEnvironment(
      authorizations: [],
      platformEligibility: [.iCloudAccount],
      distribution: [.mainApplication],
      implementedCapabilities: [.advancedRecipes, .iCloudSync],
      runtimeAvailableCapabilities: [.advancedRecipes, .iCloudSync]
    )
    let previous = ProductRules.resolveValidatedForTesting(
      grant: grant,
      environment: environment,
      user: UserProductPreferences(outboundSyncEnabled: true),
      now: now
    )
    let next = ProductRules.resolveValidatedForTesting(
      grant: grant,
      environment: environment,
      user: UserProductPreferences(outboundSyncEnabled: true),
      now: expiresAt
    )
    let sessionID = try #require(
      UUID(uuidString: "11111111-1111-1111-1111-111111111111")
    )
    #expect(
      SessionStartCommitReceipt.validatedForTesting(
        sessionID: sessionID,
        startRevision: 0,
        committedAt: now
      ) == nil
    )
    let commit = try #require(
      SessionStartCommitReceipt.validatedForTesting(
        sessionID: sessionID,
        startRevision: 1,
        committedAt: now
      )
    )
    let lease = try #require(
      SessionCapabilityLease.issue(commit: commit, snapshot: previous)
    )
    #expect(lease.sessionID == sessionID)
    #expect(lease.startRevision == 1)
    #expect(lease.capabilities == [.advancedRecipes])

    let expiry = ProductRules.transition(
      from: previous,
      to: next,
      now: expiresAt,
      activeCommit: commit,
      activeLease: lease
    )
    #expect(expiry.activeSessionCapabilities == [.advancedRecipes])
    #expect(expiry.nextOperationCapabilities.isEmpty)

    let otherSessionID = try #require(
      UUID(uuidString: "22222222-2222-2222-2222-222222222222")
    )
    let otherCommit = try #require(
      SessionStartCommitReceipt.validatedForTesting(
        sessionID: otherSessionID,
        startRevision: 1,
        committedAt: now
      )
    )
    let mismatchedSession = ProductRules.transition(
      from: previous,
      to: next,
      now: expiresAt,
      activeCommit: otherCommit,
      activeLease: lease
    )
    #expect(mismatchedSession.activeSessionCapabilities.isEmpty)

    let changedRevisionCommit = try #require(
      SessionStartCommitReceipt.validatedForTesting(
        sessionID: sessionID,
        startRevision: 2,
        committedAt: now
      )
    )
    let changedRevision = ProductRules.transition(
      from: previous,
      to: next,
      now: expiresAt,
      activeCommit: changedRevisionCommit,
      activeLease: lease
    )
    #expect(changedRevision.activeSessionCapabilities.isEmpty)

    let changedCommitTimeCommit = try #require(
      SessionStartCommitReceipt.validatedForTesting(
        sessionID: sessionID,
        startRevision: 1,
        committedAt: now.addingTimeInterval(1)
      )
    )
    let changedCommitTime = ProductRules.transition(
      from: previous,
      to: next,
      now: expiresAt,
      activeCommit: changedCommitTimeCommit,
      activeLease: lease
    )
    #expect(changedCommitTime.activeSessionCapabilities.isEmpty)

    let differentPrevious = ProductRules.resolveValidatedForTesting(
      grant: grant,
      environment: environment,
      user: UserProductPreferences(outboundSyncEnabled: false),
      now: now
    )
    let differentNext = ProductRules.resolveValidatedForTesting(
      grant: grant,
      environment: environment,
      user: UserProductPreferences(outboundSyncEnabled: false),
      now: expiresAt
    )
    let mismatchedSnapshot = ProductRules.transition(
      from: differentPrevious,
      to: differentNext,
      now: expiresAt,
      activeCommit: commit,
      activeLease: lease
    )
    #expect(mismatchedSnapshot.activeSessionCapabilities.isEmpty)

    let differentLimitsGrant = try #require(
      VerifiedGrant.validatedForTesting(
        tier: .pro,
        source: .storeKit,
        issuedAt: issuedAt,
        expiresAt: expiresAt,
        verifiedAt: now,
        limits: EntitlementLimits(maximumCounts: [.advancedRecipes: 1])
      )
    )
    let differentLimitsNext = ProductRules.resolveValidatedForTesting(
      grant: differentLimitsGrant,
      environment: environment,
      user: UserProductPreferences(outboundSyncEnabled: true),
      now: expiresAt
    )
    let mismatchedLimits = ProductRules.transition(
      from: previous,
      to: differentLimitsNext,
      now: expiresAt,
      activeCommit: commit,
      activeLease: lease
    )
    #expect(mismatchedLimits.activeSessionCapabilities.isEmpty)

    let authorizationChanged = CapabilityEnvironment(
      authorizations: [.calendar],
      platformEligibility: [.iCloudAccount],
      distribution: [.mainApplication],
      implementedCapabilities: [.advancedRecipes, .iCloudSync],
      runtimeAvailableCapabilities: [.advancedRecipes, .iCloudSync]
    )
    let platformChanged = CapabilityEnvironment(
      authorizations: [],
      platformEligibility: [],
      distribution: [.mainApplication],
      implementedCapabilities: [.advancedRecipes, .iCloudSync],
      runtimeAvailableCapabilities: [.advancedRecipes, .iCloudSync]
    )
    let distributionChanged = CapabilityEnvironment(
      authorizations: [],
      platformEligibility: [.iCloudAccount],
      distribution: [],
      implementedCapabilities: [.advancedRecipes, .iCloudSync],
      runtimeAvailableCapabilities: [.advancedRecipes, .iCloudSync]
    )
    let runtimeChanged = CapabilityEnvironment(
      authorizations: [],
      platformEligibility: [.iCloudAccount],
      distribution: [.mainApplication],
      implementedCapabilities: [.advancedRecipes, .iCloudSync],
      runtimeAvailableCapabilities: [.iCloudSync]
    )
    let immediateSnapshots = [
      ProductRules.resolveValidatedForTesting(
        grant: grant,
        environment: authorizationChanged,
        user: UserProductPreferences(outboundSyncEnabled: true),
        now: expiresAt
      ),
      ProductRules.resolveValidatedForTesting(
        grant: grant,
        environment: platformChanged,
        user: UserProductPreferences(outboundSyncEnabled: true),
        now: expiresAt
      ),
      ProductRules.resolveValidatedForTesting(
        grant: grant,
        environment: distributionChanged,
        user: UserProductPreferences(outboundSyncEnabled: true),
        now: expiresAt
      ),
      ProductRules.resolveValidatedForTesting(
        grant: grant,
        environment: runtimeChanged,
        user: UserProductPreferences(outboundSyncEnabled: true),
        now: expiresAt
      ),
      ProductRules.resolveValidatedForTesting(
        grant: grant,
        environment: environment,
        osSafety: OSSafetyRestrictions(diagnosticsAllowed: false),
        user: UserProductPreferences(outboundSyncEnabled: true),
        now: expiresAt
      ),
      ProductRules.resolveValidatedForTesting(
        grant: grant,
        environment: environment,
        user: UserProductPreferences(outboundSyncEnabled: true),
        managed: ManagedConfiguration(diagnosticsAllowed: false),
        now: expiresAt
      ),
      ProductRules.resolveValidatedForTesting(
        grant: grant,
        environment: platformChanged,
        osSafety: OSSafetyRestrictions(diagnosticsAllowed: false),
        user: UserProductPreferences(outboundSyncEnabled: true),
        now: expiresAt
      ),
    ]
    for changedSnapshot in immediateSnapshots {
      let transition = ProductRules.transition(
        from: previous,
        to: changedSnapshot,
        now: expiresAt,
        activeCommit: commit,
        activeLease: lease
      )
      #expect(transition.activeSessionCapabilities.isEmpty)
    }

    let untrustedClaim = UntrustedEntitlementClaim(
      requestedTier: .pro,
      source: .storeKit,
      issuedAt: issuedAt,
      expiresAt: expiresAt
    )
    let nonExpirySnapshots = [
      ProductRules.resolveProduction(
        claim: nil,
        environment: environment,
        user: UserProductPreferences(outboundSyncEnabled: true),
        now: expiresAt
      ),
      ProductRules.resolveProduction(
        claim: untrustedClaim,
        environment: environment,
        user: UserProductPreferences(outboundSyncEnabled: true),
        now: expiresAt
      ),
    ]
    for nonExpirySnapshot in nonExpirySnapshots {
      let transition = ProductRules.transition(
        from: previous,
        to: nonExpirySnapshot,
        now: expiresAt,
        activeCommit: commit,
        activeLease: lease
      )
      #expect(transition.activeSessionCapabilities.isEmpty)
    }

    let otherEvidenceGrant = try #require(
      VerifiedGrant.validatedForTesting(
        tier: .pro,
        source: .staticDevelopment,
        issuedAt: issuedAt,
        expiresAt: expiresAt,
        verifiedAt: now
      )
    )
    let otherIssuedAtGrant = try #require(
      VerifiedGrant.validatedForTesting(
        tier: .pro,
        source: .storeKit,
        issuedAt: issuedAt.addingTimeInterval(1),
        expiresAt: expiresAt,
        verifiedAt: now
      )
    )
    let otherExpiryGrant = try #require(
      VerifiedGrant.validatedForTesting(
        tier: .pro,
        source: .storeKit,
        issuedAt: issuedAt,
        expiresAt: expiresAt.addingTimeInterval(1),
        verifiedAt: now
      )
    )
    let mismatchedEvidenceSnapshots = [
      ProductRules.resolveValidatedForTesting(
        grant: otherEvidenceGrant,
        environment: environment,
        user: UserProductPreferences(outboundSyncEnabled: true),
        now: expiresAt
      ),
      ProductRules.resolveValidatedForTesting(
        grant: otherIssuedAtGrant,
        environment: environment,
        user: UserProductPreferences(outboundSyncEnabled: true),
        now: expiresAt
      ),
      ProductRules.resolveValidatedForTesting(
        grant: otherExpiryGrant,
        environment: environment,
        user: UserProductPreferences(outboundSyncEnabled: true),
        now: expiresAt.addingTimeInterval(1)
      ),
    ]
    for mismatchedEvidenceSnapshot in mismatchedEvidenceSnapshots {
      let transition = ProductRules.transition(
        from: previous,
        to: mismatchedEvidenceSnapshot,
        now: expiresAt.addingTimeInterval(1),
        activeCommit: commit,
        activeLease: lease
      )
      #expect(transition.activeSessionCapabilities.isEmpty)
    }
  }
}
```

Run:

```bash
swift test --package-path Packages/PraxodoroCore --filter EntitlementSnapshotTests
```

Expected RED: missing claim, grant, snapshot, environment, policy, availability, and transition
symbols. Output must name `EntitlementSnapshotTests`; zero selected tests is not accepted.

### Step 2: Implement non-forgeable grant and snapshot value types

Create `EntitlementSnapshot.swift`:

```swift
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
```

### Step 3: Implement production fail-closed resolution and typed policy

Append after the `ProductRules` declaration as a same-file extension:

```swift
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
```

The public resolver deliberately cannot produce verified Pro or Enterprise access. The internal
testing validator and resolver exist only so the downstream catalog, prerequisite, policy,
expiry, and downgrade machinery is proved before future verifier adapters are separately
specified. There is no mutable truth Boolean and no UserDefaults license flag.

### Step 4: Format and prove GREEN

```bash
xcrun swift-format format --configuration .swift-format --recursive --in-place \
  Packages/PraxodoroCore/Sources Packages/PraxodoroCore/Tests
swift test --package-path Packages/PraxodoroCore --filter EntitlementSnapshotTests
swift test --package-path Packages/PraxodoroCore
bash scripts/verify-project-generation.sh
xcodebuild \
  -project Praxodoro.xcodeproj \
  -scheme Praxodoro \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData \
  build CODE_SIGNING_ALLOWED=NO
bash scripts/run-app-tests.sh
```

Required GREEN includes named tests for public fail-closed claims, private grant construction,
future-issued/expired/invalid grant combinations, granted/available separation with every missing
reason, visible development evidence, OS/enforced/user/recommended/default provenance,
structurally fixed-off consent defaults, the exhaustive managed/audit schemas, and opaque
session-ID/revision/snapshot-bound downgrade that survives expiry alone but no immediate or
combined safety change.

### Step 5: Commit

```bash
git add Packages/PraxodoroCore
git commit -m "feat: resolve validated product access"
```

## Plan Verification Checklist

- [ ] Required Lite features include initiation, all presets, check-ins, adaptive breaks, detour,
  re-entry, low-cognitive-load, explicit accessibility fallbacks, privacy/export/delete, and all
  local Mac surfaces.
- [ ] No required Lite feature is evaluated through a paid capability set.
- [ ] Every optional capability has an exact descriptor; no default metadata path exists.
- [ ] Privileged blocking is absent pending a separate add-on spec.
- [ ] Product eligibility, OS authorization, platform eligibility, distribution, adapter
  implementation, managed policy, and runtime availability remain separate.
- [ ] Public production claims cannot produce paid access in this change.
- [ ] Static development evidence is internal and visibly non-production.
- [ ] Paid grants are privately constructed and require coherent source/tier plus
  `issuedAt <= now < expiresAt` both during validation and defensive resolution.
- [ ] Every unavailable capability records all simultaneously missing prerequisites.
- [ ] One exhaustive managed-input schema contains no coach cadence or other personal behavior
  field.
- [ ] Diagnostics and sync defaults are structurally fixed off; a recommendation cannot opt the
  user in.
- [ ] Only an opaque committed session-ID/revision/full-snapshot-bound lease preserves capabilities
  whose descriptor explicitly permits boundary downgrade, and only when transition logic derives
expiry alone from time plus matching active commit and complete previous/next contexts.
- [ ] The expiry snapshot matches the prior validated evidence source, issue, expiry, and limits;
  missing claims, logout, or verifier-unavailable fallbacks preserve no leased capability.
- [ ] OS-safety, authorization, platform, distribution, enforced-privacy, and combined changes
  apply immediately.
- [ ] Full package, generation/format, unsigned build, and executed app/UI tests regress after
  both edition atoms.
