import SwiftUI

/// Background and primary-text tokens for the companion surfaces, with the
/// two accessibility branches made explicit so they can be probed by
/// rasterization instead of inferred from source (spec: focus-loop-ui
/// "Reduce Transparency verified at render level" / "Increase Contrast
/// verified at render level").
///
/// Living Companion values: warm dusk paper, warm ink. These are the sRGB
/// approximations of the mock's tokens, matching `FieldPalette`'s pipeline.
enum SurfacePalette {
    /// The veil's alpha when the system permits translucency.
    static let veilOpacity = 0.72

    private static let paper = Color(red: 0.99, green: 0.97, blue: 0.94)
    private static let ink = Color(red: 0.24, green: 0.20, blue: 0.18)
    private static let deepInk = Color(red: 0.05, green: 0.04, blue: 0.03)

    /// Reduce Transparency replaces the veil with a solid fill — not a more
    /// opaque veil, a solid one. Nothing behind it may show through, which is
    /// what makes the alternate testable as backdrop-independence.
    static func background(reduceTransparency: Bool) -> Color {
        reduceTransparency ? paper : paper.opacity(veilOpacity)
    }

    /// Increase Contrast deepens the ink rather than only enlarging type, so
    /// the measured ratio rises instead of the layout shifting.
    static func primaryText(increasedContrast: Bool) -> Color {
        increasedContrast ? deepInk : ink
    }
}
