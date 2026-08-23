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
        let alpha: Double

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

        func maximumRGBDelta(from other: Pixel) -> Double {
            max(abs(red - other.red), abs(green - other.green), abs(blue - other.blue))
        }

        func maximumRGBByteDelta(from other: Pixel) -> Int {
            Int((maximumRGBDelta(from: other) * 255).rounded())
        }

        func blendFit(
            foreground: Pixel, background: Pixel, coverage: Double, tolerance: Double
        ) -> (failures: Int, maximumError: Double) {
            let redError = abs(red - (background.red + coverage * (foreground.red - background.red)))
            let greenError = abs(green - (background.green + coverage * (foreground.green - background.green)))
            let blueError = abs(blue - (background.blue + coverage * (foreground.blue - background.blue)))
            return (
                [redError, greenError, blueError].count { $0 > tolerance },
                max(redError, greenError, blueError)
            )
        }
    }

    /// Rasterize a view offscreen and read its centre pixel.
    private func centrePixel(of view: some View, side: CGFloat = 24) throws -> Pixel {
        let renderer = ImageRenderer(content: view.frame(width: side, height: side))
        renderer.scale = 1
        renderer.colorMode = .nonLinear
        let image = try #require(renderer.cgImage, "ImageRenderer produced no bitmap")
        #expect(image.width == Int(side) && image.height == Int(side))

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
            blue: Double(buffer[offset + 2]) / 255,
            alpha: Double(buffer[offset + 3]) / 255
        )
    }

    private func pixels(
        of view: some View, width: Int, height: Int, contrast: ColorSchemeContrast
    ) throws -> [Pixel] {
        let renderer = ImageRenderer(
            content:
                ZStack {
                    SurfacePalette.background(reduceTransparency: true)
                    view
                }
                .frame(width: CGFloat(width), height: CGFloat(height))
                .environment(\._accessibilityReduceTransparency, true)
                .environment(\._colorSchemeContrast, contrast)
                .environment(\.colorScheme, .light)
                .environment(\.locale, Locale(identifier: "en_US_POSIX")))
        renderer.scale = 1
        renderer.colorMode = .nonLinear
        let image = try #require(renderer.cgImage, "ImageRenderer produced no bitmap")
        #expect(
            image.width == width && image.height == height,
            "ImageRenderer returned \(image.width)x\(image.height), expected \(width)x\(height)")
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(
            CGContext(
                data: &buffer, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return stride(from: 0, to: buffer.count, by: 4).map { offset in
            Pixel(
                red: Double(buffer[offset]) / 255,
                green: Double(buffer[offset + 1]) / 255,
                blue: Double(buffer[offset + 2]) / 255,
                alpha: Double(buffer[offset + 3]) / 255)
        }
    }

    func assertActualSurfaceContrast<Content: View>(
        _ makeView: () -> Content, width: Int, height: Int, name: String
    ) throws {
        let standard = try pixels(of: makeView(), width: width, height: height, contrast: .standard)
        let increased = try pixels(of: makeView(), width: width, height: height, contrast: .increased)
        let background = try centrePixel(of: Rectangle().fill(SurfacePalette.background(reduceTransparency: true)))
        let standardText = try centrePixel(of: Rectangle().fill(SurfacePalette.primaryText(increasedContrast: false)))
        let increasedText = try centrePixel(of: Rectangle().fill(SurfacePalette.primaryText(increasedContrast: true)))
        let fitTolerance = 2.0 / 255
        var changed = 0
        var nearlyOpaqueGlyphs = 0
        var backgroundChanges = 0
        var backgroundPixels = 0
        var nonOpaqueOutputs = 0
        var invalidCoverages = 0
        var fitFailures = 0
        var maximumFitError = 0.0
        var failureBounds: (minX: Int, minY: Int, maxX: Int, maxY: Int)?
        let standardDirection = (
            standardText.red - background.red,
            standardText.green - background.green,
            standardText.blue - background.blue
        )
        let increasedDirection = (
            increasedText.red - background.red,
            increasedText.green - background.green,
            increasedText.blue - background.blue
        )
        let denominator =
            standardDirection.0 * standardDirection.0
            + standardDirection.1 * standardDirection.1
            + standardDirection.2 * standardDirection.2
            + increasedDirection.0 * increasedDirection.0
            + increasedDirection.1 * increasedDirection.1
            + increasedDirection.2 * increasedDirection.2
        #expect(denominator > 0, "standard and increased text tokens must differ from the background")
        guard denominator > 0 else { return }

        for (index, pair) in zip(standard, increased).enumerated() {
            let (standardPixel, increasedPixel) = pair
            if standardPixel.maximumRGBByteDelta(from: increasedPixel) < 3 {
                let standardIsBackground = standardPixel.maximumRGBByteDelta(from: background) <= 1
                let increasedIsBackground = increasedPixel.maximumRGBByteDelta(from: background) <= 1
                if standardIsBackground || increasedIsBackground {
                    backgroundPixels += 1
                    if !standardIsBackground || !increasedIsBackground { backgroundChanges += 1 }
                }
                continue
            }

            changed += 1
            if standardPixel.alpha != 1 || increasedPixel.alpha != 1 {
                nonOpaqueOutputs += 1
            }

            let numerator =
                standardDirection.0 * (standardPixel.red - background.red)
                + standardDirection.1 * (standardPixel.green - background.green)
                + standardDirection.2 * (standardPixel.blue - background.blue)
                + increasedDirection.0 * (increasedPixel.red - background.red)
                + increasedDirection.1 * (increasedPixel.green - background.green)
                + increasedDirection.2 * (increasedPixel.blue - background.blue)
            let coverage = numerator / denominator
            if !(0...1).contains(coverage) { invalidCoverages += 1 }
            if coverage >= 0.95 { nearlyOpaqueGlyphs += 1 }

            let standardFit = standardPixel.blendFit(
                foreground: standardText, background: background, coverage: coverage, tolerance: fitTolerance)
            let increasedFit = increasedPixel.blendFit(
                foreground: increasedText, background: background, coverage: coverage, tolerance: fitTolerance)
            fitFailures += standardFit.failures + increasedFit.failures
            maximumFitError = max(maximumFitError, standardFit.maximumError, increasedFit.maximumError)
            if standardFit.failures + increasedFit.failures > 0 {
                let x = index % width
                let y = index / width
                if let bounds = failureBounds {
                    failureBounds = (
                        min(bounds.minX, x), min(bounds.minY, y),
                        max(bounds.maxX, x), max(bounds.maxY, y)
                    )
                } else {
                    failureBounds = (x, y, x, y)
                }
            }
        }

        #expect(backgroundPixels > 0, "\(name) exposed no sampled opaque background pixels")
        #expect(backgroundChanges == 0, "\(name) changed \(backgroundChanges) opaque background pixels")
        #expect(nonOpaqueOutputs == 0, "\(name) text mask contains \(nonOpaqueOutputs) non-opaque output pixels")
        #expect(invalidCoverages == 0, "\(name) produced \(invalidCoverages) glyph coverages outside 0...1")
        #expect(
            fitFailures == 0,
            "\(name) has \(fitFailures) channel samples outside the 2/255 palette blend tolerance; max error \(maximumFitError); bounds \(String(describing: failureBounds))"
        )
        #expect(changed >= 20, "\(name) exposed only \(changed) changed text pixels")
        #expect(
            nearlyOpaqueGlyphs >= 8,
            "\(name) exposed only \(nearlyOpaqueGlyphs) primary-text pixels with at least 95% glyph coverage")

        let standardRatio = background.contrastRatio(against: standardText)
        let increasedRatio = background.contrastRatio(against: increasedText)
        #expect(standardRatio >= 4.5, "\(name) standard primary text must clear 4.5:1")
        #expect(increasedRatio > standardRatio, "\(name) Increase Contrast must raise the ratio")
        #expect(increasedRatio >= 7, "\(name) increased primary text must clear 7:1")
    }

    private var fixedDisplay: CompanionDisplay {
        CompanionDisplay(
            phase: .running,
            taskLine: "Edit the outline",
            nextAction: "Open the file and read the first heading",
            timeText: "17:00",
            statusLine: "Focusing",
            fieldSummary: "Companion field, breathing gently",
            offersAdjustment: false)
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
        #expect(
            opaqueOverRed.isIndistinguishable(from: opaqueOverBlue),
            "Reduce Transparency must hide the backdrop entirely; got \(opaqueOverRed) over red and \(opaqueOverBlue) over blue")

        let veiledOverRed = try centrePixel(of: background(false, over: .red))
        let veiledOverBlue = try centrePixel(of: background(false, over: .blue))
        #expect(
            !veiledOverRed.isIndistinguishable(from: veiledOverBlue),
            "the translucent branch must actually be translucent, otherwise the opaque branch proves nothing")
        #expect(
            !veiledOverRed.isIndistinguishable(from: opaqueOverRed),
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
        #expect(
            surface.contrastRatio(against: surface) == 1.0,
            "a colour against itself must measure 1:1, or the probe is not measuring contrast")
    }

    @Test func testActualMenuBarPopoverUsesIncreaseContrastToken() throws {
        try assertActualSurfaceContrast(
            {
                MenuBarPopover(
                    display: fixedDisplay, actions: .inert, motionStilledOverride: true)
            },
            width: 320, height: 420, name: "MenuBarPopover")
    }

    @Test func testActualFocusCapsuleUsesIncreaseContrastToken() throws {
        try assertActualSurfaceContrast(
            {
                FocusCapsule(
                    display: fixedDisplay, actions: .inert, motionStilledOverride: true)
            },
            width: 320, height: 72, name: "FocusCapsule")
    }

    @Test func testActualReturnOverlayUsesIncreaseContrastToken() throws {
        try assertActualSurfaceContrast(
            {
                ReturnOverlay(
                    display: fixedDisplay, onAcknowledge: {}, motionStilledOverride: true)
            },
            width: 480, height: 360, name: "ReturnOverlay")
    }
}
