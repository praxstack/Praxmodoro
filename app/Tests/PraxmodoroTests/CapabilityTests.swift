import Foundation
import Testing
@testable import Praxmodoro

@Suite struct CapabilityTests {
    @Test func testConfiguredProductContainsEveryFeature() throws {
        let registry = CapabilityRegistry(configuredKeys: Set(FeatureKey.allCases))

        try registry.validate()
        for key in FeatureKey.allCases {
            #expect(registry.isAvailable(key), "\(key) must be available in the product")
        }
    }

    @Test func testOmittedFeatureFailsValidationButLookupSelfHeals() {
        let registry = CapabilityRegistry(
            configuredKeys: Set(FeatureKey.allCases).subtracting([.localReview]))

        #expect(throws: CapabilityRegistry.ValidationError.self) {
            try registry.validate()
        }
        #expect(registry.isAvailable(.localReview), "defined keys self-heal to available")
    }
}
