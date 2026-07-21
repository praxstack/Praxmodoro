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
