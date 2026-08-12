import SwiftUI

/// Living Companion palette for the field layers — token-backed references to
/// the mock's field colours (`--color-field-*`), derived from tokens.css by
/// `scripts/generate-design-tokens.mjs`. The ring is the mock's `.field-ring`
/// border token, `--color-veil-edge`.
enum FieldPalette {
    static let apricot = DesignTokens.Light.fieldApricot
    static let rose = DesignTokens.Light.fieldRose
    static let lavender = DesignTokens.Light.fieldLavender
    static let sage = DesignTokens.Light.fieldSage
    static let gold = DesignTokens.Light.fieldGold
    static let ring = DesignTokens.Light.veilEdge
}

/// The companion field. When `motionStilled` is true (system Reduce Motion or
/// the user's "Motion: still" toggle) the physics model is never instantiated
/// — a genuinely calm static alternate renders instead (spec: focus-loop-ui
/// "Reduce Motion standdown is total"; design decision 5).
struct CompanionFieldView: View {
    let state: String
    let motionStilled: Bool
    /// Increment to bloom the field once (choice acknowledgement).
    var pulseSignal: Int = 0
    /// Physics state — nil exactly when motion is stilled.
    private(set) var model: FieldModel?

    init(state: String, motionStilled: Bool, pulseSignal: Int = 0, seed: Double = 1) {
        self.state = state
        self.motionStilled = motionStilled
        self.pulseSignal = pulseSignal
        self.model = motionStilled ? nil : FieldModel(state: state, seed: seed)
    }

    var body: some View {
        if motionStilled {
            StaticCompanionField(state: state)
        } else {
            AnimatedCompanionField(initialModel: model ?? FieldModel(state: state), pulseSignal: pulseSignal)
        }
    }
}

/// Static alternate: the same layered composition at rest — no animation,
/// no timeline, nothing breathing. Calm, not degraded.
struct StaticCompanionField: View {
    let state: String

    var body: some View {
        FieldCanvas(transforms: FieldModel(state: state).layerTransforms(unit: 0), expanded: state == "expanded")
            .accessibilityHidden(true)
    }
}

/// Animated field: a TimelineView drives the deterministic model; rendering is
/// presentation only and holds no truth (mirror of the app's timer rule).
struct AnimatedCompanionField: View {
    @State private var model: FieldModel
    @State private var lastTick: Date?
    var pulseSignal: Int = 0

    init(initialModel: FieldModel, pulseSignal: Int = 0) {
        self._model = State(initialValue: initialModel)
        self.pulseSignal = pulseSignal
    }

    var body: some View {
        TimelineView(.animation) { context in
            FieldCanvas(transforms: currentTransforms(now: context.date), expanded: false)
        }
        .accessibilityHidden(true)
        .onChange(of: pulseSignal) {
            model.acknowledge()
        }
    }

    private func currentTransforms(now: Date) -> [FieldLayerTransform] {
        var copy = model
        let dt = min(0.05, lastTick.map { now.timeIntervalSince($0) } ?? 1.0 / 60.0)
        copy.step(dt: dt)
        Task { @MainActor in
            model = copy
            lastTick = now
        }
        return copy.layerTransforms(unit: 4.2)
    }
}

/// Shared renderer: five soft radial-gradient layers, blurred and composited —
/// the Canvas analogue of the mock's blurred gradient spans.
struct FieldCanvas: View {
    let transforms: [FieldLayerTransform]
    let expanded: Bool

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                layer(0, color: expanded ? FieldPalette.sage : FieldPalette.apricot, diameter: side * 0.92, blur: side * 0.09)
                layer(1, color: FieldPalette.rose, diameter: side * 0.78, blur: side * 0.08)
                layer(2, color: expanded ? FieldPalette.apricot : FieldPalette.lavender, diameter: side * 0.62, blur: side * 0.07)
                layer(3, color: FieldPalette.gold, diameter: side * 0.40, blur: side * 0.05)
                Circle()
                    .strokeBorder(FieldPalette.ring, lineWidth: 1)
                    .frame(width: side * 0.96, height: side * 0.96)
                    .scaleEffect(transforms.indices.contains(4) ? transforms[4].scale : 1)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func layer(_ index: Int, color: Color, diameter: CGFloat, blur: CGFloat) -> some View {
        let t = transforms.indices.contains(index) ? transforms[index] : FieldLayerTransform(dx: 0, dy: 0, scale: 1)
        return Circle()
            .fill(RadialGradient(colors: [color, color.opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: diameter / 2))
            .frame(width: diameter, height: diameter)
            .scaleEffect(t.scale)
            .offset(x: t.dx, y: t.dy)
            .blur(radius: blur)
    }
}
