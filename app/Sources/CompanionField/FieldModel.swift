import Foundation

/// Per-layer render transform produced by the physics composition.
struct FieldLayerTransform: Equatable {
    let dx: Double
    let dy: Double
    let scale: Double
}

/// Deterministic composition of the golden-verified primitives, mirroring the
/// JS `Field` step math one-to-one (companion-physics.js). Pure value type:
/// given the same state changes and dt sequence, output is identical.
struct FieldModel {
    private(set) var scale: FieldSpring
    private(set) var amp: FieldSpring
    private(set) var speed: FieldSpring
    private(set) var driftAmp: FieldSpring
    private(set) var pulse: FieldSpring
    private(set) var breathClock: Double
    let seed: Double

    init(state: String = "breathing", seed: Double = 1, breathPhase: Double = 0) {
        let params = FieldStateParams.table[state] ?? FieldStateParams.table["breathing"]!
        self.scale = FieldSpring(value: params.scale, omega: 2.2)
        self.amp = FieldSpring(value: params.amp, omega: 1.6)
        self.speed = FieldSpring(value: params.speed, omega: 1.2)
        self.driftAmp = FieldSpring(value: params.driftAmp, omega: 1.2)
        self.pulse = FieldSpring(value: 0, omega: 7, zeta: 0.34)
        self.breathClock = breathPhase
        self.seed = seed
    }

    /// Spring toward a new state's targets; the change itself is acknowledged
    /// with a soft pulse, exactly like the mock.
    mutating func apply(state: String) {
        guard let params = FieldStateParams.table[state] else { return }
        scale.target = params.scale
        amp.target = params.amp
        speed.target = params.speed
        driftAmp.target = params.driftAmp
        pulse.kick(0.55)
    }

    /// A user choice blooms the field once (checkin answer, break choice…).
    mutating func acknowledge(_ impulse: Double = 0.75) {
        pulse.kick(impulse)
    }

    mutating func step(dt: Double) {
        scale.step(dt: dt)
        amp.step(dt: dt)
        speed.step(dt: dt)
        driftAmp.step(dt: dt)
        pulse.target = 0
        pulse.step(dt: dt)
        breathClock += dt * speed.x
    }

    /// Transforms for the five soft layers; `unit` scales drift range with the
    /// rendered field size (JS: max(width,120) * 0.028).
    func layerTransforms(unit: Double) -> [FieldLayerTransform] {
        FieldLayerSpec.all.map { layer in
            let b = FieldBreath.value(at: breathClock + layer.phase * FieldBreath.total)
            let breathScale = 1 + (b - 0.5) * 0.075 * layer.gain * amp.x
            let s = scale.x * breathScale + pulse.x * 0.045 * layer.gain
            let dx = FieldPhysics.drift(t: breathClock, seed: seed + layer.wander) * unit * layer.wander * driftAmp.x
            let dy = FieldPhysics.drift(t: breathClock + 37, seed: seed * 2 + layer.wander) * unit * layer.wander * driftAmp.x
            return FieldLayerTransform(dx: dx, dy: dy, scale: s)
        }
    }
}
