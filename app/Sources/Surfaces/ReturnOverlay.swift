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

    /// The recorded first action, or the task itself when none was recorded —
    /// never an empty card.
    var wayBack: String {
        display.nextAction.isEmpty ? display.taskLine : display.nextAction
    }

    var accessibilityLabel: String { "Welcome back. Pick it up here: \(wayBack)" }

    /// Exposed so the Reduce Motion standdown is assertable at runtime.
    func companionField(motionStilled: Bool) -> CompanionFieldView {
        CompanionFieldView(state: "gathering", motionStilled: motionStilled)
    }

    var body: some View {
        VStack(spacing: 18) {
            companionField(motionStilled: reduceMotion)
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
                .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.4)))
                .accessibilityIdentifier("return-next-action")

            Button {
                onAcknowledge()
            } label: {
                Label("Continue", systemImage: "arrow.right")
                    .frame(minWidth: 160, minHeight: 38)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [])
            .accessibilityIdentifier("return-continue")
        }
        .padding(36)
        .background(
            RoundedRectangle(cornerRadius: 20).fill(SurfacePalette.background(reduceTransparency: reduceTransparency))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }
}
