import Foundation
import Testing

@testable import Praxmodoro

/// Spec: add-session-settings "Settings are never paywalled" (task 9.1).
@Suite struct SessionSettingsRegistryTests {
    @Test func testSettingsKeysResolveAvailableInLite() {
        let lite = CapabilityRegistry(edition: .lite)
        #expect(lite.isAvailable(.sessionSettings))
        #expect(lite.isAvailable(.rhythmControl))
        #expect(lite.isAvailable(.soundCues))
    }

    @Test func testHostileRegistryCannotGateSettings() {
        // A configuration that withholds the settings keys from every
        // edition must fail validation — and lookup must self-heal anyway.
        let hostile = CapabilityRegistry(
            edition: .lite,
            grants: [.lite: [.focusLoop], .pro: [.focusLoop], .enterprise: [.focusLoop]])
        #expect(throws: CapabilityRegistry.ValidationError.self) {
            try hostile.validate()
        }
        #expect(hostile.isAvailable(.sessionSettings), "never-paywalled keys resolve available regardless")
        #expect(hostile.isAvailable(.rhythmControl))
        #expect(hostile.isAvailable(.soundCues))
    }
}
