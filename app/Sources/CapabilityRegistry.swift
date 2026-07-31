import Foundation

/// Feature keys every surface consults (spec: app-scaffold "Edition
/// capability registry"). String-typed for stable persistence later.
enum FeatureKey: String, CaseIterable, Sendable {
    case initiation
    case checkins
    case adaptiveBreaks
    case accessibilityModes
    case focusLoop
    case thoughtParking
    case localReview
    case sessionPersistence
}

/// Edition seam. Lite grants everything in this change; core ADHD/
/// accessibility support is structurally impossible to gate off Lite:
/// validation fails fast in debug and lookup self-heals in release.
struct CapabilityRegistry: Sendable {
    enum Edition: String, CaseIterable, Sendable { case lite, pro, enterprise }

    struct ValidationError: Error, Equatable {
        let edition: Edition
        let missing: Set<FeatureKey>
    }

    /// Initiation help, check-ins, adaptive breaks, and accessibility are
    /// never paywalled (AGENTS.md product boundary; research
    /// w2-product-scope-adjudication-005).
    static let neverPaywalled: Set<FeatureKey> = [.initiation, .checkins, .adaptiveBreaks, .accessibilityModes]

    /// This change ships everything in Lite; Pro/Enterprise inherit it all.
    static let defaultGrants: [Edition: Set<FeatureKey>] = {
        let all = Set(FeatureKey.allCases)
        return [.lite: all, .pro: all, .enterprise: all]
    }()

    let edition: Edition
    private let grants: [Edition: Set<FeatureKey>]

    init(edition: Edition, grants: [Edition: Set<FeatureKey>] = CapabilityRegistry.defaultGrants) {
        self.edition = edition
        self.grants = grants
    }

    func isAvailable(_ key: FeatureKey) -> Bool {
        Self.neverPaywalled.contains(key) || (grants[edition] ?? []).contains(key)
    }

    /// Startup validation: every edition must grant the never-paywalled set.
    func validate() throws {
        for edition in Edition.allCases {
            let missing = Self.neverPaywalled.subtracting(grants[edition] ?? [])
            if !missing.isEmpty {
                throw ValidationError(edition: edition, missing: missing)
            }
        }
    }
}
