import Foundation
import Testing

@testable import Praxmodoro

/// Spec: session-settings "Settings ship in the one product" (task 9.1).
@Suite struct SessionSettingsRegistryTests {
    @Test func testSettingsKeysResolveAvailableInProduct() {
        let registry = CapabilityRegistry(configuredKeys: Set(FeatureKey.allCases))
        #expect(registry.isAvailable(.sessionSettings))
        #expect(registry.isAvailable(.rhythmControl))
        #expect(registry.isAvailable(.soundCues))
    }

    @Test func testHostileRegistryCannotGateSettings() {
        let settingsKeys: Set<FeatureKey> = [.sessionSettings, .rhythmControl, .soundCues]
        let hostile = CapabilityRegistry(
            configuredKeys: Set(FeatureKey.allCases).subtracting(settingsKeys))
        #expect(throws: CapabilityRegistry.ValidationError.self) {
            try hostile.validate()
        }
        #expect(hostile.isAvailable(.sessionSettings), "defined keys resolve available regardless")
        #expect(hostile.isAvailable(.rhythmControl))
        #expect(hostile.isAvailable(.soundCues))
    }
}
