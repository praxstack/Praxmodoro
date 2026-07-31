import Foundation
import Testing
@testable import Praxmodoro

@Suite struct CapabilityTests {
    // Spec: app-scaffold "Lite grant is total for this change".
    @Test func testLiteGrantIsTotal() {
        let registry = CapabilityRegistry(edition: .lite)
        for key in FeatureKey.allCases {
            #expect(registry.isAvailable(key), "\(key) must be available in Lite")
        }
    }

    // Spec: "Core support cannot be paywalled" — a configuration that tries
    // to gate the never-paywalled set fails validation, and the key still
    // resolves as available (release self-heal).
    @Test func testCorePaywallAttemptFailsValidation() {
        var grants = CapabilityRegistry.defaultGrants
        grants[.lite]?.remove(.checkins)
        let registry = CapabilityRegistry(edition: .lite, grants: grants)
        #expect(throws: CapabilityRegistry.ValidationError.self) {
            try registry.validate()
        }
        #expect(registry.isAvailable(.checkins), "never-paywalled keys self-heal to available")
    }
}
