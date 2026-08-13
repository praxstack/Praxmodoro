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
    case menuBarSurface
    case focusCapsule
    case returnOverlay
    // add-session-settings: all Lite, none paywallable.
    case sessionSettings
    case rhythmControl
    case soundCues
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
    ///
    /// The companion surfaces join the set because each one *carries* that
    /// behavior: the popover holds initiation and check-in entry, the capsule
    /// holds hold/resume, and the return overlay is the re-entry path out of a
    /// break. Gating any of them would gate the boundary behavior itself
    /// (spec: companion-surfaces "Companion surfaces are never paywalled").
    /// The session-settings keys join because rhythm control and sound are
    /// the accessibility scaffolding this product exists for — a paywalled
    /// tick or break cadence would gate the boundary behaviour itself
    /// (spec: session-settings "Settings are never paywalled").
    static let neverPaywalled: Set<FeatureKey> = [
        .initiation, .checkins, .adaptiveBreaks, .accessibilityModes,
        .menuBarSurface, .focusCapsule, .returnOverlay,
        .sessionSettings, .rhythmControl, .soundCues,
    ]

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
