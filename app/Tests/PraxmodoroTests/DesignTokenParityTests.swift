import Foundation
import SwiftUI
import Testing

@testable import Praxmodoro

/// Spec: issue #8 "Design tokens, derived rather than eyeballed" (plan:
/// docs/plans/2026-08-12-settings-parity.md, lane 2).
///
/// `DesignTokens.swift` is GENERATED from the Living Companion mock's
/// `tokens.css` and `tokens-dark.css` by `scripts/generate-design-tokens.mjs`.
/// These tests reimplement the OKLCH → OKLab → LMS → linear-sRGB → gamma
/// pipeline independently, in Swift, and hold a sampled subset of the
/// generated constants to it within 1e-3 per channel — so a hand-edited or
/// drifted constant cannot hide behind the generator's own math.
///
/// The OKLCH inputs below are hardcoded copies of the mock tokens. If a mock
/// value changes, this table changes in the same commit; that is the gate.
@MainActor
@Suite struct DesignTokenParityTests {
    private struct OKLCHToken {
        let lightness: Double
        let chroma: Double
        let hueDegrees: Double
        var alpha: Double = 1
    }

    private struct RGB {
        let red: Double
        let green: Double
        let blue: Double
    }

    // MARK: - Sampled tokens, hardcoded from tokens.css (light)

    private enum LightMock {
        static let paper = OKLCHToken(lightness: 0.965, chroma: 0.014, hueDegrees: 78)
        static let ink = OKLCHToken(lightness: 0.27, chroma: 0.035, hueDegrees: 38)
        static let accent = OKLCHToken(lightness: 0.56, chroma: 0.145, hueDegrees: 22)
        static let fieldRose = OKLCHToken(lightness: 0.83, chroma: 0.07, hueDegrees: 20)
        static let fieldApricot = OKLCHToken(lightness: 0.88, chroma: 0.075, hueDegrees: 62)
        static let fieldLavender = OKLCHToken(lightness: 0.85, chroma: 0.055, hueDegrees: 300)
        static let fieldSage = OKLCHToken(lightness: 0.87, chroma: 0.055, hueDegrees: 162)
        static let fieldGold = OKLCHToken(lightness: 0.905, chroma: 0.06, hueDegrees: 88)
    }

    // MARK: - Sampled tokens, hardcoded from tokens-dark.css (authored dark)

    private enum DarkMock {
        static let paper = OKLCHToken(lightness: 0.20, chroma: 0.018, hueDegrees: 42)
        static let ink = OKLCHToken(lightness: 0.92, chroma: 0.02, hueDegrees: 78)
        static let accent = OKLCHToken(lightness: 0.68, chroma: 0.13, hueDegrees: 26)
        static let fieldRose = OKLCHToken(lightness: 0.45, chroma: 0.055, hueDegrees: 20)
        static let fieldApricot = OKLCHToken(lightness: 0.48, chroma: 0.06, hueDegrees: 62)
        static let fieldLavender = OKLCHToken(lightness: 0.46, chroma: 0.045, hueDegrees: 300)
        static let fieldSage = OKLCHToken(lightness: 0.47, chroma: 0.045, hueDegrees: 162)
        static let fieldGold = OKLCHToken(lightness: 0.52, chroma: 0.05, hueDegrees: 88)
    }

    // MARK: - Independent OKLCH → sRGB reimplementation (Björn Ottosson's OKLab)

    private func srgb(from token: OKLCHToken) -> RGB {
        let hue = token.hueDegrees * .pi / 180
        let labA = token.chroma * cos(hue)
        let labB = token.chroma * sin(hue)

        // OKLab → LMS (cube roots undone by cubing).
        let l0 = token.lightness + 0.3963377774 * labA + 0.2158037573 * labB
        let m0 = token.lightness - 0.1055613458 * labA - 0.0638541728 * labB
        let s0 = token.lightness - 0.0894841775 * labA - 1.2914855480 * labB
        let l = l0 * l0 * l0
        let m = m0 * m0 * m0
        let s = s0 * s0 * s0

        // LMS → linear sRGB.
        let linearRed = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let linearGreen = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let linearBlue = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

        // Gamma encode, then clamp to the sRGB gamut — the same clamp the
        // generator applies (and reports) for out-of-gamut tokens.
        func encode(_ value: Double) -> Double {
            let encoded = value <= 0.0031308 ? 12.92 * value : 1.055 * pow(value, 1 / 2.4) - 0.055
            return min(1, max(0, encoded))
        }
        return RGB(red: encode(linearRed), green: encode(linearGreen), blue: encode(linearBlue))
    }

    // MARK: - WCAG 2.x math (same formulas RenderAccessibilityTests measures with)

