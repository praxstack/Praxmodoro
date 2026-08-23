import SwiftUI

/// The card that meets you coming back from a break, carrying the exact next
/// action so the way back is read rather than remembered (spec:
/// companion-surfaces "Return overlay presents the exact next action").
///
/// It says nothing about the break that just ended. A pure function of a
/// CompanionDisplay, like every companion surface.
struct ReturnOverlay: View {
    static let controls = ["return-heading", "return-next-action", "return-continue"]

    let display: CompanionDisplay
    let onAcknowledge: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    /// The recorded first action, or the task itself when none was recorded —
    /// never an empty card.
    var wayBack: String {
        display.nextAction.isEmpty ? display.taskLine : display.nextAction
    }

    var accessibilityLabel: String { "Welcome back. Pick it up here: \(wayBack)" }

    /// The acknowledgement signal, passed as a value at construction like
    /// everything else these surfaces receive (spec: focus-loop-ui "Choice
    /// acknowledgement").
    var pulseSignal: Int = 0

    /// Forces the motion standdown regardless of the environment.
    ///
    /// `accessibilityReduceMotion` is read-only in the macOS 26 SDK, so an
    /// offscreen render cannot be made deterministic from the outside, and the
    /// in-app "Motion: still" preference has to reach these surfaces somehow.
    /// Production sets it from `AppModel.motionStilled`; nil falls through to
    /// the environment, which keeps system Reduce Motion authoritative.
    var motionStilledOverride: Bool?

    private var motionStilled: Bool { motionStilledOverride ?? reduceMotion }

    /// Exposed so the Reduce Motion standdown is assertable at runtime.
    func companionField(motionStilled: Bool) -> CompanionFieldView {
        CompanionFieldView(state: "gathering", motionStilled: motionStilled, pulseSignal: pulseSignal)
    }

    var body: some View {
        VStack(spacing: 18) {
            companionField(motionStilled: motionStilled)
                .frame(width: 88, height: 88)

            Text("Welcome back.")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .accessibilityIdentifier("return-heading")

            Text("Pick it up here")
                .font(.caption.smallCaps())
                .foregroundStyle(.secondary)

            Text(wayBack)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 10).stroke(DesignTokens.Light.paper3))
                .accessibilityIdentifier("return-next-action")

            Button {
                onAcknowledge()
            } label: {
                Label("Continue", systemImage: "arrow.right")
                    .frame(minWidth: 160, minHeight: 38)
            }
            .buttonStyle(.borderless)
            .background(RoundedRectangle(cornerRadius: 8).stroke(DesignTokens.Light.paper3))
            .keyboardShortcut(.return, modifiers: [])
            .accessibilityIdentifier("return-continue")
        }
        .padding(36)
        .foregroundStyle(SurfacePalette.primaryText(increasedContrast: contrast == .increased))
        .background(
            RoundedRectangle(cornerRadius: 20).fill(SurfacePalette.background(reduceTransparency: reduceTransparency))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }
}
