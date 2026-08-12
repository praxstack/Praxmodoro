import SwiftUI

/// Background and primary-text tokens for the companion surfaces, with the
/// two accessibility branches made explicit so they can be probed by
/// rasterization instead of inferred from source (spec: focus-loop-ui
/// "Reduce Transparency verified at render level" / "Increase Contrast
/// verified at render level").
///
/// Living Companion values, token-backed: every colour here is a
/// `DesignTokens` reference derived from the mock's tokens.css by
/// `scripts/generate-design-tokens.mjs` — this file states no colour of
/// its own.
enum SurfacePalette {
    /// The veil's alpha when the system permits translucency (`--color-veil`).
    static let veilOpacity = DesignTokens.Light.veilAlpha

    private static let paper = DesignTokens.Light.paper
    private static let ink = DesignTokens.Light.ink
    private static let deepInk = DesignTokens.Light.inkStrong

    /// Reduce Transparency replaces the veil with a solid fill — not a more
    /// opaque veil, a solid one. Nothing behind it may show through, which is
    /// what makes the alternate testable as backdrop-independence.
    static func background(reduceTransparency: Bool) -> Color {
        reduceTransparency ? paper : DesignTokens.Light.veil
    }

    /// Increase Contrast deepens the ink rather than only enlarging type, so
    /// the measured ratio rises instead of the layout shifting.
    static func primaryText(increasedContrast: Bool) -> Color {
        increasedContrast ? deepInk : ink
    }
}
