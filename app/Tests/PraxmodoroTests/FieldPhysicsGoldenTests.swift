import Foundation
import Testing
@testable import Praxmodoro

/// Golden parity with the approved JS physics contract. The JSON is produced
/// by `scripts/export-field-goldens.mjs` from companion-physics.js — if these
/// fail, the port drifted from the approved feel (design.md risk item).
final class GoldenMarker {}

@Suite struct FieldPhysicsGoldenTests {
    private func golden() throws -> [String: Any] {
        let url = try #require(Bundle(for: GoldenMarker.self).url(forResource: "field-physics-golden", withExtension: "json"))
        let data = try Data(contentsOf: url)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func testTransformsMatchJSContractAtFixedTimestamps() throws {
        let g = try golden()

        // Breath curve: asymmetric segments and sampled values.
        let breath = try #require(g["breath"] as? [String: Any])
        let segments = try #require(breath["segments"] as? [Double])
        #expect(FieldBreath.segments == segments)
        for sample in try #require(breath["samples"] as? [[String: Double]]) {
            let t = try #require(sample["t"])
            let expected = try #require(sample["value"])
            #expect(abs(FieldBreath.value(at: t) - expected) < 1e-9, "breath(\(t))")
        }

        // Drift wander stack.
        for sample in try #require(g["drift"] as? [[String: Double]]) {
            let expected = try #require(sample["value"])
            let actual = FieldPhysics.drift(t: try #require(sample["t"]), seed: try #require(sample["seed"]))
            #expect(abs(actual - expected) < 1e-9, "drift(\(sample))")
        }

        // Spring integrator traces, including the pulse spring (omega 7, zeta 0.34).
        for config in try #require(g["springs"] as? [[String: Any]]) {
            var spring = FieldSpring(
                value: try #require(config["start"] as? Double),
                omega: try #require(config["omega"] as? Double),
                zeta: try #require(config["zeta"] as? Double)
            )
            spring.target = try #require(config["target"] as? Double)
            if let kick = config["kick"] as? Double, kick != 0 { spring.kick(kick) }
            let dt = try #require(config["dt"] as? Double)
            var step = 0
            for point in try #require(config["trace"] as? [[String: Double]]) {
                let targetStep = Int(try #require(point["step"]))
                while step < targetStep { spring.step(dt: dt); step += 1 }
                #expect(abs(spring.x - (try #require(point["x"]))) < 1e-9, "spring x @\(targetStep)")
                #expect(abs(spring.v - (try #require(point["v"]))) < 1e-9, "spring v @\(targetStep)")
            }
        }

        // State-target vocabulary matches the contract exactly.
        let states = try #require(g["states"] as? [String: [String: Double]])
        for (name, expected) in states {
            let params = try #require(FieldStateParams.table[name], "state \(name) missing")
            #expect(params.scale == expected["scale"])
            #expect(params.amp == expected["amp"])
            #expect(params.speed == expected["speed"])
            #expect(params.driftAmp == expected["driftAmp"])
        }

        // Layer character (gain / phase / wander) matches.
        let layers = try #require(g["layers"] as? [[String: Any]])
        #expect(FieldLayerSpec.all.count == layers.count)
        for (spec, expected) in zip(FieldLayerSpec.all, layers) {
            #expect(spec.gain == expected["gain"] as? Double)
            #expect(spec.phase == expected["phase"] as? Double)
            #expect(spec.wander == expected["wander"] as? Double)
        }
    }
}
