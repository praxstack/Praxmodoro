import Foundation

/// Native port of the approved Living Companion physics contract
/// (`design-mocks/living-companion/companion-physics.js`). The JS engine is
/// the source of truth: constants and integration mirror it exactly, enforced
/// by FieldPhysicsGoldenTests against generated golden values.
enum FieldPhysics {
    /// Non-repeating wander: incommensurate sine stack, unit output.
    static func drift(t: Double, seed: Double) -> Double {
        sin(t * 0.083 + seed * 1.7) * 0.5
            + sin(t * 0.047 + seed * 3.1) * 0.32
            + sin(t * 0.121 + seed * 5.3) * 0.18
    }

    static func smooth(_ t: Double) -> Double { t * t * (3 - 2 * t) }
}

/// Semi-implicit spring-damper matching the JS `spring()` integrator.
struct FieldSpring {
    var x: Double
    var v: Double = 0
    var target: Double
    let omega: Double
    let zeta: Double

    init(value: Double, omega: Double, zeta: Double = 1) {
        self.x = value
        self.target = value
        self.omega = omega
        self.zeta = zeta
    }

    mutating func step(dt: Double) {
        let k = omega * omega
        let c = 2 * zeta * omega
        v += (k * (target - x) - c * v) * dt
        x += v * dt
    }

    mutating func kick(_ impulse: Double) { v += impulse }
}

/// Asymmetric calm breath: inhale 3.6 · hold 1.2 · exhale 5.4 · rest 1.4.
/// The long exhale is what reads as calming. Output in 0...1.
enum FieldBreath {
    static let segments: [Double] = [3.6, 1.2, 5.4, 1.4]
    static let total: Double = segments.reduce(0, +)

    static func value(at t: Double) -> Double {
        var phase = t.truncatingRemainder(dividingBy: total)
        if phase < 0 { phase += total }
        if phase < segments[0] { return FieldPhysics.smooth(phase / segments[0]) }
        phase -= segments[0]
        if phase < segments[1] { return 1 }
        phase -= segments[1]
        if phase < segments[2] { return 1 - FieldPhysics.smooth(phase / segments[2]) }
        return 0
    }
}

/// Per-state targets — the field's vocabulary, verbatim from the contract.
struct FieldStateParams: Equatable {
    let scale: Double
    let amp: Double
    let speed: Double
    let driftAmp: Double

    static let table: [String: FieldStateParams] = [
        "gathering": .init(scale: 0.94, amp: 0.55, speed: 1.15, driftAmp: 1.15),
        "breathing": .init(scale: 1.0, amp: 1.0, speed: 1.0, driftAmp: 1.0),
        "held": .init(scale: 0.985, amp: 0.07, speed: 0.55, driftAmp: 0.35),
        "ripple": .init(scale: 1.0, amp: 0.8, speed: 1.0, driftAmp: 0.8),
        "expanded": .init(scale: 1.1, amp: 1.25, speed: 0.72, driftAmp: 0.9),
        "settled": .init(scale: 0.97, amp: 0.15, speed: 0.5, driftAmp: 0.3),
    ]
}

/// Layer character: breath gain, phase offset, drift gain — one per soft layer.
struct FieldLayerSpec: Equatable {
    let sel: String
    let gain: Double
    let phase: Double
    let wander: Double

    static let all: [FieldLayerSpec] = [
        .init(sel: ".field-a", gain: 1.0, phase: 0.0, wander: 1.0),
        .init(sel: ".field-b", gain: 0.8, phase: 0.35, wander: 1.35),
        .init(sel: ".field-c", gain: 0.65, phase: 0.62, wander: 1.7),
        .init(sel: ".field-core", gain: 1.15, phase: 0.15, wander: 0.55),
        .init(sel: ".field-ring", gain: 0.4, phase: 0.0, wander: 0.0),
    ]
}
