import CoreGraphics
import Foundation
import SwiftUI
import Testing

@testable import Praxmodoro

/// Spec: focus-loop-ui "Reduce Transparency verified at render level" and
/// "Increase Contrast verified at render level".
///
/// M1 proved the alternates by scanning source, which cannot see what actually
/// renders. These tests rasterize the real tokens with `ImageRenderer` and
/// measure pixels: opacity is proved by backdrop-independence, contrast by the
/// WCAG ratio computed from rendered luminances.
@MainActor
@Suite struct RenderAccessibilityTests {
    private struct Pixel: Equatable {
        let red: Double
        let green: Double
        let blue: Double

        /// WCAG 2.x relative luminance.
        var luminance: Double {
            func channel(_ value: Double) -> Double {
                value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
        }

        func contrastRatio(against other: Pixel) -> Double {
            let lighter = max(luminance, other.luminance)
            let darker = min(luminance, other.luminance)
            return (lighter + 0.05) / (darker + 0.05)
        }

        /// Rasterization is not bit-exact across color pipelines; compare with
        /// a tolerance well below any difference a real veil would produce.
        func isIndistinguishable(from other: Pixel, tolerance: Double = 0.01) -> Bool {
            abs(red - other.red) <= tolerance
                && abs(green - other.green) <= tolerance
                && abs(blue - other.blue) <= tolerance
        }
    }

    /// Rasterize a view offscreen and read its centre pixel.
    private func centrePixel(of view: some View, side: CGFloat = 24) throws -> Pixel {
        let renderer = ImageRenderer(content: view.frame(width: side, height: side))
        renderer.scale = 1
        let image = try #require(renderer.cgImage, "ImageRenderer produced no bitmap")

        let width = Int(side)
        let height = Int(side)
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(
            CGContext(
                data: &buffer,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))

        let offset = ((height / 2) * width + width / 2) * 4
        return Pixel(
            red: Double(buffer[offset]) / 255,
            green: Double(buffer[offset + 1]) / 255,
            blue: Double(buffer[offset + 2]) / 255
        )
    }

    private func background(_ reduceTransparency: Bool, over backdrop: Color) -> some View {
        ZStack {
            backdrop
            Rectangle().fill(SurfacePalette.background(reduceTransparency: reduceTransparency))
        }
    }

    // Opacity is backdrop-independence: with Reduce Transparency on, what
    // renders must be the same over red as over blue. With it off, the veil
    // lets the backdrop through and the two must differ.
    @Test func testReduceTransparencyBackgroundIsOpaque() throws {
        let opaqueOverRed = try centrePixel(of: background(true, over: .red))
        let opaqueOverBlue = try centrePixel(of: background(true, over: .blue))
        #expect(opaqueOverRed.isIndistinguishable(from: opaqueOverBlue),
                "Reduce Transparency must hide the backdrop entirely; got \(opaqueOverRed) over red and \(opaqueOverBlue) over blue")

        let veiledOverRed = try centrePixel(of: background(false, over: .red))
        let veiledOverBlue = try centrePixel(of: background(false, over: .blue))
        #expect(!veiledOverRed.isIndistinguishable(from: veiledOverBlue),
                "the translucent branch must actually be translucent, otherwise the opaque branch proves nothing")
        #expect(!veiledOverRed.isIndistinguishable(from: opaqueOverRed),
                "the two branches must render differently over the same backdrop")
    }

    // Contrast measured from rendered pixels, not from declared values.
    @Test func testIncreaseContrastRaisesMeasuredRatio() throws {
        let surface = try centrePixel(of: Rectangle().fill(SurfacePalette.background(reduceTransparency: true)))
        let standardText = try centrePixel(of: Rectangle().fill(SurfacePalette.primaryText(increasedContrast: false)))
        let increasedText = try centrePixel(of: Rectangle().fill(SurfacePalette.primaryText(increasedContrast: true)))

        let standardRatio = surface.contrastRatio(against: standardText)
        let increasedRatio = surface.contrastRatio(against: increasedText)

        #expect(standardRatio >= 4.5, "normal text must clear the WCAG AA minimum; measured \(standardRatio)")
        #expect(increasedRatio > standardRatio, "Increase Contrast must actually raise the ratio; \(increasedRatio) vs \(standardRatio)")
        #expect(increasedRatio >= 7.0, "the increased-contrast branch must clear AAA; measured \(increasedRatio)")
    }

    // The probe must be able to fail: a measurement that reports a passing
    // ratio for two identical colours is measuring nothing.
    @Test func testContrastProbeCanFail() throws {
        let surface = try centrePixel(of: Rectangle().fill(SurfacePalette.background(reduceTransparency: true)))
        #expect(surface.contrastRatio(against: surface) == 1.0,
                "a colour against itself must measure 1:1, or the probe is not measuring contrast")
    }
}
