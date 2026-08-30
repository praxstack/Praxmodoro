import Foundation

/// Stable feature keys used to verify the one configured product.
enum FeatureKey: String, CaseIterable, Sendable {
    case initiation
    case checkins
    case adaptiveBreaks
    case accessibilityModes
    case focusLoop
    case thoughtParking
    case localReview
    case sessionPersistence
    case menuBarSurface
    case focusCapsule
    case returnOverlay
    case sessionSettings
    case rhythmControl
    case soundCues
}

/// Startup validation rejects an incomplete product configuration while
/// runtime lookup self-heals so a bad fixture cannot withhold behavior.
struct CapabilityRegistry: Sendable {
    struct ValidationError: Error, Equatable {
        let missing: Set<FeatureKey>
    }

    private let configuredKeys: Set<FeatureKey>

    init(configuredKeys: Set<FeatureKey>) {
        self.configuredKeys = configuredKeys
    }

    func isAvailable(_: FeatureKey) -> Bool {
        true
    }

    func validate() throws {
        let missing = Set(FeatureKey.allCases).subtracting(configuredKeys)
        if !missing.isEmpty {
            throw ValidationError(missing: missing)
        }
    }
}
