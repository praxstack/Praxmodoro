import Foundation
import SwiftUI
import Testing
@testable import Praxmodoro

@Suite struct CompanionFieldTests {
    // Spec: focus-loop-ui "Reduce Motion standdown is total" — the physics
    // type is never instantiated when motion is stilled (design decision 5).
    @MainActor
    @Test func testReduceMotionNeverInstantiatesPhysics() {
        let stilled = CompanionFieldView(state: "breathing", motionStilled: true)
        #expect(stilled.model == nil)

        let animated = CompanionFieldView(state: "breathing", motionStilled: false)
        #expect(animated.model != nil)
    }

    // The composition is deterministic: identical state changes + dt sequence
    // produce identical transforms (renderer holds no truth of its own).
    @Test func testFieldModelIsDeterministic() {
        var a = FieldModel(state: "breathing", seed: 1)
        var b = FieldModel(state: "breathing", seed: 1)
        for _ in 0..<180 {
            a.step(dt: 1.0 / 60.0)
            b.step(dt: 1.0 / 60.0)
        }
        a.apply(state: "held")
        b.apply(state: "held")
        for _ in 0..<120 {
            a.step(dt: 1.0 / 60.0)
            b.step(dt: 1.0 / 60.0)
        }
        #expect(a.layerTransforms(unit: 4.2) == b.layerTransforms(unit: 4.2))
    }

    // Holding the timer lets the breath glide toward stillness: amplitude
    // shrinks with spring momentum instead of freezing.
    @Test func testHoldGlidesTowardStillness() {
        var model = FieldModel(state: "breathing", seed: 1)
        for _ in 0..<120 { model.step(dt: 1.0 / 60.0) }
        let breathingAmp = model.amp.x
        model.apply(state: "held")
        var samples: [Double] = []
        for _ in 0..<240 {
            model.step(dt: 1.0 / 60.0)
            samples.append(model.amp.x)
        }
        #expect(breathingAmp > 0.9)
        #expect(samples.last! < 0.12)
        // Monotone-ish decay, not a hard cut: early samples still well above target.
        #expect(samples[10] > 0.5)
    }
}

@MainActor
@Suite struct FieldRendererSmokeTests {
    // Task 4.2 smoke: render breathing / held / expanded stills for visual
    // side-by-side with the approved mock. Artifacts land in /tmp for review.
    @Test func testRendersSmokeStills() throws {
        let outDir = URL(fileURLWithPath: "/tmp/praxmodoro-field-smoke", isDirectory: true)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        for state in ["breathing", "held", "expanded"] {
            var model = FieldModel(state: state, seed: 1, breathPhase: 2.4)
            for _ in 0..<90 { model.step(dt: 1.0 / 60.0) }
            let view = FieldCanvas(transforms: model.layerTransforms(unit: 8), expanded: state == "expanded")
                .frame(width: 360, height: 360)
                .background(Color(red: 0.97, green: 0.94, blue: 0.90))
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            let image = try #require(renderer.nsImage)
            let tiff = try #require(image.tiffRepresentation)
            let png = try #require(NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]))
            try png.write(to: outDir.appendingPathComponent("field-\(state).png"))
        }
        #expect(FileManager.default.fileExists(atPath: outDir.appendingPathComponent("field-breathing.png").path))
    }
}