    private func wcagLuminance(_ rgb: RGB) -> Double {
        func channel(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(rgb.red) + 0.7152 * channel(rgb.green) + 0.0722 * channel(rgb.blue)
    }

    private func contrastRatio(_ first: RGB, _ second: RGB) -> Double {
        let lighter = max(wcagLuminance(first), wcagLuminance(second))
        let darker = min(wcagLuminance(first), wcagLuminance(second))
        return (lighter + 0.05) / (darker + 0.05)
    }

    // MARK: - Parity probe

    private func expectParity(_ name: String, _ generated: Color, matches token: OKLCHToken) {
        let want = srgb(from: token)
        let resolved = generated.resolve(in: EnvironmentValues())
        let tolerance = 1e-3
        #expect(abs(Double(resolved.red) - want.red) <= tolerance,
                "\(name).red drifted from the mock token: generated \(resolved.red), derived \(want.red)")
        #expect(abs(Double(resolved.green) - want.green) <= tolerance,
                "\(name).green drifted from the mock token: generated \(resolved.green), derived \(want.green)")
        #expect(abs(Double(resolved.blue) - want.blue) <= tolerance,
                "\(name).blue drifted from the mock token: generated \(resolved.blue), derived \(want.blue)")
        #expect(abs(Double(resolved.opacity) - token.alpha) <= tolerance,
                "\(name).opacity drifted from the mock token: generated \(resolved.opacity), declared \(token.alpha)")
    }

    // Every sampled light constant must equal the independent conversion of
    // its tokens.css declaration, channel by channel.
    @Test func testLightConstantsMatchTheMockTokens() {
        expectParity("Light.paper", DesignTokens.Light.paper, matches: LightMock.paper)
        expectParity("Light.ink", DesignTokens.Light.ink, matches: LightMock.ink)
        expectParity("Light.accent", DesignTokens.Light.accent, matches: LightMock.accent)
        expectParity("Light.fieldRose", DesignTokens.Light.fieldRose, matches: LightMock.fieldRose)
        expectParity("Light.fieldApricot", DesignTokens.Light.fieldApricot, matches: LightMock.fieldApricot)
        expectParity("Light.fieldLavender", DesignTokens.Light.fieldLavender, matches: LightMock.fieldLavender)
        expectParity("Light.fieldSage", DesignTokens.Light.fieldSage, matches: LightMock.fieldSage)
        expectParity("Light.fieldGold", DesignTokens.Light.fieldGold, matches: LightMock.fieldGold)
    }

    // Same gate for the authored dark variant in tokens-dark.css.
    @Test func testDarkConstantsMatchTheAuthoredDarkTokens() {
        expectParity("Dark.paper", DesignTokens.Dark.paper, matches: DarkMock.paper)
        expectParity("Dark.ink", DesignTokens.Dark.ink, matches: DarkMock.ink)
        expectParity("Dark.accent", DesignTokens.Dark.accent, matches: DarkMock.accent)
        expectParity("Dark.fieldRose", DesignTokens.Dark.fieldRose, matches: DarkMock.fieldRose)
        expectParity("Dark.fieldApricot", DesignTokens.Dark.fieldApricot, matches: DarkMock.fieldApricot)
        expectParity("Dark.fieldLavender", DesignTokens.Dark.fieldLavender, matches: DarkMock.fieldLavender)
        expectParity("Dark.fieldSage", DesignTokens.Dark.fieldSage, matches: DarkMock.fieldSage)
        expectParity("Dark.fieldGold", DesignTokens.Dark.fieldGold, matches: DarkMock.fieldGold)
    }

    // The generated file must say it is generated and point at the source of
    // truth, so nobody edits constants that the next `npm run tokens:build`
    // would overwrite.
    @Test func testGeneratedFileDeclaresItsProvenance() throws {
        let generatedURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources").appendingPathComponent("DesignTokens.swift")
        let source = try String(contentsOf: generatedURL, encoding: .utf8)
        #expect(source.hasPrefix("// GENERATED by scripts/generate-design-tokens.mjs"),
                "DesignTokens.swift must open with its generation banner")
        #expect(source.contains("edit tokens.css, not this file"),
                "the banner must redirect edits to the mock tokens")
    }

    // Dark variant accessibility, by pure WCAG math on the authored tokens —
    // no rasterisation, no UI: the dark ground must carry the dark ink at AA
    // strength before any surface adopts it.
    @Test func testDarkPaperAgainstDarkInkClearsWCAGAA() {
        let measured = contrastRatio(srgb(from: DarkMock.paper), srgb(from: DarkMock.ink))
        #expect(measured >= 4.5,
                "dark ink on dark paper must clear WCAG AA; derived ratio \(measured)")
    }

    // The math must be able to fail: a known-white and known-black input must
    // reproduce the canonical 21:1, or the probe above proves nothing.
    @Test func testContrastMathIsAnchored() {
        let white = RGB(red: 1, green: 1, blue: 1)
        let black = RGB(red: 0, green: 0, blue: 0)
        #expect(abs(contrastRatio(white, black) - 21.0) < 1e-9)
    }
}
